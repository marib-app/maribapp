import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/cubits/subscription/assign_free_package_cubit.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/data/model/subscription_pacakage_model.dart';
import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:marib/utils/payment/bank_transfer_screen.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';

import 'package:marib/ui/screens/Transaction_screen.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';

import 'package:marib/utils/payment/gatways/inAppPurchaseManager.dart';
import 'package:marib/utils/ui_utils.dart';

class FeaturedAdsSubscriptionPlansItem extends StatefulWidget {
  final List<SubscriptionPackageModel> modelList;
  final InAppPurchaseManager inAppPurchaseManager;

  const FeaturedAdsSubscriptionPlansItem({
    super.key,
    required this.modelList,
    required this.inAppPurchaseManager,
  });

  @override
  _FeaturedAdsSubscriptionPlansItemState createState() =>
      _FeaturedAdsSubscriptionPlansItemState();
}

class _FeaturedAdsSubscriptionPlansItemState
    extends State<FeaturedAdsSubscriptionPlansItem> {
  int? selectedIndex;

  Widget mainUi(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      margin: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Card(
        color: context.color.secondaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.0),
        ),
        elevation: 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, //temp
          children: [
            SizedBox(
              height: 50,
            ),
            UiUtils.getSvg(AppIcons.featuredAdsIcon),
            SizedBox(
              height: 35,
            ),
            Text("featureAd".translate(context))
                .bold(weight: FontWeight.w600)
                .size(context.font.larger),
            Expanded(
              child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  itemBuilder: (context, index) {
                    return itemData(index);
                  },
                  itemCount: widget.modelList.length),
            ),
            if (selectedIndex != null)
              BlocListener<AssignFreePackageCubit, AssignFreePackageState>(
                listener: (context, state) {
                  if (state is AssignFreePackageInSuccess) {
                    Widgets.hideLoder(context);
                    HelperUtils.showSnackBarMessage(
                      context,
                      state.responseMessage,
                      type: MessageType.success,
                    );
                    Navigator.pop(context);
                  }
                  if (state is AssignFreePackageFailure) {
                    Widgets.hideLoder(context);
                    HelperUtils.showSnackBarMessage(
                        context, state.error.toString());
                  }
                  if (state is AssignFreePackageInProgress) {
                    Widgets.showLoader(context);
                  }
                },
                child: Builder(
                  builder: (buttonContext) {
                    final package = widget.modelList[selectedIndex!];
                    final isActive = package.isActive ?? false;
                    final price = package.finalPrice ?? 0;

                    return UiUtils.buildButton(buttonContext,
                        onPressed: () async {
                      UiUtils.checkUser(
                        onNotGuest: () async {
                          if (isActive) {
                            return;
                          }

                          final packageId = package.id;
                          if (packageId == null) {
                            HelperUtils.showSnackBarMessage(
                              buttonContext,
                              "somethingWentWrng".translate(buttonContext),
                              type: MessageType.error,
                            );
                            return;
                          }

                          if (price <= 0) {
                            buttonContext
                                .read<AssignFreePackageCubit>()
                                .assignFreePackage(packageId: packageId);
                            return;
                          }

                          final token = HiveUtils.getJWT();
                          if (token.isEmpty) {
                            HelperUtils.showSnackBarMessage(
                              buttonContext,
                              "loginFirst".translate(buttonContext),
                            );
                            return;
                          }
                          final packageCurrency = package.currency?.trim();

                          final args = BankTransferArgs(
                            token: token,
                            packageId: packageId,
                            amount: price.toDouble(),
                            currency: (packageCurrency?.isNotEmpty ?? false)
                                ? packageCurrency
                                : null,
                            packageType: 'featured_ad',
                            purpose: 'package',
                            itemId: null,
                          );

                          final ok = await Navigator.of(buttonContext).push(
                            BankTransferScreen.route(
                              RouteSettings(
                                name: '/bank-transfer',
                                arguments: args,
                              ),
                            ),
                          );

                          if (!mounted) {
                            return;
                          }

                          ManualPaymentSubmissionResult? submissionResult;
                          final bool success;
                          if (ok is ManualPaymentSubmissionResult) {
                            submissionResult = ok;
                            success = ok.success;
                          } else {
                            success = ok == true;
                          }

                          if (success) {
                            HelperUtils.showSnackBarMessage(
                              buttonContext,
                              "manualPaymentSubmitted".translate(buttonContext),
                              type: MessageType.success,
                            );

                            final routeArgs =
                                submissionResult?.paymentTransaction ??
                                    submissionResult?.manualPaymentRequest ??
                                    submissionResult?.raw;

                            Navigator.of(buttonContext).push(
                              TransactionScreen.route(
                                RouteSettings(
                                  name: '/transactions',
                                  arguments: routeArgs,
                                ),
                              ),
                            );
                          } else {
                            final bool wasCancelled = ok == null;
                            final String failureMessage =
                                submissionResult?.message?.isNotEmpty == true
                                    ? submissionResult!.message!
                                    : wasCancelled
                                        ? "manualPaymentSubmissionCancelled"
                                            .translate(buttonContext)
                                        : "somethingWentWrng"
                                            .translate(buttonContext);

                            HelperUtils.showSnackBarMessage(
                              buttonContext,
                              failureMessage,
                              type: MessageType.error,
                            );
                          }
                        },
                        context: buttonContext,
                      );
                    },
                        radius: 10,
                        height: 46,
                        fontSize: buttonContext.font.large,
                        buttonColor: isActive
                            ? buttonContext.color.textLightColor.brighten(300)
                            : buttonContext.color.territoryColor,
                        textColor: isActive
                            ? buttonContext.color.textDefaultColor
                                .withOpacity(0.5)
                            : buttonContext.color.secondaryColor,
                        buttonTitle: price > 0
                            ? "${"payLbl".translate(buttonContext)}\t${Constant.currencySymbol}${price.toStringAsFixed(2)}"
                            : "purchaseThisPackage".translate(buttonContext),

                        //TODO: change title to Your Current Plan according to condition
                        outerPadding: const EdgeInsets.all(20));
                  },
                ),
              )
          ],
        ),
      ),
    );
  }

/*  Future<void> _purchaseSubscription(SubscriptionPackageModel model) async {
    bool success = await widget.inAppPurchaseManager
        .purchaseSubscription(model.iosProductId!);
    if (success) {
      // Handle successful purchase
    } else {
      // Handle failed purchase
    }
  }*/

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AssignFreePackageCubit(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: context.color.backgroundColor,
            body: mainUi(context),
          );
        },
      ),
    );
  }

  Widget itemData(int index) {
    return Padding(
      padding: const EdgeInsets.only(top: 7.0),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          if (widget.modelList[index].isActive!)
            Padding(
              padding: EdgeInsetsDirectional.only(start: 13.0),
              child: ClipPath(
                clipper: CapShapeClipper(),
                child: Container(
                  color: context.color.territoryColor,
                  width: MediaQuery.of(context).size.width / 3,
                  height: 17,
                  padding: EdgeInsets.only(top: 3),
                  child: Text('activePlanLbl'.translate(context))
                      .color(context.color.secondaryColor)
                      .centerAlign()
                      .bold(weight: FontWeight.w500)
                      .size(12),
                ),
              ),
            ),
          InkWell(
            onTap: !widget.modelList[index].isActive!
                ? () {
                    setState(() {
                      selectedIndex = index;
                    });
                  }
                : null,
            child: Container(
              margin: EdgeInsets.only(top: 17),
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                      color: widget.modelList[index].isActive! ||
                              index == selectedIndex
                          ? context.color.territoryColor
                          : context.color.textDefaultColor.withOpacity(0.1),
                      width: 1.5)),
              child: !widget.modelList[index].isActive!
                  ? adsWidget(index)
                  : activeAdsWidget(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget adsWidget(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.modelList[index].name!)
                  .firstUpperCaseWidget()
                  .bold(weight: FontWeight.w600)
                  .size(context.font.large),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.modelList[index].limit == "unlimited" ? "unlimitedLbl".translate(context) : widget.modelList[index].limit.toString()}\t${"adsLbl".translate(context)}\t\t·\t\t',
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ).color(context.color.textDefaultColor.withOpacity(0.5)),
                  Flexible(
                    child: Text(
                      '${widget.modelList[index].duration.toString()}\t${"days".translate(context)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ).color(context.color.textDefaultColor.withOpacity(0.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(start: 10.0),
          child: Text(
            widget.modelList[index].finalPrice! > 0
                ? "${Constant.currencySymbol}${widget.modelList[index].finalPrice.toString()}"
                : "free".translate(context),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget activeAdsWidget(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.modelList[index].name!)
                  .firstUpperCaseWidget()
                  .bold(weight: FontWeight.w600)
                  .size(context.font.large),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: widget.modelList[index].limit == "unlimited"
                          ? "${"unlimitedLbl".translate(context)}\t${"adsLbl".translate(context)}\t\t·\t\t"
                          : '',
                      style: TextStyle(
                        color: context.color.textDefaultColor.withOpacity(0.5),
                      ),
                      children: [
                        if (widget.modelList[index].limit != "unlimited")
                          TextSpan(
                            text:
                                '${widget.modelList[index].userPurchasedPackages![0].remainingItemLimit}',
                            style: TextStyle(
                                color: context.color.textDefaultColor),
                          ),
                        if (widget.modelList[index].limit != "unlimited")
                          TextSpan(
                            text:
                                '/${widget.modelList[index].limit.toString()}\t${"adsLbl".translate(context)}\t\t·\t\t',
                          ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: widget.modelList[index].duration == "unlimited"
                            ? "${"unlimitedLbl".translate(context)}\t${"days".translate(context)}"
                            : '',
                        style: TextStyle(
                          color:
                              context.color.textDefaultColor.withOpacity(0.5),
                        ),
                        children: [
                          if (widget.modelList[index].duration != "unlimited")
                            TextSpan(
                              text:
                                  '${widget.modelList[index].userPurchasedPackages![0].remainingDays}',
                              style: TextStyle(
                                  color: context.color.textDefaultColor),
                            ),
                          if (widget.modelList[index].duration != "unlimited")
                            TextSpan(
                              text:
                                  '/${widget.modelList[index].duration.toString()}\t${"days".translate(context)}',
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(start: 10.0),
          child: Text(
            widget.modelList[index].finalPrice! > 0
                ? "${Constant.currencySymbol}${widget.modelList[index].finalPrice.toString()}"
                : "free".translate(context),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    path
      ..moveTo(size.width / 2, 0) // moving to topCenter 1st, then draw the path
      ..lineTo(size.width, size.height * .25)
      ..lineTo(size.width, size.height * .75)
      ..lineTo(size.width * .5, size.height)
      ..lineTo(0, size.height * .75)
      ..lineTo(0, size.height * .25)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }
}

class CapShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..cubicTo(
        size.width * 0.15,
        size.height,
        size.width * 0.1,
        size.height * 0.1,
        size.width * 0.25,
        size.height * 0.1,
      )
      ..lineTo(size.width * 0.75, size.height * 0.1)
      ..cubicTo(
        size.width * 0.9,
        size.height * 0.1,
        size.width * 0.85,
        size.height,
        size.width,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}
