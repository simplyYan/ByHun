// App Settings Model
class AppSettings {
  final String themeMode; // 'light', 'dark', 'system'
  final String language; // 'en', 'pt', etc.
  final int webViewQuality; // 1-5, quality setting
  final bool enableOptimizations;
  final bool autoUpdateCheck;
  final bool enableNotifications;
  final bool enableDeveloperAPI;
  final String sandboxPath; // Sandbox directory path
  final Map<String, dynamic> customSettings;

  AppSettings({
    this.themeMode = 'system',
    this.language = 'en',
    this.webViewQuality = 3,
    this.enableOptimizations = true,
    this.autoUpdateCheck = false,
    this.enableNotifications = true,
    this.enableDeveloperAPI = false,
    String? sandboxPath,
    Map<String, dynamic>? customSettings,
  })  : sandboxPath = sandboxPath ?? '',
        customSettings = customSettings ?? {};

  AppSettings copyWith({
    String? themeMode,
    String? language,
    int? webViewQuality,
    bool? enableOptimizations,
    bool? autoUpdateCheck,
    bool? enableNotifications,
    bool? enableDeveloperAPI,
    String? sandboxPath,
    Map<String, dynamic>? customSettings,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      webViewQuality: webViewQuality ?? this.webViewQuality,
      enableOptimizations: enableOptimizations ?? this.enableOptimizations,
      autoUpdateCheck: autoUpdateCheck ?? this.autoUpdateCheck,
      enableNotifications:
          enableNotifications ?? this.enableNotifications,
      enableDeveloperAPI:
          enableDeveloperAPI ?? this.enableDeveloperAPI,
      sandboxPath: sandboxPath ?? this.sandboxPath,
      customSettings: customSettings ?? this.customSettings,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode,
        'language': language,
        'webViewQuality': webViewQuality,
        'enableOptimizations': enableOptimizations,
        'autoUpdateCheck': autoUpdateCheck,
        'enableNotifications': enableNotifications,
        'enableDeveloperAPI': enableDeveloperAPI,
        'sandboxPath': sandboxPath,
        'customSettings': customSettings,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: json['themeMode'] ?? 'system',
        language: json['language'] ?? 'en',
        webViewQuality: json['webViewQuality'] ?? 3,
        enableOptimizations: json['enableOptimizations'] ?? true,
        autoUpdateCheck: json['autoUpdateCheck'] ?? false,
        enableNotifications: json['enableNotifications'] ?? true,
        enableDeveloperAPI: json['enableDeveloperAPI'] ?? false,
        sandboxPath: json['sandboxPath'] ?? '',
        customSettings: json['customSettings'] ?? {},
      );
}
