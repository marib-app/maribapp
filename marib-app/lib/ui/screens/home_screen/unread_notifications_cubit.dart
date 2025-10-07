import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/notification_data.dart';
import 'package:marib/ui/screens/settings/notifications.dart' show ReadNotifStore; // للوصول لمخزن القراءة
import 'package:shared_preferences/shared_preferences.dart';



class UnreadNotificationsCubit extends Cubit<int> {
  final String userId;
  UnreadNotificationsCubit(this.userId) : super(0);

  /// حاسبة معرّف موحّد (تُفضّل id من السيرفر؛ وإلا فـ title+createdAt)
  String _idOf(NotificationData n, {int? index}) {
    final hasId = (n.id?.toString().trim().isNotEmpty ?? false);
    if (hasId) return n.id.toString();
    return '${n.title}-${n.createdAt}-${index ?? 0}';
  }

  /// تحدّث العدد من قائمة الإشعارات الحاليّة (تُستدعى عند تحميل/تحديث الصفحة)
  Future<void> refreshFrom(List<NotificationData> list) async {
    final readSet = await ReadNotifStore.load(userId);
    int unread = 0;
    for (int i = 0; i < list.length; i++) {
      final id = _idOf(list[i], index: i);
      if (!readSet.contains(id)) unread++;
    }
    emit(unread);
  }

  /// تعليم عنصر كمقروء وتخفيض العدّاد محليًا
  Future<void> markAsRead(String id) async {
    final set = await ReadNotifStore.load(userId)..add(id);
    await ReadNotifStore.save(userId, set);
    if (state > 0) emit(state - 1);
  }
}












/// مسؤول عن حفظ/تحميل حالة الإشعارات المقروءة لكل مستخدم
class ReadNotifStore {
  static const String _prefix = 'read_notifications:'; // مفتاح لكل مستخدم

  /// تحميل قائمة المعرّفات المقروءة
  static Future<Set<String>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_prefix$userId') ?? const <String>[];
    return list.toSet();
  }

  /// حفظ القائمة الجديدة
  static Future<void> save(String userId, Set<String> set) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_prefix$userId', set.toList());
  }

  /// إضافة إشعار كمقروء
  static Future<void> add(String userId, String id) async {
    final set = await load(userId)..add(id);
    await save(userId, set);
  }

  /// إزالة إشعار من المقروء
  static Future<void> remove(String userId, String id) async {
    final set = await load(userId)..remove(id);
    await save(userId, set);
  }

  /// مسح جميع المقروءات لمستخدم
  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$userId');
  }
}