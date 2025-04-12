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
    Color selectedColor = Colors.blue;
    final localizations = AppLocalizations.of(context)!;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(localizations.newProfile),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: localizations.name,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(localizations.profileColorLabel),
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
                    label: Text(photoPath == null 
                      ? localizations.addPhoto 
                      : localizations.changePhoto
                    ),
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
                    Text(
                      localizations.photoSelected,
                      style: const TextStyle(color: Colors.green),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.cancel),
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
                  child: Text(localizations.create),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editUser(User user) async {
    final localizations = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: user.name);
    String? photoPath = user.photoPath;
    Color selectedColor = Color(user.color);

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(localizations.editProfile),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: localizations.name,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(localizations.profileColorLabel),
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
                    label: Text(photoPath == null 
                      ? localizations.addPhoto 
                      : localizations.changePhoto
                    ),
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
                  child: Text(localizations.cancel),
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
                  child: Text(localizations.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(User user) async {
    final localizations = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.deleteProfileTitle),
          content: Text(localizations.deleteProfileConfirmation(user.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations.cancel),
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
              child: Text(localizations.delete),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.selectProfile),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: widget.users.isEmpty
        ? Center(  // Si no hay usuarios, centrar todo
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  localizations.noProfiles,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),  // Espacio entre texto y botón
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(localizations.createNewProfile),
                  onPressed: () => _createNewUser(),
                ),
              ],
            ),
          )
        : Stack(  // Si hay usuarios, mantener el diseño actual
            children: [
              ListView.builder(
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
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () => _createNewUser(),
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
    );
  }
} 