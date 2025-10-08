// المنطق فقط
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/data/model/cart/checkout_models.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/data/repositories/cart/checkout_repository.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/utils/hive_utils.dart';
import 'deliveryandpayment_ui.dart';
import 'package:marib/data/model/orders/order_submission_result.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/ui/screens/cart/order_step.dart';
import 'package:marib/data/model/cart/cart_discount.dart';
import 'package:marib/data/services/cart_shipping_quote_service.dart';
import 'package:meta/meta.dart';
import 'package:marib/config/feature_flags.dart';
import 'package:marib/data/repositories/cart/addresses_repository.dart';
import 'package:marib/utils/helper_utils.dart';

import 'package:marib/data/model/orders/user_order.dart';
import 'components/delivery_and_payment/delivery_payment_timing_selector.dart';

import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/money_formatter.dart';





class DeliveryandpaymentScreen extends StatefulWidget {
  const DeliveryandpaymentScreen({super.key});

  @override
  State<DeliveryandpaymentScreen> createState() => _DeliveryandpaymentScreenState();

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(builder: (_) => const DeliveryandpaymentScreen());
  }
}

class _DeliveryandpaymentScreenState extends State<DeliveryandpaymentScreen> {


  bool _loading = true;

  bool _submitting = false;


  final CheckoutRepository _checkoutRepository = CheckoutRepository();
  late final CartCubit _cartCubit;
  late final AddressesRepository _addressesRepository;

  int? _selectedBankIndex;
  String? _selectedPaymentMethod;
  WalletSummary? _walletSummary;
  bool _walletAvailable = false;
  final TextEditingController _addressController =
  TextEditingController(text: HiveUtils.getUserDetails().address ?? '');
  final TextEditingController _couponController = TextEditingController();

  CartState _latestCartState = const CartState();
  late StreamSubscription<CartState> _cartSubscription;
  Map<String, int> _cartQuantitySnapshot = <String, int>{};
  bool _pendingCheckoutReload = false;
  bool _suppressCartListener = false;

  List<Cart> _cartItems = const <Cart>[];
  List<CartDiscount> _discounts = const <CartDiscount>[];
  Set<String> _appliedCouponCodes = <String>{};
  bool _couponSuccessDialogVisible = false;
  String? _activeDepartment;

  CheckoutDeliveryInfo? _deliveryInfo;
  CheckoutAddress? _userAddress;
  List<CheckoutBank> _banks = const <CheckoutBank>[];

  String? _deliveryPrice;
  Future<double?>? _distanceFuture;
  bool _depositToggleAllowed = false;
  bool _depositToggleValue = false;
  bool _depositRequired = false;
  bool _lastQuoteDepositEnabled = false;
  CheckoutShippingQuote? _shippingQuote;
  Map<String, dynamic>? _shippingPayment;
  bool _freeShippingApplied = false;
  double? _shippingAmount;
  String? _shippingCurrency;
  String? _departmentNotice;
  String? _returnPolicyText;
  Map<String, dynamic>? _depositInfo;
  bool _allowPayNow = true;
  bool _allowPayOnDelivery = true;
  double? _codFeeAmount;
  String? _codFeeDisplay;
  _CheckoutLoadError? _checkoutError;
  int? _lastRequestedAddressId;
  bool _requiresAddressBlock = true;



  @override
  void initState() {
    super.initState();





    _addressesRepository =
        AddressesRepository(checkoutRepository: _checkoutRepository);


    _cartCubit = context.read<CartCubit>();
    _latestCartState = _cartCubit.state;
    _cartItems = _latestCartState.items;
    _discounts = _latestCartState.discounts;
    final _PolicyData initialPolicyData =
    _resolvePolicyDataFromState(_latestCartState);
    _appliedCouponCodes = _extractAppliedCouponCodes(_discounts);
    _returnPolicyText = initialPolicyData.returnPolicyText;
    _updateDepositConfiguration(initialPolicyData.depositInfo);
    _activeDepartment = _resolveActiveDepartment(_cartItems);
    _cartQuantitySnapshot = _buildCartQuantitySnapshot(_cartItems);
    _cartSubscription = _cartCubit.stream.listen(_onCartStateChanged);
    _addressController.addListener(() => setState(() {}));
    _loadCheckout();
  }



  Future<void> _applyCoupon() async {
    await context.read<CartCubit>().applyCoupon(_couponController.text);
  }

  Future<void> _removeCoupon(CartDiscount discount) async {
    String? code = discount.code;
    code ??= discount.raw?['coupon_code']?.toString();
    code ??= discount.raw?['coupon']?.toString();
    code ??= discount.raw?['code']?.toString();
    if (code == null || code.trim().isEmpty) {
      return;
    }
    await context.read<CartCubit>().removeCoupon(code);
  }

  void _dismissCouponFeedback() {
    context.read<CartCubit>().clearCouponFeedback();
  }

  Future<void> _loadCheckout({
    int? addressId,
    Future<CheckoutAddress?>? preloadedAddress,
  }) async {
    int? resolvedAddressId = addressId ?? _userAddress?.id;
    Future<CheckoutAddress?>? preloadedAddressFuture = preloadedAddress;

    if (resolvedAddressId == null) {
      try {
        final List<Map<String, dynamic>> addresses =
        await _addressesRepository.fetchAddresses();
        Map<String, dynamic>? defaultAddress;
        Map<String, dynamic>? fallbackAddress;

        for (final Map<String, dynamic> entry in addresses) {
          fallbackAddress ??= entry;
          final bool isDefault =
              _asBool(entry['is_default'] ?? entry['isDefault']) ?? false;
          if (isDefault) {
            defaultAddress = entry;
            break;
          }
        }

        final Map<String, dynamic>? selected = defaultAddress ?? fallbackAddress;
        if (selected != null) {
          final int? selectedId = _asInt(
            selected['id'] ??
                selected['address_id'] ??
                selected['addressId'],
          );
          if (selectedId != null) {
            final Future<CheckoutAddress?> future =
            _checkoutRepository.fetchAddressForCheckout(selectedId);
            if (!mounted) return;
            await _loadCheckout(
              addressId: selectedId,
              preloadedAddress: future,
            );
            return;
          }
        }
      } catch (_) {}
    }

    _lastRequestedAddressId = resolvedAddressId;


    if (resolvedAddressId != null && preloadedAddressFuture == null) {
      preloadedAddressFuture =
          _checkoutRepository.fetchAddressForCheckout(resolvedAddressId);
    }

    final Future<CheckoutAddress?>? eagerAddressFuture =
        preloadedAddressFuture;
    if (eagerAddressFuture != null) {
      unawaited(eagerAddressFuture.then((CheckoutAddress? address) {

        if (!mounted || address == null) return;
        if (_lastRequestedAddressId != resolvedAddressId) return;

        final String? fetchedLabel = address.label;
        if (fetchedLabel != null && fetchedLabel.trim().isNotEmpty) {
          if (_addressController.text != fetchedLabel) {
            _addressController.text = fetchedLabel;
          }
        }

        setState(() {
          _userAddress = address;
        });
      }).catchError((_) {}));
    }

    Map<String, dynamic> _mergeStringKeyedMaps(
        Map<String, dynamic>? a,
        Map<String, dynamic>? b,
        ) {
      final Map<String, dynamic> res = {...?a};
      if (b == null) return res;
      b.forEach((k, v) {
        final prev = res[k];
        if (prev is Map<String, dynamic> && v is Map<String, dynamic>) {
          res[k] = _mergeStringKeyedMaps(prev, v); // دمج عميق
        } else {
          res[k] = v; // يغطي الإحلال البسيط
        }
      });
      return res;
    }


    final _CheckoutStateSnapshot previousState = _CheckoutStateSnapshot(
      userAddress: _userAddress,
      deliveryInfo: _deliveryInfo,
      distanceFuture: _distanceFuture,
      selectedBankIndex: _selectedBankIndex,
      selectedPaymentMethod: _selectedPaymentMethod,
      shippingQuote: _shippingQuote,
      shippingPayment: _shippingPayment,
      freeShippingApplied: _freeShippingApplied,
      shippingAmount: _shippingAmount,
      shippingCurrency: _shippingCurrency,
      deliveryPrice: _deliveryPrice,
      departmentNotice: _departmentNotice,
      allowPayNow: _allowPayNow,
      allowPayOnDelivery: _allowPayOnDelivery,
      codFeeAmount: _codFeeAmount,
      codFeeDisplay: _codFeeDisplay,
    );


    final Map<String, dynamic>? shippingPaymentOverride =
    _buildShippingPaymentPreferencePayload();
    final String? deliveryPaymentTimingToken =
    _stringValue(_latestCartState.deliveryPaymentTiming);

    setState(() {
      _loading = true;
      _distanceFuture = null;
      if (FeatureFlags.deliveryPricingEnabled) {
        _userAddress = null;
      }

      _deliveryInfo = null;
      _deliveryPrice = null;
      _shippingQuote = null;
      _shippingPayment = null;
      _freeShippingApplied = false;
      _shippingAmount = null;
      _shippingCurrency = null;
      _departmentNotice = null;
      _allowPayNow = true;
      _allowPayOnDelivery = true;
      _codFeeAmount = null;
      _codFeeDisplay = null;


    });

    final bool depositEnabledFlag = _shouldRequestDepositDetails;
    _lastQuoteDepositEnabled = depositEnabledFlag;


    try {
      final CheckoutResult result = resolvedAddressId != null
          ? await _checkoutRepository.fetchCheckout(
        department: _activeDepartment,
        addressId: resolvedAddressId,
        preloadedAddress: preloadedAddressFuture,
        depositEnabled: depositEnabledFlag,

        deliveryPaymentTiming: deliveryPaymentTimingToken,
        shippingPaymentOverride: shippingPaymentOverride,

      )
          : await _checkoutRepository.fetchCheckout(
        department: _activeDepartment,
        preloadedAddress: preloadedAddressFuture,
        depositEnabled: depositEnabledFlag,

        deliveryPaymentTiming: deliveryPaymentTimingToken,
        shippingPaymentOverride: shippingPaymentOverride,

      );


      if (!mounted) return;


      final CheckoutDeliveryInfo? deliveryInfo = result.deliveryInfo;
      final CheckoutAddress? userAddress = result.userAddress;
      final bool fallbackPathActive = !FeatureFlags.deliveryPricingEnabled;

      final Map<String, dynamic>? paymentSettingsMap =
      _castToStringKeyedMap(result.paymentSettings);

      final bool requiresAddressBlock = _resolveRequiresAddressBlockFlag(
        blocking: _latestCartState.blocking,
        quote: result.shippingQuote,
        deliveryInfo: deliveryInfo,
        paymentSettings: paymentSettingsMap,
      );

      final bool hasValidAddress = requiresAddressBlock
          ? _isAddressValid(userAddress, deliveryInfo)
          : true;
      final bool addressAvailable = requiresAddressBlock
          ? (hasValidAddress || (fallbackPathActive && userAddress != null))
          : (userAddress != null);

      _cartItems = result.cartItems;
      _discounts = result.discounts;
      _cartQuantitySnapshot = _buildCartQuantitySnapshot(_cartItems);
      _suppressCartListener = true;
      final Map<String, dynamic>? incomingDeliveryQuote =
      _castToStringKeyedMap(result.shippingQuote?.deliveryQuote);

      final Map<String, dynamic>? mergedDeliveryQuote =
      _mergeStringKeyedMaps(_latestCartState.deliveryQuote, incomingDeliveryQuote);


      _cartCubit.replaceWithSummary(
        CartSummary(
          items: result.cartItems,
          discounts: result.discounts,
          departmentPolicy: _latestCartState.departmentPolicy,
          support: _latestCartState.support,
          deliveryQuote: mergedDeliveryQuote ?? _latestCartState.deliveryQuote,
          blocking: _latestCartState.blocking,
          deliveryPaymentOptions: _latestCartState.deliveryPaymentOptions,
          deliveryPaymentTiming: _latestCartState.deliveryPaymentTiming,
        ),
      );
      Future.microtask(() {
        _suppressCartListener = false;
      });



      final String? resolvedDepartment =
      _normalizeDepartment(deliveryInfo?.department);
      if (resolvedDepartment != null && resolvedDepartment.isNotEmpty) {
        _activeDepartment = resolvedDepartment;
      } else if (_cartItems.isNotEmpty) {
        _activeDepartment ??=
            _normalizeDepartment(_cartItems.first.section);
      }

      _banks = _filterBanksForCurrency(
        result.banks,
        _orderCurrencyCode,
        _orderCurrencyLabel,
      );

      _requiresAddressBlock = requiresAddressBlock;
      _deliveryInfo = (!requiresAddressBlock || hasValidAddress) ? deliveryInfo : null;

      _userAddress = addressAvailable ? userAddress : null;
      _walletSummary = result.walletSummary;
      _walletAvailable = result.isWalletAvailable ?? result.walletSummary != null;
      _deliveryPrice = (!requiresAddressBlock || hasValidAddress)
          ? (deliveryInfo?.feeDisplay ??
          (deliveryInfo?.fee != null ? deliveryInfo!.fee!.toString() : null))
          : null;


      _shippingQuote = result.shippingQuote;
      final Map<String, dynamic>? shippingData = _shippingQuote?.data;
      Map<String, dynamic>? paymentData;
      bool freeApplied = false;
      double? shippingAmount;
      String? shippingCurrency;
      bool allowPayNow = true;
      bool allowPayOnDelivery = true;
      double? codFeeAmount;
      String? codFeeDisplay;
      String? departmentNotice = _shippingQuote?.departmentNotice;

      if (shippingData != null) {
        final dynamic paymentRaw = shippingData['payment'];
        if (paymentRaw is Map) {
          paymentData = Map<String, dynamic>.from(paymentRaw as Map);
          allowPayNow = _asBool(paymentData['allow_pay_now']) ?? allowPayNow;
          allowPayOnDelivery =
              _asBool(paymentData['allow_pay_on_delivery']) ?? allowPayOnDelivery;
          codFeeDisplay = _asTrimmedString(
              paymentData['cod_fee_display'] ?? paymentData['codFeeDisplay']);
          codFeeAmount = _asDouble(paymentData['cod_fee'] ?? paymentData['codFee']);
        }

        final bool? freeAppliedValue =
        _asBool(shippingData['free_applied'] ?? shippingData['freeApplied']);
        if (freeAppliedValue != null) {
          freeApplied = freeAppliedValue;
        }

        shippingAmount = _asDouble(shippingData['amount']);
        shippingCurrency = _asTrimmedString(
          shippingData['currency'] ??
              shippingData['currency_code'] ??
              shippingData['currencyCode'],
        );

        final String? departmentNoticeValue = _asTrimmedString(
          shippingData['department_notice'] ?? shippingData['departmentNotice'],
        );
        if (departmentNotice == null || departmentNotice.isEmpty) {
          departmentNotice = departmentNoticeValue;
        }
      }



      final num? deliveryFeeValue = deliveryInfo?.fee;
      if (shippingAmount == null && deliveryFeeValue != null) {
        shippingAmount = deliveryFeeValue.toDouble();
      }

      if (shippingCurrency == null || shippingCurrency.isEmpty) {
        shippingCurrency = _asTrimmedString(deliveryInfo?.currency);
      }

      if (!freeApplied) {
        if (deliveryFeeValue != null && deliveryFeeValue.toDouble() == 0) {
          freeApplied = true;
        } else {
          final String? feeDisplay = deliveryInfo?.feeDisplay?.trim();
          if (feeDisplay != null && feeDisplay.isNotEmpty) {
            final bool hasDigits =
            RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]').hasMatch(feeDisplay);
            if (!hasDigits) {
              final String lower = feeDisplay.toLowerCase();
              freeApplied = feeDisplay.contains('مجان') ||
                  feeDisplay.contains('مجانا') ||
                  lower.contains('free');
            }
          }
        }
      }

      final String? resolvedShippingDisplay =
      _resolveShippingFeeDisplayLabel(
        shippingData: shippingData,
        freeApplied: freeApplied,
        amount: shippingAmount,
        currency: shippingCurrency,
        fallback: _deliveryPrice,
      );


      _shippingPayment = paymentData;
      _freeShippingApplied = freeApplied;
      _shippingAmount = shippingAmount;
      _shippingCurrency = shippingCurrency;
      _deliveryPrice = resolvedShippingDisplay ?? _deliveryPrice;
      _departmentNotice = departmentNotice;
      _allowPayNow = allowPayNow;
      _allowPayOnDelivery = allowPayOnDelivery;
      _codFeeAmount = codFeeAmount;
      _codFeeDisplay = codFeeDisplay;
      final _PolicyData quotePolicyData =
      _resolvePolicyDataFromQuote(_shippingQuote);

      void applyQuotePolicy() {
        final String? quotePolicyText = quotePolicyData.returnPolicyText;
        if (quotePolicyText != null && quotePolicyText.trim().isNotEmpty) {
          _returnPolicyText = quotePolicyText;
        }
        _updateDepositConfiguration(quotePolicyData.depositInfo, preserveSelection: true);

      }

      if (mounted) {
        setState(() {
          _checkoutError = null;
          applyQuotePolicy();
        });
      } else {
        applyQuotePolicy();
      }

      if (_shouldRequestDepositDetails != _lastQuoteDepositEnabled) {
        _pendingCheckoutReload = true;
      }

      if (requiresAddressBlock && !addressAvailable) {

        _selectedBankIndex = null;
        _selectedPaymentMethod = null;
        _addressController.clear();
      } else {
        if (_selectedBankIndex != null &&
            (_selectedBankIndex! < 0 || _selectedBankIndex! >= _banks.length)) {
          _selectedBankIndex = null;
        }

        final String? fetchedAddress = _userAddress?.label;
        if (fetchedAddress != null && fetchedAddress.trim().isNotEmpty) {
          _addressController.text = fetchedAddress;
        }

        _selectedPaymentMethod = _selectedBankIndex != null &&
            _selectedBankIndex! >= 0 &&
            _selectedBankIndex! < _banks.length
            ? _banks[_selectedBankIndex!].paymentMethod
            : (_selectedPaymentMethod == 'wallet' && _walletCanPay ? 'wallet' : null);
        if (!requiresAddressBlock && userAddress == null) {
          _addressController.clear();
        }
      }

      _lastRequestedAddressId = _userAddress?.id ?? resolvedAddressId;
    } on CartShippingQuoteException catch (error) {
      if (!mounted) return;
      final String? errorCode = _extractErrorCode(error.payload);
      final bool isAddressRequired = errorCode == 'address_required';
      final String resolvedMessage = isAddressRequired
          ? 'يجب اختيار عنوان صالح يحتوي على الإحداثيات والمسافة قبل متابعة تسعيرة الشحن.'
          : error.message;
      setState(() {
        _restoreCheckoutSnapshot(previousState);

        _checkoutError = _createCheckoutError(
          message: resolvedMessage,
          statusCode: error.statusCode,
          code: errorCode,
          isAddressIssueOverride: isAddressRequired,
          isRetryableOverride: isAddressRequired ? false : null,
        );
        if (isAddressRequired) {
          _requiresAddressBlock = true;
        }
      });
    } on ApiHttpException catch (error) {
      if (!mounted) return;
      final String? errorCode = _extractErrorCode(error.payload);
      final bool isAddressRequired = errorCode == 'address_required';
      final String? rawMessage = error.errorMessage?.toString();
      final String? resolvedMessage = isAddressRequired
          ? 'يجب اختيار عنوان صالح يحتوي على الإحداثيات والمسافة قبل متابعة الطلب.'
          : rawMessage;
      setState(() {
        _restoreCheckoutSnapshot(previousState);

        _checkoutError = _createCheckoutError(
          message: resolvedMessage,
          statusCode: error.statusCode,
          code: errorCode,
          isAddressIssueOverride: isAddressRequired,
          isRetryableOverride: isAddressRequired ? false : null,
        );
        if (isAddressRequired) {
          _requiresAddressBlock = true;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _restoreCheckoutSnapshot(previousState);

        _checkoutError = _createCheckoutError(
          message: error.errorMessage?.toString(),
        );
      });


    } catch (_) {
      if (!mounted) return;

      setState(() {
        _restoreCheckoutSnapshot(previousState);

        _checkoutError = _createCheckoutError();

      });


    } finally {
      if (mounted) {
        setState(() => _loading = false);

        if (_pendingCheckoutReload) {
          _pendingCheckoutReload = false;
          _handleCartContextMutation();
        }
      }
    }
  }

  void _restoreCheckoutSnapshot(_CheckoutStateSnapshot snapshot) {
    _userAddress = snapshot.userAddress;
    _deliveryInfo = snapshot.deliveryInfo;
    _distanceFuture = snapshot.distanceFuture;
    _selectedBankIndex = snapshot.selectedBankIndex;
    _selectedPaymentMethod = snapshot.selectedPaymentMethod;
    _shippingQuote = snapshot.shippingQuote;
    _shippingPayment = snapshot.shippingPayment;
    _freeShippingApplied = snapshot.freeShippingApplied;
    _shippingAmount = snapshot.shippingAmount;
    _shippingCurrency = snapshot.shippingCurrency;
    _deliveryPrice = snapshot.deliveryPrice;
    _departmentNotice = snapshot.departmentNotice;
    _allowPayNow = snapshot.allowPayNow;
    _allowPayOnDelivery = snapshot.allowPayOnDelivery;
    _codFeeAmount = snapshot.codFeeAmount;
    _codFeeDisplay = snapshot.codFeeDisplay;
  }

  void _onCartStateChanged(CartState state) {
    _latestCartState = state;
    if (!mounted) return;

    final Map<String, int> nextSnapshot =
    _buildCartQuantitySnapshot(state.items);
    final bool itemsChanged =
    !_areCartSnapshotsEqual(_cartQuantitySnapshot, nextSnapshot);
    final String? resolvedDepartment =
    _resolveActiveDepartment(state.items);
    final String? currentDepartment = _normalizeDepartment(_activeDepartment);
    final bool shouldUpdateDepartment =
        resolvedDepartment != currentDepartment;
    final bool shouldTriggerReload = !_suppressCartListener &&
        (itemsChanged || shouldUpdateDepartment);

    final _PolicyData policyData = _resolvePolicyDataFromState(state);
    final bool resolvedRequiresAddressBlock = _resolveRequiresAddressBlockFlag(
      blocking: state.blocking,
      quote: _shippingQuote,
      deliveryInfo: _deliveryInfo,
    );


    final Set<String> nextAppliedCoupons =
    _extractAppliedCouponCodes(state.discounts);
    CartDiscount? newlyAppliedDiscount;
    if (!state.couponInProgress && state.couponError == null) {
      final Set<String> addedCoupons =
      nextAppliedCoupons.difference(_appliedCouponCodes);
      if (addedCoupons.isNotEmpty) {
        newlyAppliedDiscount =
            _findDiscountByNormalizedCode(state.discounts, addedCoupons.first);
      }
    }


    setState(() {
      _cartItems = state.items;
      _discounts = state.discounts;
      if (shouldUpdateDepartment) {
        _activeDepartment = resolvedDepartment;
      }
      _returnPolicyText = policyData.returnPolicyText;
      _updateDepositConfiguration(policyData.depositInfo, preserveSelection: true);
      _requiresAddressBlock = resolvedRequiresAddressBlock;

    });

    _cartQuantitySnapshot = nextSnapshot;
    _appliedCouponCodes = nextAppliedCoupons;

    if (!state.couponInProgress && state.couponError == null) {
      final String trimmedInput = _couponController.text.trim();
      if (trimmedInput.isNotEmpty) {
        final String lowerInput = trimmedInput.toLowerCase();
        final bool applied = state.discounts.any((CartDiscount discount) {
          final String? code = discount.code?.trim();
          if (code == null || code.isEmpty) return false;
          return discount.isApplied && code.toLowerCase() == lowerInput;
        });
        if (applied) {
          _couponController.clear();
        }
      }
    }

    if (shouldTriggerReload) {
      _handleCartContextMutation();
    }
    if (newlyAppliedDiscount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCouponSuccessDialog(newlyAppliedDiscount!);
      });
    }
  }

  void _handleCartContextMutation() {
    if (!mounted) {
      return;
    }
    CartShippingQuoteService.shared.invalidateCache();
    if (_loading) {
      _pendingCheckoutReload = true;
      return;
    }
    _pendingCheckoutReload = false;
    _loadCheckout(addressId: _userAddress?.id);
  }



  Set<String> _extractAppliedCouponCodes(List<CartDiscount> discounts) {
    final Set<String> codes = <String>{};
    for (final CartDiscount discount in discounts) {
      final String? code = discount.code?.trim();
      if (code == null || code.isEmpty) {
        continue;
      }
      if (discount.isApplied) {
        codes.add(code.toLowerCase());
      }
    }
    return codes;
  }

  CartDiscount? _findDiscountByNormalizedCode(
      List<CartDiscount> discounts, String normalizedCode) {
    for (final CartDiscount discount in discounts) {
      final String? code = discount.code?.trim();
      if (code == null || code.isEmpty) {
        continue;
      }
      if (discount.isApplied && code.toLowerCase() == normalizedCode) {
        return discount;
      }
    }
    return null;
  }

  void _showCouponSuccessDialog(CartDiscount discount) {
    if (!mounted || _couponSuccessDialogVisible) {
      return;
    }

    _couponSuccessDialogVisible = true;

    final String rawCode = (discount.code ?? '').trim();
    final String couponCode = rawCode.isEmpty ? 'القسيمة' : rawCode.toUpperCase();
    final String? discountAmount = discount.amountDisplay;
    final String message = discount.displayMessage;
    final String totalAfterDiscount =
    _formatCurrencyAmount(_resolveRequiredPaymentAmount());

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        final Color accent = theme.colorScheme.secondary;
        final TextStyle baseTextStyle =
            theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.check_circle_outline, color: accent, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'تم تطبيق القسيمة بنجاح',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'رمز القسيمة: $couponCode',
                style: baseTextStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              if (discountAmount != null && discountAmount.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'قيمة الخصم: $discountAmount',
                  style: baseTextStyle,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                message,
                style: baseTextStyle.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الإجمالي بعد الخصم',
                      style: baseTextStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalAfterDiscount,
                      style: baseTextStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('متابعة'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      _couponSuccessDialogVisible = false;
    });
  }


  _PolicyData _resolvePolicyDataFromState(CartState state) {
    final Map<String, dynamic>? depositMap =
    _castToStringKeyedMap(state.deliveryQuote?['deposit']);
    final Map<String, dynamic>? depositInfo =
    _buildDepositInfoMap(depositMap);

    final Map<String, dynamic>? departmentPolicy =
        _castToStringKeyedMap(state.departmentPolicy) ?? state.departmentPolicy;
    final String? departmentPolicyText = _firstStringValue(
      departmentPolicy,
      const <String>[
        'return_policy_text',
        'returnPolicyText',
        'return_policy',
        'return_policy_message',
        'policy_text',
        'text',
        'description',
      ],
    );

    final String? fallbackPolicyText = _stringValue(
      state.deliveryQuote?['return_policy_text'] ??
          state.deliveryQuote?['returnPolicyText'],
    );

    final String? returnPolicyText =
        departmentPolicyText ?? fallbackPolicyText;


    return _PolicyData(
      returnPolicyText: returnPolicyText,
      depositInfo: depositInfo,
    );
  }





  _PolicyData _resolvePolicyDataFromQuote(CheckoutShippingQuote? quote) {
    if (quote == null) {
      return const _PolicyData();
    }

    Map<String, dynamic>? depositMap;
    String? policyText;

    Map<String, dynamic>? extractDeposit(Map<String, dynamic>? source) {
      if (source == null || source.isEmpty) {
        return null;
      }
      const List<String> depositKeys = <String>[
        'deposit',
        'deposit_info',
        'depositInfo',
        'delivery_deposit',
        'booking_deposit',
        'deposit_details',
        'depositDetails',
      ];
      for (final String key in depositKeys) {
        if (!source.containsKey(key)) {
          continue;
        }
        final Map<String, dynamic>? candidate = _firstMap(source[key]);
        if (candidate != null && candidate.isNotEmpty) {
          return candidate;
        }
      }
      for (final MapEntry<String, dynamic> entry in source.entries) {
        final String normalizedKey = entry.key.toLowerCase();
        if (!normalizedKey.contains('deposit')) {
          continue;
        }
        final Map<String, dynamic>? candidate = _firstMap(entry.value);
        if (candidate != null && candidate.isNotEmpty) {
          return candidate;
        }
      }
      return null;
    }

    String? extractPolicyText(Map<String, dynamic> map) {
      final Map<String, dynamic>? policyMap = _firstMap(
        map['department_policy'] ??
            map['departmentPolicy'] ??
            map['policy'],
      );
      if (policyMap != null) {
        depositMap ??= extractDeposit(policyMap);
      }
      final String? fromPolicy = _firstStringValue(
        policyMap,
        const <String>[
          'return_policy_text',
          'returnPolicyText',
          'return_policy',
          'return_policy_message',
          'policy_text',
          'text',
          'description',
        ],
      );
      if (fromPolicy != null && fromPolicy.trim().isNotEmpty) {
        return fromPolicy;
      }

      final String? fromMap = _firstStringValue(
        map,
        const <String>[
          'return_policy_text',
          'returnPolicyText',
          'return_policy',
          'return_policy_message',
          'policy_text',
          'text',
          'description',
        ],
      );
      if (fromMap != null && fromMap.trim().isNotEmpty) {
        return fromMap;
      }

      return null;
    }

    final Set<int> visited = <int>{};

    void inspect(dynamic candidate) {
      if (candidate == null) {
        return;
      }
      if (candidate is Map || candidate is Iterable) {
        final int identity = identityHashCode(candidate);
        if (!visited.add(identity)) {
          return;
        }
      }
      if (candidate is Iterable) {
        for (final dynamic entry in candidate) {
          inspect(entry);
        }
        return;
      }

      final Map<String, dynamic>? map = _castToStringKeyedMap(candidate);
      if (map == null) {
        return;
      }

      depositMap ??= extractDeposit(map);
      policyText ??= extractPolicyText(map);

      const List<String> nestedKeys = <String>[
        'delivery_quote',
        'deliveryQuote',
        'delivery',
        'quote',
        'data',
        'payload',
        'result',
        'meta',
        'context',
        'extras',
        'extra',
        'department_policy',
        'departmentPolicy',
        'policy',
      ];

      for (final String key in nestedKeys) {
        if (map.containsKey(key)) {
          inspect(map[key]);
        }
      }

      for (final dynamic value in map.values) {
        if (value is Map || value is Iterable) {
          inspect(value);
        }
      }
    }

    inspect(quote.deliveryQuote);
    inspect(quote.delivery);
    inspect(quote.data);
    inspect(quote.raw);

    final Map<String, dynamic>? depositInfo = _buildDepositInfoMap(depositMap);

    return _PolicyData(
      returnPolicyText: policyText,
      depositInfo: depositInfo,
    );
  }



  Map<String, dynamic>? _buildDepositInfoMap(
      Map<String, dynamic>? deposit,
      ) {
    if (deposit == null || deposit.isEmpty) {
      return null;
    }

    final String? amountDueNow = _firstStringValue(deposit, const <String>[
      'amount_due_now_display',
      'amount_due_now_text',
      'amount_due_now_formatted',
      'deposit_amount_due_now_display',
      'deposit_amount_due_now_text',
      'deposit_amount_due_now',
      'amount_due_now',
      'due_now_display',
      'due_now',
    ]);


    final double? amountDueNowValue = _firstNumericValue(deposit, const <String>[
      'amount_due_now_value',
      'amount_due_now_numeric',
      'amount_due_now',
      'deposit_amount_due_now',
      'deposit_due_now',
      'due_now_value',
      'due_now_amount',
      'due_now',
    ]);



    final String? percent = _ensurePercentage(
      _firstStringValue(deposit, const <String>[
        'deposit_percent_display',
        'deposit_percent_text',
        'deposit_percent',
        'percent_display',
        'percent_text',
        'percent',
        'percentage',
      ]),
    );



    final double? ratioValue = _firstNumericValue(deposit, const <String>[
      'ratio_value',
      'deposit_ratio',
      'ratio',
      'percent_value',
      'percentage_value',
    ]);

    double? normalizedRatio = ratioValue;
    if (normalizedRatio != null && normalizedRatio > 1) {
      normalizedRatio = normalizedRatio / 100.0;
    }


    final String? minimum = _firstStringValue(deposit, const <String>[
      'minimum_display',
      'minimum_text',
      'minimum_formatted',
      'minimum_due_now_display',
      'minimum_due_now_text',
      'minimum_due_now',
      'minimum_amount_display',
      'minimum_amount_text',
      'minimum_amount',
      'minimum',
    ]);





    final double? minimumValue = _firstNumericValue(deposit, const <String>[
      'minimum_value',
      'minimum_amount_value',
      'minimum_amount',
      'minimum',
    ]);

    final String? goodsValue = _firstStringValue(deposit, const <String>[
      'goods_value_display',
      'goods_value_text',
      'goods_value',
      'goods_total_display',
      'goods_total',
      'items_total_display',
      'items_total',
      'subtotal_display',
      'subtotal',
    ]);

    final double? goodsValueValue = _firstNumericValue(deposit, const <String>[
      'goods_value_value',
      'goods_total_value',
      'goods_total',
      'goods_value',
      'items_total',
      'subtotal',
    ]);

    final String? shippingFee = _firstStringValue(deposit, const <String>[
      'shipping_fee_display',
      'shipping_fee_text',
      'shipping_fee',
      'delivery_fee_display',
      'delivery_fee',
      'shipping_amount_display',
      'shipping_amount',
    ]);

    final double? shippingFeeValue = _firstNumericValue(deposit, const <String>[
      'shipping_fee_value',
      'delivery_fee_value',
      'shipping_fee',
      'delivery_fee',
      'shipping_amount_value',
      'shipping_amount',
    ]);

    final String? totalAmount = _firstStringValue(deposit, const <String>[
      'total_amount_display',
      'total_amount_text',
      'total_amount_formatted',
      'grand_total_display',
      'grand_total_text',
      'grand_total',
      'total_amount',
      'order_total_display',
      'order_total',
    ]);

    final double? totalAmountValue = _firstNumericValue(deposit, const <String>[
      'total_amount_value',
      'grand_total_value',
      'total_amount',
      'grand_total',
      'order_total',
      'total_due',
      'total',
    ]);

    final String? remainingBalance = _firstStringValue(deposit, const <String>[
      'remaining_balance_display',
      'remaining_balance_text',
      'remaining_balance',
      'balance_due_later_display',
      'balance_due_later',
      'remaining',
    ]);

    final double? remainingBalanceValue = _firstNumericValue(deposit, const <String>[
      'remaining_balance_value',
      'remaining_balance',
      'balance_due_later_value',
      'balance_due',
      'remaining_amount',
    ]);


    final bool? includesShipping = _firstBoolValue(
      deposit,
      const <String>[
        'includes_shipping',
        'shipping_included',
        'includesShipping',
        'shippingIncluded',
      ],
    );

    final String? currency = _firstStringValue(deposit, const <String>[
      'currency_label',
      'currency',
      'currencyCode',
      'currency_display',
    ]);

    final String? message = _firstStringValue(deposit, const <String>[
      'message',
      'description',
      'note',
      'policy_message',
      'summary',
      'text',
      'body',
    ]);

    final String? title = _firstStringValue(deposit, const <String>[
      'title',
      'heading',
      'label',
      'name',
    ]);

    final String? toggleLabel = _firstStringValue(deposit, const <String>[
      'toggle_label',
      'toggleLabel',
      'switch_label',
      'switchLabel',
      'action_label',
      'actionLabel',
    ]);

    final String? toggleDescription = _firstStringValue(deposit, const <String>[
      'toggle_description',
      'toggleDescription',
      'switch_description',
      'switchDescription',
      'toggle_hint',
      'toggleHint',
      'toggle_note',
      'toggleNote',
    ]);

    final bool? allowToggle = _firstBoolValue(
      deposit,
      const <String>[
        'allow_toggle',
        'allowToggle',
        'toggle_allowed',
        'toggleAllowed',
        'optional',
        'is_optional',
        'can_toggle',
        'canToggle',
      ],
    );

    final bool? required = _firstBoolValue(
      deposit,
      const <String>[
        'required',
        'is_required',
        'mandatory',
        'enforced',
        'force',
        'force_deposit',
      ],
    );

    final bool? defaultEnabled = _firstBoolValue(
      deposit,
      const <String>[
        'default_enabled',
        'defaultEnabled',
        'default_on',
        'enabled_by_default',
        'enabledByDefault',
      ],
    );

    final bool? applied = _firstBoolValue(
      deposit,
      const <String>[
        'applied',
        'active',
        'isApplied',
        'is_active',
        'selected',
        'enabled',
      ],
    );

    final bool hasTextContent = <String?>[
      amountDueNow,
      totalAmount,
      percent,
      minimum,
      goodsValue,
      shippingFee,
      remainingBalance,
      message,
      title,
    ].any((String? value) => value != null && value.trim().isNotEmpty);

    final bool hasNumericContent = amountDueNowValue != null ||
        totalAmountValue != null ||
        goodsValueValue != null ||
        shippingFeeValue != null ||
        remainingBalanceValue != null ||
        normalizedRatio != null ||
        minimumValue != null;

    if (!hasTextContent && !hasNumericContent && includesShipping == null &&
        allowToggle != true && required != true && applied != true) {



      return null;
    }

    return <String, dynamic>{
      'amountDueNow': amountDueNow,
      'amountDueNowValue': amountDueNowValue,
      'percent': percent,
      'ratioValue': normalizedRatio,
      'minimum': minimum,
      'minimumValue': minimumValue,
      'includesShipping': includesShipping,
      'goodsValue': goodsValue,
      'goodsValueValue': goodsValueValue,
      'shippingFee': shippingFee,
      'shippingFeeValue': shippingFeeValue,
      'totalAmount': totalAmount,
      'totalAmountValue': totalAmountValue,
      'remainingBalance': remainingBalance,
      'remainingBalanceValue': remainingBalanceValue,
      'currency': currency,
      'message': message,
      'title': title,
      'toggleLabel': toggleLabel,
      'toggleDescription': toggleDescription,
      'allowToggle': allowToggle,
      'required': required,
      'defaultEnabled': defaultEnabled,
      'applied': applied,
    };
  }

  void _updateDepositConfiguration(
      Map<String, dynamic>? info, {
        bool preserveSelection = false,
      }) {
    if (info == null || info.isEmpty) {
      _depositInfo = null;
      _depositToggleAllowed = false;
      _depositToggleValue = false;
      _depositRequired = false;
      return;
    }

    final bool? allowToggleRaw =
        _firstBoolValue(info, const <String>[
          'allowToggle',
          'allow_toggle',
          'toggle_allowed',
          'toggleAllowed',
          'optional',
          'is_optional',
          'can_toggle',
          'canToggle',
        ]);

    final bool requiredRaw =
        _firstBoolValue(info, const <String>[
          'required',
          'is_required',
          'mandatory',
          'enforced',
          'force',
          'force_deposit',
        ]) ??
            false;

    final bool? defaultEnabled =
    _firstBoolValue(info, const <String>[
      'defaultEnabled',
      'default_enabled',
      'default_on',
      'enabled_by_default',
      'enabledByDefault',
    ]);

    final bool? appliedRaw =
    _firstBoolValue(info, const <String>[
      'applied',
      'active',
      'isApplied',
      'is_active',
      'selected',
      'enabled',
    ]);

    final bool allowToggle = (!requiredRaw) && (allowToggleRaw ?? true);

    final bool? depositEnabledRaw = _firstBoolValue(info, const <String>[
      'depositEnabled',
      'deposit_enabled',
      'deposit_active',
      'depositActive',
    ]);

    final bool serverSuggestedActive = (appliedRaw == true) ||
        (defaultEnabled == true) ||
        (depositEnabledRaw == true);

    final bool enforcedActivation =
        requiredRaw || (!allowToggle && serverSuggestedActive);


    final bool preserve =
        preserveSelection && _depositToggleAllowed && allowToggle;

    final bool toggleValue = preserve
        ? _depositToggleValue
        : (allowToggle ? false : enforcedActivation);

    _depositInfo = info;
    _depositToggleAllowed = allowToggle;
    _depositToggleValue = toggleValue;
    _depositRequired = requiredRaw || (!allowToggle && enforcedActivation);
  }

  String _normalizeNumericString(String input) {
    const Map<String, String> replacements = <String, String>{
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '٫': '.',
      '٬': ',',
    };


    String normalized = input;
    replacements.forEach((String key, String value) {
      normalized = normalized.replaceAll(key, value);
    });
    return normalized;
  }

  double? _numericValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final String normalized = _normalizeNumericString(value);
      final RegExp pattern = RegExp(r'-?\d+(?:[.,]\d+)?');
      final RegExpMatch? match = pattern.firstMatch(normalized);
      if (match == null) {
        return null;
      }
      String number = match.group(0)!;
      if (number.contains('.') && number.contains(',')) {
        final int lastDot = number.lastIndexOf('.');
        final int lastComma = number.lastIndexOf(',');
        if (lastDot > lastComma) {
          number = number.replaceAll(',', '');
        } else {
          number = number.replaceAll('.', '').replaceAll(',', '.');
        }
      } else if (number.contains(',')) {
        number = number.replaceAll(',', '.');
      }
      return double.tryParse(number);
    }
    return null;
  }


  bool get _shouldRequestDepositDetails =>
      _depositRequired || (_depositToggleAllowed && _depositToggleValue);

  double? _firstNumericValue(Map<String, dynamic>? map, List<String> keys) {
    if (map == null || map.isEmpty) {
      return null;
    }
    for (final String key in keys) {
      if (!map.containsKey(key)) {
        continue;
      }
      final double? value = _numericValue(map[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  bool get _isDepositApplied =>
      _depositInfo != null && (_depositRequired || _depositToggleValue);

  double? _resolveDepositDueAmount(Map<String, dynamic> info) {
    final double? explicit = info['amountDueNowValue'] is num
        ? (info['amountDueNowValue'] as num).toDouble()
        : _numericValue(info['amountDueNowValue']);
    if (explicit != null) {
      return explicit;
    }
    final double? ratio = info['ratioValue'] is num
        ? (info['ratioValue'] as num).toDouble()
        : _numericValue(info['ratioValue']);
    final double? goods = info['goodsValueValue'] is num
        ? (info['goodsValueValue'] as num).toDouble()
        : _numericValue(info['goodsValueValue']) ?? _subtotal;
    double? base = goods;
    if (info['includesShipping'] == true) {
      final double? shipping = info['shippingFeeValue'] is num
          ? (info['shippingFeeValue'] as num).toDouble()
          : _numericValue(info['shippingFeeValue']) ?? _shippingAmount;
      if (shipping != null) {
        base = (base ?? 0) + shipping;
      }
    }
    final double? total = _resolveTotalAmountValue(info) ?? base;
    if (ratio != null && total != null) {
      final double due = total * ratio;
      if (due > total) {
        return total;
      }
      return due;
    }
    return null;
  }

  double? _resolveTotalAmountValue(Map<String, dynamic> info) {
    final double? explicit = info['totalAmountValue'] is num
        ? (info['totalAmountValue'] as num).toDouble()
        : _numericValue(info['totalAmountValue']);
    if (explicit != null) {
      return explicit;
    }
    final double? goods = info['goodsValueValue'] is num
        ? (info['goodsValueValue'] as num).toDouble()
        : _numericValue(info['goodsValueValue']) ?? _subtotal;
    final double? shipping = info['shippingFeeValue'] is num
        ? (info['shippingFeeValue'] as num).toDouble()
        : _numericValue(info['shippingFeeValue']);
    if (goods != null) {
      return goods + (shipping ?? 0);
    }
    return null;
  }

  double _resolveRequiredPaymentAmount() {
    final Map<String, dynamic>? info = _depositInfo;
    if (info == null || info.isEmpty) {
      return _subtotal;
    }
    final bool applied = _isDepositApplied;
    final double? resolvedAmount = applied
        ? _resolveDepositDueAmount(info)
        : _resolveTotalAmountValue(info);
    if (resolvedAmount != null && resolvedAmount > 0) {
      return resolvedAmount;
    }
    return _subtotal;
  }

  String? _resolveDepositCurrency(Map<String, dynamic>? info) {

    final String? fromInfo = _stringValue(info?['currency']);
    if (fromInfo != null && fromInfo.trim().isNotEmpty) {
      return fromInfo.trim();
    }
    final String? fromShipping = _shippingCurrency?.trim();
    if (fromShipping != null && fromShipping.isNotEmpty) {
      return fromShipping;
    }
    final String? fromDelivery = _deliveryInfo?.currency?.trim();
    if (fromDelivery != null && fromDelivery.isNotEmpty) {
      return fromDelivery;
    }
    final String? orderCurrencyLabel = _orderCurrencyLabel;
    if (orderCurrencyLabel != null && orderCurrencyLabel.trim().isNotEmpty) {
      return orderCurrencyLabel.trim();
    }
    final String? orderCurrencyCode = _orderCurrencyCode;
    if (orderCurrencyCode != null && orderCurrencyCode.trim().isNotEmpty) {
      return orderCurrencyCode.trim();
    }
    return null;

  }

  String _formatCurrencyAmount(double amount, {String? currency}) {
    final MoneyFormatter formatter = _buildMoneyFormatter(
      label: currency,
      fallbackLabel: _resolveDepositCurrency(_depositInfo),
    );
    return formatter.format(amount);
  }

  Map<String, dynamic>? _buildDepositViewModel() {
    final Map<String, dynamic>? info = _depositInfo;
    if (info == null || info.isEmpty) {
      return null;
    }

    final Map<String, dynamic> viewModel = Map<String, dynamic>.from(info);
    final bool applied = _isDepositApplied;
    final String? currency = _resolveDepositCurrency(info);

    final double? goodsValue = info['goodsValueValue'] is num
        ? (info['goodsValueValue'] as num).toDouble()
        : _numericValue(info['goodsValueValue']);
    final double? shippingValue = info['shippingFeeValue'] is num
        ? (info['shippingFeeValue'] as num).toDouble()
        : _numericValue(info['shippingFeeValue']);

    final double? totalValue = _resolveTotalAmountValue(info) ??
        ((goodsValue ?? _subtotal) + (shippingValue ?? 0));

    final double? depositDueValue = _resolveDepositDueAmount(info);
    double resolvedDueValue =
    ((depositDueValue ?? totalValue ?? 0) as num).toDouble();
    if (resolvedDueValue < 0) {
      resolvedDueValue = 0;
    }

    double? remainingValue = info['remainingBalanceValue'] is num
        ? (info['remainingBalanceValue'] as num).toDouble()
        : _numericValue(info['remainingBalanceValue']);
    if (remainingValue == null && totalValue != null && depositDueValue != null) {
      remainingValue = totalValue - depositDueValue;
    }
    if (remainingValue != null && remainingValue < 0) {
      remainingValue = 0;
    }

    String? totalDisplay = _stringValue(info['totalAmount']) ??
        _stringValue(info['goodsValue']);
    if ((totalDisplay == null || totalDisplay.trim().isEmpty) &&
        totalValue != null) {
      totalDisplay = _formatCurrencyAmount(totalValue, currency: currency);
    } else {
      totalDisplay = totalDisplay?.trim();
    }

    String? dueDisplay = _stringValue(info['amountDueNow']);
    if ((dueDisplay == null || dueDisplay.trim().isEmpty) &&
        depositDueValue != null) {
      dueDisplay = _formatCurrencyAmount(depositDueValue, currency: currency);
    } else if (dueDisplay == null || dueDisplay.trim().isEmpty) {


      dueDisplay = totalDisplay;

    } else {
      dueDisplay = dueDisplay?.trim();
    }

    String? remainingDisplay = _stringValue(info['remainingBalance']);
    if ((remainingDisplay == null || remainingDisplay.trim().isEmpty) &&
        remainingValue != null && remainingValue > 0.009) {
      remainingDisplay =
          _formatCurrencyAmount(remainingValue, currency: currency);
    } else {
      remainingDisplay = remainingDisplay?.trim();
    }

    if (!viewModel.containsKey('goodsValue') || viewModel['goodsValue'] == null) {
      if (goodsValue != null) {
        viewModel['goodsValue'] =
            _formatCurrencyAmount(goodsValue, currency: currency);
      }
    }
    if (!viewModel.containsKey('shippingFee') || viewModel['shippingFee'] == null) {
      if (shippingValue != null) {
        viewModel['shippingFee'] =
            _formatCurrencyAmount(shippingValue, currency: currency);
      }
    }

    if (currency != null && currency.isNotEmpty) {
      viewModel['currency'] = currency;
    }
    viewModel['applied'] = applied;
    viewModel['toggleAllowed'] = _depositToggleAllowed;
    viewModel['toggleValue'] =
    _depositToggleAllowed ? _depositToggleValue : applied;
    viewModel['toggleRequired'] = _depositRequired;
    viewModel['effectiveTotalValue'] = totalValue;
    viewModel['effectiveTotalDisplay'] = totalDisplay;
    viewModel['effectiveAmountDueValue'] = resolvedDueValue;
    viewModel['effectiveAmountDueDisplay'] = dueDisplay;
    viewModel['effectiveRemainingValue'] = remainingValue ?? 0;
    viewModel['effectiveRemainingDisplay'] = remainingDisplay;
    viewModel['previewAmountDueDisplay'] ??= dueDisplay;
    viewModel['previewRemainingDisplay'] ??= remainingDisplay;

    return viewModel;
  }

  void _handleDepositToggle(bool value) {
    if (!_depositToggleAllowed) {
      return;
    }
    final bool previous = _shouldRequestDepositDetails;
    setState(() {
      _depositToggleValue = value;
      if (_selectedPaymentMethod == 'wallet' && !_walletCanPay) {
        _selectedPaymentMethod = null;
      }
    });
    if (previous != _shouldRequestDepositDetails) {
      _handleCartContextMutation();
    }
  }



  Map<String, dynamic>? _castToStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
            (dynamic key, dynamic innerValue) =>
            MapEntry<String, dynamic>(key.toString(), innerValue),
      );
    }
    return null;
  }

  Map<String, dynamic>? _firstMap(dynamic value) {
    final Map<String, dynamic>? direct = _castToStringKeyedMap(value);
    if (direct != null) {
      return direct;
    }
    if (value is Iterable) {
      for (final dynamic entry in value) {
        final Map<String, dynamic>? inner = _castToStringKeyedMap(entry);
        if (inner != null) {
          return inner;
        }
      }
    }
    return null;
  }

  String? _stringValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }

  String? _firstStringValue(Map<String, dynamic>? map, List<String> keys) {
    if (map == null || map.isEmpty) {
      return null;
    }
    for (final String key in keys) {
      if (!map.containsKey(key)) {
        continue;
      }
      final String? result = _stringValue(map[key]);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  bool? _firstBoolValue(Map<String, dynamic>? map, List<String> keys) {
    if (map == null || map.isEmpty) {
      return null;
    }
    for (final String key in keys) {
      if (!map.containsKey(key)) continue;
      final dynamic value = map[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final String normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        if (<String>{'1', 'true', 'yes', 'y'}.contains(normalized)) {
          return true;
        }
        if (<String>{'0', 'false', 'no', 'n'}.contains(normalized)) {
          return false;
        }
      }
    }
    return null;
  }


  Map<String, dynamic>? _buildShippingPaymentPreferencePayload() {
    final Map<String, dynamic> source = _shippingPayment == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(_shippingPayment!);

    final Map<String, dynamic> payload = <String, dynamic>{
      'allow_pay_now': _allowPayNow ? 1 : 0,
      'allow_pay_on_delivery': _allowPayOnDelivery ? 1 : 0,
    };

    double? resolveDouble(List<String> keys) {
      for (final String key in keys) {
        if (!source.containsKey(key)) continue;
        final double? value = _asDouble(source[key]);
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    String? resolveString(List<String> keys) {
      for (final String key in keys) {
        if (!source.containsKey(key)) continue;
        final String? value = _stringValue(source[key]);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    final double? codFee =
        _codFeeAmount ?? resolveDouble(<String>['cod_fee', 'codFee']);
    if (codFee != null) {
      payload['cod_fee'] = codFee;
    }

    final String? codFeeDisplay = (() {
      final String? explicit = _codFeeDisplay?.trim();
      if (explicit != null && explicit.isNotEmpty) {
        return explicit;
      }
      return resolveString(<String>[
        'cod_fee_display',
        'codFeeDisplay',
        'cod_fee_text',
        'codFeeText',
      ]);
    })();
    if (codFeeDisplay != null && codFeeDisplay.isNotEmpty) {
      payload['cod_fee_display'] = codFeeDisplay;
    }

    final String? codFeeCurrency = resolveString(<String>[
      'cod_fee_currency',
      'codFeeCurrency',
      'cod_fee_currency_code',
      'codFeeCurrencyCode',
    ]);
    if (codFeeCurrency != null && codFeeCurrency.isNotEmpty) {
      payload['cod_fee_currency'] = codFeeCurrency;
    }

    final String? suggestedTiming = resolveString(<String>[
      'suggested_timing',
      'suggestedTiming',
      'default_timing',
      'defaultTiming',
    ]);
    if (suggestedTiming != null && suggestedTiming.isNotEmpty) {
      payload['suggested_timing'] = suggestedTiming;
    }

    payload.removeWhere((String key, dynamic value) => value == null);
    if (payload.isEmpty) {
      return null;
    }

    return payload;
  }





  String? _ensurePercentage(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('%')) {
      return trimmed;
    }
    return '$trimmed%';
  }

  String? _resolveActiveDepartment(List<Cart> items) {
    final String? fromCubit = _normalizeDepartment(_cartCubit.activeSection);
    if (fromCubit != null && fromCubit.isNotEmpty) {
      return fromCubit;
    }
    if (items.isNotEmpty) {
      return _normalizeDepartment(items.first.section);
    }
    return null;
  }

  Map<String, int> _buildCartQuantitySnapshot(List<Cart> items) {
    final Map<String, int> snapshot = <String, int>{};
    for (final Cart item in items) {
      final String key = _cartItemKey(item);
      final int quantity = item.quantity;
      snapshot[key] = quantity + (snapshot[key] ?? 0);
    }
    return snapshot;
  }

  bool _areCartSnapshotsEqual(
      Map<String, int> previous,
      Map<String, int> current,
      ) {
    if (identical(previous, current)) {
      return true;
    }
    if (previous.length != current.length) {
      return false;
    }
    for (final MapEntry<String, int> entry in previous.entries) {
      if (current[entry.key] != entry.value) {
        return false;

      }
    }
    return true;
  }


  String _cartItemKey(Cart item) {
    final String baseId = item.cartItemId?.toString() ??
        item.id?.toString() ??
        item.hashCode.toString();
    final String variantId = item.variantId?.toString() ?? '';

    final Map<String, dynamic>? attributes = item.variantAttributes;
    final List<String> attributeParts = <String>[];
    if (attributes != null && attributes.isNotEmpty) {
      final List<String> keys =
      attributes.keys.map((dynamic key) => key.toString()).toList()
        ..sort();
      for (final String key in keys) {
        final dynamic value = attributes[key];
        attributeParts.add('$key:$value');
      }
    }

    final List<Map<String, dynamic>>? customFields =
        item.selectedCustomFields;
    final List<String> customFieldParts = <String>[];
    if (customFields != null && customFields.isNotEmpty) {
      for (final Map<String, dynamic> field in customFields) {
        final List<String> fieldKeys =
        field.keys.map((dynamic key) => key.toString()).toList()
          ..sort();
        final List<String> entries = <String>[];
        for (final String key in fieldKeys) {
          final dynamic value = field[key];
          entries.add('$key:$value');
        }
        customFieldParts.add(entries.join('|'));
      }
    }

    final String attributesKey =
    attributeParts.isEmpty ? '' : attributeParts.join(';');
    final String customFieldsKey =
    customFieldParts.isEmpty ? '' : customFieldParts.join(';');

    return '$baseId::$variantId::$attributesKey::$customFieldsKey';
  }

  String? _normalizeDepartment(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }



  Future<void> _retryCheckout() {

    if (!mounted) return Future<void>.value();
    setState(() {



      _checkoutError = null;
    });

    return _loadCheckout(addressId: _lastRequestedAddressId);
  }









  Future<double?> _fetchDistanceFromApi() {

    if (!_hasValidAddress) {
      return Future<double?>.value(_deliveryInfo?.distanceKm);
    }

    if (_distanceFuture != null) return _distanceFuture!;


    final Map<String, dynamic>? paymentOverride =
    _buildShippingPaymentPreferencePayload();
    final String? distancePaymentTimingToken =
    _stringValue(_latestCartState.deliveryPaymentTiming);


    final future = _checkoutRepository
        .refreshDeliveryInfo(
      department: _activeDepartment,
      addressId: _userAddress?.id,
      depositEnabled: _shouldRequestDepositDetails,
      deliveryPaymentTiming: distancePaymentTimingToken,
      shippingPaymentOverride: paymentOverride,

    )

        .then((CheckoutDeliveryInfo? info) {
      final double? distance = info?.distanceKm ?? _deliveryInfo?.distanceKm;
      if (info != null && mounted) {
        setState(() {
          _deliveryInfo = info;

          _deliveryPrice = info.feeDisplay ??
              (info.fee != null ? info.fee!.toString() : _deliveryPrice);
        });
      }
      _distanceFuture = Future<double?>.value(distance);
      return distance;
    }).catchError((_) {
      final double? distance = _deliveryInfo?.distanceKm;
      _distanceFuture = Future<double?>.value(distance);
      return distance;
    });

    _distanceFuture = future;
    return future;
  }


  _DeliveryPaymentMeta _resolveDeliveryPaymentMeta({
    CheckoutBank? selectedBank,
  }) {

    final List<DeliveryPaymentTimingOption> timingOptions =
    normalizeDeliveryPaymentTimingOptions(
      _latestCartState.deliveryPaymentOptions,
    );
    final DeliveryPaymentTimingOption? selectedTimingOption =
    findDeliveryPaymentTimingOption(
      timingOptions,
      _latestCartState.deliveryPaymentTiming,
    );

    final String normalizedSelectedMethod =
    (_selectedPaymentMethod ?? '').trim().toLowerCase();
    final String method =
    (selectedBank?.paymentMethod ?? normalizedSelectedMethod).trim().toLowerCase();
    final bool walletSelected = normalizedSelectedMethod == 'wallet';
    final bool hasMethod = method.isNotEmpty;

    if (!hasMethod && !walletSelected && selectedTimingOption == null) {
      return _DeliveryPaymentMeta(
        value: 'on_delivery',
        label: '—',
        note: 'اختر طريقة الدفع لمعرفة وقت التحصيل.',
        method: method,
        isWallet: false,
        isManualTransfer: false,
      );
    }

    const Set<String> explicitOnDelivery = {
      'manual_bank',
      'east_yemen_bank',
      'cash_on_delivery',
      'cod',
      'cash',
      'pay_on_delivery',
      'door_payment',
      'bank_transfer',
      'manual_transfer',
      'bank_deposit',
      'cash_deposit',
    };

    bool isManualTransfer = false;
    bool payOnDelivery = false;

    if (walletSelected) {
      payOnDelivery = false;
    } else {
      if (explicitOnDelivery.contains(method)) {
        payOnDelivery = true;
      }
      if (!payOnDelivery) {
        if (method.contains('cod') || method.contains('cash')) {
          payOnDelivery = true;
        } else if (method.contains('manual') || method.contains('transfer') ||
            method.contains('deposit')) {
          payOnDelivery = true;
        }
      }

      isManualTransfer = method.contains('manual') ||
          method.contains('transfer') ||
          method.contains('deposit') ||
          method == 'east_yemen_bank';
    }

    String value = payOnDelivery ? 'on_delivery' : 'now';
    String label = payOnDelivery ? 'الدفع عند التسليم' : 'الدفع الآن';

    if (selectedTimingOption != null) {
      final String optionValue = selectedTimingOption.value.trim();
      if (optionValue.isNotEmpty) {
        value = optionValue;
        final String normalizedValue = optionValue.toLowerCase();
        final bool explicitlyPayNow =
        <String>{'now', 'pay_now', 'paynow', 'online'}.contains(normalizedValue);
        payOnDelivery = !explicitlyPayNow;
      }
      label = selectedTimingOption.label;
    }

    String? note;
    final String? optionNote = selectedTimingOption?.description?.trim();
    if (optionNote != null && optionNote.isNotEmpty) {
      note = optionNote;
    } else {
      if (payOnDelivery) {
        note = isManualTransfer
            ? 'سيتم التنسيق لتحويل المبلغ يدويًا بعد التسليم.'
            : 'سيُدفع المبلغ عند استلام الطلب من السائق.';
      } else if (walletSelected) {
        note = 'سيتم خصم المبلغ فورًا من رصيد محفظتك.';
      } else if (hasMethod) {
        note = 'سيتم تحصيل المبلغ إلكترونيًا بعد تأكيد الطلب.';
      }
    }
    return _DeliveryPaymentMeta(
      value: value,
      label: label,
      note: note,
      method: method,
      isWallet: walletSelected,
      isManualTransfer: isManualTransfer,
    );
  }

  @override
  void dispose() {
    _cartSubscription.cancel();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    if (_submitting) {
      return;
    }

    final Map<String, dynamic>? address = _addressViewModel;
    if (_requiresAddressBlock && address == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'يرجى إضافة عنوان التوصيل قبل متابعة الطلب.',
      );
      return;
    }

    final CheckoutBank? selectedBank = _currentSelectedBank;
    final _DeliveryPaymentMeta paymentTimingMeta =
    _resolveDeliveryPaymentMeta(selectedBank: selectedBank);

    final String normalizedMethod =
    (_selectedPaymentMethod ?? '').trim().toLowerCase();
    if (normalizedMethod == 'wallet') {
      if (!_walletAvailable) {
        HelperUtils.showSnackBarMessage(
          context,
          'خيار المحفظة غير متاح حاليًا.',
        );
        return;
      }

      if (!_walletCurrencyMatchesOrder) {
        final String walletCurrency =
            _currencyDisplayToken(_walletSummary?.currency) ?? 'المحفظة';
        final String orderCurrency = _orderCurrencyLabel ?? 'الطلب';
        HelperUtils.showSnackBarMessage(
          context,
          'لا يمكن إتمام الدفع بالمحفظة بعملة $walletCurrency لطلب عملته $orderCurrency.',
        );
        return;
      }

      if (!_walletCanPay) {
        final double requiredAmount = _resolveRequiredPaymentAmount();
        final String requiredDisplay =
        _formatCurrencyAmount(requiredAmount, currency: _orderCurrencyLabel);
        HelperUtils.showSnackBarMessage(
          context,
          'رصيد المحفظة غير كافٍ لإكمال المبلغ المطلوب ($requiredDisplay).',
        );
        return;
      }
    }


    setState(() => _submitting = true);

    try {
      final OrderSubmissionResult result =
      await _checkoutRepository.submitOrder(

        cartItems: _cartItems,
        address: address,
        addressId: _userAddress?.id,

        deliveryInfo: _deliveryInfo,
        paymentBank: selectedBank,
        paymentMethodName: _selectedPaymentMethod,
        deliveryPriceDisplay: _deliveryPrice,
        department: _activeDepartment,
        subtotal: _subtotal,
        deliveryPaymentTiming: paymentTimingMeta.value,
        deliveryPaymentNote: paymentTimingMeta.note,
        depositEnabled: _isDepositApplied,
      );

      final CartCubit cartCubit = context.read<CartCubit>();
      try {
        await cartCubit.fetchCart();
      } catch (_) {}

      if (!mounted) return;

      _handleOrderSubmission(result, selectedBank, paymentTimingMeta);



    } on ApiException catch (error) {
      if (!mounted) return;
      final String message = error.errorMessage?.toString().trim() ??
          'تعذر إرسال الطلب، حاول مرة أخرى.';
      HelperUtils.showSnackBarMessage(
        context,
        message.isEmpty ? 'تعذر إرسال الطلب، حاول مرة أخرى.' : message,
      );
    } catch (_) {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(
        context,
        'تعذر إرسال الطلب، حاول مرة أخرى.',
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }



  void _handleOrderSubmission(
      OrderSubmissionResult result,
      CheckoutBank? selectedBank,
      _DeliveryPaymentMeta paymentTimingMeta) {

    final List<Map<String, dynamic>> payloadCandidates =
    _collectPayloadCandidates(result);
    final String? orderId =
    _resolveOrderIdentifier(result, payloadCandidates);
    final _ResolvedPaymentMeta paymentMeta =
    _resolvePaymentMeta(result, payloadCandidates);

    final String paymentMethod =
    (selectedBank?.paymentMethod ?? _selectedPaymentMethod ?? '')
        .trim()
        .toLowerCase();
    final bool requiresManualTransfer = paymentTimingMeta.isManualTransfer ||
        paymentMethod == 'manual_bank' ||
        paymentMethod == 'east_yemen_bank';
    final String? timingNote = paymentTimingMeta.note?.trim();

    final String confirmationMessage;
    final String? formattedAmount = paymentMeta.amount > 0
        ? _formatCurrencyAmount(paymentMeta.amount, currency: paymentMeta.currency)
        : null;

    if (requiresManualTransfer) {
      final String baseMessage = timingNote != null && timingNote.isNotEmpty

          ? 'تم إرسال الطلب (${paymentTimingMeta.label}). $timingNote'
          : 'تم إرسال الطلب (${paymentTimingMeta.label}). سيتم تزويدك بتفاصيل الدفع اليدوي ضمن متابعة الطلب.';
      confirmationMessage = formattedAmount != null
          ? '$baseMessage (المبلغ المستحق: $formattedAmount)'
          : baseMessage;
    } else {
      final String confirmationTimingText =
          'تم إرسال طلب الدفع (${paymentTimingMeta.label})، يتم تحويلك لمتابعة الطلب.';
      final String baseMessage = timingNote != null && timingNote.isNotEmpty
          ? '$confirmationTimingText $timingNote'
          : confirmationTimingText;
      confirmationMessage = formattedAmount != null
          ? '$baseMessage (الإجمالي: $formattedAmount)'
          : baseMessage;
    }



    HelperUtils.showSnackBarMessage(context, confirmationMessage);


    final Map<String, dynamic> orderStepArguments = <String, dynamic>{
      'order_id': orderId,
      if (result.order != null) 'order': result.order,
      if (result.details != null) 'orderDetails': result.details,
    };

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      OrderStepsScreen.route(
        RouteSettings(
          name: 'order-step',
          arguments: orderStepArguments,

        ),
      ),
          (Route route) => route.isFirst,
    );
  }

  List<Map<String, dynamic>> _collectPayloadCandidates(
      OrderSubmissionResult result) {
    final List<Map<String, dynamic>> queue = <Map<String, dynamic>>[];

    void addCandidate(Map<String, dynamic>? map) {
      if (map == null || map.isEmpty) return;
      queue.add(map);
    }

    addCandidate(result.order);
    addCandidate(result.raw);


    final OrderDetails? details = result.details;
    final UserOrder? order = details?.order;

    void addDetailsCandidate(Map<String, dynamic>? map) {
      if (map == null || map.isEmpty) return;
      addCandidate(map);
    }

    addDetailsCandidate(details?.raw);
    addDetailsCandidate(order?.raw);
    addDetailsCandidate(details?.paymentSummary);
    addDetailsCandidate(details?.deliveryPaymentSummary);
    addDetailsCandidate(details?.depositReceipts);
    addDetailsCandidate(order?.paymentSummary);
    addDetailsCandidate(order?.deliveryPaymentSummary);
    addDetailsCandidate(order?.paymentIntent);
    addDetailsCandidate(result.policy?.raw);
    addDetailsCandidate(result.support?.raw);

    final List<Map<String, dynamic>> collected = <Map<String, dynamic>>[];
    final Set<Map<String, dynamic>> visited = <Map<String, dynamic>>{};

    while (queue.isNotEmpty) {
      final Map<String, dynamic> current = queue.removeLast();
      if (!visited.add(current)) {
        continue;
      }

      collected.add(current);

      for (final dynamic value in current.values) {
        if (value is Map<String, dynamic>) {
          addCandidate(value);
        } else if (value is List) {
          for (final dynamic element in value) {
            if (element is Map<String, dynamic>) {
              addCandidate(element);
            }
          }
        }
      }
    }

    return collected;
  }

  String? _resolveOrderIdentifier(OrderSubmissionResult result,
      List<Map<String, dynamic>> candidates) {
    final UserOrder? order = result.details?.order;
    final List<String?> directCandidates = <String?>[
      order?.id,
      order?.code,
      result.orderId,
      result.orderCode,
      result.primaryIdentifier,
    ];

    for (final String? candidate in directCandidates) {
      final String? trimmed = _asTrimmedString(candidate);
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    final String? fromCandidates = _findStringValue(candidates, const <String>[
      'order_id',
      'orderId',
      'id',
      'code',
      'reference',
      'order_code',
    ]);
    if (fromCandidates != null) {
      return fromCandidates;
    }

    final dynamic rawOrderId = result.raw['order_id'] ?? result.raw['id'];
    return _asTrimmedString(rawOrderId);
  }



  _ResolvedPaymentMeta _resolvePaymentMeta(
      OrderSubmissionResult result, List<Map<String, dynamic>> candidates) {
    final List<Map<String, dynamic>> sources = <Map<String, dynamic>>[...candidates];

    void addSource(Map<String, dynamic>? map) {
      if (map == null || map.isEmpty) return;
      sources.add(map);
    }

    final OrderDetails? details = result.details;
    final UserOrder? order = details?.order;

    addSource(details?.paymentSummary);
    addSource(details?.deliveryPaymentSummary);
    addSource(details?.depositReceipts);
    addSource(order?.paymentSummary);
    addSource(order?.deliveryPaymentSummary);
    addSource(order?.paymentIntent);

    final double? amount = _findDoubleValue(sources, const <String>[

      'payable_amount',
      'payable',
      'total_amount',
      'amount',
      'grand_total',
      'final_total',
      'final_amount',
      'price',
    ]);

    String? currency = _findStringValue(sources, const <String>[
      'currency',
      'currency_code',
      'currencyCode',
      'order_currency',
      'currency_symbol',
      'currencySymbol',
    ]);

    double? resolvedAmount = amount;
    if ((resolvedAmount == null || resolvedAmount <= 0) &&
        order?.totalValue != null) {
      resolvedAmount = order!.totalValue!.toDouble();
    }

    currency ??= order?.currency;

    final num deliveryFee = _deliveryInfo?.fee ?? 0;
    final double fallbackAmount = (_subtotal + deliveryFee.toDouble());

    final double finalAmount =
    resolvedAmount != null && resolvedAmount > 0 ? resolvedAmount : fallbackAmount;
    final String resolvedCurrency = (currency != null &&
        currency.trim().isNotEmpty)
        ? currency.trim().toUpperCase()
        : 'YER';

    return _ResolvedPaymentMeta(
      amount: finalAmount,
      currency: resolvedCurrency,
    );
  }

  String? _findStringValue(
      List<Map<String, dynamic>> candidates, List<String> keys) {
    for (final Map<String, dynamic> map in candidates) {
      for (final String key in keys) {
        if (!map.containsKey(key)) continue;
        final String? value = _asTrimmedString(map[key]);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  double? _findDoubleValue(
      List<Map<String, dynamic>> candidates, List<String> keys) {
    for (final Map<String, dynamic> map in candidates) {
      for (final String key in keys) {
        if (!map.containsKey(key)) continue;
        final double? value = _asDouble(map[key]);
        if (value != null) {
          return value;
        }
      }
    }
    return null;
  }



  String _resolveShippingCurrency(
      String? override,
      List<Map<String, dynamic>> candidates,
      ) {
    final String? explicit = _asTrimmedString(override);
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final String? fromCandidates = _findStringValue(
      candidates,
      const <String>[
        'currency',
        'currency_code',
        'currencyCode',
        'currency_display',
        'currencyDisplay',
      ],
    );
    if (fromCandidates != null && fromCandidates.isNotEmpty) {
      return fromCandidates;
    }

    final String? fromDelivery = _deliveryInfo?.currency?.trim();
    if (fromDelivery != null && fromDelivery.isNotEmpty) {
      return fromDelivery;
    }

    final String? orderLabel = _orderCurrencyLabel;
    if (orderLabel != null && orderLabel.trim().isNotEmpty) {
      return orderLabel.trim();
    }

    final String? orderCode = _orderCurrencyCode;
    if (orderCode != null && orderCode.trim().isNotEmpty) {
      return orderCode.trim();
    }

    return '';
  }

  String _formatShippingAmount(double amount, {String? currency}) {
    final MoneyFormatter formatter = _buildMoneyFormatter(
      label: currency,
      fallbackLabel: currency ?? _orderCurrencyLabel,
    );
    final String formatted = formatter.format(amount.abs());
    return amount < 0 ? '-$formatted' : formatted;
  }

  String? _resolveShippingFeeDisplayLabel({
    Map<String, dynamic>? shippingData,
    bool freeApplied = false,
    double? amount,
    String? currency,
    String? fallback,
  }) {
    final List<Map<String, dynamic>> candidates = <Map<String, dynamic>>[];
    if (shippingData != null) {
      candidates.add(shippingData);
      final dynamic paymentRaw = shippingData['payment'];
      if (paymentRaw is Map) {
        candidates.add(Map<String, dynamic>.from(paymentRaw as Map));
      }
    }

    final String? fromCandidates = _findStringValue(
      candidates,
      const <String>[
        'display',
        'label',
        'amount_display',
        'amountDisplay',
        'fee_display',
        'feeDisplay',
        'price_display',
        'priceDisplay',
        'shipping_fee_display',
        'shipping_fee_text',
        'shipping_amount_display',
        'shippingAmountDisplay',
      ],
    );
    if (fromCandidates != null && fromCandidates.isNotEmpty) {
      return fromCandidates;
    }

    if (freeApplied) {
      return 'مجانًا';
    }

    final double? resolvedAmount =
        amount ?? _findDoubleValue(candidates, const <String>[
          'amount',
          'fee',
          'price',
          'shipping_fee',
          'shipping_amount',
          'value',
        ]);
    if (resolvedAmount != null) {
      final String resolvedCurrency =
      _resolveShippingCurrency(currency, candidates);
      return _formatShippingAmount(resolvedAmount, currency: resolvedCurrency);
    }

    final String? trimmedFallback = fallback?.trim();
    if (trimmedFallback != null && trimmedFallback.isNotEmpty) {
      return trimmedFallback;
    }

    return null;
  }


  int? _findIntValue(
      List<Map<String, dynamic>> candidates, List<String> keys) {
    for (final Map<String, dynamic> map in candidates) {
      for (final String key in keys) {
        if (!map.containsKey(key)) continue;
        final int? value = _asInt(map[key]);
        if (value != null) {
          return value;
        }
      }
    }
    return null;
  }

  String? _asTrimmedString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      return value.toString();
    }
    return value.toString();
  }


  bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == 'no' || normalized == '0') {
        return false;
      }
    }
    return null;
  }



  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final String normalized =
      trimmed.replaceAll(RegExp(r'[^0-9.,-]'), '').replaceAll(',', '');
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final String digitsOnly =
      trimmed.replaceAll(RegExp(r'[^0-9-]'), '');
      final String candidate = digitsOnly.isEmpty ? trimmed : digitsOnly;
      return int.tryParse(candidate);
    }
    return null;
  }





  void _onSelectBank(int index) {
    if (index < 0 || index >= _banks.length) {
      return;
    }
    setState(() {
      _selectedBankIndex = index;
      _selectedPaymentMethod = _banks[index].paymentMethod;

    });
  }


  String? _normalizeCurrencyToken(String? value, {String? code}) {
    final String? normalized = CurrencyUtils.normalizeCurrencyCode(code ?? value);
    if (normalized != null) {
      return normalized;
    }

    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }


  MoneyFormatter _buildMoneyFormatter({
    String? label,
    String? code,
    String? fallbackLabel,
  }) {
    String? sanitizedLabel = label?.trim();
    if (sanitizedLabel != null && sanitizedLabel.isEmpty) {
      sanitizedLabel = null;
    }

    String? sanitizedFallbackLabel = fallbackLabel?.trim();
    if (sanitizedFallbackLabel != null && sanitizedFallbackLabel.isEmpty) {
      sanitizedFallbackLabel = null;
    }

    String? orderLabel = _orderCurrencyLabel?.trim();
    if (orderLabel != null && orderLabel.isEmpty) {
      orderLabel = null;
    }

    String? effectiveCode = CurrencyUtils.normalizeCurrencyCode(
      code ?? sanitizedLabel ?? _orderCurrencyCode ?? sanitizedFallbackLabel ?? orderLabel,
    );

    final String? fallback = sanitizedFallbackLabel ?? orderLabel ?? _orderCurrencyCode ?? effectiveCode ?? sanitizedLabel;
    final String? effectiveLabel = sanitizedLabel ?? fallback ?? effectiveCode;

    return MoneyFormatter.fromCartCurrency(
      currency: effectiveLabel,
      currencyCode: effectiveCode ?? CurrencyUtils.normalizeCurrencyCode(fallback ?? effectiveLabel),
      fallbackLabel: fallback ?? effectiveCode ?? effectiveLabel,
    );
  }

  List<CheckoutBank> _filterBanksForCurrency(
      List<CheckoutBank> banks, String? orderCurrencyCode, String? orderCurrencyLabel) {
    final String? normalizedOrderCode =
    CurrencyUtils.normalizeCurrencyCode(orderCurrencyCode ?? orderCurrencyLabel);
    final String? normalizedOrderLabel = orderCurrencyLabel?.trim();

    if (normalizedOrderCode == null && (normalizedOrderLabel == null || normalizedOrderLabel.isEmpty)) {
      return banks;
    }

    bool isCompatible(CheckoutBank bank) {
      final Map<String, dynamic>? raw = bank.raw;
      if (raw == null || raw.isEmpty) {
        return true;
      }

      if (requiresPurchaseCodeGateway(bank.paymentMethod) ||
          isManualBankGateway(bank.paymentMethod)) {
        return true;
      }


      final Set<String> allowedCodes = <String>{};
      final Set<String> allowedTokens = <String>{};
      final Set<String> excludedCodes = <String>{};
      final Set<String> excludedTokens = <String>{};

      void absorbToken(String? token, {bool excluded = false}) {
        if (token == null) {
          return;
        }
        final String trimmed = token.trim();
        if (trimmed.isEmpty) {
          return;
        }
        final String upper = trimmed.toUpperCase();
        final String? normalized = CurrencyUtils.normalizeCurrencyCode(trimmed);
        if (excluded) {
          excludedTokens.add(upper);
          if (normalized != null) {
            excludedCodes.add(normalized);
          }
        } else {
          allowedTokens.add(upper);
          if (normalized != null) {
            allowedCodes.add(normalized);
          }
        }
      }

      void absorb(dynamic value, {bool excluded = false}) {
        if (value == null) {
          return;
        }
        if (value is String) {
          for (final String part in value.split(RegExp(r'[;,]'))) {
            absorbToken(part, excluded: excluded);
          }
          return;
        }
        if (value is num) {
          absorbToken(value.toString(), excluded: excluded);
          return;
        }
        if (value is Iterable) {
          for (final dynamic element in value) {
            absorb(element, excluded: excluded);
          }
          return;
        }
        if (value is Map) {
          final Map<String, dynamic> map = value is Map<String, dynamic>
              ? value
              : Map<String, dynamic>.from(value as Map);
          final CurrencyParseResult info = CurrencyUtils.parseCurrency(map);
          absorbToken(info.display, excluded: excluded);
          absorbToken(info.code, excluded: excluded);
          for (final dynamic entry in map.values) {
            absorb(entry, excluded: excluded);
          }
          return;
        }
      }

      void absorbFromKeys(Map<String, dynamic> source, Iterable<String> keys,
          {bool excluded = false}) {
        for (final String key in keys) {
          if (!source.containsKey(key)) {
            continue;
          }
          absorb(source[key], excluded: excluded);
        }
      }

      absorb(raw);

      const List<String> allowedKeys = <String>[
        'currencies',
        'supported_currencies',
        'allowed_currencies',
        'currency_list',
        'currencyList',
        'currency_options',
        'currencyOptions',
        'currency_codes',
        'currencyCodes',
        'payment_currencies',
        'paymentCurrencies',
      ];

      const List<String> excludedKeys = <String>[
        'excluded_currencies',
        'disallowed_currencies',
        'blocked_currencies',
      ];

      absorbFromKeys(raw, allowedKeys);
      absorbFromKeys(raw, excludedKeys, excluded: true);

      if (excludedCodes.contains(normalizedOrderCode) ||
          excludedTokens.contains(normalizedOrderLabel?.toUpperCase() ?? '')) {
        return false;
      }

      if (allowedCodes.isEmpty && allowedTokens.isEmpty) {
        return true;
      }

      if (normalizedOrderCode != null && allowedCodes.contains(normalizedOrderCode)) {
        return true;
      }

      final String? upperLabel = normalizedOrderLabel?.toUpperCase();
      if (upperLabel != null && allowedTokens.contains(upperLabel)) {
        return true;
      }

      return false;
    }

    return banks.where(isCompatible).toList();
  }


  String? _currencyDisplayToken(String? value, {String? code, String? fallback}) {
    final String? trimmed = value?.trim();
    final String? normalized = CurrencyUtils.normalizeCurrencyCode(code ?? trimmed);
    return CurrencyUtils.displayToken(
      label: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      fallback: fallback ?? normalized,
      code: normalized,
    ) ??
        fallback ??
        normalized;
  }

  CurrencyParseResult _currencyInfoFromMap(Map<String, dynamic>? source) {
    if (source == null || source.isEmpty) {
      return const CurrencyParseResult();
    }
    return CurrencyUtils.parseCurrency(source);
  }

  CurrencyParseResult _currencyInfoFromValue(dynamic value) {
    if (value == null) {
      return const CurrencyParseResult();
    }
    if (value is Map<String, dynamic>) {
      return CurrencyUtils.parseCurrency(value);
    }
    final String trimmed = value.toString().trim();

    if (trimmed.isEmpty) {
      return const CurrencyParseResult();
    }
    final String? normalized = CurrencyUtils.normalizeCurrencyCode(trimmed);
    return CurrencyParseResult(code: normalized, display: trimmed);
  }

  CurrencyParseResult get _orderCurrencyInfo {
    final List<CurrencyParseResult> directCandidates = <CurrencyParseResult>[
      _currencyInfoFromMap(_depositInfo),
      _currencyInfoFromMap(_latestCartState.deliveryQuote),
      _currencyInfoFromValue(_shippingCurrency),
      _currencyInfoFromValue(_deliveryInfo?.currency),
    ];
    String? display;
    String? code;

    void considerDisplay(String? candidate) {
      if (display != null) {
        return;
      }
      final String? trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        display = trimmed;
      }
    }

    void considerCode(String? candidate) {
      if (code != null) {
        return;
      }
      final String? normalized = CurrencyUtils.normalizeCurrencyCode(candidate);
      if (normalized != null && normalized.isNotEmpty) {
        code = normalized;
      }
    }
    for (final CurrencyParseResult info in directCandidates) {
      considerDisplay(info.display);
      considerCode(info.code);
    }
    final List<CurrencyParseResult> itemCandidates = <CurrencyParseResult>[];

    void considerCartItem(Cart item) {
      considerDisplay(item.currency);
      considerCode(item.currencyCode);
      considerCode(item.currency);

      final String? trimmedCurrency = item.currency?.trim();
      final String? trimmedCode = item.currencyCode?.trim();
      final String? normalizedCode =
      CurrencyUtils.normalizeCurrencyCode(trimmedCode ?? trimmedCurrency);

      if ((trimmedCurrency != null && trimmedCurrency.isNotEmpty) ||
          (normalizedCode != null && normalizedCode.isNotEmpty)) {
        itemCandidates.add(
          CurrencyParseResult(
            code: normalizedCode,
            display: trimmedCurrency ?? trimmedCode,
          ),
        );
      }

    }

    for (final Cart item in _cartItems) {
      considerCartItem(item);

    }

    for (final Cart item in _latestCartState.items) {
      considerCartItem(item);

    }

    if (itemCandidates.isNotEmpty) {
      final Set<String> itemCodes = itemCandidates
          .map((CurrencyParseResult candidate) => candidate.code)
          .whereType<String>()
          .where((String value) => value.trim().isNotEmpty)
          .map((String value) => value.trim())
          .toSet();

      if (itemCodes.length == 1) {
        code = itemCodes.first;
      } else if (code == null && itemCodes.isNotEmpty) {
        code = itemCodes.first;
      }

      final String? currentDisplayNormalized =
      CurrencyUtils.normalizeCurrencyCode(display);
      if (code != null &&
          (currentDisplayNormalized == null || currentDisplayNormalized != code)) {
        for (final CurrencyParseResult candidate in itemCandidates) {
          final String? candidateDisplay = candidate.display?.trim();
          if (candidateDisplay == null || candidateDisplay.isEmpty) {
            continue;
          }
          if (candidate.code != null && candidate.code == code) {
            display = candidateDisplay;
            break;
          }
        }
      }

      if (display == null || display!.trim().isEmpty) {
        final Iterable<String> displays = itemCandidates
            .map((CurrencyParseResult candidate) => candidate.display?.trim())
            .whereType<String>()
            .where((String value) => value.isNotEmpty);
        final Set<String> uniqueDisplays = displays.toSet();
        if (uniqueDisplays.length == 1) {
          display = uniqueDisplays.first;
        } else if (display == null && displays.isNotEmpty) {
          display = displays.first;
        }
      }

    }

    if (code == null) {
      considerCode(display);
    }

    return CurrencyParseResult(code: code, display: display?.trim());
  }

  String? get _orderCurrencyCode => _orderCurrencyInfo.code;

  String? get _orderCurrencyLabel {
    final CurrencyParseResult info = _orderCurrencyInfo;
    return _currencyDisplayToken(info.display, code: info.code);
  }




  void _onSelectWallet() {
    if (!_walletAvailable) {
      HelperUtils.showSnackBarMessage(
        context,
        'خيار المحفظة غير متاح حاليًا.',
      );
      return;
    }

    final String? walletCurrency = _normalizeCurrencyToken(
      _walletSummary?.currency,
      code: _walletSummary?.currencyCode,
    );
    final String? orderCurrency = _orderCurrencyCode;

    if (walletCurrency != null && orderCurrency != null &&
        walletCurrency != orderCurrency) {

      final String walletLabel = _currencyDisplayToken(
        _walletSummary?.currency,
        code: _walletSummary?.currencyCode,
        fallback: walletCurrency,
      ) ??
          walletCurrency;
      final String orderLabel = _orderCurrencyLabel ?? orderCurrency;

      HelperUtils.showSnackBarMessage(
        context,
        'لا يمكن استخدام المحفظة بعملة $walletLabel لطلب عملته $orderLabel.',
      );

      return;
    }

    if (!_walletCanPay) {
      final double requiredAmount = _resolveRequiredPaymentAmount();
      final String requiredDisplay =
      _formatCurrencyAmount(requiredAmount, currency: _orderCurrencyLabel);
      HelperUtils.showSnackBarMessage(
        context,
        'رصيد المحفظة غير كافٍ لإكمال المبلغ المطلوب ($requiredDisplay).',
      );
      return;
    }


    setState(() {
      _selectedBankIndex = null;
      _selectedPaymentMethod = 'wallet';

    });
  }


  bool get _walletCurrencyMatchesOrder {
    final String? walletCurrency = _normalizeCurrencyToken(
      _walletSummary?.currency,
      code: _walletSummary?.currencyCode,
    );
    final String? orderCurrency = _orderCurrencyCode;
    if (walletCurrency == null || orderCurrency == null) {
      return true;
    }
    return walletCurrency == orderCurrency;
  }


  bool get _canProceed {
    final bool addressInputEmpty = _addressController.text.trim().isEmpty;
    if ((_requiresAddressBlock && (!_hasValidAddress || addressInputEmpty)) ||
        _submitting) {

      return false;
    }

    final bool hasSelection =
    ((_selectedPaymentMethod == 'wallet' && _walletCanPay) ||
        (_selectedBankIndex != null));

    if (!hasSelection) {
      return false;
    }

    final _DeliveryPaymentMeta meta =
    _resolveDeliveryPaymentMeta(selectedBank: _currentSelectedBank);

    if (meta.payOnDelivery && !_allowPayOnDelivery) {
      return false;
    }

    if (!meta.payOnDelivery && !_allowPayNow) {
      return false;
    }

    return true;
  }





  bool get _walletCanPay =>
      _walletAvailable &&

          _walletCurrencyMatchesOrder &&

          (_walletSummary?.balance ?? 0) >= _resolveRequiredPaymentAmount();

  CheckoutBank? get _currentSelectedBank {
    if (_selectedBankIndex == null) {
      return null;
    }
    final int index = _selectedBankIndex!;
    if (index < 0 || index >= _banks.length) {
      return null;
    }
    return _banks[index];
  }



  double get _subtotal => _cartItems.fold<double>(
    0,
        (double sum, Cart item) => sum + item.subtotalAmount,
  );



  bool get _hasValidAddress {
    if (!_requiresAddressBlock) {
      return true;
    }
    return _isAddressValid(_userAddress, _deliveryInfo);
  }

  bool _isAddressValid(
      CheckoutAddress? address, CheckoutDeliveryInfo? deliveryInfo) {
    if (address == null || address.id == null) {
      return false;
    }
    final Map<String, double?> coordinates =
    _resolveAddressCoordinates(address: address, deliveryInfo: deliveryInfo);
    if (coordinates['lat'] == null || coordinates['lng'] == null) {
      return false;
    }

    final double? distance =
    _resolveAddressDistanceKm(address: address, deliveryInfo: deliveryInfo);
    if (distance == null || distance < 0) {
      return false;
    }

    return true;
  }

  Map<String, double?> _resolveAddressCoordinates({
    required CheckoutAddress? address,
    required CheckoutDeliveryInfo? deliveryInfo,
  }) {
    double? lat = deliveryInfo?.userCoordinates?.lat ?? address?.coordinates?.lat;
    double? lng = deliveryInfo?.userCoordinates?.lng ?? address?.coordinates?.lng;

    final Map<String, dynamic>? raw = address?.raw;
    if ((lat == null || lng == null) && raw != null && raw.isNotEmpty) {
      lat ??= _readCoordinateFromRaw(raw, const <List<String>>[
        <String>['lat'],
        <String>['latitude'],
        <String>['geo', 'lat'],
        <String>['geo', 'latitude'],
        <String>['location', 'lat'],
        <String>['location', 'latitude'],
        <String>['coordinates', 'lat'],
        <String>['coordinates', 'latitude'],
      ]);
      lng ??= _readCoordinateFromRaw(raw, const <List<String>>[
        <String>['lng'],
        <String>['lon'],
        <String>['long'],
        <String>['longitude'],
        <String>['geo', 'lng'],
        <String>['geo', 'lon'],
        <String>['location', 'lng'],
        <String>['location', 'lon'],
        <String>['coordinates', 'lng'],
        <String>['coordinates', 'lon'],
      ]);
    }

    return <String, double?>{'lat': lat, 'lng': lng};
  }

  double? _resolveAddressDistanceKm({
    required CheckoutAddress? address,
    required CheckoutDeliveryInfo? deliveryInfo,
  }) {
    double? distance = deliveryInfo?.distanceKm;
    if (distance == null) {
      final Map<String, dynamic>? raw = address?.raw;
      if (raw != null && raw.isNotEmpty) {
        distance = _readNumericFromRaw(raw, const <List<String>>[
          <String>['distance_km'],
          <String>['distance'],
          <String>['metrics', 'distance'],
          <String>['meta', 'distance_km'],
          <String>['meta', 'distance'],
          <String>['shipping', 'distance'],
          <String>['shipping', 'distance_km'],
          <String>['radius'],
        ]);
      }
    }

    return _normalizeDistanceValue(distance);
  }

  double? _readCoordinateFromRaw(
      Map<String, dynamic> raw, List<List<String>> candidates) {
    for (final List<String> path in candidates) {
      dynamic current = raw;
      for (final String segment in path) {
        if (current is Map<String, dynamic>) {
          current = current[segment];
        } else if (current is Map) {
          current = (current as Map)[segment];
        } else {
          current = null;
        }
        if (current == null) {
          break;
        }
      }
      final double? value = _asDouble(current);
      if (value != null) {
        return value;
      }
    }
    return null;
  }


  double? _readNumericFromRaw(
      Map<String, dynamic> raw, List<List<String>> candidates) {
    for (final List<String> path in candidates) {
      dynamic current = raw;
      for (final String segment in path) {
        if (current is Map<String, dynamic>) {
          current = current[segment];
        } else if (current is Map) {
          current = (current as Map)[segment];
        } else {
          current = null;
        }
        if (current == null) {
          break;
        }
      }
      final double? value = _asDouble(current);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  double? _normalizeDistanceValue(double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return null;
    }
    if (value < 0) {
      return null;
    }
    return double.parse(value.toStringAsFixed(3));
  }




  bool _resolveRequiresAddressBlockFlag({
    Map<String, dynamic>? blocking,
    CheckoutShippingQuote? quote,
    CheckoutDeliveryInfo? deliveryInfo,
    Map<String, dynamic>? paymentSettings,
  }) {
    final List<dynamic> candidates = <dynamic>[
      blocking,
      quote?.data,
      quote?.delivery,
      quote?.deliveryQuote,
      quote?.meta,
      quote?.raw,
      deliveryInfo?.raw,
      paymentSettings,
    ];

    for (final dynamic candidate in candidates) {
      final bool? value = _extractAddressRequirement(candidate, <int>{});
      if (value != null) {
        return value;
      }
    }

    return true;
  }

  bool? _extractAddressRequirement(dynamic source, Set<int> visited) {
    if (source == null) {
      return null;
    }

    final bool? direct = _asBool(source);
    if (direct != null) {
      return direct;
    }

    final Map<String, dynamic>? map = _castToStringKeyedMap(source);
    if (map != null) {
      final int identity = identityHashCode(map);
      if (!visited.add(identity)) {
        return null;
      }

      const List<String> requirementKeys = <String>[
        'requires_address_block',
        'requiresAddressBlock',
        'requires_address',
        'requiresAddress',
        'address_required',
        'addressRequired',
        'require_address',
        'requireAddress',
        'requires_address_selection',
        'requiresAddressSelection',
        'need_address',
        'needAddress',
        'must_have_address',
        'mustHaveAddress',
      ];

      for (final String key in requirementKeys) {
        final bool? candidate = _asBool(map[key]);
        if (candidate != null) {
          visited.remove(identity);
          return candidate;
        }
      }

      for (final dynamic value in map.values) {
        final bool? nested = _extractAddressRequirement(value, visited);
        if (nested != null) {
          visited.remove(identity);
          return nested;
        }
      }

      visited.remove(identity);
      return null;
    }

    if (source is Iterable) {
      final int identity = identityHashCode(source);
      if (!visited.add(identity)) {
        return null;
      }
      for (final dynamic entry in source) {
        final bool? nested = _extractAddressRequirement(entry, visited);
        if (nested != null) {
          visited.remove(identity);
          return nested;
        }
      }
      visited.remove(identity);
    }

    return null;
  }

  String? _extractErrorCode(dynamic payload) {
    final Map<String, dynamic>? map = _castToStringKeyedMap(payload);
    if (map == null) {
      if (payload is Iterable) {
        for (final dynamic entry in payload) {
          final String? nested = _extractErrorCode(entry);
          if (nested != null) {
            return nested;
          }
        }
      }
      return null;
    }

    for (final String key in const <String>['code', 'error_code', 'errorCode']) {
      final String? value = _asTrimmedString(map[key]);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final dynamic nestedError = map['error'] ?? map['errors'];
    if (nestedError != null) {
      final String? nested = _extractErrorCode(nestedError);
      if (nested != null) {
        return nested;
      }
    }

    for (final dynamic value in map.values) {
      final String? nested = _extractErrorCode(value);
      if (nested != null) {
        return nested;
      }
    }

    return null;
  }

  Map<String, dynamic>? get _addressViewModel {
    final CheckoutAddress? address = _userAddress;
    final CheckoutDeliveryInfo? deliveryInfo = _deliveryInfo;


    final Map<String, double?> coordinates = _resolveAddressCoordinates(
      address: address,
      deliveryInfo: deliveryInfo,
    );
    final double? lat = coordinates['lat'];
    final double? lng = coordinates['lng'];
    final double? distanceKm =

    _resolveAddressDistanceKm(address: address, deliveryInfo: deliveryInfo);

    final user = HiveUtils.getUserDetails();


    final String controllerLabel = _addressController.text.trim();
    final String rawLabel = address?.label?.trim() ?? '';
    final String storedLabel = (user.address ?? '').trim();
    final String labelCandidate = rawLabel.isNotEmpty
        ? rawLabel
        : (controllerLabel.isNotEmpty ? controllerLabel : storedLabel);

    if (address == null &&
        labelCandidate.isEmpty &&
        (user.name?.trim().isEmpty ?? true) &&
        (user.mobile?.trim().isEmpty ?? true)) {
      return null;
    }

    final String label = labelCandidate;

    if (label.isEmpty) {
      return null;
    }


    String? readFromRaw(
        Map<String, dynamic>? raw, List<List<String>> candidates) {
      if (raw == null || raw.isEmpty) return null;

      dynamic traverse(dynamic current, String key) {
        if (current is Map<String, dynamic>) {
          return current[key];
        }
        if (current is Map) {
          return (current as Map)[key];
        }
        return null;
      }

      String? asString(dynamic value) {
        if (value == null) return null;
        if (value is String) {
          final String trimmed = value.trim();
          return trimmed.isEmpty ? null : trimmed;
        }
        if (value is num || value is bool) {
          final String converted = value.toString().trim();
          return converted.isEmpty ? null : converted;
        }
        return null;
      }

      for (final path in candidates) {
        dynamic value = raw;
        for (final segment in path) {
          value = traverse(value, segment);
          if (value == null) break;
        }
        final String? result = asString(value);
        if (result != null) {
          return result;
        }
      }
      return null;
    }

    final Map<String, dynamic>? raw = address?.raw;


    String? name = address?.name?.trim();
    if (name != null && name.isEmpty) {
      name = null;
    }
    name ??= readFromRaw(raw, const [
      ['name'],
      ['contact_name'],
      ['contactName'],
      ['recipient_name'],
      ['recipientName'],
      ['receiver_name'],
      ['receiverName'],
      ['customer', 'name'],
      ['user', 'name'],
      ['contact', 'name'],
    ]);

    String? phone = address?.phone?.trim();
    if (phone != null && phone.isEmpty) {
      phone = null;
    }
    phone ??= readFromRaw(raw, const [
      ['phone'],
      ['mobile'],
      ['contact'],
      ['phone_number'],
      ['phoneNumber'],
      ['contact_phone'],
      ['contactPhone'],
      ['recipient_phone'],
      ['recipientPhone'],
      ['receiver_phone'],
      ['receiverPhone'],
      ['telephone'],
      ['contact', 'phone'],
    ]);



    final int? areaId = _asInt(raw?['area_id'] ?? raw?['areaId']);
    final String? street = readFromRaw(raw, const [
      ['street'],
      ['address', 'street'],
      ['location', 'street'],
    ]);
    final String? building = readFromRaw(raw, const [
      ['building'],
      ['building_name'],
      ['address', 'building'],
    ]);
    final String? note = readFromRaw(raw, const [
      ['note'],
      ['notes'],
      ['description'],
    ]);

    return {
      if (address?.id != null) 'id': address!.id,

      'label': label,
      'address': label,
      'name': (name ?? user.name ?? '').trim(),
      'phone': (phone ?? user.mobile ?? '').trim(),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (distanceKm != null) 'distance': distanceKm,
      if (address?.description != null) 'description': address!.description,
      if (areaId != null) 'area_id': areaId,
      if (street != null && street.trim().isNotEmpty) 'street': street.trim(),
      if (building != null && building.trim().isNotEmpty) 'building': building.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final CheckoutBank? selectedBank = _currentSelectedBank;
    final _DeliveryPaymentMeta paymentTimingMeta =
    _resolveDeliveryPaymentMeta(selectedBank: selectedBank);
    final Map<String, dynamic>? addressViewModel = _addressViewModel;
    final bool hasValidAddress = _hasValidAddress;
    final bool hasAddressData = addressViewModel != null;
    final bool addressReady =
        (_requiresAddressBlock ? hasValidAddress : true) &&
            _checkoutError == null;
    final bool showAddressBlock = _requiresAddressBlock || hasAddressData;

    final Map<String, dynamic>? depositViewModel = _buildDepositViewModel();
    final double requiredAmount = _resolveRequiredPaymentAmount();

    final String? orderCurrencyCode = _orderCurrencyCode;
    final String? orderCurrencyLabel = _orderCurrencyLabel;
    final String? walletCurrencyCode = _normalizeCurrencyToken(
      _walletSummary?.currency,
      code: _walletSummary?.currencyCode,
    );
    final String? walletCurrencyLabel = _currencyDisplayToken(
      _walletSummary?.currency,
      code: walletCurrencyCode ?? _walletSummary?.currencyCode,
      fallback: orderCurrencyLabel ?? orderCurrencyCode,
    );


    final String requiredAmountDisplay =
    _formatCurrencyAmount(requiredAmount);
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: DeliveryAndPaymentUI(
        loading: _loading,
        addressReady: addressReady,
        showAddressBlock: showAddressBlock,
        cartItems: _cartItems,
        discounts: _discounts,
        couponController: _couponController,
        couponInProgress: _latestCartState.couponInProgress,
        couponError: _latestCartState.couponError,
        onApplyCoupon: _applyCoupon,
        onRemoveCoupon: _removeCoupon,
        onDismissCouponMessage: _dismissCouponFeedback,
        address: addressViewModel,
        onManageAddresses: () async {
          final int? selectedAddressId =
          await Navigator.pushNamed<int>(context, Routes.adress);
          if (!mounted) return;
          await _loadCheckout(addressId: selectedAddressId);
        },


        banks: _banks,
        selectedBankIndex: _selectedBankIndex,
        selectedPaymentMethod: _selectedPaymentMethod,
        onSelectBank: _onSelectBank,
        walletSummary: _walletSummary,
        walletAvailable: _walletAvailable,
        walletSelected: (_selectedPaymentMethod ?? '').toLowerCase() == 'wallet',
        walletEnabled: addressReady && _walletCanPay,

        walletCurrencyMatchesOrder: _walletCurrencyMatchesOrder,
        walletCurrencyCode: walletCurrencyCode,
        walletCurrencyLabel: walletCurrencyLabel,
        orderCurrencyCode: orderCurrencyCode,
        orderCurrencyLabel: orderCurrencyLabel,

        allowPayNow: _allowPayNow,
        allowPayOnDelivery: _allowPayOnDelivery,
        codFeeAmount: _codFeeAmount,
        codFeeDisplay: _codFeeDisplay,
        payOnDeliverySelected: paymentTimingMeta.payOnDelivery,
        onSelectWallet: _onSelectWallet,
        requiredAmount: requiredAmount,
        requiredAmountDisplay: requiredAmountDisplay,
        paymentTimingLabel: paymentTimingMeta.label,
        paymentTimingNote: paymentTimingMeta.note,
        deliveryPaymentOptions: _latestCartState.deliveryPaymentOptions,
        deliveryPaymentTiming: _latestCartState.deliveryPaymentTiming,
        onSelectDeliveryPaymentTiming: (String value) {
          _cartCubit.updateDeliveryPaymentTiming(value);
        },
        shippingPayment: _shippingPayment,
        freeShippingApplied: _freeShippingApplied,
        shippingAmount: _shippingAmount,
        shippingCurrency: _shippingCurrency,
        departmentNotice: _departmentNotice,
        returnPolicyText: _returnPolicyText,
        depositInfo: depositViewModel,
        onToggleDeposit:
        _depositToggleAllowed ? _handleDepositToggle : null,
        deliveryInfo: addressReady ? _deliveryInfo : null,
        deliveryPrice: addressReady ? _deliveryPrice : null,

        canProceed: addressReady ? _canProceed : false,
        submitting: _submitting,

        onConfirm: _onConfirm,

        checkoutErrorMessage: _checkoutError?.message,
        checkoutErrorIsAddressIssue: _checkoutError?.isAddressIssue ?? false,
        checkoutErrorCanRetry: _checkoutError?.isRetryable ?? false,
        onRetryCheckout:
        _checkoutError?.isRetryable == true ? _retryCheckout : null,

      ),
    );
  }
}


class _CheckoutStateSnapshot {
  const _CheckoutStateSnapshot({
    this.userAddress,
    this.deliveryInfo,
    this.distanceFuture,
    this.selectedBankIndex,
    this.selectedPaymentMethod,
    this.shippingQuote,
    this.shippingPayment,
    this.freeShippingApplied = false,
    this.shippingAmount,
    this.shippingCurrency,
    this.deliveryPrice,
    this.departmentNotice,
    this.allowPayNow = true,
    this.allowPayOnDelivery = true,
    this.codFeeAmount,
    this.codFeeDisplay,
  });

  final CheckoutAddress? userAddress;
  final CheckoutDeliveryInfo? deliveryInfo;
  final Future<double?>? distanceFuture;
  final int? selectedBankIndex;
  final String? selectedPaymentMethod;
  final CheckoutShippingQuote? shippingQuote;
  final Map<String, dynamic>? shippingPayment;
  final bool freeShippingApplied;
  final double? shippingAmount;
  final String? shippingCurrency;
  final String? departmentNotice;
  final String? deliveryPrice;
  final bool allowPayNow;
  final bool allowPayOnDelivery;
  final double? codFeeAmount;
  final String? codFeeDisplay;
}



class _PolicyData {
  const _PolicyData({
    this.returnPolicyText,
    this.depositInfo,
  });

  final String? returnPolicyText;
  final Map<String, dynamic>? depositInfo;
 }


class _CheckoutLoadError {
  const _CheckoutLoadError({
    required this.message,
    this.isRetryable = false,
    this.isAddressIssue = false,
    this.code,

  });
  final String? code;

  final String message;
  final bool isRetryable;
  final bool isAddressIssue;
}

_CheckoutLoadError _createCheckoutError({
  String? message,
  int? statusCode,
  String? code,
  bool? isAddressIssueOverride,
  bool? isRetryableOverride,
}) {

  final String resolvedMessage = () {
    final String? trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'تعذر تحميل بيانات التوصيل والدفع حاليًا. حاول مرة أخرى.';
    }
    return trimmed;
  }();

  final bool isAddressIssue = isAddressIssueOverride ??
      (code == 'address_required' || statusCode == 422);

  bool isRetryable = isRetryableOverride ??
      (statusCode == null ||
          statusCode >= 500 ||
          statusCode == 408 ||
          statusCode == 429);
  if (isAddressIssue && isRetryableOverride == null) {
    isRetryable = false;
  }

  return _CheckoutLoadError(
    message: resolvedMessage,
    isRetryable: isRetryable,
    isAddressIssue: isAddressIssue,
    code: code,

  );
}




@visibleForTesting
dynamic debugCreateCheckoutError({String? message, int? statusCode, String? code}) =>
    _createCheckoutError(message: message, statusCode: statusCode, code: code);




class _ResolvedPaymentMeta {
  const _ResolvedPaymentMeta({
    required this.amount,
    required this.currency,
  });

  final double amount;
  final String currency;
}

class _DeliveryPaymentMeta {
  const _DeliveryPaymentMeta({
    required this.value,
    required this.label,
    required this.method,
    this.note,
    this.isWallet = false,
    this.isManualTransfer = false,
  });

  final String value;
  final String label;
  final String method;
  final String? note;
  final bool isWallet;
  final bool isManualTransfer;

  bool get payOnDelivery => value == 'on_delivery';
}
