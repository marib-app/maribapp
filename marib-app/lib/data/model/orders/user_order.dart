import 'package:meta/meta.dart';

@immutable
class UserOrder {
  const UserOrder({
    required this.id,
    this.code,
    this.createdAt,
    this.status,
    this.paymentStatus,
    this.deliveryStatus,
    this.totalFormatted,
    this.totalValue,
    this.currency,
    this.address,
    this.items = const <OrderLine>[],
    this.timeline = const <OrderTimelineEntry>[],
    this.statusTimestamps,
    this.paymentSummary,
    this.deliveryPaymentSummary,
    this.paymentIntent,
    this.paymentIntentId,
    this.statusDisplay,
    this.statusReserveOptions,
    this.actions = const OrderActions(),
    this.raw,
  });

  final String id;
  final String? code;
  final DateTime? createdAt;
  final String? status;
  final String? paymentStatus;
  final String? deliveryStatus;
  final String? totalFormatted;
  final num? totalValue;
  final String? currency;
  final String? address;
  final List<OrderLine> items;
  final List<OrderTimelineEntry> timeline;
  final Map<String, dynamic>? statusTimestamps;
  final Map<String, dynamic>? paymentSummary;
  final Map<String, dynamic>? deliveryPaymentSummary;
  final Map<String, dynamic>? paymentIntent;
  final String? paymentIntentId;
  final OrderStatusDisplay? statusDisplay;
  final OrderStatusReserveOptions? statusReserveOptions;
  final OrderActions actions;
  final Map<String, dynamic>? raw;

  String get displayLabel =>
      (code != null && code!.trim().isNotEmpty) ? code!.trim() : (id.isNotEmpty ? '#$id' : 'طلب');

  String get statusLabel =>
      (status != null && status!.trim().isNotEmpty) ? status!.trim() : 'قيد المراجعة';

  String get paymentLabel =>
      (paymentStatus != null && paymentStatus!.trim().isNotEmpty) ? paymentStatus!.trim() : '—';

  String get deliveryLabel =>
      (deliveryStatus != null && deliveryStatus!.trim().isNotEmpty) ? deliveryStatus!.trim() : '—';

  String get totalLabel {
    if (totalFormatted != null && totalFormatted!.trim().isNotEmpty) {
      return totalFormatted!.trim();
    }

    if (totalValue != null) {
      final String value = _formatNumber(totalValue!);
      final String suffix =
      (currency != null && currency!.trim().isNotEmpty) ? ' ${currency!.trim()}' : '';
      return '$value$suffix';
    }

    return '—';
  }

  String? get addressLabel =>
      (address != null && address!.trim().isNotEmpty) ? address!.trim() : null;

  bool matchesIdentifier(String identifier) {
    if (identifier.isEmpty) return false;
    final String normalized = identifier.trim().toLowerCase();
    return displayLabel.toLowerCase() == normalized ||
        id.toLowerCase() == normalized ||
        (code != null && code!.trim().toLowerCase() == normalized);
  }

  static UserOrder fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(json);

    final String id =
        _asString(map['id'] ?? map['order_id'] ?? map['reference'] ?? map['code'] ?? '') ?? '';

    final String? code =
    _asString(map['code'] ?? map['order_code'] ?? map['reference'] ?? map['invoice']);

    final DateTime? createdAt = _parseDateTime(
      map['created_at'] ?? map['createdAt'] ?? map['order_date'] ?? map['date'],
    );

    final String? status = _asString(map['status'] ?? map['order_status'] ?? map['state']);
    final String? paymentStatus =
    _asString(map['payment_status'] ?? map['paymentState'] ?? map['payment_state']);
    final String? deliveryStatus = _asString(
      map['delivery_status'] ?? map['shipping_status'] ?? map['logistics_status'],
    );

    final String? totalFormatted = _asString(
      map['total_formatted'] ?? map['total_display'] ?? map['grand_total_formatted'] ??
          map['total_text'],
    );

    final num? totalValue = _asNum(
      map['total'] ?? map['total_amount'] ?? map['grand_total'] ?? map['amount_due'],
    );

    final String? currency = _asString(
      map['currency'] ?? map['currency_code'] ?? map['currency_symbol'],
    );

    final String? address = _formatAddress(
      map['shipping_address'] ?? map['address'] ?? map['delivery_address'] ?? map['customer'],
    );

    final List<OrderLine> lines = _parseLines(
      map['items'] ?? map['order_items'] ?? map['products'] ?? map['lines'],
      currency,
    );

    final List<OrderTimelineEntry> timeline = _parseTimeline(
      map['timeline'] ?? map['history'] ?? map['status_history'] ?? map['steps'],
    );


    final Map<String, dynamic>? statusTimestamps = _mapify(
      map['status_timestamps'] ?? map['statusTimestamps'],
    );

    final Map<String, dynamic>? paymentSummary = _mapify(
      map['payment_summary'] ?? map['paymentSummary'],
    );

    final Map<String, dynamic>? deliveryPaymentSummary = _mapify(
      map['delivery_payment_summary'] ?? map['deliveryPaymentSummary'],
    );

    final dynamic paymentIntentRaw = map['payment_intent'] ?? map['paymentIntent'];
    final Map<String, dynamic>? paymentIntent = _mapify(paymentIntentRaw);
    final String? paymentIntentId = _asString(
      paymentIntent?['id'] ??
          paymentIntent?['reference'] ??
          paymentIntent?['payment_intent'] ??
          (paymentIntentRaw is String ? paymentIntentRaw : null),
    );

    final Map<String, dynamic>? statusDisplayRaw = _mapify(
      map['status_display'] ??
          map['statusDisplay'] ??
          map['order_status_display'] ??
          map['status_display_data'],
    );
    final OrderStatusDisplay? statusDisplay =
    statusDisplayRaw != null ? OrderStatusDisplay.fromJson(statusDisplayRaw) : null;

    final Map<String, dynamic>? statusReserveRaw = _mapify(
      map['status_reserve_options'] ??
          map['statusReserveOptions'] ??
          map['order_status_reserve'] ??
          map['status_reserve'],
    );
    final OrderStatusReserveOptions? statusReserveOptions =
    statusReserveRaw != null ? OrderStatusReserveOptions.fromJson(statusReserveRaw) : null;

    final Map<String, dynamic>? actionsRaw = _mapify(
      map['actions'] ??
          map['order_actions'] ??
          map['orderActions'] ??
          map['available_actions'],
    );
    final OrderActions actions = OrderActions.fromJson(actionsRaw);


    return UserOrder(
      id: id,
      code: code,
      createdAt: createdAt,
      status: status,
      paymentStatus: paymentStatus,
      deliveryStatus: deliveryStatus,
      totalFormatted: totalFormatted,
      totalValue: totalValue,
      currency: currency,
      address: address,
      items: lines,
      timeline: timeline,
      statusTimestamps: statusTimestamps,
      paymentSummary: paymentSummary,
      deliveryPaymentSummary: deliveryPaymentSummary,
      paymentIntent: paymentIntent,
      paymentIntentId: paymentIntentId,
      statusDisplay: statusDisplay,
      statusReserveOptions: statusReserveOptions,
      actions: actions,
      raw: map,
    );
  }


  List<OrderTimelineEntry> get effectiveTimeline {
    if (timeline.isNotEmpty) {
      return timeline;
    }

    if (statusTimestamps == null || statusTimestamps!.isEmpty) {
      return const <OrderTimelineEntry>[];
    }

    final List<OrderTimelineEntry> derived = statusTimestamps!.entries.map((entry) {
      final dynamic value = entry.value;
      final Map<String, dynamic> normalized = value is Map
          ? Map<String, dynamic>.from(value as Map)
          : <String, dynamic>{
        'status': entry.key,
        'timestamp': value,
      };
      normalized.putIfAbsent('label', () => entry.key);
      return OrderTimelineEntry.fromJson(normalized);
    }).toList();

    derived.sort((OrderTimelineEntry a, OrderTimelineEntry b) {
      final DateTime? aTime = a.timestamp;
      final DateTime? bTime = b.timestamp;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return aTime.compareTo(bTime);
    });

    return derived;
  }


  static List<OrderLine> _parseLines(dynamic payload, String? currency) {
    if (payload == null) return const <OrderLine>[];
    if (payload is List) {
      return payload
          .map(_mapify)
          .whereType<Map<String, dynamic>>()
          .map((map) => OrderLine.fromJson(map, currency: currency))
          .toList();
    }

    if (payload is Map) {
      return payload.values
          .map(_mapify)
          .whereType<Map<String, dynamic>>()
          .map((map) => OrderLine.fromJson(map, currency: currency))
          .toList();
    }

    return const <OrderLine>[];
  }

  static List<OrderTimelineEntry> _parseTimeline(dynamic payload) {
    if (payload == null) return const <OrderTimelineEntry>[];
    if (payload is List) {
      return payload
          .map(_mapify)
          .whereType<Map<String, dynamic>>()
          .map(OrderTimelineEntry.fromJson)
          .toList();
    }

    if (payload is Map) {
      return payload.values
          .map(_mapify)
          .whereType<Map<String, dynamic>>()
          .map(OrderTimelineEntry.fromJson)
          .toList();
    }

    return const <OrderTimelineEntry>[];
  }

  static Map<String, dynamic>? _mapify(dynamic source) {
    if (source is Map<String, dynamic>) return source;
    if (source is Map) return Map<String, dynamic>.from(source as Map);
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return null;
  }

  static num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final String normalized = value.replaceAll(',', '').trim();
      return num.tryParse(normalized);
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      if (value.toString().length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      try {
        return DateTime.parse(trimmed).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String? _formatAddress(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      return value
          .map(_asString)
          .whereType<String>()
          .map((e) => e.trim())
          .where((element) => element.isNotEmpty)
          .join(', ');
    }
    if (value is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(value as Map);
      final candidates = <String?>[
        _asString(map['label'] ?? map['address'] ?? map['street'] ?? map['line']),
        _asString(map['city'] ?? map['state'] ?? map['region']),
        _asString(map['country']),
        _asString(map['phone'] ?? map['mobile']),
      ];

      return candidates
          .whereType<String>()
          .map((e) => e.trim())
          .where((element) => element.isNotEmpty)
          .join(' • ');
    }
    return null;
  }

  static String _formatNumber(num value) {
    if (value is int) return value.toString();
    return value.toStringAsFixed(2);
  }
}

@immutable
class OrderLine {
  const OrderLine({
    required this.name,
    required this.quantity,
    this.price,
    this.priceDisplay,
    this.subtotal,
    this.subtotalDisplay,
    this.currency,
    this.raw,
  });

  final String name;
  final int quantity;
  final num? price;
  final String? priceDisplay;
  final num? subtotal;
  final String? subtotalDisplay;
  final String? currency;
  final Map<String, dynamic>? raw;

  factory OrderLine.fromJson(Map<String, dynamic> json, {String? currency}) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(json);
    final String name =
        UserOrder._asString(map['name'] ?? map['title'] ?? map['product_name'] ?? map['item']) ??
            '';
    final int quantity = (UserOrder._asNum(map['quantity'] ?? map['qty']) ?? 0).toInt();
    final num? price = UserOrder._asNum(map['price'] ?? map['unit_price']);
    final num? subtotal =
    UserOrder._asNum(map['subtotal'] ?? map['total'] ?? map['line_total']);
    final String? priceDisplay = UserOrder._asString(
      map['price_display'] ?? map['unit_price_display'] ?? map['price_text'],
    );
    final String? subtotalDisplay = UserOrder._asString(
      map['subtotal_display'] ?? map['total_display'] ?? map['line_total_display'],
    );
    final String? currencyOverride =
    UserOrder._asString(map['currency'] ?? map['currency_code'] ?? currency);

    return OrderLine(
      name: name,
      quantity: quantity,
      price: price,
      priceDisplay: priceDisplay,
      subtotal: subtotal,
      subtotalDisplay: subtotalDisplay,
      currency: currencyOverride ?? currency,
      raw: map,
    );
  }

  String get totalText {
    if (subtotalDisplay != null && subtotalDisplay!.trim().isNotEmpty) {
      return subtotalDisplay!.trim();
    }
    if (subtotal != null) {
      final String value = UserOrder._formatNumber(subtotal!);
      final String suffix =
      (currency != null && currency!.trim().isNotEmpty) ? ' ${currency!.trim()}' : '';
      return '$value$suffix';
    }
    if (priceDisplay != null && priceDisplay!.trim().isNotEmpty) {
      return priceDisplay!.trim();
    }
    if (price != null) {
      final String value = UserOrder._formatNumber(price!);
      final String suffix =
      (currency != null && currency!.trim().isNotEmpty) ? ' ${currency!.trim()}' : '';
      return '$value$suffix';
    }
    return '—';
  }
}

@immutable
class OrderTimelineEntry {
  const OrderTimelineEntry({
    required this.label,
    this.status,
    this.timestamp,
    this.description,
    this.isCompleted = false,
    this.isCurrent = false,
    this.raw,
  });

  final String label;
  final String? status;
  final DateTime? timestamp;
  final String? description;
  final bool isCompleted;
  final bool isCurrent;
  final Map<String, dynamic>? raw;

  factory OrderTimelineEntry.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(json);
    final String label =
        UserOrder._asString(map['label'] ?? map['title'] ?? map['status'] ?? map['name']) ??
            'الحالة';
    final String? status = UserOrder._asString(
      map['status_text'] ?? map['status'] ?? map['state'] ?? map['description'],
    );
    final DateTime? timestamp = UserOrder._parseDateTime(
      map['timestamp'] ?? map['time'] ?? map['created_at'] ?? map['date'],
    );
    final String? description = UserOrder._asString(map['description'] ?? map['notes']);

    final String combined = (status ?? label).toLowerCase();
    final bool completed = map['completed'] == true ||
        map['is_done'] == true ||
        map['done'] == true ||
        combined.contains('تم') ||
        combined.contains('delivered') ||
        combined.contains('completed');

    final bool current = map['current'] == true ||
        map['is_current'] == true ||
        map['active'] == true ||
        combined.contains('current');

    return OrderTimelineEntry(
      label: label,
      status: status,
      timestamp: timestamp,
      description: description,
      isCompleted: completed,
      isCurrent: current,
      raw: map,
    );
  }



}

@immutable
class OrderDetails {
  const OrderDetails({
    required this.order,
    this.policy,
    this.support,
    this.paymentSummary,
    this.deliveryPaymentSummary,
    this.depositReceipts,
    this.raw,
  });

  final UserOrder order;
  final OrderPolicy? policy;
  final OrderSupport? support;
  final Map<String, dynamic>? paymentSummary;
  final Map<String, dynamic>? deliveryPaymentSummary;
  final Map<String, dynamic>? depositReceipts;
  final Map<String, dynamic>? raw;
}

@immutable
class OrderStatusDisplay {
  const OrderStatusDisplay({
    this.title,
    this.subtitle,
    this.description,
    this.badge,
    this.note,
    this.style,
    this.raw,
  });

  final String? title;
  final String? subtitle;
  final String? description;
  final String? badge;
  final String? note;
  final String? style;
  final Map<String, dynamic>? raw;

  factory OrderStatusDisplay.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(json);
    final String? title = UserOrder._asString(
      map['title'] ??
          map['label'] ??
          map['heading'] ??
          map['status'] ??
          map['status_text'] ??
          map['primary'],
    );
    final String? subtitle = UserOrder._asString(
      map['subtitle'] ??
          map['subheading'] ??
          map['message'] ??
          map['description'] ??
          map['secondary'],
    );
    final String? description = UserOrder._asString(
      map['details'] ?? map['body'] ?? map['text'] ?? map['content'],
    );
    final String? badge = UserOrder._asString(
      map['badge'] ??
          map['badge_text'] ??
          map['badgeLabel'] ??
          map['chip'] ??
          map['pill'],
    );
    final String? note = UserOrder._asString(map['note'] ?? map['hint'] ?? map['footnote']);
    final String? style = UserOrder._asString(map['style'] ?? map['variant'] ?? map['type']);

    return OrderStatusDisplay(
      title: title,
      subtitle: subtitle,
      description: description,
      badge: badge,
      note: note,
      style: style,
      raw: map,
    );
  }

  bool get hasContent =>
      _stringHasValue(title) ||
          _stringHasValue(subtitle) ||
          _stringHasValue(description) ||
          _stringHasValue(badge) ||
          _stringHasValue(note);

  String? get primaryText {
    if (_stringHasValue(title)) return title!.trim();
    if (_stringHasValue(subtitle)) return subtitle!.trim();
    if (_stringHasValue(description)) return description!.trim();
    if (_stringHasValue(badge)) return badge!.trim();
    if (_stringHasValue(note)) return note!.trim();
    return null;
  }

  String? get secondaryText {
    final List<String?> candidates = <String?>[
      subtitle,
      description,
      note,
    ];
    final String? primary = primaryText;
    for (final String? candidate in candidates) {
      if (!_stringHasValue(candidate)) continue;
      final String trimmed = candidate!.trim();
      if (primary != null && primary == trimmed) {
        continue;
      }
      return trimmed;
    }
    return null;
  }
}

@immutable
class OrderStatusReserveOptions {
  const OrderStatusReserveOptions({
    this.title,
    this.message,
    this.highlightText,
    this.disclaimer,
    this.actionLabel,
    this.actionUrl,
    this.points = const <String>[],
    this.raw,
  });

  final String? title;
  final String? message;
  final String? highlightText;
  final String? disclaimer;
  final String? actionLabel;
  final String? actionUrl;
  final List<String> points;
  final Map<String, dynamic>? raw;

  factory OrderStatusReserveOptions.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(json);

    final List<String> points = <String>[];
    final dynamic pointsSource = map['points'] ??
        map['items'] ??
        map['bullet_points'] ??
        map['details'] ??
        map['list'] ??
        map['lines'];
    if (pointsSource is List) {
      for (final dynamic entry in pointsSource) {
        final String? resolved = UserOrder._asString(entry);
        if (_stringHasValue(resolved)) {
          points.add(resolved!.trim());
        }
      }
    }

    final String? title = UserOrder._asString(
      map['title'] ?? map['label'] ?? map['heading'],
    );
    final String? message = UserOrder._asString(
      map['message'] ?? map['description'] ?? map['text'],
    );
    final String? highlightText = UserOrder._asString(
      map['highlight_text'] ?? map['highlight'] ?? map['emphasis'],
    );
    final String? disclaimer = UserOrder._asString(
      map['disclaimer'] ?? map['note'] ?? map['hint'],
    );
    final String? actionLabel = UserOrder._asString(
      map['action_label'] ??
          map['button_label'] ??
          map['cta_label'] ??
          map['actionText'] ??
          map['buttonText'],
    );
    final String? actionUrl = UserOrder._asString(
      map['action_url'] ??
          map['button_url'] ??
          map['cta_url'] ??
          map['url'] ??
          map['href'],
    );

    return OrderStatusReserveOptions(
      title: title,
      message: message,
      highlightText: highlightText,
      disclaimer: disclaimer,
      actionLabel: actionLabel,
      actionUrl: actionUrl,
      points: points,
      raw: map,
    );
  }

  bool get hasContent =>
      _stringHasValue(title) ||
          _stringHasValue(message) ||
          _stringHasValue(highlightText) ||
          _stringHasValue(disclaimer) ||
          points.isNotEmpty;

  String? get emphasisText {
    if (_stringHasValue(highlightText)) return highlightText!.trim();
    if (_stringHasValue(message)) return message!.trim();
    if (_stringHasValue(disclaimer)) return disclaimer!.trim();
    if (_stringHasValue(title)) return title!.trim();
    return null;
  }
}

@immutable
class OrderActions {
  const OrderActions({
    this.canCancel = false,
    this.canRefundDeposit = false,
    this.cancelLabel,
    this.cancelDescription,
    this.cancelHint,
    this.raw,
  });

  final bool canCancel;
  final bool canRefundDeposit;
  final String? cancelLabel;
  final String? cancelDescription;
  final String? cancelHint;
  final Map<String, dynamic>? raw;

  factory OrderActions.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const OrderActions();
    }

    final Map<String, dynamic> map = Map<String, dynamic>.from(json);

    final bool canCancel = _asBool(
      map['can_cancel'] ??
          map['cancel'] ??
          map['allow_cancel'] ??
          map['canCancel'] ??
          map['allowCancel'],
    );
    final bool canRefundDeposit = _asBool(
      map['can_refund_deposit'] ??
          map['can_refund'] ??
          map['refund_deposit'] ??
          map['canRefundDeposit'] ??
          map['allowRefund'],
    );
    final String? cancelLabel = UserOrder._asString(
      map['cancel_label'] ??
          map['cancel_button_label'] ??
          map['cancelText'] ??
          map['cancel_button'] ??
          map['cancel_cta'] ??
          map['label'],
    );
    final String? cancelDescription = UserOrder._asString(
      map['cancel_description'] ??
          map['cancel_message'] ??
          map['message'] ??
          map['description'],
    );
    final String? cancelHint = UserOrder._asString(
      map['cancel_hint'] ?? map['hint'] ?? map['note'],
    );

    return OrderActions(
      canCancel: canCancel,
      canRefundDeposit: canRefundDeposit,
      cancelLabel: cancelLabel,
      cancelDescription: cancelDescription,
      cancelHint: cancelHint,
      raw: map,
    );
  }

  String get cancelButtonLabel {
    if (_stringHasValue(cancelLabel)) {
      return cancelLabel!.trim();
    }
    if (canRefundDeposit) {
      return 'استرداد المبلغ وإلغاء الطلب';
    }
    return 'إلغاء الطلب';
  }

  bool get hasCancelDescription => _stringHasValue(cancelDescription);

  bool get hasCancelHint => _stringHasValue(cancelHint);

  static bool _asBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return false;
      return <String>{'true', '1', 'yes', 'y', 't'}.contains(normalized);
    }
    return false;
  }
}

@immutable
class OrderPolicy {
  const OrderPolicy({
    this.title,
    this.returnPolicyText,
    this.updatedAt,
    this.raw,
  });

  final String? title;
  final String? returnPolicyText;
  final DateTime? updatedAt;
  final Map<String, dynamic>? raw;

  factory OrderPolicy.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(json);
    final String? title = UserOrder._asString(
      map['title'] ?? map['label'] ?? map['name'],
    );
    final String? returnPolicyText = UserOrder._asString(
      map['return_policy_text'] ??
          map['return_policy'] ??
          map['returnPolicyText'] ??
          map['policy_text'] ??
          map['text'],
    );
    final DateTime? updatedAt = UserOrder._parseDateTime(
      map['updated_at'] ?? map['updatedAt'] ?? map['modified_at'],
    );

    return OrderPolicy(
      title: title,
      returnPolicyText: returnPolicyText,
      updatedAt: updatedAt,
      raw: map,
    );
  }

  bool get hasReturnPolicy => _stringHasValue(returnPolicyText);

  String get effectiveTitle => _stringHasValue(title) ? title!.trim() : 'سياسة الاسترجاع';
}

@immutable
class OrderSupport {
  const OrderSupport({
    this.type,
    this.label,
    this.subtitle,
    this.url,
    this.whatsappNumber,
    this.whatsappMessage,
    this.raw,
  });

  final String? type;
  final String? label;
  final String? subtitle;
  final String? url;
  final String? whatsappNumber;
  final String? whatsappMessage;
  final Map<String, dynamic>? raw;

  factory OrderSupport.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(json);
    final String? type = UserOrder._asString(
      map['type'] ?? map['channel'] ?? map['support_type'],
    );
    final String? label = UserOrder._asString(
      map['label'] ??
          map['title'] ??
          map['button_label'] ??
          map['buttonText'] ??
          map['name'],
    );
    final String? subtitle = UserOrder._asString(
      map['subtitle'] ?? map['description'] ?? map['text'],
    );
    final String? urlCandidate = UserOrder._asString(
      map['url'] ??
          map['link'] ??
          map['href'] ??
          map['action_url'] ??
          map['actionUrl'] ??
          map['whatsapp_url'] ??
          map['support_url'],
    );
    final String? whatsappNumber = UserOrder._asString(
      map['whatsapp'] ??
          map['whatsapp_number'] ??
          map['number'] ??
          map['phone'] ??
          map['contact'] ??
          map['value'] ??
          map['recipient'],
    );
    final String? whatsappMessage = UserOrder._asString(
      map['message'] ??
          map['default_message'] ??
          map['prefill'] ??
          map['text_message'] ??
          map['body'],
    );

    final String? resolvedUrl = _resolveUrl(urlCandidate, whatsappNumber, whatsappMessage);

    return OrderSupport(
      type: type,
      label: label,
      subtitle: subtitle,
      url: resolvedUrl,
      whatsappNumber: whatsappNumber,
      whatsappMessage: whatsappMessage,
      raw: map,
    );
  }

  bool get hasContact => _stringHasValue(url);

  String get effectiveLabel {
    if (_stringHasValue(label)) {
      return label!.trim();
    }
    if (_stringHasValue(type) && type!.toLowerCase().contains('whats')) {
      return 'التواصل عبر واتساب';
    }
    return 'التواصل مع الدعم';
  }

  static String? _resolveUrl(String? urlCandidate, String? number, String? message) {
    final String? normalized = _normalizeUrl(urlCandidate);
    if (normalized != null) {
      return normalized;
    }

    final String? sanitizedNumber = _sanitizePhone(number);
    if (sanitizedNumber == null) {
      return null;
    }

    final String base = 'https://wa.me/$sanitizedNumber';
    if (_stringHasValue(message)) {
      final String encoded = Uri.encodeComponent(message!.trim());
      return '$base?text=$encoded';
    }
    return base;
  }

  static String? _normalizeUrl(String? url) {
    if (url == null) return null;
    final String trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    Uri? uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      final String scheme = uri.scheme.toLowerCase();
      if (<String>{'http', 'https', 'whatsapp', 'tel'}.contains(scheme)) {
        return trimmed;
      }
    }

    if (trimmed.startsWith('www.')) {
      uri = Uri.tryParse('https://$trimmed');
      if (uri != null) {
        return 'https://$trimmed';
      }
    }

    if (trimmed.startsWith('wa.me/') || trimmed.startsWith('api.whatsapp.com/')) {
      return 'https://$trimmed';
    }

    return null;
  }

  static String? _sanitizePhone(String? number) {
    if (number == null) return null;
    final String trimmed = number.trim();
    if (trimmed.isEmpty) return null;

    final String normalized = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) return null;

    if (normalized.startsWith('+')) {
      final String digits = normalized.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
      return digits.isNotEmpty ? digits : null;
    }

    final String digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.isNotEmpty ? digitsOnly : null;
  }
}

bool _stringHasValue(String? value) => value != null && value.trim().isNotEmpty;
