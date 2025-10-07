import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/data/cubits/competition_cubit.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:marib/data/repositories/competition_repository.dart';
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/material.dart';
import 'dart:ui';



class CompetitionShareInfoScreen extends StatelessWidget {
  const CompetitionShareInfoScreen({super.key});

  static Route route() {
    return MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => CompetitionCubit(CompetitionRepository())..fetchCompetitionData(),
        child: const CompetitionShareInfoScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: Theme.of(context).primaryColor,
      ),
      child: Scaffold(
      //  backgroundColor: context.red ? Colors.black : Colors.white,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "شارك واربح",
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildInviteSection(context),
        ),
      ),
    );
  }

  Widget _buildInviteSection(BuildContext context) {
    final state = context.watch<CompetitionCubit>().state;
    String referralCode = '';
    String inviteMessage = '';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.emoji_events, size: 80),
        const SizedBox(height: 16),
        const Text(
          "🎯 شارك كودك الآن!",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          "كل إحالة ناجحة تمنحك نقاط تقرّبك من التحديات والجوائز! شارك الكود عبر واتساب أو أي وسيلة تواصل.",
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // ✅ كود الإحالة
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.color.forthColor, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("رمز الإحالة", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    hasCode ? referralCode : '—',
                      style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                        color:
                        hasCode ? context.color.forthColor : Colors.grey.shade500,
                    ),
                  ),
                  if (!hasCode)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        unavailableLabel,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
              IconButton(
                onPressed: hasCode
                    ? () {
                  Clipboard.setData(ClipboardData(text: referralCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("تم نسخ رمز الإحالة بنجاح"),
                      backgroundColor: context.color.forthColor,
                    ),
                  );
                }
                    : null,
                icon: Icon(
                  Icons.copy,
                  color: hasCode ? context.color.forthColor : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        // ✅ QR Code
        if (hasCode)
          Container(
            height: 120,
            width: 120,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.color.forthColor.withOpacity(0.3)),
            ),
            child: QrImageView(
              data: referralCode,
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
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'سيظهر رمز QR عند توفر كود الإحالة',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),


        const SizedBox(height: 15),

        // ✅ زر المشاركة
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.color.forthColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: canShare
                ? () {
              Clipboard.setData(ClipboardData(text: shareMessage));

              UiUtils.showSoftSnackBar(
                context,
                message: "تم نسخ كود الإحالة للمشاركة",
                iconPath: 'assets/image/showSoftSnackBar.png',
              );
            }
                : null,

            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text("مشاركة الكود", style: TextStyle(color: Colors.white)),
          ),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            label: const Text("رجوع", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.color.forthColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }
}
