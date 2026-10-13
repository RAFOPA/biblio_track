import 'package:flutter/material.dart';

class BiblioTrackTitle extends StatelessWidget {
  const BiblioTrackTitle({super.key, this.fontSize = 28, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    'BiblioTrack',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: 'cursive',
      fontSize: fontSize,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w600,
      color: color ?? Theme.of(context).colorScheme.primary,
    ),
  );
}
