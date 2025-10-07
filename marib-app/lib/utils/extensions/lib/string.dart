extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    if (length == 1) {
      return toUpperCase();
    }
    final firstCodeUnit = this[0].toUpperCase();
    return firstCodeUnit + substring(1);
  }
}
