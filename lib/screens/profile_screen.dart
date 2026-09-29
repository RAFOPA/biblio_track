import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/app_bottom_navigation_bar.dart';

import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'search_screen.dart';
import 'reservations_screen.dart';
import 'loans_screen.dart';
import 'change_password_screen.dart';
import 'favorites_screen.dart';
import 'loan_history_screen.dart';
import '../widgets/swipe_tab_body.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final int _currentNavIndex = 4; // 4 = Perfil

  final Color unanBlue = const Color(0xFF09144D);
  final Color unanYellow = const Color(0xFFFFD500);
  final Color backgroundColor = const Color(0xFFF7F5EF);

  // Datos del perfil editables
  String? _profilePhoto;
  String get _userRole =>
      ApiService.currentUser?['rol']?.toString() ?? 'Usuario';
  String get _userCarnet => ApiService.currentUser?['carnet']?.toString() ?? '';
  String get _userName =>
      ApiService.currentUser?['nombre']?.toString() ?? 'Usuario';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await ApiService.getMiPerfil();
      if (mounted)
        setState(() => _profilePhoto = user['fotoPerfil']?.toString());
    } catch (_) {}
  }

  // Método para seleccionar imagen de la galería
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (pickedFile != null) {
      try {
        final bytes = await pickedFile.readAsBytes();
        final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        await ApiService.guardarFotoPerfil(dataUrl);
        if (mounted) setState(() => _profilePhoto = dataUrl);
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', '')),
            ),
          );
      }
    }
  }

  ImageProvider? get _avatarImage {
    final value = _profilePhoto;
    if (value == null || !value.startsWith('data:image/')) return null;
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(value.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      // Panel lateral (Sidebar / Drawer) requerido
      endDrawer: Drawer(
        backgroundColor: backgroundColor,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menú',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: unanBlue,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: unanBlue),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              // Opción Seguridad con subopción
              ExpansionTile(
                leading: Icon(Icons.lock_outline_rounded, color: unanBlue),
                title: const Text(
                  'Seguridad',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 40),
                    title: const Text('Cambiar contraseña'),
                    leading: const Icon(Icons.vpn_key_outlined, size: 20),
                    onTap: () {
                      // Acción para cambiar contraseña
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Opción Favoritos
              if (['estudiante', 'docente'].contains(
                ApiService.currentUser?['rol']?.toString().toLowerCase(),
              ))
                ListTile(
                  leading: const Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Favoritos',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Libros favoritos guardados'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FavoritesScreen(),
                      ),
                    );
                  },
                ),

              const Divider(height: 40),

              // Cerrar sesión
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  await ApiService.logout();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),

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
          child: Column(
            children: [
              // 1. Barra superior estilo Instagram
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BiblioTrack',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: unanBlue,
                      ),
                    ),
                    Builder(
                      builder: (context) => IconButton(
                        icon: Icon(
                          Icons.menu_rounded,
                          color: unanBlue,
                          size: 28,
                        ),
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Cabecera de Perfil (Estilo Instagram minimalista)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: unanBlue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar editable
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: Colors.white,
                            backgroundImage: _avatarImage,
                            child: _avatarImage == null
                                ? Icon(Icons.person, size: 45, color: unanBlue)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: unanYellow,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: unanBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Información de texto
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userRole.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: unanYellow,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userCarnet,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6.0),
                            child: Divider(color: Colors.white24, height: 1),
                          ),
                          Text(
                            _userName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3. Botones principales: Editar Perfil e Historial
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: unanBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _pickImage,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text(
                          'Editar Perfil',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: unanBlue, width: 1.5),
                          foregroundColor: unanBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoanHistoryScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text(
                          'Historial',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),

      // 4. Barra de Navegación Inferior Global
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) => openAppTab(context, _currentNavIndex, index, const [
          HomeScreen(),
          SearchScreen(),
          ReservationsScreen(),
          LoansScreen(),
          ProfileScreen(),
        ]),
      ),
    );
  }
}
