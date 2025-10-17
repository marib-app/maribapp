class PreferenceOption {
  const PreferenceOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  factory PreferenceOption.fromJson(Map<String, dynamic> json) {
    return PreferenceOption(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}