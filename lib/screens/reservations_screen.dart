import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'loans_screen.dart';
import 'profile_screen.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  // Índice 2 corresponde a Reservaciones
  final int _currentNavIndex = 2; 

  final Color unanBlue = const Color(0xFF09144D);
  final Color backgroundColor = const Color(0xFFF7F5EF);
  final Color timerRed = const Color(0xFFB3261E);

  @override
  Widget build(BuildContext context) {
    // DefaultTabController maneja automáticamente la lógica de las 2 pestañas
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Encabezado
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BiblioTrack',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: unanBlue,
                        fontFamily: 'Times New Roman',
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6)
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.notifications_none_rounded, color: unanBlue),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Título de página
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Reservaciones',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: unanBlue,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Pestañas (Tabs)
              TabBar(
                labelColor: unanBlue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: unanBlue,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                tabs: const [
                  Tab(text: 'Libros'),
                  Tab(text: 'Computadoras'),
                ],
              ),

              // 4. Contenido de las pestañas
              Expanded(
                child: TabBarView(
                  children: [
                    // Pestaña 1: Libros
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildReservationCard(
                          icon: Icons.book_outlined,
                          title: 'Libro1 Reservado',
                          timeText: 'Faltan 3 horas y 23 minutos',
                        ),
                      ],
                    ),
                    // Pestaña 2: Computadoras
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildReservationCard(
                          icon: Icons.computer_outlined,
                          title: 'PC 1 Reservada',
                          timeText: 'Faltan 30 minutos',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 5. Nueva Barra de Navegación (5 botones) con lógica funcional
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          selectedItemColor: unanBlue,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed, // Necesario al tener más de 3 botones
          onTap: _onNavTapped,
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

  // Método para manejar la navegación real
  void _onNavTapped(int index) {
    if (index == _currentNavIndex) return; // No hacer nada si tocas la misma pestaña

    Widget? nextScreen;
    switch (index) {
      case 0:
        nextScreen = const HomeScreen();
        break;
      case 1:
        nextScreen = const SearchScreen();
        break;
      case 3: 
        nextScreen = const LoansScreen();
        break;
      case 4:
        nextScreen = const ProfileScreen();
        break;
      default:
        return; 
    }

    if (nextScreen != null) {
      // Usamos pushReplacement para no acumular pantallas infinitamente en la memoria
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => nextScreen!,
          transitionDuration: Duration.zero, // Transición instantánea sin animaciones raras
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  // Helper para construir la tarjeta idéntica al mockup
  Widget _buildReservationCard({required IconData icon, required String title, required String timeText}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: unanBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Times New Roman',
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, color: timerRed, size: 18),
                const SizedBox(width: 8),
                Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}