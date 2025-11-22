
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/notifications/notification_detail_cubit.dart';
import 'package:marib/data/model/notification_data.dart';
import 'package:marib/data/repositories/notifications_repository_repository.dart';
import 'package:marib/ui/screens/notifications/action_request_details_screen.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:marib/utils/payment/bank_transfer_screen.dart';
import 'package:marib/utils/payment/manual_payment_service.dart'
    show ManualPaymentService, ManualPaymentSubmissionResult;
import 'package:marib/utils/payment/payment_route_result.dart';

class NotificationDetail extends StatelessWidget {
  const NotificationDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final Object? args = ModalRoute.of(context)?.settings.arguments;
    if (args is! NotificationData) {
      return _buildEmptyScaffold(context);
    }

    return BlocProvider(
      create: (_) => NotificationDetailCubit(NotificationsRepository())
        ..load(args.id, args),
      child: _NotificationDetailContent(initialNotification: args),
    );
  }

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const NotificationDetail(),
      settings: routeSettings,
    );
  }

  Widget _buildEmptyScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "notifications".translate(context),
        showBackButton: true,
      ),
      body: const Center(child: Text('notification_not_available')),
    );
  }
}

class _NotificationDetailContent extends StatelessWidget {
  const _NotificationDetailContent({required this.initialNotification});

  final NotificationData initialNotification;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "notifications".translate(context),
        showBackButton: true,
      ),
      body: BlocBuilder<NotificationDetailCubit, NotificationDetailState>(
        builder: (context, state) {
          if (state is NotificationDetailLoading ||
              state is NotificationDetailInitial) {
            return const _DetailShimmer();
          }
          if (state is NotificationDetailFailure) {
            return _DetailError(
              onRetry: () => context
                  .read<NotificationDetailCubit>()
                  .load(initialNotification.id, initialNotification),
            );
          }
          if (state is NotificationDetailSuccess) {
            return _DetailBody(notification: state.notification);
          }
          return const _DetailShimmer();
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.notification});

  final NotificationData notification;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = HelperUtils.absoluteImage(
      notification.image ?? notification.data['image'],
    );
    final String title = (notification.title ?? '').trim();
    final String message = (notification.displayMessage ?? '').trim();
    final String created = notification.createdAt ??
        notification.deliveredAt?.toIso8601String() ??
        '';
    final String timeStr = created.isEmpty
        ? ''
        : intl.DateFormat("d MMMM yyyy - h:mm a", 'ar')
            .format(DateTime.parse(created));
    final ActionRequestRouteArgs? actionArgs =
        _parseActionRequest(notification);
    final NotificationPaymentRequest? paymentRequest =
        notification.paymentRequest;

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: <Widget>[
        if (imageUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: _NetworkImageSafe(imgUrl: imageUrl),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 10),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: Colors.grey.withOpacity(0.25),
          ),
        ),
        const SizedBox(height: 10),
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Linkify(
              text: message,
              style: Theme.of(context).textTheme.bodyMedium,
              options: const LinkifyOptions(looseUrl: true),
              onOpen: (link) async {
                final uri = Uri.tryParse(link.url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        if (paymentRequest != null) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _PaymentRequestCard(
              notification: notification,
              request: paymentRequest,
            ),
          ),
        ],
        if (actionArgs != null) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  Routes.actionRequestPage,
                  arguments: actionArgs,
                ),
                child: Text("open".translate(context)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  ActionRequestRouteArgs? _parseActionRequest(NotificationData notification) {
    final String? deeplink =
        notification.deeplink ?? notification.data['deeplink']?.toString();
    if (deeplink == null || deeplink.isEmpty) {
      return null;
    }
    final Uri? uri = Uri.tryParse(deeplink);
    if (uri == null || uri.scheme != 'marib' || uri.host != 'action-request') {
      return null;
    }
    if (uri.pathSegments.isEmpty) {
      return null;
    }
    final String id = uri.pathSegments.first;
    final String? token = uri.queryParameters['token'];
    if (id.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return ActionRequestRouteArgs(requestId: id, token: token);
  }
}

class _PaymentRequestCard extends StatefulWidget {
  const _PaymentRequestCard({
    required this.notification,
    required this.request,
  });

  final NotificationData notification;
  final NotificationPaymentRequest request;

  @override
  State<_PaymentRequestCard> createState() => _PaymentRequestCardState();
}

class _PaymentRequestCardState extends State<_PaymentRequestCard> {
  bool _submitting = false;

  Future<void> _startPaymentFlow() async {
    if (_submitting) return;
    if (!HiveUtils.isUserAuthenticated()) {
      UiUtils.checkUser(onNotGuest: () {}, context: context);
      return;
    }
    final String token = HiveUtils.getJWT();
    if (token.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'loginFirst'.translate(context),
      );
      return;
    }

    final NotificationPaymentRequest request = widget.request;
    final BankTransferArgs args = BankTransferArgs(
      token: token,
      packageId: int.tryParse(widget.notification.id) ?? 0,
      amount: request.amount,
      currency: request.currency,
      packageType: 'wallet_top_up',
      purpose: ManualPaymentService.walletTopUpPurpose,
      allowedGateways:
          request.allowedGateways.isEmpty ? null : request.allowedGateways,
      allowWalletGateway: true,
    );

    setState(() => _submitting = true);

    try {
      final dynamic result = await BankTransferScreen.show(context, args);
      if (!mounted || result == null || result == false) {
        return;
      }
      if (!mounted) return;
      final _PaymentResult? mapped = _PaymentResult.fromRaw(result);
      if (mapped == null) {
        HelperUtils.showSnackBarMessage(
          context,
          'تعذر تحديد نتيجة عملية الدفع.',
        );
        return;
      }

      await context.read<NotificationDetailCubit>().updatePaymentRequest(
            notification: widget.notification,
            status: mapped.status,
            transactionId: mapped.transactionId,
            reference: mapped.reference,
          );

      if (!mounted) return;

      final String successMessage = mapped.status == 'paid'
          ? 'تم تسجيل الدفعة بنجاح.'
          : 'تم إرسال تفاصيل الدفع وبانتظار المراجعة.';
      HelperUtils.showSnackBarMessage(context, successMessage);
    } catch (error) {
      HelperUtils.showSnackBarMessage(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final NotificationPaymentRequest request = widget.request;
    final ColorScheme palette = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool isCancelled = request.status == 'cancelled';
    final Color statusColor = request.isPaid
        ? Colors.green
        : request.isSubmitted
            ? Colors.orange
            : isCancelled
                ? Colors.red
                : palette.territoryColor;
    final String statusLabel = request.isPaid
        ? 'مدفوع'
        : request.isSubmitted
            ? 'قيد المراجعة'
            : isCancelled
                ? 'ملغى'
                : 'بانتظار الدفع';

    return Card(
      margin: EdgeInsets.zero,
      color: palette.secondaryColor.withOpacity(0.65),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.territoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.request_page_outlined,
                    color: palette.territoryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دفعة مطلوبة',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.formattedAmount,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        request.isPaid
                            ? Icons.verified_rounded
                            : Icons.av_timer_rounded,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((request.note ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                request.note!,
                style: textTheme.bodyMedium
                    ?.copyWith(color: palette.textLightColor),
              ),
            ],
            if ((request.transactionId ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'مرجع العملية: ${request.transactionId}',
                style: textTheme.bodySmall
                    ?.copyWith(color: palette.textLightColor),
              ),
            ],
            const SizedBox(height: 16),
            if (request.isPending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _startPaymentFlow,
                  icon: _submitting
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.onPrimary,
                          ),
                        )
                      : const Icon(Icons.credit_score_rounded),
                  label: Text(
                    _submitting ? 'جاري التحضير...' : 'ادفع الآن',
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      request.isPaid
                          ? Icons.verified_rounded
                          : Icons.fact_check_rounded,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      request.isPaid
                          ? 'تمت معالجة الدفعة'
                          : isCancelled
                              ? 'تم إلغاء الطلب من قبل الفريق'
                              : 'بانتظار مراجعة فريق المدفوعات',
                      style: textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentResult {
  const _PaymentResult({
    required this.status,
    this.transactionId,
    this.reference,
  });

  final String status;
  final String? transactionId;
  final String? reference;

  static _PaymentResult? fromRaw(dynamic result) {
    if (result is PaymentRouteResult) {
      final String? reference =
          result.manualRequestId?.toString() ?? result.walletTxnId?.toString();
      final String status = result.kind == PaymentRouteKind.walletSuccess
          ? 'paid'
          : 'submitted';
      return _PaymentResult(
        status: status,
        transactionId: reference,
        reference: reference,
      );
    }
    if (result is ManualPaymentSubmissionResult) {
      final String? transactionId =
          result.paymentTransactionId ?? result.manualPaymentId;
      final String lowered = (result.status ?? '').toLowerCase();
      final bool immediateSuccess = !result.requiresConfirmation &&
          (lowered == 'succeeded' ||
              lowered == 'approved' ||
              lowered == 'paid');
      return _PaymentResult(
        status: immediateSuccess ? 'paid' : 'submitted',
        transactionId: transactionId ?? result.paymentIntentId,
        reference: result.manualPaymentId ?? result.paymentTransactionId,
      );
    }
    return null;
  }
}

class _DetailShimmer extends StatelessWidget {
  const _DetailShimmer();

  @override
  Widget build(BuildContext context) {
    final Color base = context.color.secondaryColor;
    return Container(
      color: base,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ShimmerBlock(height: 140),
          SizedBox(height: 16),
          _ShimmerBlock(height: 18, width: 120),
          SizedBox(height: 8),
          _ShimmerBlock(height: 20, width: double.infinity),
          SizedBox(height: 24),
          _ShimmerParagraph(lines: 5),
        ],
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CustomShimmer(
        height: height,
        width: width ?? double.infinity,
      ),
    );
  }
}

class _ShimmerParagraph extends StatelessWidget {
  const _ShimmerParagraph({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        lines,
        (int index) => Padding(
          padding: EdgeInsets.only(bottom: index == lines - 1 ? 0 : 8),
          child: _ShimmerBlock(
            height: 14,
            width: index == lines - 1 ? 180 : double.infinity,
          ),
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SomethingWentWrong(),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: Text('retry'.translate(context)),
          ),
        ],
      ),
    );
  }
}

class _NetworkImageSafe extends StatelessWidget {
  final String imgUrl;
  const _NetworkImageSafe({required this.imgUrl});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imgUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
