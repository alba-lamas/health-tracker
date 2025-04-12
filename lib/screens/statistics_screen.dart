import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/symptom.dart';
import '../models/tag.dart';
import '../models/user.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:io';

class StatisticsScreen extends StatefulWidget {
  final Map<String, List<Symptom>> symptoms;
  final List<SymptomTag> tags;
  final String userName;
  final User user;
  final VoidCallback onLogout;

  const StatisticsScreen({
    super.key,
    required this.symptoms,
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
                ...groupSymptomsByDate(filteredSymptoms).entries.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        '${entry.key.day}/${entry.key.month}/${entry.key.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    ...entry.value.map((symptom) => ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(int.parse(symptom.color)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(symptom.description),
                      subtitle: Text(symptom.tag),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTimeIcon(symptom.timeOfDay),
                          const SizedBox(width: 4),
                          _buildIntensityIcon(symptom.intensity),
                        ],
                      ),
                    )),
                  ],
                )),
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

  // Añadir este método para construir el icono de tiempo
  Widget _buildTimeIcon(String timeOfDay) {
    IconData icon;
    Color color;
    switch (timeOfDay) {
      case 'morning':
        icon = Icons.wb_sunny_outlined;
        color = Colors.yellow;
        break;
      case 'afternoon':
        icon = Icons.wb_twilight;
        color = Colors.orange;
        break;
      case 'night':
        icon = Icons.nightlight;
        color = Colors.blue;
        break;
      default:
        icon = Icons.schedule;
        color = Colors.blue;
    }
    return Icon(icon, size: 18, color: color);
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

  // Primero, creamos una estructura para almacenar las frecuencias por intensidad
  Map<String, Map<int, int>> _calculateTagFrequencyByIntensity() {
    final Map<String, Map<int, int>> frequency = {};
    
    // Inicializar el mapa para todas las etiquetas
    for (var tag in widget.tags) {
      frequency[tag.name] = {
        1: 0,  // leve
        2: 0,  // moderado
        3: 0,  // fuerte
      };
    }

    // Contar síntomas por etiqueta e intensidad
    for (var symptom in _getFilteredSymptoms()) {
      if (frequency.containsKey(symptom.tag)) {  // Verificar que la etiqueta existe
        final intensityMap = frequency[symptom.tag]!;
        final intensity = symptom.intensity.clamp(1, 3);  // Asegurar valor válido
        intensityMap[intensity] = (intensityMap[intensity] ?? 0) + 1;
      }
    }

    return frequency;
  }

  // Luego, modificamos la generación de las barras
  BarChartGroupData _generateBarGroup(
    int x,
    String tagName,
    Color baseColor,
    Map<int, int> intensityCount,
  ) {
    final leve = intensityCount[1] ?? 0;
    final moderado = intensityCount[2] ?? 0;
    final fuerte = intensityCount[3] ?? 0;
    final total = leve + moderado + fuerte;

    if (total == 0) return BarChartGroupData(x: x, barRods: []);

    // Convertir el color base a HSL para ajustar la luminosidad
    final hslColor = HSLColor.fromColor(baseColor);

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: total.toDouble(),
          width: 20,
          borderRadius: BorderRadius.zero,
          rodStackItems: [
            // Leve (más claro)
            BarChartRodStackItem(
              0,
              leve.toDouble(),
              hslColor.withLightness((hslColor.lightness + 0.3).clamp(0.0, 1.0)).toColor(),
            ),
            // Moderado (normal)
            BarChartRodStackItem(
              leve.toDouble(),
              (leve + moderado).toDouble(),
              baseColor,
            ),
            // Fuerte (más oscuro)
            BarChartRodStackItem(
              (leve + moderado).toDouble(),
              total.toDouble(),
              hslColor.withLightness((hslColor.lightness - 0.2).clamp(0.0, 1.0)).toColor(),
            ),
          ],
        ),
      ],
    );
  }

  // Y actualizamos la parte donde creamos el gráfico
  List<BarChartGroupData> _generateBarGroups() {
    final frequencyByIntensity = _calculateTagFrequencyByIntensity();
    final activeTags = widget.tags
        .where((tag) {
          final intensities = frequencyByIntensity[tag.name];
          return intensities != null && 
                 intensities.values.any((count) => count > 0);
        })
        .toList();

    return List.generate(
      activeTags.length,
      (index) {
        final tag = activeTags[index];
        final intensityMap = frequencyByIntensity[tag.name] ?? {1: 0, 2: 0, 3: 0};
        return _generateBarGroup(
          index,
          tag.name,
          Color(tag.color),
          intensityMap,
        );
      },
    );
  }
} 