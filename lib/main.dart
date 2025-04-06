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
  Map<String, List<Symptom>> _symptoms = {};
  final _prefsInstance = SharedPreferences.getInstance();
  final _uuid = const Uuid();
  List<SymptomTag> _tags = [];

  String get _userSymptomsKey => 'symptoms_${widget.user.id}';  // Clave única por usuario
  String get _userTagsKey => 'tags_${widget.user.id}';         // Clave única por usuario

  @override
  void initState() {
    super.initState();
    _loadSymptoms();
    _loadTags().then((_) {
      // Si no hay etiquetas guardadas, crear las predefinidas
      if (_tags.isEmpty) {
        final localizations = AppLocalizations.of(context)!;
        setState(() {
          _tags = [
            SymptomTag(
              id: _uuid.v4(),
              name: localizations.tagHead,
              color: Colors.red.value,
            ),
            SymptomTag(
              id: _uuid.v4(),
              name: localizations.tagBack,
              color: Colors.blue.value,
            ),
            SymptomTag(
              id: _uuid.v4(),
              name: localizations.tagStomach,
              color: Colors.green.value,
            ),
          ];
        });
        _saveTags();  // Guardar las etiquetas predefinidas
      }
    });
  }

  String _dateToKey(DateTime fecha) {
    return "${fecha.year}-${fecha.month}-${fecha.day}";
  }

  Future<void> _loadSymptoms() async {
    final prefs = await _prefsInstance;
    final symptomsString = prefs.getString(_userSymptomsKey);  // Usar clave única
    if (symptomsString != null) {
      try {
        final Map<String, dynamic> decodedData = json.decode(symptomsString);
        setState(() {
          _symptoms = Map.fromEntries(
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

  Future<void> _saveSymptoms() async {
    final prefs = await _prefsInstance;
    try {
      final symptomsJson = _symptoms.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(_userSymptomsKey, json.encode(symptomsJson));  // Usar clave única
    } catch (e) {
      debugPrint('Error guardando síntomas: $e');
    }
  }

  Future<void> _loadTags() async {
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

  Future<void> _saveTags() async {
    final prefs = await _prefsInstance;
    try {
      await prefs.setString(_userTagsKey, json.encode(_tags.map((e) => e.toJson()).toList()));  // Usar clave única
    } catch (e) {
      debugPrint('Error guardando tags: $e');
    }
  }

  Future<void> _clearData() async {
    final prefs = await _prefsInstance;
    await prefs.remove(_userSymptomsKey);  // Limpiar solo los datos del usuario actual
    await prefs.remove(_userTagsKey);      // Limpiar solo los datos del usuario actual
    setState(() {
      _tags = [];
      _symptoms = {};
    });
  }

  Future<void> _mostrarDialogoGestionTags() async {
    final localizations = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.manageTagsTitle),
          content: TextField(
            controller: TextEditingController(),
            decoration: InputDecoration(
              labelText: localizations.newTagLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                // ... código existente ...
              },
              child: Text(localizations.save),
            ),
          ],
        );
      },
    );
  }

  Future<void> _crearEditarTag(BuildContext context, [SymptomTag? tagExistente]) async {
    final localizations = AppLocalizations.of(context)!;
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
                title: Text(tagExistente == null ? localizations.newTag : localizations.editTag),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controlador,
                      decoration: InputDecoration(
                        labelText: localizations.tagName,
                        border: const OutlineInputBorder(),
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
                    child: Text(localizations.cancel),
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
                        _saveTags();
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(localizations.save),
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
    
    final key = _dateToKey(fecha);
    
    final nuevoSintoma = Symptom(
      id: _uuid.v4(),
      description: descripcion,
      tag: tag,
      color: color.toString(),
      date: fecha,
      timeOfDay: timeOfDay,
    );

    setState(() {
      if (!_symptoms.containsKey(key)) {
        _symptoms[key] = [];
      }
      _symptoms[key]!.add(nuevoSintoma);
    });

    await _saveSymptoms();
  }

  void _showSymptomsDialog(DateTime dia) {
    final controlador = TextEditingController();
    String? selectedTag;
    String selectedTime = 'allday';
    final key = _dateToKey(dia);
    List<Symptom> daySymptoms = _symptoms[key] ?? [];  // Cambiado a variable mutable
    final localizations = AppLocalizations.of(context)!;
    final date = "${dia.day}/${dia.month}/${dia.year}";

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
              title: Text(localizations.symptomsOf(date)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        localizations.newSymptom,
                        style: const TextStyle(
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
                        decoration: InputDecoration(
                          labelText: localizations.describeSymptom,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                      ),
                      const SizedBox(height: 24),
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
                                      localizations.morning,
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
                                  children: [
                                    Icon(
                                      Icons.wb_twilight,
                                      size: 18,
                                      color: selectedTime == 'afternoon' ? Colors.white : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      localizations.afternoon,
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
                                  localizations.allDay,
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
                          Text(localizations.selectTag),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: localizations.newTag,
                            onPressed: () {
                              _crearEditarTag(context).then((_) {
                                setDialogState(() {});
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            tooltip: localizations.manageTags,
                            onPressed: () {
                              _mostrarDialogoGestionTags().then((_) {
                                setDialogState(() {});
                              });
                            },
                          ),
                        ],
                      ),
                      if (_tags.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            localizations.noTags,
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
                        onPressed: isButtonEnabled() ? () async {
                          final tagColor = _tags.firstWhere(
                            (tag) => tag.name == selectedTag
                          ).color;
                          
                          await _guardarSintoma(
                            controlador.text,
                            selectedTag,
                            tagColor,
                            dia,
                            selectedTime,
                          );
                          
                          // Actualizar la lista local con el nuevo síntoma
                          setDialogState(() {
                            final nuevoSintoma = Symptom(
                              id: _uuid.v4(),
                              description: controlador.text,
                              tag: selectedTag!,
                              color: tagColor.toString(),
                              date: dia,
                              timeOfDay: selectedTime,
                            );
                            
                            // Si es el primer síntoma del día, inicializar la lista
                            if (daySymptoms.isEmpty) {
                              daySymptoms = [nuevoSintoma];
                            } else {
                              daySymptoms.add(nuevoSintoma);
                            }
                            
                            // Limpiar el formulario
                            controlador.clear();
                            selectedTag = null;
                            selectedTime = 'allday';
                          });
                        } : null,
                        child: Text(localizations.save),
                      ),
                      
                      if (daySymptoms.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        Text(
                          localizations.registeredSymptoms,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...daySymptoms.map((sintoma) => Card(
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
                                    _editSymptom(sintoma, dia, setDialogState);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setDialogState(() {
                                      _symptoms[key]!.remove(sintoma);
                                      if (_symptoms[key]!.isEmpty) {
                                        _symptoms.remove(key);
                                      }
                                    });
                                    _saveSymptoms();
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
                    child: Text(localizations.close),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editSymptom(Symptom sintoma, DateTime dia, Function setDialogState) {
    final localizations = AppLocalizations.of(context)!;
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
              title: Text(localizations.editSymptomTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controlador,
                      decoration: InputDecoration(
                        labelText: localizations.editSymptomDescription,
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
                                    localizations.morning,
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
                                    localizations.afternoon,
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
                                localizations.allDay,
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
                        Text(localizations.selectTag),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: localizations.newTag,
                          onPressed: () {
                            _crearEditarTag(context).then((_) {
                              setEditDialogState(() {});
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          tooltip: localizations.manageTags,
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
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          localizations.noTags,
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
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: selectedTag == null || controlador.text.isEmpty ? null : () {
                    final tagColor = _tags.firstWhere(
                      (tag) => tag.name == selectedTag
                    ).color;
                    
                    setState(() {
                      final key = _dateToKey(dia);
                      final index = _symptoms[key]!.indexWhere((s) => s.id == sintoma.id);
                      _symptoms[key]![index] = Symptom(
                        id: sintoma.id,
                        description: controlador.text,
                        tag: selectedTag!,
                        color: tagColor.toString(),
                        date: sintoma.date,
                        timeOfDay: selectedTime,  // Guardar el nuevo horario
                      );
                    });
                    
                    _saveSymptoms();
                    Navigator.of(context).pop();
                    setDialogState(() {});
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
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
                      title: Text(localizations.logoutConfirmation),
                      content: Text(localizations.logoutMessage(widget.user.name)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(localizations.cancel),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onLogout();
                          },
                          child: Text(localizations.logout),
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
                    _showSymptomsDialog(selectedDay);
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
                      final key = _dateToKey(date);
                      if (_symptoms.containsKey(key)) {
                        return Wrap(
                          spacing: 2,
                          children: _symptoms[key]!.map((sintoma) {
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
                      final key = _dateToKey(day);
                      final hasSymptoms = _symptoms.containsKey(key);
                      
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
                      final key = _dateToKey(day);
                      final hasSymptoms = _symptoms.containsKey(key);
                      
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
                      final key = _dateToKey(day);
                      final hasSymptoms = _symptoms.containsKey(key);
                      
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
                label: Text(AppLocalizations.of(context)?.viewStatistics ?? 'Ver Estadísticas'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StatisticsScreen(
                        symptoms: _symptoms,
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