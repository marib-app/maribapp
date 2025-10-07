import 'dart:ui' as ui;
import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:marib/data/model/social_link_model.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

/// واجهة شاشة المعلومات/حول - مفصولة بالكامل عن المنطق.
class InfoScreenUI extends StatelessWidget {
  const InfoScreenUI({
    super.key,
    required this.onGuideTap,
    required this.onFaqsTap,
    required this.onShareTap,
    required this.onContactUsTap,
    required this.onAboutUsTap,
    required this.onTermsTap,
    required this.onPrivacyTap,
    required this.socialLinks,
  });

  final VoidCallback onGuideTap;
  final VoidCallback onFaqsTap;
  final VoidCallback onShareTap;
  final VoidCallback onContactUsTap;
  final VoidCallback onAboutUsTap;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  final List<SocialLink> socialLinks;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.primaryColor,
        appBar: UiUtils.buildAppBar(
          context,
          title: "aboutUs".translate(context),
          bottomHeight: 12,
          showBackButton: true,
        ),
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            // نحافظ على العناصر في أعلى الصفحة
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // الأزرار (صغيرة + فاصلة 10px بين كل زر)
                _CustomTile(
                    title: "دليل الاستخدام".translate(context),
                    svgImagePath: AppIcons.guide,
                    onTap: onGuideTap),
                const SizedBox(height: 8),
                _CustomTile(
                    title: "faqsLbl".translate(context),
                    svgImagePath: AppIcons.faqsIcon,
                    onTap: onFaqsTap),
                const SizedBox(height: 8),
                _CustomTile(
                    title: "shareApp".translate(context),
                    svgImagePath: AppIcons.shareApp,
                    onTap: onShareTap),
                const SizedBox(height: 8),
                _CustomTile(
                    title: "contactUs".translate(context),
                    svgImagePath: AppIcons.contactUs,
                    onTap: onContactUsTap),
                const SizedBox(height: 8),
                _CustomTile(
                    title: "aboutUs".translate(context),
                    svgImagePath: AppIcons.aboutUs,
                    onTap: onAboutUsTap),
                const SizedBox(height: 8),
                _CustomTile(
                    title: "termsConditions".translate(context),
                    svgImagePath: AppIcons.terms,
                    onTap: onTermsTap),
                const SizedBox(height: 8),
                _CustomTile(
                    title: "privacyPolicy".translate(context),
                    svgImagePath: AppIcons.privacy,
                    onTap: onPrivacyTap),

                if (socialLinks.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  _SocialLinksSection(links: socialLinks),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================= Tiles صغيرة مع شريط جانبي متدرج =========================

class _CustomTile extends StatelessWidget {
  const _CustomTile({
    required this.title,
    required this.svgImagePath,
    required this.onTap,
  });

  final String title;
  final String svgImagePath;
  final VoidCallback onTap;

  final bool? isSwitchBox;
  final bool? switchValue;
  final ValueChanged<bool>? onTapSwitch;

  @override
  Widget build(BuildContext context) {
    final accent = context.color.territoryColor;

    // شريط أهدأ من لون الهوية (نفس الهيو، تشبّع أقل + إضاءة أعلى قليلًا)
    final hsl = HSLColor.fromColor(accent);
    final barBase = hsl
        .withSaturation((hsl.saturation * 0.45).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 1.05).clamp(0.0, 1.0))
        .toColor();

    final bool withSwitch = isSwitchBox == true;

    return _Pressable(
      onTap: withSwitch ? null : onTap, // لو فيه سويتش: الضغط عبر السويتش فقط
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // أصغر قليلاً
        child: Container(
          // ارتفاع نهائي ~56px
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: context.color.textDefaultColor.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // الشريط الجانبي جزء من الزر (أنحف + أهدأ حتى لا يغطي الأيقونة)

          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                barBase.withOpacity(0.25), // كان 0.40 → أهدأ
                barBase.withOpacity(0.12), // كان 0.18
                Colors.transparent,
              ],
              stops: const [0.0, 0.10, 0.20], // شريط أنحف يناسب المقاس الصغير
            ),
          ),
          child: Row(
            textDirection: TextDirection.ltr, // الأيقونة يمين دائماً
            children: [
              // يسار: سهم أو سويتش (صغير)
              if (!withSwitch)
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: Directionality.of(context) == ui.TextDirection.rtl
                        ? 3.14159
                        : 0,
                    child: UiUtils.getSvg(
                      AppIcons.arrowRight,
                      color: context.color.textColorDark,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 26,
                  width: 42,
                  child: CupertinoSwitch(
                    activeTrackColor: accent,
                    value: switchValue ?? false,
                    onChanged: (v) => onTapSwitch?.call(v),
                  ),
                ),

              const SizedBox(width: 10),

              // العنوان في الوسط
              Expanded(
                child: Text(title, textAlign: TextAlign.center)
                    .bold(weight: FontWeight.w700)
                    .color(context.color.textColorDark),
              ),

              const SizedBox(width: 10),

              // يمين: كبسولة الأيقونة (مصغّرة)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: context.color.textDefaultColor.withOpacity(0.06)),
                ),
                alignment: Alignment.center,
                child: UiUtils.getSvg(
                  svgImagePath,
                  height: 18,
                  width: 18,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================= أيقونات تواصل مصغّرة وواضحة =========================

class _SocialLinksSection extends StatelessWidget {
  const _SocialLinksSection({required this.links});

  final List<SocialLink> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Wrap(
          spacing: 12,
          runSpacing: 18,
          alignment: WrapAlignment.center,
          children: links
              .map((link) => _SocialLinkButton(link: link))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _SocialLinkButton extends StatelessWidget {
  const _SocialLinkButton({required this.link});

  final SocialLink link;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.color.territoryColor;
    final TextStyle labelStyle =
        (Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 12))
            .copyWith(
      fontSize: 11,
      height: 1.2,
      color: context.color.textDefaultColor.withOpacity(0.85),
    );

    final Widget icon = _buildIcon(accent);

    return SizedBox(
      width: 92,
      child: Tooltip(
        message: link.label,
        waitDuration: const Duration(milliseconds: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Pressable(
              onTap: () => _handleTap(context),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.color.textDefaultColor.withOpacity(0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(child: icon),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              link.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(Color accent) {
    final IconData? iconData = _resolveFontAwesomeIcon(link);
    if (iconData != null) {
      return FaIcon(
        iconData,
        size: 22,
        color: accent,
      );
    }

    final String? asset = _resolveAssetForLink(link);
    if (asset != null) {
      return UiUtils.getSvg(
        asset,
        width: 22,
        height: 22,
        color: accent,
      );
    }

    return Icon(
      Icons.link_rounded,
      size: 22,
      color: accent,
    );
  }

  void _handleTap(BuildContext context) {
    unawaited(_launchLink(context, link));
  }
}

Future<void> _launchLink(BuildContext context, SocialLink link) async {
  final Uri? uri = _normalizeLinkUri(link.url);
  if (uri == null) {
    _showLaunchError(context);
    return;
  }

  try {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      _showLaunchError(context);
    }
  } catch (_) {
    _showLaunchError(context);
  }
}

void _showLaunchError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('somethingWentWrong'.translate(context)),
    ),
  );
}

Uri? _normalizeLinkUri(String url) {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  Uri? uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return null;
  }

  if (!uri.hasScheme) {
    uri = Uri.tryParse('https://$trimmed');
  }

  return uri;
}

IconData? _resolveFontAwesomeIcon(SocialLink link) {
  final List<String> candidates = _collectKeywordCandidates(link);
  for (final String candidate in candidates) {
    final IconData? icon = _fontAwesomeIconMap[candidate];
    if (icon != null) {
      return icon;
    }
  }
  return null;
}

String? _resolveAssetForLink(SocialLink link) {
  final List<String> candidates = _collectKeywordCandidates(link);
  for (final String candidate in candidates) {
    if (candidate.contains('whatsapp')) {
      return AppIcons.whatsapp;
    }
    if (candidate.contains('instagram')) {
      return AppIcons.Instagram;
    }
    if (candidate.contains('facebook')) {
      return AppIcons.facebook;
    }
  }
  return null;
}

List<String> _collectKeywordCandidates(SocialLink link) {
  final List<String> results = <String>[];
  final Set<String> seen = <String>{};

  void addCandidate(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || seen.contains(normalized)) {
      return;
    }
    seen.add(normalized);
    results.add(normalized);
  }

  void addTokenWithVariants(String token) {
    final String normalized = token.trim().toLowerCase();
    if (normalized.isEmpty || _ignoredCssTokens.contains(normalized)) {
      return;
    }

    addCandidate(normalized);

    final String stripped = normalized.replaceFirst(
      RegExp(
        r'^(fa|fab|fas|far|fal|fat|fad|fa-brands|fa-solid|fa-regular|fa-light|fa-duotone|fa-sharp|fa-thin)-',
      ),
      '',
    );
    if (stripped.isNotEmpty && stripped != normalized) {
      addCandidate(stripped);
    }

    if (!normalized.startsWith('fa-')) {
      addCandidate('fa-$normalized');
    }
  }

  if (link.iconClass != null && link.iconClass!.trim().isNotEmpty) {
    final Iterable<String> tokens = link.iconClass!
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    for (final String token in tokens) {
      addTokenWithVariants(token);
    }
  }

  final String label = link.label;
  if (label.trim().isNotEmpty) {
    for (final String part in label
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((segment) => segment.isNotEmpty)) {
      addTokenWithVariants(part);
    }
  }

  final Uri? uri = Uri.tryParse(link.url.trim());
  if (uri != null) {
    final String host = uri.host;
    if (host.isNotEmpty) {
      for (final String segment in host.split('.')) {
        final String trimmed = segment.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        if (_ignoredHostSegments.contains(trimmed.toLowerCase())) {
          continue;
        }
        addTokenWithVariants(trimmed);
      }
    }

    for (final String segment in uri.pathSegments) {
      if (segment.trim().isEmpty) {
        continue;
      }
      addTokenWithVariants(segment);
    }
  }

  return results;
}

const Set<String> _ignoredCssTokens = <String>{
  'fa',
  'fab',
  'fas',
  'far',
  'fal',
  'fat',
  'fad',
  'fa-brands',
  'fa-solid',
  'fa-regular',
  'fa-light',
  'fa-duotone',
  'fa-thin',
  'fa-sharp',
};

const Set<String> _ignoredHostSegments = <String>{
  'www',
  'com',
  'net',
  'org',
  'co',
  'io',
  'app',
};

const Map<String, IconData> _fontAwesomeIconMap = <String, IconData>{
  'fa-facebook': FontAwesomeIcons.facebook,
  'facebook': FontAwesomeIcons.facebook,
  'fa-facebook-f': FontAwesomeIcons.facebookF,
  'facebook-f': FontAwesomeIcons.facebookF,
  'fa-square-facebook': FontAwesomeIcons.squareFacebook,
  'square-facebook': FontAwesomeIcons.squareFacebook,
  'fa-instagram': FontAwesomeIcons.instagram,
  'instagram': FontAwesomeIcons.instagram,
  'fa-whatsapp': FontAwesomeIcons.whatsapp,
  'whatsapp': FontAwesomeIcons.whatsapp,
  'fa-square-whatsapp': FontAwesomeIcons.squareWhatsapp,
  'square-whatsapp': FontAwesomeIcons.squareWhatsapp,
  'fa-telegram': FontAwesomeIcons.telegram,
  'telegram': FontAwesomeIcons.telegram,
  'fa-twitter': FontAwesomeIcons.twitter,
  'twitter': FontAwesomeIcons.twitter,
  'fa-x-twitter': FontAwesomeIcons.xTwitter,
  'x-twitter': FontAwesomeIcons.xTwitter,
  'fa-youtube': FontAwesomeIcons.youtube,
  'youtube': FontAwesomeIcons.youtube,
  'fa-youtube-play': FontAwesomeIcons.youtube,
  'fa-linkedin': FontAwesomeIcons.linkedin,
  'linkedin': FontAwesomeIcons.linkedin,
  'fa-linkedin-in': FontAwesomeIcons.linkedinIn,
  'linkedin-in': FontAwesomeIcons.linkedinIn,
  'fa-tiktok': FontAwesomeIcons.tiktok,
  'tiktok': FontAwesomeIcons.tiktok,
  'fa-snapchat': FontAwesomeIcons.snapchat,
  'snapchat': FontAwesomeIcons.snapchat,
  'fa-snapchat-ghost': FontAwesomeIcons.snapchatGhost,
  'fa-pinterest': FontAwesomeIcons.pinterest,
  'pinterest': FontAwesomeIcons.pinterest,
  'fa-pinterest-p': FontAwesomeIcons.pinterestP,
  'pinterest-p': FontAwesomeIcons.pinterestP,
  'fa-github': FontAwesomeIcons.github,
  'github': FontAwesomeIcons.github,
  'fa-behance': FontAwesomeIcons.behance,
  'behance': FontAwesomeIcons.behance,
  'fa-dribbble': FontAwesomeIcons.dribbble,
  'dribbble': FontAwesomeIcons.dribbble,
  'fa-reddit': FontAwesomeIcons.reddit,
  'reddit': FontAwesomeIcons.reddit,
  'fa-discord': FontAwesomeIcons.discord,
  'discord': FontAwesomeIcons.discord,
  'fa-medium': FontAwesomeIcons.medium,
  'medium': FontAwesomeIcons.medium,
  'fa-spotify': FontAwesomeIcons.spotify,
  'spotify': FontAwesomeIcons.spotify,
  'fa-soundcloud': FontAwesomeIcons.soundcloud,
  'soundcloud': FontAwesomeIcons.soundcloud,
  'fa-twitch': FontAwesomeIcons.twitch,
  'twitch': FontAwesomeIcons.twitch,
  'fa-vimeo': FontAwesomeIcons.vimeo,
  'vimeo': FontAwesomeIcons.vimeo,
  'fa-globe': FontAwesomeIcons.globe,
  'globe': FontAwesomeIcons.globe,
  'fa-globe-europe': FontAwesomeIcons.globeEurope,
  'globe-europe': FontAwesomeIcons.globeEurope,
  'fa-phone': FontAwesomeIcons.phone,
  'phone': FontAwesomeIcons.phone,
  'fa-phone-alt': FontAwesomeIcons.phone,
  'phone-alt': FontAwesomeIcons.phone,
  'fa-envelope': FontAwesomeIcons.envelope,
  'envelope': FontAwesomeIcons.envelope,
  'fa-envelope-open': FontAwesomeIcons.envelopeOpen,
  'mail': FontAwesomeIcons.envelope,
  'email': FontAwesomeIcons.envelope,
  'fa-location-dot': FontAwesomeIcons.locationDot,
  'location-dot': FontAwesomeIcons.locationDot,
  'fa-map-marker': FontAwesomeIcons.locationDot,
  'map-marker': FontAwesomeIcons.locationDot,
  'fa-map-marker-alt': FontAwesomeIcons.locationDot,
  'map-marker-alt': FontAwesomeIcons.locationDot,
  'fa-link': FontAwesomeIcons.link,
  'link': FontAwesomeIcons.link,
};

// ========= تأثير ضغط بسيط (Scale) — ضعه هنا إن لم يكن مستورداً =========
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  const _Pressable({Key? key, required this.child, this.onTap})
      : super(key: key);

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          scale: _down ? widget.scaleDown : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}
