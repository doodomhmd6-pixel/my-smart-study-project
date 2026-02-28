import 'dart:convert';

class Flashcard {
  final String id;
  final String question;
  final String answer;
  final String category;
  final DateTime nextReviewDate;
  final int interval;
  final String answerType; // 'text', 'multipleChoice', 'trueFalse'
  final List<String> options;
  final int? correctOptionIndex;
  final bool? lastReviewCorrect;
  final String? imagePath; // مسار الصورة المضافة للبطاقة

  Flashcard({
    required this.id,
    required this.question,
    this.answer = '',
    required this.category,
    required this.nextReviewDate,
    required this.interval,
    this.answerType = 'text',
    this.options = const [],
    this.correctOptionIndex,
    this.lastReviewCorrect,
    this.imagePath,
  });

  factory Flashcard.fromMap(Map<String, dynamic> map) {
    return Flashcard(
      id: map['id'] as String,
      question: map['question'] as String,
      answer: map['answer'] as String? ?? '',
      category: map['category'] as String? ?? 'عام',
      nextReviewDate: DateTime.parse(map['nextReviewDate'] as String),
      interval: map['interval'] as int? ?? 1,
      answerType: map['answerType'] as String? ?? 'text',
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: map['correctOptionIndex'] as int?,
      lastReviewCorrect: map['lastReviewCorrect'] as bool?,
      imagePath: map['imagePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'category': category,
      'nextReviewDate': nextReviewDate.toIso8601String(),
      'interval': interval,
      'answerType': answerType,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'lastReviewCorrect': lastReviewCorrect,
      'imagePath': imagePath,
    };
  }

  Flashcard copyWith({
    String? id,
    String? question,
    String? answer,
    String? category,
    DateTime? nextReviewDate,
    int? interval,
    String? answerType,
    List<String>? options,
    int? correctOptionIndex,
    bool? lastReviewCorrect,
    String? imagePath,
  }) {
    return Flashcard(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      category: category ?? this.category,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      interval: interval ?? this.interval,
      answerType: answerType ?? this.answerType,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      lastReviewCorrect: lastReviewCorrect ?? this.lastReviewCorrect,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  String toJson() => json.encode(toMap());
  factory Flashcard.fromJson(String source) => Flashcard.fromMap(json.decode(source));
}
