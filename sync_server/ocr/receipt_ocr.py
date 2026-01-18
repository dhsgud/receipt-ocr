"""
Receipt OCR Module using Two-Stage Pipeline
1. OCR Stage: Vision 모델로 이미지에서 텍스트 추출
2. Structuring Stage: LLM 모델로 텍스트를 JSON 구조화
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
# 1단계: OCR/Vision 모델 (이미지 -> 텍스트)
OCR_SERVER_URL = "http://183.96.3.137:409/v1/chat/completions"
OCR_MODEL_NAME = "user-model"

# 2단계: LLM 모델 (텍스트 -> JSON)
LLM_SERVER_URL = "http://183.96.3.137:408/v1/chat/completions"
LLM_MODEL_NAME = "user-model"

# 타임아웃 설정 (초)
REQUEST_TIMEOUT = 300


class ReceiptOCR:
    """2단계 OCR 파이프라인 클라이언트 (Vision OCR + LLM)"""
    
    def __init__(self, use_gpu: bool = False, lang: str = 'korean'):
        self.lang = lang
        
    def extract_text(self, image_data: bytes) -> str:
        """
        1단계: Vision/OCR 모델로 이미지에서 텍스트 추출
        """
        try:
            # 이미지 로드 및 Base64 인코딩
            image = Image.open(io.BytesIO(image_data))
            buffered = io.BytesIO()
            image.save(buffered, format="JPEG")
            img_str = base64.b64encode(buffered.getvalue()).decode('utf-8')
            
            # 텍스트 추출 전용 프롬프트
            extraction_prompt = """이 영수증 이미지에 보이는 모든 텍스트를 순서대로 그대로 적어주세요.
- 위에서 아래로, 왼쪽에서 오른쪽 순서로 읽어주세요.
- 숫자, 가격, 날짜 등 모든 정보를 빠뜨리지 말고 적어주세요.
- 형식을 맞추려 하지 말고 보이는 그대로 적어주세요."""

            payload = {
                "model": OCR_MODEL_NAME,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": extraction_prompt},
                            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_str}"}}
                        ]
                    }
                ],
                "temperature": 0.1,
                "max_tokens": 2048,
            }
            
            print(f"[OCR 1단계] Vision 모델에 요청 중... ({OCR_SERVER_URL})")
            response = requests.post(OCR_SERVER_URL, json=payload, timeout=REQUEST_TIMEOUT)
            
            if response.status_code != 200:
                raise RuntimeError(f"OCR 서버 오류: {response.text}")
                
            result = response.json()
            raw_text = result['choices'][0]['message']['content']
            
            print(f"[OCR 1단계] 추출 완료 ({len(raw_text)}자)")
            print("-" * 40)
            print(raw_text[:500] + "..." if len(raw_text) > 500 else raw_text)
            print("-" * 40)
            
            return raw_text
            
        except Exception as e:
            print(f"[OCR 1단계 오류] {str(e)}")
            raise RuntimeError(f"텍스트 추출 실패: {str(e)}")
    
    def structure_text(self, raw_text: str) -> Dict[str, Any]:
        """
        2단계: 추출된 텍스트를 JSON 구조로 변환 (LLM 사용)
        """
        try:
            structuring_prompt = f"""아래는 영수증에서 추출한 텍스트입니다. 이 정보를 분석하여 JSON 형식으로 정리해주세요.

=== 영수증 텍스트 ===
{raw_text}
=== 끝 ===

다음 JSON 형식으로 응답해주세요:
{{
    "store_name": "상호명",
    "date": "YYYY-MM-DD",
    "total_amount": 결제금액(정수),
    "category": "카테고리",
    "items": [
        {{"name": "품목명", "quantity": 수량, "unit_price": 단가, "total_price": 금액}}
    ]
}}

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
                "model": LLM_MODEL_NAME,
                "messages": [{"role": "user", "content": structuring_prompt}],
                "temperature": 0.1,
                "max_tokens": 1024,
                "json_schema": {
                    "type": "object",
                    "properties": {
                        "store_name": {"type": "string"},
                        "date": {"type": "string"},
                        "total_amount": {"type": "integer"},
                        "category": {"type": "string", "enum": ["식비", "교통", "쇼핑", "의료", "생활", "문화", "기타"]},
                        "items": {"type": "array", "items": {"type": "object", "properties": {"name": {"type": "string"}, "quantity": {"type": "integer"}, "unit_price": {"type": "integer"}, "total_price": {"type": "integer"}}}}
                    },
                    "required": ["store_name", "date", "total_amount", "category"]
                }
            }
            
            print(f"[OCR 2단계] LLM 모델에 구조화 요청 중... ({LLM_SERVER_URL})")
            response = requests.post(LLM_SERVER_URL, json=payload, timeout=REQUEST_TIMEOUT)
            
            if response.status_code != 200:
                raise RuntimeError(f"LLM 서버 오류: {response.text}")
                
            result = response.json()
            content = result['choices'][0]['message']['content']
            
            print(f"[OCR 2단계] LLM 응답 완료")
            
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
            print(f"[OCR 2단계 오류] {str(e)}")
            raise RuntimeError(f"텍스트 구조화 실패: {str(e)}")
    
    def process_image(self, image_data: bytes) -> Dict[str, Any]:
        """전체 파이프라인 실행 (1단계 + 2단계)"""
        raw_text = self.extract_text(image_data)
        structured_data = self.structure_text(raw_text)
        structured_data['raw_text'] = raw_text
        return structured_data

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
