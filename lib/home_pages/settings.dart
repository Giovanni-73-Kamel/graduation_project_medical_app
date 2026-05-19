import 'dart:math';
import 'package:flutter/material.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/settings_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  bool _contactExpanded = false;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(-1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut),
    );
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _close() {
    _slideCtrl.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    // We get the provider passed via the constructor or look it up
    // Since we can't use Provider package, we use InheritedWidget approach
    // We'll get it from the SettingsScope
    final settings = SettingsScope.of(context);
    final isDark = settings.isDarkMode;

    final bgColor = isDark ? const Color(0xFF0F1923) : Colors.grey[100]!;
    final cardColor = isDark ? const Color(0xFF1A2A3A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2A3A);
    final subtextColor =
        isDark ? Colors.white.withOpacity(0.6) : Colors.grey[600]!;
    final dividerColor =
        isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Scrim (tap to close) ──────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: GestureDetector(
              onTap: _close,
              child: Container(color: Colors.black.withOpacity(0.45)),
            ),
          ),

          // ── Sliding panel ─────────────────────────────────────────────
          SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.82,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 30,
                        offset: const Offset(8, 0),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // ── Header ──────────────────────────────────────
                        _buildHeader(settings, textColor, isDark),

                        // ── Scrollable content ─────────────────────────
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Font size
                                _buildSectionLabel(settings.t('font_size'), Icons.text_fields,
                                    textColor, subtextColor),
                                const SizedBox(height: 10),
                                _buildFontSizeCard(
                                    settings, cardColor, textColor, subtextColor),

                                const SizedBox(height: 24),

                                // 2. Appearance
                                _buildSectionLabel(settings.t('appearance'), Icons.palette,
                                    textColor, subtextColor),
                                const SizedBox(height: 10),
                                _buildDarkModeCard(
                                    settings, cardColor, textColor, isDark),

                                const SizedBox(height: 24),

                                // 3. Contact us
                                _buildSectionLabel(settings.t('contact_us'),
                                    Icons.support_agent, textColor, subtextColor),
                                const SizedBox(height: 10),
                                _buildContactCard(cardColor, textColor,
                                    subtextColor, dividerColor, isDark),

                                const SizedBox(height: 24),

                                // 4. Language
                                _buildSectionLabel(settings.t('language'), Icons.translate,
                                    textColor, subtextColor),
                                const SizedBox(height: 10),
                                _buildLanguageCard(settings, cardColor,
                                    textColor, subtextColor, isDark),

                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(SettingsProvider settings, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      child: Row(
        children: [
          // Animated gear icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 2 * pi),
            duration: const Duration(seconds: 4),
            builder: (_, angle, child) {
              return Transform.rotate(angle: angle, child: child);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, const Color(0xFF26C6DA)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.settings, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            settings.t('settings'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Close button
          GestureDetector(
            onTap: _close,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.close_rounded, color: textColor, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SECTION LABEL
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSectionLabel(
      String label, IconData icon, Color textColor, Color subtextColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  1. FONT SIZE CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFontSizeCard(SettingsProvider settings, Color cardColor,
      Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Preview word
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 32 * settings.fontScale,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
            child: const Text('Health'),
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 12 * settings.fontScale,
              color: subtextColor,
              fontWeight: FontWeight.w500,
            ),
            child: Text(
                'Preview — scale ${(settings.fontScale * 100).toInt()}%'),
          ),
          const SizedBox(height: 18),
          // Slider
          Row(
            children: [
              Icon(Icons.text_decrease, size: 18, color: subtextColor),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.primary.withOpacity(0.15),
                    thumbColor: Colors.white,
                    overlayColor: AppColors.primary.withOpacity(0.12),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 10),
                    trackHeight: 5,
                  ),
                  child: Slider(
                    value: settings.fontScale,
                    min: 0.7,
                    max: 1.5,
                    divisions: 8,
                    onChanged: (v) {
                      setState(() => settings.fontScale = v);
                    },
                  ),
                ),
              ),
              Icon(Icons.text_increase, size: 18, color: subtextColor),
            ],
          ),
          // Quick buttons
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _fontQuickBtn('S', 0.8, settings, textColor),
              _fontQuickBtn('M', 1.0, settings, textColor),
              _fontQuickBtn('L', 1.2, settings, textColor),
              _fontQuickBtn('XL', 1.4, settings, textColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fontQuickBtn(
      String label, double scale, SettingsProvider settings, Color textColor) {
    final isActive = (settings.fontScale - scale).abs() < 0.05;
    return GestureDetector(
      onTap: () => setState(() => settings.fontScale = scale),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  2. DARK MODE CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDarkModeCard(
      SettingsProvider settings, Color cardColor, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon with animated background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                    : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0xFF3F51B5).withOpacity(0.3)
                      : const Color(0xFFFF9800).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) {
                return RotationTransition(
                  turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                );
              },
              child: Icon(
                isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                key: ValueKey(isDark),
                color: isDark ? const Color(0xFFBBDEFB) : const Color(0xFFFF9800),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDark ? settings.t('dark_mode') : settings.t('light_mode'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark ? settings.t('easy_on_eyes') : settings.t('bright_clean'),
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          // Custom animated toggle
          GestureDetector(
            onTap: () {
              setState(() => settings.isDarkMode = !settings.isDarkMode);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: 58,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1A2E), const Color(0xFF3F51B5)]
                      : [const Color(0xFFFFE0B2), const Color(0xFFFF9800)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF3F51B5).withOpacity(0.4)
                        : const Color(0xFFFF9800).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Stars / rays decoration
                  if (isDark) ...[
                    Positioned(
                      top: 6,
                      left: 8,
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Colors.white54,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        width: 2,
                        height: 2,
                        decoration: const BoxDecoration(
                          color: Colors.white38,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 6,
                      child: Container(
                        width: 2.5,
                        height: 2.5,
                        decoration: const BoxDecoration(
                          color: Colors.white30,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                  // Thumb
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    alignment:
                        isDark ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            isDark
                                ? Icons.nightlight_round
                                : Icons.wb_sunny_rounded,
                            key: ValueKey(isDark),
                            size: 14,
                            color: isDark
                                ? const Color(0xFF3F51B5)
                                : const Color(0xFFFF9800),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  3. CONTACT US CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildContactCard(Color cardColor, Color textColor,
      Color subtextColor, Color dividerColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tap header
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _contactExpanded = !_contactExpanded),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.headset_mic_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Get in Touch',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "We're here to help",
                          style: TextStyle(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _contactExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  Divider(color: dividerColor, height: 1),
                  const SizedBox(height: 16),
                  _contactRow(Icons.email_outlined, 'Email',
                      'support@healthapp.com', textColor, subtextColor),
                  const SizedBox(height: 12),
                  _contactRow(Icons.phone_outlined, 'Phone',
                      '+1 (800) 123-4567', textColor, subtextColor),
                  const SizedBox(height: 12),
                  _contactRow(Icons.language, 'Website',
                      'www.healthapp.com', textColor, subtextColor),
                  const SizedBox(height: 12),
                  _contactRow(Icons.location_on_outlined, 'Address',
                      'Coming soon...', textColor, subtextColor),
                ],
              ),
            ),
            crossFadeState: _contactExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value,
      Color textColor, Color subtextColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary.withOpacity(0.7)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: subtextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  4. LANGUAGE CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLanguageCard(SettingsProvider settings, Color cardColor,
      Color textColor, Color subtextColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ...SettingsProvider.supportedLanguages.map((lang) {
            final isSelected = settings.language == lang;
            final flagEmoji = _langFlag(lang);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => setState(() => settings.language = lang),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.grey[200]!),
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(flagEmoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          lang,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primary : textColor,
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: isSelected ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _langFlag(String lang) {
    switch (lang) {
      case 'English':
        return '🇺🇸';
      case 'العربية':
        return '🇸🇦';
      case 'Français':
        return '🇫🇷';
      case 'Español':
        return '🇪🇸';
      case 'Deutsch':
        return '🇩🇪';
      default:
        return '🌐';
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  INHERITED WIDGET to make SettingsProvider available down the tree
// ═════════════════════════════════════════════════════════════════════════════
class SettingsScope extends InheritedNotifier<SettingsProvider> {
  const SettingsScope({
    super.key,
    required SettingsProvider provider,
    required super.child,
  }) : super(notifier: provider);

  static SettingsProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found in widget tree');
    return scope!.notifier!;
  }
}
