import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:marib/app/routes.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/data/cubits/item/manage_item_cubit.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:marib/utils/ecommerce_department.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:shimmer/shimmer.dart';

import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/validator.dart';

import 'package:marib/data/helper/widgets.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/user_profile/my_item_tab.dart';

import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'smart_hint.dart';
import 'package:marib/utils/errorFilter.dart';

part 'confirm_location_screen_ui.dart';



class ConfirmLocationScreen extends StatefulWidget {
  final bool? isEdit;
  final File? mainImage;
  final List<File>? otherImage;

  const ConfirmLocationScreen({
    Key? key,
    required this.isEdit,
    required this.mainImage,
    required this.otherImage,
  }) : super(key: key);

  static BlurredRouter route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;

    return BlurredRouter(
      builder: (context) {
        return BlocProvider(
          create: (context) => ManageItemCubit(),
          child: ConfirmLocationScreen(
            isEdit: arguments?['isEdit'] ?? false,
            mainImage: arguments?['mainImage'],
            otherImage: arguments?['otherImage'],
          ),
        );
      },
    );
  }

  @override
  _ConfirmLocationScreenState createState() => _ConfirmLocationScreenState();
}


CameraPosition buildCamera(LatLng target, {double zoom = 14.47}) {
  return CameraPosition(
    target: target,
    zoom: zoom,
    bearing: 0,
  );
}

Marker createMarker(String id, LatLng position) {
  return Marker(
    markerId: MarkerId(id),
    position: position,
  );
}









class _ConfirmLocationScreenState extends CloudState<ConfirmLocationScreen>
    with WidgetsBindingObserver {
  final GlobalKey<FormState> _formKey = GlobalKey();
  TextEditingController cityTextController = TextEditingController();
  TextEditingController countryTextController = TextEditingController();
  String currentLocation = '';
  AddressComponent? formatedAddress;
  double? latitude, longitude;
  CameraPosition? _cameraPosition;
  final Set<Marker> _markers = Set();
  late GoogleMapController _mapController;
  var markerMove;
  bool _openedAppSettings = false;
  MapType _mapType = MapType.normal;
  bool _isPosting = false;
  bool _navigated = false;
  late final TextEditingController _searchCtrl;
  late final FocusNode _searchFocus;
  Timer? _debounce;
  List<_PlaceSuggestion> _suggestions = [];
  bool _loadingSuggestions = false;
  final LayerLink _searchLink = LayerLink();
  Size _searchBoxSize = Size.zero;
  final _searchBoxKey = GlobalKey();
  final double _tileH = 56; // تقدير ارتفاع كل عنصر (ListTile) لسطر واحد
  final double _vPadding = 16; // هوامش داخل القائمة
  final double _maxCap = 400; // سقف أقصى لو طالبتك قائمة طويلة
  Timer? _idleDebounce;
  Set<Circle> _accuracyCircle = {};
  bool _reverseLoading = false; // لو تبغى تعرض حالة تحميل العنوان
  Future<void> _applyMapStyle() async { /* حمّل JSON حسب الثيم واستدع setMapStyle */ }
  bool _showSelectedMarker = false;
  bool _isMoving = false;
  bool _locating = false;
  bool _showPinHint = true;
  Timer? _hintTimer;
  bool _showHint = true; // متغير للتحكم في عرض التلميح
  late final SmartHintController _hint;







  void _scheduleHintReturn() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _showPinHint = true);
    });
  }





  String _short(String? s, {int max = 42}) {
    if (s == null || s.isEmpty) return '';
    return s.length <= max ? s : '${s.substring(0, max)}…';
  }


  // كاش للتفاصيل حتى ما نعمل طلب ثاني
  final Map<String, _PlaceDetails> _placeCache = {};

// جلب اقتراحات العناوين (Autocomplete) عبر Nominatim
  Future<List<_PlaceSuggestion>> _placesAutocomplete(String q) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(q)}&format=jsonv2&addressdetails=1&limit=8',
    );

    try {
      final res = await http.get(
        uri,
        headers: {
          // بعض خوادم Nominatim تتطلب User-Agent
          'User-Agent': 'marib-app/1.0 (+contact@example.com)',
        },
      );
      if (res.statusCode != 200) return [];

      final List data = json.decode(res.body) as List;

      final suggestions = <_PlaceSuggestion>[];
      for (final item in data) {
        final placeId = (item['place_id'] ?? '').toString();
        final addr = item['address'] as Map<String, dynamic>? ?? {};

        // نحاول استخراج المكوّنات
        String? area = addr['suburb'] ??
            addr['neighbourhood'] ??
            addr['quarter'] ??
            addr['village'] ??
            addr['town'];
        final String? city    = addr['city'] ?? addr['town'] ?? addr['village'];
        final String? state   = addr['state'];
        final String? country = addr['country'];

        final double? lat = (item['lat'] != null) ? double.tryParse(item['lat']) : null;
        final double? lng = (item['lon'] != null) ? double.tryParse(item['lon']) : null;

        // كوّن العنوان العربي المختصر
        final title = [
          area?.trim(),
          city?.trim(),
          state?.trim(),
          country?.trim(),
        ].where((e) => e != null && e!.isNotEmpty).map((e) => e!).join('، ');

        // لو فاضي، استخدم display_name
        final fallbackTitle = (item['display_name'] ?? '').toString();
        final shownTitle = title.isNotEmpty ? title : fallbackTitle;

        // خزّن التفاصيل في الكاش (عشان _placeDetails ترجعها فورًا)
        if (lat != null && lng != null) {
          _placeCache[placeId] = _PlaceDetails(
            lat: lat,
            lng: lng,
            area: area,
            city: city,
            state: state,
            country: country,
          );
        }

        suggestions.add(_PlaceSuggestion(
          placeId: placeId,
          title: shownTitle,
          subtitle: country,
        ));
      }
      return suggestions;
    } catch (_) {
      return [];
    }
  }

// إرجاع التفاصيل من الكاش (بلا طلب إضافي)
  Future<_PlaceDetails?> _placeDetails(String placeId) async {
    return _placeCache[placeId];
  }



  // قياس عرض/ارتفاع حقل البحث لمطابقة لوحة الاقتراحات
  void _updateSearchBoxSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _searchBoxKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox;
      setState(() => _searchBoxSize = box.size);
    });
  }




  // تمييز الجزء المطابق من النص
  InlineSpan _highlight(String text, String query, TextStyle base, TextStyle hi) {
    final q = query.trim();
    if (q.isEmpty) return TextSpan(text: text, style: base);
    final i = text.toLowerCase().indexOf(q.toLowerCase());
    if (i < 0) return TextSpan(text: text, style: base);
    return TextSpan(children: [
      TextSpan(text: text.substring(0, i), style: base),
      TextSpan(text: text.substring(i, i + q.length), style: hi),
      TextSpan(text: text.substring(i + q.length), style: base),
    ]);
  }







  double _suggestionsTop = 100; // قيمة افتراضية

  void _updateSuggestionsTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _searchBoxKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox;
      final pos = box.localToGlobal(Offset.zero);
      setState(() {
        _suggestionsTop = pos.dy + box.size.height + 8; // تحت البحث بـ 8px
      });
    });
  }


  void showGPSPermissionError() {
    showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: Text("فشل تحديد الموقع"),
            content: Text(
                "لم نتمكن من الوصول لموقعك. تأكد من تفعيل GPS ومنح الإذن."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _getCurrentLocation(); // إعادة المحاولة
                },
                child: Text("🔁 إعادة المحاولة"),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings(); // فتح الإعدادات
                },
                child: Text("⚙️ الإعدادات"),
              ),
            ],
          ),
    );
  }



  Future<void> _onPostNowPressed() async {
    if (latitude == null || longitude == null) {
      HelperUtils.showSnackBarMessage(context, "يرجى تحديد موقع صالح على الخريطة");
      return;
    }


    try {
      final cloudData = (getCloudData("with_more_details") as Map<String, dynamic>?) ??
          <String, dynamic>{};

      final AddressComponent? selectedAddress = formatedAddress;
      final cleanedArea = AddressComponent._clean(selectedAddress?.area);
      final cleanedCity = AddressComponent._clean(selectedAddress?.city);
      final cleanedState = AddressComponent._clean(selectedAddress?.state);
      final cleanedCountry = AddressComponent._clean(selectedAddress?.country);
      final String fallbackAddress =
          'الموقع المحدد (${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)})';



      final String resolvedAddress =
          AddressComponent._clean(selectedAddress?.mixed) ?? fallbackAddress;
      cloudData['address'] = resolvedAddress;

      if (cleanedArea != null) {
        cloudData['area'] = cleanedArea;
      } else {
        cloudData.remove('area');
      }


      cloudData['latitude'] = latitude;
      cloudData['longitude'] = longitude;
      cloudData['location_latitude'] = latitude;
      cloudData['location_longitude'] = longitude;

      if (cleanedCountry != null) {
        cloudData['country'] = cleanedCountry;

      } else {
        cloudData.remove('country');
      }

      final String resolvedCity = cleanedCity ?? cleanedArea ?? fallbackAddress;
      cloudData['city'] = resolvedCity;

      if (cleanedState != null) {
        cloudData['state'] = cleanedState;
      } else {
        cloudData.remove('state');


      }
      if (selectedAddress?.areaId != null) {
        cloudData['area_id'] = selectedAddress!.areaId;
      } else {
        cloudData.remove('area_id');
      }

      cloudData.removeWhere((key, value) => value == null || (value is String && value.isEmpty));



      final cubit = context.read<ManageItemCubit>();
      if (widget.isEdit == true) {
         cubit.manage(ManageItemType.edit, cloudData, widget.mainImage, widget.otherImage ?? []);
      } else {
        if (widget.mainImage == null) {
          HelperUtils.showSnackBarMessage(context, "يرجى اختيار صورة رئيسية للإعلان");
          return;
        }
         cubit.manage(ManageItemType.add, cloudData, widget.mainImage!, widget.otherImage ?? []);
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, "حدث خطأ غير متوقع");
    }
  }







  Future<void> _goToUserLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        latitude = pos.latitude;
        longitude = pos.longitude;
        _cameraPosition = CameraPosition(
          target: LatLng(latitude!, longitude!),
          zoom: 16,
        );
      });

      // حرّك الكاميرا إذا الكنترولر جاهز
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(_cameraPosition!),
        );
      }
    } on PermissionDeniedException catch (e) {
      log('GPS permission denied: $e');
      this.showGPSPermissionError();
    } on LocationServiceDisabledException catch (e) {
      log('Location services disabled: $e');
      this.showGPSPermissionError();
    } catch (e) {
      log('Failed to get user location: $e');
      this.showGPSPermissionError();
    }
  }







  @override
  void initState() {


    _searchFocus = FocusNode();
    _searchCtrl  = TextEditingController();
    _hint = SmartHintController();
    _debounce?.cancel();

    _getCurrentLocation();

    // أول ما تفتح الشاشة يظهر تلميح البداية
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hint.onScreenOpened();
    });

    WidgetsBinding.instance.addObserver(this);
    super.initState();


  }



  @override
  void dispose() {
    // مؤقتات
    _hintTimer?.cancel();
    _idleDebounce?.cancel();

    _hint.dispose();

    // ملاحظ النظام
    WidgetsBinding.instance.removeObserver(this);

    // كنترولرات
    _mapController?.dispose(); // لو معرف كـ GoogleMapController?
    cityTextController.dispose();
    countryTextController.dispose();


    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }



  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _openedAppSettings) {
      _openedAppSettings = false;

      // Reset the flag
      _getCurrentLocation();
      setState(() {}); // Call the method to fetch the current location
    }
  }

  preFillLocationWhileEdit() async {
    if (widget.isEdit!) {
      ItemModel itemModel = getCloudData('edit_request') as ItemModel;

      currentLocation = [
        itemModel.area,
        itemModel.city,
        itemModel.state,
        itemModel.country
      ].where((part) => part != null && part.isNotEmpty).join(', ');
      formatedAddress = AddressComponent(
          area: itemModel.area,
          areaId: itemModel.areaId,
          city: itemModel.city,
          country: itemModel.country,
          state: itemModel.state);
      latitude = itemModel.latitude;
      longitude = itemModel.longitude;
      _cameraPosition = buildCamera(LatLng(latitude!, longitude!));


      _markers.add(Marker(
        markerId: const MarkerId('currentLocation'),
        position: LatLng(itemModel.latitude!, itemModel.longitude!),
      ));
    } else {
      currentLocation = [
        HiveUtils.getCurrentAreaName(),
        HiveUtils.getCurrentCityName(),
        HiveUtils.getCurrentStateName(),
        HiveUtils.getCurrentCountryName()
      ].where((part) => part != null && part.isNotEmpty).join(', ');
      if (currentLocation == "") {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        latitude = position.latitude;
        longitude = position.longitude;
        final currentLatLng = LatLng(latitude!, longitude!);

        _cameraPosition = buildCamera(currentLatLng);

        getLocationFromLatitudeLongitude(latLng: currentLatLng);


        _markers.add(Marker(
          markerId: const MarkerId('currentLocation'),
          position: currentLatLng,

        ));

      } else {
        formatedAddress = AddressComponent(
            area: HiveUtils.getCurrentAreaName(),
            areaId: null,
            city: HiveUtils.getCurrentCityName(),
            country: HiveUtils.getCurrentCountryName(),
            state: HiveUtils.getCurrentStateName());
        latitude = HiveUtils.getCurrentLatitude();
        longitude = HiveUtils.getCurrentLongitude();
        _cameraPosition = buildCamera(LatLng(latitude!, longitude!));

        getLocationFromLatitudeLongitude(latLng: LatLng(latitude!, longitude!));
        _markers.add(Marker(
          markerId: const MarkerId('currentLocation'),
          position: LatLng(latitude!, longitude!),
        ));
      }
    }

    setState(() {});
  }

  getLocationFromLatitudeLongitude({LatLng? latLng}) async {
    try {
      await setLocaleIdentifier("en_US");
      Placemark? placeMark = (await placemarkFromCoordinates(
          latLng?.latitude ?? _cameraPosition!.target.latitude,
          latLng?.longitude ?? _cameraPosition!.target.longitude))
          .first;

      formatedAddress = AddressComponent(
          area: placeMark.subLocality,
          areaId: null,
          city: placeMark.locality,
          country: placeMark.country,
          state: placeMark.administrativeArea);

      setState(() {});
    } catch (e) {
      log(e.toString());
      formatedAddress = null;
      setState(() {});
    }
  }


  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        this.showGPSPermissionError();
        // المستخدم رفض الإذن نهائيًا
        return;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          this.showGPSPermissionError();
          // المستخدم ما وافق
          return;
        }
      }

      // الإذن موجود، نكمل
      try {
        await preFillLocationWhileEdit();

        if (widget.isEdit == true) {
          if (_cameraPosition == null) {
            await _goToUserLocation();
          }
        } else {

          await _goToUserLocation();
        }
      } on PermissionDeniedException catch (e) {
        log('GPS permission denied while prefilling: $e');
        this.showGPSPermissionError();
      } on LocationServiceDisabledException catch (e) {
        log('Location services disabled while prefilling: $e');
        this.showGPSPermissionError();
      }
    } catch (e) {
      log("GPS Error: $e");
      this.showGPSPermissionError();
      // أي خطأ فجائي
    }
  }


  @override
  Widget build(BuildContext context) => _buildUI(context);






  Set<Factory<OneSequenceGestureRecognizer>> getMapGestureRecognizers() {
    return <Factory<OneSequenceGestureRecognizer>>{}..add(
        Factory<PanGestureRecognizer>(
                () =>
            PanGestureRecognizer()
              ..onUpdate = (dragUpdateDetails) {}))..add(
        Factory<ScaleGestureRecognizer>(
                () =>
            ScaleGestureRecognizer()
              ..onStart = (dragUpdateDetails) {}))..add(
        Factory<TapGestureRecognizer>(() => TapGestureRecognizer()))..add(
        Factory<VerticalDragGestureRecognizer>(
                () =>
            VerticalDragGestureRecognizer()
              ..onDown = (dragUpdateDetails) {
                if (markerMove == false) {} else {
                  setState(() {
                    markerMove = false;
                  });
                }
              }));
  }

}






/// كلاس يمثل مكوّنات العنوان للجمهور العربي
class AddressComponent {
  final String? area;     // الحي/المنطقة
  final int? areaId;      // معرّف المنطقة (اختياري)
  final String? city;     // المدينة
  final String? state;    // المحافظة/المنطقة
  final String? country;  // الدولة

  const AddressComponent({
    this.area,
    this.areaId,
    this.city,
    this.state,
    this.country,
  });

  /// النص المركب الناتج عن دمج الحقول بالفاصل العربي
  String get mixed => _generateMixedString(area, city, state, country);

  /// نسخة معدّلة (الطريقة المعتمدة)
  AddressComponent copyWith({
    String? area,
    int? areaId,
    String? city,
    String? state,
    String? country,
  }) {
    return AddressComponent(
      area: area ?? this.area,
      areaId: areaId ?? this.areaId,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
    );
  }

  /// ✅ توافق رجعي مع الاستدعاءات القديمة AddressComponent.copyWithFields(...)
  factory AddressComponent.copyWithFields(
      AddressComponent original, {
        String? newArea,
        int? newAreaId,
        String? newCity,
        String? newState,
        String? newCountry,
      }) {
    return original.copyWith(
      area: newArea,
      areaId: newAreaId,
      city: newCity,
      state: newState,
      country: newCountry,
    );
  }

  /// تنظيف النصوص (trim) وإرجاع null إن كانت فارغة
  static String? _clean(String? value) {
    final t = value?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// دمج العنوان بالفاصل العربي
  static String _generateMixedString(
      String? area,
      String? city,
      String? state,
      String? country, {
        String separator = '، ',
      }) {
    return [area, city, state, country]
        .where((e) => e != null && e!.trim().isNotEmpty)
        .map((e) => e!.trim())
        .join(separator);
  }

  /// تحويل إلى خريطة (يتجاهل null/النص الفارغ إن omitNulls = true)
  Map<String, dynamic> toMap({bool omitNulls = true}) {
    final map = <String, dynamic>{
      'area': _clean(area),
      'areaId': areaId,
      'city': _clean(city),
      'state': _clean(state),
      'country': _clean(country),
      'mixed': mixed, // يُولّد لحظيًا
    };
    if (omitNulls) {
      map.removeWhere((_, v) => v == null || (v is String && v.isEmpty));
    }
    return map;
  }

  /// إنشاء من خريطة
  factory AddressComponent.fromMap(Map<String, dynamic> map) {
    int? _parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    return AddressComponent(
      area: _clean(map['area'] as String?),
      areaId: _parseInt(map['areaId']),
      city: _clean(map['city'] as String?),
      state: _clean(map['state'] as String?),
      country: _clean(map['country'] as String?),
    );
  }

  /// حالات ملائمة
  bool get isEmpty =>
      _clean(area) == null &&
          areaId == null &&
          _clean(city) == null &&
          _clean(state) == null &&
          _clean(country) == null;

  bool get isNotEmpty => !isEmpty;

  @override
  String toString() =>
      'AddressComponent(area: $area, areaId: $areaId, city: $city, state: $state, country: $country, mixed: $mixed)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AddressComponent &&
              runtimeType == other.runtimeType &&
              area == other.area &&
              areaId == other.areaId &&
              city == other.city &&
              state == other.state &&
              country == other.country;

  @override
  int get hashCode =>
      area.hashCode ^
      (areaId ?? 0).hashCode ^
      city.hashCode ^
      state.hashCode ^
      country.hashCode;
}
