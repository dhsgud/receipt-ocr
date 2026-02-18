import 'dart:io';
import 'package:flutter/material.dart';

/// 영수증 이미지를 표시하는 위젯 (모바일 전용)
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
    final file = File(imagePath);
    
    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          return const SizedBox.shrink();
        }
        
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
            GestureDetector(
              onTap: () => _showFullScreenImage(context),
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 80,
                      color: Colors.grey.withValues(alpha: 0.1),
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
  
  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('영수증', style: TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey, size: 64),
                      SizedBox(height: 16),
                      Text(
                        '이미지를 불러올 수 없습니다',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
