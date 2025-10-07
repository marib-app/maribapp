// lib/ui/screens/item/add_item_screen/more_details_ui.dart
//
// واجهة العرض فقط (UI-Only) لشاشة AddMoreDetailsScreen.
// - لا يوجد منطق جلب/تنقّل هنا.
// - تحسين UX: AnimatedSwitcher انتقالات ناعمة، ListView كسول، زر سفلي ثابت.
// - إضافة بطاقة ملاحظة أعلى الحقول توجّه المُعلن لأهمية تعبئة التفاصيل.
//
// ملاحظة: نتوقّع أن CustomFieldBuilder جُهّز في شاشة المنطق بـ stateUpdater(setState).

import 'package:flutter/material.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';

import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart'
    show CustomFieldBuilder; // ✅ تعريف النوع

class MoreDetailsUI extends StatelessWidget {
  const MoreDetailsUI({
    super.key,
    required this.formKey,
    required this.scrollController,
    required this.state,
    required this.fields,
    required this.onNextPressed,
    this.onRetry,
  });

  final GlobalKey<FormState> formKey;
  final ScrollController scrollController;
  final FetchCustomFieldState state;
  final List<CustomFieldBuilder> fields;
  final VoidCallback onNextPressed;
  final VoidCallback? onRetry; // اختياري لإعادة المحاولة عند الخطأ

  bool get _isLoading => state is FetchCustomFieldInProgress;
  bool get _isFail => state is FetchCustomFieldFail;



  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        // ✅ يثبّت الزر أسفل الشاشة حتى مع ظهور الكيبورد
        resizeToAvoidBottomInset: false,

        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "AdDetails".translate(context),
        ),

        // ✅ بدون أي padding مرتبط بالكيبورد
        bottomNavigationBar: _bottomBar(
          context,
          isDisabled: _isLoading || (fields.isEmpty && !_isLoading && !_isFail),
        ),

        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _buildBody(context),
        ),
      ),
    );
  }





  // زر الأسفل
  Widget _bottomBar(BuildContext context, {required bool isDisabled}) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: UiUtils.buildButton(
        context,
        // ✅ نمرّر دائمًا دالة غير فارغة لتفادي خطأ النوع
        onPressed: () {
          if (!isDisabled) onNextPressed();
        },
        height: 48.rh(context),
        fontSize: context.font.large,
        buttonTitle: "next".translate(context),
      ),
    );
  }

  // جسم الشاشة حسب الحالة
  Widget _buildBody(BuildContext context) {
    if (_isFail) {
      final err = (state as FetchCustomFieldFail).error;
      return _errorView(context, err);
    }

    if (_isLoading && fields.isEmpty) {
      return _loadingView(context);
    }

    // Success أو تحميل مع وجود حقول
    return _formView(context);
  }

  // شاشة خطأ بسيطة + زر إعادة المحاولة (اختياري)
  Widget _errorView(BuildContext context, Object err) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: context.color.error),
            const SizedBox(height: 12),
            Text(
              err.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.font.normal,
                color: onSurface.withOpacity(0.75), // ✅ بديل textLight
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              UiUtils.buildButton(
                context,
                onPressed: () {
                  // ✅ دالة غير فارغة
                  if (onRetry != null) onRetry!();
                },
                buttonTitle: "retry".translate(context),
                height: 44.rh(context),
                fontSize: context.font.normal,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // شاشة تحميل
  Widget _loadingView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UiUtils.progress(),
            const SizedBox(height: 12),
            Text(
              "يرجى الانتظار ..".translate(context),
              style: TextStyle(fontSize: context.font.normal),
            ),
          ],
        ),
      ),
    );
  }




// نموذج الحقول (بطاقة ملاحظة + تمرير تلقائي + صور وأيقونات كبيرة داخل بطاقة الحقل)
  Widget _formView(BuildContext context) {
    final border = BorderSide(
      color: context.color.borderColor.withOpacity(0.4),
      width: 1,
    );

    // padding سفلي بارتفاع الكيبورد حتى لا تُحجب الحقول السفلى
    final double kb = MediaQuery.of(context).viewInsets.bottom;

    // ثيم خاص للفورم: تكبير مساحة الأيقونة بجانب العنوان داخل

    final theme = Theme.of(context).copyWith(
      // أيقونات عامة (لا تغيّر الصور)
      iconTheme: const IconThemeData(size: 26),
      // أهم شيء: تكبير مساحة prefix/suffix داخل حقول الإدخال
      inputDecorationTheme: const InputDecorationTheme(
        isDense: false,
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        prefixIconConstraints: BoxConstraints(minWidth: 56, minHeight: 56),
        suffixIconConstraints: BoxConstraints(minWidth: 56, minHeight: 56),
      ),
      // لو بعض الحقول تستعمل ListTile كعنوان مع أيقونة "leading"
      listTileTheme: const ListTileThemeData(
        minLeadingWidth: 56,
        horizontalTitleGap: 12,
        // minVerticalPadding: 10, // فعّلها لو تبغى ارتفاعاً أكبر لبطاقة العنوان
      ),
      // كثافة أقل لإعطاء مساحة عمودية مريحة
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );



    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      child: Theme(
        data: theme,
        child: Form(
          key: formKey,
          child: Column(
            children: [
              // عنوان
              Padding(
                padding: const EdgeInsets.only(top: 18.0, bottom: 8.0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    "giveMoreDetailsAboutYourAds".translate(context),
                    style: TextStyle(
                      fontSize: context.font.large,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // بطاقة الملاحظة
              _adviceCard(context, border),

              Divider(
                height: 16,
                thickness: 0.6,
                color: context.color.borderColor.withOpacity(0.5),
              ),

              // قائمة الحقول: بناء كسول + تمرير تلقائي عند التركيز
              Expanded(
                child: NotificationListener<OverscrollIndicatorNotification>(
                  onNotification: (o) {
                    o.disallowIndicator();
                    return false;
                  },
                  child: ListView.separated(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.only(top: 8.0, bottom: 12.0 + kb),
                    itemCount: fields.length + (_isLoading ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12.0),
                    itemBuilder: (context, index) {
                      // مؤشر تحميل في نهاية القائمة عند الحاجة
                      if (_isLoading && index == fields.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(child: UiUtils.progress()),
                        );
                      }

                      final field = fields[index];

                      // عزل تحديث كل حقل محليًا + تمرير تلقائي فوق الكيبورد
                      return StatefulBuilder(
                        builder: (ctx, setItemState) {
                          field.stateUpdater(setItemState);

                          return Focus(
                            onFocusChange: (hasFocus) {
                              if (hasFocus) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!ctx.mounted) return;
                                  Scrollable.ensureVisible(
                                    ctx,
                                    alignment: 0.2,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                  );
                                });
                              }
                            },
                            // ملاحظة: لا نستخدم IconTheme حول الحقل حتى لا تؤثر على الصور،
                            // التكبير يتم عبر قيود الثيم أعلاه (prefix/suffix/ListTile).
                            child: RepaintBoundary(child: field.build(ctx)),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }



// بطاقة الملاحظة: رمادي باهت + أيقونة بلون الهوية
  Widget _adviceCard(BuildContext context, BorderSide border) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(border),
        // رمادي باهت يعتمد على الثيم
        color: cs.surfaceVariant.withOpacity(0.20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // أيقونة التنبيه: دائرة رمادية باهتة + لون الهوية للأيقونة
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceVariant.withOpacity(0.50),
            ),
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsetsDirectional.only(end: 14, top: 2),
            child: Icon(
              Icons.info_rounded,
              size: 20,
              color: context.color.territoryColor, // ✅ لون الهوية
            ),
          ),

          // النص المختصر
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "قد تكون بعض الحقول هنا اختيارية، لكن تعبئتها بدقّة تحسّن ظهور إعلانك وتزيد فرصة نجاحه .",
                  style: TextStyle(
                    fontSize: context.font.small,
                    height: 1.45,
                    color: cs.onSurface.withOpacity(0.78), // رمادي نص باهت
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
