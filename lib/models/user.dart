import 'package:flutter/material.dart';

class User {
  final String id;
  final String name;
  final String? photoPath;  // Path a la imagen guardada localmente
  final int color;  // Añadimos el color

  User({
    required this.id,
    required this.name,
    this.photoPath,
    required this.color,  // Color requerido
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'photoPath': photoPath,
    'color': color,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    photoPath: json['photoPath'],
    color: json['color'] ?? Colors.blue.value,  // Valor por defecto
  );
} 