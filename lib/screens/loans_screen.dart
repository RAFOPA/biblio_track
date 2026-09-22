import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'home_screen.dart'; // O tu pantalla de inicio principal
import 'search_screen.dart';
import 'reservations_screen.dart';
import 'profile_screen.dart';

class LoansScreen extends StatefulWidget {
  final String resourceType; // 'Libro' o 'Computadora'
  final String resourceTitle; // Título del libro o nombre de la PC

  const LoansScreen({
    super.key,
    this.resourceType = 'Recurso bibliográfico',
    this.resourceTitle = 'Cálculo Multivariable - James Stewart',
  });

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final int _currentNavIndex = 3; // 3 = Préstamos

  final Color unanBlue = const Color(0xFF09144D);
  final Color unanYellow = const Color(0xFFFFD500);
  final Color backgroundColor = const Color(0xFFF7F5EF);
  final Color timerRed = const Color(0xFFB3261E);

  // Controladores para los campos autocompletados
  late TextEditingController _nameController;
  late TextEditingController _idController;
  late TextEditingController _careerController;
  late TextEditingController _resourceController;
  late TextEditingController _dateController;
  late TextEditingController _timeController;

  @override
  void initState() {
    super.initState();
    // Simulando el autocompletado con datos del estudiante y el recurso seleccionado
    _nameController = TextEditingController(text: 'Fernando José Pérez');
    _idController = TextEditingController(text: '21-12345-6');
    _careerController = TextEditingController(text: 'Ingeniería en Sistemas de Información');
    _resourceController = TextEditingController(text: widget.resourceTitle);
    _dateController = TextEditingController(text: '22/09/2026');
    _timeController = TextEditingController(text: '02:30 PM (Válido por 3h)');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _careerController.dispose();
    _resourceController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isComputer = widget.resourceType == 'Computadora';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BiblioTrack',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF09144D),
                      fontFamily: 'Times New Roman',
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6)
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.notifications_none_rounded, color: unanBlue),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Título de sección
              Text(
                'Registrar Préstamo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: unanBlue,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Tarjeta contenedora del formulario (Rediseñada, moderna y elegante)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: unanBlue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: unanBlue.withAlpha(50),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Aviso de QR Vigente
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Reserva activa. Presenta tu QR al personal para validar.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Campos del Formulario Autocompletados
                    _buildModernTextField(label: 'Nombre completo', controller: _nameController),
                    const SizedBox(height: 12),
                    _buildModernTextField(label: 'Número de carnet', controller: _idController),
                    const SizedBox(height: 12),
                    _buildModernTextField(label: 'Carrera', controller: _careerController),
                    const SizedBox(height: 12),
                    _buildModernTextField(
                      label: isComputer ? 'Computadora' : 'Recurso bibliográfico',
                      controller: _resourceController,
                      icon: isComputer ? Icons.computer : Icons.book,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildModernTextField(label: 'Fecha', controller: _dateController)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildModernTextField(label: 'Hora límite', controller: _timeController)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botón para Ver Código QR en Grande
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: unanYellow,
                          foregroundColor: unanBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 24),
                        label: const Text(
                          'Ver código QR de acceso',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _showQRCodeModal(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // 4. Barra de navegación inferior
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        selectedItemColor: unanBlue,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == _currentNavIndex) return;

          Widget? nextScreen;
          switch (index) {
            case 0:
              nextScreen = const HomeScreen(); // Asegúrate de tener tu HomeScreen importado o ajustado
              break;
            case 1:
              nextScreen = const SearchScreen();
              break;
            case 2:
              nextScreen = const ReservationsScreen();
              break;
            case 4:
              nextScreen = const ProfileScreen();
              break;
          }

          if (nextScreen != null) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, a1, a2) => nextScreen!,
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.search_outlined), activeIcon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Reservas'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Préstamos'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  // Widget auxiliar para construir campos de texto limpios, modernos y estéticos
  Widget _buildModernTextField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: unanYellow,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: true, // Es autocompletado por el sistema al reservar
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withAlpha(20),
            prefixIcon: icon != null ? Icon(icon, color: unanYellow, size: 18) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // Modal para mostrar el código QR en grande para su respectivo escaneo en el recinto
  void _showQRCodeModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Text(
                'QR de Préstamo',
                style: TextStyle(color: unanBlue, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 4),
              const Text(
                'Muestre este código al personal del recinto',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 10),
                  ],
                ),
                child: QrImageView(
                  data: 'BIBLIOTRACK-PRESTAMO-21-12345-6-${widget.resourceTitle}',
                  version: QrVersions.auto,
                  size: 200.0,
                  foregroundColor: unanBlue,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: timerRed.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_filled, color: timerRed, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Expira en: 02h 59m',
                      style: TextStyle(color: timerRed, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar', style: TextStyle(color: unanBlue, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}