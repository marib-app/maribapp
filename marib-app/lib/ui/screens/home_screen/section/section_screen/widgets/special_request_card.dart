import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/data/cubits/request_device/request_device_cubit.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/screen_scaler.dart';

class SpecialRequestCard extends StatelessWidget {
  final String sectionSlug;

  const SpecialRequestCard({
    super.key,
    required this.sectionSlug,
  });

  @override
  Widget build(BuildContext context) {
    const double cardRadius = 20.0;
    const double innerPadding = 6.0;
    const double gridGap = 6.0;

    final double cardExtent = ScreenScaler.s(58);
    final double spacing = math.min(ScreenScaler.s(14), gridGap);

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextStyle? textStyle = theme.textTheme.labelMedium?.copyWith(
      color: colors.textDefaultColor,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(cardRadius),
        onTap: () => _openRequestSheet(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: cardExtent,
              width: cardExtent,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cardRadius),
                color: context.color.surface,
                border: Border.all(
                  color: colors.borderColor.withOpacity(0.5),
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.all(innerPadding),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.color.surface,
                  borderRadius: BorderRadius.circular(
                    (cardRadius - innerPadding)
                        .clamp(0.0, cardRadius)
                        .toDouble(),
                  ),
                ),
                child: Icon(
                  Icons.assignment_add,
                  size: cardExtent * 0.5,
                  color: context.color.textLightColor.withOpacity(0.7),
                ),
              ),
            ),
            SizedBox(height: spacing),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: cardExtent + 12,
                  child: Text(
                    'طلب خاص',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRequestSheet(BuildContext outerContext) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController qtyController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController linkController = TextEditingController();
    final bool isSheinSection = sectionSlug.trim().toLowerCase() == 'shein';

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
              String composeSubject() {
                final String qty = qtyController.text.trim();
                final String qtyTag = qty.isEmpty ? "" : " - Qty: $qty";
                return "Special Request: ${titleController.text.trim()}$qtyTag";
              }

              String composeMessage() {
                final String desc = descController.text.trim();
                final String qty = qtyController.text.trim();
                final String notes = notesController.text.trim();
                final String hasImage = pickedFile != null ? "Yes" : "No";
                final String link = linkController.text.trim();
                return [
                  "Title: ${titleController.text.trim().isEmpty ? '-' : titleController.text.trim()}",
                  if (isSheinSection) "Link: ${link.isEmpty ? '-' : link}",
                  "Description: ${desc.isEmpty ? '-' : desc}",
                  "Quantity: ${qty.isEmpty ? 'Not set' : qty}",
                  "Notes: ${notes.isEmpty ? '-' : notes}",
                  "Has image: $hasImage",
                ].join("\n");
              }

              return BlocConsumer<RequestDeviceCubit, RequestDeviceState>(
                listener: (ctx, state) {
                  if (state is RequestDeviceSuccess) {
                    Navigator.pop(outerContext);
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      const SnackBar(
                        content: Text("تم إرسال الطلب بنجاح"),
                      ),
                    );
                  } else if (state is RequestDeviceFailure) {
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      SnackBar(content: Text(state.error)),
                    );
                  }
                },
                builder: (ctx, state) {
                  final bool isSubmitting = state is RequestDeviceInProgress;

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
                          Container(
                            height: 5,
                            width: 60,
                            margin: const EdgeInsets.only(top: 12, bottom: 16),
                            decoration: BoxDecoration(
                              color:
                              context.color.textColorDark.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Form(
                                key: formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "ننفذ طلبك الخاص!",
                                      style: TextStyle(
                                        fontSize: context.font.larger,
                                        fontWeight: FontWeight.bold,
                                        color: context.color.textDefaultColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "اكتب تفاصيل الطلب وأرفق صورة اختيارية. في قسم شي إن يمكنك إضافة رابط المنتج أو السلة لننفذه لك.",
                                      style: TextStyle(
                                        fontSize: context.font.normal,
                                        height: 1.6,
                                        color: context.color.textDefaultColor
                                            .withOpacity(0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _buildField(
                                      controller: titleController,
                                      label: "عنوان الطلب",
                                      icon: Icons.title,
                                      rootContext: context,
                                      validator: (val) =>
                                      val == null || val.isEmpty
                                          ? "مطلوب"
                                          : null,
                                    ),
                                    const SizedBox(height: 14),
                                    if (isSheinSection) ...[
                                      _buildField(
                                        controller: linkController,
                                        label:
                                        "ضع رابط منتج شي إن أو رابط السلة",
                                        icon: Icons.link,
                                        rootContext: context,
                                        validator: (val) =>
                                        val == null || val.trim().isEmpty
                                            ? "الرابط مطلوب"
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    _buildField(
                                      controller: descController,
                                      label: "وصف الطلب",
                                      icon: Icons.description_outlined,
                                      rootContext: context,
                                      maxLines: 3,
                                      validator: (val) =>
                                      val == null || val.isEmpty
                                          ? "مطلوب"
                                          : null,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildField(
                                      controller: qtyController,
                                      label: "الكمية المطلوبة (اختياري)",
                                      icon: Icons.confirmation_number_outlined,
                                      rootContext: context,
                                      keyboardType: TextInputType.number,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildField(
                                      controller: phoneController,
                                      label: "رقم الهاتف للتواصل",
                                      icon: Icons.phone_android,
                                      rootContext: context,
                                      keyboardType: TextInputType.phone,
                                      validator: (val) =>
                                      val == null || val.isEmpty
                                          ? "رقم الهاتف مطلوب"
                                          : null,
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
                                    InkWell(
                                      onTap: isSubmitting
                                          ? null
                                          : () async {
                                        final picker = ImagePicker();
                                        final file =
                                        await picker.pickImage(
                                          source: ImageSource.gallery,
                                        );
                                        if (file != null) {
                                          setState(() {
                                            isUploading = true;
                                            uploadSuccess = false;
                                          });
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
                                            color: context.color.textColorDark
                                                .withOpacity(0.2),
                                          ),
                                          borderRadius:
                                          BorderRadius.circular(12),
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
                                            MainAxisAlignment
                                                .center,
                                            children: const [
                                              Icon(Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 40),
                                              SizedBox(height: 8),
                                              Text("تم رفع الصورة"),
                                            ],
                                          )
                                              : pickedFile == null
                                              ? Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment
                                                .center,
                                            children: [
                                              Icon(
                                                Icons
                                                    .add_a_photo_outlined,
                                                size: 35,
                                                color: context
                                                    .color
                                                    .textDefaultColor
                                                    .withOpacity(
                                                    0.7),
                                              ),
                                              const SizedBox(
                                                  height: 8),
                                              Text(
                                                "أرفق صورة (اختياري)",
                                                style: TextStyle(
                                                  color: context
                                                      .color
                                                      .textDefaultColor
                                                      .withOpacity(
                                                      0.7),
                                                ),
                                              ),
                                            ],
                                          )
                                              : ClipRRect(
                                            borderRadius:
                                            BorderRadius
                                                .circular(12),
                                            child: Image.file(
                                              File(pickedFile!
                                                  .path),
                                              fit: BoxFit.cover,
                                              width:
                                              double.infinity,
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
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                            decoration: BoxDecoration(
                              color: context.color.secondaryColor,
                              border: Border(
                                top: BorderSide(
                                  color: context.color.textColorDark
                                      .withOpacity(0.1),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: context.color.textLightColor,
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: isSubmitting
                                        ? null
                                        : () => Navigator.pop(outerContext),
                                    child: Text(
                                      "إلغاء",
                                      style: TextStyle(
                                        color: context.color.textLightColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      context.color.territoryColor,
                                      foregroundColor:
                                      context.color.secondaryColor,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: isSubmitting
                                        ? null
                                        : () {
                                      if (formKey.currentState
                                          ?.validate() ??
                                          false) {
                                        ctx
                                            .read<RequestDeviceCubit>()
                                            .requestDevice(
                                          phone: phoneController.text
                                              .trim(),
                                          subject: composeSubject(),
                                          message: composeMessage(),
                                          section:
                                          _resolveSectionForRequest(),
                                        );
                                      }
                                    },
                                    icon: isSubmitting
                                        ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.2),
                                    )
                                        : const Icon(Icons.send),
                                    label: Text(
                                      isSubmitting
                                          ? "جارٍ الإرسال..."
                                          : "أرسل الطلب",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
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
    final String normalized = sectionSlug.trim().toLowerCase();
    switch (normalized) {
      case 'shein':
        return 'shein';
      case 'computer':
        return 'computer';
      default:
        return 'computer';
    }
  }
}
