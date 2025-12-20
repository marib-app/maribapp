// Store add rating bottom sheet (mirrors service rating UI)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/widgets/standard_bottom_sheet_scaffold.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/ui/screens/storefront/widgets/store_ratings_api.dart';

class AddStoreRatingBottomSheet extends StatefulWidget {
  const AddStoreRatingBottomSheet({
    super.key,
    this.storeId,
    this.storeSlug,
    this.storeName,
  });

  final int? storeId;
  final String? storeSlug;
  final String? storeName;

  @override
  State<AddStoreRatingBottomSheet> createState() => _AddStoreRatingBottomSheetState();
}

class _AddStoreRatingBottomSheetState extends State<AddStoreRatingBottomSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  static const List<String> _emojis = ["😔", "🙁", "😐", "🙂", "🤩"];
  static const List<Map<String, String>> _labelPairs = [
    {"ar": "سيئ جداً", "en": "Very bad"},
    {"ar": "سيئ", "en": "Bad"},
    {"ar": "مقبول", "en": "Okay"},
    {"ar": "جيد", "en": "Good"},
    {"ar": "ممتاز", "en": "Excellent"},
  ];

  static const List<Map<String, String>> _suggestionPairs = [
    {"ar": "جودة المنتجات لا تطابق الوصف", "en": "Quality did not match description"},
    {"ar": "تأخير أو عدم الالتزام بالتسليم", "en": "Delay or delivery timing issues"},
    {"ar": "تواصل غير احترافي", "en": "Unprofessional communication"},
    {"ar": "السعر لا يطابق القيمة", "en": "Price does not match value"},
    {"ar": "أنصح بالتعامل مع هذا المتجر", "en": "I recommend this store"},
    {"ar": "تجربة مميزة وخدمة رائعة", "en": "Great experience and service"},
  ];

  int? _selectedSuggestion;
  double _rating = 0;
  bool _isSubmitting = false;
  late final AnimationController _emojiAnim;

  @override
  void initState() {
    super.initState();
    _emojiAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: .85,
      upperBound: 1.12,
    );
    _controller.addListener(() {
      final suggestions = _localizedSuggestions;
      if (_selectedSuggestion != null &&
          _selectedSuggestion! < suggestions.length &&
          _controller.text.trim() != suggestions[_selectedSuggestion!]) {
        setState(() => _selectedSuggestion = null);
      }
    });
  }

  @override
  void dispose() {
    _emojiAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;
  String _t(String ar, String en) => _isRtl ? ar : en;

  List<String> get _localizedLabels =>
      _labelPairs.map((p) => _t(p["ar"]!, p["en"]!)).toList();

  List<String> get _localizedSuggestions =>
      _suggestionPairs.map((p) => _t(p["ar"]!, p["en"]!)).toList();

  void _onRatingChanged(int v) {
    setState(() => _rating = v.toDouble());
    _emojiAnim.forward(from: .9);
  }

  Future<void> _submit() async {
    final stars = _rating.toInt();
    String text = _controller.text.trim();

    if (stars == 0) {
      HelperUtils.showSnackBarMessage(
          context, _t('اختر تقييمك أولاً', 'Please select a rating'));
      return;
    }
    if (text.isEmpty) {
      text = _t('أضف رأيك حول المتجر', 'Share a few words about the store');
    }

    final int? storeId = widget.storeId;
    if ((storeId == null || storeId <= 0) && (widget.storeSlug == null || widget.storeSlug!.isEmpty)) {
      HelperUtils.showSnackBarMessage(
          context, _t('لا يوجد معرف متجر صالح', 'Store id is missing'));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final ok = await StoreRatingsApi.addRating(
        storeId: storeId ?? 0,
        storeSlug: widget.storeSlug,
        stars: stars,
        comment: text,
      );

      if (!mounted) return;

      if (ok) {
        HelperUtils.showSnackBarMessage(
            context, _t('تم إرسال تقييمك بنجاح', 'Rating submitted successfully'));
        Navigator.of(context).pop(<String, dynamic>{
          'stars': stars.toDouble(),
          'review': text,
        });
      } else {
        HelperUtils.showSnackBarMessage(
            context, _t('تعذر إرسال التقييم', 'Failed to submit rating'));
      }
    } catch (e, stack) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Store add rating failed: $e\n$stack');
      }
      if (mounted) {
        HelperUtils.showSnackBarMessage(
            context,
            e.toString().isNotEmpty
                ? e.toString()
                : _t('تعذر إرسال التقييم', 'Failed to submit rating'));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.color;
    final accent = colors.territoryColor;
    final insets = MediaQuery.of(context).viewInsets;
    final isDark = theme.brightness == Brightness.dark;

    final titleText = _t('قيّم الخدمة', 'Rate the service'); // intentionally mirror service UI
    final subtitleText =
        _t('ملاحظاتك تساعدنا على تحسين جودة الخدمات.', 'Your feedback helps us improve.');
    final noteText = _t(
      'عزيزي العميل، نأخذ ملاحظاتك على محمل الجد. كن منصفاً وشارك تفاصيل تساعد الآخرين وأصحاب المتاجر.',
      'We take your feedback seriously. Be fair and share details that help others and store owners.',
    );
    final ratingLabel = _t('اختر التقييم', 'Choose rating');
    final quickLabel = _t('اقتراحات سريعة', 'Quick suggestions');
    final commentLabel = _t('اكتب رأيك', 'Share your experience');
    final hintText = _t('اكتب رأيك هنا...', 'Type your feedback here...');
    final submitText = _t('إرسال التقييم', 'Submit rating');
    final storeName = widget.storeName?.trim();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: StandardBottomSheetScaffold(
        header: StandardBottomSheetHeader(
          onClosePressed: () => Navigator.of(context).maybePop(),
          showCloseButton: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitleText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textDefaultColor.withValues(alpha: 0.72),
                  height: 1.4,
                ),
              ),
              if (storeName != null && storeName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.secondaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.borderColor.withValues(alpha: isDark ? 0.4 : 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined, size: 18, color: accent),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          storeName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textColorDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.secondaryColor.withValues(alpha: isDark ? 0.36 : 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderColor.withValues(alpha: 0.45)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.info_rounded, color: accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        noteText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textDefaultColor.withValues(alpha: 0.8),
                          height: 1.45,
                        ),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                ratingLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textColorDark,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final i = index + 1;
                        final selected = _rating >= i;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Material(
                            color: selected
                                ? accent.withValues(alpha: 0.12)
                                : colors.secondaryColor.withValues(alpha: 0.3),
                            shape: const CircleBorder(),
                            child: IconButton(
                              iconSize: 30,
                              visualDensity: VisualDensity.compact,
                              splashRadius: 26,
                              onPressed: () => _onRatingChanged(i),
                              icon: Icon(
                                selected ? Icons.star_rounded : Icons.star_border_rounded,
                                color: selected
                                    ? accent
                                    : colors.textDefaultColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: Center(
                        child: _rating > 0
                            ? ScaleTransition(
                                scale: _emojiAnim,
                                child: Text(
                                  "${_emojis[_rating.toInt() - 1]}  ${_localizedLabels[_rating.toInt() - 1]}",
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.textColorDark,
                                  ),
                                ),
                              )
                            : const SizedBox(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                quickLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textColorDark,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: List.generate(_localizedSuggestions.length, (i) {
                  final selected = _selectedSuggestion == i;
                  final label = _localizedSuggestions[i];
                  return ChoiceChip(
                    label: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: selected,
                    showCheckmark: false,
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? accent
                          : colors.textDefaultColor.withValues(alpha: 0.8),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    backgroundColor:
                        colors.secondaryColor.withValues(alpha: isDark ? 0.35 : 0.7),
                    selectedColor: accent.withValues(alpha: isDark ? 0.22 : 0.14),
                    side: BorderSide(
                      color: selected
                          ? accent
                          : colors.borderColor.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _selectedSuggestion = val ? i : null;
                        if (val) {
                          _controller.text = label;
                          _controller.selection = TextSelection.collapsed(
                            offset: _controller.text.length,
                          );
                        }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 18),
              Text(
                commentLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textColorDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                maxLines: 4,
                cursorColor: accent,
                decoration: InputDecoration(
                  hintText: hintText,
                  filled: true,
                  fillColor: colors.secondaryColor.withValues(
                    alpha: isDark ? 0.25 : 0.55,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.borderColor.withValues(alpha: 0.6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.borderColor.withValues(alpha: 0.6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: accent, width: 1.4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting || _rating == 0 ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: colors.secondaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.send_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          submitText,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
