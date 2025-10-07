// competitions_screen_ui.dart
// واجهة المسابقة فقط — المنطق بالكامل في competitions_screen.dart
// تم تقسيم الواجهة إلى كلاسات صغيرة مع تعليقات عربية، مع الحفاظ على نفس الشكل.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show SystemUiOverlayStyle, Clipboard, ClipboardData;
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/app/routes.dart';

import 'package:marib/data/model/challenge_model.dart'; // Challenge
import 'package:marib/ui/screens/competitions/context_extensions.dart'; // context.isDarkMode / context.color
import 'package:marib/ui/screens/competitions/competitions_screen.dart'; // CompetitionState/Logic/Actions

/// واجهة العرض الرئيسية: تربط الحالة + المنطق + الإجراءات بالكلاسات المرئية.
class CompetitionScreenUI extends StatelessWidget {
  final TabController tabController;
  final CompetitionState state;
  final CompetitionLogic logic;
  final CompetitionActions actions;

  const CompetitionScreenUI({
    super.key,
    required this.tabController,
    required this.state,
    required this.logic,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.isDarkMode ? Colors.black : Colors.white,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "competition".translate(context),
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            _Tabs(tabController: tabController),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  _ActivitiesTab(state: state, logic: logic, actions: actions),
                  _PaymentTab(state: state, actions: actions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط التبويبات (أنشطة / دفع)
class _Tabs extends StatelessWidget {
  final TabController tabController;
  const _Tabs({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: tabController,
      tabs: [
        Tab(
          child: Text('activities'.translate(context),
              style: TextStyle(color: context.color.textDefaultColor)),
        ),
        Tab(
          child: Text('payment'.translate(context),
              style: TextStyle(color: context.color.textDefaultColor)),
        ),
      ],
    );
  }
}

/// تبويب الأنشطة — عرض فقط (قراءة من الحالة + استخدام المنطق)
class _ActivitiesTab extends StatelessWidget {
  final CompetitionState state;
  final CompetitionLogic logic;
  final CompetitionActions actions;
  const _ActivitiesTab(
      {required this.state, required this.logic, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (state is CompetitionLoading || state is CompetitionInitial) {
      return _GridShimmer();
    }
    if (state is CompetitionFailure) {
      return const SomethingWentWrong();
    }

    final s = state as CompetitionSuccess;

    // حسابات مشتقة للعرض فقط
    final highest = logic.highestChallenge(s.challenges);
    final nearest =
        logic.nearestUnreached(s.challenges, s.referralPoints.currentPoints);
    final remaining =
        logic.remainingToNearest(s.challenges, s.referralPoints.currentPoints);
    final progress =
        logic.progressToHighest(s.challenges, s.referralPoints.currentPoints);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // كرت العداد (نقاط/شريط/زر/تحذير)
          PointsCard(
            currentPoints: s.referralPoints.currentPoints,
            highestRequired: highest?.requiredPoints ?? 0,
            nearestTitle: nearest?.title,
            remainingToNearest: remaining,
            progressToHighest: progress,
            showWarning: actions.onWarningFlagGetter(),
            onCollectPressed: () {
              final ok = actions.onTryCollect(
                s.referralPoints.currentPoints,
                s.challenges,
              );
              if (!ok) {
                actions.onWarningFlagSetter(true);
                Future.delayed(const Duration(seconds: 3), () {
                  actions.onWarningFlagSetter(false);
                });
              }
            },
            shakeAnimation: actions.onShakeAnimation, // تمرير الدالة كما هي
          ),

          const SizedBox(height: 12),
          // كود الإحالة
          ReferralCodeBox(code: s.referralPoints.referralCode),
          const SizedBox(height: 20),

          // شبكة التحديات (صفوف، كل صف عنصرين)
          _ChallengesGrid(
            challenges: s.challenges,
            currentPoints: s.referralPoints.currentPoints,
            onOpenDetails: (challenge) => _showChallengeDetailsDialog(
              context,
              challenge,
              actions.goToChallengeInstructions,
            ),
          ),
        ],
      ),
    );
  }
}

/// تبويب الدفع — خيارات الدفع + سجل المعاملات (عرض فقط)
class _PaymentTab extends StatelessWidget {
  final CompetitionState state;
  final CompetitionActions actions;
  const _PaymentTab({required this.state, required this.actions});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> tx = (state is CompetitionSuccess)
        ? (state as CompetitionSuccess).paymentTransactions
        : const [];

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("paymentDetails".translate(context),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        // خيارات الدفع (كلاس مستقل)
        PaymentMethodsSection(onSavePaymentInfo: actions.onSavePaymentInfo),

        const SizedBox(height: 20),
        Row(
          children: [
            Text("transactionHistory".translate(context),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (tx.isNotEmpty)
              TextButton.icon(
                onPressed: () => _showAllTransactionsDialog(context, tx),
                icon: const Icon(Icons.list_alt, size: 18),
                label: Text("all".translate(context)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (tx.isEmpty)
          Text("noTransactions".translate(context),
              style: TextStyle(color: Colors.grey[600])),
      ]),
    );
  }
}

//
// ========================== كروت/مكوّنات مستقلة ==========================
//

/// كرت العداد: نقاط/شريط/زر/تحذير — واجهة فقط
class PointsCard extends StatelessWidget {
  final int currentPoints;
  final int highestRequired;
  final String? nearestTitle;
  final int remainingToNearest;
  final double progressToHighest;
  final bool showWarning;
  final VoidCallback onCollectPressed;
  final Animation<double> Function()
      shakeAnimation; // متروك لو أردت استخدامه لاحقًا

  const PointsCard({
    super.key,
    required this.currentPoints,
    required this.highestRequired,
    required this.nearestTitle,
    required this.remainingToNearest,
    required this.progressToHighest,
    required this.showWarning,
    required this.onCollectPressed,
    required this.shakeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final canCollect = (nearestTitle != null && remainingToNearest == 0);
    final progressColor = progressToHighest >= 1.0
        ? Colors.green
        : (progressToHighest >= 0.5 ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // نصوص + أزرار
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$currentPoints/${highestRequired > 0 ? highestRequired : currentPoints} ${'points'.translate(context)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progressToHighest,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation(progressColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  nearestTitle != null
                      ? (remainingToNearest > 0
                          ? "باقي لك $remainingToNearest نقطة للحصول على جائزة التحدي '$nearestTitle' 🎁"
                          : "جاهز لجائزة التحدي '$nearestTitle' 🎁")
                      : "🎉 ${'allChallengesReached'.translate(context)}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: onCollectPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canCollect ? Colors.orange : Colors.grey,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        canCollect ? "اجمع نقاطك الآن" : "اجمع نقاط التحدي",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: showWarning ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        nearestTitle != null && remainingToNearest > 0
                            ? "باقي $remainingToNearest نقطة لتفعيل الزر"
                            : "",
                        style:
                            TextStyle(fontSize: 12, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Image.asset('assets/image/rewards.png',
              width: 110, height: 100, fit: BoxFit.contain),
        ],
      ),
    );
  }
}

/// كرت التحدي المفرد — واجهة فقط
class ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final int currentPoints;
  final VoidCallback onTap;

  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.currentPoints,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = challenge.isActive;
    final bool isEligible = currentPoints >= challenge.requiredPoints;

    final Color badgeColor =
        isActive ? Colors.orange.shade100 : Colors.grey.shade300;
    final Color badgeTextColor =
        isActive ? Colors.deepOrange : Colors.grey.shade700;
    final Color backgroundColor = isEligible
        ? Colors.lightGreen.shade50
        : (isActive ? Colors.amber.shade50 : Colors.grey.shade100);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3))
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🎊", style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              challenge.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor),
            ),
            const SizedBox(height: 6),
            Text(
                "${challenge.requiredPoints} ${'pointsRequired'.translate(context)}",
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: badgeColor, borderRadius: BorderRadius.circular(20)),
              child: Text(isActive ? "🔥 نشط" : "🚫 غير نشط",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeTextColor)),
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (currentPoints / challenge.requiredPoints)
                        .clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation(
                        isEligible ? Colors.green : Colors.orange),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// عنصر عرض: كود الإحالة مع زر نسخ
class ReferralCodeBox extends StatelessWidget {
  final String code;
  const ReferralCodeBox({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final String trimmedCode = code.trim();
    final bool hasCode = trimmedCode.isNotEmpty;
    final unavailableTextRaw = "referralCodeUnavailable".translate(context);
    final unavailableText = unavailableTextRaw == "referralCodeUnavailable"
        ? "Referral code is currently unavailable"
        : unavailableTextRaw;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "yourReferralCode".translate(context),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  hasCode ? trimmedCode : "—",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hasCode
                        ? context.color.forthColor
                        : Colors.grey.shade500,
                  ),
                ),
                if (!hasCode)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      unavailableText,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: hasCode ? "copy".translate(context) : unavailableText,
            onPressed: hasCode
                ? () {
                    Clipboard.setData(ClipboardData(text: trimmedCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("messageCopied".translate(context))),
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
    );
  }
}

/// قسم خيارات الدفع — يفتح نفس الحوارات ويحفظ عبر actions.onSavePaymentInfo
class PaymentMethodsSection extends StatelessWidget {
  final Future<void> Function({
    required List<String> paymentMethods,
    required Map<String, dynamic> paymentAccountDetails,
    String? businessName,
    String? businessWhatsapp,
    String? businessLocation,
    List<String>? businessCategories,
    String? commercialRegister,
    String? email,
  }) onSavePaymentInfo;

  const PaymentMethodsSection({super.key, required this.onSavePaymentInfo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.credit_card, color: Colors.orange),
          title: Text("addCreditCard".translate(context)),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showAddCreditCardDialog(context),
        ),
        ListTile(
          leading:
              const Icon(Icons.account_balance_wallet, color: Colors.orange),
          title: Text("payViaWallet".translate(context)),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showWalletDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.phone_android, color: Colors.orange),
          title: Text("payViaPhone".translate(context)),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showPhoneDialog(context),
        ),
      ],
    );
  }

  // نفس الحوارات السابقة — واجهة فقط، الحفظ عبر onSavePaymentInfo

  void _showAddCreditCardDialog(BuildContext context) {
    final numberController = TextEditingController();
    final mmYYController = TextEditingController();
    final cvvController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => BlurredDialogBox(
        title: "addCreditCard".translate(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: InputDecoration(
                labelText: "cardNumber".translate(context),
                hintText: "1234 5678 9012 3456",
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: mmYYController,
                    decoration: const InputDecoration(
                        labelText: "MM/YY", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: cvvController,
                    decoration: const InputDecoration(
                        labelText: "CVV", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.color.forthColor),
              onPressed: () async {
                await onSavePaymentInfo(
                  paymentMethods: const ['credit_card'],
                  paymentAccountDetails: {
                    'type': 'credit_card',
                    'card_number': 'masked_number', // لا تحفظ بيانات حساسة
                  },
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: Text("save".translate(context),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showWalletDialog(BuildContext context) {
    final walletController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => BlurredDialogBox(
        title: "payViaWallet".translate(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: walletController,
              decoration: InputDecoration(
                labelText: "electronicWalletNumber".translate(context),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.color.forthColor),
              onPressed: () async {
                await onSavePaymentInfo(
                  paymentMethods: const ['wallet'],
                  paymentAccountDetails: {
                    'type': 'wallet',
                    'wallet_number': 'wallet_id',
                  },
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: Text("save".translate(context),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhoneDialog(BuildContext context) {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => BlurredDialogBox(
        title: "payViaPhone".translate(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                  labelText: "phoneNumber".translate(context),
                  border: const OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.color.forthColor),
              onPressed: () async {
                await onSavePaymentInfo(
                  paymentMethods: const ['phone'],
                  paymentAccountDetails: {
                    'type': 'phone',
                    'phone_number': 'phone_id',
                  },
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: Text("save".translate(context),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

//
// ========================== عناصر مساعدة للعرض فقط ==========================
//

/// شبكة صفوف التحديات (كل صف عنصرين) — تستخدم ChallengeCard
class _ChallengesGrid extends StatelessWidget {
  final List<Challenge> challenges;
  final int currentPoints;
  final void Function(Challenge challenge) onOpenDetails;
  const _ChallengesGrid({
    required this.challenges,
    required this.currentPoints,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < challenges.length; i += 2) {
      final left = challenges[i];
      final right = (i + 1 < challenges.length) ? challenges[i + 1] : null;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: ChallengeCard(
                  challenge: left,
                  currentPoints: currentPoints,
                  onTap: () => onOpenDetails(left),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: right != null
                    ? ChallengeCard(
                        challenge: right,
                        currentPoints: currentPoints,
                        onTap: () => onOpenDetails(right),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// شيمر شبكة — نفس الشكل السابق أثناء التحميل
class _GridShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 6,
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(width: 1.5, color: context.color.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomShimmer(
                  width: double.infinity,
                  height: (100 as num).rh(context),
                  borderRadius: 16),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomShimmer(
                          width: (120 as num).rw(context),
                          height: (15 as num).rh(context),
                          borderRadius: 4),
                      const SizedBox(height: 8),
                      Row(children: [
                        CustomShimmer(
                            width: (20 as num).rw(context),
                            height: (20 as num).rh(context),
                            borderRadius: 10),
                        const SizedBox(width: 4),
                        CustomShimmer(
                            width: (60 as num).rw(context),
                            height: (12 as num).rh(context),
                            borderRadius: 4),
                      ]),
                      const SizedBox(height: 8),
                      CustomShimmer(
                          width: (100 as num).rw(context),
                          height: (12 as num).rh(context),
                          borderRadius: 4),
                      const SizedBox(height: 8),
                      CustomShimmer(
                          width: double.infinity,
                          height: (8 as num).rh(context),
                          borderRadius: 4),
                    ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

//
// ========================== حوارات (عرض فقط) ==========================
//

void _showChallengeDetailsDialog(
  BuildContext context,
  Challenge challenge,
  VoidCallback goToInstructions,
) {
  showDialog(
    context: context,
    builder: (_) => BlurredDialogBox(
      title: "🎯 ${challenge.title}",
      showCancleButton: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.description, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Expanded(
                child: Text(challenge.description,
                    style: const TextStyle(fontSize: 14))),
          ]),
          const SizedBox(height: 20),
          Divider(thickness: 1, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.people, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Text("الإحالات المطلوبة: ${challenge.requiredReferrals}",
                style: const TextStyle(fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.star_rate_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Text("النقاط لكل إحالة: ${challenge.pointsPerReferral}",
                style: const TextStyle(fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(challenge.isActive ? Icons.check_circle : Icons.cancel,
                color: challenge.isActive ? Colors.green : Colors.grey),
            const SizedBox(width: 8),
            Text(challenge.isActive ? "الحالة: 🔥 نشط" : "الحالة: 🚫 غير نشط",
                style: const TextStyle(fontSize: 14)),
          ]),
          const SizedBox(height: 20),
          Divider(thickness: 1, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                goToInstructions();
              },
              icon: const Icon(Icons.info_outline),
              label: const Text("تعليمات التحدي"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade800,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showAllTransactionsDialog(
  BuildContext context,
  List<dynamic> paymentTransactions,
) {
  showDialog(
    context: context,
    builder: (_) => BlurredDialogBox(
      title: "allTransactions".translate(context),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: paymentTransactions.length,
          itemBuilder: (context, index) {
            final tx = paymentTransactions[index] as Map<String, dynamic>;
            final status =
                (tx['payment_status'] ?? '').toString().toLowerCase();
            final isSuccess = status == 'success' || status == 'succeeded';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSuccess
                      ? Colors.green
                      : (status == 'pending' ? Colors.orange : Colors.red),
                  child: Icon(
                    isSuccess
                        ? Icons.check
                        : (status == 'pending' ? Icons.schedule : Icons.close),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                title: Text(
                  "${"transaction".translate(context)} #${tx['id']}",
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "${tx['payment_gateway'] ?? 'notSpecified'.translate(context)} - ${_formatDate(tx['created_at'])}",
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: Text(
                  "${tx['amount']} ${"rial".translate(context)}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

//
// ========================== أدوات عرض صغيرة ==========================
//

String _formatDate(dynamic dateString) {
  if (dateString == null) return '';
  try {
    final date = DateTime.parse(dateString.toString());
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return "$dd/$mm/${date.year} $hh:$min";
  } catch (_) {
    return dateString.toString();
  }
}
