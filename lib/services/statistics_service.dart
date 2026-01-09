import '../models/app_model.dart';
import '../services/storage_service.dart';

// Statistics Service
class StatisticsService {
  final StorageService _storage = StorageService();

  Future<AppStatistics> getStatistics() async {
    final apps = await _storage.getApps();
    
    if (apps.isEmpty) {
      return AppStatistics(
        totalApps: 0,
        favoriteApps: 0,
        totalFileSize: 0,
        mostUsedApps: [],
        categories: {},
        totalUsageTime: Duration.zero,
      );
    }

    // Calculate total file size
    final totalFileSize = apps.fold<int>(
      0,
      (sum, app) => sum + app.fileSizeBytes,
    );

    // Count favorites
    final favoriteCount = apps.where((app) => app.isFavorite).length;

    // Most used apps
    final mostUsedApps = List<ByhunAppModel>.from(apps)
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));

    // Categories count
    final categories = <String, int>{};
    for (final app in apps) {
      categories[app.category] = (categories[app.category] ?? 0) + 1;
    }

    // Calculate total usage time (placeholder - would need time tracking)
    final totalUsageTime = Duration.zero;

    return AppStatistics(
      totalApps: apps.length,
      favoriteApps: favoriteCount,
      totalFileSize: totalFileSize,
      mostUsedApps: mostUsedApps.take(10).toList(),
      categories: categories,
      totalUsageTime: totalUsageTime,
    );
  }

  Future<Map<String, int>> getUsageByCategory() async {
    final apps = await _storage.getApps();
    final usageByCategory = <String, int>{};

    for (final app in apps) {
      final categoryUsage = usageByCategory[app.category] ?? 0;
      usageByCategory[app.category] = categoryUsage + app.usageCount;
    }

    return usageByCategory;
  }

  Future<List<ByhunAppModel>> getRecentlyUsedApps({int limit = 10}) async {
    final apps = await _storage.getApps();
    final withUsage = apps.where((app) => app.lastUsedDate != null).toList();
    withUsage.sort((a, b) {
      final aDate = a.lastUsedDate;
      final bDate = b.lastUsedDate;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return withUsage.take(limit).toList();
  }
}

class AppStatistics {
  final int totalApps;
  final int favoriteApps;
  final int totalFileSize;
  final List<ByhunAppModel> mostUsedApps;
  final Map<String, int> categories;
  final Duration totalUsageTime;

  AppStatistics({
    required this.totalApps,
    required this.favoriteApps,
    required this.totalFileSize,
    required this.mostUsedApps,
    required this.categories,
    required this.totalUsageTime,
  });

  String get totalFileSizeFormatted {
    if (totalFileSize < 1024) return '$totalFileSize B';
    if (totalFileSize < 1024 * 1024) {
      return '${(totalFileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalFileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
