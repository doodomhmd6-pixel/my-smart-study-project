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
  List<Flashcard> filteredFlashcards = [];
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
    _searchController.addListener(_filterFlashcards);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterFlashcards);
    _searchController.dispose();
    super.dispose();
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
    setState(() {
      flashcards = tempLoadedCards;
      filteredFlashcards = List.from(flashcards);
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
        title: Text('حذف البطاقة'),
        content: Text('هل أنت متأكد من رغبتك في حذف هذه البطاقة نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() {
        flashcards.removeWhere((c) => c.id == id);
        filteredFlashcards.removeWhere((c) => c.id == id); // Remove from filtered list too
      });
      await _saveFlashcards();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف البطاقة')));
    }
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
                if (newUrl.startsWith('http://') && newUrl.contains('onrender.com')) {
                   newUrl = newUrl.replaceFirst('http://', 'https://');
                }
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

  void _filterFlashcards() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredFlashcards = flashcards.where((card) {
        return card.question.toLowerCase().contains(query) ||
               card.answer.toLowerCase().contains(query) ||
               card.category.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use filteredFlashcards for display
    final displayCards = filteredFlashcards;

    return Scaffold(
      appBar: AppBar(
        title: Text('ذاكرتي الذكية'),
        actions: [
          IconButton(icon: Icon(Icons.bar_chart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StatisticsScreen(flashcards: flashcards)))), // Pass all flashcards for stats
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
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن بطاقة...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                _buildActionButton(icon: Icons.style, label: 'البطاقات', color: Colors.blue, onTap: () { /* Navigate to AllFlashcardsScreen */ Navigator.push(context, MaterialPageRoute(builder: (context) => AllFlashcardsScreen(allFlashcards: flashcards))); }),
                _buildActionButton(icon: Icons.category, label: 'التصنيفات', color: Colors.cyan, onTap: _showCategoriesList),
                _buildActionButton(icon: Icons.quiz, label: 'اختبار', color: Colors.orange, onTap: _startQuiz),
                _buildActionButton(icon: Icons.text_fields, label: 'نص', color: Colors.teal, onTap: _showProcessTextDialog),
                _buildActionButton(icon: Icons.camera_alt, label: 'صورة', color: Colors.purple, onTap: _showImageSourceDialog),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: displayCards.isEmpty
                  ? Center(child: Text('لا توجد بطاقات مطابقة للبحث'))
                  : ListView.builder(
                      itemCount: displayCards.length,
                      itemBuilder: (context, index) {
                        final card = displayCards[index]; // Use displayCards
                        return Card(
                          child: ListTile(
                            leading: card.imagePath != null ? Icon(Icons.image, color: Colors.purple) : Icon(Icons.note),
                            title: Column( // Use Column to stack question and answer
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(card.question, maxLines: 1, overflow: TextOverflow.ellipsis),
                                SizedBox(height: 4), // Space between question and answer
                                Text(
                                  'الإجابة: ${card.answer}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            // Displaying Category
                            subtitle: Text('التصنيف: ${card.category}', style: TextStyle(fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () => _showEditCardDialog(card)),
                                IconButton(icon: Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _deleteCard(card.id)),
                                // Share Button for individual card
                                IconButton(icon: Icon(Icons.share, size: 20, color: Colors.grey), onPressed: () => _shareCard(card)),
                              ],
                            ),
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

      if (response.statusCode == 307 || response.statusCode == 308 || response.statusCode == 301) {
        String? location = response.headers['location'];
        if (location != null) {
          uri = uri.resolve(location);
          response = await http.post(
            uri,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'text': text, 'card_type': cardType}),
          );
        }
      }

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
            answerType: cardData['answerType'] ?? cardType, // Use server-provided type or fallback
            options: (cardData['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
            correctOptionIndex: cardData['correctOptionIndex'] as int?,
          )).toList();
          setState(() {
            flashcards.addAll(newCards);
            filteredFlashcards.addAll(newCards); // Add to filtered list as well
            _filterFlashcards(); // Re-apply filter in case search text is present
          });
          await _saveFlashcards();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إنشاء ${newCards.length} بطاقة بنجاح!'), backgroundColor: Colors.green));
        } else {
          _showErrorSnackBar('فشل في معالجة النص: ${data['error'] ?? 'سبب غير معروف'}');
        }
      } else {
        String serverError = 'رمز الحالة: ${response.statusCode}';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData['error'] != null) {
            serverError = errorData['error'];
          }
        } catch (_) {}
        _showErrorSnackBar('خطأ من الخادم: $serverError');
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
      builder: (context) => AlertDialog(
        title: Text('جاري المعالجة...'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('يرجى الانتظار'),
          ],
        ),
      ),
    );
  }

  Future<void> _processImage(XFile image, String category, String cardType) async {
    _showLoadingIndicator(); 
    http.Client? client;
    try {
      client = http.Client();
      Uri uri = Uri.parse('${serverUrlNotifier.value}/api/process-image');
      
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', image.path, contentType: MediaType('image', 'jpeg')));
      request.fields['card_type'] = cardType; // Add card_type to multipart request fields
      
      var streamedResponse = await client.send(request);
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 307 || response.statusCode == 308 || response.statusCode == 301) {
        String? location = response.headers['location'];
        if (location != null) {
          uri = uri.resolve(location);
          var retryRequest = http.MultipartRequest('POST', uri);
          retryRequest.files.add(await http.MultipartFile.fromPath('image', image.path, contentType: MediaType('image', 'jpeg')));
          retryRequest.fields['card_type'] = cardType;
          streamedResponse = await client.send(retryRequest);
          response = await http.Response.fromStream(streamedResponse);
        }
      }

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
            answerType: cardData['answerType'] ?? cardType, // Use server-provided type or fallback
            options: (cardData['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
            correctOptionIndex: cardData['correctOptionIndex'] as int?,
          )).toList();
          setState(() {
            flashcards.addAll(newCards);
            filteredFlashcards.addAll(newCards); // Add to filtered list as well
            _filterFlashcards(); // Re-apply filter
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إنشاء ${newCards.length} بطاقة بنجاح!'), backgroundColor: Colors.green));
        } else {
          _showErrorSnackBar('فشل في معالجة الصورة: ${data['error'] ?? 'سبب غير معروف'}');
        }
      } else {
        String serverError = 'رمز الحالة: ${response.statusCode}';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData['error'] != null) {
            serverError = errorData['error'];
          }
        } catch (_) {}
        _showErrorSnackBar('خطأ من الخادم: $serverError');
      }
    } catch (e) {
      if (e.toString().contains('Software caused connection abort')) {
        _showErrorSnackBar('تم قطع الاتصال من الخادم. يرجى التأكد من استخدام https:// في عنوان السيرفر.');
      } else {
        _showErrorSnackBar('خطأ في الاتصال بالسيرفر: $e');
      }
    } finally {
      if (mounted) Navigator.of(context).pop(); 
      client?.close();
    }
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
            if (!flashcards.any((c) => c.id == nc.id)) {
              flashcards.add(nc);
              filteredFlashcards.add(nc); // Add to filtered list too
            }
          }
        });
        await _saveFlashcards();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الاستيراد بنجاح')));
      }
    } catch (e) { _showErrorSnackBar('خطأ في الاستيراد: $e'); }
  }

  void _showCategoriesList() {
    final categories = <String, int>{};
    for (var card in flashcards) {
      categories.update(card.category, (count) => count + 1, ifAbsent: () => 1);
    }
    final sorted = categories.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: sorted.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(sorted[index].key),
          trailing: Text('(${sorted[index].value})'), // Display count here
          onTap: () {
            Navigator.pop(context);
            // Optionally navigate to a filtered list of cards for this category
            // Or just close the bottom sheet
          },
        ),
      ),
    );
  }

  // New helper to show a dialog for card type selection
  Future<String?> _showCardTypeSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('اختر نوع البطاقة التي سيتم توليدها'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('بطاقة نصية (سؤال وإجابة)'),
              onTap: () => Navigator.pop(context, 'text'),
            ),
            ListTile(
              title: Text('اختيار من متعدد'),
              onTap: () => Navigator.pop(context, 'multipleChoice'),
            ),
            ListTile(
              title: Text('صح أو خطأ'),
              onTap: () => Navigator.pop(context, 'trueFalse'),
            ),
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
    String type = 'text';
    String? imagePath;
    List<TextEditingController> optionControllers = [];
    int? correctOptionIndex;

    // Initialize with some empty options for multipleChoice
    if (type == 'multipleChoice') {
      for (int i = 0; i < 4; i++) { // Default to 4 options
        optionControllers.add(TextEditingController());
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('إضافة بطاقة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imagePath != null) Image.file(File(imagePath!), height: 100, fit: BoxFit.cover),
                ElevatedButton.icon(
                  onPressed: () async {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) setDialogState(() => imagePath = image.path);
                  },
                  icon: Icon(Icons.add_a_photo),
                  label: Text('إضافة صورة'),
                ),
                TextField(controller: qController, decoration: InputDecoration(labelText: 'السؤال')),
                DropdownButtonFormField<String>(
                  value: type,
                  items: [
                    DropdownMenuItem(value: 'text', child: Text('نص')),
                    DropdownMenuItem(value: 'multipleChoice', child: Text('اختيارات')),
                    DropdownMenuItem(value: 'trueFalse', child: Text('صح/خطأ'))
                  ],
                  onChanged: (v) {
                    setDialogState(() {
                      type = v!;
                      // Reset options/correct index when type changes
                      optionControllers.clear();
                      correctOptionIndex = null;
                      if (type == 'multipleChoice') {
                        for (int i = 0; i < 4; i++) { // Default to 4 options
                          optionControllers.add(TextEditingController());
                        }
                      } else if (type == 'trueFalse') {
                        // For true/false, options are fixed and managed by the UI below
                        // correctOptionIndex will be set by radio buttons
                      }
                    });
                  },
                ),
                if (type == 'text') // Only show answer field for text type
                  TextField(controller: aController, decoration: InputDecoration(labelText: 'الإجابة'))
                else if (type == 'multipleChoice') // Options for multiple choice
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 10),
                      Text('الخيارات:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...List.generate(optionControllers.length, (index) => TextField(
                        controller: optionControllers[index],
                        decoration: InputDecoration(
                          labelText: 'خيار ${index + 1}',
                          suffixIcon: IconButton(
                            icon: Icon(Icons.check_circle_outline, color: correctOptionIndex == index ? Colors.green : Colors.grey),
                            onPressed: () => setDialogState(() => correctOptionIndex = index),
                          ),
                        ),
                      )),
                    ],
                  )
                else if (type == 'trueFalse') // Options for true/false
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 10),
                      Text('الإجابة الصحيحة:', style: TextStyle(fontWeight: FontWeight.bold)),
                      RadioListTile<int>(
                        title: Text('صح'),
                        value: 0,
                        groupValue: correctOptionIndex,
                        onChanged: (v) => setDialogState(() => correctOptionIndex = v),
                      ),
                      RadioListTile<int>(
                        title: Text('خطأ'),
                        value: 1,
                        groupValue: correctOptionIndex,
                        onChanged: (v) => setDialogState(() => correctOptionIndex = v),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                List<String>? finalOptions;
                if (type == 'multipleChoice') {
                  finalOptions = optionControllers.map((c) => c.text).where((text) => text.isNotEmpty).toList();
                  if (finalOptions.length < 2 && type == 'multipleChoice') {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الرجاء إدخال خيارين على الأقل لبطاقة الاختيارات'), backgroundColor: Colors.red));
                     return;
                  }
                  if (correctOptionIndex == null && type == 'multipleChoice') {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الرجاء تحديد الإجابة الصحيحة لبطاقة الاختيارات'), backgroundColor: Colors.red));
                     return;
                  }

                } else if (type == 'trueFalse') {
                  finalOptions = ['صح', 'خطأ']; // Hardcoded options
                   if (correctOptionIndex == null && type == 'trueFalse') {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الرجاء تحديد الإجابة الصحيحة لبطاقة صح/خطأ'), backgroundColor: Colors.red));
                     return;
                  }
                }

                final card = Flashcard(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  question: qController.text,
                  answer: aController.text.isNotEmpty ? aController.text : (type == 'text' ? 'إجابة فارغة' : ''), // Only for text type, otherwise it's handled by options/correctOptionIndex
                  category: category,
                  nextReviewDate: DateTime.now(),
                  interval: 1,
                  answerType: type,
                  imagePath: imagePath,
                  options: finalOptions ?? [], // Corrected: provide empty list if finalOptions is null
                  correctOptionIndex: correctOptionIndex,
                );

                setState(() {
                  flashcards.add(card);
                  filteredFlashcards.add(card);
                  _filterFlashcards();
                });
                await _saveFlashcards();
                Navigator.pop(context);
              },
              child: Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditCardDialog(Flashcard card) async {
    TextEditingController qController = TextEditingController(text: card.question);
    TextEditingController aController = TextEditingController(text: card.answer); // For text type
    String? imagePath = card.imagePath;
    String type = card.answerType; // Current type
    List<TextEditingController> optionControllers = [];
    int? correctOptionIndex = card.correctOptionIndex;

    if (type == 'multipleChoice' && card.options != null) {
      for (var option in card.options!) {
        optionControllers.add(TextEditingController(text: option));
      }
      // Ensure at least 4 controllers if less than 4 options were saved
      while (optionControllers.length < 4) {
        optionControllers.add(TextEditingController());
      }
    } else if (type == 'trueFalse') {
      // Options are fixed, no controllers needed
    }

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text('تعديل البطاقة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null) Image.file(File(imagePath!), height: 80),
            TextButton.icon(
              onPressed: () async {
                final img = await _picker.pickImage(source: ImageSource.gallery);
                if (img != null) setDialogState(() => imagePath = img.path);
              },
              icon: Icon(Icons.edit),
              label: Text('تغيير الصورة'),
            ),
            TextField(controller: qController, decoration: InputDecoration(labelText: 'السؤال')),
            DropdownButtonFormField<String>(
              value: type,
              items: [
                DropdownMenuItem(value: 'text', child: Text('نص')),
                DropdownMenuItem(value: 'multipleChoice', child: Text('اختيارات')),
                DropdownMenuItem(value: 'trueFalse', child: Text('صح/خطأ'))
              ],
              onChanged: (v) {
                setDialogState(() {
                  type = v!;
                  optionControllers.clear();
                  correctOptionIndex = null; // Reset when type changes
                  if (type == 'multipleChoice') {
                    for (int i = 0; i < 4; i++) {
                      optionControllers.add(TextEditingController());
                    }
                  }
                });
              },
            ),
            if (type == 'text')
              TextField(controller: aController, decoration: InputDecoration(labelText: 'الإجابة'))
            else if (type == 'multipleChoice')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10),
                  Text('الخيارات:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...List.generate(optionControllers.length, (index) => TextField(
                    controller: optionControllers[index],
                    decoration: InputDecoration(
                      labelText: 'خيار ${index + 1}',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.check_circle_outline, color: correctOptionIndex == index ? Colors.green : Colors.grey),
                        onPressed: () => setDialogState(() => correctOptionIndex = index),
                      ),
                    ),
                  )),
                ],
              )
            else if (type == 'trueFalse')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10),
                  Text('الإجابة الصحيحة:', style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile<int>(
                    title: Text('صح'),
                    value: 0,
                    groupValue: correctOptionIndex,
                    onChanged: (v) => setDialogState(() => correctOptionIndex = v),
                  ),
                  RadioListTile<int>(
                    title: Text('خطأ'),
                    value: 1,
                    groupValue: correctOptionIndex,
                    onChanged: (v) => setDialogState(() => correctOptionIndex = v),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
        ElevatedButton(onPressed: () async {
          List<String>? finalOptions;
          if (type == 'multipleChoice') {
            finalOptions = optionControllers.map((c) => c.text).where((text) => text.isNotEmpty).toList();
            if (finalOptions.length < 2 && type == 'multipleChoice') {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الرجاء إدخال خيارين على الأقل لبطاقة الاختيارات'), backgroundColor: Colors.red));
               return;
            }
            if (correctOptionIndex == null && type == 'multipleChoice') {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الرجاء تحديد الإجابة الصحيحة لبطاقة الاختيارات'), backgroundColor: Colors.red));
               return;
            }
          } else if (type == 'trueFalse') {
            finalOptions = ['صح', 'خطأ'];
            if (correctOptionIndex == null && type == 'trueFalse') {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الرجاء تحديد الإجابة الصحيحة لبطاقة صح/خطأ'), backgroundColor: Colors.red));
               return;
            }
          }

          final updated = card.copyWith(
            question: qController.text,
            answer: aController.text,
            answerType: type,
            imagePath: imagePath,
            options: finalOptions ?? [], // Corrected: provide empty list if finalOptions is null
            correctOptionIndex: correctOptionIndex,
          );
          setState(() {
            int idx = flashcards.indexWhere((c) => c.id == card.id);
            if (idx != -1) flashcards[idx] = updated;
            idx = filteredFlashcards.indexWhere((c) => c.id == card.id); // Update in filtered list too
            if (idx != -1) filteredFlashcards[idx] = updated;
            _filterFlashcards(); // Re-apply filter
          });
          await _saveFlashcards();
          Navigator.pop(context);
        }, child: Text('حفظ'))
      ],
    )));
  }

  void _showFlashcards() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AllFlashcardsScreen(allFlashcards: flashcards)));
  }

  void _startQuiz() async {
    final categories = flashcards.map((c) => c.category).toSet().toList();
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا توجد بطاقات للمراجعة')));
      return;
    }

    String? selectedCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('اختر التصنيف للاختبار'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text('كل التصنيفات'), onTap: () => Navigator.pop(context, 'ALL')),
              Divider(),
              ...categories.map((cat) => ListTile(
                title: Text(cat),
                onTap: () => Navigator.pop(context, cat),
              )).toList(),
            ],
          ),
        ),
      ),
    );

    if (selectedCategory == null) return;

    final now = DateTime.now();
    List<Flashcard> due = flashcards.where((c) => c.nextReviewDate.isBefore(now.add(Duration(minutes: 1)))).toList();

    if (selectedCategory != 'ALL') {
      due = due.where((c) => c.category == selectedCategory).toList();
    }

    if (due.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا توجد بطاقات مراجعة حالية لهذا التصنيف')));
      return;
    }

    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ReviewScreen(flashcards: due)));
    if (result != null && result is List<Flashcard>) {
      setState(() {
        for (var updated in result) {
          int idx = flashcards.indexWhere((c) => c.id == updated.id);
          if (idx != -1) flashcards[idx] = updated;
          idx = filteredFlashcards.indexWhere((c) => c.id == updated.id); // Update in filtered list too
          if (idx != -1) filteredFlashcards[idx] = updated;
        }
        _filterFlashcards(); // Re-apply filter to ensure state is correct
      });
      await _saveFlashcards();
    }
  }

  void _showProcessTextDialog() async {
    final category = await _showCategoryDialog(title: 'تصنيف البطاقات الجديدة');
    if (category == null) return;

    final cardType = await _showCardTypeSelectionDialog();
    if (cardType == null) return; // User cancelled type selection

    TextEditingController textController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: Text('معالجة نص'), content: TextField(controller: textController, decoration: InputDecoration(labelText: 'الصق النص هنا'), maxLines: 5), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')), ElevatedButton(onPressed: () { _processText(textController.text, category, cardType); Navigator.pop(context); }, child: Text('معالجة'))]));
  }
  
  void _showImageSourceDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text('مصدر الصورة'), content: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: Icon(Icons.camera_alt), title: Text('الكاميرا'), onTap: () async { 
      Navigator.pop(context); 
      final category = await _showCategoryDialog(title: 'تصنيف الصورة');
      if (category == null) return;
      final cardType = await _showCardTypeSelectionDialog();
      if (cardType == null) return;
      _pickImage(ImageSource.camera, category, cardType); 
    }), ListTile(leading: Icon(Icons.photo_library), title: Text('المعرض'), onTap: () async {
      Navigator.pop(context); 
      final category = await _showCategoryDialog(title: 'تصنيف الصورة');
      if (category == null) return;
      final cardType = await _showCardTypeSelectionDialog();
      if (cardType == null) return;
      _pickImage(ImageSource.gallery, category, cardType); 
    })])));
  }

  void _showCardDetails(Flashcard card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل البطاقة'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('السؤال: ${card.question}', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              if (card.imagePath != null)
                Image.file(File(card.imagePath!), height: 150, width: double.infinity, fit: BoxFit.cover),
              SizedBox(height: 8),
              Text('الإجابة: ${card.answer}'),
              SizedBox(height: 8),
              Text('التصنيف: ${card.category}'),
              SizedBox(height: 8),
              Text('نوع الإجابة: ${card.answerType}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إغلاق')),
        ],
      ),
    );
  }

  Future<String?> _showCategoryDialog({required String title, String? initialCategory}) async {
    final categories = <String>{};
    for (var card in flashcards) {
      categories.add(card.category);
    }
    
    String? selectedCategory = initialCategory;
    final textController = TextEditingController();
    
    if (initialCategory != null && !categories.contains(initialCategory)) {
      textController.text = initialCategory;
      selectedCategory = null;
    } else if (initialCategory != null) {
      selectedCategory = initialCategory;
    }

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  decoration: InputDecoration(labelText: 'اسم التصنيف الجديد'),
                  onChanged: (v) {
                    setState(() {
                      selectedCategory = null;
                    });
                  },
                ),
                if (categories.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('أو اختر من التصنيفات الموجودة:')),
                  Wrap(spacing: 8.0, runSpacing: 4.0, children: categories.map((c) => ChoiceChip(
                    label: Text(c),
                    selected: selectedCategory == c,
                    onSelected: (s) {
                      setState(() {
                        selectedCategory = s ? c : null;
                        textController.clear();
                      });
                    },
                  )).toList()),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                String? finalCategory;
                if (textController.text.isNotEmpty) {
                  finalCategory = textController.text;
                } else if (selectedCategory != null) {
                  finalCategory = selectedCategory;
                }
                Navigator.pop(context, finalCategory);
              },
              child: Text('تأكيد'),
            ),
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

  // New function to share a single card
  Future<void> _shareCard(Flashcard card) async {
    try {
      final textToShare = "السؤال: ${card.question}\n\nالإجابة: ${card.answer}\n\nالتصنيف: ${card.category}";
      await Share.share(textToShare, subject: 'بطاقة تعليمية');
    } catch (e) {
      _showErrorSnackBar('خطأ أثناء مشاركة البطاقة: $e');
    }
  }
}

// --- AllFlashcardsScreen ---
class AllFlashcardsScreen extends StatefulWidget {
  final List<Flashcard> allFlashcards;
  const AllFlashcardsScreen({Key? key, required this.allFlashcards}) : super(key: key);

  @override
  _AllFlashcardsScreenState createState() => _AllFlashcardsScreenState();
}

class _AllFlashcardsScreenState extends State<AllFlashcardsScreen> {
  List<Flashcard> _filteredCards = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredCards = List.from(widget.allFlashcards);
    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredCards = widget.allFlashcards.where((card) => 
          card.question.toLowerCase().contains(query) ||
          card.answer.toLowerCase().contains(query) ||
          card.category.toLowerCase().contains(query)
        ).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('كل البطاقات (${_filteredCards.length})'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight), 
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن بطاقة...', 
                prefixIcon: Icon(Icons.search), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
      ),
      body: _filteredCards.isEmpty
          ? Center(child: Text('لا توجد بطاقات مطابقة للبحث'))
          : ListView.builder(
              itemCount: _filteredCards.length,
              itemBuilder: (context, index) {
                final card = _filteredCards[index];
                return Card(
                  child: ListTile(
                    leading: card.imagePath != null ? Icon(Icons.image, color: Colors.purple) : Icon(Icons.note),
                    title: Column( // Use Column to stack question and answer
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.question, maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: 4), // Space between question and answer
                        Text(
                          'الإجابة: ${card.answer}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    subtitle: Text('التصنيف: ${card.category}', style: TextStyle(fontSize: 12)), // Display Category
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () {
                          // TODO: Implement edit functionality for AllFlashcardsScreen
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Edit not fully implemented on this screen yet')));
                        }),
                        IconButton(icon: Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () {
                           // TODO: Implement delete functionality for AllFlashcardsScreen
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete not fully implemented on this screen yet')));
                        }),
                        // Add share button here as well
                         IconButton(icon: Icon(Icons.share, size: 20, color: Colors.grey), onPressed: () => _shareCardFromAllCardsScreen(card)),
                      ],
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CardDetailScreen(card: card))),
                  ),
                );
              },
            ),
    );
  }
  // Helper to share card from AllFlashcardsScreen
  Future<void> _shareCardFromAllCardsScreen(Flashcard card) async {
     try {
      final textToShare = "السؤال: ${card.question}\n\nالإجابة: ${card.answer}\n\nالتصنيف: ${card.category}";
      await Share.share(textToShare, subject: 'بطاقة تعليمية');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء مشاركة البطاقة: $e'), backgroundColor: Colors.red));
    }
  }
}

// --- CardDetailScreen ---
class CardDetailScreen extends StatelessWidget {
  final Flashcard card;
  const CardDetailScreen({Key? key, required this.card}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل البطاقة: ${card.category}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center( 
          child: Column( 
            mainAxisAlignment: MainAxisAlignment.center, 
            crossAxisAlignment: CrossAxisAlignment.center, 
            children: [
              if (card.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.file(
                    File(card.imagePath!),
                    height: 200, 
                    width: double.infinity, 
                    fit: BoxFit.cover,
                  ),
                ),
              SizedBox(height: 20),
              Text(
                'السؤال: ${card.question}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center, 
              ),
              SizedBox(height: 15),
              Text(
                'الإجابة: ${card.answer}',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 15),
              Text('التصنيف: ${card.category}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              SizedBox(height: 10), 
              Text('نوع الإجابة: ${card.answerType}', style: TextStyle(fontSize: 14, color: Colors.grey[600]))
            ]
          )
        ),
      )
    );
  }
}
