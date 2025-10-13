// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'dart:convert';

import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/repositories/category_repository.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

abstract class FetchCategoryState {}

class FetchCategoryInitial extends FetchCategoryState {}

class FetchCategoryInProgress extends FetchCategoryState {}

class FetchCategorySuccess extends FetchCategoryState {
  final int total;
  final int page;
  final bool isLoadingMore;
  final bool hasError;
  final List<CategoryModel> categories;
  final String? interfaceType;
  final int? categoryId;
  final List<int>? categoryIds;
  final bool onlyAllowed;
  final List<int>? ensureCategoryIds;


  FetchCategorySuccess({
    required this.total,
    required this.page,
    required this.isLoadingMore,
    required this.hasError,
    required this.categories,
    this.interfaceType,
    this.categoryId,
    this.categoryIds,
    this.onlyAllowed = false,
    this.ensureCategoryIds,
  });

  FetchCategorySuccess copyWith({
    int? total,
    int? page,
    bool? isLoadingMore,
    bool? hasError,
    List<CategoryModel>? categories,
    bool? onlyAllowed,
    List<int>? ensureCategoryIds,
  }) {
    return FetchCategorySuccess(
      total: total ?? this.total,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
      categories: categories ?? this.categories,
      interfaceType: interfaceType ?? this.interfaceType,
      categoryId: categoryId ?? this.categoryId,
      categoryIds: categoryIds ?? this.categoryIds,
      onlyAllowed: onlyAllowed ?? this.onlyAllowed,
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
      'interfaceType': interfaceType,
      'categoryId': categoryId,
      'categoryIds': categoryIds,
      'onlyAllowed': onlyAllowed,
      'ensureCategoryIds': ensureCategoryIds,
    };
  }

  factory FetchCategorySuccess.fromMap(Map<String, dynamic> map) {
    return FetchCategorySuccess(
      total: map['total'] as int,
      page: map[' page'] as int,
      isLoadingMore: map['isLoadingMore'] as bool,
      hasError: map['hasError'] as bool,
      categories: List<CategoryModel>.from(
        (map['categories']).map<CategoryModel>(
          (x) => CategoryModel.fromJson(x as Map<String, dynamic>),
        ),
      ),
      interfaceType: map['interfaceType'] as String?,
      categoryId: map['categoryId'] as int?,
      categoryIds: (map['categoryIds'] as List<dynamic>?)
          ?.map((dynamic e) => e as int)
          .toList(),
      onlyAllowed: map['onlyAllowed'] as bool? ?? false,
      ensureCategoryIds: (map['ensureCategoryIds'] as List<dynamic>?)
          ?.map((dynamic e) => e as int)
          .toList(),
    );
  }

  String toJson() => json.encode(toMap());

  factory FetchCategorySuccess.fromJson(String source) =>
      FetchCategorySuccess.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'FetchCategorySuccess(total: $total,  page: $page, isLoadingMore: $isLoadingMore, hasError: $hasError, interfaceType: $interfaceType, categoryId: $categoryId, categoryIds: $categoryIds, onlyAllowed: $onlyAllowed, ensureCategoryIds: $ensureCategoryIds, categories: $categories)';  }
}

class FetchCategoryFailure extends FetchCategoryState {
  final String errorMessage;

  FetchCategoryFailure(this.errorMessage);
}

class FetchCategoryCubit extends Cubit<FetchCategoryState> {
  FetchCategoryCubit({CategoryRepository? categoryRepository})
      : _categoryRepository = categoryRepository ?? CategoryRepository(),
        super(FetchCategoryInitial());
  final CategoryRepository _categoryRepository;


  Future<void> fetchCategories({
    bool? forceRefresh,
    bool? loadWithoutDelay,
    String? interfaceType,
    int? categoryId,
    List<int>? categoryIds,
    bool onlyAllowed = false,
    Iterable<int> ensureCategoryIds = const <int>[],
  }) async {
    final List<int> normalizedEnsureIds = ensureCategoryIds.toList();

    try {
      if (state is FetchCategorySuccess && forceRefresh != true) {
        final FetchCategorySuccess current = state as FetchCategorySuccess;
        final bool sameInterface =
        _sameInterface(current.interfaceType, interfaceType);
        final bool sameCategoryId = current.categoryId == categoryId;
        final bool sameCategoryIds = listEquals(
            current.categoryIds,
            categoryIds);
        final bool sameOnlyAllowed = current.onlyAllowed == onlyAllowed;
        final bool sameEnsured = _sameEnsureIds(
          current.ensureCategoryIds,
          normalizedEnsureIds,
        );
        if (sameInterface && sameCategoryId && sameCategoryIds &&
            sameOnlyAllowed && sameEnsured) {

          return;
        }
      }
      emit(FetchCategoryInProgress());

      DataOutput<CategoryModel> categories =
      await _categoryRepository.fetchCategories(
        page: 1,
        interfaceType: interfaceType,
        categoryId: categoryId,
        categoryIds: categoryIds,
        onlyAllowed: onlyAllowed,
        ensureCategoryIds: normalizedEnsureIds,
      );

      emit(FetchCategorySuccess(
          total: categories.total,
          categories: categories.modelList,
          page: 1,
          hasError: false,
        isLoadingMore: false,
        interfaceType: interfaceType?.trim(),
        categoryId: categoryId,
        categoryIds: categoryIds == null
            ? null
            : List<int>.from(categoryIds),
        onlyAllowed: onlyAllowed,
        ensureCategoryIds: normalizedEnsureIds.isEmpty
            ? null
            : List<int>.from(normalizedEnsureIds),
      ));
    } catch (e) {
      emit(FetchCategoryFailure(e.toString()));
    }
  }

  List<CategoryModel> getCategories() {
    if (state is FetchCategorySuccess) {
      return (state as FetchCategorySuccess).categories;
    }

    return <CategoryModel>[];
  }

  Future<void> fetchCategoriesMore() async {
    try {
      if (state is FetchCategorySuccess) {
        if ((state as FetchCategorySuccess).isLoadingMore) {
          return;
        }
        emit((state as FetchCategorySuccess).copyWith(isLoadingMore: true));
        final FetchCategorySuccess current = state as FetchCategorySuccess;
        DataOutput<CategoryModel> result =
            await _categoryRepository.fetchCategories(
              page: current.page + 1,
              interfaceType: current.interfaceType,
              categoryId: current.categoryId,
              categoryIds: current.categoryIds,
              onlyAllowed: current.onlyAllowed,
              ensureCategoryIds:
              current.ensureCategoryIds ?? const <int>[],
        );

        FetchCategorySuccess categoryState = (state as FetchCategorySuccess);
        categoryState.categories.addAll(result.modelList);

        List<String> list =
            categoryState.categories.map((e) => e.url!).toList();
        await HelperUtils.precacheSVG(list);

        emit(FetchCategorySuccess(
            isLoadingMore: false,
            hasError: false,
            categories: categoryState.categories,
            page: current.page + 1,
            total: result.total,
            interfaceType: current.interfaceType,
            categoryId: current.categoryId,
          categoryIds: current.categoryIds,
          onlyAllowed: current.onlyAllowed,
          ensureCategoryIds: current.ensureCategoryIds,
        ));
      }
    } catch (e) {
      emit((state as FetchCategorySuccess)
          .copyWith(isLoadingMore: false, hasError: true));
    }
  }

  bool _sameInterface(String? current, String? requested) {
    final String? a = _normalizeInterface(current);
    final String? b = _normalizeInterface(requested);
    return a == b;
  }

  bool _sameEnsureIds(List<int>? current, List<int> requested) {
    if ((current == null || current.isEmpty) && requested.isEmpty) {
      return true;
    }
    if (current == null) {
      return false;
    }
    return listEquals(current, requested);
  }

  String? _normalizeInterface(String? raw) {
    if (raw == null) {
      return null;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.toLowerCase();
  }


  bool hasMoreData() {
    if (state is FetchCategorySuccess) {
      return (state as FetchCategorySuccess).categories.length <
          (state as FetchCategorySuccess).total;
    }
    return false;
  }
}
