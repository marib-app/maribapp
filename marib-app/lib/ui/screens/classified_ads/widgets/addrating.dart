// lib/new_code/ui/classified_ads/widgets/addrating.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/ui/screens/classified_ads/widgets/service_ratings_api.dart';

class AddRatingBottomSheet extends StatefulWidget {
  const AddRatingBottomSheet({
    super.key,
    this.itemId,
    this.serviceTitle,
    this.sellerId, // احتياطي للتوافق مع الاستدعاءات السابقة
    this.serviceUid,

  });

  final int? itemId;           // معرّف الخدمة
  final String? serviceTitle;  // غير مستخدم للإرسال، فقط للعرض إن لزم
  final int? sellerId;         // لم يعد مطلوبًا من واجهة الخدمة الحالية
  final String? serviceUid;

  @override
  State<AddRatingBottomSheet> createState() => _AddRatingBottomSheetState();
}

class _AddRatingBottomSheetState extends State<AddRatingBottomSheet> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  final List<String> _emojis = ["😡","🙁","😐","🙂","😍"];
  final List<String> _labels = ["سيّئ جدًا","سيّئ","عادي","جيد","ممتاز"];

  final List<String> _suggestions = const [
    "الخدمة ممتازة وسريعة.",
    "تواصل رائع واحترام للمواعيد.",
    "السعر مناسب مقابل الجودة.",
    "تأخير في التسليم.",
    "التواصل كان ضعيفًا.",
    "تجربة رائعة وأنصح بها.",
    "الردود كانت بطيئة.",
    "جودة العمل عالية.",
  ];

  int? _selectedSuggestion;
  double _rating = 0;
  bool _isSubmitting = false;
  late final AnimationController _emojiAnim;

  @override
  void initState() {
    super.initState();
    _emojiAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220),
      lowerBound: .85, upperBound: 1.12,
    );
    _controller.addListener(() {
      if (_selectedSuggestion != null &&
          _controller.text.trim() != _suggestions[_selectedSuggestion!]) {
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

  void _onRatingChanged(int v) {
    setState(() => _rating = v.toDouble());
    _emojiAnim.forward(from: .9);
  }

  // ---------- إرسال ----------
  Future<void> _submit() async {
    final stars = _rating.toInt();
    String text  = _controller.text.trim();

    if (stars == 0) {
      HelperUtils.showSnackBarMessage(context, "اختر عدد النجوم");
      return;
    }
    if (text.isEmpty) text = "تم إرسال تقييم من التطبيق";


    final int? itemId   = widget.itemId;


    if (itemId == null) {
      HelperUtils.showSnackBarMessage(context, "تعذّر تحديد الخدمة.");
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final ok = await ServiceRatingsApi.addRating(
        itemId: itemId,
        stars: stars,
        comment: text,
        serviceUid: widget.serviceUid,

      );



      if (!mounted) return;


      if (ok) {
        HelperUtils.showSnackBarMessage(context, "تم ارسال تقييمك بنجاح");
        Navigator.of(context).pop(true); // لتحديث القائمة
      } else {
        HelperUtils.showSnackBarMessage(context, "تعذر إرسال التقييم");


      }


    } catch (e, stack) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('addRating failed: $e\n$stack');
      }
      if (mounted) {
        final message = e.toString().trim();
        HelperUtils.showSnackBarMessage(
          context,
          message.isNotEmpty ? message : "تعذر إرسال التقييم",
        );
      }


    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------- الواجهة (كما هي) ----------
  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final insets = MediaQuery.of(context).viewInsets;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.65,
          maxChildSize: 0.98,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return CustomScrollView(
              controller: scrollCtrl,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black26,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.send_rounded, size: 20),
                            SizedBox(width: 8),
                            Text("ارسل تقييمك", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "دقة تقييمكم مهمة — قد تفيد الآخرين أو تضرهم. فضلاً قدّم رأيًا صادقًا يعكس تجربتك الحقيقية.",
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("كم نجمة يستحق؟", style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 6),

                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final i = index + 1;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: GestureDetector(
                                    onTap: () => _onRatingChanged(i),
                                    child: AnimatedScale(
                                      duration: const Duration(milliseconds: 160),
                                      scale: _rating == i ? 1.12 : 1.0,
                                      child: Icon(
                                        _rating >= i ? Icons.star_rounded : Icons.star_border_rounded,
                                        color: Colors.amber,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 40,
                              child: Center(
                                child: _rating > 0
                                    ? ScaleTransition(
                                  scale: _emojiAnim,
                                  child: Text(
                                    "${_emojis[_rating.toInt()-1]}  ${_labels[_rating.toInt()-1]}",
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                )
                                    : const SizedBox(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("اقتراحات جاهزة", style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 8),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Wrap(
                          spacing: 8, runSpacing: 8,
                          children: List.generate(_suggestions.length, (i) {
                            final selected = _selectedSuggestion == i;
                            return ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (selected) ...[
                                    const Icon(Icons.check_circle_rounded, size: 16),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(child: Text(_suggestions[i])),
                                ],
                              ),
                              selected: selected,
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: selected ? Colors.amber : (isDark ? Colors.white12 : Colors.black12)),
                              ),
                              onSelected: (val) {
                                setState(() {
                                  _selectedSuggestion = val ? i : null;
                                  if (val) {
                                    _controller.text = _suggestions[i];
                                    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
                                  }
                                });
                              },
                            );
                          }),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("اكتب رأيك", style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 6),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _controller,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: "اكتب رأيك...",
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity, height: 46,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text("إرسال تقييمك"),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
