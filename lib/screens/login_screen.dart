import 'package:flutter/material.dart';
import 'search_screen.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Variable para controlar si la contraseña se oculta o se muestra
  bool _isObscure = true;

  // Definimos los colores de la universidad y el mockup
  final Color unanBlue = const Color(0xFF09144D); // Azul oscuro
  final Color unanYellow = const Color(0xFFFFD500); // Amarillo
  final Color unanRed = const Color(0xFFD32F2F); // Rojo

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // SafeArea evita que el diseño se superponga con la barra de estado del teléfono
      body: SafeArea(
        child: Center(
          // SingleChildScrollView evita el error de desbordamiento cuando se abre el teclado
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo / Título
                Center(
                  child: Text(
                    'BiblioTrack',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: unanBlue,
                      fontFamily: 'Times New Roman', // Estilo serif parecido al mockup
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // Etiqueta Correo electrónico
                Text(
                  'Correo electrónico',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: unanBlue,
                  ),
                ),
                const SizedBox(height: 8),

                // Caja de texto de Correo
                TextField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'example@gmail.com',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    // Borde normal (Azul)
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: unanBlue, width: 1.5),
                    ),
                    // Borde cuando se está escribiendo (Rojo)
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: unanRed, width: 2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Etiqueta Contraseña
                Text(
                  'Contraseña',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: unanBlue,
                  ),
                ),
                const SizedBox(height: 8),

                // Caja de texto de Contraseña
                TextField(
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    hintText: '••••••••••••',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    // Borde normal (Azul)
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: unanBlue, width: 1.5),
                    ),
                    // Borde cuando se está escribiendo (Rojo)
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: unanRed, width: 2.0),
                    ),
                    // Icono del ojito
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () {
                        // Esto actualiza la pantalla al presionar el ojo
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Botón Iniciar sesión
                SizedBox(
                  width: double.infinity, // Hace que el botón ocupe todo el ancho
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const SearchScreen()),
  );
},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: unanBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0, // Le quita la sombra para que se vea plano y moderno
                    ),
                    child: Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: unanYellow,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}