// lib/ui/screens/home/section/Items_List/widgets/map_search/utils/map_item_adapter.dart

import 'package:marib/data/model/item/item_model.dart'
    as app; // ItemModel تبع التطبيق

/// محوّل من موديل الخريطة (maprepo.ItemModel) إلى موديل التطبيق (app.ItemModel)
class MapItemAdapter {
  static app.ItemModel toAppItem(app.ItemModel m) => m;
}
