part of 'chat_screen.dart';

extension _ChatScreenUiOffer on _ChatScreenState {
Widget buildOfferWidget() {
    final offerCurrencySymbol = _resolveCurrencySymbol();
    final double? offerPrice = widget.itemOfferPrice;

    if (offerPrice != null) {
      final String offerLabel =
          _formatPriceWithCurrency(offerPrice, offerCurrencySymbol);

      if (int.parse(HiveUtils.getUserId()!) == int.parse(widget.buyerId!)) {
        return Align(
          alignment: AlignmentDirectional.topEnd,
          child: Container(
              height: 71,
              margin: EdgeInsetsDirectional.only(top: 15, bottom: 15, end: 15),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: context.color.territoryColor.withOpacity(0.3)),
                  color: context.color.territoryColor.withOpacity(0.17),
                  borderRadius: BorderRadius.only(
                      topRight: Radius.circular(0),
                      topLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                      bottomLeft: Radius.circular(8))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("yourOffer".translate(context))
                      .color(context.color.textDefaultColor.withOpacity(0.5)),

                  /*  Text("yourOffer".translate(context))
                  .color(context.color.textDefaultColor.withOpacity(0.5)),*/
                  Text(offerLabel)
                      .bold()
                      .size(context.font.larger)
                      .color(context.color.textDefaultColor)
                ],
              )),
        );
      } else {
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Container(
              height: 71,
              margin:
                  EdgeInsetsDirectional.only(top: 15, bottom: 15, start: 15),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: context.color.territoryColor.withOpacity(0.3)),
                  color: context.color.territoryColor.withOpacity(0.17),
                  borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      topLeft: Radius.circular(0),
                      bottomRight: Radius.circular(8),
                      bottomLeft: Radius.circular(8))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("offerLbl".translate(context))
                      .color(context.color.textDefaultColor.withOpacity(0.5)),
                  Text(offerLabel)
                      .bold()
                      .size(context.font.larger)
                      .color(context.color.textDefaultColor)
                ],
              )),
        );
      }
    } else {
      return SizedBox.shrink();
    }
  }
}
