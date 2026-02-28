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

late ValueNotifier<ThemeMode> themeNotifier;
late ValueNotifier<String> serverUrlNotifier; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          supportedLocales: [Locale('ar', '')],
          locale: Locale('ar', ''),
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
    _loadFlashcards();
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
    } catch (e) { print('Error: $e'); }
    setState(() => flashcards = tempLoadedCards);
  }

  Future<void> _saveFlashcards() async {
    final box = Hive.box('flashcards');
    await box.put('cards', flashcards.map((c) => c.toMap()).toList());
  }

  void _showServerSettings() {
    TextEditingController urlController = TextEditingController(text: serverUrlNotifier.value);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إعدادات الاتصال عن بُعد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('أدخل رابط السيرفر (مثلاً رابط Ngrok أو IP الجهاز):', style: TextStyle(fontSize: 13)),
            SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: InputDecoration(border: OutlineInputBorder(), hintText: 'http://your-link.ngrok-free.app'),
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              String newUrl = urlController.text.trim();
              if (newUrl.isNotEmpty) {
                serverUrlNotifier.value = newUrl;
                Hive.box('settings').put('serverUrl', newUrl);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ العنوان الجديد')));
              }
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentCards = flashcards.length > 5 ? flashcards.sublist(flashcards.length - 5) : flashcards;

    return Scaffold(
      appBar: AppBar(
        title: Text('ذاكرتي الذكية'),
        actions: [
          IconButton(icon: Icon(Icons.bar_chart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StatisticsScreen(flashcards: flashcards)))),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (val) {
               if (val == 'theme') _showThemeMenu();
               if (val == 'server') _showServerSettings();
               if (val == 'export') _exportAllCards();
               if (val == 'import') _importFlashcards();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'theme', child: Text('المظهر')),
              PopupMenuItem(value: 'server', child: Text('إعدادات السيرفر (عن بُعد)')),
              PopupMenuItem(value: 'export', child: Text('تصدير نسخة احتياطية')),
              PopupMenuItem(value: 'import', child: Text('استيراد نسخة احتياطية')),
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
                    SizedBox(height: 10),
                    Text('مرحباً بك في ذاكرتي الذكية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ValueListenableBuilder<String>(
                      valueListenable: serverUrlNotifier,
                      builder: (_, url, __) => Text('متصل بـ: $url', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildActionButton(icon: Icons.add, label: 'إضافة', color: Colors.green, onTap: _showAddCardDialog),
                _buildActionButton(icon: Icons.style, label: 'البطاقات', color: Colors.blue, onTap: _showFlashcards),
                _buildActionButton(icon: Icons.category, label: 'التصنيفات', color: Colors.cyan, onTap: _showCategoriesList),
                _buildActionButton(icon: Icons.quiz, label: 'اختبار', color: Colors.orange, onTap: _startQuiz),
                _buildActionButton(icon: Icons.text_fields, label: 'نص', color: Colors.teal, onTap: _showProcessTextDialog),
                _buildActionButton(icon: Icons.camera_alt, label: 'صورة', color: Colors.purple, onTap: _showImageSourceDialog),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: recentCards.length,
                itemBuilder: (context, index) {
                  final card = recentCards[recentCards.length - 1 - index];
                  return Card(
                    child: ListTile(
                      leading: card.imagePath != null ? Icon(Icons.image, color: Colors.purple) : Icon(Icons.note),
                      title: Text(card.question, maxLines: 1),
                      subtitle: Text(card.category),
                      trailing: IconButton(icon: Icon(Icons.edit, size: 20), onPressed: () => _showEditCardDialog(card)),
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
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 28, color: color), Text(label, style: TextStyle(fontSize: 11))])),
    );
  }

  Future<void> _processText(String text, String category) async {
    try {
      final response = await http.post(
        Uri.parse('${serverUrlNotifier.value}/api/process-text'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'text': text}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> newCardsData = data['flashcards'];
          final newCards = newCardsData.map((cardData) => Flashcard(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_' + cardData['question'].hashCode.toString(),
            question: cardData['question'] ?? '',
            answer: cardData['answer'] ?? '',
            category: category,
            nextReviewDate: DateTime.now(),
            interval: 1,
          )).toList();
          setState(() => flashcards.addAll(newCards));
          await _saveFlashcards();
        }
      }
    } catch (e) { _showErrorSnackBar('خطأ في الاتصال بالسيرفر: $e'); }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      final category = await _showCategoryDialog(title: 'تصنيف الصورة');
      if (category != null) {
        _processImage(image, category);
      }
    }
  }

  Future<void> _processImage(XFile image, String category) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('${serverUrlNotifier.value}/api/process-image'));
      request.files.add(await http.MultipartFile.fromPath('image', image.path, contentType: MediaType('image', 'jpeg')));
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        if (data['success'] == true) {
          final List<dynamic> newCardsData = data['flashcards'];
          final newCards = newCardsData.map((cardData) => Flashcard(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_' + cardData['question'].hashCode.toString(),
            question: cardData['question'] ?? '',
            answer: cardData['answer'] ?? '',
            category: category,
            nextReviewDate: DateTime.now(),
            interval: 1,
          )).toList();
          setState(() => flashcards.addAll(newCards));
          await _saveFlashcards();
        }
      }
    } catch (e) { _showErrorSnackBar('خطأ في الاتصال بالسيرفر: $e'); }
  }

  void _showThemeMenu() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('اختر المظهر'),
        children: [
          ListTile(title: Text('تلقائي'), onTap: () { themeNotifier.value = ThemeMode.system; Hive.box('settings').put('themeMode', 0); Navigator.pop(context); }),
          ListTile(title: Text('فاتح'), onTap: () { themeNotifier.value = ThemeMode.light; Hive.box('settings').put('themeMode', 1); Navigator.pop(context); }),
          ListTile(title: Text('داكن'), onTap: () { themeNotifier.value = ThemeMode.dark; Hive.box('settings').put('themeMode', 2); Navigator.pop(context); }),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الاستيراد بنجاح')));
      }
    } catch (e) { _showErrorSnackBar('خطأ في الاستيراد: $e'); }
  }

  void _showCategoriesList() {
    final categories = <String, int>{};
    for (var card in flashcards) categories[card.category] = (categories[card.category] ?? 0) + 1;
    final sorted = categories.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: sorted.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(sorted[index].key),
          trailing: IconButton(icon: Icon(Icons.share, color: Colors.blue), onPressed: () {
            Navigator.pop(context);
            _exportCards(flashcards.where((c) => c.category == sorted[index].key).toList(), "category_${sorted[index].key}");
          }),
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

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(title: Text('إضافة بطاقة'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [if (imagePath != null) Image.file(File(imagePath!), height: 100, fit: BoxFit.cover), ElevatedButton.icon(onPressed: () async { final XFile? image = await _picker.pickImage(source: ImageSource.gallery); if (image != null) setDialogState(() => imagePath = image.path); }, icon: Icon(Icons.add_a_photo), label: Text('إضافة صورة')), TextField(controller: qController, decoration: InputDecoration(labelText: 'السؤال')), DropdownButtonFormField<String>(value: type, items: [DropdownMenuItem(value: 'text', child: Text('نص')), DropdownMenuItem(value: 'multipleChoice', child: Text('اختيارات')), DropdownMenuItem(value: 'trueFalse', child: Text('صح/خطأ'))], onChanged: (v) => setDialogState(() => type = v!)), TextField(controller: aController, decoration: InputDecoration(labelText: 'الإجابة'))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')), ElevatedButton(onPressed: () async { final card = Flashcard(id: DateTime.now().millisecondsSinceEpoch.toString(), question: qController.text, answer: aController.text, category: category, nextReviewDate: DateTime.now(), interval: 1, answerType: type, imagePath: imagePath); setState(() => flashcards.add(card)); await _saveFlashcards(); Navigator.pop(context); }, child: Text('إضافة'))])));
  }

  Future<void> _showEditCardDialog(Flashcard card) async {
    TextEditingController qController = TextEditingController(text: card.question);
    String? imagePath = card.imagePath;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(title: Text('تعديل'), content: Column(mainAxisSize: MainAxisSize.min, children: [if (imagePath != null) Image.file(File(imagePath!), height: 80), TextButton.icon(onPressed: () async { final img = await _picker.pickImage(source: ImageSource.gallery); if (img != null) setDialogState(() => imagePath = img.path); }, icon: Icon(Icons.edit), label: Text('تغيير الصورة')), TextField(controller: qController)]), actions: [ElevatedButton(onPressed: () async { final updated = card.copyWith(question: qController.text, imagePath: imagePath); setState(() { int idx = flashcards.indexWhere((c) => c.id == card.id); flashcards[idx] = updated; }); await _saveFlashcards(); Navigator.pop(context); }, child: Text('حفظ'))])));
  }

  void _showFlashcards() { showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) => DraggableScrollableSheet(expand: false, builder: (context, scroll) => ListView.builder(controller: scroll, itemCount: flashcards.length, itemBuilder: (context, i) => ListTile(title: Text(flashcards[i].question))))); }
  
  void _startQuiz() async {
    final now = DateTime.now();
    final due = flashcards.where((c) => c.nextReviewDate.isBefore(now.add(Duration(minutes: 1)))).toList();
    if (due.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا توجد بطاقات للمراجعة'))); return; }
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ReviewScreen(flashcards: due)));
    if (result != null && result is List<Flashcard>) { setState(() { for (var updated in result) { int idx = flashcards.indexWhere((c) => c.id == updated.id); if (idx != -1) flashcards[idx] = updated; } }); await _saveFlashcards(); }
  }

  void _showProcessTextDialog() async {
    final category = await _showCategoryDialog(title: 'تصنيف البطاقات الجديدة');
    if (category == null) return;
    TextEditingController textController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: Text('معالجة نص'), content: TextField(controller: textController, decoration: InputDecoration(labelText: 'الصق النص هنا'), maxLines: 5), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')), ElevatedButton(onPressed: () { _processText(textController.text, category); Navigator.pop(context); }, child: Text('معالجة'))]));
  }
  
  void _showImageSourceDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text('مصدر الصورة'), content: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: Icon(Icons.camera_alt), title: Text('الكاميرا'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }), ListTile(leading: Icon(Icons.photo_library), title: Text('المعرض'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); })])));
  }

  void _showCardDetails(Flashcard card) {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text('تفاصيل'), content: Text('السؤال: ${card.question}\nالإجابة: ${card.answer}\nالتصنيف: ${card.category}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('إغلاق'))]));
  }

  Future<String?> _showCategoryDialog({required String title, String? initialCategory}) async {
    final categories = flashcards.map((card) => card.category).toSet().toList();
    String? selectedCategory = initialCategory;
    final textController = TextEditingController();
    if (initialCategory != null && !categories.contains(initialCategory)) textController.text = initialCategory;

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: textController, decoration: InputDecoration(labelText: 'تصنيف جديد'), onChanged: (v) => setState(() => selectedCategory = null)),
                if (categories.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('أو اختر من الموجود:')),
                  Wrap(spacing: 8, children: categories.map((c) => ChoiceChip(label: Text(c), selected: selectedCategory == c, onSelected: (s) => setState(() { selectedCategory = s ? c : null; textController.clear(); }))).toList()),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(context, textController.text.isNotEmpty ? textController.text : selectedCategory), child: Text('تأكيد')),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String msg) { 
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red)); 
    }
  }
}
