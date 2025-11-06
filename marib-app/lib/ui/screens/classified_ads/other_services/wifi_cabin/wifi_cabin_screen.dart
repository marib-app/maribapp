import 'package:flutter/material.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/app/app_scroll_behavior.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';

// واجهة وهمية لخدمة "كبينة واي فاي" مع نفس اسم الكلاس.
// لا توجد أي استدعاءات شبكة. كل شيء محلي لعرض التدفق فقط.

class WifiCabinScreen extends StatefulWidget {
  const WifiCabinScreen({super.key});

  static Route route(RouteSettings settings) {
    return AppPageRoute.build(
      builder: (_) => const WifiCabinScreen(),
      settings: settings,
      maintainState: true,
      motionPattern: AppMotionPattern.glide,
    );
  }

  @override
  State<WifiCabinScreen> createState() => _WifiCabinScreenState();
}

class _WifiCabinScreenState extends State<WifiCabinScreen>
    with TickerProviderStateMixin {
  // تبويب عام
  late final TabController _tab = TabController(length: 3, vsync: this);

  // حالة نموذج "إضافة شبكة"
  final _formKey = GlobalKey<FormState>();
  final _ownerName = TextEditingController();
  final _networkName = TextEditingController();
  final _slug = TextEditingController();
  final _notes = TextEditingController();
  final _commission = TextEditingController(text: '5'); // عمولة افتراضية %

  // صور وملفات وهمية
  String? _logoFile;
  String? _loginPageShot;
  // موقع
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _radiusKm = TextEditingController(text: '2');

  // تواصل
  final List<TextEditingController> _phones = [TextEditingController()];

  // خطوة داخل شاشة إضافة شبكة
  int _step = 0; // 0..3

  // الفئات (الخطط) + ملفات الأكواد
  final List<_DraftPlan> _plans = [];

  // الطلبات الوهمية
  final List<_DraftRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _networkName.addListener(() {
      if (_slug.text.trim().isEmpty) {
        _slug.text = _slugify(_networkName.text);
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _ownerName.dispose();
    _networkName.dispose();
    _slug.dispose();
    _notes.dispose();
    _commission.dispose();
    _lat.dispose();
    _lng.dispose();
    _radiusKm.dispose();
    for (final c in _phones) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: 'wifiCabin'.translate(context),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _HeaderBanner(),
          const SizedBox(height: 8),
          TabBar(
            controller: _tab,
            labelColor: color.primary,
            unselectedLabelColor: color.onSurface.withOpacity(.6),
            tabs: const [
              Tab(text: 'الخدمة'),
              Tab(text: 'إضافة شبكة'),
              Tab(text: 'طلباتي'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: AppScrollBehavior.defaultPhysics,
              children: [
                _buildOverviewTab(),
                _buildAddNetworkTab(),
                _buildRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // تبويب 1: نظرة عامة مختصرة + CTA
  Widget _buildOverviewTab() {
    final c = context.color;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'كبينة واي فاي لملاك شبكات MikroTik',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
         //   color: c.textDefaultColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'أضف شبكتك. ارفع أكوادك بصيغ CSV/XLSX. نبيع للمستخدمين داخل التطبيق. '
              'يُسلَّم الكود فور الدفع. تُحتسب العمولة، وتُحوَّل بقية المبالغ لمحفظتك.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(text: 'ملفات أكواد مرتبة (سطر=كود)'),
            _Chip(text: 'فئات (كرت 200 ريال، 500 ريال...)'),
            _Chip(text: 'عمولة لكل شبكة أو فئة'),
            _Chip(text: 'موقع الشبكة ونطاق التغطية'),
            _Chip(text: 'إشعارات حالة الطلب'),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _tab.index = 1,
          icon: const Icon(Icons.add),
          label: const Text('ابدأ بإضافة شبكتك'),
        ),
      ],
    );
  }

  // تبويب 2: إضافة شبكة جديدة (مع خطوات داخلية بسيطة)
  Widget _buildAddNetworkTab() {
    final steps = ['بيانات الشبكة', 'الموقع والتواصل', 'الفئات والأكواد', 'مراجعة وإرسال'];
    return Column(
      children: [
        const SizedBox(height: 12),
        _StepsHeader(current: _step, steps: steps),
        const SizedBox(height: 8),
        Expanded(
          child: Form(
            key: _formKey,
            child: IndexedStack(
              index: _step,
              children: [
                _buildStepNetworkInfo(),
                _buildStepLocationContacts(),
                _buildStepPlans(),
                _buildStepReview(),
              ],
            ),
          ),
        ),
        _buildStepControls(),
      ],
    );
  }

  // تبويب 3: طلباتي
  Widget _buildRequestsTab() {
    if (_requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 56),
              const SizedBox(height: 8),
              const Text('لا توجد طلبات بعد'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _tab.index = 1,
                child: const Text('قدّم طلب شبكة جديدة'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final r = _requests[i];
        return Card(
          child: ListTile(
            title: Text(r.networkName),
            subtitle: Text('الحالة: ${r.statusLabel} • الخطط: ${r.plans.length}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRequestDetails(r),
          ),
        );
      },
    );
  }

  // ———————— الخطوات ————————

  Widget _buildStepNetworkInfo() {
    final c = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SectionTitle('بيانات الشبكة'),
        TextFormField(
          controller: _ownerName,
          decoration: const InputDecoration(labelText: 'اسم مالك الشبكة'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _networkName,
          decoration: const InputDecoration(labelText: 'اسم الشبكة'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _slug,
          decoration: const InputDecoration(labelText: 'اسم مختصر (slug)'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FilePickerFake(
                label: 'شعار الشبكة',
                value: _logoFile,
                onPick: () => setState(() => _logoFile = 'logo_sample.png'),
                onClear: () => setState(() => _logoFile = null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FilePickerFake(
                label: 'صورة صفحة تسجيل الدخول',
                value: _loginPageShot,
                onPick: () => setState(() => _loginPageShot = 'login_page.png'),
                onClear: () => setState(() => _loginPageShot = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _commission,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'عمولة افتراضية للشبكة (%)',
            helperText: 'تُطبق إذا لم تُحدد عمولة خاصة للفئة',
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'مطلوب';
            final num? n = num.tryParse(v);
            if (n == null || n < 0) return 'قيمة غير صالحة';
            return null;
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline, color: c.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('لن تُرفع ملفات حقيقية. هذه واجهة تجريبية فقط.'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepLocationContacts() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SectionTitle('الموقع والتغطية'),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _lat,
                decoration: const InputDecoration(labelText: 'خط العرض (lat)'),
                validator: _required,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lng,
                decoration: const InputDecoration(labelText: 'خط الطول (lng)'),
                validator: _required,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _radiusKm,
          decoration: const InputDecoration(labelText: 'نصف قطر التغطية (كم)'),
          keyboardType: TextInputType.number,
          validator: _required,
        ),
        const SizedBox(height: 16),
        _SectionTitle('أرقام التواصل'),
        ..._phones.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: c,
                    decoration: InputDecoration(labelText: 'رقم ${i + 1}'),
                    keyboardType: TextInputType.phone,
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _phones.length == 1
                      ? null
                      : () => setState(() {
                    final removed = _phones.removeAt(i);
                    removed.dispose();
                  }),
                  icon: const Icon(Icons.remove_circle_outline),
                )
              ],
            ),
          );
        }),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _phones.add(TextEditingController())),
            icon: const Icon(Icons.add),
            label: const Text('إضافة رقم'),
          ),
        ),
      ],
    );
  }

  Widget _buildStepPlans() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SectionTitle('الفئات والأكواد'),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            onPressed: _addPlanDialog,
            icon: const Icon(Icons.add),
            label: const Text('إضافة فئة كرت'),
          ),
        ),
        const SizedBox(height: 12),
        if (_plans.isEmpty)
          const Text('لا توجد فئات بعد.'),
        ..._plans.map((p) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name.isEmpty ? 'فئة بدون اسم' : p.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Switch(
                      value: p.active,
                      onChanged: (v) => setState(() => p.active = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill('السعر: ${p.price} ${p.currency}'),
                    if (p.dataCap.isNotEmpty) _InfoPill('البيانات: ${p.dataCap}'),
                    if (p.validityDays.isNotEmpty) _InfoPill('الصلاحية: ${p.validityDays} يوم'),
                    if (p.speed.isNotEmpty) _InfoPill('السرعة: ${p.speed}'),
                    if (p.commission?.isNotEmpty == true) _InfoPill('عمولة: ${p.commission}%'),
                  ],
                ),
                const SizedBox(height: 12),
                _FilePickerFake(
                  label: 'ملف الأكواد (CSV/XLSX)',
                  value: p.codesFile,
                  onPick: () => setState(() => p.codesFile = 'codes_${p.name}.xlsx'),
                  onClear: () => setState(() => p.codesFile = null),
                  helper: 'يُتوقع سطر = كود. سيُقرأ من أول صف تلقائيًا.',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _editPlanDialog(p),
                      icon: const Icon(Icons.edit),
                      label: const Text('تعديل'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => setState(() => _plans.remove(p)),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف'),
                    ),
                  ],
                )
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildStepReview() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SectionTitle('مراجعة'),
        _SummaryRow('مالك الشبكة', _ownerName.text),
        _SummaryRow('اسم الشبكة', _networkName.text),
        _SummaryRow('Slug', _slug.text),
        _SummaryRow('شعار', _logoFile ?? 'غير محدد'),
        _SummaryRow('صورة تسجيل الدخول', _loginPageShot ?? 'غير محدد'),
        _SummaryRow('الموقع', '$_lat / $_lng • نصف القطر ${_radiusKm.text} كم'),
        _SummaryRow('أرقام التواصل', _phones.map((e) => e.text).where((e) => e.isNotEmpty).join(', ')),
        _SummaryRow('عمولة الشبكة', '${_commission.text}%'),
        if (_notes.text.isNotEmpty) _SummaryRow('ملاحظات', _notes.text),
        const SizedBox(height: 12),
        _SectionTitle('الفئات'),
        if (_plans.isEmpty) const Text('لا توجد فئات.'),
        ..._plans.map((p) => _SummaryRow(
          p.name,
          [
            'السعر: ${p.price} ${p.currency}',
            if (p.dataCap.isNotEmpty) 'البيانات: ${p.dataCap}',
            if (p.validityDays.isNotEmpty) 'الصلاحية: ${p.validityDays} يوم',
            if (p.speed.isNotEmpty) 'السرعة: ${p.speed}',
            if (p.commission?.isNotEmpty == true) 'عمولة: ${p.commission}%',
            'الملف: ${p.codesFile ?? 'غير مرفوع'}',
            'الحالة: ${p.active ? 'نشطة' : 'موقوفة'}',
          ].join(' • '),
        )),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notes,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'ملاحظات إضافية (اختياري)',
          ),
        ),
      ],
    );
  }

  Widget _buildStepControls() {
    final isFirst = _step == 0;
    final isLast = _step == 3;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isFirst ? null : () => setState(() => _step--),
                child: const Text('رجوع'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (!isLast) {
                    if (_validateCurrentStep()) {
                      setState(() => _step++);
                    }
                  } else {
                    if (_validateAll()) {
                      _submitDraft();
                    }
                  }
                },
                child: Text(isLast ? 'تقديم الطلب' : 'التالي'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validateCurrentStep() {
    switch (_step) {
      case 0:
        return _validateFields([_ownerName, _networkName, _commission]);
      case 1:
        return _validateFields([_lat, _lng, _radiusKm, ..._phones]);
      case 2:
        if (_plans.isEmpty) {
          _showSnack('أضف فئة واحدة على الأقل');
          return false;
        }
        return true;
      case 3:
        return true;
      default:
        return true;
    }
  }

  bool _validateAll() {
    if (!_validateCurrentStep()) return false;
    final saved = _step;
    bool ok = true;
    for (int i = 0; i < 3; i++) {
      _step = i;
      if (!_validateCurrentStep()) {
        ok = false;
        break;
      }
    }
    _step = saved;
    if (!ok) setState(() {});
    return ok;
  }

  bool _validateFields(List<TextEditingController> ctrls) {
    for (final c in ctrls) {
      if (c.text.trim().isEmpty) {
        _showSnack('يرجى تعبئة الحقول المطلوبة');
        return false;
      }
    }
    return true;
  }

  void _submitDraft() {
    final r = _DraftRequest(
      id: DateTime.now().millisecondsSinceEpoch,
      ownerName: _ownerName.text.trim(),
      networkName: _networkName.text.trim(),
      slug: _slug.text.trim(),
      commission: _commission.text.trim(),
      lat: _lat.text.trim(),
      lng: _lng.text.trim(),
      radiusKm: _radiusKm.text.trim(),
      phones: _phones.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList(),
      logoFile: _logoFile,
      loginShot: _loginPageShot,
      notes: _notes.text.trim(),
      plans: List<_DraftPlan>.from(_plans),
      status: _RequestStatus.pending,
    );
    setState(() {
      _requests.insert(0, r);
      _resetForm();
      _tab.index = 2; // إلى "طلباتي"
    });
    _showSnack('تم إرسال الطلب. يمكنك المتابعة في "طلباتي".');
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _ownerName.clear();
    _networkName.clear();
    _slug.clear();
    _commission.text = '5';
    _lat.clear();
    _lng.clear();
    _radiusKm.text = '2';
    for (final c in _phones) {
      c.dispose();
    }
    _phones
      ..clear()
      ..add(TextEditingController());
    _logoFile = null;
    _loginPageShot = null;
    _plans.clear();
    _notes.clear();
    _step = 0;
  }

  // ———————— الحوارات ————————

  Future<void> _addPlanDialog() async {
    final p = await showDialog<_DraftPlan>(
      context: context,
      builder: (_) => _PlanDialog(),
    );
    if (p != null) {
      setState(() => _plans.add(p));
    }
  }

  Future<void> _editPlanDialog(_DraftPlan plan) async {
    final updated = await showDialog<_DraftPlan>(
      context: context,
      builder: (_) => _PlanDialog(initial: plan),
    );
    if (updated != null) {
      setState(() {
        final i = _plans.indexOf(plan);
        if (i >= 0) _plans[i] = updated;
      });
    }
  }

  // ———————— أدوات ————————

  void _showRequestDetails(_DraftRequest r) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تفاصيل الطلب', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _SummaryRow('المالك', r.ownerName),
            _SummaryRow('الشبكة', r.networkName),
            _SummaryRow('الحالة', r.statusLabel),
            _SummaryRow('العمولة', '${r.commission}%'),
            const SizedBox(height: 8),
            Text('الفئات (${r.plans.length})'),
            const SizedBox(height: 6),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: r.plans.length,
                itemBuilder: (_, i) {
                  final p = r.plans[i];
                  return Container(
                    width: 220,
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('السعر: ${p.price} ${p.currency} • الحالة: ${p.active ? 'نشطة' : 'موقوفة'}'),
                        if (p.codesFile != null) Text('ملف الأكواد: ${p.codesFile}'),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'سيتم ربط التحكم والموافقة والرفض لاحقًا من الخادم. هذه واجهة عرض فقط.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null;

  String _slugify(String input) {
    final plain = input.trim().toLowerCase();
    final replaced = plain.replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '-');
    return replaced.replaceAll(RegExp('-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    // ملاحظة: يدعم العربية واللاتينية بشكل مبسّط.
  }
}

// ———————— عناصر مساعدة ————————

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.primaryContainer.withOpacity(.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: const [
          Icon(Icons.wifi_tethering, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'خدمة بيع أكواد شبكات MikroTik داخل التطبيق — واجهة تجريبية.',
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsHeader extends StatelessWidget {
  const _StepsHeader({required this.current, required this.steps});
  final int current;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepDot(active: i == current, label: steps[i]),
            if (i != steps.length - 1) const Expanded(child: Divider(height: 1)),
          ]
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.active, required this.label});
  final bool active;
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: active ? c.primary : c.outlineVariant,
          child: const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: active ? c.primary : c.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text),
    );
  }
}

class _FilePickerFake extends StatelessWidget {
  const _FilePickerFake({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
    this.helper,
  });
  final String label;
  final String? value;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                value ?? 'لم يتم اختيار ملف',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onPick,
              child: const Text('اختيار'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: value == null ? null : onClear,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!, style: Theme.of(context).textTheme.bodySmall),
        ]
      ],
    );
  }
}

// ———————— بيانات وهمية ————————

class _DraftPlan {
  _DraftPlan({
    required this.name,
    required this.price,
    required this.currency,
    this.dataCap = '',
    this.validityDays = '',
    this.speed = '',
    this.commission,
    this.active = true,
    this.codesFile,
  });

  String name;
  String price;
  String currency;
  String dataCap;
  String validityDays;
  String speed;
  String? commission;
  bool active;
  String? codesFile;
}

enum _RequestStatus { pending, accepted, rejected }

class _DraftRequest {
  _DraftRequest({
    required this.id,
    required this.ownerName,
    required this.networkName,
    required this.slug,
    required this.commission,
    required this.lat,
    required this.lng,
    required this.radiusKm,
    required this.phones,
    required this.logoFile,
    required this.loginShot,
    required this.notes,
    required this.plans,
    required this.status,
  });

  final int id;
  final String ownerName;
  final String networkName;
  final String slug;
  final String commission;
  final String lat;
  final String lng;
  final String radiusKm;
  final List<String> phones;
  final String? logoFile;
  final String? loginShot;
  final String notes;
  final List<_DraftPlan> plans;
  final _RequestStatus status;

  String get statusLabel {
    switch (status) {
      case _RequestStatus.pending:
        return 'قيد المراجعة';
      case _RequestStatus.accepted:
        return 'مقبول';
      case _RequestStatus.rejected:
        return 'مرفوض';
    }
  }
}

// ———————— حوار إضافة/تعديل فئة ————————

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({this.initial});
  final _DraftPlan? initial;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _currency;
  final _dataCap = TextEditingController();
  final _validity = TextEditingController();
  final _speed = TextEditingController();
  final _commission = TextEditingController();
  bool _active = true;
  String? _codesFile;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(text: p?.price ?? '');
    _currency = TextEditingController(text: p?.currency ?? 'YER');
    _dataCap.text = p?.dataCap ?? '';
    _validity.text = p?.validityDays ?? '';
    _speed.text = p?.speed ?? '';
    _commission.text = p?.commission ?? '';
    _active = p?.active ?? true;
    _codesFile = p?.codesFile;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _currency.dispose();
    _dataCap.dispose();
    _validity.dispose();
    _speed.dispose();
    _commission.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'إضافة فئة' : 'تعديل الفئة'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الفئة'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'السعر'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _currency,
                      decoration: const InputDecoration(labelText: 'العملة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dataCap,
                decoration: const InputDecoration(labelText: 'سعة البيانات (اختياري)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _validity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الصلاحية بالأيام (اختياري)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _speed,
                decoration: const InputDecoration(labelText: 'السرعة (اختياري)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commission,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'عمولة الفئة % (اختياري)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _FilePickerFake(
                      label: 'ملف الأكواد (CSV/XLSX)',
                      value: _codesFile,
                      onPick: () => setState(() => _codesFile = 'codes.xlsx'),
                      onClear: () => setState(() => _codesFile = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                title: const Text('تفعيل الفئة'),
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState?.validate() != true) return;
            final p = _DraftPlan(
              name: _name.text.trim(),
              price: _price.text.trim(),
              currency: _currency.text.trim().toUpperCase(),
              dataCap: _dataCap.text.trim(),
              validityDays: _validity.text.trim(),
              speed: _speed.text.trim(),
              commission: _commission.text.trim().isEmpty ? null : _commission.text.trim(),
              active: _active,
              codesFile: _codesFile,
            );
            Navigator.pop(context, p);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

// ———————— عناصر ملخص ————————

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: style?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}
