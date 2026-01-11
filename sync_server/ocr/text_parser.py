"""
Receipt Text Parser Module
OCR 결과에서 영수증 정보를 구조화하여 추출하는 모듈
- 개선: 금액 추출 패턴 확대, 카테고리 자동 판단 기능 추가
"""

import re
from typing import Dict, List, Optional, Tuple
from datetime import datetime
from dataclasses import dataclass, asdict


@dataclass
class ReceiptItem:
    """영수증 품목"""
    name: str
    quantity: int = 1
    unit_price: float = 0
    total_price: float = 0


@dataclass
class ReceiptData:
    """영수증 데이터"""
    store_name: Optional[str] = None
    date: Optional[str] = None
    total_amount: Optional[float] = None
    items: List[ReceiptItem] = None
    raw_text: str = ""
    category: Optional[str] = None  # 자동 판단된 카테고리
    
    def __post_init__(self):
        if self.items is None:
            self.items = []
    
    def to_dict(self) -> Dict:
        """딕셔너리로 변환"""
        return {
            'store_name': self.store_name,
            'date': self.date,
            'total_amount': self.total_amount,
            'items': [asdict(item) for item in self.items],
            'raw_text': self.raw_text,
            'category': self.category,
        }


# 카테고리 판단을 위한 키워드 사전
CATEGORY_KEYWORDS = {
    '식비': [
        # 음식점
        '식당', '레스토랑', 'restaurant', '치킨', '피자', '햄버거', '버거킹', '맥도날드',
        'kfc', '롯데리아', '파파이스', '써브웨이', 'subway', '도미노', '미스터피자',
        '피자헛', '뽕뜨락', '김밥', '분식', '떡볶이', '순대', '라면', '국밥', '설렁탕',
        '삼겹살', '고기', '구이', '족발', '보쌈', '냉면', '칼국수', '짜장', '짬뽕',
        '중화요리', '일식', '초밥', '스시', '우동', '돈까스', '돈가스', '덮밥',
        '비빔밥', '백반', '한식', '양식', '중식', '일식', '분식', '배달', '요기요',
        '배달의민족', '쿠팡이츠', '배민', '반찬', '도시락', '정식', '식사',
    ],
    '카페': [
        '카페', 'cafe', 'coffee', '커피', '스타벅스', 'starbucks', '투썸', '투썸플레이스',
        'twosome', '이디야', 'ediya', '빽다방', '메가커피', 'mega', '컴포즈', 'compose',
        '할리스', 'hollys', '엔젤리너스', '파스쿠찌', 'pascucci', '탐앤탐스', 'tom n toms',
        '폴바셋', 'paul bassett', '블루보틀', 'blue bottle', '아메리카노', '라떼', '에스프레소',
        '카푸치노', '프라푸치노', '빙수', '디저트', '케이크', '마카롱', '쿠키', '베이커리',
        '브레드', '빵집', '베이글', '크로와상', '와플', '공차', '고카페', '달콤커피',
    ],
    '편의점': [
        'cu', 'gs25', 'gs 25', '세븐일레븐', '7-eleven', '711', '이마트24', 'emart24',
        '미니스톱', 'ministop', '편의점', 'cvs', '씨유', '지에스', '스토리웨이',
    ],
    '마트': [
        '이마트', 'emart', '홈플러스', 'homeplus', '롯데마트', 'lottemart', '코스트코',
        'costco', '하나로마트', '농협마트', '메가마트', '빅마트', '킴스클럽', '마트',
        '슈퍼마켓', '슈퍼', '식료품', '농산물', '수산물', '정육', '채소', '과일',
        '트레이더스', 'traders', '노브랜드', 'no brand', '다이소', 'daiso',
    ],
    '쇼핑': [
        '백화점', '롯데백화점', '신세계', '현대백화점', '갤러리아', '아울렛', 'outlet',
        '의류', '옷', '패션', 'fashion', '신발', '가방', '악세서리', '쥬얼리', '시계',
        '화장품', '코스메틱', '올리브영', '롭스', '랄라블라', '뷰티', 'beauty',
        '유니클로', 'uniqlo', 'zara', '자라', 'h&m', '무신사', 'musinsa', '에이블리',
        '지그재그', 'zigzag', '쿠팡', 'coupang', '11번가', 'g마켓', 'gmarket', '옥션',
    ],
    '교통': [
        '주유', '주유소', '기름', '휘발유', '경유', 'lpg', 'gs칼텍스', 'sk에너지',
        's-oil', '에쓰오일', '현대오일', '알뜰주유소', '택시', 'taxi', '우버', 'uber',
        '카카오택시', 't map', '티맵', '버스', 'bus', '지하철', 'metro', 'subway',
        '고속버스', '시외버스', 'ktx', 'srt', '기차', '열차', '톨게이트', '하이패스',
        '주차', 'parking', '주차장', '발렛', '렌터카', '렌트카', 'rent', '쏘카', 'socar',
        '그린카', 'greencar', '타다', '정비', '카센터', '타이어', '오토', 'auto',
    ],
    '의료': [
        '병원', 'hospital', '의원', 'clinic', '약국', 'pharmacy', '약', '처방',
        '진료', '치료', '수술', '검사', '건강', '의료', '보험', '실비', '한의원',
        '치과', '안과', '피부과', '성형', '정형외과', '내과', '외과', '산부인과',
        '소아과', '이비인후과', '비뇨기과', '신경과', '정신과', '재활', '물리치료',
        '한약', '침', '보약', '건강검진', '건진', '예방접종', '백신', '비타민', '영양제',
    ],
    '여가': [
        '영화', 'movie', 'cgv', '롯데시네마', '메가박스', 'megabox', '씨네', 'cine',
        '극장', 'theater', '게임', 'game', 'pc방', '피시방', '노래방', '코인노래방',
        '볼링', 'bowling', '당구', 'billiard', '헬스', 'gym', 'fitness', '요가', 'yoga',
        '필라테스', 'pilates', '수영', '골프', 'golf', '테니스', 'tennis', '축구',
        '야구', '농구', '배드민턴', '운동', 'sports', '레저', 'leisure', '여행',
        'travel', '호텔', 'hotel', '모텔', '펜션', '리조트', 'resort', '에어비앤비',
        'airbnb', '항공', 'airline', '비행기', '티켓', 'ticket', '공연', '콘서트',
        '뮤지컬', '연극', '전시', '미술관', '박물관', '놀이공원', '워터파크',
    ],
    '공과금': [
        '전기', 'electric', '한국전력', '한전', 'kepco', '가스', 'gas', '도시가스',
        '수도', 'water', '상하수도', '통신', '핸드폰', '휴대폰', '인터넷', 'internet',
        'kt', 'skt', 'sk텔레콤', 'lg유플러스', 'lgu+', '관리비', '월세', '임대료',
        '보험료', '건강보험', '국민연금', '세금', 'tax', '공과금', '요금', '납부',
    ],
}


class ReceiptParser:
    """한국어 영수증 텍스트 파서"""
    
    # 상점명 키워드 (이 키워드가 포함된 줄은 상점명이 아님)
    EXCLUDE_STORE_KEYWORDS = [
        '영수증', '카드', '현금', '합계', '총액', '부가세', '과세', '면세',
        '전화', 'tel', '주소', '사업자', '대표', '거래', '승인', '카드번호',
        '일시', '신용', '체크', '결제', '취소', '반품', '교환', '소계', '거스름'
    ]
    
    # 금액 패턴 (한국 영수증) - 띄어쓰기 문제 해결을 위해 유연하게 설정
    AMOUNT_PATTERNS = [
        # 총 금액/합계 패턴
        (r'총[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        (r'합[\s]*계[\s:：]*([0-9,]+)', 'total'),
        (r'결[\s]*제[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        (r'판[\s]*매[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        (r'총[\s]*액[\s:：]*([0-9,]+)', 'total'),
        (r'TOTAL[\s:：]*([0-9,]+)', 'total'),
        (r'합[\s]*계[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        # 소계 패턴
        (r'소[\s]*계[\s:：]*([0-9,]+)', 'subtotal'),
        (r'SUB[\s]*TOTAL[\s:：]*([0-9,]+)', 'subtotal'),
        # 전체 승인 / 승인 금액 패턴  
        (r'전[\s]*체[\s]*승[\s]*인[\s:：]*([0-9,]+)', 'total'),
        (r'승[\s]*인[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        (r'승[\s]*인[\s:：]*([0-9,]+)', 'total'),
        # 받을 금액
        (r'받[\s]*을[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        # 실제 결제 금액
        (r'실[\s]*결[\s]*제[\s:：]*([0-9,]+)', 'total'),
        # 결제/지불 금액
        (r'결[\s]*제[\s:：]*([0-9,]+)', 'total'),
        (r'지[\s]*불[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        # 카드 결제
        (r'카[\s]*드[\s]*결[\s]*제[\s:：]*([0-9,]+)', 'total'),
        (r'신[\s]*용[\s]*카[\s]*드[\s:：]*([0-9,]+)', 'total'),
        # 현금 결제
        (r'현[\s]*금[\s]*결[\s]*제[\s:：]*([0-9,]+)', 'total'),
        # 거스름돈 역산을 위한 패턴 (받은 금액 - 거스름돈)
        (r'받[\s]*은[\s]*돈[\s:：]*([0-9,]+)', 'received'),
        (r'거[\s]*스[\s]*름[\s:：]*([0-9,]+)', 'change'),
    ]
    
    # 날짜 패턴
    DATE_PATTERNS = [
        # YYYY-MM-DD, YYYY.MM.DD, YYYY/MM/DD
        r'(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})',
        # YY-MM-DD, YY.MM.DD
        r'(\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})',
        # YYYY년 MM월 DD일
        r'(\d{4})년[\s]*(\d{1,2})월[\s]*(\d{1,2})일',
    ]
    
    def __init__(self):
        self._compiled_amount_patterns = [
            (re.compile(pattern, re.IGNORECASE), ptype)
            for pattern, ptype in self.AMOUNT_PATTERNS
        ]
        self._compiled_date_patterns = [
            re.compile(pattern) for pattern in self.DATE_PATTERNS
        ]
    
    def parse(self, ocr_texts: List[Tuple[str, float]]) -> ReceiptData:
        """
        OCR 결과를 파싱하여 구조화된 데이터 반환
        
        Args:
            ocr_texts: (text, confidence) 튜플 리스트
            
        Returns:
            ReceiptData 객체
        """
        # 텍스트만 추출
        texts = [text for text, _ in ocr_texts]
        raw_text = '\n'.join(texts)
        
        # 각 정보 추출
        store_name = self._extract_store_name(texts)
        date = self._extract_date(raw_text)
        total_amount = self._extract_total_amount(raw_text)
        items = self._extract_items(texts)
        
        # 카테고리 자동 판단
        category = self._guess_category(store_name, raw_text, items)
        
        return ReceiptData(
            store_name=store_name,
            date=date,
            total_amount=total_amount,
            items=items,
            raw_text=raw_text,
            category=category,
        )
    
    def parse_from_text(self, raw_text: str) -> ReceiptData:
        """
        원시 텍스트를 파싱하여 구조화된 데이터 반환
        """
        texts = raw_text.split('\n')
        ocr_texts = [(text, 1.0) for text in texts if text.strip()]
        return self.parse(ocr_texts)
    
    def _extract_store_name(self, texts: List[str]) -> Optional[str]:
        """
        상점명 추출 (보통 영수증 상단에 위치)
        """
        # 처음 7줄 내에서 상점명 찾기
        for text in texts[:7]:
            text = text.strip()
            
            # 빈 줄 스킵
            if not text or len(text) < 2:
                continue
            
            # 숫자만 있는 줄 스킵
            if re.match(r'^[\d\s\-:./]+$', text):
                continue
            
            # 제외 키워드 포함 시 스킵
            if any(keyword in text.lower() for keyword in self.EXCLUDE_STORE_KEYWORDS):
                continue
            
            # 전화번호 패턴 스킵
            if re.search(r'\d{2,4}[-\s]?\d{3,4}[-\s]?\d{4}', text):
                continue
            
            # 사업자등록번호 패턴 스킵
            if re.search(r'\d{3}[-\s]?\d{2}[-\s]?\d{5}', text):
                continue
            
            # 유효한 상점명이면 반환
            if len(text) >= 2:
                # 앞뒤 특수문자 제거
                cleaned = re.sub(r'^[\*\-=\s]+|[\*\-=\s]+$', '', text)
                if cleaned:
                    return cleaned
        
        return None
    
    def _extract_date(self, text: str) -> Optional[str]:
        """
        날짜 추출 (YYYY-MM-DD 형식으로 반환)
        """
        for pattern in self._compiled_date_patterns:
            match = pattern.search(text)
            if match:
                groups = match.groups()
                
                # 년도 처리
                year = int(groups[0])
                if year < 100:
                    year += 2000
                
                month = int(groups[1])
                day = int(groups[2])
                
                # 유효성 검사
                if 1 <= month <= 12 and 1 <= day <= 31:
                    return f"{year:04d}-{month:02d}-{day:02d}"
        
        return None
    
    def _extract_total_amount(self, text: str) -> Optional[float]:
        """
        총 금액 추출 - 띄어쓰기 문제 해결을 위해 공백 제거 후 매칭
        """
        amounts = []
        received = None
        change = None
        
        # 공백을 제거한 버전도 시도
        text_no_space = re.sub(r'\s+', '', text)
        
        for pattern, ptype in self._compiled_amount_patterns:
            # 원본 텍스트에서 시도
            matches = pattern.findall(text)
            for match in matches:
                try:
                    amount_str = match.replace(',', '')
                    amount = float(amount_str)
                    if amount > 0:
                        if ptype == 'received':
                            received = amount
                        elif ptype == 'change':
                            change = amount
                        elif ptype in ('total', 'subtotal'):
                            amounts.append(amount)
                except ValueError:
                    continue
            
            # 공백 제거 버전에서도 시도 (더 정확한 매칭)
            pattern_no_space = re.compile(pattern.pattern.replace(r'[\s]*', '').replace(r'[\s]', ''), re.IGNORECASE)
            matches = pattern_no_space.findall(text_no_space)
            for match in matches:
                try:
                    amount_str = match.replace(',', '')
                    amount = float(amount_str)
                    if amount > 0 and amount not in amounts:
                        amounts.append(amount)
                except ValueError:
                    continue
        
        # 거스름돈 계산으로 결제 금액 추정
        if received is not None and change is not None:
            calc_amount = received - change
            if calc_amount > 0:
                amounts.append(calc_amount)
        
        # 가장 큰 금액을 총 금액으로 간주
        if amounts:
            return max(amounts)
        
        # 패턴 매칭 실패 시, "원" 단위 숫자 추출
        number_pattern = re.compile(r'([0-9,]+)[\s]*원')
        matches = number_pattern.findall(text)
        
        for match in matches:
            try:
                amount = float(match.replace(',', ''))
                if amount >= 100:  # 100원 이상만
                    amounts.append(amount)
            except ValueError:
                continue
        
        return max(amounts) if amounts else None
    
    def _extract_items(self, texts: List[str]) -> List[ReceiptItem]:
        """
        품목 리스트 추출
        """
        items = []
        
        # 품목 패턴들
        item_patterns = [
            # 상품명 수량 단가 금액
            re.compile(r'^(.+?)\s+(\d+)\s+([0-9,]+)\s+([0-9,]+)$'),
            # 상품명 금액
            re.compile(r'^(.+?)\s+([0-9,]+)$'),
        ]
        
        # 제외 키워드
        exclude_keywords = ['합계', '총액', '부가세', '과세', '면세', '결제', '소계', '승인', '거스름', '받은']
        
        for text in texts:
            text = text.strip()
            
            # 제외 키워드
            if any(kw in text for kw in exclude_keywords):
                continue
            
            # 상세 패턴 매칭
            match = item_patterns[0].match(text)
            if match:
                name = match.group(1).strip()
                quantity = int(match.group(2))
                unit_price = float(match.group(3).replace(',', ''))
                total_price = float(match.group(4).replace(',', ''))
                
                if name and total_price > 0:
                    items.append(ReceiptItem(
                        name=name,
                        quantity=quantity,
                        unit_price=unit_price,
                        total_price=total_price,
                    ))
                continue
            
            # 간단한 패턴 매칭
            match = item_patterns[1].match(text)
            if match:
                name = match.group(1).strip()
                total_price = float(match.group(2).replace(',', ''))
                
                # 상품명이 너무 짧거나 숫자만 있으면 스킵
                if len(name) < 2 or re.match(r'^[\d\s]+$', name):
                    continue
                
                # 금액이 너무 작으면 스킵
                if total_price < 100:
                    continue
                
                items.append(ReceiptItem(
                    name=name,
                    quantity=1,
                    unit_price=total_price,
                    total_price=total_price,
                ))
        
        return items
    
    def _guess_category(self, store_name: Optional[str], raw_text: str, items: List[ReceiptItem]) -> str:
        """
        상점명과 텍스트 내용을 기반으로 카테고리 추론
        """
        # 검색할 텍스트 준비 (소문자, 공백 정규화)
        search_text = ""
        if store_name:
            search_text += store_name.lower() + " "
        search_text += raw_text.lower()
        
        # 품목명도 검색 대상에 추가
        for item in items:
            search_text += " " + item.name.lower()
        
        # 공백 정규화
        search_text = re.sub(r'\s+', ' ', search_text)
        
        # 각 카테고리별 매칭 점수 계산
        category_scores = {}
        
        for category, keywords in CATEGORY_KEYWORDS.items():
            score = 0
            for keyword in keywords:
                keyword_lower = keyword.lower()
                if keyword_lower in search_text:
                    # 상점명에서 매칭되면 더 높은 점수
                    if store_name and keyword_lower in store_name.lower():
                        score += 10
                    else:
                        score += 1
            
            if score > 0:
                category_scores[category] = score
        
        # 가장 높은 점수의 카테고리 반환
        if category_scores:
            best_category = max(category_scores, key=category_scores.get)
            return best_category
        
        return '기타'


def parse_receipt_ocr_result(ocr_texts: List[Tuple[str, float]]) -> Dict:
    """
    OCR 결과를 파싱하여 딕셔너리로 반환하는 헬퍼 함수
    """
    parser = ReceiptParser()
    result = parser.parse(ocr_texts)
    return result.to_dict()
