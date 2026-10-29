#!/usr/bin/env python3
"""Convierte co.svg (Simplemaps) a assets/data/colombia_departments_geo.json.

Uso (desde la raíz del repositorio):
    python tools/svg_to_geo_json.py tools/source/co.svg assets/data/colombia_departments_geo.json

Salida: JSON con los límites globales y, por departamento, el código DANE,
el nombre y sus anillos de puntos [x, y] en coordenadas absolutas del SVG
(0..1000). Sin dependencias externas (solo biblioteca estándar).

Fuente: Simplemaps.com (https://simplemaps.com/resources/svg-license).
Se ejecuta UNA vez; el JSON resultante se versiona. No se escriben coordenadas a mano.
"""
import json
import re
import sys

# Equivalencia ID de Simplemaps -> código DANE (DIVIPOLA, 2 dígitos).
# Revisar contra la tabla oficial del DANE antes de dar por cerrado.
DANE_CODES = {
    "COANT": "05", "COATL": "08", "CODC": "11", "COBOL": "13",
    "COBOY": "15", "COCAL": "17", "COCAQ": "18", "COCAU": "19",
    "COCES": "20", "COCHO": "27", "COCOR": "23", "COCUN": "25",
    "COGUA": "94", "COGUV": "95", "COHUI": "41", "COLAG": "44",
    "COMAG": "47", "COMET": "50", "CONAR": "52", "CONSA": "54",
    "COPUT": "86", "COQUI": "63", "CORIS": "66", "COSAN": "68",
    "COSAP": "88", "COSUC": "70", "COTOL": "73", "COVAC": "76",
    "COARA": "81", "COCAS": "85", "COAMA": "91", "COVID": "99",
    "COVAU": "97",
}

NUMBER = re.compile(r"-?\d*\.?\d+(?:[eE][-+]?\d+)?")
TOKEN = re.compile(r"[MmLlZz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?")


def parse_path(d):
    """Devuelve una lista de anillos [[x, y], ...] en coordenadas absolutas.

    Soporta M, m, L, l, Z, z (los únicos comandos que usa este SVG).
    Falla con error claro si aparece otro comando.
    """
    unknown = set(re.findall(r"[A-Za-z]", d)) - set("MmLlZz")
    if unknown:
        raise ValueError(f"Comandos de path no soportados: {sorted(unknown)}")

    rings, ring = [], []
    x = y = 0.0
    start = (0.0, 0.0)
    cmd = None
    nums = []

    def flush_pairs():
        nonlocal x, y, ring, start, cmd, nums
        while len(nums) >= 2:
            dx, dy = nums[0], nums[1]
            nums = nums[2:]
            if cmd in ("m", "l"):
                x, y = x + dx, y + dy
            else:
                x, y = dx, dy
            if cmd in ("M", "m") and not ring:
                start = (x, y)
            ring.append([x, y])
            # Tras el primer par, M/m continúa como L/l.
            if cmd == "M":
                cmd = "L"
            elif cmd == "m":
                cmd = "l"

    for tok in TOKEN.findall(d):
        if tok in "MmLlZz" and len(tok) == 1 and not NUMBER.fullmatch(tok):
            flush_pairs()
            if tok in "Zz":
                if ring:
                    rings.append(ring)
                    x, y = start
                    ring = []
                cmd = None
            else:
                if tok in "Mm" and ring:
                    rings.append(ring)
                    ring = []
                cmd = tok
        else:
            nums.append(float(tok))
    flush_pairs()
    if ring:
        rings.append(ring)
    return rings


def main(src, dst):
    svg = open(src, encoding="utf-8").read()
    # Solo el grupo "features"; "points" y "label_points" no son geometría.
    features = svg.split('id="points"')[0]

    departments = []
    for match in re.finditer(r"<path(.*?)>", features, re.S):
        attrs = dict(re.findall(r'([\w-]+)="([^"]*)"', match.group(1)))
        if "d" not in attrs:
            continue
        svg_id = attrs["id"]
        if svg_id not in DANE_CODES:
            raise SystemExit(f"ID sin código DANE: {svg_id}")
        rings = parse_path(attrs["d"])
        departments.append(
            {
                "code": DANE_CODES[svg_id],
                "svgId": svg_id,
                "name": attrs["name"],
                "rings": [[[round(px, 2), round(py, 2)] for px, py in r] for r in rings],
            }
        )

    departments.sort(key=lambda dep: dep["code"])
    codes = [dep["code"] for dep in departments]
    assert len(departments) == 33, f"Se esperaban 33 territorios, hay {len(departments)}"
    assert len(set(codes)) == 33, "Códigos DANE duplicados"
    assert all(dep["rings"] for dep in departments), "Hay departamentos sin geometría"

    xs = [p[0] for dep in departments for r in dep["rings"] for p in r]
    ys = [p[1] for dep in departments for r in dep["rings"] for p in r]
    data = {
        "source": "Simplemaps.com (co.svg) - https://simplemaps.com/resources/svg-license",
        "bounds": {
            "minX": min(xs), "minY": min(ys),
            "maxX": max(xs), "maxY": max(ys),
        },
        "departments": departments,
    }
    with open(dst, "w", encoding="utf-8") as out:
        json.dump(data, out, ensure_ascii=False, separators=(",", ":"))

    print(f"OK: {len(departments)} territorios, {len(xs)} vértices -> {dst}")
    print(f"Límites: {data['bounds']}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2])
