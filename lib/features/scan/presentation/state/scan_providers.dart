import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/scan/domain/scan_mode.dart';

/// Controlador del modo de escaneo seleccionado (Precio vs Contrato).
class ScanModeNotifier extends Notifier<ScanMode> {
  @override
  ScanMode build() => ScanMode.price;

  void selectMode(ScanMode mode) {
    state = mode;
  }

  void reset() {
    state = ScanMode.price;
  }
}

/// Proveedor del modo de escaneo activo en la pestaña Escanear.
final scanModeProvider = NotifierProvider<ScanModeNotifier, ScanMode>(
  ScanModeNotifier.new,
);
