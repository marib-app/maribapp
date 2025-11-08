import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'merchant_location_picker_screen.dart';

class ActivityInfoData {
  final String storeName;
  final String description;
  final String address;
  final double? latitude;
  final double? longitude;
  final File? logo;

  ActivityInfoData({
    required this.storeName,
    required this.description,
    required this.address,
    required this.longitude,
    required this.latitude,
    required this.logo,
  });
}

class Phase1ActivityInfo extends StatefulWidget {
  final void Function(ActivityInfoData data) onNext;

  const Phase1ActivityInfo({super.key, required this.onNext});

  @override
  State<Phase1ActivityInfo> createState() => _Phase1ActivityInfoState();
}

class _Phase1ActivityInfoState extends State<Phase1ActivityInfo> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _isReady = false;
  bool _locationLoading = false;
  File? _logoFile;
  double? _latitude;
  double? _longitude;

  Future<void> _prepare() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _isReady = true;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepare();
    });
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final XFile? selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (selected != null) {
      setState(() {
        _logoFile = File(selected.path);
      });
    }
  }

  Future<void> _openLocationPicker() async {
    setState(() => _locationLoading = true);
    try {
      final result = await Navigator.of(context).push<MerchantLocationPickerResult>(
        MaterialPageRoute(
          builder: (_) => MerchantLocationPickerScreen(
            initialPosition: (_latitude != null && _longitude != null)
                ? LatLng(_latitude!, _longitude!)
                : null,
          ),
        ),
      );

      if (result != null) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
          _addressCtrl.text = result.address ?? '';
        });
      }
    } catch (_) {
      HelperUtils.showSnackBarMessage(
        context,
        "errorGettingLocation".translate(context),
        messageDuration: 3,
      );
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _onNext() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    widget.onNext(ActivityInfoData(
      storeName: _storeNameCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      logo: _logoFile,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.color;
    if (!_isReady) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: const [
          ShimmerBox(height: 40),
          SizedBox(height: 12),
          ShimmerBox(height: 120),
          SizedBox(height: 12),
          ShimmerBox(height: 56),
          SizedBox(height: 12),
          ShimmerBox(height: 56),
        ],
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("phase1_title".translate(context))
                  .size(context.font.extraLarge)
                  .color(theme.textDefaultColor)
                  .bold(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _storeNameCtrl,
                decoration: InputDecoration(
                  labelText: "storeName".translate(context),
                  fillColor: theme.secondaryColor,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "requiredField".translate(context);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.borderColor),
                    color: theme.secondaryColor,
                  ),
                  child: Center(
                    child: _logoFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_logoFile!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.upload_file,
                                  size: 34, color: theme.territoryColor),
                              const SizedBox(height: 8),
                              Text("uploadLogo".translate(context)),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: "storeDescription".translate(context),
                  hintText: "brieflyDescribeYourStore".translate(context),
                  fillColor: theme.secondaryColor,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "requiredField".translate(context);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "storeAddress".translate(context),
                  hintText: "enterPreciseAddress".translate(context),
                  fillColor: theme.secondaryColor,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "requiredField".translate(context);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              Text(
                "addressAffectsDelivery".translate(context),
                style: TextStyle(
                  color: theme.textColorDark.withOpacity(0.7),
                  fontSize: context.font.small,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _locationLoading ? null : _openLocationPicker,
                icon: _locationLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.map, color: theme.primaryColor),
                label: Text(
                  "setLocationOnMap".translate(context),
                  style: TextStyle(
                    color: theme.textDefaultColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.territoryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: UiUtils.buildButton(
            context,
            onPressed: _onNext,
            buttonTitle: "nextStage".translate(context),
            radius: 14,
            height: 48,
          ),
        ),
      ),
    );
  }
}
