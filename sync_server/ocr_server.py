"""
Receipt OCR Server with PaddleOCR
기존 sync_server와 통합된 OCR 서버
"""

import io
import base64
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Optional
from contextlib import contextmanager

from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Import OCR modules
from ocr.receipt_ocr import ReceiptOCR, preprocess_receipt_image
from ocr.text_parser import ReceiptParser

# Database path
DB_PATH = Path(__file__).parent / "sync_data.db"

app = FastAPI(
    title="Receipt Ledger OCR Server",
    description="PaddleOCR 기반 영수증 OCR 서버",
    version="2.0.0"
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# OCR 엔진 초기화 (싱글톤)
ocr_engine: Optional[ReceiptOCR] = None
receipt_parser: Optional[ReceiptParser] = None


def get_ocr_engine() -> ReceiptOCR:
    """OCR 엔진 싱글톤"""
    global ocr_engine
    if ocr_engine is None:
        ocr_engine = ReceiptOCR(use_gpu=False, lang='korean')
    return ocr_engine


def get_parser() -> ReceiptParser:
    """파서 싱글톤"""
    global receipt_parser
    if receipt_parser is None:
        receipt_parser = ReceiptParser()
    return receipt_parser


# Pydantic Models
class OCRRequest(BaseModel):
    """Base64 이미지 OCR 요청"""
    image: str  # Base64 encoded image
    preprocess: bool = True  # 이미지 전처리 여부


class OCRResponse(BaseModel):
    """OCR 응답"""
    store_name: Optional[str] = None
    date: Optional[str] = None
    total_amount: Optional[float] = None
    items: list = []
    raw_text: str = ""
    processing_time_ms: int = 0


class TransactionModel(BaseModel):
    id: str
    date: str
    category: str
    amount: float
    description: str
    receiptImagePath: Optional[str] = None
    storeName: Optional[str] = None
    isIncome: int
    ownerKey: str
    createdAt: str
    updatedAt: str
    isSynced: int = 1


class SyncRequest(BaseModel):
    transactions: list[TransactionModel]
    lastSyncTime: Optional[str] = None


class SyncResponse(BaseModel):
    uploaded: int
    downloaded: list[TransactionModel]
    serverTime: str


# Database functions
@contextmanager
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def init_db():
    """Initialize database"""
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY,
                date TEXT NOT NULL,
                category TEXT NOT NULL,
                amount REAL NOT NULL,
                description TEXT NOT NULL,
                receiptImagePath TEXT,
                storeName TEXT,
                isIncome INTEGER DEFAULT 0,
                ownerKey TEXT NOT NULL,
                createdAt TEXT NOT NULL,
                updatedAt TEXT NOT NULL,
                serverUpdatedAt TEXT NOT NULL
            )
        """)
        conn.commit()
    print(f"Database initialized at: {DB_PATH}")


def row_to_transaction(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "date": row["date"],
        "category": row["category"],
        "amount": row["amount"],
        "description": row["description"],
        "receiptImagePath": row["receiptImagePath"],
        "storeName": row["storeName"],
        "isIncome": row["isIncome"],
        "ownerKey": row["ownerKey"],
        "createdAt": row["createdAt"],
        "updatedAt": row["updatedAt"],
        "isSynced": 1,
    }


# ============== OCR Endpoints ==============

@app.post("/api/ocr", response_model=OCRResponse)
async def process_receipt_ocr(request: OCRRequest):
    """
    Base64 인코딩된 이미지에서 영수증 정보 추출
    
    - **image**: Base64 인코딩된 이미지 문자열
    - **preprocess**: 이미지 전처리 여부 (기본값: True)
    """
    import time
    start_time = time.time()
    
    try:
        # Base64 디코딩
        image_data = request.image
        if ',' in image_data:
            image_data = image_data.split(',')[1]
        
        image_bytes = base64.b64decode(image_data)
        
        # 이미지 전처리
        if request.preprocess:
            image_bytes = preprocess_receipt_image(image_bytes)
        
        # OCR 실행
        ocr = get_ocr_engine()
        ocr_results = ocr.process_image(image_bytes)
        
        # 텍스트 파싱
        parser = get_parser()
        receipt_data = parser.parse(ocr_results)
        
        # 처리 시간 계산
        processing_time = int((time.time() - start_time) * 1000)
        
        return OCRResponse(
            store_name=receipt_data.store_name,
            date=receipt_data.date,
            total_amount=receipt_data.total_amount,
            items=[{
                'name': item.name,
                'quantity': item.quantity,
                'unit_price': item.unit_price,
                'total_price': item.total_price,
            } for item in receipt_data.items],
            raw_text=receipt_data.raw_text,
            processing_time_ms=processing_time,
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OCR 처리 실패: {str(e)}")


@app.post("/api/ocr/upload")
async def process_receipt_upload(
    file: UploadFile = File(...),
    preprocess: bool = Form(True)
):
    """
    파일 업로드로 영수증 OCR 처리
    
    - **file**: 영수증 이미지 파일
    - **preprocess**: 이미지 전처리 여부
    """
    import time
    start_time = time.time()
    
    try:
        # 파일 읽기
        image_bytes = await file.read()
        
        # 이미지 전처리
        if preprocess:
            image_bytes = preprocess_receipt_image(image_bytes)
        
        # OCR 실행
        ocr = get_ocr_engine()
        ocr_results = ocr.process_image(image_bytes)
        
        # 텍스트 파싱
        parser = get_parser()
        receipt_data = parser.parse(ocr_results)
        
        # 처리 시간 계산
        processing_time = int((time.time() - start_time) * 1000)
        
        return {
            "store_name": receipt_data.store_name,
            "date": receipt_data.date,
            "total_amount": receipt_data.total_amount,
            "items": [{
                'name': item.name,
                'quantity': item.quantity,
                'unit_price': item.unit_price,
                'total_price': item.total_price,
            } for item in receipt_data.items],
            "raw_text": receipt_data.raw_text,
            "processing_time_ms": processing_time,
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OCR 처리 실패: {str(e)}")


@app.get("/api/ocr/status")
async def ocr_status():
    """OCR 엔진 상태 확인"""
    try:
        # OCR 엔진 초기화 확인
        ocr = get_ocr_engine()
        return {
            "status": "ready",
            "engine": "PaddleOCR",
            "language": ocr.lang,
            "gpu": ocr.use_gpu,
        }
    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
        }


# ============== Health & Info ==============

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "time": datetime.now().isoformat(),
        "version": "2.0.0",
        "features": ["sync", "ocr"],
    }


@app.get("/")
async def root():
    """API 정보"""
    return {
        "name": "Receipt Ledger OCR Server",
        "version": "2.0.0",
        "endpoints": {
            "ocr": "/api/ocr",
            "ocr_upload": "/api/ocr/upload",
            "sync": "/api/sync",
            "health": "/health",
        }
    }


# ============== Sync Endpoints (기존 sync_server.py와 동일) ==============

@app.get("/api/transactions")
async def get_all_transactions():
    with get_db() as conn:
        cursor = conn.execute("SELECT * FROM transactions ORDER BY date DESC")
        rows = cursor.fetchall()
        return [row_to_transaction(row) for row in rows]


@app.get("/api/transactions/{transaction_id}")
async def get_transaction(transaction_id: str):
    with get_db() as conn:
        cursor = conn.execute(
            "SELECT * FROM transactions WHERE id = ?", (transaction_id,)
        )
        row = cursor.fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Transaction not found")
        return row_to_transaction(row)


@app.post("/api/transactions")
async def upsert_transaction(transaction: TransactionModel):
    server_time = datetime.now().isoformat()
    
    with get_db() as conn:
        conn.execute("""
            INSERT INTO transactions 
            (id, date, category, amount, description, receiptImagePath, 
             storeName, isIncome, ownerKey, createdAt, updatedAt, serverUpdatedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                date = excluded.date,
                category = excluded.category,
                amount = excluded.amount,
                description = excluded.description,
                receiptImagePath = excluded.receiptImagePath,
                storeName = excluded.storeName,
                isIncome = excluded.isIncome,
                updatedAt = excluded.updatedAt,
                serverUpdatedAt = excluded.serverUpdatedAt
        """, (
            transaction.id,
            transaction.date,
            transaction.category,
            transaction.amount,
            transaction.description,
            transaction.receiptImagePath,
            transaction.storeName,
            transaction.isIncome,
            transaction.ownerKey,
            transaction.createdAt,
            transaction.updatedAt,
            server_time,
        ))
        conn.commit()
    
    return {"status": "ok", "id": transaction.id}


@app.delete("/api/transactions/{transaction_id}")
async def delete_transaction(transaction_id: str):
    with get_db() as conn:
        cursor = conn.execute(
            "DELETE FROM transactions WHERE id = ?", (transaction_id,)
        )
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Transaction not found")
    return {"status": "ok", "id": transaction_id}


@app.get("/api/sync")
async def get_changes_since(since: Optional[str] = None):
    with get_db() as conn:
        if since:
            cursor = conn.execute(
                "SELECT * FROM transactions WHERE serverUpdatedAt > ? ORDER BY serverUpdatedAt",
                (since,)
            )
        else:
            cursor = conn.execute("SELECT * FROM transactions ORDER BY serverUpdatedAt")
        
        rows = cursor.fetchall()
        return {
            "transactions": [row_to_transaction(row) for row in rows],
            "serverTime": datetime.now().isoformat(),
        }


@app.post("/api/sync")
async def sync_transactions(request: SyncRequest):
    server_time = datetime.now().isoformat()
    uploaded_count = 0
    
    with get_db() as conn:
        for t in request.transactions:
            conn.execute("""
                INSERT INTO transactions 
                (id, date, category, amount, description, receiptImagePath, 
                 storeName, isIncome, ownerKey, createdAt, updatedAt, serverUpdatedAt)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    date = excluded.date,
                    category = excluded.category,
                    amount = excluded.amount,
                    description = excluded.description,
                    receiptImagePath = excluded.receiptImagePath,
                    storeName = excluded.storeName,
                    isIncome = excluded.isIncome,
                    updatedAt = excluded.updatedAt,
                    serverUpdatedAt = excluded.serverUpdatedAt
                WHERE excluded.updatedAt > transactions.updatedAt
            """, (
                t.id, t.date, t.category, t.amount, t.description,
                t.receiptImagePath, t.storeName, t.isIncome, t.ownerKey,
                t.createdAt, t.updatedAt, server_time,
            ))
            uploaded_count += 1
        
        conn.commit()
        
        if request.lastSyncTime:
            cursor = conn.execute(
                "SELECT * FROM transactions WHERE serverUpdatedAt > ?",
                (request.lastSyncTime,)
            )
        else:
            cursor = conn.execute("SELECT * FROM transactions")
        
        rows = cursor.fetchall()
        downloaded = [row_to_transaction(row) for row in rows]
    
    return SyncResponse(
        uploaded=uploaded_count,
        downloaded=downloaded,
        serverTime=server_time,
    )


# Startup event
@app.on_event("startup")
async def startup_event():
    init_db()
    # Pre-initialize OCR engine (optional, for faster first request)
    # get_ocr_engine()
    print("Server started with OCR support")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8888)
