import 'package:flutter/material.dart';

import 'package:marib/ui/screens/auth/login_new/shared/auth_text_field.dart';
import 'package:marib/ui/screens/auth/login_new/shared/signup_new_view_model.dart';

class SignupStepVerification extends StatelessWidget {
  final SignupNewViewModel viewModel;
  final SignupNewUiState state;

  const SignupStepVerification({
    super.key,
    required this.viewModel,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = viewModel.phoneController.text.trim();

    return Column(
      key: const ValueKey('signup-verification'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify your account',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          phone.isEmpty
              ? 'Enter the 6-digit verification code.'
              : 'Enter the 6-digit code sent to +${state.dialCode}$phone.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: viewModel.otpController,
          focusNode: viewModel.otpFocus,
          label: 'Verification code',
          hint: '------',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onChanged: viewModel.onOtpChanged,
        ),
        const SizedBox(height: 24),
        _TermsAcceptance(
          accepted: state.termsAccepted,
          onChanged: viewModel.setTermsAccepted,
        ),
      ],
    );
  }
}

class _TermsAcceptance extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const _TermsAcceptance({
    required this.accepted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: accepted,
          onChanged: (value) => onChanged(value ?? false),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: textStyle?.copyWith(color: theme.colorScheme.onSurface),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: textStyle?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: textStyle?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}