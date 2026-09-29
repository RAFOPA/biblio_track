import 'package:flutter/material.dart';

import '../api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _blue = Color(0xFF09144D);
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
      final items = await ApiService.getNotificaciones();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ApiService.eliminarNotificacion(id);
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
      title: const Text('Notificaciones'),
      backgroundColor: const Color(0xFFF7F5EF),
      foregroundColor: _blue,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            ),
          )
        : _items.isEmpty
        ? const Center(child: Text('No tienes notificaciones.'))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index] as Map<String, dynamic>;
                final date = DateTime.tryParse(
                  item['createdAt']?.toString() ?? '',
                )?.toLocal();
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE9ECF6),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: _blue,
                      ),
                    ),
                    title: Text(
                      item['titulo']?.toString() ?? 'Notificación',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['mensaje']?.toString() ?? ''),
                        if (date != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              MaterialLocalizations.of(context)
                                  .formatMediumDate(date),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _delete(item['_id'].toString()),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),
  );
}
