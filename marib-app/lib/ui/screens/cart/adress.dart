import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/data/repositories/cart/addresses_repository.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/api.dart';
import 'dart:async';
import 'dart:collection';

// منطقي فقط
import 'adress_ui.dart';

import 'package:marib/ui/theme/theme.dart';

import 'components/address_location_picker.dart';








class AdressScreen extends StatefulWidget {
  const AdressScreen({super.key});



  static Route<int?> route(RouteSettings routeSettings) {
    return BlurredRouter<int?>(builder: (_) => const AdressScreen());
  }

  @override
  State<AdressScreen> createState() => _AdressScreenState();

}

class _AdressScreenState extends State<AdressScreen> {
  // حالة العرض والبيانات
  bool _loading = true;





  bool _mutating = false;

  final AddressesRepository _addressesRepository = AddressesRepository();

  List<Map<String, dynamic>> _addresses = <Map<String, dynamic>>[];
  int? _selectedAddressId;
  int? _defaultAddressId;




  // مثال: ربط أولي
  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  // TODO: اربط بمصدر بياناتك الحقيقي (API/DB). لا تضع بيانات وهمية هنا.
  Future<void> _loadAddresses() async {
    setState(() => _loading = true);
    try {
      final List<Map<String, dynamic>> addresses =
      await _addressesRepository.fetchAddresses();
      if (!mounted) return;
      _applyAddresses(addresses, forceDefaultSelection: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(context, error.toString());
    } on ApiHttpException catch (error) {
      if (!mounted) return;
      final dynamic message =
      error.payload is Map<String, dynamic> ? error.payload['message'] : null;
      HelperUtils.showSnackBarMessage(
        context,
        message?.toString() ?? 'تعذر تحميل العناوين.',
      );
    } catch (_) {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(
        context,
        'تعذر تحميل العناوين.',
      );

    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // الأحداث القادمة من الواجهة

  Future<void> _onAddNew() async {
    if (_mutating) return;

    final Map<String, dynamic>? result = await _showAddressForm();
    if (result == null) return;


    final Set<int> previousIds = _knownAddressIds;
    await _performMutation(() async {
      final List<Map<String, dynamic>> addresses =
      await _addressesRepository.createAddress(result);
      final Set<int> nextIds = addresses
          .map(_addressId)
          .whereType<int>()
          .toSet();
      final int? createdId =
      nextIds.difference(previousIds).isNotEmpty
          ? nextIds.difference(previousIds).first
          : null;
      _applyAddresses(addresses, preferSelectedId: createdId);
    }, successMessage: 'تم حفظ العنوان بنجاح.');

  }

  void _onSelect(int index) {
    if (_mutating) return;
    if (index < 0 || index >= _addresses.length) {
      return;
    }
    final int? id = _addressId(_addresses[index]);
    setState(() => _selectedAddressId = id);

    _popWithSelection();


  }

  Future<void> _onEdit(int index) async {

    if (_mutating) return;
    if (index < 0 || index >= _addresses.length) {
      return;
    }
    final Map<String, dynamic> current = _addresses[index];

    final Map<String, dynamic>? result = await _showAddressForm(initial: current);
    if (result == null) return;

    final int? id = _addressId(current);
    if (id == null) {
      return;
    }

    await _performMutation(() async {
      final List<Map<String, dynamic>> addresses =
      await _addressesRepository.updateAddress(id, result);
      _applyAddresses(addresses, preferSelectedId: id);

  },
        successMessage: 'تم تحديث العنوان بنجاح.');


  }

  void _onDelete(int index) {
    if (_mutating) return;
    if (index < 0 || index >= _addresses.length) {
      return;
    }
    final int? id = _addressId(_addresses[index]);
    if (id == null) {
      return;
    }

    unawaited(_performMutation(() async {
      final List<Map<String, dynamic>> addresses =
      await _addressesRepository.deleteAddress(id);
      _applyAddresses(addresses);
    }, successMessage: 'تم حذف العنوان بنجاح.'));

  }

  void _onSetDefault(int index) {
    if (_mutating) return;
    if (index < 0 || index >= _addresses.length) {
      return;
    }
    final int? id = _addressId(_addresses[index]);
    if (id == null) {
      return;
    }

    unawaited(_performMutation(() async {
      final List<Map<String, dynamic>> addresses =
      await _addressesRepository.markDefault(id);
      _applyAddresses(addresses, forceDefaultSelection: true);
    }, successMessage: 'تم تعيين العنوان الافتراضي.'));

  }

  Future<void> _onAddLocation(int index) async {
    if (_mutating) return;
    if (index < 0 || index >= _addresses.length) {
      return;
    }
    final Map<String, dynamic> base = _addresses[index];
    final Map<String, dynamic>? result = await _pickLocation(base);
    if (result == null) return;

    final int? id = _addressId(base);
    if (id == null) {
      return;
    }

    await _performMutation(() async {
      final List<Map<String, dynamic>> addresses =
      await _addressesRepository.updateAddress(id, result);
      _applyAddresses(addresses, preferSelectedId: id);
    }, successMessage: 'تم تحديث موقع العنوان بنجاح.');

  }

  Future<Map<String, dynamic>?> _showAddressForm({Map<String, dynamic>? initial}) async {
    final TextEditingController nameController =
    TextEditingController(text: (initial?['name'] ?? '').toString());
    final TextEditingController phoneController =
    TextEditingController(text: (initial?['phone'] ?? '').toString());
    final TextEditingController labelController = TextEditingController(
      text: (initial?['address'] ?? initial?['label'] ?? '').toString(),
    );


    final TextEditingController areaController = TextEditingController(
      text: (initial?['area'] ?? initial?['city'] ?? '').toString(),
    );
    final TextEditingController noteController = TextEditingController(
      text: (initial?['note'] ?? initial?['description'] ?? '').toString(),
    );






    Map<String, dynamic>? location = _normalizeLocationData(initial);

    String? locationError;

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool saving = false;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 46,
                            height: 4,
                            decoration: BoxDecoration(
                              color: context.color.borderColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          initial == null ? 'إضافة عنوان جديد' : 'تعديل العنوان',
                          style: TextStyle(
                            fontSize: context.font.larger,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          context,
                          controller: nameController,
                          label: 'اسم المستلم',
                          keyboardType: TextInputType.name,
                          validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? 'الرجاء إدخال الاسم' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          context,
                          controller: phoneController,
                          label: 'رقم التواصل',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                          validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? 'الرجاء إدخال رقم صحيح' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          context,
                          controller: labelController,
                          label: 'عنوان التوصيل',
                          keyboardType: TextInputType.streetAddress,
                          validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? 'الرجاء إدخال العنوان' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          context,
                          controller: areaController,
                          label: 'المنطقة (اختياري)',
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          context,
                          controller: noteController,
                          label: 'ملاحظات إضافية (اختياري)',
                          keyboardType: TextInputType.multiline,
                          maxLines: 3,
                        ),

                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: context.color.primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: context.color.territoryColor.withOpacity(0.4),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on_outlined, color: context.color.territoryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      location != null
                                          ? _describeLocation(location!)

                                          : 'حدد الموقع الجغرافي على الخريطة',
                                      style: TextStyle(
                                        fontSize: context.font.normal,
                                        color: context.color.textDefaultColor,
                                      ),
                                    ),
                                    if (location == null)
                                      Text(
                                        'سيساعدنا تحديد الموقع على تحسين خدمة التوصيل.',
                                        style: TextStyle(
                                          fontSize: context.font.smaller,
                                          color: context.color.textLightColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () async {
                                  final Map<String, dynamic>? picked =
                                  await _pickLocation(location);

                                  if (picked == null) return;
                                  setModalState(() {
                                    location = picked;
                                    locationError = null;

                                    final String? areaName =
                                    (picked['area'] ?? picked['city'])
                                        ?.toString()
                                        .trim();
                                    if (areaName != null && areaName.isNotEmpty) {
                                      areaController.text = areaName;
                                    }

                                    final String? formatted =
                                    picked['formatted_address']?.toString().trim();
                                    if (formatted != null && formatted.isNotEmpty) {
                                      labelController.text = formatted;
                                    }


                                  });
                                },
                                child: Text(
                                  location == null ? 'اختيار' : 'تعديل',
                                  style: TextStyle(color: context.color.territoryColor),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (locationError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            locationError!,
                            style: TextStyle(
                              color: context.color.textDefaultColor,
                              fontSize: context.font.small,
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        UiUtils.buildButton(
                          context,
                          buttonTitle: initial == null ? 'حفظ العنوان' : 'تحديث العنوان',
                          radius: 14,
                          height: 54,
                          isInProgress: saving,
                          titleWhenProgress: 'جارٍ الحفظ...',
                          disabled: saving,
                          onPressed: () {
                            if (saving) {
                              return;
                            }

                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }

                            final dynamic lat = location?['lat'] ?? location?['latitude'];
                            final dynamic lng = location?['lng'] ?? location?['longitude'];
                            if (lat == null || lng == null) {
                              setModalState(() {
                                locationError = 'الرجاء تحديد الموقع الجغرافي قبل الحفظ.';
                              });
                              return;
                            }

                            setModalState(() {
                              saving = true;
                            });

                            final Map<String, dynamic> payload = <String, dynamic>{
                              'name': nameController.text.trim(),
                              'phone': phoneController.text.trim(),
                              'label': labelController.text.trim(),

                            };

                            if (location != null) {
                              final Map<String, dynamic> normalizedLocation =
                              Map<String, dynamic>.from(location!);
                              final dynamic latValue =
                              normalizedLocation.remove('lat');
                              final dynamic lngValue =
                              normalizedLocation.remove('lng');
                              normalizedLocation['latitude'] =
                                  normalizedLocation['latitude'] ?? latValue;
                              normalizedLocation['longitude'] =
                                  normalizedLocation['longitude'] ?? lngValue;
                              payload.addAll(normalizedLocation);
                            }


                            final String areaText = areaController.text.trim();
                            if (areaText.isNotEmpty) {
                              payload['area'] = areaText;
                            }

                            final String noteText = noteController.text.trim();
                            if (noteText.isNotEmpty) {
                              payload['note'] = noteText;
                            }
                            payload.putIfAbsent('distance_km', () => 0);

                            Navigator.pop(context, payload);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _pickLocation(Map<String, dynamic>? seed) async {
    final Map<String, dynamic>? response =
    await CartAddressLocationPicker.show(context, initial: seed);
    if (response == null) {
      return seed;
    }

    final Map<String, dynamic> merged =
    Map<String, dynamic>.from(seed ?? const <String, dynamic>{})
      ..addAll(response);
    return _normalizeLocationData(merged);
  }



  Map<String, dynamic>? _normalizeLocationData(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final Map<String, dynamic> normalized = <String, dynamic>{};

    void put(String key, dynamic value) {
      if (value == null) return;
      normalized[key] = value;
    }

    final dynamic latitude = raw['latitude'] ?? raw['lat'];
    final dynamic longitude = raw['longitude'] ?? raw['lng'];
    put('latitude', latitude);
    put('longitude', longitude);
    put('lat', latitude);
    put('lng', longitude);

    for (final String key
    in const <String>['area', 'city', 'state', 'country', 'formatted_address']) {

      put(key, raw[key]);
    }

    return normalized.isEmpty ? null : normalized;
  }

  Widget _buildTextField(
      BuildContext context, {
        required TextEditingController controller,
        required String label,
        TextInputType? keyboardType,
        List<TextInputFormatter>? inputFormatters,
        String? Function(String?)? validator,
        int maxLines = 1,

      }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,

      decoration: InputDecoration(

        labelText: label,
        filled: true,
        fillColor: context.color.primaryColor.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.borderColor.withOpacity(0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.borderColor.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.territoryColor),
        ),
      ),
    );
  }

  String _describeLocation(Map<String, dynamic> location) {
    final List<String> parts = <String>[
      if ((location['formatted_address']?.toString().trim().isNotEmpty ?? false))
        location['formatted_address'].toString().trim(),
      for (final String key in const <String>['area', 'city', 'state', 'country'])
        if ((location[key]?.toString().trim().isNotEmpty ?? false))
          location[key].toString().trim(),
    ];

    if (parts.isEmpty) {
      return 'تم تحديد الإحداثيات بنجاح';
    }
    return parts.join('، ');
  }

  @override
  Widget build(BuildContext context) {

    final int selectedIndex = _selectedAddressId == null
        ? -1
        : _addresses.indexWhere(
          (Map<String, dynamic> element) =>
      _addressId(element) == _selectedAddressId,
    );

    return WillPopScope(
      onWillPop: () async {
        _popWithSelection();
        return false;
      },
      child: AnnotatedRegion(
        value: UiUtils.getSystemUiOverlayStyle(
          context: context,
          statusBarColor: context.color.secondaryColor,
        ),
        child: AdressUI(
          // حالة العرض
          isLoading: _loading && !_mutating,
          addressList: _addresses,
          selectedIndex: selectedIndex,

          // ردود الأفعال
          onAddNew: _onAddNew,
          onSelect: _onSelect,
          onEdit: _onEdit,
          onDelete: _onDelete,
          onSetDefault: _onSetDefault,
          onAddLocation: _onAddLocation,
          onBackPress: _popWithSelection,
        ),
      ),
    );
  }




  Future<bool> _performMutation(
      Future<void> Function() action, {
        String? successMessage,
      }) async {
    if (_mutating) return false;
    setState(() => _mutating = true);


    bool success = false;
    String? _resolveHttpError(ApiHttpException error) {
      Map<String, dynamic>? mapify(dynamic value) {
        if (value is Map<String, dynamic>) {
          return value;
        }
        if (value is Map) {
          return Map<String, dynamic>.from(value as Map);
        }
        return null;
      }
      void collectStrings(dynamic value, List<String> target) {
        if (value == null) return;
        if (value is String) {
          final String trimmed = value.trim();
          if (trimmed.isNotEmpty) {
            target.add(trimmed);
          }
          return;
        }
        if (value is Iterable) {
          for (final dynamic item in value) {
            collectStrings(item, target);
          }
          return;
        }
        if (value is Map) {
          value.forEach((dynamic _, dynamic entry) => collectStrings(entry, target));
        }
      }

      final Map<String, dynamic>? payloadMap = mapify(error.payload);

      if (error.statusCode == 422 && payloadMap != null) {
        final Map<String, dynamic>? errorsMap = mapify(payloadMap['errors']);
        if (errorsMap != null && errorsMap.isNotEmpty) {
          final Map<String, String> fieldLabels = const <String, String>{
            'label': 'العنوان',
            'phone': 'رقم الهاتف',
            'phone_number': 'رقم الهاتف',
            'mobile': 'رقم الهاتف',
            'latitude': 'خط العرض',
            'longitude': 'خط الطول',
            'distance_km': 'المسافة',
            'distance': 'المسافة',
            'distanceKm': 'المسافة',
            'area_id': 'المنطقة',
            'street': 'الشارع',
            'building': 'المبنى',
            'note': 'الملاحظات',
          };
          final List<String> fieldMessages = <String>[];

          errorsMap.forEach((dynamic key, dynamic value) {
            final String fieldKey = key?.toString() ?? '';
            final List<String> entryMessages = <String>[];
            collectStrings(value, entryMessages);
            if (entryMessages.isEmpty) {
              return;
            }
            final String fieldLabel = fieldLabels[fieldKey] ?? fieldKey;
            fieldMessages.add('$fieldLabel: ${entryMessages.join('، ')}');
          });

          if (fieldMessages.isNotEmpty) {
            return LinkedHashSet<String>.from(fieldMessages).join('\n');
          }
        }
      }

      final List<String> messages = <String>[];

      if (payloadMap != null) {
        collectStrings(payloadMap['errors'], messages);


        if (messages.isEmpty) {
          collectStrings(payloadMap['error'], messages);
        }
        if (messages.isEmpty) {
          collectStrings(payloadMap['data'], messages);
        }
        if (messages.isEmpty) {
          final dynamic message = payloadMap['message'];
          if (message is String && message.trim().isNotEmpty) {
            messages.add(message.trim());
          }
        }
      }

      if (messages.isEmpty) {
        final dynamic fallback = error.errorMessage;
        if (fallback is String && fallback.trim().isNotEmpty) {
          messages.add(fallback.trim());
        }
      }

      if (messages.isEmpty) {
        return null;
      }
      return LinkedHashSet<String>.from(messages).join('\n');
    }

    try {
      await action();
      success = true;
      if (successMessage != null && mounted) {
        HelperUtils.showSnackBarMessage(context, successMessage);
      }
    } on ApiException catch (error) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, error.toString());
      }
    } on ApiHttpException catch (error) {
      if (mounted) {
        final String message =
            _resolveHttpError(error) ?? 'حدث خطأ أثناء حفظ العنوان.';
        HelperUtils.showSnackBarMessage(context, message);
      }
    } catch (_) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          'حدث خطأ أثناء حفظ العنوان.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
      }
    }
    return success;

  }

  void _applyAddresses(
      List<Map<String, dynamic>> addresses, {
        int? preferSelectedId,
        bool forceDefaultSelection = false,
      }) {
    final int? defaultId = _findDefaultId(addresses);

    int? nextSelectedId = _selectedAddressId;
    if (preferSelectedId != null &&
        addresses.any((Map<String, dynamic> element) =>
        _addressId(element) == preferSelectedId)) {
      nextSelectedId = preferSelectedId;
    } else {
      if (nextSelectedId != null &&
          !addresses.any((Map<String, dynamic> element) =>
          _addressId(element) == nextSelectedId)) {
        nextSelectedId = null;
      }

      if (defaultId != null &&
          (forceDefaultSelection || _defaultAddressId != defaultId)) {
        nextSelectedId = defaultId;
      }
    }

    nextSelectedId ??= defaultId;
    nextSelectedId ??= addresses
        .map(_addressId)
        .firstWhere((int? id) => id != null, orElse: () => null);

    setState(() {
      _addresses = addresses;
      _defaultAddressId = defaultId;
      _selectedAddressId = nextSelectedId;
    });
  }


  void _popWithSelection() {
    if (!mounted) return;
    final NavigatorState navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    final int? resolvedId =
        _selectedAddressId ??
            _defaultAddressId ??
            _addresses.map(_addressId).firstWhere(
                  (int? id) => id != null,
              orElse: () => null,
            );
    navigator.pop<int?>(resolvedId);
  }

  int? _findDefaultId(List<Map<String, dynamic>> addresses) {
    for (final Map<String, dynamic> address in addresses) {
      if (address['is_default'] == true ||
          address['isDefault'] == true ||
          address['default'] == true) {
        return _addressId(address);
      }
    }
    return null;
  }

  int? _addressId(Map<String, dynamic> address) {
    final dynamic id =
        address['id'] ?? address['address_id'] ?? address['addressId'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse(id?.toString() ?? '');
  }

  Set<int> get _knownAddressIds => _addresses
      .map(_addressId)
      .whereType<int>()
      .toSet();


}
