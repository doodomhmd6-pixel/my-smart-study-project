import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  final List<Map<String, dynamic>> flashcards;

  QuizScreen({required this.flashcards});

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  bool _showAnswer = false;
  late List<Map<String, dynamic>> _quizCards;

  @override
  void initState() {
    super.initState();
    // Shuffle the cards for the quiz
    _quizCards = List.from(widget.flashcards)..shuffle();
  }

  void _nextCard() {
    setState(() {
      if (_currentIndex < _quizCards.length - 1) {
        _currentIndex++;
        _showAnswer = false; // Hide answer for the new card
      } else {
        // End of quiz
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('انتهى الاختبار!')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_quizCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('اختبار')),
        body: Center(
          child: Text('لا توجد بطاقات لبدء الاختبار.'),
        ),
      );
    }

    final card = _quizCards[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('اختبار (${_currentIndex + 1}/${_quizCards.length})'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Card content
              Expanded(
                child: Card(
                  elevation: 8,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        _showAnswer ? (card['answer'] ?? '') : (card['question'] ?? ''),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Action buttons
              if (!_showAnswer)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    setState(() {
                      _showAnswer = true;
                    });
                  },
                  child: Text('إظهار الإجابة'),
                ),
              
              if (_showAnswer)
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
