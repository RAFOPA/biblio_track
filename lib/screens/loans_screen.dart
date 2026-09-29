import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/app_bottom_navigation_bar.dart';

import 'package:qr_flutter/qr_flutter.dart';

import '../api_service.dart';
import 'admin_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'reservations_screen.dart';
import 'search_screen.dart';
import '../widgets/swipe_tab_body.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  static const _blue = Color(0xFF09144D);
  static const _yellow = Color(0xFFFFD500);
  static const _background = Color(0xFFF7F5EF);
  final _nameController = TextEditingController();
  final _carnetController = TextEditingController();
  final _careerController = TextEditingController();
  final _resourceController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  List<dynamic> _reservations = [];
  List<dynamic> _loans = [];
  String? _selectedReservationId;
  Map<String, dynamic>? _pendingLoan;
  String? _qrValue;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (ApiService.currentUser?['rol']?.toString().toLowerCase() == 'admin' ||
        ApiService.currentUser?['rol']?.toString().toLowerCase() ==
            'administrador') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminScreen()),
          );
      });
    }
    _loadData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _nameController.dispose();
    _carnetController.dispose();
    _careerController.dispose();
    _resourceController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getMisReservas(),
        ApiService.getMisPrestamos(),
      ]);
      if (!mounted) return;
      setState(() {
        _reservations = results[0];
        _loans = results[1];
        _error = null;
        _loading = false;
        if (_selectedReservationId != null &&
            !_reservations.any((item) => _id(item) == _selectedReservationId)) {
          _selectedReservationId = null;
          _updateForm(null);
        }
        if (_selectedReservationId != null)
          _updateForm(_reservationById(_selectedReservationId!));
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  String? _id(dynamic item) =>
      item is Map<String, dynamic> ? item['_id']?.toString() : null;

  Map<String, dynamic>? _reservationById(String id) {
    for (final item in _reservations) {
      if (_id(item) == id && item is Map<String, dynamic>) return item;
    }
    return null;
  }

  Map<String, dynamic>? _loanForReservation(String id) {
    for (final item in _loans) {
      if (item is Map<String, dynamic> &&
          item['reservaId'] is Map<String, dynamic>) {
        if ((item['reservaId'] as Map<String, dynamic>)['_id']?.toString() ==
            id)
          return item;
      }
    }
    return null;
  }

  void _updateForm(Map<String, dynamic>? reservation) {
    if (reservation == null) {
      _nameController.clear();
      _carnetController.clear();
      _careerController.clear();
      _resourceController.clear();
      _dateController.clear();
      _timeController.clear();
      _pendingLoan = null;
      _qrValue = null;
      return;
    }
    final resource = reservation['recursoId'] as Map<String, dynamic>? ?? {};
    final user = ApiService.currentUser ?? {};
    _nameController.text = user['nombre']?.toString() ?? '';
    _carnetController.text = user['carnet']?.toString() ?? '';
    _careerController.text = user['carrera']?.toString() ?? '';
    _resourceController.text = resource['nombre']?.toString() ?? '';
    _dateController.text = '';
    _timeController.text = '';
    _pendingLoan = _loanForReservation(_id(reservation)!);
    final token = _pendingLoan?['qrToken']?.toString();
    _qrValue = token == null ? null : 'BIBLIOTRACK:$token';
    _syncActiveLoanFields();
  }

  void _syncActiveLoanFields() {
    for (final item in _loans) {
      if (item is! Map<String, dynamic> || item['estado'] != 'Activo') continue;
      final reserva = item['reservaId'];
      if (reserva is Map<String, dynamic> &&
          reserva['_id']?.toString() == _selectedReservationId) {
        final due = DateTime.tryParse(
          item['fechaDevolucionEstimada']?.toString() ?? '',
        )?.toLocal();
        _dateController.text = due == null
            ? ''
            : MaterialLocalizations.of(context).formatMediumDate(due);
        _timeController.text = '${item['plazoDias'] ?? ''} días';
      }
    }
  }

  Future<void> _prepareLoan() async {
    if (_selectedReservationId == null) {
      setState(() => _error = 'Selecciona una reservación activa primero.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ApiService.crearPrestamoPendiente(
        _selectedReservationId!,
      );
      if (!mounted) return;
      setState(() {
        _pendingLoan = result['prestamo'] as Map<String, dynamic>;
        _qrValue = result['qr']?.toString();
      });
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showQr() {
    final value = _qrValue;
    if (value == null || value.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('QR de préstamo', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Presenta este código al personal de biblioteca.'),
            const SizedBox(height: 16),
            QrImageView(
              data: value,
              version: QrVersions.auto,
              size: 220,
              foregroundColor: _blue,
            ),
            const SizedBox(height: 8),
            const Text(
              'El préstamo empezará cuando el personal lo confirme.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SwipeTabBody(
        index: 3,
        destinations: const [
          HomeScreen(),
          SearchScreen(),
          ReservationsScreen(),
          LoansScreen(),
          ProfileScreen(),
        ],
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BiblioTrack',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _blue,
                      ),
                    ),
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh, color: _blue),
                      tooltip: 'Actualizar',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Registrar préstamo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _blue,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _blue.withAlpha(50),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seleccionar reservación',
                        style: TextStyle(
                          color: _yellow,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_loading)
                        const LinearProgressIndicator(color: _yellow)
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedReservationId,
                          isExpanded: true,
                          dropdownColor: _blue,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withAlpha(20),
                            hintText: 'Elige una reserva activa',
                            hintStyle: const TextStyle(color: Colors.white60),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _reservations.map((item) {
                            final reservation = item as Map<String, dynamic>;
                            final resource =
                                reservation['recursoId']
                                    as Map<String, dynamic>? ??
                                {};
                            return DropdownMenuItem(
                              value: _id(reservation),
                              child: Text(
                                '${resource['tipo'] ?? 'Recurso'}: ${resource['nombre'] ?? 'Sin título'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() {
                            _selectedReservationId = value;
                            _error = null;
                            _updateForm(
                              value == null ? null : _reservationById(value),
                            );
                          }),
                        ),
                      const SizedBox(height: 16),
                      _field('Nombre del estudiante', _nameController),
                      const SizedBox(height: 12),
                      _field('Número de carnet', _carnetController),
                      const SizedBox(height: 12),
                      _field('Carrera', _careerController),
                      const SizedBox(height: 12),
                      _field(
                        'Recurso o computadora',
                        _resourceController,
                        icon: Icons.menu_book_outlined,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _field('Devolución', _dateController),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field(
                              'Plazo impuesto por personal',
                              _timeController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'El plazo se asigna en biblioteca y aparecerá aquí al confirmar el préstamo.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.amberAccent),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _yellow,
                            foregroundColor: _blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _saving || _selectedReservationId == null
                              ? null
                              : (_pendingLoan == null ? _prepareLoan : _showQr),
                          icon: _saving
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _pendingLoan == null
                                      ? Icons.assignment_outlined
                                      : Icons.qr_code_2_rounded,
                                ),
                          label: Text(
                            _saving
                                ? 'Preparando...'
                                : _pendingLoan == null
                                ? 'Préstamo de recurso'
                                : 'Ver código QR de acceso',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Mis préstamos activos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _blue,
                  ),
                ),
                const SizedBox(height: 10),
                ..._loans
                    .where(
                      (item) =>
                          item is Map<String, dynamic> &&
                          item['estado'] == 'Activo',
                    )
                    .map(
                      (item) => _activeLoanCard(item as Map<String, dynamic>),
                    ),
                if (!_loading &&
                    !_loans.any(
                      (item) =>
                          item is Map<String, dynamic> &&
                          item['estado'] == 'Activo',
                    ))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No tienes préstamos activos.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: 3,
        onTap: _navigate,
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    IconData? icon,
  }) => Column(
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
      TextField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withAlpha(20),
          prefixIcon: icon == null
              ? null
              : Icon(icon, color: _yellow, size: 18),
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

  Widget _activeLoanCard(Map<String, dynamic> loan) {
    final resource = loan['recursoId'] as Map<String, dynamic>? ?? {};
    final due = DateTime.tryParse(
      loan['fechaDevolucionEstimada']?.toString() ?? '',
    )?.toLocal();
    final dueText = due == null
        ? 'Sin fecha asignada'
        : MaterialLocalizations.of(context).formatMediumDate(due);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined, color: _yellow),
              SizedBox(width: 8),
              Text(
                'Préstamo confirmado',
                style: TextStyle(color: _yellow, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            resource['nombre']?.toString() ?? 'Recurso',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _loanResultField(
            'Tiempo de préstamo',
            '${loan['plazoDias'] ?? '—'} días',
          ),
          const SizedBox(height: 8),
          _loanResultField('Fecha de devolución', dueText),
        ],
      ),
    );
  }

  Widget _loanResultField(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  void _navigate(int index) {
    openAppTab(context, 3, index, const [
      HomeScreen(),
      SearchScreen(),
      ReservationsScreen(),
      LoansScreen(),
      ProfileScreen(),
    ]);
  }
}
