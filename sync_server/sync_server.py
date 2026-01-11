"""
Receipt Ledger Sync Server
데스크탑에서 실행되어 Flutter 앱과 데이터를 동기화하는 REST API 서버
"""

import sqlite3
import json
from datetime import datetime
from pathlib import Path
from typing import Optional
from contextlib import contextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Database path
DB_PATH = Path(__file__).parent / "sync_data.db"

app = FastAPI(title="Receipt Ledger Sync Server", version="1.0.0")

# CORS 설정 (모든 origin 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Pydantic Models
class TransactionModel(BaseModel):
    id: str
    date: str
    category: str
    amount: float
    description: str
    receiptImagePath: Optional[str] = None
    storeName: Optional[str] = None
    isIncome: int  # 0 or 1
    ownerKey: str
    createdAt: str
    updatedAt: str
    isSynced: int = 1  # 서버에 저장되면 synced


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
    """Initialize database with transactions table"""
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
    """Convert database row to transaction dict"""
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


# API Endpoints
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok", "time": datetime.now().isoformat()}


@app.get("/api/transactions")
async def get_all_transactions():
    """Get all transactions"""
    with get_db() as conn:
        cursor = conn.execute("SELECT * FROM transactions ORDER BY date DESC")
        rows = cursor.fetchall()
        return [row_to_transaction(row) for row in rows]


@app.get("/api/transactions/{transaction_id}")
async def get_transaction(transaction_id: str):
    """Get a single transaction by ID"""
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
    """Insert or update a transaction"""
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
    """Delete a transaction"""
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
    """Get transactions changed since a timestamp"""
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
    """
    Full sync: 
    1. Upload client transactions to server
    2. Return all server transactions updated since lastSyncTime
    """
    server_time = datetime.now().isoformat()
    uploaded_count = 0
    
    with get_db() as conn:
        # Upload client transactions
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
        
        # Get transactions to download
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


# Initialize database on startup
@app.on_event("startup")
async def startup_event():
    init_db()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8888)
