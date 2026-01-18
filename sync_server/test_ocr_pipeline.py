"""
OCR Pipeline Test Script
2단계 OCR 파이프라인 테스트
"""

import sys
import os

# 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ocr.receipt_ocr import ReceiptOCR, preprocess_receipt_image


def test_with_sample_image(image_path: str):
    """샘플 이미지로 테스트"""
    print(f"\n{'='*50}")
    print(f"테스트 이미지: {image_path}")
    print(f"{'='*50}\n")
    
    # 이미지 로드
    with open(image_path, 'rb') as f:
        image_data = f.read()
    
    # 전처리
    image_data = preprocess_receipt_image(image_data)
    
    # OCR 엔진 초기화
    ocr = ReceiptOCR()
    
    # 1단계 테스트: 텍스트 추출만
    print("\n[테스트 1] 텍스트 추출 (1단계만)")
    print("-" * 40)
    try:
        raw_text = ocr.extract_text(image_data)
        print(f"✓ 성공: {len(raw_text)}자 추출됨")
    except Exception as e:
        print(f"✗ 실패: {e}")
        return
    
    # 2단계 테스트: 텍스트 구조화
    print("\n[테스트 2] 텍스트 구조화 (2단계)")
    print("-" * 40)
    try:
        structured = ocr.structure_text(raw_text)
        print(f"✓ 성공!")
        print(f"  - 상호명: {structured.get('store_name')}")
        print(f"  - 날짜: {structured.get('date')}")
        print(f"  - 금액: {structured.get('total_amount')}원")
        print(f"  - 카테고리: {structured.get('category')}")
        print(f"  - 품목 수: {len(structured.get('items', []))}")
    except Exception as e:
        print(f"✗ 실패: {e}")
        return
    
    # 전체 파이프라인 테스트
    print("\n[테스트 3] 전체 파이프라인 (process_image)")
    print("-" * 40)
    try:
        result = ocr.process_image(image_data)
        print(f"✓ 성공!")
        print(f"  - raw_text 포함: {'raw_text' in result}")
    except Exception as e:
        print(f"✗ 실패: {e}")
    
    print(f"\n{'='*50}")
    print("테스트 완료!")
    print(f"{'='*50}\n")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("사용법: python test_ocr_pipeline.py <영수증_이미지_경로>")
        print("예시: python test_ocr_pipeline.py receipt.jpg")
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    if not os.path.exists(image_path):
        print(f"오류: 파일을 찾을 수 없습니다: {image_path}")
        sys.exit(1)
    
    test_with_sample_image(image_path)
