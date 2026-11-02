import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cin_cin_widgets.dart';
import '../../core/widgets/content_report_sheet.dart';
import '../../models/offer.dart';
import '../profile/public_profile_page.dart';
import '../profile/profile_gallery_viewer_page.dart';
import '../chat/chat_page.dart';

class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.apiClient,
    required this.currentUserId,
    this.currentUserName = 'Utente',
    this.currentUserPhotoFilename = '',
    this.onChatClosed,
    this.onClaim,
    this.onEditOwn,
    this.onDeleteOwn,
    this.onArchive,
    this.onFavoritePlaceChanged,
    this.isPremiumUser = false,
    this.allowProfileOpen = true,
    this.showAddressLeadIcon = true,
  });

  final Offer offer;
  final ApiClient apiClient;
  final String currentUserId;
  final String currentUserName;
  final String currentUserPhotoFilename;
  final VoidCallback? onChatClosed;
  final Future<void> Function()? onClaim;
  final VoidCallback? onEditOwn;
  final Future<void> Function()? onDeleteOwn;
  final Future<void> Function()? onArchive;
  final Future<void> Function()? onFavoritePlaceChanged;
  final bool isPremiumUser;
  final bool allowProfileOpen;
  final bool showAddressLeadIcon;

  bool get _isPast => offer.dataOra.toLocal().isBefore(DateTime.now());

  bool get _isOngoing =>
      _isPast &&
      offer.dataOra
          .toLocal()
          .isAfter(DateTime.now().subtract(const Duration(hours: 3)));

  bool get _canArchive =>
      offer.isOwn &&
      offer.dataOra
          .toLocal()
          .isBefore(DateTime.now().subtract(const Duration(hours: 3)));

  bool get _isEmptyStartedOwn =>
      offer.isOwn &&
      offer.participants.isEmpty &&
      offer.dataOra.toLocal().isBefore(DateTime.now());

  List<String> _offerGalleryUrls() {
    final filenames = <String>[];
    if (offer.fotoLocale.isNotEmpty && offer.fotoLocale != 'nessuna.jpg') {
      filenames.add(offer.fotoLocale);
    }
    for (final filename in offer.fotoLocaleGallery) {
      if (filename.isNotEmpty &&
          filename != 'nessuna.jpg' &&
          !filenames.contains(filename)) {
        filenames.add(filename);
      }
    }
    return filenames.map(apiClient.buildUploadUrl).toList();
  }

  static const _dangerColor = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isUpcoming = offer.dataOra.toLocal().isAfter(DateTime.now());
    final canNavigateToOffer = offer.isOwn || offer.claimStatus == 'claimed';
    final canManageReminders = isUpcoming &&
        (offer.isOwn || offer.alreadyClaimed || offer.claimStatus == 'claimed');
    final freeSeats = offer.postiDisponibili.clamp(0, offer.postiTotali);
    final offerGalleryUrls = _offerGalleryUrls();
    final localeImageUrl =
        offerGalleryUrls.isNotEmpty ? offerGalleryUrls.first : null;
    final authorPhotoUrl = offer.autoreFoto.isNotEmpty
        ? apiClient.buildUploadUrl(offer.autoreFoto)
        : null;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: offerGalleryUrls.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProfileGalleryViewerPage(
                            imageUrls: offerGalleryUrls,
                            title: offer.nomeLocale,
                          ),
                        ),
                      ),
              child: OfferPhoto(
                imageUrl: localeImageUrl,
                tipoPasto: offer.tipoPasto,
                height: 200,
                overlay: [
                  Positioned(
                    left: 12,
                    top: 12,
                    child: MealSticker(tipoPasto: offer.tipoPasto),
                  ),
                  if (offerGalleryUrls.length > 1)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.notte.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '+${offerGalleryUrls.length - 1}',
                          style: const TextStyle(
                            color: AppTheme.panna,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (!offer.isOwn &&
                      isUpcoming &&
                      freeSeats > 0 &&
                      freeSeats <= 2)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: CinCinSticker(
                        label: freeSeats == 1
                            ? 'ULTIMO POSTO'
                            : 'ULTIMI $freeSeats POSTI',
                        angle: -0.05,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatWhenLabel(offer.dataOra),
                          style: const TextStyle(
                            color: AppTheme.limone,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      if (canManageReminders)
                        _ReminderButton(
                          offer: offer,
                          apiClient: apiClient,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(offer.nomeLocale, style: textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  _buildAddress(canNavigateToOffer),
                  const SizedBox(height: 10),
                  _FavoritePlaceButton(
                    offer: offer,
                    apiClient: apiClient,
                    isPremiumUser: isPremiumUser,
                    onChanged: onFavoritePlaceChanged,
                  ),
                  const SizedBox(height: 14),
                  _buildSeats(context, freeSeats),
                  const SizedBox(height: 12),
                  _buildHost(context, authorPhotoUrl),
                  if (offer.descrizione.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: AppTheme.vellutoChiaro,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                          bottomLeft: Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        offer.descrizione,
                        style: const TextStyle(
                          height: 1.45,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.panna,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (offer.stato == 'archiviata')
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Text(
                        'Evento archiviato',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.panna,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else if (_isEmptyStartedOwn)
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: onEditOwn,
                            child: const Text('Modifica la tua offerta'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onDeleteOwn == null
                                ? null
                                : () => onDeleteOwn?.call(),
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: const Text('Elimina evento a vuoto'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _dangerColor,
                              side: const BorderSide(
                                color: _dangerColor,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (_isOngoing && offer.isOwn)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Text(
                        'In corso',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.menta,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    )
                  else if (_canArchive && onArchive != null)
                    FilledButton(
                      onPressed: () => onArchive?.call(),
                      child: const Text('Archivia'),
                    )
                  else if (offer.isOwn &&
                      offer.telefonoLocale.trim().isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: onEditOwn,
                            child: const Text('Modifica la tua offerta'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _callLocalPhone,
                            icon: const Icon(Icons.call_outlined),
                            label: const Text('Chiama il locale'),
                          ),
                        ),
                      ],
                    )
                  else
                    FilledButton(
                      onPressed: offer.isOwn
                          ? onEditOwn
                          : (!offer.canClaim || onClaim == null
                              ? null
                              : () => onClaim!.call()),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        textStyle: const TextStyle(
                          fontFamily: AppTheme.textFont,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(_ctaLabel()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddress(bool canNavigateToOffer) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.mist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (showAddressLeadIcon) ...[
            const Icon(
              Icons.place_rounded,
              color: AppTheme.spritz,
              size: 22,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.indirizzo,
                  style: const TextStyle(
                    color: AppTheme.panna,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Circa ${offer.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: AppTheme.lavanda,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (canNavigateToOffer) ...[
            const SizedBox(width: 12),
            Tooltip(
              message: 'Indicazioni stradali',
              child: Material(
                color: AppTheme.spritz,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _openExternalLink(_googleMapsDirectionsUrl()),
                  child: const SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(
                      Icons.near_me_rounded,
                      color: AppTheme.onAccent,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeats(BuildContext context, int freeSeats) {
    final textTheme = Theme.of(context).textTheme;
    final freeSeatsShown = math.min(freeSeats, 6);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.mist,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  freeSeats == 0
                      ? 'Al completo'
                      : freeSeats == 1
                          ? '1 posto libero'
                          : '$freeSeats posti liberi',
                  style: textTheme.headlineSmall?.copyWith(fontSize: 26),
                ),
              ),
              Text(
                'su ${offer.postiTotali}',
                style: const TextStyle(
                  color: AppTheme.lavanda,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...offer.participants.map((participant) {
                final photoUrl = participant.photoFilename.isNotEmpty
                    ? apiClient.buildUploadUrl(participant.photoFilename)
                    : null;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openProfile(context, participant.id),
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            color: AppTheme.lampone,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: AppTheme.vellutoChiaro,
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null
                                ? const Icon(Icons.person_outline)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          participant.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.panna,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (offer.isOwn) ...[
                          const SizedBox(height: 6),
                          _ChatParticipantAction(
                            offerId: offer.id,
                            apiClient: apiClient,
                            currentUserId: currentUserId,
                            currentUserName: currentUserName,
                            currentUserPhotoFilename: currentUserPhotoFilename,
                            participantId: participant.id,
                            participantName: participant.name,
                            participantPhotoFilename: participant.photoFilename,
                            onChatClosed: onChatClosed,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              for (var i = 0; i < freeSeatsShown; i++) const _FreeSeat(),
            ],
          ),
          if (offer.participants.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Per ora nessuno si e\' ancora aggiunto.',
              style: textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHost(BuildContext context, String? authorPhotoUrl) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppTheme.mist,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: allowProfileOpen
            ? () => _openProfile(context, offer.autoreId)
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.vellutoChiaro,
                backgroundImage: authorPhotoUrl != null
                    ? NetworkImage(authorPhotoUrl)
                    : null,
                child: authorPhotoUrl == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offre ${offer.autoreNome}',
                      style: textTheme.titleLarge?.copyWith(fontSize: 19),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${offer.autoreEta} anni',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: AppTheme.limone,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          offer.autoreRatingAverage.toStringAsFixed(1),
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.panna,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (allowProfileOpen) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Visualizza profilo',
                        style: TextStyle(
                          color: AppTheme.limone,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (!offer.isOwn && offer.claimStatus == 'claimed') ...[
                      const SizedBox(height: 10),
                      _ChatButton(
                        offer: offer,
                        apiClient: apiClient,
                        currentUserId: currentUserId,
                        currentUserName: currentUserName,
                        currentUserPhotoFilename: currentUserPhotoFilename,
                        onChatClosed: onChatClosed,
                      ),
                    ],
                  ],
                ),
              ),
              if (!offer.isOwn)
                IconButton(
                  onPressed: () => _reportOffer(context),
                  icon: const Icon(Icons.report_problem_outlined),
                  color: AppTheme.lavanda,
                  tooltip: 'Segnala evento',
                )
              else if (allowProfileOpen)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.lavanda,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _ctaLabel() {
    if (offer.stato == 'archiviata') {
      return 'Evento archiviato';
    }
    if (_isEmptyStartedOwn) {
      return 'Elimina evento a vuoto';
    }
    if (_isOngoing && offer.isOwn) {
      return 'In corso';
    }
    if (_canArchive) {
      return 'Archivia';
    }
    if (offer.isOwn) {
      return 'Modifica la tua offerta';
    }
    if (offer.claimStatus == 'pending') {
      return 'Richiesta inviata';
    }
    if (offer.claimStatus == 'rejected') {
      return 'Richiesta non accettata';
    }
    if (offer.claimStatus == 'started') {
      return 'In corso';
    }
    if (offer.alreadyClaimed || offer.claimStatus == 'claimed') {
      return 'Hai approfittato';
    }
    if (offer.claimStatus == 'full') {
      return 'Completa · non piu\' prenotabile';
    }
    if (offer.premiumLateBooking ||
        offer.claimStatus == 'premium_last_minute') {
      return 'Approfitta last minute';
    }
    if (offer.claimStatus == 'booking_closed' ||
        offer.claimStatus == 'started') {
      return 'Non piu\' prenotabile';
    }
    return 'Approfitta';
  }

  String _formatWhenLabel(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(local.year, local.month, local.day);
    final time = DateFormat('HH:mm').format(local);

    if (eventDay == today) {
      return 'OGGI ALLE $time';
    }
    if (eventDay == today.add(const Duration(days: 1))) {
      return 'DOMANI ALLE $time';
    }
    return DateFormat('dd/MM - HH:mm').format(local).toUpperCase();
  }

  void _openProfile(BuildContext context, int userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfilePage(
          apiClient: apiClient,
          userId: userId,
        ),
      ),
    );
  }

  Future<void> _reportOffer(BuildContext context) async {
    await showContentReportSheet(
      context: context,
      apiClient: apiClient,
      title: 'Segnala evento',
      targetType: 'offer',
      targetId: offer.id,
      offerId: offer.id,
      reportedUserId: offer.autoreId,
    );
  }

  Future<void> _openExternalLink(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callLocalPhone() async {
    final digits = offer.telefonoLocale.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      return;
    }
    final uri = Uri.tryParse('tel:$digits');
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _googleMapsDirectionsUrl() {
    return 'https://www.google.com/maps/dir/?api=1&destination=${offer.latitude},${offer.longitude}';
  }

  Future<void> _openCalendar() async {
    final uri = Uri.tryParse(_googleCalendarUrl());
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _googleCalendarUrl() {
    final startDate = offer.dataOra.toUtc();
    final endDate = startDate.add(const Duration(hours: 2));
    final summary =
        '${offer.tipoPasto.toUpperCase()} presso ${offer.nomeLocale}';
    final description =
        'Condividi un pasto con ${offer.autoreNome}. Per favore arriva puntuale.';
    final location =
        offer.indirizzo.isNotEmpty ? offer.indirizzo : offer.nomeLocale;
    final dates =
        '${_formatCalendarTimestamp(startDate)}/${_formatCalendarTimestamp(endDate)}';

    final uri = Uri.https(
      'calendar.google.com',
      '/calendar/render',
      {
        'action': 'TEMPLATE',
        'text': summary,
        'dates': dates,
        'details': description,
        'location': location,
      },
    );
    return uri.toString();
  }

  String _formatCalendarTimestamp(DateTime value) {
    return '${value.toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z';
  }
}

class _FavoritePlaceButton extends StatefulWidget {
  const _FavoritePlaceButton({
    required this.offer,
    required this.apiClient,
    required this.isPremiumUser,
    this.onChanged,
  });

  final Offer offer;
  final ApiClient apiClient;
  final bool isPremiumUser;
  final Future<void> Function()? onChanged;

  @override
  State<_FavoritePlaceButton> createState() => _FavoritePlaceButtonState();
}

class _FavoritePlaceButtonState extends State<_FavoritePlaceButton> {
  late bool _isFavorite;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.offer.isFavoritePlace;
  }

  @override
  void didUpdateWidget(covariant _FavoritePlaceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offer.id != widget.offer.id ||
        oldWidget.offer.isFavoritePlace != widget.offer.isFavoritePlace) {
      _isFavorite = widget.offer.isFavoritePlace;
    }
  }

  Future<void> _showPremiumSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: AppTheme.cream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppTheme.vividViolet,
                  size: 42,
                ),
                const SizedBox(height: 10),
                Text(
                  'Funzione Premium',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'I locali preferiti sono disponibili per gli utenti Premium con abbonamento attivo. In futuro gli ApprofittOffro Points potranno permettere di ottenere mesi Premium gratuiti.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.brown.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Diventa Premium'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveFavoritePlace() async {
    if (!widget.isPremiumUser) {
      await _showPremiumSheet();
      return;
    }
    if (_isFavorite || _isSaving) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      await widget.apiClient.favoritePlaceFromOffer(widget.offer.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _isFavorite = true;
        _isSaving = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content:
              Text('${widget.offer.nomeLocale} salvato nei locali preferiti.'),
        ),
      );
      await widget.onChanged?.call();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Non riesco a salvare il locale: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = !widget.isPremiumUser;
    return OutlinedButton.icon(
      onPressed: (_isSaving || _isFavorite) ? null : _saveFavoritePlace,
      icon: _isSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              locked
                  ? Icons.lock_rounded
                  : (_isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded),
            ),
      label: Text(
        locked
            ? 'Salva locale preferito - Premium'
            : (_isFavorite
                ? 'Locale nei tuoi preferiti'
                : 'Salva locale preferito'),
      ),
    );
  }
}

class _ChatParticipantAction extends StatelessWidget {
  const _ChatParticipantAction({
    required this.offerId,
    required this.apiClient,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserPhotoFilename,
    required this.participantId,
    required this.participantName,
    this.participantPhotoFilename = '',
    this.onChatClosed,
  });

  final int offerId;
  final ApiClient apiClient;
  final String currentUserId;
  final String currentUserName;
  final String currentUserPhotoFilename;
  final int participantId;
  final String participantName;
  final String participantPhotoFilename;
  final VoidCallback? onChatClosed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChatPage(
                apiClient: apiClient,
                offerId: offerId.toString(),
                currentUserId: currentUserId,
                currentUserName: currentUserName,
                currentUserPhotoFilename: currentUserPhotoFilename,
                otherUserId: participantId.toString(),
                otherUserName: participantName,
                otherUserPhotoFilename: participantPhotoFilename,
              ),
            ),
          );
          onChatClosed?.call();
        },
        child: Ink(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.peach.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppTheme.vividViolet,
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _ReminderButton extends StatefulWidget {
  const _ReminderButton({
    required this.offer,
    required this.apiClient,
  });

  final Offer offer;
  final ApiClient apiClient;

  @override
  State<_ReminderButton> createState() => _ReminderButtonState();
}

class _ReminderButtonState extends State<_ReminderButton> {
  List<int> _reminderMinutes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    try {
      final minutes =
          await widget.apiClient.fetchOfferReminders(widget.offer.id);
      if (mounted) {
        setState(() {
          _reminderMinutes = minutes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveReminders(List<int> minutes) async {
    try {
      await widget.apiClient.saveOfferReminders(widget.offer.id, minutes);
      if (mounted) {
        setState(() => _reminderMinutes = minutes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Errore nel salvataggio dei promemoria.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReminders = _reminderMinutes.isNotEmpty;
    final reminderBackground = AppTheme.isDarkPalette
        ? AppTheme.orange.withValues(alpha: 0.28)
        : const Color(0xFFFFD54F).withValues(alpha: 0.85);
    final reminderIconColor =
        AppTheme.isDarkPalette ? AppTheme.espresso : const Color(0xFF8D6E00);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _openReminderDialog(context),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: hasReminders
                ? reminderBackground
                : AppTheme.peach.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Icon(
            hasReminders
                ? Icons.notifications_active
                : Icons.notifications_none,
            color: hasReminders ? reminderIconColor : AppTheme.vividViolet,
            size: hasReminders ? 20 : 26,
          ),
        ),
      ),
    );
  }

  Future<void> _openReminderDialog(BuildContext context) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) => _ReminderDialog(
        offer: widget.offer,
        currentReminders: _reminderMinutes,
      ),
    );
    if (result != null) {
      await _saveReminders(result);
      if (context.mounted) {
        _showFloatingReminderMessage(
          context,
          result.isEmpty
              ? 'Promemoria disattivati'
              : 'Promemoria impostati a ${result.join(', ')} min prima',
        );
      }
    }
  }
}

void _showFloatingReminderMessage(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    return;
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      final top = MediaQuery.of(context).padding.top + 86;
      return Positioned(
        top: top,
        left: 18,
        right: 18,
        child: Material(
          color: Colors.transparent,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.vividViolet),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.espresso,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  Timer(const Duration(seconds: 3), entry.remove);
}

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({
    required this.offer,
    required this.currentReminders,
  });

  final Offer offer;
  final List<int> currentReminders;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late List<int> _selectedMinutes;

  final List<int> _options = [15, 30, 60, 120, 180];

  @override
  void initState() {
    super.initState();
    _selectedMinutes = List.from(widget.currentReminders);
  }

  void _toggleOption(int minutes) {
    setState(() {
      if (_selectedMinutes.contains(minutes)) {
        _selectedMinutes.remove(minutes);
      } else if (_selectedMinutes.length < 2) {
        _selectedMinutes.add(minutes);
        _selectedMinutes.sort();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Imposta promemoria'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scegli fino a 2 promemoria per "${widget.offer.nomeLocale}":',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options.map((minutes) {
              final isSelected = _selectedMinutes.contains(minutes);
              return FilterChip(
                label: Text('$minutes min'),
                selected: isSelected,
                onSelected: (_) => _toggleOption(minutes),
                selectedColor: AppTheme.isDarkPalette
                    ? AppTheme.orange.withValues(alpha: 0.3)
                    : const Color(0xFFFFD54F),
              );
            }).toList(),
          ),
          if (_selectedMinutes.length >= 2) ...[
            const SizedBox(height: 12),
            Text(
              'Massimo 2 promemoria selezionati.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.orange,
                  ),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedMinutes),
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

class _ChatButton extends StatelessWidget {
  const _ChatButton({
    required this.offer,
    required this.apiClient,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserPhotoFilename,
    this.onChatClosed,
  });

  final Offer offer;
  final ApiClient apiClient;
  final String currentUserId;
  final String currentUserName;
  final String currentUserPhotoFilename;
  final VoidCallback? onChatClosed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChatPage(
                apiClient: apiClient,
                offerId: offer.id.toString(),
                currentUserId: currentUserId,
                currentUserName: currentUserName,
                currentUserPhotoFilename: currentUserPhotoFilename,
                otherUserId: offer.autoreId.toString(),
                otherUserName: offer.autoreNome,
                otherUserPhotoFilename: offer.autoreFoto,
              ),
            ),
          );
          onChatClosed?.call();
        },
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.peach.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppTheme.vividViolet,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _FreeSeat extends StatelessWidget {
  const _FreeSeat();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Posto libero',
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 57,
              height: 57,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.limone, width: 2.5),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppTheme.limone,
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Libero',
              style: TextStyle(
                color: AppTheme.limone,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
