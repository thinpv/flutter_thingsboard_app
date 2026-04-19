import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/core/auth/login/provider/login_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/profile/presentation/home_management_page.dart';
import 'package:thingsboard_app/modules/smarthome/profile/presentation/profile_account_page.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(loginProvider).user;
    final home = ref.watch(selectedHomeProvider).valueOrNull;

    final firstName = user?.firstName ?? '';
    final lastName = user?.lastName ?? '';
    final fullName =
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final email = user?.email ?? '';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

    final homeName = home?.name ?? 'SmartHome';
    final homeInitial = homeName[0].toUpperCase();

    return Scaffold(
      backgroundColor: MpColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 20),
              child: Row(
                children: [
                  const Text(
                    'Cá nhân',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: MpColors.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // ── Owner card — tap → Profile & Tài khoản ──────────────────
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ProfileAccountPage()),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MpColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MpColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: MpColors.violetSoft,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: MpColors.violet,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: MpColors.text,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: MpColors.bg, width: 2),
                            ),
                            child: const Icon(Icons.edit,
                                size: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName.isNotEmpty ? fullName : 'Người dùng',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: MpColors.text,
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(email,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: MpColors.text3)),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 18, color: MpColors.text3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Ngôi nhà của tôi ─────────────────────────────────────────
            _SectionLabel('NGÔI NHÀ CỦA TÔI'),
            const SizedBox(height: 8),
            _MpTile(
              iconWidget: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: MpColors.violetSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  homeInitial,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: MpColors.violet,
                  ),
                ),
              ),
              title: homeName,
              subtitle: 'Quản lý phòng và thiết bị',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const HomeManagementPage()),
              ),
            ),
            const SizedBox(height: 24),

            // ── Ứng dụng ─────────────────────────────────────────────────
            _SectionLabel('ỨNG DỤNG'),
            const SizedBox(height: 8),
            _MpTile(
              icon: Icons.language_outlined,
              iconColor: MpColors.blue,
              iconTint: MpColors.blueSoft,
              title: 'Ngôn ngữ',
              subtitle: 'Tiếng Việt',
              onTap: () {},
            ),
            const SizedBox(height: 4),
            _MpTile(
              icon: Icons.help_outline,
              iconColor: MpColors.text2,
              iconTint: MpColors.surfaceAlt,
              title: 'Trợ giúp & Phản hồi',
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // ── Đăng xuất ────────────────────────────────────────────────
            _MpTile(
              icon: Icons.logout,
              iconColor: MpColors.red,
              iconTint: MpColors.redSoft,
              title: 'Đăng xuất',
              onTap: () => _logout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(color: MpColors.text, fontWeight: FontWeight.w500),
        ),
        content: const Text(
          'Bạn có muốn đăng xuất không?',
          style: TextStyle(color: MpColors.text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất',
                style: TextStyle(color: MpColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(loginProvider.notifier).logout();
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: MpColors.text3,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _MpTile extends StatelessWidget {
  const _MpTile({
    this.icon,
    this.iconColor,
    this.iconTint,
    this.iconWidget,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData? icon;
  final Color? iconColor;
  final Color? iconTint;
  final Widget? iconWidget;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: MpColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            iconWidget ??
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: iconColor),
                ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MpColors.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MpColors.text3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: MpColors.text3),
          ],
        ),
      ),
    );
  }
}
