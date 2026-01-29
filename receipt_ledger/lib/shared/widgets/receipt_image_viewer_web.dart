import 'package:flutter/material.dart';

/// 영수증 이미지 플레이스홀더 (웹 전용)
class ReceiptImageViewer extends StatelessWidget {
  final String imagePath;
  final double maxHeight;
  
  const ReceiptImageViewer({
    super.key,
    required this.imagePath,
    this.maxHeight = 150,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '영수증',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ),
        Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, color: Colors.grey),
                SizedBox(height: 4),
                Text(
                  '모바일 앱에서 확인 가능',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }
}
