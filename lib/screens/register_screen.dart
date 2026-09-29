import 'package:flutter/material.dart';

import '../api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _carnet = TextEditingController();
  final _email = TextEditingController();
  final _career = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _loading = false;
  String _role = 'Estudiante';
  String? _error;

  static const _blue = Color(0xFF09144D);
  static const _yellow = Color(0xFFFFD500);
  static const _red = Color(0xFFD32F2F);

  @override
  void dispose() {
    _name.dispose();
    _carnet.dispose();
    _email.dispose();
    _career.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.register(
        nombre: _name.text.trim(),
        carnet: _carnet.text.trim(),
        correo: _email.text.trim(),
        carrera: _career.text.trim(),
        password: _password.text,
        rol: _role,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'BiblioTrack',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: _blue,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 42,
                        color: _blue,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crear cuenta',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completa tus datos para ingresar al sistema',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _label('Nombre completo'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Tu nombre y apellido'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa tu nombre.'
                      : null,
                ),
                const SizedBox(height: 16),
                _label('Tipo de cuenta'),
                const SizedBox(height: 7),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Estudiante',
                      label: Text('Estudiante'),
                      icon: Icon(Icons.school_outlined),
                    ),
                    ButtonSegment(
                      value: 'Docente',
                      label: Text('Docente'),
                      icon: Icon(Icons.cast_for_education_outlined),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (selection) =>
                      setState(() => _role = selection.first),
                ),
                const SizedBox(height: 16),
                _label('Carnet (opcional)'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _carnet,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Número de carnet'),
                ),
                const SizedBox(height: 16),
                _label('Correo electrónico'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('tu.correo@universidad.edu'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Ingresa tu correo.';
                    if (!ApiService.correoValido(value)) {
                      return 'Ingresa un correo válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _label('Carrera (opcional)'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _career,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Tu carrera'),
                ),
                const SizedBox(height: 16),
                _label('Contraseña'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Mínimo 8 caracteres').copyWith(
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.length < 8
                      ? 'Usa al menos 8 caracteres.'
                      : null,
                ),
                const SizedBox(height: 16),
                _label('Confirmar contraseña'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: _obscureConfirmation,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  decoration: _decoration('Vuelve a escribir tu contraseña')
                      .copyWith(
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscureConfirmation = !_obscureConfirmation,
                          ),
                          icon: Icon(
                            _obscureConfirmation
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                  validator: (value) => value != _password.text
                      ? 'Las contraseñas no coinciden.'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _yellow,
                            ),
                          )
                        : const Text(
                            'Crear cuenta',
                            style: TextStyle(
                              color: _yellow,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _blue,
    ),
  );

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _blue, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _red, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
  );
}
