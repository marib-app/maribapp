part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

class _SearchHeaderBar extends StatelessWidget {
  const _SearchHeaderBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.secondaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ابحث عن شبكة Wi-Fi بالاسم',
            style: TextStyle(
              color: color.textDefaultColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [

              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'مثال: شبكة الحارة أو اسم المقهى',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                          tooltip: 'مسح البحث',
                          icon: const Icon(Icons.clear),
                          onPressed: onClear,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                width: 46,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onRefresh,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                      : const Icon(Icons.refresh),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'تأكد من مطابقة صورة صفحة الدخول قبل الشراء، وأبلغ صاحب الشبكة عن أي مشكلة.',
            style: TextStyle(
              color: color.textDefaultColor.withOpacity(0.75),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}