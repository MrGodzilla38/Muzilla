import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

class MiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;

  const MiniPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerProvider.select((state) => state.currentSong));
    if (song == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = ref.watch(
      playerProvider.select((state) => state.isPlaying),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                border: Border(top: BorderSide(color: AppColors.outlineVariant)),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.dflt),
                          child: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            artworkWidth: 44,
                            artworkHeight: 44,
                            artworkFit: BoxFit.cover,
                            nullArtworkWidget: Container(
                              width: 44,
                              height: 44,
                              color: AppColors.surfaceContainerHigh,
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMd.copyWith(
                                  color: AppColors.textHighContrast,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                song.artist ?? 'Bilinmeyen sanatçı',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySm,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            ref
                                .read(playerProvider.notifier)
                                .togglePlayPause();
                          },
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _ProgressLine(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressLine extends ConsumerWidget {
  const _ProgressLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerProvider.select((state) => state.position));
    final duration = ref.watch(playerProvider.select((state) => state.duration));
    final total = duration.inMilliseconds;
    final progress = total <= 0 ? 0.0 : position.inMilliseconds / total;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final filled = (width * progress).clamp(0.0, width);
        return SizedBox(
          width: width,
          height: 3,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: filled,
                  decoration: const BoxDecoration(
                    gradient: AppColors.scrubberFill,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
