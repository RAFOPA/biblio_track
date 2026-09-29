import 'package:flutter/material.dart';

import '../api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.cambiarPassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contraseña actualizada.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F5EF),
    appBar: AppBar(
      title: const Text('Cambiar contraseña'),
      backgroundColor: const Color(0xFFF7F5EF),
      foregroundColor: const Color(0xFF09144D),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _password(_current, 'Contraseña actual'),
              const SizedBox(height: 14),
              _password(
                _next,
                'Nueva contraseña',
                validator: (v) =>
                    (v ?? '').length < 8 ? 'Usa al menos 8 caracteres.' : null,
              ),
              const SizedBox(height: 14),
              _password(
                _confirm,
                'Confirmar nueva contraseña',
                validator: (v) =>
                    v != _next.text ? 'Las contraseñas no coinciden.' : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const CircularProgressIndicator()
                      : const Text('Guardar contraseña'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _password(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    obscureText: true,
    validator:
        validator ??
        (v) => (v ?? '').isEmpty ? 'Este campo es obligatorio.' : null,
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
