import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/notifications/action_request_cubit.dart';
import 'package:marib/data/model/action_request.dart';
import 'package:marib/data/repositories/action_request_repository.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';

class ActionRequestRouteArgs {
  final String requestId;
  final String token;

  const ActionRequestRouteArgs({
    required this.requestId,
    required this.token,
  });
}

class ActionRequestDetailsScreen extends StatefulWidget {
  const ActionRequestDetailsScreen({super.key, this.args});

  static Route route(RouteSettings settings) {
    final args = settings.arguments;
    if (args is! ActionRequestRouteArgs) {
      return BlurredRouter(
        builder: (_) => const ActionRequestDetailsScreen(),
        settings: settings,
      );
    }

    return BlurredRouter(
      builder: (_) => BlocProvider(
        create: (_) => ActionRequestCubit(ActionRequestRepository()),
        child: ActionRequestDetailsScreen(args: args),
      ),
      settings: settings,
    );
  }

  final ActionRequestRouteArgs? args;

  @override
  State<ActionRequestDetailsScreen> createState() =>
      _ActionRequestDetailsScreenState();
}

class _ActionRequestDetailsScreenState
    extends State<ActionRequestDetailsScreen> {
  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args != null) {
      context.read<ActionRequestCubit>().load(args.requestId, args.token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        title: "action_request".translate(context),
        showBackButton: true,
      ),
      backgroundColor: Theme.of(context).colorScheme.primaryColor,
      body: BlocConsumer<ActionRequestCubit, ActionRequestState>(
        listener: (context, state) {
          if (state is ActionRequestFailure) {
            HelperUtils.showSnackBarMessage(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is ActionRequestLoading || state is ActionRequestInitial) {
            return Center(child: UiUtils.progress(width: 48, height: 48));
          }

          if (state is ActionRequestFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.message,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (state is ActionRequestSuccess) {
            return _buildSuccess(context, state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSuccess(
    BuildContext context,
    ActionRequestSuccess state,
  ) {
    final ActionRequestModel request = state.request;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DateFormat formatter = DateFormat.yMd().add_jm();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: colors.secondaryColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    label: "type".translate(context),
                    value: request.kind,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 8),
                  if (request.amount != null)
                    _buildDetailRow(
                      label: "amount".translate(context),
                      value:
                          '${request.amount!.toStringAsFixed(2)} ${request.currency ?? ''}',
                      textTheme: textTheme,
                    ),
                  if (request.entity != null) const SizedBox(height: 8),
                  if (request.entity != null)
                    _buildDetailRow(
                      label: "entity".translate(context),
                      value: '${request.entity} ${request.entityId ?? ''}',
                      textTheme: textTheme,
                    ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    label: "status".translate(context),
                    value: request.status,
                    textTheme: textTheme,
                  ),
                  if (request.dueAt != null) const SizedBox(height: 8),
                  if (request.dueAt != null)
                    _buildDetailRow(
                      label: "due_at".translate(context),
                      value: formatter.format(request.dueAt!),
                      textTheme: textTheme,
                    ),
                  if (request.expiresAt != null) const SizedBox(height: 8),
                  if (request.expiresAt != null)
                    _buildDetailRow(
                      label: "expires_at".translate(context),
                      value: formatter.format(request.expiresAt!),
                      textTheme: textTheme,
                    ),
                  if (request.meta != null && request.meta!.isNotEmpty)
                    const SizedBox(height: 12),
                  if (request.meta != null && request.meta!.isNotEmpty)
                    Text(
                      "details".translate(context),
                      style: textTheme.titleMedium,
                    ),
                  if (request.meta != null && request.meta!.isNotEmpty)
                    const SizedBox(height: 6),
                  if (request.meta != null && request.meta!.isNotEmpty)
                    ...request.meta!.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: _buildDetailRow(
                          label: entry.key,
                          value: entry.value.toString(),
                          textTheme: textTheme,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.performing || request.isCompleted
                  ? null
                  : () => _performRequest(state.request),
              child: state.performing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: UiUtils.progress(width: 20, height: 20),
                    )
                  : Text(
                      request.isCompleted
                          ? "completed".translate(context)
                          : "perform_request".translate(context),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required TextTheme textTheme,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label.firstUpperCase(),
            style: textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  void _performRequest(ActionRequestModel request) {
    final args = widget.args;
    if (args == null) return;
    context.read<ActionRequestCubit>().perform(args.requestId, args.token);
  }
}
