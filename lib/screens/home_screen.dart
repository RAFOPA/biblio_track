import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'reservations_screen.dart';
import 'loans_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Índice 0 corresponde a Inicio en el BottomNavigationBar
  final int _currentNavIndex = 0;

  final Color unanBlue = const Color(0xFF09144D);
  final Color unanYellow = const Color(0xFFFFD500);
  final Color backgroundColor = const Color(0xFFF7F5EF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
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
              const SizedBox(height: 20),

              // 2. Tarjeta de Bienvenida Personalizada
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: unanBlue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: unanBlue.withAlpha(40),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '¡Bienvenido de nuevo,',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fernando José!',
                            style: TextStyle(
                              color: unanYellow,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Times New Roman',
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Explora el acervo bibliográfico y gestiona tus préstamos al instante.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.local_library_rounded, color: unanYellow, size: 36),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. Título de Sección: Libros de interés
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Libros de interés',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _navigateToSearch(context),
                    child: Text(
                      'Ver buscador',
                      style: TextStyle(color: unanBlue, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 4. Categorías y Carruseles de Libros (Muestra limitada para incentivar la búsqueda)
              _buildCategorySection(
                categoryTitle: 'Matemáticas y Cálculo',
                books: [
                  {'title': 'Cálculo Multivariable', 'author': 'James Stewart'},
                  {'title': 'Álgebra Lineal', 'author': 'Stanley Grossman'},
                ],
              ),
              const SizedBox(height: 20),

              _buildCategorySection(
                categoryTitle: 'Ingeniería de Software y Sistemas',
                books: [
                  {'title': 'Clean Code', 'author': 'Robert C. Martin'},
                  {'title': 'Arquitectura de Software', 'author': 'Mark Richards'},
                ],
              ),
              const SizedBox(height: 20),

              _buildCategorySection(
                categoryTitle: 'Bases de Datos',
                books: [
                  {'title': 'MongoDB en Acción', 'author': 'Kyle Banker'},
                  {'title': 'Sistemas de Base de Datos', 'author': 'Elmasri Navathe'},
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),

      // 5. Barra de Navegación Inferior Conectada
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        selectedItemColor: unanBlue,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == _currentNavIndex) return;

          Widget? nextScreen;
          switch (index) {
            case 1:
              nextScreen = const SearchScreen();
              break;
            case 2:
              nextScreen = const ReservationsScreen();
              break;
            case 3:
              nextScreen = const LoansScreen();
              break;
            case 4:
              nextScreen = const ProfileScreen();
              break;
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

  // Método auxiliar para crear cada sección de categoría con desplazamiento horizontal
  Widget _buildCategorySection({required String categoryTitle, required List<Map<String, String>> books}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          categoryTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: unanBlue,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.book_outlined, color: unanBlue, size: 22),
                    const SizedBox(height: 8),
                    Text(
                      book['title']!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book['author']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToSearch(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a1, a2) => const SearchScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}