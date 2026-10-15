import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';

const _adminBlue = Color(0xFF09144D);
const _adminYellow = Color(0xFFFFD500);

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 3).toInt();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administración'),
      backgroundColor: _adminBlue,
      foregroundColor: Colors.white,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Row(
          children: [
            _tabButton('Recursos', 0, Icons.library_books_outlined),
            _tabButton('Usuarios', 1, Icons.people_outline),
            _tabButton('Devoluciones', 2, Icons.assignment_return_outlined),
            _tabButton('Reportes', 3, Icons.bar_chart_outlined),
          ],
        ),
      ),
    ),
    body: IndexedStack(
      index: _tab,
      children: const [
        _ResourceAdmin(),
        _UserAdmin(),
        _ReturnAdmin(),
        _ReportAdmin(),
      ],
    ),
  );

  Widget _tabButton(String label, int index, IconData icon) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        height: 62,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _tab == index ? _adminYellow : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Icon(
                    icon,
                    key: ValueKey(_tab == index),
                    size: 18,
                    color: _tab == index ? _adminYellow : Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: _tab == index ? _adminYellow : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ResourceAdmin extends StatefulWidget {
  const _ResourceAdmin();
  @override
  State<_ResourceAdmin> createState() => _ResourceAdminState();
}

class _ResourceAdminState extends State<_ResourceAdmin> {
  static const _pageSize = 30;
  final _query = TextEditingController();
  final _author = TextEditingController();
  final _year = TextEditingController();
  final _publisher = TextEditingController();
  final _category = TextEditingController();
  Timer? _debounce;
  String _type = '';
  int _page = 1;
  late Future<Map<String, dynamic>> _resources = _fetch();

  Future<Map<String, dynamic>> _fetch() => ApiService.getAdminRecursos(
    query: _query.text,
    autor: _author.text,
    anio: _year.text,
    editorial: _publisher.text,
    categoria: _category.text,
    tipo: _type,
    page: _page,
    limit: _pageSize,
  );
  void _reload({bool resetPage = false}) {
    if (!mounted) return;
    setState(() {
      if (resetPage) _page = 1;
      _resources = _fetch();
    });
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _reload(resetPage: true),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_query, _author, _year, _publisher, _category]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _edit([Map<String, dynamic>? resource]) async {
    final form = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ResourceForm(resource: resource),
    );
    if (form == null) return;
    try {
      await ApiService.saveAdminRecurso(form, id: resource?['_id']?.toString());
      _reload();
      if (mounted)
        _toast(resource == null ? 'Recurso creado.' : 'Recurso actualizado.');
    } catch (e) {
      if (mounted) _toast(_error(e));
    }
  }

  Future<void> _deactivate(Map<String, dynamic> resource) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dar de baja recurso'),
        content: Text(
          '¿Dar de baja “${resource['nombre']}”? Dejará de aparecer en el catálogo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.darDeBajaRecurso(resource['_id'].toString());
      _reload();
    } catch (e) {
      if (mounted) _toast(_error(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F5EF),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _edit,
      backgroundColor: _adminBlue,
      foregroundColor: _adminYellow,
      icon: const Icon(Icons.add),
      label: const Text('Nuevo recurso'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  onChanged: _searchChanged,
                  decoration: const InputDecoration(
                    labelText: 'Buscar recursos',
                    hintText: 'Título, autor, código...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar página actual',
                onPressed: () => _reload(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ExpansionTile(
            title: const Text('Filtros adicionales'),
            tilePadding: EdgeInsets.zero,
            children: [
              TextField(
                controller: _author,
                onChanged: _searchChanged,
                decoration: const InputDecoration(labelText: 'Autor'),
              ),
              TextField(
                controller: _year,
                onChanged: _searchChanged,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Año'),
              ),
              TextField(
                controller: _publisher,
                onChanged: _searchChanged,
                decoration: const InputDecoration(labelText: 'Editorial'),
              ),
              TextField(
                controller: _category,
                onChanged: _searchChanged,
                decoration: const InputDecoration(labelText: 'Categoría'),
              ),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Todos')),
                  DropdownMenuItem(value: 'Libro', child: Text('Libro')),
                  DropdownMenuItem(
                    value: 'Computadora',
                    child: Text('Computadora'),
                  ),
                ],
                onChanged: (v) {
                  _type = v ?? '';
                  _reload(resetPage: true);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _resources,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return _errorView(_error(snapshot.error!), _reload);
              final data = snapshot.data ?? {};
              final resources = data['items'] as List<dynamic>? ?? [];
              final total = (data['total'] as num?)?.toInt() ?? 0;
              final pages = (total / _pageSize).ceil().clamp(1, 1 << 30);
              if (resources.isEmpty)
                return const Center(child: Text('No se encontraron recursos.'));
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$total recursos · página $_page de $pages'),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _page > 1
                                  ? () => setState(() {
                                      _page--;
                                      _resources = _fetch();
                                    })
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              onPressed: _page < pages
                                  ? () => setState(() {
                                      _page++;
                                      _resources = _fetch();
                                    })
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: resources.length,
                      itemBuilder: (context, i) {
                        final r = resources[i] as Map<String, dynamic>;
                        return Card(
                          color: Colors.white,
                          child: ListTile(
                            leading: Icon(
                              r['tipo'] == 'Computadora'
                                  ? Icons.computer
                                  : Icons.menu_book,
                              color: _adminBlue,
                            ),
                            title: Text(
                              r['nombre']?.toString() ?? 'Sin nombre',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                r['tipo'] ?? 'Recurso',
                                if ((r['autor'] ?? '').toString().isNotEmpty)
                                  r['autor'],
                                if ((r['anio'] ?? '').toString().isNotEmpty)
                                  r['anio'],
                                '${r['enPrestamo'] ?? 0} en préstamo',
                                '${r['reservado'] ?? 0} reservados',
                              ].join(' · '),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) =>
                                  action == 'edit' ? _edit(r) : _deactivate(r),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'deactivate',
                                  child: Text('Dar de baja'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _ResourceForm extends StatefulWidget {
  const _ResourceForm({this.resource});
  final Map<String, dynamic>? resource;
  @override
  State<_ResourceForm> createState() => _ResourceFormState();
}

class _ResourceFormState extends State<_ResourceForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late String _type;
  bool _busy = false;
  static const _labels = <String, String>{
    'nombre': 'Nombre *',
    'codigoInventario': 'Código de inventario',
    'autor': 'Autor',
    'categoria': 'Categoría',
    'especificaciones': 'Especificaciones',
    'ubicacion': 'Ubicación',
    'edicion': 'Edición',
    'lugar': 'Lugar de publicación',
    'editorial': 'Editorial',
    'anio': 'Año',
  };
  @override
  void initState() {
    super.initState();
    final r = widget.resource ?? {};
    _type = r['tipo']?.toString() == 'Computadora' ? 'Computadora' : 'Libro';
    _controllers = {
      for (final key in _labels.keys)
        key: TextEditingController(text: r[key]?.toString() ?? ''),
    };
    final copies = r['codigosCopias'];
    _controllers['codigosCopias'] = TextEditingController(
      text: copies is List ? copies.join('\n') : '',
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.resource == null ? 'Nuevo recurso' : 'Editar recurso'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'Libro', child: Text('Libro')),
                  DropdownMenuItem(
                    value: 'Computadora',
                    child: Text('Computadora'),
                  ),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'Libro'),
              ),
              ..._labels.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextFormField(
                    controller: _controllers[entry.key],
                    decoration: InputDecoration(labelText: entry.value),
                    validator: entry.key == 'nombre'
                        ? (v) => (v == null || v.trim().isEmpty)
                              ? 'El nombre es obligatorio'
                              : null
                        : null,
                    maxLines: entry.key == 'especificaciones' ? 2 : 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: _controllers['codigosCopias'],
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Códigos de copias',
                    helperText: 'Uno por línea (aplica a libros)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final data = {
      for (final entry in _controllers.entries)
        if (entry.key != 'codigosCopias') entry.key: entry.value.text.trim(),
      'tipo': _type,
      'codigosCopias': _controllers['codigosCopias']!.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    };
    Navigator.pop(context, data);
  }
}

class _UserAdmin extends StatefulWidget {
  const _UserAdmin();
  @override
  State<_UserAdmin> createState() => _UserAdminState();
}

class _UserAdminState extends State<_UserAdmin> {
  static const _pageSize = 30;
  final _query = TextEditingController();
  Timer? _debounce;
  String _roleFilter = '';
  String _statusFilter = '';
  int _page = 1;
  late Future<Map<String, dynamic>> _users = _fetch();

  Future<Map<String, dynamic>> _fetch() => ApiService.getAdminUsuarios(
    query: _query.text,
    rol: _roleFilter,
    estado: _statusFilter,
    page: _page,
    limit: _pageSize,
  );
  void _reload({bool resetPage = false}) {
    if (!mounted) return;
    setState(() {
      if (resetPage) _page = 1;
      _users = _fetch();
    });
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _reload(resetPage: true),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _update(Future<void> Function() action) async {
    try {
      await action();
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_error(e))));
      }
    }
  }

  Future<void> _askToSuspend(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Suspender cuenta?'),
        content: Text(
          'La cuenta de $name no podrá iniciar sesión hasta levantar la suspensión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Suspender cuenta'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _update(() => ApiService.cambiarSuspensionUsuario(id, true));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _query,
                onChanged: _searchChanged,
                decoration: const InputDecoration(
                  labelText: 'Buscar usuarios',
                  hintText: 'Nombre, correo, carnet o carrera',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar página actual',
              onPressed: () => _reload(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _roleFilter,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Todos')),
                DropdownMenuItem(
                  value: 'Estudiante',
                  child: Text('Estudiante'),
                ),
                DropdownMenuItem(value: 'Docente', child: Text('Docente')),
                DropdownMenuItem(
                  value: 'Administrador',
                  child: Text('Administrador'),
                ),
              ],
              onChanged: (v) {
                _roleFilter = v ?? '';
                _reload(resetPage: true);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Todos')),
                DropdownMenuItem(value: 'activos', child: Text('Activos')),
                DropdownMenuItem(
                  value: 'suspendidos',
                  child: Text('Suspendidos'),
                ),
              ],
              onChanged: (v) {
                _statusFilter = v ?? '';
                _reload(resetPage: true);
              },
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _users,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError)
              return _errorView(_error(snapshot.error!), _reload);
            final data = snapshot.data ?? {};
            final users = data['items'] as List<dynamic>? ?? [];
            final total = (data['total'] as num?)?.toInt() ?? 0;
            final pages = (total / _pageSize).ceil().clamp(1, 1 << 30);
            if (users.isEmpty)
              return const Center(child: Text('No se encontraron usuarios.'));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$total usuarios · página $_page de $pages'),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _page > 1
                                ? () => setState(() {
                                    _page--;
                                    _users = _fetch();
                                  })
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            onPressed: _page < pages
                                ? () => setState(() {
                                    _page++;
                                    _users = _fetch();
                                  })
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: users.length,
                    itemBuilder: (context, i) {
                      final user = users[i] as Map<String, dynamic>;
                      final id =
                          user['_id']?.toString() ??
                          user['id']?.toString() ??
                          '';
                      final role = user['rol']?.toString() ?? 'Estudiante';
                      final currentRole =
                          [
                            'Estudiante',
                            'Docente',
                            'Administrador',
                          ].contains(role)
                          ? role
                          : 'Estudiante';
                      final isAdmin = [
                        'admin',
                        'administrador',
                      ].contains(role.toLowerCase());
                      final name = user['nombre']?.toString() ?? 'Usuario';
                      final isSuspended = user['baneado'] == true && !isAdmin;
                      final ownId =
                          ApiService.currentUser?['id']?.toString() ??
                          ApiService.currentUser?['_id']?.toString();
                      final isSelf = ownId == id;

                      return Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(user['correo']?.toString() ?? ''),
                              if ((user['infraccionesPrestamo'] as num?)
                                          ?.toInt() !=
                                      null &&
                                  (user['infraccionesPrestamo'] as num)
                                          .toInt() >
                                      0)
                                Text(
                                  'Infracciones por préstamo vencido: ${user['infraccionesPrestamo']}',
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              Row(
                                children: [
                                  const Text('Rol: '),
                                  DropdownButton<String>(
                                    value: currentRole,
                                    items:
                                        const [
                                              'Estudiante',
                                              'Docente',
                                              'Administrador',
                                            ]
                                            .map(
                                              (value) => DropdownMenuItem(
                                                value: value,
                                                child: Text(value),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null &&
                                          value != currentRole) {
                                        _update(
                                          () => ApiService.cambiarRolUsuario(
                                            id,
                                            value,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                isSuspended
                                    ? 'Cuenta suspendida'
                                    : 'Cuenta activa',
                                style: TextStyle(
                                  color: isSuspended
                                      ? Colors.red
                                      : Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Tooltip(
                                    message: isSelf
                                        ? 'No puedes suspender tu propia cuenta.'
                                        : isAdmin
                                        ? 'Las cuentas administrativas no se pueden suspender.'
                                        : 'Suspende esta cuenta.',
                                    child: TextButton.icon(
                                      onPressed:
                                          isSuspended || isSelf || isAdmin
                                          ? null
                                          : () => _askToSuspend(id, name),
                                      icon: const Icon(Icons.block),
                                      label: const Text('Suspender cuenta'),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: isSuspended
                                        ? () => _update(
                                            () =>
                                                ApiService.cambiarSuspensionUsuario(
                                                  id,
                                                  false,
                                                ),
                                          )
                                        : null,
                                    icon: const Icon(Icons.lock_open),
                                    label: const Text('Levantar suspensión'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class _ReturnAdmin extends StatefulWidget {
  const _ReturnAdmin();
  @override
  State<_ReturnAdmin> createState() => _ReturnAdminState();
}

class _ReturnAdminState extends State<_ReturnAdmin> {
  static const _pageSize = 30;
  final _query = TextEditingController();
  Timer? _debounce;
  int _page = 1;
  bool _returning = false;
  late Future<Map<String, dynamic>> _loans = _fetch();

  Future<Map<String, dynamic>> _fetch() => ApiService.getAdminPrestamosActivos(
    query: _query.text,
    page: _page,
    limit: _pageSize,
  );

  void _reload({bool resetPage = false}) {
    if (!mounted) return;
    setState(() {
      if (resetPage) _page = 1;
      _loans = _fetch();
    });
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _reload(resetPage: true),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _registerReturn(Map<String, dynamic> loan) async {
    final borrower = loan['usuario'] as Map<String, dynamic>? ?? const {};
    final resource = loan['recurso'] as Map<String, dynamic>? ?? const {};
    final borrowerName = borrower['nombre']?.toString() ?? 'Usuario';
    final resourceName = resource['nombre']?.toString() ?? 'Recurso';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar devolución'),
        content: Text(
          '¿Confirmas que $borrowerName devolvió “$resourceName”? El recurso volverá a estar disponible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.assignment_return),
            label: const Text('Confirmar devolución'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _returning = true);
    try {
      await ApiService.devolverPrestamoAdmin(loan['_id'].toString());
      _reload(resetPage: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Devolución registrada: $resourceName.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_error(error))));
        _reload();
      }
    } finally {
      if (mounted) setState(() => _returning = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _query,
                onChanged: _searchChanged,
                decoration: const InputDecoration(
                  labelText: 'Buscar préstamo activo',
                  hintText: 'Estudiante, carnet, recurso o inventario',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar lista',
              onPressed: () => _reload(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Busca por los datos del usuario o del recurso y registra la devolución al recibirlo.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loans,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _errorView(_error(snapshot.error!), _reload);
            }
            final data = snapshot.data ?? {};
            final loans = data['items'] as List<dynamic>? ?? [];
            final total = (data['total'] as num?)?.toInt() ?? 0;
            final pages = (total / _pageSize).ceil().clamp(1, 1 << 30);
            if (loans.isEmpty) {
              return Center(
                child: Text(
                  _query.text.trim().isEmpty
                      ? 'No hay préstamos activos pendientes de devolución.'
                      : 'No se encontraron préstamos con esa búsqueda.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$total préstamos · página $_page de $pages'),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _page > 1
                                ? () => setState(() {
                                    _page--;
                                    _loans = _fetch();
                                  })
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            onPressed: _page < pages
                                ? () => setState(() {
                                    _page++;
                                    _loans = _fetch();
                                  })
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: loans.length,
                    itemBuilder: (context, index) {
                      final loan = loans[index] as Map<String, dynamic>;
                      final borrower =
                          loan['usuario'] as Map<String, dynamic>? ?? const {};
                      final resource =
                          loan['recurso'] as Map<String, dynamic>? ?? const {};
                      final dueDate = DateTime.tryParse(
                        loan['fechaDevolucionEstimada']?.toString() ?? '',
                      )?.toLocal();
                      final overdue =
                          dueDate != null && dueDate.isBefore(DateTime.now());
                      final inventory =
                          resource['codigoInventario']?.toString() ?? '';
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.menu_book_outlined),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          resource['nombre']?.toString() ??
                                              'Recurso',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (inventory.isNotEmpty)
                                          Text('Inventario: $inventory'),
                                      ],
                                    ),
                                  ),
                                  if (overdue)
                                    const Chip(
                                      label: Text('Vencido'),
                                      visualDensity: VisualDensity.compact,
                                      labelStyle: TextStyle(color: Colors.red),
                                    ),
                                  if (loan['infraccionAplicadaEn'] != null)
                                    const Chip(
                                      label: Text('Infracción registrada'),
                                      visualDensity: VisualDensity.compact,
                                      labelStyle: TextStyle(
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                ],
                              ),
                              const Divider(height: 22),
                              Text(
                                borrower['nombre']?.toString() ?? 'Usuario',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                [
                                      borrower['carnet']?.toString(),
                                      borrower['correo']?.toString(),
                                    ]
                                    .whereType<String>()
                                    .where((v) => v.isNotEmpty)
                                    .join(' · '),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 16,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Préstamo: ${_returnDate(loan['fechaPrestamo'])}',
                                  ),
                                  Text(
                                    'Vence: ${_formatReturnDateTime(context, dueDate)}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonalIcon(
                                  onPressed: _returning
                                      ? null
                                      : () => _registerReturn(loan),
                                  icon: const Icon(Icons.assignment_return),
                                  label: const Text('Registrar devolución'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

String _returnDate(dynamic value) =>
    _formatReturnDate(DateTime.tryParse(value?.toString() ?? '')?.toLocal());

String _formatReturnDate(DateTime? value) => value == null
    ? '—'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatReturnDateTime(BuildContext context, DateTime? value) {
  if (value == null) return '—';
  final localizations = MaterialLocalizations.of(context);
  return '${_formatReturnDate(value)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
}

class _ReportAdmin extends StatefulWidget {
  const _ReportAdmin();
  @override
  State<_ReportAdmin> createState() => _ReportAdminState();
}

class _ReportAdminState extends State<_ReportAdmin> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );
  late Future<Map<String, dynamic>> _report = _load();
  Future<Map<String, dynamic>> _load() =>
      ApiService.getAdminReporte(start: _range.start, end: _range.end);
  Future<void> _chooseRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (range != null)
      setState(() {
        _range = range;
        _report = _load();
      });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _report,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return _errorView(
          _error(snapshot.error!),
          () => setState(() => _report = _load()),
        );
      final data = snapshot.data ?? {};
      final totals = data['totales'] as Map<String, dynamic>? ?? {};
      final top = data['recursosMasSolicitados'] as List<dynamic>? ?? [];
      final byDay = data['prestamosPorDia'] as List<dynamic>? ?? [];
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _chooseRange,
            icon: const Icon(Icons.calendar_month),
            label: Text('${_date(_range.start)} — ${_date(_range.end)}'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in [
                ('Usuarios', totals['usuarios']),
                ('Recursos', totals['recursos']),
                ('Préstamos', totals['prestamos']),
                ('Reservas', totals['reservas']),
              ])
                _MetricCard(label: item.$1, value: item.$2?.toString() ?? '0'),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Préstamos por día',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          _LoansChart(points: byDay),
          const SizedBox(height: 22),
          const Text(
            'Recursos más solicitados',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          if (top.isEmpty)
            const Text('No hay reservas en este período.')
          else
            ...top.map((item) {
              final value = item as Map<String, dynamic>;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(value['nombre']?.toString() ?? 'Recurso'),
                subtitle: Text(value['tipo']?.toString() ?? 'Recurso'),
                trailing: CircleAvatar(
                  backgroundColor: _adminBlue,
                  foregroundColor: _adminYellow,
                  child: Text(value['solicitudes'].toString()),
                ),
              );
            }),
        ],
      );
    },
  );
  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 42) / 2,
    child: Card(
      color: _adminBlue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: _adminYellow,
                fontWeight: FontWeight.bold,
                fontSize: 25,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LoansChart extends StatelessWidget {
  const _LoansChart({required this.points});
  final List<dynamic> points;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty)
      return const SizedBox(
        height: 90,
        child: Center(
          child: Text('Sin préstamos confirmados en este período.'),
        ),
      );
    final visible = points.length > 14
        ? points.sublist(points.length - 14)
        : points;
    final maxValue = visible
        .map((p) => ((p as Map)['total'] as num).toDouble())
        .fold<double>(1, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in visible)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${p['total']}', style: const TextStyle(fontSize: 10)),
                    const SizedBox(height: 4),
                    Container(
                      height: 105 * ((p['total'] as num) / maxValue),
                      decoration: BoxDecoration(
                        color: _adminBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      p['_id'].toString().substring(5),
                      style: const TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _errorView(String message, VoidCallback retry) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        TextButton(onPressed: retry, child: const Text('Reintentar')),
      ],
    ),
  ),
);
String _error(Object error) => error.toString().replaceFirst('Exception: ', '');
