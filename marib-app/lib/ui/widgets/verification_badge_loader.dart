import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/app/routes.dart';
import 'package:shimmer/shimmer.dart';

class VerificationBadgeAnimated extends StatelessWidget {
  final bool isLoading;
  final bool showVerificationButton;
  final bool isVerified;
  final String? status;
  final DateTime? expiresAt;
  final VoidCallback onVerifyTap;
  final VoidCallback onStatusTap;

  const VerificationBadgeAnimated({
    super.key,
    required this.isLoading,
    required this.showVerificationButton,
    required this.isVerified,
    required this.status,
    required this.expiresAt,
    required this.onVerifyTap,
    required this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axis: Axis.horizontal,
          child: child,
        ),
      ),
      child: isLoading
          ? const _VerificationBadgePlaceholder()
          : _buildResolvedBadge(context),
    );
  }

  Widget _buildResolvedBadge(BuildContext context) {
    if (showVerificationButton) {
      return VerifyAccountChip(
        key: const ValueKey('verify-account'),
        onTap: onVerifyTap,
      );
    }

    if (isVerified ||
        status == 'pending' ||
        status == 'resubmitted' ||
        status == 'rejected' ||
        status == 'approved') {
      return buildVerificationStatusBadge(
        key: ValueKey('status-$status'),
        context: context,
        isVerified: isVerified,
        status: status,
        expiresAt: expiresAt,
        onTap: onStatusTap,
      );
    }

    return const SizedBox.shrink();
  }
}

class _VerificationBadgePlaceholder extends StatelessWidget {
  const _VerificationBadgePlaceholder();

  @override
  Widget build(BuildContext context) {
    final Color base = context.color.textDefaultColor.withOpacity(0.14);
    final Color highlight = context.color.textDefaultColor.withOpacity(0.08);
    final double height = 34.rh(context);
    final double width = 120.rw(context);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        key: const ValueKey('verification-placeholder'),
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}

class VerifyAccountChip extends StatelessWidget {
  final VoidCallback onTap;

  const VerifyAccountChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: context.color.territoryColor, width: 1.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor:
            context.color.territoryColor.withOpacity(isDark ? 0.12 : 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined,
              size: 18, color: context.color.territoryColor),
          const SizedBox(width: 6),
          Text(
            'verifyAccountCta'.translate(context),
            style: TextStyle(
              color: context.color.territoryColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

Widget buildVerificationStatusBadge({
  Key? key,
  required BuildContext context,
  required bool isVerified,
  required String? status,
  required DateTime? expiresAt,
  required VoidCallback onTap,
}) {
  final normalized = (status ?? "").trim().toLowerCase();
  final bool expired = expiresAt != null && expiresAt.isBefore(DateTime.now());

  if (isVerified && !expired) {
    return VerifiedBadge(
      key: key,
      label: 'verifiedLbl'.translate(context),
      color: Colors.green,
      onTap: onTap,
    );
  }

  if (normalized == "approved" && !expired) {
    return VerifiedBadge(
      key: key,
      label: 'verifiedLbl'.translate(context),
      color: Colors.green,
      onTap: onTap,
    );
  }

  if (normalized == "pending" || normalized == "resubmitted") {
    return VerifiedBadge(
      key: key,
      label: 'underReview'.translate(context),
      color: Colors.amber,
      onTap: onTap,
    );
  }

  if (normalized == "rejected") {
    return VerifiedBadge(
      key: key,
      label: 'rejected'.translate(context),
      color: Colors.red,
      onTap: onTap,
    );
  }

  return VerifyAccountChip(
    key: key,
    onTap: () => Navigator.of(context).pushNamed(Routes.accountVerificationInfo),
  );
}

class VerifiedBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final String? label;
  final Color? color;

  const VerifiedBadge({super.key, this.onTap, this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final Color accent = color ?? context.color.territoryColor;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            (label ?? "verifiedLbl".translate(context)),
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return badge;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: badge,
    );
  }
}
