// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'dart:convert';

import 'package:marib/utils/helper_utils.dart';
import 'package:marib/data/repositories/category_repository.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FetchSubCategoriesState {}

class FetchSubCategoriesInitial extends FetchSubCategoriesState {}

class FetchSubCategoriesInProgress extends FetchSubCategoriesState {}

class FetchSubCategoriesSuccess extends FetchSubCategoriesState {
  final int total;
  final int page;
  final bool isLoadingMore;
  final bool hasError;
  final List<CategoryModel> categories;
  final bool onlyAllowed;
  final List<int>? allowedCategoryIds;
  final List<int>? ensureCategoryIds;

  FetchSubCategoriesSuccess({
    required this.total,
    required this.page,
    required this.isLoadingMore,
    required this.hasError,
    required this.categories,
    this.onlyAllowed = false,
    this.allowedCategoryIds,
    this.ensureCategoryIds,
  });

  FetchSubCategoriesSuccess copyWith({
    int? total,
    int? page,
    bool? isLoadingMore,
    bool? hasError,
    List<CategoryModel>? categories,
    bool? onlyAllowed,
    List<int>? allowedCategoryIds,
    List<int>? ensureCategoryIds,
  }) {
    return FetchSubCategoriesSuccess(
      total: total ?? this.total,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
      categories: categories ?? this.categories,
      onlyAllowed: onlyAllowed ?? this.onlyAllowed,
      allowedCategoryIds: allowedCategoryIds ?? this.allowedCategoryIds,
      ensureCategoryIds: ensureCategoryIds ?? this.ensureCategoryIds,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'total': total,
      ' page': page,
      'isLoadingMore': isLoadingMore,
      'hasError': hasError,
      'categories': categories.map((x) => x.toJson()).toList(),
      'onlyAllowed': onlyAllowed,
      'allowedCategoryIds': allowedCategoryIds,
      'ensureCategoryIds': ensureCategoryIds,
    };
  }

  factory FetchSubCategoriesSuccess.fromMap(Map<String, dynamic> map) {
    return FetchSubCategoriesSuccess(
      total: map['total'] as int,
      page: map[' page'] as int,
      isLoadingMore: map['isLoadingMore'] as bool,
      hasError: map['hasError'] as bool,
      categories: List<CategoryModel>.from(
        (map['categories']).map<CategoryModel>(
          (x) => CategoryModel.fromJson(x as Map<String, dynamic>),
        ),
      ),
      onlyAllowed: map['onlyAllowed'] as bool? ?? false,
      allowedCategoryIds: (map['allowedCategoryIds'] as List<dynamic>?)
          ?.map((dynamic e) => e as int)
          .toList(),
      ensureCategoryIds: (map['ensureCategoryIds'] as List<dynamic>?)
          ?.map((dynamic e) => e as int)
          .toList(),
    );
  }

  String toJson() => json.encode(toMap());

  factory FetchSubCategoriesSuccess.fromJson(String source) =>
      FetchSubCategoriesSuccess.fromMap(
          json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'FetchSubCategoriesSuccess(total: $total,  page: $page, isLoadingMore: $isLoadingMore, hasError: $hasError, onlyAllowed: $onlyAllowed, allowedCategoryIds: $allowedCategoryIds, ensureCategoryIds: $ensureCategoryIds, categories: $categories)';
  }
}

class FetchSubCategoriesFailure extends FetchSubCategoriesState {
  final String errorMessage;

  FetchSubCategoriesFailure(this.errorMessage);
}

class FetchSubCategoriesCubit extends Cubit<FetchSubCategoriesState> {
  FetchSubCategoriesCubit() : super(FetchSubCategoriesInitial());

  final CategoryRepository _categoryRepository = CategoryRepository();
  int? _activeCategoryId;

  Future<void> fetchSubCategories({
    bool? forceRefresh,
    bool? loadWithoutDelay,
    required int categoryId,
    bool onlyAllowed = false,
    Iterable<int> allowedCategoryIds = const <int>[],
    Iterable<int> ensureCategoryIds = const <int>[],
  }) async {
    try {
      emit(FetchSubCategoriesInProgress());
      _activeCategoryId = categoryId;

      final List<int> normalizedAllowed =
          _normalizeCategoryIds(allowedCategoryIds);
      final List<int> normalizedEnsure =
          _normalizeCategoryIds(ensureCategoryIds);

      DataOutput<CategoryModel> categories = await _categoryRepository
          .fetchCategories(
              page: 1,
              categoryId: categoryId,
              onlyAllowed: onlyAllowed,
              allowedCategoryIds: normalizedAllowed,
              ensureCategoryIds: normalizedEnsure);


      final List<CategoryModel> sanitizedCategories =
      _sanitizeCategoryList(categories.modelList);

      emit(FetchSubCategoriesSuccess(
          total: categories.total,
          categories: sanitizedCategories,
          page: 1,
          hasError: false,
          isLoadingMore: false,
          onlyAllowed: onlyAllowed,
          allowedCategoryIds: normalizedAllowed.isEmpty
              ? null
              : List<int>.from(normalizedAllowed),
          ensureCategoryIds: normalizedEnsure.isEmpty
              ? null
              : List<int>.from(normalizedEnsure)));
    } catch (e) {
      _activeCategoryId = null;
      emit(FetchSubCategoriesFailure(e.toString()));
    }
  }

  List<CategoryModel> getSubCategories() {
    if (state is FetchSubCategoriesSuccess) {
      return (state as FetchSubCategoriesSuccess).categories;
    }

    return <CategoryModel>[];
  }

  Future<void> fetchSubCategoriesMore() async {
    try {
      if (state is FetchSubCategoriesSuccess) {
        final FetchSubCategoriesSuccess current =
            state as FetchSubCategoriesSuccess;
        if (current.isLoadingMore) {
          return;
        }
        emit(current.copyWith(isLoadingMore: true));
        DataOutput<CategoryModel> result =
            await _categoryRepository.fetchCategories(
          page: current.page + 1,
          categoryId: _activeCategoryId,
          onlyAllowed: current.onlyAllowed,
          allowedCategoryIds: current.allowedCategoryIds ?? const <int>[],
          ensureCategoryIds: current.ensureCategoryIds ?? const <int>[],
        );

        final List<CategoryModel> updatedCategories =
        List<CategoryModel>.from(current.categories)
          ..addAll(_sanitizeCategoryList(result.modelList));

        final List<String> list =
        updatedCategories.map((e) => e.url).whereType<String>().toList();

        await HelperUtils.precacheSVG(list);

        emit(FetchSubCategoriesSuccess(
            isLoadingMore: false,
            hasError: false,
            categories: updatedCategories,
            page: current.page + 1,
            total: result.total,
            onlyAllowed: current.onlyAllowed,
            allowedCategoryIds: current.allowedCategoryIds,
            ensureCategoryIds: current.ensureCategoryIds));
      }
    } catch (e) {
      emit((state as FetchSubCategoriesSuccess)
          .copyWith(isLoadingMore: false, hasError: true));
    }
  }


  List<CategoryModel> _sanitizeCategoryList(List<CategoryModel> raw) {
    if (raw.isEmpty) {
      return const <CategoryModel>[];
    }

    final List<CategoryModel> sanitized = <CategoryModel>[];
    final Set<int?> seenIds = <int?>{};

    for (final CategoryModel category in raw) {
      final int? id = category.id;

      if (id != null && _activeCategoryId != null && id == _activeCategoryId) {
        continue;
      }

      if (!seenIds.add(id)) {
        continue;
      }

      sanitized.add(category);
    }

    return sanitized;
  }


  bool hasMoreData() {
    if (state is FetchSubCategoriesSuccess) {
      return (state as FetchSubCategoriesSuccess).categories.length <
          (state as FetchSubCategoriesSuccess).total;
    }
    return false;
  }

  @override
  FetchSubCategoriesState? fromJson(Map<String, dynamic> json) {
    return null;
  }

  @override
  Map<String, dynamic>? toJson(FetchSubCategoriesState state) {
    return null;
  }

  List<int> _normalizeCategoryIds(Iterable<int> ids) {
    final Set<int> normalized = <int>{};
    for (final int id in ids) {
      if (id > 0) {
        normalized.add(id);
      }
    }
    if (normalized.isEmpty) {
      return const <int>[];
    }
    return List<int>.unmodifiable(normalized);
  }
}
