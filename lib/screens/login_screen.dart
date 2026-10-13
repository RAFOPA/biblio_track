import 'package:flutter/material.dart';

import '../api_service.dart';
import 'admin_screen.dart';
import 'app_shell_screen.dart';
import 'register_screen.dart';
import 'change_password_screen.dart';
import '../widgets/bibliotrack_title.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;
  String? _error;

  static const _blue = Color(0xFF09144D);
  static const _yellow = Color(0xFFFFD500);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final usuario = await ApiService.login(
        correo: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      final isAdmin = [
        'admin',
        'administrador',
      ].contains(usuario['rol']?.toString().toLowerCase());
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isAdmin ? const AdminScreen() : const AppShellScreen(),
        ),
      );
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openRegistration() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada. Ya puedes iniciar sesión.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: BiblioTrackTitle(fontSize: 42, color: _blue),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 42,
                      color: Color(0xFF168A45),
                    ),
                  ),
                  const SizedBox(height: 36),
                  _fieldLabel('Correo electrónico'),
                  const SizedBox(height: 8),
                  AnimatedFlagBorder(
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        hint: 'tu.correo@universidad.edu',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Ingresa tu correo.';
                        if (!ApiService.correoValido(value)) {
                          return 'Ingresa un correo válido.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _fieldLabel('Contraseña'),
                  const SizedBox(height: 8),
                  AnimatedFlagBorder(
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _isObscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration:
                          _inputDecoration(hint: 'Ingresa tu contraseña')
                              .copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isObscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey.shade500,
                                  ),
                                  onPressed: () =>
                                      setState(() => _isObscure = !_isObscure),
                                ),
                              ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Ingresa tu contraseña.'
                          : null,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(
                            startWithRecovery: true,
                          ),
                        ),
                      ),
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _yellow,
                              ),
                            )
                          : const Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _yellow,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        const Text('¿No tiene una cuenta? '),
                        GestureDetector(
                          onTap: _openRegistration,
                          child: const Text(
                            'Cree una',
                            style: TextStyle(
                              color: _blue,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _blue,
    ),
  );

  InputDecoration _inputDecoration({required String hint}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.transparent, width: 2.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.transparent, width: 2.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.transparent, width: 2.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.transparent, width: 2.5),
    ),
  );
}

class AnimatedFlagBorder extends StatefulWidget {
  const AnimatedFlagBorder({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedFlagBorder> createState() => _AnimatedFlagBorderState();
}

class _AnimatedFlagBorderState extends State<AnimatedFlagBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, child) => CustomPaint(
      foregroundPainter: _FlagBorderPainter(rotation: _controller.value),
      child: child,
    ),
    child: widget.child,
  );
}

class _FlagBorderPainter extends CustomPainter {
  const _FlagBorderPainter({required this.rotation});

  final double rotation;
  static const _strokeWidth = 2.5;
  static const _colors = [
    Color(0xFFE53935),
    Color(0xFF123C9A),
    Color(0xFFFFD500),
    Colors.white,
    Color(0xFFE53935),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final border = RRect.fromRectAndRadius(
      rect.deflate(_strokeWidth / 2),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      border,
      Paint()
        ..color = Colors.black.withAlpha(20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth + 0.5,
    );
    canvas.drawRRect(
      border,
      Paint()
        ..shader = SweepGradient(
          colors: _colors,
          stops: const [0, .25, .5, .75, 1],
          transform: GradientRotation(rotation * 2 * 3.141592653589793),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _FlagBorderPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}
