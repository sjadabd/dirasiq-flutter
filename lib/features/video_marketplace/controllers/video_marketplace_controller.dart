// Phase 7 — Video Marketplace controller.
//
// One GetX controller backs the whole marketplace screen. It owns the four
// curated sections (trending / popular / newest / recommended), the My
// Library list, and the active filter set. Sections fetch in parallel on
// initial load; filters trigger a single combined refetch.
//
// Defensively unwraps every response. The backend's envelope is
//   { success, data: { trending: [...], popular: [...], ... } }
// for the marketplace endpoint, but neighbouring endpoints have drifted
// between `data: [...]`, `data: { items: [...] }`, and `data: { courses: [...] }`
// in legacy code, so we look in several places before giving up.

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../core/services/api_service.dart';

class VideoMarketplaceFilters {
  const VideoMarketplaceFilters({
    this.gradeId,
    this.subject,
    this.teacherId,
    this.minPrice,
    this.maxPrice,
  });

  final String? gradeId;
  final String? subject;
  final String? teacherId;
  final num? minPrice;
  final num? maxPrice;

  bool get isEmpty =>
      (gradeId == null || gradeId!.isEmpty) &&
      (subject == null || subject!.isEmpty) &&
      (teacherId == null || teacherId!.isEmpty) &&
      minPrice == null &&
      maxPrice == null;

  VideoMarketplaceFilters copyWith({
    String? gradeId,
    String? subject,
    String? teacherId,
    num? minPrice,
    num? maxPrice,
    bool clearGrade = false,
    bool clearSubject = false,
    bool clearTeacher = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return VideoMarketplaceFilters(
      gradeId: clearGrade ? null : (gradeId ?? this.gradeId),
      subject: clearSubject ? null : (subject ?? this.subject),
      teacherId: clearTeacher ? null : (teacherId ?? this.teacherId),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
    );
  }

  int get activeCount {
    int n = 0;
    if (gradeId != null && gradeId!.isNotEmpty) n++;
    if (subject != null && subject!.isNotEmpty) n++;
    if (teacherId != null && teacherId!.isNotEmpty) n++;
    if (minPrice != null) n++;
    if (maxPrice != null) n++;
    return n;
  }
}

class VideoMarketplaceController extends GetxController {
  final _api = ApiService();

  // Section state — each is a parallel slot so one section's failure
  // doesn't blank the others.
  final RxList<Map<String, dynamic>> trending = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> popular = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> newest = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> recommended = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> myLibrary = <Map<String, dynamic>>[].obs;

  // Aggregate loading + error states. We expose a single error string per
  // surface (marketplace / library) so the UI can show one retry button
  // each rather than four.
  final RxBool marketplaceLoading = false.obs;
  final RxString marketplaceError = ''.obs;
  final RxBool libraryLoading = false.obs;
  final RxString libraryError = ''.obs;

  // Active filters. UI listens via Obx and rebuilds the chip row.
  final Rx<VideoMarketplaceFilters> filters =
      const VideoMarketplaceFilters().obs;

  // Purchase-in-flight state per courseId. UI dims that card's button.
  final RxSet<String> purchasing = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    await Future.wait([
      _fetchMarketplace(),
      _fetchLibrary(),
    ]);
  }

  Future<void> _fetchMarketplace() async {
    marketplaceLoading.value = true;
    marketplaceError.value = '';
    try {
      final f = filters.value;
      final res = await _api.fetchVideoMarketplace(
        gradeId: f.gradeId,
        subject: f.subject,
        teacherId: f.teacherId,
        minPrice: f.minPrice,
        maxPrice: f.maxPrice,
      );
      final data = res['data'];
      final body = (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      trending.assignAll(_extractList(body, ['trending', 'trendingCourses']));
      popular.assignAll(_extractList(body, ['popular', 'popularCourses']));
      newest.assignAll(_extractList(body, ['newest', 'newestCourses', 'latest']));
      recommended.assignAll(_extractList(body, ['recommended', 'forYou']));
    } catch (e) {
      marketplaceError.value = 'تعذّر تحميل المتجر';
      if (kDebugMode) {
        // ignore: avoid_print
        print('[VideoMarketplace] fetch failed: $e');
      }
    } finally {
      marketplaceLoading.value = false;
    }
  }

  Future<void> _fetchLibrary() async {
    libraryLoading.value = true;
    libraryError.value = '';
    try {
      final res = await _api.fetchMyVideoLibrary();
      final data = res['data'];
      List<Map<String, dynamic>> items;
      if (data is List) {
        items = data
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      } else if (data is Map) {
        items = _extractList(
          Map<String, dynamic>.from(data),
          ['items', 'courses', 'library', 'videoCourses'],
        );
      } else {
        items = const [];
      }
      myLibrary.assignAll(items);
    } catch (e) {
      libraryError.value = 'تعذّر تحميل مكتبتي';
      if (kDebugMode) {
        // ignore: avoid_print
        print('[VideoMarketplace] library fetch failed: $e');
      }
    } finally {
      libraryLoading.value = false;
    }
  }

  Future<void> applyFilters(VideoMarketplaceFilters next) async {
    filters.value = next;
    await _fetchMarketplace();
  }

  Future<void> clearFilters() async {
    filters.value = const VideoMarketplaceFilters();
    await _fetchMarketplace();
  }

  /// Initiates a purchase and returns the Wayl payment URL (or null on
  /// failure). Callers decide whether to launch the URL externally or
  /// show it in an in-app webview.
  Future<String?> purchase(String videoCourseId) async {
    if (videoCourseId.isEmpty) return null;
    if (purchasing.contains(videoCourseId)) return null;
    purchasing.add(videoCourseId);
    try {
      final res = await _api.purchaseVideoCourse(videoCourseId);
      final data = res['data'];
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      // Backend may name the field paymentUrl, payment_url, waylUrl,
      // checkoutUrl — accept any.
      for (final key in const ['paymentUrl', 'payment_url', 'waylUrl', 'checkoutUrl', 'url']) {
        final v = map[key];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[VideoMarketplace] purchase failed: $e');
      }
      return null;
    } finally {
      purchasing.remove(videoCourseId);
    }
  }

  List<Map<String, dynamic>> _extractList(
    Map<String, dynamic> body,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = body[k];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    }
    return const [];
  }
}
