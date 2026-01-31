// 조건부 export - 웹에서는 웹 버전, 모바일에서는 네이티브 버전 사용
export 'receipt_image_viewer_web.dart'
    if (dart.library.io) 'receipt_image_viewer_native.dart';
