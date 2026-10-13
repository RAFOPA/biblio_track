import 'package:flutter/material.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _gold = Color(0xFFD4AF37);
  static const _items = <({IconData icon, IconData activeIcon, String label})>[
    (
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Inicio',
    ),
    (
      icon: Icons.search_rounded,
      activeIcon: Icons.search_rounded,
      label: 'Buscar',
    ),
    (
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Reservas',
    ),
    (
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      label: 'Préstamos',
    ),
    (
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 8,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            for (var index = 0; index < _items.length; index++)
              Expanded(
                child: IconButton(
                  tooltip: _items[index].label,
                  onPressed: () => onTap(index),
                  splashRadius: 25,
                  constraints: const BoxConstraints.tightFor(height: 60),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    currentIndex == index
                        ? _items[index].activeIcon
                        : _items[index].icon,
                    size: 26,
                    color: currentIndex == index ? _gold : Colors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
