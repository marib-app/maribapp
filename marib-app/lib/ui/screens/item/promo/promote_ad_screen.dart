import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image_picker/image_picker.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';

import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/data/cubits/subscription/fetch_user_package_limit_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/promote_ad_cubit.dart';
import 'package:marib/data/model/subscription_status.dart';
import 'package:marib/data/model/item/item_model.dart';

import 'dart:async';

class PromoteAdScreen extends StatefulWidget {
  final ItemModel model;
  final double? dailyPrice;

  const PromoteAdScreen({
    super.key,
    required this.model,
    this.dailyPrice,
  });

  static Route route(RouteSettings settings) {
    final Map<dynamic, dynamic>? args =
        settings.arguments as Map<dynamic, dynamic>?;
    final ItemModel model = (args?['model'] as ItemModel?) ?? ItemModel();
    final dynamic rawDailyPrice = args?['dailyPrice'];
    final double? dailyPrice = rawDailyPrice is num
        ? rawDailyPrice.toDouble()
        : rawDailyPrice as double?;

    return BlurredRouter(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => FetchUserPackageLimitCubit()),
          BlocProvider(
            create: (_) => PromoteAdCubit(
              adId: model.id ?? 0,
            ),
          ),
        ],
        child: PromoteAdScreen(
          model: model,
          dailyPrice: dailyPrice,
        ),
      ),
    );
  }

  @override
  State<PromoteAdScreen> createState() => _PromoteAdScreenState();
}

class _PromoteAdScreenState extends State<PromoteAdScreen> {
  // صفحة جاهزة بعد شيمر خفيف أول ما تدخل
  bool _pageLoaded = false;

  // مرحلة الدفع (تظهر بعد الضغط على الزر) مع شيمر أثناء الجلب
  bool _showPayments = false;
  bool _loadingPayments = false;

  // تحكم
  int _days = 1;
  late final double _dailyPrice = widget.dailyPrice ?? 3000;

  final ScrollController _scrollCtrl = ScrollController();

  // اختيار وسيلة الدفع: 0 شرق (فوري) / 1 إيزي كاش / 2 الشبكة
  int? _selectedMethodIndex;

  @override
  void initState() {
    super.initState();
    // ما نجلب أي بيانات “ثقيلة” — فقط ننتقل من شيمر لواجهة جاهزة
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _pageLoaded = true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<FetchUserPackageLimitCubit>()
          .fetchUserPackageLimit(packageType: 'advertisement');
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // تمرير فوري لأقصى أسفل الصفحة (نكرر أكثر من نبضة للتأكد)
  void _scrollToBottomHard() {
    void jump() {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }

    Future<void>.delayed(Duration.zero, jump);
    Future<void>.delayed(const Duration(milliseconds: 120), jump);
    Future<void>.delayed(const Duration(milliseconds: 240), jump);
    Future<void>.delayed(const Duration(milliseconds: 360), jump);
  }

  Widget _buildLimitStatusCard() {
    return BlocBuilder<FetchUserPackageLimitCubit, FetchUserPackageLimitState>(
      builder: (context, state) {
        final theme = Theme.of(context);

        if (state is FetchUserPackageLimitInProgress) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (state is FetchUserPackageLimitInSuccess) {
          final Color accent = state.canCreateListing
              ? context.color.territoryColor
              : theme.colorScheme.error;
          final String statusKey = state.canCreateListing
              ? 'subscriptionLimitActionAllowed'
              : 'subscriptionLimitActionBlocked';
          final String statusLabel =
              UiUtils.getTranslatedLabel(context, statusKey);
          final String? summary = UiUtils.subscriptionLimitSummary(
            context,
            state.limit,
            includeExpiry: false,
          );
          final String? expiry =
              UiUtils.subscriptionLimitExpiry(context, state.limit);

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (summary != null && summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (expiry != null && expiry.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    expiry,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        if (state is FetchUserPackageLimitFailure) {
          final message = UiUtils.getTranslatedLabel(
            context,
            'subscriptionLimitActionBlocked',
          );
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        return const SizedBox(height: 12);
      },
    );
  }

  // بيانات الطرق (للبطاقات + الحوارات)
  Map<String, String> _bankMeta(int index) {
    // مطابق لما شاركته في PaymentStandalonePage (مع إبقاء الشرق فوري بدون رقم في البطاقة)
    switch (index) {
      case 0:
        return {
          "name": "الدفع بواسطة بنك الشرق اليمني",
          "logo": "assets/svg/Logo/بنك الشرق اليمني.png",
          "accountName": "",
          "accountNumber": "", // لا نعرض في البطاقة — والحوار فوري بكود شراء
        };
      case 1:
        return {
          "name": "نقطة إيزي كاش",
          "logo": "assets/svg/Logo/نقطة إيزي كاش.png",
          "accountName": "",
          "accountNumber": "712226666",
        };
      case 2:
        return {
          "name": "الشبكة ( الحولات الداخلية )",
          "logo": "assets/svg/Logo/الشبكة.png",
          "accountName": "مأرب بين يديك للخدمات الإلكترونية",
          "accountNumber": "مأرب بين يديك للخدمات الألكترونية",
        };
      default:
        return {"name": "", "logo": "", "accountName": "", "accountNumber": ""};
    }
  }

  Widget _buildSubscriptionDetails() {
    bool statusHasBalance(SubscriptionStatus status) {
      final double available = status.availableBalance ?? 0;
      final int remaining = status.featuredCount ?? 0;
      return available > 0 || remaining > 0;
    }

    return BlocBuilder<PromoteAdCubit, PromoteAdState>(
      builder: (context, state) {
        SubscriptionStatus? status;
        bool hasBalance = false;
        bool isFeatured = false;
        bool canPause = false;

        if (state is PromoteAdSubscriberReady) {
          status = state.status;
          hasBalance = state.hasBalance;
          isFeatured = state.isFeatured;
          canPause = state.canPause;
        } else if (state is PromoteAdActing) {
          status = state.status;
        } else if (state is PromoteAdError) {
          status = state.status;
        } else if (state is PromoteAdChecking) {
          status = state.previousStatus;
        } else if (state is PromoteAdNonSubscriber) {
          status = state.status;
        }

        if (status == null || !status.hasActive) {
          return const SizedBox.shrink();
        }

        if (state is! PromoteAdSubscriberReady) {
          hasBalance = statusHasBalance(status);
          isFeatured = status.isFeatured ?? false;
          canPause = status.canPause ?? false;
        }

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;
        final double? balance = status.availableBalance;
        final int? remainingDays = status.featuredCount;

        Widget detailRow(String label, String value) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final List<Widget> rows = [];

        if (balance != null) {
          rows.add(detailRow('الرصيد المتاح للتمييز', _formatYer(balance)));
        }

        if (remainingDays != null) {
          final String daysLabel =
              '$remainingDays ${_arabicDays(remainingDays)}';
          rows.add(detailRow('الأيام المميزة المتبقية', daysLabel));
        }

        if (isFeatured) {
          rows.add(
            detailRow(
              'حالة الإعلان',
              canPause
                  ? 'الإعلان مميز حالياً ويمكنك إيقاف التمييز مؤقتاً.'
                  : 'الإعلان مميز حالياً.',
            ),
          );
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تفاصيل الاشتراك',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ...rows,
              if (!hasBalance)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.error.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    'رصيدك الحالي لا يكفي لتمييز إعلان جديد. قم بشحن الباقة أو شراء باقة جديدة للمتابعة.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // الانتقال لمرحلة الدفع (جلب الطرق فقط هنا)
  Future<void> _goToPaymentStep() async {
    setState(() {
      _showPayments = true;
      _loadingPayments = true;
    });
    _scrollToBottomHard();

    // ===== API HOOK: جلب طرق الدفع من السيرفر =====
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() => _loadingPayments = false);
  }

  // الدفع الآن ⇒ افتح الحوارات الأصلية حسب الاختيار
  Future<void> _payNow() async {
    _scrollToBottomHard();

    if (_selectedMethodIndex == null) {
      HelperUtils.showSnackBarMessage(context, 'اختر وسيلة الدفع أولاً');
      return;
    }

    final meta = _bankMeta(_selectedMethodIndex!);

    if (_selectedMethodIndex == 0) {
      // الشرق — فوري عبر كود شراء
      await _showPurchaseCodeDialog(onConfirm: () async {
        await _finalizePaymentInstant(); // فوري
      });
    } else {
      // إيزي كاش / الشبكة — بيانات حوالة + إرفاق إيصال (اختياري)
      await _showBankTransferDialog(
        paymentMethodName: meta["name"] ?? "",
        accountName: meta["accountName"] ?? "",
        accountNumber: meta["accountNumber"] ?? "",
        onConfirm: (customerName, transferCode, receipt) async {
          await _finalizePaymentManual(
            methodName: meta["name"] ?? "",
            customerName: customerName,
            transferCode: transferCode,
            receipt: receipt,
          );
        },
      );
    }
  }

  // تفعيل فوري (الشرق)
  Future<void> _finalizePaymentInstant() async {
    // ===== API HOOK: تأكيد فوري على السيرفر =====
    // مثال: await PaymentsApi.confirmEastBank(itemId: widget.model.id!, days: _days);
    await _applyFeatureOnServer(days: _days);
    if (!mounted) return;
    HelperUtils.showSnackBarMessage(context, 'تم تفعيل الإعلان كمميز فورًا 🎉');
    Navigator.pop(context, 'refresh');
  }

  // تفعيل يدوي (إيزي/الشبكة)
  Future<void> _finalizePaymentManual({
    required String methodName,
    required String customerName,
    required String transferCode,
    File? receipt,
  }) async {
    // ===== API HOOK: إرسال بيانات الحوالة + المرفق (receipt) =====
    // await PaymentsApi.submitTransfer(itemId: widget.model.id!, method: methodName, name: customerName, code: transferCode, file: receipt, days: _days);
    await _applyFeatureOnServer(days: _days);
    if (!mounted) return;
    HelperUtils.showSnackBarMessage(
        context, 'تم استلام بيانات الدفع وتفعيل التمييز ✅');
    Navigator.pop(context, 'refresh');
  }

  // تطبيق التمييز فعليًا على السيرفر
  Future<void> _applyFeatureOnServer({required int days}) async {
    await context.read<PromoteAdCubit>().feature();

    if (!mounted) return;
    await context
        .read<FetchUserPackageLimitCubit>()
        .fetchUserPackageLimit(packageType: 'advertisement');
  }

  String _formatYer(num v) {
    final s = v.round().toString();
    final withSep = s.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '$withSep ر.ي';
  }

  String _arabicDays(int d) {
    return (d == 1)
        ? 'يوم'
        : (d == 2)
            ? 'يومان'
            : (d >= 3 && d <= 10)
                ? 'أيام'
                : 'يوماً';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);

    final limitState = context.watch<FetchUserPackageLimitCubit>().state;
    final bool limitInProgress = limitState is FetchUserPackageLimitInProgress;
    final bool limitFailure = limitState is FetchUserPackageLimitFailure;
    final bool canProceed = limitState is FetchUserPackageLimitInSuccess
        ? limitState.canCreateListing
        : !limitFailure;
    final bool disableAction = limitInProgress || !canProceed;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: BlocListener<PromoteAdCubit, PromoteAdState>(
        listener: (context, state) {
          if (state is PromoteAdError) {
            HelperUtils.showSnackBarMessage(
              context,
              state.message,
              type: MessageType.error,
            );
          } else if (state is PromoteAdSubscriberReady) {
            final String? message = state.message;
            if (message != null && message.isNotEmpty) {
              HelperUtils.showSnackBarMessage(
                context,
                message,
                type: MessageType.success,
              );
            }
          } else if (state is PromoteAdNonSubscriber) {
            final String? message = state.message;
            if (message != null && message.isNotEmpty) {
              HelperUtils.showSnackBarMessage(
                context,
                message,
                type: MessageType.success,
              );
            }
          }
        },
        child: Scaffold(
          backgroundColor: context.color.secondaryDetailsColor,
          appBar: UiUtils.buildAppBar(
            context,
            title: 'تمييز الإعلان',
            showBackButton: true,
          ),

          // شريط الإجمالي + زر سفلي (كما طلبت)
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, -3))
                ],
              ),
              child: BlocBuilder<PromoteAdCubit, PromoteAdState>(
                builder: (context, promoteState) {
                  final PromoteAdCubit cubit = context.read<PromoteAdCubit>();

                  String buttonTitle = 'تمييز الآن';
                  VoidCallback onPressed = () {};
                  bool disabledButton = disableAction;

                  final bool isProcessing = promoteState is PromoteAdChecking ||
                      promoteState is PromoteAdActing;

                  String progressTitle = 'جاري التنفيذ...';
                  if (promoteState is PromoteAdChecking) {
                    progressTitle = 'جاري التحقق...';
                  } else if (promoteState is PromoteAdActing) {
                    progressTitle = promoteState.isFeaturing
                        ? 'جاري تمييز الإعلان...'
                        : 'جاري إيقاف التمييز...';
                    buttonTitle = promoteState.isFeaturing
                        ? 'تمييز الآن'
                        : 'إيقاف التمييز';
                  }

                  if (!isProcessing) {
                    if (promoteState is PromoteAdIdle) {
                      if (!disableAction) {
                        disabledButton = false;
                        onPressed = () => cubit.check();
                      }
                    } else if (promoteState is PromoteAdSubscriberReady) {
                      if (promoteState.isFeatured && promoteState.canPause) {
                        buttonTitle = 'إيقاف التمييز';
                        if (!disableAction) {
                          disabledButton = false;
                          onPressed = () => cubit.unfeature();
                        }
                      } else {
                        buttonTitle = 'تمييز الآن';
                        if (!disableAction && promoteState.hasBalance) {
                          disabledButton = false;
                          onPressed = () => cubit.feature();
                        } else {
                          disabledButton = true;
                        }
                      }
                    } else if (promoteState is PromoteAdNonSubscriber) {
                      buttonTitle = 'شراء باقة مميزة الآن';
                      if (!disableAction) {
                        disabledButton = false;
                        onPressed = () {
                          Navigator.pushNamed(
                            context,
                            Routes.subscriptionPackageListRoute,
                          );
                        };
                      }
                    } else if (promoteState is PromoteAdError) {
                      buttonTitle = 'إعادة المحاولة';
                      if (!disableAction) {
                        disabledButton = false;
                        onPressed = () => cubit.check();
                      }
                    } else {
                      if (!disableAction) {
                        disabledButton = false;
                        onPressed = () => cubit.check();
                      }
                    }
                  }

                  if (isProcessing) {
                    disabledButton = true;
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UiUtils.buildButton(
                        context,
                        onPressed: onPressed,
                        disabled: disabledButton,
                        buttonTitle: buttonTitle,
                        height: 52,
                        radius: 12,
                        isInProgress: isProcessing,
                        showProgressTitle: isProcessing,
                        titleWhenProgress: progressTitle,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          body: SafeArea(
            child: BlocBuilder<PromoteAdCubit, PromoteAdState>(
              builder: (context, promoteState) {
                final bool showOverlay = promoteState is PromoteAdChecking ||
                    promoteState is PromoteAdActing;

                return Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scrollCtrl,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        14.rw(context),
                        10.rh(context),
                        14.rw(context),
                        (media.viewPadding.bottom + 12).clamp(16, 32),
                      ),
                      child: _pageLoaded
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AdHero(
                                  imageUrl: widget.model.image ?? '',
                                  badgeColor: context.color.territoryColor,
                                ),
                                _buildLimitStatusCard(),
                                _SellingPoints(),
                                const SizedBox(height: 8),
                                _buildSubscriptionDetails(),
                                _ComparisonCard(),
                                const SizedBox(height: 16),
                                const SizedBox(height: 12),
                              ],
                            )
                          : _PageSkeleton(),
                    ),
                    if (showOverlay)
                      Positioned.fill(
                        child: Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withOpacity(0.65),
                          alignment: Alignment.center,
                          child: Shimmer.fromColors(
                            baseColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.3),
                            highlightColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 36,
                                height: 36,
                                child:
                                    CircularProgressIndicator(strokeWidth: 3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ============================
  // حوارات الدفع (مطابقة للأصل)
  // ============================

  Future<void> _showPurchaseCodeDialog(
      {required VoidCallback onConfirm}) async {
    final TextEditingController codeController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final fieldColor =
            isDark ? Colors.grey.shade800 : const Color(0xFFF5F5F5);
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular((16.0).rw(context))),
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          title: const Text("🧾 كود الشراء"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "رمز الشراء *",
                  filled: true,
                  fillColor: fieldColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular((10.0).rw(context))),
                ),
              ),
              SizedBox(height: (8.0).rh(context)),
              const Text("أدخل رمز الشراء الذي حصلت عليه لإتمام العملية",
                  style: TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء")),
            FilledButton(
              onPressed: () {
                if (codeController.text.trim().isEmpty) {
                  HelperUtils.showSnackBarMessage(
                      context, "يرجى إدخال كود الشراء");
                  return;
                }
                Navigator.pop(ctx);
                onConfirm();
              },
              child: const Text("تأكيد"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBankTransferDialog({
    required String paymentMethodName,
    required String accountName,
    required String accountNumber,
    required Future<void> Function(String name, String code, File? receipt)
        onConfirm,
  }) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController transferCodeController =
        TextEditingController();
    final ValueNotifier<bool> isUploading = ValueNotifier(false);
    final ValueNotifier<File?> receiptImage = ValueNotifier(null);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fieldColor =
        isDark ? Colors.grey.shade800 : const Color(0xFFF5F5F5);
    final Color mainColor = const Color(0xFFFF8000);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular((16.0).rw(context)),
          ),
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          title: const Text("💳 الدفع عن طريق حوالة مصرفية"),
          content: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اسم الوسيلة
                Text(
                  paymentMethodName,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: mainColor),
                ),
                SizedBox(height: (6.0).rh(context)),

                // رقم الحساب (إن وُجد) مع نسخ سريع
                if (accountNumber.trim().isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: accountNumber));
                      HelperUtils.showSnackBarMessage(
                          context, "✅ تم نسخ رقم الحساب");
                    },
                    borderRadius: BorderRadius.circular((10.0).rw(context)),
                    child: Container(
                      padding: EdgeInsets.all((10.0).rw(context)),
                      margin: EdgeInsets.only(bottom: (16.0).rh(context)),
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular((10.0).rw(context)),
                      ),
                      child: Text(accountNumber,
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ),

                // الاسم
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "الاسم *",
                    filled: true,
                    fillColor: fieldColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular((10.0).rw(context)),
                    ),
                  ),
                ),
                SizedBox(height: (12.0).rh(context)),

                // رقم الحوالة
                TextField(
                  controller: transferCodeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "رقم الحوالة *",
                    filled: true,
                    fillColor: fieldColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular((10.0).rw(context)),
                    ),
                  ),
                ),
                SizedBox(height: (16.0).rh(context)),

                // إرفاق الإيصال (اختياري)
                ValueListenableBuilder<File?>(
                  valueListenable: receiptImage,
                  builder: (_, file, __) {
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular((10.0).rw(context)),
                              ),
                            ),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final XFile? picked = await picker.pickImage(
                                  source: ImageSource.gallery);
                              if (picked != null) {
                                isUploading.value = true;
                                // ===== API HOOK: رفع الصورة لسيرفرك (اختياري) =====
                                await Future.delayed(
                                    const Duration(milliseconds: 750));
                                receiptImage.value = File(picked.path);
                                isUploading.value = false;
                                HelperUtils.showSnackBarMessage(
                                    context, "تم إرفاق صورة الإيصال");
                              }
                            },
                            icon: const Icon(Icons.attachment),
                            label: const Text("إرفاق صورة الإيصال"),
                          ),
                        ),
                        SizedBox(width: (8.0).rw(context)),
                        ValueListenableBuilder<bool>(
                          valueListenable: isUploading,
                          builder: (_, uploading, __) {
                            if (uploading) {
                              return const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              );
                            }
                            if (file != null) {
                              return const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 20),
                                  SizedBox(width: 4),
                                  Text("مرفق",
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.green)),
                                ],
                              );
                            }
                            return const Text("لم يتم الإرفاق",
                                style: TextStyle(color: Colors.grey));
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  HelperUtils.showSnackBarMessage(context, "يرجى إدخال الاسم");
                  return;
                }
                if (transferCodeController.text.trim().isEmpty) {
                  HelperUtils.showSnackBarMessage(
                      context, "يرجى إدخال رقم الحوالة");
                  return;
                }
                Navigator.pop(ctx);
                await onConfirm(
                  nameController.text.trim(),
                  transferCodeController.text.trim(),
                  receiptImage.value,
                );
              },
              child: const Text("تأكيد"),
            ),
          ],
        );
      },
    );
  }
}

/// =============================
/// عناصر الواجهة (كما في النسخة السابقة)
/// =============================

class _SummaryBar extends StatelessWidget {
  final String totalText;
  const _SummaryBar({required this.totalText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              totalText,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}

// صورة الإعلان + شارة "مُميز" يمين الصورة + شيمر آمن
class _AdHero extends StatelessWidget {
  final String imageUrl;
  final Color badgeColor;

  const _AdHero({required this.imageUrl, required this.badgeColor});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = w * 9 / 16;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: double.infinity,
        height: h,
        child: Stack(
          children: [
            const Positioned.fill(child: _ShimmerBox(height: double.infinity)),
            Positioned.fill(
              child: Image.network(
                imageUrl.isEmpty
                    ? 'https://via.placeholder.com/800x450?text=Ad'
                    : imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
            Positioned(
              right: 8, // يمين الشاشة للجمهور العربي
              top: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.local_fire_department,
                        size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('مُميز',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// بطاقة التسعير المتجاوبة (+/- بارزة)
class _PricingCard extends StatelessWidget {
  final int days;
  final double dailyPrice;
  final num total;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final String Function(num) formatYer;

  const _PricingCard({
    required this.days,
    required this.dailyPrice,
    required this.total,
    required this.onInc,
    required this.onDec,
    required this.formatYer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget stepBtn(IconData icon, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withOpacity(.3)),
          ),
          child: Icon(icon, size: 22),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('خطتك لتمييز الإعلان',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'اختر المدة المناسبة وابدأ بجذب الانتباه فورًا.',
            style: t.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(.7)),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.star_rate_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'السعر لليوم الواحد: ${formatYer(dailyPrice)}',
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stepBtn(Icons.remove, onDec),
              const SizedBox(width: 10),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$days ${_arabicDays(days)}',
                      style:
                          t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              stepBtn(Icons.add, onInc),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.payments_outlined, color: cs.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الإجمالي: ${formatYer(total)}',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _arabicDays(int d) {
    return (d == 1)
        ? 'يوم'
        : (d == 2)
            ? 'يومان'
            : (d >= 3 && d <= 10)
                ? 'أيام'
                : 'يوماً';
  }
}

class _SellingPoints extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    Widget chip(IconData icon, String title, String sub) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withOpacity(.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(sub,
                      style: t.bodySmall
                          ?.copyWith(color: cs.onSurface.withOpacity(.7))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        chip(Icons.visibility, 'ظهور أعلى القوائم',
            'إعلانك يبرز ويتقدّم نتائج البحث.'),
        const SizedBox(height: 8),
        chip(Icons.flash_on, 'تفاعل أسرع',
            'نقرات أكثر ومحادثات خلال فترة التمييز.'),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    Widget line(IconData icon, String text) {
      return Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, textDirection: TextDirection.rtl)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الفرق بين العادي والمميز',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          line(Icons.filter_none, 'المميز يظهر أعلى النتائج وبشارة لافتة.'),
          const SizedBox(height: 6),
          line(Icons.timeline, 'تحسّن ملحوظ في الانطباعات والنقرات.'),
        ],
      ),
    );
  }
}

// بطاقات الدفع (الشكل المعتمد) — بدون حقول داخلية؛ الحقول في الحوارات فقط
class _PaymentSectionOriginal extends StatelessWidget {
  final bool loading;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  const _PaymentSectionOriginal({
    required this.loading,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ShimmerTitle(text: 'الدفع'),
          SizedBox(height: 10),
          _ShimmerBox(height: 86, radius: 14),
          SizedBox(height: 8),
          _ShimmerBox(height: 86, radius: 14),
          SizedBox(height: 8),
          _ShimmerBox(height: 86, radius: 14),
        ],
      );
    }

    Widget bankTile({
      required int index,
      required String name,
      required String logo,
      required bool isInstant,
    }) {
      final selected = selectedIndex == index;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Material(
          color:
              selected ? cs.surface : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(index),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                    color: selected ? cs.primary : cs.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      logo,
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.account_balance_wallet),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: t.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        if (isInstant)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF8000),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('فوري',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: selected
                        ? Icon(Icons.check_circle,
                            color: const Color(0xFFFF8000),
                            key: const ValueKey('on'))
                        : const Icon(Icons.circle_outlined,
                            key: ValueKey('off')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الدفع',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        bankTile(
          index: 0,
          name: "الدفع بواسطة بنك الشرق اليمني",
          logo: "assets/svg/Logo/بنك الشرق اليمني.png",
          isInstant: true,
        ),
        bankTile(
          index: 1,
          name: "نقطة إيزي كاش",
          logo: "assets/svg/Logo/نقطة إيزي كاش.png",
          isInstant: false,
        ),
        bankTile(
          index: 2,
          name: "الشبكة ( الحولات الداخلية )",
          logo: "assets/svg/Logo/الشبكة.png",
          isInstant: false,
        ),
      ],
    );
  }
}

class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _ShimmerBox(height: 180),
        SizedBox(height: 12),
        _ShimmerBox(height: 140),
        SizedBox(height: 12),
        _ShimmerBox(height: 80),
        SizedBox(height: 8),
        _ShimmerBox(height: 120),
      ],
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  const _ShimmerBox({required this.height, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlight = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 900),
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _ShimmerTitle extends StatelessWidget {
  final String text;
  const _ShimmerTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Text(text,
        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700));
  }
}
