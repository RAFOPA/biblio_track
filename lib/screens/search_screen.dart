import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'reservations_screen.dart';
import 'loans_screen.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Pestaña seleccionada en el BottomNavigationBar (1 = Buscar)
  final int _currentNavIndex = 1;

  // Categoría seleccionada
  String _selectedCategory = 'Libros';

  // Colores de la app y universidad
  final Color unanBlue = const Color(0xFF09144D);
  final Color unanYellow = const Color(0xFFFFD500);
  final Color backgroundColor = const Color(0xFFF7F5EF); // Fondo crema/hueso del mockup

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Barra superior: Título + Notificaciones
              Row(
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
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.notifications_none_rounded, color: unanBlue),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Campo de búsqueda
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '¿Qué deseas buscar?',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                    suffixIcon: Icon(Icons.tune_rounded, color: unanBlue), // Icono de filtros
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Botones de filtro de categorías (Libros, Computadoras...)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('Libros'),
                    const SizedBox(width: 10),
                    _buildCategoryChip('Computadoras'),
                    const SizedBox(width: 10),
                    _buildCategoryChip('Otros'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Título de sección
              const Text(
                'Resultados encontrados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // 5. Lista de Resultados
              Expanded(
                child: ListView(
                  children: [
                    if (_selectedCategory == 'Libros') ...[
                      _buildResultCard(
                        title: 'Ejemplo libro1',
                        subtitle: 'Dr. Marcus Vance',
                        status: 'Disponible',
                      ),
                      const SizedBox(height: 12),
                      _buildResultCard(
                        title: 'Cálculo Multivariable',
                        subtitle: 'James Stewart',
                        status: 'Disponible',
                      ),
                    ] else ...[
                      _buildResultCard(
                        title: 'Computadora HP #04',
                        subtitle: 'Laboratorio A - Intel i5 16GB',
                        status: 'Disponible',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // 6. Barra de navegación inferior conectada
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        selectedItemColor: unanBlue,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == _currentNavIndex) return;

          Widget? nextScreen;
          if (index == 0) {
            nextScreen = const HomeScreen();
          } else if (index == 2) {
            nextScreen = const ReservationsScreen();
          } else if (index == 3) {
            nextScreen = const LoansScreen();
          } else if (index == 4) {
            nextScreen = const ProfileScreen();
          }

          if (nextScreen != null) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, a1, a2) => nextScreen!,
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.search_outlined), activeIcon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Reservas'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Préstamos'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  // Helper para construir los Chips de Categoría
  Widget _buildCategoryChip(String label) {
    final bool isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? unanBlue : Colors.grey.shade700,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Helper para construir la tarjeta de resultado
  Widget _buildResultCard({
    required String title,
    required String subtitle,
    required String status,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: unanBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: unanYellow,
              fontFamily: 'Times New Roman',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: unanYellow.withAlpha(200),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: unanBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}