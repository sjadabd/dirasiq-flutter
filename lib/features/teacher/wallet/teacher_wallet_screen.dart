import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_helpers.dart' show fmtIQD;

/// Teacher → "المحفظة" (Teacher Design System pass).
///
/// Wallet top-up: the teacher enters an amount → the app creates a Wayl
/// payment link via `POST /teacher/wallet/topup` → opens it in the browser →
/// on return the balance is refreshed (the backend webhook credits the wallet
/// once Wayl confirms payment). `fetchWallet` / `createWalletTopup` are the
/// only network calls.
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
  bool _awaitingPayment = false;
  Map<String, dynamic> _wallet = const {};

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
    // Returning from the Wayl browser → pull the (possibly credited) balance.
    if (state == AppLifecycleState.resumed && _awaitingPayment) {
      _awaitingPayment = false;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchWallet();
      _wallet =
          (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
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
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: MqSpacing.md),
                            decoration: BoxDecoration(
                                color: mq.line, borderRadius: MqRadius.brPill),
                          ),
                        ),
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
                            InkWell(
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.pop(sheetCtx);
                              },
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child:
                                    Icon(Icons.close_rounded, color: mq.ink3),
                              ),
                            ),
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

    // Dispose after the sheet's slide-out animation (see the subjects-screen
    // fix: synchronous dispose crashes a still-animating TextField).
    Future.delayed(const Duration(milliseconds: 500), amountCtl.dispose);

    if (amount != null) {
      await _startTopup(amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          final balance = _wallet['balance'];

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
                  _balanceCard(context, balance),
                  const SizedBox(height: MqSpacing.lg),
                  MqButton(
                    label: _preparing ? 'جارٍ التحضير…' : 'شحن المحفظة',
                    icon: _preparing ? null : Icons.add_card_outlined,
                    loading: _preparing,
                    onPressed: _preparing ? null : _showTopupSheet,
                  ),
                  const SizedBox(height: MqSpacing.md),
                  _infoNote(context),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _balanceCard(BuildContext context, dynamic balance) {
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
              Text('رصيد المحفظة',
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
              child: Text(fmtIQD(balance),
                  style: MqTypography.mono(
                      color: t.heroInk, size: 34, weight: FontWeight.w700)),
            ),
          const SizedBox(height: MqSpacing.xs),
          Text('الرصيد الحالي القابل للاستخدام',
              style: context.text.labelSmall?.copyWith(color: t.heroInk2)),
        ],
      ),
    );
  }

  Widget _infoNote(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.accentSoft,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.accentLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: MqSize.iconSm, color: mq.accent),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text(
              'يتم الشحن عبر بوابة الدفع Wayl. بعد إتمام الدفع يُضاف المبلغ '
              'إلى رصيدك تلقائياً خلال لحظات.',
              style: context.text.bodySmall?.copyWith(color: mq.ink2, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
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
