import 'package:marib/data/model/item/item_model.dart';

typedef PriceFormatter = String Function(ItemModel ad);
typedef ImageUrlResolver = String? Function(ItemModel ad);