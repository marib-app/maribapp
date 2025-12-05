import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:marib/data/model/social_link_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:url_launcher/url_launcher.dart';

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
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _CustomTile(
                  title: "guide".translate(context),
                  svgImagePath: AppIcons.guide,
                  onTap: onGuideTap,
                ),
                const SizedBox(height: 8),
                _CustomTile(
                  title: "faqsLbl".translate(context),
                  svgImagePath: AppIcons.faqsIcon,
                  onTap: onFaqsTap,
                ),
                const SizedBox(height: 8),
                _CustomTile(
                  title: "shareApp".translate(context),
                  svgImagePath: AppIcons.shareApp,
                  onTap: onShareTap,
                ),
                const SizedBox(height: 8),
                _CustomTile(
                  title: "contactUs".translate(context),
                  svgImagePath: AppIcons.contactUs,
                  onTap: onContactUsTap,
                ),
                const SizedBox(height: 8),
                _CustomTile(
                  title: "aboutUs".translate(context),
                  svgImagePath: AppIcons.aboutUs,
                  onTap: onAboutUsTap,
                ),
                const SizedBox(height: 8),
                _CustomTile(
                  title: "termsConditions".translate(context),
                  svgImagePath: AppIcons.terms,
                  onTap: onTermsTap,
                ),
                const SizedBox(height: 8),
                _CustomTile(
                  title: "privacyPolicy".translate(context),
                  svgImagePath: AppIcons.privacy,
                  onTap: onPrivacyTap,
                ),
                if (socialLinks.isNotEmpty) ...[
                  const SizedBox(height: 24),
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

class _CustomTile extends StatelessWidget {
  const _CustomTile({
    required this.title,
    required this.svgImagePath,
    required this.onTap,
    this.isSwitchBox,
    this.switchValue,
    this.onTapSwitch,
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

    final hsl = HSLColor.fromColor(accent);
    final barBase = hsl
        .withSaturation((hsl.saturation * 0.45).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 1.05).clamp(0.0, 1.0))
        .toColor();

    final bool withSwitch = isSwitchBox == true;

    return _Pressable(
      onTap: withSwitch ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.color.textDefaultColor.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                barBase.withOpacity(0.25),
                barBase.withOpacity(0.12),
                Colors.transparent,
              ],
              stops: const [0.0, 0.10, 0.20],
            ),
          ),
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
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
                    activeColor: accent,
                    value: switchValue ?? false,
                    onChanged: (v) => onTapSwitch?.call(v),
                  ),
                ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(title, textAlign: TextAlign.center)
                    .bold(weight: FontWeight.w700)
                    .color(context.color.textColorDark),
              ),

              const SizedBox(width: 10),

              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.color.textDefaultColor.withOpacity(0.06),
                  ),
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

class _SocialLinksSection extends StatelessWidget {
  const _SocialLinksSection({required this.links});

  final List<SocialLink> links;

  @override
  Widget build(BuildContext context) {
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
    final TextStyle labelStyle = (Theme.of(context).textTheme.bodySmall ??
        const TextStyle(fontSize: 12))
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
              onTap: () => _launchLink(context, link),
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
    final IconData? iconData = _resolveIconData(link);
    if (iconData != null) {
      return FaIcon(iconData, size: 22, color: accent);
    }
    return Icon(Icons.link_rounded, size: 22, color: accent);
  }
}

Future<void> _launchLink(BuildContext context, SocialLink link) async {
  final Uri? uri = _normalizeLinkUri(link.url);
  if (uri == null) {
    _showLaunchError(context);
    return;
  }

  try {
    final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
  if (trimmed.isEmpty) return null;

  Uri? uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (!uri.hasScheme) {
    uri = Uri.tryParse('https://$trimmed');
  }
  return uri;
}

IconData? _resolveIconData(SocialLink link) {
  final String corpus = [
    link.iconClass ?? '',
    link.label,
    link.url,
  ].join(' ').toLowerCase();

  IconData? match(String keyword, IconData icon) =>
      corpus.contains(keyword) ? icon : null;

  return match('whatsapp', FontAwesomeIcons.whatsapp) ??
      match('telegram', FontAwesomeIcons.telegram) ??
      match('instagram', FontAwesomeIcons.instagram) ??
      match('facebook', FontAwesomeIcons.facebook) ??
      match('snapchat', FontAwesomeIcons.snapchat) ??
      match('tiktok', FontAwesomeIcons.tiktok) ??
      match('youtube', FontAwesomeIcons.youtube) ??
      match('linkedin', FontAwesomeIcons.linkedin) ??
      match('twitter', FontAwesomeIcons.xTwitter) ??
      match('x.com', FontAwesomeIcons.xTwitter) ??
      match('phone', FontAwesomeIcons.phone) ??
      match('email', FontAwesomeIcons.envelope) ??
      match('mail', FontAwesomeIcons.envelope) ??
      match('link', FontAwesomeIcons.link);
}

class _Pressable extends StatefulWidget {
  const _Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

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
