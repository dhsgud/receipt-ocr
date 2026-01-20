"""
LightOnOCR-2-1B Vision OCR Server
Hugging Face Transformers 기반 FastAPI 서버
라즈베리파이 5 (8GB) 최적화
"""

import io
import os
import base64
import logging
from typing import List, Optional, Union, Any
from contextlib import asynccontextmanager

import torch
from PIL import Image
from pydantic import BaseModel
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============== 모델 설정 ==============
MODEL_NAME = "lightonai/LightOnOCR-2-1B"
MAX_NEW_TOKENS = 2048

# 전역 모델 변수
model = None
processor = None


class Message(BaseModel):
    role: str
    content: Any  # str, list, dict 등 모든 형식 허용


class ChatRequest(BaseModel):
    model: str = "lightonai/LightOnOCR-2-1B"
    messages: List[Message]
    max_tokens: Optional[int] = MAX_NEW_TOKENS
    temperature: Optional[float] = 0.1
    top_p: Optional[float] = 0.9


class Choice(BaseModel):
    index: int
    message: dict
    finish_reason: str


class ChatResponse(BaseModel):
    id: str = "chatcmpl-lightonocr"
    object: str = "chat.completion"
    model: str = MODEL_NAME
    choices: List[Choice]


def load_model():
    """모델 로드"""
    global model, processor
    
    logger.info(f"Loading model: {MODEL_NAME}")
    
    # 디바이스 설정
    if torch.cuda.is_available():
        device = "cuda"
        dtype = torch.bfloat16
        logger.info("Using CUDA")
    elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
        device = "mps"
        dtype = torch.float32
        logger.info("Using MPS")
    else:
        device = "cpu"
        dtype = torch.float32
        logger.info("Using CPU")
    
    try:
        from transformers import LightOnOcrForConditionalGeneration, LightOnOcrProcessor
        
        # 메모리 최적화: 8GB RAM 고려
        model = LightOnOcrForConditionalGeneration.from_pretrained(
            MODEL_NAME,
            torch_dtype=dtype,
            low_cpu_mem_usage=True,
        ).to(device)
        
        processor = LightOnOcrProcessor.from_pretrained(MODEL_NAME)
        
        # 추론 모드로 설정
        model.eval()
        
        logger.info(f"Model loaded successfully on {device}")
        return device, dtype
        
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise


# 디바이스 정보 저장
device_info = {"device": "cpu", "dtype": torch.float32}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """앱 시작/종료 시 모델 로드/언로드"""
    global device_info
    device, dtype = load_model()
    device_info["device"] = device
    device_info["dtype"] = dtype
    yield
    # 종료 시 정리
    logger.info("Shutting down...")


app = FastAPI(
    title="LightOnOCR-2-1B Server",
    description="Vision OCR API compatible with OpenAI format",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def decode_base64_image(data_url: str) -> Image.Image:
    """Base64 이미지 디코딩"""
    if data_url.startswith("data:"):
        # data:image/jpeg;base64,xxx 형식
        header, data = data_url.split(",", 1)
    else:
        data = data_url
    
    image_bytes = base64.b64decode(data)
    return Image.open(io.BytesIO(image_bytes)).convert("RGB")


def extract_image_from_content(content: Union[str, List]) -> Optional[Image.Image]:
    """메시지에서 이미지 추출"""
    if isinstance(content, str):
        return None
    
    for item in content:
        if isinstance(item, dict):
            if item.get("type") == "image_url":
                url = item.get("image_url", {}).get("url", "")
                if url.startswith("data:") or not url.startswith("http"):
                    return decode_base64_image(url)
            elif item.get("type") == "image":
                # {"type": "image", "url": "..."} 형식도 지원
                url = item.get("url", "")
                if url.startswith("data:"):
                    return decode_base64_image(url)
    return None


def extract_text_from_content(content: Union[str, List]) -> str:
    """메시지에서 텍스트 추출"""
    if isinstance(content, str):
        return content
    
    texts = []
    for item in content:
        if isinstance(item, dict) and item.get("type") == "text":
            texts.append(item.get("text", ""))
    return "\n".join(texts)


@app.get("/health")
async def health():
    """헬스체크"""
    return {
        "status": "ok",
        "model": MODEL_NAME,
        "device": device_info["device"]
    }


@app.get("/v1/models")
async def list_models():
    """모델 목록"""
    return {
        "data": [
            {
                "id": MODEL_NAME,
                "object": "model",
                "owned_by": "lightonai"
            }
        ]
    }


@app.post("/v1/chat/completions")
async def chat_completions(request: ChatRequest):
    """OpenAI 호환 Chat Completions API"""
    global model, processor
    
    if model is None or processor is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # 마지막 user 메시지에서 이미지와 텍스트 추출
        image = None
        prompt_text = ""
        
        for msg in reversed(request.messages):
            if msg.role == "user":
                # 디버깅: content 타입과 내용 확인
                logger.info(f"Message content type: {type(msg.content)}")
                
                # content를 적절한 형식으로 변환
                content = msg.content
                if hasattr(content, 'model_dump'):
                    content = content.model_dump()
                elif hasattr(content, '__iter__') and not isinstance(content, (str, dict)):
                    content = [item.model_dump() if hasattr(item, 'model_dump') else item for item in content]
                
                logger.info(f"Processed content: {str(content)[:500]}")
                
                image = extract_image_from_content(content)
                prompt_text = extract_text_from_content(content)
                break
        
        if image is None:
            logger.error("No image found in the request content")
            raise HTTPException(status_code=400, detail="No image provided")
        
        # LightOnOCR 형식으로 conversation 구성
        # 텍스트 프롬프트가 있으면 포함, 없으면 이미지만
        if prompt_text:
            conversation = [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt_text},
                        {"type": "image", "image": image}
                    ]
                }
            ]
        else:
            conversation = [
                {
                    "role": "user",
                    "content": [{"type": "image", "image": image}]
                }
            ]
        
        # 입력 처리
        inputs = processor.apply_chat_template(
            conversation,
            add_generation_prompt=True,
            tokenize=True,
            return_dict=True,
            return_tensors="pt",
        )
        
        device = device_info["device"]
        dtype = device_info["dtype"]
        
        inputs = {
            k: v.to(device=device, dtype=dtype) if v.is_floating_point() else v.to(device)
            for k, v in inputs.items()
        }
        
        # 추론
        with torch.no_grad():
            output_ids = model.generate(
                **inputs,
                max_new_tokens=request.max_tokens or MAX_NEW_TOKENS,
                do_sample=request.temperature > 0,
                temperature=request.temperature if request.temperature > 0 else None,
                top_p=request.top_p if request.temperature > 0 else None,
            )
        
        # 결과 디코딩
        generated_ids = output_ids[0, inputs["input_ids"].shape[1]:]
        output_text = processor.decode(generated_ids, skip_special_tokens=True)
        
        logger.info(f"Generated {len(output_text)} characters")
        
        return ChatResponse(
            choices=[
                Choice(
                    index=0,
                    message={"role": "assistant", "content": output_text},
                    finish_reason="stop"
                )
            ]
        )
        
    except Exception as e:
        logger.error(f"Inference error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 408))
    uvicorn.run(app, host="0.0.0.0", port=port)
