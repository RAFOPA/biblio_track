import 'package:flutter/material.dart';

import '../api_service.dart';
import 'resource_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiService.getFavoritos();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(String id) async {
    try {
      await ApiService.quitarFavorito(id);
      if (mounted)
        setState(() => _items.removeWhere((x) => x['_id']?.toString() == id));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F5EF),
    appBar: AppBar(
      title: const Text('Mis favoritos'),
      backgroundColor: const Color(0xFFF7F5EF),
      foregroundColor: const Color(0xFF09144D),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : _items.isEmpty
        ? const Center(child: Text('Todavía no guardas libros favoritos.'))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index] as Map<String, dynamic>;
                final id = item['_id']?.toString() ?? '';
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(
                      Icons.menu_book_outlined,
                      color: Color(0xFF09144D),
                    ),
                    title: Text(item['nombre']?.toString() ?? 'Libro'),
                    subtitle: Text(
                      item['autor']?.toString() ?? 'Autor no especificado',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.redAccent),
                      onPressed: () => _remove(id),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResourceDetailScreen(resource: item),
                      ),
                    ).then((_) => _load()),
                  ),
                );
              },
            ),
          ),
  );
}
