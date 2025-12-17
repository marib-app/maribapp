import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:image_picker/image_picker.dart';

import 'package:marib/data/cubits/item/manage_item_cubit.dart';

import 'package:marib/data/model/category_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_initialization_service.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_keyboard_manager.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_shein_service.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_submission.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_view.dart';
import 'package:marib/ui/screens/item/add_item_screen/image_section.dart';

import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';

import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/constant.dart';

import 'package:marib/utils/extensions/extensions.dart';

import 'package:marib/utils/imagePicker.dart';

import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/theme/theme.dart';

class AddItemDetails extends StatefulWidget {
  const AddItemDetails({
    super.key,
    this.breadCrumbItems,
    required this.isEdit,
  });

  final List<CategoryModel>? breadCrumbItems;
  final bool? isEdit;

  static Route route(RouteSettings settings) {
    final Map<String, dynamic>? arguments =
        settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (BuildContext context) {
        return BlocProvider<ManageItemCubit>(
          create: (_) => ManageItemCubit(),
          child: AddItemDetails(
            breadCrumbItems:
                arguments?['breadCrumbItems'] as List<CategoryModel>?,
            isEdit: arguments?['isEdit'] as bool?,
          ),
        );
      },
    );
  }

  @override
  CloudState<AddItemDetails> createState() => AddItemDetailsState();
}

class AddItemDetailsState extends CloudState<AddItemDetails>
    with ImageSectionMixin<AddItemDetails>, WidgetsBindingObserver {
  late final AddItemDetailsModel model;
  late final AddItemDetailsKeyboardManager keyboardManager;
  late final AddItemDetailsInitializationService initializationService;
  late final AddItemDetailsSubmissionService submissionService;
  late final AddItemDetailsSheinService sheinService;

  @override
  PageController get imageSectionPageController =>
      model.imageSectionPageController;

  @override
  void initState() {
    super.initState();
    model = AddItemDetailsModel(
      breadcrumbItems: widget.breadCrumbItems,
      isEdit: widget.isEdit,
    );
    keyboardManager = AddItemDetailsKeyboardManager(
      formScrollController: model.formScrollController,
    );
    initializationService = AddItemDetailsInitializationService(
      model: model,
      state: this,
      refresh: _refresh,
      onSheinCategoryChanged: _updateSheinCategoryFlag,
    );
    initializationService.initialize();

    submissionService = AddItemDetailsSubmissionService(
      model: model,
      state: this,
      refresh: _refresh,
      onSheinCategoryChanged: _updateSheinCategoryFlag,
    );

    sheinService = AddItemDetailsSheinService(
      model: model,
      refresh: _refresh,
    );

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    initializationService.dispose();
    model.dispose();

    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    keyboardManager.handleMetricsChanged(this);
  }

  void _updateSheinCategoryFlag(Iterable<int> ids, {bool notify = true}) {
    final bool next = ids.any((int id) => id == Constant.sheinRootCategoryId);
    if (model.isSheinCategory != next && !next) {
      model.reviewLinkController.clear();
      model.adProductLinkController.clear();
    }
    if (!notify) {
      model.isSheinCategory = next;
      return;
    }

    if (model.isSheinCategory != next) {
      if (mounted) {
        setState(() => model.isSheinCategory = next);
      } else {
        model.isSheinCategory = next;
      }
    }
  }

  Future<void> _pickCoverImage() async {
    await model.coverImagePicker.pick(
      context: context,
      pickMultiple: false,
      source: ImageSource.gallery,
    );

    // Debug: log what the picker emitted and refresh UI immediately.
    if (kDebugMode) {
      try {
        // ignore: avoid_print
        print('[debug] _pickCoverImage after pick -> pickedFile=${model.coverImagePicker.pickedFile} lastPayload=${model.coverImagePicker.lastPayload}');
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  Future<void> _pickGalleryImage(ImageSource source) async {
    setState(() => model.isUploadingGallery = true);
    try {
      await model.galleryPicker.pick(
        context: context,
        pickMultiple: true,
        source: source,
        imageLimit: 25,
        maxLength: model.galleryItems.length,
      );
      if (kDebugMode) {
        try {
          // ignore: avoid_print
          print('[debug] _pickGalleryImage after pick -> galleryPicker.pickedFile=${model.galleryPicker.pickedFile} lastPayload=${model.galleryPicker.lastPayload}');
        } catch (_) {}
      }
    } finally {
      if (!mounted) {
        model.isUploadingGallery = false;
        return;
      }
      setState(() => model.isUploadingGallery = false);
    }
  }

  void _removeGalleryImage(int index) {
    setState(() {
      final dynamic removed = model.galleryItems[index];
      if (removed is Map) {
        final dynamic rawId = removed['id'];
        final int? imageId = rawId is int
            ? rawId
            : (rawId is String ? int.tryParse(rawId) : null);
        if (imageId != null && !model.deletedImageIds.contains(imageId)) {
          model.deletedImageIds.add(imageId);
        }
        if (removed['isMain'] == true ||
            removed['url'] == model.coverImageUrl) {
          model.coverImageUrl = '';
        }
      } else if (removed is File &&
          model.coverImagePicker.pickedFile == removed) {
        model.coverImagePicker.pickedFile = null;
      }
      model.galleryItems.removeAt(index);
    });
  }

  void _handleSubmit() {
    submissionService.handleSubmit(context);
  }

  void _handleManageItemState(BuildContext context, ManageItemState state) {
    submissionService.handleManageItemState(context, state);
  }

  void _onBreadcrumbTap(int index) {
    final List<CategoryModel> items = model.breadcrumbItems;
    if (items.isEmpty) {
      return;
    }
    final int safeIndex = index.clamp(0, items.length - 1);
    final int popTimes = (items.length - 1) - safeIndex;
    final int totalPops = popTimes <= 0 ? 1 : popTimes;
    for (int i = 0; i < totalPops; i++) {
      if (!Navigator.of(context).canPop()) {
        break;
      }
      Navigator.of(context).pop();
    }
  }

  Widget _buildGallerySection({
    required BuildContext context,
    required List<dynamic> mixedItemImageList,
    required bool isUploadingExtra,
    required PickImage itemImagePicker,
    required void Function(ImageSource source) onPick,
    required void Function(int index) onRemove,
  }) {
    return itemImagesListener(
      context: context,
      mixedItemImageList: mixedItemImageList,
      isUploadingExtra: isUploadingExtra,
      itemImagePicker: itemImagePicker,
      onPick: onPick,
      onRemove: onRemove,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: MultiBlocListener(
        listeners: <BlocListener<dynamic, dynamic>>[
          BlocListener<ManageItemCubit, ManageItemState>(
            listener: _handleManageItemState,
          ),
        ],
        child: AddItemDetailsView(
          model: model,
          keyboardManager: keyboardManager,
          submissionService: submissionService,
          sheinService: sheinService,
          galleryBuilder: ({
            required BuildContext context,
            required List<dynamic> mixedItemImageList,
            required bool isUploadingExtra,
            required dynamic itemImagePicker,
            required void Function(ImageSource source) onPick,
            required void Function(int index) onRemove,
          }) {
            return _buildGallerySection(
              context: context,
              mixedItemImageList: mixedItemImageList,
              isUploadingExtra: isUploadingExtra,
              itemImagePicker: itemImagePicker as PickImage,
              onPick: onPick,
              onRemove: onRemove,
            );
          },
          onSubmit: _handleSubmit,
          onRefresh: _refresh,
          onPickCoverImage: _pickCoverImage,
          onPickGalleryImage: _pickGalleryImage,
          onRemoveGalleryImage: _removeGalleryImage,
          onBreadcrumbTap: _onBreadcrumbTap,
        ),
      ),
    );
  }
}