import 'package:marib/data/model/category_model.dart';
import 'package:marib/ui/screens/settings/ad_creation_access.dart';
import 'package:marib/utils/hive_utils.dart';

/// Parsed payload passed to the ad creation wizard.
class AdCreationWizardArguments {
  const AdCreationWizardArguments({
    required this.categoryPath,
    required this.isEdit,
    required this.delegateScope,
  });

  final List<CategoryModel>? categoryPath;
  final bool isEdit;
  final AdCreationScope delegateScope;

  /// Creates arguments from the raw [settingsArguments] supplied to the route.
  factory AdCreationWizardArguments.from(Object? settingsArguments) {
    if (settingsArguments is AdCreationWizardArguments) {
      return settingsArguments;
    }

    final Map<String, dynamic> map =
    settingsArguments is Map<String, dynamic>
        ? settingsArguments
        : <String, dynamic>{};

    final List<CategoryModel>? categoryPath = _extractCategoryPath(map);
    final bool isEdit = map['isEdit'] == true;

    final AdCreationScope delegateScope =
    map['delegateScope'] is AdCreationScope
        ? map['delegateScope'] as AdCreationScope
        : resolveDefaultScope();

    return AdCreationWizardArguments(
      categoryPath: categoryPath,
      isEdit: isEdit,
      delegateScope: delegateScope,
    );
  }

  /// Ensures callers may reuse the same logic when assembling arguments.
  Map<String, dynamic> toMap() {
    final List<CategoryModel>? normalizedPath = categoryPath != null
        ? List<CategoryModel>.from(categoryPath!)
        : null;

    return <String, dynamic>{
      'categoryPath': normalizedPath,
      // Maintain legacy naming so inner widgets relying on the old key continue
      // to function without changes.
      'breadCrumbItems': normalizedPath,
      'isEdit': isEdit,
      'delegateScope': delegateScope,
    };
  }

  static List<CategoryModel>? _extractCategoryPath(
      Map<String, dynamic> map,
      ) {
    final Object? direct = map['categoryPath'];
    if (direct is List<CategoryModel>) {
      return List<CategoryModel>.from(direct);
    }

    final Object? legacy = map['breadCrumbItems'];
    if (legacy is List<CategoryModel>) {
      return List<CategoryModel>.from(legacy);
    }

    return null;
  }

  static AdCreationScope resolveDefaultScope() {
    return resolveAdCreationScope(
      user: HiveUtils.getUserDetails(),
      permittedDelegateSections: HiveUtils.getPermittedDelegateSections(),
      blockedDelegateSections: HiveUtils.getBlockedDelegateSections(),
    );
  }
}