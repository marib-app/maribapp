import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/orders/order_payment.dart';
import 'package:marib/data/repositories/orders/order_payments_repository.dart';
import 'package:marib/utils/api.dart';
import 'package:meta/meta.dart';

enum OrderPaymentStatus {
  initial,
  loading,
  options,
  processing,
  actionRequired,
  confirming,
  success,
  failure,
}

@immutable
class OrderPaymentState {
  const OrderPaymentState({
    this.status = OrderPaymentStatus.initial,
    this.methods = const <OrderPaymentMethod>[],
    this.selectedMethod,
    this.intent,
    this.action,
    this.errorMessage,
    this.orderId,
    this.amount,
    this.currency,
  });

  final OrderPaymentStatus status;
  final List<OrderPaymentMethod> methods;
  final OrderPaymentMethod? selectedMethod;
  final OrderPaymentIntentResult? intent;
  final OrderPaymentAction? action;
  final String? errorMessage;
  final String? orderId;
  final double? amount;
  final String? currency;

  bool get isBusy =>
      status == OrderPaymentStatus.loading ||
          status == OrderPaymentStatus.processing ||
          status == OrderPaymentStatus.confirming;

  OrderPaymentState copyWith({
    OrderPaymentStatus? status,
    List<OrderPaymentMethod>? methods,
    OrderPaymentMethod? selectedMethod,
    bool clearSelectedMethod = false,
    OrderPaymentIntentResult? intent,
    OrderPaymentAction? action,
    bool clearAction = false,
    String? errorMessage,
    bool clearError = false,
    String? orderId,
    double? amount,
    String? currency,
  }) {
    return OrderPaymentState(
      status: status ?? this.status,
      methods: methods ?? this.methods,
      selectedMethod: clearSelectedMethod ? null : (selectedMethod ?? this.selectedMethod),
      intent: intent ?? this.intent,
      action: clearAction ? null : (action ?? this.action),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
    );
  }
}

class OrderPaymentCubit extends Cubit<OrderPaymentState> {
  OrderPaymentCubit({OrderPaymentsRepository? repository})
      : _repository = repository ?? const OrderPaymentsRepository(),
        super(const OrderPaymentState());

  final OrderPaymentsRepository _repository;

  Future<void> loadOptions({
    required String orderId,
    double? amount,
    String? currency,
    Map<String, dynamic>? extraData,
  }) async {
    emit(
      state.copyWith(
        status: OrderPaymentStatus.loading,
        orderId: orderId,
        amount: amount,
        currency: currency,
        clearAction: true,
        clearError: true,
      ),
    );

    try {
      final OrderPaymentIntentResult result = await _repository.initiatePayment(
        orderId: orderId,
        amount: amount,
        currency: currency,
        extraData: extraData,
      );

      final List<OrderPaymentMethod> methods = result.availableMethods;
      final OrderPaymentMethod? selected = _resolveInitialMethod(methods, state.selectedMethod);

      emit(
        state.copyWith(
          status: OrderPaymentStatus.options,
          methods: methods,
          selectedMethod: selected,
          intent: result,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: OrderPaymentStatus.failure,
          errorMessage: _resolveError(error),
        ),
      );
    }
  }

  void selectMethod(OrderPaymentMethod method) {
    emit(
      state.copyWith(
        status: OrderPaymentStatus.options,
        selectedMethod: method,
        clearError: true,
      ),
    );
  }

  Future<void> submitPayment({
    OrderPaymentMethod? method,
    Map<String, dynamic>? extraData,
  }) async {
    final OrderPaymentMethod? resolvedMethod = method ?? state.selectedMethod;
    final String? orderId = state.orderId;
    if (resolvedMethod == null || orderId == null) {
      emit(
        state.copyWith(
          status: OrderPaymentStatus.failure,
          errorMessage: 'يرجى اختيار وسيلة الدفع.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: OrderPaymentStatus.processing,
        clearError: true,
        clearAction: true,
      ),
    );

    try {
      final OrderPaymentIntentResult initiation = await _repository.initiatePayment(
        orderId: orderId,
        paymentMethod: resolvedMethod.id,
        amount: state.amount,
        currency: state.currency,
        extraData: extraData,
      );

      if (initiation.requiresAction &&
          (initiation.authorizationUrl != null && initiation.authorizationUrl!.isNotEmpty)) {
        emit(
          state.copyWith(
            status: OrderPaymentStatus.actionRequired,
            intent: initiation,
            action: OrderPaymentAction(
              authorizationUrl: initiation.authorizationUrl!,
              reference: initiation.reference,
              method: resolvedMethod,
              intent: initiation,
            ),
          ),
        );
        return;
      }

      await _confirm(
        method: resolvedMethod,
        intent: initiation,
        reference: initiation.reference,
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: OrderPaymentStatus.failure,
          errorMessage: _resolveError(error),
        ),
      );
    }
  }

  Future<void> confirmPayment({String? reference}) async {
    final OrderPaymentAction? action = state.action;
    final String? orderId = state.orderId;
    if (action == null || orderId == null) {
      return;
    }

    await _confirm(
      method: action.method,
      intent: action.intent,
      reference: reference ?? action.reference,
    );
  }

  Future<void> _confirm({
    required OrderPaymentMethod method,
    required OrderPaymentIntentResult intent,
    String? reference,
  }) async {
    final String? orderId = state.orderId;
    if (orderId == null) {
      emit(
        state.copyWith(
          status: OrderPaymentStatus.failure,
          errorMessage: 'تعذر تحديد الطلب المستهدف.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: OrderPaymentStatus.confirming,
        clearError: true,
        clearAction: true,
      ),
    );

    try {
      final OrderPaymentIntentResult confirmation = await _repository.confirmPayment(
        orderId: orderId,
        paymentMethod: method.id,
        intentId: intent.intentId,
        transactionId: intent.transactionId,
        reference: reference,
        amount: state.amount,
        currency: state.currency,
      );

      emit(
        state.copyWith(
          status: OrderPaymentStatus.success,
          intent: confirmation,
          clearAction: true,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: OrderPaymentStatus.failure,
          errorMessage: _resolveError(error),
        ),
      );
    }
  }

  void cancelAction() {
    emit(
      state.copyWith(
        status: OrderPaymentStatus.options,
        clearAction: true,
      ),
    );
  }

  void reportGatewayFailure(String message) {
    emit(
      state.copyWith(
        status: OrderPaymentStatus.failure,
        errorMessage: message,
        clearAction: true,
      ),
    );
  }

  void reset() {
    emit(const OrderPaymentState());
  }

  OrderPaymentMethod? _resolveInitialMethod(
      List<OrderPaymentMethod> methods,
      OrderPaymentMethod? previous,
      ) {
    if (methods.isEmpty) {
      return null;
    }
    if (previous != null) {
      for (final OrderPaymentMethod method in methods) {
        if (method.id.toLowerCase() == previous.id.toLowerCase()) {
          return method;
        }
      }
    }
    for (final OrderPaymentMethod method in methods) {
      if (method.isDefault) {
        return method;
      }
    }
    return methods.first;
  }

  String _resolveError(dynamic error) {
    if (error is ApiException) {
      final String? message = error.errorMessage?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    if (error is Exception) {
      return error.toString();
    }
    return 'تعذر إكمال عملية الدفع. حاول مرة أخرى لاحقًا.';
  }
}