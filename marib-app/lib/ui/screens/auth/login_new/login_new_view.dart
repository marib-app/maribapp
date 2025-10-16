import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/auth/login_cubit.dart';
import 'package:marib/ui/screens/auth/login_new/shared/auth_action_button.dart';
import 'package:marib/ui/screens/auth/login_new/shared/auth_card_shell.dart';
import 'package:marib/ui/screens/auth/login_new/shared/auth_error_notice.dart';
import 'package:marib/ui/screens/auth/login_new/shared/auth_loading_overlay.dart';
import 'package:marib/ui/screens/auth/login_new/shared/auth_page_header.dart';
import 'package:marib/ui/screens/auth/login_new/shared/auth_shimmer.dart';
import 'package:marib/ui/screens/auth/login_new/shared/auth_text_field.dart';
import 'package:marib/ui/screens/auth/login_new/shared/login_new_view_model.dart';
import 'package:marib/utils/extensions/extensions.dart';

class LoginNewView extends StatelessWidget {
  final LoginNewViewModel viewModel;

  const LoginNewView({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<LoginCubit, LoginState>(
          listener: (context, state) =>
              viewModel.handleLoginState(context, state),
        ),
        BlocListener<AuthenticationCubit, AuthenticationState>(
          listener: (context, state) =>
              viewModel.handleAuthenticationState(context, state),
        ),
      ],
      child: ValueListenableBuilder<LoginNewUiState>(
        valueListenable: viewModel,
        builder: (context, state, _) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Stack(
              children: [
                SafeArea(
                  child: _LoginBody(viewModel: viewModel, state: state),
                ),
                AuthLoadingOverlay(isVisible: state.isProcessing),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoginBody extends StatelessWidget {
  final LoginNewViewModel viewModel;
  final LoginNewUiState state;

  const _LoginBody({
    required this.viewModel,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 720;
        final double horizontalPadding = isWide ? 48 : 20;

        final child = SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthPageHeader(
                    title: 'readytoserve'.translate(context),
                    subtitle: 'welcomeback'.translate(context),
                    trailing: CircleAvatar(
                      radius: 28,
                      backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.lock_open_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _LoginCard(viewModel: viewModel, state: state),
                  const SizedBox(height: 24),
                  _LoginFooter(viewModel: viewModel, state: state),
                ],
              ),
            ),
          ),
        );

        if (isWide) {
          return Align(
            alignment: Alignment.topCenter,
            child: child,
          );
        }
        return child;
      },
    );
  }
}

class _LoginCard extends StatelessWidget {
  final LoginNewViewModel viewModel;
  final LoginNewUiState state;

  const _LoginCard({
    required this.viewModel,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (state.enablePhone)
                ChoiceChip(
                  label: Text('phone'.translate(context)),
                  selected: state.usingPhoneInput,
                  onSelected: (_) => viewModel.switchIdentifierMode(true),
                ),
              if (state.enableEmail)
                ChoiceChip(
                  label: Text('email'.translate(context)),
                  selected: !state.usingPhoneInput,
                  onSelected: (_) => viewModel.switchIdentifierMode(false),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (state.errorMessage != null) ...[
            AuthErrorNotice(message: state.errorMessage!),
            const SizedBox(height: 20),
          ],
          if (state.infoMessage != null) ...[
            AuthErrorNotice(
              message: state.infoMessage!,
              isWarning: true,
            ),
            const SizedBox(height: 20),
          ],
          if (state.showIdentifierShimmer)
            const AuthShimmerPlaceholder()
          else
            AuthTextField(
              controller: viewModel.identifierController,
              focusNode: viewModel.identifierFocusNode,
              keyboardType: state.usingPhoneInput
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              label: state.usingPhoneInput
                  ? 'Phone number'
                  : 'Email address',
              hint: state.usingPhoneInput
                  ? 'Enter your phone number'
                  : 'Enter your email',
              leading: state.usingPhoneInput
                  ? _DialCodeChip(
                dialCode: state.dialCode,
                flagEmoji: state.flagEmoji,
                onTap: () => viewModel.selectCountry(context),
              )
                  : null,
              onChanged: viewModel.onIdentifierChanged,
              textInputAction: TextInputAction.next,
            ),
          const SizedBox(height: 20),
          if (!state.showOtpField) ...[
            AuthTextField(
              controller: viewModel.passwordController,
              focusNode: viewModel.passwordFocusNode,
              label: 'Password',
              hint: 'Enter your password',
              obscureText: state.obscurePassword,
              trailing: IconButton(
                onPressed: viewModel.togglePasswordVisibility,
                icon: Icon(
                  state.obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              onChanged: viewModel.onPasswordChanged,
              textInputAction:
              state.usingPhoneInput ? TextInputAction.done : TextInputAction.next,
            ),
          ] else ...[
            AuthTextField(
              controller: viewModel.otpController,
              focusNode: viewModel.otpFocusNode,
              label: 'Enter OTP',
              hint: '------',
              keyboardType: TextInputType.number,
              onChanged: viewModel.onOtpChanged,
              textInputAction: TextInputAction.done,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!state.showOtpField)
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    Routes.forgotPassword,
                  ),
                  child: const Text('Forgot password?'),
                )
              else
                TextButton(
                  onPressed: () => viewModel.startOtpFlow(context),
                  child: const Text('Resend code'),
                ),
              if (state.enablePhone && !state.showOtpField)
                TextButton(
                  onPressed: viewModel.canRequestOtp
                      ? () => viewModel.startOtpFlow(context)
                      : null,
                  child: const Text('Send OTP'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AuthActionButton(
            label: state.showOtpField
                ? 'Verify & continue'
                : 'login'.translate(context),
            onPressed: () => viewModel.submitPrimary(context),
            isLoading: state.isProcessing,
            enabled: state.canSubmit,
          ),
        ],
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  final LoginNewViewModel viewModel;
  final LoginNewUiState state;

  const _LoginFooter({
    required this.viewModel,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<Widget> socialButtons = [];

    if (state.enableGoogle) {
      socialButtons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: state.isProcessing ? null : viewModel.loginWithGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded),
            label: const Text('Google'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      );
    }

    if (state.enableApple) {
      if (socialButtons.isNotEmpty) {
        socialButtons.add(const SizedBox(width: 12));
      }
      socialButtons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: state.isProcessing ? null : viewModel.loginWithApple,
            icon: const Icon(Icons.apple),
            label: const Text('Apple'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (socialButtons.isNotEmpty) ...[
          Text(
            'Or continue with',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: socialButtons),
          const SizedBox(height: 24),
        ],
        TextButton(
          onPressed: () => viewModel.goToSignup(context),
          child: const Text('Create a new account'),
        ),
      ],
    );
  }
}

class _DialCodeChip extends StatelessWidget {
  final String dialCode;
  final String? flagEmoji;
  final VoidCallback onTap;

  const _DialCodeChip({
    required this.dialCode,
    required this.flagEmoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flagEmoji != null) ...[
              Text(
                flagEmoji!,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
            ],
            Text('+$dialCode'),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }
}