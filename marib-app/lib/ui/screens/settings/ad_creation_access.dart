import 'package:collection/collection.dart';
import 'package:collection/collection.dart';
import 'package:marib/data/model/user_model.dart';
import 'package:marib/utils/constant.dart';

/// Represents a normalized launch target for the ad creation wizard.
class AdCreationTarget {
  const AdCreationTarget({
    required this.type,
    required this.interfaceType,
    required this.allowedCategoryIds,
    this.initialCategoryIds = const <int>[],
  });

  final AdCreationTargetType type;
  final String interfaceType;
  final Set<int> allowedCategoryIds;
  final List<int> initialCategoryIds;
}

/// High-level categories the user can create listings for.
enum AdCreationTargetType {
  publicAudience,
  realEstate,
  store,
  shein,
  computer,
}

/// Bundle of data shared between the launcher and the wizard.
class AdCreationScope {
  const AdCreationScope({
    required this.accountTypeCode,
    required this.permittedDelegateSections,
    required this.blockedDelegateSections,
    required this.targets,
  });

  final String? accountTypeCode;
  final Set<String> permittedDelegateSections;
  final Set<String> blockedDelegateSections;
  final List<AdCreationTarget> targets;

  bool get hasMultipleTargets => targets.length > 1;
  bool get hasTargets => targets.isNotEmpty;
}

/// Resolves the destinations a user may access in the ad creation wizard.
AdCreationScope resolveAdCreationScope({
  UserModel? user,
  Iterable<String> permittedDelegateSections = const <String>[],
  Iterable<String> blockedDelegateSections = const <String>[],
}) {
  final String? accountTypeCode = _resolveAccountTypeCode(user);
  final _AccountKind accountKind = _resolveAccountKind(user);
  final Set<int> storeCategoryIds = _extractStoreCategoryIds(user);

  final Set<String> permittedSections =
  _normalizeSectionSet(permittedDelegateSections);
  final Set<String> blockedSections =
  _normalizeSectionSet(blockedDelegateSections);

  final List<AdCreationTarget> delegateTargets = permittedSections
      .map((String section) =>
      _buildDelegateTarget(section: section, storeCategoryIds: storeCategoryIds))
      .whereNotNull()
      .toList(growable: false);

  if (delegateTargets.isNotEmpty) {
    return AdCreationScope(
      accountTypeCode: accountTypeCode,
      permittedDelegateSections: permittedSections,
      blockedDelegateSections: blockedSections,
      targets: delegateTargets,
    );
  }

  final List<AdCreationTarget> accountTargets =
  _buildAccountTargets(accountKind, storeCategoryIds);

  if (accountTargets.isNotEmpty) {
    return AdCreationScope(
      accountTypeCode: accountTypeCode,
      permittedDelegateSections: permittedSections,
      blockedDelegateSections: blockedSections,
      targets: accountTargets,
    );
  }

  // Fallback: allow public audience listings if nothing else matched.
  return AdCreationScope(
    accountTypeCode: accountTypeCode,
    permittedDelegateSections: permittedSections,
    blockedDelegateSections: blockedSections,
    targets: <AdCreationTarget>[_buildPublicAudienceTarget()],
  );
}

AdCreationTarget? _buildDelegateTarget({
  required String section,
  required Set<int> storeCategoryIds,
}) {
  switch (section) {
    case 'shein':
      return AdCreationTarget(
        type: AdCreationTargetType.shein,
        interfaceType: 'shein_products',
        allowedCategoryIds: <int>{Constant.sheinRootCategoryId},
        initialCategoryIds: <int>[Constant.sheinRootCategoryId],
      );
    case 'computer':
      return AdCreationTarget(
        type: AdCreationTargetType.computer,
        interfaceType: 'computer_section',
        allowedCategoryIds: <int>{Constant.computerRootCategoryId},
        initialCategoryIds: <int>[Constant.computerRootCategoryId],
      );
    case 'store':
      final Set<int> allowed = _normalizeCategorySet(storeCategoryIds);
      if (allowed.isEmpty) {
        allowed.add(Constant.storeRootCategoryId);
      } else {
        allowed.add(Constant.storeRootCategoryId);
      }
      return AdCreationTarget(
        type: AdCreationTargetType.store,
        interfaceType: 'store_products',
        allowedCategoryIds: allowed,
        initialCategoryIds: allowed.length == 1
            ? allowed.toList(growable: false)
            : <int>[Constant.storeRootCategoryId],
      );
    default:
      return null;
  }
}

List<AdCreationTarget> _buildAccountTargets(
    _AccountKind accountKind, Set<int> storeCategoryIds) {
  switch (accountKind) {
    case _AccountKind.individual:
      return <AdCreationTarget>[_buildPublicAudienceTarget()];
    case _AccountKind.realEstate:
      return <AdCreationTarget>[_buildRealEstateTarget()];
    case _AccountKind.commercial:
      return <AdCreationTarget>[
        _buildStoreTarget(storeCategoryIds: storeCategoryIds)
      ];
    case _AccountKind.unknown:
      return const <AdCreationTarget>[];
  }
}

AdCreationTarget _buildPublicAudienceTarget() {
  return AdCreationTarget(
    type: AdCreationTargetType.publicAudience,
    interfaceType: 'public_ads',
    allowedCategoryIds: <int>{Constant.publicRootCategoryId},
    initialCategoryIds: <int>[Constant.publicRootCategoryId],
  );
}

AdCreationTarget _buildRealEstateTarget() {
  return AdCreationTarget(
    type: AdCreationTargetType.realEstate,
    interfaceType: 'real_estate_services',
    allowedCategoryIds: <int>{Constant.realEstateRootCategoryId},
    initialCategoryIds: <int>[Constant.realEstateRootCategoryId],
  );
}

AdCreationTarget _buildStoreTarget({required Set<int> storeCategoryIds}) {
  final Set<int> allowed = _normalizeCategorySet(storeCategoryIds);
  allowed.add(Constant.storeRootCategoryId);

  final List<int> initialPath;
  if (allowed.length == 1) {
    initialPath = allowed.toList(growable: false);
  } else {
    initialPath = <int>[Constant.storeRootCategoryId];
  }

  return AdCreationTarget(
    type: AdCreationTargetType.store,
    interfaceType: 'store_products',
    allowedCategoryIds: allowed,
    initialCategoryIds: initialPath,
  );
}

Set<String> _normalizeSectionSet(Iterable<String> raw) {
  final Set<String> normalized = <String>{};
  for (final String value in raw) {
    final String trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      continue;
    }
    normalized.add(trimmed);
  }
  return normalized;
}

Set<int> _normalizeCategorySet(Iterable<int> raw) {
  final Set<int> normalized = <int>{};
  for (final int value in raw) {
    if (value <= 0) {
      continue;
    }
    normalized.add(value);
  }
  return normalized;
}

_AccountKind _resolveAccountKind(UserModel? user) {
  final dynamic raw = user?.userType ?? user?.additionalInfo?['account_type'];
  final int? code = _tryParseInt(raw);
  switch (code) {
    case 1:
      return _AccountKind.individual;
    case 2:
      return _AccountKind.realEstate;
    case 3:
      return _AccountKind.commercial;
    default:
      return _AccountKind.unknown;
  }
}

String? _resolveAccountTypeCode(UserModel? user) {
  final dynamic raw = user?.userType ??
      user?.additionalInfo?['account_type'] ??
      user?.additionalInfo?['accountType'];
  final int? numeric = _tryParseInt(raw);
  if (numeric != null) {
    return numeric.toString();
  }
  if (raw is String) {
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (raw is num) {
    return raw.toInt().toString();
  }
  return null;
}

int? _tryParseInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }
  return null;
}

Set<int> _extractStoreCategoryIds(UserModel? user) {
  final dynamic additional = user?.additionalInfo;
  if (additional is Map<String, dynamic>) {
    return _parseCategoryIds(additional['categories']);
  }
  return <int>{};
}

Set<int> _parseCategoryIds(dynamic raw) {
  final Set<int> ids = <int>{};

  void consume(dynamic value) {
    if (value == null) {
      return;
    }
    if (value is int) {
      if (value > 0) {
        ids.add(value);
      }
      return;
    }
    if (value is num) {
      final int candidate = value.toInt();
      if (candidate > 0) {
        ids.add(candidate);
      }
      return;
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return;
      }
      final Iterable<String> tokens =
      trimmed.split(RegExp(r'[\s,]+')).where((String token) => token.isNotEmpty);
      if (tokens.length > 1) {
        for (final String token in tokens) {
          consume(token);
        }
        return;
      }
      final int? parsed = int.tryParse(trimmed);
      if (parsed != null && parsed > 0) {
        ids.add(parsed);
      }
      return;
    }
    if (value is Iterable) {
      for (final dynamic entry in value) {
        consume(entry);
      }
      return;
    }
    if (value is Map) {
      for (final dynamic entry in value.values) {
        consume(entry);
      }
    }
  }

  consume(raw);
  return ids;
}

enum _AccountKind { individual, realEstate, commercial, unknown }