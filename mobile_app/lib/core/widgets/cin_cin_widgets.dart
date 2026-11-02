import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Adesivo inclinato in stile Cin Cin ("ULTIMI 2 POSTI", "cin cin!").
class CinCinSticker extends StatelessWidget {
  const CinCinSticker({
    super.key,
    required this.label,
    this.color = AppTheme.limone,
    this.textColor = AppTheme.onAccent,
    this.angle = -0.05,
    this.fontSize = 13,
  });

  final String label;
  final Color color;
  final Color textColor;

  /// Rotazione in radianti.
  final double angle;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            height: 1.1,
            letterSpacing: 0.3,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

/// Etichetta del momento (colazione, aperitivo, pranzo, cena) nel suo colore.
class MealSticker extends StatelessWidget {
  const MealSticker({
    super.key,
    required this.tipoPasto,
    this.angle = 0,
  });

  final String tipoPasto;

  /// Rotazione in radianti.
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 6, 12, 6),
        decoration: BoxDecoration(
          color: AppTheme.mealColor(tipoPasto),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppTheme.mealIcon(tipoPasto),
              size: 16,
              color: AppTheme.onAccent,
            ),
            const SizedBox(width: 5),
            Text(
              AppTheme.mealLabel(tipoPasto).toUpperCase(),
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                height: 1.1,
                letterSpacing: 0.4,
                color: AppTheme.onAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// I posti del tavolo: occupati in Lampone, liberi con il bordo Limone.
class SeatDots extends StatelessWidget {
  const SeatDots({
    super.key,
    required this.total,
    required this.free,
    this.size = 14,
  });

  final int total;
  final int free;
  final double size;

  static const int _maxDots = 12;

  @override
  Widget build(BuildContext context) {
    final seats = math.min(math.max(total, 0), _maxDots);
    final freeSeats = math.min(math.max(free, 0), seats);
    return Semantics(
      label: '$free posti liberi su $total',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: size * 0.35,
          runSpacing: size * 0.35,
          children: List.generate(seats, (index) {
            final isFree = index >= seats - freeSeats;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFree ? Colors.transparent : AppTheme.lampone,
                border: isFree
                    ? Border.all(color: AppTheme.limone, width: size * 0.16)
                    : null,
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Foto del locale con un fondo colorato quando la foto manca.
class OfferPhoto extends StatelessWidget {
  const OfferPhoto({
    super.key,
    required this.imageUrl,
    required this.tipoPasto,
    this.height = 160,
    this.borderRadius = 22,
    this.overlay = const [],
  });

  final String? imageUrl;
  final String tipoPasto;
  final double height;
  final double borderRadius;

  /// Widget sovrapposti alla foto (di solito Positioned).
  final List<Widget> overlay;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppTheme.mealColor(tipoPasto),
      child: Center(
        child: Icon(
          AppTheme.mealIcon(tipoPasto),
          size: height * 0.3,
          color: AppTheme.onAccent.withValues(alpha: 0.75),
        ),
      ),
    );
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url == null)
              fallback
            else
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => fallback,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return const ColoredBox(color: AppTheme.vellutoChiaro);
                },
              ),
            ...overlay,
          ],
        ),
      ),
    );
  }
}
