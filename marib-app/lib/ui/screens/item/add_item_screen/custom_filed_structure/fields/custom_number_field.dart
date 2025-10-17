import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';

import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/utils/validator.dart';

/// =====================
/// Logic (Controller)
/// =====================
class CustomNumberField extends CustomField {
  @override
  String type = "number";

  // قيم منطق الحقل
  String _initialValue = "";
  String _title = "";
  String? _notes;
  dynamic _image;
  int? _maxLen;
  int? _minLen;
  bool _required = false;
  dynamic _id;

  @override
  void init() {
    // التهيئة من parameters
    _title = (parameters['name'] ?? '').toString();
    _notes = (parameters['notes']?.toString().isNotEmpty ?? false)
        ? parameters['notes'].toString()
        : null;
    _image = parameters['image'];
    _maxLen = parameters['max_length'];
    _minLen = parameters['min_length'];
    _required = parameters['required'] == 1 || parameters['required'] == true;
    _id = parameters['id'];

    // وضع التعديل
    if (parameters['isEdit'] == true &&
        parameters['value'] != null &&
        (parameters['value'] as List).isNotEmpty) {
      _initialValue = parameters['value'][0].toString();
      update?.call(() {});
    }
    super.init();
  }

  @override
  Widget render() {

    Map<String, dynamic> params;
    try {
      params = Map<String, dynamic>.from(parameters);
    } catch (_) {
      params = <String, dynamic>{};
    }

    String effectiveTitle = _title;
    final dynamic rawName = params['name'] ?? params['title'];
    if (rawName is String && rawName.trim().isNotEmpty) {
      effectiveTitle = rawName.trim();
    }

    String? effectiveNotes = _notes;
    final dynamic rawNotes = params['notes'];
    if (rawNotes is String && rawNotes.trim().isNotEmpty) {
      effectiveNotes = rawNotes.trim();
    }

    dynamic effectiveImage = _image;
    if (params.containsKey('image')) {
      effectiveImage = params['image'];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: CustomNumberFieldView(
        title: effectiveTitle,
        notes: effectiveNotes,
        image: effectiveImage,
        value: _initialValue,
        maxLen: _maxLen,
        minLen: _minLen,
        requiredField: _required,
        id: _id,
      ),
    );
  }
}

/// =====================
/// UI (Presentation)
/// =====================
class CustomNumberFieldView extends StatelessWidget {
  const CustomNumberFieldView({
    super.key,
    required this.title,
    required this.value,
    required this.requiredField,
    required this.id,
    this.notes,
    this.image,
    this.maxLen,
    this.minLen,
  });

  final String title;
  final String value;
  final bool requiredField;
  final dynamic id;

  final String? notes;
  final dynamic image;
  final int? maxLen;
  final int? minLen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(
          title: title,
          notes: notes,
          image: image,
        ),
        SizedBox(height: 14.rh(context)),

        // حقل الإدخال الرقمي
        CustomTextFieldDynamic(
          initController: value.isNotEmpty,
          value: value,
          validator: CustomTextFieldValidator.minAndMixLen,
          maxLen: maxLen,
          minLen: minLen,
          hintText: "", // يمكن تمرير hint من الـ parameters إن وجد
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],

          action: TextInputAction.next,
          keyboardType: TextInputType.number,
          required: requiredField,
          id: id,
        ),
      ],
    );
  }
}




/// هيدر موحّد (أيقونة + عنوان + ملاحظات)
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    this.notes,
    this.image,
  });

  final String title;
  final String? notes;
  final dynamic image;

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
            child: SizedBox(
              height: 24,
              width: 24,
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title)
                .size(context.font.large)
                .bold(weight: FontWeight.w500)
                .color(context.color.textColorDark),
            if (notes != null && notes!.isNotEmpty) ...[
              SizedBox(height: 5.rh(context)),
              Text(notes!)
                  .size(context.font.small)
                  .color(context.color.textLightColor),
            ],
          ],
        ),
      ],
    );
  }
}
