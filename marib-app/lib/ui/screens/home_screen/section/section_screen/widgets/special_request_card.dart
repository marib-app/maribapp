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
    const double gridGap = 6.0;

    final double cardExtent = 52;
    final double spacing = math.min(ScreenScaler.s(14), gridGap);

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextStyle? textStyle = theme.textTheme.labelMedium?.copyWith(
      color: colors.textDefaultColor,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(cardExtent),
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: ClipOval(
                child: Container(
                  color: Colors.transparent,
                  child: Icon(
                    Icons.assignment_add,
                    size: cardExtent * 0.52,
                    color: context.color.textDefaultColor.withOpacity(0.8),
                  ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textStyle?.copyWith(
                      fontSize: context.font.smaller,
                      height: 1.05,
                    ),
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
                      color: outerContext.color.secondaryColor,
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
                              color: outerContext.color.textColorDark
                                  .withOpacity(0.2),
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
                                      "تفاصيل الطلب",
                                      style: TextStyle(
                                        fontSize: outerContext.font.larger,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            outerContext.color.textDefaultColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "املأ التفاصيل وسنعود إليك بأقرب وقت.",
                                      style: TextStyle(
                                        fontSize: outerContext.font.normal,
                                        height: 1.6,
                                        color:
                                            outerContext.color.textLightColor,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: titleController,
                                      decoration: const InputDecoration(
                                        labelText: "عنوان الطلب",
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return "الرجاء إدخال عنوان الطلب";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    if (isSheinSection)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextFormField(
                                            controller: linkController,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  "رابط المنتج (شي إن أو رابط السلة)",
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                      ),
                                    TextFormField(
                                      controller: descController,
                                      decoration: const InputDecoration(
                                        labelText: "وصف الطلب",
                                      ),
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: qtyController,
                                      decoration: const InputDecoration(
                                        labelText: "الكمية (اختياري)",
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: notesController,
                                      decoration: const InputDecoration(
                                        labelText: "ملاحظات إضافية",
                                      ),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: phoneController,
                                      decoration: const InputDecoration(
                                        labelText: "رقم التواصل (اختياري)",
                                      ),
                                      keyboardType: TextInputType.phone,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: isSubmitting
                                              ? null
                                              : () async {
                                                  final picker = ImagePicker();
                                                  final file =
                                                      await picker.pickImage(
                                                          source: ImageSource
                                                              .gallery);
                                                  if (file != null) {
                                                    setState(() {
                                                      pickedFile = file;
                                                    });
                                                  }
                                                },
                                          icon:
                                              const Icon(Icons.image_outlined),
                                          label: Text(
                                            pickedFile == null
                                                ? "أرفق صورة (اختياري)"
                                                : "تم اختيار صورة",
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        if (pickedFile != null)
                                          Text(
                                            File(pickedFile!.path)
                                                .path
                                                .split('/')
                                                .last,
                                            style: TextStyle(
                                              fontSize:
                                                  outerContext.font.smaller,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: isSubmitting
                                            ? null
                                            : () {
                                                if (!formKey.currentState!
                                                    .validate()) {
                                                  return;
                                                }
                                                final subject =
                                                    composeSubject();
                                                final message =
                                                    composeMessage();

                                                outerContext
                                    .read<RequestDeviceCubit>()
                                    .requestDevice(
                                      phone: phoneController.text.trim(),
                                      subject: subject,
                                      message: message,
                                      section: sectionSlug,
                                    );
                                              },
                                        child: isSubmitting
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text("إرسال"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
}
