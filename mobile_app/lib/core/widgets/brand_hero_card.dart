import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'cin_cin_widgets.dart';

class BrandHeroCard extends StatelessWidget {
  const BrandHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.footer,
    this.eyebrow,
    this.padding,
    this.centered = false,
  });

  final String title;
  final String subtitle;
  final Widget? footer;
  final String? eyebrow;
  final EdgeInsetsGeometry? padding;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.velluto,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Align(
              alignment: centered ? Alignment.center : Alignment.centerLeft,
              child: CinCinSticker(label: eyebrow!),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  height: 1.05,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (footer != null) ...[
            const SizedBox(height: 18),
            footer!,
          ],
        ],
      ),
    );
  }
}
