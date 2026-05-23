// Teacher video-course detail (full screen). Phase 10.1.B.5 Flutter mirror.
//
// This is a STUB scaffold so the parent list screen compiles. The full
// implementation (lessons grid, edit dialog, upload dialog, HLS player)
// lands in the next iteration of the Flutter mirror commit.

import 'package:flutter/material.dart';

class TeacherVideoCourseDetailScreen extends StatelessWidget {
  const TeacherVideoCourseDetailScreen({super.key, required this.courseId});
  final String courseId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الدورة المرئية')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction_outlined, size: 64),
              const SizedBox(height: 12),
              Text('قيد التطوير — معرّف الدورة: $courseId',
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              const Text(
                'إدارة الدروس والرفع التفصيلية متوفّرة حالياً في لوحة التحكم على الويب.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
