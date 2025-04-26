import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/symptom.dart';
import '../models/tag.dart';
import '../models/user.dart';
import '../models/medication.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  final Map<String, List<Symptom>> symptoms;
  final Map<String, List<Medication>> medications;
  final List<SymptomTag> tags;
  final String userName;
  final User user;
  final VoidCallback onLogout;

  const StatisticsScreen({
    super.key,
    required this.symptoms,
    required this.medications,
    required this.tags,
    required this.userName,
    required this.user,
    required this.onLogout,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = 'month';  // Valores: 'week', 'month', 'year', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  Set<String> _visibleDataTypes = {'symptoms', 'medications'};  // Nuevo estado

  Map<String, int> _calculateTagFrequency() {
    final Map<String, int> frequency = {};
    final now = DateTime.now();
    
    // Inicializar el mapa con todas las etiquetas en 0
    for (var tag in widget.tags) {
      frequency[tag.name] = 0;
    }

    // Filtrar síntomas según el período seleccionado
    widget.symptoms.forEach((dateStr, symptoms) {
      // Corregir el formato de la fecha
      try {
        final dateParts = dateStr.split('-');
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        final date = DateTime(year, month, day);
        
        bool includeSymptoms = false;

        switch (_selectedPeriod) {
          case 'week':
            includeSymptoms = now.difference(date).inDays <= 7;
            break;
          case 'month':
            includeSymptoms = date.year == now.year && date.month == now.month;
            break;
          case 'year':
            includeSymptoms = date.year == now.year;
            break;
          case 'custom':
            if (_customStartDate != null && _customEndDate != null) {
              includeSymptoms = !date.isBefore(_customStartDate!) && 
                              !date.isAfter(_customEndDate!);
            }
            break;
        }

        if (includeSymptoms) {
          for (var symptom in symptoms) {
            frequency[symptom.tag] = (frequency[symptom.tag] ?? 0) + 1;
          }
        }
      } catch (e) {
        debugPrint('Error parsing date: $dateStr');
      }
    });

    return frequency;
  }

  Future<void> _showCustomDatePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedPeriod = 'custom';
      });
    }
  }

  String _getPeriodTitle() {
    final localizations = AppLocalizations.of(context)!;
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'week':
        return localizations.lastDays;
      case 'month':
        return localizations.monthYear(
          _getMonthName(now.month),
          now.year.toString(),
        );
      case 'year':
        return localizations.yearOnly(now.year.toString());
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return localizations.dateRange(
            '${_customStartDate!.day}/${_customStartDate!.month}',
            '${_customEndDate!.day}/${_customEndDate!.month}',
          );
        }
        return localizations.customPeriod;
      default:
        return '';
    }
  }

  String _getMonthName(int month) {
    final localizations = AppLocalizations.of(context)!;
    final months = [
      localizations.january,
      localizations.february,
      localizations.march,
      localizations.april,
      localizations.may,
      localizations.june,
      localizations.july,
      localizations.august,
      localizations.september,
      localizations.october,
      localizations.november,
      localizations.december,
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final tagFrequency = _calculateTagFrequency();
    // Filtrar solo las etiquetas que tienen registros
    final activeTags = widget.tags.where((tag) => (tagFrequency[tag.name] ?? 0) > 0).toList();
    final maxValue = tagFrequency.values.fold(0, (max, value) => value > max ? value : max);
    final filteredSymptoms = _getFilteredSymptoms();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.statisticsOf(widget.userName)),
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
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(  // Añadido para permitir scroll
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de período
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: Text(localizations.last7Days),
                    selected: _selectedPeriod == 'week',
                    onSelected: (selected) {
                      setState(() => _selectedPeriod = 'week');
                    },
                  ),
                  ChoiceChip(
                    label: Text(localizations.month),
                    selected: _selectedPeriod == 'month',
                    onSelected: (selected) {
                      setState(() => _selectedPeriod = 'month');
                    },
                  ),
                  ChoiceChip(
                    label: Text(localizations.year),
                    selected: _selectedPeriod == 'year',
                    onSelected: (selected) {
                      setState(() => _selectedPeriod = 'year');
                    },
                  ),
                  ActionChip(
                    label: Text(localizations.custom),
                    onPressed: _showCustomDatePicker,
                    backgroundColor: _selectedPeriod == 'custom' 
                      ? Theme.of(context).primaryColor 
                      : null,
                    labelStyle: TextStyle(
                      color: _selectedPeriod == 'custom' ? Colors.white : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _getPeriodTitle(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0, bottom: 80.0),
                  child: activeTags.isEmpty
                    ? Center(
                        child: Text(
                          localizations.noRecordsForPeriod,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxValue.toDouble(),
                          barGroups: _generateBarGroups(),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final tagName = activeTags[value.toInt()].name;
                                  final words = tagName.split(' ');
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: RotatedBox(
                                      quarterTurns: 1,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: words.map((word) => Text(
                                          word,
                                          style: const TextStyle(fontSize: 12),
                                          textAlign: TextAlign.center,
                                        )).toList(),
                                      ),
                                    ),
                                  );
                                },
                                reservedSize: 80,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 12),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 8),
              _buildChartLegend(),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                localizations.symptomDetails,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (filteredSymptoms.isEmpty)
                Text(
                  localizations.noRecordsForPeriod,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                )
              else
                _buildStatisticsContent(
                  filteredSymptoms,
                  _getFilteredMedications(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Nueva función para obtener los síntomas filtrados
  List<Symptom> _getFilteredSymptoms() {
    final now = DateTime.now();
    final List<Symptom> filtered = [];

    widget.symptoms.forEach((dateStr, symptoms) {
      try {
        final dateParts = dateStr.split('-');
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        final date = DateTime(year, month, day);
        
        bool includeSymptoms = false;

        switch (_selectedPeriod) {
          case 'week':
            includeSymptoms = now.difference(date).inDays <= 7;
            break;
          case 'month':
            includeSymptoms = date.year == now.year && date.month == now.month;
            break;
          case 'year':
            includeSymptoms = date.year == now.year;
            break;
          case 'custom':
            if (_customStartDate != null && _customEndDate != null) {
              includeSymptoms = !date.isBefore(_customStartDate!) && 
                              !date.isAfter(_customEndDate!);
            }
            break;
        }

        if (includeSymptoms) {
          filtered.addAll(symptoms.map((s) => s.copyWith(date: date)));
        }
      } catch (e) {
        debugPrint('Error parsing date: $dateStr');
      }
    });

    // Ordenar por fecha más reciente primero
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  // Añadir este método para construir el icono de intensidad
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

  // Añadir este método para construir el icono de tiempo
  Widget _buildTimeIcon(String timeOfDay) {
    return Icon(
      timeOfDay == 'morning' ? Icons.wb_sunny_outlined :
      timeOfDay == 'afternoon' ? Icons.wb_twilight :
      timeOfDay == 'night' ? Icons.nightlight :
      Icons.schedule,
      size: 18,
      color: Colors.grey[600],
    );
  }

  // Función helper para agrupar síntomas por fecha
  Map<DateTime, List<Symptom>> groupSymptomsByDate(List<Symptom> symptoms) {
    final grouped = <DateTime, List<Symptom>>{};
    for (var symptom in symptoms) {
      final date = DateTime(
        symptom.date.year,
        symptom.date.month,
        symptom.date.day,
      );
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(symptom);
    }
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key))
    );
  }

  // Modificar para incluir tanto síntomas como medicaciones
  Map<String, Map<String, Map<int, int>>> _calculateTagFrequencyByType() {
    final Map<String, Map<String, Map<int, int>>> frequency = {};
    
    // Inicializar el mapa para todas las etiquetas
    for (var tag in widget.tags) {
      frequency[tag.name] = {
        'symptoms': {1: 0, 2: 0, 3: 0},  // Intensidades para síntomas
        'medications': {1: 0},  // Solo conteo para medicaciones
      };
    }

    // Contar síntomas
    for (var symptom in _getFilteredSymptoms()) {
      if (frequency.containsKey(symptom.tag)) {
        final intensityMap = frequency[symptom.tag]!['symptoms']!;
        final intensity = symptom.intensity.clamp(1, 3);
        intensityMap[intensity] = (intensityMap[intensity] ?? 0) + 1;
      }
    }

    // Contar medicaciones
    for (var medication in _getFilteredMedications()) {
      if (frequency.containsKey(medication.tag)) {
        final medicationMap = frequency[medication.tag]!['medications']!;
        medicationMap[1] = (medicationMap[1] ?? 0) + 1;
      }
    }

    return frequency;
  }

  BarChartGroupData _generateBarGroup(
    int x,
    String tagName,
    Color baseColor,
    Map<String, Map<int, int>> typeCount,
  ) {
    final symptomTotal = typeCount['symptoms']!.values.fold(0, (a, b) => a + b);
    final medicationTotal = typeCount['medications']!.values.fold(0, (a, b) => a + b);
    final barWidth = 12.0;
    final hslColor = HSLColor.fromColor(baseColor);

    return BarChartGroupData(
      x: x,
      groupVertically: false,
      barRods: [
        // Barra de síntomas (sólida con gradiente de intensidad)
        BarChartRodData(
          toY: symptomTotal.toDouble(),
          width: barWidth,
          borderRadius: BorderRadius.zero,
          rodStackItems: [
            // Leve (más claro)
            BarChartRodStackItem(
              0,
              typeCount['symptoms']![1]!.toDouble(),
              hslColor.withLightness((hslColor.lightness + 0.3).clamp(0.0, 1.0)).toColor(),
            ),
            // Moderado (normal)
            BarChartRodStackItem(
              typeCount['symptoms']![1]!.toDouble(),
              (typeCount['symptoms']![1]! + typeCount['symptoms']![2]!).toDouble(),
              baseColor,
            ),
            // Fuerte (más oscuro)
            BarChartRodStackItem(
              (typeCount['symptoms']![1]! + typeCount['symptoms']![2]!).toDouble(),
              symptomTotal.toDouble(),
              hslColor.withLightness((hslColor.lightness - 0.2).clamp(0.0, 1.0)).toColor(),
            ),
          ],
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: symptomTotal.toDouble(),
            color: Colors.grey[200],
          ),
        ),
        // Barra de medicaciones (con borde y relleno semitransparente)
        BarChartRodData(
          toY: medicationTotal.toDouble(),
          width: barWidth,
          color: baseColor.withOpacity(0.3),  // Color semitransparente para el relleno
          borderRadius: BorderRadius.zero,
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: medicationTotal.toDouble(),
            color: Colors.grey[200],
          ),
          borderSide: BorderSide(  // Añadir borde
            width: 2,
            color: baseColor,
          ),
        ),
      ],
      barsSpace: 4,
    );
  }

  List<BarChartGroupData> _generateBarGroups() {
    final frequencyByType = _calculateTagFrequencyByType();
    final activeTags = widget.tags
        .where((tag) {
          final counts = frequencyByType[tag.name];
          return counts != null && 
                 (_visibleDataTypes.contains('symptoms') && counts['symptoms']!.values.any((count) => count > 0) ||
                  _visibleDataTypes.contains('medications') && counts['medications']!.values.any((count) => count > 0));
        })
        .toList();

    return List.generate(
      activeTags.length,
      (index) {
        final tag = activeTags[index];
        final typeCount = frequencyByType[tag.name]!;
        
        // Si un tipo no está visible, poner sus valores en 0
        if (!_visibleDataTypes.contains('symptoms')) {
          typeCount['symptoms'] = {1: 0, 2: 0, 3: 0};
        }
        if (!_visibleDataTypes.contains('medications')) {
          typeCount['medications'] = {1: 0};
        }
        
        return _generateBarGroup(
          index,
          tag.name,
          Color(tag.color),
          typeCount,
        );
      },
    );
  }

  Widget _buildStatisticsContent(List<Symptom> symptoms, List<Medication> medications) {
    final localizations = AppLocalizations.of(context)!;
    final Map<String, List<List<dynamic>>> itemsByTag = {};
    
    // Agrupar síntomas y medicaciones por tag
    for (var symptom in symptoms) {
      if (!itemsByTag.containsKey(symptom.tag)) {
        itemsByTag[symptom.tag] = [[], []];
      }
      (itemsByTag[symptom.tag]![0] as List).add(symptom);
    }
    
    for (var medication in medications) {
      if (!itemsByTag.containsKey(medication.tag)) {
        itemsByTag[medication.tag] = [[], []];
      }
      (itemsByTag[medication.tag]![1] as List).add(medication);
    }

    return Column(
      children: [
        ...itemsByTag.entries.map((entry) {
          final symptoms = List<Symptom>.from(entry.value[0]);
          final medications = List<Medication>.from(entry.value[1]);
          final tagColor = symptoms.isNotEmpty 
              ? Color(int.parse(symptoms.first.color))
              : Color(int.parse(medications.first.color));

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: tagColor,
                        radius: 8,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (symptoms.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      localizations.symptom,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...symptoms.map((symptom) => _buildSymptomItem(symptom)),
                  ],
                  if (medications.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      localizations.medication,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...medications.map((medication) => _buildMedicationItem(medication)),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSymptomItem(Symptom symptom) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _buildTimeIcon(symptom.timeOfDay),
          const SizedBox(width: 4),
          _buildIntensityIcon(symptom.intensity),
          const SizedBox(width: 8),
          Expanded(
            child: Text(symptom.description),
          ),
          Text(DateFormat('d/M/y').format(symptom.date)),
        ],
      ),
    );
  }

  Widget _buildMedicationItem(Medication medication) {
    final localizations = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _buildTimeIcon(medication.timeOfDay),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medication.description),
                if (medication.dose.isNotEmpty)
                  Text(
                    '${localizations.dose}: ${medication.dose}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Text(DateFormat('d/M/y').format(medication.date)),
        ],
      ),
    );
  }

  List<Medication> _getFilteredMedications() {
    final now = DateTime.now();
    final List<Medication> filtered = [];

    widget.medications.forEach((dateStr, medications) {
      try {
        final dateParts = dateStr.split('-');
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        final date = DateTime(year, month, day);
        
        bool includeMedications = false;

        switch (_selectedPeriod) {
          case 'week':
            includeMedications = now.difference(date).inDays <= 7;
            break;
          case 'month':
            includeMedications = date.year == now.year && date.month == now.month;
            break;
          case 'year':
            includeMedications = date.year == now.year;
            break;
          case 'custom':
            if (_customStartDate != null && _customEndDate != null) {
              includeMedications = !date.isBefore(_customStartDate!) && 
                              !date.isAfter(_customEndDate!);
            }
            break;
        }

        if (includeMedications) {
          filtered.addAll(medications.map((m) => m.copyWith(date: date)));
        }
      } catch (e) {
        debugPrint('Error parsing date: $dateStr');
      }
    });

    // Ordenar por fecha más reciente primero
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  void _showMinimumSelectionWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.minimumSelectionRequired),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildChartLegend() {
    final localizations = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sick, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                localizations.symptom,
                style: TextStyle(
                  color: _visibleDataTypes.contains('symptoms') ? null : Colors.grey[600],
                ),
              ),
            ],
          ),
          selected: _visibleDataTypes.contains('symptoms'),
          onSelected: (bool selected) {
            if (!selected && _visibleDataTypes.length <= 1) {
              _showMinimumSelectionWarning();
              return;
            }
            setState(() {
              if (selected) {
                _visibleDataTypes.add('symptoms');
              } else {
                _visibleDataTypes.remove('symptoms');
              }
            });
          },
        ),
        const SizedBox(width: 16),
        FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.medication, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                localizations.medication,
                style: TextStyle(
                  color: _visibleDataTypes.contains('medications') ? null : Colors.grey[600],
                ),
              ),
            ],
          ),
          selected: _visibleDataTypes.contains('medications'),
          onSelected: (bool selected) {
            if (!selected && _visibleDataTypes.length <= 1) {
              _showMinimumSelectionWarning();
              return;
            }
            setState(() {
              if (selected) {
                _visibleDataTypes.add('medications');
              } else {
                _visibleDataTypes.remove('medications');
              }
            });
          },
        ),
      ],
    );
  }
} 