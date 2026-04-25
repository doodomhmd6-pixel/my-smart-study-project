import 'dart:convert';   // استيراد مكتبة للتحويل بين النصوص و JSON

class Flashcard {   // تعريف كلاس البطاقة التعليمية
  final String id;   // معرف فريد للبطاقة
  final String question;   // نص السؤال
  final String answer;   // نص الإجابة
  final String category;   // التصنيف (مثلاً: رياضيات، تاريخ...)
  final DateTime nextReviewDate;   // تاريخ المراجعة القادم
  final int interval;   // الفاصل الزمني بين المراجعات (عدد الأيام)
  final String answerType; // نوع الإجابة: نص، اختيار من متعدد، صح/خطأ
  final List<String> options;   // قائمة الخيارات (في حالة الاختيار من متعدد)
  final int? correctOptionIndex;   // مؤشر الخيار الصحيح (في حالة الاختيار من متعدد)
  final bool? lastReviewCorrect;   // هل كانت آخر مراجعة صحيحة أم لا
  final String? imagePath; // مسار الصورة المرتبطة بالبطاقة (اختياري)

  Flashcard({   // الكونستركتور لإنشاء بطاقة جديدة
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

  factory Flashcard.fromMap(Map<String, dynamic> map) {   // تحويل البيانات من Map إلى كائن Flashcard
    return Flashcard(
      id: map['id'] as String,
      question: map['question'] as String,
      answer: map['answer'] as String? ?? '',   // إذا لم توجد إجابة يتم تعيين قيمة فارغة
      category: map['category'] as String? ?? 'عام',   // إذا لم يوجد تصنيف يتم تعيين "عام"
      nextReviewDate: DateTime.parse(map['nextReviewDate'] as String),   // تحويل النص إلى تاريخ
      interval: map['interval'] as int? ?? 1,   // إذا لم يوجد فاصل يتم تعيين 1
      answerType: map['answerType'] as String? ?? 'text',   // إذا لم يوجد نوع يتم تعيين نص
      options: List<String>.from(map['options'] ?? []),   // تحويل القائمة إلى List<String>
      correctOptionIndex: map['correctOptionIndex'] as int?,
      lastReviewCorrect: map['lastReviewCorrect'] as bool?,
      imagePath: map['imagePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {   // تحويل البطاقة إلى Map لتخزينها
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'category': category,
      'nextReviewDate': nextReviewDate.toIso8601String(),   // تحويل التاريخ إلى نص
      'interval': interval,
      'answerType': answerType,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'lastReviewCorrect': lastReviewCorrect,
      'imagePath': imagePath,
    };
  }

  Flashcard copyWith({   // إنشاء نسخة جديدة من البطاقة مع إمكانية تعديل بعض القيم
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

  String toJson() => json.encode(toMap());   // تحويل البطاقة إلى JSON نصي
  factory Flashcard.fromJson(String source) => Flashcard.fromMap(json.decode(source));   // إنشاء بطاقة من JSON نصي
}