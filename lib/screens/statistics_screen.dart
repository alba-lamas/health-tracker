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
                          barGroups: activeTags.asMap().entries.map((entry) {
                            final index = entry.key;
                            final tag = entry.value;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: tagFrequency[tag.name]?.toDouble() ?? 0,
                                  color: Color(tag.color),
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }).toList(),
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
              ...filteredSymptoms.map((symptom) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Card(
                  child: ListTile(
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(int.parse(symptom.color)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(symptom.description),
                    subtitle: Row(
                      children: [
                        Text(
                          '${symptom.date.day}/${symptom.date.month}/${symptom.date.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text(' - '),
                        Text(symptom.tag),
                        const Spacer(),
                        Icon(
                          symptom.timeOfDay == 'morning'
                            ? Icons.wb_sunny_outlined
                            : symptom.timeOfDay == 'afternoon'
                              ? Icons.wb_twilight
                              : Icons.schedule,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          symptom.timeOfDay == 'morning'
                            ? localizations.morning
                            : symptom.timeOfDay == 'afternoon'
                              ? localizations.afternoon
                              : localizations.allDay,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )).toList(),
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
} 