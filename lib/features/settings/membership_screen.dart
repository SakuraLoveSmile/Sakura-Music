import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../data/server_repository.dart';

class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> {
  bool _isTrialActive = true;
  static const int _remainingDays = 25;

  @override
  Widget build(BuildContext context) {
    final activeServer = ref.watch(activeServerProvider);
    final serversAsync = ref.watch(serversProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF131418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131418),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28, color: Colors.white),
          tooltip: '返回',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: const Text(
          '我的会员',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          if (activeServer != null)
            PopupMenuButton<Server>(
              tooltip: '切换音乐库',
              offset: const Offset(0, 40),
              color: const Color(0xFF22252E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                child: const Icon(Icons.album_rounded, size: 18, color: Color(0xFF1E7BF6)),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2028),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, size: 18, color: Colors.white70),
              tooltip: '设置',
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
              icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white70),
              tooltip: '退出登录',
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
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: <Color>[
                      Color(0xFF6B2B2B),
                      Color(0xFF3B1E38),
                      Color(0xFF20172B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFFF5E3A).withValues(alpha: 0.2),
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
                          const Text(
                            '公测试用中',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '公测剩余 $_remainingDays 天，期间可试用全部会员功能',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 4 Feature Pillars in Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildFeatureIcon(
                    icon: Icons.auto_awesome_rounded,
                    label: '全功能',
                    color: const Color(0xFFFF2D55),
                  ),
                  _buildFeatureIcon(
                    icon: Icons.devices_rounded,
                    label: '多设备',
                    color: const Color(0xFFAF52DE),
                  ),
                  _buildFeatureIcon(
                    icon: Icons.sync_rounded,
                    label: '持续更新',
                    color: const Color(0xFF0A84FF),
                  ),
                  _buildFeatureIcon(
                    icon: Icons.all_inclusive_rounded,
                    label: '终身有效',
                    color: const Color(0xFFFF9500),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Status Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1C22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
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
                      child: const Icon(
                        Icons.access_time_filled_rounded,
                        color: Color(0xFFFF9500),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _isTrialActive ? '公测试用剩余 $_remainingDays 天' : '已取消试用',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '购买后将永久享有会员资格。',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isTrialActive = !_isTrialActive;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isTrialActive ? '已恢复公测试用' : '已取消公测试用'),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      child: Text(
                        _isTrialActive ? '取消试用' : '重新开启',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Bottom Notice
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '1. 会员最多可同时在 7 台装置上登录。',
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
