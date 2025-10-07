import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/services.dart';   // للنسخ إلى الحافظة
import 'package:share_plus/share_plus.dart'; // للمشاركة

import 'package:marib/data/cubits/fetch_faqs_cubit.dart';

import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';

class FaqsScreen extends StatefulWidget {
  const FaqsScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(builder: (_) => const FaqsScreen());
  }

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
  bool _adShown = false;

  @override
  void initState() {
    super.initState();
    AdHelper.loadInterstitialAd();
    // إعلان مرّة واحدة بعد أول رسم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_adShown) {
        AdHelper.showInterstitialAd();
        _adShown = true;
      }
    });

    context.read<FetchFaqsCubit>().fetchFaqs();
  }

  Future<void> _refresh() async {
    context.read<FetchFaqsCubit>().fetchFaqs();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: context.color.territoryColor,
      onRefresh: _refresh,
      child: Scaffold(
        backgroundColor: context.color.primaryColor,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "faqsLbl".translate(context),
        ),
        body: BlocBuilder<FetchFaqsCubit, FetchFaqsState>(
          builder: (context, state) {
            if (state is FetchFaqsInProgress) {
              return _buildFaqsShimmer(context);
            }

            if (state is FetchFaqsFailure) {
              if (state.errorMessage is ApiException &&
                  state.errorMessage.error == "no-internet") {
                return NoInternet(onRetry: _refresh);
              }
              return const SomethingWentWrong();
            }

            if (state is FetchFaqsSuccess) {
              final faqs = state.faqModel;
              if (faqs.isEmpty) {
                return Center(child: NoDataFound(onTap: _refresh));
              }

              // نستخدم ExpansionPanelList.radio مرّة واحدة
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                children: [
                  _CardWrapper(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        splashColor:
                        context.color.territoryColor.withOpacity(0.08),
                        highlightColor:
                        context.color.territoryColor.withOpacity(0.05),
                      ),
                      child: ExpansionPanelList.radio(
                        animationDuration: const Duration(milliseconds: 300),
                        expandedHeaderPadding: EdgeInsets.zero,
                        elevation: 0,
                        children: List.generate(faqs.length, (index) {
                          final item = faqs[index];
                          final value = item.id ?? index; // قيمة فريدة

                          return ExpansionPanelRadio(
                            value: value,
                            backgroundColor: context.color.secondaryColor,
                            canTapOnHeader: true,
                            headerBuilder: (context, isExpanded) {
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                title: Text(item.question ?? '-')
                                    .bold()
                                    .size(context.font.normal),
                              );
                            },
                            body: Padding(
                              padding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // نص الإجابة مع دعم الروابط
                                  Linkify(
                                    text: item.answer ?? '-',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      color:
                                      context.color.textDefaultColor,
                                      height: 1.4,
                                    ),
                                    linkStyle: TextStyle(
                                      color: context.color.territoryColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                    options: const LinkifyOptions(
                                      humanize: true,
                                      looseUrl: true,
                                    ),
                                    onOpen: (link) async {
                                      final uri = Uri.parse(link.url);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode
                                              .externalApplication,
                                        );
                                      }
                                    },
                                  ),

                                  const SizedBox(height: 10),

                                  // شريط أكشنات بسيط: نسخ/مشاركة
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        tooltip: "نسخ",
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 18,
                                        ),
                                        color: context
                                            .color.textDefaultColor
                                            .withOpacity(0.7),
                                        onPressed: () {
                                          final txt = (item.answer ?? '').trim();
                                          if (txt.isNotEmpty) {
                                            Clipboard.setData(ClipboardData(text: txt));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("تم النسخ")),
                                            );
                                          }
                                        },

                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        tooltip: "مشاركة",
                                        icon: const Icon(
                                          Icons.share_rounded,
                                          size: 18,
                                        ),
                                        color: context
                                            .color.textDefaultColor
                                            .withOpacity(0.7),
                                        onPressed: () async {
                                          final q = (item.question ?? '').trim();
                                          final a = (item.answer ?? '').trim();
                                          final share = q.isEmpty ? a : "$q\n\n$a";
                                          if (share.isNotEmpty) {
                                            await Share.share(share);
                                          }
                                        },

                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // شيمر أقرب لهيئة البطاقات
  Widget _buildFaqsShimmer(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) {
        return _CardWrapper(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CustomShimmer(height: 14, width: 220),
                const SizedBox(height: 12),
                CustomShimmer(height: 10, width: context.screenWidth * 0.75),
                const SizedBox(height: 8),
                CustomShimmer(height: 10, width: context.screenWidth * 0.55),
                const SizedBox(height: 8),
                CustomShimmer(height: 10, width: context.screenWidth * 0.35),
              ],
            ),
          ),
        );
      },
    );
  }
}

// غلاف بطاقة موحّد
class _CardWrapper extends StatelessWidget {
  final Widget child;
  const _CardWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.borderColor.darken(30),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
