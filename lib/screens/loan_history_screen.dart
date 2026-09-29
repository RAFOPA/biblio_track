import 'package:flutter/material.dart';

import '../api_service.dart';

class LoanHistoryScreen extends StatefulWidget {
  const LoanHistoryScreen({super.key});
  @override
  State<LoanHistoryScreen> createState() => _LoanHistoryScreenState();
}

class _LoanHistoryScreenState extends State<LoanHistoryScreen> {
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
      final items = await ApiService.getMisPrestamos();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F5EF),
    appBar: AppBar(
      title: const Text('Historial de préstamos'),
      backgroundColor: const Color(0xFFF7F5EF),
      foregroundColor: const Color(0xFF09144D),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : _items.isEmpty
        ? const Center(child: Text('Todavía no tienes préstamos registrados.'))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index] as Map<String, dynamic>;
                final resource = item['recursoId'] is Map<String, dynamic>
                    ? item['recursoId'] as Map<String, dynamic>
                    : <String, dynamic>{};
                final due = DateTime.tryParse(
                  item['fechaDevolucionEstimada']?.toString() ?? '',
                )?.toLocal();
                final dueLabel = due == null
                    ? ''
                    : ' · Devolución: ${MaterialLocalizations.of(context).formatMediumDate(due)}';
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(
                      Icons.assignment_outlined,
                      color: Color(0xFF09144D),
                    ),
                    title: Text(resource['nombre']?.toString() ?? 'Recurso'),
                    subtitle: Text(
                      '${item['estado'] ?? 'Estado desconocido'}$dueLabel',
                    ),
                    trailing: Text(
                      item['plazoDias'] == null ? '' : '${item['plazoDias']} d',
                    ),
                  ),
                );
              },
            ),
          ),
  );
}
