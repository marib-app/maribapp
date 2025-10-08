

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/data/cubits/subscription/assign_free_package_cubit.dart';
import 'package:marib/data/model/subscription_pacakage_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;

import 'package:marib/utils/payment/gatways/inAppPurchaseManager.dart';

import 'package:marib/data/helper/widgets.dart';
import 'package:marib/utils/payment/bank_transfer_screen.dart';
import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/ui/screens/Transaction_screen.dart'; // مسار شاشة المعاملات
import 'package:marib/utils/payment/manual_payment_service.dart';



class ItemListingSubscriptionPlansItem extends StatefulWidget {
  final int itemIndex, index;
  final SubscriptionPackageModel model;
  final InAppPurchaseManager inAppPurchaseManager;

  const ItemListingSubscriptionPlansItem({
    super.key,
    required this.itemIndex,
    required this.index,
    required this.model,
    required this.inAppPurchaseManager,
  });

  @override
  _ItemListingSubscriptionPlansItemState createState() =>
      _ItemListingSubscriptionPlansItemState();
}

class _ItemListingSubscriptionPlansItemState
    extends State<ItemListingSubscriptionPlansItem> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      bottomNavigationBar: bottomWidget(),
        body: BlocProvider(
          create: (context) => AssignFreePackageCubit(),
          child: BlocListener<AssignFreePackageCubit, AssignFreePackageState>(
            listener: (context, state) {
              if (state is AssignFreePackageInSuccess) {
                Widgets.hideLoder(context);
                HelperUtils.showSnackBarMessage(
                  context,
                  state.responseMessage,
                );
                Navigator.pop(context);
              }
              if (state is AssignFreePackageFailure) {
                Widgets.hideLoder(context);
                HelperUtils.showSnackBarMessage(
                  context,
                  state.error.toString(),
                );
              }
              if (state is AssignFreePackageInProgress) {
                Widgets.showLoader(context);
              }
            },
            child: Padding(
                padding: EdgeInsets.only(
                  top: (widget.index == widget.itemIndex) ? 40 : 70,
                  bottom: (widget.index == widget.itemIndex) ? 100 : 120,
                ),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    if (widget.model.isActive!)
                      ClipPath(
                        clipper: CapShapeClipper(),
                        child: Container(
                          alignment: Alignment.center,
                          color: context.color.territoryColor,
                          width: MediaQuery.of(context).size.width / 1.6,
                          height: 33,
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('activePlanLbl'.translate(context))
                              .color(context.color.secondaryColor)
                              .centerAlign()
                              .bold(weight: FontWeight.w500)
                              .size(15),
                        ),
                      ),
                    Card(
                      color: context.color.secondaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                        side: BorderSide(
                          color: widget.model.isActive!
                              ? context.color.territoryColor
                              : context.color.secondaryColor,
                          width: 1.5,
                        ),
                      ),
                      elevation: 0,
                      margin: const EdgeInsets.fromLTRB(14, 33, 14, 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(height: 50.rh(context)),
                          ClipPath(
                            clipper: HexagonClipper(),
                            child: Container(
                              width: 100,
                              height: 110,
                              padding: const EdgeInsets.all(30),
                              color: context.color.primaryColor,
                              child: UiUtils.imageType(
                                widget.model.icon!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SizedBox(height: 18.rh(context)),
                          widget.model.isActive! && widget.model.finalPrice! > 0
                              ? activeAdsData()
                              : adsData(),

                          const Spacer(),
                          Text(
                            widget.model.finalPrice! > 0
                                ? "${Constant.currencySymbol}${widget.model.finalPrice.toString()}"
                                : "free".translate(context),
                          ).size(context.font.xxLarge).bold(),
                          if (widget.model.discount! > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("${widget.model.discount}%\t${"OFF".translate(context)}")
                                      .color(context.color.forthColor)
                                      .bold(),
                                  SizedBox(width: 5.rh(context)),
                                  Text(
                                    " ${Constant.currencySymbol}${widget.model.price.toString()}",
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // زر الشراء/التفعيل — مُعالج بدون fallback
// زر الشراء/التفعيل — تحويل بنكي فقط + مجاني عبر الكيوبت
                          UiUtils.buildButton(
                            context,
                            onPressed: () async {
                              UiUtils.checkUser(
                                onNotGuest: () async {
                                  if (widget.model.isActive!) return;

                                  // مجاني
                                  if (widget.model.finalPrice! <= 0) {
                                    context.read<AssignFreePackageCubit>().assignFreePackage(
                                      packageId: widget.model.id!,
                                    );
                                    return;
                                  }

                                  // مدفوع: افتح شاشة التحويل البنكي
                                  final token = HiveUtils.getJWT();
                                  if (token == null || token.isEmpty) {
                                    HelperUtils.showSnackBarMessage(context, "سجّل الدخول أولاً");
                                    return;
                                  }


                                  final packageCurrency =
                                  widget.model.currency?.trim();

                                  final ok = await Navigator.of(context).push(
                                    BankTransferScreen.route(
                                      RouteSettings(
                                        name: '/bank-transfer',
                                        arguments: BankTransferArgs(
                                          token: token,
                                          packageId: widget.model.id!,
                                          amount: widget.model.finalPrice!.toDouble(),
                                          currency:
                                          (packageCurrency?.isNotEmpty ?? false)
                                              ? packageCurrency
                                              : null,
                                          packageType: 'item_listing',
                                          purpose: 'package',
                                          itemId: null,
                                        ),
                                      ),
                                    ),
                                  );

                                  if (!mounted) return;

                                  final bool success;
                                  ManualPaymentSubmissionResult? submissionResult;
                                  if (ok is ManualPaymentSubmissionResult) {
                                    submissionResult = ok;
                                    success = ok.success;
                                  } else {
                                    success = ok == true;
                                  }

                                  if (success) {



                                    // انتقل لواجهة المعاملات

                                    final routeArgs =
                                        submissionResult?.paymentTransaction ??
                                            submissionResult
                                                ?.manualPaymentRequest ??
                                            submissionResult?.raw;

                                    Navigator.of(context).push(
                                      TransactionScreen.route(
                                        RouteSettings(
                                          name: '/transactions',
                                          arguments: routeArgs,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                context: context,
                              );
                            },
                            radius: 10,
                            height: 46,
                            fontSize: context.font.large,
                            buttonColor: widget.model.isActive!
                                ? context.color.textLightColor.brighten(300)
                                : context.color.territoryColor,
                            textColor: widget.model.isActive!
                                ? context.color.textDefaultColor.withOpacity(0.5)
                                : context.color.secondaryColor,
                            buttonTitle: "purchaseThisPackage".translate(context),
                            outerPadding: const EdgeInsets.all(20),
                          )
,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }





  Widget adsData() {
    return Expanded(
      flex: 10,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        children: [
          Text(widget.model.name!)
              .firstUpperCaseWidget()
              .centerAlign()
              .copyWith(
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontWeight: FontWeight.w600,
            ),
          )
              .size(context.font.larger),
          const SizedBox(height: 15),
          if (widget.model.type == "item_listing")
            checkmarkPoint(
              context,
              "${widget.model.limit == "unlimited" ? "unlimitedLbl".translate(context) : widget.model.limit.toString()}\t${"adsListing".translate(context)}",
            ),
          if (widget.model.type == "advertisement")
            checkmarkPoint(
              context,
              "${widget.model.limit == "unlimited" ? "unlimitedLbl".translate(context) : widget.model.limit.toString()}\t${"featuredAdsListing".translate(context)}",
            ),
          checkmarkPoint(
            context,
            "${widget.model.duration.toString()}\t${"days".translate(context)}",
          ),
          if (widget.model.description != null &&
              widget.model.description != "") ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.model.description!,
                  textAlign: TextAlign.start,
                ).color(context.color.textDefaultColor.withOpacity(0.7)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget activeAdsData() {
    return Expanded(
      flex: 10,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        children: [
          Text(widget.model.name!)
              .firstUpperCaseWidget()
              .copyWith(
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontWeight: FontWeight.w600,
            ),
          )
              .size(context.font.larger)
              .centerAlign(),
          const SizedBox(height: 15),
          if (widget.model.type == "item_listing")
            checkmarkPoint(
              context,
              "${widget.model.userPurchasedPackages![0].remainingItemLimit}/${widget.model.limit == "unlimited" ? "unlimitedLbl".translate(context) : widget.model.limit.toString()}\t${"adsListing".translate(context)}",
            ),
          if (widget.model.type == "advertisement")
            checkmarkPoint(
              context,
              "${widget.model.userPurchasedPackages![0].remainingItemLimit}/${widget.model.limit == "unlimited" ? "unlimitedLbl".translate(context) : widget.model.limit.toString()}\t${"featuredAdsListing".translate(context)}",
            ),
          checkmarkPoint(
            context,
            "${widget.model.userPurchasedPackages![0].remainingDays}/${widget.model.duration.toString()}\t${"days".translate(context)}",
          ),
          if (widget.model.description != null &&
              widget.model.description != "")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.model.description!,
                  textAlign: TextAlign.start,
                ).color(context.color.textDefaultColor.withOpacity(0.7)),
              ),
            ),
        ],
      ),
    );
  }

  SingleChildRenderObjectWidget bottomWidget() {
    if (widget.model.isActive! &&
        widget.model.finalPrice! > 0 &&
        widget.model.userPurchasedPackages != null &&
        widget.model.userPurchasedPackages![0].endDate != null) {
      DateTime dateTime =
      DateTime.parse(widget.model.userPurchasedPackages![0].endDate!);
      String formattedDate = intl.DateFormat.yMMMMd().format(dateTime);
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 15.0, start: 15, end: 15),
        child: Text(
          "${"yourSubscriptionWillExpireOn".translate(context)} $formattedDate",
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget circlePoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 2.0),
            child: Icon(Icons.circle_rounded, size: 8),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(text, textAlign: TextAlign.start)
                .color(context.color.textDefaultColor),
          ),
        ],
      ),
    );
  }

  Widget checkmarkPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiUtils.getSvg(AppIcons.active_mark),
          SizedBox(width: 8.rw(context)),
          Expanded(
            child: Text(text, textAlign: TextAlign.start).color(
              context.color.textDefaultColor,
            ),
          ),
        ],
      ),
    );
  }
}



class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    path
      ..moveTo(size.width / 2, 0)
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
