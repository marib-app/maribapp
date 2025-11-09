import 'dart:io';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ManageItemType { add, edit, delete }

abstract class ManageItemState {}

class ManageItemInitial extends ManageItemState {}

class ManageItemInProgress extends ManageItemState {}

class ManageItemSuccess extends ManageItemState {
  final ManageItemType type;
  final ItemModel model;

  ManageItemSuccess(this.model, this.type);
}

class ManageItemFail extends ManageItemState {
  final dynamic error;

  ManageItemFail(this.error);
}

class ManageItemCubit extends Cubit<ManageItemState> {
  ManageItemCubit() : super(ManageItemInitial());
  final ItemRepository _itemRepository = ItemRepository();

  void manage(
    ManageItemType type,
    Map<String, dynamic> data,
    File? mainImage,
    List<File>? otherImage,
  ) async {
    try {
      emit(ManageItemInProgress());


      final List<File>? galleryImages =
          otherImage == null || otherImage.isEmpty
              ? null
              : List<File>.from(otherImage);

      if (type == ManageItemType.add) {
        if (mainImage == null) {
          throw ArgumentError('mainImage is required when creating an item.');
        }

        final ItemModel itemModel = await _itemRepository.createItem(
          data,
          mainImage,
          galleryImages,
        );
        emit(ManageItemSuccess(itemModel, type));
      } else if (type == ManageItemType.edit) {
        final ItemModel itemModel = await _itemRepository.editItem(
          data,
          mainImage,
          galleryImages,
        );
        emit(ManageItemSuccess(itemModel, type));
      }
    } catch (e) {
      emit(ManageItemFail(e));
    }
  }
}
