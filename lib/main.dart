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
import 'package:intl/intl.dart';
import 'models/medication.dart';

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

  Future<void> _saveUsers(List<User> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('users', json.encode(users.map((e) => e.toJson()).toList()));
    setState(() {
      _users = users;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Create theme based on user color
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
      theme: theme,  // Use custom theme
      home: Builder(
        builder: (context) => _selectedUser == null
          ? UserSelectionScreen(
              users: _users,
              onUserSelected: (user) {
                setState(() {
                  _selectedUser = user;
                });
              },
              onUsersUpdated: _saveUsers,
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
  Map<String, List<Medication>> _medications = {};
  final _prefsInstance = SharedPreferences.getInstance();
  final _uuid = const Uuid();
  List<SymptomTag> _tags = [];
  int selectedIntensity = 2;
  String selectedDose = '';
  Set<String> _visibleMarkers = {'symptoms', 'medications'};  // Por defecto mostrar ambos

  String get _userSymptomsKey => 'symptoms_${widget.user.id}';  // Use unique key
  String get _userTagsKey => 'tags_${widget.user.id}';         // Use unique key

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadTags().then((_) {
      // If there are no saved tags, create default ones
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
        _saveTags();  // Save default tags
      }
    });
  }

  String _dateToKey(DateTime fecha) {
    return "${fecha.year}-${fecha.month}-${fecha.day}";
  }

  Future<void> _loadData() async {
    final prefs = await _prefsInstance;
    
    // Load symptoms
    final symptomsJson = prefs.getString(_userSymptomsKey);
    if (symptomsJson != null) {
      final Map<String, dynamic> decoded = json.decode(symptomsJson);
      _symptoms = decoded.map((key, value) => MapEntry(
        key,
        (value as List).map((item) => Symptom.fromJson(item)).toList(),
      ));
    }

    // Load medications
    final medicationsJson = prefs.getString('medications_${widget.user.id}');
    if (medicationsJson != null) {
      final Map<String, dynamic> decoded = json.decode(medicationsJson);
      _medications = decoded.map((key, value) => MapEntry(
        key,
        (value as List).map((item) => Medication.fromJson(item)).toList(),
      ));
    }

    // Load tags
    final tagsJson = prefs.getString('tags_${widget.user.id}');
    if (tagsJson != null) {
      _tags = (json.decode(tagsJson) as List)
          .map((item) => SymptomTag.fromJson(item))
          .toList();
    }
  }

  Future<void> _saveData() async {
    final prefs = await _prefsInstance;
    
    // Save symptoms
    final symptomsJson = json.encode(_symptoms.map(
      (key, value) => MapEntry(key, value.map((s) => s.toJson()).toList()),
    ));
    await prefs.setString(_userSymptomsKey, symptomsJson);

    // Save medications
    final medicationsJson = json.encode(_medications.map(
      (key, value) => MapEntry(key, value.map((m) => m.toJson()).toList()),
    ));
    await prefs.setString('medications_${widget.user.id}', medicationsJson);

    await prefs.setString('tags_${widget.user.id}', json.encode(_tags.map((t) => t.toJson()).toList()));
  }

  Future<void> _loadTags() async {
    final prefs = await _prefsInstance;
    final tagsString = prefs.getString(_userTagsKey);  // Use unique key
    if (tagsString != null) {
      try {
        final List<dynamic> decodedData = json.decode(tagsString);
        setState(() {
          _tags = decodedData
              .map((item) => SymptomTag.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        });
      } catch (e) {
        debugPrint('Error loading tags: $e');
      }
    }
  }

  Future<void> _saveTags() async {
    final prefs = await _prefsInstance;
    try {
      await prefs.setString(_userTagsKey, json.encode(_tags.map((e) => e.toJson()).toList()));  // Use unique key
    } catch (e) {
      debugPrint('Error saving tags: $e');
    }
  }

  Future<void> _clearData() async {
    final prefs = await _prefsInstance;
    await prefs.remove(_userSymptomsKey);  // Clean only current user data
    await prefs.remove(_userTagsKey);      // Clean only current user data
    setState(() {
      _tags = [];
      _symptoms = {};
    });
  }

  Future<void> _showTagManagementDialog([DateTime? day, String? currentDescription, String? currentTime]) async {
    final localizations = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(localizations.manageTagsTitle),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _tags.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _tags.length) {
                      return ListTile(
                        leading: const Icon(Icons.add),
                        title: Text(localizations.newTag),
                        onTap: () {
                          Navigator.pop(context);
                          _createEditTag(context, null, null, null, null);
                        },
                      );
                    }
                    
                    final tag = _tags[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(tag.color),
                        radius: 12,
                      ),
                      title: Text(tag.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.pop(context);
                              _createEditTag(context, tag, null, null, null);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              _deleteTag(tag, setState);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (day != null) {
                      _showNewSymptomDialog(day, null, currentDescription, currentTime);
                    }
                  },
                  child: Text(localizations.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createEditTag(
    BuildContext context, 
    [SymptomTag? existingTag, 
    DateTime? day, 
    String? currentDescription, 
    String? currentTime,
    Symptom? symptomToEdit  // Añadir el parámetro
  ]) async {
    final localizations = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: existingTag?.name ?? '');
    Color selectedColor = Color(existingTag?.color ?? Colors.blue.value);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingTag == null ? localizations.newTag : localizations.editTag),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
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
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    if (day != null) {
                      _showNewSymptomDialog(
                        day, 
                        symptomToEdit,  // Pasar el síntoma que se está editando
                        currentDescription, 
                        currentTime
                      );
                    }
                  },
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      setState(() {
                        if (existingTag == null) {
                          _tags.add(SymptomTag(
                            id: _uuid.v4(),
                            name: controller.text,
                            color: selectedColor.value,
                          ));
                        } else {
                          final index = _tags.indexWhere((t) => t.id == existingTag.id);
                          if (index != -1) {
                            _tags[index] = SymptomTag(
                              id: existingTag.id,
                              name: controller.text,
                              color: selectedColor.value,
                            );

                            // Actualizar todos los symptoms that use this tag
                            _symptoms.forEach((date, symptoms) {
                              for (var i = 0; i < symptoms.length; i++) {
                                if (symptoms[i].tag == existingTag.name) {
                                  symptoms[i] = symptoms[i].copyWith(
                                    color: selectedColor.value.toString(),
                                    tag: controller.text,
                                  );
                                }
                              }
                            });
                          }
                        }
                      });
                      _saveTags();
                      Navigator.of(dialogContext).pop();
                      if (day != null) {
                        _showNewSymptomDialog(
                          day, 
                          symptomToEdit,  // Pasar el síntoma que se está editando
                          currentDescription, 
                          currentTime
                        );
                      }
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

  Future<void> _saveSymptom(
    String description, 
    String? tag, 
    int color, 
    DateTime date,
    String timeOfDay,
    int intensity,
  ) async {
    if (tag == null) return;
    
    final key = _dateToKey(date);
    
    final nuevoSintoma = Symptom(
      id: _uuid.v4(),
      description: description,
      tag: tag,
      color: color.toString(),
      date: date,
      timeOfDay: timeOfDay,
      intensity: intensity,
    );

    setState(() {
      if (!_symptoms.containsKey(key)) {
        _symptoms[key] = [];
      }
      _symptoms[key]!.add(nuevoSintoma);
    });

    await _saveData();
    
    // Volver a mostrar el dialog of symptoms updated
    if (mounted) {
      Navigator.of(context).pop();  // Close the new symptom dialog
      _showSymptomsDialog(date);    // Show the dialog of registered symptoms
    }
  }

  Widget _buildTimeIcon(String timeOfDay, {double size = 18, Color? color}) {
    return Icon(
      timeOfDay == 'morning' ? Icons.wb_sunny_outlined :
      timeOfDay == 'afternoon' ? Icons.wb_twilight :
      timeOfDay == 'night' ? Icons.nightlight :
      Icons.schedule,
      size: size,
      color: color ?? Colors.grey[600],  // Usar el color proporcionado o gris como fallback
    );
  }

  Widget _buildCalendarMarker(String timeOfDay) {
    final color = Colors.grey;
    return CustomPaint(
      size: const Size(24, 24),
      painter: ShapeMarkerPainter(
        color: color,
        timeOfDay: timeOfDay,
      ),
    );
  }

  Widget _buildIntensityIcon(int intensity) {
    return Icon(
      intensity == 1 ? Icons.arrow_downward :
      intensity == 3 ? Icons.arrow_upward :
      Icons.remove,
      size: 18,
      color: intensity == 1 ? Colors.green :
             intensity == 3 ? Colors.red :
             Colors.orange,
    );
  }

  void _showSymptomsDialog(DateTime day) {
    final localizations = AppLocalizations.of(context)!;
    final key = _dateToKey(day);
    final symptoms = _symptoms[key] ?? [];
    final medications = _medications[key] ?? [];
    bool showingMedications = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(  // Cambiado de AlertDialog a Dialog para más control
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),  // Reducir márgenes
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,  // Usar 95% del ancho de pantalla
                constraints: const BoxConstraints(maxWidth: 600),  // Máximo ancho en tablets
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('d MMMM yyyy', Localizations.localeOf(context).languageCode).format(day),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<bool>(
                            segments: [
                              ButtonSegment<bool>(
                                value: false,
                                label: Text(localizations.symptom),
                                icon: const Icon(Icons.sick),
                              ),
                              ButtonSegment<bool>(
                                value: true,
                                label: Text(localizations.medication),
                                icon: const Icon(Icons.medication),
                              ),
                            ],
                            selected: {showingMedications},
                            onSelectionChanged: (Set<bool> newSelection) {
                              setDialogState(() {
                                showingMedications = newSelection.first;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Flexible(  // Hacer que el contenido sea scrollable si es muy largo
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  showingMedications 
                                    ? localizations.medication
                                    : localizations.symptom,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _showNewSymptomDialog(day, null, '', '', showingMedications);
                                  },
                                ),
                              ],
                            ),
                            if ((showingMedications ? medications : symptoms).isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(localizations.noSymptomsRegistered),
                              )
                            else
                              ...(showingMedications ? medications : symptoms)
                                  .map((item) => _buildItemCard(item, day)),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(localizations.close),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNewSymptomDialog(
    DateTime dia, 
    dynamic itemToEdit, 
    String? currentDescription,
    String? currentTime,
    [bool isNewMedication = false]  // Renombrado para evitar conflicto
  ) {
    final localizations = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: itemToEdit?.description ?? currentDescription ?? '');
    String? selectedTag = itemToEdit?.tag;
    Set<String> selectedTimes = (currentTime?.isEmpty ?? true)
        ? {'allday'} 
        : currentTime == 'allday' 
          ? {'allday'} 
          : {currentTime!};
    bool isMedication = itemToEdit != null ? itemToEdit is Medication : isNewMedication;  // Usar el parámetro renombrado
    String selectedDose = itemToEdit is Medication ? itemToEdit.dose : '';
    int selectedIntensity = itemToEdit is Symptom ? itemToEdit.intensity : 2;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itemToEdit == null ? localizations.newItem : localizations.editItem),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(localizations.symptom),
                        icon: const Icon(Icons.sick),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(localizations.medication),
                        icon: const Icon(Icons.medication),
                      ),
                    ],
                    selected: {isMedication},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setDialogState(() {
                        isMedication = newSelection.first;
                      });
                    },
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: isMedication 
                          ? localizations.describeMedication 
                          : localizations.describeSymptom,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: Text(localizations.morning),
                          selected: selectedTimes.contains('morning'),
                          onSelected: (bool selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedTimes.remove('allday');
                                selectedTimes.add('morning');
                              } else if (selectedTimes.length > 1) {
                                selectedTimes.remove('morning');
                              }
                              if (selectedTimes.isEmpty) {
                                selectedTimes.add('allday');
                              }
                            });
                          },
                        ),
                        FilterChip(
                          label: Text(localizations.afternoon),
                          selected: selectedTimes.contains('afternoon'),
                          onSelected: (bool selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedTimes.remove('allday');
                                selectedTimes.add('afternoon');
                              } else if (selectedTimes.length > 1) {
                                selectedTimes.remove('afternoon');
                              }
                              if (selectedTimes.isEmpty) {
                                selectedTimes.add('allday');
                              }
                            });
                          },
                        ),
                        FilterChip(
                          label: Text(localizations.night),
                          selected: selectedTimes.contains('night'),
                          onSelected: (bool selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedTimes.remove('allday');
                                selectedTimes.add('night');
                              } else if (selectedTimes.length > 1) {
                                selectedTimes.remove('night');
                              }
                              if (selectedTimes.isEmpty) {
                                selectedTimes.add('allday');
                              }
                            });
                          },
                        ),
                        FilterChip(
                          label: Text(localizations.allDay),
                          selected: selectedTimes.contains('allday'),
                          onSelected: (bool selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedTimes.clear();
                                selectedTimes.add('allday');
                              }
                            });
                          },
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
                            Navigator.pop(context);
                            _createEditTag(
                              context, 
                              null, 
                              dia, 
                              controller.text, 
                              selectedTimes.first,
                              itemToEdit
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          tooltip: localizations.manageTags,
                          onPressed: () {
                            Navigator.pop(context);
                            _showTagManagementDialog(dia, controller.text, selectedTimes.first);
                          },
                        ),
                      ],
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
                          setDialogState(() {
                            selectedTag = selected ? tag.name : null;
                          });
                        },
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                    if (isMedication) ...[
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          labelText: localizations.dose,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          selectedDose = value;
                        },
                        controller: TextEditingController(text: selectedDose),
                      ),
                    ] else ...[
                      // Sección existente de intensidad
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(localizations.intensity),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ChoiceChip(
                            label: Text(localizations.intensityMild),
                            selected: selectedIntensity == 1,
                            selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            backgroundColor: Colors.transparent,
                            onSelected: (bool selected) {
                              setDialogState(() {
                                selectedIntensity = selected ? 1 : 2;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text(localizations.intensityModerate),
                            selected: selectedIntensity == 2,
                            selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            backgroundColor: Colors.transparent,
                            onSelected: (bool selected) {
                              setDialogState(() {
                                selectedIntensity = 2;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text(localizations.intensityStrong),
                            selected: selectedIntensity == 3,
                            selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            backgroundColor: Colors.transparent,
                            onSelected: (bool selected) {
                              setDialogState(() {
                                selectedIntensity = selected ? 3 : 2;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showSymptomsDialog(dia);
                  },
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: (selectedTag != null && 
                              selectedTimes.isNotEmpty &&
                              (!isMedication || selectedIntensity > 0))
                    ? () {
                        final timeOfDay = selectedTimes.length > 1 ? 'allday' : selectedTimes.first;
                        final key = _dateToKey(dia);
                        if (itemToEdit != null) {
                          if (isMedication) {
                            if (!_medications.containsKey(key)) {
                              _medications[key] = [];
                            }
                            final index = _medications[key]!.indexWhere((m) => m.id == itemToEdit.id);
                            if (index != -1) {
                              setState(() {
                                _medications[key]![index] = Medication(
                                  id: itemToEdit.id,
                                  description: controller.text,
                                  tag: selectedTag!,
                                  color: _tags.firstWhere((tag) => tag.name == selectedTag).color.toString(),
                                  date: dia,
                                  timeOfDay: timeOfDay,
                                  dose: selectedDose,
                                );
                              });
                            }
                          } else {
                            if (!_symptoms.containsKey(key)) {
                              _symptoms[key] = [];
                            }
                            final index = _symptoms[key]!.indexWhere((s) => s.id == itemToEdit.id);
                            if (index != -1) {
                              setState(() {
                                _symptoms[key]![index] = Symptom(
                                  id: itemToEdit.id,
                                  description: controller.text,
                                  tag: selectedTag!,
                                  color: _tags.firstWhere((tag) => tag.name == selectedTag).color.toString(),
                                  date: dia,
                                  timeOfDay: timeOfDay,
                                  intensity: selectedIntensity,
                                );
                              });
                            }
                          }
                        } else {
                          if (isMedication) {
                            if (!_medications.containsKey(key)) {
                              _medications[key] = [];
                            }
                            _medications[key]!.add(Medication(
                              id: _uuid.v4(),
                              description: controller.text,
                              tag: selectedTag!,
                              color: _tags.firstWhere((tag) => tag.name == selectedTag).color.toString(),
                              date: dia,
                              timeOfDay: timeOfDay,
                              dose: selectedDose,
                            ));
                          } else {
                            if (!_symptoms.containsKey(key)) {
                              _symptoms[key] = [];
                            }
                            _symptoms[key]!.add(Symptom(
                              id: _uuid.v4(),
                              description: controller.text,
                              tag: selectedTag!,
                              color: _tags.firstWhere((tag) => tag.name == selectedTag).color.toString(),
                              date: dia,
                              timeOfDay: timeOfDay,
                              intensity: selectedIntensity,
                            ));
                          }
                        }

                        _saveData();
                        setState(() {});
                        Navigator.of(context).pop();
                        _showSymptomsDialog(dia);
                      }
                    : null,
                  child: Text(localizations.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Añadir botón de filtro antes del botón de logout
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                if (_visibleMarkers.contains(value)) {
                  _visibleMarkers.remove(value);  // Permitir desmarcar aunque no quede ninguna opción
                } else {
                  _visibleMarkers.add(value);
                }
              });
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'symptoms',
                checked: _visibleMarkers.contains('symptoms'),
                child: Text(localizations.symptom),
              ),
              CheckedPopupMenuItem(
                value: 'medications',
                checked: _visibleMarkers.contains('medications'),
                child: Text(localizations.medication),
              ),
            ],
          ),
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
          const SizedBox(width: 16),  // Space at the end
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TableCalendar(
                  locale: Localizations.localeOf(context).languageCode,
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
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
                  headerStyle: HeaderStyle(
                    titleTextFormatter: (date, locale) {
                      final month = _capitalizeFirstLetter(DateFormat.MMMM(locale).format(date));
                      final year = DateFormat.y(locale).format(date);
                      return '$month $year';
                    },
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
                    // Mark days with symptoms
                    markerDecoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 1,
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      final key = _dateToKey(date);
                      if (_symptoms.containsKey(key) || _medications.containsKey(key)) {
                        final symptoms = _visibleMarkers.contains('symptoms') ? (_symptoms[key] ?? []) : [];
                        final medications = _visibleMarkers.contains('medications') ? (_medications[key] ?? []) : [];
                        final allItems = [...symptoms, ...medications];
                        
                        if (allItems.isEmpty) return null;  // No mostrar nada si no hay items visibles
                        
                        return Positioned(
                          bottom: 1,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 1.5,
                            runSpacing: 1.5,
                            children: allItems.take(6).map((dynamic item) {
                              final timeOfDay = (item is Symptom || item is Medication) 
                                ? item.timeOfDay 
                                : 'allday';
                              final color = (item is Symptom || item is Medication)
                                ? Color(int.parse(item.color))
                                : Colors.grey[600]!;
                              return Container(
                                width: 10,
                                height: 10,
                                child: Icon(
                                  // Usar diferentes iconos según el tipo
                                  item is Medication
                                    ? (timeOfDay == 'morning' ? Icons.medication :
                                       timeOfDay == 'afternoon' ? Icons.medication_liquid :
                                       timeOfDay == 'night' ? Icons.medication :
                                       Icons.medical_services)
                                    : (timeOfDay == 'morning' ? Icons.wb_sunny_outlined :
                                       timeOfDay == 'afternoon' ? Icons.wb_twilight :
                                       timeOfDay == 'night' ? Icons.nightlight :
                                       Icons.schedule),
                                  size: 10,
                                  color: color,
                                ),
                              );
                            }).toList(),
                          ),
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
                        medications: _medications,
                        tags: _tags,
                        userName: widget.user.name,
                        user: widget.user,
                        onLogout: widget.onLogout,
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

  Future<void> _deleteTag(SymptomTag tag, Function setState) async {
    final localizations = AppLocalizations.of(context)!;
    
    // Buscar todos los symptoms that use this tag
    Map<String, List<DateTime>> usedDates = {};
    _symptoms.forEach((dateKey, symptoms) {
      final datesWithTag = symptoms
          .where((s) => s.tag == tag.name)
          .map((s) => s.date)  // Use the date directly
          .toList();
      if (datesWithTag.isNotEmpty) {
        usedDates[dateKey] = datesWithTag;
      }
    });

    if (usedDates.isEmpty) {
      // If the tag is not in use, delete it directly
      this.setState(() {
        _tags.remove(tag);
      });
      _saveTags();
      setState(() {});
    } else {
      // If the tag is in use, show warning dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(localizations.cannotDeleteTag),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizations.tagInUseMessage),
                const SizedBox(height: 8),
                Text(localizations.datesWithTag),
                const SizedBox(height: 4),
                ...usedDates.entries.map((entry) {
                  final date = entry.value.first;  // Take the first date from the list
                  return Text(
                    '• ${DateFormat('d/M/y').format(date)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  );
                }),
                const SizedBox(height: 8),
                Text(localizations.changeTagsBeforeDelete),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(localizations.ok),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildItemCard(dynamic item, DateTime day) {
    final localizations = AppLocalizations.of(context)!;
    final bool isMedication = item is Medication;
    final itemColor = Color(int.parse(item.color));

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTimeIcon(item.timeOfDay, size: 18, color: itemColor),
                if (!isMedication) ...[
                  const SizedBox(height: 4),
                  _buildIntensityIcon(item.intensity),
                ],
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.description),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: itemColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        item.tag,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (isMedication) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${localizations.dose}: ${item.dose}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showNewSymptomDialog(
                      day,
                      item,
                      item.description,
                      item.timeOfDay,
                    );
                  },
                ),
                const SizedBox(height: 4),
                IconButton(
                  icon: const Icon(Icons.delete),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      final key = _dateToKey(day);
                      if (isMedication) {
                        _medications[key]?.removeWhere((m) => m.id == item.id);
                        if (_medications[key]?.isEmpty ?? false) {
                          _medications.remove(key);
                        }
                      } else {
                        _symptoms[key]?.removeWhere((s) => s.id == item.id);
                        if (_symptoms[key]?.isEmpty ?? false) {
                          _symptoms.remove(key);
                        }
                      }
                    });
                    _saveData();
                    Navigator.of(context).pop();
                    _showSymptomsDialog(day);
                  },
                ),
              ],
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

    switch (timeOfDay) {
      case 'morning':
        // Upward arrow (triangle)
        final path = Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case 'afternoon':
        // Downward arrow (inverted triangle)
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case 'night':
        // Crescent moon
        final outerCircle = Path()
          ..addArc(
            Rect.fromLTWH(0, 0, size.width, size.height),
            0,
            3.14 * 2,
          );
        final innerCircle = Path()
          ..addArc(
            Rect.fromLTWH(size.width * 0.2, 0, size.width, size.height),
            0,
            3.14 * 2,
          );
        canvas.drawPath(
          Path.combine(PathOperation.difference, outerCircle, innerCircle),
          paint,
        );
        break;
      default:
        // Full circle for "all day"
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          size.width / 2,
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
} 