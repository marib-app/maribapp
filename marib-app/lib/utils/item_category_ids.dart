import 'dart:collection';

import 'package:marib/data/model/item/item_model.dart';

/// Collects every numeric category identifier that belongs to [item].
///
/// The API sometimes sends the ancestor ids as bracketed or JSON strings
/// (e.g. "[1, 2, 3]" or "[\"1\",\"2\"]"), so we rely on a digit regex
/// to capture every occurrence and keep them in insertion order. The item's
/// direct `categoryId` and nested `category?.id` are appended afterwards to
/// make sure we always include the primary category as well.
List<int> buildItemCategoryIds(ItemModel item) {
  final ids = LinkedHashSet<int>();

  final raw = item.allCategoryIds;
  if (raw != null && raw.trim().isNotEmpty) {
    for (final match in RegExp(r'\d+').allMatches(raw)) {
      final value = match.group(0);
      final parsed = value == null ? null : int.tryParse(value);
      if (parsed != null) {
        ids.add(parsed);
      }
    }
  }

  final primaryId = item.categoryId;
  if (primaryId != null) {
    ids.add(primaryId);
  }

  final nestedId = item.category?.id;
  if (nestedId != null) {
    ids.add(nestedId);
  }

  return ids.toList(growable: false);
}
