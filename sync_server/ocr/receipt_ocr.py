"""
Receipt OCR Module - LightOnOCR Hybrid Pipeline
Pipeline: Local LightOnOCR (Vision) -> Raw Text -> Gemini Flash (Structuring)
Fallback: Gemini Vision (If Local fails) -> Local Fallback
"""

import io
import json
import base64
import os
import requests
import random
import time
from typing import Optional, Any, Dict
from typing import Optional, Any, Dict
from PIL import Image, ImageFile

try:
    from openai import OpenAI
except ImportError:
    OpenAI = None

try:
    from anthropic import Anthropic
except ImportError:
    Anthropic = None


# 손상된/불완전한 이미지 로드 허용
ImageFile.LOAD_TRUNCATED_IMAGES = True

# ============== 서버 설정 ==============
# 라즈베리파이/PC에서 실행 중인 llama-server (LightOnOCR GGUF 로드됨)
LOCAL_SERVERS = [
    "http://localhost:408/v1/chat/completions",
    "http://127.0.0.1:408/v1/chat/completions",
    "http://183.96.3.137:408/v1/chat/completions",
]

# 환경변수 오버라이드
VISION_SERVER_URL = os.environ.get("VISION_SERVER_URL", None)
LOCAL_MODEL_NAME = "gpt-4-vision-preview" # llama.cpp 호환성용

# Gemini 설정
DEFAULT_GEMINI_MODEL = "gemini-2.0-flash"
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", DEFAULT_GEMINI_MODEL)
GEMINI_API_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"

REQUEST_TIMEOUT = 300
HEALTH_CHECK_TIMEOUT = 3


class ReceiptOCR:
    """LightOnOCR + Gemini 하이브리드 파이프라인"""
    
    def __init__(self, use_gpu: bool = False, lang: str = 'korean', server_url: str = None):
        self.lang = lang
        self.local_server_url = server_url or self._find_available_server()
        
        # Gemini 키 로드
        self.gemini_keys = []
        if os.environ.get("GEMINI_API_KEY_1"):
            self.gemini_keys.append(os.environ.get("GEMINI_API_KEY_1"))
        if os.environ.get("GEMINI_API_KEY_2"):
            self.gemini_keys.append(os.environ.get("GEMINI_API_KEY_2"))

        # Other Clients (Initialized on demand)
        self.openai_client = None
        self.anthropic_client = None
        self.xai_client = None


    def _find_available_server(self) -> str:
        """사용 가능한 로컬 서버 찾기"""
        if VISION_SERVER_URL:
            return VISION_SERVER_URL
        
        for url in LOCAL_SERVERS:
            try:
                health = url.replace("/v1/chat/completions", "/health")
                requests.get(health, timeout=1)
                print(f"[OCR] 로컬 서버 감지됨: {url}")
                return url
            except:
                continue
        
        print("[OCR] 활성 로컬 서버 없음, 기본값 사용")
        return LOCAL_SERVERS[-1]

    def _call_gemini_text(self, text: str) -> Optional[Dict[str, Any]]:
        """Gemini에게 텍스트 구조화 요청 (저비용)"""
        if not text or len(text) < 5:
            return None
            
        print(f"[OCR] Gemini Text structuring... ({len(text)} chars)")
        
        prompt = f"""다음 영수증 OCR 텍스트를 분석하여 JSON으로 변환해주세요.

[OCR 텍스트]
{text}
[끝]

## 분석 규칙
1. 상호명, 날짜(YYYY-MM-DD), 합계금액, 품목 리스트 추출
2. 카테고리는 상호명과 품목을 보고 추론 (식비, 교통, 의료, 마트, 편의점, 카페, 기타 등)
3. 숫자가 오인식된 경우(예: 'IO00' -> 1000) 문맥에 맞춰 교정

## JSON 포맷
{{
    "store_name": "상호명",
    "date": "YYYY-MM-DD",
    "total_amount": 0,
    "category": "카테고리",
    "is_income": false,
    "items": [
        {{"name": "품목명", "quantity": 1, "unit_price": 0, "total_price": 0}}
    ]
}}
JSON만 응답하세요."""
        
        return self._call_gemini_api_base(prompt)

    def _call_gemini_vision(self, image_base64: str) -> Optional[Dict[str, Any]]:
        """Gemini에게 이미지 분석 요청 (Fallback)"""
        print("[OCR] Gemini Vision processing...")
        prompt = """영수증 이미지를 분석하여 JSON으로 정리해주세요.
상호명, 날짜, 합계, 품목, 카테고리를 추출하세요.
JSON 형식만 응답하세요."""
        return self._call_gemini_api_base(prompt, image_base64)

    def _call_gemini_api_base(self, prompt: str, image_base64: str = None) -> Optional[Dict[str, Any]]:
        """Gemini API 공통 호출"""
        if not self.gemini_keys:
            return None
            
        keys = list(self.gemini_keys)
        random.shuffle(keys)
        
        for api_key in keys:
             # Retry logic for rate limiting
            for attempt in range(2): 
                try:
                    parts = [{"text": prompt}]
                    if image_base64:
                        parts.append({
                            "inline_data": {
                                "mime_type": "image/jpeg",
                                "data": image_base64
                            }
                        })
                    
                    payload = {
                        "contents": [{"parts": parts}],
                        "generationConfig": {
                            "temperature": 0.1,
                            "responseMimeType": "application/json"
                        }
                    }
                    
                    res = requests.post(f"{GEMINI_API_URL}?key={api_key}", json=payload, timeout=60)
                    if res.status_code == 200:
                        try:
                            txt = res.json()['candidates'][0]['content']['parts'][0]['text']
                            return json.loads(txt)
                        except Exception as e:
                            print(f"[OCR] Gemini Parsing Error: {e}, Response: {res.text[:100]}...")
                            break 
                    elif res.status_code == 429:
                        print(f"[OCR] Rate Limit Hit (429). Sleeping 15s before retry...")
                        time.sleep(15)
                        continue # Retry same key
                    else:
                        print(f"[OCR] Gemini API Error: {res.status_code} - {res.text}")
                        break
                except Exception as e:
                    print(f"[OCR] Gemini Connection Error: {e}")
                    break
        return None

    def _call_lighton_ocr(self, image_base64: str) -> Optional[str]:
        """로컬 LightOnOCR 호출 (Text Extraction)"""
        if not self.local_server_url:
            return None
            
        print(f"[OCR] Local LightOnOCR processing... ({self.local_server_url})")
        
        # LightOnOCR 프롬프트: 텍스트 추출에 집중
        # 모델마다 최적 프롬프트가 다를 수 있음. 일반적인 OCR 요청 사용.
        prompt = "Convert this receipt image to text. Transcribe all visible text line by line."
        
        payload = {
            "model": LOCAL_MODEL_NAME,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}}
                    ]
                }
            ],
            "temperature": 0.1,
            "max_tokens": 2048,
        }
        
        try:
            # 로컬 Inference는 느릴 수 있음 (300s -> 600s)
            res = requests.post(self.local_server_url, json=payload, timeout=600) 
            if res.status_code == 200:
                content = res.json()['choices'][0]['message']['content']
                print(f"[OCR] Local extracted {len(content)} chars")
                return content
            else:
                print(f"[OCR] Local Server Error: {res.status_code}")
        except Exception as e:
            print(f"[OCR] Local Server Connect Error: {e}")
            
        return None

    def process_image(self, image_data: bytes) -> Dict[str, Any]:
        """
        [New Pipeline]
        1. Local LightOnOCR (Vision) -> Raw Text
        2. Gemini Flash (Text) -> JSON Structuring
        3. Fallback: Gemini Vision (Image) -> JSON
        """
        start_time = time.time()
        image_base64 = base64.b64encode(image_data).decode('utf-8')
        
        # 1. Local LightOnOCR (Text Extraction)
        try:
            raw_text = self._call_lighton_ocr(image_base64)
            if raw_text:
                # 2. Gemini Text Structuring
                json_result = self._call_gemini_text(raw_text)
                if json_result:
                    print(f"[OCR] Pipeline Success (Local+Gemini) - {time.time()-start_time:.2f}s")
                    return json_result
                else:
                    # Gemini Structuring Failed, but we have text. Return partial result.
                    print("[OCR] Warning: Gemini structuring failed (Rate Limit?), returning raw text result")
                    return {
                        "store_name": "OCR Text Only", # Special flag for UI
                        "date": None,
                        "total_amount": 0,
                        "items": [],
                        "category": None,
                        "raw_text": raw_text
                    }
        except Exception as e:
            print(f"[OCR] Pipeline 1 Failed: {e}")

        # 3. Fallback: Gemini Vision
        print("[OCR] Fallback to Gemini Vision API...")
        vision_result = self._call_gemini_vision(image_base64)
        if vision_result:
            return vision_result
            
        raise RuntimeError("All OCR pipelines failed")

    def process_image_v2(self, image_data: bytes, provider: str = 'auto') -> Dict[str, Any]:
        """
        Provider-aware OCR processing.
        Providers: 'auto' (Hybrid), 'gemini', 'gpt', 'claude', 'grok'
        """
        image_base64 = base64.b64encode(image_data).decode('utf-8')
        
        print(f"[OCR] Processing with provider: {provider}")

        # 1. Direct Cloud Providers
        if provider == 'gpt':
            return self._call_gpt_vision(image_base64)
        elif provider == 'claude':
            return self._call_claude_vision(image_base64)
        elif provider == 'grok':
            return self._call_grok_vision(image_base64)
        elif provider == 'gemini':
            # Direct Gemini Vision (Bypass Local)
            res = self._call_gemini_vision(image_base64)
            if not res:
                raise RuntimeError("Gemini Vision failed")
            return res
            
        # 2. Auto / Hybrid Mode (Default)
        return self.process_image(image_data)

    def _call_gpt_vision(self, image_base64: str) -> Dict[str, Any]:
        """OpenAI GPT-4o Vision"""
        if OpenAI is None:
            raise ImportError("openai package not installed. Run 'pip install openai'")
            
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY not found")
            
        if not self.openai_client:
            self.openai_client = OpenAI(api_key=api_key)
            
        response = self.openai_client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Extract receipt info as JSON: {store_name, date, total_amount, items[{name, quantity, unit_price, total_price}], category, is_income}. Return ONLY JSON."},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{image_base64}"
                            }
                        }
                    ]
                }
            ],
            response_format={"type": "json_object"},
            max_tokens=1000,
        )
        return json.loads(response.choices[0].message.content)

    def _call_claude_vision(self, image_base64: str) -> Dict[str, Any]:
        """Anthropic Claude 3.5 Sonnet"""
        if Anthropic is None:
            raise ImportError("anthropic package not installed. Run 'pip install anthropic'")

        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY not found")
            
        if not self.anthropic_client:
            self.anthropic_client = Anthropic(api_key=api_key)
            
        message = self.anthropic_client.messages.create(
            model="claude-3-5-sonnet-20240620",
            max_tokens=1024,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": image_base64,
                            },
                        },
                        {
                            "type": "text",
                            "text": "Extract receipt data into JSON format: {store_name, date(YYYY-MM-DD), total_amount(int), items[{name, quantity, unit_price, total_price}], category, is_income(bool)}. Return only JSON."
                        }
                    ],
                }
            ]
        )
        # Claude doesn't enforce JSON mode strictly, manual cleanup might be needed
        # but 3.5 Sonnet is usually good.
        text = message.content[0].text
        start = text.find('{')
        end = text.rfind('}') + 1
        return json.loads(text[start:end])

    def _call_grok_vision(self, image_base64: str) -> Dict[str, Any]:
        """xAI Grok Vision (OpenAI Compatible)"""
        if OpenAI is None:
            raise ImportError("openai package not installed. Run 'pip install openai'")

        api_key = os.environ.get("XAI_API_KEY")
        if not api_key:
            raise ValueError("XAI_API_KEY not found")
            
        if not self.xai_client:
            self.xai_client = OpenAI(
                api_key=api_key,
                base_url="https://api.x.ai/v1",
            )
            
        response = self.xai_client.chat.completions.create(
            model="grok-vision-beta",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Extract receipt info as JSON: {store_name, date, total_amount, items, category}. JSON only."},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{image_base64}"
                            }
                        }
                    ]
                }
            ],
            stream=False,
        )
        text = response.choices[0].message.content
        start = text.find('{')
        end = text.rfind('}') + 1
        return json.loads(text[start:end])


    def process_base64(self, base64_image: str) -> Dict[str, Any]:
        if ',' in base64_image:
            base64_image = base64_image.split(',')[1]
        image_data = base64.b64decode(base64_image)
        return self.process_image(image_data)

def preprocess_receipt_image(image_data: bytes) -> bytes:
    """영수증 이미지 전처리 (리사이징 및 포맷 변환)"""
    try:
        image = Image.open(io.BytesIO(image_data))
        
        # RGBA -> RGB 변환
        if image.mode in ('RGBA', 'P'):
            image = image.convert('RGB')
            
        # 최대 크기 제한 (2048px)
        max_size = 2048
        if max(image.size) > max_size:
            ratio = max_size / max(image.size)
            new_size = (int(image.size[0] * ratio), int(image.size[1] * ratio))
            image = image.resize(new_size, Image.Resampling.LANCZOS)
            
        # JPEG로 변환
        output = io.BytesIO()
        image.save(output, format='JPEG', quality=85)
        return output.getvalue()
        
    except Exception as e:
        print(f"[Preprocess] Error: {e}")
        return image_data

