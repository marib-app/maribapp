// ignore_for_file: public_member_api_docs, sort_constructors_first
// 📌 هذا الملف مسؤول عن عرض الأزرار السفلية في صفحة تفاصيل الإعلان (Ad Details Screen)
// - يدير منطق الأزرار حسب حالة الإعلان (نشط/مباع/منتهي/قيد المراجعة...)
// - يحتوي على دوال مساعدة لبناء أزرار عامة (تحرير/حذف/تجديد...)
// - يعرض شريط سفلي (BottomBar) متناسق مع الثيم ويغطي كامل العرض

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ل Clipboard
import 'package:marib/utils/ecommerce_department.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:marib/data/cubits/item/fetch_my_item_cubit.dart';
import 'package:marib/data/cubits/item/delete_item_cubit.dart';
import 'package:marib/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:marib/data/cubits/chat/make_an_offer_item_cubit.dart';
import 'package:marib/data/cubits/chat/send_message.dart';
import 'package:marib/data/cubits/chat/load_chat_messages.dart';
import 'package:marib/data/cubits/chat/delete_message_cubit.dart';
import 'package:marib/ui/screens/cart/delivery_pricing_guard.dart';

import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';

import 'package:marib/data/model/cart/cart_safety_tip.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/chat/chat_screen.dart';
import '../add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/utils/item_category_ids.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/delivery_department.dart';

import 'add_cart_sheet.dart';
import 'owner_action_bar.dart';

import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/data/cubits/item/change_my_items_status_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/notification/notification_service.dart';
import 'cart_field_helpers.dart';
import 'package:marib/utils/currency_utils.dart';

typedef CartItemBuilder = Cart Function({
  List<Map<String, dynamic>>? selectedCustomFields,
});

class CartBuildException implements Exception {
  CartBuildException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BottomButtonsShimmer extends StatelessWidget {
  final bool isOwner;
  final int? buttonCount;
  final VoidCallback? onMakeOffer; // ← جديد

  const BottomButtonsShimmer(
      {super.key, this.isOwner = false, this.onMakeOffer, this.buttonCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = buttonCount ?? (isOwner ? 3 : 2);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outline.withOpacity(0.08)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: List.generate(count, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: index == count - 1 ? 0 : 12,
                ),
                child: const CustomShimmer(
                  height: 46,
                  borderRadius: 14,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// --------------------------------------------------
// 🔹 PrimaryButton: زر أساسي مع قابلية إضافة أيقونة
// --------------------------------------------------
class PrimaryButton extends StatelessWidget {
  final String title; // نص الزر
  final VoidCallback onPressed; // حدث عند الضغط
  final IconData? icon; // أيقونة اختيارية
  final Color? color; // لون خلفية الزر
  final Color? textColor; // لون النص

  const PrimaryButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.icon,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final narrow = w < 360;

    final double btnHeight = narrow ? 42 : 46;
    final double radius = narrow ? 12 : 16;
    final double gap = narrow ? 6 : 8;
    final double iconSize = narrow ? 18 : 20;
    final double fontSize = narrow ? context.font.normal : context.font.large;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? cs.primary,
        foregroundColor: textColor ?? cs.onPrimary,
        minimumSize: Size(double.infinity, btnHeight),
        // يأخذ عرض كامل
        padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        elevation: 0,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      child: FittedBox(
        // يمنع overflow ويصغّر النص إذا ما فيه مساحة
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: iconSize,
                color: textColor ?? cs.onPrimary,
              ),
              SizedBox(width: gap),
            ],
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                color: textColor ?? cs.onPrimary,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// 🔹 bottomButtonWidget: يحدد الأزرار حسب هل الإعلان لي أو لغيري
// --------------------------------------------------

Widget bottomButtonWidget({
  required BuildContext context,
  required ItemModel model,
  required bool isAddedByMe,
  required List<CustomFieldBuilder> moreDetailDynamicFields,
  required VoidCallback onRenewPressed,
  required void Function(List<CustomFieldBuilder>) onUpdateFields,

  // 👇 جديد لاستخدامه كبديل زر "إبلاغ"
  VoidCallback? onMakeOffer,
  CartItemBuilder? cartBuilder,
  // ✅ هوكات اختيارية لنداءات API
  Future<bool> Function()? onPausePressed,
  Future<void> Function()? onResumePressed,
}) {
  String _slugOrId(ItemModel m) {
    final s = (m.slug ?? '').trim();
    return s.isNotEmpty ? s : (m.id?.toString() ?? '');
  }

  // 🟦 إن كان الإعلان يخصني → شريط أزرار المالك
  if (isAddedByMe) {
    final statusLower = (model.status ?? '').toLowerCase().trim();

    return StatefulBuilder(
      builder: (context, setSB) {
        bool _pausing = false;
        bool _resuming = false;

        String _statusMessage({
          required String fallback,
          bool preferFailureMessage = false,
        }) {
          final cubit = BlocProvider.of<ChangeMyItemStatusCubit>(context);
          if (cubit == null) return fallback;

          final statusState = cubit.state;
          if (statusState is ChangeMyItemStatusSuccess &&
              statusState.message.isNotEmpty) {
            return statusState.message;
          }
          if (preferFailureMessage &&
              statusState is ChangeMyItemStatusFailure &&
              statusState.errorMessage.isNotEmpty) {
            return statusState.errorMessage;
          }
          return fallback;
        }

        String _cleanErrorMessage(Object error) {
          final raw = error.toString();
          const prefix = 'Exception: ';
          return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
        }

        // 🔄 استنتاج حالة الإيقاف محليًا
        bool pausedLocal =
            (statusLower == 'inactive') || (model.active == false);

        Future<void> _doPause() async {
          if (_pausing) return;
          setSB(() => _pausing = true);
          try {
            if (onPausePressed != null) {
              await onPausePressed(); // ← API
            }
            // تحديث فوري للموديل
            setSB(() {
              pausedLocal = true;
              model.status = 'inactive';
              try {
                model.active = false;
              } catch (_) {}
            });
            HelperUtils.showSnackBarMessage(context, 'تم إيقاف الإعلان مؤقتًا');
          } catch (error) {
            final cleaned = _cleanErrorMessage(error);
            HelperUtils.showSnackBarMessage(
              context,
              _statusMessage(
                fallback:
                    cleaned.isNotEmpty ? cleaned : 'تعذر الإيقاف، حاول لاحقًا',
                preferFailureMessage: true,
              ),
            );
          } finally {
            setSB(() => _pausing = false);
          }
        }

        Future<void> _openReview() async {
          if (_resuming) return;
          setSB(() => _resuming = true);
          try {
            if (onResumePressed != null) {
              await onResumePressed();
            }
          } catch (error) {
            final cleaned = _cleanErrorMessage(error);
            HelperUtils.showSnackBarMessage(
              context,
              cleaned.isNotEmpty
                  ? cleaned
                  : 'تعذر فتح شاشة المراجعة، حاول لاحقًا',
            );
          } finally {
            setSB(() => _resuming = false);
          }
        }

        // 1) الحالات: approved/active/inactive
        if (statusLower == 'approved' ||
            statusLower == 'active' ||
            statusLower == 'inactive') {
          return OwnerActionBar(
            model: model,
            isFeatured: model.isFeature == true,
            onEdit: () => _goToEdit(context, model),
            onPromote: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context, rootNavigator: true).pushNamed(
                Routes.promoteAdScreen,
                arguments: {
                  "model": model,
                  "pricePerDay": 3000.0,
                  "currencySymbol": CurrencyUtils.preferredDisplayFor('YER') ?? 'ر.ي',
                  "minDays": 1,
                  "maxDays": 30,
                },
              );
            },
            onMarkSold: () {
              Navigator.pushNamed(
                context,
                Routes.soldOutBoughtScreen,
                arguments: {
                  "itemId": model.id,
                  "price": model.price,
                  "itemName": model.name,
                  "itemImage": model.image,
                },
              );
              HelperUtils.showSnackBarMessage(
                  context, 'انتقلنا لوسم الإعلان كمباع');
            },
            onPause: (!pausedLocal && !_pausing) ? _doPause : null,
            onResume: (pausedLocal && !_resuming) ? () => _openReview() : null,
            buildShareSlug: () => _slugOrId(model),
            onCopyLink: () async {
              final slug = _slugOrId(model);
              final link = HelperUtils.nativeDeepLinkUrlOfItem(slug);
              await Clipboard.setData(ClipboardData(text: link));
              HelperUtils.showSnackBarMessage(context, 'تم نسخ الرابط');
            },
            onDelete: () async {
              final confirm = await UiUtils.showBlurredDialoge(
                context,
                dialoge: BlurredDialogBox(
                  title: "deleteBtnLbl".translate(context),
                  content: Text("deleteitemwarning".translate(context)),
                ),
              );
              if (confirm == true) {
                context.read<DeleteItemCubit>().deleteItem(model.id!);
                context.read<FetchMyItemsCubit>().deleteItem(model);
                HelperUtils.showSnackBarMessage(context, 'تم حذف الإعلان');
              }
            },
          );
        }

        // 2) مرفوض
        if (statusLower == 'rejected') {
          return OwnerActionBar(
            model: model,
            onDelete: () async {
              final confirm = await UiUtils.showBlurredDialoge(
                context,
                dialoge: BlurredDialogBox(
                  title: "deleteBtnLbl".translate(context),
                  content: Text("deleteitemwarning".translate(context)),
                ),
              );
              if (confirm == true) {
                context.read<DeleteItemCubit>().deleteItem(model.id!);
                context.read<FetchMyItemsCubit>().deleteItem(model);
                HelperUtils.showSnackBarMessage(context, 'تم حذف الإعلان');
              }
            },
          );
        }

        // 3) قيد المراجعة/انتظار
        if (statusLower == 'review' ||
            statusLower == 'pending' ||
            statusLower == 'under review') {
          return OwnerActionBar(
            model: model,
            onEdit: () => _goToEdit(context, model),
            buildShareSlug: () => _slugOrId(model),
            onCopyLink: () async {
              final slug = _slugOrId(model);
              final link = HelperUtils.nativeDeepLinkUrlOfItem(slug);
              await Clipboard.setData(ClipboardData(text: link));
              HelperUtils.showSnackBarMessage(context, 'تم نسخ الرابط');
            },
            onDelete: () async {
              final confirm = await UiUtils.showBlurredDialoge(
                context,
                dialoge: BlurredDialogBox(
                  title: "deleteBtnLbl".translate(context),
                  content: Text("deleteitemwarning".translate(context)),
                ),
              );
              if (confirm == true) {
                context.read<DeleteItemCubit>().deleteItem(model.id!);
                context.read<FetchMyItemsCubit>().deleteItem(model);
                HelperUtils.showSnackBarMessage(context, 'تم حذف الإعلان');
              }
            },
          );
        }

        // 4) أقل شيء
        return OwnerActionBar(
          model: model,
          onEdit: () => _goToEdit(context, model),
          onDelete: () async {
            final confirm = await UiUtils.showBlurredDialoge(
              context,
              dialoge: BlurredDialogBox(
                title: "deleteBtnLbl".translate(context),
                content: Text("deleteitemwarning".translate(context)),
              ),
            );
            if (confirm == true) {
              context.read<DeleteItemCubit>().deleteItem(model.id!);
              context.read<FetchMyItemsCubit>().deleteItem(model);
              HelperUtils.showSnackBarMessage(context, 'تم حذف الإعلان');
            }
          },
        );
      },
    );
  }

  // 🔹 إعلان الزائر: استخدم البار الجديد الذي يعرض "تقديم عرض" دومًا كزر ثانوي
  return AdDetailsBottomBar(
    model: model,
    moreDetailDynamicFields: moreDetailDynamicFields,
    onUpdateFields: onUpdateFields,
    onMakeOffer: onMakeOffer,
    // 👈 هنا الربط
    cartBuilder: cartBuilder,
  );
}

// --------------------------------------------------
// 🔹 وضع الأزرار حسب نوع القسم (متجر/سلة أو إعلانات/عقارات)
// --------------------------------------------------
enum AdActionMode { ecommerce, classifieds }

// ✅ عدّل هذه القوائم حسب IDs الأقسام عندك
// - kEcommerceIds: الأقسام التي تتصرف كمتجر (كمبيوترات، متاجر إلكترونية، شي إن...)
// - kClassifiedIds: أقسام الإعلانات (عقارات، إعلانات عامة...)

// ===== ضبط القوائم حسب أقسامك =====
const Set<int> kClassifiedIds = {
  1,
  2,
  6
}; // العقارات / السياحة / إعلانات الجمهور

const Set<String> _kRealEstateKeywords = <String>{
  'realestate',
  'real_estate',
  'real-estate',
  'estate',
  'property',
  'properties',
  'aqar',
  'aqarat',
  'aqarats',
  'عقار',
  'عقارات',
  'العقارات',
  'الاراضي',
  'اراضي',
  'ارض',
  'ايجار',
  'الايجار',
};

const Set<String> _kGeneralAudienceKeywords = <String>{
  'publicads',
  'publicad',
  'public',
  'audience',
  'generalads',
  'generalad',
  'general',
  'announcement',
  'announcements',
  'اعلان',
  'اعلانات',
  'اعلانالجمهور',
  'اعلاناتالجمهور',
  'الجمهور',
  'قسمالجمهور',
  'قسمالاعلانات',
  'اعلاناتعامه',
  'اعلانعام',
  'الاعلانات',
  'القسمالعام',
};

bool _containsKeyword(String? source, Set<String> keywords) {
  if (source == null) {
    return false;
  }

  final String condensed =
      source.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '').trim();

  if (condensed.isEmpty) {
    return false;
  }

  for (final String keyword in keywords) {
    if (condensed.contains(keyword)) {
      return true;
    }
  }
  return false;
}

bool _isClassifiedByText(ItemModel model) {
  final Iterable<String?> candidates = <String?>[
    model.category?.name,
    model.category?.description,
    model.departmentSlug,
    model.type,
    model.itemType,
  ];

  for (final String? candidate in candidates) {
    if (_containsKeyword(candidate, _kRealEstateKeywords) ||
        _containsKeyword(candidate, _kGeneralAudienceKeywords)) {
      return true;
    }
  }
  return false;
}

// ---- Helpers: نجمع كل IDs المتاحة من الموديل بأمان ----
int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v.trim());
  return null;
}

Set<int> _collectCategoryIds(ItemModel m) {
  final ids = <int>{};

  // من الحقل المباشر
  final id1 = _toInt(m.categoryId);
  if (id1 != null) ids.add(id1);

  // من الموديل الفرعي (إن وجد)
  final id2 = _toInt(m.category?.id);
  if (id2 != null) ids.add(id2);

  // من سلسلة allCategoryIds: نلتقط كل الأرقام أينما كانت
  final raw = (m.allCategoryIds ?? '').trim();
  if (raw.isNotEmpty) {
    for (final match in RegExp(r'\d+').allMatches(raw)) {
      final v = int.tryParse(match.group(0)!);
      if (v != null) ids.add(v);
    }
  }

  return ids;
}

// ---- القرار النهائي: نستخدم أي ID متاح (categoryId / category.id / allCategoryIds)
AdActionMode resolveActionMode(ItemModel m) {
  final ids = _collectCategoryIds(m);

  if (ids.any(kClassifiedIds.contains) || _isClassifiedByText(m)) {
    return AdActionMode.classifieds;
  }

  if (isEcommerceItem(m)) {
    return AdActionMode.ecommerce;
  }

  // (اختياري) fallback خفيف عبر نوع العنصر (لو مشروعك يستخدمه)
  final kind = (m.itemType ?? m.type ?? '').toLowerCase();
  if (kind.contains('real') ||
      kind.contains('estate') ||
      kind.contains('rent') ||
      kind.contains('classified') ||
      kind.contains('اعلان') ||
      kind.contains('الجمهور')) {
    return AdActionMode.classifieds;
  }
  if (kind.contains('store') ||
      kind.contains('product') ||
      kind.contains('ecommerce')) {
    return AdActionMode.ecommerce;
  }

  // الافتراضي
  return AdActionMode.classifieds;
}

// --------------------------------------------------
// 🔹 AdDetailsBottomBar: شريط سفلي يغطي العرض كامل (لغير المالك)
// --------------------------------------------------
class AdDetailsBottomBar extends StatefulWidget {
  final ItemModel model;
  final List<CustomFieldBuilder> moreDetailDynamicFields;
  final void Function(List<CustomFieldBuilder>) onUpdateFields;
  final VoidCallback? onMakeOffer;
  final CartItemBuilder? cartBuilder;

  const AdDetailsBottomBar({
    super.key,
    this.onMakeOffer,
    this.cartBuilder,
    required this.model,
    required this.moreDetailDynamicFields,
    required this.onUpdateFields,
  });

  @override
  State<AdDetailsBottomBar> createState() => _AdDetailsBottomBarState();
}

class _AdDetailsBottomBarState extends State<AdDetailsBottomBar> {
  bool _isAddToCartInProgress = false;

  ItemModel get model => widget.model;

  List<CustomFieldBuilder> get moreDetailDynamicFields =>
      widget.moreDetailDynamicFields;

  void Function(List<CustomFieldBuilder>) get onUpdateFields =>
      widget.onUpdateFields;

  VoidCallback? get onMakeOffer => widget.onMakeOffer;

  CartItemBuilder? get cartBuilder => widget.cartBuilder;

  // --------------------------------------------
  // 📨 فتح الدردشة (يعتمد على منطقك الحالي في المشروع)
  // --------------------------------------------
  void _openChat(
      BuildContext context, ItemModel model, ChatedUser? chatedUser) {
    UiUtils.checkUser(
      onNotGuest: () async {
        if (_isAddToCartInProgress) {
          return;
        }
        if (chatedUser != null) {
          _navigateToChat(context, model, chatedUser);
        } else {
          // أول مرة: اصنع محادثة/عرض ثم افتح الشات
          context
              .read<MakeAnOfferItemCubit>()
              .makeAnOfferItem(id: model.id!, from: "chat");
        }
      },
      context: context,
    );
  }

  void _navigateToChat(
    BuildContext context,
    ItemModel model,
    ChatedUser chatedUser, {
    int? itemOfferPrice,
  }) {
    final double resolvedItemPrice = model.price ?? 0;

    final double? resolvedOfferPrice =
        itemOfferPrice?.toDouble() ?? chatedUser.amount;

    final String? currency = chatedUser.item?.currency ?? model.currency;
    final String? currencySymbol = chatedUser.item?.currencySymbol ??
        chatedUser.item?.currency ??
        model.currency;

    final int resolvedOfferId = chatedUser.itemOfferId ?? chatedUser.id ?? 0;
    final String conversationId =
        chatedUser.conversationId ?? chatedUser.id?.toString() ?? '';

    final List<ChatParticipant>? participants = chatedUser.participants ??
        NotificationService.getCachedParticipants(
          conversationId,
          itemOfferId: resolvedOfferId > 0 ? resolvedOfferId : null,
          senderId: model.user?.id?.toString(),
          itemId: chatedUser.itemId?.toString(),
        ) ??
        NotificationService.buildParticipantsFromNotification(
          data: {
            'user_id': model.user?.id,
            'user_name': model.user?.name,
            'user_profile': model.user?.profile,
            'conversation_id': conversationId,
            'item_offer_id': resolvedOfferId,
          },
        );

    Navigator.push(
      context,
      BlurredRouter(
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => SendMessageCubit()),
            BlocProvider(create: (_) => LoadChatMessagesCubit()),
            BlocProvider(create: (_) => DeleteMessageCubit()),
          ],
          child: ChatScreen(
            profilePicture: model.user?.profile ?? "",
            userName: model.user?.name ?? '',
            userId: (model.user?.id ?? '').toString(),
            from: "item",
            itemImage: model.image ?? '',
            itemId: model.id.toString(),
            date: model.created ?? '',
            itemTitle: model.name ?? '',
            itemOfferId: chatedUser.itemOfferId ?? chatedUser.id ?? 0,
            conversationId:
                chatedUser.conversationId ?? chatedUser.id?.toString() ?? '',
            itemPrice: resolvedItemPrice,
            status: model.status ?? '',
            buyerId: HiveUtils.getUserId(),
            isPurchased: model.isPurchased ?? 0,
            alreadyReview: (model.review != null && model.review!.isNotEmpty),
            itemOfferPrice: resolvedOfferPrice,
            participants: participants,
            currency: currency,
            currencySymbol: currencySymbol,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _coerceResponseMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  ChatedUser? _parseChatedUserFromResponse(dynamic raw) {
    final map = _coerceResponseMap(raw);
    if (map == null) {
      return null;
    }

    final chat = ChatedUser.fromJson(map);
    chat.userBlocked ??= false;
    return chat;
  }

  int? _parseAmountAsInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.isNotEmpty) {
      return int.tryParse(value);
    }
    return null;
  }

  bool _isRealEstate() {
    final n = (model.category?.name ?? '').toString().toLowerCase().trim();

    const realEstateHints = [
      'realestate',
      'real-estate',
      'estate',
      'property',
      'عقار',
      'عقارات',
      'العقارات'
    ];
    return realEstateHints.any((h) => n.contains(h));
  }

  // --------------------------------------------
  // 🚩 فتح نموذج الإبلاغ (بدّلها باستدعاء BottomSheet/شاشة الإبلاغ)
  // --------------------------------------------
  void _openReport(BuildContext context, ItemModel model) {
    // مثال بدائي؛ استبدله بما لديك:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('فتح نموذج الإبلاغ...')),
    );
    // مثال: _bottomSheet(model.id!);
  }

  // --------------------------------------------
  // 🛒 إضافة إلى السلة (منطقك كما هو)
  // --------------------------------------------
  Future<void> _addToCart(BuildContext context) async {
    UiUtils.checkUser(
      onNotGuest: () async {
        // حضّر الحقول المخصّصة لو لسه ما تجهّزت
        if (moreDetailDynamicFields.isEmpty) {
          final fields = context
              .read<FetchCustomFieldsCubit>()
              .getFields()
              .where((f) => (f.isCustomerOption ?? 0) == 1);

          final newFields = fields.map((field) {
            final b = CustomFieldBuilder(field.toMap());
            b.stateUpdater((_) {});
            b.init();
            return b;
          }).toList();

          onUpdateFields(newFields);
        }

        final String? validationError =
            validateRequiredCustomFieldSelections(moreDetailDynamicFields);

        if (validationError != null) {
          HelperUtils.showSnackBarMessage(context, validationError);
          return;
        }

        final List<Map<String, dynamic>> selectedCustomFields =
            buildSelectedCustomFieldsPayload();
        final List<Map<String, dynamic>>? selectedCustomFieldsPayload =
            selectedCustomFields.isEmpty ? null : selectedCustomFields;

        if (model.id == null) {
          HelperUtils.showSnackBarMessage(
            context,
            'لا يمكن إضافة هذا المنتج إلى السلة في الوقت الحالي.',
          );
          return;
        }

        late final Cart cartItem;
        try {
          if (cartBuilder != null) {
            cartItem = cartBuilder!(
              selectedCustomFields: selectedCustomFieldsPayload,
            );
          } else {
            cartItem = Cart.fromItemModel(
              model,
              quantity: 1,
              selectedCustomFields: selectedCustomFieldsPayload,
            );
          }
        } on CartBuildException catch (error) {
          HelperUtils.showSnackBarMessage(context, error.message);
          return;
        } catch (_) {
          HelperUtils.showSnackBarMessage(
            context,
            'تعذر تجهيز هذا المنتج للسلة. حاول مرة أخرى لاحقاً.',
          );
          return;
        }

        final cartCubit = context.read<CartCubit>();
        final existingItems = cartCubit.state.items;

        String? normalizeCurrency(String? raw) {
          final String? trimmed = raw?.trim();
          if (trimmed == null || trimmed.isEmpty) {
            return null;
          }
          return trimmed.toUpperCase();
        }

        String? activeCartCurrency(Iterable<Cart> items) {
          for (final Cart entry in items) {
            final String? candidate = normalizeCurrency(entry.currency);
            if (candidate != null) {
              return candidate;
            }
          }
          return null;
        }

        final String incomingSection = cartItem.section.trim();
        final String? existingSection = existingItems.isNotEmpty
            ? existingItems.first.section.trim()
            : null;

        bool sectionsMatch(String? a, String? b) =>
            a != null && b != null && a.toLowerCase() == b.toLowerCase();

        if (existingSection != null &&
            !sectionsMatch(existingSection, incomingSection)) {
          UiUtils.showBlurredDialoge(
            context,
            dialoge: const BlurredDialogBox(
              title: "تنبيه السلة",
              content: Text(
                  "لا يمكنك خلط الأقسام داخل السلة. فضلاً أفرغ السلة قبل إضافة منتجات من قسم مختلف."),
              showCancleButton: false,
              acceptButtonName: "حسنًا",
            ),
          );
          return;
        }

        final String? existingCurrency = activeCartCurrency(existingItems);
        final String? incomingCurrency =
            normalizeCurrency(cartItem.currency ?? model.currency);

        if (existingCurrency != null &&
            incomingCurrency != null &&
            existingCurrency != incomingCurrency) {
          HelperUtils.showSnackBarMessage(
            context,
            'لا يمكن إضافة هذا المنتج لأن السلة مضبوطة على عملة $existingCurrency بينما المنتج بعملة $incomingCurrency.',
          );
          return;
        }

        if (isDuplicateCartLine(existingItems, cartItem)) {
          HelperUtils.showSnackBarMessage(
            context,
            "productAlreadyInCart".translate(context),
          );
          return;
        }

        if (_isAddToCartInProgress) {
          return;
        }

        if (mounted) {
          setState(() {
            _isAddToCartInProgress = true;
          });
        } else {
          _isAddToCartInProgress = true;
        }

        try {
          await cartCubit.addItem(cartItem);

          final CartSafetyTipsPayload? safetyTips = cartCubit.state.safetyTips;
          final bool shouldNavigateToCart =
              safetyTips == null || !safetyTips.hasDisplayableContent;

          if (shouldNavigateToCart) {
            final navigator = Navigator.of(context, rootNavigator: true);
            navigator.popUntil((route) => route is! PopupRoute);
            navigator.pushNamed(Routes.cart);
          }
        } catch (e) {
          final message = DeliveryPricingGuard.readableErrorMessage(
            context,
            e,
          );

          HelperUtils.showSnackBarMessage(
            context,
            message,
          );
        } finally {
          if (mounted) {
            setState(() {
              _isAddToCartInProgress = false;
            });
          } else {
            _isAddToCartInProgress = false;
          }
        }
      },
      context: context,
    );
  }

  Color _brandGreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.green.shade400 : Colors.green.shade600;
  }

  Color _brandOrange(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.orange.shade400 : Colors.orange.shade600;
  }

  Color _onFor(Color bg) {
    // اختيار لون نص مناسب تلقائياً
    return bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MakeAnOfferItemCubit, MakeAnOfferItemState>(
      listener: (context, state) {
        if (state is MakeAnOfferItemInProgress) {
          Widgets.showLoader(context);
        } else if (state is MakeAnOfferItemSuccess) {
          Widgets.hideLoder(context);

          if (state.from == 'chat') {
            final chatedUser = _parseChatedUserFromResponse(state.data);
            if (chatedUser != null) {
              final responseMap = _coerceResponseMap(state.data);
              final offerPrice = responseMap != null
                  ? _parseAmountAsInt(responseMap['amount'])
                  : null;

              context.read<GetBuyerChatListCubit>().addNewChat(chatedUser);

              _navigateToChat(
                context,
                model,
                chatedUser,
                itemOfferPrice: offerPrice,
              );
            }
          }
        } else if (state is MakeAnOfferItemFailure) {
          Widgets.hideLoder(context);
          HelperUtils.showSnackBarMessage(
            context,
            state.errorMessage,
            messageDuration: 3,
          );
        }
      },
      child: Builder(
        builder: (context) {
          final cs = context.color;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          final outlinedTextColor = isDark ? Colors.white : Colors.black87;
          final outlinedBorderColor = isDark ? Colors.white54 : Colors.black26;

          // تحديد نمط الإجراء لهذا الإعلان
          final mode = resolveActionMode(model);
          final bool isEcommerce = (mode == AdActionMode.ecommerce);

          // إن وُجدت محادثة/عرض سابق لهذا المنتج
          final ChatedUser? chatedUser = context.select(
            (GetBuyerChatListCubit cubit) => cubit.getOfferForItem(model.id!),
          );

          // نعرض "تقديم عرض" عندما لا يكون نمط الإعلان سلة/متجر
          final bool showOffer = !isEcommerce;

          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.secondaryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    // الزر الرئيسي
                    Expanded(
                      child: isEcommerce
                          ? ElevatedButton(
                              onPressed: _isAddToCartInProgress
                                  ? null
                                  : () => _addToCart(context),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: _brandGreen(context),
                                foregroundColor: _onFor(_brandGreen(context)),
                                elevation: 0,
                              ),
                              child: _isAddToCartInProgress
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'جاري الإضافة...',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text('إضافة الى السلة'),
                            )
                          : ElevatedButton.icon(
                              onPressed: () =>
                                  _openChat(context, model, chatedUser),
                              icon: const Icon(Icons.chat_bubble_outline,
                                  size: 18),
                              label: const Text('مراسلة المُعلن'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: _brandOrange(context),
                                foregroundColor: _onFor(_brandOrange(context)),
                                elevation: 0,
                              ),
                            ),
                    ),

                    const SizedBox(width: 10),

                    // الزر الثانوي
                    if (isEcommerce)
                      OutlinedButton.icon(
                        onPressed: () => _openChat(context, model, chatedUser),
                        icon: const Icon(Icons.chat_outlined, size: 18),
                        label: const Text('راسل'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: outlinedBorderColor),
                          foregroundColor: outlinedTextColor,
                        ),
                      )
                    else
                      // 👇 بدّلنا "إبلاغ" إلى "تقديم عرض" دومًا لغير السلة
                      OutlinedButton.icon(
                        onPressed: showOffer ? (onMakeOffer ?? () {}) : null,
                        icon: const Icon(Icons.local_offer_outlined, size: 18),
                        label: const Text('تقديم عرض'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: outlinedBorderColor),
                          foregroundColor: outlinedTextColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// تعديل الاعلان

void _goToEdit(BuildContext context, ItemModel model) {
  FocusScope.of(context).unfocus();
  final categoryIds = buildItemCategoryIds(model);

  Navigator.of(context, rootNavigator: true).pushNamed(
    Routes.addMoreDetailsScreen,
    arguments: {
      "isEdit": true,
      "model": model, // مهم
      "item": model, // احتياطي
      "id": model.id, // اختياري
      "categoryId": model.categoryId, // اختياري
      "breadCrumbItems": null,
      "categoryIds": categoryIds.isEmpty ? null : categoryIds,
    },
  );
}

// تمييز الاعلان

void _goToPromote(BuildContext context, ItemModel model) {
  FocusScope.of(context).unfocus();
  Navigator.of(context, rootNavigator: true).pushNamed(
    Routes.subscriptionPackageListRoute,
    arguments: {
      "source": "feature",
      "itemId": model.id,
      "model": model,
    },
  );
}
