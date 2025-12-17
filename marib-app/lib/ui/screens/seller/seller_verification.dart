import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/seller/fetch_seller_verification_field.dart';
import 'package:marib/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:marib/data/cubits/seller/send_verification_field_cubit.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/data/model/verification_request_model.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/verification_metadata.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/ui/screens/home_screen/home_screen.dart';
import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:marib/utils/payment/bank_transfer_screen.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:marib/utils/payment/payment_route_result.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/app/app_scroll_behavior.dart';

class SellerVerificationScreen extends StatefulWidget {
  final bool isResubmitted;

  SellerVerificationScreen({super.key, required this.isResubmitted});

  @override
  CloudState<SellerVerificationScreen> createState() =>
      _SellerVerificationScreenState();

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;
    return BlurredRouter(
      builder: (context) {
        return SellerVerificationScreen(
          isResubmitted: arguments?["isResubmitted"],
        );
      },
    );
  }
}

class _SellerVerificationScreenState
    extends CloudState<SellerVerificationScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  double fillValue = 0.5;
  int page = 1;
  bool isBack = false;
  List<CustomFieldBuilder> moreDetailDynamicFields = [];
  final _scrollController = ScrollController();
  bool _hasRequestedFields = false;
  bool _paymentInProgress = false;

  @override
  void initState() {
    super.initState();
    AbstractField.fieldsData.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isResubmitted == true) {
        context
            .read<FetchVerificationRequestsCubit>()
            .fetchVerificationRequests();
      }
    });

    nameController.text = (HiveUtils.getUserDetails().name) ?? "";
    emailController.text = HiveUtils.getUserDetails().email ?? "";
    addressController.text = HiveUtils.getUserDetails().address ?? "";
    phoneController.text = HiveUtils.getUserDetails().mobile ?? "";
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    super.dispose();
    phoneController.dispose();
    nameController.dispose();
    emailController.dispose();
    addressController.dispose();
    _scrollController.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.atEdge) {
      if (_scrollController.position.pixels != 0) {
        // Reached the bottom of the list
        FocusScope.of(context).unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: isBack,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        if (page == 2) {
          setState(() {
            page = 1;
            fillValue = 0.5;
            isBack = false;
          });
        } else {
          setState(() {
            isBack = true;
          });
        }
      },
      child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          appBar: UiUtils.buildAppBar(context, showBackButton: true,
              onBackPress: () {
            if (page == 2) {
              setState(() {
                page = 1;
                fillValue = 0.5;
              });
            } else {
              Navigator.pop(context);
            }
          }),
          bottomNavigationBar: bottomBar(),
          body: mainBody()),
    );
  }

/*  Map<String, dynamic> convertToCustomFields(Map<dynamic, dynamic> fieldsData) {
     return fieldsData.map((key, value) {
      return MapEntry('verification_field[$key]', value);
    });
  }*/

  Map<String, dynamic> convertToCustomFields(Map<dynamic, dynamic> fieldsData) {
    final Map<String, dynamic> mapped = {};


    fieldsData.forEach((key, dynamic rawValue) {
      final String fieldKey = 'verification_field[$key]';

      if (rawValue is Iterable) {
        final List<String> sanitized = rawValue
            .map((element) => element?.toString().trim() ?? '')
            .where((element) => element.isNotEmpty)
            .toList();

        mapped[fieldKey] = sanitized.isEmpty ? '' : sanitized.join(',');
      } else if (rawValue != null) {
        final String value = rawValue.toString().trim();
        mapped[fieldKey] = value;
      } else {
        mapped[fieldKey] = '';
      }
    });

    mapped.removeWhere((_, value) => value == null);

    return mapped;
  }

  Widget bottomBar() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: sidePadding, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UiUtils.buildButton(context, height: 46, radius: 8, onPressed: () async {
            if (page == 1) {
              setState(() {
                page = 2;
                fillValue = 1.0;
                _requestVerificationFieldsIfNeeded();
              });
            } else {
              if (_formKey.currentState?.validate() ?? false) {
                await _handleVerificationPaymentAndSubmit();
              }
            }
          }, buttonTitle: "continue".translate(context)),
        ],
      ),
    );
  }

  Widget mainBody() {
    return BlocListener<SendVerificationFieldCubit, SendVerificationFieldState>(
      listener: (context, state) {
        if (state is SendVerificationFieldInProgress) {
          Widgets.showLoader(context);
        }
        if (state is SendVerificationFieldSuccess) {
          Widgets.hideLoder(context);

          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushNamed(
                context,
                Routes.sellerVerificationComplteScreen,
              );
            }
          });
        }

        if (state is SendVerificationFieldFail) {
          HelperUtils.showSnackBarMessage(context, state.error.toString());
          Widgets.hideLoder(context);
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 20),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scrollController,
            physics: AppScrollBehavior.defaultPhysics,
            shrinkWrap: true,
            /* crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,*/
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'userVerification'.translate(context),
                  )
                      .color(context.color.textDefaultColor)
                      .size(context.font.extraLarge)
                      .bold(weight: FontWeight.w600),
                  Spacer(),
                  Text('${"stepLbl".translate(context)}\t$page\t${"of2Lbl".translate(context)}')
                      .color(context.color.textLightColor)
                ],
              ),
              linearIndicator(),
              page == 1 ? firstPageVerification() : secondPageVerification(),
            ],
          ),
        ),
      ),
    );
  }

  Widget linearIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 5.0),
      child: Center(
        child: Stack(
          children: [
            // First part (bottom progress indicator)
            LinearProgressIndicator(
              value: 0.5,
              borderRadius: BorderRadius.circular(2),
              // 50% of the total progress
              backgroundColor: Colors.grey[300],
              // Background color for the first part
              valueColor:
                  AlwaysStoppedAnimation<Color>(context.color.backgroundColor),
              // Color for the first 50%
              minHeight: 4.0,
            ),
            // Second part (overlaying progress indicator for the remaining 50%)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fillValue,
                  // This limits the width of the second indicator to 50%
                  child: LinearProgressIndicator(
                    value: 1.0,
                    borderRadius: BorderRadius.circular(2),
                    // Full for the second half
                    backgroundColor: Colors.transparent,
                    // No background for the overlay
                    valueColor: AlwaysStoppedAnimation<Color>(
                        context.color.textDefaultColor),
                    // Color for the second 50%
                    minHeight: 4.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget firstPageVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 16),
        Text(
          'personalInformation'.translate(context),
        )
            .color(context.color.textDefaultColor)
            .size(context.font.larger)
            .bold(),
        SizedBox(height: 8),
        Text('pleaseProvideYourAccurateInformation'.translate(context))
            .color(context.color.textDefaultColor)
            .size(context.font.large),
        SizedBox(height: 10),
        buildTextField(
          context,
          title: "fullName",
          hintText: "provideFullNameHere".translate(context),
          controller: nameController,
          //validator: CustomTextFieldValidator.nullCheck,
          readOnly: true,
        ),
        buildTextField(
          context,
          title: "addressLbl",
          hintText: "homeAddressHere".translate(context),
          controller: addressController,
          //validator: CustomTextFieldValidator.nullCheck,
          readOnly: true,
        ),
        buildTextField(
          context,
          title: "phoneNumber",
          hintText: "phoneNumberHere".translate(context),
          controller: phoneController,
          readOnly: true,
          //validator: CustomTextFieldValidator.phoneNumber,
        ),
        buildTextField(
          context,
          title: "emailAddress",
          hintText: "emailAddressHere".translate(context),
          controller: emailController,
          readOnly: true,
          //validator: CustomTextFieldValidator.email,
        ),
      ],
    );
  }

  Widget buildTextField(BuildContext context,
      {required String title,
      required TextEditingController controller,
      //CustomTextFieldValidator? validator,
      bool? readOnly,
      required String hintText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 10.rh(context),
        ),
        Text(title.translate(context)).color(context.color.textDefaultColor),
        SizedBox(
          height: 10.rh(context),
        ),
        CustomTextFormField(
          controller: controller,
          isReadOnly: readOnly,
          //validator: validator,
          hintText: hintText,
          fillColor: context.color.secondaryColor,
        ),
      ],
    );
  }

  Widget secondPageVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 16),
        Text(
          'idVerification'.translate(context),
        )
            .color(context.color.textDefaultColor)
            .size(context.font.larger)
            .bold(),
        SizedBox(height: 8),
        Text('selectDocumentToConfirmIdentity'.translate(context))
            .color(context.color.textDefaultColor)
            .size(context.font.large),
        SizedBox(height: 10),
        BlocBuilder<FetchVerificationRequestsCubit,
            FetchVerificationRequestState>(
          builder: (context, verificationState) {
            return BlocConsumer<FetchSellerVerificationFieldsCubit,
                FetchSellerVerificationFieldState>(
              listener: (context, state) {
                if (state is FetchSellerVerificationFieldSuccess) {
                  moreDetailDynamicFields =
                      _prepareDynamicFields(state.fields, verificationState);
                  setState(() {});
                }
              },
              builder: (context, state) {
                if (state is FetchSellerVerificationFieldInProgress ||
                    state is FetchSellerVerificationFieldInitial) {
                  return const _VerificationFieldShimmer();
                }

                if (state is FetchSellerVerificationFieldFail) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.error.toString(),
                        style: TextStyle(color: context.color.error),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () =>
                            _requestVerificationFieldsIfNeeded(force: true),
                        icon: const Icon(Icons.refresh),
                        label: Text('retryLbl'.translate(context)),
                      ),
                    ],
                  );
                }

                if (moreDetailDynamicFields.isNotEmpty) {
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: moreDetailDynamicFields.length,
                    itemBuilder: (context, index) {
                      final field = moreDetailDynamicFields[index];
                      field.stateUpdater(setState);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9.0),
                        child: field.build(context),
                      );
                    },
                  ); /*return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: moreDetailDynamicFields.map((field) {
                  field.stateUpdater(setState);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9.0),
                    child: field.build(context),
                  );
                }).toList(),
              );*/
                } else {
                  return const _VerificationFieldShimmer();
                }
              },
            );
          },
        ),
      ],
    );
  }

  void _requestVerificationFieldsIfNeeded({bool force = false}) {
    if (_hasRequestedFields && !force) return;
    _hasRequestedFields = true;
    moreDetailDynamicFields.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String accountType = HiveUtils.getAccountTypeLower();
      context.read<FetchSellerVerificationFieldsCubit>().fetchSellerVerificationFields(
          accountType: accountType, forceRefresh: true);
    });
  }

  List<CustomFieldBuilder> _prepareDynamicFields(
      List<VerificationFieldModel> fields,
      FetchVerificationRequestState verificationState) {
    return fields.map((field) {
      final Map<String, dynamic> fieldData = field.toMap();
      if (widget.isResubmitted == true &&
          verificationState is FetchVerificationRequestSuccess) {
        final List<VerificationFieldValues> verificationList =
            verificationState.data.verificationFieldValues ?? [];
        VerificationFieldValues? matchingField;
        for (final VerificationFieldValues value in verificationList) {
          if (value.verificationFieldId == field.id) {
            matchingField = value;
            break;
          }
        }
        if (matchingField != null) {
          final String rawValue = matchingField.value ?? '';
          final List<String> parsedValues = rawValue
              .split(',')
              .map((entry) => entry.trim())
              .where((entry) => entry.isNotEmpty)
              .toList();

          fieldData['value'] = parsedValues;
          fieldData['isEdit'] = true;
        }
      }

      final CustomFieldBuilder customFieldBuilder =
          CustomFieldBuilder(fieldData);
      customFieldBuilder.stateUpdater(setState);
      customFieldBuilder.init();
      return customFieldBuilder;
    }).toList();
  }

  Future<void> _handleVerificationPaymentAndSubmit() async {
    if (_paymentInProgress) return;

    final fieldsState = context.read<FetchSellerVerificationFieldsCubit>().state;
    if (fieldsState is! FetchSellerVerificationFieldSuccess) {
      HelperUtils.showSnackBarMessage(
          context, 'somethingWentWrong'.translate(context));
      _requestVerificationFieldsIfNeeded(force: true);
      return;
    }

    final VerificationOffering? offering =
        fieldsState.metadata.findForAccountType(fieldsState.accountType);
    final double amount = offering?.pricing.amount ?? 0;
    final String? currency = offering?.pricing.currency;

    if (amount <= 0) {
      HelperUtils.showSnackBarMessage(
          context, 'somethingWentWrong'.translate(context));
      return;
    }

    final String token = HiveUtils.getJWT();
    if (token.isEmpty) {
      HelperUtils.showSnackBarMessage(context, 'loginFirst'.translate(context));
      return;
    }

    setState(() => _paymentInProgress = true);

    final BankTransferArgs args = BankTransferArgs(
      token: token,
      packageId: 0,
      amount: amount,
      currency: currency,
      packageType: 'verification',
      purpose: 'verification',
      allowedGateways: const [
        BankTransferGateway.manualBank,
        BankTransferGateway.eastYemenBank,
      ],
      allowWalletGateway: false,
    );

    final dynamic paymentResult = await BankTransferScreen.show(context, args);

    if (!mounted) return;
    setState(() => _paymentInProgress = false);

    if (paymentResult == null || paymentResult == false) {
      return;
    }

    final String? paymentReference =
        _extractPaymentReference(paymentResult)?.trim();

    final bool paymentSucceeded = paymentReference != null ||
        (paymentResult is ManualPaymentSubmissionResult &&
            paymentResult.success) ||
        paymentResult is PaymentRouteResult ||
        paymentResult == true;

    if (!paymentSucceeded) {
      HelperUtils.showSnackBarMessage(
          context, 'somethingWentWrong'.translate(context));
      return;
    }

    final Map<String, dynamic> data = _buildSubmissionPayload();
    if (paymentReference != null && paymentReference.isNotEmpty) {
      data['payment_transaction_id'] = paymentReference;
    }
    context.read<SendVerificationFieldCubit>().send(data: data);
  }

  Map<String, dynamic> _buildSubmissionPayload() {
    final Map<String, dynamic> data =
        convertToCustomFields(AbstractField.fieldsData);

    final Map<String, dynamic> files = AbstractField.files;

    files.forEach((key, value) {
      if (key.startsWith('custom_field_files[') && key.endsWith(']')) {
        final String index =
            key.substring('custom_field_files['.length, key.length - 1);
        final String newKey = 'verification_field_files[$index]';
        data[newKey] = value;
      } else {
        data[key] = value;
      }
    });

    return data;
  }

  String? _extractPaymentReference(dynamic result) {
    if (result == null) return null;

    if (result is PaymentRouteResult) {
      if (result.kind == PaymentRouteKind.walletSuccess) {
        return result.walletTxnId?.toString();
      }
      if (result.kind == PaymentRouteKind.bankTransferCreated) {
        return result.manualRequestId?.toString();
      }
    }

    if (result is ManualPaymentSubmissionResult) {
      final List<dynamic> candidates = [
        result.paymentTransactionId,
        result.manualPaymentId,
        result.paymentTransaction?['id'],
        result.manualPaymentRequest?['id'],
        result.raw['payment_transaction_id'],
        result.raw['manual_payment_id'],
        result.raw['id'],
      ];
      for (final dynamic candidate in candidates) {
        if (candidate == null) continue;
        final String normalized = candidate.toString().trim();
        if (normalized.isNotEmpty) return normalized;
      }
    }

    if (result is Map<String, dynamic>) {
      final List<dynamic> candidates = [
        result['payment_transaction_id'],
        result['transaction_id'],
        result['manual_payment_id'],
        result['manual_payment_request_id'],
        result['id'],
      ];
      for (final dynamic candidate in candidates) {
        if (candidate == null) continue;
        final String normalized = candidate.toString().trim();
        if (normalized.isNotEmpty) return normalized;
      }
    }

    if (result is int) {
      return result.toString();
    }

    if (result is String && result.trim().isNotEmpty) {
      return result.trim();
    }

    return null;
  }
}

class _VerificationFieldShimmer extends StatelessWidget {
  const _VerificationFieldShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              CustomShimmer(height: 14, width: 160),
              SizedBox(height: 10),
              CustomShimmer(height: 48, width: double.infinity, borderRadius: 12),
            ],
          ),
        );
      }),
    );
  }
}
