/// Normalizes transaction API responses that may wrap the payload
/// in nested `data` keys (e.g. `{ data: { data: [...] } }`) or use
/// alternative top-level keys.
List<Map<String, dynamic>> extractTransactionRows(
    Map<String, dynamic> response) {
  final dynamic root = response['data'] ?? response;
  final rows = _unwrapRows(root);
  return rows;
}

List<Map<String, dynamic>> _unwrapRows(dynamic payload) {
  if (payload is List) {
    final rows = <Map<String, dynamic>>[];
    for (final element in payload) {
      if (element is Map<String, dynamic>) {
        rows.add(element);
      } else if (element is Map) {
        rows.add(Map<String, dynamic>.from(element));
      }
    }
    return rows;
  }

  if (payload is Map) {
    // First try the common Laravel pagination structure { data: [...] }
    final dynamic innerData = payload['data'];
    if (innerData != null) {
      final rows = _unwrapRows(innerData);
      if (rows.isNotEmpty) {
        return rows;
      }
    }

    for (final key in const [
      'manual_payment_requests',
      'payment_transactions',
      'transactions',
      'items',
      'results',
    ]) {
      if (payload.containsKey(key)) {
        final rows = _unwrapRows(payload[key]);
        if (rows.isNotEmpty) {
          return rows;
        }
      }
    }
  }

  return const [];
}
