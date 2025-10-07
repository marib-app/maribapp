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

    return Scaffold(
      backgroundColor: context.color.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: ' خيارات الدفع ',
        showBackButton: true,
      ),
      body: _loadingBanks
          ? _banksShimmer(onSurface)
          : (!hasAnyOptions
              ? _emptyBanks()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                  children: [
                    // عنوان توضيحي أعلى الصفحة
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
                        pressed: _pressedBankId ==
                            _BankTransferScreenState._eastYemenPressedKey,
                        onSurface: onSurface,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // بطاقة ملخص المحفظة فوق قائمة البنوك
                    _walletPaymentCard(onSurface),
                    const SizedBox(height: 12),

                    // قائمة كروت البنوك (بدون ظل + تأثير ضغط)
                    ...List.generate(_banks.length, (i) {
                      final b = _banks[i];
                      final selected = _selectedMethod ==
                              _BankTransferScreenState._manualBankMethod &&
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
                            _selectedMethod =
                                _BankTransferScreenState._manualBankMethod;
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
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? context.color.secondaryColor
                                        .withOpacity(.88)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? context.color.territoryColor
                                      : context.color.borderColor
                                          .withOpacity(.65),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // اسم البنك
                                        Text(
                                          b.bankName,
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
                                              final raw =
                                                  accountName.replaceAll(
                                                RegExp(r'\s+'),
                                                '',
                                              );
                                              final isNumeric =
                                                  raw.isNotEmpty &&
                                                      RegExp(r'^[0-9٠-٩]+$')
                                                          .hasMatch(raw);
                                              final title = isNumeric
                                                  ? 'رقم الحساب'
                                                  : 'حوالة باسم';
                                              final highlighted =
                                                  _highlightedAccountNameBankId ==
                                                      b.id;
                                              final highlightBorderColor =
                                                  highlighted
                                                      ? context
                                                          .color.territoryColor
                                                          .withOpacity(
                                                          Theme.of(context)
                                                                      .brightness ==
                                                                  Brightness
                                                                      .dark
                                                              ? .7
                                                              : .5,
                                                        )
                                                      : onSurface
                                                          .withOpacity(.12);

                                              return Row(
                                                children: [
                                                  Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: onSurface
                                                          .withOpacity(.7),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Material(
                                                      type: MaterialType
                                                          .transparency,
                                                      child: Ink(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: onSurface
                                                              .withOpacity(.05),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          border: Border.all(
                                                            color:
                                                                highlightBorderColor,
                                                          ),
                                                        ),
                                                        child: InkWell(
                                                          onHighlightChanged:
                                                              (h) {
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
                                                              BorderRadius
                                                                  .circular(10),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 12,
                                                              vertical: 10,
                                                            ),
                                                            child: Text(
                                                              accountName,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color:
                                                                    onSurface,
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
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    onSurface.withOpacity(.05),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: onSurface
                                                      .withOpacity(.12),
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      displayNumber,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.copy_rounded,
                                                    size: 18,
                                                    color: onSurface
                                                        .withOpacity(.6),
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

                    const SizedBox(height: 12),

                    // تعليمات البنك (notes) أسفل القائمة
                    if (instructionsText != null)
                      _bankNoteCard(
                        title: instructionsTitle ?? 'ملاحظة',
                        note: instructionsText,
                        onSurface: onSurface,
                      ),

                    const SizedBox(height: 12),

                    if (_selectedMethod ==
                        _BankTransferScreenState._manualBankMethod)
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

                    // ملاحظات (اختياري)
                    _inputField(
                      controller: _notesCtrl,
                      hint: 'ملاحظات (اختياري)',
                      onSurface: onSurface,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),

                    // إرفاق الإيصال مع أنميشن + معاينة مصغّرة
                    if (_selectedMethod ==
                        _BankTransferScreenState._manualBankMethod)
                      _attachReceiptTile(onSurface),
                  ],
                )),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _confirmButton(amountStr, curr),
        ),
      ),
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

  Widget _walletPaymentCard(Color onSurface) {
    final summary = _walletSummary;
    final currency = summary?.currency ??
        widget.args.normalizedCurrency ??
        widget.args.currency ??
        '';
    final balanceText = summary != null
        ? _formatWalletBalance(summary)
        : '—${currency.isNotEmpty ? ' $currency' : ''}';
    final bool hasError = _walletError != null;
    final bool selected = _usingWallet;
    final bool pressed =
        _pressedBankId == _BankTransferScreenState._walletPressedKey;

    final errorMessage = () {
      if (!hasError) return null;
      final text = _walletError.toString().trim();
      if (text.isEmpty || text == 'null') {
        return 'تعذّر تحديث رصيد المحفظة. حاول مرة أخرى.';
      }
      return 'تعذّر تحديث رصيد المحفظة: $text';
    }();

    String statusText;
    Color statusColor;
    if (hasError) {
      statusText = errorMessage ?? 'تعذّر تحديث رصيد المحفظة';
      statusColor = Theme.of(context).colorScheme.error;
    } else if (_loadingWallet) {
      statusText = 'جاري تحديث رصيد المحفظة...';
      statusColor = onSurface.withOpacity(.7);
    } else if (summary == null) {
      statusText = 'الرصيد غير متاح';

      statusColor = onSurface.withOpacity(.7);
    } else {
      statusText = 'الرصيد: $balanceText';
      statusColor = _walletHasEnoughBalance
          ? onSurface.withOpacity(.8)
          : Theme.of(context).colorScheme.error;
      if (!_walletHasEnoughBalance) {
        statusText = '$statusText (غير كافٍ)';
      }
    }

    final bool showInteractiveBalance = !hasError &&
        !_loadingWallet &&
        summary != null &&
        _walletHasEnoughBalance;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onHighlightChanged: (h) => setState(() => _pressedBankId =
            h ? _BankTransferScreenState._walletPressedKey : null),
        onTap: () => setState(() {
          _selectedMethod = _BankTransferScreenState._walletMethod;
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? context.color.secondaryColor
                            .withOpacity(selected ? .45 : .25)
                        : context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'محفظتي',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!showInteractiveBalance)
                        Text(
                          statusText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Text(
                              'الرصيد المتاح',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: onSurface.withOpacity(.75),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Material(
                                type: MaterialType.transparency,
                                child: InkWell(
                                  onHighlightChanged: (h) =>
                                      setState(() => _walletBalancePressed = h),
                                  onTap: () => _copyValueToClipboard(
                                    balanceText,
                                    label: 'الرصيد المتاح',
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    decoration: BoxDecoration(
                                      color: onSurface.withOpacity(
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? .12
                                              : .05),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _walletBalancePressed
                                            ? context.color.territoryColor
                                            : onSurface.withOpacity(.12),
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
                                            balanceText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (hasError && !_loadingWallet)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Icon(
                      Icons.error_outline,
                      color: statusColor,
                    ),
                  ),
                if (_loadingWallet)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? context.color.territoryColor
                      : context.color.borderColor.withOpacity(.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatWalletBalance(WalletSummary summary) {
    final currency = summary.currency ??
        widget.args.normalizedCurrency ??
        widget.args.currency ??
        'SAR';
    return '${summary.balance.toStringAsFixed(2)} $currency';
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
