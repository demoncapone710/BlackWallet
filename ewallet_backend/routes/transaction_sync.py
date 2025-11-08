"""
Offline Transaction Sync Routes
Handles synchronization of transactions created while offline
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, Dict, List
import logging
from datetime import datetime

from database import get_db
from models import User, Transaction
from auth import get_current_user

router = APIRouter(prefix="/transactions", tags=["Transactions"])
logger = logging.getLogger(__name__)


class OfflineTransactionSync(BaseModel):
    sender: str
    receiver: str
    amount: float
    transaction_type: str
    device_id: str
    queued_at: str
    extra_data: Optional[Dict] = None


@router.post("/sync-offline")
async def sync_offline_transaction(
    transaction: OfflineTransactionSync,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Sync a transaction that was created while offline.
    Validates and processes the queued transaction.
    """
    try:
        # Verify sender is current user
        if transaction.sender != current_user.username:
            raise HTTPException(
                status_code=403,
                detail="Cannot sync transaction for another user"
            )
        
        # Check if transaction already exists (prevent duplicates)
        existing = db.query(Transaction).filter(
            Transaction.sender == transaction.sender,
            Transaction.receiver == transaction.receiver,
            Transaction.amount == transaction.amount,
            Transaction.device_id == transaction.device_id,
            Transaction.created_at >= datetime.fromisoformat(transaction.queued_at)
        ).first()
        
        if existing:
            logger.info(f"Duplicate transaction skipped: {existing.id}")
            return {
                "status": "duplicate",
                "message": "Transaction already exists",
                "transaction_id": existing.id
            }
        
        # Validate sender has sufficient balance
        if current_user.balance < transaction.amount:
            raise HTTPException(
                status_code=400,
                detail=f"Insufficient balance. Available: ${current_user.balance:.2f}"
            )
        
        # Find receiver
        receiver = db.query(User).filter(User.username == transaction.receiver).first()
        if not receiver:
            raise HTTPException(status_code=404, detail="Receiver not found")
        
        # Process transaction
        current_user.balance -= transaction.amount
        receiver.balance += transaction.amount
        
        # Create transaction record
        new_transaction = Transaction(
            sender=transaction.sender,
            receiver=transaction.receiver,
            amount=transaction.amount,
            transaction_type=transaction.transaction_type,
            status="completed",
            is_offline=True,
            device_id=transaction.device_id,
            created_at=datetime.fromisoformat(transaction.queued_at),
            processed_at=datetime.utcnow(),
            extra_data=transaction.extra_data
        )
        
        db.add(new_transaction)
        db.commit()
        db.refresh(new_transaction)
        
        # Update user's last sync time
        current_user.last_sync_at = datetime.utcnow()
        db.commit()
        
        logger.info(
            f"Synced offline transaction: {new_transaction.id} "
            f"from {transaction.sender} to {transaction.receiver} "
            f"amount ${transaction.amount}"
        )
        
        return {
            "status": "success",
            "message": "Transaction synced successfully",
            "transaction_id": new_transaction.id,
            "new_balance": current_user.balance
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to sync offline transaction: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sync-batch")
async def sync_batch_transactions(
    transactions: List[OfflineTransactionSync],
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Sync multiple offline transactions in a batch.
    More efficient than syncing one at a time.
    """
    results = []
    successful = 0
    failed = 0
    
    for trans in transactions:
        try:
            # Verify sender
            if trans.sender != current_user.username:
                results.append({
                    "status": "failed",
                    "transaction": trans.dict(),
                    "error": "Cannot sync transaction for another user"
                })
                failed += 1
                continue
            
            # Check for duplicates
            existing = db.query(Transaction).filter(
                Transaction.sender == trans.sender,
                Transaction.receiver == trans.receiver,
                Transaction.amount == trans.amount,
                Transaction.device_id == trans.device_id
            ).first()
            
            if existing:
                results.append({
                    "status": "duplicate",
                    "transaction": trans.dict(),
                    "transaction_id": existing.id
                })
                successful += 1
                continue
            
            # Validate balance
            if current_user.balance < trans.amount:
                results.append({
                    "status": "failed",
                    "transaction": trans.dict(),
                    "error": f"Insufficient balance for transaction"
                })
                failed += 1
                continue
            
            # Find receiver
            receiver = db.query(User).filter(User.username == trans.receiver).first()
            if not receiver:
                results.append({
                    "status": "failed",
                    "transaction": trans.dict(),
                    "error": "Receiver not found"
                })
                failed += 1
                continue
            
            # Process transaction
            current_user.balance -= trans.amount
            receiver.balance += trans.amount
            
            # Create record
            new_transaction = Transaction(
                sender=trans.sender,
                receiver=trans.receiver,
                amount=trans.amount,
                transaction_type=trans.transaction_type,
                status="completed",
                is_offline=True,
                device_id=trans.device_id,
                created_at=datetime.fromisoformat(trans.queued_at),
                processed_at=datetime.utcnow(),
                extra_data=trans.extra_data
            )
            
            db.add(new_transaction)
            db.commit()
            db.refresh(new_transaction)
            
            results.append({
                "status": "success",
                "transaction": trans.dict(),
                "transaction_id": new_transaction.id
            })
            successful += 1
            
        except Exception as e:
            logger.error(f"Error syncing transaction: {e}")
            db.rollback()
            results.append({
                "status": "failed",
                "transaction": trans.dict(),
                "error": str(e)
            })
            failed += 1
    
    # Update last sync time
    current_user.last_sync_at = datetime.utcnow()
    db.commit()
    
    return {
        "total": len(transactions),
        "successful": successful,
        "failed": failed,
        "results": results,
        "new_balance": current_user.balance
    }


@router.get("/offline-status")
async def get_offline_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get offline mode status and statistics for user.
    """
    # Count offline transactions waiting to be synced
    pending_count = db.query(Transaction).filter(
        Transaction.sender == current_user.username,
        Transaction.is_offline == True,
        Transaction.status == "queued_offline"
    ).count()
    
    return {
        "offline_mode_enabled": current_user.offline_mode_enabled,
        "last_sync_at": current_user.last_sync_at.isoformat() if current_user.last_sync_at else None,
        "pending_transactions": pending_count,
        "balance": current_user.balance
    }
