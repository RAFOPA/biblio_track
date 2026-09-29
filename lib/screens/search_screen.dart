import 'package:flutter/material.dart';

import '../widgets/app_bottom_navigation_bar.dart';

import '../api_service.dart';
import 'home_screen.dart';
import 'loans_screen.dart';
import 'profile_screen.dart';
import 'reservations_screen.dart';
import 'resource_detail_screen.dart';
import 'notifications_screen.dart';
import '../widgets/swipe_tab_body.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.usuario});

  final Map<String, dynamic>? usuario;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final int _currentNavIndex = 1;
  final _searchController = TextEditingController();
  String _selectedCategory = 'Todos';
  List<dynamic> _resources = [];
  bool _isLoading = true;
  String? _error;

  static const _blue = Color(0xFF09144D);
  static const _yellow = Color(0xFFFFD500);
  static const _background = Color(0xFFF7F5EF);

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resources = await ApiService.getRecursos(
        query: _searchController.text,
        tipo: _selectedCategory,
      );
      if (mounted) setState(() => _resources = resources);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SwipeTabBody(
        index: _currentNavIndex,
        destinations: const [
          HomeScreen(),
          SearchScreen(),
          ReservationsScreen(),
          LoansScreen(),
          ProfileScreen(),
        ],
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: 'Notificaciones',
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: _blue,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _loadResources(),
                    decoration: InputDecoration(
                      hintText: '¿Qué deseas buscar?',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade600,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Buscar',
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: _blue,
                        ),
                        onPressed: _loadResources,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Todos', 'Libros', 'Computadoras'].map((
                      category,
                    ) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = category);
                            _loadResources();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? _blue : Colors.grey.shade700,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Resultados (${_resources.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildResults()),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _navigate,
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading)
      return const Center(child: CircularProgressIndicator(color: _blue));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: _blue, size: 42),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadResources,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, color: _blue, size: 48),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isEmpty
                  ? 'Todavía no hay recursos registrados.'
                  : 'No encontramos recursos con esa búsqueda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _resources.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _buildResultCard(_resources[index] as Map<String, dynamic>),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> resource) {
    final title = resource['nombre']?.toString() ?? 'Recurso sin título';
    final type = resource['tipo']?.toString() ?? 'Recurso';
    final author = resource['autor']?.toString();
    final category = resource['categoria']?.toString();
    final location = resource['ubicacion']?.toString();
    final inventoryCode = resource['codigoInventario']?.toString();
    final available = resource['disponible'] == true;
    final details = [
      if (author != null && author.isNotEmpty) author,
      if (category != null && category.isNotEmpty) category,
      if (location != null && location.isNotEmpty) location,
      if (inventoryCode != null && inventoryCode.isNotEmpty)
        'Código: $inventoryCode',
    ].join(' • ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResourceDetailScreen(resource: resource),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _yellow,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                details.isEmpty ? type : '$type • $details',
                style: TextStyle(fontSize: 13, color: _yellow.withAlpha(210)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      available ? 'Disponible' : 'No disponible',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: available ? _blue : Colors.red.shade700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _yellow),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(int index) {
    openAppTab(context, _currentNavIndex, index, const [
      HomeScreen(),
      SearchScreen(),
      ReservationsScreen(),
      LoansScreen(),
      ProfileScreen(),
    ]);
  }
}
