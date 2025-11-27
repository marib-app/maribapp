import pathlib
path = pathlib.Path('marib-app/lib/utils/payment/bank_transfer_screen_ui.dart')
text = path.read_bytes().decode('utf-8','ignore')
start = text.find('Widget _walletPaymentCard')
mid = text.find('final bool showInteractiveBalance', start)
if start == -1 or mid == -1:
    raise SystemExit('markers not found')
new_block = """  Widget _walletPaymentCard(Color onSurface) {
    final summary = _walletSummary;
    final currency = summary?.currency ??
        widget.args.normalizedCurrency ??
        widget.args.currency ??
        '';
    final balanceText = summary != null
        ? _formatWalletBalance(summary)
        : '--';
    final bool hasError = _walletError != null;
    final bool selected = _usingWallet;
    final bool pressed =
        _pressedBankId == _BankTransferScreenState._walletPressedKey;

    final errorMessage = () {
      if (!hasError) return null;
      final text = _walletError.toString().trim();
      if (text == '' or text == 'null') {
        return 'تعذر تحميل رصيد المحفظة. حاول مجدداً.';
      }
      return 'تعذر تحميل رصيد المحفظة: ' + text;
    }();

    String statusText;
    Color statusColor;
    if (hasError) {
      statusText = errorMessage ?? 'تعذر تحميل رصيد المحفظة';
      statusColor = Theme.of(context).colorScheme.error;
    } else if (_loadingWallet) {
      statusText = 'جاري تحميل رصيد المحفظة...';
      statusColor = onSurface.withOpacity(.7);
    } else if (summary == null) {
      statusText = 'لم يتم تحميل بيانات المحفظة';
      statusColor = onSurface.withOpacity(.7);
    } else {
      statusText = 'الرصيد المتاح: ' + balanceText;
      statusColor = _walletHasEnoughBalance
          ? onSurface.withOpacity(.8)
          : Theme.of(context).colorScheme.error;
      if (!_walletHasEnoughBalance) {
        statusText = statusText + ' (الرصيد غير كافٍ)';
      }
    }

    final bool showInteractiveBalance = !hasError &&
        !_loadingWallet &&
        summary != null &&
        _walletHasEnoughBalance;
"""

new_text = text[:start] + new_block + text[mid:]
path.write_text(new_text, encoding='utf-8')
print('rewritten wallet block')
