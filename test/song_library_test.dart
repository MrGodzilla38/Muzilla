import 'package:flutter_test/flutter_test.dart';
import 'package:muzilla/providers/song_library_provider.dart';

void main() {
  group('isInMusicFolder', () {
    test('kabul: Music klasörünün altındaki dosyalar', () {
      expect(isInMusicFolder('/storage/emulated/0/Music/song.mp3'), isTrue);
      expect(
        isInMusicFolder('/storage/emulated/0/Music/Albümler/Albüm/01.mp3'),
        isTrue,
      );
      expect(isInMusicFolder('/sdcard/Music/x.flac'), isTrue);
      expect(isInMusicFolder('/storage/1A2B-3C4D/Music/y.m4a'), isTrue);
      expect(isInMusicFolder('/storage/emulated/0/music/z.mp3'), isTrue);
    });

    test('ret: kayıt, WhatsApp ve diğer klasörler', () {
      expect(
        isInMusicFolder('/storage/emulated/0/Recordings/20260101.m4a'),
        isFalse,
      );
      expect(
        isInMusicFolder('/storage/emulated/0/Recorders/kayıt_001.mp3'),
        isFalse,
      );
      expect(
        isInMusicFolder(
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio/notes.m4a',
        ),
        isFalse,
      );
      expect(
        isInMusicFolder('/storage/emulated/0/Notifications/alert.ogg'),
        isFalse,
      );
      expect(isInMusicFolder('/storage/emulated/0/Download/ses.mp3'), isFalse);
      expect(isInMusicFolder(''), isFalse);
    });

    test('Music adını içeren ama klasör olmayan dosya adları', () {
      expect(
        isInMusicFolder('/storage/emulated/0/Recordings/music_note.m4a'),
        isFalse,
      );
    });
  });
}
