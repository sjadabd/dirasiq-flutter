import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';

/// GetX state for teacher advertisements list + summary stats.
class TeacherAdsController extends GetxController {
  TeacherAdsController({TeacherApiService? api}) : _api = api ?? TeacherApiService();

  final TeacherApiService _api;

  final loading = false.obs;
  final items = <Map<String, dynamic>>[].obs;
  final stats = <String, dynamic>{}.obs;
  final error = RxnString();

  @override
  Future<void> refresh() async {
    loading.value = true;
    error.value = null;
    try {
      final res = await _api.fetchAdvertisements(limit: 50);
      final data = res['data'];
      if (data is List) {
        items.assignAll(data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)));
      } else if (data is Map && data['data'] is List) {
        items.assignAll(
          (data['data'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
        );
      } else {
        items.clear();
      }
      stats.assignAll(await _api.fetchAdvertisementStatistics());
    } catch (e) {
      error.value = e.toString();
      items.clear();
    } finally {
      loading.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    refresh();
  }
}
