"""
Receipt OCR Module using PaddleOCR
한국어 영수증 이미지에서 텍스트를 추출하는 모듈
"""

import io
import base64
from typing import List, Tuple, Optional
from pathlib import Path

import numpy as np
from PIL import Image, ImageFile

# 손상된/불완전한 이미지 로드 허용
ImageFile.LOAD_TRUNCATED_IMAGES = True

# PaddleOCR import with error handling
try:
    from paddleocr import PaddleOCR
    PADDLE_AVAILABLE = True
except ImportError:
    PADDLE_AVAILABLE = False
    print("Warning: PaddleOCR not installed. OCR functionality will be limited.")


class ReceiptOCR:
    """PaddleOCR 기반 영수증 텍스트 추출기"""
    
    def __init__(self, use_gpu: bool = False, lang: str = 'korean'):
        """
        OCR 엔진 초기화
        
        Args:
            use_gpu: GPU 사용 여부 (라즈베리파이에서는 False)
            lang: 언어 설정 ('korean', 'en', 'ch' 등)
        """
        self.use_gpu = use_gpu
        self.lang = lang
        self._ocr = None
        
    def _get_ocr(self) -> 'PaddleOCR':
        """OCR 엔진 lazy initialization"""
        if self._ocr is None:
            if not PADDLE_AVAILABLE:
                raise RuntimeError("PaddleOCR is not installed. Please install with: pip install paddleocr")
            
            self._ocr = PaddleOCR(
                use_angle_cls=True,  # 텍스트 방향 감지
                lang=self.lang,
                use_gpu=self.use_gpu,
                show_log=False,
                # 라즈베리파이 최적화 설정
                cpu_threads=4,
                enable_mkldnn=False,  # ARM에서는 비활성화
            )
        return self._ocr
    
    def process_image(self, image_data: bytes) -> List[Tuple[str, float]]:
        """
        이미지에서 텍스트 추출
        
        Args:
            image_data: 이미지 바이트 데이터
            
        Returns:
            List of (text, confidence) tuples
        """
        try:
            # 이미지 로드
            image = Image.open(io.BytesIO(image_data))
            
            # RGB로 변환 (투명 배경 처리)
            if image.mode in ('RGBA', 'P'):
                image = image.convert('RGB')
            
            # numpy 배열로 변환
            img_array = np.array(image)
            
            # OCR 실행
            ocr = self._get_ocr()
            result = ocr.ocr(img_array, cls=True)
            
            # 결과 파싱
            extracted_texts = []
            if result and result[0]:
                for line in result[0]:
                    if line and len(line) >= 2:
                        text = line[1][0]  # 텍스트
                        confidence = line[1][1]  # 신뢰도
                        extracted_texts.append((text, confidence))
            
            return extracted_texts
            
        except Exception as e:
            raise RuntimeError(f"OCR processing failed: {str(e)}")
    
    def process_base64(self, base64_image: str) -> List[Tuple[str, float]]:
        """
        Base64 인코딩된 이미지에서 텍스트 추출
        
        Args:
            base64_image: Base64 인코딩된 이미지 문자열
            
        Returns:
            List of (text, confidence) tuples
        """
        # data:image/jpeg;base64, 접두어 제거
        if ',' in base64_image:
            base64_image = base64_image.split(',')[1]
        
        image_data = base64.b64decode(base64_image)
        return self.process_image(image_data)
    
    def get_raw_text(self, image_data: bytes, min_confidence: float = 0.5) -> str:
        """
        이미지에서 전체 텍스트를 하나의 문자열로 추출
        
        Args:
            image_data: 이미지 바이트 데이터
            min_confidence: 최소 신뢰도 임계값
            
        Returns:
            추출된 전체 텍스트
        """
        texts = self.process_image(image_data)
        filtered_texts = [text for text, conf in texts if conf >= min_confidence]
        return '\n'.join(filtered_texts)
    
    def get_text_with_positions(self, image_data: bytes) -> List[dict]:
        """
        이미지에서 텍스트와 위치 정보 추출
        
        Args:
            image_data: 이미지 바이트 데이터
            
        Returns:
            List of dicts with 'text', 'confidence', 'bbox' keys
        """
        try:
            # 이미지 로드
            image = Image.open(io.BytesIO(image_data))
            
            if image.mode in ('RGBA', 'P'):
                image = image.convert('RGB')
            
            img_array = np.array(image)
            
            # OCR 실행
            ocr = self._get_ocr()
            result = ocr.ocr(img_array, cls=True)
            
            # 결과 파싱
            extracted = []
            if result and result[0]:
                for line in result[0]:
                    if line and len(line) >= 2:
                        bbox = line[0]  # [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]
                        text = line[1][0]
                        confidence = line[1][1]
                        
                        # bbox를 단순화 (좌상단, 우하단)
                        x_coords = [p[0] for p in bbox]
                        y_coords = [p[1] for p in bbox]
                        
                        extracted.append({
                            'text': text,
                            'confidence': confidence,
                            'bbox': {
                                'x1': min(x_coords),
                                'y1': min(y_coords),
                                'x2': max(x_coords),
                                'y2': max(y_coords),
                            }
                        })
            
            return extracted
            
        except Exception as e:
            raise RuntimeError(f"OCR processing failed: {str(e)}")


def preprocess_receipt_image(image_data: bytes) -> bytes:
    """
    영수증 이미지 전처리
    
    - 그레이스케일 변환
    - 대비 향상
    - 노이즈 제거
    
    Args:
        image_data: 원본 이미지 바이트 데이터
        
    Returns:
        전처리된 이미지 바이트 데이터
    """
    try:
        from PIL import ImageEnhance, ImageFilter
        
        image = Image.open(io.BytesIO(image_data))
        
        # RGB로 변환
        if image.mode in ('RGBA', 'P'):
            image = image.convert('RGB')
        
        # 대비 향상
        enhancer = ImageEnhance.Contrast(image)
        image = enhancer.enhance(1.5)
        
        # 선명도 향상
        enhancer = ImageEnhance.Sharpness(image)
        image = enhancer.enhance(1.5)
        
        # 바이트로 변환
        output = io.BytesIO()
        image.save(output, format='JPEG', quality=95)
        return output.getvalue()
        
    except Exception as e:
        # 전처리 실패 시 원본 반환
        print(f"Image preprocessing failed: {e}")
        return image_data
