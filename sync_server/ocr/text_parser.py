"""
Receipt Text Parser Module
OCR 결과에서 영수증 정보를 구조화하여 추출하는 모듈
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
        }


class ReceiptParser:
    """한국어 영수증 텍스트 파서"""
    
    # 상점명 키워드 (이 키워드가 포함된 줄은 상점명이 아님)
    EXCLUDE_STORE_KEYWORDS = [
        '영수증', '카드', '현금', '합계', '총액', '부가세', '과세', '면세',
        '전화', 'tel', '주소', '사업자', '대표', '거래', '승인', '카드번호',
        '일시', '신용', '체크', '결제', '취소', '반품', '교환'
    ]
    
    # 금액 패턴 (한국 영수증)
    AMOUNT_PATTERNS = [
        # 총 금액 패턴
        (r'총[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        (r'합[\s]*계[\s:：]*([0-9,]+)', 'total'),
        (r'결[\s]*제[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        (r'판[\s]*매[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        (r'총[\s]*액[\s:：]*([0-9,]+)', 'total'),
        (r'TOTAL[\s:：]*([0-9,]+)', 'total'),
        (r'합[\s]*계[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        # 받을 금액
        (r'받[\s]*을[\s]*금[\s]*액[\s:：]*([0-9,]+)', 'total'),
        # 실제 결제 금액
        (r'실[\s]*결[\s]*제[\s:：]*([0-9,]+)', 'total'),
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
    
    # 시간 패턴
    TIME_PATTERNS = [
        r'(\d{1,2}):(\d{2})(?::(\d{2}))?',
        r'(\d{1,2})시[\s]*(\d{2})분',
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
        
        return ReceiptData(
            store_name=store_name,
            date=date,
            total_amount=total_amount,
            items=items,
            raw_text=raw_text,
        )
    
    def parse_from_text(self, raw_text: str) -> ReceiptData:
        """
        원시 텍스트를 파싱하여 구조화된 데이터 반환
        
        Args:
            raw_text: OCR에서 추출된 전체 텍스트
            
        Returns:
            ReceiptData 객체
        """
        texts = raw_text.split('\n')
        ocr_texts = [(text, 1.0) for text in texts if text.strip()]
        return self.parse(ocr_texts)
    
    def _extract_store_name(self, texts: List[str]) -> Optional[str]:
        """
        상점명 추출 (보통 영수증 상단에 위치)
        """
        # 처음 5줄 내에서 상점명 찾기
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
        총 금액 추출
        """
        amounts = []
        
        for pattern, ptype in self._compiled_amount_patterns:
            matches = pattern.findall(text)
            for match in matches:
                try:
                    amount_str = match.replace(',', '')
                    amount = float(amount_str)
                    if amount > 0:
                        amounts.append(amount)
                except ValueError:
                    continue
        
        # 가장 큰 금액을 총 금액으로 간주 (영수증에서 총액이 가장 큼)
        if amounts:
            return max(amounts)
        
        # 패턴 매칭 실패 시, 숫자만 추출하여 가장 큰 값 찾기
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
        
        # 품목 패턴: 상품명 수량 단가 금액
        # 예: "아메리카노 2 4,500 9,000"
        # 예: "아메리카노    2    4,500    9,000"
        item_pattern = re.compile(
            r'^(.+?)\s+(\d+)\s+([0-9,]+)\s+([0-9,]+)$'
        )
        
        # 간단한 패턴: 상품명 금액
        # 예: "아메리카노 9,000"
        simple_pattern = re.compile(
            r'^(.+?)\s+([0-9,]+)$'
        )
        
        for text in texts:
            text = text.strip()
            
            # 제외 키워드
            if any(kw in text for kw in ['합계', '총액', '부가세', '과세', '면세', '결제']):
                continue
            
            # 상세 패턴 매칭
            match = item_pattern.match(text)
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
            match = simple_pattern.match(text)
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


def parse_receipt_ocr_result(ocr_texts: List[Tuple[str, float]]) -> Dict:
    """
    OCR 결과를 파싱하여 딕셔너리로 반환하는 헬퍼 함수
    
    Args:
        ocr_texts: (text, confidence) 튜플 리스트
        
    Returns:
        영수증 데이터 딕셔너리
    """
    parser = ReceiptParser()
    result = parser.parse(ocr_texts)
    return result.to_dict()
