/// Utility helper to ensure interface type values match the canonical names
/// expected by the backend service. The server currently uses values such as
/// `services_medical` while different parts of the UI may still reference the
/// older aliases like `medical_services`.
///
/// This mapper keeps the logic in a single place so every caller can normalize
/// their local values before sending them to the server or before comparing
/// values coming from different sources.
class SliderInterfaceMapper {
  static const Map<String, String> _preferredForms = <String, String>{
    'homepage': 'homepage',
    'request_ad': 'request_ad',
    'public_ads': 'public_ads',
    'real_estate_services': 'real_estate_services',
    'tourism_services': 'tourism_services',
    'shein_products': 'shein_products',
    'computer_section': 'computer_section',
    'other_services': 'other_services',
    'e_store': 'e_store',

    'services_all': 'services_all',


    'jobs': 'jobs',
    'events_offers': 'events_offers',
    'marib_lost': 'marib_lost',
    'marib_guide': 'marib_guide',
    'services_local': 'services_local',
    'services_medical': 'services_medical',
    'services_student': 'services_student',
  };

  static const Map<String, String> _aliases = <String, String>{
    'local_services': 'services_local',
    'localservices': 'services_local',
    'serviceslocal': 'services_local',
    'medical_services': 'services_medical',
    'medicalservices': 'services_medical',
    'servicesmedical': 'services_medical',
    'student_services': 'services_student',
    'studentservices': 'services_student',
    'servicesstudent': 'services_student',
    'shein': 'shein_products',
    'sheinproducts': 'shein_products',
    'shein_section': 'shein_products',
    'public': 'public_ads',
    'publicads': 'public_ads',
    'merchants': 'e_store',
    'merchant': 'e_store',
    'estore': 'e_store',
    'real_estate': 'real_estate_services',
    'realestate': 'real_estate_services',
    'tourism': 'tourism_services',
    'tourismservices': 'tourism_services',
    'computer': 'computer_section',
    'computers': 'computer_section',
    'computersection': 'computer_section',
    'services': 'services_all',
    'servicesall': 'services_all',


  };

  /// Returns the canonical interface type value expected by the backend.
  ///
  /// The method performs a light-weight cleanup (trim, lower case and
  /// separators normalisation) and resolves known aliases. When no alias is
  /// known the cleaned value is returned, giving the caller a best-effort
  /// normalisation.
  static String? normalize(String? rawValue) {
    if (rawValue == null) {
      return null;
    }

    final String cleaned = rawValue
        .trim()
        .replaceAll(RegExp(r"[\s-]+"), '_')
        .replaceAll('ـ', '_')
        .toLowerCase();

    if (cleaned.isEmpty) {
      return null;
    }

    return _aliases[cleaned] ?? _preferredForms[cleaned] ?? cleaned;
  }

  /// Convenience helper used by list filtering logic to compare values after
  /// applying the canonical mapping.
  static bool isEquivalent(String? a, String? b) {
    return normalize(a) == normalize(b);
  }
}