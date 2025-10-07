import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // استيراد أيقونة واتساب
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart'; // للتعامل مع روابط الواتساب

// IMPORTS لثيمك وهيلبرزكم (عدّل المسارات لو اختلفت عندك)
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart'; // UiUtils.buildAppBar

class TemporarySectionScreen extends StatefulWidget {
  final String catName;
  final String catID;
  final String? interfaceType; // مثل: 'computer_section'
  final List<String>? categoryIds;

  const TemporarySectionScreen({
    Key? key,
    required this.catName,
    required this.catID,
    this.interfaceType,
    this.categoryIds,
  }) : super(key: key);

  @override
  State<TemporarySectionScreen> createState() => _TemporarySectionScreenState();
}

class _TemporarySectionScreenState extends State<TemporarySectionScreen> {
  bool _loadingBackdrop = true;

  static const _imagesTimeout = Duration(seconds: 8);

  // نصوص الطبقة العلوية
  late final _FrontTexts _frontTexts;

  @override
  void initState() {
    super.initState();
    _frontTexts = _pickFrontTexts(
      interfaceType: widget.interfaceType,
      catId: widget.catID,
      catName: widget.catName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,  // تمرير context
        title: widget.catName,  // تمرير title
      ),
      body: Stack(
        children: [
          // طبقة تأثيرات متحركة خلف البلور
          Positioned.fill(
            child: _AnimatedBackdrop(
              isDark: isDark,
            ),
          ),

          // ضباب قوي + طبقة تعتيم خفيفة لتفكيك التفاصيل تمامًا
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.surface.withOpacity(isDark ? 0.40 : 0.50),
                        cs.surface.withOpacity(isDark ? 0.55 : 0.65),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // الطبقة العلوية: النصوص + زر عودة + زر انضمام للتجار + أيقونة واتساب
          Positioned.fill(
            child: _FrontComingSoon(
              title: _frontTexts.title,
              subtitle: _frontTexts.subtitle,
            ),
          ),
        ],
      ),
    );
  }

  _FrontTexts _pickFrontTexts({
    required String? interfaceType,
    required String catId,
    required String catName,
  }) {
    if (interfaceType == 'computer_section' || catId == '5') {
      return _FrontTexts(
        title: 'قسم الكمبيوتر قادم 💻',
        subtitle: 'قريبًا: جميع أنواع أجهزة الكمبيوتر الحديثة مع ملحقاتها.\nطلبات خاصة حسب احتياجاتك، نصلها لباب منزلك.',
      );
    }
    if (catId == '4') {
      return _FrontTexts(
        title: 'انضموا لمتجرنا المحلي!\nللتجار فقط',
        subtitle: 'افتح متجرًا خاصًا بك، وأضف منتجاتك، وادير عمليات البيع بسهولة.\nفريقنا سيقوم بتوصيل الطلبات مباشرة للعميل.',
      );
    }
    return _FrontTexts(
      title: '$catName — قريبًا ✨',
      subtitle: 'متجر إكسسوارات: ساعات، سماعات، كفرات… ترقّب واجهة احترافية.',
    );
  }
}

// مكونات النصوص والزر
class _FrontComingSoon extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FrontComingSoon({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.color.territoryColor; // لون الهوية
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // لمسة هوية صغيرة تحت العنوان (شريط براند)
              Container(
                width: 64,
                height: 6,
                decoration: BoxDecoration(
                  color: brand,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),

              // زر "انضمام للتجار"
              SizedBox(
                width: 240,
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: brand, // ✅ هوية
                    foregroundColor: Colors.white, // تباين جيد
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    // هنا يمكننا ربط الزر لاحقًا
                  },
                  icon: const Icon(Icons.store),
                  label: const Text('انضم إلى المتجر'),
                ),
              ),
              const SizedBox(height: 16),

              // أيقونة واتساب مع نص
              InkWell(
                onTap: () {
                  launch("https://wa.me/697783714389");
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FontAwesomeIcons.whatsapp, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'للاستفسار، تواصل معنا عبر الواتساب',
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// تعريف الكلاس الذي يحمل النصوص المخصصة لكل قسم
class _FrontTexts {
  final String title;
  final String subtitle;

  _FrontTexts({required this.title, required this.subtitle});
}

// خلفية الأنميشن
class _AnimatedBackdrop extends StatelessWidget {
  final bool isDark;

  const _AnimatedBackdrop({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(seconds: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.2),
            cs.secondary.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
