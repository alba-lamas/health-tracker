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
  final _prefsInstance = SharedPreferences.getInstance();
  final _uuid = const Uuid();
  List<SymptomTag> _tags = [];
  int selectedIntensity = 2;

  String get _userSymptomsKey => 'symptoms_${widget.user.id}';  // Use unique key
  String get _userTagsKey => 'tags_${widget.user.id}';         // Use unique key

  @override
  void initState() {
    super.initState();
    _loadSymptoms();
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

  Future<void> _loadSymptoms() async {
    final prefs = await _prefsInstance;
    final symptomsString = prefs.getString(_userSymptomsKey);  // Use unique key
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
        debugPrint('Error loading symptoms: $e');
      }
    }
  }

  Future<void> _saveSymptoms() async {
    final prefs = await _prefsInstance;
    try {
      final symptomsJson = _symptoms.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(_userSymptomsKey, json.encode(symptomsJson));  // Use unique key
    } catch (e) {
      debugPrint('Error saving symptoms: $e');
    }
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
                          _createEditTag(context, null, null, null);
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
                              _createEditTag(context, tag, null, null);
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

  Future<void> _createEditTag(BuildContext context, [SymptomTag? existingTag, DateTime? day, String? currentDescription, String? currentTime]) async {
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
                      _showNewSymptomDialog(day, null, currentDescription, currentTime);
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
                        _showNewSymptomDialog(day, null, currentDescription, currentTime);
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

    await _saveSymptoms();
    
    // Volver a mostrar el dialog of symptoms updated
    if (mounted) {
      Navigator.of(context).pop();  // Close the new symptom dialog
      _showSymptomsDialog(date);    // Show the dialog of registered symptoms
    }
  }

  Widget _buildTimeIcon(String timeOfDay) {
    IconData icon;
    switch (timeOfDay) {
      case 'morning':
        icon = Icons.wb_sunny_outlined;
        break;
      case 'afternoon':
        icon = Icons.wb_twilight;
        break;
      case 'night':
        icon = Icons.nightlight;  // o Icons.bedtime
        break;
      default:
        icon = Icons.schedule;
    }
    return Icon(icon, size: 18, color: Colors.grey);
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
    IconData icon;
    Color color;
    switch (intensity) {
      case 1:
        icon = Icons.arrow_downward;
        color = Colors.green;
        break;
      case 3:
        icon = Icons.arrow_upward;
        color = Colors.red;
        break;
      default:
        icon = Icons.remove;
        color = Colors.orange;
    }
    return Icon(icon, size: 18, color: color);
  }

  void _showSymptomsDialog(DateTime dia) {
    final key = _dateToKey(dia);
    List<Symptom> daySymptoms = _symptoms[key] ?? [];
    final localizations = AppLocalizations.of(context)!;
    final date = "${dia.day}/${dia.month}/${dia.year}";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(localizations.symptomsOf(date)),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(localizations.newSymptom),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showNewSymptomDialog(dia, null, null, null);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (daySymptoms.isEmpty)
                      Text(
                        localizations.noSymptomsRegistered,
                        textAlign: TextAlign.center,
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: daySymptoms.length,
                          itemBuilder: (context, index) {
                            final symptom = daySymptoms[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Color(int.parse(symptom.color)),
                                  radius: 12,
                                ),
                                title: Text(symptom.description),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(symptom.tag),
                                    Row(
                                      children: [
                                        _buildTimeIcon(symptom.timeOfDay),
                                        const SizedBox(width: 8),
                                        Icon(
                                          symptom.intensity == 1 ? Icons.arrow_downward :
                                          symptom.intensity == 2 ? Icons.remove :
                                          Icons.arrow_upward,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _showNewSymptomDialog(dia, symptom, null, null);
                                      },
                                      padding: const EdgeInsets.all(0),
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () {
                                        setState(() {
                                          _symptoms[key]!.remove(symptom);
                                          if (_symptoms[key]!.isEmpty) {
                                            _symptoms.remove(key);
                                          }
                                        });
                                        _saveSymptoms();
                                        Navigator.of(context).pop();
                                        _showSymptomsDialog(dia);
                                      },
                                      padding: const EdgeInsets.all(0),
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNewSymptomDialog(DateTime dia, [Symptom? symptomToEdit, String? savedDescription, String? savedTime]) {
    final localizations = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: symptomToEdit?.description ?? savedDescription ?? '');
    String? selectedTag = symptomToEdit?.tag;
    String selectedTime = symptomToEdit?.timeOfDay ?? savedTime ?? '';
    int selectedIntensity = symptomToEdit?.intensity ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(symptomToEdit == null ? localizations.newSymptom : localizations.editSymptom),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: localizations.describeSymptom,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    // Botones de selección de momento del día
                    Column(
                      children: [
                        // First row: Morning and Afternoon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.wb_sunny_outlined,
                                        size: 18,
                                        color: selectedTime == 'morning' ? Colors.grey[800] : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(localizations.morning),
                                    ],
                                  ),
                                  selected: selectedTime == 'morning',
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  backgroundColor: Colors.transparent,
                                  showCheckmark: false,
                                  onSelected: (bool selected) {
                                    setDialogState(() {
                                      selectedTime = selected ? 'morning' : '';
                                    });
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.wb_twilight,
                                        size: 18,
                                        color: selectedTime == 'afternoon' ? Colors.grey[800] : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(localizations.afternoon),
                                    ],
                                  ),
                                  selected: selectedTime == 'afternoon',
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  backgroundColor: Colors.transparent,
                                  showCheckmark: false,
                                  onSelected: (bool selected) {
                                    setDialogState(() {
                                      selectedTime = selected ? 'afternoon' : '';
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Second row: Night and All day
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.nightlight,
                                        size: 18,
                                        color: selectedTime == 'night' ? Colors.grey[800] : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(localizations.night),
                                    ],
                                  ),
                                  selected: selectedTime == 'night',
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  backgroundColor: Colors.transparent,
                                  showCheckmark: false,
                                  onSelected: (bool selected) {
                                    setDialogState(() {
                                      selectedTime = selected ? 'night' : '';
                                    });
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 18,
                                        color: selectedTime == 'allday' ? Colors.grey[800] : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(localizations.allDay),
                                    ],
                                  ),
                                  selected: selectedTime == 'allday',
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  backgroundColor: Colors.transparent,
                                  showCheckmark: false,
                                  onSelected: (bool selected) {
                                    setDialogState(() {
                                      selectedTime = 'allday';
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
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
                            _createEditTag(context, null, dia, controller.text, selectedTime);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          tooltip: localizations.manageTags,
                          onPressed: () {
                            Navigator.pop(context);
                            _showTagManagementDialog(dia, controller.text, selectedTime);
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
                              selectedTime.isNotEmpty &&
                              selectedIntensity > 0)  // Quitar la validación de controller.text
                    ? () {
                        final key = _dateToKey(dia);
                        if (!_symptoms.containsKey(key)) {
                          _symptoms[key] = [];
                        }

                        setState(() {
                          _symptoms[key]!.add(Symptom(
                            id: _uuid.v4(),
                            description: controller.text,
                            tag: selectedTag!,
                            color: _tags.firstWhere((tag) => tag.name == selectedTag).color.toString(),
                            date: dia,
                            timeOfDay: selectedTime,
                            intensity: selectedIntensity,
                          ));
                        });

                        _saveSymptoms();
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
                        // First row: Morning and Afternoon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.wb_sunny_outlined,
                                        size: 18,
                                        color: selectedTime == 'morning' ? Colors.grey[800] : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        localizations.morning,
                                        style: TextStyle(
                                          color: selectedTime == 'morning' ? Colors.grey[800] : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  selected: selectedTime == 'morning',
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  backgroundColor: Colors.transparent,
                                  showCheckmark: false,
                                  onSelected: (bool selected) {
                                    setEditDialogState(() {
                                      selectedTime = selected ? 'morning' : 'allday';
                                    });
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.wb_twilight,
                                        size: 18,
                                        color: selectedTime == 'afternoon' ? Colors.grey[800] : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        localizations.afternoon,
                                        style: TextStyle(
                                          color: selectedTime == 'afternoon' ? Colors.grey[800] : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  selected: selectedTime == 'afternoon',
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  backgroundColor: Colors.transparent,
                                  showCheckmark: false,
                                  onSelected: (bool selected) {
                                    setEditDialogState(() {
                                      selectedTime = selected ? 'afternoon' : 'allday';
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Second row: Night and All day
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.nightlight,
                                        size: 18,
                                        color: selectedTime == 'night' ? Colors.grey[800] : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        localizations.night,
                                        style: TextStyle(
                                          color: selectedTime == 'night' ? Colors.grey[800] : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  selected: selectedTime == 'night',
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  backgroundColor: Colors.transparent,
                                  showCheckmark: false,
                                  onSelected: (bool selected) {
                                    setEditDialogState(() {
                                      selectedTime = selected ? 'night' : 'allday';
                                    });
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 18,
                                        color: selectedTime == 'allday' ? Colors.grey[800] : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        localizations.allDay,
                                        style: TextStyle(
                                          color: selectedTime == 'allday' ? Colors.grey[800] : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  selected: selectedTime == 'allday',
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  backgroundColor: Colors.transparent,
                                  showCheckmark: false,
                                  onSelected: (bool selected) {
                                    setEditDialogState(() {
                                      selectedTime = 'allday';
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
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
                            _createEditTag(context).then((_) {
                              setEditDialogState(() {});
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          tooltip: localizations.manageTags,
                          onPressed: () {
                            _showTagManagementDialog().then((_) {
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
                  onPressed: (controlador.text.isNotEmpty && 
                              selectedTag != null && 
                              selectedTime.isNotEmpty)  // Only validate description, tag and time
                    ? () {
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
                            timeOfDay: selectedTime,
                            intensity: selectedIntensity,
                          );
                        });
                        
                        _saveSymptoms();
                        Navigator.of(context).pop();
                        setDialogState(() {});
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