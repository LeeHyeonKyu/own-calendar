import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../themes/tokens.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(title: const Text('테마')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Theme mode toggle ──
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '모드',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('라이트'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_brightness_outlined),
                label: Text('시스템'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('다크'),
              ),
            ],
            selected: {themeProvider.themeMode},
            onSelectionChanged: (modes) {
              themeProvider.setThemeMode(modes.first);
            },
          ),

          const SizedBox(height: 24),

          // ── Theme presets grid ──
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '컬러 테마',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: themePresets.length,
            itemBuilder: (context, index) {
              final preset = themePresets[index];
              final isSelected = themeProvider.currentPreset == preset.id;
              final tokens = brightness == Brightness.light
                  ? preset.light
                  : preset.dark;

              return _ThemePresetCard(
                preset: preset,
                tokens: tokens,
                isSelected: isSelected,
                onTap: () => themeProvider.setPreset(preset.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemePresetCard extends StatelessWidget {
  final ThemePresetInfo preset;
  final CalendarThemeTokens tokens;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePresetCard({
    required this.preset,
    required this.tokens,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: tokens.surfacePrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? tokens.accentPrimary
                : tokens.gridBorder,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: tokens.accentPrimary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 9.5 : 11),
          child: Column(
            children: [
              // Mini calendar preview
              Expanded(child: _MiniCalendarPreview(tokens: tokens)),
              // Preset name
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceSecondary,
                  border: Border(
                    top: BorderSide(color: tokens.gridBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: tokens.accentPrimary,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tiny calendar month preview showing the theme's colors in context.
class _MiniCalendarPreview extends StatelessWidget {
  final CalendarThemeTokens tokens;

  const _MiniCalendarPreview({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.surfacePrimary,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month header
          Row(
            children: [
              Text(
                '9월',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: tokens.accentPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Day labels row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['일', '월', '화', '수', '목', '금', '토']
                .map((d) => SizedBox(
                      width: 14,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w500,
                          color: tokens.textTertiary,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 2),

          // Calendar grid (2 rows of days)
          ...List.generate(3, (row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (col) {
                  final dayNum = row * 7 + col + 1;
                  final isToday = dayNum == 9;
                  final hasEvent = dayNum == 5 || dayNum == 12 || dayNum == 15;

                  if (dayNum > 21) {
                    return const SizedBox(width: 14, height: 14);
                  }

                  return SizedBox(
                    width: 14,
                    height: 14,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isToday)
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: tokens.accentToday,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w400,
                            color: isToday
                                ? Colors.white
                                : tokens.textPrimary,
                          ),
                        ),
                        if (hasEvent)
                          Positioned(
                            bottom: 0,
                            child: Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: tokens.eventColors[
                                    dayNum % tokens.eventColors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            );
          }),

          const Spacer(),

          // Sample event bars
          ...[0, 2, 4].map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: tokens.eventColors[i % tokens.eventColors.length]
                        .withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 20 + (i * 5).toDouble(),
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
