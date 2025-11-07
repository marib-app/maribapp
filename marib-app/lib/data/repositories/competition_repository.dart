import 'package:marib/data/model/challenge_model.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/payment/transaction_response_parser.dart';






class CompetitionRepository {
  Future<Map<String, dynamic>> getChallenges() async {
    try {
      // Replace 'Api.challengesEndpoint' with your actual API endpoint for challenges
      // Ensure Api.baseUrl is correctly defined in your utils/api.dart
      final response = await Api.get(url: Api.challengesApi);

      if (response['error'] == false && response['data'] is Map<String, dynamic>) {
        final Map<String, dynamic> envelope =
        Map<String, dynamic>.from(response['data'] as Map<String, dynamic>);

        final List<dynamic> challengesJson =
            envelope['challenges'] as List<dynamic>? ?? <dynamic>[];


        final List<Challenge> challenges = challengesJson
            .whereType<Map<String, dynamic>>()
            .map(Challenge.fromJson)
            .toList();

        final int maxPoints = (envelope['max_points'] as num?)?.toInt() ?? 0;
        final int totalPoints = (envelope['total_points'] as num?)?.toInt() ?? 0;
        final int totalRequiredReferrals =
            (envelope['total_required_referrals'] as num?)?.toInt() ?? 0;

        return {
          'challenges': challenges,
          'max_points': maxPoints,
          'total_points': totalPoints,
          'total_required_referrals': totalRequiredReferrals,
        };
      } else {
        throw Exception(
            response['message'] ?? 'Failed to load challenges: Invalid data format');
      }
    } catch (e) {
      // Handle other errors
      throw Exception('Failed to load challenges: $e');
    }
  }

  Future<Map<String, dynamic>> getUserReferralPoints() async {
    try {
      final response = await Api.get(url: 'user-referral-points');

      if (response['error'] == false) {
        return Map<String, dynamic>.from(
            response['data'] ?? const <String, dynamic>{});

      } else {
        throw Exception(
            response['message'] ?? 'Failed to load user referral points');
      }
    } catch (e) {
      throw Exception('Failed to load user referral points: $e');
    }
  }

  /// حفظ المعلومات المالية للمستخدم باستخدام complete-registration API
  Future<Map<String, dynamic>> savePaymentInfo({
    required String accountType,
    String? businessName,
    String? businessWhatsapp,
    String? businessLocation,
    List<String>? businessCategories,
    String? commercialRegister,
    List<String>? paymentMethods,
    Map<String, dynamic>? paymentAccountDetails,
    String? email,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'account_type': accountType,
      };

      // إضافة البيانات الاختيارية
      if (email != null && email.isNotEmpty) {
        payload['email'] = email;
      }

      if (businessName != null && businessName.isNotEmpty) {
        payload['business_name'] = businessName;
      }

      if (businessWhatsapp != null && businessWhatsapp.isNotEmpty) {
        payload['business_whatsapp'] = businessWhatsapp;
      }

      if (businessLocation != null && businessLocation.isNotEmpty) {
        payload['business_location'] = businessLocation;
      }

      if (businessCategories != null && businessCategories.isNotEmpty) {
        payload['business_categories'] = businessCategories.join(',');
      }

      if (commercialRegister != null && commercialRegister.isNotEmpty) {
        payload['commercial_register'] = commercialRegister;
      }

      if (paymentMethods != null && paymentMethods.isNotEmpty) {
        payload['payment_methods'] = paymentMethods.join(',');
      }

      if (paymentAccountDetails != null && paymentAccountDetails.isNotEmpty) {
        payload['payment_account_details'] = paymentAccountDetails;
      }

      final response = await Api.post(
        url: 'complete-registration',
        parameter: payload,
      );

      if (response['error'] == false) {
        final data = response['data'];
        final Map<String, dynamic> normalized = data is Map<String, dynamic>
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};

        if (response['store'] is Map<String, dynamic>) {
          normalized['store'] =
              Map<String, dynamic>.from(response['store'] as Map<String, dynamic>);
        }

        return normalized;
      } else {
        throw Exception(response['message'] ?? 'Failed to save payment info');
      }
    } catch (e) {
      throw Exception('Failed to save payment info: $e');
    }
  }

  /// الحصول على تاريخ المعاملات المالية باستخدام payment-transactions API
  Future<List<Map<String, dynamic>>> getPaymentTransactions({
    bool latestOnly = false,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (latestOnly) {
        queryParams['latest_only'] = true;
      }

      final response = await Api.get(
        url: Api.getPaymentDetailsApi,
        queryParameters: queryParams,
      );

      if (response['error'] == false) {

        final transactions = extractTransactionRows(response);
        return transactions;

      } else {
        throw Exception(
            response['message'] ?? 'Failed to load payment transactions');
      }
    } catch (e) {
      throw Exception('Failed to load payment transactions: $e');
    }
  }

  /// تحديث معلومات الدفع للمستخدم الحالي
  Future<Map<String, dynamic>> updateUserPaymentMethods({
    required List<String> paymentMethods,
    required Map<String, dynamic> paymentAccountDetails,
  }) async {
    try {
      return await savePaymentInfo(
        accountType: '2', // حساب تجاري
        paymentMethods: paymentMethods,
        paymentAccountDetails: paymentAccountDetails,
      );
    } catch (e) {
      throw Exception('Failed to update payment methods: $e');
    }
  }

  /// الحصول على آخر المعاملات المالية
  Future<List<Map<String, dynamic>>> getRecentPaymentTransactions() async {
    try {
      return await getPaymentTransactions(latestOnly: true);
    } catch (e) {
      throw Exception('Failed to load recent transactions: $e');
    }
  }
}
