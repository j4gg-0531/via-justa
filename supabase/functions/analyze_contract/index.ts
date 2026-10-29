// ============================================================================
// Vía Justa MVP · Edge Function `analyze_contract` (VJ-14)
// ============================================================================
// Endpoint: POST /functions/v1/analyze_contract
// Seguridad y Privacidad (RN-10 / D9 / D20 / D22):
//   1. `verify_jwt = true` en `supabase/config.toml` + verificación explícita
//      de identidad del usuario mediante `auth.getUser(jwt)`.
//   2. Reserva atómica de cuota diaria en `public.ai_usage` mediante la RPC
//      `public.consume_ai_daily_quota(user.id)` (máximo 5 análisis/día en
//      zona horaria `America/Bogota`). Si se agota, devuelve HTTP 429
//      con `code: "AI_DAILY_LIMIT_EXCEEDED"`.
//   3. Si la invocación posterior a Gemini falla (`502`/`504`/`AI_RESPONSE_INVALID`),
//      reintegra automáticamente la unidad de cuota mediante
//      `public.refund_ai_daily_quota(user.id)` para que el reintento del
//      usuario no penalice su cupo diario.
//   4. Cero retención (RN-10): el texto del contrato NUNCA se almacena en base
//      de datos, Storage ni logs del servidor.
// ============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  type ContractErrorCode,
  type ContractModelClient,
  ContractServiceError,
  GeminiContractModelClient,
  validateAndSanitizeModelOutput,
  validateContractAnalysisRequest,
} from "./contract_analyzer.ts";

export interface AuthVerifier {
  verifyUserId(jwt: string): Promise<string | null>;
}

export interface QuotaManager {
  consumeQuota(userId: string): Promise<{
    allowed: boolean;
    code: string;
    used_count: number;
    daily_limit: number;
    remaining: number;
    day: string;
    timezone: string;
  }>;
  refundQuota(userId: string): Promise<void>;
}

export interface AnalyzeContractHandlerDeps {
  authVerifier: AuthVerifier;
  quotaManager: QuotaManager;
  modelClient: ContractModelClient;
}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

const MAX_RAW_BODY_BYTES = 131072; // 128 KB máximo de payload JSON crudo

function jsonErrorResponse(
  status: number,
  code: ContractErrorCode,
  message: string,
  extra?: Record<string, unknown>,
): Response {
  return new Response(
    JSON.stringify({
      error: code,
      code,
      message,
      ...(extra ?? {}),
    }),
    {
      status,
      headers: CORS_HEADERS,
    },
  );
}

/**
 * Crea el manejador HTTP puro e inyectable para pruebas unitarias e integración.
 */
export function createAnalyzeContractHandler(deps: AnalyzeContractHandlerDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: CORS_HEADERS });
    }

    if (req.method !== "POST") {
      return jsonErrorResponse(
        405,
        "INVALID_INPUT_EMPTY",
        "Método HTTP no permitido. Usa POST.",
      );
    }

    // 1. Extraer y verificar JWT de sesión
    const authHeader = req.headers.get("Authorization") ??
      req.headers.get("authorization");
    if (!authHeader || !authHeader.toLowerCase().startsWith("bearer ")) {
      return jsonErrorResponse(
        401,
        "AUTH_UNAUTHORIZED",
        "Sesión requerida para analizar documentos.",
      );
    }

    const token = authHeader.slice(7).trim();
    if (token.length === 0) {
      return jsonErrorResponse(
        401,
        "AUTH_UNAUTHORIZED",
        "Token de sesión vacío o inválido.",
      );
    }

    let userId: string | null = null;
    try {
      userId = await deps.authVerifier.verifyUserId(token);
    } catch {
      userId = null;
    }

    if (!userId) {
      return jsonErrorResponse(
        401,
        "AUTH_UNAUTHORIZED",
        "Sesión inválida o expirada. Inicia sesión nuevamente.",
      );
    }

    // 2. Verificar tamaño máximo de cuerpo HTTP antes de parsear
    const contentLengthHeader = req.headers.get("content-length");
    if (contentLengthHeader) {
      const byteLength = Number.parseInt(contentLengthHeader, 10);
      if (!Number.isNaN(byteLength) && byteLength > MAX_RAW_BODY_BYTES) {
        return jsonErrorResponse(
          413,
          "TEXT_TOO_LONG",
          "El cuerpo de la solicitud supera el límite máximo permitido.",
        );
      }
    }

    let rawBodyText: string;
    try {
      rawBodyText = await req.text();
    } catch {
      return jsonErrorResponse(
        400,
        "INVALID_INPUT_EMPTY",
        "No fue posible leer el cuerpo de la solicitud.",
      );
    }

    if (new TextEncoder().encode(rawBodyText).byteLength > MAX_RAW_BODY_BYTES) {
      return jsonErrorResponse(
        413,
        "TEXT_TOO_LONG",
        "El texto supera el tamaño máximo permitido.",
      );
    }

    let parsedPayload: unknown;
    try {
      parsedPayload = JSON.parse(rawBodyText);
    } catch {
      return jsonErrorResponse(
        400,
        "INVALID_INPUT_EMPTY",
        "El cuerpo de la solicitud no es un JSON válido.",
      );
    }

    // 3. Validar campos tipados (`contract_text`/`text`, `locale`/`language`, <= 15.000 chars)
    let validatedInput;
    try {
      validatedInput = validateContractAnalysisRequest(parsedPayload);
    } catch (err) {
      if (err instanceof ContractServiceError) {
        return jsonErrorResponse(err.httpStatus, err.code, err.message);
      }
      return jsonErrorResponse(
        400,
        "INVALID_INPUT_EMPTY",
        "Solicitud de análisis inválida.",
      );
    }

    // 4. Consumir cuota diaria atómica en `public.ai_usage` (máx. 5/día en America/Bogota)
    let quotaStatus;
    try {
      quotaStatus = await deps.quotaManager.consumeQuota(userId);
    } catch {
      return jsonErrorResponse(
        503,
        "AI_SERVICE_UNAVAILABLE",
        "No fue posible verificar la cuota diaria de análisis.",
      );
    }

    if (!quotaStatus.allowed) {
      return jsonErrorResponse(
        429,
        "AI_DAILY_LIMIT_EXCEEDED",
        "Has alcanzado el límite diario de análisis de contratos.",
        {
          daily_limit: quotaStatus.daily_limit,
          used_count: quotaStatus.used_count,
          remaining: quotaStatus.remaining,
          day: quotaStatus.day,
          timezone: quotaStatus.timezone,
        },
      );
    }

    // 5. Invocar Gemini y validar estrictamente el esquema de salida.
    //    Si falla el proveedor o el esquema, se reintegra la cuota reservada.
    try {
      const rawModelResponse = await deps.modelClient.generateStructuredAnalysis({
        contractText: validatedInput.contractText,
        locale: validatedInput.locale,
        signal: req.signal,
      });

      const sanitizedResult = validateAndSanitizeModelOutput(
        rawModelResponse,
        validatedInput.locale,
      );

      return new Response(JSON.stringify(sanitizedResult), {
        status: 200,
        headers: CORS_HEADERS,
      });
    } catch (err) {
      // Reintegrar la cuota para que un fallo técnico no penalice al usuario al reintentar
      try {
        await deps.quotaManager.refundQuota(userId);
      } catch {
        // Silenciar error secundario de reembolso sin exponer trazas internas
      }

      if (err instanceof ContractServiceError) {
        return jsonErrorResponse(err.httpStatus, err.code, err.message);
      }

      return jsonErrorResponse(
        502,
        "AI_SERVICE_UNAVAILABLE",
        "El servicio de análisis no está disponible temporalmente.",
      );
    }
  };
}

// Inicialización del servidor Deno en Supabase Edge Runtime
if (import.meta.main) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const geminiModel = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";

  const authClient = createClient(supabaseUrl, supabaseAnonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const handler = createAnalyzeContractHandler({
    authVerifier: {
      async verifyUserId(jwt: string): Promise<string | null> {
        const { data, error } = await authClient.auth.getUser(jwt);
        if (error || !data?.user?.id) {
          return null;
        }
        return data.user.id;
      },
    },
    quotaManager: {
      async consumeQuota(userId: string) {
        const { data, error } = await serviceClient.rpc(
          "consume_ai_daily_quota",
          { p_user_id: userId },
        );
        if (error || !data) {
          throw new Error("Quota RPC error");
        }
        return data;
      },
      async refundQuota(userId: string) {
        await serviceClient.rpc("refund_ai_daily_quota", { p_user_id: userId });
      },
    },
    modelClient: new GeminiContractModelClient({
      apiKey: geminiApiKey,
      model: geminiModel,
      timeoutMs: 25000,
    }),
  });

  Deno.serve(handler);
}
