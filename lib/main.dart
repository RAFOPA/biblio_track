import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'screens/admin_screen.dart';
import 'screens/app_shell_screen.dart';
import 'screens/login_screen.dart';
import 'session_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BiblioTrackApp());
}

class BiblioTrackApp extends StatefulWidget {
  const BiblioTrackApp({super.key});

  @override
  State<BiblioTrackApp> createState() => _BiblioTrackAppState();
}

class _BiblioTrackAppState extends State<BiblioTrackApp>
    with WidgetsBindingObserver {
  static const _backgroundLimit = Duration(minutes: 2);
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final Future<void> _restoreFuture;
  DateTime? _backgroundedAt;
  Timer? _sessionCheckTimer;
  bool _restored = false;
  bool _isInactive = false;
  String? _logoutNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiService.onSessionInvalidated = _handleRemoteSessionInvalidation;
    _restoreFuture = _restoreSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (ApiService.onSessionInvalidated == _handleRemoteSessionInvalidation) {
      ApiService.onSessionInvalidated = null;
    }
    super.dispose();
  }

  Future<void> _restoreSession() async {
    try {
      final saved = await SessionStore.readSession();
      if (saved == null) {
        await SessionStore.clearSession();
        return;
      }
      ApiService.currentToken = saved.token;
      ApiService.currentUser = saved.user;
      // A saved background timestamp may belong to a previous app process
      // that was closed. Only enforce the timeout while this process is alive.
      _backgroundedAt = null;
      await SessionStore.clearBackgroundedAt();
    } catch (_) {
      ApiService.currentToken = null;
      ApiService.currentUser = null;
      await SessionStore.clearSession();
    } finally {
      _restored = true;
      if (mounted) setState(() {});
      if (ApiService.currentToken != null) {
        _startSessionMonitor();
        unawaited(_validateServerSession());
      }
      _showPendingLogoutNotice();
    }
  }

  bool get _isAdmin => const [
    'admin',
    'administrador',
  ].contains(ApiService.currentUser?['rol']?.toString().toLowerCase());

  void _handleRemoteSessionInvalidation(String message) {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = null;
    _logoutNotice = message;
    unawaited(_finishLocalLogout());
  }

  void _startSessionMonitor() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_validateServerSession()),
    );
  }

  Future<void> _validateServerSession() async {
    if (ApiService.currentToken == null) {
      _sessionCheckTimer?.cancel();
      _sessionCheckTimer = null;
      return;
    }
    try {
      await ApiService.getMiPerfil();
    } catch (_) {
      // Keep the local session during temporary network failures. A 401
      // invalidates it through ApiService.onSessionInvalidated.
    }
  }

  Future<void> _finishLocalLogout() async {
    await SessionStore.clearSession();
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    _showPendingLogoutNotice();
  }

  void _showPendingLogoutNotice() {
    final message = _logoutNotice;
    final context = _navigatorKey.currentContext;
    if (message == null || context == null || !mounted || !_restored) return;
    _logoutNotice = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dialogContext = _navigatorKey.currentContext;
      if (dialogContext == null || !mounted) return;
      showDialog<void>(
        context: dialogContext,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.lock_clock_rounded, color: Color(0xFF09144D)),
          title: const Text('Sesión cerrada'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_restored) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _sessionCheckTimer?.cancel();
      _sessionCheckTimer = null;
      if (!_isInactive && ApiService.currentToken != null) {
        _isInactive = true;
        _backgroundedAt = DateTime.now().toUtc();
      }
      return;
    }
    if (state != AppLifecycleState.resumed || !_isInactive) return;

    _isInactive = false;
    unawaited(_handleResume());
  }

  Future<void> _handleResume() async {
    await _checkBackgroundTimeout();
    if (ApiService.currentToken != null) {
      _startSessionMonitor();
      unawaited(_validateServerSession());
    }
  }

  Future<void> _checkBackgroundTimeout() async {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null || ApiService.currentToken == null) return;
    if (DateTime.now().toUtc().difference(backgroundedAt) < _backgroundLimit) {
      return;
    }
    _logoutNotice = 'Se cerró tu sesión porque la app permaneció en segundo plano durante 2 minutos.';
    await ApiService.logout();
    if (!mounted) return;
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    _showPendingLogoutNotice();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF09144D);
    const canvas = Color(0xFFF5F7FB);
    const surface = Colors.white;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Biblio Track',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: blue, surface: surface),
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: canvas,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        popupMenuTheme: PopupMenuThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: blue,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: blue.withAlpha(24)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: blue, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 50),
            animationDuration: const Duration(milliseconds: 180),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            animationDuration: const Duration(milliseconds: 180),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            animationDuration: const Duration(milliseconds: 180),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            animationDuration: const Duration(milliseconds: 180),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: FutureBuilder<void>(
        future: _restoreFuture,
        builder: (context, snapshot) {
          if (!_restored) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (ApiService.currentToken == null) return const LoginScreen();
          return _isAdmin ? const AdminScreen() : const AppShellScreen();
        },
      ),
    );
  }
}
