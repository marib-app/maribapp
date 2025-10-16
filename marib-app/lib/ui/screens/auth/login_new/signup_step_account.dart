import 'package:flutter/material.dart';

import 'package:marib/ui/screens/auth/login_new/shared/auth_text_field.dart';
import 'package:marib/ui/screens/auth/login_new/shared/signup_new_view_model.dart';

class SignupStepAccount extends StatelessWidget {
  final SignupNewViewModel viewModel;

  const SignupStepAccount({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('signup-account'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tell us about you',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: viewModel.fullNameController,
          focusNode: viewModel.nameFocus,
          label: 'Full name',
          hint: 'Enter your full name',
          textInputAction: TextInputAction.next,
          onChanged: viewModel.onNameChanged,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: viewModel.emailController,
          focusNode: viewModel.emailFocus,
          label: 'Email address',
          hint: 'Enter your email address',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: viewModel.onEmailChanged,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: viewModel.passwordController,
          focusNode: viewModel.passwordFocus,
          label: 'Password',
          hint: 'Create a secure password',
          obscureText: viewModel.value.obscurePassword,
          trailing: IconButton(
            onPressed: viewModel.togglePasswordVisibility,
            icon: Icon(
              viewModel.value.obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          textInputAction: TextInputAction.next,
          onChanged: viewModel.onPasswordChanged,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: viewModel.confirmPasswordController,
          focusNode: viewModel.confirmPasswordFocus,
          label: 'Confirm password',
          hint: 'Re-enter your password',
          obscureText: viewModel.value.obscureConfirmPassword,
          trailing: IconButton(
            onPressed: viewModel.toggleConfirmVisibility,
            icon: Icon(
              viewModel.value.obscureConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          textInputAction: TextInputAction.done,
          onChanged: viewModel.onConfirmPasswordChanged,
        ),
      ],
    );
  }
}