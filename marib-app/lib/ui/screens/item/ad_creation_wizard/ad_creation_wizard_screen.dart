import 'dart:async';

import 'package:flutter/material.dart';

import 'ad_creation_wizard_models.dart';
import 'custom_fields_step.dart';
import 'main_category_step.dart';
import 'media_step.dart';
import 'review_step.dart';
import 'sub_category_step.dart';
import 'text_details_step.dart';

class AdCreationWizardArguments {
  const AdCreationWizardArguments({
    this.draftId,
    this.interfaceType,
    this.initialCategoryIds,
    this.accountTypeCode,
    this.permittedDelegateSections,
    this.blockedDelegateSections,
    this.allowedCategoryIds,
  });

  final String? draftId;
  final String? interfaceType;
  final List<int>? initialCategoryIds;
  final String? accountTypeCode;
  final Set<String>? permittedDelegateSections;
  final Set<String>? blockedDelegateSections;
  final Set<int>? allowedCategoryIds;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (draftId != null) 'draftId': draftId,
      if (interfaceType != null) 'interfaceType': interfaceType,
      if (initialCategoryIds != null && initialCategoryIds!.isNotEmpty)
        'initialCategoryIds': List<int>.from(initialCategoryIds!),
      if (accountTypeCode != null) 'accountTypeCode': accountTypeCode,
      if (permittedDelegateSections != null)
        'permittedDelegateSections': permittedDelegateSections!.toList(),
      if (blockedDelegateSections != null)
        'blockedDelegateSections': blockedDelegateSections!.toList(),
      if (allowedCategoryIds != null)
        'allowedCategoryIds': allowedCategoryIds!.toList(),
    };
  }

  static AdCreationWizardArguments fromMap(Map<String, dynamic> map) {
    return AdCreationWizardArguments(
      draftId: _stringOrNull(map['draftId'] ?? map['draft_id']),
      interfaceType: _stringOrNull(map['interfaceType'] ?? map['interface_type']),
      initialCategoryIds: _listOfInts(map['initialCategoryIds'] ?? map['categoryIds'] ?? map['category_ids']),
      accountTypeCode: _stringOrNull(map['accountTypeCode'] ?? map['account_type_code']),
      permittedDelegateSections:
      _stringSetOf(map['permittedDelegateSections'] ?? map['permitted_sections']),
      blockedDelegateSections:
      _stringSetOf(map['blockedDelegateSections'] ?? map['blocked_sections']),
      allowedCategoryIds: _intSetOf(map['allowedCategoryIds'] ?? map['allowed_category_ids']),
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString();
    return text.isEmpty ? null : text;
  }

  static List<int>? _listOfInts(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Iterable) {
      return value.map((dynamic e) => int.tryParse(e.toString()) ?? -1).where((int v) => v > 0).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value
          .split(RegExp(r'[\s,]+'))
          .map((String token) => int.tryParse(token) ?? -1)
          .where((int v) => v > 0)
          .toList();
    }
    final int? parsed = int.tryParse(value.toString());
    return parsed == null || parsed <= 0 ? null : <int>[parsed];
  }

  static Set<String>? _stringSetOf(dynamic value) {
    if (value == null) {
      return null;
    }
    final Set<String> results = <String>{};
    if (value is Iterable) {
      for (final dynamic entry in value) {
        final String text = entry.toString().trim();
        if (text.isNotEmpty) {
          results.add(text);
        }
      }
      return results;
    }
    if (value is String) {
      final List<String> tokens = value.split(RegExp(r'[\s,]+'));
      for (final String token in tokens) {
        final String trimmed = token.trim();
        if (trimmed.isNotEmpty) {
          results.add(trimmed);
        }
      }
      return results;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : <String>{text};
  }

  static Set<int>? _intSetOf(dynamic value) {
    if (value == null) {
      return null;
    }
    final Set<int> results = <int>{};
    if (value is Iterable) {
      for (final dynamic entry in value) {
        final int? parsed = int.tryParse(entry.toString());
        if (parsed != null && parsed > 0) {
          results.add(parsed);
        }
      }
      return results;
    }
    if (value is String) {
      final List<String> tokens = value.split(RegExp(r'[\s,]+'));
      for (final String token in tokens) {
        final int? parsed = int.tryParse(token);
        if (parsed != null && parsed > 0) {
          results.add(parsed);
        }
      }
      return results;
    }
    final int? parsed = int.tryParse(value.toString());
    return parsed == null || parsed <= 0 ? null : <int>{parsed};
  }
}

class AdCreationWizardScreen extends StatefulWidget {
  const AdCreationWizardScreen({
    super.key,
    this.draftId,
    this.interfaceType,
    this.initialCategoryIds,
    this.accountTypeCode,
    this.permittedDelegateSections,
    this.blockedDelegateSections,
    this.allowedCategoryIds,
    this.arguments,
    this.routeSettings,
    this.routeArgumentMap,
    this.persistDrafts = false,
  });

  final String? draftId;
  final String? interfaceType;
  final List<int>? initialCategoryIds;
  final String? accountTypeCode;
  final Set<String>? permittedDelegateSections;
  final Set<String>? blockedDelegateSections;
  final Set<int>? allowedCategoryIds;
  final AdCreationWizardArguments? arguments;
  final RouteSettings? routeSettings;
  final Map<String, dynamic>? routeArgumentMap;
  final bool persistDrafts;

  static Route<void> route(RouteSettings settings) {
    final Map<String, dynamic>? argumentMap =
    settings.arguments is Map<String, dynamic> ? settings.arguments as Map<String, dynamic> : null;
    final AdCreationWizardArguments arguments =
    argumentMap == null ? const AdCreationWizardArguments() : AdCreationWizardArguments.fromMap(argumentMap);

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => AdCreationWizardScreen(
        draftId: arguments.draftId,
        interfaceType: arguments.interfaceType,
        initialCategoryIds: arguments.initialCategoryIds,
        accountTypeCode: arguments.accountTypeCode,
        permittedDelegateSections: arguments.permittedDelegateSections,
        blockedDelegateSections: arguments.blockedDelegateSections,
        allowedCategoryIds: arguments.allowedCategoryIds,
        arguments: arguments,
        routeSettings: settings,
        routeArgumentMap: argumentMap,
      ),
    );
  }

  @override
  State<AdCreationWizardScreen> createState() => _AdCreationWizardScreenState();
}

class _AdCreationWizardScreenState extends State<AdCreationWizardScreen> {
  late final PageController _pageController;
  late final AdCreationWizardController _controller;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _controller = AdCreationWizardController(
      draftId: widget.draftId ?? widget.arguments?.draftId,
      interfaceType: widget.interfaceType ?? widget.arguments?.interfaceType,
      initialCategoryIds: widget.initialCategoryIds ?? widget.arguments?.initialCategoryIds,
      accountTypeCode: widget.accountTypeCode ?? widget.arguments?.accountTypeCode,
      permittedSections: widget.permittedDelegateSections ?? widget.arguments?.permittedDelegateSections,
      blockedSections: widget.blockedDelegateSections ?? widget.arguments?.blockedDelegateSections,
      allowedCategoryIds: widget.allowedCategoryIds ?? widget.arguments?.allowedCategoryIds,
      persistDrafts: widget.persistDrafts,
    );
    unawaited(_controller.initialize());
    _pageController = PageController(initialPage: _controller.currentStepIndex);
    _controller.addListener(_handleControllerUpdated);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.removeListener(_handleControllerUpdated);
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleControllerUpdated() {
    if (!_pageController.hasClients) {
      return;
    }
    final int targetPage = _controller.currentStepIndex;
    final double? current = _pageController.page;
    if (current != null && current.round() == targetPage) {
      return;
    }
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _handleDraftChanged() {
    _controller.markDraftChanged();
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _controller.autoSaveCurrentStep();
    });
    setState(() {});
  }

  void _handleNext() {
    _controller.goToNextStep();
    _scheduleImmediateSave();
  }

  void _handleBack() {
    _controller.goToPreviousStep();
    _scheduleImmediateSave();
  }

  void _scheduleImmediateSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _controller.autoSaveCurrentStep();
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء إعلان جديد'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          return Column(
            children: <Widget>[
              _ProgressHeader(controller: _controller),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    MainCategoryStep(
                      controller: _controller,
                      onNext: _handleNext,
                      onDraftChanged: _handleDraftChanged,
                    ),
                    SubCategoryStep(
                      controller: _controller,
                      onNext: _handleNext,
                      onBack: _handleBack,
                      onDraftChanged: _handleDraftChanged,
                    ),
                    CustomFieldsStep(
                      controller: _controller,
                      onBack: _handleBack,
                      onNext: _handleNext,
                      onDraftChanged: _handleDraftChanged,
                    ),
                    MediaStep(
                      controller: _controller,
                      onBack: _handleBack,
                      onNext: _handleNext,
                      onDraftChanged: _handleDraftChanged,
                    ),
                    TextDetailsStep(
                      controller: _controller,
                      onBack: _handleBack,
                      onNext: _handleNext,
                      onDraftChanged: _handleDraftChanged,
                    ),
                    ReviewStep(controller: _controller),
                  ],
                ),
              ),
              _AutoSaveStatus(controller: _controller),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.controller});

  final AdCreationWizardController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int stepIndex = controller.currentStepIndex + 1;
    final int totalSteps = AdCreationStep.values.length;
    final double progress = stepIndex / totalSteps;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
          const SizedBox(height: 8),
          Text(
            'الخطوة $stepIndex من $totalSteps: ${controller.currentStep.label}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _AutoSaveStatus extends StatelessWidget {
  const _AutoSaveStatus({required this.controller});

  final AdCreationWizardController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> messages = <Widget>[];

    if (controller.isSaving) {
      messages.add(Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('جارٍ الحفظ التلقائي...', style: theme.textTheme.bodySmall),
        ],
      ));
    } else if (controller.hasPendingChanges) {
      messages.add(Row(
        children: <Widget>[
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: 6),
          Text('هناك تغييرات غير محفوظة بعد.', style: theme.textTheme.bodySmall),
        ],
      ));
    } else if (controller.lastAutoSave != null) {
      final String formatted = _formatTimestamp(controller.lastAutoSave!);
      messages.add(Row(
        children: <Widget>[
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 6),
          Text('تم الحفظ التلقائي $formatted.', style: theme.textTheme.bodySmall),
        ],
      ));
    }

    if (controller.autoSaveError != null) {
      messages.add(Row(
        children: <Widget>[
          const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'تعذر حفظ المسودة: ${controller.autoSaveError}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ));
    } else if (controller.hasOfflineDraft) {
      messages.add(Row(
        children: <Widget>[
          const Icon(Icons.cloud_off, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'سيتم مزامنة التغييرات عند توفر الاتصال بالإنترنت.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ));
    }

    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final Duration diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) {
      return 'منذ لحظات';
    }
    if (diff.inHours < 1) {
      return 'منذ ${diff.inMinutes} دقيقة';
    }
    if (diff.inDays < 1) {
      return 'منذ ${diff.inHours} ساعة';
    }
    return 'في ${timestamp.toLocal().toString().split('.').first}';
  }
}