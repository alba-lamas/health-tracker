import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'models/symptom.dart';
import 'models/tag.dart';
import 'models/user.dart';
import 'screens/user_selection_screen.dart';
import 'dart:io';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'screens/statistics_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final usersJson = prefs.getString('users');
  final List<User> initialUsers = usersJson != null
    ? (json.decode(usersJson) as List)
        .map((item) => User.fromJson(Map<String, dynamic>.from(item)))
        .toList()
    : [];

  runApp(MyApp(initialUsers: initialUsers));
}

class MyApp extends StatefulWidget {
  final List<User> initialUsers;

  const MyApp({
    super.key,
    required this.initialUsers,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late List<User> _users;
  User? _selectedUser;

  @override
  void initState() {
    super.initState();
    _users = widget.initialUsers;
  }

  Future<void> _guardarUsuarios(List<User> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('users', json.encode(users.map((e) => e.toJson()).toList()));
    setState(() {
      _users = users;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Crear el tema basado en el color del usuario
    final ThemeData theme = _selectedUser != null
      ? ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Color(_selectedUser!.color),
          ),
          useMaterial3: true,
        )
      : ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
          ),
          useMaterial3: true,
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Health Checker',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('es'), // Spanish
        Locale('ca'), // Catalan
      ],
      theme: theme,  // Usar el tema personalizado
      home: Builder(
        builder: (context) => _selectedUser == null
          ? UserSelectionScreen(
              users: _users,
              onUserSelected: (user) {
                setState(() {
                  _selectedUser = user;
                });
              },
              onUsersUpdated: _guardarUsuarios,
            )
          : HomePage(
              title: AppLocalizations.of(context)?.appTitle ?? 'Health Checker',
              user: _selectedUser!,
              onLogout: () {
                setState(() {
                  _selectedUser = null;
                });
              },
            ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;
  final String title;

  const HomePage({
    super.key,
    required this.user,
    required this.onLogout,
    required this.title,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Symptom>> _sintomas = {};
  final _prefsInstance = SharedPreferences.getInstance();
  final _uuid = const Uuid();
  List<SymptomTag> _tags = [];

  String get _userSymptomsKey => 'symptoms_${widget.user.id}';  // Clave única por usuario
  String get _userTagsKey => 'tags_${widget.user.id}';         // Clave única por usuario

  @override
  void initState() {
    super.initState();
    _cargarSintomas();
    _cargarTags().then((_) {
      // Si no hay etiquetas guardadas, crear las predefinidas
      if (_tags.isEmpty) {
        setState(() {
          _tags = [
            SymptomTag(
              id: _uuid.v4(),
              name: 'Cabeza',
              color: Colors.red.value,
            ),
            SymptomTag(
              id: _uuid.v4(),
              name: 'Espalda',
              color: Colors.blue.value,
            ),
            SymptomTag(
              id: _uuid.v4(),
              name: 'Barriga',
              color: Colors.green.value,
            ),
          ];
        });
        _guardarTags();  // Guardar las etiquetas predefinidas
      }
    });
  }

  String _fechaAClave(DateTime fecha) {
    return "${fecha.year}-${fecha.month}-${fecha.day}";
  }

  Future<void> _cargarSintomas() async {
    final prefs = await _prefsInstance;
    final sintomasString = prefs.getString(_userSymptomsKey);  // Usar clave única
    if (sintomasString != null) {
      try {
        final Map<String, dynamic> decodedData = json.decode(sintomasString);
        setState(() {
          _sintomas = Map.fromEntries(
            decodedData.entries.map(
              (e) => MapEntry(
                e.key,
                (e.value as List)
                    .map((item) => Symptom.fromJson(Map<String, dynamic>.from(item)))
                    .toList(),
              ),
            ),
          );
        });
      } catch (e) {
        debugPrint('Error cargando síntomas: $e');
      }
    }
  }

  Future<void> _guardarSintomas() async {
    final prefs = await _prefsInstance;
    try {
      final sintomasJson = _sintomas.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(_userSymptomsKey, json.encode(sintomasJson));  // Usar clave única
    } catch (e) {
      debugPrint('Error guardando síntomas: $e');
    }
  }

  Future<void> _cargarTags() async {
    final prefs = await _prefsInstance;
    final tagsString = prefs.getString(_userTagsKey);  // Usar clave única
    if (tagsString != null) {
      try {
        final List<dynamic> decodedData = json.decode(tagsString);
        setState(() {
          _tags = decodedData
              .map((item) => SymptomTag.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        });
      } catch (e) {
        debugPrint('Error cargando tags: $e');
      }
    }
  }

  Future<void> _guardarTags() async {
    final prefs = await _prefsInstance;
    try {
      await prefs.setString(_userTagsKey, json.encode(_tags.map((e) => e.toJson()).toList()));  // Usar clave única
    } catch (e) {
      debugPrint('Error guardando tags: $e');
    }
  }

  Future<void> _limpiarDatos() async {
    final prefs = await _prefsInstance;
    await prefs.remove(_userSymptomsKey);  // Limpiar solo los datos del usuario actual
    await prefs.remove(_userTagsKey);      // Limpiar solo los datos del usuario actual
    setState(() {
      _tags = [];
      _sintomas = {};
    });
  }

  Future<void> _mostrarDialogoGestionTags() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Gestionar Etiquetas'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_tags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No hay etiquetas creadas',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ..._tags.map((tag) => ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(tag.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(tag.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              _crearEditarTag(context, tag).then((_) {
                                setDialogState(() {});
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                _tags.removeWhere((t) => t.id == tag.id);
                              });
                              setDialogState(() {});
                              _guardarTags();
                            },
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva Etiqueta'),
                      onPressed: () {
                        _crearEditarTag(context).then((_) {
                          setDialogState(() {});
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _crearEditarTag(BuildContext context, [SymptomTag? tagExistente]) async {
    final controlador = TextEditingController(text: tagExistente?.name ?? '');
    Color colorSeleccionado = Color(tagExistente?.color ?? Colors.blue.value);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                title: Text(tagExistente == null ? 'Nueva Etiqueta' : 'Editar Etiqueta'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controlador,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la etiqueta',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        Colors.red,
                        Colors.pink,
                        Colors.purple,
                        Colors.deepPurple,
                        Colors.blue,
                        Colors.lightBlue,
                        Colors.cyan,
                        Colors.teal,
                        Colors.green,
                        Colors.lightGreen,
                        Colors.orange,
                        Colors.deepOrange,
                      ].map((color) => GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            colorSeleccionado = color;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: color == colorSeleccionado
                                ? Border.all(color: Colors.black, width: 2)
                                : null,
                          ),
                        ),
                      )).toList(),
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
                      if (controlador.text.isNotEmpty) {
                        setState(() {
                          if (tagExistente == null) {
                            _tags.add(SymptomTag(
                              id: _uuid.v4(),
                              name: controlador.text,
                              color: colorSeleccionado.value,
                            ));
                          } else {
                            final index = _tags.indexWhere((t) => t.id == tagExistente.id);
                            _tags[index] = SymptomTag(
                              id: tagExistente.id,
                              name: controlador.text,
                              color: colorSeleccionado.value,
                            );
                          }
                        });
                        _guardarTags();
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _guardarSintoma(
    String descripcion, 
    String? tag, 
    int color, 
    DateTime fecha,
    String timeOfDay,
  ) async {
    if (tag == null) return;
    
    final key = _fechaAClave(fecha);
    
    final nuevoSintoma = Symptom(
      id: _uuid.v4(),
      description: descripcion,
      tag: tag,
      color: color.toString(),
      date: fecha,
      timeOfDay: timeOfDay,
    );

    setState(() {
      if (!_sintomas.containsKey(key)) {
        _sintomas[key] = [];
      }
      _sintomas[key]!.add(nuevoSintoma);
    });

    await _guardarSintomas();
  }

  void _mostrarDialogoSintomas(DateTime dia) {
    final controlador = TextEditingController();
    String? selectedTag;
    String selectedTime = 'allday';
    final key = _fechaAClave(dia);
    final sintomasDelDia = _sintomas[key] ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateSelectedTag(String? newTag) {
              setDialogState(() {
                selectedTag = newTag;
              });
            }

            bool isButtonEnabled() {
              return controlador.text.isNotEmpty && selectedTag != null;
            }

            return AlertDialog(
              title: Text('Síntomas del ${dia.day}/${dia.month}/${dia.year}'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Formulario de nuevo síntoma
                      const Text(
                        'Nuevo síntoma:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controlador,
                        onChanged: (text) {
                          setDialogState(() {});
                        },
                        decoration: const InputDecoration(
                          labelText: 'Describe el síntoma',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(16),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                      ),
                      const SizedBox(height: 24),  // Aumentado de 16 a 24
                      // Botones de selección de momento del día
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.wb_sunny_outlined,
                                      size: 18,
                                      color: selectedTime == 'morning' ? Colors.white : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Mañana',
                                      style: TextStyle(
                                        color: selectedTime == 'morning' ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                selected: selectedTime == 'morning',
                                onSelected: (bool selected) {
                                  setDialogState(() {
                                    selectedTime = selected ? 'morning' : 'allday';
                                  });
                                },
                                selectedColor: Theme.of(context).primaryColor,
                                backgroundColor: Colors.grey.shade200,
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.wb_twilight,
                                      size: 18,
                                      color: selectedTime == 'afternoon' ? Colors.white : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tarde',
                                      style: TextStyle(
                                        color: selectedTime == 'afternoon' ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                selected: selectedTime == 'afternoon',
                                onSelected: (bool selected) {
                                  setDialogState(() {
                                    selectedTime = selected ? 'afternoon' : 'allday';
                                  });
                                },
                                selectedColor: Theme.of(context).primaryColor,
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 18,
                                  color: selectedTime == 'allday' ? Colors.white : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Todo el día',
                                  style: TextStyle(
                                    color: selectedTime == 'allday' ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            selected: selectedTime == 'allday',
                            onSelected: (bool selected) {
                              setDialogState(() {
                                selectedTime = 'allday';
                              });
                            },
                            selectedColor: Theme.of(context).primaryColor,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Selecciona una etiqueta:'),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: 'Nueva Etiqueta',
                            onPressed: () {
                              _crearEditarTag(context).then((_) {
                                setDialogState(() {});
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            tooltip: 'Gestionar Etiquetas',
                            onPressed: () {
                              _mostrarDialogoGestionTags().then((_) {
                                setDialogState(() {});
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_tags.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'No hay etiquetas creadas',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags.map((tag) => FilterChip(
                          selected: tag.name == selectedTag,
                          label: Text(tag.name),
                          avatar: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Color(tag.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          onSelected: (bool selected) {
                            updateSelectedTag(selected ? tag.name : null);
                          },
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: isButtonEnabled() 
                          ? () {
                              final tagColor = _tags.firstWhere(
                                (tag) => tag.name == selectedTag
                              ).color;
                              
                              _guardarSintoma(
                                controlador.text,
                                selectedTag,
                                tagColor,
                                dia,
                                selectedTime,
                              );
                              
                              setDialogState(() {
                                controlador.clear();
                                selectedTag = null;
                                selectedTime = 'allday';
                              });
                            }
                          : null,
                        child: const Text('Guardar'),
                      ),
                      
                      // Lista de síntomas registrados
                      if (sintomasDelDia.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const Text(
                          'Síntomas registrados:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...sintomasDelDia.map((sintoma) => Card(
                          child: ListTile(
                            leading: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(int.parse(sintoma.color)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(sintoma.description),
                            subtitle: Text(sintoma.tag),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  sintoma.timeOfDay == 'morning'
                                    ? Icons.wb_sunny_outlined
                                    : sintoma.timeOfDay == 'afternoon'
                                      ? Icons.wb_twilight
                                      : Icons.schedule,
                                  size: 20,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _editarSintoma(sintoma, dia, setDialogState);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setDialogState(() {
                                      _sintomas[key]!.remove(sintoma);
                                      if (_sintomas[key]!.isEmpty) {
                                        _sintomas.remove(key);
                                      }
                                    });
                                    _guardarSintomas();
                                  },
                                ),
                              ],
                            ),
                          ),
                        )).toList(),
                      ],
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              actions: [
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editarSintoma(Symptom sintoma, DateTime dia, Function setDialogState) {
    final controlador = TextEditingController(text: sintoma.description);
    String? selectedTag = sintoma.tag;
    String selectedTime = sintoma.timeOfDay;  // Inicializar con el horario actual

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setEditDialogState) {
            return AlertDialog(
              title: const Text('Editar Síntoma'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controlador,
                      decoration: const InputDecoration(
                        labelText: 'Describe el síntoma',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(16),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                    ),
                    const SizedBox(height: 16),
                    // Botones de selección de momento del día
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.wb_sunny_outlined,
                                    size: 18,
                                    color: selectedTime == 'morning' ? Colors.white : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mañana',
                                    style: TextStyle(
                                      color: selectedTime == 'morning' ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              selected: selectedTime == 'morning',
                              onSelected: (bool selected) {
                                setEditDialogState(() {
                                  selectedTime = selected ? 'morning' : 'allday';
                                });
                              },
                              avatar: null,
                              selectedColor: Colors.blue,
                              backgroundColor: Colors.grey.shade200,
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.wb_twilight,
                                    size: 18,
                                    color: selectedTime == 'afternoon' ? Colors.white : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tarde',
                                    style: TextStyle(
                                      color: selectedTime == 'afternoon' ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              selected: selectedTime == 'afternoon',
                              onSelected: (bool selected) {
                                setEditDialogState(() {
                                  selectedTime = selected ? 'afternoon' : 'allday';
                                });
                              },
                              avatar: null,
                              selectedColor: Colors.blue,
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 18,
                                color: selectedTime == 'allday' ? Colors.white : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Todo el día',
                                style: TextStyle(
                                  color: selectedTime == 'allday' ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          selected: selectedTime == 'allday',
                          onSelected: (bool selected) {
                            setEditDialogState(() {
                              selectedTime = 'allday';
                            });
                          },
                          avatar: null,
                          selectedColor: Colors.blue,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Selecciona una etiqueta:'),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: 'Nueva Etiqueta',
                          onPressed: () {
                            _crearEditarTag(context).then((_) {
                              setEditDialogState(() {});
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          tooltip: 'Gestionar Etiquetas',
                          onPressed: () {
                            _mostrarDialogoGestionTags().then((_) {
                              setEditDialogState(() {});
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_tags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'No hay etiquetas creadas',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags.map((tag) => FilterChip(
                        selected: tag.name == selectedTag,
                        label: Text(tag.name),
                        avatar: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Color(tag.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        onSelected: (bool selected) {
                          setEditDialogState(() {
                            selectedTag = selected ? tag.name : null;
                          });
                        },
                      )).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selectedTag == null || controlador.text.isEmpty ? null : () {
                    final tagColor = _tags.firstWhere(
                      (tag) => tag.name == selectedTag
                    ).color;
                    
                    setState(() {
                      final key = _fechaAClave(dia);
                      final index = _sintomas[key]!.indexWhere((s) => s.id == sintoma.id);
                      _sintomas[key]![index] = Symptom(
                        id: sintoma.id,
                        description: controlador.text,
                        tag: selectedTag!,
                        color: tagColor.toString(),
                        date: sintoma.date,
                        timeOfDay: selectedTime,  // Guardar el nuevo horario
                      );
                    });
                    
                    _guardarSintomas();
                    Navigator.of(context).pop();
                    setDialogState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('¿Salir del perfil?'),
                      content: Text('¿Deseas cerrar la sesión de ${widget.user.name}?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onLogout();
                          },
                          child: const Text('Salir'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: widget.user.photoPath != null
                  ? ClipOval(
                      child: Image.file(
                        File(widget.user.photoPath!),
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      widget.user.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
              ),
            ),
          ),
          const SizedBox(width: 16),  // Espacio al final
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TableCalendar(
                  firstDay: DateTime(DateTime.now().year - 1),
                  lastDay: DateTime(DateTime.now().year + 1, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _mostrarDialogoSintomas(selectedDay);
                  },
                  availableGestures: AvailableGestures.all,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    // Marcar días con síntomas
                    markerDecoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 1,
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      final key = _fechaAClave(date);
                      if (_sintomas.containsKey(key)) {
                        return Wrap(
                          spacing: 2,
                          children: _sintomas[key]!.map((sintoma) {
                            return CustomPaint(
                              size: const Size(10, 10),
                              painter: ShapeMarkerPainter(
                                color: Color(int.parse(sintoma.color)),
                                timeOfDay: sintoma.timeOfDay,
                              ),
                            );
                          }).toList(),
                        );
                      }
                      return null;
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      final key = _fechaAClave(day);
                      final hasSymptoms = _sintomas.containsKey(key);
                      
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: hasSymptoms ? Colors.grey.withOpacity(0.1) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: hasSymptoms 
                                ? Theme.of(context).primaryColor
                                : null,
                            ),
                          ),
                        ),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      final key = _fechaAClave(day);
                      final hasSymptoms = _sintomas.containsKey(key);
                      
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                    todayBuilder: (context, day, focusedDay) {
                      final key = _fechaAClave(day);
                      final hasSymptoms = _sintomas.containsKey(key);
                      
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: hasSymptoms 
                            ? Colors.blue.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: hasSymptoms 
                                ? Colors.blue.shade900
                                : Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bar_chart),
                label: const Text('Ver Estadísticas'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StatisticsScreen(
                        symptoms: _sintomas,
                        tags: _tags,
                        userName: widget.user.name,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShapeMarkerPainter extends CustomPainter {
  final Color color;
  final String timeOfDay;

  ShapeMarkerPainter({
    required this.color,
    required this.timeOfDay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    // Hacemos el área de dibujo un poco más grande para las flechas
    final drawingSize = size * 1.2;  // 20% más grande
    final center = Offset(size.width / 2, size.height / 2);

    switch (timeOfDay) {
      case 'morning':
        // Flecha hacia arriba
        final path = Path();
        // Punta de la flecha más grande
        path.moveTo(center.dx, center.dy - drawingSize.height / 2);  // Punto superior
        path.lineTo(center.dx - drawingSize.width / 2, center.dy);   // Punto izquierdo
        path.lineTo(center.dx + drawingSize.width / 2, center.dy);   // Punto derecho
        path.close();
        canvas.drawPath(path, paint);
        break;
      
      case 'afternoon':
        // Flecha hacia abajo
        final path = Path();
        // Punta de la flecha más grande
        path.moveTo(center.dx, center.dy + drawingSize.height / 2);  // Punto inferior
        path.lineTo(center.dx - drawingSize.width / 2, center.dy);   // Punto izquierdo
        path.lineTo(center.dx + drawingSize.width / 2, center.dy);   // Punto derecho
        path.close();
        canvas.drawPath(path, paint);
        break;
      
      default:
        // Círculo (todo el día) - mantenemos el mismo tamaño que las flechas
        canvas.drawCircle(center, drawingSize.width / 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(ShapeMarkerPainter oldDelegate) {
    return color != oldDelegate.color || timeOfDay != oldDelegate.timeOfDay;
  }
} 