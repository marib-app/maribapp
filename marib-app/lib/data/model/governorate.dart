class Governorate {
  final String code;
  final String name;

  const Governorate({
    required this.code,
    required this.name,
  });

  factory Governorate.fromJson(Map<String, dynamic> json) {
    return Governorate(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }
}