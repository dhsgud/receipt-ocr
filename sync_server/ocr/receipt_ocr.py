"""
Receipt OCR Module using Llama.cpp Server
Nanonets-OCR2-3B-GGUF 모델을 사용하는 로컬 Llama.cpp 서버와 통신
"""

import io
import json
import base64
import requests
from typing import List, Tuple, Optional, Any, Dict
from PIL import Image, ImageFile

# 손상된/불완전한 이미지 로드 허용
ImageFile.LOAD_TRUNCATED_IMAGES = True

# Llama.cpp 서버 설정 (사용자가 8888 포트에 띄움)
LLAMA_SERVER_URL = "http://localhost:8888/v1/chat/completions"

class ReceiptOCR:
    """Llama.cpp 기반 영수증 OCR 클라이언트"""
    
    def __init__(self, use_gpu: bool = False, lang: str = 'korean'):
        """
        초기화
        """
        self.lang = lang
        
    def process_image(self, image_data: bytes) -> Dict[str, Any]:
        """
        이미지에서 텍스트 추출 및 구조화된 데이터 반환
        """
        try:
            # 이미지 로드 및 검증 (PIL 사용)
            image = Image.open(io.BytesIO(image_data))
            # 다시 바이트로 변환 (검증된 이미지)
            buffered = io.BytesIO()
            image.save(buffered, format="JPEG")
            img_str = base64.b64encode(buffered.getvalue()).decode('utf-8')
            
            # Llama.cpp 서버 요청
            payload = {
                "model": "user-model", # 모델명은 서버에 로드된 것을 따름 (alias 사용 권장)
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "Extract valid JSON from this receipt. Fields: store_name, date (YYYY-MM-DD), total_amount (int), items (list of {name, quantity, unit_price, total_price})."},
                            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_str}"}}
                        ]
                    }
                ],
                "temperature": 0.1,
                "max_tokens": 1024,
                "json_schema": {
                    "type": "object",
                    "properties": {
                        "store_name": {"type": "string"},
                        "date": {"type": "string"},
                        "total_amount": {"type": "integer"},
                        "items": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "name": {"type": "string"},
                                    "quantity": {"type": "integer"},
                                    "unit_price": {"type": "integer"},
                                    "total_price": {"type": "integer"}
                                }
                            }
                        }
                    }
                }
            }
            
            print(f"[OCR] Sending request to Llama.cpp server...")
            response = requests.post(LLAMA_SERVER_URL, json=payload, timeout=120)
            
            if response.status_code != 200:
                raise RuntimeError(f"Llama.cpp server failed: {response.text}")
                
            result = response.json()
            content = result['choices'][0]['message']['content']
            
            print(f"[OCR] Llama.cpp response: {content[:100]}...")
            
            # JSON 파싱 시도
            try:
                data = json.loads(content)
                return data
            except json.JSONDecodeError:
                # Markdown 코드 블록 제거 시도
                if "```json" in content:
                    content = content.split("```json")[1].split("```")[0].strip()
                    return json.loads(content)
                elif "```" in content:
                    content = content.split("```")[1].split("```")[0].strip()
                    return json.loads(content)
                else:
                    raise RuntimeError("Failed to parse JSON from Llama.cpp response")
            
        except Exception as e:
            print(f"[OCR ERROR] {str(e)}")
            # 에러 발생 시 빈 데이터 반환 대신 에러 전파
            raise RuntimeError(f"OCR processing failed: {str(e)}")

    def process_base64(self, base64_image: str) -> Dict[str, Any]:
        """Base64 이미지 처리"""
        if ',' in base64_image:
            base64_image = base64_image.split(',')[1]
        image_data = base64.b64decode(base64_image)
        return self.process_image(image_data)

def preprocess_receipt_image(image_data: bytes) -> bytes:
    """
    영수증 이미지 전처리
    (Llama.cpp는 원본 이미지를 잘 처리할 수 있으므로 최소한의 처리만 수행)
    """
    try:
        from PIL import ImageEnhance
        image = Image.open(io.BytesIO(image_data))
        if image.mode in ('RGBA', 'P'):
            image = image.convert('RGB')
        
        # 크기 조정 (너무 큰 이미지는 리사이즈)
        if max(image.size) > 2048:
            image.thumbnail((2048, 2048))
            
        output = io.BytesIO()
        image.save(output, format='JPEG', quality=85)
        return output.getvalue()
    except Exception:
        return image_data
