import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/db/app_database.dart';
import '../../data/server_repository.dart';
import '../../data/settings_repository.dart';
import '../../l10n/l10n.dart';

class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> {
  static const String _githubRepoUrl =
      'https://github.com/SakuraLoveSmile/Sakura-Music';

  final TextEditingController _codeController = TextEditingController();
  bool _isActivatingCode = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _launchGitHubRepo() async {
    final uri = Uri.parse(_githubRepoUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleCodeActivation() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.activationCodeInvalid)),
      );
      return;
    }

    setState(() => _isActivatingCode = true);
    final success = await ref
        .read(membershipControllerProvider.notifier)
        .activateWithCode(code);
    if (!mounted) return;
    setState(() => _isActivatingCode = false);

    if (success) {
      _codeController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.activationSuccess)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.activationCodeInvalid)),
      );
    }
  }

  Future<void> _handleStarToggle(bool enabled) async {
    await ref
        .read(membershipControllerProvider.notifier)
        .setStarActivation(enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? context.l10n.activationSuccess
              : context.l10n.deactivatedSuccess,
        ),
      ),
    );
  }

  Future<void> _handleDeactivate() async {
    await ref.read(membershipControllerProvider.notifier).deactivate();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.deactivatedSuccess)));
  }

  @override
  Widget build(BuildContext context) {
    final activeServer = ref.watch(activeServerProvider);
    final serversAsync = ref.watch(serversProvider);
    final membership =
        ref.watch(membershipControllerProvider).value ??
        (active: false, method: null);
    final isActive = membership.active;
    final method = membership.method;

    return Scaffold(
      backgroundColor: const Color(0xFF131418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131418),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 28,
            color: Colors.white,
          ),
          tooltip: context.l10n.back,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: Text(
          context.l10n.myMembership,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          if (activeServer != null)
            PopupMenuButton<Server>(
              tooltip: context.l10n.switchLibrary,
              offset: const Offset(0, 40),
              color: const Color(0xFF22252E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (server) {
                ref.read(selectedServerIdProvider.notifier).state = server.id;
              },
              itemBuilder: (context) {
                final servers = serversAsync.value ?? <Server>[];
                return servers
                    .map(
                      (s) => PopupMenuItem<Server>(
                        value: s,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.album_rounded,
                              size: 16,
                              color: s.id == activeServer.id
                                  ? const Color(0xFF1E7BF6)
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s.name)),
                          ],
                        ),
                      ),
                    )
                    .toList();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2028),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.album_rounded,
                  size: 18,
                  color: Color(0xFF1E7BF6),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2028),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                size: 18,
                color: Colors.white70,
              ),
              tooltip: context.l10n.settings,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: () => context.go('/settings'),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2028),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: Colors.white70,
              ),
              tooltip: context.l10n.logout,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: () => context.go('/welcome'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: <Widget>[
              // Top VIP Aurora Banner
              _buildAuroraBanner(isActive: isActive, method: method),
              const SizedBox(height: 28),

              // 4 Feature Pillars in Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildFeatureIcon(
                    icon: Icons.auto_awesome_rounded,
                    label: context.l10n.featureAll,
                    color: const Color(0xFFFF2D55),
                  ),
                  _buildFeatureIcon(
                    icon: Icons.devices_rounded,
                    label: context.l10n.featureMultiDevice,
                    color: const Color(0xFFAF52DE),
                  ),
                  _buildFeatureIcon(
                    icon: Icons.sync_rounded,
                    label: context.l10n.featureUpdates,
                    color: const Color(0xFF0A84FF),
                  ),
                  _buildFeatureIcon(
                    icon: Icons.all_inclusive_rounded,
                    label: context.l10n.featureLifetime,
                    color: const Color(0xFFFF9500),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Status / Activation Area
              if (isActive)
                _buildActivatedCard(method: method)
              else ...<Widget>[
                _buildCodeActivationCard(),
                const SizedBox(height: 16),
                _buildStarActivationCard(),
              ],
              const SizedBox(height: 28),

              // Bottom Notice
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  context.l10n.membershipNote,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuroraBanner({required bool isActive, required String? method}) {
    String title;
    String subtitle;
    if (isActive) {
      title = context.l10n.membershipActiveBannerTitle;
      subtitle = switch (method) {
        'code' => context.l10n.activatedViaCode,
        'star' => context.l10n.activatedViaStar,
        _ => context.l10n.membershipActivated,
      };
    } else {
      title = context.l10n.activateMembership;
      subtitle = context.l10n.activateMembershipSubtitle;
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isActive
              ? const <Color>[
                  Color(0xFF8B3A14),
                  Color(0xFF5D2450),
                  Color(0xFF1E172B),
                ]
              : const <Color>[
                  Color(0xFF6B2B2B),
                  Color(0xFF3B1E38),
                  Color(0xFF20172B),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color:
                (isActive ? const Color(0xFFFF9500) : const Color(0xFFFF5E3A))
                    .withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          // Decorative glow overlays
          Positioned(
            left: -20,
            top: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF8A00).withValues(alpha: 0.25),
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFAF52DE).withValues(alpha: 0.2),
              ),
            ),
          ),

          // Main Text Content
          Positioned(
            left: 28,
            bottom: 28,
            right: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isActive) ...<Widget>[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFFFF9500),
                        size: 24,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivatedCard({required String? method}) {
    final isStarMethod = method == 'star';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF9500).withValues(alpha: 0.18),
            ),
            child: Icon(
              isStarMethod ? Icons.star_rounded : Icons.vpn_key_rounded,
              color: const Color(0xFFFF9500),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isStarMethod
                      ? context.l10n.activatedViaStar
                      : context.l10n.activatedViaCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.membershipLifetimeNote,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isStarMethod) ...<Widget>[
            IconButton(
              icon: const Icon(
                Icons.open_in_new_rounded,
                size: 20,
                color: Colors.white70,
              ),
              tooltip: context.l10n.goToStar,
              onPressed: _launchGitHubRepo,
            ),
            Switch(
              value: true,
              activeTrackColor: const Color(0xFFFF9500),
              onChanged: (value) {
                if (!value) {
                  _handleStarToggle(false);
                }
              },
            ),
          ] else ...<Widget>[
            TextButton(
              onPressed: _handleDeactivate,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: Text(
                context.l10n.deactivateMembership,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCodeActivationCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF2D55).withValues(alpha: 0.16),
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: Color(0xFFFF2D55),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.activationCodeTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _codeController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: context.l10n.activationCodeHint,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF131418),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF9500),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _handleCodeActivation(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _isActivatingCode ? null : _handleCodeActivation,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isActivatingCode
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        context.l10n.activateButton,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarActivationCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF9500).withValues(alpha: 0.16),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFF9500),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.starActivationTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.starActivationDesc,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _launchGitHubRepo,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(context.l10n.goToStar),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const Spacer(),
              Switch(
                value: false,
                activeTrackColor: const Color(0xFFFF9500),
                onChanged: (value) {
                  if (value) {
                    _handleStarToggle(true);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.16),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
