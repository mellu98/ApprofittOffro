import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({
    super.key,
    this.compact = false,
    this.centered = false,
  });

  final bool compact;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final badge = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.limone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 12,
          vertical: compact ? 5 : 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: AppTheme.onAccent,
              size: compact ? 15 : 18,
            ),
            SizedBox(width: compact ? 5 : 7),
            Text(
              'Premium',
              style: TextStyle(
                color: AppTheme.onAccent,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 12 : 13.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );

    if (!centered) {
      return badge;
    }
    return Center(child: badge);
  }
}
