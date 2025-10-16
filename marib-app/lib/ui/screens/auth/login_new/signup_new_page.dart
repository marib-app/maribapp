import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/repositories/auth_repository.dart';

import 'shared/signup_new_view_model.dart';
import 'signup_stepper.dart';

class SignupNewPage extends StatefulWidget {
  const SignupNewPage({
    super.key,
    this.initialAccountType,
    this.initialPhoneNumber,
    this.initialDialCode,
    this.fromSocialLogin = false,
    this.legacyArguments,
  });


  final int? initialAccountType;
  final String? initialPhoneNumber;
  final String? initialDialCode;
  final bool fromSocialLogin;
  final Map<String, dynamic>? legacyArguments;

  static Route<void> route(RouteSettings settings) {
    final parsed = _SignupRouteArguments.from(settings.arguments);

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => SignupNewPage(
        initialAccountType: parsed.selectedAccountType,
        initialPhoneNumber: parsed.phoneNumber,
        initialDialCode: parsed.dialCode,
        fromSocialLogin: parsed.fromSocialLogin,
        legacyArguments: parsed.rawArguments,
      ),
    );
  }

  @override
  State<SignupNewPage> createState() => _SignupNewPageState();
}

class _SignupNewPageState extends State<SignupNewPage> {
  late final SignupNewViewModel _viewModel;

  UserDetailsCubit? _resolveUserDetailsCubit() {
    try {
      return context.read<UserDetailsCubit>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final userDetails = _resolveUserDetailsCubit();

    _viewModel = SignupNewViewModel(
      authRepository: AuthRepository(),
      multiAuthRepository: MultiAuthRepository(),
      userDetailsCubit: userDetails,
      initialAccountType: widget.initialAccountType,
      initialPhoneNumber: widget.initialPhoneNumber,
      initialDialCode: widget.initialDialCode,
      fromSocialLogin: widget.fromSocialLogin,
      legacyArguments: widget.legacyArguments,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewModel.initialize(context);
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignupStepper(viewModel: _viewModel);
  }
}

class _SignupRouteArguments {
  final int? selectedAccountType;
  final String? phoneNumber;
  final String? dialCode;
  final bool fromSocialLogin;
  final Map<String, dynamic>? rawArguments;

  const _SignupRouteArguments({
    required this.selectedAccountType,
    required this.phoneNumber,
    required this.dialCode,
    required this.fromSocialLogin,
    required this.rawArguments,
  });

  factory _SignupRouteArguments.from(Object? arguments) {
    if (arguments is _SignupRouteArguments) {
      return arguments;
    }

    if (arguments is Map) {
      final map = Map<String, dynamic>.from(arguments as Map);
      final dynamic rawAccountType = map['selectedAccountType'];
      int? parsedAccountType;
      if (rawAccountType is int) {
        parsedAccountType = rawAccountType;
      } else if (rawAccountType is String) {
        parsedAccountType = int.tryParse(rawAccountType);
      }

      final String? phone = map['phoneNumber']?.toString();
      final String? rawDial = map['countryCode']?.toString();
      final bool fromSocial =
          (map['fromSocialLogin'] as bool?) ?? (map['isFromGoogleLogin'] as bool?) ?? false;

      return _SignupRouteArguments(
        selectedAccountType: parsedAccountType,
        phoneNumber: phone?.trim().isEmpty ?? true ? null : phone?.trim(),
        dialCode: rawDial?.trim().isEmpty ?? true ? null : rawDial?.trim(),
        fromSocialLogin: fromSocial,
        rawArguments: map,
      );
    }

    return const _SignupRouteArguments(
      selectedAccountType: null,
      phoneNumber: null,
      dialCode: null,
      fromSocialLogin: false,
      rawArguments: null,
    );
  }
}