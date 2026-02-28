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
  bool _answerSubmitted = false;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
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
        title: Text('مراجعة ${_currentCardIndex + 1}/${widget.flashcards.length}'),
      ),
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
                  if (currentCard.answerType == 'text' || _answerSubmitted) {
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
              isFront ? 'السؤال' : 'الإجابة',
              style: TextStyle(
                color: theme.colorScheme.primary, 
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Divider(height: 20, color: theme.colorScheme.outlineVariant),
            
            // عرض الصورة إذا كانت موجودة (فقط في وجه السؤال لتقليل التشتت)
            if (isFront && card.imagePath != null)
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(card.imagePath!),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            
            SizedBox(height: 10),
            
            Expanded(
              flex: 2,
              child: Center(
                child: SingleChildScrollView(
                  child: Text(
                    isFront ? card.question : (card.answerType == 'text' ? card.answer : 'النتيجة بالأسفل'),
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            
            if (isFront)
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
    if (_isFront && card.answerType != 'text' && !_answerSubmitted) {
      return _buildChoiceInput(card);
    }

    if (!_isFront || (card.answerType == 'text' && _isFront) || _answerSubmitted) {
       if (!_isFront || card.answerType == 'text') {
          return _buildSRSArea(card);
       }
    }
    
    return ElevatedButton.icon(
      onPressed: _flipCard,
      icon: Icon(Icons.flip),
      label: Text('اقلب البطاقة'),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      ),
    );
  }

  Widget _buildChoiceInput(Flashcard card) {
    return Column(
      children: [
        if (card.answerType == 'multipleChoice')
          ...List.generate(card.options.length, (index) => Card(
            margin: EdgeInsets.only(bottom: 6),
            child: RadioListTile<int>(
              title: Text(card.options[index]),
              value: index,
              groupValue: _selectedOptionIndex,
              onChanged: (v) => setState(() => _selectedOptionIndex = v),
              dense: true,
            ),
          ))
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton.tonal(
                onPressed: () { setState(() { _selectedOptionIndex = 0; _answerSubmitted = true; }); _flipCard(); }, 
                child: Text('صح'),
              ),
              FilledButton.tonal(
                onPressed: () { setState(() { _selectedOptionIndex = 1; _answerSubmitted = true; }); _flipCard(); }, 
                child: Text('خطأ'),
              ),
            ],
          ),
        if (card.answerType == 'multipleChoice')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FilledButton(
              onPressed: _selectedOptionIndex != null ? () {
                setState(() => _answerSubmitted = true);
                _flipCard();
              } : null,
              child: Text('تأكيد الإجابة'),
            ),
          )
      ],
    );
  }

  Widget _buildSRSArea(Flashcard card) {
    bool isCorrect = true;
    if (card.answerType != 'text') {
      isCorrect = _selectedOptionIndex == card.correctOptionIndex;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: isCorrect ? Colors.green : Colors.red),
            SizedBox(width: 10),
            Text(isCorrect ? 'إجابة صحيحة' : 'إجابة خاطئة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 15),
        if (isCorrect)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton.tonal(onPressed: () => _rateCard(1), child: Text('جيد')),
              FilledButton(onPressed: () => _rateCard(2), child: Text('سهل')),
            ],
          )
        else
          FilledButton(
            onPressed: () => _rateCard(0), 
            child: Text('متابعة (صعب)'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  void _rateCard(int rating) {
    final card = widget.flashcards[_currentCardIndex];
    DateTime now = DateTime.now();
    int interval = card.interval;
    if (card.answerType != 'text' && _selectedOptionIndex != card.correctOptionIndex) rating = 0;
    if (rating == 0) interval = 1;
    else if (rating == 1) interval = (interval * 1.5).ceil();
    else interval = interval * 2;

    final updatedCard = card.copyWith(
      interval: interval,
      nextReviewDate: now.add(Duration(days: interval)),
      lastReviewCorrect: rating > 0,
    );

    setState(() {
      widget.flashcards[_currentCardIndex] = updatedCard;
      if (_currentCardIndex < widget.flashcards.length - 1) {
        _currentCardIndex++;
        _isFront = true;
        _answerSubmitted = false;
        _selectedOptionIndex = null;
        _controller.reset();
      } else {
        Navigator.pop(context, widget.flashcards);
      }
    });
  }
}
