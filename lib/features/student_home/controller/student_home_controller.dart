import 'dart:async';

import 'package:get/get.dart';

import '../data/models/student_home_data.dart';
import '../data/repositories/student_home_repository.dart';

enum StudentHomeStatus { loading, ready, error }

/// Drives the Student Home screen. Owns the load lifecycle, exposes the
/// composed [StudentHomeData], and runs a low-frequency ticker so the
/// countdown labels on the upcoming-lecture / upcoming-exam cards stay fresh
/// without refetching.
class StudentHomeController extends GetxController {
  StudentHomeController({StudentHomeRepository? repository})
      : _repo = repository ?? StudentHomeRepository();

  final StudentHomeRepository _repo;

  final status = StudentHomeStatus.loading.obs;
  final data = Rxn<StudentHomeData>();
  final errorMessage = ''.obs;

  /// Bumped every minute; the screen watches it to rebuild countdowns.
  final tick = 0.obs;
  Timer? _ticker;

  @override
  void onInit() {
    super.onInit();
    load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => tick.value++);
  }

  @override
  void onClose() {
    _ticker?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    if (data.value == null) status.value = StudentHomeStatus.loading;
    errorMessage.value = '';
    try {
      final result = await _repo.load();
      final home = result.data;

      // Reliability gate — never show the discovery/onboarding layout because
      // of a network failure:
      //   • total failure   → no critical endpoint succeeded.
      //   • cannot determine → the result *looks* new but at least one critical
      //     endpoint failed, so the emptiness may be hiding real data.
      final totalFailure = !result.anyCriticalOk;
      final cannotDetermine = home.isNewStudent && !result.allCriticalOk;

      if (totalFailure || cannotDetermine) {
        // Keep showing existing content on a failed refresh; only surface the
        // error/retry state when there is nothing to fall back to.
        if (data.value == null) {
          status.value = StudentHomeStatus.error;
          errorMessage.value = totalFailure
              ? 'تعذّر الاتصال بالخادم. تحقّق من الإنترنت وأعد المحاولة'
              : 'تعذّر تحميل بعض البيانات. أعد المحاولة';
        }
        return;
      }

      // Reaching here, an "isNewStudent" result is guaranteed to have all
      // critical endpoints confirmed empty — the discovery layout is safe.
      data.value = home;
      status.value = StudentHomeStatus.ready;
    } catch (e) {
      // Defensive: the repository isolates failures and should not throw, but
      // a malformed payload could. Only blank the screen if nothing is shown.
      if (data.value == null) {
        status.value = StudentHomeStatus.error;
        errorMessage.value = 'تعذّر تحميل الصفحة الرئيسية';
      }
    }
  }

  /// Pull-to-refresh entry point — never flips to the full-screen skeleton.
  Future<void> refreshAll() => load();
}
