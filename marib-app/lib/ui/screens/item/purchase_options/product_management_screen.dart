import 'package:flutter/material.dart';

import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/manage_item_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/repositories/item/item_purchase_options_repository.dart';
import 'package:marib/data/cubits/item/product_management_cubit.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/ecommerce_department.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:flutter/foundation.dart';
import 'product_management/product_management_arguments.dart';
import 'product_management/unsupported_product_management.dart';
import 'product_management/tabs/attributes_tab.dart';
import 'product_management/tabs/delivery_size_tab.dart';
import 'product_management/tabs/discount_tab.dart';
import 'product_management/tabs/stock_tab.dart';
import 'product_management/widgets/common_widgets.dart';
import 'pending_item_draft.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({
    super.key,
    required this.item,
    this.pendingDraft,
  });

  final ItemModel item;
  final PendingItemDraft? pendingDraft;

  static Route<dynamic> route(RouteSettings settings) {
    final ProductManagementArguments args =
        ProductManagementArguments.from(settings.arguments);

    return AppPageRoute.build(
      settings: settings,
      builder: (_) {
        if (args.pendingDraft == null && !isEcommerceItem(args.item)) {
          return const UnsupportedProductManagement();
        }

        Widget content = ProductManagementScreen(
          item: args.item,
          pendingDraft: args.pendingDraft,
        );

        content = BlocProvider<ProductManagementCubit>(
          create: (context) => ProductManagementCubit(
            ItemPurchaseOptionsRepository(),
            args.item,
            createItem: args.pendingDraft != null
                ? () => submitPendingItemDraft(
                      cubit: context.read<ManageItemCubit>(),
                      draft: args.pendingDraft!,
                    )
                : null,
            pendingProductOptions: args.pendingDraft?.productOptions,
          )..initialize(),
          child: content,
        );

        if (args.pendingDraft != null) {
          content = BlocProvider<ManageItemCubit>(
            create: (_) => ManageItemCubit(),
            child: content,
          );
        }

        return content;
      },
      motionPattern: AppMotionPattern.glide,
    );
  }

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 4, vsync: this);

  final Map<String, TextEditingController> _stockControllers =
      <String, TextEditingController>{};

  PendingItemDraft? get _pendingDraft => widget.pendingDraft;

  @override
  void dispose() {
    _tabController.dispose();

    for (final TextEditingController controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductManagementCubit, ProductManagementState>(
      builder: (BuildContext context, ProductManagementState state) {
        final color = context.color;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: UiUtils.getSystemUiOverlayStyle(
            context: context,
            statusBarColor: color.secondaryColor,
          ),
          child: Scaffold(
            backgroundColor: color.primaryColor,
            appBar: UiUtils.buildAppBar(
              context,
              title: 'إدارة المنتج',
              showBackButton: true,
              bottomHeight: 72,
              bottom: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: _buildTabBar(context),
                ),
              ],
            ),
            body: _buildBody(context, state),
            bottomNavigationBar: _buildBottomBar(context, state),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ProductManagementState state) {
    final color = context.color;

    if (state.loading) {
      return const _ProductManagementShimmer();
    }

    if (state.error != null) {
      return ProductManagementErrorView(
        message: state.error!,
        onRetry: () => context.read<ProductManagementCubit>().initialize(),
      );
    }

    return Container(
      color: color.primaryColor,
      child: TabBarView(
        controller: _tabController,
        children: <Widget>[
          AttributesTab(state: state),
          DeliverySizeTab(state: state),
          StockTab(
            state: state,
            stockControllers: _stockControllers,
          ),
          DiscountTab(state: state),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final color = context.color;
    final TextStyle? labelStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontWeight: FontWeight.w700);

    return Container(
      decoration: BoxDecoration(
        color: color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.borderColor.withOpacity(0.4)),
      ),
      child: TabBar(
        controller: _tabController,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        indicator: BoxDecoration(
          color: color.territoryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: color.territoryColor,
        unselectedLabelColor: color.textDefaultColor.withOpacity(0.7),
        labelStyle: labelStyle,
        tabs: const <Tab>[
          Tab(text: 'السمات'),
          Tab(text: 'الحجم'),
          Tab(text: 'المخزون'),
          Tab(text: 'الخصم'),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ProductManagementState state) {
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();

    final bool isSaving =
        state.attributesSaving || state.stockSaving || state.discountSaving;
    final bool hasProductData = state.managedAttributes.isNotEmpty ||
        (state.options?.attributes.isNotEmpty ?? false) ||
        (state.options?.variantStocks.isNotEmpty ?? false) ||
        ((state.options?.deliverySize ?? 0) > 0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: UiUtils.buildButton(
          context,
          onPressed: () => _onSavePressed(context, cubit),
          buttonTitle: 'حفظ ومعاينة الإعلان',
          titleWhenProgress: 'جارٍ الحفظ...',
          isInProgress: isSaving,
          disabled: isSaving || !hasProductData,
          height: 48.rh(context),
          fontSize: context.font.large,
        ),
      ),
    );
  }

  Future<void> _onSavePressed(
      BuildContext context, ProductManagementCubit cubit) async {
    debugPrint(
        '[ProductManagementScreen] save pressed: item.id=${cubit.item.id} state.item.id=${cubit.state.item.id} optionsId=${cubit.state.options?.itemId}');
    Widgets.showLoader(context);
    SubmissionOutcome? outcome;
    try {
      final int? ensuredId = await cubit.ensureItemId();
      if (ensuredId == null) {
        debugPrint('[ProductManagementScreen] ensureItemId returned null');
        return;
      }
      debugPrint(
          '[ProductManagementScreen] ensureItemId ok: id=$ensuredId, submitting...');
      outcome = await cubit.submitAllAndReview();
    } catch (e, st) {
      debugPrint('[ProductManagementScreen] submit exception: $e\n$st');
      HelperUtils.showSnackBarMessage(
        context,
        'تعذر الحفظ حالياً، يرجى المحاولة لاحقاً.',
      );
      return;
    } finally {
      if (mounted) {
        Widgets.hideLoder(context);
      }
    }

    if (outcome == null) {
      debugPrint('[ProductManagementScreen] outcome is null');
      return;
    }

    if (!mounted) {
      return;
    }

    final String message = _resolveOutcomeMessage(outcome);
    debugPrint(
        '[ProductManagementScreen] submit outcome success=${outcome.success} message="$message"');

    final String normalizedMsg = message.toLowerCase();
    final bool canProceed = outcome.success ||
        normalizedMsg.contains('options saved for review');

    if (!canProceed) {
      HelperUtils.showSnackBarMessage(context, message);
      return;
    }

    int? _validId(int? value) => (value != null && value > 0) ? value : null;
    final int? itemId = _validId(cubit.state.item.id) ??
        _validId(cubit.item.id) ??
        _validId(cubit.state.options?.itemId);
    if (itemId == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'تعذر فتح المعاينة حاليًا، لم يتم إنشاء الإعلان بعد.',
      );
      return;
    }

    ItemModel previewModel = cubit.state.item;
    if (previewModel.id != itemId) {
      previewModel = previewModel.copyWith(id: itemId);
    }

    HelperUtils.showSnackBarMessage(context, message);

    Navigator.of(context, rootNavigator: true).pushNamed(
      Routes.adDetailsScreen,
      arguments: <String, dynamic>{
        'itemId': itemId,
        'item': previewModel,
        'model': previewModel,
        'options': cubit.state.options,
        'preview': true,
      },
    );
  }

  String _resolveOutcomeMessage(SubmissionOutcome outcome) {
    final String trimmed = outcome.message.trim();
    if (trimmed.isEmpty) {
      return outcome.success
          ? ProductManagementCubit.genericSuccessMessage
          : ProductManagementCubit.genericFailureMessage;
    }

    final String normalized = trimmed.toLowerCase();
    if (normalized == 'null' ||
        normalized == 'none' ||
        normalized == 'undefined' ||
        normalized == 'request-failed' ||
        normalized == 'manage-item-fail' ||
        normalized.contains('something went wrong')) {
      return outcome.success
          ? ProductManagementCubit.genericSuccessMessage
          : ProductManagementCubit.genericFailureMessage;
    }

    return trimmed;
  }
}

class _ProductManagementShimmer extends StatelessWidget {
  const _ProductManagementShimmer();

  @override
  Widget build(BuildContext context) {
    final color = context.color;
    return Container(
      color: color.primaryColor,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomShimmer(height: 26, width: 180, borderRadius: 10),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: CustomShimmer(height: 44, borderRadius: 14)),
              const SizedBox(width: 12),
              Expanded(child: CustomShimmer(height: 44, borderRadius: 14)),
              const SizedBox(width: 12),
              Expanded(child: CustomShimmer(height: 44, borderRadius: 14)),
              const SizedBox(width: 12),
              Expanded(child: CustomShimmer(height: 44, borderRadius: 14)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.secondaryColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.borderColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomShimmer(height: 18, width: 120, borderRadius: 8),
                    const SizedBox(height: 12),
                    CustomShimmer(height: 14, width: 180, borderRadius: 6),
                    const SizedBox(height: 16),
                    CustomShimmer(height: 44, borderRadius: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
