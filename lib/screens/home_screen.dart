import 'package:flutter/material.dart';

import '../widgets/app_bottom_navigation_bar.dart';

import '../api_service.dart';
import 'loans_screen.dart';
import 'profile_screen.dart';
import 'reservations_screen.dart';
import 'search_screen.dart';
import '../widgets/swipe_tab_body.dart';
import '../widgets/bibliotrack_title.dart';
import 'notifications_screen.dart';
import 'resource_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _currentNavIndex = 0;
  static const _blue = Color(0xFF09144D);
  static const _yellow = Color(0xFFFFD500);
  static const _background = Color(0xFFF7F5EF);
  List<dynamic> _resources = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiService.availabilityVersion.addListener(_onAvailabilityChanged);
    _loadResources();
  }

  @override
  void dispose() {
    ApiService.availabilityVersion.removeListener(_onAvailabilityChanged);
    super.dispose();
  }

  void _onAvailabilityChanged() => _loadResources();

  Future<void> _loadResources() async {
    try {
      final resources = await ApiService.getRecursos(tipo: 'Libros');
      if (mounted) setState(() => _resources = resources);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ApiService.currentUser?['nombre']?.toString() ?? 'Usuario';
    final isAdmin = const [
      'admin',
      'administrador',
    ].contains(ApiService.currentUser?['rol']?.toString().toLowerCase());
    return Scaffold(
      backgroundColor: _background,
      body: SwipeTabBody(
        index: _currentNavIndex,
        enabled: !widget.embedded,
        destinations: const [
          HomeScreen(),
          SearchScreen(),
          ReservationsScreen(),
          LoansScreen(),
          ProfileScreen(),
        ],
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const BiblioTrackTitle(fontSize: 28, color: _blue),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Notificaciones',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          ),
                          icon: Icon(
                            Icons.notifications_none_rounded,
                            color: _blue,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isAdmin)
                              const Text(
                                'Bienvenido personal administrativo',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (!isAdmin) ...[
                              const Text(
                                '¡Bienvenid@,',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$name!',
                                style: const TextStyle(
                                  color: _yellow,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              isAdmin
                                  ? 'Gestiona recursos, usuarios y préstamos de la biblioteca.'
                                  : 'Explora el acervo bibliográfico y gestiona tus préstamos.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.local_library_rounded,
                        color: _yellow,
                        size: 42,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Libros disponibles en el catálogo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _navigate(1),
                      child: Text(
                        'Ver buscador',
                        style: TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: CircularProgressIndicator(color: _blue),
                    ),
                  )
                else if (_error != null)
                  _emptyMessage(
                    _error!,
                    icon: Icons.cloud_off_outlined,
                    action: TextButton(
                      onPressed: _loadResources,
                      child: const Text('Reintentar'),
                    ),
                  )
                else if (_resources.isEmpty)
                  _emptyMessage(
                    'Todavía no hay libros registrados en el catálogo.',
                    icon: Icons.menu_book_outlined,
                  )
                else
                  ..._resources
                      .take(10)
                      .map(
                        (item) => _resourceCard(item as Map<String, dynamic>),
                      ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.embedded
          ? null
          : AppBottomNavigationBar(
              currentIndex: _currentNavIndex,
              onTap: _navigate,
            ),
    );
  }

  Widget _resourceCard(Map<String, dynamic> resource) {
    final title = resource['nombre']?.toString() ?? 'Recurso sin título';
    final author = resource['autor']?.toString();
    final category = resource['categoria']?.toString();
    final available = resource['disponible'] == true;
    final status =
        resource['estadoDisponibilidad']?.toString() ??
        (available ? 'Disponible' : 'En préstamo');
    final statusColor = status == 'Disponible'
        ? Colors.green
        : status == 'Reservado'
        ? Colors.orange
        : Colors.red;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResourceDetailScreen(resource: resource),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined, color: _blue, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (author != null && author.isNotEmpty)
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  if (category != null && category.isNotEmpty)
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status == 'Disponible'
                      ? Icons.check_circle_outline
                      : status == 'Reservado'
                      ? Icons.bookmark_added_outlined
                      : Icons.assignment_turned_in_outlined,
                  color: statusColor,
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyMessage(
    String message, {
    required IconData icon,
    Widget? action,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(icon, color: _blue, size: 38),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        ?action,
      ],
    ),
  );

  void _navigate(int index) {
    navigateToAppTab(context, _currentNavIndex, index, const [
      HomeScreen(),
      SearchScreen(),
      ReservationsScreen(),
      LoansScreen(),
      ProfileScreen(),
    ]);
  }
}
