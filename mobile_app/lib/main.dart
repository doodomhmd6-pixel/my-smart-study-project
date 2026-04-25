import 'dart:math';   // استيراد مكتبة الرياضيات لتوفير دوال رياضية مثل الجذر والتوليد العشوائي
import 'package:flutter/material.dart';   // استيراد مكتبة واجهة المستخدم الأساسية في Flutter
import 'package:flutter_localizations/flutter_localizations.dart';   // استيراد دعم تعدد اللغات والتعريب
import 'package:hive/hive.dart';   // استيراد مكتبة Hive للتخزين المحلي (قاعدة بيانات خفيفة)
import 'package:path_provider/path_provider.dart';   // استيراد مكتبة للحصول على مسارات التخزين في الجهاز
import 'dart:io';   // استيراد مكتبة التعامل مع الملفات والنظام
import 'dart:convert';   // استيراد مكتبة التحويل بين النصوص و JSON
import 'package:http/http.dart' as http;   // استيراد مكتبة HTTP لإرسال واستقبال الطلبات من السيرفر
import 'package:http_parser/http_parser.dart';   // استيراد مكتبة لتحليل محتوى HTTP
import 'package:image_picker/image_picker.dart';   // استيراد مكتبة لاختيار الصور من الكاميرا أو المعرض
import 'package:file_picker/file_picker.dart';   // استيراد مكتبة لاختيار الملفات من الجهاز
import 'package:intl/intl.dart';   // استيراد مكتبة للتعامل مع التواريخ والأوقات بصيغ مختلفة
import 'package:share_plus/share_plus.dart';   // استيراد مكتبة لمشاركة الملفات أو النصوص مع تطبيقات أخرى
import 'review_screen.dart';   // استيراد شاشة مراجعة البطاقات
import 'statistics_screen.dart';   // استيراد شاشة الإحصائيات
import 'models/flashcard_model.dart';   // استيراد نموذج البطاقات التعليمية
import 'services/notification_service.dart';   // استيراد خدمة الإشعارات

late ValueNotifier<ThemeMode> themeNotifier;   // متغير لمتابعة وتغيير وضع الثيم (فاتح/داكن)
late ValueNotifier<String> serverUrlNotifier;   // متغير لمتابعة وتغيير رابط السيرفر

void main() async {   // الدالة الرئيسية لتشغيل التطبيق
  WidgetsFlutterBinding.ensureInitialized();   // تهيئة ربط Flutter قبل أي عملية غير متزامنة
  await NotificationService.init();   // تهيئة خدمة الإشعارات
  final appDocumentDir = await getApplicationDocumentsDirectory();   // الحصول على مسار مجلد المستندات
  Hive.init(appDocumentDir.path);   // تهيئة قاعدة بيانات Hive في ذلك المسار
  await Hive.openBox('flashcards');   // فتح صندوق تخزين البطاقات التعليمية
  final settings = await Hive.openBox('settings');   // فتح صندوق تخزين الإعدادات

  final themeIndex = settings.get('themeMode', defaultValue: 0) as int;   // قراءة إعداد الثيم (افتراضي: فاتح)
  themeNotifier = ValueNotifier(ThemeMode.values[themeIndex]);   // تعيين الثيم الحالي في ValueNotifier

  final savedUrl = settings.get('serverUrl', defaultValue: 'http://192.168.43.226:5000') as String;   // قراءة رابط السيرفر المحفوظ أو استخدام الافتراضي
  serverUrlNotifier = ValueNotifier(savedUrl);   // تعيين رابط السيرفر في ValueNotifier

  runApp(MyApp());   // تشغيل التطبيق
}

class MyApp extends StatelessWidget {   // تعريف الكلاس الرئيسي للتطبيق
  @override
  Widget build(BuildContext context) {   // بناء واجهة التطبيق
    return ValueListenableBuilder<ThemeMode>(   // مستمع لتغيير الثيم
      valueListenable: themeNotifier,   // ربطه بالـ ValueNotifier الخاص بالثيم
      builder: (_, mode, __) {   // بناء واجهة التطبيق عند تغيير الثيم
        return MaterialApp(
          title: 'ذاكرتي الذكية',   // عنوان التطبيق
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue, brightness: Brightness.light),   // إعدادات الثيم الفاتح
          darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue, brightness: Brightness.dark),   // إعدادات الثيم الداكن
          themeMode: mode,   // تطبيق الثيم الحالي
          debugShowCheckedModeBanner: false,   // إخفاء شريط "Debug" من واجهة التطبيق
          localizationsDelegates: [   // إضافة دعم التعريب
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('ar', '')],   // تحديد اللغة المدعومة (العربية)
          locale: const Locale('ar', ''),   // تعيين اللغة الافتراضية (العربية)
          home: HomeScreen(),   // الشاشة الرئيسية للتطبيق
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {   // تعريف الشاشة الرئيسية كـ StatefulWidget
  @override
  _HomeScreenState createState() => _HomeScreenState();   // إنشاء الحالة الخاصة بالشاشة
}

class _HomeScreenState extends State<HomeScreen> {   // الحالة الخاصة بالشاشة الرئيسية
  List<Flashcard> flashcards = [];   // قائمة البطاقات التعليمية
  final ImagePicker _picker = ImagePicker();   // أداة لاختيار الصور

  @override
  void initState() {   // دالة التهيئة عند بداية تشغيل الشاشة
    super.initState();
    _initializeApp();   // استدعاء دالة التهيئة الخاصة بالتطبيق
  }

  Future<void> _initializeApp() async {   // دالة تهيئة التطبيق
    await _loadFlashcards();   // تحميل البطاقات التعليمية من التخزين
    await NotificationService.requestPermissions();   // طلب صلاحيات الإشعارات
    _checkDueCards();   // التحقق من البطاقات المستحقة للمراجعة
  }

  void _checkDueCards() {   // دالة للتحقق من البطاقات المستحقة للمراجعة
    final now = DateTime.now();   // الحصول على الوقت الحالي
    final dueCount = flashcards.where((c) => c.nextReviewDate.isBefore(now.add(const Duration(minutes: 1)))).length;   // حساب عدد البطاقات المستحقة
    NotificationService.checkAndNotifyDueCards(dueCount);   // إرسال إشعار بعدد البطاقات المستحقة
  }

  Future<void> _loadFlashcards() async {   // دالة لتحميل البطاقات التعليمية
    final box = Hive.box('flashcards');   // فتح صندوق البطاقات
    List<Flashcard> tempLoadedCards = [];   // قائمة مؤقتة لتخزين البطاقات المحملة
    try {
      dynamic cardsData = box.get('cards');   // قراءة البيانات المخزنة في الصندوق
      if (cardsData is List) {   // التحقق إذا كانت البيانات عبارة عن قائمة
        for (var item in cardsData) {   // المرور على كل عنصر في القائمة
          if (item is Map) {   // التحقق إذا كان العنصر عبارة عن خريطة (Map)
            tempLoadedCards.add(Flashcard.fromMap(Map<String, dynamic>.from(item)));   // تحويل البيانات إلى كائن Flashcard وإضافته للقائمة
          }
        }
      }
    } catch (e) { print('Error Loading Cards: $e'); }   // في حالة حدوث خطأ أثناء تحميل البطاقات يتم طباعته
    setState(() {   // تحديث واجهة المستخدم
      flashcards = tempLoadedCards;   // تعيين البطاقات المحملة إلى القائمة الرئيسية
    });
  }

  Future<void> _saveFlashcards() async {   // دالة لحفظ البطاقات في التخزين
    final box = Hive.box('flashcards');   // فتح صندوق البطاقات
    await box.put('cards', flashcards.map((c) => c.toMap()).toList());   // تحويل البطاقات إلى Map وحفظها
  }

  Future<void> _deleteCard(String id) async {   // دالة لحذف بطاقة معينة
    bool confirm = await showDialog(   // عرض نافذة تأكيد الحذف
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البطاقة'),   // عنوان النافذة
        content: const Text('هل أنت متأكد من رغبتك في حذف هذه البطاقة نهائياً؟'),   // نص التأكيد
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),   // زر الإلغاء
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('حذف', style: TextStyle(color: Colors.red))),   // زر الحذف
        ],
      ),
    ) ?? false;

    if (confirm) {   // إذا أكد المستخدم الحذف
      setState(() {   // تحديث واجهة المستخدم
        flashcards.removeWhere((c) => c.id == id);   // إزالة البطاقة من القائمة
      });
      await _saveFlashcards();   // حفظ التغييرات
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف البطاقة')));   // إظهار رسالة نجاح
    }
  }

  void _showServerSettings() {   // دالة لعرض إعدادات السيرفر
    TextEditingController urlController = TextEditingController(text: serverUrlNotifier.value);   // إنشاء متحكم للنص مع الرابط الحالي
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات الاتصال عن بُعد'),   // عنوان النافذة
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل رابط السيرفر الجديد:', style: TextStyle(fontSize: 13)),   // تعليمات للمستخدم
            const SizedBox(height: 10),   // مسافة فارغة
            TextField(
              controller: urlController,   // حقل إدخال الرابط
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'https://your-server.com'),   // تنسيق الحقل
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),   // زر الإلغاء
          ElevatedButton(
            onPressed: () {   // عند الضغط على زر الحفظ
              String newUrl = urlController.text.trim();   // قراءة الرابط الجديد
              if (newUrl.isNotEmpty) {   // إذا لم يكن فارغاً
                if (newUrl.startsWith('http://') && newUrl.contains('onrender.com')) {   // إذا كان الرابط يبدأ بـ http ويحتوي على onrender.com
                  newUrl = newUrl.replaceFirst('http://', 'https://');   // تحويله إلى https
                }
                serverUrlNotifier.value = newUrl;   // تحديث الرابط في التطبيق
                Hive.box('settings').put('serverUrl', newUrl);   // حفظ الرابط الجديد في الإعدادات
                Navigator.pop(context);   // إغلاق النافذة
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ العنوان الجديد')));   // إظهار رسالة نجاح
              }
            },
            child: const Text('حفظ'),   // نص زر الحفظ
          ),
        ],
      ),
    );
  }

  void _showAboutApp() {   // دالة لعرض نافذة "حول التطبيق"
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حول التطبيق'),   // عنوان النافذة
        content: const SingleChildScrollView(   // محتوى قابل للتمرير
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ذاكرتي الذكية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),   // اسم التطبيق
              SizedBox(height: 10),
              Text('كيف يعمل التطبيق:', style: TextStyle(fontWeight: FontWeight.bold)),   // عنوان القسم
              Text('يعتمد التطبيق على نظام التكرار المتباعد (Spaced Repetition System) لضمان حفظ المعلومات في الذاكرة طويلة المدى. يتم جدولة مراجعة البطاقات بناءً على مستوى صعوبتها بالنسبة لك.'),   // شرح آلية عمل التطبيق
              SizedBox(height: 10),
              Text('مميزات التطبيق:', style: TextStyle(fontWeight: FontWeight.bold)),   // عنوان القسم
              Text('• إنشاء بطاقات ذكية من النصوص والصور باستخدام الذكاء الاصطناعي.'),   // ميزة 1
              Text('• دعم أنواع مختلفة من الأسئلة: نصية، اختيار من متعدد، وصح أو خطأ.'),   // ميزة 2
              Text('• ميزة "اشرح لي" لفهم المعلومات بعمق عبر الذكاء الاصطناعي.'),   // ميزة 3
              Text('• إحصائيات دقيقة لمتابعة مستوى تقدمك الدراسي.'),   // ميزة 4
              Text('• نظام إشعارات ذكي لتذكيرك بمواعيد المراجعة اليومية.'),   // ميزة 5
              Text('• إمكانية تصدير واستيراد البطاقات لمشاركتها مع الآخرين.'),   // ميزة 6
            ],
          ),
        ),
        actions: [
          // هنا يمكن إضافة زر "إغلاق" أو "موافق"

            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {   // دالة بناء واجهة الشاشة الرئيسية
    final displayCards = flashcards.reversed.take(10).toList();   // أخذ آخر 10 بطاقات مضافة وعرضها بترتيب عكسي

    return Scaffold(
      appBar: AppBar(
        title: const Text('ذاكرتي الذكية'),   // عنوان التطبيق في شريط العنوان
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),   // أيقونة الإحصائيات
            onPressed: () => Navigator.push(   // عند الضغط يتم الانتقال لشاشة الإحصائيات
              context,
              MaterialPageRoute(builder: (context) => StatisticsScreen(flashcards: flashcards)),
            ),
          ),
          PopupMenuButton<String>(   // زر القائمة المنسدلة (المزيد)
            icon: const Icon(Icons.more_vert),   // أيقونة القائمة
            onSelected: (val) {   // عند اختيار عنصر من القائمة
              if (val == 'theme') _showThemeMenu();   // تغيير المظهر
              if (val == 'server') _showServerSettings();   // إعدادات السيرفر
              if (val == 'export') _exportAllCards();   // تصدير البطاقات
              if (val == 'import') _importFlashcards();   // استيراد البطاقات
              if (val == 'about') _showAboutApp();   // نافذة حول التطبيق
            },
            itemBuilder: (context) => [   // عناصر القائمة
              const PopupMenuItem(value: 'theme', child: Text('المظهر')),
              const PopupMenuItem(value: 'server', child: Text('إعدادات السيرفر')),
              const PopupMenuItem(value: 'export', child: Text('تصدير نسخة احتياطية')),
              const PopupMenuItem(value: 'import', child: Text('استيراد نسخة احتياطية')),
              const PopupMenuItem(value: 'about', child: Text('حول التطبيق')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),   // إضافة هوامش حول المحتوى
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(   // بطاقة ترحيبية
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.school, size: 60, color: Theme.of(context).colorScheme.primary),   // أيقونة تعليمية
                    const SizedBox(height: 10),
                    const Text('مرحباً بك في ذاكرتي الذكية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),   // نص ترحيبي
                    ValueListenableBuilder<String>(   // مستمع لتحديث رابط السيرفر
                      valueListenable: serverUrlNotifier,
                      builder: (_, url, __) => Text('متصل بـ: $url', style: const TextStyle(fontSize: 10, color: Colors.grey)),   // عرض الرابط الحالي
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(   // شبكة من الأزرار (اختصارات)
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),   // منع التمرير داخل الشبكة
              crossAxisCount: 3,   // عدد الأعمدة
              childAspectRatio: 1.1,   // نسبة العرض إلى الطول
              mainAxisSpacing: 10,   // المسافة بين الصفوف
              crossAxisSpacing: 10,   // المسافة بين الأعمدة
              children: [
                _buildActionButton(icon: Icons.add, label: 'إضافة', color: Colors.green, onTap: _showAddCardDialog),   // زر إضافة بطاقة
                _buildActionButton(icon: Icons.style, label: 'البطاقات', color: Colors.blue, onTap: () async {   // زر عرض جميع البطاقات
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AllFlashcardsScreen(allFlashcards: flashcards, onDelete: _deleteCard, onEdit: _showEditCardDialog)),
                  );
                  _loadFlashcards();   // إعادة تحميل البطاقات بعد العودة
                }),
                _buildActionButton(icon: Icons.category, label: 'التصنيفات', color: Colors.cyan, onTap: _showCategoriesList),   // زر التصنيفات
                _buildActionButton(icon: Icons.quiz, label: 'اختبار', color: Colors.orange, onTap: _startQuiz),   // زر الاختبار
                _buildActionButton(icon: Icons.text_fields, label: 'نص', color: Colors.teal, onTap: _showProcessTextDialog),   // زر معالجة النصوص
                _buildActionButton(icon: Icons.camera_alt, label: 'صورة', color: Colors.purple, onTap: _showImageSourceDialog),   // زر معالجة الصور
              ],
            ),
            const SizedBox(height: 20),
            const Text('آخر البطاقات المضافة:', style: TextStyle(fontWeight: FontWeight.bold)),   // عنوان قسم آخر البطاقات
            const SizedBox(height: 10),
            Expanded(
              child: displayCards.isEmpty   // إذا لم توجد بطاقات
                  ? const Center(child: Text('لا توجد بطاقات حالياً'))   // عرض رسالة فارغة
                  : ListView.builder(   // عرض قائمة آخر البطاقات
                itemCount: displayCards.length,
                itemBuilder: (context, index) {
                  final card = displayCards[index];   // الحصول على البطاقة الحالية
                  return Card(
                    child: ListTile(
                      leading: card.imagePath != null ? const Icon(Icons.image, color: Colors.purple) : const Icon(Icons.note),   // أيقونة حسب نوع البطاقة
                      title: Text(card.question, maxLines: 1, overflow: TextOverflow.ellipsis),   // عرض السؤال مع اقتصاص إذا كان طويلاً
                      subtitle: Text('التصنيف: ${card.category}', style: const TextStyle(fontSize: 12)),   // عرض التصنيف
                      trailing: IconButton(icon: const Icon(Icons.share, size: 20, color: Colors.grey), onPressed: () => _shareCard(card)),   // زر مشاركة البطاقة
                      onTap: () => _showCardDetails(card),   // عند الضغط يتم عرض تفاصيل البطاقة
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Card(   // إنشاء بطاقة تحتوي على زر
      elevation: 2,   // ارتفاع الظل للبطاقة
      child: InkWell(   // عنصر قابل للنقر
          onTap: onTap,   // تنفيذ الدالة عند الضغط
          borderRadius: BorderRadius.circular(12),   // تدوير الحواف
          child: Column(   // تنظيم العناصر عمودياً
              mainAxisAlignment: MainAxisAlignment.center,   // محاذاة العناصر في الوسط
              children: [
                Icon(icon, size: 28, color: color),   // عرض الأيقونة
                Text(label, style: const TextStyle(fontSize: 11))   // عرض النص أسفل الأيقونة
              ]
          )
      ),
    );
  }

  Future<void> _processText(String text, String category, String cardType) async {
    if (text.isEmpty) {   // التحقق إذا كان النص فارغاً
      _showErrorSnackBar('الرجاء إدخال نص للمعالجة');   // إظهار رسالة خطأ
      return;
    }
    _showLoadingIndicator();   // إظهار مؤشر التحميل
    try {
      Uri uri = Uri.parse('${serverUrlNotifier.value}/api/process-text');   // إنشاء رابط API لمعالجة النص
      var response = await http.post(   // إرسال طلب POST للسيرفر
        uri,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},   // تحديد نوع المحتوى
        body: jsonEncode({'text': text, 'card_type': cardType}),   // إرسال النص ونوع البطاقة
      );

      if (response.statusCode == 200) {   // إذا كان الرد ناجحاً
        final data = jsonDecode(utf8.decode(response.bodyBytes));   // فك تشفير البيانات المستلمة
        if (data['success'] == true) {   // إذا كانت العملية ناجحة
          final List<dynamic> newCardsData = data['flashcards'];   // الحصول على البطاقات الجديدة
          final newCards = newCardsData.map((cardData) => Flashcard(   // تحويل البيانات إلى كائنات Flashcard
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_' + (cardData['question']?.hashCode.toString() ?? Random().nextInt(1000).toString()),   // إنشاء معرف فريد
            question: cardData['question'] ?? 'سؤال فارغ',   // السؤال
            answer: cardData['answer'] ?? 'إجابة فارغة',   // الإجابة
            category: category,   // التصنيف
            nextReviewDate: DateTime.now(),   // تاريخ المراجعة القادم
            interval: 1,   // الفاصل الزمني للمراجعة
            answerType: cardData['answerType'] ?? cardType,   // نوع الإجابة
            options: (cardData['options'] as List?)?.map((e) => e.toString()).toList() ?? [],   // الخيارات (إن وجدت)
            correctOptionIndex: cardData['correctOptionIndex'] as int?,   // الخيار الصحيح
          )).toList();
          setState(() {   // تحديث واجهة المستخدم
            flashcards.addAll(newCards);   // إضافة البطاقات الجديدة للقائمة
          });
          await _saveFlashcards();   // حفظ البطاقات في التخزين
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(   // إظهار رسالة نجاح
            SnackBar(content: Text('تم إنشاء ${newCards.length} بطاقة بنجاح!'), backgroundColor: Colors.green),
          );
        } else {
          _showErrorSnackBar('فشل في معالجة النص: ${data['error'] ?? 'سبب غير معروف'}');   // إظهار رسالة خطأ إذا فشلت العملية
        }
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في الاتصال بالسيرفر: $e');   // إظهار رسالة خطأ عند حدوث مشكلة في الاتصال
    } finally {
      if (mounted) Navigator.of(context).pop();   // إغلاق مؤشر التحميل
    }
  }

  Future<void> _pickImage(ImageSource source, String category, String cardType) async {
    final XFile? image = await _picker.pickImage(source: source);   // اختيار صورة من الكاميرا أو المعرض
    if (image != null) {
      _processImage(image, category, cardType);   // معالجة الصورة إذا تم اختيارها
    }
  }

  void _showLoadingIndicator() {   // دالة لإظهار مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,   // منع إغلاق النافذة بالنقر خارجها
      builder: (context) => const AlertDialog(
        title: Text('جاري المعالجة...'),   // عنوان النافذة
        content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),   // مؤشر دائري للتحميل
              SizedBox(width: 20),
              Text('يرجى الانتظار')   // نص توضيحي
            ]
        ),
      ),
    );
  }

  Future<void> _processImage(XFile image, String category, String cardType) async {
    _showLoadingIndicator();   // إظهار مؤشر التحميل
    try {
      Uri uri = Uri.parse('${serverUrlNotifier.value}/api/process-image');   // رابط API لمعالجة الصور
      var request = http.MultipartRequest('POST', uri);   // إنشاء طلب متعدد الأجزاء
      request.files.add(await http.MultipartFile.fromPath('image', image.path, contentType: MediaType('image', 'jpeg')));   // إضافة الصورة للطلب
      request.fields['card_type'] = cardType;   // إضافة نوع البطاقة

      var streamedResponse = await request.send();   // إرسال الطلب
      var response = await http.Response.fromStream(streamedResponse);   // الحصول على الرد

      if (response.statusCode == 200) {   // إذا كان الرد ناجحاً
        final data = jsonDecode(utf8.decode(response.bodyBytes));   // فك تشفير البيانات
        if (data['success'] == true) {   // إذا كانت العملية ناجحة
          final List<dynamic> newCardsData = data['flashcards'];   // الحصول على البطاقات الجديدة
          final newCards = newCardsData.map((cardData) => Flashcard(   // تحويل البيانات إلى كائنات Flashcard
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_' + (cardData['question']?.hashCode.toString() ?? Random().nextInt(1000).toString()),
            question: cardData['question'] ?? 'سؤال فارغ',
            answer: cardData['answer'] ?? 'إجابة فارغة',
            category: category,
            nextReviewDate: DateTime.now(),
            interval: 1,
            answerType: cardData['answerType'] ?? cardType,
            options: (cardData['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
            correctOptionIndex: cardData['correctOptionIndex'] as int?,
          )).toList();
          setState(() {   // تحديث واجهة المستخدم
            flashcards.addAll(newCards);
          });
          await _saveFlashcards();   // حفظ البطاقات
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(   // إظهار رسالة نجاح
              SnackBar(
                content: Text('تم إنشاء ${newCards.length} بطاقة بنجاح!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في الاتصال بالسيرفر: $e');   // إظهار رسالة خطأ عند فشل الاتصال
    } finally {
      if (mounted) Navigator.of(context).pop();   // إغلاق مؤشر التحميل
    }
  }
  void _showThemeMenu() {   // دالة لعرض قائمة اختيار المظهر
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختر المظهر'),   // عنوان النافذة
        children: [
          ListTile(   // خيار المظهر التلقائي
            title: const Text('تلقائي'),
            onTap: () {
              themeNotifier.value = ThemeMode.system;   // تعيين المظهر حسب النظام
              Hive.box('settings').put('themeMode', 0);   // حفظ الإعداد
              Navigator.pop(context);   // إغلاق النافذة
            },
          ),
          ListTile(   // خيار المظهر الفاتح
            title: const Text('فاتح'),
            onTap: () {
              themeNotifier.value = ThemeMode.light;   // تعيين المظهر الفاتح
              Hive.box('settings').put('themeMode', 1);   // حفظ الإعداد
              Navigator.pop(context);
            },
          ),
          ListTile(   // خيار المظهر الداكن
            title: const Text('داكن'),
            onTap: () {
              themeNotifier.value = ThemeMode.dark;   // تعيين المظهر الداكن
              Hive.box('settings').put('themeMode', 2);   // حفظ الإعداد
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportCards(List<Flashcard> cardsToExport, String fileNamePrefix) async {   // دالة لتصدير البطاقات إلى ملف JSON
    if (cardsToExport.isEmpty) return;   // إذا لم توجد بطاقات لا يتم التصدير
    try {
      final jsonString = jsonEncode(cardsToExport.map((c) => c.toMap()).toList());   // تحويل البطاقات إلى JSON
      final tempDir = await getTemporaryDirectory();   // الحصول على مجلد مؤقت
      final file = File('${tempDir.path}/${fileNamePrefix}.json');   // إنشاء ملف باسم محدد
      await file.writeAsString(jsonString);   // كتابة البيانات في الملف
      await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية من ذاكرتي الذكية');   // مشاركة الملف عبر التطبيقات
    } catch (e) {
      _showErrorSnackBar('خطأ في التصدير: $e');   // إظهار رسالة خطأ عند الفشل
    }
  }

  void _exportAllCards() => _exportCards(flashcards, "backup_all");   // دالة لتصدير جميع البطاقات باسم backup_all.json

  void _importFlashcards() async {   // دالة لاستيراد البطاقات من ملف JSON
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(   // فتح نافذة لاختيار ملف
        type: FileType.custom,
        allowedExtensions: ['json'],   // السماح فقط بملفات JSON
      );
      if (result != null) {   // إذا تم اختيار ملف
        File file = File(result.files.single.path!);   // الحصول على الملف
        String jsonString = await file.readAsString();   // قراءة محتوى الملف
        dynamic decodedData = jsonDecode(jsonString);   // فك تشفير JSON
        List<Flashcard> newCards = [];
        if (decodedData is List) {   // إذا كانت البيانات عبارة عن قائمة
          for (var item in decodedData) {
            newCards.add(Flashcard.fromMap(Map<String, dynamic>.from(item)));   // تحويل كل عنصر إلى كائن Flashcard
          }
        }
        setState(() {   // تحديث واجهة المستخدم
          for (var nc in newCards) {
            if (!flashcards.any((c) => c.id == nc.id)) flashcards.add(nc);   // إضافة البطاقات الجديدة إذا لم تكن موجودة مسبقاً
          }
        });
        await _saveFlashcards();   // حفظ البطاقات في التخزين
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاستيراد بنجاح')));   // إظهار رسالة نجاح
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في الاستيراد: $e');   // إظهار رسالة خطأ عند الفشل
    }
  }

  void _showCategoriesList() {   // دالة لعرض قائمة التصنيفات
    final categories = <String, int>{};   // خريطة لتخزين التصنيفات وعدد البطاقات في كل تصنيف
    for (var card in flashcards) categories.update(card.category, (count) => count + 1, ifAbsent: () => 1);   // حساب عدد البطاقات لكل تصنيف
    final sorted = categories.entries.toList()..sort((a, b) => a.key.compareTo(b.key));   // تحويل الخريطة إلى قائمة وفرزها أبجدياً حسب اسم التصنيف

    showModalBottomSheet(   // عرض نافذة من الأسفل تحتوي على التصنيفات
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('التصنيفات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),   // عنوان القائمة
          ),
          Flexible(
            child: ListView.builder(   // بناء قائمة التصنيفات
              shrinkWrap: true,
              itemCount: sorted.length,   // عدد التصنيفات
              itemBuilder: (context, index) {
                final catName = sorted[index].key;   // اسم التصنيف
                final count = sorted[index].value;   // عدد البطاقات في التصنيف
                return ListTile(
                  title: Text(catName),   // عرض اسم التصنيف
                  trailing: Row(   // عرض العدد وزر المشاركة
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('($count)'),   // عرض عدد البطاقات
                      IconButton(
                        icon: const Icon(Icons.share, size: 20, color: Colors.blue),   // زر مشاركة التصنيف
                        onPressed: () {
                          Navigator.pop(context);   // إغلاق النافذة
                          _exportCards(flashcards.where((c) => c.category == catName).toList(), "category_$catName");   // تصدير البطاقات الخاصة بهذا التصنيف
                        },
                      ),
                    ],
                  ),
                  onTap: () async {   // عند الضغط على التصنيف
                    Navigator.pop(context);   // إغلاق النافذة
                    final filteredCards = flashcards.where((c) => c.category == catName).toList();   // الحصول على البطاقات الخاصة بهذا التصنيف
                    await Navigator.push(context, MaterialPageRoute(
                        builder: (context) => AllFlashcardsScreen(   // الانتقال لشاشة عرض البطاقات الخاصة بالتصنيف
                          allFlashcards: filteredCards,
                          onDelete: _deleteCard,
                          onEdit: _showEditCardDialog,
                          title: 'تصنيف: $catName',
                        )
                    ));
                    _loadFlashcards();   // إعادة تحميل البطاقات بعد العودة
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCardTypeSelectionDialog() async {   // دالة لعرض نافذة اختيار نوع البطاقة
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر نوع البطاقة'),   // عنوان النافذة
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('نصية (سؤال وإجابة)'), onTap: () => Navigator.pop(context, 'text')),   // خيار البطاقة النصية
            ListTile(title: const Text('اختيار من متعدد'), onTap: () => Navigator.pop(context, 'multipleChoice')),   // خيار البطاقة متعددة الاختيارات
            ListTile(title: const Text('صح أو خطأ'), onTap: () => Navigator.pop(context, 'trueFalse')),   // خيار البطاقة صح أو خطأ
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCardDialog() async {   // دالة لإضافة بطاقة جديدة
    final category = await _showCategoryDialog(title: 'تصنيف البطاقة الجديدة');   // اختيار التصنيف
    if (category == null) return;   // إذا لم يتم اختيار تصنيف يتم الإلغاء

    TextEditingController qController = TextEditingController();   // متحكم للنص الخاص بالسؤال
    TextEditingController aController = TextEditingController();   // متحكم للنص الخاص بالإجابة
    String type = 'text'; String? imagePath;   // نوع البطاقة (افتراضي نصية) + مسار الصورة
    List<TextEditingController> optionControllers = [];   // متحكمات خيارات الاختيار المتعدد
    int? correctOptionIndex;   // مؤشر الخيار الصحيح

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة بطاقة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imagePath != null) Image.file(File(imagePath!), height: 100),   // عرض الصورة إذا تم اختيارها
                ElevatedButton.icon(   // زر لإضافة صورة
                  onPressed: () async {
                    final img = await _picker.pickImage(source: ImageSource.gallery);
                    if (img != null) setDialogState(() => imagePath = img.path);
                  },
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('إضافة صورة'),
                ),
                TextField(controller: qController, decoration: const InputDecoration(labelText: 'السؤال')),   // إدخال السؤال
                DropdownButtonFormField<String>(   // اختيار نوع البطاقة
                  value: type,
                  items: [
                    const DropdownMenuItem(value: 'text', child: Text('نص')),
                    const DropdownMenuItem(value: 'multipleChoice', child: Text('اختيارات')),
                    const DropdownMenuItem(value: 'trueFalse', child: Text('صح/خطأ'))
                  ],
                  onChanged: (v) {
                    setDialogState(() {
                      type = v!;
                      optionControllers.clear();
                      correctOptionIndex = null;
                      if (type == 'multipleChoice') for (int i = 0; i < 4; i++) optionControllers.add(TextEditingController());
                    });
                  },
                ),
                if (type == 'text') TextField(controller: aController, decoration: const InputDecoration(labelText: 'الإجابة'))   // إدخال الإجابة النصية
                else if (type == 'multipleChoice') Column(   // إدخال خيارات متعددة
                  children: List.generate(optionControllers.length, (i) => TextField(
                    controller: optionControllers[i],
                    decoration: InputDecoration(
                      labelText: 'خيار ${i + 1}',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.check_circle, color: correctOptionIndex == i ? Colors.green : Colors.grey),
                        onPressed: () => setDialogState(() => correctOptionIndex = i),
                      ),
                    ),
                  )),
                )
                else if (type == 'trueFalse') Column(   // إدخال خيار صح أو خطأ
                    children: [
                      RadioListTile<int>(title: const Text('صح'), value: 0, groupValue: correctOptionIndex, onChanged: (v) => setDialogState(() => correctOptionIndex = v)),
                      RadioListTile<int>(title: const Text('خطأ'), value: 1, groupValue: correctOptionIndex, onChanged: (v) => setDialogState(() => correctOptionIndex = v))
                    ],
                  )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),   // زر الإلغاء
            ElevatedButton(
              onPressed: () async {
                final card = Flashcard(   // إنشاء البطاقة الجديدة
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  question: qController.text,
                  answer: aController.text,
                  category: category,
                  nextReviewDate: DateTime.now(),
                  interval: 1,
                  answerType: type,
                  imagePath: imagePath,
                  options: optionControllers.map((c) => c.text).toList(),
                  correctOptionIndex: correctOptionIndex,
                );
                setState(() => flashcards.add(card));   // إضافة البطاقة للقائمة
                await _saveFlashcards();   // حفظ البطاقات
                Navigator.pop(context);   // إغلاق النافذة
              },
              child: const Text('إضافة'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _showEditCardDialog(Flashcard card) async {   // دالة لتعديل بطاقة موجودة
    TextEditingController qController = TextEditingController(text: card.question);
    TextEditingController aController = TextEditingController(text: card.answer);
    String type = card.answerType; String? imagePath = card.imagePath;
    List<TextEditingController> optionControllers = card.options.map((o) => TextEditingController(text: o)).toList();
    int? correctOptionIndex = card.correctOptionIndex;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل البطاقة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imagePath != null) Image.file(File(imagePath!), height: 80),   // عرض الصورة إذا موجودة
                TextField(controller: qController, decoration: const InputDecoration(labelText: 'السؤال')),   // تعديل السؤال
                if (type == 'text') TextField(controller: aController, decoration: const InputDecoration(labelText: 'الإجابة'))   // تعديل الإجابة النصية
                else if (type == 'multipleChoice') Column(   // تعديل خيارات متعددة
                  children: List.generate(optionControllers.length, (i) => TextField(
                    controller: optionControllers[i],
                    decoration: InputDecoration(
                      labelText: 'خيار ${i + 1}',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.check_circle, color: correctOptionIndex == i ? Colors.green : Colors.grey),
                        onPressed: () => setDialogState(() => correctOptionIndex = i),
                      ),
                    ),
                  )),
                )
                else if (type == 'trueFalse') Column(   // تعديل خيار صح أو خطأ
                    children: [
                      RadioListTile<int>(title: const Text('صح'), value: 0, groupValue: correctOptionIndex, onChanged: (v) => setDialogState(() => correctOptionIndex = v)),
                      RadioListTile<int>(title: const Text('خطأ'), value: 1, groupValue: correctOptionIndex, onChanged: (v) => setDialogState(() => correctOptionIndex = v))
                    ],
                  )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),   // زر الإلغاء
            ElevatedButton(
              onPressed: () async {
                final updated = card.copyWith(   // إنشاء نسخة محدثة من البطاقة
                  question: qController.text,
                  answer: aController.text,
                  imagePath: imagePath,
                  options: optionControllers.map((c) => c.text).toList(),
                  correctOptionIndex: correctOptionIndex,
                );
                setState(() { int idx = flashcards.indexWhere((c) => c.id == card.id); flashcards[idx] = updated; });   // تحديث البطاقة في القائمة
                await _saveFlashcards();   // حفظ التعديلات
                Navigator.pop(context);   // إغلاق النافذة
              },
              child: const Text('حفظ'),
            )
          ],
        ),
      ),
    );
  }

  void _startQuiz() async {   // دالة لبدء الاختبار
    final now = DateTime.now();
    final dueCardsOverall = flashcards.where((c) => c.nextReviewDate.isBefore(now.add(const Duration(minutes: 1)))).toList();   // الحصول على البطاقات المستحقة
    final categoriesWithDueCards = dueCardsOverall.map((c) => c.category).toSet().toList();   // استخراج التصنيفات المستحقة

    if (categoriesWithDueCards.isEmpty) {   // إذا لم توجد بطاقات مستحقة
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بطاقات للمراجعة حالياً')));
      return;
    }

    String? cat = await showDialog<String>(   // اختيار التصنيف للاختبار
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر التصنيف للاختبار'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('كل التصنيفات المستحقة'), onTap: () => Navigator.pop(context, 'ALL')),
              ...categoriesWithDueCards.map((c) => ListTile(title: Text(c), onTap: () => Navigator.pop(context, c)))
            ],
          ),
        ),
      ),
    );

    if (cat == null) return;   // إذا لم يتم اختيار تصنيف يتم الإلغاء

    var due = (cat == 'ALL')   // تحديد البطاقات المستحقة حسب التصنيف المختار
        ? dueCardsOverall      // إذا كان "كل التصنيفات" يتم أخذ جميع البطاقات المستحقة
        : dueCardsOverall.where((c) => c.category == cat).toList();   // وإلا يتم تصفية البطاقات حسب التصنيف

    final result = await Navigator.push(   // الانتقال إلى شاشة المراجعة
      context,
      MaterialPageRoute(builder: (context) => ReviewScreen(flashcards: due)),
    );

    if (result != null && result is List<Flashcard>) {   // إذا تم إرجاع نتائج من شاشة المراجعة
      setState(() {
        for (var updatedCard in result) {   // تحديث البطاقات بعد المراجعة
          int index = flashcards.indexWhere((c) => c.id == updatedCard.id);
          if (index != -1) flashcards[index] = updatedCard;
        }
      });
      await _saveFlashcards();   // حفظ التعديلات
    }
  }

  void _showProcessTextDialog() async {   // دالة لعرض نافذة معالجة النصوص
    final cat = await _showCategoryDialog(title: 'تصنيف البطاقات'); if (cat == null) return;
    final type = await _showCardTypeSelectionDialog(); if (type == null) return;
    TextEditingController textC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معالجة نص'),
        content: TextField(controller: textC, maxLines: 5),   // إدخال النص
        actions: [
          ElevatedButton(
            onPressed: () { _processText(textC.text, cat, type); Navigator.pop(context); },   // معالجة النص وإغلاق النافذة
            child: const Text('معالجة'),
          )
        ],
      ),
    );
  }

  void _showImageSourceDialog() {   // دالة لاختيار مصدر الصورة
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مصدر الصورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(   // خيار الكاميرا
              leading: const Icon(Icons.camera_alt),
              title: const Text('الكاميرا'),
              onTap: () async {
                Navigator.pop(context);
                final cat = await _showCategoryDialog(title: 'التصنيف');
                final type = await _showCardTypeSelectionDialog();
                if (cat != null && type != null) _pickImage(ImageSource.camera, cat, type);
              },
            ),
            ListTile(   // خيار المعرض
              leading: const Icon(Icons.photo_library),
              title: const Text('المعرض'),
              onTap: () async {
                Navigator.pop(context);
                final cat = await _showCategoryDialog(title: 'التصنيف');
                final type = await _showCardTypeSelectionDialog();
                if (cat != null && type != null) _pickImage(ImageSource.gallery, cat, type);
              },
            )
          ],
        ),
      ),
    );
  }

  void _showCardDetails(Flashcard card) {   // دالة لعرض تفاصيل البطاقة
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفاصيل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('السؤال: ${card.question}'),
            Text('الإجابة: ${card.answer}'),
            Text('التصنيف: ${card.category}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  Future<String?> _showCategoryDialog({required String title}) async {   // دالة لاختيار أو إنشاء تصنيف
    final categories = flashcards.map((c) => c.category).toSet().toList();   // استخراج التصنيفات الموجودة
    TextEditingController textC = TextEditingController(); String? selected;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: textC, decoration: const InputDecoration(labelText: 'تصنيف جديد')),   // إدخال تصنيف جديد
              Wrap(children: categories.map((c) => ChoiceChip(   // عرض التصنيفات الحالية كـ Chips
                label: Text(c),
                selected: selected == c,
                onSelected: (s) => setState(() => selected = s ? c : null),
              )).toList())
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, textC.text.isNotEmpty ? textC.text : selected),   // تأكيد الاختيار أو التصنيف الجديد
              child: const Text('تأكيد'),
            )
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));   // دالة لإظهار رسالة خطأ
  void _shareCard(Flashcard card) => Share.share("سؤال: ${card.question}\nإجابة: ${card.answer}");   // دالة لمشاركة البطاقة
}
class AllFlashcardsScreen extends StatefulWidget {   // شاشة لعرض جميع البطاقات
  final List<Flashcard> allFlashcards;   // قائمة البطاقات
  final Function(String) onDelete;   // دالة لحذف بطاقة
  final Function(Flashcard) onEdit;   // دالة لتعديل بطاقة
  final String title;   // عنوان الشاشة
  AllFlashcardsScreen({required this.allFlashcards, required this.onDelete, required this.onEdit, this.title = 'كل البطاقات'});
  @override
  _AllFlashcardsScreenState createState() => _AllFlashcardsScreenState();   // إنشاء الحالة الخاصة بالشاشة
}

class _AllFlashcardsScreenState extends State<AllFlashcardsScreen> {
  List<Flashcard> _filtered = [];   // قائمة البطاقات بعد التصفية (بحث)
  TextEditingController _search = TextEditingController();   // متحكم لحقل البحث

  @override
  void initState() {
    super.initState();
    _filtered = widget.allFlashcards;   // تعيين البطاقات المرسلة للشاشة
    _search.addListener(() {   // إضافة مستمع لحقل البحث
      setState(() {
        _filtered = widget.allFlashcards.where((c) => c.question.contains(_search.text) || c.category.contains(_search.text)).toList();   // تصفية البطاقات حسب السؤال أو التصنيف
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),   // عرض عنوان الشاشة
        bottom: PreferredSize(   // إضافة شريط بحث أسفل العنوان
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'بحث...',   // نص توضيحي
                prefixIcon: const Icon(Icons.search),   // أيقونة البحث
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),   // تنسيق الحقل
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(   // بناء قائمة البطاقات
        itemCount: _filtered.length,   // عدد البطاقات بعد التصفية
        itemBuilder: (context, i) {
          final c = _filtered[i];   // البطاقة الحالية
          return Card(
            child: ListTile(
              title: Text(c.question),   // عرض السؤال
              subtitle: Text('إجابة: ${c.answer}\nتصنيف: ${c.category}', style: const TextStyle(fontSize: 12)),   // عرض الإجابة والتصنيف
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(   // زر تعديل البطاقة
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      await widget.onEdit(c);   // استدعاء دالة التعديل
                      setState(() {
                        _filtered = Hive.box('flashcards').get('cards').map((m) => Flashcard.fromMap(Map<String, dynamic>.from(m))).toList();   // إعادة تحميل البطاقات من التخزين
                        if (widget.title != 'كل البطاقات') {   // إذا كانت الشاشة خاصة بتصنيف معين
                          String cat = widget.title.replaceFirst('تصنيف: ', '');
                          _filtered = _filtered.where((fc) => fc.category == cat).toList();   // تصفية البطاقات حسب التصنيف
                        }
                      });
                    },
                  ),
                  IconButton(   // زر حذف البطاقة
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await widget.onDelete(c.id);   // استدعاء دالة الحذف
                      setState(() { _filtered.removeWhere((item) => item.id == c.id); });   // إزالة البطاقة من القائمة
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}