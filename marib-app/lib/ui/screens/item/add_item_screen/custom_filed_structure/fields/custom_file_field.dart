// lib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_file_field.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:marib/utils/validator.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';

import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';

/// =====================
/// Logic (Controller)
/// =====================
class CustomFileField extends CustomField {
  @override
  String type = "fileinput";

  String? picked; // المسار الحالي (محلي/رابط)
  bool _busy = false; // حالة انشغال أثناء الاختيار/الضغط

  @override
  void init() {
    // وضع التعديل: حمّل القيمة القديمة إن وُجدت
    if (parameters['isEdit'] == true) {
      final val = parameters['value'];
      if (val is List && val.isNotEmpty) {
        picked = val[0].toString();
        update(() {});
      }
    }
    super.init();
  }

  BuildContext get _rootCtx =>
      Navigator.of(context, rootNavigator: true).context;

  /// فتح منتقي الملفات (يدعم ضغط الصور الكبيرة)
  Future<File?> _pickFileInternal() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      // أضفت webp لأن المعاينة تتعرف عليه
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'svg', 'pdf'],
    );
    if (result == null) return null;

    final PlatformFile pf = result.files.first;
    final File selected = File(pf.path!);

    // SVG/PDF نرجعه كما هو
    if (_isSvg(selected) || _isPdf(selected)) return selected;

    // صور قابلة للضغط
    if (_isCompressibleImage(selected)) {
      final size = await selected.length();
      if (size > Constant.maxSizeInBytes) {
        final compressed = await HelperUtils.compressImageFile(selected);
        return compressed;
      }
    }
    return selected;
  }

  bool _isSvg(File f) => f.path.toLowerCase().endsWith('.svg');
  bool _isPdf(File f) => f.path.toLowerCase().endsWith('.pdf');
  bool _isCompressibleImage(File f) {
    final ext = f.path.split('.').last.toLowerCase();
    return ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp';
  }

  /// منطق الاختيار/الربط (مفصول عن الواجهة)
  Future<void> _pickAndAttach(void Function(MultipartFile?) didChange) async {
    _busy = true;
    update(() {});
    try {
      final t0 = DateTime.now().millisecondsSinceEpoch;

      final file = await _pickFileInternal();
      if (file == null) {
        HelperUtils.showSnackBarMessage(context, "لم يتم اختيار أي ملف");
        return;
      }

      picked = file.path;

      final mf = await MultipartFile.fromFile(file.path);
      didChange(mf); // مرر القيمة للفالديتور/الفورم
      AbstractField.files["custom_field_files[${parameters['id']}]"] = mf;

      final took = ((DateTime.now().millisecondsSinceEpoch - t0) / 1000)
          .toStringAsFixed(1);
      HelperUtils.showSnackBarMessage(context, "تم اختيار الملف (${took}ث)");
    } catch (_) {
      HelperUtils.showSnackBarMessage(context, "حدث خطأ أثناء اختيار الملف");
    } finally {
      _busy = false;
      update(() {});
    }
  }

  /// اختيار/استبدال ملف (مع نافذة تأكيد موحدة)
  Future<void> _onPick(void Function(MultipartFile?) didChange) async {
    // إذا فيه ملف محدد مسبقًا → افتح نافذة تأكيد بنفس نمط المشروع
    if (picked?.isNotEmpty == true) {
      UiUtils.showBlurredDialoge(
        context,
        dialoge: BlurredDialogBox(
          title: "تأكيد الاستبدال",
          content: const Text(
            "سيتم استبدال الملف الحالي بالملف الجديد.",
            textAlign: TextAlign.center,
          ),
          acceptButtonName: "استبدال",
          cancelButtonName: "إلغاء",
          cancelTextColor: context.color.textColorDark,
          onAccept: () async {
            await _pickAndAttach(didChange); // نفّذ الاستبدال فعليًا
          },
          onCancel: () {
            HelperUtils.showSnackBarMessage(context, "تم إلغاء الاستبدال");
          },
        ),
      );
      return;
    }

    // أول اختيار بدون تأكيد
    await _pickAndAttach(didChange);
  }

  /// حذف الملف الحالي
  void _onClear(void Function(MultipartFile?) didChange) {
    didChange(null);
    AbstractField.files.remove("custom_field_files[${parameters['id']}]");
    picked = null;
    update(() {});
    HelperUtils.showSnackBarMessage(context, "تم حذف الملف");
  }

  /// معاينة صورة بكامل الشاشة (موحّدة ومريحة)
  void _showImageViewer(
    BuildContext ctx,
    String localOrRemotePath, {
    String? fileName,
    String? sizeText,
  }) {
    showGeneralDialog(
      context: ctx,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      barrierLabel: "image_viewer",
      pageBuilder: (_, __, ___) {
        return SafeArea(
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                // الصورة
                Positioned.fill(
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: localOrRemotePath.startsWith('http')
                          ? Image.network(localOrRemotePath,
                              fit: BoxFit.contain)
                          : Image.file(File(localOrRemotePath),
                              fit: BoxFit.contain),
                    ),
                  ),
                ),

                // شريط علوي: رجوع + العنوان
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsetsDirectional.only(
                        start: 8, end: 8, top: 8, bottom: 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          tooltip: "رجوع",
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName ?? "معاينة الصورة",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // شريط سفلي: اسم الملف + الحجم (اختياري)
                if ((fileName?.isNotEmpty ?? false) ||
                    (sizeText?.isNotEmpty ?? false))
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              [
                                if (fileName?.isNotEmpty ?? false) fileName!,
                                if (sizeText?.isNotEmpty ?? false)
                                  " • $sizeText",
                              ].join(""),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget render() {
    final String title = parameters['name'] ?? '';
    final String? notes = (parameters['notes']?.toString().isNotEmpty ?? false)
        ? parameters['notes'].toString()
        : null;
    final dynamic image = parameters['image'];
    final bool requiredField = parameters['required'] == 1;

    return CustomValidator<MultipartFile?>(
      validator: (value) {
        if (requiredField && value == null && picked == null) {
          return "pleaseSelectFile".translate(context);
        }
        return null;
      },
      builder: (state) {
        return CustomFileFieldView(
          // هيدر
          title: title,
          notes: notes,
          image: image,

          // حالة
          hasError: state.hasError,
          errorText: state.errorText,
          pickedPath: picked,
          busy: _busy,

          // أحداث
          onPick: () => _onPick(state.didChange),
          onClear: () => _onClear(state.didChange),

          // معاينة كاملة
          onOpenImage: (p, name, size) =>
              _showImageViewer(_rootCtx, p, fileName: name, sizeText: size),
        );
      },
    );
  }
}

/// =====================
/// UI (Presentation Only)
/// =====================
class CustomFileFieldView extends StatefulWidget {
  const CustomFileFieldView({
    super.key,
    required this.title,
    required this.hasError,
    required this.pickedPath,
    required this.onPick,
    required this.onClear,
    required this.busy,
    required this.onOpenImage,
    this.notes,
    this.image,
    this.errorText,
  });

  final String title;
  final String? notes;
  final dynamic image;

  final bool hasError;
  final String? errorText;

  final String? pickedPath;
  final bool busy;

  final VoidCallback onPick;
  final VoidCallback onClear;

  /// فتح المعاينة الكاملة (يمرّرها المنطق لتوحيد سلوك العرض)
  final void Function(String path, String? fileName, String? sizeText)
      onOpenImage;

  @override
  State<CustomFileFieldView> createState() => _CustomFileFieldViewState();
}

class _CustomFileFieldViewState extends State<CustomFileFieldView> {
  bool _hover = false; // تفاعل حدود على Desktop

  // تحويل bytes → MB كنص
  String _bytesToMbString(int bytes) =>
      (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final picked = widget.pickedPath;
    final fileName = picked?.split("/").last ?? "";
    final borderBase = widget.hasError
        ? context.color.error
        : context.color.textLightColor.darken(50);
    final borderColor = _hover ? context.color.territoryColor : borderBase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: widget.title,
          notes: widget.notes,
          image: widget.image,
          hasError: widget.hasError,
        ),
        SizedBox(height: 14.rh(context)),

        // زر إضافة ملف (Ripple + حالة انشغال)
        MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.busy ? null : widget.onPick,
              child: DottedBorder(
                borderType: BorderType.RRect,
                radius: const Radius.circular(10),
                color: borderColor,
                strokeCap: StrokeCap.round,
                padding: const EdgeInsets.all(5),
                dashPattern: const [3, 3],
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: Center(
                    child: widget.busy
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.color.territoryColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text("جاري التحضير…")
                                  .size(context.font.large)
                                  .color(
                                    context.color.textDefaultColor
                                        .withOpacity(.6),
                                  ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.upload_file),
                              const SizedBox(width: 6),
                              Text("addFile".translate(context))
                                  .size(context.font.large)
                                  .color(
                                    context.color.textDefaultColor
                                        .withOpacity(.6),
                                  ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // معاينة ب AnimatedSwitcher
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: picked == null
              ? const SizedBox.shrink(key: ValueKey('noFile'))
              : _PickedPreview(
                  key: const ValueKey('hasFile'),
                  path: picked,
                  openImage: (p, sizeText) =>
                      widget.onOpenImage(p, fileName, sizeText),
                  onOpenPdf: (p) => Navigator.pushNamed(
                    context,
                    Routes.pdfViewerScreen,
                    arguments: p,
                  ),
                  onClear: widget.onClear,
                ),
        ),

        const SizedBox(height: 8),

        // تلميح أنواع/حجم مسموح
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 6, end: 4),
          child: Text(
            "${'allowedFileTypes'.translate(context)}: PNG, JPG, JPEG, SVG, PDF — "
            "${_bytesToMbString(Constant.maxSizeInBytes)} MB",
          ).size(context.font.smaller).color(context.color.textLightColor),
        ),

        if (widget.hasError && (widget.errorText?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 6),
          Text(widget.errorText!)
              .size(context.font.small)
              .color(context.color.error),
        ],
      ],
    );
  }
}

/// هيدر بسيط (أيقونة اختيارية + عنوان + ملاحظات)
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.hasError,
    this.notes,
    this.image,
  });

  final String title;
  final String? notes;
  final dynamic image;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (image != null) ...[
          Container(
            width: 48.rw(context),
            height: 48.rh(context),
            decoration: BoxDecoration(
              color: context.color.territoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.none,
                child: UiUtils.imageType(
                  image,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  color: context.color.textDefaultColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.rw(context)),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
                softWrap: true,
              ).size(context.font.large).bold(weight: FontWeight.w500).color(
                    hasError
                        ? context.color.error
                        : context.color.textColorDark,
                  ),
              if (notes != null && notes!.isNotEmpty) ...[
                SizedBox(height: 5.rh(context)),
                Text(notes!)
                    .size(context.font.small)
                    .color(context.color.textLightColor),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// معاينة الملف: صورة مصغّرة/أيقونة + اسم + حجم (للمحلي) + حذف
class _PickedPreview extends StatelessWidget {
  const _PickedPreview({
    super.key,
    required this.path,
    required this.onClear,
    required this.openImage,
    required this.onOpenPdf,
  });

  final String path;
  final VoidCallback onClear;

  /// فتح معاينة صورة (يمرّره المنطق ليوحّد العرض)
  final void Function(String path, String? sizeText) openImage;

  /// فتح PDF
  final void Function(String path) onOpenPdf;

  bool get _isRemote => path.startsWith('http');
  bool get _isImage =>
      path.toLowerCase().endsWith('.png') ||
      path.toLowerCase().endsWith('.jpg') ||
      path.toLowerCase().endsWith('.jpeg') ||
      path.toLowerCase().endsWith('.webp');
  bool get _isPdf => path.toLowerCase().endsWith('.pdf');

  String? _sizeText() {
    if (_isRemote) return null;
    try {
      final bytes = File(path).lengthSync();
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
      return "$mb MB";
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = path.split('/').last;
    final sizeText = _sizeText();

    Widget leading;
    if (_isImage) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _isRemote
            ? Image.network(path, width: 40, height: 40, fit: BoxFit.cover)
            : Image.file(File(path), width: 40, height: 40, fit: BoxFit.cover),
      );
    } else {
      leading = Icon(
        Icons.insert_drive_file,
        color: context.color.territoryColor,
        size: 35,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          // اضغط للمعاينة (صورة/ PDF)
          GestureDetector(
            onTap: () {
              if (_isImage) {
                openImage(path, sizeText);
              } else if (_isPdf) {
                onOpenPdf(path);
              }
            },
            child: leading,
          ),
          const SizedBox(width: 8),

          // الاسم + الحجم مع Tooltip
          Expanded(
            child: Tooltip(
              message: fileName,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName)
                      .setMaxLines(lines: 1)
                      .bold(weight: FontWeight.w500),
                  if (sizeText != null)
                    Text(sizeText).size(context.font.smaller),
                ],
              ),
            ),
          ),

          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
            tooltip: "حذف",
          ),
        ],
      ),
    );
  }
}
