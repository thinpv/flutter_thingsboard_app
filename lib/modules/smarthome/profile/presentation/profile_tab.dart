import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/core/auth/login/provider/login_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/profile/presentation/home_management_page.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(selectedHomeProvider).valueOrNull;
    final initial = (home?.name ?? 'S')[0].toUpperCase();

    return Scaffold(
      backgroundColor: MpColors.bg,
      body: SafeArea(
        child: ListView(
          children: [
            // ── Avatar header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: MpColors.violetSoft,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: MpColors.violet,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          home?.name ?? 'SmartHome',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: MpColors.text,
                          ),
                        ),
                        const Text(
                          'Chủ nhà',
                          style: TextStyle(
                            fontSize: 13,
                            color: MpColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Section: Nhà ──────────────────────────────────────────────
            _SectionLabel(label: 'NHÀ'),
            _MpTile(
              icon: Icons.home_outlined,
              iconColor: MpColors.blue,
              iconTint: MpColors.blueSoft,
              title: 'Quản lý nhà',
              subtitle: 'Thêm, sửa, xóa nhà và phòng',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HomeManagementPage()),
              ),
            ),
            const SizedBox(height: 8),

            // ── Section: Tài khoản ────────────────────────────────────────
            _SectionLabel(label: 'TÀI KHOẢN'),
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
            child: const Text(
              'Đăng xuất',
              style: TextStyle(color: MpColors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(loginProvider.notifier).logout();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
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
    required this.icon,
    required this.iconColor,
    required this.iconTint,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconTint;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: MpColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: Row(
          children: [
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
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MpColors.text3,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: MpColors.text3,
            ),
          ],
        ),
      ),
    );
  }
}
