import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/core/auth/login/provider/login_provider.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class ProfileAccountPage extends ConsumerStatefulWidget {
  const ProfileAccountPage({super.key});

  @override
  ConsumerState<ProfileAccountPage> createState() => _ProfileAccountPageState();
}

class _ProfileAccountPageState extends ConsumerState<ProfileAccountPage> {
  Future<void> _editField(String title, String currentValue,
      Future<void> Function(String) onSave) async {
    final controller = TextEditingController(text: currentValue);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: MpColors.text, fontWeight: FontWeight.w500)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: MpColors.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: MpColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Lưu',
                style: TextStyle(
                    color: MpColors.blue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty || value == currentValue) return;
    try {
      await onSave(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _saveName(String newValue) async {
    final parts = newValue.trim().split(' ');
    final client = getIt<ITbClientService>().client;
    final user = ref.read(loginProvider).user;
    if (user == null) return;
    user.firstName = parts.first;
    user.lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    await client.getUserService().saveUser(user);
    await ref.read(loginProvider.notifier).loadUser();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(loginProvider).user;
    final firstName = user?.firstName ?? '';
    final lastName = user?.lastName ?? '';
    final fullName =
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final email = user?.email ?? '';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: MpColors.text),
        centerTitle: true,
        title: const Text(
          'Profile & Tài khoản',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: MpColors.text,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Avatar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: MpColors.violetSoft,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          color: MpColors.violet,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: MpColors.text,
                          shape: BoxShape.circle,
                          border: Border.all(color: MpColors.bg, width: 2),
                        ),
                        child: const Icon(Icons.edit,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  fullName.isNotEmpty ? fullName : 'Người dùng',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: MpColors.text,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(email,
                      style: const TextStyle(
                          fontSize: 13, color: MpColors.text3)),
                ],
              ],
            ),
          ),

          // ── Thông tin cá nhân ───────────────────────────────────────────
          _SectionLabel('THÔNG TIN CÁ NHÂN'),
          const SizedBox(height: 6),
          _InfoCard(children: [
            _EditableRow(
              label: 'Họ và tên',
              value: fullName.isNotEmpty ? fullName : '—',
              onTap: () => _editField('Họ và tên', fullName, _saveName),
            ),
            _EditableRow(
              label: 'Email',
              value: email.isNotEmpty ? email : '—',
              editable: false,
            ),
          ]),
          const SizedBox(height: 20),

          // ── Bảo mật ────────────────────────────────────────────────────
          _SectionLabel('BẢO MẬT'),
          const SizedBox(height: 6),
          _InfoCard(children: [
            _EditableRow(
              label: 'Đổi mật khẩu',
              value: '',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Tính năng đang phát triển'),
                    duration: Duration(seconds: 2)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.label,
    required this.value,
    this.editable = true,
    this.last = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool editable;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: editable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: MpColors.border, width: 0.5),
                ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: MpColors.text)),
            ),
            if (value.isNotEmpty)
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, color: MpColors.text3)),
            if (editable) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  size: 16, color: MpColors.text3),
            ],
          ],
        ),
      ),
    );
  }
}
