/// Utilities to work with the seller verification status that can arrive from
/// the API using a variety of shapes (int, bool, string, status text...)
/// and needs to be interpreted consistently across the app.
bool parseSellerVerification(dynamic raw) {
  if (raw == null) {
    return false;
  }

  if (raw is bool) {
    return raw;
  }

  if (raw is num) {
    return raw == 1;
  }

  final String normalized = raw.toString().trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }

  return normalized == '1' ||
      normalized == 'true' ||
      normalized == 'approved';
}