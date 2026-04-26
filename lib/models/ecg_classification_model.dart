// ─────────────────────────────────────────────────────────────────────────────
//  ECG Classification Models
//  Matches the JSON shape expected from:
//    GET /ecg/classifications
//    GET /ecg/classification-levels
// ─────────────────────────────────────────────────────────────────────────────

/// A single ECG record-level classification entry.
/// Backend JSON shape:
/// {
///   "code":        "NORM",
///   "label":       "Normal ECG",
///   "description": "No clear abnormalities ...",
///   "color_hex":   "#00C853",       // optional – fallback used if absent
///   "icon_name":   "check_circle"   // optional – mapped in UI layer
/// }
class EcgClassification {
  final String code;
  final String label;
  final String description;

  /// Hex color string, e.g. "#00C853". Null means UI uses its own default.
  final String? colorHex;

  /// Icon identifier string (resolved to IconData in the UI layer).
  final String? iconName;

  const EcgClassification({
    required this.code,
    required this.label,
    required this.description,
    this.colorHex,
    this.iconName,
  });

  factory EcgClassification.fromJson(Map<String, dynamic> json) {
    return EcgClassification(
      code: json['code'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      colorHex: json['color_hex'] as String?,
      iconName: json['icon_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        'description': description,
        if (colorHex != null) 'color_hex': colorHex,
        if (iconName != null) 'icon_name': iconName,
      };
}

/// A classification level group (beat-level OR record-level).
/// Backend JSON shape:
/// {
///   "level_type":  "beat" | "record",
///   "title":       "Beat-Level Classification",
///   "subtitle":    "Classifies a single heartbeat",
///   "codes": [
///     { "code": "N", "color_hex": "#00C853" },
///     ...
///   ]
/// }
class ClassificationLevel {
  final String levelType; // "beat" or "record"
  final String title;
  final String subtitle;
  final List<ClassificationCode> codes;

  const ClassificationLevel({
    required this.levelType,
    required this.title,
    required this.subtitle,
    required this.codes,
  });

  factory ClassificationLevel.fromJson(Map<String, dynamic> json) {
    return ClassificationLevel(
      levelType: json['level_type'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      codes: (json['codes'] as List<dynamic>)
          .map((e) => ClassificationCode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single code badge inside a [ClassificationLevel].
class ClassificationCode {
  final String code;
  final String? colorHex;

  const ClassificationCode({required this.code, this.colorHex});

  factory ClassificationCode.fromJson(Map<String, dynamic> json) {
    return ClassificationCode(
      code: json['code'] as String,
      colorHex: json['color_hex'] as String?,
    );
  }
}
