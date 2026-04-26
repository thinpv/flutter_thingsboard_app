import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';

class SmartHomeShell extends StatefulWidget {
  const SmartHomeShell({
    required this.navigationShell,
    required this.branchNavKeys,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<GlobalKey<NavigatorState>> branchNavKeys;

  @override
  State<SmartHomeShell> createState() => _SmartHomeShellState();
}

class _SmartHomeShellState extends State<SmartHomeShell> {
  /// Timestamp of the last back-press at the tab root. Two back-presses
  /// within [_exitWindow] exit the app; a single press just shows a hint.
  DateTime? _lastBackPressAt;
  static const _exitWindow = Duration(seconds: 2);

  void _handleBackInvoked() {
    final now = DateTime.now();
    if (_lastBackPressAt != null &&
        now.difference(_lastBackPressAt!) < _exitWindow) {
      // Second press within the window — leave the app. SystemNavigator.pop
      // is the equivalent of the OS back gesture finishing the activity on
      // Android; on iOS it's a no-op (Apple HIG forbids programmatic exit),
      // which is the expected behaviour there anyway.
      SystemNavigator.pop();
      return;
    }
    _lastBackPressAt = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Nhấn lần nữa để thoát mHome',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        duration: _exitWindow,
        behavior: SnackBarBehavior.floating,
        // ~60% black for the soft translucent toast look (Android-style).
        backgroundColor: Color(0x99000000),
        elevation: 0,
        // Fixed width auto-centers the snackbar horizontally and gives the
        // pill-shape feel instead of stretching edge-to-edge.
        width: 240,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // We always block the system pop and decide ourselves whether to exit.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackInvoked();
      },
      child: Scaffold(
        backgroundColor: MpColors.bg,
        body: widget.navigationShell,
        bottomNavigationBar: _MpBottomNav(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: (index) {
            if (index != widget.navigationShell.currentIndex) {
              // Pop all sub-screens in the current tab before switching so
              // returning to any tab always shows its root screen.
              widget.branchNavKeys[widget.navigationShell.currentIndex]
                  .currentState
                  ?.popUntil((route) => route.isFirst);
            }
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
        ),
      ),
    );
  }
}

class _MpBottomNav extends StatelessWidget {
  const _MpBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MpColors.bg,
        border: Border(top: BorderSide(color: MpColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Nhà',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.auto_awesome_outlined,
                activeIcon: Icons.auto_awesome,
                label: 'Thông minh',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Cá nhân',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 22,
                  color: selected ? MpColors.text : MpColors.text3,
                ),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: MpColors.red,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: MpColors.bg, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      alignment: Alignment.center,
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? MpColors.text : MpColors.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
