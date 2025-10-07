// lib/new_code/feature/feature_rules.dart
import 'package:marib/data/model/item/item_model.dart';

class FeatureRules {
  // عدّل القيم الافتراضية حسب مشروعك
  static const Set<int> allowedCategoryIds = {
    3,
    4,
    5
  }; // الأقسام المسموح تمييزها
  static const double minPrice = 1.0; // أقل سعر للسماح بالتمييز
  static const Set<String> allowedStatuses = {'active', 'approved'};

  /// ترجع null لو كل شيء تمام، أو رسالة سبب المنع لو غير مؤهل
  static String? whyNotPromote(
    ItemModel m, {
    bool isAlreadyFeatured = false,
    bool hasActivePlan = false,
    int remainingItemLimit = 0,
    int remainingDays = 0,
  }) {
    // 1) ممنوع لو هو مميز أصلاً
    if (isAlreadyFeatured) return 'الإعلان مميز بالفعل';

    // 2) الحالة
    final status = (m.status ?? '').toLowerCase().trim();
    if (!allowedStatuses.contains(status)) {
      return 'لا يمكن تمييز إعلان حالته: ${m.status ?? 'غير معروفة'}';
    }

    // 3) القسم
    final cid = m.categoryId ?? m.category?.id;
    if (cid == null || !allowedCategoryIds.contains(cid)) {
      return 'هذا القسم غير مدعوم للتمييز';
    }

    // 4) السعر
    final price = m.price ?? 0;
    if (price < minPrice) {
      return 'يلزم أن يكون السعر ≥ $minPrice';
    }

    // 5) الخطة (وجود خطة نشطة وحدّ متبقٍ وأيام متبقية)
    if (!hasActivePlan) return 'لا توجد باقة تمييز نشطة';
    if (remainingItemLimit <= 0)
      return 'انتهى حد الإعلانات المسموح بها في باقتك';
    if (remainingDays <= 0) return 'انتهت صلاحية باقتك';

    return null; // ✅ مؤهل
  }
}
