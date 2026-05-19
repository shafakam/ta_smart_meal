import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/ai_nutrition_provider.dart';

class AiWeeklyCard extends StatelessWidget {
  const AiWeeklyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Consumer<AiNutritionProvider>(builder: (context, prov, _) {
          if (prov.loading) {
            return const SizedBox(
                height: 180, child: Center(child: CircularProgressIndicator()));
          }
          final a = prov.analysis;
          if (a == null) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Weekly Insight',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('No analysis yet. Save your profile to get insights.',
                    style: TextStyle(color: Colors.black54)),
              ],
            );
          }

          final avgKcal = a['avgDailyCalories']?.toStringAsFixed(0) ??
              a['avgDailyCalories']?.toString() ??
              '-';
          final weightDelta = (a['predictedWeeklyChange'] != null)
              ? '${(a['predictedWeeklyChange']).toStringAsFixed(2)} kg'
              : '-';
          final topFoods = (a['topFoods'] is List)
              ? (a['topFoods'] as List).join(', ')
              : '-';

          final daily = (a['dailyCalories'] is List)
              ? List<int>.from(
                  a['dailyCalories'].map((e) => (e as num).toInt()))
              : List<int>.generate(
                  7, (i) => (a['avgDailyCalories'] ?? 2000).toInt());
          final weightProg = (a['weightProgress'] is List)
              ? List<double>.from(
                  a['weightProgress'].map((e) => (e as num).toDouble()))
              : [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI Weekly Insight',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _Metric(label: 'Avg kcal', value: '$avgKcal')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _Metric(label: 'Weight Δ', value: weightDelta)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (daily.reduce((a, b) => a > b ? a : b))
                                      .toDouble() *
                                  1.2,
                              titlesData: FlTitlesData(
                                  show: true,
                                  leftTitles: const AxisTitles(
                                      sideTitles: SideTitles(
                                          showTitles: true, reservedSize: 28)),
                                  bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final idx = value.toInt();
                                            final labels = [
                                              'Mon',
                                              'Tue',
                                              'Wed',
                                              'Thu',
                                              'Fri',
                                              'Sat',
                                              'Sun'
                                            ];
                                            return Text(
                                                labels[idx % labels.length],
                                                style: const TextStyle(
                                                    fontSize: 10));
                                          }))),
                              barGroups: List.generate(
                                  daily.length,
                                  (i) => BarChartGroupData(x: i, barRods: [
                                        BarChartRodData(
                                            toY: daily[i].toDouble(),
                                            color: Colors.blueAccent)
                                      ])),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: LineChart(
                            LineChartData(
                              minY: weightProg.isEmpty
                                  ? 0
                                  : weightProg.reduce((a, b) => a < b ? a : b) -
                                      2,
                              maxY: weightProg.isEmpty
                                  ? 1
                                  : weightProg.reduce((a, b) => a > b ? a : b) +
                                      2,
                              titlesData: const FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false))),
                              lineBarsData: [
                                LineChartBarData(
                                    spots: List.generate(
                                        weightProg.length,
                                        (i) => FlSpot(
                                            i.toDouble(), weightProg[i])),
                                    isCurved: true,
                                    barWidth: 2,
                                    color: Colors.green)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Top foods: $topFoods',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              if (a['overeating'] == true)
                const Text('Detected: Overeating',
                    style: TextStyle(color: Colors.red)),
              if (a['highSugar'] == true)
                const Text('Detected: High sugar consumption',
                    style: TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              Consumer<AiNutritionProvider>(builder: (context, p, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton(
                        onPressed: () async {
                          // request recommendations from backend
                          await p.getRecommendations(p.analysis ?? {}, []);
                        },
                        child: p.recLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Get Smart Recommendations')),
                    const SizedBox(height: 8),
                    if (p.recommendations.isNotEmpty) ...[
                      const Text('Recommendations:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ...p.recommendations.map((r) => ListTile(
                            title:
                                Text(r['title'] ?? r['name'] ?? 'Suggestion'),
                            subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (r['reasons'] != null)
                                    Text((r['reasons'] as List).join(' • '),
                                        style: const TextStyle(fontSize: 12)),
                                  if (r['actions'] != null)
                                    Text(
                                        'Actions: ${(r['actions'] as List).join(', ')}',
                                        style: const TextStyle(fontSize: 12))
                                ]),
                          ))
                    ]
                  ],
                );
              })
            ],
          );
        }),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
