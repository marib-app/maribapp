part of 'ad_creation_wizard_screen.dart';

extension _MainCategoryStepView on _AdCreationWizardScreenState {
  Widget _buildMainCategoryStep() => _MainCategoryStepContent(screen: this);

  Widget _buildCategorySearchField() {
    final ThemeData theme = Theme.of(context);
    return TextField(
      controller: _categorySearchController,
      onChanged: _onMainCategorySearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        labelText: 'بحث عن فئة',
        hintText: 'اكتب اسم الفئة الرئيسية للعثور عليها بسرعة',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.25),
      ),
    );
  }

  void _onMainCategorySearchChanged(String value) {
    _categorySearchDebounce?.cancel();
    final String query = value;
    _categorySearchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _categorySearchQuery = query;
      });
    });
  }

  String _interfaceDisplayName(String? interfaceType) {
    final String normalized = interfaceType?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return 'واجهة عامة';
    }
    return _AdCreationWizardScreenState._interfaceTypeLabels[normalized] ??
        interfaceType ??
        'واجهة عامة';
  }

  Widget _buildMainCategoryCard(_MainCategoryOption category) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isSelected = _selectedMainCategory?.id == category.id;
    final String interfaceLabel = _interfaceDisplayName(category.interfaceType);
    final bool isPressed = _pressedMainCategoryId == category.id;
    final BorderRadius radius = BorderRadius.circular(16);


    return Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: AnimatedScale(
          scale: isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onHighlightChanged: (bool value) {
                if (!mounted) {
                  return;
                }
                if (value) {
                  setState(() => _pressedMainCategoryId = category.id);
                } else if (_pressedMainCategoryId == category.id) {
                  setState(() => _pressedMainCategoryId = null);
                }
              },
              onTap: () => _onMainCategorySelected(category),
              child: Ink(
                width: 220,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: isSelected ? colors.primaryContainer : colors.surface,
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.outlineVariant,
                    width: isSelected ? 2 : 1,
                ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: colors.shadow.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                    child: category.imageUrl != null &&
                        category.imageUrl!.trim().isNotEmpty
                        ? LazyNetworkImage(
                      imageUrl: category.imageUrl!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      height: 120,
                      width: double.infinity,
                      color: colors.surfaceVariant,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.category_outlined,
                        color: colors.onSurfaceVariant,
                        size: 40,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          category.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? colors.onPrimaryContainer
                                : colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          interfaceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? colors.onPrimaryContainer.withOpacity(0.85)
                                : colors.onSurfaceVariant,
                          ),
                        ),
                        if (category.subCategories.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            '${category.subCategories.length} فئات فرعية',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? colors.onPrimaryContainer
                                  .withOpacity(0.7)
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                ],
              ),
            ),
            ),
        ),
      ),
    );
  }


}

class _MainCategoryStepContent extends StatelessWidget {
  const _MainCategoryStepContent({required this.screen});

  final _AdCreationWizardScreenState screen;

  @override
  Widget build(BuildContext context) {

    if (!screen._hasRequestedCategoryFetch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (screen.mounted && !screen._hasRequestedCategoryFetch) {
          screen._triggerCategoryFetch();
        }
      });
    }

    return BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
      builder: (BuildContext context, FetchCategoryState fetchState) {
        final bool isLoading = fetchState is FetchCategoryInProgress;

        if (fetchState is FetchCategoryFailure &&
            screen._mainCategories.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              screen._buildErrorCard(
                message: 'تعذّر تحميل الفئات. حاول مرة أخرى.',
                onRetry: screen._retryFetchCategories,
              ),
            ],
          );
        }

        if (screen._mainCategories.isEmpty) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              screen._buildPlaceholderMessage(
                  'لا توجد فئات متاحة لهذا الحساب حاليًا.'),
              if (fetchState is FetchCategoryFailure)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: screen._buildErrorCard(
                    message: 'تعذّر تحميل الفئات. حاول مجددًا.',
                    onRetry: screen._retryFetchCategories,
                  ),
                ),
            ],
          );
        }

        final ThemeData theme = Theme.of(context);
        final List<_MainCategoryOption> displayCategories =
            screen._filteredMainCategories;
        final bool hasSearchTerm =
            screen._categorySearchQuery.trim().isNotEmpty;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
                'اختر الفئة الرئيسية الأنسب لنوع حسابك. يمكنك تعديل الاختيار لاحقًا.'),
            if (screen._preferredInterfaceTypeOriginal != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'واجهة العرض الحالية: ${screen._preferredInterfaceTypeOriginal}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            screen._buildCategorySearchField(),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 16),
            if (displayCategories.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  screen._buildPlaceholderMessage(
                    hasSearchTerm
                        ? 'لا توجد فئات مطابقة لبحثك. جرّب كلمة مختلفة.'
                        : 'لا توجد فئات متاحة لهذا الحساب حاليًا.',
                  ),
                  if (hasSearchTerm)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () {
                          screen._categorySearchDebounce?.cancel();
                          screen._categorySearchController.clear();
                          screen.setState(() => screen._categorySearchQuery = '');
                        },
                        child: const Text('إعادة ضبط البحث'),
                      ),
                    ),
                ],
              )
            else ...[
              SizedBox(
                height: 236,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
                  itemCount: displayCategories.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _MainCategoryOption option = displayCategories[index];
                    return screen._buildMainCategoryCard(option);
                  },

                ),

              ),
            ],
            if (fetchState is FetchCategoryFailure &&
                screen._mainCategories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: screen._buildErrorCard(
                  message: 'حدث خطأ أثناء تحديث الفئات. حاول مرة أخرى.',
                  onRetry: screen._retryFetchCategories,
                ),
              ),
          ],
        );
      },
    );
  }
}