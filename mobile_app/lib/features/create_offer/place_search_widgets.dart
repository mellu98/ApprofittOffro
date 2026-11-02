import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/place_candidate.dart';
import '../../models/place_suggestion.dart';

/// Campo di ricerca in cima alla mappa: locali per nome oppure citta e vie.
class PlaceSearchField extends StatelessWidget {
  const PlaceSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    this.loading = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.sentences,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.espresso,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Cerca un locale, una città o una via',
            filled: true,
            fillColor: AppTheme.mist,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  )
                : hasText
                    ? IconButton(
                        tooltip: 'Cancella ricerca',
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.lilla, width: 1.6),
            ),
          ),
        );
      },
    );
  }
}

/// Elenco dei suggerimenti sopra la mappa.
class PlaceSuggestionsPanel extends StatelessWidget {
  const PlaceSuggestionsPanel({
    super.key,
    required this.suggestions,
    required this.onSelected,
    this.loading = false,
    this.errorText,
    this.query = '',
    this.maxHeight = 320,
  });

  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSelected;
  final bool loading;
  final String? errorText;
  final String query;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content;
    if (errorText != null) {
      content = _PanelMessage(icon: Icons.wifi_off_rounded, text: errorText!);
    } else if (suggestions.isEmpty && loading) {
      content = const _PanelMessage(
        icon: Icons.search_rounded,
        text: 'Sto cercando...',
      );
    } else if (suggestions.isEmpty) {
      content = _PanelMessage(
        icon: Icons.search_off_rounded,
        text: query.isEmpty
            ? 'Scrivi il nome del locale o della città.'
            : 'Nessun bar o ristorante trovato per "$query". Prova con il nome della città.',
      );
    } else {
      content = ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 58,
          color: AppTheme.cardBorder.withValues(alpha: 0.7),
        ),
        itemBuilder: (context, index) => PlaceSuggestionTile(
          suggestion: suggestions[index],
          onTap: () => onSelected(suggestions[index]),
        ),
      );
    }

    return Material(
      color: AppTheme.paper.withValues(alpha: 0.98),
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x52000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: content),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Text(
                'Risultati da Google',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.lavanda,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceSuggestionTile extends StatelessWidget {
  const PlaceSuggestionTile({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArea = suggestion.isArea;
    final accent = isArea ? AppTheme.lilla : AppTheme.limone;
    final distance = formatPlaceDistance(suggestion.distanceMeters);
    final subtitleParts = [
      if (isArea) 'Sposta la mappa qui',
      if (suggestion.subtitle.isNotEmpty) suggestion.subtitle,
    ];
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isArea
                      ? Icons.location_city_rounded
                      : Icons.restaurant_rounded,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      suggestion.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.espresso,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.brown.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (distance != null) ...[
                const SizedBox(width: 10),
                Text(
                  distance,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.lavanda,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.lavanda),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brown,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Voto, fascia di prezzo e "aperto ora" del locale, presi da Google.
class PlaceGoogleInfoRow extends StatelessWidget {
  const PlaceGoogleInfoRow({super.key, required this.place});

  final PlaceCandidate place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];
    final rating = place.rating;
    if (rating != null) {
      chips.add(_InfoChip(
        icon: Icons.star_rounded,
        iconColor: AppTheme.limone,
        label: [
          formatPlaceRating(rating),
          if (place.ratingCount != null)
            '(${formatPlaceRatingCount(place.ratingCount!)})',
        ].join(' '),
      ));
    }
    final price = formatPlacePriceLevel(place.priceLevel);
    if (price != null) {
      chips.add(_InfoChip(label: price));
    }
    final openNow = place.openNow;
    if (openNow != null) {
      chips.add(_InfoChip(
        icon: Icons.circle,
        iconSize: 8,
        iconColor: openNow ? AppTheme.menta : AppTheme.lampone,
        label: openNow ? 'Aperto ora' : 'Chiuso ora',
      ));
    }
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return DefaultTextStyle.merge(
      style: theme.textTheme.labelMedium?.copyWith(
        color: AppTheme.espresso,
        fontWeight: FontWeight.w700,
      ),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    this.icon,
    this.iconColor,
    this.iconSize = 15,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.mist,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: iconColor),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
    );
  }
}

/// Foto del locale presa da Google, con l'autore come richiesto da Google.
class PlacePhotoThumb extends StatelessWidget {
  const PlacePhotoThumb({super.key, required this.url, this.size = 64});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.mist,
            child:
                const Icon(Icons.storefront_rounded, color: AppTheme.lavanda),
          ),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : Container(color: AppTheme.mist),
        ),
      ),
    );
  }
}

String formatPlaceRating(double rating) =>
    NumberFormat('0.0', 'it').format(rating);

String formatPlaceRatingCount(int count) =>
    NumberFormat.decimalPattern('it').format(count);

String? formatPlacePriceLevel(int? level) {
  if (level == null || level <= 0) {
    return null;
  }
  return '€' * level.clamp(1, 4);
}

String? formatPlaceDistance(int? meters) {
  if (meters == null || meters < 0) {
    return null;
  }
  if (meters < 1000) {
    return '${(meters / 50).round() * 50} m';
  }
  final km = meters / 1000;
  return km < 10
      ? '${NumberFormat('0.0', 'it').format(km)} km'
      : '${km.round()} km';
}
