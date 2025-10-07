import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/extensions/extensions.dart'; // من أجل translate
import 'package:marib/data/cubits/competition_cubit.dart'; // تأكد من المسار الصحيح
import 'package:share_plus/share_plus.dart';

class InviteFriendsScreen extends StatelessWidget {
  final String referralUrl = "https://app.com/ref/7C711MZBFF";
  final String referralCode = "7C711MZBFF";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final primaryColor = theme.primaryColor;
    final divider = theme.dividerColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("دعوة الأصدقاء"),
        centerTitle: true,
        leading: BackButton(color: textColor),
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            buildReferralCard(context, referralCode, referralUrl),
            const SizedBox(height: 32),
            buildHowItWorksSection(context),
            const SizedBox(height: 32),
            _buildInviteSection(),
          ],
        ),
      ),
    );
  }

  Widget buildReferralCard(BuildContext context, String code, String url) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final primaryColor = theme.primaryColor;
    final cardColor = theme.cardColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text("الرمز الشخصي الخاص بك",
            style: theme.textTheme.bodySmall
                ?.copyWith(color: textColor.withOpacity(0.6))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: primaryColor, width: 1.5),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم نسخ الكود")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: const StadiumBorder(),
                ),
                child:
                    const Text("ينسخ", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Text(code,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 80,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "قم بدعوة الأصدقاء عبر رمز الاستجابة السريعة",
                  style: TextStyle(fontSize: 14, color: textColor),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IconButton(
          icon: Icon(Icons.share, size: 28, color: primaryColor),
          onPressed: () {
            // TODO: مشاركة الكود
          },
        )
      ],
    );
  }

  Widget buildHowItWorksSection(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final cardColor = theme.cardColor;
    final divider = theme.dividerColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Center(
            child: Text(
              "كيف تعمل",
              style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    "• شارك كود الإحالة الخاص بك مع أصدقائك على منصات التواصل.",
                    style: TextStyle(color: textColor),
                    textAlign: TextAlign.right),
                const SizedBox(height: 8),
                Text("• عند تسجيل صديقك، يبدأ بجمع النقاط تلقائيًا.",
                    style: TextStyle(color: textColor),
                    textAlign: TextAlign.right),
                const SizedBox(height: 8),
                Text(
                    "• ستحصل على نقاط مضاعفة بمجرد أن يستخدم صديقك التطبيق في الشهر الأول.",
                    style: TextStyle(color: textColor),
                    textAlign: TextAlign.right),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _shareInviteMessage(String message, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      message,
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );
  }

  Widget _buildInviteSection() {
    return BlocBuilder<CompetitionCubit, CompetitionState>(
      builder: (context, state) {
        String referralCode = "LOADING...";
        String inviteMessage = "loading".translate(context);

        if (state is CompetitionSuccess) {
          referralCode = state.referralPoints.referralCode.trim();
          final friendMessage =
              state.referralPoints.inviteFriendMessage.trim().isNotEmpty
                  ? state.referralPoints.inviteFriendMessage
                  : state.referralPoints.qrCodeData;
          inviteMessage = friendMessage.trim().isNotEmpty
              ? friendMessage
              : state.referralPoints.qrCodeData;
        }
        final bool hasCode = referralCode.isNotEmpty;
        final unavailableLabelRaw =
            "referralCodeUnavailable".translate(context);
        final String unavailableLabel =
            unavailableLabelRaw == "referralCodeUnavailable"
                ? 'Referral code is currently unavailable'
                : unavailableLabelRaw;
        final String shareMessage = inviteMessage.trim();
        final bool canShare = shareMessage.isNotEmpty;
        return Container(
          padding: EdgeInsets.all(16.0),
          width: 370,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                "inviteFriendsEarnPoints".translate(context),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 15),

              // عرض كود الإحالة
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Theme.of(context).primaryColor, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "yourReferralCode".translate(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          hasCode ? referralCode : '—',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: hasCode
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade500,
                          ),
                        ),
                        if (!hasCode)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              unavailableLabel,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      onPressed: hasCode
                          ? () {
                              Clipboard.setData(
                                  ClipboardData(text: referralCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text("messageCopied".translate(context)),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                ),
                              );
                            }
                          : null,
                      icon: Icon(
                        Icons.copy,
                        color: hasCode
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 15),

              if (hasCode)
                Container(
                  height: 120,
                  width: 120,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3)),
                  ),
                  child: QrImageView(
                    data: shareMessage,
                    version: QrVersions.auto,
                    size: 104.0,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                )
              else
                Container(
                  height: 120,
                  width: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3)),
                  ),
                  child: Icon(Icons.qr_code, size: 40, color: Colors.grey),
                ),

              SizedBox(height: 15),

              // أزرار المشاركة
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: canShare
                          ? () {
                              if (state is CompetitionSuccess) {
                                _shareInviteMessage(shareMessage, context);
                              }
                            }
                          : null,
                      icon: Icon(Icons.share, color: Colors.white, size: 18),
                      label: Text(
                        "share".translate(context),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
