import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/symptom.dart';
import '../models/tag.dart';

class StatisticsScreen extends StatelessWidget {
  final Map<String, List<Symptom>> symptoms;
  final List<SymptomTag> tags;
  final String userName;

  const StatisticsScreen({
    super.key,
    required this.symptoms,
    required this.tags,
    required this.userName,
  });

  Map<String, int> _calculateTagFrequency() {
    final Map<String, int> frequency = {};
    
    // Inicializar el mapa con todas las etiquetas en 0
    for (var tag in tags) {
      frequency[tag.name] = 0;
    }

    // Contar ocurrencias de cada etiqueta
    for (var daySymptoms in symptoms.values) {
      for (var symptom in daySymptoms) {
        frequency[symptom.tag] = (frequency[symptom.tag] ?? 0) + 1;
      }
    }

    return frequency;
  }

  @override
  Widget build(BuildContext context) {
    final tagFrequency = _calculateTagFrequency();
    final maxValue = tagFrequency.values.fold(0, (max, value) => value > max ? value : max);

    return Scaffold(
      appBar: AppBar(
        title: Text('Estadísticas de ${userName}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Frecuencia de Síntomas por Etiqueta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0, bottom: 40.0),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxValue.toDouble(),
                      barGroups: tags.asMap().entries.map((entry) {
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
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: RotatedBox(
                                  quarterTurns: 1,
                                  child: Text(
                                    tags[value.toInt()].name,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            },
                            reservedSize: 60,
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
            ],
          ),
        ),
      ),
    );
  }
} 