import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../shared/design/teacher_design.dart';

/// Office-location picker mirroring the web dashboard's Leaflet map:
/// OpenStreetMap tiles, tap-to-place marker, GPS "locate me", place search
/// (Nominatim, biased to Iraq), and +/- zoom controls.
///
/// When [enabled] is false the map is read-only (no tap/search/GPS) but zoom
/// still works so the saved location can be inspected. Emits 6-decimal
/// lat/lng via [onChanged] on every change.
class TeacherLocationPicker extends StatefulWidget {
  const TeacherLocationPicker({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.enabled,
    required this.onChanged,
  });

  final double? latitude;
  final double? longitude;
  final bool enabled;
  final void Function(double lat, double lng) onChanged;

  @override
  State<TeacherLocationPicker> createState() => _TeacherLocationPickerState();
}

class _TeacherLocationPickerState extends State<TeacherLocationPicker> {
  static const LatLng _baghdad = LatLng(33.3152, 44.3661);

  final MapController _map = MapController();
  final TextEditingController _searchCtl = TextEditingController();
  LatLng? _point;
  bool _locating = false;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    if (widget.latitude != null && widget.longitude != null) {
      _point = LatLng(widget.latitude!, widget.longitude!);
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TeacherLocationPicker old) {
    super.didUpdateWidget(old);
    if (widget.latitude != old.latitude || widget.longitude != old.longitude) {
      if (widget.latitude != null && widget.longitude != null) {
        _point = LatLng(widget.latitude!, widget.longitude!);
      } else {
        _point = null;
      }
    }
  }

  LatLng get _center => _point ?? _baghdad;

  void _setPoint(LatLng p) {
    final lat = double.parse(p.latitude.toStringAsFixed(6));
    final lng = double.parse(p.longitude.toStringAsFixed(6));
    setState(() => _point = LatLng(lat, lng));
    widget.onChanged(lat, lng);
  }

  void _zoomBy(double delta) {
    final cam = _map.camera;
    final z = (cam.zoom + delta).clamp(3.0, 18.0);
    _map.move(cam.center, z);
  }

  Future<void> _search() async {
    final q = _searchCtl.text.trim();
    if (q.isEmpty || _searching) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _searching = true);
    try {
      // OpenStreetMap Nominatim — same provider the web dashboard searches with.
      // countrycodes=iq biases results to Iraq for accuracy; ar returns Arabic
      // names. Nominatim requires a descriptive User-Agent.
      final dio = Dio();
      final res = await dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'format': 'json',
          'q': q,
          'limit': 1,
          'countrycodes': 'iq',
          'accept-language': 'ar',
        },
        options: Options(
          headers: {'User-Agent': 'MulhimIQ-App/1.0 (teacher-profile)'},
          responseType: ResponseType.json,
        ),
      );
      final list = res.data ?? const [];
      if (list.isEmpty) {
        Get.snackbar(
          'بحث',
          'لم يُعثر على هذا المكان — جرّب صياغة أخرى',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final first = list.first as Map;
      final lat = double.tryParse('${first['lat']}');
      final lng = double.tryParse('${first['lon']}');
      if (lat == null || lng == null) return;
      final p = LatLng(lat, lng);
      _setPoint(p);
      _map.move(p, 15);
    } catch (_) {
      Get.snackbar(
        'بحث',
        'تعذّر البحث — تحقّق من الاتصال',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        Get.snackbar(
          'الموقع',
          'خدمة الموقع غير مفعّلة على الجهاز',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        Get.snackbar(
          'الموقع',
          'لم يتم منح إذن الوصول إلى الموقع',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final p = LatLng(pos.latitude, pos.longitude);
      _setPoint(p);
      _map.move(p, 16);
    } catch (e) {
      Get.snackbar(
        'الموقع',
        'تعذّر تحديد الموقع الحالي',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.enabled) ...[
          Text(
            'اضغط على الخريطة أو ابحث لتحديد موقع مكتبك ليجدك الطلاب القريبون',
            style: context.text.bodySmall?.copyWith(color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.sm),
          TextField(
            controller: _searchCtl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'مثال: شارع المتنبي، بغداد',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'بحث',
                      onPressed: _search,
                    ),
            ),
          ),
          const SizedBox(height: MqSpacing.sm),
        ],
        ClipRRect(
          borderRadius: MqRadius.brMd,
          child: SizedBox(
            height: 260,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _point == null ? 11 : 14,
                    minZoom: 3,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onTap: widget.enabled
                        ? (_, point) => _setPoint(point)
                        : null,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mulhimiq.app',
                    ),
                    if (_point != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _point!,
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.location_on,
                              color: mq.accent,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Zoom controls (always available, even in view mode).
                PositionedDirectional(
                  end: MqSpacing.sm,
                  top: MqSpacing.sm,
                  child: Column(
                    children: [
                      _MapButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                      const SizedBox(height: MqSpacing.xs),
                      _MapButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                    ],
                  ),
                ),
                if (widget.enabled)
                  PositionedDirectional(
                    end: MqSpacing.sm,
                    bottom: MqSpacing.sm,
                    child: _MapButton(
                      icon: Icons.my_location,
                      busy: _locating,
                      onTap: _locateMe,
                    ),
                  ),
                if (_point == null && !widget.enabled)
                  IgnorePointer(
                    child: Container(
                      color: mq.fill.withValues(alpha: 0.6),
                      alignment: Alignment.center,
                      child: Text(
                        'لم يُحدَّد موقع بعد',
                        style: context.text.bodyMedium?.copyWith(
                          color: mq.ink2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_point != null) ...[
          const SizedBox(height: MqSpacing.sm),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 16, color: mq.ink3),
              const SizedBox(width: 4),
              Text(
                'خط العرض ${_point!.latitude.toStringAsFixed(6)}'
                '  •  خط الطول ${_point!.longitude.toStringAsFixed(6)}',
                style: context.text.labelSmall?.copyWith(color: mq.ink2),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onTap,
    this.busy = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: mq.card,
      shape: const CircleBorder(),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: mq.accent, size: 22),
        ),
      ),
    );
  }
}
