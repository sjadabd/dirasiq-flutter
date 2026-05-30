// Phase 7 — Filters bottom sheet for the Video Marketplace.
//
// Captures grade / subject / teacher / price range and returns a new
// [VideoMarketplaceFilters] via Navigator.pop. Grade + subject pull from
// existing student catalogs (suggested teachers/courses use the same
// shape). Teacher is a free-text field for now — a full picker is a
// future-phase improvement.
//
// Apply commits via pop(); Reset returns an empty filter set.

import 'package:flutter/material.dart';

import '../controllers/video_marketplace_controller.dart';

class FiltersSheet extends StatefulWidget {
  const FiltersSheet({
    super.key,
    required this.initial,
    required this.gradeOptions,
    required this.subjectOptions,
  });

  final VideoMarketplaceFilters initial;
  final List<Map<String, dynamic>> gradeOptions;
  final List<Map<String, dynamic>> subjectOptions;

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  String? _gradeId;
  String? _subject;
  final _teacherCtl = TextEditingController();
  final _minPriceCtl = TextEditingController();
  final _maxPriceCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _gradeId = widget.initial.gradeId;
    _subject = widget.initial.subject;
    _teacherCtl.text = widget.initial.teacherId ?? '';
    _minPriceCtl.text = widget.initial.minPrice?.toString() ?? '';
    _maxPriceCtl.text = widget.initial.maxPrice?.toString() ?? '';
  }

  @override
  void dispose() {
    _teacherCtl.dispose();
    _minPriceCtl.dispose();
    _maxPriceCtl.dispose();
    super.dispose();
  }

  void _apply() {
    final next = VideoMarketplaceFilters(
      gradeId: (_gradeId ?? '').isEmpty ? null : _gradeId,
      subject: (_subject ?? '').isEmpty ? null : _subject,
      teacherId: _teacherCtl.text.trim().isEmpty
          ? null
          : _teacherCtl.text.trim(),
      minPrice: num.tryParse(_minPriceCtl.text.replaceAll(',', '')),
      maxPrice: num.tryParse(_maxPriceCtl.text.replaceAll(',', '')),
    );
    Navigator.of(context).pop(next);
  }

  void _reset() {
    Navigator.of(context).pop(const VideoMarketplaceFilters());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.tune, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('تصفية النتائج',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            TextButton(onPressed: _reset, child: const Text('مسح')),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _gradeId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'المرحلة',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('الكل')),
              ...widget.gradeOptions.map((g) {
                final id = (g['id'] ?? g['gradeId'] ?? '').toString();
                final label = (g['name'] ?? g['gradeName'] ?? id).toString();
                return DropdownMenuItem<String?>(value: id, child: Text(label));
              }),
            ],
            onChanged: (v) => setState(() => _gradeId = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _subject,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'المادة',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('الكل')),
              ...widget.subjectOptions.map((s) {
                final name = (s['name'] ?? s['subject'] ?? '').toString();
                return DropdownMenuItem<String?>(value: name, child: Text(name));
              }),
            ],
            onChanged: (v) => setState(() => _subject = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _teacherCtl,
            decoration: const InputDecoration(
              labelText: 'المعلّم (UUID اختياري)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _minPriceCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الحد الأدنى للسعر',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _maxPriceCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الحد الأعلى للسعر',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.check),
            label: const Text('تطبيق التصفية'),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
