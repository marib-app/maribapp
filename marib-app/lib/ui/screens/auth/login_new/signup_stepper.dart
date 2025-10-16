import 'package:flutter/material.dart';

import 'package:marib/ui/screens/auth/login_new/shared/auth_action_button.dart';
import 'package:marib/ui/screens/auth/login_new/shared/auth_card_shell.dart';
import 'package:marib/ui/screens/auth/login_new/shared/auth_error_notice.dart';
import 'package:marib/ui/screens/auth/login_new/shared/auth_loading_overlay.dart';
import 'package:marib/ui/screens/auth/login_new/shared/auth_page_header.dart';
import 'package:marib/ui/screens/auth/login_new/shared/signup_new_view_model.dart';
import 'package:marib/ui/screens/auth/login_new/signup_step_account.dart';
import 'package:marib/ui/screens/auth/login_new/signup_step_contact.dart';
import 'package:marib/ui/screens/auth/login_new/signup_step_verification.dart';

class SignupStepper extends StatelessWidget {
  final SignupNewViewModel viewModel;

  const SignupStepper({
    super.key,
    required this.viewModel,
  });

  static const List<String> _stepTitles = <String>[
    'Account',
    'Profile',
    'Verification',
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SignupNewUiState>(
      valueListenable: viewModel,
      builder: (context, state, _) {
        return Scaffold(
          body: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthPageHeader(
                            title: 'Create your account',
                            subtitle:
                            'Complete the following quick steps to get started.',
                            trailing: CircleAvatar(
                              radius: 26,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Icon(
                                Icons.person_add_alt_1_rounded,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _StepHeader(currentStep: state.currentStep),
                          const SizedBox(height: 20),
                          if (state.errorMessage != null) ...[
                            AuthErrorNotice(message: state.errorMessage!),
                            const SizedBox(height: 16),
                          ],
                          if (state.infoMessage != null) ...[
                            AuthErrorNotice(
                              message: state.infoMessage!,
                              isWarning: true,
                            ),
                            const SizedBox(height: 16),
                          ],
                          AuthCardShell(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _buildStepContent(state),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _StepperControls(
                            viewModel: viewModel,
                            state: state,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AuthLoadingOverlay(isVisible: state.isProcessing),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepContent(SignupNewUiState state) {
    switch (state.currentStep) {
      case 0:
        return SignupStepAccount(viewModel: viewModel);
      case 1:
        return SignupStepContact(viewModel: viewModel, state: state);
      case 2:
        return SignupStepVerification(viewModel: viewModel, state: state);
      default:
        return SignupStepAccount(viewModel: viewModel);
    }
  }
}

class _StepHeader extends StatelessWidget {
  final int currentStep;

  const _StepHeader({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(SignupStepper._stepTitles.length, (index) {
        final bool isActive = index == currentStep;
        final bool isCompleted = index < currentStep;
        final ColorScheme colorScheme = theme.colorScheme;

        final Color background = isActive
            ? colorScheme.primary
            : isCompleted
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceVariant;
        final Color foreground = isActive
            ? colorScheme.onPrimary
            : isCompleted
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant;

        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(
                right: index == SignupStepper._stepTitles.length - 1 ? 0 : 8),

            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Step ${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground.withOpacity(0.8),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SignupStepper._stepTitles[index],
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _StepperControls extends StatelessWidget {
  final SignupNewViewModel viewModel;
  final SignupNewUiState state;

  const _StepperControls({
    required this.viewModel,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [];

    if (state.currentStep > 0) {
      actions.add(
        OutlinedButton(
          onPressed: state.isProcessing ? null : viewModel.goToPreviousStep,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: const Text('Back'),
        ),
      );
      actions.add(const SizedBox(height: 12));
    }

    final bool isLastStep = state.currentStep == 2;

    actions.add(
      AuthActionButton(
        label: isLastStep ? 'Create account' : 'Continue',
        onPressed: () {
          if (isLastStep) {
            viewModel.submit(context);
          } else {
            viewModel.goToNextStep(context);
          }
        },
        isLoading: state.isProcessing,
        enabled: isLastStep ? state.canSubmit : state.canContinue,
      ),
    );

    if (isLastStep) {
      actions.add(
        TextButton(
          onPressed: state.isProcessing ? null : () => viewModel.resendOtp(context),
          child: const Text('Resend code'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: actions,
    );
  }
}