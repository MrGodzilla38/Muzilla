import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/duration_formatter.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerProvider.select((state) => state.currentSong));

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.auroraBottomLeft),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.auroraTopRight),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
              ),
              child: Column(
                children: [
                  _TopBar(onClose: () => Navigator.of(context).pop()),
                  Expanded(
                    child: song == null
                        ? const _EmptyState()
                        : _PlayerBody(song: song),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;

  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kMinInteractiveDimension,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textHighContrast,
              ),
            ),
          ),
          Text('Şu An Çalıyor', style: AppTextStyles.labelLg),
        ],
      ),
    );
  }
}

class _PlayerBody extends StatelessWidget {
  final SongModel song;

  const _PlayerBody({required this.song});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortest = constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    size: 400,
                    artworkWidth: shortest,
                    artworkHeight: shortest,
                    artworkFit: BoxFit.cover,
                    nullArtworkWidget: Container(
                      width: shortest,
                      height: shortest,
                      color: AppColors.surfaceContainerHigh,
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: AppColors.textMuted,
                        size: 72,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          song.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headlineMd,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          song.artist ?? 'Bilinmeyen sanatçı',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMd,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _ProgressBar(),
        const SizedBox(height: AppSpacing.md),
        const _ControlsRow(),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _ProgressBar extends ConsumerStatefulWidget {
  const _ProgressBar();

  @override
  ConsumerState<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends ConsumerState<_ProgressBar> {
  bool _scrubbing = false;
  double _scrubPosition = 0;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(playerProvider.select((state) => state.position));
    final duration = ref.watch(playerProvider.select((state) => state.duration));
    final total = duration.inMilliseconds;
    final max = total > 0 ? total.toDouble() : 1.0;
    final current = (_scrubbing
            ? _scrubPosition
            : position.inMilliseconds.toDouble())
        .clamp(0.0, max);

    return Column(
      children: [
        Slider(
          value: current,
          max: max,
          onChanged: (value) {
            setState(() {
              _scrubbing = true;
              _scrubPosition = value;
            });
          },
          onChangeEnd: (value) {
            setState(() => _scrubbing = false);
            ref
                .read(playerProvider.notifier)
                .seek(Duration(milliseconds: value.round()));
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDurationMs(current.round()),
                style: AppTextStyles.labelMd,
              ),
              Text(
                total > 0
                    ? '-${formatDurationMs((total - current).round())}'
                    : '--:--',
                style: AppTextStyles.labelMd,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ControlsRow extends ConsumerWidget {
  const _ControlsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shuffleEnabled = ref.watch(
      playerProvider.select((state) => state.shuffleEnabled),
    );
    final repeatMode = ref.watch(
      playerProvider.select((state) => state.repeatMode),
    );
    final isPlaying = ref.watch(
      playerProvider.select((state) => state.isPlaying),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            ref.read(playerProvider.notifier).toggleShuffle();
          },
          icon: Icon(
            Icons.shuffle_rounded,
            size: 26,
            color: shuffleEnabled
                ? AppColors.primary
                : AppColors.textMuted,
          ),
        ),
        IconButton(
          onPressed: () {
            ref.read(playerProvider.notifier).playPrevious();
          },
          icon: const Icon(
            Icons.skip_previous_rounded,
            size: 40,
            color: AppColors.textHighContrast,
          ),
        ),
        _PlayButton(isPlaying: isPlaying),
        IconButton(
          onPressed: () {
            ref.read(playerProvider.notifier).playNext();
          },
          icon: const Icon(
            Icons.skip_next_rounded,
            size: 40,
            color: AppColors.textHighContrast,
          ),
        ),
        IconButton(
          onPressed: () {
            ref.read(playerProvider.notifier).cycleRepeat();
          },
          icon: Icon(
            repeatMode == PlayerRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            size: 26,
            color: repeatMode == PlayerRepeatMode.off
                ? AppColors.textMuted
                : AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends ConsumerWidget {
  final bool isPlaying;

  const _PlayButton({required this.isPlaying});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: AppColors.activeGlow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            ref.read(playerProvider.notifier).togglePlayPause();
          },
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.music_off_rounded,
            size: 40,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Çalan bir şarkı yok', style: AppTextStyles.bodyMd),
        ],
      ),
    );
  }
}
