import 'package:flutter_local_notifications/flutter_local_notifications.dart';   // مكتبة الإشعارات المحلية
import 'package:timezone/timezone.dart' as tz;                                  // مكتبة إدارة المناطق الزمنية
import 'package:timezone/data/latest.dart' as tz_data;                          // بيانات أحدث المناطق الزمنية

class NotificationService {
  // الكائن الأساسي لإدارة الإشعارات
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // تهيئة الإشعارات
  static Future<void> init() async {
    tz_data.initializeTimeZones();   // تهيئة قاعدة بيانات المناطق الزمنية

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');   // إعداد أيقونة الإشعار الافتراضية

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);   // تهيئة النظام
  }

  // طلب صلاحيات الإشعارات (مطلوبة في Android 13+)
  static Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();   // طلب الإذن من المستخدم
    }
  }

  // عرض إشعار فوري
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'study_reminders',   // معرف القناة
      'تنبيهات المذاكرة',   // اسم القناة
      channelDescription: 'إشعارات لتذكيرك بمراجعة البطاقات المستحقة',   // وصف القناة
      importance: Importance.max,   // أهمية عالية
      priority: Priority.high,      // أولوية عالية
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      id,     // رقم الإشعار
      title,  // عنوان الإشعار
      body,   // نص الإشعار
      platformChannelSpecifics,   // تفاصيل القناة
    );
  }

  // التحقق من البطاقات المستحقة وإرسال إشعار إذا وجد
  static Future<void> checkAndNotifyDueCards(int dueCount) async {
    if (dueCount > 0) {
      await showNotification(
        id: 1,
        title: 'حان وقت المراجعة! 📚',
        body: 'لديك $dueCount بطاقة مستحقة للمراجعة اليوم. لا تدعها تتراكم!',
      );
    }
  }
}