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
# llama.cpp Vision LLM 서버 (OpenAI 호환 API)
VISION_SERVER_URL = "http://183.96.3.137:408/v1/chat/completions"
MODEL_NAME = "gpt-4-vision-preview"  # llama.cpp에서는 무시됨

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
            
            # 통합 프롬프트: 이미지 → JSON 바로 추출 (COT 기법)
            prompt = """영수증 이미지를 분석해주세요.

## 분석 단계 (Chain of Thought)

1️⃣ 먼저 상호명을 확인하세요:
   - "약국", "팜", "Pharmacy" → 의료
   - "카페", "커피", "스타벅스", "투썸" → 카페
   - "편의점", "CU", "GS25", "세븐일레븐" → 편의점
   - "마트", "이마트", "홈플러스", "슈퍼" → 마트
   - "주유소", "SK", "GS칼텍스", "현대오일" → 교통
   - "병원", "의원", "클리닉" → 의료
   - "식당", "레스토랑", "치킨", "피자" → 식비

2️⃣ 품목명도 확인하세요:
   - 약, 밴드, 감기약, 진통제 → 의료
   - 커피, 라떼, 아메리카노 → 카페
   - 음식, 식사, 반찬 → 식비
   - 주유, 휘발유, 경유 → 교통

3️⃣ 상호명과 품목을 종합하여 가장 적합한 카테고리를 선택하세요.

## JSON 형식으로 응답
{
    "store_name": "상호명",
    "date": "YYYY-MM-DD",
    "total_amount": 결제금액(정수),
    "category": "카테고리",
    "is_income": false,
    "items": [{"name": "품목명", "quantity": 수량, "unit_price": 단가, "total_price": 금액}]
}

## 카테고리 목록
- 의료: 약국, 병원, 의원
- 카페: 커피숍, 카페
- 편의점: CU, GS25, 세븐일레븐, 이마트24
- 마트: 대형마트, 슈퍼마켓
- 식비: 음식점, 식당, 배달음식
- 교통: 주유소, 택시, 대중교통, 주차
- 쇼핑: 의류, 전자제품, 온라인쇼핑
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
