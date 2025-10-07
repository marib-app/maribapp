import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

double _degToRad(double deg) => deg * (pi / 180);

double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) *
          cos(_degToRad(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

// ✅ الدالة الجديدة: مسافة السيارة من خرائط Google
Future<double?> getDrivingDistanceInKm({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
}) async {
  const apiKey = "AIzaSyBPXbLVNlZLz_At8lWbjQDWwjH-qPoDf6E";

  final url =
      "https://maps.googleapis.com/maps/api/directions/json?origin=$originLat,$originLng&destination=$destLat,$destLng&key=$apiKey&mode=driving";

  try {
    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['routes'] != null &&
        data['routes'].isNotEmpty &&
        data['routes'][0]['legs'] != null &&
        data['routes'][0]['legs'].isNotEmpty) {
      final meters = data['routes'][0]['legs'][0]['distance']['value'];
      return meters / 1000; // كم
    }
  } catch (e) {
    print("خطأ في المسافة: $e");
  }
  return null;
}

// ✅ دالة حساب رسوم التوصيل بدقة
int calculateDeliveryFee(double distanceKm, String size) {
  switch (size) {
    case "small":
      return (distanceKm * 500).round();
    case "medium":
      return (distanceKm * 600).round();
    case "large":
      return (distanceKm * 800).round();
    default:
      return 0;
  }
}
