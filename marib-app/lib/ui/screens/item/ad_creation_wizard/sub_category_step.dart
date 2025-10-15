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
    const double cardHeight = 104;
    final BorderRadius radius = BorderRadius.circular(16);
    final BorderRadius imageRadius = const BorderRadiusDirectional.only(
      topEnd: Radius.circular(16),
      bottomEnd: Radius.circular(16),
    ).resolve(Directionality.of(context));
    final BorderRadius radius = BorderRadius.circular(16);
    final String? imageUrl = category.imageUrl?.trim();

    Widget buildThumbnail() {
      final String? imageUrl = category.imageUrl?.trim();

      if (imageUrl != null && imageUrl.isNotEmpty) {
        return LazyNetworkImage(
          imageUrl: imageUrl,
          height: cardHeight,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      }
      return Container(
        height: cardHeight,
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
              color:
              isSelected ? colors.secondaryContainer : colors.surface,
              border: Border.all(
                color:
                isSelected ? colors.secondary : colors.outlineVariant,
                width: isSelected ? 2 : 1,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colors.shadow.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SizedBox(
                height: cardHeight,
                child: Row(
                  textDirection: TextDirection.rtl,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: imageRadius,
                    child: SizedBox(
                      width: 104,
                      child: buildThumbnail(),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
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


      return screen
          ._buildPlaceholderMessage('لا توجد فئات فرعية متاحة لهذه الفئة.');
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