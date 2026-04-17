import 'package:flutter/material.dart';
import 'models/flashcard_model.dart';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart';

class ReviewScreen extends StatefulWidget {
  final List<Flashcard> flashcards;

  ReviewScreen({required this.flashcards});

  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> with SingleTickerProviderStateMixin {
  late List<Flashcard> _sessionCards;
  int _currentCardIndex = 0;
  bool _isFront = true;
  bool _answerShown = false;
  bool _showTextResult = false;
  final TextEditingController _textAnswerController = TextEditingController();
  int? _selectedOptionIndex;
  bool _isExplaining = false;

  // متغيرات لحفظ الترتيب العشوائي للخيارات لكل بطاقة
  late List<String> _shuffledOptions;
  late int _shuffledCorrectIndex;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _sessionCards = List.from(widget.flashcards)..shuffle();
    _prepareCardOptions(); // تجهيز خيارات أول بطاقة

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  // دالة لتجهيز خيارات البطاقة الحالية بشكل عشوائي
  void _prepareCardOptions() {
    final card = _sessionCards[_currentCardIndex];
    if (card.answerType == 'multipleChoice' || card.answerType == 'trueFalse') {
      // حفظ الإجابة الصحيحة الأصلية
      String correctText = card.options[card.correctOptionIndex ?? 0];

      // خلط الخيارات
      _shuffledOptions = List.from(card.options)..shuffle();

      // إيجاد مكان الإجابة الصحيحة الجديد
      _shuffledCorrectIndex = _shuffledOptions.indexOf(correctText);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _textAnswerController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) _controller.forward();
    else _controller.reverse();
    setState(() => _isFront = !_isFront);
  }

  void _moveToNextCard() {
    if (_currentCardIndex < _sessionCards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _isFront = true;
        _answerShown = false;
        _textAnswerController.clear();
        _showTextResult = false;
        _selectedOptionIndex = null;
        _prepareCardOptions(); // تجهيز خيارات البطاقة التالية
        _controller.reset();
      });
    } else {
      // إرجاع القائمة الكاملة المحدثة لضمان حفظ الإحصائيات
      Navigator.pop(context, widget.flashcards);
    }
  }

  Future<void> _showAIExplanation(Flashcard card) async {
    setState(() => _isExplaining = true);
    try {
      final response = await http.post(
        Uri.parse('${serverUrlNotifier.value}/api/explain'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': card.question,
          'answer': card.answerType == 'text' ? card.answer : card.options[card.correctOptionIndex ?? 0],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _showExplanationDialog(data['explanation']);
      } else {
        _showError('فشل السيرفر في تقديم شرح حالياً');
      }
    } catch (e) {
      _showError('خطأ في الاتصال: $e');
    } finally {
      setState(() => _isExplaining = false);
    }
  }

  void _showExplanationDialog(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.lightbulb, color: Colors.orange), SizedBox(width: 10), Text('شرح الذكاء الاصطناعي')]),
        content: SingleChildScrollView(child: Text(text, style: TextStyle(fontSize: 16, height: 1.5))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('فهمت'))],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionCards.isEmpty) return Scaffold(appBar: AppBar(title: Text('مراجعة')), body: Center(child: Text('فارغ')));
    final currentCard = _sessionCards[_currentCardIndex];
    final progress = (_currentCardIndex) / _sessionCards.length;

    return Scaffold(
      appBar: AppBar(title: Text('مراجعة ${_currentCardIndex + 1}/${_sessionCards.length}')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(10)),
            SizedBox(height: 30),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (currentCard.answerType == 'text' && !_answerShown) return;
                  if (!_answerShown) { setState(() => _answerShown = true); _flipCard(); }
                },
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final angle = _animation.value * pi;
                    return Transform(
                      transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
                      alignment: Alignment.center,
                      child: angle < pi / 2
                          ? _buildCardSide(currentCard, isFront: true)
                          : Transform(transform: Matrix4.identity()..rotateY(pi), alignment: Alignment.center, child: _buildCardSide(currentCard, isFront: false)),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 30),
            _buildActionArea(currentCard),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSide(Flashcard card, {required bool isFront}) {
    final theme = Theme.of(context);
    final isTextResult = card.answerType == 'text' && _showTextResult && !isFront;
    final isChoiceResult = (card.answerType == 'multipleChoice' || card.answerType == 'trueFalse') && _answerShown && !isFront;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isFront ? theme.cardColor : theme.colorScheme.primaryContainer,
      child: Container(
        width: double.infinity, padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isFront ? 'السؤال' : 'النتيجة', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            Divider(height: 20),
            if (isFront && card.imagePath != null) Expanded(flex: 3, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(card.imagePath!), fit: BoxFit.contain))),
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  child: isChoiceResult ? _buildChoiceResultSide(card) : (isTextResult ? _buildTextResultSide(card) : Text(isFront ? card.question : card.answer, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceResultSide(Flashcard card) {
    return Column(
      children: [
        Text(card.question, style: TextStyle(fontSize: 16, color: Colors.grey[700]), textAlign: TextAlign.center),
        SizedBox(height: 20),
        ...List.generate(_shuffledOptions.length, (i) {
          bool isCorrect = i == _shuffledCorrectIndex;
          bool isSelected = i == _selectedOptionIndex;
          Color bgColor = isCorrect ? Colors.green.withOpacity(0.2) : (isSelected ? Colors.red.withOpacity(0.2) : Colors.transparent);
          return Container(
            margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: isCorrect ? Colors.green : (isSelected ? Colors.red : Colors.grey[300]!))),
            child: Row(children: [Icon(isCorrect ? Icons.check_circle : (isSelected ? Icons.cancel : Icons.circle_outlined), color: isCorrect ? Colors.green : (isSelected ? Colors.red : Colors.grey)), SizedBox(width: 10), Expanded(child: Text(_shuffledOptions[i], style: TextStyle(fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal)))]),
          );
        }),
      ],
    );
  }

  Widget _buildTextResultSide(Flashcard card) {
    return Column(
      children: [
        Text('إجابتك:', style: TextStyle(fontSize: 14, color: Colors.grey)),
        Text(_textAnswerController.text.isEmpty ? "(فارغة)" : _textAnswerController.text, style: TextStyle(fontSize: 18)),
        Divider(height: 30),
        Text('الإجابة الصحيحة:', style: TextStyle(fontSize: 14, color: Colors.grey)),
        Text(card.answer, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionArea(Flashcard card) {
    if (_answerShown) return _buildRatingArea(card);
    if (card.answerType == 'text') return _buildTextInputArea();
    return _buildChoiceInput(card);
  }

  Widget _buildTextInputArea() {
    return Column(
      children: [
        TextField(controller: _textAnswerController, decoration: InputDecoration(labelText: 'أدخل إجابتك', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), onSubmitted: (_) => _submitTextAnswer()),
        SizedBox(height: 12),
        FilledButton.icon(onPressed: _submitTextAnswer, icon: Icon(Icons.check), label: Text('تحقق من الإجابة'), style: FilledButton.styleFrom(minimumSize: Size(double.infinity, 50))),
      ],
    );
  }

  Widget _buildChoiceInput(Flashcard card) {
    bool isMCQ = card.answerType == 'multipleChoice';
    return Column(
      children: [
        if (isMCQ) ...List.generate(_shuffledOptions.length, (i) => Card(margin: EdgeInsets.only(bottom: 8), child: RadioListTile<int>(title: Text(_shuffledOptions[i]), value: i, groupValue: _selectedOptionIndex, onChanged: (v) => setState(() => _selectedOptionIndex = v))))
        else Row(children: [Expanded(child: FilledButton.tonal(onPressed: () { _selectedOptionIndex = _shuffledOptions.indexOf('صح'); _submitAnswer(); }, child: Text('صح'))), SizedBox(width: 10), Expanded(child: FilledButton.tonal(onPressed: () { _selectedOptionIndex = _shuffledOptions.indexOf('خطأ'); _submitAnswer(); }, child: Text('خطأ')))]),
        if (isMCQ) FilledButton(onPressed: _selectedOptionIndex != null ? _submitAnswer : null, child: Text('تأكيد الإجابة'), style: FilledButton.styleFrom(minimumSize: Size(double.infinity, 50))),
      ],
    );
  }

  void _submitTextAnswer() { setState(() { _answerShown = true; _showTextResult = true; }); _flipCard(); }
  void _submitAnswer() { setState(() => _answerShown = true); _flipCard(); }

  Widget _buildRatingArea(Flashcard card) {
    bool isCorrect = card.answerType == 'text' || _selectedOptionIndex == _shuffledCorrectIndex;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (card.answerType != 'text') Text(isCorrect ? '✅ إجابة صحيحة' : '❌ إجابة خاطئة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.red)) else Container(),
            TextButton.icon(
              onPressed: _isExplaining ? null : () => _showAIExplanation(card),
              icon: _isExplaining ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.auto_awesome, size: 18),
              label: Text(_isExplaining ? 'جاري التحضير...' : 'اشرح لي 💡'),
            ),
          ],
        ),
        SizedBox(height: 10),
        if (!isCorrect) FilledButton(onPressed: () => _rateCard(0), child: Text('فهمت، سأحاول لاحقاً'), style: FilledButton.styleFrom(backgroundColor: Colors.red, minimumSize: Size(double.infinity, 50)))
        else Row(children: [Expanded(child: _rateBtn(0, 'صعب', Colors.red)), SizedBox(width: 8), Expanded(child: _rateBtn(1, 'جيد', Colors.orange)), SizedBox(width: 8), Expanded(child: _rateBtn(2, 'سهل', Colors.green))]),
      ],
    );
  }

  Widget _rateBtn(int r, String label, Color c) => FilledButton.tonal(onPressed: () => _rateCard(r), child: Text(label), style: FilledButton.styleFrom(foregroundColor: c));

  void _rateCard(int rating) {
    final currentCard = _sessionCards[_currentCardIndex];
    bool isActuallyCorrect = currentCard.answerType == 'text' || _selectedOptionIndex == _shuffledCorrectIndex;

    if (!isActuallyCorrect) rating = 0;

    if (rating == 0) {
      _sessionCards.add(currentCard);
      _updateCardInOriginalList(currentCard, 1, false);
    } else {
      int multiplier = (rating == 1) ? 2 : 4;
      int nextInterval = (currentCard.interval * multiplier).clamp(1, 365);
      _updateCardInOriginalList(currentCard, nextInterval, true);
    }
    _moveToNextCard();
  }

  void _updateCardInOriginalList(Flashcard card, int interval, bool correct) {
    int idx = widget.flashcards.indexWhere((c) => c.id == card.id);
    if (idx != -1) widget.flashcards[idx] = card.copyWith(interval: interval, nextReviewDate: DateTime.now().add(Duration(days: interval)), lastReviewCorrect: correct);
  }
}