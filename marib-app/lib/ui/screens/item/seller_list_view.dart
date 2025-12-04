import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/ui/screens/sliders/slider_widget.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/utils/constant.dart';

import '../../../data/cubits/seller/fetch_sellers_cubit.dart';
import '../../../data/model/user_model.dart';
import '../../../utils/extensions/extensions.dart';
import 'seller_card.dart';

class SellerListView extends StatelessWidget {
  const SellerListView({
    super.key,
    required this.controller,
    required this.lastSellersCount,
    required this.onSellersCountChanged,
  });

  final ScrollController controller;
  final int lastSellersCount;
  final ValueChanged<int> onSellersCountChanged;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 2)),
        const SliverToBoxAdapter(child: SliderWidget(interfaceType: "e_store")),
        BlocBuilder<FetchSellersCubit, FetchSellersState>(
          builder: (context, state) {
            if (state is FetchSellersProgress) {
              final int shimmerItemCount =
                  lastSellersCount > 0 ? lastSellersCount : 6;
              return _SellerShimmerList(shimmerItemCount: shimmerItemCount);
            }

            if (state is FetchSellersSuccess) {
              onSellersCountChanged(state.sellers.length);
              if (state.sellers.isEmpty) {
                return _SellerEmptyState(onRetry: () {
                  context
                      .read<FetchSellersCubit>()
                      .fetchSellers(accountType: Constant.accountTypeSeller);
                });
              }
              return SellerCardList(sellers: state.sellers);
            }

            if (state is FetchSellersFailure) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: SomethingWentWrong(
                  description: state.errorMessage,
                  onReload: () => context
                      .read<FetchSellersCubit>()
                      .fetchSellers(accountType: Constant.accountTypeSeller),
                ),
              );
            }

            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
        ),
      ],
    );
  }
}

class SellerCardList extends StatelessWidget {
  const SellerCardList({super.key, required this.sellers});

  final List<UserModel> sellers;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return SellerCard(seller: sellers[index]);
        },
        childCount: sellers.length,
      ),
    );
  }
}

class _SellerShimmerList extends StatelessWidget {
  const _SellerShimmerList({required this.shimmerItemCount});

  final int shimmerItemCount;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return const _SellerShimmerCard();
        },
        childCount: shimmerItemCount,
      ),
    );
  }
}

class _SellerShimmerCard extends StatelessWidget {
  const _SellerShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      child: CustomShimmer(
        height: 150,
        width: double.infinity,
        borderRadius: 12,
      ),
    );
  }
}

class _SellerEmptyState extends StatelessWidget {
  const _SellerEmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: NoDataFound(
        onTap: onRetry,
        category: EmptyStateCategory.profile,
      ),
    );
  }
}
