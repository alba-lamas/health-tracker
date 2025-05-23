class Medication {
  final String id;
  final String description;
  final String tag;
  final String color;
  final DateTime date;
  final String timeOfDay; // 'morning', 'afternoon', 'night', 'allday'
  final String dose;  // Instead of intensity, we store the dose

  Medication({
    required this.id,
    required this.description,
    required this.tag,
    required this.color,
    required this.date,
    required this.timeOfDay,
    required this.dose,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'tag': tag,
    'color': color,
    'date': date.toIso8601String(),
    'timeOfDay': timeOfDay,
    'dose': dose,
  };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    id: json['id'],
    description: json['description'],
    tag: json['tag'],
    color: json['color'],
    date: DateTime.parse(json['date']),
    timeOfDay: json['timeOfDay'] ?? 'allday',
    dose: json['dose'],
  );

  Medication copyWith({
    String? id,
    String? description,
    String? tag,
    String? color,
    DateTime? date,
    String? timeOfDay,
    String? dose,
  }) {
    return Medication(
      id: id ?? this.id,
      description: description ?? this.description,
      tag: tag ?? this.tag,
      color: color ?? this.color,
      date: date ?? this.date,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      dose: dose ?? this.dose,
    );
  }
} 