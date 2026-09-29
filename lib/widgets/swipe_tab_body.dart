import 'package:flutter/material.dart';

void openAppTab(
  BuildContext context,
  int currentIndex,
  int targetIndex,
  List<Widget> destinations,
) {
  if (targetIndex == currentIndex ||
      targetIndex < 0 ||
      targetIndex >= destinations.length)
    return;
  final from = Offset(targetIndex > currentIndex ? 1 : -1, 0);
  Navigator.of(context).pushReplacement(
    PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => destinations[targetIndex],
      transitionDuration: const Duration(milliseconds: 230),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: animation.drive(
          Tween(
            begin: from,
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    ),
  );
}

class SwipeTabBody extends StatefulWidget {
  const SwipeTabBody({
    super.key,
    required this.index,
    required this.destinations,
    required this.child,
  });

  final int index;
  final List<Widget> destinations;
  final Widget child;

  @override
  State<SwipeTabBody> createState() => _SwipeTabBodyState();
}

class _SwipeTabBodyState extends State<SwipeTabBody> {
  double _dragDistance = 0;

  void _finishSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldSwipe = _dragDistance.abs() > 72 || velocity.abs() > 420;
    final direction = _dragDistance.abs() > 72
        ? _dragDistance.sign
        : velocity.sign;
    _dragDistance = 0;
    if (!shouldSwipe || direction == 0) return;

    // Dragging left advances one tab; dragging right goes back one tab.
    final target = widget.index + (direction < 0 ? 1 : -1);
    if (target < 0 || target >= widget.destinations.length) return;
    openAppTab(context, widget.index, target, widget.destinations);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
    onHorizontalDragEnd: _finishSwipe,
    onHorizontalDragCancel: () => _dragDistance = 0,
    child: widget.child,
  );
}
