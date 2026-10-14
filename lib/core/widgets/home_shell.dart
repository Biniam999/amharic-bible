import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../features/settings/settings_providers.dart';
import '../../features/widget/daily_verse_sync.dart';
import '../../l10n/generated/app_localizations.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final keepScreenOn = ref.watch(appSettingsProvider.select((s) => s.keepScreenOn));
    return Scaffold(
      // Branch 1 is the Read tab (0 is Home).
      body: DailyVerseSync(
        child: _ScreenAwake(enabled: keepScreenOn && shell.currentIndex == 1, child: shell),
      ),
      bottomNavigationBar: HudNavBar(
        index: shell.currentIndex,
        // Tapping the active tab returns it to its root.
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: [
          HudNavItem(Icons.home_outlined, Icons.home_rounded, l10n.navHome),
          HudNavItem(Icons.menu_book_outlined, Icons.menu_book_rounded, l10n.navRead),
          HudNavItem(Icons.history_edu_outlined, Icons.history_edu_rounded, l10n.navCommentary),
          HudNavItem(Icons.bookmarks_outlined, Icons.bookmarks_rounded, l10n.navLibrary),
          HudNavItem(Icons.settings_outlined, Icons.settings_rounded, l10n.navSettings),
        ],
      ),
    );
  }
}

class HudNavItem {
  const HudNavItem(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Floating glass navigation pill with a glowing ring on the active tab.
class HudNavBar extends StatelessWidget {
  const HudNavBar({super.key, required this.index, required this.onTap, required this.items});

  final int index;
  final ValueChanged<int> onTap;
  final List<HudNavItem> items;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(30);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: dark ? const Color(0xFF1A5FD0).withValues(alpha: 0.22) : const Color(0x261A5FD0),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: dark
                        ? [const Color(0xE6101A30), const Color(0xE6060A14)]
                        : [const Color(0xF2FFFFFF), const Color(0xF2F0F5FE)],
                  ),
                  border: Border.all(
                    color: dark ? Colors.white.withValues(alpha: 0.09) : const Color(0xFFD5E2F7),
                  ),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _HudNavButton(
                          key: ValueKey('nav-$i'),
                          item: items[i],
                          selected: i == index,
                          onTap: () => onTap(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HudNavButton extends StatelessWidget {
  const _HudNavButton({super.key, required this.item, required this.selected, required this.onTap});

  final HudNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: selected ? 46 : 36,
              height: selected ? 34 : 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                color: selected ? scheme.primary.withValues(alpha: 0.16) : Colors.transparent,
                border: Border.all(color: selected ? scheme.primary.withValues(alpha: 0.55) : Colors.transparent),
                boxShadow: selected
                    ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: -2)]
                    : null,
              ),
              child: Icon(selected ? item.selectedIcon : item.icon, size: 22, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the screen on while [enabled] (the Read tab with the setting on).
/// Android/iOS release it automatically when the app goes to the background.
class _ScreenAwake extends StatefulWidget {
  const _ScreenAwake({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_ScreenAwake> createState() => _ScreenAwakeState();
}

class _ScreenAwakeState extends State<_ScreenAwake> {
  // The screen is not held on at launch, so nothing to do until enabled.
  bool _applied = false;

  void _apply() {
    if (_applied == widget.enabled) return;
    _applied = widget.enabled;
    WakelockPlus.toggle(enable: widget.enabled).ignore();
  }

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(_ScreenAwake oldWidget) {
    super.didUpdateWidget(oldWidget);
    _apply();
  }

  @override
  void dispose() {
    if (_applied) WakelockPlus.disable().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
