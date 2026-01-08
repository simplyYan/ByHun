// App Model
class ByhunAppModel {
  final String id;
  final String name;
  final String developer;
  final String source;
  final DateTime addedDate;

  ByhunAppModel({
    required this.id,
    required this.name,
    required this.developer,
    required this.source,
    required this.addedDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'developer': developer,
        'source': source,
        'addedDate': addedDate.toIso8601String(),
      };

  factory ByhunAppModel.fromJson(Map<String, dynamic> json) => ByhunAppModel(
        id: json['id'],
        name: json['name'],
        developer: json['developer'],
        source: json['source'],
        addedDate: DateTime.parse(json['addedDate']),
      );
}
