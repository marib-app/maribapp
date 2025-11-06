import 'dart:async';
import 'dart:io';

import 'package:marib/data/cubits/item/manage_item_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/user_profile/my_item_tab.dart';

const Object _kSentinel = Object();

class PendingItemDraft {
  PendingItemDraft({
    required Map<String, dynamic> payload,
    required ItemModel item,
    required List<int> categoryPath,
    File? mainImage,
    List<File>? galleryImages,
    bool isEdit = false,
    String? editSourceKey,
  })  : payload = Map<String, dynamic>.unmodifiable(
          Map<String, dynamic>.from(payload),
        ),
        item = item,
        mainImage = mainImage,
        galleryImages = List<File>.unmodifiable(
          List<File>.from(galleryImages ?? const <File>[]),
        ),
        isEdit = isEdit,
        editSourceKey = editSourceKey,
        categoryPath = List<int>.unmodifiable(
          List<int>.from(categoryPath),
        );

  final Map<String, dynamic> payload;
  final ItemModel item;
  final File? mainImage;
  final List<File> galleryImages;
  final bool isEdit;
  final String? editSourceKey;
  final List<int> categoryPath;

  bool get requiresCreation => item.id == null;

  Map<String, dynamic> toMutablePayload() =>
      Map<String, dynamic>.from(payload);

  List<File> toMutableGallery() => List<File>.from(galleryImages);

  PendingItemDraft copyWith({
    Map<String, dynamic>? payload,
    ItemModel? item,
    Object? mainImage = _kSentinel,
    List<File>? galleryImages,
    bool? isEdit,
    Object? editSourceKey = _kSentinel,
    List<int>? categoryPath,
  }) {
    return PendingItemDraft(
      payload: payload ?? this.payload,
      item: item ?? this.item,
      mainImage: identical(mainImage, _kSentinel)
          ? this.mainImage
          : mainImage as File?,
      galleryImages: galleryImages ?? this.galleryImages,
      isEdit: isEdit ?? this.isEdit,
      editSourceKey: identical(editSourceKey, _kSentinel)
          ? this.editSourceKey
          : editSourceKey as String?,
      categoryPath: categoryPath ?? this.categoryPath,
    );
  }
}

Future<ItemModel> submitPendingItemDraft({
  required ManageItemCubit cubit,
  required PendingItemDraft draft,
}) {
  final ManageItemType type =
      draft.isEdit ? ManageItemType.edit : ManageItemType.add;

  if (type == ManageItemType.add && draft.mainImage == null) {
    return Future<ItemModel>.error(
      ArgumentError('Pending draft is missing a main image.'),
    );
  }

  final Completer<ItemModel> completer = Completer<ItemModel>();
  late final StreamSubscription<ManageItemState> subscription;

  subscription = cubit.stream.listen(
    (ManageItemState state) {
      if (state is ManageItemSuccess) {
        final String? editKey = draft.editSourceKey;
        if (editKey != null && editKey.isNotEmpty) {
          myAdsCubitReference[editKey]?.edit(state.model);
        }
        if (!completer.isCompleted) {
          completer.complete(state.model);
        }
        subscription.cancel();
      } else if (state is ManageItemFail) {
        if (!completer.isCompleted) {
          completer.completeError(state.error ?? Exception('manage-item-fail'));
        }
        subscription.cancel();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
  );

  cubit.manage(
    type,
    draft.toMutablePayload(),
    draft.mainImage,
    draft.toMutableGallery(),
  );

  return completer.future.whenComplete(() {
    if (!completer.isCompleted) {
      subscription.cancel();
    }
  });
}
