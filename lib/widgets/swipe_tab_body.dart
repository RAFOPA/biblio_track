import 'package:flutter/foundation.dart';
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
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: animation.drive(
          Tween(
            begin: from,
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        ),
        child: child,
      ),
    ),
  );
}

class AppTabScope extends InheritedNotifier<ValueListenable<int>> {
  const AppTabScope({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
    required super.child,
  }) : super(notifier: currentIndex);

  final ValueChanged<int> onNavigate;
  final ValueListenable<int> currentIndex;

  static AppTabScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppTabScope>();

  @override
  bool updateShouldNotify(AppTabScope oldWidget) =>
      onNavigate != oldWidget.onNavigate ||
      currentIndex != oldWidget.currentIndex;
}

void navigateToAppTab(
  BuildContext context,
  int currentIndex,
  int targetIndex,
  List<Widget> destinations,
) {
  final shell = AppTabScope.maybeOf(context);
  if (shell != null) {
    shell.onNavigate(targetIndex);
    return;
  }
  openAppTab(context, currentIndex, targetIndex, destinations);
}

class SwipeTabBody extends StatefulWidget {
  const SwipeTabBody({
    super.key,
    required this.index,
    required this.destinations,
    required this.child,
    this.enabled = true,
  });

  final int index;
  final List<Widget> destinations;
  final Widget child;
  final bool enabled;

  @override
  State<SwipeTabBody> createState() => _SwipeTabBodyState();
}

class _SwipeTabBodyState extends State<SwipeTabBody>
    with SingleTickerProviderStateMixin {
  final _dragOffset = ValueNotifier<double>(0);
  late final AnimationController _snapBackController;
  int? _activePointer;
  Offset? _startPosition;
  Duration? _startTime;
  Offset _latestPosition = Offset.zero;
  bool _isHorizontalDrag = false;

  @override
  void initState() {
    super.initState();
    _snapBackController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          final startOffset = _snapBackStart;
          _dragOffset.value = startOffset * (1 - _snapBackController.value);
        });
  }

  double _snapBackStart = 0;

  @override
  void dispose() {
    _snapBackController.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _snapBackController.stop();
    _activePointer = event.pointer;
    _startPosition = event.position;
    _latestPosition = event.position;
    _startTime = event.timeStamp;
    _isHorizontalDrag = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _startPosition == null) return;
    _latestPosition = event.position;
    final delta = event.position - _startPosition!;
    if (!_isHorizontalDrag && delta.distance > 8) {
      _isHorizontalDrag = delta.dx.abs() > delta.dy.abs() * 1.15;
    }
    if (!_isHorizontalDrag) return;

    final direction = delta.dx < 0 ? 1 : -1;
    final target = widget.index + direction;
    if (target < 0 || target >= widget.destinations.length) {
      _dragOffset.value = delta.dx * .2;
      return;
    }
    _dragOffset.value = delta.dx;
  }

  void _onPointerUp(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    final startPosition = _startPosition;
    final startTime = _startTime;
    _activePointer = null;
    _startPosition = null;
    _startTime = null;

    if (startPosition == null || startTime == null || !_isHorizontalDrag) {
      _animateSnapBack();
      return;
    }

    final dx = _latestPosition.dx - startPosition.dx;
    final elapsedMs = (event.timeStamp - startTime).inMilliseconds;
    final velocity = elapsedMs > 0 ? dx * 1000 / elapsedMs : 0.0;
    final shouldSwipe =
        dx.abs() > 72 || (dx.abs() > 24 && velocity.abs() > 520);
    if (!shouldSwipe) {
      _animateSnapBack();
      return;
    }

    final target = widget.index + (dx < 0 ? 1 : -1);
    if (target < 0 || target >= widget.destinations.length) {
      _animateSnapBack();
      return;
    }
    openAppTab(context, widget.index, target, widget.destinations);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _startPosition = null;
    _startTime = null;
    _animateSnapBack();
  }

  void _animateSnapBack() {
    _snapBackStart = _dragOffset.value;
    if (_snapBackStart == 0) return;
    _snapBackController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: ValueListenableBuilder<double>(
        valueListenable: _dragOffset,
        child: widget.child,
        builder: (_, offset, child) =>
            Transform.translate(offset: Offset(offset, 0), child: child),
      ),
    );
  }
}
