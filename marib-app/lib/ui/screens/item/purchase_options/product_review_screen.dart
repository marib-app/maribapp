import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/manage_item_cubit.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart'
    show CustomFieldColorEntry, CustomFieldModel;
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/data/repositories/item/item_purchase_options_repository.dart';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/ui/screens/item/purchase_options/pending_item_draft.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/variant_key.dart';

class ProductReviewScreen extends StatefulWidget {
  const ProductReviewScreen({
    super.key,
    required this.item,
    this.initialOptions,
    this.initialMessage,
    this.pendingDraft,
  });

  final ItemModel item;
  final ItemPurchaseOptions? initialOptions;
  final String? initialMessage;
  final PendingItemDraft? pendingDraft;

  static Route<dynamic> route(RouteSettings settings) {
    ItemModel? item;
    ItemPurchaseOptions? options;
    String? message;
    PendingItemDraft? draft;

    final dynamic arguments = settings.arguments;
    if (arguments is ItemModel) {
      item = arguments;
    } else if (arguments is PendingItemDraft) {
      draft = arguments;
      item = draft.item;
    } else if (arguments is Map) {
      final dynamic draftCandidate =
          arguments['pendingDraft'] ?? arguments['draft'];
      if (draftCandidate is PendingItemDraft) {
        draft = draftCandidate;
      }
      final dynamic itemCandidate =
          arguments['item'] ?? arguments['model'] ?? arguments['ad'];
      if (itemCandidate is ItemModel) {
        item = itemCandidate;
      } else if (draft != null) {
        item = draft.item;
      }
      final dynamic optionsCandidate = arguments['options'];
      if (optionsCandidate is ItemPurchaseOptions) {
        options = optionsCandidate;
      }
      final dynamic messageCandidate = arguments['message'];
      if (messageCandidate is String && messageCandidate.trim().isNotEmpty) {
        message = messageCandidate;
      }
    }

    if (draft != null && item == null) {
      item = draft.item;
    }

    if (item == null) {
      throw ArgumentError('ProductReviewScreen expects an ItemModel.');
    }

    Widget content = ProductReviewScreen(
      item: item!,
      initialOptions: options,
      initialMessage: message,
      pendingDraft: draft,
    );

    if (draft != null) {
      content = BlocProvider<ManageItemCubit>(
        create: (_) => ManageItemCubit(),
        child: content,
      );
    }

    return MaterialPageRoute(builder: (_) => content, settings: settings);
  }

  @override
  State<ProductReviewScreen> createState() => _ProductReviewScreenState();
}

class _ProductReviewScreenState extends State<ProductReviewScreen> {
  late ItemModel _item;
  ItemPurchaseOptions? _options;
  PendingItemDraft? _pendingDraft;
  bool _isFetching = false;
  bool _publishing = false;
  String? _error;
  late final PageController _galleryController;
  int _galleryIndex = 0;

  final ItemPurchaseOptionsRepository _optionsRepository =
      ItemPurchaseOptionsRepository();
  final ItemRepository _itemRepository = ItemRepository();

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _options = widget.initialOptions;
    _pendingDraft = widget.pendingDraft;
    _galleryController = PageController();

    if (_options == null && _item.id != null) {
      _fetchOptions();
    }

    final String? message = widget.initialMessage;
    if (message != null && message.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        HelperUtils.showSnackBarMessage(context, message);
      });
    }
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> sections = _buildSections();

    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        title: '?????? ???????',
        showBackButton: true,
        actions: [
          IconButton(
            onPressed: _isFetching ? null : _fetchOptions,
            tooltip: '????? ????????',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: context.color.territoryColor,
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < sections.length; i++) ...[
                      sections[i],
                      if (i != sections.length - 1) const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            if (_isFetching && _options != null)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(child: _buildBottomBar()),
    );
  }

  Future<void> _handleRefresh() async {
    if (_item.id == null) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return;
    }
    await _fetchOptions();
  }

  List<Widget> _buildSections() {
    final List<Widget> sections = <Widget>[];
    final List<_GalleryMedia> media = _resolveGalleryMedia();

    if (media.isNotEmpty) {
      sections.add(_buildGallerySection(media));
    }

    sections.add(_buildDetailsCard());
    sections.add(_buildMetaInfoCard());

    if (_item.customFields?.isNotEmpty ?? false) {
      sections.add(_buildCustomFieldsCard());
    }

    if (_options != null) {
      sections.addAll(<Widget>[
        _buildSummaryCard(_options!),
        _buildAttributesCard(_options!),
        _buildStockCard(_options!),
        _buildDiscountCard(_options!),
      ]);
    } else if (_pendingDraft != null) {
      sections.add(_buildPendingDraftPreview());
    }

    if (_error != null && _options == null) {
      sections.add(
        _SectionCard(
          title: 'حالة التحميل',
          child: Text(
            _error!,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    return sections;
  }

  Widget _buildGallerySection(List<_GalleryMedia> media) {
    final ColorScheme palette = context.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView.builder(
              controller: _galleryController,
              itemCount: media.length,
              onPageChanged: (int index) => setState(() => _galleryIndex = index),
              itemBuilder: (_, int index) {
                final _GalleryMedia entry = media[index];
                if (entry.file != null) {
                  return Image.file(entry.file!, fit: BoxFit.cover);
                }
                return Image.network(
                  entry.url!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: palette.secondaryColor,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: palette.secondaryColor,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, size: 48),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(media.length, (int index) {
            final bool active = index == _galleryIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? palette.territoryColor
                    : palette.borderColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDetailsCard() {
    final ThemeData theme = Theme.of(context);
    final String title =
        _item.name?.trim().isNotEmpty == true ? _item.name!.trim() : (_draftValue('title') ?? '????? ???? ?????');
    final String? description = _item.description?.trim().isNotEmpty == true
        ? _item.description
        : _draftValue('description');

    return _SectionCard(
      title: '?????? ???????',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            _resolvePrimaryPrice(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: context.color.territoryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            (description == null || description.trim().isEmpty)
                ? '?? ???? ??? ???? ???? ???????.'
                : description,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfoCard() {
    final List<_InfoRow> rows = <_InfoRow>[
      _InfoRow('?????', _item.category?.name),
      _InfoRow('???????', _item.city ?? _draftValue('city')),
      _InfoRow('???????', _item.state ?? _draftValue('state')),
      _InfoRow('??????', _item.country ?? _draftValue('country')),
      _InfoRow('???????', _item.address ?? _draftValue('address')),
      _InfoRow('??? ???????', _item.contact ?? _draftValue('contact')),
      _InfoRow('???? ??????', _item.productLink ?? _draftValue('product_link')),
      _InfoRow('???? ????????', _item.reviewLink ?? _draftValue('review_link')),
    ];

    final Iterable<_InfoRow> available =
        rows.where((row) => row.value != null && row.value!.trim().isNotEmpty);

    if (available.isEmpty) {
      return _SectionCard(
        title: '?????? ?????? ???????',
        child: const Text('?? ???? ?????? ????? ?? ???? ?????.'),
      );
    }

    return _SectionCard(
      title: '?????? ?????? ???????',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: available
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _buildKeyValueRow(row.label, row.value!),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildCustomFieldsCard() {
    final List<CustomFieldModel> fields = _item.customFields ?? const [];
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    return _SectionCard(
      title: '???? ??????',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields
            .map(
              (field) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.name ?? '??? ????',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      field.value.isNotEmpty ? field.value.join(', ') : field.values.join(', '),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildPendingDraftPreview() {
    final List<_SummaryRow> rows = _buildDraftSummaryRows();
    final Widget child = rows.isEmpty
        ? const Text('?? ???? ?????? ????? ?? ??????? ??????? ???? ??? ???????? ?????.')
        : _buildSummaryRowsColumn(rows);

    return _SectionCard(title: '?????? ???????', child: child);
  }

  Widget _buildSummaryCard(ItemPurchaseOptions options) {
    final List<_SummaryRow> rows = <_SummaryRow>[
      _SummaryRow('????? ???????', _formatPrice(options.basePrice)),
      _SummaryRow('????? ??? ????????', _formatPrice(options.finalPrice)),
    ];
    if (options.deliverySize != null) {
      rows.add(_SummaryRow('????? ????? (?)', _formatDeliverySize(options.deliverySize!)));
    }
    return _SectionCard(
      title: '?????? ??????',
      child: _buildSummaryRowsColumn(rows),
    );
  }

  Widget _buildAttributesCard(ItemPurchaseOptions options) {
    if (options.attributes.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return _SectionCard(
      title: '???? ??????',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: options.attributes.map((attribute) {
          final List<String> values = attribute.selectedValues.isNotEmpty
              ? attribute.selectedValues
              : attribute.allowedValues;
          final String valueText = values.isNotEmpty
              ? values.join(', ')
              : attribute.defaultValue ?? '??? ????';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attribute.name,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(valueText, style: theme.textTheme.bodyMedium),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildStockCard(ItemPurchaseOptions options) {
    if (options.variantStocks.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return _SectionCard(
      title: '???????',
      child: Column(
        children: options.variantStocks.map((ItemVariantStockOption entry) {
          final String key = entry.variantKey.isEmpty ? '?????? ??????' : entry.variantKey;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    key,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '/',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildDiscountCard(ItemPurchaseOptions options) {
    final ItemDiscount? discount = options.discount;
    if (discount == null && options.finalPrice == options.basePrice) {
      return const SizedBox.shrink();
    }

    final List<_SummaryRow> rows = <_SummaryRow>[
      _SummaryRow('??? ?????', _formatPrice(options.finalPrice)),
    ];

    if (discount?.value != null) {
      rows.add(_SummaryRow(
        discount!.type == 'fixed' ? '???? ?????' : '???? ?????',
        discount.value!.toString(),
      ));
    }

    if (discount?.start != null) {
      rows.add(
        _SummaryRow('بداية العرض', _formatDate(discount!.start) ?? '-'),
      );
    }

    if (discount?.end != null) {
      rows.add(
        _SummaryRow('نهاية العرض', _formatDate(discount!.end) ?? '-'),
      );
    }

    return _SectionCard(
      title: '????????',
      child: _buildSummaryRowsColumn(rows),
    );
  }

  Widget _buildSummaryRowsColumn(List<_SummaryRow> rows) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _buildKeyValueRow(row.label, row.value),
              ))
          .toList(growable: false),
    );
  }

  Widget _buildKeyValueRow(String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.color.textColor.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Future<void> _fetchOptions() async {
    if (_item.id == null) {
      return;
    }

    setState(() {
      _isFetching = true;
      _error = null;
    });

    try {
      final ItemPurchaseOptions options = await _optionsRepository.fetch(_item.id!);
      if (!mounted) return;
      setState(() {
        _options = options;
        _error = null;
      });
    } catch (error) {
      final String message =
          ErrorFilter.check(error).error?.toString() ?? error.toString();
      if (!mounted) return;
      setState(() {
        _error = message.isNotEmpty ? message : '???? ????? ???????? ???? ??????.';
      });
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _publishNow() async {
    if (_publishing) return;

    if (_item.id == null && _pendingDraft == null) {
      HelperUtils.showSnackBarMessage(context, '?? ???? ????? ??? ????? ???????.');
      return;
    }

    setState(() => _publishing = true);
    Widgets.showLoader(context);
    bool loaderDismissed = false;

    try {
      if (_item.id == null && _pendingDraft != null) {
        final ManageItemCubit cubit = context.read<ManageItemCubit>();
        final ItemModel created = await submitPendingItemDraft(
          cubit: cubit,
          draft: _pendingDraft!,
        );
        _item = created;
        _pendingDraft = null;
      }

      final int itemId = _item.id!;
      String status = (_item.status ?? '').toLowerCase();

      if (status == 'review') {
        HelperUtils.showSnackBarMessage(context, '??????? ??? ???????? ??????.');
        Widgets.hideLoder(context);
        loaderDismissed = true;
        return;
      }

      const Set<String> alreadyPublished = <String>{
        'approved',
        'active',
        'published',
        'enabled',
      };

      if (alreadyPublished.contains(status)) {
        HelperUtils.showSnackBarMessage(context, '??????? ????? ??????.');
        Widgets.hideLoder(context);
        loaderDismissed = true;
        return;
      }

      if (status == 'rejected') {
        HelperUtils.showSnackBarMessage(context, '??????? ????? ??????? ?????? ??? ?????.');
        Widgets.hideLoder(context);
        loaderDismissed = true;
        return;
      }

      await _itemRepository.changeMyItemStatus(itemId: itemId, status: 'active');
      final ItemModel? refreshed = await _reloadItem(itemId);
      if (!mounted) return;

      Widgets.hideLoder(context);
      loaderDismissed = true;

      if (refreshed != null) {
        _item = refreshed;
      }

      HelperUtils.showSnackBarMessage(context, '?? ??? ??????? ?????.');
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.adDetailsScreen,
        (Route<dynamic> route) => route.isFirst, 
        arguments: <String, dynamic>{'model': _item},
      );
    } catch (error) {
      final String message =
          ErrorFilter.check(error).error?.toString() ?? error.toString();
      if (mounted) {
        if (!loaderDismissed) {
          Widgets.hideLoder(context);
        }
        HelperUtils.showSnackBarMessage(
          context,
          message.isNotEmpty ? message : '??? ??? ????? ?????.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  Future<ItemModel?> _reloadItem(int itemId) async {
    try {
      final DataOutput<ItemModel> response =
          await _itemRepository.fetchItemFromItemId(itemId);
      if (response.modelList.isNotEmpty) {
        return response.modelList.first;
      }
    } catch (_) {}
    return null;
  }

  String _resolvePrimaryPrice() {
    final double? price = _item.finalPrice ?? _item.price;
    if (price != null) {
      return _formatPrice(price);
    }
    return _formatDraftPrice(_draftValue('price'), _draftValue('currency')) ?? '?';
  }

  Map<String, dynamic> _draftPayload() {
    if (_pendingDraft == null) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(_pendingDraft!.payload);
  }

  String? _draftValue(String key) {
    final Map<String, dynamic> payload = _draftPayload();
    if (!payload.containsKey(key)) {
      return null;
    }
    final String text = payload[key]?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  List<_GalleryMedia> _resolveGalleryMedia() {
    final List<_GalleryMedia> entries = <_GalleryMedia>[];
    final PendingItemDraft? draft = _pendingDraft;

    if (draft != null) {
      if (draft.mainImage != null) {
        entries.add(_GalleryMedia.file(draft.mainImage!));
      }
      for (final File file in draft.galleryImages) {
        entries.add(_GalleryMedia.file(file));
      }
    }

    final List<GalleryImages>? gallery = _item.galleryImages;
    if (gallery != null) {
      for (final GalleryImages image in gallery) {
        final String? url = image.detailImageUrl ?? image.image;
        if (url != null && url.trim().isNotEmpty) {
          entries.add(_GalleryMedia.network(url));
        }
      }
    }

    final List<String?> fallbacks = <String?>[
      _item.detailImageUrl,
      _item.image,
      _item.thumbnailUrl,
      _item.thumbnailFallbackUrl,
    ];
    for (final String? url in fallbacks) {
      if (url != null && url.trim().isNotEmpty) {
        entries.add(_GalleryMedia.network(url));
        break;
      }
    }

    return entries;
  }

  List<_SummaryRow> _buildDraftSummaryRows() {
    final Map<String, dynamic> payload = _draftPayload();
    final List<_SummaryRow> rows = <_SummaryRow>[];

    void addRow(String label, String? raw) {
      final String? text = raw?.trim();
      if (text == null || text.isEmpty) return;
      rows.add(_SummaryRow(label, text));
    }

    addRow('???????', _item.name ?? payload['title']?.toString());
    addRow('?????', _formatDraftPrice(payload['price'], payload['currency']));
    addRow('?????', _item.description ?? payload['description']?.toString());
    addRow('??????', _item.contact ?? payload['contact']?.toString());
    addRow('???????', _item.city ?? payload['city']?.toString());
    addRow('??????', _item.country ?? payload['country']?.toString());
    addRow('??????', _item.productLink ?? payload['product_link']?.toString());

    return rows;
  }

  Widget _buildBottomBar() {
    final String status = (_item.status ?? '').trim().toLowerCase();
    const Set<String> blockedStatuses = <String>{
      'review',
      'approved',
      'active',
      'published',
      'enabled',
      'rejected',
    };

    final bool hasBlockedStatus = blockedStatuses.contains(status);
    final bool disablePublish =
        _publishing || _item.id == null || hasBlockedStatus;
    final String buttonTitle =
        hasBlockedStatus ? _resolveDisabledButtonTitle(status) : '??? ????';
    final String? disabledMessage =
        hasBlockedStatus ? _resolveDisabledMessage(status) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _publishing ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.color.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('????'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiUtils.buildButton(
                  context,
                  onPressed: () async {
                    if (disablePublish) return;
                    await _publishNow();
                  },
                  buttonTitle: buttonTitle,
                  titleWhenProgress: '???? ?????...',
                  height: 48,
                  isInProgress: _publishing,
                  disabled: disablePublish,
                  onTapDisabledButton: disabledMessage == null
                      ? null
                      : () => HelperUtils.showSnackBarMessage(
                            context,
                            disabledMessage,
                          ),
                ),
                if (disabledMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    disabledMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: context.color.textColor.withOpacity(0.8)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _resolveDisabledButtonTitle(String status) {
    switch (status) {
      case 'review':
        return '??? ????????';
      case 'approved':
      case 'active':
      case 'published':
      case 'enabled':
        return '?????';
      case 'rejected':
        return '?????';
      default:
        return '??? ????';
    }
  }

  String? _resolveDisabledMessage(String status) {
    switch (status) {
      case 'review':
        return '??????? ??? ???????? ?? ??? ??????.';
      case 'approved':
      case 'active':
      case 'published':
      case 'enabled':
        return '??????? ????? ??????.';
      case 'rejected':
        return '?? ??? ??????? ???? ?????? ??? ?????.';
      default:
        return null;
    }
  }

  String _formatPrice(double value) {
    final NumberFormat formatter = NumberFormat('#,##0.00', 'ar');
    final String currency = (_item.currency ?? _item.currencyCode ?? '').trim();
    final String formatted = formatter.format(value);
    return currency.isEmpty ? formatted : '$formatted $currency';
  }

  String _formatDeliverySize(double value) {
    final NumberFormat formatter = NumberFormat('#,##0.###', 'ar');
    return formatter.format(value);
  }

  String? _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return null;
    }
    final DateFormat formatter = DateFormat('yyyy/MM/dd ? HH:mm', 'ar');
    return formatter.format(dateTime.toLocal());
  }

  String? _formatDraftPrice(dynamic rawPrice, dynamic rawCurrency) {
    double? parsedPrice;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else {
      parsedPrice = double.tryParse(rawPrice?.toString() ?? '');
    }
    if (parsedPrice == null) {
      return null;
    }
    final String currency =
        _draftValue('currency') ?? _draftValue('currency_code') ?? 'YER';
    final NumberFormat formatter = NumberFormat('#,##0.##', 'ar');
    final String formatted = formatter.format(parsedPrice);
    return '$formatted $currency';
  }
}

class _GalleryMedia {
  const _GalleryMedia.file(this.file) : url = null;
  const _GalleryMedia.network(this.url) : file = null;

  final File? file;
  final String? url;
}

class _SummaryRow {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    return Card(
      color: palette.secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

