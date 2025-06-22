class AppSettings {
  final String language;
  
  AppSettings({
    required this.language,
  });
  
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      language: json['language'] ?? 'id',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'language': language,
    };
  }
  
  AppSettings copyWith({
    String? language,
  }) {
    return AppSettings(
      language: language ?? this.language,
    );
  }
}