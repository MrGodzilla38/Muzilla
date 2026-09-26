import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoShuffle = false;
  bool _gapless = true;
  bool _crossfade = true;
  bool _sleepTimer = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.marginMobile,
                  AppSpacing.sm,
                  AppSpacing.marginMobile,
                  AppSpacing.lg,
                ),
                children: [
                  _SectionCard(
                    title: 'ÇALMA',
                    children: [
                      _SwitchRow(
                        icon: Icons.shuffle_rounded,
                        label: 'Otomatik karıştır',
                        value: _autoShuffle,
                        onChanged: (v) => setState(() => _autoShuffle = v),
                      ),
                      _SwitchRow(
                        icon: Icons.queue_music_rounded,
                        label: 'Kesintisiz çalma',
                        value: _gapless,
                        onChanged: (v) => setState(() => _gapless = v),
                      ),
                      _SwitchRow(
                        icon: Icons.blur_on_rounded,
                        label: 'Geçiş efektleri',
                        value: _crossfade,
                        onChanged: (v) => setState(() => _crossfade = v),
                      ),
                      _SwitchRow(
                        icon: Icons.nightlight_round,
                        label: 'Uyku zamanlayıcı',
                        value: _sleepTimer,
                        onChanged: (v) => setState(() => _sleepTimer = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: 'SES',
                    children: const [
                      _ValueRow(
                        icon: Icons.graphic_eq_rounded,
                        label: 'Ekolayzır',
                        value: 'Dengeli',
                      ),
                      _ValueRow(
                        icon: Icons.high_quality_rounded,
                        label: 'Çalma kalitesi',
                        value: 'Yüksek',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: 'HAKKINDA',
                    children: const [
                      _ValueRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Sürüm',
                        value: '1.0.0',
                      ),
                      _ValueRow(
                        icon: Icons.music_note_rounded,
                        label: 'Uygulama',
                        value: 'Muzilla',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        AppSpacing.sm,
        AppSpacing.marginMobile,
        0,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('Ayarlar', style: AppTextStyles.headlineSm),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Text(title, style: AppTextStyles.labelMd),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RowShell extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  const _RowShell({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMd.copyWith(color: AppColors.textHighContrast)),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: icon,
      label: label,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.surfaceContainerHigh,
        activeThumbColor: AppColors.textHighContrast,
        inactiveThumbColor: AppColors.textMuted,
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ValueRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: icon,
      label: label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted)),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
