import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'cin_cin_mark.dart';

/// Logo completo: simbolo Cin Cin + scritta «approfittoffro»
/// con la «o» condivisa in Spritz.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.height = 36,
    this.alignment = Alignment.center,
    this.showMark = true,
  });

  final double height;
  final Alignment alignment;
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final fontSize = height * 0.5;
    return Align(
      alignment: alignment,
      child: SizedBox(
        height: height,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showMark) ...[
                CinCinMark(size: height * 0.8),
                SizedBox(width: height * 0.12),
              ],
              Text.rich(
                const TextSpan(
                  children: [
                    TextSpan(text: 'approfitt'),
                    TextSpan(
                      text: 'o',
                      style: TextStyle(color: AppTheme.spritz),
                    ),
                    TextSpan(text: 'ffro'),
                  ],
                ),
                semanticsLabel: 'ApprofittOffro',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                  height: 1,
                  letterSpacing: -fontSize * 0.035,
                  color: AppTheme.panna,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
