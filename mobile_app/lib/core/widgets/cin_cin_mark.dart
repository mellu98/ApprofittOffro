import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Simbolo del brand: due bicchieri che brindano, con la scintilla.
/// Disegnato in vettoriale su una griglia 120x120.
class CinCinMark extends StatelessWidget {
  const CinCinMark({
    super.key,
    this.size = 40,
    this.glassColor = AppTheme.panna,
    this.liquidColor = AppTheme.spritz,
    this.sparkColor = AppTheme.limone,
  });

  final double size;
  final Color glassColor;
  final Color liquidColor;
  final Color sparkColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _CinCinPainter(
          glassColor: glassColor,
          liquidColor: liquidColor,
          sparkColor: sparkColor,
          // Sotto i 40 px il contorno si ingrossa per restare leggibile.
          strokeWidth: size < 40 ? 7 : 5.5,
        ),
      ),
    );
  }
}

class _CinCinPainter extends CustomPainter {
  _CinCinPainter({
    required this.glassColor,
    required this.liquidColor,
    required this.sparkColor,
    required this.strokeWidth,
  });

  final Color glassColor;
  final Color liquidColor;
  final Color sparkColor;
  final double strokeWidth;

  static const _leftLiquid = [
    Offset(53.3, 69.8),
    Offset(44.2, 95),
    Offset(22, 89),
    Offset(25.5, 69.8),
  ];
  static const _rightLiquid = [
    Offset(94.5, 69.8),
    Offset(98, 89),
    Offset(75.8, 95),
    Offset(66.7, 69.8),
  ];
  static const _leftGlass = [
    Offset(29.5, 47.5),
    Offset(58.5, 55.3),
    Offset(44.2, 95),
    Offset(22, 89),
  ];
  static const _rightGlass = [
    Offset(61.5, 55.3),
    Offset(90.5, 47.5),
    Offset(98, 89),
    Offset(75.8, 95),
  ];
  static const _spark = [
    Offset(60, 23.5),
    Offset(61.8, 31.7),
    Offset(70, 33.5),
    Offset(61.8, 35.4),
    Offset(60, 43.5),
    Offset(58.2, 35.4),
    Offset(50, 33.5),
    Offset(58.2, 31.7),
  ];

  Path _polygon(List<Offset> points) {
    return Path()
      ..addPolygon(points, true)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 120);

    final liquid = Paint()
      ..color = liquidColor
      ..isAntiAlias = true;
    canvas.drawPath(_polygon(_leftLiquid), liquid);
    canvas.drawPath(_polygon(_rightLiquid), liquid);

    final glass = Paint()
      ..color = glassColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(_polygon(_leftGlass), glass);
    canvas.drawPath(_polygon(_rightGlass), glass);

    canvas.drawPath(
      _polygon(_spark),
      Paint()
        ..color = sparkColor
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CinCinPainter oldDelegate) {
    return oldDelegate.glassColor != glassColor ||
        oldDelegate.liquidColor != liquidColor ||
        oldDelegate.sparkColor != sparkColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
