part of 'ad_creation_wizard_screen.dart';

extension _SubCategoryStepView on _AdCreationWizardScreenState {
  Widget _buildSubCategoryStep() => _SubCategoryStepContent(screen: this);


  Widget _buildSubCategorySearchField() {
    final ThemeData theme = Theme.of(context);
    return TextField(
      controller: _subCategorySearchController,
      onChanged: _onSubCategorySearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        labelText: 'بحث عن فئة فرعية',
        hintText: 'اكتب اسم الفئة الفرعية للعثور عليها بسرعة',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.25),
      ),
    );
  }

  void _onSubCategorySearchChanged(String value) {
    _subCategorySearchDebounce?.cancel();
    final String query = value;
    _subCategorySearchDebounce =
        Timer(const Duration(milliseconds: 180), () {
          if (!mounted) {
            return;
          }
          setState(() {
            _subCategorySearchQuery = query;
          });
        });
  }

  void _resetSubCategorySearch() {
    _subCategorySearchDebounce?.cancel();
    if (_subCategorySearchController.text.isNotEmpty) {
      _subCategorySearchController.clear();
    }
    if (!mounted) {
      _subCategorySearchQuery = '';
      return;
    }
    setState(() {
      _subCategorySearchQuery = '';
    });
  }

  Widget _buildSubCategoryCard(_SubCategoryOption category) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isSelected = _selectedSubCategory?.id == category.id;
    final bool isPressed = _pressedSubCategoryId == category.id;
    const double cardHeight = 82;
    const double thumbnailSize = 64;
    final BorderRadius radius = BorderRadius.circular(16);
    final BorderRadius imageRadius = const BorderRadiusDirectional.only(
      topStart: Radius.circular(16),
      bottomStart: Radius.circular(16),
    ).resolve(Directionality.of(context));


    Widget buildCategoryFallback() {
      return Container(
        height: double.infinity,
        width: double.infinity,
        color: colors.territoryColor.withOpacity(0.12),
        alignment: Alignment.center,
        child: Icon(
          Icons.category,
          color: colors.onSurfaceVariant,
          size: 32,
        ),
      );
    }


    Widget buildThumbnail() {
      final String? imageUrl = category.imageUrl?.trim();

      if (imageUrl != null && imageUrl.isNotEmpty) {
        return LazyNetworkImage(
          imageUrl: imageUrl,
          height: double.infinity,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: buildCategoryFallback(),
          errorWidget: buildCategoryFallback(),
        );
      }
      return Container(
        height: double.infinity,
        width: double.infinity,
        color: colors.surfaceVariant,
        alignment: Alignment.center,
        child: Icon(
          Icons.category,
          color: colors.onSurfaceVariant,
          size: 32,
        ),
      );
    }

    return AnimatedScale(
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
              setState(() => _pressedSubCategoryId = category.id);
            } else if (_pressedSubCategoryId == category.id) {
              setState(() => _pressedSubCategoryId = null);
            }
          },
          onTap: () => _onSubCategorySelected(category),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: isSelected
                  ? colors.territoryColor.withOpacity(0.12)
                  : colors.secondaryColor,
              border: Border.all(color: colors.borderColor),
            ),
            child: SizedBox(
              height: cardHeight,
              child: Row(
                textDirection: TextDirection.rtl,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: imageRadius,
                    child: SizedBox.square(
                      dimension: thumbnailSize,
                      child: buildThumbnail(),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  category.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? colors.onSecondaryContainer
                                        : colors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_left,
                            color: isSelected
                                ? colors.onSecondaryContainer
                                : colors.onSurfaceVariant,
                            size: 20,
                          ),
                        ],
                      ),
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

class _SubCategoryStepContent extends StatelessWidget {
  const _SubCategoryStepContent({required this.screen});

  final _AdCreationWizardScreenState screen;

  @override
  Widget build(BuildContext context) {
    final _MainCategoryOption? mainCategory = screen._selectedMainCategory;
    if (mainCategory == null) {
      return screen._buildPlaceholderMessage(
          'يرجى اختيار الفئة الرئيسية أولًا لمتابعة اختيار الفئة الفرعية.');
    }

    final List<_SubCategoryOption> displayCategories =
    screen._filteredSubCategories(mainCategory);
    final bool hasSearchTerm =
        screen._subCategorySearchQuery.trim().isNotEmpty;

    if (mainCategory.subCategories.isEmpty) {


      screen._ensureSubCategoryFetch(mainCategory.id);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          Text('جارٍ تحميل الفئات الفرعية المتاحة...'),
          SizedBox(height: 16),
          _CategoryListShimmer(itemCount: 4),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('اختر الفئة الفرعية المناسبة لإعلانك ضمن ${mainCategory.name}.'),
        const SizedBox(height: 12),
        screen._buildSubCategorySearchField(),
        const SizedBox(height: 16),
        if (displayCategories.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              screen._buildPlaceholderMessage(
                hasSearchTerm
                    ? 'لا توجد فئات فرعية مطابقة لبحثك. جرّب كلمة مختلفة.'
                    : 'لا توجد فئات فرعية متاحة لهذه الفئة.',
              ),
              if (hasSearchTerm)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: screen._resetSubCategorySearch,
                    child: const Text('إعادة ضبط البحث'),
                  ),
                ),
            ],
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: displayCategories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final _SubCategoryOption option = displayCategories[index];
              return screen._buildSubCategoryCard(option);
            },
          ),
      ],
    );
  }
}