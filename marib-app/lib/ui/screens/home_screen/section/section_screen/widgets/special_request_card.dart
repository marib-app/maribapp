// lib/ui/screens/home/section/Items_List/widgets/special_request_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/screen_scaler.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';


import 'package:marib/data/cubits/request_device/request_device_cubit.dart';





// مكوّن البطاقة كما هو (نفس القياسات، الألوان، والخطوط)
class SpecialRequestCard extends StatelessWidget {
  final String sectionSlug;

  const SpecialRequestCard({
    super.key,
    required this.sectionSlug,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = ScreenScaler.s(58);
    final fontSize = ScreenScaler.s(10);
    final spacing = ScreenScaler.s(14);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBackground = isDark ? Colors.grey.shade900 : Colors.grey[200];
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openRequestSheet(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              height: iconSize,
              width: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBackground,
              ),
              child: Icon(Icons.shopping_bag_outlined,
                  size: iconSize * 0.6, color: textColor),
            ),
            SizedBox(height: spacing),
            Text(
              'طلب خاص',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fontSize, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  // نفس فتح النافذة السفلية، مع ربط Cubit وإدارة الحالات دون تغيير الستايل
  void _openRequestSheet(BuildContext outerContext) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final qtyController = TextEditingController();
    final notesController = TextEditingController();
    final phoneController = TextEditingController();

    XFile? pickedFile;
    bool isUploading = false;
    bool uploadSuccess = false;

    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: StatefulBuilder(
            builder: (context, setState) {
              // تكوين العنوان والرسالة المرسلة للسيرفر
              String composeSubject() {
                final qty = qtyController.text.trim();
                final qtyTag = qty.isEmpty ? "" : " - كمية: $qty";
                return "طلب خاص: ${titleController.text.trim()}$qtyTag";
              }

              String composeMessage() {
                final desc = descController.text.trim();
                final qty = qtyController.text.trim();
                final notes = notesController.text.trim();
                final hasImage = pickedFile != null ? "نعم" : "لا";
                return [
                  "العنوان: ${titleController.text.trim().isEmpty ? '-' : titleController.text.trim()}",
                  "الوصف: ${desc.isEmpty ? '-' : desc}",
                  "الكمية: ${qty.isEmpty ? 'غير محدد' : qty}",
                  "ملاحظات: ${notes.isEmpty ? '-' : notes}",
                  "صورة مرفقة: $hasImage",
                ].join("\n");
              }

              // نلفّ المحتوى بـ BlocConsumer لإغلاق النافذة عند النجاح وإظهار الرسائل
              return BlocConsumer<RequestDeviceCubit, RequestDeviceState>(
                listener: (ctx, state) {
                  if (state is RequestDeviceSuccess) {
                    Navigator.pop(outerContext); // اغلاق الشيت بعد نجاح الإرسال
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      const SnackBar(content: Text("✅ تم إرسال الطلب بنجاح")),
                    );
                  } else if (state is RequestDeviceFailure) {
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      SnackBar(content: Text(state.error)),
                    );
                  }
                },
                builder: (ctx, state) {
                  final isSubmitting = state is RequestDeviceInProgress;

                  return Container(
                    decoration: BoxDecoration(
                      color: context.color.secondaryColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          // مقبض السحب (نفس الستايل)
                          Container(
                            height: 5,
                            width: 60,
                            margin: const EdgeInsets.only(top: 12, bottom: 16),
                            decoration: BoxDecoration(
                              color: context.color.textColorDark.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),

                          // النموذج (نفس الترتيب والألوان)
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Form(
                                key: formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "👋 أهلاً بك!",
                                      style: TextStyle(
                                        fontSize: context.font.larger,
                                        fontWeight: FontWeight.bold,
                                        color: context.color.textDefaultColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "يمكنك عبر هذه الخدمة إرسال طلب خاص لأي منتج أو مواصفات تناسب احتياجك، وسنساعدك في توفيره.",
                                      style: TextStyle(
                                        fontSize: context.font.normal,
                                        height: 1.6,
                                        color: context.color.textDefaultColor.withOpacity(0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    _buildField(
                                      controller: titleController,
                                      label: "عنوان الطلب",
                                      icon: Icons.title,
                                      rootContext: context,
                                      validator: (val) =>
                                      val == null || val.isEmpty ? "مطلوب" : null,
                                    ),
                                    const SizedBox(height: 14),

                                    _buildField(
                                      controller: descController,
                                      label: "الوصف",
                                      icon: Icons.description_outlined,
                                      rootContext: context,
                                      maxLines: 3,
                                      validator: (val) =>
                                      val == null || val.isEmpty ? "مطلوب" : null,
                                    ),
                                    const SizedBox(height: 14),

                                    _buildField(
                                      controller: qtyController,
                                      label: "الكمية المطلوبة",
                                      icon: Icons.confirmation_number_outlined,
                                      rootContext: context,
                                      keyboardType: TextInputType.number,
                                    ),
                                    const SizedBox(height: 14),

                                    _buildField(
                                      controller: phoneController,
                                      label: "رقم للتواصل",
                                      icon: Icons.phone_android,
                                      rootContext: context,
                                      keyboardType: TextInputType.phone,
                                      validator: (val) =>
                                      val == null || val.isEmpty ? "أدخل رقمك" : null,
                                    ),
                                    const SizedBox(height: 14),

                                    _buildField(
                                      controller: notesController,
                                      label: "ملاحظات إضافية (اختياري)",
                                      icon: Icons.notes_outlined,
                                      rootContext: context,
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 16),

                                    // رفع صورة + نفس الانيميشن/الألوان
                                    InkWell(
                                      onTap: isSubmitting
                                          ? null
                                          : () async {
                                        final picker = ImagePicker();
                                        final file = await picker.pickImage(
                                          source: ImageSource.gallery,
                                        );
                                        if (file != null) {
                                          setState(() {
                                            isUploading = true;
                                            uploadSuccess = false;
                                          });
                                          // محاكاة رفع الصورة (2 ثواني) - للواجهة فقط
                                          await Future.delayed(
                                              const Duration(seconds: 2));
                                          setState(() {
                                            pickedFile = file;
                                            isUploading = false;
                                            uploadSuccess = true;
                                          });
                                        }
                                      },
                                      child: Container(
                                        height: 150,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: context.color.textColorDark.withOpacity(0.2),
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          color: context.color.secondaryColor,
                                        ),
                                        child: Center(
                                          child: isUploading
                                              ? Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: const [
                                              CircularProgressIndicator(),
                                              SizedBox(height: 10),
                                              Text("جاري رفع الصورة..."),
                                            ],
                                          )
                                              : uploadSuccess
                                              ? Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: const [
                                              Icon(Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 40),
                                              SizedBox(height: 8),
                                              Text("تم رفع الصورة بنجاح"),
                                            ],
                                          )
                                              : pickedFile == null
                                              ? Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment
                                                .center,
                                            children: [
                                              Icon(
                                                Icons.add_a_photo_outlined,
                                                size: 35,
                                                color: context
                                                    .color
                                                    .textDefaultColor
                                                    .withOpacity(0.7),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "اضغط لإضافة صورة",
                                                style: TextStyle(
                                                  color: context
                                                      .color
                                                      .textDefaultColor
                                                      .withOpacity(0.7),
                                                ),
                                              ),
                                            ],
                                          )
                                              : ClipRRect(
                                            borderRadius:
                                            BorderRadius.circular(12),
                                            child: Image.file(
                                              File(pickedFile!.path),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 90),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // الأزرار (نفس الستايل) + تعطيل أثناء الإرسال فقط
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                            decoration: BoxDecoration(
                              color: context.color.secondaryColor,
                              border: Border(
                                top: BorderSide(
                                  color: context.color.textColorDark.withOpacity(0.1),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: context.color.territoryColor,
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: isSubmitting ? null : () => Navigator.pop(outerContext),
                                    child: Text(
                                      "إلغاء",
                                      style: TextStyle(
                                        color: context.color.territoryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: context.color.territoryColor,
                                      foregroundColor: context.color.secondaryColor,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    // هنا الاستدعاء الحقيقي للسيرفر عبر Cubit
                                    onPressed: isSubmitting
                                        ? null
                                        : () {
                                      if (formKey.currentState?.validate() ?? false) {
                                        ctx.read<RequestDeviceCubit>().requestDevice(
                                          phone: phoneController.text.trim(),
                                          subject: composeSubject(),
                                          message: composeMessage(),
                                          section: _resolveSectionForRequest(),
                                        );
                                      }
                                    },
                                    icon: isSubmitting
                                        ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2.2),
                                    )
                                        : const Icon(Icons.send),
                                    label: Text(
                                      isSubmitting ? "جاري الإرسال..." : "إرسال الطلب",
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // دالة بناء الحقول (نفسها 1:1 — تحترم ألوان/خطوط theme عبر context.color و context.font)
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required BuildContext rootContext,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: rootContext.color.territoryColor),
        filled: true,
        fillColor: rootContext.color.secondaryColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: rootContext.color.textColorDark.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: rootContext.color.territoryColor,
            width: 1.6,
          ),
        ),
      ),
      style: TextStyle(color: rootContext.color.textDefaultColor),
    );
  }

  String _resolveSectionForRequest() {
    switch (sectionSlug) {
      case 'shein':
        return 'shein';
      case 'computer':
        return 'computer';
      default:
        return 'computer';
    }
  }

}
