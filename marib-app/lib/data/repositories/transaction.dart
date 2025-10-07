import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/transaction_model.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/payment/transaction_response_parser.dart';

class TransactionRepository {
  Future<DataOutput<TransactionModel>> fetchTransactions(
      {required int page}) async {
    Map<String, dynamic> parameters = {
      //Api.page:page
    };

    Map<String, dynamic> response = await Api.get(
        url: Api.getPaymentDetailsApi, queryParameters: parameters);

    final rows = extractTransactionRows(response);

    List<TransactionModel> transactionList =
        rows.map((e) => TransactionModel.fromJson(e)).toList();

    return DataOutput<TransactionModel>(
        total: transactionList.length, modelList: transactionList);
  }
}
