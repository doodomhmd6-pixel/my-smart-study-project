import 'package:flutter/material.dart';
import 'models/flashcard_model.dart';
import 'dart:math';
import 'dart:io';

class ReviewScreen extends StatefulWidget {
  final List<Flashcard> flashcards;

  ReviewScreen({required this.flashcards});

  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> with SingleTickerProviderStateMixin {
  int _currentCardIndex = 0;
  bool _isFront = true;
  int? _selectedOptionIndex;
  bool _answerShown = false;
  bool _showTextResult = false; 
  final TextEditingController _textAnswerController = TextEditingController();

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // عشوائية ترتيب البطاقات عند بدء كل جلسة اختبار
    widget.flashcards.shuffle(); 
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _textAnswerController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  void _moveToNextCard() {
    if (_currentCardIndex < widget.flashcards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _isFront = true;
        _answerShown = false;
        _selectedOptionIndex = null;
        _textAnswerController.clear();
        _showTextResult = false;
        _controller.reset();
      });
    } else {
      // العودة للقائمة الرئيسية بعد إنهاء جميع البطاقات
      Navigator.pop(context, widget.flashcards);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('مراجعة البطاقات')),
        body: Center(child: Text('لا توجد بطاقات للمراجعة!')),
      );
    }

    final currentCard = widget.flashcards[_currentCardIndex];
    final progress = (_currentCardIndex) / widget.flashcards.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('مراجعة ${_currentCardIndex + 1}/${widget.flashcards.length}')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: progress, 
              minHeight: 8, 
              borderRadius: BorderRadius.circular(10),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            ),
            SizedBox(height: 30),
            
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // لا تسمح بالقلب باللمس للبطاقات النصية قبل الضغط على "تحقق" لضمان كتابة الإجابة
                  if (currentCard.answerType == 'text' && !_answerShown) return;
                  
                  if (!_answerShown) {
                    setState(() => _answerShown = true);
                    _flipCard();
                  }
                },
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final angle = _animation.value * pi;
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      alignment: Alignment.center,
                      child: angle < pi / 2 
                        ? _buildCardSide(currentCard, isFront: true) 
                        : Transform(
                            transform: Matrix4.identity()..rotateY(pi),
                            alignment: Alignment.center,
                            child: _buildCardSide(currentCard, isFront: false),
                          ),
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
    final isTextCardWithResult = card.answerType == 'text' && _showTextResult && !isFront;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isFront ? theme.cardColor : theme.colorScheme.primaryContainer,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isFront ? 'السؤال' : (isTextCardWithResult ? 'النتيجة' : 'الإجابة'),
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Divider(height: 20, color: theme.colorScheme.outlineVariant),
            
            if (isFront && card.imagePath != null)
              Expanded(flex: 3, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(card.imagePath!), fit: BoxFit.contain))),
            
            SizedBox(height: 10), 
            
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  child: isTextCardWithResult
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('إجابتك: ', style: TextStyle(fontSize: 14, color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7))),
                          Text(_textAnswerController.text.isEmpty ? "(فارغة)" : _textAnswerController.text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          Divider(height: 30, color: theme.colorScheme.onPrimaryContainer.withOpacity(0.2)),
                          Text('الإجابة الصحيحة: ', style: TextStyle(fontSize: 14, color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7))),
                          Text(card.answer, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Text(
                        isFront ? card.question : card.answer,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: isFront ? theme.colorScheme.onSurface : theme.colorScheme.onPrimaryContainer),
                        textAlign: TextAlign.center,
                      ),
                ),
              ),
            ),
            
            if (isFront && !_answerShown)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Icon(Icons.touch_app, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3), size: 24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionArea(Flashcard card) {
    if (_answerShown) {
      return _buildRatingArea(card);
    }

    if (card.answerType == 'text') {
      return _buildTextInputArea();
    }

    return _buildChoiceInput(card);
  }

  Widget _buildTextInputArea() {
    return Column(
      children: [
        TextField(
          controller: _textAnswerController,
          decoration: InputDecoration(
            labelText: 'أدخل إجابتك هنا (اختياري)', 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
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

  Widget _buildChoiceInput(Flashcard card) {
    return Column(
      children: [
        if (card.answerType == 'multipleChoice')
          ...List.generate(card.options.length, (index) => Card(
            margin: EdgeInsets.only(bottom: 8),
            child: RadioListTile<int>(
              title: Text(card.options[index]),
              value: index,
              groupValue: _selectedOptionIndex,
              onChanged: (v) => setState(() => _selectedOptionIndex = v),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ))
        else // trueFalse
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilledButton.tonal(onPressed: () { setState(() => _selectedOptionIndex = 0); _submitAnswer(); }, child: Text('صح')),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilledButton.tonal(onPressed: () { setState(() => _selectedOptionIndex = 1); _submitAnswer(); }, child: Text('خطأ')),
                ),
              ),
            ],
          ),
        if (card.answerType == 'multipleChoice')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FilledButton(
              onPressed: _selectedOptionIndex != null ? _submitAnswer : null, 
              child: Text('تأكيد الإجابة'),
              style: FilledButton.styleFrom(minimumSize: Size(double.infinity, 50)),
            ),
          )
      ],
    );
  }

  void _submitTextAnswer() {
    setState(() {
      _answerShown = true;
      _showTextResult = true;
    });
    _flipCard();
  }

  void _submitAnswer() {
    if (_selectedOptionIndex == null) return;
    setState(() => _answerShown = true);
    _flipCard();
  }

  Widget _buildRatingArea(Flashcard card) {
    bool isText = card.answerType == 'text';
    bool isCorrect = true;
    if (!isText) {
      isCorrect = _selectedOptionIndex == card.correctOptionIndex;
    }

    return Column(
      children: [
        // لا نعرض أيقونة "إجابة صحيحة" تلقائية للأسئلة النصية لأن التقييم يدوي من المستخدم
        if (!isText)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: isCorrect ? Colors.green : Colors.red, size: 28),
              SizedBox(width: 8),
              Text(isCorrect ? 'إجابة صحيحة' : 'إجابة خاطئة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.red)),
            ],
          ),
        SizedBox(height: 15),
        Text('كيف تقيم معرفتك بهذه البطاقة؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        SizedBox(height: 12),
        // إذا كانت الإجابة خاطئة (في الاختيارات) يظهر فقط زر متابعة لتقليل التشتت
        if (!isText && !isCorrect)
          FilledButton(
            onPressed: () => _rateCard(0), 
            child: Text('فهمت، متابعة'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, minimumSize: Size(double.infinity, 50)),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRateButton(0, 'صعب', Theme.of(context).colorScheme.error),
              _buildRateButton(1, 'جيد', Colors.orange),
              _buildRateButton(2, 'سهل', Colors.green),
            ],
          ),
      ],
    );
  }

  Widget _buildRateButton(int rating, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(
          onPressed: () => _rateCard(rating), 
          child: Text(label),
          style: FilledButton.styleFrom(
            foregroundColor: color,
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  void _rateCard(int rating) {
    final card = widget.flashcards[_currentCardIndex];
    DateTime now = DateTime.now();
    int interval = card.interval;
    bool correct = true;

    if (card.answerType != 'text') {
      correct = _selectedOptionIndex == card.correctOptionIndex;
    }
    
    if (!correct) rating = 0; 

    if (rating == 0) { 
      interval = 1;
    } else if (rating == 1) { 
      interval = (interval * 1.5).ceil();
    } else {
      interval = interval * 2;
    }

    interval = interval.clamp(1, 365);

    final updatedCard = card.copyWith(
      interval: interval,
      nextReviewDate: now.add(Duration(days: interval)),
      lastReviewCorrect: correct,
    );

    widget.flashcards[_currentCardIndex] = updatedCard;
    _moveToNextCard();
  }
}
