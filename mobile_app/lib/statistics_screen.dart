import 'package:flutter/material.dart';   // مكتبة واجهة المستخدم الأساسية
import 'package:fl_chart/fl_chart.dart' as chart;   // مكتبة الرسوم البيانية
import 'models/flashcard_model.dart';   // استيراد نموذج البطاقات

class StatisticsScreen extends StatelessWidget {   // شاشة الإحصائيات
  final List<Flashcard> flashcards; // قائمة البطاقات المستخدمة في الحسابات

  const StatisticsScreen({Key? key, required this.flashcards}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- الحسابات الإحصائية ---
    final totalCards = flashcards.length;   // إجمالي عدد البطاقات
    final dueCards = _getDueCardsCount();   // عدد البطاقات المستحقة للمراجعة
    final categories = _getCategoryCounts();   // عدد البطاقات حسب التصنيف
    final successRates = _getSuccessRateByType();   // معدل النجاح حسب نوع البطاقة
    final avgIntervals = _getAverageReviewIntervals();   // متوسط الفاصل الزمني بين المراجعات

    return Scaffold(
      appBar: AppBar(
        title: Text('الإحصائيات'),   // عنوان الشاشة
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStatCard(   // بطاقة تعرض إجمالي البطاقات
              icon: Icons.style,
              title: 'إجمالي البطاقات',
              value: totalCards.toString(),
              color: Colors.blue
          ),
          _buildStatCard(   // بطاقة تعرض عدد البطاقات المستحقة
              icon: Icons.today,
              title: 'بطاقات مستحقة للمراجعة',
              value: dueCards.toString(),
              color: Colors.orange
          ),
          SizedBox(height: 20),
          Text(
            'البطاقات حسب التصنيف',   // عنوان قسم التصنيفات
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 10),
          if (categories.isEmpty)
            Center(child: Text('لا توجد تصنيفات لعرضها.'))   // إذا لم توجد تصنيفات
          else
            ...categories.entries.map((entry) {   // عرض التصنيفات مع عدد البطاقات
              return Card(
                child: ListTile(
                  title: Text(entry.key),   // اسم التصنيف
                  trailing: Chip(
                    label: Text(entry.value.toString()),   // عدد البطاقات
                    backgroundColor: Colors.cyan.shade100,
                  ),
                ),
              );
            }).toList(),

          SizedBox(height: 20),
          Text(
            'معدل النجاح حسب نوع البطاقة',   // عنوان قسم معدل النجاح
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 10),
          if (successRates.isEmpty)
            Center(child: Text('لا توجد بيانات لنجاح البطاقات.'))   // إذا لم توجد بيانات
          else
            _buildSuccessRateChart(successRates),   // عرض رسم بياني لمعدل النجاح

          SizedBox(height: 30),
          Text(
            'توزيع البطاقات حسب التصنيف',   // عنوان قسم توزيع البطاقات
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 10),
          if (categories.isEmpty)
            Center(child: Text('لا توجد بيانات للتصنيفات.'))   // إذا لم توجد بيانات
          else
            SizedBox(
              height: 250,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: chart.PieChart(   // رسم بياني دائري للتصنيفات
                    chart.PieChartData(
                      sections: _getCategoryChartSections(categories),   // أقسام الرسم البياني
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
            ),

          SizedBox(height: 30),
          Text(
            'متوسط فاصل المراجعة (بالأيام)',   // عنوان قسم الفواصل الزمنية
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 10),
          if (avgIntervals.isEmpty)
            Center(child: Text('لا توجد بيانات لمتوسط فواصل المراجعة.'))   // إذا لم توجد بيانات
          else ...[
            ...avgIntervals.entries.where((entry) => entry.key != 'overall').map((entry) {   // عرض متوسط الفاصل لكل نوع بطاقة
              return _buildStatCard(
                icon: _getIconForCardType(entry.key),
                title: '${_getTitleForCardType(entry.key)} (أيام)',
                value: entry.value.toStringAsFixed(1),
                color: _getColorForCardType(entry.key),
              );
            }).toList(),
            if (avgIntervals.containsKey('overall'))   // عرض المتوسط العام
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
    return Card(   // بطاقة تعرض إحصائية معينة
      elevation: 2,   // ارتفاع الظل
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),   // أيقونة الإحصائية
            SizedBox(width: 16),   // مسافة بين الأيقونة والنص
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[600])),   // عنوان الإحصائية
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),   // القيمة الرقمية
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _getDueCardsCount() {   // دالة لحساب عدد البطاقات المستحقة للمراجعة
    final now = DateTime.now();   // الوقت الحالي
    return flashcards.where((card) {
      final reviewDate = card.nextReviewDate;   // تاريخ المراجعة للبطاقة
      return DateTime(reviewDate.year, reviewDate.month, reviewDate.day)
          .isBefore(DateTime(now.year, now.month, now.day))   // إذا كان تاريخ المراجعة قبل اليوم
          || DateTime(reviewDate.year, reviewDate.month, reviewDate.day)
              .isAtSameMomentAs(DateTime(now.year, now.month, now.day));   // أو يساوي اليوم الحالي
    }).length;   // إرجاع عدد البطاقات المستحقة
  }

  Map<String, int> _getCategoryCounts() {   // دالة لحساب عدد البطاقات حسب التصنيف
    final counts = <String, int>{};   // خريطة لتخزين النتائج
    for (var card in flashcards) {
      counts[card.category] = (counts[card.category] ?? 0) + 1;   // زيادة العدد لكل تصنيف
    }
    return counts;   // إرجاع الخريطة
  }

  Map<String, int> _getSuccessRateByType() {   // دالة لحساب معدل النجاح حسب نوع البطاقة
    final rates = <String, int>{};   // خريطة لتخزين المعدلات
    final typeTotals = {'text': 0, 'multipleChoice': 0, 'trueFalse': 0};   // إجمالي البطاقات لكل نوع
    final typeCorrects = {'text': 0, 'multipleChoice': 0, 'trueFalse': 0};   // عدد الإجابات الصحيحة لكل نوع

    for (var card in flashcards) {
      if (card.lastReviewCorrect != null) {   // إذا كانت نتيجة آخر مراجعة موجودة
        typeTotals[card.answerType] = (typeTotals[card.answerType] ?? 0) + 1;   // زيادة العدد الكلي
        if (card.lastReviewCorrect == true) {
          typeCorrects[card.answerType] = (typeCorrects[card.answerType] ?? 0) + 1;   // زيادة عدد الصحيحة
        }
      }
    }

    typeTotals.forEach((type, total) {   // حساب النسبة لكل نوع
      if (total > 0) {
        rates[type] = ((typeCorrects[type]! / total) * 100).round();   // نسبة النجاح = الصحيحة ÷ الكلية × 100
      } else {
        rates[type] = 0;   // إذا لم توجد بيانات، النسبة = 0
      }
    });

    return rates;   // إرجاع النتائج
  }
  Widget _buildSuccessRateChart(Map<String, int> successRates) {
    return Card(   // بطاقة تحتوي على الرسم البياني
      elevation: 2,   // ارتفاع الظل
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('معدل النجاح حسب نوع البطاقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),   // عنوان القسم
            SizedBox(height: 20),
            SizedBox(
              height: 150,   // تحديد ارتفاع الرسم البياني
              child: chart.BarChart(   // رسم بياني بالأعمدة
                chart.BarChartData(
                  alignment: chart.BarChartAlignment.spaceAround,   // توزيع الأعمدة بشكل متساوي
                  maxY: 100,   // الحد الأقصى للقيمة (100%)
                  barGroups: [   // مجموعات الأعمدة (لكل نوع بطاقة)
                    _buildBarGroup(0, successRates['text']?.toDouble() ?? 0, 'text'),   // عمود للبطاقات النصية
                    _buildBarGroup(1, successRates['multipleChoice']?.toDouble() ?? 0, 'multipleChoice'),   // عمود للاختيار من متعدد
                    _buildBarGroup(2, successRates['trueFalse']?.toDouble() ?? 0, 'trueFalse'),   // عمود لصح/خطأ
                  ],
                  titlesData: chart.FlTitlesData(   // إعدادات العناوين للمحاور
                    show: true,
                    bottomTitles: chart.AxisTitles(   // عناوين المحور السفلي
                      sideTitles: chart.SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {   // تحديد النص لكل عمود
                          String text = '';
                          if (value == 0) text = 'نص';
                          if (value == 1) text = 'اختيارات';
                          if (value == 2) text = 'صح/خطأ';
                          return chart.SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 4,
                            child: Text(text, style: TextStyle(fontSize: 10)),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: chart.AxisTitles(   // عناوين المحور الجانبي (النسبة %)
                      sideTitles: chart.SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => chart.SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text('${value.toInt()}%', style: TextStyle(fontSize: 10)),
                        ),
                        interval: 25,   // الفاصل بين القيم (0، 25، 50، 75، 100)
                        reservedSize: 35,
                      ),
                    ),
                    topTitles: chart.AxisTitles(sideTitles: chart.SideTitles(showTitles: false)),   // إخفاء العناوين العلوية
                    rightTitles: chart.AxisTitles(sideTitles: chart.SideTitles(showTitles: false)),   // إخفاء العناوين اليمنى
                  ),
                  gridData: chart.FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25),   // خطوط الشبكة الأفقية كل 25%
                  borderData: chart.FlBorderData(show: false),   // إخفاء الحدود
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  chart.BarChartGroupData _buildBarGroup(int x, double y, String type) {
    return chart.BarChartGroupData(   // إنشاء مجموعة أعمدة للرسم البياني
      x: x,   // موقع العمود على المحور الأفقي
      barRods: [
        chart.BarChartRodData(
          toY: y,   // قيمة العمود (النسبة %)
          color: _getColorForCardType(type),   // اللون حسب نوع البطاقة
          width: 20,   // عرض العمود
          borderRadius: BorderRadius.circular(4),   // تدوير الحواف
        )
      ],
    );
  }

  List<chart.PieChartSectionData> _getCategoryChartSections(Map<String, int> categories) {
    final List<chart.PieChartSectionData> sections = [];   // قائمة أقسام الرسم البياني الدائري
    int total = categories.values.fold(0, (sum, item) => sum + item);   // حساب إجمالي البطاقات
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.cyan];   // ألوان مختلفة للتصنيفات

    int i = 0;
    categories.forEach((key, value) {
      final percentage = (value / total) * 100;   // حساب النسبة المئوية لكل تصنيف
      sections.add(chart.PieChartSectionData(
        color: colors[i % colors.length],   // اختيار اللون
        value: value.toDouble(),   // القيمة (عدد البطاقات)
        title: '${percentage.toStringAsFixed(0)}%',   // عرض النسبة المئوية
        radius: 60,   // نصف قطر القسم
        titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),   // تنسيق النص
      ));
      i++;
    });
    return sections;   // إرجاع الأقسام
  }

  IconData _getIconForCardType(String type) {   // دالة لإرجاع أيقونة حسب نوع البطاقة
    if (type == 'multipleChoice') return Icons.quiz;
    if (type == 'trueFalse') return Icons.check;
    return Icons.text_fields;
  }

  String _getTitleForCardType(String type) {   // دالة لإرجاع عنوان نصي حسب نوع البطاقة
    if (type == 'multipleChoice') return 'الاختيارات المتعددة';
    if (type == 'trueFalse') return 'صح أم خطأ';
    return 'نص';
  }

  Color _getColorForCardType(String type) {   // دالة لإرجاع لون حسب نوع البطاقة
    if (type == 'multipleChoice') return Colors.deepPurple;
    if (type == 'trueFalse') return Colors.teal;
    return Colors.blueGrey;
  }

  Map<String, double> _getAverageReviewIntervals() {
    // دالة لحساب متوسط الفاصل الزمني للمراجعة
    final typeTotals = {
      'text': 0.0,
      'multipleChoice': 0.0,
      'trueFalse': 0.0
    }; // مجموع الفواصل لكل نوع
    final typeCounts = {
      'text': 0,
      'multipleChoice': 0,
      'trueFalse': 0
    }; // عدد البطاقات لكل نوع
    double overallTotal = 0.0; // مجموع الفواصل لجميع البطاقات
    int overallCount = 0; // عدد البطاقات الكلي

    for (var card in flashcards) {
      typeTotals[card.answerType] = (typeTotals[card.answerType] ?? 0.0) +
          card.interval; // جمع الفواصل لكل نوع
      typeCounts[card.answerType] =
          (typeCounts[card.answerType] ?? 0) + 1; // زيادة العدد لكل نوع
      overallTotal += card.interval; // جمع الفواصل الكلي
      overallCount++;
    }

    final avgIntervals = <String, double>{}; // خريطة للمتوسطات
    typeTotals.forEach((type, total) {
      if (typeCounts[type]! > 0)
        avgIntervals[type] = total / typeCounts[type]!; // حساب المتوسط لكل نوع
    });
    if (overallCount > 0) avgIntervals['overall'] =
        overallTotal / overallCount; // حساب المتوسط العام

    return avgIntervals; // إرجاع النتائج
  }
}
