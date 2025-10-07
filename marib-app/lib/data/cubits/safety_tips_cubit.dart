import 'package:marib/data/model/safety_tips_model.dart';
import 'package:marib/data/repositories/safety_tips_repository.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FetchSafetyTipsListState {}

class FetchSafetyTipsInitial extends FetchSafetyTipsListState {}

class FetchSafetyTipsInProgress extends FetchSafetyTipsListState {}

class FetchSafetyTipsSuccess extends FetchSafetyTipsListState {
  final int total;
  final List<SafetyTipsModel> tips;

  final SafetyTipsDepartment? department;
  final String? productLink;
  final List<SafetyTipAction> actions;

  FetchSafetyTipsSuccess({
    required this.total,
    required this.tips,
    this.department,
    this.productLink,
    List<SafetyTipAction>? actions,
  }) : actions = List<SafetyTipAction>.unmodifiable(
            actions ?? const <SafetyTipAction>[]);

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'tips': tips.map((e) => e.toJson()).toList(),
      'department': department?.toJson(),
      'product_link': productLink,
      'actions': actions.map((e) => e.toJson()).toList(),
    };
  }

  factory FetchSafetyTipsSuccess.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawTips = (map['tips'] as List?) ?? const <dynamic>[];
    final List<SafetyTipsModel> parsedTips = rawTips
        .whereType<Map>()
        .map(
          (map) => SafetyTipsModel.fromJson(
            map.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList();
    final SafetyTipsDepartment? parsedDepartment =
        SafetyTipsDepartment.fromNullableJson(map['department']);
    final List<SafetyTipAction> parsedActions =
        SafetyTipAction.parseList(map['actions']);
    final List<SafetyTipAction> resolvedActions = parsedActions.isNotEmpty
        ? parsedActions
        : (parsedTips.isNotEmpty
            ? parsedTips.first.actions
            : const <SafetyTipAction>[]);
    final int resolvedTotal = _coerceInt(map['total']) ?? parsedTips.length;
    return FetchSafetyTipsSuccess(
      total: resolvedTotal,
      tips: parsedTips,
      department: parsedDepartment,
      productLink: map['product_link']?.toString(),
      actions: resolvedActions,
    );
  }
}

class FetchSafetyTipsFailure extends FetchSafetyTipsListState {
  final dynamic error;

  FetchSafetyTipsFailure(this.error);
}

class FetchSafetyTipsListCubit extends Cubit<FetchSafetyTipsListState> {
  FetchSafetyTipsListCubit() : super(FetchSafetyTipsInitial());
  final SafetyTipsRepository _repository = SafetyTipsRepository();

  Future<void> fetchSafetyTips({
    required String department,
    required int itemId,
  }) async {
    try {
      emit(FetchSafetyTipsInProgress());

      final DataOutput<SafetyTipsModel> result =
          await _repository.fetchTipsList(
        department: department,
        itemId: itemId,
      );
      final SafetyTipsDepartment? departmentData = result.modelList.isNotEmpty
          ? result.modelList.first.department
          : null;
      final String? productLink = result.modelList.isNotEmpty
          ? result.modelList.first.productLink
          : null;
      final List<SafetyTipAction> actions = result.modelList.isNotEmpty
          ? result.modelList.first.actions
          : const <SafetyTipAction>[];

      emit(FetchSafetyTipsSuccess(
        tips: result.modelList,
        total: result.total,
        department: departmentData,
        productLink: productLink,
        actions: actions,
      ));
    } catch (e) {
      emit(
        FetchSafetyTipsFailure(
          e.toString(),
        ),
      );
    }
  }

  List<SafetyTipsModel>? getList() {
    if (state is FetchSafetyTipsSuccess) {
      return (state as FetchSafetyTipsSuccess).tips;
    }
    return null;
  }

  List<SafetyTipAction> getActions() {
    if (state is FetchSafetyTipsSuccess) {
      return (state as FetchSafetyTipsSuccess).actions;
    }
    return const <SafetyTipAction>[];
  }

  @override
  FetchSafetyTipsListState? fromJson(Map<String, dynamic> json) {
    try {
      if (json['cubit_state'] == "FetchSafetyTipsSuccess") {
        FetchSafetyTipsSuccess fetchSafetyTipsSuccess =
            FetchSafetyTipsSuccess.fromMap(json);

        return fetchSafetyTipsSuccess;
      }
    } catch (e) {}
    return null;
  }

  @override
  Map<String, dynamic>? toJson(FetchSafetyTipsListState state) {
    try {
      if (state is FetchSafetyTipsSuccess) {
        Map<String, dynamic> mapped = state.toMap();
        mapped['cubit_state'] = "FetchSafetyTipsSuccess";
        return mapped;
      }
    } catch (e) {}

    return null;
  }
}

int? _coerceInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
