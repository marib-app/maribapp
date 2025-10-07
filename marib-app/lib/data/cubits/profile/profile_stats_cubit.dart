import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/api.dart';

// States
abstract class ProfileStatsState {}

class ProfileStatsInitial extends ProfileStatsState {}

class ProfileStatsLoading extends ProfileStatsState {}

class ProfileStatsSuccess extends ProfileStatsState {
  final int totalAds;
  final int activAds;
  final int totalFavorites;
  final int totalChats;

  ProfileStatsSuccess({
    required this.totalAds,
    required this.activAds,
    required this.totalFavorites,
    required this.totalChats,
  });
}

class ProfileStatsError extends ProfileStatsState {
  final String message;

  ProfileStatsError(this.message);
}

// Cubit
class ProfileStatsCubit extends Cubit<ProfileStatsState> {
  ProfileStatsCubit() : super(ProfileStatsInitial());

  Future<void> fetchProfileStats() async {
    try {
      print("📊 بدء جلب إحصائيات الملف الشخصي...");
      emit(ProfileStatsLoading());

      final response = await Api.get(
        url: Api.userProfileStatsApi,
      );

      print("📥 استجابة إحصائيات الملف الشخصي:");
      print("   - نجح: ${response['success']}");
      print("   - البيانات: ${response['data']}");

      // التحقق من وجود البيانات بغض النظر عن حقل success
      if (response['data'] != null && response['data'] is Map) {
        final data = response['data'];

        print("✅ تم جلب الإحصائيات بنجاح:");
        print("   - إجمالي الإعلانات: ${data['total_ads'] ?? 0}");
        print("   - الإعلانات النشطة: ${data['active_ads'] ?? 0}");
        print("   - إجمالي المفضلة: ${data['total_favorites'] ?? 0}");
        print("   - إجمالي المحادثات: ${data['total_chats'] ?? 0}");

        emit(ProfileStatsSuccess(
          totalAds: data['total_ads'] ?? 0,
          activAds: data['active_ads'] ?? 0,
          totalFavorites: data['total_favorites'] ?? 0,
          totalChats: data['total_chats'] ?? 0,
        ));
      } else if (response['success'] == true) {
        // الحالة الأصلية للتوافق مع استجابات أخرى
        final data = response['data'];

        print("✅ تم جلب الإحصائيات بنجاح (الطريقة الأصلية):");
        print("   - إجمالي الإعلانات: ${data['total_ads'] ?? 0}");
        print("   - الإعلانات النشطة: ${data['active_ads'] ?? 0}");
        print("   - إجمالي المفضلة: ${data['total_favorites'] ?? 0}");
        print("   - إجمالي المحادثات: ${data['total_chats'] ?? 0}");

        emit(ProfileStatsSuccess(
          totalAds: data['total_ads'] ?? 0,
          activAds: data['active_ads'] ?? 0,
          totalFavorites: data['total_favorites'] ?? 0,
          totalChats: data['total_chats'] ?? 0,
        ));
      } else {
        print("❌ فشل في جلب الإحصائيات: ${response['message']}");
        emit(ProfileStatsError(response['message'] ?? 'خطأ في جلب الإحصائيات'));
      }
    } catch (e) {
      print("💥 خطأ في جلب إحصائيات الملف الشخصي: $e");
      emit(ProfileStatsError('خطأ في الاتصال بالخادم'));
    }
  }
}
