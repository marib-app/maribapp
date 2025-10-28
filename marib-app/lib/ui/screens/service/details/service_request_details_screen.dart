import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/service_request_model.dart';
import 'package:marib/data/repositories/service_request_repository.dart';
import 'package:marib/ui/screens/classified_ads/units/service_payment_page.dart';
import 'package:marib/utils/helper_utils.dart';

class ServiceRequestDetailsScreen extends StatefulWidget {
  const ServiceRequestDetailsScreen({
    super.key,
    required this.serviceRequestId,
    this.subject,
    this.next,
  });

  final int serviceRequestId;
  final Map<String, dynamic>? subject;
  final Map<String, dynamic>? next;

  static Route route({
    required int serviceRequestId,
    Map<String, dynamic>? subject,
    Map<String, dynamic>? next,
  }) {
    return MaterialPageRoute(
      builder: (_) => ServiceRequestDetailsScreen(
        serviceRequestId: serviceRequestId,
        subject: subject,
        next: next,
      ),
      settings: RouteSettings(
        name: Routes.serviceRequestDetailsScreen,
        arguments: <String, dynamic>{
          'service_request_id': serviceRequestId,
          if (subject != null) 'subject': subject,
          if (next != null) 'next': next,
        },
      ),
    );
  }

  @override
  State<ServiceRequestDetailsScreen> createState() =>
      _ServiceRequestDetailsScreenState();
}

class _ServiceRequestDetailsScreenState
    extends State<ServiceRequestDetailsScreen> {
  final ServiceRequestRepository _repository = ServiceRequestRepository();
  ServiceRequestModel? _request;
  Map<String, dynamic>? _purchaseOptions;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final ServiceRequestModel request =
          await _repository.fetchRequest(id: widget.serviceRequestId);

      Map<String, dynamic>? options;
      try {
        options =
            await _repository.fetchPurchaseOptions(id: widget.serviceRequestId);
      } catch (_) {
        options = null;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _request = request;
        _purchaseOptions = options;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = true;
      });

      final String message =
          error is Exception ? error.toString() : 'Failed to load request.';
      HelperUtils.showSnackBarMessage(context, message);
    }
  }

  bool get _requiresPayment {
    final String? status = _request?.paymentStatus?.toLowerCase();

    if (status == null || status.isEmpty) {
      return true;
    }

    const Set<String> successStates = <String>{
      'success',
      'succeed',
      'succeeded',
      'paid',
      'approved',
      'completed',
    };

    return !successStates.contains(status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Request'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error || _request == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          Text(
            'Unable to load service request.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final ServiceRequestModel request = _request!;
    final List<Widget> details = <Widget>[
      _buildDetailTile('Request #', request.requestNumber ?? '#${request.id}'),
      _buildDetailTile('Status', request.status),
      _buildDetailTile('Payment Status', request.paymentStatus ?? 'pending'),
      if (request.serviceTitle != null)
        _buildDetailTile('Service', request.serviceTitle!),
      if (request.amount != null)
        _buildDetailTile(
          'Amount',
          _formatAmount(request.amount, request.currency),
        ),
      if (request.note != null && request.note!.isNotEmpty)
        _buildDetailTile('Note', request.note!),
      if (request.createdAt != null)
        _buildDetailTile(
          'Submitted',
          request.createdAt!.toLocal().toString(),
        ),
    ];

    final List<dynamic>? methodsRaw =
        _purchaseOptions?['methods'] as List<dynamic>?;
    final Iterable<Widget> methodChips = methodsRaw == null
        ? const <Widget>[]
        : methodsRaw
            .map(_normalizeMap)
            .where((Map<String, dynamic> map) => map.isNotEmpty)
            .map(
              (Map<String, dynamic> map) => Chip(
                label: Text(
                  (map['code'] ?? map['name'] ?? map['label'] ?? 'method')
                      .toString(),
                ),
              ),
            );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        ...details,
        if (methodChips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Available Payment Methods',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: methodChips.toList(),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _requiresPayment ? _handlePayNow : null,
          icon: const Icon(Icons.payments_outlined),
          label: Text(
            _requiresPayment ? 'Complete Payment' : 'Payment Completed',
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTile(String label, String value) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: textTheme.titleMedium),
        ],
      ),
    );
  }

  Future<void> _handlePayNow() async {
    final ServiceRequestModel? request = _request;

    if (request == null) {
      return;
    }

    final int? serviceId = request.serviceId;

    if (serviceId == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'Service information is missing.',
      );
      return;
    }

    final Map<String, dynamic> args = <String, dynamic>{
      'service_id': serviceId,
      'service_request_id': request.id,
      if (request.serviceTitle != null) 'serviceTitle': request.serviceTitle,
      if (request.amount != null) 'amount': request.amount,
      if (request.currency != null) 'currency': request.currency,
      if (request.note != null) 'note': request.note,
    };

    final Object? result = await Navigator.of(context).push(
      ServicePaymentPage.route(
        RouteSettings(
          name: Routes.servicePaymentPage,
          arguments: args,
        ),
      ),
    );

    if (!mounted || result == null || result == false) {
      return;
    }

    await _load();

    if (!mounted) {
      return;
    }

    HelperUtils.showSnackBarMessage(
      context,
      'Payment flow completed. Latest status loaded.',
    );
  }

  String _formatAmount(double? amount, String? currency) {
    if (amount == null) {
      return '--';
    }

    final String displayCurrency =
        (currency ?? '').trim().isEmpty ? 'YER' : currency!.trim().toUpperCase();

    final String formatted =
        amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);

    return '$formatted $displayCurrency';
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic val) =>
            MapEntry<String, dynamic>(key.toString(), val),
      );
    }
    return <String, dynamic>{};
  }
}
