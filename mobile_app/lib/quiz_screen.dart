import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  final List<Map<String, dynamic>> flashcards;   // قائمة البطاقات (سؤال/إجابة)

  QuizScreen({required this.flashcards});

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;   // مؤشر البطاقة الحالية
  bool _showAnswer = false;   // هل يتم عرض الإجابة أم لا
  late List<Map<String, dynamic>> _quizCards;   // قائمة البطاقات بعد الترتيب العشوائي

  @override
  void initState() {
    super.initState();
    // ترتيب البطاقات بشكل عشوائي عند بدء الاختبار
    _quizCards = List.from(widget.flashcards)..shuffle();
  }

  void _nextCard() {   // الانتقال إلى البطاقة التالية
    setState(() {
      if (_currentIndex < _quizCards.length - 1) {
        _currentIndex++;   // الانتقال للبطاقة التالية
        _showAnswer = false;   // إخفاء الإجابة للبطاقة الجديدة
      } else {
        // نهاية الاختبار
        Navigator.pop(context);   // إغلاق الشاشة
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('انتهى الاختبار!')),   // رسالة انتهاء الاختبار
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_quizCards.isEmpty) {   // إذا لم توجد بطاقات
      return Scaffold(
        appBar: AppBar(title: Text('اختبار')),
        body: Center(
          child: Text('لا توجد بطاقات لبدء الاختبار.'),
        ),
      );
    }

    final card = _quizCards[_currentIndex];   // البطاقة الحالية

    return Scaffold(
      appBar: AppBar(
        title: Text('اختبار (${_currentIndex + 1}/${_quizCards.length})'),   // عرض رقم البطاقة الحالية من إجمالي البطاقات
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // محتوى البطاقة
              Expanded(
                child: Card(
                  elevation: 8,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        _showAnswer ? (card['answer'] ?? '') : (card['question'] ?? ''),   // عرض السؤال أو الإجابة
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // أزرار التحكم
              if (!_showAnswer)   // زر إظهار الإجابة
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    setState(() {
                      _showAnswer = true;   // إظهار الإجابة
                    });
                  },
                  child: Text('إظهار الإجابة'),
                ),

              if (_showAnswer)   // زر البطاقة التالية أو إنهاء الاختبار
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: Size(double.infinity, 50),
                  ),
                  onPressed: _nextCard,
                  child: Text(_currentIndex < _quizCards.length - 1 ? 'البطاقة التالية' : 'إنهاء الاختبار'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}