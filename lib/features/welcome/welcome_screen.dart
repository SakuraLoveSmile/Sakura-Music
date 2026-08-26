import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/feature_cards.dart';
import 'widgets/privacy_policy_dialog.dart';
import 'widgets/server_picker_view.dart';
import '../../l10n/l10n.dart';
import 'widgets/server_sidebar.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isWelcomeSelected = true;
  int? _highlightServerId;
  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _openAddServerDialog() async {
    await context.push('/add-server');
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: const Color(0xFF111216),
      body: Row(
        children: <Widget>[
          if (isWide)
            ServerSidebar(
              isWelcomeSelected: _isWelcomeSelected,
              onSelectWelcome: () => setState(() => _isWelcomeSelected = true),
              onAddServer: _openAddServerDialog,
            ),
          Expanded(
            child: isWide
                ? SafeArea(
                    child: Column(
                      children: <Widget>[
                        // Top Header Bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                          child: Row(
                            children: <Widget>[
                              Text(
                                context.l10n.appName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2028),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.grid_view_rounded,
                                    size: 19,
                                    color: Colors.white70,
                                  ),
                                  tooltip: context.l10n.viewSwitch,
                                  onPressed: () {},
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2028),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.settings_outlined,
                                    size: 19,
                                    color: Colors.white70,
                                  ),
                                  tooltip: context.l10n.settings,
                                  onPressed: () => context.push('/settings'),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Main Content Scrollable Area
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 20,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 860,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    const SizedBox(height: 10),

                                    // Glowing Squircle App Icon
                                    const WelcomeAppLogo(size: 96),
                                    const SizedBox(height: 18),

                                    // App Title & Tagline
                                    Text(
                                      context.l10n.appName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      context.l10n.welcomeTagline,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 36),

                                    // Feature Cards Grid
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        if (constraints.maxWidth < 620) {
                                          // Single column for small displays
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: <Widget>[
                                              const MultiSourceCard(),
                                              const SizedBox(height: 14),
                                              const LosslessCard(),
                                              const SizedBox(height: 14),
                                              const NativeExperienceCard(),
                                              const SizedBox(height: 14),
                                              CrossPlatformBannerCard(
                                                onAddServer:
                                                    _openAddServerDialog,
                                              ),
                                            ],
                                          );
                                        }

                                        // Row of 3 cards + Full width banner
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                            const Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Expanded(
                                                  flex: 12,
                                                  child: MultiSourceCard(),
                                                ),
                                                SizedBox(width: 14),
                                                Expanded(
                                                  flex: 9,
                                                  child: LosslessCard(),
                                                ),
                                                SizedBox(width: 14),
                                                Expanded(
                                                  flex: 9,
                                                  child: NativeExperienceCard(),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 14),
                                            CrossPlatformBannerCard(
                                              onAddServer: _openAddServerDialog,
                                            ),
                                          ],
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 24),

                                    // Privacy Policy Footer
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        Text(
                                          context.l10n.privacyPrefix,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.4,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () =>
                                              PrivacyPolicyDialog.show(context),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                              vertical: 1,
                                            ),
                                            child: Text(
                                              context.l10n.privacyPolicy,
                                              style: const TextStyle(
                                                color: Color(0xFF0A84FF),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ServerPickerView(
                    onAddServer: _openAddServerDialog,
                    highlightServerId: _highlightServerId,
                  ),
          ),
        ],
      ),
    );
  }
}
