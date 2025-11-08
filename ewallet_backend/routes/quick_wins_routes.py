"""
API Routes for Quick Win Features
"""
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from database import get_db
from models import User, Transaction
from models_quick_wins import Favorite, ScheduledPayment, PaymentLink, TransactionTag, SubWallet
from services.quick_wins_services import (
    FavoriteService, ScheduledPaymentService, PaymentLinkService,
    TransactionSearchService, SubWalletService, QRLimitService
)
from utils.security import decode_token

router = APIRouter()


def get_current_user(authorization: str = Header(...), db: Session = Depends(get_db)):
    """Get current user from JWT token"""
    try:
        token = authorization.replace("Bearer ", "")
        payload = decode_token(token)
        username = payload.get("username")
        user = db.query(User).filter(User.username == username).first()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        return user
    except:
        raise HTTPException(status_code=401, detail="Invalid token")


# ==================== FAVORITES ====================

class AddFavoriteRequest(BaseModel):
    recipient_type: str  # username, phone, email, bank
    recipient_identifier: str
    nickname: Optional[str] = None

@router.post("/favorites/add")
async def add_favorite(
    request: AddFavoriteRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add recipient to favorites"""
    favorite = FavoriteService.add_favorite(
        user=current_user,
        recipient_type=request.recipient_type,
        recipient_identifier=request.recipient_identifier,
        nickname=request.nickname,
        db=db
    )
    
    return {
        "message": "Added to favorites",
        "favorite": {
            "id": favorite.id,
            "recipient": favorite.recipient_identifier,
            "nickname": favorite.nickname,
            "type": favorite.recipient_type
        }
    }


@router.delete("/favorites/{favorite_id}")
async def remove_favorite(
    favorite_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Remove from favorites"""
    success = FavoriteService.remove_favorite(current_user, favorite_id, db)
    
    if success:
        return {"message": "Removed from favorites"}
    else:
        raise HTTPException(status_code=404, detail="Favorite not found")


@router.get("/favorites")
async def get_favorites(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's favorite recipients"""
    favorites = FavoriteService.get_favorites(current_user, db)
    
    return {
        "favorites": [
            {
                "id": fav.id,
                "recipient": fav.recipient_identifier,
                "nickname": fav.nickname,
                "type": fav.recipient_type,
                "use_count": fav.use_count,
                "last_used": fav.last_used
            }
            for fav in favorites
        ]
    }


# ==================== SCHEDULED PAYMENTS ====================

class CreateScheduledPaymentRequest(BaseModel):
    recipient_type: str
    recipient_identifier: str
    amount: float
    scheduled_date: str  # ISO format
    schedule_type: str = "once"  # once, daily, weekly, monthly, biweekly
    note: Optional[str] = None

@router.post("/scheduled-payments/create")
async def create_scheduled_payment(
    request: CreateScheduledPaymentRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Schedule a payment"""
    scheduled_date = datetime.fromisoformat(request.scheduled_date.replace('Z', '+00:00'))
    
    payment = ScheduledPaymentService.create_scheduled_payment(
        user=current_user,
        recipient_type=request.recipient_type,
        recipient_identifier=request.recipient_identifier,
        amount=request.amount,
        scheduled_date=scheduled_date,
        schedule_type=request.schedule_type,
        note=request.note,
        db=db
    )
    
    return {
        "message": "Payment scheduled",
        "payment": {
            "id": payment.id,
            "recipient": payment.recipient_identifier,
            "amount": payment.amount,
            "scheduled_date": payment.scheduled_date,
            "is_recurring": payment.is_recurring
        }
    }


@router.get("/scheduled-payments")
async def get_scheduled_payments(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's scheduled payments"""
    payments = db.query(ScheduledPayment).filter(
        ScheduledPayment.user_id == current_user.id,
        ScheduledPayment.status == "pending"
    ).order_by(ScheduledPayment.next_execution).all()
    
    return {
        "payments": [
            {
                "id": p.id,
                "recipient": p.recipient_identifier,
                "amount": p.amount,
                "next_execution": p.next_execution,
                "schedule_type": p.schedule_type,
                "is_recurring": p.is_recurring,
                "note": p.note
            }
            for p in payments
        ]
    }


@router.delete("/scheduled-payments/{payment_id}")
async def cancel_scheduled_payment(
    payment_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cancel a scheduled payment"""
    success = ScheduledPaymentService.cancel_payment(current_user, payment_id, db)
    
    if success:
        return {"message": "Payment cancelled"}
    else:
        raise HTTPException(status_code=404, detail="Payment not found")


# ==================== PAYMENT LINKS ====================

class CreatePaymentLinkRequest(BaseModel):
    amount: Optional[float] = None  # None = variable amount
    description: Optional[str] = None
    max_uses: Optional[int] = None
    expires_in_hours: Optional[int] = None

@router.post("/payment-links/create")
async def create_payment_link(
    request: CreatePaymentLinkRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a shareable payment link"""
    link = PaymentLinkService.create_payment_link(
        user=current_user,
        amount=request.amount,
        description=request.description,
        max_uses=request.max_uses,
        expires_in_hours=request.expires_in_hours,
        db=db
    )
    
    return {
        "message": "Payment link created",
        "link": {
            "code": link.link_code,
            "url": f"blackwallet://pay/{link.link_code}",
            "web_url": f"https://blackwallet.app/pay/{link.link_code}",
            "amount": link.amount,
            "description": link.description,
            "expires_at": link.expires_at
        }
    }


@router.get("/payment-links/{link_code}")
async def get_payment_link(
    link_code: str,
    db: Session = Depends(get_db)
):
    """Get payment link details"""
    link = PaymentLinkService.get_link(link_code, db)
    
    if not link:
        raise HTTPException(status_code=404, detail="Payment link not found")
    
    validation = PaymentLinkService.validate_link(link)
    
    recipient = db.query(User).filter(User.id == link.user_id).first()
    
    return {
        "valid": validation["valid"],
        "error": validation.get("error"),
        "link": {
            "amount": link.amount,
            "description": link.description,
            "recipient": recipient.username,
            "uses": f"{link.current_uses}/{link.max_uses}" if link.max_uses else "unlimited"
        }
    }


class PayViLinkRequest(BaseModel):
    link_code: str
    amount: Optional[float] = None  # Required if link has no fixed amount

@router.post("/payment-links/pay")
async def pay_via_link(
    request: PayViLinkRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Pay using a payment link"""
    link = PaymentLinkService.get_link(request.link_code, db)
    
    if not link:
        raise HTTPException(status_code=404, detail="Payment link not found")
    
    result = PaymentLinkService.process_payment(
        link=link,
        payer=current_user,
        amount=request.amount,
        db=db
    )
    
    if result["success"]:
        return {
            "message": "Payment successful",
            "transaction_id": result["transaction_id"],
            "amount": result["amount"]
        }
    else:
        raise HTTPException(status_code=400, detail=result["error"])


@router.get("/payment-links")
async def get_my_payment_links(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's payment links"""
    links = db.query(PaymentLink).filter(
        PaymentLink.user_id == current_user.id
    ).order_by(PaymentLink.created_at.desc()).all()
    
    return {
        "links": [
            {
                "code": link.link_code,
                "amount": link.amount,
                "description": link.description,
                "uses": f"{link.current_uses}/{link.max_uses}" if link.max_uses else "unlimited",
                "total_collected": link.total_collected,
                "is_active": link.is_active,
                "expires_at": link.expires_at
            }
            for link in links
        ]
    }


# ==================== TRANSACTION SEARCH ====================

class SearchTransactionsRequest(BaseModel):
    query: Optional[str] = None
    min_amount: Optional[float] = None
    max_amount: Optional[float] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    transaction_type: Optional[str] = None
    tags: Optional[List[str]] = None

@router.post("/transactions/search")
async def search_transactions(
    request: SearchTransactionsRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Search and filter transactions"""
    start_date = None
    end_date = None
    
    if request.start_date:
        start_date = datetime.fromisoformat(request.start_date.replace('Z', '+00:00'))
    if request.end_date:
        end_date = datetime.fromisoformat(request.end_date.replace('Z', '+00:00'))
    
    transactions = TransactionSearchService.search_transactions(
        user=current_user,
        query=request.query,
        min_amount=request.min_amount,
        max_amount=request.max_amount,
        start_date=start_date,
        end_date=end_date,
        transaction_type=request.transaction_type,
        tags=request.tags,
        db=db
    )
    
    return {
        "count": len(transactions),
        "transactions": [
            {
                "id": txn.id,
                "sender": txn.sender,
                "receiver": txn.receiver,
                "amount": txn.amount,
                "type": txn.transaction_type,
                "status": txn.status,
                "created_at": txn.created_at
            }
            for txn in transactions
        ]
    }


# ==================== TRANSACTION TAGS ====================

class AddTagRequest(BaseModel):
    transaction_id: int
    tag: str

@router.post("/transactions/tags/add")
async def add_transaction_tag(
    request: AddTagRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add tag to transaction"""
    # Verify transaction belongs to user
    transaction = db.query(Transaction).filter(Transaction.id == request.transaction_id).first()
    
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    if transaction.sender != current_user.username and transaction.receiver != current_user.username:
        raise HTTPException(status_code=403, detail="Not your transaction")
    
    # Check if tag already exists
    existing = db.query(TransactionTag).filter(
        TransactionTag.transaction_id == request.transaction_id,
        TransactionTag.tag == request.tag
    ).first()
    
    if existing:
        return {"message": "Tag already exists"}
    
    tag = TransactionTag(
        transaction_id=request.transaction_id,
        tag=request.tag
    )
    
    db.add(tag)
    db.commit()
    
    return {"message": "Tag added"}


@router.get("/transactions/{transaction_id}/tags")
async def get_transaction_tags(
    transaction_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get tags for a transaction"""
    tags = db.query(TransactionTag).filter(
        TransactionTag.transaction_id == transaction_id
    ).all()
    
    return {
        "tags": [tag.tag for tag in tags]
    }


# ==================== SUB-WALLETS ====================

class CreateSubWalletRequest(BaseModel):
    name: str
    wallet_type: str  # personal, business, savings
    icon: str = "wallet"
    color: str = "#DC143C"

@router.post("/wallets/create")
async def create_sub_wallet(
    request: CreateSubWalletRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new sub-wallet"""
    wallet = SubWalletService.create_wallet(
        user=current_user,
        name=request.name,
        wallet_type=request.wallet_type,
        icon=request.icon,
        color=request.color,
        db=db
    )
    
    return {
        "message": "Wallet created",
        "wallet": {
            "id": wallet.id,
            "name": wallet.name,
            "type": wallet.wallet_type,
            "balance": wallet.balance,
            "icon": wallet.icon,
            "color": wallet.color
        }
    }


@router.get("/wallets")
async def get_sub_wallets(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's sub-wallets"""
    wallets = SubWalletService.get_wallets(current_user, db)
    
    return {
        "wallets": [
            {
                "id": w.id,
                "name": w.name,
                "type": w.wallet_type,
                "balance": w.balance,
                "icon": w.icon,
                "color": w.color,
                "is_default": w.is_default
            }
            for w in wallets
        ]
    }


class TransferBetweenWalletsRequest(BaseModel):
    from_wallet_id: int
    to_wallet_id: int
    amount: float

@router.post("/wallets/transfer")
async def transfer_between_wallets(
    request: TransferBetweenWalletsRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Transfer money between user's wallets"""
    result = SubWalletService.transfer_between_wallets(
        user=current_user,
        from_wallet_id=request.from_wallet_id,
        to_wallet_id=request.to_wallet_id,
        amount=request.amount,
        db=db
    )
    
    if result["success"]:
        return {
            "message": "Transfer successful",
            "from_balance": result["from_balance"],
            "to_balance": result["to_balance"]
        }
    else:
        raise HTTPException(status_code=400, detail=result["error"])


# ==================== QR PAYMENT LIMITS ====================

@router.get("/qr-limits")
async def get_qr_limits(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's QR payment limits"""
    limits = QRLimitService.get_or_create_limits(current_user, db)
    
    return {
        "max_per_transaction": limits.max_per_transaction,
        "daily_limit": limits.daily_limit,
        "require_auth_above": limits.require_auth_above,
        "today_total": limits.today_total,
        "remaining_today": limits.daily_limit - limits.today_total
    }


class UpdateQRLimitsRequest(BaseModel):
    max_per_transaction: Optional[float] = None
    daily_limit: Optional[float] = None
    require_auth_above: Optional[float] = None

@router.post("/qr-limits/update")
async def update_qr_limits(
    request: UpdateQRLimitsRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update QR payment limits"""
    limits = QRLimitService.get_or_create_limits(current_user, db)
    
    if request.max_per_transaction is not None:
        limits.max_per_transaction = request.max_per_transaction
    if request.daily_limit is not None:
        limits.daily_limit = request.daily_limit
    if request.require_auth_above is not None:
        limits.require_auth_above = request.require_auth_above
    
    db.commit()
    
    return {"message": "Limits updated"}


class CheckQRLimitRequest(BaseModel):
    amount: float

@router.post("/qr-limits/check")
async def check_qr_limit(
    request: CheckQRLimitRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Check if QR payment is within limits"""
    result = QRLimitService.check_limit(current_user, request.amount, db)
    return result
