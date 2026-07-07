import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/features/student_home/data/models/student_home_data.dart';
import 'package:mulhimiq/features/student_home/presentation/widgets/sh_common.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'package:mulhimiq/shared/widgets/status_views.dart';

/// Full-screen detail for a [ContentFeedItem] from the home feed.
class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({super.key});

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  final _api = ApiService();
  ContentFeedItem? _item;
  Map<String, dynamic> _detail = {};
  bool _loading = true;
  String? _error;
  bool _viewRecorded = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is ContentFeedItem) {
      _item = args;
    } else if (args is Map) {
      _item = ContentFeedItem.fromJson(Map<String, dynamic>.from(args));
    }
    _load();
  }

  Future<void> _load() async {
    final item = _item;
    if (item == null) {
      setState(() {
        _loading = false;
        _error = 'تعذر فتح المحتوى';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Map<String, dynamic> detail;
      if (item.isAd) {
        detail = await _api.fetchAdvertisementDetail(item.id);
        if (!_viewRecorded) {
          _viewRecorded = true;
          try {
            await _api.recordAdvertisementView(item.id);
          } catch (_) {}
        }
      } else {
        detail = await _api.fetchContentFeedNewsDetail(item.id);
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _text(List<String> keys) {
    for (final k in keys) {
      final v = _detail[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final mq = context.mq;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: mq.page,
        appBar: AppBar(
          title: Text(item?.badgeLabel ?? 'التفاصيل'),
          backgroundColor: mq.page,
          elevation: 0,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? StatusView.error(message: _error!, onAction: _load)
                : ListView(
                    padding: const EdgeInsets.all(MqSpacing.lg),
                    children: [
                      ShCover(
                        url: resolveAssetUrl(_text(['coverImageUrl', 'cover_image_url'])) != ''
                            ? resolveAssetUrl(_text(['coverImageUrl', 'cover_image_url']))
                            : (item?.imageUrl ?? ''),
                        icon: item?.isAd == true ? Icons.campaign_outlined : Icons.newspaper_outlined,
                        borderRadius: BorderRadius.circular(MqRadius.lg),
                      ),
                      const SizedBox(height: MqSpacing.lg),
                      if (item != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Chip(
                            label: Text(item.badgeLabel),
                            backgroundColor: item.isAd ? mq.orangeSoft : mq.accentSoft,
                          ),
                        ),
                      const SizedBox(height: MqSpacing.sm),
                      Text(
                        _text(['title']).isNotEmpty ? _text(['title']) : (item?.title ?? ''),
                        style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (_text(['publisherName', 'publisher_name']).isNotEmpty ||
                          (item?.publisherName ?? '').isNotEmpty) ...[
                        const SizedBox(height: MqSpacing.sm),
                        Text(
                          _text(['publisherName', 'publisher_name']).isNotEmpty
                              ? _text(['publisherName', 'publisher_name'])
                              : (item?.publisherName ?? ''),
                          style: context.text.bodyMedium?.copyWith(color: mq.ink3),
                        ),
                      ],
                      if (_text(['governorate', 'teacherGovernorate', 'teacher_governorate']).isNotEmpty) ...[
                        const SizedBox(height: MqSpacing.xs),
                        Text(
                          'المحافظة: ${_text(['governorate', 'teacherGovernorate', 'teacher_governorate'])}',
                          style: context.text.bodySmall?.copyWith(color: mq.ink3),
                        ),
                      ],
                      const SizedBox(height: MqSpacing.lg),
                      Text(
                        _text(['description', 'details']).isNotEmpty
                            ? _text(['description', 'details'])
                            : 'لا يوجد وصف إضافي.',
                        style: context.text.bodyLarge,
                      ),
                    ],
                  ),
      ),
    );
  }
}
