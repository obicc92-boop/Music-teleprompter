import 'dart:convert';
import 'package:http/http.dart' as http;

class LrclibResult {
  final int id;
  final String trackName;
  final String artistName;
  final String albumName;
  final double duration;
  final bool instrumental;
  final String? syncedLyrics;
  final String? plainLyrics;

  const LrclibResult({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.instrumental,
    this.syncedLyrics,
    this.plainLyrics,
  });

  bool get hasSyncedLyrics =>
      syncedLyrics != null && syncedLyrics!.trim().isNotEmpty;

  String get durationLabel {
    final secs = duration.round();
    final m = secs ~/ 60;
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  factory LrclibResult.fromJson(Map<String, dynamic> json) => LrclibResult(
        id: json['id'] as int? ?? 0,
        trackName: json['trackName'] as String? ?? '',
        artistName: json['artistName'] as String? ?? '',
        albumName: json['albumName'] as String? ?? '',
        duration: (json['duration'] as num?)?.toDouble() ?? 0,
        instrumental: json['instrumental'] as bool? ?? false,
        syncedLyrics: json['syncedLyrics'] as String?,
        plainLyrics: json['plainLyrics'] as String?,
      );
}

class LrclibService {
  static const _base = 'https://lrclib.net/api';
  static const _headers = {'Lrclib-Client': 'MusicTeleprompter/1.0'};

  static Future<List<LrclibResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$_base/search')
          .replace(queryParameters: {'q': query.trim()});
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((e) => LrclibResult.fromJson(e as Map<String, dynamic>))
          .where((r) => r.hasSyncedLyrics)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
