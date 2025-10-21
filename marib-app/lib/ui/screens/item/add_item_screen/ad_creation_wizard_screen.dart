import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:marib/data/cubits/item/manage_item_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details.dart';
import 'package:marib/ui/screens/settings/ad_creation_access.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/utils/hive_utils.dart';

/// Entry point for the ad creation wizard flow.
class AdCreationWizardScreen extends StatelessWidget {
  const AdCreationWizardScreen({
    super.key,
    required this.arguments,
  });

  final AdCreationWizardArguments arguments;

  /// Normalizes the provided [RouteSettings] into a [Route] that mirrors the
  /// behaviour of the legacy [AddItemDetails.route] builder while also
  /// providing the additional context the wizard expects.
  static Route<dynamic> route(RouteSettings settings) {
    final AdCreationWizardArguments args =
    AdCreationWizardArguments.from(settings.arguments);

    return BlurredRouter(
      settings: RouteSettings(
        name: settings.name,
        arguments: args.toMap(),
      ),
      builder: (BuildContext context) {
        return MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<FetchCustomFieldsCubit>(
              create: (_) => FetchCustomFieldsCubit(),
            ),
            BlocProvider<ManageItemCubit>(
              create: (_) => ManageItemCubit(),
            ),
          ],
          child: AdCreationWizardScreen(arguments: args),
        );
      },
    );
  }

  /// Helper to build a strongly typed argument payload for the wizard.
  static Map<String, dynamic> buildArguments({
    List<CategoryModel>? categoryPath,
    required bool isEdit,
    AdCreationScope? delegateScope,
  }) {
    final AdCreationWizardArguments args = AdCreationWizardArguments(
      categoryPath: categoryPath,
      isEdit: isEdit,
      delegateScope: delegateScope ??
          AdCreationWizardArguments.resolveDefaultScope(),
    );

    return args.toMap();
  }

  @override
  Widget build(BuildContext context) {
    return AddItemDetails(
      breadCrumbItems: arguments.categoryPath,
      isEdit: arguments.isEdit,
    );
  }
}

/// Parsed payload passed to the wizard.
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
      Map<String, dynamic> map) {
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