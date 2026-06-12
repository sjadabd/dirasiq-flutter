import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/teacher_api_service.dart';
import '../../../core/utils/money.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_helpers.dart' show fmtIQD;

/// Teacher → "المحفظة".
///
/// One wallet with two spendable buckets — top-up balance (charged via Wayl to
/// pay platform fees) and video-course earnings (net of commission, credited on
/// each paid sale). Both are withdrawable. The teacher can:
///   - شحن المحفظة  → Wayl top-up link.
///   - طلب سحب      → payout request reviewed + executed by the super-admin.
/// A dedicated video-earnings report (ربحت / سحبت / المتبقي) and the full
/// withdrawals history (with the transfer receipt on confirmed ones) are shown.
class TeacherWalletScreen extends StatefulWidget {
  const TeacherWalletScreen({super.key});
  @override
  State<TeacherWalletScreen> createState() => _TeacherWalletScreenState();
}

class _TeacherWalletScreenState extends State<TeacherWalletScreen>
    with WidgetsBindingObserver {
  final _api = TeacherApiService();
  bool _loading = false;
  bool _preparing = false;
  bool _submittingWithdraw = false;
  bool _awaitingPayment = false;
  Map<String, dynamic> _wallet = const {};
  List<Map<String, dynamic>> _withdrawals = const [];

  static const _minTopup = 1000;
  static const _maxTopup = 5000000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingPayment) {
      _awaitingPayment = false;
      _fetch();
    }
  }

  // ---- numbers --------------------------------------------------------------

  num _n(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  num get _total => _n(_wallet['total'] ?? _wallet['balance']);
  num get _topup => _n(_wallet['topupBalance']);
  num get _videoAvailable => _n(_wallet['videoEarningsAvailable']);
  Map<String, dynamic> get _videoReport =>
      (_wallet['videoReport'] is Map) ? Map<String, dynamic>.from(_wallet['videoReport']) : const {};

  // ---- data -----------------------------------------------------------------

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchWallet(),
        _api.fetchWalletWithdrawals(),
      ]);
      final wRes = results[0];
      _wallet = (wRes['data'] is Map) ? Map<String, dynamic>.from(wRes['data']) : {};
      final dRes = results[1];
      final list = (dRes['data'] is List)
          ? dRes['data'] as List
          : (dRes['data'] is Map && (dRes['data'] as Map)['items'] is List)
              ? (dRes['data'] as Map)['items'] as List
              : const [];
      _withdrawals =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      _toast('تعذّر جلب المحفظة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
      ));
  }

  String? _apiMessage(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map && data['message'] is String) {
        final m = (data['message'] as String).trim();
        if (m.isNotEmpty) return m;
      }
    } catch (_) {}
    return null;
  }

  // ---- top-up flow ----------------------------------------------------------

  Future<void> _startTopup(int amount) async {
    if (_preparing) return;
    setState(() => _preparing = true);
    try {
      final res = await _api.createWalletTopup(amount);
      final data = (res['data'] is Map) ? res['data'] as Map : const {};
      final url = (data['url'] ?? '').toString();
      if (url.isEmpty) {
        _toast('تعذّر إنشاء رابط الدفع — حاول مجدداً');
        return;
      }
      final opened = await _launchPayment(url);
      if (!opened) {
        _toast('تعذّر فتح رابط الدفع');
        return;
      }
      _awaitingPayment = true;
      _toast('بعد إتمام الدفع، عُد إلى التطبيق وسيُحدَّث الرصيد تلقائياً');
    } catch (e) {
      _toast(_apiMessage(e) ?? 'تعذّر بدء عملية الشحن');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<bool> _launchPayment(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
      return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      return false;
    }
  }

  Future<void> _showTopupSheet() async {
    final amountCtl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int? selectedQuick;

    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Theme(
        data: isDark ? MqTheme.dark() : MqTheme.light(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (sheetCtx, setLocal) {
            final mq = sheetCtx.mq;

            void submit() {
              final raw = amountCtl.text.replaceAll(RegExp(r'[^0-9]'), '');
              final amt = int.tryParse(raw);
              if (amt == null || amt < _minTopup) {
                _toast('الحد الأدنى للشحن ${fmtIQD(_minTopup)}');
                return;
              }
              if (amt > _maxTopup) {
                _toast('الحد الأقصى للشحن ${fmtIQD(_maxTopup)}');
                return;
              }
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(sheetCtx, amt);
            }

            Widget quickChip(int value) {
              final sel = selectedQuick == value;
              return MqChip(
                label: fmtIQD(value),
                selected: sel,
                onTap: () {
                  amountCtl.text = value.toString();
                  setLocal(() => selectedQuick = value);
                },
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: mq.card,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MqRadius.xl)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(MqSpacing.lg,
                        MqSpacing.sm, MqSpacing.lg, MqSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sheetGrip(mq),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                  color: mq.accentSoft,
                                  borderRadius: MqRadius.brSm),
                              child: Icon(Icons.add_card_outlined,
                                  size: MqSize.iconSm, color: mq.accent),
                            ),
                            const SizedBox(width: MqSpacing.sm),
                            Expanded(
                              child: Text('شحن المحفظة',
                                  style: sheetCtx.text.titleMedium),
                            ),
                            _sheetClose(sheetCtx),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.lg),
                        TextField(
                          controller: amountCtl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) {
                            if (selectedQuick != null) {
                              setLocal(() => selectedQuick = null);
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'المبلغ (د.ع)',
                            hintText: 'مثال: 25000',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                        ),
                        const SizedBox(height: MqSpacing.sm),
                        Text('الحد الأدنى ${fmtIQD(_minTopup)}',
                            style: sheetCtx.text.labelSmall
                                ?.copyWith(color: mq.ink3)),
                        const SizedBox(height: MqSpacing.md),
                        Wrap(
                          spacing: MqSpacing.sm,
                          runSpacing: MqSpacing.sm,
                          children: [
                            quickChip(10000),
                            quickChip(25000),
                            quickChip(50000),
                            quickChip(100000),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.xl),
                        MqButton(
                          label: 'متابعة الدفع',
                          icon: Icons.arrow_back_rounded,
                          onPressed: submit,
                        ),
                        const SizedBox(height: MqSpacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 13, color: mq.ink3),
                            const SizedBox(width: 4),
                            Text('دفع آمن عبر Wayl',
                                style: sheetCtx.text.labelSmall
                                    ?.copyWith(color: mq.ink3)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), amountCtl.dispose);
    if (amount != null) await _startTopup(amount);
  }

  // ---- withdraw flow --------------------------------------------------------

  Future<void> _showWithdrawSheet() async {
    if (_total <= 0) {
      _toast('لا يوجد رصيد متاح للسحب');
      return;
    }
    final amountCtl = TextEditingController();
    final notesCtl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Theme(
        data: isDark ? MqTheme.dark() : MqTheme.light(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (sheetCtx, setLocal) {
            final mq = sheetCtx.mq;

            void submit() {
              final raw = amountCtl.text.replaceAll(RegExp(r'[^0-9]'), '');
              final amt = int.tryParse(raw);
              if (amt == null || amt < 1000) {
                _toast('الحد الأدنى للسحب ${fmtIQD(1000)}');
                return;
              }
              if (amt > _total) {
                _toast('المبلغ يتجاوز رصيدك المتاح (${fmtMoney(_total)})');
                return;
              }
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(sheetCtx, {'amount': amt, 'notes': notesCtl.text});
            }

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: mq.card,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MqRadius.xl)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(MqSpacing.lg,
                        MqSpacing.sm, MqSpacing.lg, MqSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sheetGrip(mq),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                  color: mq.accentSoft,
                                  borderRadius: MqRadius.brSm),
                              child: Icon(Icons.account_balance_outlined,
                                  size: MqSize.iconSm, color: mq.accent),
                            ),
                            const SizedBox(width: MqSpacing.sm),
                            Expanded(
                              child: Text('طلب سحب الأموال',
                                  style: sheetCtx.text.titleMedium),
                            ),
                            _sheetClose(sheetCtx),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.sm),
                        Text('الرصيد المتاح: ${fmtMoney(_total)} د.ع',
                            style: sheetCtx.text.labelMedium
                                ?.copyWith(color: mq.accent)),
                        const SizedBox(height: MqSpacing.lg),
                        TextField(
                          controller: amountCtl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'المبلغ المطلوب سحبه (د.ع)',
                            hintText: 'مثال: 50000',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                        ),
                        const SizedBox(height: MqSpacing.xs),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => amountCtl.text =
                                _total.round().toString(),
                            child: const Text('سحب كامل الرصيد'),
                          ),
                        ),
                        const SizedBox(height: MqSpacing.sm),
                        TextField(
                          controller: notesCtl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات / تفاصيل التحويل (اختياري)',
                            hintText: 'مثال: رقم الحساب أو وسيلة الاستلام',
                            prefixIcon: Icon(Icons.note_alt_outlined),
                          ),
                        ),
                        const SizedBox(height: MqSpacing.xl),
                        MqButton(
                          label: 'إرسال الطلب',
                          icon: Icons.send_rounded,
                          onPressed: submit,
                        ),
                        const SizedBox(height: MqSpacing.sm),
                        Text(
                          'تتم مراجعة الطلب من الإدارة وتحويل المبلغ خلال 24 ساعة إلى 3 أيام.',
                          style: sheetCtx.text.labelSmall
                              ?.copyWith(color: mq.ink3, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      amountCtl.dispose();
      notesCtl.dispose();
    });

    if (result != null) {
      await _submitWithdraw(
        result['amount'] as int,
        (result['notes'] ?? '').toString(),
      );
    }
  }

  Future<void> _submitWithdraw(int amount, String notes) async {
    if (_submittingWithdraw) return;
    setState(() => _submittingWithdraw = true);
    try {
      await _api.createWalletWithdrawal(amount: amount, notes: notes);
      _toast('تم إرسال طلب السحب — ستتم مراجعته من الإدارة');
      await _fetch();
    } catch (e) {
      _toast(_apiMessage(e) ?? 'تعذّر إرسال طلب السحب');
    } finally {
      if (mounted) setState(() => _submittingWithdraw = false);
    }
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'المحفظة',
              actions: [_RefreshAction(loading: _loading, onTap: _fetch)],
            ),
            drawer: const TeacherDrawer(),
            body: RefreshIndicator(
              onRefresh: _fetch,
              color: mq.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xl),
                children: [
                  _totalCard(context),
                  const SizedBox(height: MqSpacing.md),
                  _bucketsRow(context),
                  const SizedBox(height: MqSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: MqButton(
                          label: _preparing ? 'جارٍ التحضير…' : 'شحن',
                          icon: _preparing ? null : Icons.add_card_outlined,
                          loading: _preparing,
                          onPressed: _preparing ? null : _showTopupSheet,
                        ),
                      ),
                      const SizedBox(width: MqSpacing.md),
                      Expanded(
                        child: MqButton.secondary(
                          label: _submittingWithdraw ? 'جارٍ الإرسال…' : 'طلب سحب',
                          icon: _submittingWithdraw
                              ? null
                              : Icons.account_balance_outlined,
                          loading: _submittingWithdraw,
                          onPressed: (_submittingWithdraw || _total <= 0)
                              ? null
                              : _showWithdrawSheet,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MqSpacing.lg),
                  _videoReportCard(context),
                  const SizedBox(height: MqSpacing.lg),
                  _withdrawalsSection(context),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _totalCard(BuildContext context) {
    final t = context.teacher;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MqSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.heroA, t.heroB],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: MqRadius.brXl,
        boxShadow: t.shadowLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.heroTile,
                  borderRadius: MqRadius.brMd,
                  border: Border.all(color: t.heroLine),
                ),
                child: Icon(Icons.account_balance_wallet_outlined,
                    color: t.heroInk, size: 24),
              ),
              const SizedBox(width: MqSpacing.md),
              Text('إجمالي رصيد المحفظة',
                  style: context.text.titleSmall?.copyWith(color: t.heroInk)),
            ],
          ),
          const SizedBox(height: MqSpacing.xl),
          if (_loading)
            SizedBox(
              height: 36,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    color: context.mq.orange,
                    backgroundColor: t.heroLine,
                  ),
                ),
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text('${fmtMoney(_total)} د.ع',
                  style: MqTypography.mono(
                      color: t.heroInk, size: 34, weight: FontWeight.w700)),
            ),
          const SizedBox(height: MqSpacing.xs),
          Text('المبلغ المتاح للإنفاق والسحب',
              style: context.text.labelSmall?.copyWith(color: t.heroInk2)),
        ],
      ),
    );
  }

  Widget _bucketsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _miniBalance(
            context,
            icon: Icons.add_card_outlined,
            label: 'رصيد الشحن',
            value: _topup,
          ),
        ),
        const SizedBox(width: MqSpacing.md),
        Expanded(
          child: _miniBalance(
            context,
            icon: Icons.smart_display_outlined,
            label: 'أرباح الدورات المرئية',
            value: _videoAvailable,
          ),
        ),
      ],
    );
  }

  Widget _miniBalance(BuildContext context,
      {required IconData icon, required String label, required num value}) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.card,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: MqSize.iconSm, color: mq.accent),
              const SizedBox(width: MqSpacing.xs),
              Expanded(
                child: Text(label,
                    style: context.text.labelSmall?.copyWith(color: mq.ink2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: MqSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text('${fmtMoney(value)} د.ع',
                style: context.text.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _videoReportCard(BuildContext context) {
    final mq = context.mq;
    final r = _videoReport;
    final earned = _n(r['lifetimeEarned']);
    final withdrawn = _n(r['withdrawn']);
    final inFlight = _n(r['inFlight']);
    final available = _n(r['available']);
    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        color: mq.card,
        borderRadius: MqRadius.brLg,
        border: Border.all(color: mq.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_display_outlined,
                  size: MqSize.iconSm, color: mq.accent),
              const SizedBox(width: MqSpacing.sm),
              Text('تقرير الدورات المرئية المدفوعة',
                  style: context.text.titleSmall),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          _reportRow(context, 'إجمالي ما ربحته', earned, strong: true),
          _reportRow(context, 'المبلغ المسحوب', withdrawn),
          if (inFlight > 0) _reportRow(context, 'قيد المعالجة', inFlight),
          const Divider(height: MqSpacing.lg),
          _reportRow(context, 'المتبقي المتاح', available,
              strong: true, color: mq.accent),
        ],
      ),
    );
  }

  Widget _reportRow(BuildContext context, String label, num value,
      {bool strong = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: context.text.bodySmall
                    ?.copyWith(color: context.mq.ink2)),
          ),
          Text('${fmtMoney(value)} د.ع',
              style: (strong
                      ? context.text.titleSmall
                      : context.text.bodyMedium)
                  ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color ?? context.mq.ink)),
        ],
      ),
    );
  }

  Widget _withdrawalsSection(BuildContext context) {
    final mq = context.mq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: MqSize.iconSm, color: mq.ink2),
            const SizedBox(width: MqSpacing.sm),
            Text('السحوبات', style: context.text.titleSmall),
          ],
        ),
        const SizedBox(height: MqSpacing.md),
        if (_withdrawals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: MqSpacing.xl),
            decoration: BoxDecoration(
              color: mq.card,
              borderRadius: MqRadius.brMd,
              border: Border.all(color: mq.line),
            ),
            child: Text('لا توجد طلبات سحب بعد',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: mq.ink3)),
          )
        else
          ..._withdrawals.map((w) => _WithdrawalTile(
                data: w,
                onViewReceipt: _openReceipt,
              )),
      ],
    );
  }

  void _openReceipt(String url) {
    final full = url.startsWith('http') ? url : '${AppConfig.serverBaseUrl}$url';
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(full,
                    errorBuilder: (_, _, _) => const Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('تعذّر تحميل صورة الوصل',
                              style: TextStyle(color: Colors.white)),
                        )),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetGrip(dynamic mq) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: MqSpacing.md),
          decoration:
              BoxDecoration(color: mq.line, borderRadius: MqRadius.brPill),
        ),
      );

  Widget _sheetClose(BuildContext ctx) => InkWell(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.pop(ctx);
        },
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.close_rounded, color: ctx.mq.ink3),
        ),
      );
}

// ---------------------------------------------------------------------------
// Withdrawal tile
// ---------------------------------------------------------------------------

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({required this.data, required this.onViewReceipt});
  final Map<String, dynamic> data;
  final void Function(String url) onViewReceipt;

  num _n(dynamic v) =>
      v is num ? v : (v is String ? num.tryParse(v) ?? 0 : 0);

  ({String label, Color color, IconData icon}) _statusOf(
      BuildContext context, String status) {
    final mq = context.mq;
    switch (status) {
      case 'paid':
        return (label: 'تم التحويل', color: mq.success, icon: Icons.check_circle_outline);
      case 'approved':
        return (label: 'تمت الموافقة', color: mq.accent, icon: Icons.thumb_up_outlined);
      case 'rejected':
        return (label: 'مرفوض', color: mq.error, icon: Icons.cancel_outlined);
      default:
        return (label: 'قيد المراجعة', color: mq.orange, icon: Icons.hourglass_top_outlined);
    }
  }

  String _date(dynamic v) {
    if (v == null) return '';
    final d = DateTime.tryParse(v.toString())?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final status = (data['status'] ?? 'pending').toString();
    final s = _statusOf(context, status);
    final amount = _n(data['amount_iqd']);
    final receipt = (data['payout_receipt_url'] ?? '').toString();
    final reason = (data['rejection_reason'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: MqSpacing.sm),
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.card,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${fmtMoney(amount)} د.ع',
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: MqSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.12),
                  borderRadius: MqRadius.brPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.icon, size: 13, color: s.color),
                    const SizedBox(width: 4),
                    Text(s.label,
                        style: context.text.labelSmall
                            ?.copyWith(color: s.color, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('بتاريخ ${_date(data['created_at'])}',
              style: context.text.labelSmall?.copyWith(color: mq.ink3)),
          if (status == 'rejected' && reason.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.xs),
            Text('سبب الرفض: $reason',
                style: context.text.labelSmall?.copyWith(color: mq.error)),
          ],
          if (status == 'paid' && receipt.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.sm),
            InkWell(
              onTap: () => onViewReceipt(receipt),
              borderRadius: MqRadius.brSm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: MqSpacing.sm, vertical: 6),
                decoration: BoxDecoration(
                  color: mq.accentSoft,
                  borderRadius: MqRadius.brSm,
                  border: Border.all(color: mq.accentLine),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined,
                        size: MqSize.iconSm, color: mq.accent),
                    const SizedBox(width: MqSpacing.xs),
                    Text('عرض وصل التحويل',
                        style: context.text.labelSmall
                            ?.copyWith(color: mq.accent, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RefreshAction extends StatelessWidget {
  const _RefreshAction({required this.loading, required this.onTap});
  final bool loading;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.xs),
      child: Material(
        color: mq.fill,
        shape: RoundedRectangleBorder(
          borderRadius: MqRadius.brMd,
          side: BorderSide(color: mq.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : () => onTap(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: mq.ink3),
                  )
                : Icon(Icons.refresh_rounded,
                    size: MqSize.iconSm, color: mq.ink2),
          ),
        ),
      ),
    );
  }
}
