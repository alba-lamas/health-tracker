class User {
  final String id;
  final String name;
  final String? photoPath;  // Path a la imagen guardada localmente

  User({
    required this.id,
    required this.name,
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'photoPath': photoPath,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    photoPath: json['photoPath'],
  );
} 