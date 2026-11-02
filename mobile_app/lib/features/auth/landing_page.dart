import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_wordmark.dart';
import '../../core/widgets/cin_cin_widgets.dart';
import '../../models/offer.dart';
import 'auth_controller.dart';
import 'login_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({
    super.key,
    required this.authController,
    this.autoOpenLogin = false,
    this.showLoginButton = true,
  });

  final AuthController authController;
  final bool autoOpenLogin;
  final bool showLoginButton;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late Future<List<Offer>> _offersFuture;
  bool _didAutoOpenLogin = false;

  @override
  void initState() {
    super.initState();
    _offersFuture = widget.authController.apiClient.fetchOffers(limit: 20);
    _scheduleAutoLoginIfNeeded();
  }

  @override
  void didUpdateWidget(covariant LandingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoOpenLogin && !oldWidget.autoOpenLogin) {
      _didAutoOpenLogin = false;
      _scheduleAutoLoginIfNeeded();
    }
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(
          authController: widget.authController,
        ),
      ),
    );
  }

  void _scheduleAutoLoginIfNeeded() {
    if (!widget.autoOpenLogin || _didAutoOpenLogin) {
      return;
    }
    _didAutoOpenLogin = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _openLogin();
    });
  }

  Future<void> _reloadOffers() async {
    final future = widget.authController.apiClient.fetchOffers(limit: 20);
    setState(() {
      _offersFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppTheme.notte,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reloadOffers,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: BrandWordmark(
                              height: 44,
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                          if (widget.showLoginButton)
                            TextButton(
                              onPressed: _openLogin,
                              child: const Text('Accedi'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _LandingPhotoCluster(),
                      const SizedBox(height: 26),
                      Text.rich(
                        const TextSpan(
                          children: [
                            TextSpan(text: 'Tu offri,\n'),
                            TextSpan(
                              text: 'io approfitto.',
                              style: TextStyle(color: AppTheme.lampone),
                            ),
                          ],
                        ),
                        style: textTheme.displaySmall?.copyWith(
                          fontSize: 44,
                          height: 0.98,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Nuove persone, tavoli veri, pasti condivisi davvero. ApprofittOffro mette insieme chi offre un pasto e chi vuole viverlo con leggerezza, con profili reali.',
                        style: textTheme.bodyLarge,
                      ),
                      if (widget.showLoginButton) ...[
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _openLogin,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            textStyle: const TextStyle(
                              fontFamily: AppTheme.textFont,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('Entra nel giro'),
                        ),
                      ],
                      const SizedBox(height: 36),
                      const _LandingSectionHeading(
                        eyebrow: 'COME FUNZIONA',
                        title: 'Tre passi e sei a tavola',
                      ),
                      const SizedBox(height: 14),
                      const _LandingStepCard(
                        number: 1,
                        accent: AppTheme.spritz,
                        title: 'Scopri chi c\'è in giro',
                        body:
                            'Apri Approfitta e guarda colazioni, aperitivi, pranzi e cene pubblicati dalla community.',
                      ),
                      const _LandingStepCard(
                        number: 2,
                        accent: AppTheme.lampone,
                        title: 'Entra nei profili veri',
                        body:
                            'Da Community puoi vedere foto, età, città e scegliere chi seguire davvero.',
                      ),
                      const _LandingStepCard(
                        number: 3,
                        accent: AppTheme.limone,
                        title: 'Iscriviti per partecipare',
                        body:
                            'Se un evento ti piace, crei il tuo account, entri nella community e poi approfitti davvero.',
                      ),
                      if (widget.showLoginButton) ...[
                        const SizedBox(height: 30),
                        const _LandingSectionHeading(
                          eyebrow: 'EVENTI APERTI',
                          title: 'Cosa aspetti, approfitta.',
                        ),
                        const SizedBox(height: 14),
                        FutureBuilder<List<Offer>>(
                          future: _offersFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return const _LandingNoticeCard(
                                message:
                                    'Non riesco a caricare gli eventi aperti in questo momento.',
                              );
                            }

                            final offers = (snapshot.data ?? const <Offer>[])
                                .where(
                                  (offer) =>
                                      offer.claimStatus == 'open' &&
                                      offer.canClaim,
                                )
                                .take(4)
                                .toList();
                            if (offers.isEmpty) {
                              return const _LandingNoticeCard(
                                message:
                                    'Per ora non vedo ancora eventi pubblici aperti.',
                              );
                            }

                            return Column(
                              children: offers
                                  .map(
                                    (offer) => _PublicOfferCard(
                                      offer: offer,
                                      apiClient:
                                          widget.authController.apiClient,
                                      onTap: _openLogin,
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 30),
                      const _LandingInfoCard(
                        title: 'ApprofittOffro Card',
                        body:
                            'Presto avrai la possibilità di aderire alla Community Card e con la tessera socio avrai diritto a sconti esclusivi nei locali che preferisci.',
                        highlighted: true,
                      ),
                      const SizedBox(height: 30),
                      const _LandingSectionHeading(
                        eyebrow: 'VISIONE',
                        title: 'Perché nasce ApprofittOffro',
                      ),
                      const SizedBox(height: 14),
                      const _LandingInfoCard(
                        title: 'Più community, meno rumore',
                        body:
                            'L\'idea non è collezionare prenotazioni: è creare un giro di persone che si riconoscono e tornano.',
                      ),
                      const _LandingInfoCard(
                        title: 'Profili, follower e fiducia',
                        body:
                            'Segui le persone che ti piacciono, guarda i loro profili e tieni vivi i contatti migliori.',
                      ),
                      if (widget.showLoginButton) ...[
                        const SizedBox(height: 24),
                        OutlinedButton(
                          onPressed: _openLogin,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                          child: const Text('Accedi / Iscriviti'),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingSectionHeading extends StatelessWidget {
  const _LandingSectionHeading({
    required this.eyebrow,
    required this.title,
  });

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CinCinSticker(label: eyebrow, angle: -0.04),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 27,
              ),
        ),
      ],
    );
  }
}

class _LandingPhotoCluster extends StatefulWidget {
  const _LandingPhotoCluster();

  @override
  State<_LandingPhotoCluster> createState() => _LandingPhotoClusterState();
}

class _LandingPhotoClusterState extends State<_LandingPhotoCluster>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = math.min(width * 0.92, 360.0);
        return SizedBox(
          height: height,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress =
                  reduceMotion ? 0.0 : _controller.value * 2 * math.pi;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: width * 0.02,
                    top: height * 0.08 + math.sin(progress) * 6,
                    child: _FloatingPhotoCard(
                      assetPath: 'assets/landing/hero-aperitivo.jpg',
                      width: width * 0.5,
                      height: height * 0.62,
                      angle: -0.12,
                      borderColor: AppTheme.spritz,
                    ),
                  ),
                  Positioned(
                    right: width * 0.01,
                    top: math.sin(progress + 1.7) * 7,
                    child: _FloatingPhotoCard(
                      assetPath: 'assets/landing/hero-brunch.jpg',
                      width: width * 0.46,
                      height: height * 0.54,
                      angle: 0.1,
                      borderColor: AppTheme.lampone,
                    ),
                  ),
                  Positioned(
                    left: width * 0.28,
                    bottom: height * 0.02 + math.sin(progress + 3.2) * 6,
                    child: _FloatingPhotoCard(
                      assetPath: 'assets/landing/hero-dinner.jpg',
                      width: width * 0.6,
                      height: height * 0.42,
                      angle: -0.035,
                      borderColor: AppTheme.limone,
                    ),
                  ),
                  Positioned(
                    left: width * 0.04,
                    bottom: height * 0.12,
                    child: const CinCinSticker(
                      label: 'cin cin!',
                      color: AppTheme.lampone,
                      angle: -0.16,
                      fontSize: 18,
                    ),
                  ),
                  Positioned(
                    right: width * 0.02,
                    top: height * 0.5,
                    child: const CinCinSticker(
                      label: 'POSTI LIBERI',
                      angle: 0.12,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _FloatingPhotoCard extends StatelessWidget {
  const _FloatingPhotoCard({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.angle,
    required this.borderColor,
  });

  final String assetPath;
  final double width;
  final double height;
  final double angle;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: borderColor,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _LandingStepCard extends StatelessWidget {
  const _LandingStepCard({
    required this.number,
    required this.accent,
    required this.title,
    required this.body,
  });

  final int number;
  final Color accent;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.velluto,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: AppTheme.onAccent,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingInfoCard extends StatelessWidget {
  const _LandingInfoCard({
    required this.title,
    required this.body,
    this.highlighted = false,
  });

  final String title;
  final String body;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.velluto,
        borderRadius: BorderRadius.circular(28),
        border: highlighted
            ? Border.all(
                color: AppTheme.lampone.withValues(alpha: 0.7),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlighted) ...[
            const CinCinSticker(label: 'PRESTO', angle: -0.05),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              fontSize: highlighted ? 25 : 20,
              color: AppTheme.panna,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
              color: AppTheme.lavandaChiara,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingNoticeCard extends StatelessWidget {
  const _LandingNoticeCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.velluto,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PublicOfferCard extends StatelessWidget {
  const _PublicOfferCard({
    required this.offer,
    required this.apiClient,
    required this.onTap,
  });

  final Offer offer;
  final ApiClient apiClient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final photoFilename = offer.coverPhotoFilename;
    final photoUrl =
        photoFilename != null ? apiClient.buildUploadUrl(photoFilename) : null;
    final authorPhotoUrl = offer.autoreFoto.isNotEmpty
        ? apiClient.buildUploadUrl(offer.autoreFoto)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppTheme.velluto,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OfferPhoto(
                  imageUrl: photoUrl,
                  tipoPasto: offer.tipoPasto,
                  height: 140,
                  overlay: [
                    Positioned(
                      left: 10,
                      top: 10,
                      child: MealSticker(tipoPasto: offer.tipoPasto),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatWhenLabel(offer.dataOra),
                        style: const TextStyle(
                          color: AppTheme.limone,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(offer.nomeLocale, style: textTheme.headlineSmall),
                      if (offer.indirizzo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          offer.indirizzo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.lavanda,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.vellutoChiaro,
                            backgroundImage: authorPhotoUrl != null
                                ? NetworkImage(authorPhotoUrl)
                                : null,
                            child: authorPhotoUrl == null
                                ? const Icon(Icons.person, size: 18)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Offre ${offer.autoreNome}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: onTap,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            child: const Text('Approfitta'),
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

  String _formatWhenLabel(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(local.year, local.month, local.day);
    final time = DateFormat('HH:mm').format(local);

    if (eventDay == today) {
      return 'Oggi alle $time';
    }
    if (eventDay == today.add(const Duration(days: 1))) {
      return 'Domani alle $time';
    }
    return DateFormat('dd/MM - HH:mm').format(local);
  }
}
