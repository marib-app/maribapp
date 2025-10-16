import 'package:flutter/material.dart';

import 'package:marib/ui/screens/auth/login_new/shared/auth_text_field.dart';
import 'package:marib/ui/screens/auth/login_new/shared/signup_new_view_model.dart';

class SignupStepContact extends StatelessWidget {
  final SignupNewViewModel viewModel;
  final SignupNewUiState state;

  const SignupStepContact({
    super.key,
    required this.viewModel,
    required this.state,
  });

  static const Map<int, String> _accountTypes = <int, String>{
    1: 'Individual',
    2: 'Real estate',
    3: 'Business',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('signup-contact'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How can we reach you?',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: viewModel.phoneController,
          focusNode: viewModel.phoneFocus,
          label: 'Phone number',
          hint: 'Enter your phone number',
          keyboardType: TextInputType.phone,
          leading: _DialCodeButton(
            dialCode: state.dialCode,
            flagEmoji: state.flagEmoji,
            onTap: () => viewModel.selectCountry(context),
          ),
          textInputAction: TextInputAction.next,
          onChanged: viewModel.onPhoneChanged,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: viewModel.cityController,
          focusNode: viewModel.cityFocus,
          label: 'City (optional)',
          hint: 'Where are you located?',
          textInputAction: TextInputAction.done,
          onChanged: viewModel.onCityChanged,
        ),
        const SizedBox(height: 24),
        Text(
          'Select the account type that best describes you',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _accountTypes.entries.map((entry) {
            final bool selected = state.selectedAccountType == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) => viewModel.setAccountType(entry.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DialCodeButton extends StatelessWidget {
  final String dialCode;
  final String? flagEmoji;
  final VoidCallback onTap;

  const _DialCodeButton({
    required this.dialCode,
    required this.flagEmoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.12),
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