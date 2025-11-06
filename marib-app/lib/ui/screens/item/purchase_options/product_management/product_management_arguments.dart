import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/item/purchase_options/pending_item_draft.dart';

class ProductManagementArguments {
  const ProductManagementArguments({
    required this.item,
    this.pendingDraft,
  });

  final ItemModel item;
  final PendingItemDraft? pendingDraft;

  factory ProductManagementArguments.from(dynamic arguments) {
    PendingItemDraft? draft;
    ItemModel? item;

    if (arguments is PendingItemDraft) {
      draft = arguments;
      item = draft.item;
    } else if (arguments is ItemModel) {
      item = arguments;
    } else if (arguments is Map) {
      final dynamic draftCandidate =
          arguments['pendingDraft'] ?? arguments['draft'];
      if (draftCandidate is PendingItemDraft) {
        draft = draftCandidate;
      }

      final dynamic itemCandidate = arguments['item'] ?? arguments['model'];
      if (itemCandidate is ItemModel) {
        item = itemCandidate;
      }

      if (item == null && draft != null) {
        item = draft.item;
      }
    }

    if (draft != null && item == null) {
      item = draft.item;
    }

    if (item == null) {
      throw ArgumentError(
        'ProductManagementScreen expects an ItemModel or PendingItemDraft.',
      );
    }

    return ProductManagementArguments(
      item: item!,
      pendingDraft: draft,
    );
  }
}