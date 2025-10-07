import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

// CategoryPcCard هو ويدجيت لعرض بطاقة تصنيف بشكل دائري تحتوي على صورة (من رابط URL) وعنوان نصي.
// يتم عرض الصورة داخل دائرة مع ظل خفيف، والعنوان يظهر أسفل الصورة.
// عند الضغط على البطاقة يتم استدعاء دالة onTap المحددة.
// يُستخدم هذا الويدجيت عادةً في واجهات تعرض تصنيفات بشكل شبكي أو أفقي.




class CategoryPcCard extends StatelessWidget {
  /// عنوان التصنيف الذي سيُعرض أسفل الصورة.
  final String title;

  /// رابط الصورة التي سيتم عرضها داخل الدائرة.
  final String url;

  /// دالة تُستدعى عند الضغط على البطاقة.
  final VoidCallback onTap;

  /// المُنشئ الأساسي الذي يأخذ العنوان، الرابط، ودالة الضغط.
  const CategoryPcCard({
    super.key,
    required this.title,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // يستمع لنقرات المستخدم على كامل البطاقة وينفذ onTap عند الضغط.
      onTap: onTap,

      child: Column(
        mainAxisSize: MainAxisSize.min, // يجبر العمود على الحجم الأدنى اللازم لمحتوياته فقط.
        children: [
          Container(
            width: 60, // عرض الدائرة 60 بكسل
            height: 60, // ارتفاع الدائرة 60 بكسل
            decoration: BoxDecoration(
              color: Colors.white, // خلفية بيضاء للدائرة
              shape: BoxShape.circle, // شكل الحاوية دائري
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15), // ظل خفيف رمادي شفاف قليلاً
                  blurRadius: 6, // مقدار تمويه الظل ليبدو ناعماً
                  offset: const Offset(0, 2), // إزاحة الظل قليلاً للأسفل
                ),
              ],
            ),

            // ClipOval يضمن أن الصورة ستكون داخل دائرة تمامًا
            child: ClipOval(
              child: UiUtils.imageType(
                url, // تحميل الصورة من الرابط
                fit: BoxFit.cover, // تغطية المساحة بالكامل مع قص الأجزاء الزائدة
              ),
            ),
          ),

          const SizedBox(height: 8), // مسافة رأسية بين الصورة والنص

          Text(
            title, // عرض عنوان التصنيف
            textAlign: TextAlign.center, // توسيط النص
            maxLines: 2, // الحد الأقصى لعدد أسطر النص
            overflow: TextOverflow.ellipsis, // قطع النص مع ثلاث نقاط إذا طالت المساحة
            style: TextStyle(
              fontSize: 11.5, // حجم الخط صغير قليلاً
              fontWeight: FontWeight.w500, // وزن الخط متوسط
              color: context.color.textDefaultColor, // لون النص مأخوذ من الثيم عبر امتداد context
            ),
          ),
        ],
      ),
    );
  }
}
