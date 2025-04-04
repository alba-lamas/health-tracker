class Symptom {
  final String id;
  final String description;
  final String tag;
  final String color;
  final DateTime date;
  final String timeOfDay; // 'morning', 'afternoon', 'allday'

  Symptom({
    required this.id,
    required this.description,
    required this.tag,
    required this.color,
    required this.date,
    required this.timeOfDay,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'tag': tag,
    'color': color,
    'date': date.toIso8601String(),
    'timeOfDay': timeOfDay,
  };

  factory Symptom.fromJson(Map<String, dynamic> json) => Symptom(
    id: json['id'],
    description: json['description'],
    tag: json['tag'],
    color: json['color'],
    date: DateTime.parse(json['date']),
    timeOfDay: json['timeOfDay'] ?? 'allday', // valor por defecto para compatibilidad
  );
} 