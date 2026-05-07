String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

const int _defaultColor = 0xFF555555;

// Sentinel for nullable copyWith fields
const Object _unset = Object();

enum SetlistItemType { song, separator }

class SetlistItem {
  final String id;
  final SetlistItemType type;
  final String path;       // song only
  final String title;      // song only
  final int colorValue;    // song only
  final String note;       // song only — commentary shown on card
  final double? speedMultiplier; // song only — null means use global default
  final String text;       // separator only

  const SetlistItem._({
    required this.id,
    required this.type,
    this.path = '',
    this.title = '',
    this.colorValue = _defaultColor,
    this.note = '',
    this.speedMultiplier,
    this.text = '',
  });

  factory SetlistItem.song({
    String? id,
    required String path,
    required String title,
    int colorValue = _defaultColor,
    String note = '',
    double? speedMultiplier,
  }) =>
      SetlistItem._(
        id: id ?? _newId(),
        type: SetlistItemType.song,
        path: path,
        title: title,
        colorValue: colorValue,
        note: note,
        speedMultiplier: speedMultiplier,
      );

  factory SetlistItem.separator({String? id, String text = ''}) =>
      SetlistItem._(
        id: id ?? _newId(),
        type: SetlistItemType.separator,
        text: text,
      );

  bool get isSong => type == SetlistItemType.song;
  bool get isSeparator => type == SetlistItemType.separator;

  SetlistItem copyWith({
    String? path,
    String? title,
    int? colorValue,
    String? note,
    String? text,
    Object? speedMultiplier = _unset,
  }) =>
      SetlistItem._(
        id: id,
        type: type,
        path: path ?? this.path,
        title: title ?? this.title,
        colorValue: colorValue ?? this.colorValue,
        note: note ?? this.note,
        speedMultiplier: identical(speedMultiplier, _unset)
            ? this.speedMultiplier
            : speedMultiplier as double?,
        text: text ?? this.text,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'path': path,
        'title': title,
        'colorValue': colorValue,
        'note': note,
        'speedMultiplier': speedMultiplier,
        'text': text,
      };

  factory SetlistItem.fromJson(Map<String, dynamic> j) => SetlistItem._(
        id: j['id'] as String? ?? _newId(),
        type: j['type'] == 'separator'
            ? SetlistItemType.separator
            : SetlistItemType.song,
        path: j['path'] as String? ?? '',
        title: j['title'] as String? ?? '',
        colorValue: j['colorValue'] as int? ?? _defaultColor,
        note: j['note'] as String? ?? '',
        speedMultiplier: (j['speedMultiplier'] as num?)?.toDouble(),
        text: j['text'] as String? ?? '',
      );
}

class Setlist {
  final String id;
  final String name;
  final List<SetlistItem> items;

  const Setlist({
    required this.id,
    required this.name,
    required this.items,
  });

  Setlist copyWith({String? name, List<SetlistItem>? items}) => Setlist(
        id: id,
        name: name ?? this.name,
        items: items ?? this.items,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory Setlist.fromJson(Map<String, dynamic> j) => Setlist(
        id: j['id'] as String? ?? _newId(),
        name: j['name'] as String? ?? 'My Setlist',
        items: (j['items'] as List<dynamic>? ?? [])
            .map((i) => SetlistItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

// Used by app.dart for in-show teleprompter navigation (songs only, no separators)
typedef SetlistEntry = ({String path, String title, double? speedMultiplier});
