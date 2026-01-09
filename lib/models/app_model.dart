// App Model
class ByhunAppModel {
  final String id;
  String name;
  String developer;
  final String source;
  final DateTime addedDate;
  DateTime? lastUsedDate;
  int usageCount;
  int fileSizeBytes;
  bool isFavorite;
  String category;
  List<String> tags;
  String? sha256Hash;
  DateTime? lastUpdated;

  ByhunAppModel({
    required this.id,
    required this.name,
    required this.developer,
    required this.source,
    required this.addedDate,
    this.lastUsedDate,
    this.usageCount = 0,
    this.fileSizeBytes = 0,
    this.isFavorite = false,
    this.category = 'Uncategorized',
    List<String>? tags,
    this.sha256Hash,
    this.lastUpdated,
  }) : tags = tags ?? [];

  // Copy with method for immutability
  ByhunAppModel copyWith({
    String? id,
    String? name,
    String? developer,
    String? source,
    DateTime? addedDate,
    DateTime? lastUsedDate,
    int? usageCount,
    int? fileSizeBytes,
    bool? isFavorite,
    String? category,
    List<String>? tags,
    String? sha256Hash,
    DateTime? lastUpdated,
  }) {
    return ByhunAppModel(
      id: id ?? this.id,
      name: name ?? this.name,
      developer: developer ?? this.developer,
      source: source ?? this.source,
      addedDate: addedDate ?? this.addedDate,
      lastUsedDate: lastUsedDate ?? this.lastUsedDate,
      usageCount: usageCount ?? this.usageCount,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isFavorite: isFavorite ?? this.isFavorite,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      sha256Hash: sha256Hash ?? this.sha256Hash,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'developer': developer,
        'source': source,
        'addedDate': addedDate.toIso8601String(),
        'lastUsedDate': lastUsedDate?.toIso8601String(),
        'usageCount': usageCount,
        'fileSizeBytes': fileSizeBytes,
        'isFavorite': isFavorite,
        'category': category,
        'tags': tags,
        'sha256Hash': sha256Hash,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory ByhunAppModel.fromJson(Map<String, dynamic> json) => ByhunAppModel(
        id: json['id'],
        name: json['name'],
        developer: json['developer'],
        source: json['source'],
        addedDate: DateTime.parse(json['addedDate']),
        lastUsedDate: json['lastUsedDate'] != null
            ? DateTime.parse(json['lastUsedDate'])
            : null,
        usageCount: json['usageCount'] ?? 0,
        fileSizeBytes: json['fileSizeBytes'] ?? 0,
        isFavorite: json['isFavorite'] ?? false,
        category: json['category'] ?? 'Uncategorized',
        tags: json['tags'] != null
            ? List<String>.from(json['tags'])
            : [],
        sha256Hash: json['sha256Hash'],
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'])
            : null,
      );

  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Duration get totalUsageTime {
    // This would be tracked separately, for now return zero
    return Duration.zero;
  }
}
