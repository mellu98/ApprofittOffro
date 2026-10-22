import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_wordmark.dart';
import '../../core/widgets/cin_cin_widgets.dart';
import '../../models/offer.dart';
import '../auth/auth_controller.dart';
import 'offer_card.dart';
import 'offers_controller.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({
    super.key,
    required this.authController,
    required this.offersController,
    required this.onGoToProfile,
    required this.onGoToChat,
  });

  final AuthController authController;
  final OffersController offersController;
  final VoidCallback onGoToProfile;
  final VoidCallback onGoToChat;

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  static const _mealFilters = [
    ('Aperitivi', 'ape'),
    ('Colazioni', 'colazione'),
    ('Pranzi', 'pranzo'),
    ('Cene', 'cena'),
  ];

  double? _distancePreferenceDraft;
  bool _isSavingDistance = false;
  bool _isDistanceCardExpanded = false;

  String _greeting(String? fullName) {
    final firstName = (fullName ?? '').trim().split(RegExp(r'\s+')).first;
    final hour = DateTime.now().hour;
    final question = hour >= 5 && hour < 11
        ? 'che colazione si fa?'
        : hour >= 11 && hour < 15
            ? 'chi viene a pranzo?'
            : 'stasera si esce?';
    return firstName.isEmpty
        ? 'Ciao,\n$question'
        : 'Ciao $firstName,\n$question';
  }

  int _normalizeDistanceForUi(int rawValue) {
    return rawValue.clamp(
      OffersController.minRadiusKm,
      OffersController.maxRadiusKm,
    );
  }

  String _distanceLabelText(int valueKm) {
    return '$valueKm km';
  }

  bool _canCancelClaim(Offer offer) {
    return false;
  }

  String _cancelClaimLabel(Offer offer) {
    return offer.claimStatus == 'pending'
        ? 'Annulla richiesta'
        : 'Annulla partecipazione';
  }

  bool _canHideRejectedOffer(Offer offer) {
    return offer.claimStatus == 'rejected' && offer.claimId > 0;
  }

  Future<void> _openOfferDetails(
    BuildContext context,
    Offer offer,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.84,
          minChildSize: 0.58,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return DecoratedBox(
              decoration: const BoxDecoration(
                color: AppTheme.cream,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                child: Column(
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
                    const SizedBox(height: 14),
                    Text(
                      'Evento aperto',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 14),
                    OfferCard(
                      offer: offer,
                      apiClient: widget.authController.apiClient,
                      currentUserId:
                          widget.authController.currentUser?.id.toString() ??
                              '',
                      currentUserName:
                          widget.authController.currentUser?.nome ?? 'Utente',
                      currentUserPhotoFilename:
                          widget.authController.currentUser?.photoFilename ??
                              '',
                      onChatClosed: () {
                        widget.onGoToChat();
                        final sheetNavigator =
                            Navigator.of(sheetContext, rootNavigator: true);
                        if (sheetNavigator.canPop()) {
                          sheetNavigator.pop();
                        }
                      },
                      onFavoritePlaceChanged:
                          widget.offersController.loadOffers,
                      isPremiumUser:
                          widget.authController.currentUser?.isPremium == true,
                      allowProfileOpen: true,
                      onEditOwn: null,
                      onArchive: offer.isOwn
                          ? () async {
                              final navigator = Navigator.of(sheetContext);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await widget.authController.apiClient
                                    .archiveOffer(offer.id);
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text('Offerta archiviata')),
                                );
                                navigator.pop();
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Errore: $e')),
                                );
                              }
                            }
                          : null,
                      onClaim: offer.isOwn || !offer.canClaim
                          ? null
                          : () async {
                              final navigator = Navigator.of(sheetContext);
                              final messenger = ScaffoldMessenger.of(context);
                              final message =
                                  await widget.offersController.claimOffer(
                                offer,
                              );
                              if (!context.mounted || message == null) {
                                return;
                              }
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            },
                    ),
                    if (_canCancelClaim(offer)) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: sheetContext,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(_cancelClaimLabel(offer)),
                              content: Text(
                                offer.claimStatus == 'pending'
                                    ? 'Vuoi davvero annullare la richiesta per ${offer.nomeLocale}?'
                                    : 'Vuoi davvero annullare la partecipazione a ${offer.nomeLocale}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text('No'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: const Text('Sì'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) {
                            return;
                          }
                          final navigator = Navigator.of(sheetContext);
                          final messenger = ScaffoldMessenger.of(context);
                          final message =
                              await widget.offersController.cancelClaim(offer);
                          if (!context.mounted || message == null) {
                            return;
                          }
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        },
                        icon: const Icon(Icons.event_busy_outlined),
                        label: Text(_cancelClaimLabel(offer)),
                      ),
                    ],
                    if (_canHideRejectedOffer(offer)) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: sheetContext,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Non visualizzare più'),
                              content: Text(
                                'Vuoi togliere ${offer.nomeLocale} dagli eventi che vedi in community?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text('No'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: const Text('Sì'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) {
                            return;
                          }
                          final navigator = Navigator.of(sheetContext);
                          final messenger = ScaffoldMessenger.of(context);
                          final message =
                              await widget.offersController.hideRejectedOffer(
                            offer,
                          );
                          if (!context.mounted || message == null) {
                            return;
                          }
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        },
                        icon: const Icon(Icons.visibility_off_outlined),
                        label: const Text('Non visualizzare più'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveDistancePreference() async {
    final user = widget.authController.currentUser;
    if (user == null) {
      return;
    }

    final selectedKm = (_distancePreferenceDraft ??
            widget.offersController.selectedRadiusKm.toDouble())
        .round()
        .clamp(
          OffersController.minRadiusKm,
          OffersController.maxRadiusKm,
        );
    final currentKm = widget.offersController.selectedRadiusKm;
    if (selectedKm == currentKm) {
      return;
    }

    setState(() => _isSavingDistance = true);
    try {
      await widget.offersController.selectRadiusKm(selectedKm);
      await widget.authController.apiClient.updateProfile(
        nome: user.nome,
        email: user.email,
        eta: user.etaDisplay,
        gender: user.gender,
        actionRadiusKm: selectedKm,
        numeroTelefono: user.phoneNumber,
        citta: user.city,
        latitude: user.latitude?.toString() ?? '',
        longitude: user.longitude?.toString() ?? '',
        preferredFoods: user.preferredFoods,
        intolerances: user.intolerances,
        bio: user.bio,
        existingGalleryFilenames: user.galleryFilenames,
      );
      await widget.authController.refreshCurrentUser();
      if (!mounted) {
        return;
      }
      setState(() {
        _distancePreferenceDraft = selectedKm.toDouble();
        _isDistanceCardExpanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Da ora vedrai eventi entro $selectedKm km.'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Non riesco ad aggiornare la distanza adesso.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingDistance = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.authController,
        widget.offersController,
      ]),
      builder: (context, _) {
        final currentActionRadius = _normalizeDistanceForUi(
          widget.offersController.selectedRadiusKm,
        );
        final distanceDraft =
            _distancePreferenceDraft ?? currentActionRadius.toDouble();
        final user = widget.authController.currentUser;
        final hasOffersToManage = user != null &&
            (user.pendingClaimRequests.isNotEmpty ||
                widget.offersController.hiddenOwnOffersCount > 0);

        return Scaffold(
          backgroundColor: AppTheme.cream,
          appBar: AppBar(
            toolbarHeight: kToolbarHeight,
            backgroundColor: AppTheme.cream,
            surfaceTintColor: AppTheme.cream,
            shadowColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: const SizedBox.shrink(),
            leadingWidth: kToolbarHeight,
            centerTitle: true,
            title: const BrandWordmark(
              height: 50,
              alignment: Alignment.center,
            ),
            actions: const [
              SizedBox(width: kToolbarHeight),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: widget.offersController.loadOffers,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _greeting(user?.nome),
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            children: [
                              for (final meal in _mealFilters) ...[
                                _MealChip(
                                  label: meal.$1,
                                  value: meal.$2,
                                  selected: widget
                                          .offersController.selectedMealType ==
                                      meal.$2,
                                  onTap: widget.offersController.toggleMealType,
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DistancePreferenceControl(
                          valueKm: _normalizeDistanceForUi(
                            distanceDraft.round(),
                          ),
                          isSaving: _isSavingDistance,
                          isExpanded: _isDistanceCardExpanded,
                          distanceLabel: _distanceLabelText(
                            _normalizeDistanceForUi(
                              distanceDraft.round(),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => _distancePreferenceDraft = value);
                          },
                          onToggle: () {
                            setState(
                              () => _isDistanceCardExpanded =
                                  !_isDistanceCardExpanded,
                            );
                          },
                          onSave: _saveDistancePreference,
                          isDirty: _normalizeDistanceForUi(
                                distanceDraft.round(),
                              ) !=
                              currentActionRadius,
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasOffersToManage)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child:
                          _ProfileOffersReminder(onTap: widget.onGoToProfile),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    child: Text(
                      'Tutti gli eventi aperti',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontSize: 22),
                    ),
                  ),
                ),
                if (widget.offersController.isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (widget.offersController.errorMessage != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.offersController.errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else if (widget.offersController.offers.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Per questa selezione non vedo ancora eventi aperti. Appena arriva un nuovo tavolo, lo troverai qui.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: widget.offersController.offers.length,
                    itemBuilder: (context, index) {
                      final offer = widget.offersController.offers[index];
                      return _OfferPreviewCard(
                        offer: offer,
                        apiClient: widget.authController.apiClient,
                        onOpen: () => _openOfferDetails(context, offer),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileOffersReminder extends StatelessWidget {
  const _ProfileOffersReminder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.velluto,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.bordo),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.event_note_rounded,
                color: AppTheme.limone,
                size: 22,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Gestisci i tuoi eventi dal profilo.',
                  style: TextStyle(
                    color: AppTheme.panna,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.lavanda,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferPreviewCard extends StatelessWidget {
  const _OfferPreviewCard({
    required this.offer,
    required this.apiClient,
    required this.onOpen,
  });

  final Offer offer;
  final ApiClient apiClient;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isUpcoming = offer.dataOra.toLocal().isAfter(DateTime.now());
    final authorPhotoUrl = offer.autoreFoto.isNotEmpty
        ? apiClient.buildUploadUrl(offer.autoreFoto)
        : null;
    final photoFilename = offer.coverPhotoFilename;
    final photoUrl =
        photoFilename != null ? apiClient.buildUploadUrl(photoFilename) : null;
    final freeSeats = offer.postiDisponibili.clamp(0, offer.postiTotali);
    final canManageReminders = isUpcoming &&
        (offer.isOwn || offer.alreadyClaimed || offer.claimStatus == 'claimed');
    final showLastSeats =
        !offer.isOwn && isUpcoming && freeSeats > 0 && freeSeats <= 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Material(
        color: AppTheme.velluto,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OfferPhoto(
                  imageUrl: photoUrl,
                  tipoPasto: offer.tipoPasto,
                  height: 150,
                  overlay: [
                    Positioned(
                      left: 10,
                      top: 10,
                      child: MealSticker(tipoPasto: offer.tipoPasto),
                    ),
                    if (offer.isOwn)
                      const Positioned(
                        right: 10,
                        top: 10,
                        child: CinCinSticker(
                          label: 'IL TUO EVENTO',
                          color: AppTheme.panna,
                          angle: 0.04,
                        ),
                      )
                    else if (showLastSeats)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: CinCinSticker(
                          label: freeSeats == 1
                              ? 'ULTIMO POSTO'
                              : 'ULTIMI $freeSeats POSTI',
                          angle: 0.06,
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatWhenLabel(context, offer.dataOra),
                        style: const TextStyle(
                          color: AppTheme.limone,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(offer.nomeLocale, style: textTheme.headlineSmall),
                      if (offer.cityLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          offer.cityLabel,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.lavanda,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.vellutoChiaro,
                            backgroundImage: authorPhotoUrl != null
                                ? NetworkImage(authorPhotoUrl)
                                : null,
                            child: authorPhotoUrl == null
                                ? const Icon(Icons.person, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Offre ${offer.autoreNome}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleSmall,
                                ),
                                if (offer.autoreRatingCount > 0)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 15,
                                        color: AppTheme.limone,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${offer.autoreRatingAverage.toStringAsFixed(1)} · ${offer.autoreRatingCount} recensioni',
                                        style: textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SeatDots(
                                  total: offer.postiTotali,
                                  free: freeSeats,
                                  size: 13,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  freeSeats == 0
                                      ? 'Al completo'
                                      : freeSeats == 1
                                          ? '1 posto libero'
                                          : '$freeSeats posti liberi',
                                  style: textTheme.titleSmall?.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canManageReminders) ...[
                            _CompactReminderButton(
                              offer: offer,
                              apiClient: apiClient,
                            ),
                            const SizedBox(width: 8),
                          ],
                          FilledButton(
                            onPressed: onOpen,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            child: const Text('Apri evento'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatWhenLabel(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(local.year, local.month, local.day);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: true,
    );

    if (eventDay == today) {
      return 'Oggi alle $time';
    }
    if (eventDay == today.add(const Duration(days: 1))) {
      return 'Domani alle $time';
    }
    final dateLabel =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
    return '$dateLabel - $time';
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

class _CompactReminderButton extends StatefulWidget {
  const _CompactReminderButton({
    required this.offer,
    required this.apiClient,
  });

  final Offer offer;
  final ApiClient apiClient;

  @override
  State<_CompactReminderButton> createState() => _CompactReminderButtonState();
}

class _CompactReminderButtonState extends State<_CompactReminderButton> {
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
          width: 46,
          height: 46,
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
            size: hasReminders ? 18 : 25,
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
                    ? AppTheme.orange.withValues(alpha: 0.38)
                    : const Color(0xFFFFD54F),
                labelStyle: TextStyle(
                  color: AppTheme.isDarkPalette ? AppTheme.espresso : null,
                  fontWeight: FontWeight.w700,
                ),
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

class _MealChip extends StatelessWidget {
  const _MealChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final Future<void> Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final mealColor = AppTheme.mealColor(value);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? mealColor : AppTheme.velluto,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onTap(value),
          child: Container(
            height: 44,
            padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppTheme.mealIcon(value),
                  size: 19,
                  color: selected ? AppTheme.onAccent : mealColor,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppTheme.onAccent : AppTheme.panna,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DistancePreferenceControl extends StatelessWidget {
  const _DistancePreferenceControl({
    required this.valueKm,
    required this.isSaving,
    required this.isExpanded,
    required this.distanceLabel,
    required this.onChanged,
    required this.onToggle,
    required this.onSave,
    required this.isDirty,
  });

  final int valueKm;
  final bool isSaving;
  final bool isExpanded;
  final String distanceLabel;
  final ValueChanged<double> onChanged;
  final VoidCallback onToggle;
  final Future<void> Function() onSave;
  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.velluto,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.radar_rounded,
                    color: AppTheme.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Visualizza eventi entro $distanceLabel',
                      style: const TextStyle(
                        color: AppTheme.espresso,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppTheme.brown,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.orange,
                inactiveTrackColor: AppTheme.cardBorder,
                thumbColor: AppTheme.orange,
                overlayColor: AppTheme.orange.withValues(alpha: 0.14),
                valueIndicatorColor: AppTheme.orange,
                valueIndicatorTextStyle: const TextStyle(
                  color: AppTheme.onAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Slider(
                min: OffersController.minRadiusKm.toDouble(),
                max: OffersController.maxRadiusKm.toDouble(),
                divisions: (OffersController.maxRadiusKm -
                    OffersController.minRadiusKm),
                value: valueKm
                    .clamp(
                      OffersController.minRadiusKm,
                      OffersController.maxRadiusKm,
                    )
                    .toDouble(),
                label: '$valueKm km',
                onChanged: isSaving ? null : onChanged,
              ),
            ),
            Row(
              children: [
                Text(
                  '${OffersController.minRadiusKm} km',
                  style: TextStyle(
                    color: AppTheme.brown.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${OffersController.maxRadiusKm} km',
                  style: TextStyle(
                    color: AppTheme.brown.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: isSaving || !isDirty ? null : onSave,
              child: Text(
                isSaving
                    ? 'Salvataggio...'
                    : (isDirty ? 'Salva distanza' : 'Distanza aggiornata'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
