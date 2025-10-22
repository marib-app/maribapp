class Adapter {
  ///String to int
  static int? forceInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is bool) {
      return value ? 1 : 0;
    }

    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return 0;
      }

      final String lower = trimmed.toLowerCase();
      if (lower == 'true') {
        return 1;
      }
      if (lower == 'false') {
        return 0;
      }
      return int.tryParse(trimmed);

    }
    throw "$value is not valid parsable int";

  }

  double? forceDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value == "") {
      return 0.0;
    }
    if (value is double) {
      return value;
    } else {
      try {
        return double.tryParse(value as String);
      } catch (e) {
        throw "$value is not valid parsable double";
      }
    }
  }
}
