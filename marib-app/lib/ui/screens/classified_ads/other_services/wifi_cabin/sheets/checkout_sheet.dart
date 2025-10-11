part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

class PaymentGatewayView {
  const PaymentGatewayView({
    required this.id,
    required this.name,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({required this.plan});

  final WifiPlan plan;

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final WifiRepository _repository = const WifiRepository();
  final Map<String, WifiPaymentGateway> _gatewayEntities =
  <String, WifiPaymentGateway>{};

  int _quantity = 1;
  String _gateway = 'wallet';
  List<PaymentGatewayView> _gateways = <PaymentGatewayView>[];
  bool _loadingGateways = false;
  String? _gatewaysError;
  bool _isSubmitting = false;
  bool _acknowledged = false;

  num get total => widget.plan.price * _quantity;

  @override
  void initState() {
    super.initState();
    _loadGateways();
  }

  Future<void> _loadGateways() async {
    if (_loadingGateways) return;
    setState(() {
      _loadingGateways = true;
      _gatewaysError = null;
    });

    List<PaymentGatewayView> views = _gateways;
    Map<String, WifiPaymentGateway> lookup = <String, WifiPaymentGateway>{};
    String? selectedId;
    String? errorMessage;

    try {
      final gateways = await _repository.fetchPaymentGateways();
      lookup = {for (final gateway in gateways) gateway.id: gateway};
      views = gateways
          .map(
            (gateway) => PaymentGatewayView(
          id: gateway.id,
          name: gateway.name,
          description: gateway.description,
        ),
      )
          .toList();

      if (views.isEmpty) {
        final WifiPaymentGateway fallback =
        const WifiPaymentGateway(id: 'wallet', name: 'المحفظة', isWallet: true);
        lookup = <String, WifiPaymentGateway>{fallback.id: fallback};
        views = const <PaymentGatewayView>[
          PaymentGatewayView(id: 'wallet', name: 'المحفظة'),
        ];
      }

      selectedId = _pickDefaultGatewayId(gateways, views.first.id);
    } catch (error) {
      errorMessage = error is ApiHttpException
          ? _extractErrorMessage(error.payload) ?? error.toString()
          : error.toString();
      if (_gateways.isEmpty) {
        final WifiPaymentGateway fallback =
        const WifiPaymentGateway(id: 'wallet', name: 'المحفظة', isWallet: true);
        lookup = <String, WifiPaymentGateway>{fallback.id: fallback};
        views = const <PaymentGatewayView>[
          PaymentGatewayView(id: 'wallet', name: 'المحفظة'),
        ];
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingGateways = false;
        _gateways = views;
        if (lookup.isNotEmpty) {
          _gatewayEntities
            ..clear()
            ..addAll(lookup);
        } else if (_gateways.isNotEmpty &&
            !_gatewayEntities.containsKey(_gateways.first.id)) {
          _gatewayEntities[_gateways.first.id] = WifiPaymentGateway(
            id: _gateways.first.id,
            name: _gateways.first.name,
            isWallet: _gateways.first.id.toLowerCase() == 'wallet',
          );
        }
        if (selectedId != null) {
          _gateway = selectedId!;
        } else if (!_gateways.any((gateway) => gateway.id == _gateway) &&
            _gateways.isNotEmpty) {
          _gateway = _gateways.first.id;
        }
        _gatewaysError = errorMessage;
      });
    }
  }

  String _pickDefaultGatewayId(
      List<WifiPaymentGateway> gateways,
      String fallbackId,
      ) {
    for (final gateway in gateways) {
      if (gateway.isDefault) {
        return gateway.id;
      }
    }
    for (final gateway in gateways) {
      if (gateway.isWallet) {
        return gateway.id;
      }
    }
    return fallbackId;
  }

  String? _stringify(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return value.trim().isEmpty ? null : value.trim();
    }
    return value.toString();
  }

  List<String> _flattenErrors(dynamic value) {
    if (value == null) return const <String>[];
    if (value is List) {
      return value
          .map((dynamic element) => _stringify(element))
          .whereType<String>()
          .where((element) => element.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      final List<String> results = <String>[];
      value.forEach((_, dynamic element) {
        final List<String> nested = _flattenErrors(element);
        if (nested.isEmpty) {
          final String? candidate = _stringify(element);
          if (candidate != null && candidate.isNotEmpty) {
            results.add(candidate);
          }
        } else {
          results.addAll(nested);
        }
      });
      return results;
    }
    final String? single = _stringify(value);
    if (single == null || single.isEmpty) {
      return const <String>[];
    }
    return <String>[single];
  }

  String? _extractErrorMessage(dynamic payload) {
    if (payload is Map) {
      final Map<String, dynamic> map = payload is Map<String, dynamic>
          ? payload
          : Map<String, dynamic>.from(payload as Map);
      final String? base = _stringify(
        map['message'] ?? map['error'] ?? map['detail'],
      );
      final List<String> details = _flattenErrors(map['errors']);
      final List<String> parts = <String>[
        if (base != null && base.isNotEmpty) base,
        if (details.isNotEmpty) details.join('\n'),
      ];
      if (parts.isEmpty) {
        return null;
      }
      return parts.join('\n');
    }
    return _stringify(payload);
  }

  void _showErrorMessage(String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onConfirm() async {
    if (_isSubmitting) return;
    if (!_acknowledged) {
      _showErrorMessage('يجب الموافقة على الإقرار قبل المتابعة.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _repository.purchasePlan(
        planId: widget.plan.id,
        quantity: _quantity,
        paymentGateway: _gateway,
        termsAcknowledged: _acknowledged,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiHttpException catch (error) {
      final String message =
          _extractErrorMessage(error.payload) ?? error.toString();
      _showErrorMessage(message);
    } on ApiException catch (error) {
      _showErrorMessage(error.toString());
    } catch (error) {
      _showErrorMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, controller) {
          return Container(
            decoration: BoxDecoration(
              color: color.backgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: color.secondaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan.name,
                        style: TextStyle(
                          color: color.textDefaultColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.plan.description ?? 'راجع تفاصيل الخطة قبل المتابعة.',
                        style: TextStyle(
                          color: color.textDefaultColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Row(
                        children: [
                          Text(
                            'الكمية',
                            style: TextStyle(
                              color: color.textDefaultColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _QtyStepper(
                            value: _quantity,
                            onChanged: (value) => setState(() => _quantity = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _TotalBar(
                        total: total,
                        currency: widget.plan.currency,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'طريقة الدفع',
                        style: TextStyle(
                          color: color.textDefaultColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_loadingGateways && _gateways.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        if (_gateways.isNotEmpty)
                          _GatewayPicker(
                            gateways: _gateways,
                            value: _gateway,
                            enabled: !_isSubmitting,
                            onChanged: (value) =>
                                setState(() => _gateway = value),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(
                              color: color.secondaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'لا توجد طرق دفع متاحة حالياً.',
                              style: TextStyle(
                                color: color.textDefaultColor.withOpacity(0.75),
                              ),
                            ),
                          ),
                        if (_loadingGateways && _gateways.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (_gatewaysError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _gatewaysError!,
                                  style: TextStyle(
                                    color: color.error,
                                    fontSize: 12.5,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadGateways,
                                  child: const Text('إعادة محاولة تحميل الطرق'),
                                ),
                              ],
                            ),
                          )
                        else
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color.secondaryColor
                                        .withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.shield_outlined,
                                        size: 20,
                                        color: color.textDefaultColor
                                            .withOpacity(0.8),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'الكرت يباع من صاحب الشبكة مباشرة. التطبيق يوفر وسيط الدفع فقط ولا يضمن صلاحية الكود أو الخدمة.',
                                          style: TextStyle(
                                            color: color.textDefaultColor
                                                .withOpacity(0.8),
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                CheckboxListTile(
                                  value: _acknowledged,
                                  onChanged: _isSubmitting
                                      ? null
                                      : (value) => setState(
                                        () =>
                                    _acknowledged = value ?? false,
                                  ),
                                  controlAffinity:
                                  ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'أؤكد أنني تحققت من صورة صفحة الدخول وأقر بأن أي مشكلة تُحل مباشرة مع صاحب الشبكة.',
                                    style: TextStyle(
                                      color: color.textDefaultColor,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                      (_isSubmitting || !_acknowledged) ? null : _onConfirm,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isSubmitting
                            ? Row(
                          key: const ValueKey('processing'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('جارٍ معالجة الدفع'),
                          ],
                        )
                            : Row(
                          key: const ValueKey('confirm'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle_outline),
                            SizedBox(width: 8),
                            Text('تأكيد الدفع'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.secondaryColor.withOpacity(0.2),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: color.textDefaultColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.total, this.currency});

  final num total;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.secondaryColor.withOpacity(0.2),
      ),
      child: Row(
        children: [
          Text(
            'الإجمالي',
            style: TextStyle(
              color: color.textDefaultColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${total.toStringAsFixed(2)} ${currency ?? 'ريال'}',
            style: TextStyle(
              color: color.textDefaultColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _GatewayPicker extends StatelessWidget {
  const _GatewayPicker({
    required this.gateways,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<PaymentGatewayView> gateways;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Column(
      children: gateways
          .map(
            (gateway) => RadioListTile<String>(
          value: gateway.id,
          groupValue: value,
          onChanged: enabled
              ? (val) {
            if (val != null) onChanged(val);
          }
              : null,
          title: Text(
            gateway.name,
            style: TextStyle(color: color.textDefaultColor),
          ),
          subtitle: gateway.description != null
              ? Text(
            gateway.description!,
            style: TextStyle(
              color: color.textDefaultColor.withOpacity(0.65),
              fontSize: 12,
            ),
          )
              : null,
        ),
      )
          .toList(),
    );
  }
}