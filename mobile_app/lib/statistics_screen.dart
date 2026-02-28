import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart' as chart;
import 'models/flashcard_model.dart';

class StatisticsScreen extends StatelessWidget {
  final List<Flashcard> flashcards; // استخدام كائن Flashcard

  const StatisticsScreen({Key? key, required this.flashcards}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- الحسابات الإحصائية ---
    final totalCards = flashcards.length;
    final dueCards = _getDueCardsCount();
    final categories = _getCategoryCounts();
    final successRates = _getSuccessRateByType();
    final avgIntervals = _getAverageReviewIntervals();

    return Scaffold(
      appBar: AppBar(
        title: Text('الإحصائيات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStatCard(
            icon: Icons.style, 
            title: 'إجمالي البطاقات', 
            value: totalCards.toString(), 
            color: Colors.blue
          ),
          _buildStatCard(
            icon: Icons.today, 
            title: 'بطاقات مستحقة للمراجعة', 
            value: dueCards.toString(), 
            color: Colors.orange
          ),
          SizedBox(height: 20),
          Text(
            'البطاقات حسب التصنيف',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 10),
          if (categories.isEmpty)
            Center(child: Text('لا توجد تصنيفات لعرضها.'))
          else
            ...categories.entries.map((entry) {
              return Card(
                child: ListTile(
                  title: Text(entry.key),
                  trailing: Chip(
                    label: Text(entry.value.toString()),
                    backgroundColor: Colors.cyan.shade100,
                  ),
                ),
              );
            }).toList(),
          
          SizedBox(height: 20),
          Text(
            'معدل النجاح حسب نوع البطاقة',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 10),
          if (successRates.isEmpty)
            Center(child: Text('لا توجد بيانات لنجاح البطاقات.'))
          else
            _buildSuccessRateChart(successRates),
          
          SizedBox(height: 30),
          Text(
            'توزيع البطاقات حسب التصنيف',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 10),
          if (categories.isEmpty)
             Center(child: Text('لا توجد بيانات للتصنيفات.'))
          else
            SizedBox(
              height: 250,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: chart.PieChart(
                    chart.PieChartData(
                      sections: _getCategoryChartSections(categories),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
            ),
          
          SizedBox(height: 30),
          Text(
            'متوسط فاصل المراجعة (بالأيام)',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 10),
          if (avgIntervals.isEmpty)
            Center(child: Text('لا توجد بيانات لمتوسط فواصل المراجعة.'))
          else ...[
            ...avgIntervals.entries.where((entry) => entry.key != 'overall').map((entry) {
              return _buildStatCard(
                icon: _getIconForCardType(entry.key),
                title: '${_getTitleForCardType(entry.key)} (أيام)',
                value: entry.value.toStringAsFixed(1),
                color: _getColorForCardType(entry.key),
              );
            }).toList(),
            if (avgIntervals.containsKey('overall'))
              _buildStatCard(
                icon: Icons.all_inclusive,
                title: 'المتوسط العام (أيام)',
                value: (avgIntervals['overall'] ?? 0.0).toStringAsFixed(1),
                color: Colors.blueGrey,
              ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required String title, required String value, required Color color}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _getDueCardsCount() {
    final now = DateTime.now();
    return flashcards.where((card) {
      final reviewDate = card.nextReviewDate;
      return DateTime(reviewDate.year, reviewDate.month, reviewDate.day).isBefore(DateTime(now.year, now.month, now.day)) ||
          DateTime(reviewDate.year, reviewDate.month, reviewDate.day).isAtSameMomentAs(DateTime(now.year, now.month, now.day));
    }).length;
  }

  Map<String, int> _getCategoryCounts() {
    final counts = <String, int>{};
    for (var card in flashcards) {
      counts[card.category] = (counts[card.category] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> _getSuccessRateByType() {
    final rates = <String, int>{};
    final typeTotals = {'text': 0, 'multipleChoice': 0, 'trueFalse': 0};
    final typeCorrects = {'text': 0, 'multipleChoice': 0, 'trueFalse': 0};

    for (var card in flashcards) {
      if (card.lastReviewCorrect != null) {
        typeTotals[card.answerType] = (typeTotals[card.answerType] ?? 0) + 1;
        if (card.lastReviewCorrect == true) {
          typeCorrects[card.answerType] = (typeCorrects[card.answerType] ?? 0) + 1;
        }
      }
    }

    typeTotals.forEach((type, total) {
      if (total > 0) {
        rates[type] = ((typeCorrects[type]! / total) * 100).round();
      } else {
        rates[type] = 0;
      }
    });

    return rates;
  }

  Widget _buildSuccessRateChart(Map<String, int> successRates) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('معدل النجاح حسب نوع البطاقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: chart.BarChart(
                chart.BarChartData(
                  alignment: chart.BarChartAlignment.spaceAround,
                  maxY: 100,
                  barGroups: [
                    _buildBarGroup(0, successRates['text']?.toDouble() ?? 0, 'text'),
                    _buildBarGroup(1, successRates['multipleChoice']?.toDouble() ?? 0, 'multipleChoice'),
                    _buildBarGroup(2, successRates['trueFalse']?.toDouble() ?? 0, 'trueFalse'),
                  ],
                  titlesData: chart.FlTitlesData(
                    show: true,
                    bottomTitles: chart.AxisTitles(
                      sideTitles: chart.SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          String text = '';
                          if (value == 0) text = 'نص';
                          if (value == 1) text = 'اختيارات';
                          if (value == 2) text = 'صح/خطأ';
                          return chart.SideTitleWidget(axisSide: meta.axisSide, space: 4, child: Text(text, style: TextStyle(fontSize: 10)));
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: chart.AxisTitles(
                      sideTitles: chart.SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => chart.SideTitleWidget(axisSide: meta.axisSide, space: 4, child: Text('${value.toInt()}%', style: TextStyle(fontSize: 10))),
                        interval: 25,
                        reservedSize: 35,
                      ),
                    ),
                    topTitles: chart.AxisTitles(sideTitles: chart.SideTitles(showTitles: false)),
                    rightTitles: chart.AxisTitles(sideTitles: chart.SideTitles(showTitles: false)),
                  ),
                  gridData: chart.FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25),
                  borderData: chart.FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  chart.BarChartGroupData _buildBarGroup(int x, double y, String type) {
    return chart.BarChartGroupData(
      x: x,
      barRods: [chart.BarChartRodData(toY: y, color: _getColorForCardType(type), width: 20, borderRadius: BorderRadius.circular(4))],
    );
  }

  List<chart.PieChartSectionData> _getCategoryChartSections(Map<String, int> categories) {
    final List<chart.PieChartSectionData> sections = [];
    int total = categories.values.fold(0, (sum, item) => sum + item);
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.cyan];

    int i = 0;
    categories.forEach((key, value) {
      final percentage = (value / total) * 100;
      sections.add(chart.PieChartSectionData(
        color: colors[i % colors.length],
        value: value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });
    return sections;
  }

  IconData _getIconForCardType(String type) {
    if (type == 'multipleChoice') return Icons.quiz;
    if (type == 'trueFalse') return Icons.check;
    return Icons.text_fields;
  }

  String _getTitleForCardType(String type) {
    if (type == 'multipleChoice') return 'الاختيارات المتعددة';
    if (type == 'trueFalse') return 'صح أم خطأ';
    return 'نص';
  }

  Color _getColorForCardType(String type) {
    if (type == 'multipleChoice') return Colors.deepPurple;
    if (type == 'trueFalse') return Colors.teal;
    return Colors.blueGrey;
  }

  Map<String, double> _getAverageReviewIntervals() {
    final typeTotals = {'text': 0.0, 'multipleChoice': 0.0, 'trueFalse': 0.0};
    final typeCounts = {'text': 0, 'multipleChoice': 0, 'trueFalse': 0};
    double overallTotal = 0.0;
    int overallCount = 0;

    for (var card in flashcards) {
      typeTotals[card.answerType] = (typeTotals[card.answerType] ?? 0.0) + card.interval;
      typeCounts[card.answerType] = (typeCounts[card.answerType] ?? 0) + 1;
      overallTotal += card.interval;
      overallCount++;
    }

    final avgIntervals = <String, double>{};
    typeTotals.forEach((type, total) {
      if (typeCounts[type]! > 0) avgIntervals[type] = total / typeCounts[type]!;
    });
    if (overallCount > 0) avgIntervals['overall'] = overallTotal / overallCount;

    return avgIntervals;
  }
}
