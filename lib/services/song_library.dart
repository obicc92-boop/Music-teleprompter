import 'dart:io';
import '../models/song_settings.dart';
import 'file_service.dart';
import 'formatting_service.dart';
import 'setlist_service.dart';
import 'song_audio_store.dart';
import 'song_lrc_content_store.dart';
import 'song_lrc_store.dart';
import 'song_settings_store.dart';
import 'song_transpose_store.dart';

/// A song's file together with everything saved about it under its title:
/// its own settings, formatting, timing, backing track and key. Renaming
/// moves all of it and points every setlist at the new name, so the song
/// stays the same song.
class SongLibrary {
  SongLibrary._();

  /// Saves [content] as [to], removes the file [from] and carries the
  /// song's data and setlist entries over. Returns the new file's path.
  static Future<String> rename({
    required String from,
    required String to,
    required String content,
  }) async {
    final files = FileService();
    final oldPath = await files.libraryPath(from);
    final newPath = await files.saveToLibrary(content, to);
    if (oldPath != newPath) {
      final old = File(oldPath);
      if (await old.exists()) await old.delete();
    }
    await FormattingService().rename(from, to);
    await _moveSongData(from, to);
    await SetlistService().songRenamed(
      oldPath: oldPath,
      oldTitle: from,
      newPath: newPath,
      newTitle: to,
    );
    return newPath;
  }

  static Future<void> _moveSongData(String from, String to) async {
    if (from == to) return;

    final settings = await SongSettingsStore.getSettings(from);
    if (!settings.isEmpty) {
      await SongSettingsStore.saveSettings(to, settings);
      await SongSettingsStore.saveSettings(from, SongSettings.none);
    }

    final timing = await SongLrcContentStore.getContent(from);
    if (timing != null) {
      await SongLrcContentStore.saveContent(to, timing);
      await SongLrcContentStore.removeContent(from);
    }

    final lrcPath = await SongLrcStore.getPath(from);
    if (lrcPath != null) {
      await SongLrcStore.savePath(to, lrcPath);
      await SongLrcStore.removePath(from);
    }

    final audio = await SongAudioStore.getPath(from);
    if (audio != null) {
      await SongAudioStore.savePath(to, audio);
      await SongAudioStore.removePath(from);
    }

    final transpose = await SongTransposeStore.getTranspose(from);
    if (transpose != 0) {
      await SongTransposeStore.saveTranspose(to, transpose);
      await SongTransposeStore.saveTranspose(from, 0);
    }
  }
}
