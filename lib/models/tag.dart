class SymptomTag {
  final String id;
  final String name;
  final int color;

  SymptomTag({
    required this.id,
    required this.name,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
  };

  factory SymptomTag.fromJson(Map<String, dynamic> json) => SymptomTag(
    id: json['id'],
    name: json['name'],
    color: json['color'],
  );
} 