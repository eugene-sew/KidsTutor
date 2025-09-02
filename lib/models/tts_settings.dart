class TtsSettings {
  final double speechRate;
  final double volume;
  final double pitch;
  final String language;
  final String voice;
  final bool enabled;

  const TtsSettings({
    this.speechRate = 0.5,
    this.volume = 0.8,
    this.pitch = 1.0,
    this.language = 'en-US',
    this.voice = '',
    this.enabled = true,
  });

  TtsSettings copyWith({
    double? speechRate,
    double? volume,
    double? pitch,
    String? language,
    String? voice,
    bool? enabled,
  }) {
    return TtsSettings(
      speechRate: speechRate ?? this.speechRate,
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
      language: language ?? this.language,
      voice: voice ?? this.voice,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speechRate': speechRate,
      'volume': volume,
      'pitch': pitch,
      'language': language,
      'voice': voice,
      'enabled': enabled,
    };
  }

  factory TtsSettings.fromJson(Map<String, dynamic> json) {
    return TtsSettings(
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.5,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.8,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      language: json['language'] as String? ?? 'en-US',
      voice: json['voice'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
