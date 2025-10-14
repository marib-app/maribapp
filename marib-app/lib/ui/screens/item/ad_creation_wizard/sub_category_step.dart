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
    final BorderRadius radius = BorderRadius.circular(16);
    final String? imageUrl = category.imageUrl?.trim();

    Widget buildThumbnail() {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        return LazyNetworkImage(
          imageUrl: imageUrl,
          height: 100,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      }
      return Container(
        height: 100,
        width: double.infinity,
        color: colors.surfaceVariant,
        alignment: Alignment.center,
        child: Icon(
          Icons.category,
          color: colors.onSurfaceVariant,
          size: 36,
        ),
      );
    }

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
                setState(() => _pressedSubCategoryId = category.id);
              } else if (_pressedSubCategoryId == category.id) {
                setState(() => _pressedSubCategoryId = null);
              }
            },
            onTap: () => _onSubCategorySelected(category),
            child: Ink(
              width: 180,
              decoration: BoxDecoration(
                borderRadius: radius,
                color: isSelected
                    ? colors.secondaryContainer
                    : colors.surface,
                border: Border.all(
                  color: isSelected
                      ? colors.secondary
                      : colors.outlineVariant,
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
                    child: buildThumbnail(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
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
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
              itemCount: displayCategories.length,
              itemBuilder: (BuildContext context, int index) {
                final _SubCategoryOption option = displayCategories[index];
                return screen._buildSubCategoryCard(option);
              },
            ),
          ),
      ],
    );
  }
}