import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/scene_image.dart';
import '../../core/widgets/scenic_background.dart';
import '../../l10n/generated/app_localizations.dart';
import 'profile_providers.dart';

/// First launch only: painted landscape, glowing cross, the app name,
/// a name field and "Get started". No account, nothing leaves the phone.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canStart => _name.text.trim().isNotEmpty && !_saving;

  Future<void> _start() async {
    if (!_canStart) return;
    setState(() => _saving = true);
    FocusScope.of(context).unfocus();
    await ref.read(userProfileProvider.notifier).completeOnboarding(_name.text);
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1430),
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const SceneImage(AppImages.welcome, fallback: SceneVariant.dawn, alignment: Alignment(0.2, 0)),
            // Keeps the title and the name field readable on any photo.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.05),
                    const Color(0xFF020409).withValues(alpha: 0.55),
                    const Color(0xFF020409).withValues(alpha: 0.92),
                  ],
                  stops: const [0, 0.35, 0.7, 1],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: keyboard),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          SizedBox(height: box.maxHeight * 0.12),
                          const _FadeUp(delay: 0, child: GlowingCross(size: 70)),
                          const SizedBox(height: 26),
                          _FadeUp(
                            delay: 150,
                            child: Text(
                              l10n.welcomeTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: AppFonts.abyssinica,
                                fontFamilyFallback: [AppFonts.sansLatin],
                                color: Colors.white,
                                fontSize: 44,
                                height: 1.2,
                                shadows: [Shadow(color: Color(0x887FD3FF), blurRadius: 24)],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _FadeUp(
                            delay: 280,
                            child: Text(
                              l10n.welcomeSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14,
                                letterSpacing: 2.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(height: box.maxHeight * 0.30),
                          _FadeUp(
                            delay: 420,
                            child: GlassCard(
                              forceDark: true,
                              radius: 20,
                              padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
                              child: Row(
                                children: [
                                  Text(
                                    '${l10n.yourName}:',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 15),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _name,
                                      textCapitalization: TextCapitalization.words,
                                      textInputAction: TextInputAction.done,
                                      maxLength: 40,
                                      onSubmitted: (_) => _start(),
                                      cursorColor: const Color(0xFF7FD3FF),
                                      style: const TextStyle(color: Colors.white, fontSize: 17),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        counterText: '',
                                        hintText: l10n.nameHint,
                                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _FadeUp(
                            delay: 520,
                            child: GlowPillButton(label: l10n.getStarted, onPressed: _canStart ? _start : null),
                          ),
                          const SizedBox(height: 18),
                          _FadeUp(
                            delay: 600,
                            child: Text(
                              l10n.welcomePrivacy,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12.5),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and slides a child up once, after [delay] ms.
class _FadeUp extends StatefulWidget {
  const _FadeUp({required this.delay, required this.child});

  final int delay;
  final Widget child;

  @override
  State<_FadeUp> createState() => _FadeUpState();
}

class _FadeUpState extends State<_FadeUp> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 200 + widget.delay), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      opacity: _shown ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        offset: _shown ? Offset.zero : const Offset(0, 0.15),
        child: widget.child,
      ),
    );
  }
}
