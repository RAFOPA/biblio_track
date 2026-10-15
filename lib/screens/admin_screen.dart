import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api_service.dart';
import 'admin_management_screen.dart';
import 'notifications_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _blue = Color(0xFF09144D);
  static const _yellow = Color(0xFFFFD500);
  late final MobileScannerController _scannerController;
  String? _lastScannedValue;
  Map<String, dynamic>? _loan;
  bool _lookingUp = false;
  bool _confirming = false;
  bool _retryingCamera = false;
  String _loanTermUnit = 'dias';
  int _loanTermValue = 7;
  String? _error;
  String? _message;

  @override
  void dispose() {
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(autoStart: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startCamera());
    });
  }

  Future<void> _startCamera() async {
    try {
      await _scannerController.start();
    } on MobileScannerException catch (_) {
      // MobileScanner reflects permission and camera errors in its errorBuilder.
    }
  }

  Future<void> _openCameraSettings() async {
    try {
      await const MethodChannel('biblio_track/camera')
          .invokeMethod<void>('openAppSettings');
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudieron abrir los ajustes: ${error.message ?? ''}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _retryCameraPermission() async {
    if (_retryingCamera) return;
    setState(() => _retryingCamera = true);
    try {
      if (_scannerController.value.isRunning) {
        await _scannerController.stop();
      }
      await _startCamera();
    } on MobileScannerException catch (error) {
      if (mounted) setState(() => _error = error.errorCode.message);
    } finally {
      if (mounted) setState(() => _retryingCamera = false);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value == _lastScannedValue) return;
    _lastScannedValue = value;
    await _lookup(value);
  }

  Future<void> _lookup(String rawValue) async {
    if (_lookingUp) return;
    var value = rawValue.trim();
    if (value.startsWith('BIBLIOTRACK:'))
      value = value.substring('BIBLIOTRACK:'.length);
    if (value.isEmpty) return;
    setState(() {
      _lookingUp = true;
      _loan = null;
      _error = null;
      _message = null;
    });
    try {
      final loan = await ApiService.getPrestamoPorQr(value);
      if (!mounted) return;
      setState(() {
        _loan = loan;
      });
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _confirmLoan() async {
    final loanId = _loan?['_id']?.toString();
    if (loanId == null) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      final loan = await ApiService.confirmarPrestamo(
        prestamoId: loanId,
        plazoUnidad: _loanTermUnit,
        plazoValor: _loanTermValue,
      );
      if (!mounted) return;
      setState(() {
        _loan = null;
        _message = 'Préstamo confirmado por ${_loanTermLabel(loan)}.';
      });
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text('Panel de biblioteca'),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Gestionar recursos, usuarios y reportes',
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminManagementScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted)
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (_) => false);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: _blue,
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Bienvenido personal administrativo',
                style: TextStyle(
                  color: _yellow,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Préstamos pendientes',
            style: TextStyle(
              fontSize: 24,
              color: _blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Escanea el código QR del estudiante para revisar y confirmar el préstamo.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 18),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(
                Icons.admin_panel_settings_outlined,
                color: _blue,
              ),
              title: const Text('Herramientas administrativas'),
              subtitle: const Text(
                'Gestionar recursos y usuarios, consultar reportes',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminManagementScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(
                Icons.assignment_return_outlined,
                color: _blue,
              ),
              title: const Text('Registrar devolución'),
              subtitle: const Text(
                'Buscar el préstamo por estudiante, carnet o recurso',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminManagementScreen(initialTab: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 280,
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
                errorBuilder: (context, error) {
                  final permissionDenied =
                      error.errorCode ==
                      MobileScannerErrorCode.permissionDenied;
                  return Material(
                    color: Colors.black,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              permissionDenied
                                  ? Icons.no_photography_outlined
                                  : Icons.videocam_off_outlined,
                              color: Colors.white70,
                              size: 38,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _retryingCamera
                                  ? 'Solicitando acceso a la cámara…'
                                  : permissionDenied && kIsWeb
                                  ? 'El navegador bloqueó el permiso. Habilita Cámara en los permisos de este sitio y luego pulsa Reintentar.'
                                  : permissionDenied
                                  ? 'No hay acceso a la cámara. Pulsa para volver a solicitar el permiso.'
                                  : 'No se pudo iniciar la cámara. Pulsa para reintentarlo.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _retryingCamera
                                  ? null
                                  : _retryCameraPermission,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                _retryingCamera
                                    ? 'Solicitando…'
                                    : 'Reintentar cámara',
                              ),
                            ),
                            if (permissionDenied &&
                                !kIsWeb &&
                                defaultTargetPlatform ==
                                    TargetPlatform.android) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _openCameraSettings,
                                icon: const Icon(Icons.settings_outlined),
                                label: const Text('Abrir ajustes de la app'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_lookingUp)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(color: _blue),
            ),
          if (_message != null) ...[
            const SizedBox(height: 14),
            _notice(_message!, Colors.green.shade800),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            _notice(_error!, Colors.red.shade800),
          ],
          if (_loan != null) ...[const SizedBox(height: 18), _loanForm(_loan!)],
        ],
      ),
    );
  }

  Widget _loanForm(Map<String, dynamic> loan) {
    final user = loan['usuarioId'] as Map<String, dynamic>? ?? {};
    final resource = loan['recursoId'] as Map<String, dynamic>? ?? {};
    final reservation = loan['reservaId'] as Map<String, dynamic>? ?? {};
    final isComputer =
        resource['tipo']?.toString().toLowerCase().contains('comput') ?? false;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Validar préstamo',
            style: TextStyle(
              color: _yellow,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _readOnlyField('Nombre completo', user['nombre']?.toString() ?? ''),
          const SizedBox(height: 12),
          _readOnlyField('Número de carnet', user['carnet']?.toString() ?? ''),
          const SizedBox(height: 12),
          _readOnlyField('Carrera', user['carrera']?.toString() ?? ''),
          const SizedBox(height: 12),
          _readOnlyField('Correo', user['correo']?.toString() ?? ''),
          const SizedBox(height: 12),
          _readOnlyField(
            isComputer ? 'Computadora' : 'Recurso bibliográfico',
            resource['nombre']?.toString() ?? '',
          ),
          const SizedBox(height: 12),
          _readOnlyField('Tipo de recurso', resource['tipo']?.toString() ?? ''),
          const SizedBox(height: 12),
          _readOnlyField('Autor', resource['autor']?.toString() ?? 'No aplica'),
          const SizedBox(height: 12),
          _readOnlyField(
            'Codigo de inventario',
            resource['codigoInventario']?.toString() ?? 'No especificado',
          ),
          const SizedBox(height: 12),
          _readOnlyField(
            'Reservado hasta',
            _formatDate(reservation['fechaExpiracion']),
          ),
          const SizedBox(height: 14),
          const Text(
            'Plazo de préstamo',
            style: TextStyle(color: _yellow, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _loanTermUnit,
                  dropdownColor: _blue,
                  style: const TextStyle(color: Colors.white),
                  decoration: _termInputDecoration(),
                  items: const [
                    DropdownMenuItem(value: 'horas', child: Text('Horas')),
                    DropdownMenuItem(value: 'dias', child: Text('Días')),
                  ],
                  onChanged: (unit) {
                    if (unit == null) return;
                    setState(() {
                      _loanTermUnit = unit;
                      _loanTermValue = unit == 'horas' ? 2 : 7;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _loanTermValue,
                  dropdownColor: _blue,
                  style: const TextStyle(color: Colors.white),
                  decoration: _termInputDecoration(),
                  items:
                      (_loanTermUnit == 'horas'
                              ? const [1, 2, 3, 4, 6, 8, 12, 24]
                              : const [1, 3, 7, 14])
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                '$value ${_loanTermUnit == 'horas'
                                    ? 'h'
                                    : value == 1
                                    ? 'día'
                                    : 'días'}',
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setState(() => _loanTermValue = value ?? _loanTermValue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _readOnlyField(
            'Fecha límite de devolución',
            _formatDueDate(
              DateTime.now().add(
                _loanTermUnit == 'horas'
                    ? Duration(hours: _loanTermValue)
                    : Duration(days: _loanTermValue),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _confirming ? null : _confirmLoan,
              style: ElevatedButton.styleFrom(
                backgroundColor: _yellow,
                foregroundColor: _blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _confirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _confirming ? 'Confirmando...' : 'Confirmar préstamo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _termInputDecoration() => InputDecoration(
    filled: true,
    fillColor: Colors.white.withAlpha(20),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );

  String _loanTermLabel(Map<String, dynamic> loan) {
    final unit = loan['plazoUnidad']?.toString() ?? _loanTermUnit;
    final value = loan['plazoValor'] ?? _loanTermValue;
    final unitLabel = unit == 'horas'
        ? (value == 1 ? 'hora' : 'horas')
        : (value == 1 ? 'día' : 'días');
    return '$value $unitLabel';
  }

  String _formatDueDate(DateTime date) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(date)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  Widget _readOnlyField(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _yellow,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      TextFormField(
        initialValue: value,
        readOnly: true,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withAlpha(20),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  );

  Widget _notice(String message, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );

  String _formatDate(dynamic value) {
    final date = value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '');
    return date == null
        ? '—'
        : MaterialLocalizations.of(context).formatFullDate(date.toLocal());
  }
}
