"""
Receipt OCR Module - Hybrid Pipeline (Gemini Cloud + Local Llama.cpp)
이미지에서 바로 JSON 구조화된 영수증 데이터 추출
우선순위: Gemini API (Key Rotation) -> Local Llama.cpp
"""

import io
import json
import base64
import os
import requests
import random
from typing import Optional, Any, Dict
from PIL import Image, ImageFile

# 손상된/불완전한 이미지 로드 허용
ImageFile.LOAD_TRUNCATED_IMAGES = True

# ============== 서버 설정 ==============
# llama.cpp Vision LLM 서버 (OpenAI 호환 API)
# 환경변수로 오버라이드 가능: VISION_SERVER_URL

# 서버 목록 (우선순위대로 시도 - 로컬 폴백용)
LOCAL_SERVERS = [
    "http://localhost:408/v1/chat/completions",        # 로컬 데스크탑
    "http://127.0.0.1:408/v1/chat/completions",        # 로컬 대체
    "http://183.96.3.137:408/v1/chat/completions",     # 라즈베리파이 (원격)
]

# 환경변수 우선
VISION_SERVER_URL = os.environ.get("VISION_SERVER_URL", None)
LOCAL_MODEL_NAME = "gpt-4-vision-preview"  # llama.cpp에서는 무시됨

# Gemini 설정
# 사용자가 "2.5 flash" 급을 원했으므로 최신 2.0 Flash를 기본값으로 설정
# (참고: 2026년 1월 기준 2.0 Flash가 유효함, 3.0 Preview도 존재)
DEFAULT_GEMINI_MODEL = "gemini-2.0-flash"
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", DEFAULT_GEMINI_MODEL)
GEMINI_API_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"

# 타임아웃 설정 (초)
REQUEST_TIMEOUT = 300
HEALTH_CHECK_TIMEOUT = 3  # 서버 감지용


def get_available_local_server() -> str:
    """사용 가능한 로컬/원격 llama.cpp 서버 찾기"""
    # 환경변수로 지정된 경우
    if VISION_SERVER_URL:
        return VISION_SERVER_URL
    
    # 서버 목록에서 첫 번째 사용 가능한 서버 찾기
    for server_url in LOCAL_SERVERS:
        try:
            health_url = server_url.replace("/v1/chat/completions", "/health")
            response = requests.get(health_url, timeout=HEALTH_CHECK_TIMEOUT)
            if response.status_code == 200:
                print(f"[OCR] 로컬 서버 감지: {server_url}")
                return server_url
        except:
            continue
    
    # 기본값 반환
    print("[OCR] 활성 로컬 서버 없음, 기본값 사용")
    return LOCAL_SERVERS[-1]


class ReceiptOCR:
    """하이브리드 OCR 파이프라인 (Gemini + Local Fallback)"""
    
    def __init__(self, use_gpu: bool = False, lang: str = 'korean', server_url: str = None):
        self.lang = lang
        self.local_server_url = server_url or get_available_local_server()
        
        # Gemini 키 로드
        self.gemini_keys = []
        if os.environ.get("GEMINI_API_KEY_1"):
            self.gemini_keys.append(os.environ.get("GEMINI_API_KEY_1"))
        if os.environ.get("GEMINI_API_KEY_2"):
            self.gemini_keys.append(os.environ.get("GEMINI_API_KEY_2"))
            
        if self.gemini_keys:
            print(f"[OCR] Gemini API 활성화됨 (키 {len(self.gemini_keys)}개)")
        else:
            print("[OCR] Gemini API 키 없음. 로컬/원격 서버만 사용합니다.")

    def _get_gemini_key(self) -> Optional[str]:
        """사용할 Gemini 키 선택 (간단한 로드밸런싱)"""
        if not self.gemini_keys:
            return None
        # 무작위 선택으로 분산
        return random.choice(self.gemini_keys)

    def _call_gemini(self, image_base64: str, prompt: str) -> Optional[Dict[str, Any]]:
        """Gemini API 호출 시도"""
        # 시도할 키 목록 (순서 섞어서)
        keys_to_try = list(self.gemini_keys)
        random.shuffle(keys_to_try)
        
        for api_key in keys_to_try:
            try:
                print(f"[OCR] Gemini ({api_key[:4]}...) 요청 중...")
                
                payload = {
                    "contents": [{
                        "parts": [
                            {"text": prompt + "\n\nJSON 형식으로만 응답해주세요."},
                            {
                                "inline_data": {
                                    "mime_type": "image/jpeg",
                                    "data": image_base64
                                }
                            }
                        ]
                    }],
                    "generationConfig": {
                        "temperature": 0.1,
                        "responseMimeType": "application/json"
                    }
                }
                
                response = requests.post(
                    f"{GEMINI_API_URL}?key={api_key}",
                    json=payload,
                    timeout=30
                )
                
                if response.status_code == 200:
                    result = response.json()
                    try:
                        text_content = result['candidates'][0]['content']['parts'][0]['text']
                        return json.loads(text_content)
                    except (KeyError, IndexError, json.JSONDecodeError) as e:
                        print(f"[OCR] Gemini 응답 파싱 실패: {e}")
                        # 파싱 실패는 다른 키로 재시도할 가치가 있음 (모델이 이상한 답을 줬을 수 있음)
                        continue
                else:
                    print(f"[OCR] Gemini 오류 ({response.status_code}): {response.text}")
                    # 429 (Too Many Requests) 등의 경우 다음 키 시도
                    continue
                    
            except Exception as e:
                print(f"[OCR] Gemini 연결 실패: {e}")
                continue
                
        return None # 모든 키 실패

    def _call_local_llm(self, image_base64: str, prompt: str) -> Dict[str, Any]:
        """로컬 Llama.cpp 호출"""
        print(f"[OCR] 로컬 Llama.cpp ({self.local_server_url})로 폴백...")
        
        payload = {
            "model": LOCAL_MODEL_NAME,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt + "\nJSON만 응답해주세요."},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}}
                    ]
                }
            ],
            "temperature": 0.1,
            "max_tokens": 2048,
        }
        
        response = requests.post(self.local_server_url, json=payload, timeout=REQUEST_TIMEOUT)
        
        if response.status_code != 200:
            raise RuntimeError(f"로컬 서버 오류: {response.text}")
            
        result = response.json()
        content = result['choices'][0]['message']['content']
        
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

    def process_image(self, image_data: bytes) -> Dict[str, Any]:
        """
        이미지에서 영수증 정보 추출 (Priority: Gemini -> Local)
        """
        try:
            # 이미지 전처리 및 Base64 인코딩
            image = Image.open(io.BytesIO(image_data))
            buffered = io.BytesIO()
            image.save(buffered, format="JPEG")
            img_str = base64.b64encode(buffered.getvalue()).decode('utf-8')
            
            # 통합 프롬프트
            prompt = """영수증 이미지를 분석해주세요.

## 분석 단계 (Chain of Thought)
1️⃣ 상호명 확인: "약국", "카페", "편의점", "마트" 등 키워드로 카테고리 유추
2️⃣ 품목명 확인: 약, 커피, 음식 등 품목으로 카테고리 유추
3️⃣ 상호명과 품목을 종합하여 가장 적합한 카테고리 선택

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
의료, 카페, 편의점, 마트, 식비, 교통, 쇼핑, 생활, 문화, 기타"""

            # 1. Gemini 시도
            if self.gemini_keys:
                gemini_result = self._call_gemini(img_str, prompt)
                if gemini_result:
                    print("[OCR] Gemini 처리 성공")
                    return gemini_result
                else:
                    print("[OCR] 모든 Gemini 키 사용 실패/초과. 로컬로 전환합니다.")
            
            # 2. 로컬 폴백
            return self._call_local_llm(img_str, prompt)
            
        except Exception as e:
            print(f"[OCR ERROR] 파이프라인 실패: {str(e)}")
            raise RuntimeError(f"OCR 처리 실패: {str(e)}")

    
    def extract_raw_text(self, image_data: bytes) -> str:
        """
        이미지에서 Raw 텍스트 추출 (Priority: Gemini -> Local)
        """
        image = Image.open(io.BytesIO(image_data))
        buffered = io.BytesIO()
        image.save(buffered, format="JPEG")
        img_str = base64.b64encode(buffered.getvalue()).decode('utf-8')
        
        prompt = "이 영수증 이미지의 모든 텍스트를 있는 그대로 읽어주세요."
        
        # 1. Gemini 시도
        if self.gemini_keys:
            keys_to_try = list(self.gemini_keys)
            random.shuffle(keys_to_try)
            
            for api_key in keys_to_try:
                try:
                    payload = {
                        "contents": [{"parts": [
                            {"text": prompt},
                            {"inline_data": {"mime_type": "image/jpeg", "data": img_str}}
                        ]}]
                    }
                    response = requests.post(f"{GEMINI_API_URL}?key={api_key}", json=payload, timeout=30)
                    if response.status_code == 200:
                        return response.json()['candidates'][0]['content']['parts'][0]['text'].strip()
                except:
                    continue
        
        # 2. 로컬 폴백 (간단 구현)
        # TODO: 로컬 Raw text 추출 로직 구현 필요 시 추가
        return "Raw text extraction not fully implemented for local fallback yet."

    def process_base64(self, base64_image: str) -> Dict[str, Any]:
        """Base64 이미지 처리"""
        if ',' in base64_image:
            base64_image = base64_image.split(',')[1]
        image_data = base64.b64decode(base64_image)
        return self.process_image(image_data)
        
    def extract_raw_text_base64(self, base64_image: str) -> str:
        """Base64 이미지에서 Raw 텍스트 추출"""
        if ',' in base64_image:
            base64_image = base64_image.split(',')[1]
        image_data = base64.b64decode(base64_image)
        return self.extract_raw_text(image_data)


