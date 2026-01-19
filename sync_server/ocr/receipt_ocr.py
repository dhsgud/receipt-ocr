"""
Receipt OCR Module - Single Vision LLM Pipeline
이미지에서 바로 JSON 구조화된 영수증 데이터 추출
"""

import io
import json
import base64
import requests
from typing import Optional, Any, Dict
from PIL import Image, ImageFile

# 손상된/불완전한 이미지 로드 허용
ImageFile.LOAD_TRUNCATED_IMAGES = True

# ============== 서버 설정 ==============
# Vision LLM 서버 (이미지 -> JSON 한 번에)
VISION_SERVER_URL = "http://183.96.3.137:408/v1/chat/completions"
MODEL_NAME = "user-model"

# 타임아웃 설정 (초)
REQUEST_TIMEOUT = 300


class ReceiptOCR:
    """단일 Vision LLM 파이프라인 클라이언트"""
    
    def __init__(self, use_gpu: bool = False, lang: str = 'korean'):
        self.lang = lang
        
    def process_image(self, image_data: bytes) -> Dict[str, Any]:
        """
        이미지에서 바로 JSON 구조화된 영수증 데이터 추출
        """
        try:
            # 이미지 로드 및 Base64 인코딩
            image = Image.open(io.BytesIO(image_data))
            buffered = io.BytesIO()
            image.save(buffered, format="JPEG")
            img_str = base64.b64encode(buffered.getvalue()).decode('utf-8')
            
            # 통합 프롬프트: 이미지 → JSON 바로 추출
            prompt = """이 영수증 이미지를 분석하여 JSON 형식으로 정리해주세요.

다음 JSON 형식으로 응답해주세요:
{
    "store_name": "상호명",
    "date": "YYYY-MM-DD",
    "total_amount": 결제금액(정수),
    "category": "카테고리",
    "items": [
        {"name": "품목명", "quantity": 수량, "unit_price": 단가, "total_price": 금액}
    ]
}

⚠️ 품목명 처리 규칙 (한국 영수증 특성상 품목명이 잘리는 경우가 많음):
- 잘린 품목명은 문맥상 추측 가능하면 전체 이름으로 복원 (예: "신라면멀" → "신라면멀티팩")
- 추측이 어려우면 잘린 그대로 + "?" 표시 (예: "아이스아메리" → "아이스아메리?")
- 완전히 알 수 없으면 "?품목?" 으로 표시

카테고리는 다음 중 하나로 선택:
- 식비: 음식점, 카페, 편의점, 마트 식품
- 교통: 주유소, 대중교통, 택시, 주차
- 쇼핑: 의류, 전자제품, 생활용품
- 의료: 병원, 약국
- 생활: 공과금, 통신비
- 문화: 영화, 공연, 도서
- 기타: 위에 해당하지 않는 경우

JSON만 응답해주세요."""

            payload = {
                "model": MODEL_NAME,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_str}"}}
                        ]
                    }
                ],
                "temperature": 0.1,
                "max_tokens": 2048,
            }
            
            print(f"[OCR] Vision LLM 요청 중... ({VISION_SERVER_URL})")
            response = requests.post(VISION_SERVER_URL, json=payload, timeout=REQUEST_TIMEOUT)
            
            if response.status_code != 200:
                raise RuntimeError(f"서버 오류: {response.text}")
                
            result = response.json()
            content = result['choices'][0]['message']['content']
            
            print(f"[OCR] 응답 완료")
            print("-" * 40)
            print(content[:500] + "..." if len(content) > 500 else content)
            print("-" * 40)
            
            # JSON 파싱
            try:
                return json.loads(content)
            except json.JSONDecodeError:
                if "```json" in content:
                    content = content.split("```json")[1].split("```")[0].strip()
                    return json.loads(content)
                elif "```" in content:
                    content = content.split("```")[1].split("```")[0].strip()
                    return json.loads(content)
                raise RuntimeError("JSON 파싱 실패")
            
        except Exception as e:
            print(f"[OCR 오류] {str(e)}")
            raise RuntimeError(f"영수증 처리 실패: {str(e)}")

    def process_base64(self, base64_image: str) -> Dict[str, Any]:
        """Base64 이미지 처리"""
        if ',' in base64_image:
            base64_image = base64_image.split(',')[1]
        image_data = base64.b64decode(base64_image)
        return self.process_image(image_data)


def preprocess_receipt_image(image_data: bytes) -> bytes:
    """영수증 이미지 전처리"""
    try:
        image = Image.open(io.BytesIO(image_data))
        if image.mode in ('RGBA', 'P'):
            image = image.convert('RGB')
        if max(image.size) > 2048:
            image.thumbnail((2048, 2048))
        output = io.BytesIO()
        image.save(output, format='JPEG', quality=85)
        return output.getvalue()
    except Exception:
        return image_data
