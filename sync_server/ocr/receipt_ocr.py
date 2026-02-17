"""
Receipt OCR Module - Gemini Vision API (공식 SDK)
google-generativeai SDK를 사용한 영수증 이미지 분석 및 JSON 구조화
"""

import io
import json
import base64
import os
import time
from typing import Optional, Any, Dict

from PIL import Image, ImageFile

import google.generativeai as genai


# 손상된/불완전한 이미지 로드 허용
ImageFile.LOAD_TRUNCATED_IMAGES = True

# ============== Gemini SDK 설정 ==============
DEFAULT_GEMINI_MODEL = "gemini-2.0-flash"
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", DEFAULT_GEMINI_MODEL)


class ReceiptOCR:
    """google-generativeai SDK 기반 영수증 OCR"""
    
    def __init__(self, use_gpu: bool = False, lang: str = 'korean', **kwargs):
        self.lang = lang
        self.model = None
        
        # Gemini API 키 로드 (여러 키 중 첫 번째 유효 키 사용)
        api_key = (
            os.environ.get("GEMINI_API_KEY_1")
            or os.environ.get("GEMINI_API_KEY_2")
            or os.environ.get("GEMINI_API_KEY_3")
            or os.environ.get("GEMINI_API_KEY")
        )
        
        if not api_key:
            print("[OCR] WARNING: Gemini API key not found!")
            return
        
        try:
            genai.configure(api_key=api_key)
            self.model = genai.GenerativeModel(GEMINI_MODEL)
            print(f"[OCR] Gemini SDK initialized with model: {GEMINI_MODEL}")
        except Exception as e:
            print(f"[OCR] Gemini SDK init error: {e}")

    # ============== 프롬프트 ==============
    
    VISION_PROMPT = """영수증 이미지를 분석하여 JSON으로 정리해주세요.

## 추출 항목
- store_name: 상호명
- date: 날짜 (YYYY-MM-DD 형식)
- total_amount: 합계 금액 (숫자만, 쉼표 없이)
- category: 카테고리 (아래 목록에서 정확히 선택)
- is_income: 수입 여부 (true/false, 일반 영수증은 false)
- items: 품목 목록 [{name, quantity, unit_price, total_price}]

## 지출 카테고리 (is_income: false) - 반드시 아래 이름 중 하나 사용
- 식비: 식당, 카페, 편의점, 베이커리, 배달, 마트 식품코너
- 교통비: 주유소, 택시, 대중교통, 기차, 항공, 렌터카, 주차장
- 주거비: 월세, 관리비, 전기/가스/수도 요금, 인테리어
- 통신비: 휴대폰, 인터넷, 기기할부
- 의류/미용: 옷, 신발, 화장품, 미용실, 네일, 세탁
- 생활용품: 마트(비식품), 다이소, 가구, 가전, 문구
- 건강/의료: 병원, 약국, 치과, 한의원, 피부과, 안과, 헬스장
- 여가/문화: 영화, 공연, 서점, 여행, 숙박, 놀이공원, 캠핑, 골프
- 구독서비스: 넷플릭스, 유튜브프리미엄, 멜론, 앱결제
- 교육: 학원, 등록금, 강의, 교재
- 경조사/선물: 축의금, 조의금, 선물, 기부
- 금융: 대출상환, 수수료, 투자, 적금
- 육아/자녀: 어린이집, 유아용품, 장난감, 소아과
- 반려동물: 사료, 동물병원, 반려용품
- 자동차: 정비, 세차, 타이어, 차량용품
- 보험: 생명/건강/화재/자동차 보험
- 세금/공과금: 소득세, 재산세, 국민연금, 건강보험료
- 기타: 위에 해당하지 않는 경우

## 수입 카테고리 (is_income: true)
- 월급, 상여금, 수당, 프리랜서수입, 사업소득, 투자수익
- 배당금, 이자수익, 임대소득, 부수입, 연금, 환급금
- 장학금, 중고판매, 보험금수령, 퇴직금, 정부지원금, 기타수입

## JSON 형식
{"store_name": "상호명", "date": "YYYY-MM-DD", "total_amount": 숫자, "category": "카테고리", "is_income": false, "items": [{"name": "품목", "quantity": 1, "unit_price": 0, "total_price": 0}]}

JSON만 응답하세요."""

    TEXT_PROMPT = """다음 영수증 OCR 텍스트를 분석하여 JSON으로 변환해주세요.

[OCR 텍스트]
{text}
[끝]

## 분석 규칙
1. 상호명, 날짜(YYYY-MM-DD), 합계금액, 품목 리스트 추출
2. 카테고리는 상호명과 품목을 보고 아래 카테고리 중 하나로 정확히 매칭
3. 숫자가 오인식된 경우(예: 'IO00' -> 1000) 문맥에 맞춰 교정
4. is_income은 일반 영수증이면 false, 급여명세서/환급금 등이면 true

## 지출 카테고리 (is_income: false)
- 식비: 식당, 음식점, 레스토랑, 치킨, 피자, 분식, 카페, 베이커리, 편의점, 배달
- 교통비: 주유소, 택시, 버스, 지하철, 기차, 항공, 렌터카, 주차장, 톨게이트
- 주거비: 월세, 관리비, 전기/가스/수도, 인테리어, 부동산
- 통신비: 휴대폰요금, 인터넷요금, 기기할부
- 의류/미용: 옷가게, 신발, 화장품, 미용실, 네일, 세탁소
- 생활용품: 마트, 다이소, 생필품, 가구, 가전, 문구
- 건강/의료: 병원, 약국, 한의원, 치과, 피부과, 안과, 헬스장
- 여가/문화: 영화관, 공연, 서점, 여행, 숙박, 놀이공원, 캠핑, 골프
- 구독서비스: OTT, 음악스트리밍, 멤버십, 앱결제
- 교육: 학원, 등록금, 강의, 교재, 자격증
- 경조사/선물: 축의금, 조의금, 선물, 기부, 생일, 기념일
- 금융: 대출상환, 수수료, 투자, 적금
- 육아/자녀: 어린이집, 유아용품, 장난감, 소아과, 아이학원
- 반려동물: 사료, 동물병원, 반려용품, 펫미용
- 자동차: 정비, 세차, 타이어, 차량용품, 차량할부
- 보험: 생명보험, 건강보험, 화재보험, 자동차보험
- 세금/공과금: 소득세, 재산세, 국민연금, 건강보험료
- 기타: 위 카테고리에 맞지 않는 경우

## 수입 카테고리 (is_income: true)
- 월급, 상여금, 수당, 야근수당, 프리랜서수입, 사업소득
- 투자수익, 배당금, 이자수익, 임대소득, 부수입
- 연금, 환급금, 용돈, 선물금/축의금, 장학금
- 중고판매, 보험금수령, 퇴직금, 정부지원금, 아동수당
- 암호화폐수익, 유튜브/SNS수익, 상속/증여, 기타수입

## JSON 포맷
{{
    "store_name": "상호명",
    "date": "YYYY-MM-DD",
    "total_amount": 0,
    "category": "카테고리명(위 목록에서 정확히 선택)",
    "is_income": false,
    "items": [
        {{"name": "품목명", "quantity": 1, "unit_price": 0, "total_price": 0}}
    ]
}}
JSON만 응답하세요."""

    # ============== Gemini SDK 호출 ==============

    def _call_gemini_vision(self, image: Image.Image) -> Optional[Dict[str, Any]]:
        """Gemini SDK로 이미지 분석 요청"""
        if not self.model:
            return None

        print("[OCR] Gemini Vision processing (SDK)...")
        try:
            response = self.model.generate_content(
                [self.VISION_PROMPT, image],
                generation_config=genai.GenerationConfig(
                    temperature=0.1,
                    response_mime_type="application/json",
                )
            )

            receipt_info = response.text

            # JSON 추출 (중첩 텍스트 대비)
            lpos = receipt_info.find("{")
            if lpos == -1:
                print(f"[OCR] No JSON found in response: {receipt_info[:100]}")
                return None
            receipt_info = receipt_info[lpos:]
            rpos = receipt_info.rfind("}")
            receipt_info = receipt_info[:rpos + 1]

            return json.loads(receipt_info)

        except json.JSONDecodeError as e:
            print(f"[OCR] Gemini JSON parse error: {e}")
            return None
        except Exception as e:
            print(f"[OCR] Gemini SDK error: {e}")
            return None

    def _call_gemini_text(self, text: str) -> Optional[Dict[str, Any]]:
        """Gemini SDK로 텍스트 구조화 요청 (저비용)"""
        if not self.model:
            return None
        if not text or len(text) < 5:
            return None
            
        print(f"[OCR] Gemini Text structuring (SDK)... ({len(text)} chars)")
        
        prompt = self.TEXT_PROMPT.format(text=text)
        
        try:
            response = self.model.generate_content(
                prompt,
                generation_config=genai.GenerationConfig(
                    temperature=0.1,
                    response_mime_type="application/json",
                )
            )

            receipt_info = response.text
            lpos = receipt_info.find("{")
            if lpos == -1:
                return None
            receipt_info = receipt_info[lpos:]
            rpos = receipt_info.rfind("}")
            receipt_info = receipt_info[:rpos + 1]

            return json.loads(receipt_info)

        except json.JSONDecodeError as e:
            print(f"[OCR] Gemini Text JSON parse error: {e}")
            return None
        except Exception as e:
            print(f"[OCR] Gemini Text SDK error: {e}")
            return None

    # ============== 응답 정규화 ==============

    def _normalize_response(self, result: Dict[str, Any]) -> Dict[str, Any]:
        """OCR 결과 정규화: 문자열 금액을 숫자로 변환, 한글 키를 영문으로 변환"""
        # Gemini가 list를 반환하는 경우 처리
        if isinstance(result, list):
            if len(result) > 0 and isinstance(result[0], dict):
                result = result[0]
            else:
                print(f"[OCR] Warning: Unexpected list response: {result}")
                return {
                    "store_name": "Unknown",
                    "total_amount": 0,
                    "items": [],
                    "category": "기타"
                }
        
        if not isinstance(result, dict):
            print(f"[OCR] Warning: Unexpected response type: {type(result)}")
            return {
                "store_name": "Unknown",
                "total_amount": 0,
                "items": [],
                "category": "기타"
            }
        
        def parse_amount(val):
            if val is None:
                return None
            if isinstance(val, (int, float)):
                return val
            if isinstance(val, str):
                # 쉼표, 공백, 원화 기호 제거
                cleaned = val.replace(',', '').replace(' ', '').replace('₩', '').replace('원', '')
                try:
                    return int(cleaned) if cleaned.isdigit() else float(cleaned)
                except:
                    return None
            return None
        
        # 한글 키 -> 영문 키 매핑
        key_mapping = {
            '상호명': 'store_name',
            '날짜': 'date',
            '합계': 'total_amount',
            '총액': 'total_amount',
            '품목': 'items',
            '카테고리': 'category',
            '수입여부': 'is_income',
        }
        
        # 한글 키를 영문으로 변환
        for kr_key, en_key in key_mapping.items():
            if kr_key in result and en_key not in result:
                result[en_key] = result[kr_key]
        
        # items 내 품목 정규화
        if 'items' in result and isinstance(result['items'], list):
            normalized_items = []
            for item in result['items']:
                if isinstance(item, dict):
                    norm_item = {}
                    # 한글 키 매핑
                    norm_item['name'] = item.get('name') or item.get('이름') or item.get('품목명') or ''
                    norm_item['quantity'] = item.get('quantity') or item.get('수량') or 1
                    norm_item['unit_price'] = parse_amount(item.get('unit_price') or item.get('단가')) or 0
                    norm_item['total_price'] = parse_amount(item.get('total_price') or item.get('가격') or item.get('price')) or 0
                    normalized_items.append(norm_item)
            result['items'] = normalized_items
        
        # total_amount 정규화 (total, 합계, 총액 키도 확인)
        total = parse_amount(result.get('total_amount')) or parse_amount(result.get('total')) or parse_amount(result.get('합계')) or parse_amount(result.get('총액'))
        result['total_amount'] = total if total else 0
        
        # 카테고리 자동 추론 (없거나 '기타'인 경우)
        category = result.get('category')
        if not category or category == '기타':
            store_name = (result.get('store_name') or '').lower()
            inferred = self._infer_category(store_name)
            if inferred != '기타':
                result['category'] = inferred
                print(f"[OCR] Category inferred from store name: {inferred}")
        
        print(f"[OCR] Normalized result: store_name={result.get('store_name')}, total_amount={result.get('total_amount')}, category={result.get('category')}")
        return result
    
    def _infer_category(self, store_name: str) -> str:
        """상호명으로 카테고리 추론 (확장된 카테고리 지원)"""
        store_lower = store_name.lower()
        
        # 건강/의료
        if any(k in store_lower for k in ['약국', '병원', '의원', '메디', '클리닉', '치과', '안과', '내과', '외과', '피부과', '정형외과', '한의원', '한방', '소아과', '이비인후과', '산부인과', '비뇨기과', '정신과', '상담센터']):
            return '건강/의료'
        # 교통비
        if any(k in store_lower for k in ['주유', '주유소', '택시', '버스', '지하철', '교통', 'sk에너지', 'gs칼텍스', '현대오일', 's-oil', '고속도로', '톨게이트', '공항', '항공', '렌터카', '쏘카', '타다', '킥보드']):
            return '교통비'
        # 자동차
        if any(k in store_lower for k in ['정비', '카센터', '오토', '타이어', '세차', '자동차', '카워시']):
            return '자동차'
        # 식비 (카페 포함)
        if any(k in store_lower for k in ['카페', '커피', '스타벅스', '공차', '이디야', '투썸', '빽다방', '메가커피', 'cafe', 'coffee', '편의점', 'cu', 'gs25', 'gs 25', '세븐일레븐', '7-eleven', '미니스톱', 'ministop', '이마트24', '식당', '음식점', '레스토랑', '치킨', '피자', '분식', '포차', '회', '고기', '곱창', '삼겹', '족발', '보쌈', '국밥', '찌개', '탕', '면', '밥', 'bbq', 'bhc', '교촌', '굽네', '맘스터치', '롯데리아', '맥도날드', '버거킹', '서브웨이', '도미노', '한솥', '죠스떡볶이', '베이커리', '빵', '파리바게뜨', '뚜레쥬르', '던킨']):
            return '식비'
        # 생활용품 (마트)
        if any(k in store_lower for k in ['마트', '이마트', '홈플러스', '롯데마트', '하나로', '코스트코', 'costco', '트레이더스', '다이소', '아성다이소', '오늘의집']):
            return '생활용품'
        # 의류/미용
        if any(k in store_lower for k in ['백화점', '쇼핑몰', '의류', '옷', '신발', '아울렛', '유니클로', '자라', 'zara', 'h&m', '미용실', '헤어', '네일', '뷰티', '올리브영', '화장품', '세탁', '클리닝']):
            return '의류/미용'
        # 여가/문화
        if any(k in store_lower for k in ['영화', 'cgv', '메가박스', '롯데시네마', '공연', '전시', '뮤지컬', '서점', '교보문고', '예스24', '알라딘', '노래방', '볼링', '당구', '피씨방', 'pc방', '놀이공원', '에버랜드', '롯데월드', '워터파크', '캠핑', '골프', '스키', '리조트']):
            return '여가/문화'
        # 교육
        if any(k in store_lower for k in ['학원', '학교', '대학교', '교육', '강의', '어학원', '영어', '수학', '과외']):
            return '교육'
        # 반려동물
        if any(k in store_lower for k in ['동물병원', '펫', '반려', '강아지', '고양이', '사료', '펫샵', '동물']):
            return '반려동물'
        # 육아/자녀
        if any(k in store_lower for k in ['어린이집', '유치원', '키즈', '아이', '유아', '장난감', '토이저러스', '레고']):
            return '육아/자녀'
        # 구독서비스
        if any(k in store_lower for k in ['넷플릭스', 'netflix', '유튜브', 'youtube', '멜론', 'melon', '스포티파이', '애플뮤직', '디즈니+', '쿠팡플레이', '왓챠', '구독']):
            return '구독서비스'
        # 보험
        if any(k in store_lower for k in ['보험', '삼성생명', '한화생명', '교보생명', '메리츠', 'db손해보험', '현대해상']):
            return '보험'
        # 세금/공과금
        if any(k in store_lower for k in ['세금', '국세', '지방세', '국민연금', '건강보험', '공과금']):
            return '세금/공과금'
        # 경조사/선물
        if any(k in store_lower for k in ['축의금', '조의금', '화환', '꽃배달', '선물', '기프트']):
            return '경조사/선물'
        # 통신비
        if any(k in store_lower for k in ['skt', 'kt', 'lg유플러스', 'lgu+', '알뜰폰', '통신']):
            return '통신비'
        
        return '기타'

    # ============== 공개 API ==============

    def process_image(self, image_data: bytes) -> Dict[str, Any]:
        """
        Gemini Vision SDK로 영수증 이미지 분석
        """
        start_time = time.time()
        
        # bytes → PIL Image
        image = Image.open(io.BytesIO(image_data))
        if image.mode in ('RGBA', 'P'):
            image = image.convert('RGB')
        
        print("[OCR] Gemini Vision processing (SDK)...")
        vision_result = self._call_gemini_vision(image)
        if vision_result:
            print(f"[OCR] Gemini Vision Success - {time.time()-start_time:.2f}s")
            return self._normalize_response(vision_result)
            
        raise RuntimeError("Gemini Vision OCR failed")

    def process_image_v2(self, image_data: bytes, provider: str = 'gemini') -> Dict[str, Any]:
        """
        Provider-aware OCR processing.
        현재는 'gemini' SDK만 지원
        """
        print(f"[OCR] Processing with provider: {provider}")
        return self.process_image(image_data)

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
