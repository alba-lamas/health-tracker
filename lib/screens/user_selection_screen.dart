import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/user.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class UserSelectionScreen extends StatefulWidget {
  final List<User> users;
  final Function(User) onUserSelected;
  final Function(List<User>) onUsersUpdated;

  const UserSelectionScreen({
    super.key,
    required this.users,
    required this.onUserSelected,
    required this.onUsersUpdated,
  });

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final _uuid = const Uuid();

  Future<void> _createNewUser() async {
    final controller = TextEditingController();
    String? photoPath;
    Color selectedColor = Colors.blue;  // Color por defecto

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nuevo Perfil'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Color del perfil:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Colors.blue,
                      Colors.purple,
                      Colors.teal,
                      Colors.orange,
                      Colors.pink,
                      Colors.green,
                      Colors.red,
                      Colors.indigo,
                    ].map((color) => GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: color == selectedColor
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                        ),
                      ),
                    )).toList(),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Añadir Foto'),
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      
                      if (image != null) {
                        final directory = await getApplicationDocumentsDirectory();
                        final name = '${_uuid.v4()}.jpg';
                        final File newImage = File('${directory.path}/$name');
                        await File(image.path).copy(newImage.path);
                        
                        setState(() {
                          photoPath = newImage.path;
                        });
                      }
                    },
                  ),
                  if (photoPath != null)
                    const Text('Foto seleccionada', style: TextStyle(color: Colors.green)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      final newUser = User(
                        id: _uuid.v4(),
                        name: controller.text,
                        photoPath: photoPath,
                        color: selectedColor.value,  // Guardamos el color
                      );
                      
                      final updatedUsers = [...widget.users, newUser];
                      widget.onUsersUpdated(updatedUsers);
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editUser(User user) async {
    final controller = TextEditingController(text: user.name);
    String? photoPath = user.photoPath;
    Color selectedColor = Color(user.color);  // Inicializar con el color actual

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar Perfil'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Color del perfil:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Colors.blue,
                      Colors.purple,
                      Colors.teal,
                      Colors.orange,
                      Colors.pink,
                      Colors.green,
                      Colors.red,
                      Colors.indigo,
                    ].map((color) => GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: color.value == selectedColor.value
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (photoPath != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: photoPath != null 
                            ? FileImage(File(photoPath!))  // Usamos ! para asegurar que no es null
                            : null,  // Fallback si photoPath es null
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              photoPath = null;
                            });
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: Text(photoPath == null ? 'Añadir Foto' : 'Cambiar Foto'),
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      
                      if (image != null) {
                        final directory = await getApplicationDocumentsDirectory();
                        final name = '${_uuid.v4()}.jpg';
                        final File newImage = File('${directory.path}/$name');
                        await File(image.path).copy(newImage.path);
                        
                        // Borrar la foto anterior si existe
                        if (photoPath != null) {
                          try {
                            await File(photoPath!).delete();
                          } catch (e) {
                            debugPrint('Error borrando foto anterior: $e');
                          }
                        }
                        
                        setState(() {
                          photoPath = newImage.path;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      final updatedUser = User(
                        id: user.id,
                        name: controller.text,
                        photoPath: photoPath,
                        color: selectedColor.value,  // Incluir el color al actualizar
                      );
                      
                      final updatedUsers = widget.users.map((u) => 
                        u.id == user.id ? updatedUser : u
                      ).toList();
                      
                      widget.onUsersUpdated(updatedUsers);
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(User user) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Borrar Perfil'),
          content: Text('¿Estás seguro de que quieres borrar el perfil de ${user.name}? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                // Borrar la foto si existe
                if (user.photoPath != null) {
                  try {
                    await File(user.photoPath!).delete();
                  } catch (e) {
                    debugPrint('Error borrando foto: $e');
                  }
                }
                
                final updatedUsers = widget.users.where((u) => u.id != user.id).toList();
                widget.onUsersUpdated(updatedUsers);
                Navigator.of(context).pop();
              },
              child: const Text('Borrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.selectProfile),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.users.isEmpty
              ? Center(
                  child: Text(AppLocalizations.of(context)!.noProfiles),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: widget.users.length,
                  itemBuilder: (context, index) {
                    final user = widget.users[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: user.photoPath != null
                            ? ClipOval(
                                child: Image.file(
                                  File(user.photoPath!),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                        ),
                        title: Text(user.name),
                        onTap: () => widget.onUserSelected(user),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editUser(user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _confirmDelete(user),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Crear Nuevo Perfil'),
              onPressed: _createNewUser,
            ),
          ),
        ],
      ),
    );
  }
} 