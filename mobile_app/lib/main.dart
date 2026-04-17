import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; 
import 'review_screen.dart';
import 'statistics_screen.dart';
import 'models/flashcard_model.dart';
import 'services/notification_service.dart'; 

late ValueNotifier<ThemeMode> themeNotifier;
late ValueNotifier<String> serverUrlNotifier; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox('flashcards');
  final settings = await Hive.openBox('settings');
  
  final themeIndex = settings.get('themeMode', defaultValue: 0) as int;
  themeNotifier = ValueNotifier(ThemeMode.values[themeIndex]);

  final savedUrl = settings.get('serverUrl', defaultValue: 'http://192.168.43.226:5000') as String;
  serverUrlNotifier = ValueNotifier(savedUrl);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'ذاكرتي الذكية',
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue, brightness: Brightness.light),
          darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue, brightness: Brightness.dark),
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [const Locale('ar', '')], 
          locale: const Locale('ar', ''),
          home: HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Flashcard> flashcards = []; 
  final ImagePicker _picker = ImagePicker(); 

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadFlashcards();
    await NotificationService.requestPermissions();
    _checkDueCards();
  }

  void _checkDueCards() {
    final now = DateTime.now();
    final dueCount = flashcards.where((c) => c.nextReviewDate.isBefore(now.add(const Duration(minutes: 1)))).length;
    NotificationService.checkAndNotifyDueCards(dueCount);
  }

  Future<void> _loadFlashcards() async {
    final box = Hive.box('flashcards');
    List<Flashcard> tempLoadedCards = [];
    try {
      dynamic cardsData = box.get('cards');
      if (cardsData is List) {
        for (var item in cardsData) {
          if (item is Map) {
            tempLoadedCards.add(Flashcard.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      }
    } catch (e) { print('Error Loading Cards: $e'); }
    setState(() {
      flashcards = tempLoadedCards;
    });
  }

  Future<void> _saveFlashcards() async {
    final box = Hive.box('flashcards');
    await box.put('cards', flashcards.map((c) => c.toMap()).toList());
  }

  Future<void> _deleteCard(String id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البطاقة'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذه البطاقة نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() {
        flashcards.removeWhere((c) => c.id == id);
      });
      await _saveFlashcards();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف البطاقة')));
    }
  }

  void _showServerSettings() {
    TextEditingController urlController = TextEditingController(text: serverUrlNotifier.value);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات الاتصال عن بُعد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل رابط السيرفر الجديد:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'https://your-server.com'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              String newUrl = urlController.text.trim();
              if (newUrl.isNotEmpty) {
                if (newUrl.startsWith('http://') && newUrl.contains('onrender.com')) {
                   newUrl = newUrl.replaceFirst('http://', 'https://');
                }
                serverUrlNotifier.value = newUrl;
                Hive.box('settings').put('serverUrl', newUrl);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ العنوان الجديد')));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayCards = flashcards.reversed.take(10).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ذاكرتي الذكية'),
        actions: [
          IconButton(icon: const Icon(Icons.bar_chart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StatisticsScreen(flashcards: flashcards)))), 
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
               if (val == 'theme') _showThemeMenu();
               if (val == 'server') _showServerSettings();
               if (val == 'export') _exportAllCards();
               if (val == 'import') _importFlashcards();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'theme', child: Text('المظهر')),
              const PopupMenuItem(value: 'server', child: Text('إعدادات السيرفر')),
              const PopupMenuItem(value: 'export', child: Text('تصدير نسخة احتياطية')),
              const PopupMenuItem(value: 'import', child: Text('استيراد نسخة احتياطية')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.school, size: 60, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 10),
                    const Text('مرحباً بك في ذاكرتي الذكية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ValueListenableBuilder<String>(
                      valueListenable: serverUrlNotifier,
                      builder: (_, url, __) => Text('متصل بـ: $url', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildActionButton(icon: Icons.add, label: 'إضافة', color: Colors.green, onTap: _showAddCardDialog),
                _buildActionButton(icon: Icons.style, label: 'البطاقات', color: Colors.blue, onTap: () async { 
                   await Navigator.push(context, MaterialPageRoute(builder: (context) => AllFlashcardsScreen(allFlashcards: flashcards, onDelete: _deleteCard, onEdit: _showEditCardDialog))); 
                   _loadFlashcards();
                }),
                _buildActionButton(icon: Icons.category, label: 'التصنيفات', color: Colors.cyan, onTap: _showCategoriesList),
                _buildActionButton(icon: Icons.quiz, label: 'اختبار', color: Colors.orange, onTap: _startQuiz),
                _buildActionButton(icon: Icons.text_fields, label: 'نص', color: Colors.teal, onTap: _showProcessTextDialog),
                _buildActionButton(icon: Icons.camera_alt, label: 'صورة', color: Colors.purple, onTap: _showImageSourceDialog),
              ],
            ),
            const SizedBox(height: 20),
            const Text('آخر البطاقات المضافة:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: displayCards.isEmpty
                  ? const Center(child: Text('لا توجد بطاقات حالياً'))
                  : ListView.builder(
                      itemCount: displayCards.length,
                      itemBuilder: (context, index) {
                        final card = displayCards[index];
                        return Card(
                          child: ListTile(
                            leading: card.imagePath != null ? const Icon(Icons.image, color: Colors.purple) : const Icon(Icons.note),
                            title: Text(card.question, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('التصنيف: ${card.category}', style: const TextStyle(fontSize: 12)),
                            trailing: IconButton(icon: const Icon(Icons.share, size: 20, color: Colors.grey), onPressed: () => _shareCard(card)),
                            onTap: () => _showCardDetails(card),
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
    return Card(
      elevation: 2,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 28, color: color), Text(label, style: const TextStyle(fontSize: 11))])),
    );
  }

  Future<void> _processText(String text, String category, String cardType) async {
    if (text.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال نص للمعالجة');
      return;
    }
    _showLoadingIndicator(); 
    try {
      Uri uri = Uri.parse('${serverUrlNotifier.value}/api/process-text');
      var response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'text': text, 'card_type': cardType}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> newCardsData = data['flashcards'];
          final newCards = newCardsData.map((cardData) => Flashcard(
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
          setState(() {
            flashcards.addAll(newCards);
          });
          await _saveFlashcards();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إنشاء ${newCards.length} بطاقة بنجاح!'), backgroundColor: Colors.green));
        } else {
          _showErrorSnackBar('فشل في معالجة النص: ${data['error'] ?? 'سبب غير معروف'}');
        }
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في الاتصال بالسيرفر: $e');
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _pickImage(ImageSource source, String category, String cardType) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      _processImage(image, category, cardType);
    }
  }

  void _showLoadingIndicator() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('جاري المعالجة...'),
        content: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(width: 20), Text('يرجى الانتظار')]),
      ),
    );
  }

  Future<void> _processImage(XFile image, String category, String cardType) async {
    _showLoadingIndicator(); 
    try {
      Uri uri = Uri.parse('${serverUrlNotifier.value}/api/process-image');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', image.path, contentType: MediaType('image', 'jpeg')));
      request.fields['card_type'] = cardType;
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> newCardsData = data['flashcards'];
          final newCards = newCardsData.map((cardData) => Flashcard(
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
          setState(() {
            flashcards.addAll(newCards);
          });
          await _saveFlashcards();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم إنشاء ${newCards.length} بطاقة بنجاح!'),
                backgroundColor: Colors.green,
              ),
            );
          }        }
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في الاتصال بالسيرفر: $e');
    } finally {
      if (mounted) Navigator.of(context).pop(); 
    }
  }

  void _showThemeMenu() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختر المظهر'),
        children: [
          ListTile(title: const Text('تلقائي'), onTap: () { themeNotifier.value = ThemeMode.system; Hive.box('settings').put('themeMode', 0); Navigator.pop(context); }),
          ListTile(title: const Text('فاتح'), onTap: () { themeNotifier.value = ThemeMode.light; Hive.box('settings').put('themeMode', 1); Navigator.pop(context); }),
          ListTile(title: const Text('داكن'), onTap: () { themeNotifier.value = ThemeMode.dark; Hive.box('settings').put('themeMode', 2); Navigator.pop(context); }),
        ],
      ),
    );
  }

  Future<void> _exportCards(List<Flashcard> cardsToExport, String fileNamePrefix) async {
    if (cardsToExport.isEmpty) return;
    try {
      final jsonString = jsonEncode(cardsToExport.map((c) => c.toMap()).toList());
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${fileNamePrefix}.json');
      await file.writeAsString(jsonString);
      await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية من ذاكرتي الذكية');
    } catch (e) { _showErrorSnackBar('خطأ في التصدير: $e'); }
  }

  void _exportAllCards() => _exportCards(flashcards, "backup_all");

  void _importFlashcards() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();
        dynamic decodedData = jsonDecode(jsonString);
        List<Flashcard> newCards = [];
        if (decodedData is List) {
          for (var item in decodedData) {
            newCards.add(Flashcard.fromMap(Map<String, dynamic>.from(item)));
          }
        }
        setState(() {
          for (var nc in newCards) {
            if (!flashcards.any((c) => c.id == nc.id)) flashcards.add(nc);
          }
        });
        await _saveFlashcards();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاستيراد بنجاح')));
      }
    } catch (e) { _showErrorSnackBar('خطأ في الاستيراد: $e'); }
  }

  void _showCategoriesList() {
    final categories = <String, int>{};
    for (var card in flashcards) categories.update(card.category, (c) => c + 1, ifAbsent: () => 1);
    final sorted = categories.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('التصنيفات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final catName = sorted[index].key;
                final count = sorted[index].value;
                return ListTile(
                  title: Text(catName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('($count)'),
                      IconButton(
                        icon: const Icon(Icons.share, size: 20, color: Colors.blue),
                        onPressed: () {
                          Navigator.pop(context);
                          _exportCards(flashcards.where((c) => c.category == catName).toList(), "category_$catName");
                        },
                      ),
                    ],
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final filteredCards = flashcards.where((c) => c.category == catName).toList();
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (context) => AllFlashcardsScreen(
                        allFlashcards: filteredCards, 
                        onDelete: _deleteCard, 
                        onEdit: _showEditCardDialog,
                        title: 'تصنيف: $catName',
                      )
                    ));
                    _loadFlashcards();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCardTypeSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر نوع البطاقة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('نصية (سؤال وإجابة)'), onTap: () => Navigator.pop(context, 'text')),
            ListTile(title: const Text('اختيار من متعدد'), onTap: () => Navigator.pop(context, 'multipleChoice')),
            ListTile(title: const Text('صح أو خطأ'), onTap: () => Navigator.pop(context, 'trueFalse')),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCardDialog() async {
    final category = await _showCategoryDialog(title: 'تصنيف البطاقة الجديدة');
    if (category == null) return;
    TextEditingController qController = TextEditingController();
    TextEditingController aController = TextEditingController();
    String type = 'text'; String? imagePath;
    List<TextEditingController> optionControllers = [];
    int? correctOptionIndex;

    await showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('إضافة بطاقة'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (imagePath != null) Image.file(File(imagePath!), height: 100),
        ElevatedButton.icon(onPressed: () async { final img = await _picker.pickImage(source: ImageSource.gallery); if (img != null) setDialogState(() => imagePath = img.path); }, icon: const Icon(Icons.add_a_photo), label: const Text('إضافة صورة')),
        TextField(controller: qController, decoration: const InputDecoration(labelText: 'السؤال')),
        DropdownButtonFormField<String>(value: type, items: [const DropdownMenuItem(value: 'text', child: Text('نص')), const DropdownMenuItem(value: 'multipleChoice', child: Text('اختيارات')), const DropdownMenuItem(value: 'trueFalse', child: Text('صح/خطأ'))], onChanged: (v) { setDialogState(() { type = v!; optionControllers.clear(); correctOptionIndex = null; if (type == 'multipleChoice') for (int i = 0; i < 4; i++) optionControllers.add(TextEditingController()); }); }),
        if (type == 'text') TextField(controller: aController, decoration: const InputDecoration(labelText: 'الإجابة'))
        else if (type == 'multipleChoice') Column(children: List.generate(optionControllers.length, (i) => TextField(controller: optionControllers[i], decoration: InputDecoration(labelText: 'خيار ${i + 1}', suffixIcon: IconButton(icon: Icon(Icons.check_circle, color: correctOptionIndex == i ? Colors.green : Colors.grey), onPressed: () => setDialogState(() => correctOptionIndex = i))))))
        else if (type == 'trueFalse') Column(children: [RadioListTile<int>(title: const Text('صح'), value: 0, groupValue: correctOptionIndex, onChanged: (v) => setDialogState(() => correctOptionIndex = v)), RadioListTile<int>(title: const Text('خطأ'), value: 1, groupValue: correctOptionIndex, onChanged: (v) => setDialogState(() => correctOptionIndex = v))])
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), ElevatedButton(onPressed: () async {
        final card = Flashcard(id: DateTime.now().millisecondsSinceEpoch.toString(), question: qController.text, answer: aController.text, category: category, nextReviewDate: DateTime.now(), interval: 1, answerType: type, imagePath: imagePath, options: optionControllers.map((c) => c.text).toList(), correctOptionIndex: correctOptionIndex);
        setState(() => flashcards.add(card)); await _saveFlashcards(); Navigator.pop(context);
      }, child: const Text('إضافة'))]
    )));
  }

  Future<void> _showEditCardDialog(Flashcard card) async {
    TextEditingController qController = TextEditingController(text: card.question);
    TextEditingController aController = TextEditingController(text: card.answer);
    String type = card.answerType; String? imagePath = card.imagePath;
    List<TextEditingController> optionControllers = card.options.map((o) => TextEditingController(text: o)).toList();
    int? correctOptionIndex = card.correctOptionIndex;

    await showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('تعديل البطاقة'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (imagePath != null) Image.file(File(imagePath!), height: 80),
        TextField(controller: qController, decoration: const InputDecoration(labelText: 'السؤال')),
        if (type == 'text') TextField(controller: aController, decoration: const InputDecoration(labelText: 'الإجابة'))
        else if (type == 'multipleChoice') Column(children: List.generate(optionControllers.length, (i) => TextField(controller: optionControllers[i], decoration: InputDecoration(labelText: 'خيار ${i + 1}', suffixIcon: IconButton(icon: Icon(Icons.check_circle, color: correctOptionIndex == i ? Colors.green : Colors.grey), onPressed: () => setDialogState(() => correctOptionIndex = i))))))
        else if (type == 'trueFalse') Column(children: [RadioListTile<int>(title: const Text('صح'), value: 0, groupValue: correctOptionIndex, onChanged: (v) => setDialogState(() => correctOptionIndex = v)), RadioListTile<int>(title: const Text('خطأ'), value: 1, groupValue: correctOptionIndex, onChanged: (v) => setDialogState(() => correctOptionIndex = v))])
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), ElevatedButton(onPressed: () async {
        final updated = card.copyWith(question: qController.text, answer: aController.text, imagePath: imagePath, options: optionControllers.map((c) => c.text).toList(), correctOptionIndex: correctOptionIndex);
        setState(() { int idx = flashcards.indexWhere((c) => c.id == card.id); flashcards[idx] = updated; });
        await _saveFlashcards(); Navigator.pop(context);
      }, child: const Text('حفظ'))]
    )));
  }

  void _startQuiz() async {
    final now = DateTime.now();
    // الحصول على التصنيفات التي لديها بطاقات مستحقة فقط
    final dueCardsOverall = flashcards.where((c) => c.nextReviewDate.isBefore(now.add(const Duration(minutes: 1)))).toList();
    final categoriesWithDueCards = dueCardsOverall.map((c) => c.category).toSet().toList();

    if (categoriesWithDueCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بطاقات للمراجعة حالياً')));
      return;
    }

    String? cat = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('اختر التصنيف'), 
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: const Text('كل التصنيفات المستحقة'), onTap: () => Navigator.pop(context, 'ALL')),
        ...categoriesWithDueCards.map((c) => ListTile(title: Text(c), onTap: () => Navigator.pop(context, c)))
      ]))));

    if (cat == null) return;
    
    var due = (cat == 'ALL') 
        ? dueCardsOverall 
        : dueCardsOverall.where((c) => c.category == cat).toList();

    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ReviewScreen(flashcards: due)));
    
    if (result != null && result is List<Flashcard>) {
       setState(() {
         for (var updatedCard in result) {
           int index = flashcards.indexWhere((c) => c.id == updatedCard.id);
           if (index != -1) flashcards[index] = updatedCard;
         }
       });
       await _saveFlashcards();
    }
  }

  void _showProcessTextDialog() async {
    final cat = await _showCategoryDialog(title: 'تصنيف البطاقات'); if (cat == null) return;
    final type = await _showCardTypeSelectionDialog(); if (type == null) return;
    TextEditingController textC = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('معالجة نص'), content: TextField(controller: textC, maxLines: 5), actions: [ElevatedButton(onPressed: () { _processText(textC.text, cat, type); Navigator.pop(context); }, child: const Text('معالجة'))]));
  }

  void _showImageSourceDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('مصدر الصورة'), content: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.camera_alt), title: const Text('الكاميرا'), onTap: () async { Navigator.pop(context); final cat = await _showCategoryDialog(title: 'التصنيف'); final type = await _showCardTypeSelectionDialog(); if (cat != null && type != null) _pickImage(ImageSource.camera, cat, type); }), ListTile(leading: const Icon(Icons.photo_library), title: const Text('المعرض'), onTap: () async { Navigator.pop(context); final cat = await _showCategoryDialog(title: 'التصنيف'); final type = await _showCardTypeSelectionDialog(); if (cat != null && type != null) _pickImage(ImageSource.gallery, cat, type); })])));
  }

  void _showCardDetails(Flashcard card) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('تفاصيل'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('السؤال: ${card.question}'), Text('الإجابة: ${card.answer}'), Text('التصنيف: ${card.category}')]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))]));
  }

  Future<String?> _showCategoryDialog({required String title}) async {
    final categories = flashcards.map((c) => c.category).toSet().toList();
    TextEditingController textC = TextEditingController(); String? selected;
    return showDialog<String>(context: context, builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: textC, decoration: const InputDecoration(labelText: 'تصنيف جديد')), Wrap(children: categories.map((c) => ChoiceChip(label: Text(c), selected: selected == c, onSelected: (s) => setState(() => selected = s ? c : null))).toList())],),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(context, textC.text.isNotEmpty ? textC.text : selected), child: const Text('تأكيد'))]
    )));
  }

  void _showErrorSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  void _shareCard(Flashcard card) => Share.share("سؤال: ${card.question}\nإجابة: ${card.answer}");
}

class AllFlashcardsScreen extends StatefulWidget {
  final List<Flashcard> allFlashcards;
  final Function(String) onDelete;
  final Function(Flashcard) onEdit;
  final String title;
  AllFlashcardsScreen({required this.allFlashcards, required this.onDelete, required this.onEdit, this.title = 'كل البطاقات'});
  @override
  _AllFlashcardsScreenState createState() => _AllFlashcardsScreenState();
}

class _AllFlashcardsScreenState extends State<AllFlashcardsScreen> {
  List<Flashcard> _filtered = [];
  TextEditingController _search = TextEditingController();

  @override
  void initState() { super.initState(); _filtered = widget.allFlashcards; _search.addListener(() { setState(() { _filtered = widget.allFlashcards.where((c) => c.question.contains(_search.text) || c.category.contains(_search.text)).toList(); }); }); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), bottom: PreferredSize(preferredSize: const Size.fromHeight(60), child: Padding(padding: EdgeInsets.all(8), child: TextField(controller: _search, decoration: InputDecoration(hintText: 'بحث...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))))),
      body: ListView.builder(
        itemCount: _filtered.length,
        itemBuilder: (context, i) {
          final c = _filtered[i];
          return Card(child: ListTile(
            title: Text(c.question),
            subtitle: Text('إجابة: ${c.answer}\nتصنيف: ${c.category}', style: const TextStyle(fontSize: 12)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () async { 
                await widget.onEdit(c); 
                setState(() { 
                  _filtered = Hive.box('flashcards').get('cards').map((m) => Flashcard.fromMap(Map<String, dynamic>.from(m))).toList(); if (widget.title != 'كل البطاقات') { String cat = widget.title.replaceFirst('تصنيف: ', ''); _filtered = _filtered.where((fc) => fc.category == cat).toList(); } 
                }); 
              }),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { 
                await widget.onDelete(c.id); setState(() { _filtered.removeWhere((item) => item.id == c.id); });
              }),
            ]),
          ));
        },
      ),
    );
  }
}
