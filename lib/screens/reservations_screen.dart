import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import 'home_screen.dart';
import 'loans_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final int _currentNavIndex = 2;
  static const _blue = Color(0xFF09144D);
  static const _background = Color(0xFFF7F5EF);
  List<dynamic> _reservations = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadReservations();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadReservations());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReservations() async {
    try {
      final reservations = await ApiService.getMisReservas();
      if (mounted) setState(() {
        _reservations = reservations;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = _reservations.where((item) => !_isComputer(item)).toList();
    final computers = _reservations.where(_isComputer).toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('BiblioTrack', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _blue, fontFamily: 'Times New Roman')),
                    IconButton(onPressed: _loadReservations, icon: const Icon(Icons.refresh, color: _blue), tooltip: 'Actualizar reservas'),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Reservaciones', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _blue)),
              ),
              const SizedBox(height: 14),
              const TabBar(
                labelColor: _blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _blue,
                tabs: [Tab(text: 'Libros'), Tab(text: 'Computadoras')],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))), TextButton(onPressed: _loadReservations, child: const Text('Reintentar'))]),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _blue))
                    : TabBarView(
                        children: [
                          _reservationList(books, 'No tienes reservas de libros.'),
                          _reservationList(computers, 'No tienes reservas de computadoras.'),
                        ],
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          selectedItemColor: _blue,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          onTap: _navigate,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.search_outlined), activeIcon: Icon(Icons.search), label: 'Buscar'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Reservas'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Préstamos'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }

  bool _isComputer(dynamic reservation) {
    final resource = (reservation as Map<String, dynamic>)['recursoId'];
    return resource is Map<String, dynamic> && (resource['tipo']?.toString().toLowerCase().contains('comput') ?? false);
  }

  Widget _reservationList(List<dynamic> reservations, String emptyMessage) {
    if (_error != null && reservations.isEmpty) return Center(child: Text('No se pudieron cargar las reservas.', style: TextStyle(color: Colors.grey.shade700)));
    if (reservations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.event_busy_outlined, color: _blue.withAlpha(150), size: 44), const SizedBox(height: 12), Text(emptyMessage, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700))],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: reservations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _reservationCard(reservations[index] as Map<String, dynamic>),
      ),
    );
  }

  Widget _reservationCard(Map<String, dynamic> reservation) {
    final resource = reservation['recursoId'] as Map<String, dynamic>? ?? {};
    final expiresAt = DateTime.tryParse(reservation['fechaExpiracion']?.toString() ?? '')?.toLocal();
    final remaining = expiresAt == null ? 'Tiempo de reserva no disponible' : _remaining(expiresAt.difference(DateTime.now()));
    final name = resource['nombre']?.toString() ?? 'Recurso';
    final isComputer = _isComputer(reservation);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isComputer ? Icons.computer_outlined : Icons.book_outlined, color: Colors.white, size: 22),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Times New Roman')),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: Color(0xFFB3261E), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Tiempo restante: $remaining', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Reserva de ${reservation['duracionMinutos'] ?? '—'} minutos', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  String _remaining(Duration duration) {
    if (duration.isNegative || duration.inSeconds == 0) return 'Venciendo';
    if (duration.inMinutes < 1) return 'menos de 1 minuto';
    if (duration.inMinutes < 60) return '${duration.inMinutes} min';
    final minutes = duration.inMinutes.remainder(60);
    return '${duration.inHours} h ${minutes.toString().padLeft(2, '0')} min';
  }

  void _navigate(int index) {
    if (index == _currentNavIndex) return;
    final Widget? screen = switch (index) {
      0 => const HomeScreen(),
      1 => const SearchScreen(),
      3 => const LoansScreen(),
      4 => const ProfileScreen(),
      _ => null,
    };
    if (screen == null) return;
    Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => screen, transitionDuration: Duration.zero, reverseTransitionDuration: Duration.zero));
  }
}
