import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/activity/presentation/alarms_sub_tab.dart';
import 'package:thingsboard_app/modules/smarthome/activity/presentation/notifications_sub_tab.dart';
import 'package:thingsboard_app/modules/smarthome/activity/providers/alarms_provider.dart';
import 'package:thingsboard_app/modules/smarthome/activity/providers/notifications_provider.dart';

class ActivityTab extends ConsumerStatefulWidget {
  /// [initialTab]: 0 = Thông báo, 1 = Cảnh báo.
  /// Nếu null → dùng logic mặc định (Cảnh báo nếu có unack alarms).
  const ActivityTab({super.key, this.initialTab});
  final int? initialTab;

  @override
  ConsumerState<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<ActivityTab>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  bool _initialTabResolved = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab ?? 0,
    );
    // Nếu initialTab được chỉ định rõ → không để logic tự động override
    if (widget.initialTab != null) _initialTabResolved = true;
    WidgetsBinding.instance.addObserver(this);
    // Đảm bảo dữ liệu mới nhất khi mở màn hình (từ shell tab → push nav)
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Khi app từ background về foreground → refresh
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
    ref.invalidate(activeUnackAlarmsCountProvider);
    // Invalidate tất cả variants của family
    for (final p in AlarmPeriod.values) {
      ref.invalidate(alarmsProvider(p));
    }
  }

  /// Default tab logic: tab Cảnh báo nếu có alarm ACTIVE chưa ack, ngược lại
  /// tab Thông báo. Chỉ resolve 1 lần khi count đầu tiên load xong.
  void _maybeSetInitialTab(int unackAlarms) {
    if (_initialTabResolved) return;
    _initialTabResolved = true;
    final target = unackAlarms > 0 ? 1 : 0;
    if (_tabController.index != target) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabController.animateTo(target);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final unackAlarms = ref.watch(activeUnackAlarmsCountProvider);

    unackAlarms.whenData(_maybeSetInitialTab);

    return Scaffold(
      backgroundColor: MpColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
              child: Row(
                children: [
                  // Back button khi được push từ bell icon
                  if (Navigator.of(context).canPop())
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: MpColors.text),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  const Text(
                    'Hoạt động',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.22,
                      color: MpColors.text,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              decoration: BoxDecoration(
                color: MpColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MpColors.border, width: 0.5),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: MpColors.text,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(3),
                dividerColor: Colors.transparent,
                labelColor: MpColors.bg,
                unselectedLabelColor: MpColors.text2,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                tabs: [
                  _TabLabel(
                    label: 'Thông báo',
                    count: unreadCount.valueOrNull ?? 0,
                  ),
                  _TabLabel(
                    label: 'Cảnh báo',
                    count: unackAlarms.valueOrNull ?? 0,
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  NotificationsSubTab(),
                  AlarmsSubTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: MpColors.red,
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
