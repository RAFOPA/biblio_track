import 'package:flutter/material.dart';

import '../api_service.dart';
import 'login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.startWithRecovery = false});

  final bool startWithRecovery;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const _blue = Color(0xFF09144D);
  static const _background = Color(0xFFF5F7FB);

  final _normalFormKey = GlobalKey<FormState>();
  final _recoveryFormKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _recoveryMode = false;
  bool _codeSent = false;
  bool _busy = false;
  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirm = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _email.text = ApiService.currentUser?['correo']?.toString() ?? '';
    _recoveryMode = widget.startWithRecovery;
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_normalFormKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
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
    } catch (error) {
      if (mounted) setState(() => _error = _cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_recoveryFormKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final message = await ApiService.solicitarRecuperacion(
        _email.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _message = message;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_recoveryFormKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final message = await ApiService.restablecerPassword(
        correo: _email.text.trim(),
        codigo: _code.text.trim(),
        newPassword: _next.text,
      );
      await ApiService.logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _toggleRecovery() {
    setState(() {
      _recoveryMode = !_recoveryMode;
      _error = null;
      _message = null;
      _codeSent = false;
      _code.clear();
      _next.clear();
      _confirm.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      title: Text(
        _recoveryMode ? 'Recuperar contraseña' : 'Cambiar contraseña',
      ),
      backgroundColor: _background,
      foregroundColor: _blue,
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _recoveryMode ? _recoveryForm() : _changeForm(),
          ),
        ),
      ),
    ),
  );

  Widget _changeForm() => Container(
    key: const ValueKey('change'),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: _blue.withAlpha(12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Form(
      key: _normalFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.shield_outlined, size: 38, color: _blue),
          const SizedBox(height: 12),
          const Text(
            'Actualiza tu contraseña',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: _blue,
            ),
          ),
          const SizedBox(height: 22),
          _passwordField(
            _current,
            'Contraseña actual',
            visible: _showCurrent,
            toggle: () => setState(() => _showCurrent = !_showCurrent),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _toggleRecovery,
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          _passwordField(
            _next,
            'Nueva contraseña',
            visible: _showNext,
            toggle: () => setState(() => _showNext = !_showNext),
            validator: _newPasswordValidator,
          ),
          const SizedBox(height: 14),
          _passwordField(
            _confirm,
            'Confirmar nueva contraseña',
            visible: _showConfirm,
            toggle: () => setState(() => _showConfirm = !_showConfirm),
            validator: (value) =>
                value != _next.text ? 'Las contraseñas no coinciden.' : null,
          ),
          if (_error != null) _feedback(_error!, isError: true),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _changePassword,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar contraseña'),
          ),
        ],
      ),
    ),
  );

  Widget _recoveryForm() => Container(
    key: const ValueKey('recovery'),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: _blue.withAlpha(12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Form(
      key: _recoveryFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 38, color: _blue),
          const SizedBox(height: 12),
          const Text(
            'Recupera tu cuenta',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: _blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _codeSent
                ? 'Ingresa el código enviado a tu correo y define una contraseña nueva.'
                : 'Te enviaremos un código de un solo uso que vence en 15 minutos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: _decoration(
              'Correo de tu cuenta',
              Icons.email_outlined,
            ),
            validator: (value) =>
                !_validEmail(value ?? '') ? 'Ingresa un correo válido.' : null,
          ),
          if (_codeSent) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: _decoration(
                'Código de 8 dígitos',
                Icons.pin_outlined,
              ),
              validator: (value) => !RegExp(r'^\d{8}$').hasMatch(value ?? '')
                  ? 'Ingresa el código de 8 dígitos.'
                  : null,
            ),
            const SizedBox(height: 4),
            _passwordField(
              _next,
              'Nueva contraseña',
              visible: _showNext,
              toggle: () => setState(() => _showNext = !_showNext),
              validator: _newPasswordValidator,
            ),
            const SizedBox(height: 14),
            _passwordField(
              _confirm,
              'Confirmar nueva contraseña',
              visible: _showConfirm,
              toggle: () => setState(() => _showConfirm = !_showConfirm),
              validator: (value) =>
                  value != _next.text ? 'Las contraseñas no coinciden.' : null,
            ),
          ],
          if (_message != null) _feedback(_message!),
          if (_error != null) _feedback(_error!, isError: true),
          if (_codeSent)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _codeSent = false;
                      _code.clear();
                      _message = null;
                      _error = null;
                    }),
              child: const Text('Cambiar correo o solicitar otro código'),
            ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : (_codeSent ? _resetPassword : _sendCode),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_codeSent ? 'Restablecer contraseña' : 'Enviar código'),
          ),
          TextButton(
            onPressed: _busy ? null : _toggleRecovery,
            child: const Text('Volver a cambiar contraseña'),
          ),
        ],
      ),
    ),
  );

  String? _newPasswordValidator(String? value) =>
      (value ?? '').length < 8 ? 'Usa al menos 8 caracteres.' : null;

  bool _validEmail(String value) => RegExp(
    r'^[^\s@.][^\s@]*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$',
  ).hasMatch(value.trim());

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    required bool visible,
    required VoidCallback toggle,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    obscureText: !visible,
    autofillHints: const [AutofillHints.newPassword],
    validator:
        validator ??
        (value) => (value ?? '').isEmpty ? 'Este campo es obligatorio.' : null,
    decoration: _decoration(label, Icons.lock_outline).copyWith(
      suffixIcon: IconButton(
        tooltip: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
        onPressed: toggle,
        icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    ),
  );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: _background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.blueGrey.withAlpha(35)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _blue, width: 1.5),
    ),
  );

  Widget _feedback(String message, {bool isError = false}) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(
      message,
      style: TextStyle(
        color: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
      textAlign: TextAlign.center,
    ),
  );
}
