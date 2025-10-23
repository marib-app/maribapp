String normalizeConversationId(String? value) {
  if (value == null) {
    return '';
  }

  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  if (trimmed.toLowerCase() == 'null') {
    return '';
  }

  return trimmed;
}

bool hasConversationId(String? value) {
  return normalizeConversationId(value).isNotEmpty;
}