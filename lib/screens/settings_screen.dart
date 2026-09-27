import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Cihaz EQ bilgisi gelene kadar varsayılan frekans etiketleri gösterilir.
  static const List<double> _defaultBandFrequencies = <double>[
    60,
    230,
    910,
    3600,
    14000,
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

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
                        value: settings.autoShuffle,
                        onChanged: notifier.setAutoShuffle,
                      ),
                      _SwitchRow(
                        icon: Icons.queue_music_rounded,
                        label: 'Kesintisiz çalma',
                        value: settings.gapless,
                        onChanged: notifier.setGapless,
                      ),
                      _SwitchRow(
                        icon: Icons.blur_on_rounded,
                        label: 'Geçiş efektleri',
                        value: settings.crossfade,
                        onChanged: notifier.setCrossfade,
                      ),
                      _ValueRow(
                        icon: Icons.nightlight_round,
                        label: 'Uyku zamanlayıcı',
                        value: _sleepLabel(settings),
                        onTap: _showSleepTimerDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: 'SES',
                    children: [
                      _ValueRow(
                        icon: Icons.graphic_eq_rounded,
                        label: 'Ekolayzır',
                        value: settings.equalizerPresetLabel,
                        onTap: _showEqualizerSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SectionCard(
                    title: 'HAKKINDA',
                    children: [
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

  String _sleepLabel(SettingsState settings) {
    switch (settings.sleepMode) {
      case SleepTimerMode.off:
        return 'Kapalı';
      case SleepTimerMode.songEnd:
        return 'Şarkı sonunda';
      case SleepTimerMode.timed:
        final minutes = settings.sleepMinutes;
        final prefix = minutes != null ? '$minutes dk' : 'Zamanlayıcı';
        return '$prefix · ${_formatClock(settings.sleepRemaining)}';
    }
  }

  String _formatClock(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _showSleepTimerDialog() {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final groupValue = settings.sleepMode == SleepTimerMode.timed
        ? (settings.sleepMinutes?.toString() ?? 'timed')
        : settings.sleepMode.name;

    const options = <(String, String)>[
      ('off', 'Kapalı'),
      ('15', '15 dakika'),
      ('30', '30 dakika'),
      ('45', '45 dakika'),
      ('60', '60 dakika'),
      ('songEnd', 'Şarkı sonunda'),
    ];

    void select(String value) {
      Navigator.of(context).pop();
      if (value == 'off') {
        notifier.clearSleepTimer();
      } else if (value == 'songEnd') {
        notifier.setSleepTimerOnSongEnd();
      } else {
        notifier.setSleepTimerDuration(int.parse(value));
      }
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDeep,
          title: Text('Uyku zamanlayıcı', style: AppTextStyles.headlineSm),
          content: RadioGroup<String>(
            groupValue: groupValue,
            onChanged: (next) {
              if (next != null) {
                select(next);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (value, label) in options)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      label,
                      style: AppTextStyles.bodyMd
                          .copyWith(color: AppColors.textHighContrast),
                    ),
                    value: value,
                    activeColor: AppColors.primary,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Vazgeç',
                style: AppTextStyles.labelLg
                    .copyWith(color: AppColors.secondary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEqualizerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceDeep,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final settings = ref.watch(settingsProvider);
                final notifier = ref.read(settingsProvider.notifier);
                return FutureBuilder<AndroidEqualizerParameters>(
                  future: ref
                      .read(playerProvider.notifier)
                      .equalizerParameters,
                  builder: (context, snapshot) {
                    final parameters = snapshot.data;
                    final bandCount = parameters?.bands.length ?? 5;
                    final bands = settings.bandsFor(bandCount);

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Ekolayzır',
                                  style: AppTextStyles.headlineSm,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final preset in equalizerPresets)
                                _presetChip(
                                  label: preset.label,
                                  selected: settings.equalizerPresetId ==
                                      preset.id,
                                  onTap: () => notifier
                                      .setEqualizerPreset(preset.id),
                                ),
                              _presetChip(
                                label: 'Özel',
                                selected: settings.equalizerPresetId ==
                                    customEqualizerPresetId,
                                onTap: () => notifier
                                    .setEqualizerBands(bands),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (parameters == null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Text(
                                'Ekolayzır ilk şarkı çalınca etkinleşir.',
                                style: AppTextStyles.bodySm,
                              ),
                            ),
                          for (var i = 0; i < bandCount; i++)
                            _BandSlider(
                              label: _bandLabel(i, parameters),
                              value: i < bands.length
                                  ? bands[i].clamp(-1.0, 1.0)
                                  : 0.0,
                              gainLabel: parameters == null
                                  ? null
                                  : _formatGain(
                                      bands[i],
                                      parameters.minDecibels,
                                      parameters.maxDecibels,
                                    ),
                              onChanged: (next) {
                                final updated = List<double>.from(bands);
                                updated[i] = next;
                                notifier.setEqualizerBands(updated);
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _presetChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLg.copyWith(
            color: selected
                ? AppColors.textHighContrast
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  String _bandLabel(int index, AndroidEqualizerParameters? parameters) {
    if (parameters == null) {
      if (index < _defaultBandFrequencies.length) {
        return _formatFrequency(_defaultBandFrequencies[index]);
      }
      return 'Bant ${index + 1}';
    }
    if (index < parameters.bands.length) {
      return _formatFrequency(parameters.bands[index].centerFrequency);
    }
    return 'Bant ${index + 1}';
  }

  String _formatFrequency(double hertz) {
    if (hertz >= 1000) {
      final kiloHertz = hertz / 1000;
      final text = kiloHertz == kiloHertz.roundToDouble()
          ? kiloHertz.round().toString()
          : kiloHertz.toStringAsFixed(1);
      return '$text kHz';
    }
    return '${hertz.round()} Hz';
  }

  String _formatGain(double normalized, double minDecibels, double maxDecibels) {
    final gain = normalized >= 0
        ? normalized * maxDecibels
        : normalized * minDecibels.abs();
    final rounded = gain.toStringAsFixed(1);
    return gain > 0 ? '+$rounded dB' : '$rounded dB';
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
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(title, style: AppTextStyles.labelMd),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: AppColors.outlineVariant.withValues(alpha: 0.4),
                  ),
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
  final VoidCallback? onTap;
  const _RowShell({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMd
                  .copyWith(color: AppColors.textHighContrast),
            ),
          ),
          trailing,
        ],
      ),
    );
    if (onTap == null) {
      return row;
    }
    return InkWell(onTap: onTap, child: row);
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
  final VoidCallback? onTap;
  const _ValueRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: icon,
      label: label,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final String label;
  final double value;
  final String? gainLabel;
  final ValueChanged<double> onChanged;
  const _BandSlider({
    required this.label,
    required this.value,
    required this.gainLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppTextStyles.bodySm),
            const Spacer(),
            if (gainLabel != null)
              Text(gainLabel!, style: AppTextStyles.labelSm),
          ],
        ),
        Slider(
          value: value,
          min: -1,
          max: 1,
          divisions: 40,
          activeColor: AppColors.secondary,
          inactiveColor: AppColors.surfaceContainerHigh,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
