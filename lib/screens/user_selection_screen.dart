import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/user.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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

  Future<void> _crearNuevoUsuario() async {
    final controlador = TextEditingController();
    String? photoPath;

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
                    controller: controlador,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                    if (controlador.text.isNotEmpty) {
                      final newUser = User(
                        id: _uuid.v4(),
                        name: controlador.text,
                        photoPath: photoPath,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Perfil'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.users.isEmpty
              ? const Center(
                  child: Text('No hay perfiles creados'),
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
              onPressed: _crearNuevoUsuario,
            ),
          ),
        ],
      ),
    );
  }
} 