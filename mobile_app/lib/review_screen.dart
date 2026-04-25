import 'package:flutter/material.dart';   // واجهة المستخدم
import 'models/flashcard_model.dart';     // نموذج البطاقات
import 'dart:math';                       // العمليات الرياضية (مثل pi للدوران)
import 'dart:io';                         // التعامل مع الملفات (مثل الصور)
import 'dart:convert';                    // تحويل البيانات (JSON)
import 'package:http/http.dart' as http;  // إرسال واستقبال طلبات HTTP
import 'main.dart';                       // استدعاء إعدادات أو متغيرات من الملف الرئيسي

class ReviewScreen extends StatefulWidget {
  final List<Flashcard> flashcards;   // قائمة البطاقات المراد مراجعتها

  ReviewScreen({required this.flashcards});

  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> with SingleTickerProviderStateMixin {
  late List<Flashcard> _sessionCards;   // البطاقات الخاصة بجلسة المراجعة (مرتبة عشوائياً)
  int _currentCardIndex = 0;   // مؤشر البطاقة الحالية
  bool _isFront = true;   // هل البطاقة في وضع الواجهة أم الخلفية (للانيميشن)
  bool _answerShown = false;   // هل تم إظهار الإجابة
  bool _showTextResult = false;   // هل يتم عرض نتيجة الإجابة النصية
  final TextEditingController _textAnswerController = TextEditingController();   // متحكم لإدخال الإجابة النصية
  int? _selectedOptionIndex;   // الخيار المحدد في حالة الاختيار من متعدد
  bool _isExplaining = false;   // هل يتم عرض شرح الذكاء الاصطناعي حالياً

  late List<String> _shuffledOptions;   // خيارات البطاقة بعد ترتيبها عشوائياً
  late int _shuffledCorrectIndex;   // مؤشر الخيار الصحيح بعد الترتيب العشوائي

  late AnimationController _controller;   // متحكم للانيميشن
  late Animation<double> _animation;   // انيميشن لقلب البطاقة

  @override
  void initState() {
    super.initState();
    _sessionCards = List.from(widget.flashcards)..shuffle();   // ترتيب البطاقات عشوائياً
    _prepareCardOptions();   // تجهيز خيارات البطاقة الحالية

    _controller = AnimationController(   // إعداد الانيميشن
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  void _prepareCardOptions() {   // تجهيز خيارات البطاقة (اختيارات أو صح/خطأ)
    final card = _sessionCards[_currentCardIndex];
    if (card.answerType == 'multipleChoice' || card.answerType == 'trueFalse') {
      String correctText = card.options[card.correctOptionIndex ?? 0];   // النص الصحيح
      _shuffledOptions = List.from(card.options)..shuffle();   // ترتيب الخيارات عشوائياً
      _shuffledCorrectIndex = _shuffledOptions.indexOf(correctText);   // تحديد موقع الخيار الصحيح بعد الترتيب
    } else {
      _shuffledOptions = [];
      _shuffledCorrectIndex = -1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();   // التخلص من الانيميشن
    _textAnswerController.dispose();   // التخلص من متحكم النص
    super.dispose();
  }

  void _flipCard() {   // قلب البطاقة (انيميشن)
    if (_isFront) _controller.forward();
    else _controller.reverse();
    setState(() => _isFront = !_isFront);
  }

  void _moveToNextCard() {   // الانتقال إلى البطاقة التالية
    if (_currentCardIndex < _sessionCards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _isFront = true;
        _answerShown = false;
        _textAnswerController.clear();
        _showTextResult = false;
        _selectedOptionIndex = null;
        _prepareCardOptions();
        _controller.reset();
      });
    } else {
      Navigator.pop(context, widget.flashcards);   // إنهاء المراجعة والعودة
    }
  }


  Future<void> _showAIExplanation(Flashcard card) async {   // دالة لطلب شرح من الذكاء الاصطناعي
    setState(() => _isExplaining = true);   // تفعيل حالة "جاري الشرح"
    try {
      final response = await http.post(   // إرسال طلب للسيرفر
        Uri.parse('${serverUrlNotifier.value}/api/explain'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': card.question,   // إرسال السؤال
          'answer': card.answerType == 'text' ? card.answer : card.options[card.correctOptionIndex ?? 0],   // إرسال الإجابة الصحيحة
        }),
      );

      if (response.statusCode == 200) {   // إذا كان الرد ناجحاً
        final data = jsonDecode(utf8.decode(response.bodyBytes));   // فك تشفير البيانات
        _showExplanationDialog(data['explanation']);   // عرض الشرح في نافذة
      } else {
        _showError('فشل السيرفر في تقديم شرح حالياً');   // رسالة خطأ إذا فشل السيرفر
      }
    } catch (e) {
      _showError('خطأ في الاتصال: $e');   // رسالة خطأ عند حدوث مشكلة في الاتصال
    } finally {
      setState(() => _isExplaining = false);   // إنهاء حالة "جاري الشرح"
    }
  }

  void _showExplanationDialog(String text) {   // دالة لعرض نافذة الشرح
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.lightbulb, color: Colors.orange), SizedBox(width: 10), Text('شرح الذكاء الاصطناعي')]),
        content: SingleChildScrollView(child: Text(text, style: TextStyle(fontSize: 16, height: 1.5))),   // عرض النص مع تنسيق
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('فهمت'))],   // زر إغلاق النافذة
      ),
    );
  }

  void _showError(String msg) {   // دالة لإظهار رسالة خطأ
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionCards.isEmpty)   // إذا لم توجد بطاقات
      return Scaffold(appBar: AppBar(title: Text('مراجعة')), body: Center(child: Text('فارغ')));

    final currentCard = _sessionCards[_currentCardIndex];   // البطاقة الحالية
    final progress = (_currentCardIndex) / _sessionCards.length;   // نسبة التقدم

    return Scaffold(
      appBar: AppBar(title: Text('مراجعة ${_currentCardIndex + 1}/${_sessionCards.length}')),   // عنوان مع رقم البطاقة
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(10)),   // شريط التقدم
            SizedBox(height: 30),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (currentCard.answerType == 'text' && !_answerShown) return;   // لا يتم قلب البطاقة النصية إلا بعد إظهار الإجابة
                  if (!_answerShown) { setState(() => _answerShown = true); _flipCard(); }   // قلب البطاقة عند الضغط
                },
                child: AnimatedBuilder(   // بناء البطاقة مع انيميشن القلب
                  animation: _animation,
                  builder: (context, child) {
                    final angle = _animation.value * pi;   // زاوية الدوران
                    return Transform(
                      transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
                      alignment: Alignment.center,
                      child: angle < pi / 2
                          ? _buildCardSide(currentCard, isFront: true)   // عرض الوجه الأمامي
                          : Transform(transform: Matrix4.identity()..rotateY(pi), alignment: Alignment.center, child: _buildCardSide(currentCard, isFront: false)),   // عرض الوجه الخلفي
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 30),
            _buildActionArea(currentCard),   // منطقة الأزرار (إظهار الإجابة، التالي...)
          ],
        ),
      ),
    );
  }

  Widget _buildCardSide(Flashcard card, {required bool isFront}) {   // بناء واجهة البطاقة (أمامية/خلفية)
    final theme = Theme.of(context);
    final isTextResult = card.answerType == 'text' && _showTextResult && !isFront;   // إذا كانت البطاقة نصية والنتيجة معروضة
    final isChoiceResult = (card.answerType == 'multipleChoice' || card.answerType == 'trueFalse') && _answerShown && !isFront;   // إذا كانت البطاقة اختيارية والنتيجة معروضة

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
            if (isFront && card.imagePath != null)   // إذا كانت البطاقة تحتوي صورة
              Expanded(flex: 3, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(card.imagePath!), fit: BoxFit.contain))),
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  child: isChoiceResult
                      ? _buildChoiceResultSide(card)   // عرض نتيجة الاختيارات
                      : (isTextResult
                      ? _buildTextResultSide(card)   // عرض نتيجة النص
                      : Text(isFront ? card.question : card.answer, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),   // عرض السؤال أو الإجابة
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceResultSide(Flashcard card) {   // عرض نتيجة بطاقة الاختيارات
    return Column(
      children: [
        Text(card.question, style: TextStyle(fontSize: 16, color: Colors.grey[700]), textAlign: TextAlign.center),
        SizedBox(height: 20),
        ...List.generate(_shuffledOptions.length, (i) {   // بناء قائمة الخيارات
          bool isCorrect = i == _shuffledCorrectIndex;   // هل الخيار صحيح
          bool isSelected = i == _selectedOptionIndex;   // هل المستخدم اختاره
          Color bgColor = isCorrect ? Colors.green.withOpacity(0.2) : (isSelected ? Colors.red.withOpacity(0.2) : Colors.transparent);
          return Container(
            margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isCorrect ? Colors.green : (isSelected ? Colors.red : Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Icon(isCorrect ? Icons.check_circle : (isSelected ? Icons.cancel : Icons.circle_outlined),
                    color: isCorrect ? Colors.green : (isSelected ? Colors.red : Colors.grey)),
                SizedBox(width: 10),
                Expanded(child: Text(_shuffledOptions[i], style: TextStyle(fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal))),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTextResultSide(Flashcard card) {   // عرض نتيجة البطاقة النصية
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

  Widget _buildActionArea(Flashcard card) {   // منطقة الأزرار حسب حالة البطاقة
    if (_answerShown) return _buildRatingArea(card);   // إذا ظهرت الإجابة → تقييم البطاقة
    if (card.answerType == 'text') return _buildTextInputArea();   // إذا كانت نصية → إدخال نص
    return _buildChoiceInput(card);   // إذا كانت اختيارية → إدخال اختيار
  }

  Widget _buildTextInputArea() {   // إدخال الإجابة النصية
    return Column(
      children: [
        TextField(
          controller: _textAnswerController,
          decoration: InputDecoration(labelText: 'أدخل إجابتك', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          onSubmitted: (_) => _submitTextAnswer(),
        ),
        SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submitTextAnswer,
          icon: Icon(Icons.check),
          label: Text('تحقق من الإجابة'),
          style: FilledButton.styleFrom(minimumSize: Size(double.infinity, 50)),
        ),
      ],
    );
  }

  Widget _buildChoiceInput(Flashcard card) {   // إدخال الاختيارات
    bool isMCQ = card.answerType == 'multipleChoice';
    return Column(
      children: [
        if (isMCQ)
          ...List.generate(_shuffledOptions.length, (i) => Card(
            margin: EdgeInsets.only(bottom: 8),
            child: RadioListTile<int>(
              title: Text(_shuffledOptions[i]),
              value: i,
              groupValue: _selectedOptionIndex,
              onChanged: (v) => setState(() => _selectedOptionIndex = v),
            ),
          ))
        else
          Row(children: List.generate(_shuffledOptions.length, (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: FilledButton.tonal(
                onPressed: () { setState(() => _selectedOptionIndex = i); _submitAnswer(); },
                child: Text(_shuffledOptions[i]),
              ),
            ),
          ))),
        if (isMCQ)
          FilledButton(
            onPressed: _selectedOptionIndex != null ? _submitAnswer : null,
            child: Text('تأكيد الإجابة'),
            style: FilledButton.styleFrom(minimumSize: Size(double.infinity, 50)),
          ),
      ],
    );
  }

  void _submitTextAnswer() {   // عند إدخال إجابة نصية
    setState(() { _answerShown = true; _showTextResult = true; });
    _flipCard();
  }

  void _submitAnswer() {   // عند إدخال إجابة اختيارية
    setState(() => _answerShown = true);
    _flipCard();
  }

  Widget _buildRatingArea(Flashcard card) {   // منطقة تقييم البطاقة بعد الإجابة
    bool isCorrect = card.answerType == 'text' || _selectedOptionIndex == _shuffledCorrectIndex;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (card.answerType != 'text')
              Text(isCorrect ? '✅ إجابة صحيحة' : '❌ إجابة خاطئة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.red))
            else Container(),
            TextButton.icon(
              onPressed: _isExplaining ? null : () => _showAIExplanation(card),
              icon: _isExplaining ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.auto_awesome, size: 18),
              label: Text(_isExplaining ? 'جاري التحضير...' : 'اشرح لي 💡'),
            ),
          ],
        ),
        SizedBox(height: 10),
        if (!isCorrect)
          FilledButton(
            onPressed: () => _rateCard(0),
            child: Text('فهمت، سأحاول لاحقاً'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red, minimumSize: Size(double.infinity, 50)),
          )
        else
          Row(children: [
            Expanded(child: _rateBtn(0, 'صعب', Colors.red)),
            SizedBox(width: 8),
            Expanded(child: _rateBtn(1, 'جيد', Colors.orange)),
            SizedBox(width: 8),
            Expanded(child: _rateBtn(2, 'سهل', Colors.green)),
          ]),
      ],
    );
  }

  Widget _rateBtn(int r, String label, Color c) => FilledButton.tonal(
    onPressed: () => _rateCard(r),
    child: Text(label),
    style: FilledButton.styleFrom(foregroundColor: c),
  );

  void _rateCard(int rating) {   // تقييم البطاقة لتحديد الفاصل الزمني القادم
    final currentCard = _sessionCards[_currentCardIndex];
    bool isActuallyCorrect = currentCard.answerType == 'text' || _selectedOptionIndex == _shuffledCorrectIndex;

    if (!isActuallyCorrect) rating = 0;

    if (rating == 0) {
      _updateCardInOriginalList(currentCard, 1, false);   // إذا كانت خاطئة → مراجعة غداً
    } else {
      int multiplier = (rating == 1) ? 2 : 4;   // جيد = مضاعفة ×2، سهل = مضاعفة ×4
      int nextInterval = (currentCard.interval * multiplier).clamp(1, 365);   // تحديد الفاصل الجديد
      _updateCardInOriginalList(currentCard, nextInterval, true);
    }
    _moveToNextCard();   // الانتقال للبطاقة التالية
  }

  void _updateCardInOriginalList(Flashcard card, int interval, bool correct) {   // تحديث البطاقة في القائمة الأصلية
    int idx = widget.flashcards.indexWhere((c) => c.id == card.id);
    if (idx != -1) {
      widget.flashcards[idx] = card.copyWith(
        interval: interval,
        nextReviewDate: DateTime.now().add(Duration(days: interval)),   // تحديد موعد المراجعة القادم
        lastReviewCorrect: correct,
      );
    }
  }
}
