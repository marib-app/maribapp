import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:marib/app/app_scroll_behavior.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/auth_cubit.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/model/user_model.dart';
import 'package:marib/data/repositories/cart/addresses_repository.dart';
import 'package:marib/ui/screens/cart/components/delivery_and_payment/delivery_address_section.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';

class ProEditProfileScreen extends StatefulWidget {
  const ProEditProfileScreen({super.key});

  static Route route(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const ProEditProfileScreen(),
    );
  }

  @override
  State<ProEditProfileScreen> createState() => _ProEditProfileScreenState();
}

class _ProEditProfileScreenState extends State<ProEditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final AddressesRepository _addressesRepo = AddressesRepository();

  bool _notifications = true;
  bool _showPersonal = true;
  File? _avatar;
  bool _saving = false;
  Map<String, dynamic>? _addressData;
  bool _bootLoading = true;

  @override
  void initState() {
    super.initState();
    final user = HiveUtils.getUserDetails();
    _name.text = user.name ?? '';
    _email.text = user.email ?? '';
    _phone.text = user.mobile ?? '';
    _address.text = user.address ?? '';
    _notifications = user.notification == 1;
    _showPersonal = user.isPersonalDetailShow == 1;
    _addressData = _extractAddress(user);
    _loadDefaultAddress();
  }

  Future<void> _loadDefaultAddress() async {
    try {
      final List<Map<String, dynamic>> addresses =
          await _addressesRepo.fetchAddresses();
      Map<String, dynamic>? defaultAddr;
      Map<String, dynamic>? fallback;
      for (final Map<String, dynamic> entry in addresses) {
        fallback ??= entry;
        final bool? isDefault = _asBool(entry['is_default'] ?? entry['isDefault']);
        if (isDefault == true) {
          defaultAddr = entry;
          break;
        }
      }
      final Map<String, dynamic>? selected = defaultAddr ?? fallback;
      if (mounted && selected != null) {
        setState(() {
          _addressData = selected;
          if (_address.text.trim().isEmpty) {
            final String label =
                (selected['label'] ?? selected['address'] ?? '').toString().trim();
            if (label.isNotEmpty) _address.text = label;
          }
        });
      }
    } catch (_) {
      // ignore fetch errors
    } finally {
      if (mounted) setState(() => _bootLoading = false);
    }
  }

  Map<String, dynamic>? _extractAddress(UserModel user) {
    final info = user.additionalInfo;
    if (info is Map) {
      final val = info['address'];
      if (val is Map<String, dynamic>) return val;
      if (val is Map) return Map<String, dynamic>.from(val);
    }
    return null;
  }

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase().trim();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return null;
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _avatar = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final resp = await context.read<AuthCubit>().updateuserdata(
            context,
            name: _name.text.trim(),
            email: _email.text.trim(),
            address: _address.text.trim(),
            mobile: _phone.text.trim(),
            fileUserimg: _avatar,
            notification: _notifications ? "1" : "0",
            personalDetail: _showPersonal ? 1 : 0,
          );

      context.read<UserDetailsCubit>().copy(UserModel.fromJson(resp['data']));
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          resp['message'] ?? "تم التحديث",
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = HiveUtils.getUserDetails();

    return Scaffold(
      backgroundColor: context.color.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "تعديل الملف الشخصي",
        showBackButton: true,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: UiUtils.buildButton(
            context,
            height: 48,
            onPressed: () async {
              if (_saving) return;
              await _save();
            },
            buttonTitle: _saving ? "جارٍ الحفظ..." : "حفظ التغييرات",
          ),
        ),
      ),
      body: ScrollConfiguration(
        behavior: AppScrollBehavior(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bootLoading
                  ? const _HeaderSkeleton()
                  : _HeaderCard(
                      user: user,
                      name: _name.text,
                      email: _email.text,
                      phone: _phone.text,
                      location: _address.text,
                      avatar: _avatar,
                      onPickAvatar: _pickAvatar,
                    ),
              const SizedBox(height: 18),
              const _SectionTitle(icon: Icons.edit, title: "بيانات الحساب"),
              const SizedBox(height: 10),
              _FormCard(
                child: _bootLoading
                    ? const _FormSkeleton()
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildField(
                              context,
                              controller: _name,
                              label: "الاسم الكامل",
                              validator: CustomTextFieldValidator.nullCheck,
                            ),
                            _buildField(
                              context,
                              controller: _email,
                              label: "البريد الإلكتروني",
                              readOnly: user.type == AuthenticationType.email.name ||
                                  user.type == AuthenticationType.google.name ||
                                  user.type == AuthenticationType.apple.name,
                            ),
                            _buildField(
                              context,
                              controller: _phone,
                              label: "رقم الجوال",
                              keyboardType: TextInputType.phone,
                              validator: CustomTextFieldValidator.phoneNumber,
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                  icon: Icons.location_on_outlined, title: "العناوين الجغرافية"),
              const SizedBox(height: 10),
              _FormCard(
                child: _bootLoading
                    ? const ShimmerBox(height: 120)
                    : DeliveryAddressSection(
                        loading: false,
                        address: _addressData,
                        onManageAddresses: () {
                          Navigator.of(context).pushNamed(Routes.adress);
                        },
                      ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                  icon: Icons.shield_outlined, title: "الخصوصية والإشعارات"),
              const SizedBox(height: 10),
              _FormCard(
                child: _bootLoading
                    ? const _FormSkeleton(lines: 2)
                    : Column(
                        children: [
                          _SwitchTile(
                            title: "الإشعارات",
                            subtitle: "تفعيل أو إيقاف الإشعارات",
                            value: _notifications,
                            onChanged: (v) {
                              HapticFeedback.lightImpact();
                              setState(() => _notifications = v);
                            },
                          ),
                          const SizedBox(height: 12),
                          _SwitchTile(
                            title: "إظهار بيانات الاتصال",
                            subtitle: "إخفاء معلومات الاتصال عن الإعلانات",
                            value: _showPersonal,
                            onChanged: (v) {
                              HapticFeedback.lightImpact();
                              setState(() => _showPersonal = v);
                            },
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

  Widget _buildField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    CustomTextFieldValidator? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label)
              .size(context.font.normal)
              .color(context.color.textDefaultColor),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: controller,
            isReadOnly: readOnly,
            validator: validator,
            keyboard: keyboardType,
            maxLine: maxLines,
            fillColor: context.color.secondaryColor,
            isCustomStyle: false,
            hintText: label,
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final UserModel user;
  final String name;
  final String email;
  final String phone;
  final String location;
  final File? avatar;
  final VoidCallback onPickAvatar;

  const _HeaderCard({
    required this.user,
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    required this.avatar,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.isNotEmpty ? name : (user.name ?? '');
    final displayEmail = email.isNotEmpty ? email : (user.email ?? '');
    final displayPhone = phone.isNotEmpty ? phone : (user.mobile ?? '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? .3 : .08,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 82,
                width: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.color.borderColor, width: 1.4),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatar != null
                    ? Image.file(avatar!, fit: BoxFit.cover)
                    : (HiveUtils.getUserDetails().profile ?? '').isNotEmpty
                        ? UiUtils.getImage(HiveUtils.getUserDetails().profile!, fit: BoxFit.cover)
                        : UiUtils.getSvg(AppIcons.defaultPersonLogo, fit: BoxFit.none, color: context.color.territoryColor),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onPickAvatar,
                  child: Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      color: context.color.territoryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.color.secondaryColor, width: 1.5),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName.isEmpty ? "..." : displayName)
                    .size(context.font.larger)
                    .bold()
                    .color(context.color.textDefaultColor),
                if (displayEmail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(displayEmail)
                      .size(context.font.small)
                      .color(context.color.textColorDark.withOpacity(.8)),
                ],
                if (displayPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(displayPhone)
                      .size(context.font.normal)
                      .color(context.color.textDefaultColor),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: context.color.textLightColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(location.isEmpty ? "غير محدد" : location)
                          .size(context.font.small)
                          .color(context.color.textColorDark.withOpacity(.8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;
  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.color.borderColor, width: 1),
      ),
      child: child,
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ShimmerBox(height: 140);
  }
}

class _FormSkeleton extends StatelessWidget {
  final int lines;
  const _FormSkeleton({this.lines = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(lines, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == lines - 1 ? 0 : 12),
          child: const ShimmerBox(height: 52),
        );
      }),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.color.secondaryColor.withOpacity(.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: context.color.textDefaultColor),
        ),
        const SizedBox(width: 10),
        Text(title).size(context.font.large).bold().color(context.color.textDefaultColor),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title)
                    .size(context.font.normal)
                    .bold()
                    .color(context.color.textDefaultColor),
                const SizedBox(height: 4),
                Text(subtitle)
                    .size(context.font.small)
                    .color(context.color.textColorDark.withOpacity(.7)),
              ],
            ),
          ),
          Switch(
            activeColor: context.color.territoryColor,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
