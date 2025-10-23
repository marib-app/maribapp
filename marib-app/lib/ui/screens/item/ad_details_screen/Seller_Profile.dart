import 'dart:async';
import 'package:timeago/timeago.dart' as timeago;
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:marib/data/cubits/report/fetch_item_report_reason_list.dart';
import 'package:marib/data/cubits/subscription/fetch_ads_listing_subscription_packages_cubit.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/data/model/user_model.dart';
import 'package:marib/ui/screens/home_screen/home_screen.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:marib/data/cubits/chat/make_an_offer_item_cubit.dart';
import 'package:marib/data/cubits/favorite/favorite_cubit.dart';
import 'package:marib/data/cubits/item/create_featured_ad_cubit.dart';
import 'package:marib/data/cubits/item/fetch_my_item_cubit.dart';
import 'package:marib/data/cubits/item/item_total_click_cubit.dart';
import 'package:marib/data/cubits/item/related_item_cubit.dart';
import 'package:marib/data/cubits/renew_item_cubit.dart';
import 'package:marib/data/cubits/safety_tips_cubit.dart';
import 'package:marib/data/cubits/seller/fetch_seller_ratings_cubit.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/safety_tips_model.dart';
import 'package:marib/data/model/subscription_pacakage_model.dart';
import 'package:intl/intl.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/validator.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:marib/data/repositories/favourites_repository.dart';
import 'dart:ui';
import 'package:marib/data/model/classified_model.dart';
import 'package:marib/utils/screen_scaler.dart';
import 'package:marquee/marquee.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';

import 'package:shimmer/shimmer.dart';

import 'package:flutter/widgets.dart';
import 'package:marib/utils/seller_category_utils.dart'
    as seller_category_utils;

/// ويدجت لعرض صورة البائع بشكل احترافي مع شيمر يظهر إلى أن تكتمل الصورة
class SellerProfileImage extends StatefulWidget {
  final String? imageUrl; // رابط صورة البائع (إن وُجد)

  const SellerProfileImage({super.key, required this.imageUrl});

  @override
  State<SellerProfileImage> createState() => _SellerProfileImageState();
}

class _SellerProfileImageState extends State<SellerProfileImage> {
  bool _isImageLoaded = false; // حالة: هل تم تحميل الصورة بالكامل؟

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imageUrl?.isNotEmpty == true;

    return SizedBox(
      height: 60.rh(context), // ارتفاع متجاوب
      width: 60.rw(context), // عرض متجاوب
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10), // حواف ناعمة
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  // ✅ صورة البائع من الإنترنت
                  Image.network(
                    widget.imageUrl!,
                    fit: BoxFit.cover, // تغطية مناسبة بدون تشويه
                    frameBuilder: (context, child, frame, wasLoaded) {
                      if (frame != null && !_isImageLoaded) {
                        // أول ظهور فعلي للصورة → نوقف الشيمر
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => _isImageLoaded = true);
                          }
                        });
                      }
                      return child; // نرجع الصورة نفسها
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // في حال فشل التحميل → نعرض الأيقونة الافتراضية
                      return UiUtils.getSvg(
                        AppIcons.defaultPersonLogo,
                        color: context.color.territoryColor,
                        fit: BoxFit.none,
                      );
                    },
                  ),

                  // ✨ شيمر احترافي يظهر فوق الصورة إلى أن تكتمل
                  if (!_isImageLoaded)
                    Shimmer.fromColors(
                      baseColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]!
                          : Colors.grey[300]!,
                      highlightColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[700]!
                              : Colors.grey[100]!,
                      child: Container(color: Colors.grey),
                    ),
                ],
              )
            : UiUtils.getSvg(
                // ❌ في حال لا يوجد رابط صورة أصلاً
                AppIcons.defaultPersonLogo,
                color: context.color.territoryColor,
                fit: BoxFit.none,
              ),
      ),
    );
  }
}

/// ويدجت تعرض معلومات البائع (الاسم، التوثيق، التقييم، البريد)
/// مع تأثير Shimmer يظهر مؤقتاً أثناء تحميل البيانات

class SellerInfoSection extends StatelessWidget {
  final User user;

  const SellerInfoSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // 🔄 جلب بيانات التقييم من Cubit
    final sellerData = context.watch<FetchSellerRatingsCubit>().sellerData();
    final rating = sellerData?.averageRating;
    final total = context.watch<FetchSellerRatingsCubit>().totalSellerRatings();

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ شارة التوثيق (إن وُجد)
          if (user.isVerified == 1)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: context.color.forthColor,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              child: Text("verified".translate(context)).bold().size(10),
            ),
          const SizedBox(height: 4),

          // ✅ اسم المستخدم
          Text(user.name ?? "").bold().size(context.font.large),

          const SizedBox(height: 4),

          // ✅ التقييم والنجوم وعدد التقييمات
          if (rating != null)
            Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 17,
                  color: context.color.textDefaultColor,
                ),
                const SizedBox(width: 4),
                Text(rating.toStringAsFixed(2))
                    .size(14)
                    .color(context.color.textDefaultColor),
                const SizedBox(width: 6),
                Text('|').color(
                  context.color.textDefaultColor.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Text('${total ?? 0} ${"ratings".translate(context)}')
                    .size(14)
                    .color(
                      context.color.textDefaultColor.withOpacity(0.3),
                    ),
              ],
            ),

          const SizedBox(height: 4),

          // ✅ البريد الإلكتروني (إذا كان ظاهر ومتوفر)
          if (user.showPersonalDetails == 1 && user.email?.isNotEmpty == true)
            Text(user.email!)
                .color(context.color.textLightColor)
                .size(context.font.small),
        ],
      ),
    );
  }
}

/// ويدجت تعرض أزرار الرسائل والاتصال (بدون شيمر)
class SellerActions extends StatelessWidget {
  final User user;

  const SellerActions({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // ✅ التحقق من صلاحية عرض الأزرار
    final canShow =
        user.showPersonalDetails == 1 && user.mobile?.isNotEmpty == true;

    if (!canShow) return const SizedBox.shrink();

    final phone = HelperUtils.formatPhoneNumber(
      user.mobile!,
      Constant.defaultCountryCode,
    );

    return Row(
      children: [
        IconActionButton(
          assetName: AppIcons.message,
          onTap: () {
            HelperUtils.launchPathURL(
              isTelephone: false,
              isSMS: true,
              isMail: false,
              value: phone,
              context: context,
            );
          },
        ),
        SizedBox(width: 10.rw(context)),
        IconActionButton(
          assetName: AppIcons.call,
          onTap: () {
            HelperUtils.launchPathURL(
              isTelephone: true,
              isSMS: false,
              isMail: false,
              value: phone,
              context: context,
            );
          },
        ),
      ],
    );
  }
}

/// زر أيقونة بتأثير بصري احترافي (بدون شيمر)
class IconActionButton extends StatelessWidget {
  final String assetName; // مسار SVG
  final VoidCallback onTap; // الإجراء عند النقر
  final Color? color; // لون الأيقونة (اختياري)
  final double size; // حجم الزر (عرض × ارتفاع)
  final double borderRadius; // نصف قطر الحواف

  const IconActionButton({
    super.key,
    required this.assetName,
    required this.onTap,
    this.color,
    this.size = 40,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: SvgPicture.asset(
            assetName,
            colorFilter: ColorFilter.mode(
              color ?? cs.primary,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

// دالة عرض معلومات المعلن

Widget setSellerDetails(BuildContext context, ItemModel model) {
  final user = model.user;
  if (user == null) return SizedBox.shrink();

  return InkWell(
    onTap: () {
      if (_isMerchantAccount(user) && user.id != null) {
        final String displayName = _merchantDisplayName(user);
        final seller_category_utils.SellerCategoryIdentifiers sellerCategories =
            _extractSellerCategoryIdentifiers(user);
        final dynamic sellerCategoryPayload = sellerCategories.toRoutePayload();
        final String storeCategoryId = Constant.storeRootCategoryIdAsString;

        Navigator.pushNamed(
          context,
          Routes.section_screen,
          arguments: {
            'catID': storeCategoryId,
            'catName': displayName,
            'categoryIds': [storeCategoryId],
            'interfaceType': 'e_store',
            'sellerId': user.id,
            if (sellerCategoryPayload != null)
              'sellerCategoryIds': sellerCategoryPayload,
          },
        );
        return;
      }

      Navigator.pushNamed(
        context,
        Routes.sellerProfileScreen,
        arguments: {
          "model": user,
          "total":
              context.read<FetchSellerRatingsCubit>().totalSellerRatings() ?? 0,
          "rating": context
              .read<FetchSellerRatingsCubit>()
              .sellerData()
              ?.averageRating,
        },
      );
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SellerProfileImage(imageUrl: user.profile),
          Expanded(child: SellerInfoSection(user: user)),
          SellerActions(user: user),
        ],
      ),
    ),
  );
}

bool _isMerchantAccount(User user) {
  final int? accountType = _extractAccountType(user);
  if (accountType == Constant.accountTypeSeller) {
    return true;
  }

  final String? normalizedType = user.type?.trim().toLowerCase();
  return normalizedType == 'seller' || normalizedType == 'commercial';
}

int? _extractAccountType(User user) {
  if (user.accountType != null) {
    return user.accountType;
  }

  final String? rawType = user.type;
  if (rawType == null) {
    return null;
  }

  final String trimmed = rawType.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final int? numeric = int.tryParse(trimmed);
  if (numeric != null) {
    return numeric;
  }

  switch (trimmed.toLowerCase()) {
    case 'seller':
    case 'commercial':
      return Constant.accountTypeSeller;
    case 'real_estate':
    case 'realestate':
    case 'real-estate':
      return Constant.accountTypeRealEstate;
  }

  return null;
}

Map<String, dynamic>? _contactInfoFromUser(User user) {
  return seller_category_utils.extractContactInfo(user.additionalInfo);
}

String _merchantDisplayName(User user) {
  final Map<String, dynamic>? contactInfo = _contactInfoFromUser(user);
  if (contactInfo != null) {
    final dynamic name = contactInfo['business_name'];
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
  }
  return user.name ?? '';
}

seller_category_utils.SellerCategoryIdentifiers
    _extractSellerCategoryIdentifiers(User user) {
  final Map<String, dynamic>? contactInfo = _contactInfoFromUser(user);
  return seller_category_utils.extractSellerCategoryIdentifiers(contactInfo);
}

class SellerDetailsShimmer extends StatelessWidget {
  const SellerDetailsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: const [
          CustomShimmer(height: 60, width: 60, borderRadius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomShimmer(height: 14, width: 120, borderRadius: 6),
                SizedBox(height: 8),
                CustomShimmer(height: 12, borderRadius: 6),
                SizedBox(height: 6),
                CustomShimmer(height: 12, width: 80, borderRadius: 6),
              ],
            ),
          ),
          SizedBox(width: 12),
          CustomShimmer(height: 42, width: 42, borderRadius: 12),
        ],
      ),
    );
  }
}
