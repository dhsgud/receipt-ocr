"""
Receipt OCR Server - Gemini Vision API
기존 sync_server와 통합된 OCR 서버 (Gemini API Backend)
"""

import io
import json
import base64
import sqlite3
import traceback
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Any
from contextlib import contextmanager
from dotenv import load_dotenv

load_dotenv() # Load environment variables


from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel

# Import OCR modules
from ocr.receipt_ocr import ReceiptOCR, preprocess_receipt_image

# Database path
DB_PATH = Path(__file__).parent / "sync_data.db"

# Image storage path
IMAGES_PATH = Path(__file__).parent / "images"
IMAGES_PATH.mkdir(exist_ok=True)

app = FastAPI(
    title="Receipt Ledger OCR Server",
    description="Gemini Vision API 기반 영수증 OCR 서버",
    version="2.2.0"
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

def get_ocr_engine() -> ReceiptOCR:
    """OCR 엔진 싱글톤"""
    global ocr_engine
    if ocr_engine is None:
        ocr_engine = ReceiptOCR(use_gpu=False, lang='korean')
    return ocr_engine


# Pydantic Models
class OCRRequest(BaseModel):
    """Base64 이미지 OCR 요청"""
    image: str  # Base64 encoded image
    preprocess: bool = True  # 이미지 전처리 여부
    provider: str = 'gemini'  # 'gemini' (default)


class ReceiptItem(BaseModel):
    name: str
    quantity: int
    unit_price: int
    total_price: int

class OCRResponse(BaseModel):
    """OCR 응답"""
    store_name: Optional[str] = None
    date: Optional[str] = None
    total_amount: Optional[int] = None
    items: List[ReceiptItem] = []
    raw_text: str = ""
    category: Optional[str] = None
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


class BudgetModel(BaseModel):
    id: str
    year: int
    month: int
    totalBudget: float
    categoryBudgets: str  # JSON string
    ownerKey: str
    createdAt: str
    updatedAt: str
    isSynced: int = 1


class FixedExpenseModel(BaseModel):
    id: str
    name: str
    amount: float
    categoryId: str
    paymentDay: int
    frequency: int
    isActive: int
    autoRecord: int
    memo: Optional[str] = None
    ownerKey: str
    createdAt: str
    updatedAt: str
    lastRecordedDate: Optional[str] = None
    isSynced: int = 1


class SyncRequest(BaseModel):
    transactions: list[TransactionModel] = []
    budgets: list[BudgetModel] = []
    fixedExpenses: list[FixedExpenseModel] = []
    lastSyncTime: Optional[str] = None


class SyncResponse(BaseModel):
    uploaded: int
    downloaded: list[TransactionModel]
    downloadedBudgets: list[dict] = []
    downloadedFixedExpenses: list[dict] = []
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
        conn.execute("""
            CREATE TABLE IF NOT EXISTS budgets (
                id TEXT PRIMARY KEY,
                year INTEGER NOT NULL,
                month INTEGER NOT NULL,
                totalBudget REAL NOT NULL,
                categoryBudgets TEXT DEFAULT '{}',
                ownerKey TEXT NOT NULL,
                createdAt TEXT NOT NULL,
                updatedAt TEXT NOT NULL,
                serverUpdatedAt TEXT NOT NULL
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS fixed_expenses (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                amount REAL NOT NULL,
                categoryId TEXT NOT NULL,
                paymentDay INTEGER NOT NULL,
                frequency INTEGER DEFAULT 0,
                isActive INTEGER DEFAULT 1,
                autoRecord INTEGER DEFAULT 0,
                memo TEXT,
                ownerKey TEXT NOT NULL,
                createdAt TEXT NOT NULL,
                updatedAt TEXT NOT NULL,
                lastRecordedDate TEXT,
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
    Base64 인코딩된 이미지에서 영수증 정보 추출 (Gemini Vision)
    """
    import time
    start_time = time.time()
    
    try:
        # Base64 디코딩
        image_data = request.image
        if ',' in image_data:
            image_data = image_data.split(',')[1]
        
        image_bytes = base64.b64decode(image_data)
        print(f"[OCR] Received image: {len(image_bytes)} bytes")
        
        # 이미지 전처리
        if request.preprocess:
            image_bytes = preprocess_receipt_image(image_bytes)
            print(f"[OCR] Preprocessed: {len(image_bytes)} bytes")
        
        # OCR 실행 (Gemini Vision API)
        ocr = get_ocr_engine()
        result = ocr.process_image_v2(image_bytes, provider=request.provider)
        print(f"[OCR] Result: {result}")
        
        # 처리 시간 계산
        processing_time = int((time.time() - start_time) * 1000)
        
        # 결과 매핑
        return OCRResponse(
            store_name=result.get('store_name'),
            date=result.get('date'),
            total_amount=result.get('total_amount'),
            items=[{
                'name': item.get('name', 'Unknown'),
                'quantity': item.get('quantity', 1),
                'unit_price': item.get('unit_price', 0),
                'total_price': item.get('total_price', 0),
            } for item in result.get('items', [])],
            raw_text=json.dumps(result, ensure_ascii=False), # 전체 JSON을 raw_text로 저장
            category=result.get('category', '기타'),  # SLLM이 자동 분류
            processing_time_ms=processing_time,
        )
        
    except Exception as e:
        print(f"[OCR ERROR] {str(e)}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"OCR 처리 실패: {str(e)}")


@app.post("/api/ocr/upload")
async def process_receipt_upload(
    file: UploadFile = File(...),
    preprocess: bool = Form(True)
):
    """
    파일 업로드로 영수증 OCR 처리
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
        result = ocr.process_image(image_bytes)
        
        # 처리 시간 계산
        processing_time = int((time.time() - start_time) * 1000)
        
        return {
            "store_name": result.get('store_name'),
            "date": result.get('date'),
            "total_amount": result.get('total_amount'),
            "items": result.get('items', []),
            "raw_text": json.dumps(result, ensure_ascii=False),
            "category": result.get('category', '기타'),  # SLLM이 자동 분류
            "processing_time_ms": processing_time,
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OCR 처리 실패: {str(e)}")


@app.get("/api/ocr/status")
async def ocr_status():
    """OCR 엔진 상태 확인"""
    try:
        return {
            "status": "ready",
            "engine": "Gemini Vision API (gemini-2.0-flash)",
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
        "version": "2.2.0",
        "features": ["sync", "ocr", "images"],
    }


@app.get("/")
async def root():
    """API 정보"""
    return {
        "name": "Receipt Ledger OCR Server",
        "version": "2.2.0",
        "endpoints": {
            "ocr": "/api/ocr",
            "ocr_upload": "/api/ocr/upload",
            "sync": "/api/sync",
            "images": "/api/images/{transaction_id}",
            "health": "/health",
        }
    }


# ============== Image Endpoints ==============

class ImageUploadRequest(BaseModel):
    """이미지 업로드 요청"""
    image: str  # Base64 encoded image


@app.post("/api/images/{transaction_id}")
async def upload_image(transaction_id: str, request: ImageUploadRequest):
    """
    트랜잭션 ID에 해당하는 영수증 이미지 업로드 (Base64)
    """
    try:
        # Base64 디코딩
        image_data = request.image
        if ',' in image_data:
            image_data = image_data.split(',')[1]
        
        image_bytes = base64.b64decode(image_data)
        
        # 이미지 저장
        image_path = IMAGES_PATH / f"{transaction_id}.jpg"
        with open(image_path, 'wb') as f:
            f.write(image_bytes)
        
        print(f"[Image] Saved: {image_path} ({len(image_bytes)} bytes)")
        
        return {
            "status": "ok",
            "transaction_id": transaction_id,
            "size_bytes": len(image_bytes),
        }
    except Exception as e:
        print(f"[Image ERROR] {str(e)}")
        raise HTTPException(status_code=500, detail=f"이미지 저장 실패: {str(e)}")


@app.get("/api/images/{transaction_id}")
async def get_image(transaction_id: str):
    """
    트랜잭션 ID에 해당하는 영수증 이미지 다운로드
    """
    image_path = IMAGES_PATH / f"{transaction_id}.jpg"
    
    if not image_path.exists():
        raise HTTPException(status_code=404, detail="이미지를 찾을 수 없습니다")
    
    return FileResponse(
        path=str(image_path),
        media_type="image/jpeg",
        filename=f"{transaction_id}.jpg"
    )


@app.head("/api/images/{transaction_id}")
async def check_image(transaction_id: str):
    """
    이미지 존재 여부 확인 (HEAD 요청)
    """
    image_path = IMAGES_PATH / f"{transaction_id}.jpg"
    
    if not image_path.exists():
        raise HTTPException(status_code=404, detail="이미지를 찾을 수 없습니다")
    
    return {"exists": True}


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
async def sync_transactions(
    request: SyncRequest,
    owner_key: str = Header(None, alias="X-Owner-Key"),
    partner_key: str = Header(None, alias="X-Partner-Key")
):
    """Full sync with partner-based filtering"""
    server_time = datetime.now().isoformat()
    uploaded_count = 0
    
    with get_db() as conn:
        # Upload transactions
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
        
        # Upload budgets
        for b in request.budgets:
            conn.execute("""
                INSERT INTO budgets
                (id, year, month, totalBudget, categoryBudgets, ownerKey,
                 createdAt, updatedAt, serverUpdatedAt)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    totalBudget = excluded.totalBudget,
                    categoryBudgets = excluded.categoryBudgets,
                    updatedAt = excluded.updatedAt,
                    serverUpdatedAt = excluded.serverUpdatedAt
                WHERE excluded.updatedAt > budgets.updatedAt
            """, (
                b.id, b.year, b.month, b.totalBudget, b.categoryBudgets,
                b.ownerKey, b.createdAt, b.updatedAt, server_time,
            ))
            uploaded_count += 1
        
        # Upload fixed expenses
        for e in request.fixedExpenses:
            conn.execute("""
                INSERT INTO fixed_expenses
                (id, name, amount, categoryId, paymentDay, frequency,
                 isActive, autoRecord, memo, ownerKey, createdAt, updatedAt,
                 lastRecordedDate, serverUpdatedAt)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    amount = excluded.amount,
                    categoryId = excluded.categoryId,
                    paymentDay = excluded.paymentDay,
                    frequency = excluded.frequency,
                    isActive = excluded.isActive,
                    autoRecord = excluded.autoRecord,
                    memo = excluded.memo,
                    updatedAt = excluded.updatedAt,
                    lastRecordedDate = excluded.lastRecordedDate,
                    serverUpdatedAt = excluded.serverUpdatedAt
                WHERE excluded.updatedAt > fixed_expenses.updatedAt
            """, (
                e.id, e.name, e.amount, e.categoryId, e.paymentDay,
                e.frequency, e.isActive, e.autoRecord, e.memo, e.ownerKey,
                e.createdAt, e.updatedAt, e.lastRecordedDate, server_time,
            ))
            uploaded_count += 1
        
        conn.commit()
        
        # Build list of allowed owner keys (self + partner)
        allowed_keys = []
        if owner_key:
            allowed_keys.append(owner_key)
        if partner_key:
            allowed_keys.append(partner_key)
        
        # Download transactions
        if allowed_keys:
            placeholders = ",".join("?" * len(allowed_keys))
            if request.lastSyncTime:
                cursor = conn.execute(
                    f"SELECT * FROM transactions WHERE ownerKey IN ({placeholders}) AND serverUpdatedAt > ?",
                    (*allowed_keys, request.lastSyncTime)
                )
            else:
                cursor = conn.execute(
                    f"SELECT * FROM transactions WHERE ownerKey IN ({placeholders})",
                    tuple(allowed_keys)
                )
        else:
            cursor = conn.execute("SELECT * FROM transactions WHERE 1=0")
        
        rows = cursor.fetchall()
        downloaded = [row_to_transaction(row) for row in rows]
        
        # Download budgets
        downloaded_budgets = []
        if allowed_keys:
            placeholders = ",".join("?" * len(allowed_keys))
            if request.lastSyncTime:
                cursor = conn.execute(
                    f"SELECT * FROM budgets WHERE ownerKey IN ({placeholders}) AND serverUpdatedAt > ?",
                    (*allowed_keys, request.lastSyncTime)
                )
            else:
                cursor = conn.execute(
                    f"SELECT * FROM budgets WHERE ownerKey IN ({placeholders})",
                    tuple(allowed_keys)
                )
            for row in cursor.fetchall():
                downloaded_budgets.append({
                    "id": row["id"], "year": row["year"], "month": row["month"],
                    "totalBudget": row["totalBudget"],
                    "categoryBudgets": row["categoryBudgets"],
                    "ownerKey": row["ownerKey"],
                    "createdAt": row["createdAt"], "updatedAt": row["updatedAt"],
                    "isSynced": 1,
                })
        
        # Download fixed expenses
        downloaded_fixed = []
        if allowed_keys:
            placeholders = ",".join("?" * len(allowed_keys))
            if request.lastSyncTime:
                cursor = conn.execute(
                    f"SELECT * FROM fixed_expenses WHERE ownerKey IN ({placeholders}) AND serverUpdatedAt > ?",
                    (*allowed_keys, request.lastSyncTime)
                )
            else:
                cursor = conn.execute(
                    f"SELECT * FROM fixed_expenses WHERE ownerKey IN ({placeholders})",
                    tuple(allowed_keys)
                )
            for row in cursor.fetchall():
                downloaded_fixed.append({
                    "id": row["id"], "name": row["name"],
                    "amount": row["amount"], "categoryId": row["categoryId"],
                    "paymentDay": row["paymentDay"], "frequency": row["frequency"],
                    "isActive": row["isActive"], "autoRecord": row["autoRecord"],
                    "memo": row["memo"], "ownerKey": row["ownerKey"],
                    "createdAt": row["createdAt"], "updatedAt": row["updatedAt"],
                    "lastRecordedDate": row["lastRecordedDate"],
                    "isSynced": 1,
                })
    
    return SyncResponse(
        uploaded=uploaded_count,
        downloaded=downloaded,
        downloadedBudgets=downloaded_budgets,
        downloadedFixedExpenses=downloaded_fixed,
        serverTime=server_time,
    )


# Startup event
@app.on_event("startup")
async def startup_event():
    init_db()
    print("Server started with Gemini Vision OCR support")


if __name__ == "__main__":
    import uvicorn
    import json
    uvicorn.run(app, host="0.0.0.0", port=9999)
