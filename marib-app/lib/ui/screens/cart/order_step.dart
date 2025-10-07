import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/model/orders/user_order.dart';
import 'package:marib/data/repositories/orders/orders_repository.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:marib/ui/screens/cart/order_step_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/orders/order_payment_cubit.dart';
import 'package:marib/ui/screens/cart/components/order_payment_sheet.dart';
import 'package:marib/ui/screens/cart/order_outstanding_info.dart';

class OrderStepsScreen extends StatefulWidget {
  const OrderStepsScreen({super.key, this.orderId, this.initialDetails});

  final String? orderId;
  final OrderDetails? initialDetails;

  static Route route(RouteSettings routeSettings) {
    String? orderId;
    OrderDetails? initialDetails;

    final Object? arguments = routeSettings.arguments;

    if (arguments is Map) {
      final dynamic rawDetails =
          arguments['order_details'] ?? arguments['orderDetails'];
      if (rawDetails is OrderDetails) {
        initialDetails = rawDetails;
      }
      final dynamic rawOrderId =
          arguments['order_id'] ?? arguments['orderId'] ?? arguments['id'];
      if (rawOrderId != null && rawOrderId.toString().trim().isNotEmpty) {
        orderId = rawOrderId.toString().trim();
      }
    } else if (arguments is String && arguments.trim().isNotEmpty) {
      orderId = arguments.trim();
    } else if (arguments is OrderDetails) {
      initialDetails = arguments;
      orderId = arguments.order.id;
    }
    orderId ??= initialDetails?.order.id;

    return MaterialPageRoute(
      settings: routeSettings,
      builder: (_) => OrderStepsScreen(
        orderId: orderId,
        initialDetails: initialDetails,
      ),
    );
  }

  @override
  State<OrderStepsScreen> createState() => _OrderStepsScreenState();
}

class _OrderStepsScreenState extends State<OrderStepsScreen> {
  final OrdersRepository _ordersRepository = const OrdersRepository();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  bool _listLoading = false;
  bool _detailLoading = false;
  bool _cancelLoading = false;
  bool _invoiceLoading = false;
  String? _errorMessage;
  OrderDetails? _orderDetails;
  List<UserOrder> _orders = const <UserOrder>[];
  String? _activeDetailId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final OrderDetails? initial = widget.initialDetails;
    if (initial != null) {
      setState(() {
        _orderDetails = initial;
        _orders = <UserOrder>[initial.order];
        _errorMessage = null;
      });
    }

    final String? explicitId = widget.orderId?.trim();
    if (initial != null) {
      if (explicitId != null &&
          explicitId.isNotEmpty &&
          initial.order.id != explicitId) {
        await _loadOrderDetails(explicitId, resetCurrent: true);
      }

      if (mounted) {
        unawaited(_fetchOrders(preserveCurrent: true));
      }
      return;
    }
    if (explicitId != null && explicitId.isNotEmpty) {
      await _loadOrderDetails(explicitId, resetCurrent: true);
    } else {
      await _fetchOrders();
    }
  }

  Future<void> _fetchOrders({bool preserveCurrent = false}) async {
    setState(() {
      _listLoading = true;
      _errorMessage = null;
    });

    try {
      final List<UserOrder> orders = await _ordersRepository.fetchOrders();
      if (!mounted) return;

      final UserOrder? initial = _resolveInitialOrder(orders);

      setState(() {
        _orders = orders;
      });

      if (initial != null) {
        final bool sameAsCurrent =
            preserveCurrent && _orderDetails?.order.id == initial.id;
        if (sameAsCurrent) {
          setState(() {
            _orders = _updateOrdersList(_orderDetails!.order);
          });
        } else {
          await _loadOrderDetails(
            initial.id,
            resetCurrent: !preserveCurrent,
          );
        }
      } else if (!preserveCurrent) {
        setState(() {
          _orderDetails = null;
          _activeDetailId = null;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      _onFailure(error.errorMessage?.toString() ?? 'تعذر تحميل الطلبات.');
    } catch (error) {
      if (!mounted) return;
      _onFailure(error.toString());
    } finally {
      if (mounted) {
        setState(() => _listLoading = false);
      }
    }
  }

  UserOrder? _resolveInitialOrder(List<UserOrder> orders) {
    if (orders.isEmpty) return null;

    final String? target = widget.orderId?.trim();
    if (target != null && target.isNotEmpty) {
      for (final UserOrder order in orders) {
        if (order.matchesIdentifier(target)) {
          return order;
        }
      }
    }

    return orders.first;
  }

  Future<void> _loadOrderDetails(String id, {bool resetCurrent = false}) async {
    if (id.isEmpty) return;

    setState(() {
      if (resetCurrent) {
        _orderDetails = null;
      }
      _detailLoading = true;
      _activeDetailId = id;
      _errorMessage = null;
    });

    try {
      final OrderDetails detailed =
          await _ordersRepository.fetchOrderDetails(id);
      if (!mounted || _activeDetailId != id) return;

      setState(() {
        _orderDetails = detailed;
        _orders = _updateOrdersList(detailed.order);
      });
    } on ApiException catch (error) {
      if (!mounted || _activeDetailId != id) return;
      _onFailure(error.errorMessage?.toString() ?? 'تعذر تحميل تفاصيل الطلب.');
    } catch (error) {
      if (!mounted || _activeDetailId != id) return;
      _onFailure(error.toString());
    } finally {
      if (mounted && _activeDetailId == id) {
        setState(() {
          _detailLoading = false;
          _activeDetailId = null;
        });
      }
    }
  }

  List<UserOrder> _updateOrdersList(UserOrder updated) {
    if (_orders.isEmpty) {
      return <UserOrder>[updated];
    }

    final List<UserOrder> result = <UserOrder>[];
    bool inserted = false;

    for (final UserOrder order in _orders) {
      if (order.id == updated.id) {
        result.add(updated);
        inserted = true;
      } else {
        result.add(order);
      }
    }

    if (!inserted) {
      result.insert(0, updated);
    }

    return result;
  }

  void _onFailure(String message) {
    setState(() => _errorMessage = message);

    if (message.trim().isEmpty || !mounted) {
      return;
    }

    UiUtils.showSoftSnackBar(context, message: message);
  }

  Future<void> _refresh() async {
    final UserOrder? order = _orderDetails?.order;
    if (order != null) {
      await _loadOrderDetails(order.id, resetCurrent: true);
    } else {
      await _fetchOrders();
    }
  }

  Future<void> _openInvoice(UserOrder order) async {
    final OrderOutstandingInfo? outstanding = _findOutstandingInfo(order);
    if (outstanding != null && outstanding.amount > _outstandingEpsilon) {
      if (!mounted) return;
      UiUtils.showSoftSnackBar(
        context,
        message: _buildOutstandingMessage(outstanding),
      );
      return;
    }

    setState(() {
      _invoiceLoading = true;
    });
    try {
      final InvoiceDownloadResult result =
          await _ordersRepository.fetchInvoicePdf(order.id);
      if (!mounted) {
        return;
      }

      if (result.hasBytes) {
        final File file = await _persistInvoice(
          result.bytes!,
          fileName: result.fileName ?? 'invoice-${order.id}.pdf',
        );

        final OpenResult openResult = await OpenFilex.open(file.path);
        if (openResult.type != ResultType.done) {
          UiUtils.showSoftSnackBar(
            context,
            message:
                'تم تنزيل الفاتورة لكن تعذر فتحها تلقائيًا. الموقع: ${file.path}',
          );
        }
        return;
      }

      if (result.hasDownloadUrl) {
        await UiUtils.launchURL(result.downloadUrl!);
        return;
      }

      UiUtils.showSoftSnackBar(
        context,
        message: 'تعذر فتح الفاتورة. حاول لاحقًا.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      UiUtils.showSoftSnackBar(
        context,
        message: error.errorMessage?.toString() ?? 'تعذر تنزيل الفاتورة.',
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      UiUtils.showSoftSnackBar(
        context,
        message: error.message,
      );
    } catch (_) {
      if (!mounted) return;
      UiUtils.showSoftSnackBar(
        context,
        message: 'تعذر تنزيل الفاتورة. حاول لاحقًا.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _invoiceLoading = false;
        });
      }
    }
  }

  Future<void> _handleCancel(UserOrder order) async {
    final bool confirmed = await _confirmCancellation(order);
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _cancelLoading = true;
      _errorMessage = null;
    });

    try {
      final OrderDetails updated =
          await _ordersRepository.cancelOrder(order.id);
      if (!mounted) return;
      setState(() {
        _orderDetails = updated;
        _orders = _updateOrdersList(updated.order);
      });
      UiUtils.showSoftSnackBar(context, message: 'تم إلغاء الطلب بنجاح.');

      if (mounted) {
        await _loadOrderDetails(order.id, resetCurrent: true);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      UiUtils.showSoftSnackBar(
        context,
        message: error.errorMessage?.toString() ?? 'تعذر إلغاء الطلب.',
      );
    } catch (_) {
      if (!mounted) return;
      UiUtils.showSoftSnackBar(context,
          message: 'تعذر إلغاء الطلب. حاول لاحقًا.');
    } finally {
      if (!mounted) return;
      setState(() => _cancelLoading = false);
    }
  }

  Future<bool> _confirmCancellation(UserOrder order) async {
    final OrderActions actions = order.actions;
    final String title = actions.canRefundDeposit
        ? 'استرداد المبلغ وإلغاء الطلب؟'
        : 'هل تريد إلغاء الطلب؟';
    final String message = actions.hasCancelDescription
        ? actions.cancelDescription!.trim()
        : actions.canRefundDeposit
            ? 'سيتم إرسال طلب لاسترداد العربون وإلغاء الطلب الحالي. هل ترغب في المتابعة؟'
            : 'سيتم إلغاء الطلب الحالي. هل ترغب في المتابعة؟';
    final String? hint = actions.hasCancelHint ? actions.cancelHint : null;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message,
                textAlign: TextAlign.start,
              ),
              if (hint != null && hint.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  hint.trim(),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(actions.cancelButtonLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  static const double _outstandingEpsilon = 0.005;

  OrderOutstandingInfo? _findOutstandingInfo(UserOrder order) {
    OrderOutstandingInfo? info;

    info = _selectOutstanding(info, _extractOutstanding(order.paymentSummary));
    info = _selectOutstanding(
        info, _extractOutstanding(order.deliveryPaymentSummary));
    info = _selectOutstanding(info, _extractOutstanding(order.raw));

    return info;
  }

  OrderOutstandingInfo? _selectOutstanding(
      OrderOutstandingInfo? current, OrderOutstandingInfo? candidate) {
    if (candidate == null) {
      return current;
    }
    if (current == null) {
      return candidate;
    }

    final bool candidatePositive = candidate.amount > _outstandingEpsilon;
    final bool currentPositive = current.amount > _outstandingEpsilon;

    if (candidatePositive && !currentPositive) {
      return candidate;
    }
    if (!candidatePositive && currentPositive) {
      return current;
    }
    if (candidatePositive && currentPositive) {
      return candidate.amount >= current.amount ? candidate : current;
    }
    return current;
  }

  OrderOutstandingInfo? _extractOutstanding(Map<String, dynamic>? source) {
    if (source == null || source.isEmpty) {
      return null;
    }

    OrderOutstandingInfo? resolved;

    void traverse(dynamic node, {String? key}) {
      if (node is Map) {
        final Map<dynamic, dynamic> map = node;
        for (final MapEntry<dynamic, dynamic> entry in map.entries) {
          final String entryKey = entry.key.toString();
          if (_isOutstandingKey(entryKey)) {
            final OrderOutstandingInfo? candidate =
                _extractOutstandingValue(entry.value);
            if (candidate != null) {
              resolved = _selectOutstanding(resolved, candidate);
            }
          }
          traverse(entry.value, key: entryKey);
        }
      } else if (node is Iterable) {
        for (final dynamic element in node) {
          traverse(element, key: key);
        }
      } else if (key != null && _isOutstandingKey(key)) {
        final OrderOutstandingInfo? candidate = _extractOutstandingValue(node);
        if (candidate != null) {
          resolved = _selectOutstanding(resolved, candidate);
        }
      }
    }

    traverse(source);
    return resolved;
  }

  bool _isOutstandingKey(String key) {
    final String lower = key.toLowerCase();
    if (lower.contains('due_date') ||
        lower.contains('due_at') ||
        lower.contains('due_on') ||
        lower.contains('due_time')) {
      return false;
    }

    const List<String> indicators = <String>[
      'outstanding',
      'balance_due',
      'due_balance',
      'due_amount',
      'amount_due',
      'amount_due_now',
      'remaining_balance',
      'remaining_due',
      'pending_amount',
      'pending_balance',
      'unpaid_amount',
      'unpaid_balance',
      'total_due',
      'due_total',
      'amount_remaining',
      'remaining_amount',
      'left_to_pay',
      'still_due',
      'balance_to_pay',
      'payment_due',
    ];

    if (lower == 'due' || lower.endsWith('_due') || lower.endsWith('due')) {
      return true;
    }

    for (final String indicator in indicators) {
      final String normalized = indicator.toLowerCase();
      if (lower == normalized || lower.contains(normalized)) {
        return true;
      }
    }

    return false;
  }

  OrderOutstandingInfo? _extractOutstandingValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Map) {
      final Map<dynamic, dynamic> map = value;
      OrderOutstandingInfo? nested;

      for (final MapEntry<dynamic, dynamic> entry in map.entries) {
        final String key = entry.key.toString().toLowerCase();
        if (_isDisplayKey(key)) {
          final String? label = _asString(entry.value);
          if (label != null) {
            nested = (nested ?? OrderOutstandingInfo(0, label: label.trim()))
                .copyWith(label: label.trim());
          }
        }

        if (_isNumericKey(key)) {
          final OrderOutstandingInfo? candidate =
              _extractOutstandingValue(entry.value);
          if (candidate != null) {
            nested = _selectOutstanding(nested, candidate);
          }
        }
      }

      if (nested != null && nested.amount.abs() > _outstandingEpsilon) {
        return nested;
      }

      final String? fallbackLabel = _findDisplayValue(map);
      if (fallbackLabel != null && (nested == null || nested.label == null)) {
        nested =
            (nested ?? OrderOutstandingInfo(0, label: fallbackLabel.trim()))
                .copyWith(label: fallbackLabel.trim());
      }

      if (nested != null && nested.amount == 0) {
        final double? numeric = _tryParseNumeric(map);
        if (numeric != null) {
          nested = nested.copyWith(amount: numeric);
        }
      }

      if (nested != null) {
        return nested.amount == 0
            ? nested.copyWith(amount: _tryParseNumeric(map) ?? 0)
            : nested;
      }

      final double? numeric = _tryParseNumeric(map);
      if (numeric != null) {
        return OrderOutstandingInfo(
          numeric,
          label: _findDisplayValue(map),
        );
      }

      return null;
    }

    if (value is Iterable) {
      OrderOutstandingInfo? result;
      for (final dynamic element in value) {
        final OrderOutstandingInfo? candidate =
            _extractOutstandingValue(element);
        if (candidate != null) {
          result = _selectOutstanding(result, candidate);
        }
      }
      return result;
    }

    final double? numeric = _tryParseNumeric(value);
    if (numeric != null) {
      return OrderOutstandingInfo(
        numeric,
        label: value is String ? value.trim() : null,
      );
    }

    return null;
  }

  bool _isDisplayKey(String key) {
    return key.contains('display') ||
        key.contains('formatted') ||
        key.contains('label') ||
        key.contains('text') ||
        key.contains('string');
  }

  bool _isNumericKey(String key) {
    return key.contains('value') ||
        key.contains('amount') ||
        key.contains('total') ||
        key.contains('due') ||
        key.contains('balance') ||
        key.contains('remaining') ||
        key.contains('numeric') ||
        key.contains('raw');
  }

  String? _findDisplayValue(Map<dynamic, dynamic> map) {
    for (final MapEntry<dynamic, dynamic> entry in map.entries) {
      final String key = entry.key.toString().toLowerCase();
      if (_isDisplayKey(key)) {
        final String? value = _asString(entry.value);
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  String? _asString(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }

  double? _tryParseNumeric(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      String normalized = value.replaceAll(RegExp('[^0-9,.-]'), '');
      if (normalized.isEmpty) {
        return null;
      }

      final int lastComma = normalized.lastIndexOf(',');
      final int lastDot = normalized.lastIndexOf('.');

      if (lastComma > lastDot) {
        normalized = normalized.replaceAll('.', '');
        normalized = normalized.replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }

      return double.tryParse(normalized);
    }

    if (value is Map) {
      return _tryParseNumeric(value.values);
    }

    if (value is Iterable) {
      for (final dynamic element in value) {
        final double? candidate = _tryParseNumeric(element);
        if (candidate != null) {
          return candidate;
        }
      }
    }

    return null;
  }

  String _buildOutstandingMessage(OrderOutstandingInfo info) {
    final String? label = info.label;
    final String suffix = label != null && label.trim().isNotEmpty
        ? ' (${label.trim()})'
        : info.amount > 0
            ? ' (${NumberFormat('#,##0.##').format(info.amount)})'
            : '';
    return 'لا يمكن عرض الفاتورة قبل تسوية جميع المبالغ المستحقة$suffix.';
  }

  String _formatOutstandingLabel(OrderOutstandingInfo info) {
    if (info.label != null && info.label!.trim().isNotEmpty) {
      return info.label!.trim();
    }
    final NumberFormat formatter = NumberFormat('#,##0.##');
    final String formatted = formatter.format(info.amount);
    final String currency = (info.currency ?? '').trim();
    final String suffix =
        currency.isNotEmpty ? ' ${currency.toUpperCase()}' : '';
    return '$formatted$suffix'.trim();
  }

  Future<void> _handlePayOutstanding(
      UserOrder order, OrderOutstandingInfo outstanding) {
    return _showPaymentSheet(order, outstanding);
  }

  Future<File> _persistInvoice(Uint8List bytes,
      {required String fileName}) async {
    final Directory directory = await getTemporaryDirectory();
    final String sanitized = _sanitizeFileName(fileName);
    final File file = File(path.join(directory.path, sanitized));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _sanitizeFileName(String value) {
    String normalized = value.trim();
    if (normalized.isEmpty) {
      normalized = 'invoice.pdf';
    }

    normalized = normalized.replaceAll(RegExp('[\\/:*?"<>|]'), '-');
    if (!normalized.toLowerCase().endsWith('.pdf')) {
      normalized = '$normalized.pdf';
    }
    return normalized;
  }

  Future<void> _showPaymentSheet(
      UserOrder order, OrderOutstandingInfo outstanding) async {
    final bool? refreshed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return BlocProvider<OrderPaymentCubit>(
          create: (_) => OrderPaymentCubit(),
          child: OrderPaymentSheet(
            orderId: order.id,
            orderLabel: order.displayLabel,
            outstandingAmount: outstanding.amount,
            outstandingLabel: outstanding.label,
            currency: outstanding.currency ?? order.currency,
          ),
        );
      },
    );

    if (refreshed == true && mounted) {
      await _loadOrderDetails(order.id, resetCurrent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserOrder? order = _orderDetails?.order;
    final bool showLoading = (_listLoading || _detailLoading) && order == null;

    final List<OrderStepData> steps =
        order != null ? buildOrderStepData(order) : const <OrderStepData>[];

    final OrderOutstandingInfo? outstanding =
        order != null ? _findOutstandingInfo(order) : null;
    final OrderOutstandingInfo? outstandingWithCurrency = outstanding?.copyWith(
      currency: order?.currency,
    );
    final bool canOpenInvoice = order != null &&
        (outstandingWithCurrency == null ||
            outstandingWithCurrency.amount <= _outstandingEpsilon);

    final String? invoiceBlockReason =
        !canOpenInvoice && outstandingWithCurrency != null
            ? _buildOutstandingMessage(outstandingWithCurrency)
            : null;

    final bool hasOutstanding = outstandingWithCurrency != null &&
        outstandingWithCurrency.amount > _outstandingEpsilon;
    final String? outstandingLabel = hasOutstanding
        ? _formatOutstandingLabel(outstandingWithCurrency)
        : null;

    return OrderStepContent(
      isLoading: showLoading,
      order: order,
      orderDetails: _orderDetails,
      steps: steps,
      errorMessage: _errorMessage,
      dateFormat: _dateFormat,
      onRetry: _refresh,
      onOpenInvoice: _openInvoice,
      onCancelOrder: _handleCancel,
      isCancelling: _cancelLoading,
      canOpenInvoice: canOpenInvoice,
      isInvoiceLoading: _invoiceLoading,
      invoiceBlockReason: invoiceBlockReason,
      outstanding: outstandingLabel,
      onPayOutstanding: (order != null && hasOutstanding)
          ? () => _handlePayOutstanding(order, outstandingWithCurrency)
          : null,
      paymentSummary: _orderDetails?.paymentSummary ?? order?.paymentSummary,
      deliveryPaymentSummary: _orderDetails?.deliveryPaymentSummary ??
          order?.deliveryPaymentSummary,
      depositReceipts: _orderDetails?.depositReceipts,
    );
  }
}
