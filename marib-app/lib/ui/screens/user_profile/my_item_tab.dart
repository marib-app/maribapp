// lib/ui/screens/item/my_item_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/fetch_my_item_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';

import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';



import 'my_item_tab_ui.dart';

Map<String, FetchMyItemsCubit> myAdsCubitReference = {};

class MyItemTab extends StatelessWidget {
  final String? getItemsWithStatus;
  final void Function(String statusKey, bool isLoading)? onLoadingChanged;
  final VoidCallback? onFullRefreshRequested;

  const MyItemTab({
    super.key,
    this.getItemsWithStatus,
    this.onLoadingChanged,
    this.onFullRefreshRequested,
  });



  @override
  Widget build(BuildContext context) {
    // لو مو مسجل دخول
    if (!HiveUtils.isUserAuthenticated()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLoadingChanged?.call(_resolveStatusKey(), false);
      });
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.lock_outline, size: 40),
              SizedBox(height: 10),
              Text("يرجى تسجيل الدخول لمشاهدة إعلاناتك"),
            ],
          ),
        ),
      );
    }

    // ✅ Cubit مستقل لهذا التبويب
    return BlocProvider(
      create: (ctx) {
        final c = FetchMyItemsCubit();
        // أول جلب
        c.fetchMyItems(getItemsWithStatus: getItemsWithStatus);
        // خزّن المرجع لو تحتاجه بمكان آخر
        myAdsCubitReference[getItemsWithStatus ?? 'all'] = c;
        return c;
      },
      child: _MyItemTabBody(
        statusKey: _resolveStatusKey(),
        onLoadingChanged: onLoadingChanged,
        onFullRefreshRequested: onFullRefreshRequested,
      ),
    );
  }

  String _resolveStatusKey() {
    final status = getItemsWithStatus;
    if (status == null || status.isEmpty) {
      return 'all';
    }
    return status;
  }
}

class _MyItemTabBody extends StatefulWidget {
  final String statusKey; // ex: 'active' / 'review' / 'all'
  final void Function(String statusKey, bool isLoading)? onLoadingChanged;
  final VoidCallback? onFullRefreshRequested;

  const _MyItemTabBody({
    super.key,
    required this.statusKey,
    this.onLoadingChanged,
    this.onFullRefreshRequested,
  });


  @override
  State<_MyItemTabBody> createState() => _MyItemTabBodyState();
}

class _MyItemTabBodyState extends State<_MyItemTabBody>
    with AutomaticKeepAliveClientMixin<_MyItemTabBody> {
  @override
  bool get wantKeepAlive => true;

  ScrollController? _pageScrollController;
  ScrollController? _ownedScrollController;
  bool _usingPrimaryController = false;

  ScrollController get _effectiveScrollController {
    final controller = _pageScrollController;
    if (controller != null) {
      return controller;
    }

    final owned = _ensureOwnedController();
    _attachScrollController(owned, isPrimary: false);
    return owned;
  }

  ScrollController _ensureOwnedController() {
    return _ownedScrollController ??= ScrollController();
  }

  void _attachScrollController(ScrollController controller,
      {required bool isPrimary}) {
    if (_pageScrollController == controller) {
      _usingPrimaryController = isPrimary;
      return;
    }

    _pageScrollController?.removeListener(_onPageScroll);

    _pageScrollController = controller;
    _usingPrimaryController = isPrimary;
    _pageScrollController!.addListener(_onPageScroll);
  }


  @override
  void initState() {
    super.initState();
    final owned = _ensureOwnedController();
    _attachScrollController(owned, isPrimary: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = PrimaryScrollController.of(context);
    if (primary != null) {
      _attachScrollController(primary, isPrimary: true);
    } else {
      _attachScrollController(_ensureOwnedController(), isPrimary: false);
    }
  }

  void _onPageScroll() {
    final cubit = context.read<FetchMyItemsCubit>();
    final st = cubit.state;
    final bool isLoadingMore =
    st is FetchMyItemsSuccess ? st.isLoadingMore : false;

    // حمّل المزيد بحذر
    final controller = _effectiveScrollController;

    if (controller.hasClients &&
        controller.position.extentAfter < 200 &&
        cubit.hasMoreData() &&
        !isLoadingMore) {
      cubit.fetchMyMoreItems(getItemsWithStatus: widget.statusKey);
    }
  }

  Future<void> _onRefresh() async {
    widget.onFullRefreshRequested?.call();

    final cubit = context.read<FetchMyItemsCubit>();
    cubit.fetchMyItems(getItemsWithStatus: widget.statusKey); // ← بدون await
  }




  void _onTapItem(ItemModel item) {
    Navigator.pushNamed(context, Routes.adDetailsScreen, arguments: {
      "model": item,
    }).then((value) {
      if (!mounted) return;
      if (value == "refresh") {
        widget.onFullRefreshRequested?.call();
        context
            .read<FetchMyItemsCubit>()
            .fetchMyItems(getItemsWithStatus: widget.statusKey);
      }
    });
  }

  @override
  void dispose() {
    _pageScrollController?.removeListener(_onPageScroll);

    if (_usingPrimaryController) {
      _ownedScrollController?.dispose();
      _ownedScrollController = null;
    } else {
      _pageScrollController?.dispose();
    }
    _pageScrollController = null;
    myAdsCubitReference.remove(widget.statusKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<FetchMyItemsCubit, FetchMyItemsState>(
          listenWhen: (previous, current) {
            final bool wasLoading = previous is FetchMyItemsInProgress;
            final bool isLoading = current is FetchMyItemsInProgress;
            return wasLoading != isLoading;
          },
          listener: (context, state) {
            widget.onLoadingChanged?.call(
              widget.statusKey,
              state is FetchMyItemsInProgress,
            );
          },
        ),
        BlocListener<FetchMyItemsCubit, FetchMyItemsState>(
          listenWhen: (previous, current) => current is FetchMyItemsFailed,
          listener: (context, state) {
            widget.onLoadingChanged?.call(widget.statusKey, false);
          },
        ),
      ],
      child: BlocBuilder<FetchMyItemsCubit, FetchMyItemsState>(
        // ابني فقط عند تغير العناصر أو حالة التحميل
        buildWhen: (prev, curr) {
          if (prev.runtimeType != curr.runtimeType) return true;
          if (curr is FetchMyItemsSuccess && prev is FetchMyItemsSuccess) {
            return curr.items != prev.items ||
                curr.isLoadingMore != prev.isLoadingMore;
          }
          return true;
        },
        builder: (context, state) {
          return MyItemTabUI(
            state: state,
            controller: _effectiveScrollController,
            onRefresh: _onRefresh,
            onRetry: () => context
                .read<FetchMyItemsCubit>()
                .fetchMyItems(getItemsWithStatus: widget.statusKey),
            onTapItem: _onTapItem,

            // ✅ مفتاح تمرير ديناميكي لكل تبويب (تعديل صغير بالملف الآخر)
            storageKey: 'my_item_tab_list_${widget.statusKey}',
          );
        },
      ),
    );
  }
}
