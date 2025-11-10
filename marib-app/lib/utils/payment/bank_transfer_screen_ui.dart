part of 'bank_transfer_screen.dart';

extension _BankTransferScreenUi on _BankTransferScreenState {
  Widget buildBankTransferScreen(BuildContext context) {
    final amountStr = widget.args.amount.toStringAsFixed(2);
    final curr = widget.args.normalizedCurrency ?? widget.args.currency ?? '';
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hasAnyOptions = (_eastYemenBank != null) || _banks.isNotEmpty;

    BankAccount? selectedBank;
    if (_selectedMethod == _BankTransferScreenState._manualBankMethod &&
        _banks.isNotEmpty) {
      for (final bank in _banks) {
        if (bank.id == _selectedBankId) {
          selectedBank = bank;
          break;
        }
      }
      selectedBank ??= _banks.first;
    }
    String? instructionsText;
    String? instructionsTitle;

    if (_usingEastYemen) {
      instructionsText = _eastYemenBank?.note?.isNotEmpty == true
          ? _eastYemenBank!.note!
          : 'سيتم تحويلك لإكمال الدفع الإلكتروني عبر بنك الشرق.';
      instructionsTitle = 'تنبيه بنك الشرق';
    } else if ((selectedBank?.notes ?? '').isNotEmpty) {
      instructionsText = selectedBank!.notes;
      instructionsTitle = 'ملاحظة من البنك';
    }

    return StandardBottomSheetScaffold(
      header: _sheetHeader(onSurface, amountStr, curr),
      body: _loadingBanks
          ? _banksShimmer(onSurface)
          : (!hasAnyOptions
              ? _emptyBanks()
              : _buildPaymentOptionsList(
                  onSurface: onSurface,
                  instructionsText: instructionsText,
                  instructionsTitle: instructionsTitle,
                )),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: _confirmButton(amountStr, curr),
      ),
    );
  }

  StandardBottomSheetHeader _sheetHeader(
      Color onSurface, String amount, String currency) {
    final theme = Theme.of(context);
    final accent = context.color.territoryColor;
    final amountLabel = currency.isNotEmpty ? '$amount $currency' : amount;
    return StandardBottomSheetHeader(
      backgroundColor: theme.colorScheme.surface,
      showCloseButton: true,
      onClosePressed: _showCloseConfirmation,
      closeIconColor: accent,
      closeButtonBackgroundColor: accent.withOpacity(.12),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خيارات الدفع',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'المبلغ المستحق: $amountLabel',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: onSurface.withOpacity(.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'النافذة تبقى ظاهرة حتى تأكيد الإغلاق لضمان إتمام العملية بأمان.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: onSurface.withOpacity(.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionsList({
    required Color onSurface,
    required String? instructionsText,
    required String? instructionsTitle,
  }) {
    final bool hideWalletOption = !_walletGatewayAllowed ||
        _isWalletTopUpPurpose(widget.args.normalizedPurpose) ||
        _isWalletTopUpPurpose(_resolvedPurpose());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics:
          AppScrollBehavior.defaultPhysics,
      children: [
        Text(
          'اختر وسيلة الدفع المناسبة لك',
          style: TextStyle(
            color: onSurface.withOpacity(.85),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        if (_eastYemenBank != null) ...[
          _gatewayCard(
            config: _eastYemenBank!,
            selected: _usingEastYemen,
            pressed:
                _pressedBankId == _BankTransferScreenState._eastYemenPressedKey,
            onSurface: onSurface,
          ),
          const SizedBox(height: 12),
        ],
        if (!hideWalletOption) ...[
          _walletPaymentCard(),
          const SizedBox(height: 12),
        ],
        if (_manualGatewayAllowed) ...[
          ...List.generate(_banks.length, (i) {
            final b = _banks[i];
            final selected =
                _selectedMethod == _BankTransferScreenState._manualBankMethod &&
                    _selectedBankId == b.id;

          final pressed = _pressedBankId == b.id;

          final accountName = (b.accountName ?? '').trim();
          final accountNumber = (b.accountNumber ?? '').trim();
          final ibanValue = (b.iban ?? '').trim();
          final String? displayNumber = () {
            if (ibanValue.isNotEmpty) {
              return ibanValue;
            }
            if (accountNumber.isNotEmpty) {
              return accountNumber;
            }
            return null;
          }();
          final String displayLabel =
              ibanValue.isNotEmpty ? 'IBAN' : 'رقم الحساب';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onHighlightChanged: (h) =>
                  setState(() => _pressedBankId = h ? b.id : null),
              onTap: () => setState(() {
                _selectedMethod = _BankTransferScreenState._manualBankMethod;
                _selectedBankId = b.id;
                _attempted = false;
              }),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedScale(
                scale: pressed ? 0.98 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? context.color.secondaryColor.withOpacity(.88)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? context.color.territoryColor
                          : context.color.borderColor.withOpacity(.65),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _bankLogo(b.logoUrl),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _resolveBankDisplayName(b),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: onSurface,
                              ),
                            ),
                            if (accountName.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final raw = accountName.replaceAll(
                                    RegExp(r'\s+'),
                                    '',
                                  );
                                  final isNumeric = raw.isNotEmpty &&
                                      RegExp(r'^[0-9٠-٩]+$').hasMatch(raw);
                                  final title =
                                      isNumeric ? 'رقم الحساب' : 'حوالة باسم';
                                  final highlighted =
                                      _highlightedAccountNameBankId == b.id;
                                  final highlightBorderColor = highlighted
                                      ? context.color.territoryColor
                                          .withOpacity(
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? .7
                                                  : .5)
                                      : onSurface.withOpacity(.12);

                                  return Row(
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: onSurface.withOpacity(.7),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              color: onSurface.withOpacity(.05),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: highlightBorderColor,
                                              ),
                                            ),
                                            child: InkWell(
                                              onHighlightChanged: (h) {
                                                if (h &&
                                                    _highlightedAccountNameBankId !=
                                                        b.id) {
                                                  setState(() =>
                                                      _highlightedAccountNameBankId =
                                                          b.id);
                                                } else if (!h &&
                                                    _highlightedAccountNameBankId ==
                                                        b.id) {
                                                  setState(() =>
                                                      _highlightedAccountNameBankId =
                                                          null);
                                                }
                                              },
                                              onTap: () =>
                                                  _copyValueToClipboard(
                                                accountName,
                                                label: title,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                                child: Text(
                                                  accountName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: onSurface,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                            if (displayNumber != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                displayLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: onSurface.withOpacity(.7),
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => _copyValueToClipboard(
                                  displayNumber,
                                  label: displayLabel,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: onSurface.withOpacity(.05),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: onSurface.withOpacity(.12),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          displayNumber,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: onSurface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                        color: onSurface.withOpacity(.6),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected
                            ? context.color.territoryColor
                            : context.color.borderColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        ],
        const SizedBox(height: 12),
        if (instructionsText != null)
          _bankNoteCard(
            title: instructionsTitle ?? 'ملاحظة',
            note: instructionsText!,
            onSurface: onSurface,
          ),
        const SizedBox(height: 12),
        if (_selectedMethod == _BankTransferScreenState._manualBankMethod)
          _instructionCard(
            'إرفاق الإيصال مطلوب لاستكمال مراجعة التحويل.',
            onSurface,
          ),
        if (_usingEastYemen)
          _instructionCard(
            'لن تحتاج إلى رفع إيصال عند استخدام بوابة بنك الشرق الإلكترونية.',
            onSurface,
          ),
        const SizedBox(height: 16),
        if (_shouldShowSenderField) ...[
          _inputField(
            controller: _senderCtrl,
            hint: 'اسم المرسل',
            onSurface: onSurface,
            showError: _attempted && !_senderOk,
          ),
          const SizedBox(height: 12),
        ],
        if (_shouldShowTransferCodeField) ...[
          _inputField(
            controller: _transferCodeCtrl,
            hint: 'رقم الحوالة',
            onSurface: onSurface,
            showError: _attempted && !_transferCodeOk,
          ),
          const SizedBox(height: 12),
        ],
        _inputField(
          controller: _notesCtrl,
          hint: 'ملاحظات (اختياري)',
          onSurface: onSurface,
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        if (_selectedMethod == _BankTransferScreenState._manualBankMethod)
          _attachReceiptTile(onSurface),
      ],
    );
  }

  Widget _bankNoteCard({
    required String title,
    required String note,
    required Color onSurface,
  }) {
    final theme = Theme.of(context);
    final accent = context.color.territoryColor;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? accent.withOpacity(.18) : accent.withOpacity(.08);
    final borderColor = accent.withOpacity(isDark ? .5 : .35);
    final titleColor = isDark ? accent.withOpacity(.95) : accent;
    final bodyColor = onSurface.withOpacity(.9);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: accent,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: titleColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note,
                    style: TextStyle(
                      color: bodyColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletPaymentCard() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondaryColor = const Color(0xFFFF8000);
    final Color backgroundColor = theme.colorScheme.surface;
    final Color lightBackground =
    isDark ? Colors.grey.shade800 : const Color(0xFFF9F9F9);
    final Color textColor = isDark ? Colors.white : const Color(0xFF222222);
    final Color borderColor =
    isDark ? Colors.grey.shade600 : const Color(0xFFE0E0E0);
    final Color iconBackground =
    isDark ? Colors.deepPurple.shade400 : Colors.deepPurple.shade100;
    final Color iconColor = isDark ? Colors.white : Colors.deepPurple;

    String? sanitize(String? value) {
      if (value == null) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final WalletSummary? summary = _walletSummary;
    final bool walletSelected = _usingWallet;

    final bool hasError = _walletError != null;
    final bool walletCurrencyMismatch = !_walletCurrencyMatchesPayment;
    final bool canSelectWallet =
        !hasError && !_loadingWallet && summary != null && _walletCanPay;
    final bool pressed =
        canSelectWallet &&
            _pressedBankId == _BankTransferScreenState._walletPressedKey;

    final MoneyFormatter balanceFormatter = MoneyFormatter.fromCartCurrency(
      currency: sanitize(summary?.currency) ??
          sanitize(_paymentCurrencyLabel) ??
          sanitize(widget.args.normalizedCurrency) ??
          sanitize(widget.args.currency),
      currencyCode: summary?.currencyCode ?? _paymentCurrencyCode,
      fallbackLabel: _paymentCurrencyDisplay ??
          _paymentCurrencyLabel ??
          _paymentCurrencyCode ??
          sanitize(widget.args.normalizedCurrency) ??
          sanitize(widget.args.currency),
    );
    final String balanceText =
    summary == null ? '—' : balanceFormatter.format(summary.balance);

    final MoneyFormatter requiredFormatter = MoneyFormatter.fromCartCurrency(
      currency: sanitize(_paymentCurrencyLabel) ??
          sanitize(summary?.currency) ??
          sanitize(widget.args.normalizedCurrency) ??
          sanitize(widget.args.currency),
      currencyCode: _paymentCurrencyCode ?? summary?.currencyCode,
      fallbackLabel: _paymentCurrencyDisplay ??
          _paymentCurrencyLabel ??
          _paymentCurrencyCode ??
          sanitize(widget.args.normalizedCurrency) ??
          sanitize(widget.args.currency),
    );
    final String requiredAmountText =
    requiredFormatter.format(widget.args.amount);

    final String walletMessageLabel = _walletCurrencyLabel ??
        _walletCurrencyCode ??
        balanceFormatter.currencyLabel ??
        '—';
    final String paymentMessageLabel = _paymentCurrencyDisplay ??
        _paymentCurrencyLabel ??
        _paymentCurrencyCode ??
        requiredFormatter.currencyLabel ??
        '—';

    String statusText;
    Color statusColor;
    if (_loadingWallet) {

      statusText = 'جاري تحديث رصيد المحفظة...';
      statusColor = textColor.withOpacity(0.85);
    } else if (hasError) {
      statusText = 'تعذر تحديث رصيد المحفظة';
      statusColor = Colors.orange;
    } else if (summary == null) {

      statusText = 'المحفظة غير متاحة حاليًا';
      statusColor = Colors.orange;
    } else if (walletCurrencyMismatch) {

      statusText =
      'لا يمكن استخدام المحفظة بعملة $walletMessageLabel لعملية عملتها $paymentMessageLabel.';
      statusColor = Colors.orange;
    } else if (!_walletHasEnoughBalance) {
      statusText = 'الرصيد غير كافٍ لإجمالي $requiredAmountText';
      statusColor = Colors.redAccent;
    } else {
      statusText = 'الرصيد متاح للدفع';
      statusColor = Colors.green;
    }

    final double cardOpacity =
    canSelectWallet || _loadingWallet ? 1.0 : 0.65;
    final Color cardBorderColor =
    walletSelected ? secondaryColor : borderColor;
    final Color cardBackgroundColor =
    walletSelected ? lightBackground : backgroundColor;

    return Opacity(
      opacity: cardOpacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onHighlightChanged: canSelectWallet
              ? (h) => setState(() => _pressedBankId =
                  h ? _BankTransferScreenState._walletPressedKey : null)
              : null,
          onTap: canSelectWallet
              ? () => setState(() {
                    _selectedMethod = _BankTransferScreenState._walletMethod;
                    _selectedBankId = null;
                    _attempted = false;
                  })
              : null,
          borderRadius: BorderRadius.circular(12),

          child: AnimatedScale(
            scale: pressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: cardBackgroundColor,
                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: cardBorderColor,
                  width: walletSelected ? 1.6 : 1.2,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: iconBackground,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: iconColor,
                ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                      'المحفظة الإلكترونية',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: textColor,
                      ),
                        ),
                    const SizedBox(height: 6),
                    Text(
                      'الرصيد المتاح: $balanceText',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                        Text(
                          statusText,

                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                            height: 1.35,

                          ),

                        ),
                      ],
                    ),
                  ),
                if (_loadingWallet) ...[
              const SizedBox(width: 12),
          SizedBox(
                      height: 20,
                      width: 20,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                ] else if (walletSelected) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.check_circle, color: secondaryColor),
                ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatWalletBalance(WalletSummary summary) {
    final MoneyFormatter formatter = MoneyFormatter.fromCartCurrency(
      currency: summary.currency ??
          _paymentCurrencyLabel ??
          widget.args.normalizedCurrency ??
          widget.args.currency,
      currencyCode: summary.currencyCode ?? _paymentCurrencyCode,
      fallbackLabel: _paymentCurrencyDisplay ??
          _paymentCurrencyLabel ??
          _paymentCurrencyCode ??
          widget.args.normalizedCurrency ??
          widget.args.currency,
    );
    return formatter.format(summary.balance);
  }

  String _formatWalletUpdated(DateTime? updatedAt) {
    if (updatedAt == null) {
      return '—';
    }
    final formatter = DateFormat('d MMM yyyy • h:mm a', 'ar');
    return formatter.format(updatedAt.toLocal());
  }

  // ======= Widgets =======

  Widget _banksShimmer(Color onSurface) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
      children: [
        _ShimmerBox(controller: _shimmerCtl, height: 18, width: 220, radius: 6),
        const SizedBox(height: 12),
        ...List.generate(4, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.color.borderColor,
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _ShimmerBox(
                      controller: _shimmerCtl,
                      height: 46,
                      width: 46,
                      radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShimmerBox(
                            controller: _shimmerCtl,
                            height: 14,
                            width: 140,
                            radius: 4),
                        const SizedBox(height: 8),
                        _ShimmerBox(
                            controller: _shimmerCtl,
                            height: 12,
                            width: 200,
                            radius: 4),
                        const SizedBox(height: 8),
                        _ShimmerBox(
                            controller: _shimmerCtl,
                            height: 10,
                            width: 120,
                            radius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        _ShimmerBox(controller: _shimmerCtl, height: 44, radius: 12),
        const SizedBox(height: 12),
        _ShimmerBox(controller: _shimmerCtl, height: 80, radius: 12),
        const SizedBox(height: 12),
        _ShimmerBox(controller: _shimmerCtl, height: 64, radius: 12),
      ],
    );
  }

  Widget _emptyBanks() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'لا توجد وسائل دفع متاحة حالياً',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadBanks,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  Widget _gatewayCard({
    required EastYemenBankConfig config,
    required bool selected,
    required bool pressed,
    required Color onSurface,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onHighlightChanged: (h) => setState(() => _pressedBankId =
            h ? _BankTransferScreenState._eastYemenPressedKey : null),
        onTap: () => setState(() {
          _selectedMethod = _BankTransferScreenState._eastYemenMethod;
          _selectedBankId = null;
          _attempted = false;
        }),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedScale(
          scale: pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? context.color.territoryColor
                    : context.color.borderColor,
                width: selected ? 2 : 1.2,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _bankLogo(config.logoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'بوابة بنك الشرق — دفع إلكتروني مباشر',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: onSurface.withOpacity(.75),
                        ),
                      ),
                      if ((config.currencyCode ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'العملة: ${config.currencyCode}',
                            style: TextStyle(
                              fontSize: 11,
                              color: onSurface.withOpacity(.65),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? context.color.territoryColor
                      : context.color.borderColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _copyableValueChip({
    required String label,
    required String value,
    required Color onSurface,
  }) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return const SizedBox.shrink();

    final backgroundColor = Theme.of(context).brightness == Brightness.dark
        ? onSurface.withOpacity(.06)
        : Colors.grey.shade100;

    return Tooltip(
      message: 'نسخ $label',
      child: InkWell(
        onTap: () => _copyValueToClipboard(trimmedValue, label: label),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: onSurface.withOpacity(.18)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: onSurface.withOpacity(.75),
                      fontSize: 12,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: '$label ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: onSurface.withOpacity(.8),
                        ),
                      ),
                      TextSpan(
                        text: '"$trimmedValue"',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.copy_rounded,
                size: 18,
                color: onSurface.withOpacity(.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instructionCard(String note, Color onSurface) {
    return Container(
      decoration: BoxDecoration(
        color: onSurface.withOpacity(.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onSurface.withOpacity(.12)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, color: onSurface.withOpacity(.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bankLogo(String? url) {
    final placeholder = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.account_balance, size: 24),
    );

    if (url == null || url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        loadingBuilder: (c, w, p) => p == null ? w : placeholder,
        errorBuilder: (c, e, s) => placeholder,
      ),
    );
  }

  Widget _attachReceiptTile(Color onSurface) {
    final picked = _receiptFile != null;
    final showError = _attempted && !_receiptOk;
    final name = _receiptName ?? 'إرفاق إيصال (صورة/PDF)';
    final ext = (_receiptName ?? '').split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
    final errorColor = Theme.of(context).colorScheme.error;

    Widget leadingContent() {
      if (_pickingReceipt) {
        return const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      if (picked && isImage) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            _receiptFile!,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
          ),
        );
      }
      return Icon(
        picked ? Icons.check_circle_rounded : Icons.attachment_rounded,
        color: showError
            ? errorColor
            : picked
                ? Colors.green
                : onSurface.withOpacity(.8),
        size: 26,
      );
    }

    final borderColor = showError
        ? errorColor
        : picked
            ? context.color.territoryColor
            : context.color.borderColor;
    final borderWidth = showError ? 2.0 : (picked ? 2.0 : 1.2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: leadingContent(),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: showError ? errorColor : null,
          ),
        ),
        subtitle: showError
            ? Text(
                'الرجاء إرفاق إيصال التحويل',
                style: TextStyle(color: errorColor),
              )
            : (picked
                ? const Text('انقر للتغيير أو إعادة الاختيار')
                : const Text('الحد الأقصى 5MB — أرفق صورة أو PDF واضحة')),
        onTap: _pickingReceipt ? null : _pickReceipt,
        trailing: picked
            ? IconButton(
                tooltip: 'إزالة',
                onPressed: () => setState(() {
                  _receiptFile = null;
                  _receiptName = null;
                }),
                icon: const Icon(Icons.close),
              )
            : null,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required Color onSurface,
    int maxLines = 1,
    bool showError = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: context.color.secondaryColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.borderColor, width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: context.color.territoryColor, width: 1.6),
        ),
        errorText: showError ? 'الرجاء تعبئة هذا الحقل' : null,
      ),
      style: TextStyle(color: onSurface),
    );
  }

  Widget _confirmButton(String amount, String currency) {
    final bool canTap = _usingEastYemen ? !_submitting : _readyToSubmit;
    return ElevatedButton(
      onPressed: canTap ? _handleConfirmPressed : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        elevation: 0,
        backgroundColor:
            (canTap) ? context.color.territoryColor : context.color.borderColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ).merge(
        ButtonStyle(
          overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(.08)),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _submitting
            ? const SizedBox(
                key: ValueKey('loading'),
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                key: const ValueKey('text'),
                'تأكيد الدفع – $amount $currency',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
