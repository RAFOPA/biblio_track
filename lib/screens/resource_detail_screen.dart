import 'package:flutter/material.dart';

import '../api_service.dart';

class ResourceDetailScreen extends StatefulWidget {
  const ResourceDetailScreen({super.key, required this.resource});

  final Map<String, dynamic> resource;

  @override
  State<ResourceDetailScreen> createState() => _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends State<ResourceDetailScreen> {
  static const _blue = Color(0xFF09144D);
  static const _yellow = Color(0xFFFFD500);
  int _duration = 30;
  bool _reserving = false;
  bool _checkingHold = true;
  bool _alreadyHeld = false;
  bool _favorite = false;
  bool _favoriteLoading = false;
  String? _error;

  String _value(String key, [String fallback = 'No especificado']) {
    final value = widget.resource[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    _loadFavorite();
    _loadActiveHold();
  }

  Future<void> _loadActiveHold() async {
    if (![
      'estudiante',
      'docente',
    ].contains(ApiService.currentUser?['rol']?.toString().toLowerCase())) {
      if (mounted) setState(() => _checkingHold = false);
      return;
    }
    try {
      final results = await Future.wait([
        ApiService.getMisReservas(),
        ApiService.getMisPrestamos(),
      ]);
      final resourceId = _value('_id', '');
      bool holds(dynamic item) {
        if (item is! Map) return false;
        final resource = item['recursoId'];
        final id = resource is Map
            ? resource['_id']?.toString()
            : resource?.toString();
        return id == resourceId;
      }

      if (mounted) {
        setState(() {
          _alreadyHeld = results.any((items) => items.any(holds));
        });
      }
    } catch (_) {
      // The API validates duplicate reservations even if this status check fails.
    } finally {
      if (mounted) setState(() => _checkingHold = false);
    }
  }

  Future<void> _loadFavorite() async {
    if (![
      'estudiante',
      'docente',
    ].contains(ApiService.currentUser?['rol']?.toString().toLowerCase()))
      return;
    try {
      final favorites = await ApiService.getFavoritos();
      if (mounted)
        setState(
          () => _favorite = favorites.any(
            (item) =>
                item is Map && item['_id']?.toString() == _value('_id', ''),
          ),
        );
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteLoading) return;
    setState(() => _favoriteLoading = true);
    try {
      if (_favorite) {
        await ApiService.quitarFavorito(_value('_id', ''));
        if (mounted) setState(() => _favorite = false);
      } else {
        await ApiService.agregarFavorito(_value('_id', ''));
        if (mounted) setState(() => _favorite = true);
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
    } finally {
      if (mounted) setState(() => _favoriteLoading = false);
    }
  }

  Future<void> _reserve() async {
    final user = ApiService.currentUser;
    if (user == null) {
      setState(() => _error = 'Inicia sesión para reservar un recurso.');
      return;
    }
    if (![
      'estudiante',
      'docente',
    ].contains(user['rol']?.toString().toLowerCase())) {
      setState(
        () => _error = 'Las reservas estan disponibles para cuentas de estudiante o docente.',
      );
      return;
    }
    setState(() {
      _reserving = true;
      _error = null;
    });
    try {
      await ApiService.reservarRecurso(
        recursoId: _value('_id', ''),
        duracionMinutos: _duration,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recurso reservado. Ya aparece en Reservas.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _reserving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.resource['disponible'] == true;
    final availability =
        widget.resource['estadoDisponibilidad']?.toString() ??
        (available ? 'Disponible' : 'En préstamo');
    final isStudent = [
      'estudiante',
      'docente',
    ].contains(ApiService.currentUser?['rol']?.toString().toLowerCase());
    final normalizedType = _value('tipo').toLowerCase();
    final isComputer =
        normalizedType.contains('comput') || normalizedType == 'equipo';
    final isBook = _value('tipo').toLowerCase().contains('libro');
    final codes = widget.resource['codigosCopias'];
    final copyCapacity = isComputer
        ? 1
        : codes is List
        ? codes
              .map((code) => code.toString().trim())
              .where((code) => code.isNotEmpty)
              .toSet()
              .length
        : 1;
    final occupiedCopies =
        ((widget.resource['reservasActivas'] as num?)?.toInt() ?? 0) +
        ((widget.resource['prestamosActivos'] as num?)?.toInt() ?? 0);
    final availableCopies = (copyCapacity - occupiedCopies).clamp(
      0,
      copyCapacity,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5EF),
        foregroundColor: _blue,
        actions: [
          if (isBook && isStudent)
            IconButton(
              tooltip: _favorite
                  ? 'Quitar de favoritos'
                  : 'Guardar en favoritos',
              onPressed: _favoriteLoading ? null : _toggleFavorite,
              icon: _favoriteLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _favorite ? Icons.favorite : Icons.favorite_border,
                      color: _favorite ? Colors.redAccent : _blue,
                    ),
            ),
        ],
        title: Text(
          'Información del ${isBook ? 'libro' : 'recurso'}',
          style: const TextStyle(color: _blue),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isComputer
                        ? Icons.computer_rounded
                        : Icons.menu_book_rounded,
                    color: _yellow,
                    size: 36,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _value('nombre', 'Recurso sin título'),
                    style: const TextStyle(
                      color: _yellow,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _value('tipo'),
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _infoCard([
              _infoRow('Autor', _value('autor')),
              _infoRow('Año', _value('anio')),
              _infoRow('Editorial', _value('editorial')),
              _infoRow('Edición', _value('edicion')),
              _infoRow('Categoría', _value('categoria')),
              _infoRow('Código de inventario', _value('codigoInventario')),
              _infoRow('Códigos de copias', _copies()),
              _infoRow('Ubicación', _value('ubicacion')),
              _infoRow('Lugar de publicación', _value('lugar')),
              _infoRow('Especificaciones', _value('especificaciones')),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    availability == 'Disponible'
                        ? Icons.check_circle
                        : availability == 'Reservado'
                        ? Icons.bookmark_added_outlined
                        : Icons.assignment_turned_in_outlined,
                    color: availability == 'Disponible'
                        ? Colors.green
                        : availability == 'Reservado'
                        ? Colors.orange
                        : Colors.blue,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    availability,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (available && isStudent && !_alreadyHeld) ...[
              const SizedBox(height: 18),
              const Text(
                'Tiempo para llegar al recinto',
                style: TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 30, label: Text('30 minutos')),
                  ButtonSegment(value: 60, label: Text('1 hora')),
                ],
                selected: {_duration},
                onSelectionChanged: (selection) =>
                    setState(() => _duration = selection.first),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed:
                    available &&
                        isStudent &&
                        !_reserving &&
                        !_checkingHold &&
                        !_alreadyHeld
                    ? _reserve
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: _yellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _reserving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _yellow,
                        ),
                      )
                    : Text(
                        _checkingHold && isStudent
                            ? 'Verificando reserva…'
                            : _alreadyHeld
                            ? 'Ya tienes este recurso reservado o prestado'
                            : available
                            ? (availability == 'Disponible'
                                  ? 'Reservar'
                                  : 'Reservar copia disponible ($availableCopies)')
                            : availability,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _copies() {
    final copies = widget.resource['codigosCopias'];
    if (copies is List && copies.isNotEmpty) return copies.join(', ');
    return 'No especificado';
  }

  Widget _infoCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: rows),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 148,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.black87)),
        ),
      ],
    ),
  );
}
