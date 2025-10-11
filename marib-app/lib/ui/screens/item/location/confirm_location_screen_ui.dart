part of 'confirm_location_screen.dart';

extension _ConfirmLocationUI on _ConfirmLocationScreenState {
  // ==========================
  // Entry
  // ==========================




  Widget _buildUI(BuildContext context) {
    final canPost = latitude != null && longitude != null;

    // إعدادات قياس لوحة الاقتراحات (طول مرن)
    const double _tileH = 56;   // ارتفاع تقريبي لكل عنصر اقتراح
    const double _vPad  = 16;   // padding رأسي داخلي
    const double _maxCap = 400; // سقف أقصى للارتفاع

    // يحسب الارتفاع المناسب: تحميل/لا توجد نتائج = 56، غير ذلك = عدد العناصر * ارتفاع العنصر + padding مع سقف
    double _calcMaxHeight() {
      if (_loadingSuggestions) return 56;
      if (_suggestions.isEmpty) return 56;
      return math.min((_suggestions.length * _tileH) + _vPad, _maxCap);
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "confirmLocation".translate(context),
          onBackPress: () => Navigator.maybePop(context),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.only(bottom: 12, left: 18, right: 18),
          child: UiUtils.buildButton(
            context,
            onPressed: () {
              if (!canPost) return;
              _onPostNowPressed();
            },
            height: 48.rh(context),
            fontSize: context.font.large,
            autoWidth: false,
            radius: 8,
            width: double.maxFinite,
            buttonTitle: "postNow".translate(context),
            disabled: !canPost,
            disabledColor: const Color.fromARGB(255, 104, 102, 106),
          ),
        ),
        body: Stack(
          children: [
            bodyData(),

            // طبقة إغلاق بالنقر خارج اللوحة
            if (_loadingSuggestions || _suggestions.isNotEmpty)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _suggestions = []),
                ),
              ),

            // لوحة الاقتراحات مثبتة تحت حقل البحث وبنفس عرضه
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: (_loadingSuggestions || _suggestions.isNotEmpty)
                  ? CompositedTransformFollower(
                link: _searchLink,
                showWhenUnlinked: false,
                offset: Offset(0, _searchBoxSize.height + 10),
                child: Align(
                  alignment: (Directionality.of(context) == TextDirection.rtl)
                      ? AlignmentDirectional.topEnd
                      : AlignmentDirectional.topStart,
                  child: Material(
                    elevation: 20,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    color: Theme.of(context).colorScheme.surface,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _searchBoxSize.width == 0
                            ? MediaQuery.of(context).size.width - 20
                            : _searchBoxSize.width,
                        // 👇 الطول المرن بدل 500 ثابت
                        maxHeight: _calcMaxHeight(),
                      ),
                      child: _loadingSuggestions
                          ? const SizedBox(
                        height: 56,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : (_suggestions.isEmpty
                          ? const SizedBox(
                        height: 56,
                        child: Center(child: Text('لا توجد نتائج')),
                      )
                          : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place),
                            title: RichText(
                              text: _highlight(
                                s.title,
                                _searchCtrl.text,
                                Theme.of(context).textTheme.bodyMedium!,
                                Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            subtitle: (s.subtitle != null) ? Text(s.subtitle!) : null,
                            onTap: () async {
                              _dismissKeyboard();
                              final det = await _placeDetails(s.placeId);
                              if (!mounted || det == null) return;
                              setState(() {
                                _suggestions = [];
                                latitude = det.lat;
                                longitude = det.lng;
                                formatedAddress = AddressComponent(
                                  area: det.area,
                                  city: det.city,
                                  state: det.state,
                                  country: det.country,
                                );
                                _cameraPosition = buildCamera(LatLng(det.lat, det.lng));
                                _mapController.animateCamera(
                                  CameraUpdate.newCameraPosition(_cameraPosition!),
                                );
                                _markers
                                  ..clear()
                                  ..add(Marker(
                                    markerId: const MarkerId('currentLocation'),
                                    position: LatLng(det.lat, det.lng),
                                  ));
                              });
                              _searchCtrl.text = formatedAddress!.mixed;
                            },
                          );
                        },
                      )),
                    ),
                  ),
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }





  // ==========================
  // Actions
  // ==========================


  void _dismissKeyboard() {
    if (_searchFocus.hasFocus) {
      _searchFocus.unfocus();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }


  Future<void> _onPostNowPressed() async {
    // ===== Helpers =====
    String? _clean(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    void _snack(String msgKeyOrText, {bool isKey = true}) {
      final txt = isKey ? msgKeyOrText.translate(context) : msgKeyOrText;
      HelperUtils.showSnackBarMessage(context, txt);
    }

    // ===== Guards =====
    if (latitude == null || longitude == null) {
      _snack("يرجى تحديد موقع صالح على الخريطة", isKey: false);
      return;
    }



    // منع النقر المزدوج بشكل بسيط (لو ما عندك isPosting خارجي)
    if (_isPosting == true) return;
    _isPosting = true;

    try {
      // ===== Build payload =====
      final Map<String, dynamic> cloudData =
          (getCloudData("with_more_details") as Map<String, dynamic>?) ??
              <String, dynamic>{};


      String? _existingValue(String key) {
        final value = cloudData[key];
        if (value == null) return null;
        if (value is String) {
          return _clean(value);
        }
        return _clean(value.toString());
      }

      int? _normalizeAreaId(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value.toString());
      }

      final _area    = _clean(formatedAddress?.area);
      final _city    = _clean(formatedAddress?.city);
      final _state   = _clean(formatedAddress?.state);
      final _country = _clean(formatedAddress?.country);

      // city: city or (area) else null
      final _resolvedCity = _city ?? _area;

      // address mixed جاهز بالعربي من AddressComponent
      final address = _clean(formatedAddress?.mixed) ?? _existingValue('address');
      if (address == null) {
        _isPosting = false;
        _snack('تعذر تحديد العنوان. يرجى اختيار موقع صالح.', isKey: false);
        return;
      }
      cloudData['address'] = address;

      cloudData['latitude']  = latitude;
      cloudData['longitude'] = longitude;
      // بعض نقاط النهاية الخلفية القديمة ما زالت تتوقع مفاتيح location_*.
      // نرسلها مع الحقول الجديدة لضمان التوافق وتفادي أخطاء validation.required.
      cloudData['location_latitude']  = latitude;
      cloudData['location_longitude'] = longitude;
      final resolvedCity = _resolvedCity ?? _existingValue('city');
      if (resolvedCity == null) {
        _isPosting = false;
        _snack('يرجى تحديد المدينة قبل المتابعة.', isKey: false);
        return;
      }
      cloudData['city'] = resolvedCity;


      final country = _country ?? _existingValue('country');
      if (country == null) {
        _isPosting = false;
        _snack('يرجى تحديد الدولة قبل المتابعة.', isKey: false);
        return;
      }
      cloudData['country'] = country;

      final state = _state ?? _existingValue('state');
      if (state != null) {
        cloudData['state'] = state;

      } else {
        cloudData.remove('state');
      }



      final areaId = formatedAddress?.areaId ?? _normalizeAreaId(cloudData['area_id']);
      if (areaId != null) {
        cloudData['area_id'] = areaId;
      } else {
        cloudData.remove('area_id');
      }

      // احذف القيم الفارغة حفاظًا على نظافة الطلب
      cloudData.removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));

      // ===== Submit =====
      final manage = context.read<ManageItemCubit>();
      if (widget.isEdit == true) {
        _dismissKeyboard();
        manage.manage(
          ManageItemType.edit,
          cloudData,
          widget.mainImage,      // قد تكون null في التعديل وهذا منطقي
          widget.otherImage ?? const [], // حماية
        );
      } else {
        // في الإضافة نتوقع وجود صور
        if (widget.mainImage == null) {
          _isPosting = false;
          _snack("يرجى اختيار صورة رئيسية للإعلان", isKey: false);
          return;
        }
        _dismissKeyboard();
        manage.manage(
          ManageItemType.add,
          cloudData,
          widget.mainImage!,
          widget.otherImage ?? const [],
        );
      }

      // نجاح العملية (اختياري الرجوع للشاشة السابقة)
      if (!mounted) return;
      _snack("savedSuccessfully"); // أضف مفتاح ترجمة مناسب
      Navigator.maybePop(context);
    } catch (e) {
      // سجل الخطأ وبلغ المستخدم برسالة ودّية
      debugPrint("PostNow error: $e");
      if (mounted) _snack("somethingWentWrong"); // مفتاح ترجمة عام
    } finally {
      _isPosting = false;
    }
  }








  // ==========================
  // Body (Bloc + Content)
  // ==========================


  Widget bodyData() {
    return BlocConsumer<ManageItemCubit, ManageItemState>(
      listener: _manageItemListener,
      builder: (context, state) {
        return _cameraPosition != null ? _buildBodyContent() : shimmerEffect();
      },
    );
  }

  void _manageItemListener(BuildContext context, ManageItemState state) {
    if (state is ManageItemInProgress) {
      Widgets.showLoader(context);
    }
    if (state is ManageItemSuccess) {
      Widgets.hideLoder(context);
      final dynamic editKey = getCloudData('edit_from');
      if (editKey is String && editKey.isNotEmpty) {
        myAdsCubitReference[editKey]?.edit(state.model);
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final bool openProductManagement =
              state.type == ManageItemType.add && isEcommerceItem(state.model);

          if (openProductManagement) {
            Navigator.pushNamed(
              context,
              Routes.productManagementScreen,
              arguments: {'model': state.model},
            );
          } else {
            Navigator.pushNamed(
              context,
              Routes.successItemScreen,
              arguments: {'model': state.model, 'isEdit': widget.isEdit},
            );
          }
        }
      });
    }
    if (state is ManageItemFail) {
      final filteredError = ErrorFilter.check(state.error).error;
      final message =
      filteredError is String ? filteredError : filteredError.toString();
      HelperUtils.showSnackBarMessage(context, message);

      Widgets.hideLoder(context);
    }
  }





  Widget _buildBodyContent() {
    final color = Theme.of(context).colorScheme;

    final screenWidth = MediaQuery.of(context).size.width;
    const double cardRightInset = 20;
    const double minLeftInset = 12;
    const double maxCardWidth = 360;
    const double minCardWidth = 220;
    final double availableCardWidth = math.max(
      screenWidth - cardRightInset - minLeftInset,
      0,
    );
    final double cardWidth = math.max(
      math.min(availableCardWidth, maxCardWidth),
      math.min(minCardWidth, availableCardWidth),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitleAndPickOtherLocationButton(),
            const SizedBox(height: 1),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // الخريطة تملى المساحة
                    Positioned.fill(child: _buildMapStack()),

                    // تدرّج سفلي لتحسين قراءة بطاقة العنوان فوق الخريطة
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                color.surface.withOpacity(0.90),
                                color.surface.withOpacity(0.40),
                                color.surface.withOpacity(0.00),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ==========================
  // Sections
  // ==========================


  Widget _buildTitleAndPickOtherLocationButton() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Text("locationItemSellingLbl".translate(context))
              .bold(weight: FontWeight.bold)
              .size(context.font.larger)
              .centerAlign(),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [
              // حقل البحث (مع key + CompositedTransformTarget)
              Container(
                key: _searchBoxKey,
                child: CompositedTransformTarget(
                  link: _searchLink,
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: "ابحث عن عنوان…",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: (_searchCtrl.text.isNotEmpty)
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _suggestions = []);
                        },
                      )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onTap: _updateSearchBoxSize,
                    onChanged: (q) {
                      _updateSearchBoxSize();
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () async {
                        if (q.trim().length < 2) {
                          setState(() => _suggestions = []);
                          return;
                        }
                        setState(() => _loadingSuggestions = true);
                        try {
                          final res = await _placesAutocomplete(q);
                          if (mounted) setState(() => _suggestions = res);
                        } finally {
                          if (mounted) setState(() => _loadingSuggestions = false);
                        }
                      });
                    },
                    onSubmitted: (_) => _dismissKeyboard(),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }














  Widget _buildMapStack() {
    return Stack(
      children: [
        // الخريطة
        _buildGoogleMapCard(),

        // الدبوس الثابت في المنتصف
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: AnimatedScale(
                scale: _isMoving ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: _centerPin(),
              ),
            ),
          ),
        ),

        // تلميحات ذكية تحت الدبوس
        Positioned.fill(
          child: SmartHintOverlay(controller: _hint),
        ),

        // أزرار التحكم
        _buildMapControls(),


        // لودينغ اختياري
        if (_reverseLoading)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
      ],
    );
  }









  Widget _buildGoogleMapCard() {
    final bottomPad = MediaQuery.of(context).padding.bottom + 72;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: GoogleMap(
          padding: EdgeInsets.only(bottom: bottomPad),
          initialCameraPosition: _cameraPosition!,
          mapType: _mapType,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: true,
          indoorViewEnabled: true,
          mapToolbarEnabled: true,
          minMaxZoomPreference: const MinMaxZoomPreference(0, 20),
          gestureRecognizers: getMapGestureRecognizers(),

          // الماركر صار Overlay ثابت، ما نستخدم markers هنا

          onMapCreated: (c) async {
            _mapController = c;
            _mapController.animateCamera(
              CameraUpdate.newCameraPosition(_cameraPosition!),
            );
            await _applyMapStyle();
          },

          onCameraMoveStarted: () {
            _dismissKeyboard();
            if (!_isMoving) setState(() => _isMoving = true);
            _hint.onMoveStart(); // 🔔 بدء حركة
          },

          onCameraMove: (pos) {
            _cameraPosition = pos;
            _hint.onMove(zoom: pos.zoom); // 🔔 قراءة الزوم أثناء الحركة
          },
          onTap: (_) => _dismissKeyboard(),

          onCameraIdle: () {
            _hint.onIdle(); // 🔔 سكون الكاميرا

            _idleDebounce?.cancel();
            _idleDebounce = Timer(const Duration(milliseconds: 250), () async {
              final t = _cameraPosition?.target;
              if (t == null) return;

              final same = (latitude != null && longitude != null) &&
                  (LatLng(latitude!, longitude!) == LatLng(t.latitude, t.longitude));
              if (same) {
                if (mounted) setState(() => _isMoving = false);
                return;
              }

              if (mounted) {
                setState(() {
                  _reverseLoading = true;
                  latitude = t.latitude;
                  longitude = t.longitude;
                });
              }

              _hint.onReverseStart(); // 🔔 بدء جلب العنوان

              await getLocationFromLatitudeLongitude(latLng: LatLng(t.latitude, t.longitude));

              final ok = mounted && (formatedAddress?.mixed.isNotEmpty == true);

              if (!mounted) return;
              setState(() {
                _reverseLoading = false;
                _isMoving = false;
              });

              HapticFeedback.selectionClick();
              _hint.onReverseDone(success: ok); // 🔔 نتيجة الجلب
            });
          },
        ),
      ),
    );
  }






  Widget _buildMapControls() {
    const spacing = 12.0;

    final color = Theme.of(context).colorScheme;
    final isHybrid = _mapType == MapType.hybrid;


    return Positioned(
      bottom: 16,
      right: 16,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildMapControlButton(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _mapType = isHybrid ? MapType.normal : MapType.hybrid;
                });
              },
              backgroundColor: isHybrid ? color.primary : color.surface,
              borderColor: isHybrid
                  ? color.primary.withOpacity(.6)
                  : color.outline.withOpacity(.6),
              child: Icon(
                Icons.layers,
                color: isHybrid ? color.onPrimary : color.primary,
              ),
            ),
            const SizedBox(height: spacing),
            _buildMyLocationControl(),
            const SizedBox(height: spacing),
            _buildMapControlButton(
              onTap: () => _animateZoom(zoomIn: true),
              child: Icon(Icons.add, color: color.primary),
            ),
            const SizedBox(height: spacing),
            _buildMapControlButton(
              onTap: () => _animateZoom(zoomIn: false),
              child: Icon(Icons.remove, color: color.primary),
            ),
          ],
        ),
      ),
    );
  }









  Widget _buildMyLocationControl() {
    final cs = Theme.of(context).colorScheme;

    Future<void> _goToMyLocation() async {
      if (_locating) return;
      HapticFeedback.selectionClick();
      setState(() => _locating = true);

      try {
        // فحص الأذونات
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
          if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
            HelperUtils.showSnackBarMessage(context, 'لم يتم منح إذن الموقع');
            setState(() => _locating = false);
            return;
          }
        }

        // جلب الموقع الحالي
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        latitude = pos.latitude;
        longitude = pos.longitude;

        final target = LatLng(latitude!, longitude!);
        _cameraPosition = buildCamera(target);
        await _mapController.animateCamera(CameraUpdate.newCameraPosition(_cameraPosition!));

        // تحديث العنوان
        await getLocationFromLatitudeLongitude(latLng: target);

        // تنبيه نجاح
        HelperUtils.showSnackBarMessage(context, 'تم تحديد موقعك بنجاح');

        HapticFeedback.lightImpact();
      } catch (e) {
        // خطأ عام
        HelperUtils.showSnackBarMessage(context, 'حدث خطأ أثناء تحديد الموقع');
      } finally {
        if (mounted) setState(() => _locating = false);
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: _buildMapControlButton(
        key: ValueKey(_locating),
        onTap: _goToMyLocation,
        backgroundColor: cs.surface,
        gradient: _locating
            ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withOpacity(.18), cs.primary.withOpacity(.10)],
        )
            : null,
        borderColor: _locating ? cs.primary.withOpacity(.35) : cs.outline.withOpacity(.6),
        child: Stack(
            alignment: Alignment.center,
            children: [
        AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _locating ? 0.0 : 1.0,
        child: Icon(Icons.my_location_rounded, color: cs.primary),
      ),
      AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _locating ? 1.0 : 0.0,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            ],
        ),
      ),
    );
  }

  Widget _buildMapControlButton({
    Key? key,
    required VoidCallback? onTap,
    required Widget child,
    Color? backgroundColor,
    Gradient? gradient,
    Color? borderColor,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      key: key,
      color: Colors.transparent,
      elevation: 6,
      shape: const CircleBorder(),
      shadowColor: cs.primary.withOpacity(.25),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            color: gradient == null ? (backgroundColor ?? cs.surface) : null,
            border: Border.all(
              color: borderColor ?? cs.outline.withOpacity(.6),
              width: 1,
            ),

          ),
          child: Center(child: child),

        ),
      ),
    );
  }



  Future<void> _animateZoom({required bool zoomIn}) async {
    try {
      final currentZoom = await _mapController.getZoomLevel();
      const double minZoom = 0.0;
      const double maxZoom = 20.0;

      if (zoomIn && currentZoom >= maxZoom) {
        HapticFeedback.selectionClick();
        return;
      }
      if (!zoomIn && currentZoom <= minZoom) {
        HapticFeedback.selectionClick();
        return;
      }

      HapticFeedback.selectionClick();
      await _mapController.animateCamera(
        zoomIn ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut(),
      );
    } catch (_) {
      // تجاهل أي أخطاء أثناء تحريك الكاميرا
    }
  }





  Widget _centerPin() {
    final color = Theme.of(context).colorScheme;

    return IgnorePointer(
      ignoring: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // دبوس بنبضة خفيفة
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: _isMoving ? 1.06 : 1.0),
              duration: const Duration(milliseconds: 160),
              builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
              child: CustomPaint(
                size: const Size(32, 46),
                painter: _PinPainter(
                  fill: color.primary,
                  border: color.onPrimary.withOpacity(.95),
                  shadow: color.primary.withOpacity(.35),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // ظل أرضي
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: _isMoving ? 28 : 22,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }








  Widget _buildAddressCard() {
    return Container(
      width: context.screenWidth,
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon box
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: context.color.territoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(width: Constant.borderWidth, color: context.color.borderColor),
            ),
            child: SizedBox(
              width: 8.11,
              height: 5.67,
              child: SvgPicture.asset(
                AppIcons.location,
                fit: BoxFit.none,
                colorFilter: ColorFilter.mode(context.color.territoryColor, BlendMode.srcIn),
              ),
            ),
          ),
          SizedBox(width: 10.rw(context)),
          // Texts
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatedAddress == null
                    ? "____"
                    : (formatedAddress!.city == null || formatedAddress!.city!.isEmpty)
                    ? ((formatedAddress!.area?.isNotEmpty ?? false) ? formatedAddress!.area! : "____")
                    : ((formatedAddress!.area?.isNotEmpty ?? false)
                    ? "${formatedAddress!.area!}, ${formatedAddress!.city!}"
                    : formatedAddress!.city!),
              ).size(context.font.large),
              const SizedBox(height: 4),
              Text(
                "${(formatedAddress?.state?.isNotEmpty ?? false) ? formatedAddress!.state! : "____"},"
                    "${(formatedAddress?.country?.isNotEmpty ?? false) ? formatedAddress!.country! : "____"}",
              ),
            ],
          ),
        ],
      ),
    );
  }






  // ==========================
  // Shimmer
  // ==========================



  Widget shimmerEffect() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
          highlightColor: Theme.of(context).colorScheme.shimmerHighlightColor,
          child: Container(
            height: 50,
            alignment: AlignmentDirectional.center,
            margin: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Shimmer.fromColors(
            baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
            highlightColor: Theme.of(context).colorScheme.shimmerHighlightColor,
            child: Container(
              height: 400,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Shimmer.fromColors(
            baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
            highlightColor: Theme.of(context).colorScheme.shimmerHighlightColor,
            child: Container(
              height: 146,
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }


  // ==========================
  // (اختياري) دوال لاحقة للفصل الدقيق
  // ==========================




  // ==========================
// Dialogs (moved to UI extension)
// ==========================




  void dialogueBottomSheet({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required int from,
  }) async {
    await UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        content: dialogueWidget(title, controller, hintText),
        acceptButtonName: "add".translate(context),
        isAcceptContainesPush: true,
        onAccept: () => Future.value().then((_) {
          if (_formKey.currentState!.validate()) {
            setState(() {
              if (formatedAddress != null) {
                // Update existing formatedAddress
                if (from == 1) {
                  formatedAddress = AddressComponent.copyWithFields(
                    formatedAddress!,
                    newCity: controller.text,
                  );
                } else if (from == 2) {
                  formatedAddress = AddressComponent.copyWithFields(
                    formatedAddress!,
                    newState: controller.text,
                  );
                } else if (from == 3) {
                  formatedAddress = AddressComponent.copyWithFields(
                    formatedAddress!,
                    newCountry: controller.text,
                  );
                }
              } else {
                // Create new AddressComponent if null
                if (from == 1) {
                  formatedAddress = AddressComponent(
                    area: "",
                    areaId: null,
                    city: controller.text,
                    country: "",
                    state: "",
                  );
                } else if (from == 2) {
                  formatedAddress = AddressComponent(
                    area: "",
                    areaId: null,
                    city: "",
                    country: "",
                    state: controller.text,
                  );
                } else if (from == 3) {
                  formatedAddress = AddressComponent(
                    area: "",
                    areaId: null,
                    city: "",
                    country: controller.text,
                    state: "",
                  );
                }
              }
              Navigator.pop(context);
            });
          }
        }),
      ),
    );
  }





  Widget dialogueWidget(
      String title,
      TextEditingController controller,
      String hintText,
      ) {
    final bottomPadding = (MediaQuery.of(context).viewInsets.bottom - 50);
    final isBottomPaddingNegative = bottomPadding.isNegative;

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title).size(context.font.larger).centerAlign().bold(),
              Divider(
                thickness: 1,
                color: context.color.borderColor.darken(30),
              ),
              Padding(
                padding: EdgeInsetsDirectional.only(
                  bottom: isBottomPaddingNegative ? 0 : bottomPadding,
                  start: 20,
                  end: 20,
                  top: 18,
                ),
                child: TextFormField(
                  maxLines: null,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor.withOpacity(0.5),
                  ),
                  controller: controller,
                  cursorColor: context.color.territoryColor,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return Validator.nullCheckValidator(val, context: context);
                    } else {
                      return null;
                    }
                  },
                  decoration: InputDecoration(
                    fillColor: context.color.borderColor.darken(20),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 10,
                    ),
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor.withOpacity(0.5),
                    ),
                    focusColor: context.color.territoryColor,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: context.color.borderColor.darken(60),
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: context.color.borderColor.darken(60),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: context.color.territoryColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }




// ==========================
// GPS Permission Dialog (UI)
// ==========================
  void showGPSPermissionError() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("فشل تحديد الموقع"),
        content: const Text("لم نتمكن من الوصول لموقعك. تأكد من تفعيل GPS ومنح الإذن."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _getCurrentLocation(); // إعادة المحاولة
            },
            child: const Text("🔁 إعادة المحاولة"),
          ),
          TextButton(
            onPressed: () {
              _openedAppSettings = true; // نحتاجها لـ didChangeAppLifecycleState
              openAppSettings();         // من permission_handler
            },
            child: const Text("⚙️ الإعدادات"),
          ),
        ],
      ),
    );
  }









  PreferredSizeWidget _buildAppBar() => AppBar(title: const Text('تأكيد الموقع'));
  Widget _buildMapSection() => const SizedBox.shrink();
  Widget _buildAddressForm() => const SizedBox.shrink();
  Widget _buildActionButtons() => const SizedBox.shrink();
}


// --------- نماذج بيانات داخل نفس الملف (بسيطة) ---------
class _PlaceSuggestion {
  final String placeId; // أو osmId
  final String title;
  final String? subtitle;

  _PlaceSuggestion({
    required this.placeId,
    required this.title,
    this.subtitle,
  });
}

class _PlaceDetails {
  final double lat, lng;
  final String? area, city, state, country;

  _PlaceDetails({
    required this.lat,
    required this.lng,
    this.area,
    this.city,
    this.state,
    this.country,
  });
}





class _PinPainter extends CustomPainter {
  final Color fill, border, shadow;
  _PinPainter({required this.fill, required this.border, required this.shadow});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w / 2, h * 0.42);

    // ظل خفيف
    final shadowPaint = Paint()..color = shadow..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center.translate(0, 2), 10, shadowPaint);

    // شكل الدبوس: قطرة + سن سفلي
    final path = Path()
      ..moveTo(w / 2, h) // السن
      ..quadraticBezierTo(w * 0.82, h * 0.68, w * 0.82, h * 0.42)
      ..arcToPoint(Offset(w * 0.18, h * 0.42), radius: Radius.circular(w), clockwise: false)
      ..quadraticBezierTo(w * 0.18, h * 0.68, w / 2, h)
      ..close();

    final fillPaint = Paint()..color = fill;
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // دائرة داخلية صغيرة توضح المركز
    final inner = Paint()..color = Colors.white.withOpacity(.9);
    canvas.drawCircle(center, 4, inner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
