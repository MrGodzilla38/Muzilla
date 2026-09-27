import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../providers/player_provider.dart';
import '../providers/song_library_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../widgets/song_tile.dart';

/// Ekran görüntüsüyle birebir aynı ana sayfa düzeni.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(songLibraryProvider);

    return Scaffold(
      body: Stack(
        children: [
          const _AuroraBackground(),
          SafeArea(
            child: libraryAsync.when(
              loading: () => _HomeShell(
                songs: const [],
                showFilterRow: false,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => _HomeShell(
                songs: const [],
                showFilterRow: false,
                child: _CenteredNotice(
                  icon: Icons.error_outline_rounded,
                  iconColor: AppColors.error,
                  message: 'Ana sayfa yüklenirken bir sorun oluştu.\n$err',
                  actionLabel: 'Tekrar dene',
                  onAction: () => ref.invalidate(songLibraryProvider),
                ),
              ),
              data: (result) {
                switch (result) {
                  case SongLibraryPermissionDenied():
                    return _HomeShell(
                      songs: const [],
                      showFilterRow: false,
                      child: _CenteredNotice(
                        icon: Icons.lock_outline_rounded,
                        iconColor: AppColors.textMuted,
                        message:
                            'Şarkılarını görebilmemiz için cihazındaki müzik dosyalarına erişim izni gerekiyor.',
                        actionLabel: 'İzin ver',
                        onAction: () => ref.invalidate(songLibraryProvider),
                      ),
                    );
                  case SongLibraryLoaded(:final songs):
                    if (songs.isEmpty) {
                      return _HomeShell(
                        songs: songs,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _ShufflePlayRow(songs: []),
                            const SizedBox(height: AppSpacing.lg + 4),
                            _EmptyMusicCard(
                              onRefresh: () =>
                                  ref.invalidate(songLibraryProvider),
                            ),
                          ],
                        ),
                      );
                    }
                    return _HomeContent(songs: songs);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E2249), Color(0xFF0A1731), AppColors.canvasBase],
          stops: [0.0, 0.30, 0.66],
        ),
      ),
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.1, -1.0),
              radius: 1.15,
              colors: [AppColors.primary.withValues(alpha: 0.4), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeShell extends StatelessWidget {
  final List<SongModel> songs;
  final Widget child;
  final int selectedFilter;
  final ValueChanged<int>? onFilterChanged;
  final bool showFilterRow;

  const _HomeShell({
    required this.songs,
    required this.child,
    this.selectedFilter = 0,
    this.onFilterChanged,
    this.showFilterRow = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        const _TopBar(),
        const SizedBox(height: AppSpacing.xs),
        if (showFilterRow) ...[
          _CategoryTabs(
            songs: songs,
            selected: selectedFilter,
            onChanged: onFilterChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
        ] else
          const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _HomeContent extends ConsumerStatefulWidget {
  final List<SongModel> songs;
  const _HomeContent({required this.songs});

  @override
  ConsumerState<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<_HomeContent> {
  int _filterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final songs = [...widget.songs]
      ..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    final favorites = songs.take(6).toList();
    final recentlyPlayed = songs.reversed.take(8).toList();
    final newest = songs.take(5).toList();
    final weeklyCount = min(30, songs.length);

    final sections = <Widget>[];

    void addSection({
      required bool show,
      required String title,
      required Widget row,
    }) {
      if (!show) {
        return;
      }
      sections.add(_SectionHeader(title: title));
      sections.add(const SizedBox(height: AppSpacing.sm + 4));
      sections.add(row);
      sections.add(const SizedBox(height: AppSpacing.lg + 8));
    }

    // 0: Tümü, 1: Şarkılar, 2: Kütüphane (boş)
    final showFavorites = _filterIndex == 0;
    final showRecent = _filterIndex == 0;
    final showWeekly = _filterIndex == 0;
    final showNewest = _filterIndex == 0;
    final showAllSongs = _filterIndex == 1;

    addSection(
      show: showFavorites,
      title: 'Sık Kullanılanların',
      row: _FavoritesRow(songs: favorites),
    );
    addSection(
      show: showRecent,
      title: 'En Son Oynatılanlar',
      row: _RecentlyPlayedRow(songs: recentlyPlayed),
    );
    if (showWeekly) {
      sections.add(_WeeklyDiscoveryCard(count: weeklyCount, songs: songs));
      sections.add(const SizedBox(height: AppSpacing.lg + 8));
    }
    addSection(
      show: showNewest,
      title: 'Yeni Eklenenler',
      row: _FavoritesRow(songs: newest),
    );
    addSection(
      show: showAllSongs,
      title: 'Şarkılar',
      row: _AllSongsList(songs: songs),
    );

    return _HomeShell(
      songs: songs,
      selectedFilter: _filterIndex,
      onFilterChanged: (index) => setState(() => _filterIndex = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ShufflePlayRow(songs: songs),
          const SizedBox(height: AppSpacing.lg + 4),
          ...sections,
        ],
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
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Muzilla',
              style: AppTextStyles.headlineSm.copyWith(
                fontSize: 19,
                height: 1.2,
                color: AppColors.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {},
              icon: const Icon(
                Icons.search_rounded,
                color: AppColors.textHighContrast,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  final List<SongModel> songs;
  final int selected;
  final ValueChanged<int>? onChanged;
  const _CategoryTabs({
    required this.songs,
    this.selected = 0,
    this.onChanged,
  });

  static const List<(String, String)> _tabs = [
    ('Tümü', ''),
    ('Şarkılar', 'Alfabetik liste'),
    ('Kütüphane', 'Çalma listeleri'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg + 4),
        itemBuilder: (context, index) {
          final (title, caption) = _tabs[index];
          final isActive = index == selected;
          final label = index == 1 ? '${songs.length} şarkı' : caption;
          return InkWell(
            onTap: onChanged == null ? null : () => onChanged!(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.headlineSm.copyWith(
                      fontSize: 16,
                      height: 1.2,
                      color: isActive
                          ? AppColors.textHighContrast
                          : Colors.white.withValues(alpha: 0.55),
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (label.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: AppTextStyles.labelSm.copyWith(
                        color: isActive
                            ? AppColors.secondary
                            : AppColors.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShufflePlayRow extends ConsumerWidget {
  final List<SongModel> songs;
  const _ShufflePlayRow({required this.songs});

  void _showNoMusicMessage(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF101A3A),
          content: const Text(
            'Müzik bulunamadı. Cihazında henüz çalınacak bir şarkı yok.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              onTap: () {
                if (songs.isEmpty) {
                  _showNoMusicMessage(context);
                  return;
                }
                final shuffled = [...songs]..shuffle();
                ref
                    .read(playerProvider.notifier)
                    .playSong(shuffled.first, queue: shuffled);
              },
              background: const Color(0xFF0C1A33),
              border: Colors.white.withValues(alpha: 0.07),
              badgeShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.dflt),
              ),
              badgeBackground: AppColors.secondary.withValues(alpha: 0.16),
              badgeIcon: Icons.shuffle_rounded,
              badgeColor: AppColors.secondary,
              label: 'Karıştır',
            ),
          ),
          const SizedBox(width: AppSpacing.md - 4),
          Expanded(
            child: _ActionButton(
              onTap: () {
                if (songs.isEmpty) {
                  _showNoMusicMessage(context);
                  return;
                }
                ref
                    .read(playerProvider.notifier)
                    .playSong(songs.first, queue: songs);
              },
              gradient: const LinearGradient(
                colors: [Color(0xFF3B7DFF), Color(0xFF59C7FF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              badgeShape: const CircleBorder(),
              badgeBackground: Colors.white,
              badgeIcon: Icons.play_arrow_rounded,
              badgeColor: AppColors.primary,
              label: 'Oynat',
              labelWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color? background;
  final Gradient? gradient;
  final Color? border;
  final ShapeBorder badgeShape;
  final Color badgeBackground;
  final IconData badgeIcon;
  final Color badgeColor;
  final String label;
  final FontWeight labelWeight;

  const _ActionButton({
    required this.onTap,
    required this.badgeShape,
    required this.badgeBackground,
    required this.badgeIcon,
    required this.badgeColor,
    required this.label,
    this.background,
    this.gradient,
    this.border,
    this.labelWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(18));

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? background : null,
          gradient: gradient,
          borderRadius: radius,
          border: border == null ? null : Border.all(color: border!),
          boxShadow: gradient == null
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 26,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: badgeBackground,
                    shape: badgeShape,
                  ),
                  child: Icon(badgeIcon, size: 20, color: badgeColor),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: AppTextStyles.labelLg.copyWith(
                    fontSize: 17,
                    height: 1.2,
                    fontWeight: labelWeight,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headlineSm.copyWith(
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.7),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'Tümü',
            style: AppTextStyles.labelLg.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(width: 2),
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

class _FavoritesRow extends ConsumerWidget {
  final List<SongModel> songs;
  const _FavoritesRow({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(
      playerProvider.select((state) => state.currentSong?.id),
    );

    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final song = songs[index];
          final isPlaying = currentId == song.id;
          return Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: isPlaying
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : const Color(0x8C101A3A),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: isPlaying
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                onTap: () {
                  ref
                      .read(playerProvider.notifier)
                      .playSong(song, queue: songs);
                },
                child: SizedBox(
                  width: 236,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        _Artwork(song: song, size: 44, radius: 10),
                        const SizedBox(width: AppSpacing.sm + 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMd.copyWith(
                                  fontSize: 15,
                                  height: 1.25,
                                  color: AppColors.textHighContrast,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist ?? 'Bilinmeyen sanatçı',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySm.copyWith(
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.secondary.withValues(alpha: 0.18),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 20,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AllSongsList extends ConsumerWidget {
  final List<SongModel> songs;
  const _AllSongsList({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(
      playerProvider.select((state) => state.currentSong?.id),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x8C101A3A),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return SongTile(
              song: song,
              isPlaying: currentId == song.id,
              onTap: () {
                ref.read(playerProvider.notifier).playSong(song, queue: songs);
              },
            );
          },
        ),
      ),
    );
  }
}

class _RecentlyPlayedRow extends ConsumerWidget {
  final List<SongModel> songs;
  const _RecentlyPlayedRow({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 146,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm + 4),
        itemBuilder: (context, index) {
          final song = songs[index];
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () {
              ref.read(playerProvider.notifier).playSong(song, queue: songs);
            },
            child: _Artwork(song: song, size: 146, radius: AppRadius.lg),
          );
        },
      ),
    );
  }
}

class _WeeklyDiscoveryCard extends ConsumerWidget {
  final int count;
  final List<SongModel> songs;
  const _WeeklyDiscoveryCard({required this.count, required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xE6101A3A),
            borderRadius: BorderRadius.circular(AppRadius.xl + 4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.xl + 4),
            onTap: () {
              ref
                  .read(playerProvider.notifier)
                  .playSong(songs.first, queue: songs);
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D2440),
                      borderRadius: BorderRadius.circular(AppRadius.md + 2),
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Color(0xFF5B8CFF),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HAFTALIK KEŞİF •',
                          style: AppTextStyles.labelSm.copyWith(
                            fontSize: 11,
                            color: AppColors.secondary,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Sana Özel Akış Hazır',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headlineSm.copyWith(
                            fontSize: 19,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$count yeni şarkı eklendi',
                          style: AppTextStyles.bodySm.copyWith(height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.35),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 30,
                      color: Color(0xFF05213A),
                    ),
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

class _EmptyMusicCard extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyMusicCard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: const Color(0xE6101A3A),
          borderRadius: BorderRadius.circular(AppRadius.xl + 4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.music_off_rounded,
              color: AppColors.textMuted,
              size: 44,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Henüz müzik yok',
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineSm.copyWith(
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cihazında henüz şarkı bulunamadı. Müzik dosyaları ekledikten '
              ' sonra Sık Kullanılanlar, En Son Oynatılanlar ve Haftalık '
              'Keşif burada listelenecek.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Yenile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final SongModel song;
  final double size;
  final double radius;
  const _Artwork({required this.song, required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: QueryArtworkWidget(
        id: song.id,
        type: ArtworkType.AUDIO,
        artworkWidth: size,
        artworkHeight: size,
        artworkFit: BoxFit.cover,
        artworkBorder: BorderRadius.circular(radius),
        nullArtworkWidget: Container(
          width: size,
          height: size,
          color: AppColors.surfaceContainerHigh,
          child: Icon(
            Icons.music_note_rounded,
            color: AppColors.textMuted,
            size: size * 0.42,
          ),
        ),
      ),
    );
  }
}

class _CenteredNotice extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredNotice({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
