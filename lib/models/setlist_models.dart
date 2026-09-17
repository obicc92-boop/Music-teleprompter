String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

const int _defaultColor = 0xFF555555;
const String _defaultCardFont = 'TeleprompterMono';
const double _defaultCardFontSize = 15.0;

// Sentinel for nullable copyWith fields
const Object _unset = Object();

enum SetlistItemType { song, separator }

class SetlistItem {
  final String id;
  final SetlistItemType type;
  final String path;            // song only
  final String title;           // song only
  final int colorValue;         // song only
  final String note;            // song only
  final double? speedMultiplier; // song only — null = use global default
  final String text;            // separator only

  // Per-card display style (song only)
  final double cardPosition;   // 0.0 = left edge, 0.5 = center, 1.0 = right edge
  final double cardFontSize;   // title font size in px
  final String cardFont;       // fontFamily for title

  const SetlistItem._({
    required this.id,
    required this.type,
    this.path = '',
    this.title = '',
    this.colorValue = _defaultColor,
    this.note = '',
    this.speedMultiplier,
    this.text = '',
    this.cardPosition = 0.5,
    this.cardFontSize = _defaultCardFontSize,
    this.cardFont = _defaultCardFont,
  });

  factory SetlistItem.song({
    String? id,
    required String path,
    required String title,
    int colorValue = _defaultColor,
    String note = '',
    double? speedMultiplier,
    double cardPosition = 0.5,
    double cardFontSize = _defaultCardFontSize,
    String cardFont = _defaultCardFont,
  }) =>
      SetlistItem._(
        id: id ?? _newId(),
        type: SetlistItemType.song,
        path: path,
        title: title,
        colorValue: colorValue,
        note: note,
        speedMultiplier: speedMultiplier,
        cardPosition: cardPosition,
        cardFontSize: cardFontSize,
        cardFont: cardFont,
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
    double? cardPosition,
    double? cardFontSize,
    String? cardFont,
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
        cardPosition: cardPosition ?? this.cardPosition,
        cardFontSize: cardFontSize ?? this.cardFontSize,
        cardFont: cardFont ?? this.cardFont,
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
        'cardPosition': cardPosition,
        'cardFontSize': cardFontSize,
        'cardFont': cardFont,
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
        cardPosition: (j['cardPosition'] as num?)?.toDouble() ?? 0.5,
        cardFontSize: (j['cardFontSize'] as num?)?.toDouble() ?? _defaultCardFontSize,
        cardFont: j['cardFont'] as String? ?? _defaultCardFont,
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
