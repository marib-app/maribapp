// lib/ui/screens/item/my_item_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/fetch_my_item_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';

import 'package:marib/utils/hive_utils.dart';

import 'package:marib/ui/screens/user_profile/my_item_tab_ui.dart';

Map<String, FetchMyItemsCubit> myAdsCubitReference = {};

class MyItemTab extends StatelessWidget {
  final String? getItemsWithStatus;
  const MyItemTab({super.key, this.getItemsWithStatus});

  @override
  Widget build(BuildContext context) {
    // لو مو مسجل دخول
    if (!HiveUtils.isUserAuthenticated()) {
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
      child: _MyItemTabBody(statusKey: getItemsWithStatus ?? 'all'),
    );
  }
}

class _MyItemTabBody extends StatefulWidget {
  final String statusKey; // ex: 'active' / 'review' / 'all'
  const _MyItemTabBody({required this.statusKey});

  @override
  State<_MyItemTabBody> createState() => _MyItemTabBodyState();
}

class _MyItemTabBodyState extends State<_MyItemTabBody>
    with AutomaticKeepAliveClientMixin<_MyItemTabBody> {
  @override
  bool get wantKeepAlive => true;

  late final ScrollController _pageScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageScrollController.addListener(_onPageScroll);
  }

  void _onPageScroll() {
    final cubit = context.read<FetchMyItemsCubit>();
    final st = cubit.state;
    final bool isLoadingMore =
        st is FetchMyItemsSuccess ? st.isLoadingMore : false;

    // حمّل المزيد بحذر
    if (_pageScrollController.hasClients &&
        _pageScrollController.position.extentAfter < 200 &&
        cubit.hasMoreData() &&
        !isLoadingMore) {
      cubit.fetchMyMoreItems(getItemsWithStatus: widget.statusKey);
    }
  }

  Future<void> _onRefresh() async {
    final cubit = context.read<FetchMyItemsCubit>();
    cubit.fetchMyItems(getItemsWithStatus: widget.statusKey); // ← بدون await
  }

  void _onTapItem(ItemModel item) {
    Navigator.pushNamed(context, Routes.adDetailsScreen, arguments: {
      "model": item,
    }).then((value) {
      if (!mounted) return;
      if (value == "refresh") {
        context
            .read<FetchMyItemsCubit>()
            .fetchMyItems(getItemsWithStatus: widget.statusKey);
      }
    });
  }

  @override
  void dispose() {
    _pageScrollController.removeListener(_onPageScroll);
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<FetchMyItemsCubit, FetchMyItemsState>(
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
          controller: _pageScrollController,
          onRefresh: _onRefresh,
          onRetry: () => context
              .read<FetchMyItemsCubit>()
              .fetchMyItems(getItemsWithStatus: widget.statusKey),
          onTapItem: _onTapItem,

          // ✅ مفتاح تمرير ديناميكي لكل تبويب (تعديل صغير بالملف الآخر)
          storageKey: 'my_item_tab_list_${widget.statusKey}',
        );
      },
    );
  }
}
