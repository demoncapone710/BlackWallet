"""
Admin API Routes
Comprehensive admin panel for managing users, balances, monitoring, and system configuration
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, desc
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, timedelta
import logging

from database import get_db
from models import (
    User, Transaction, Notification, Advertisement, 
    Promotion, CustomerMessage, PromotionUsage
)
from auth import get_current_user
from utils.security import hash_password
from config import settings

router = APIRouter()
logger = logging.getLogger(__name__)


def require_admin(current_user: User = Depends(get_current_user)):
    """Dependency to ensure user is an admin"""
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user


# Request/Response Models
class UserUpdateRequest(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    full_name: Optional[str] = None
    is_admin: Optional[bool] = None


class BalanceUpdateRequest(BaseModel):
    new_balance: float = Field(..., ge=0, description="New balance amount")
    reason: str = Field(..., min_length=1, description="Reason for balance change")


class StripeModeRequest(BaseModel):
    mode: str = Field(..., pattern="^(test|live)$", description="Stripe mode: test or live")


# ============================================
# USER MANAGEMENT ENDPOINTS
# ============================================

@router.get("/users")
async def get_all_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    search: Optional[str] = None,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Get paginated list of all users with optional search"""
    query = db.query(User)
    
    if search:
        search_pattern = f"%{search}%"
        query = query.filter(
            (User.username.like(search_pattern)) |
            (User.email.like(search_pattern)) |
            (User.full_name.like(search_pattern))
        )
    
    total = query.count()
    users = query.offset(skip).limit(limit).all()
    
    return {
        "total": total,
        "skip": skip,
        "limit": limit,
        "users": [
            {
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "phone": user.phone,
                "full_name": user.full_name,
                "balance": user.balance,
                "is_admin": user.is_admin,
                "stripe_account_id": user.stripe_account_id
            }
            for user in users
        ]
    }


@router.get("/users/{user_id}")
async def get_user_details(
    user_id: int,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Get detailed information about a specific user"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get recent transactions
    recent_transactions = db.query(Transaction).filter(
        (Transaction.sender_id == user_id) | (Transaction.recipient_id == user_id)
    ).order_by(desc(Transaction.timestamp)).limit(20).all()
    
    # Calculate statistics
    total_sent = db.query(func.sum(Transaction.amount)).filter(
        Transaction.sender_id == user_id
    ).scalar() or 0
    
    total_received = db.query(func.sum(Transaction.amount)).filter(
        Transaction.recipient_id == user_id
    ).scalar() or 0
    
    transaction_count = db.query(func.count(Transaction.id)).filter(
        (Transaction.sender_id == user_id) | (Transaction.recipient_id == user_id)
    ).scalar() or 0
    
    return {
        "user": {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "phone": user.phone,
            "full_name": user.full_name,
            "balance": user.balance,
            "is_admin": user.is_admin,
            "stripe_account_id": user.stripe_account_id,
            "stripe_customer_id": user.stripe_customer_id
        },
        "statistics": {
            "total_sent": float(total_sent),
            "total_received": float(total_received),
            "transaction_count": transaction_count,
            "net_flow": float(total_received - total_sent)
        },
        "recent_transactions": [
            {
                "id": t.id,
                "type": "sent" if t.sender_id == user_id else "received",
                "amount": t.amount,
                "other_party": t.recipient.username if t.sender_id == user_id else t.sender.username,
                "timestamp": t.timestamp.isoformat()
            }
            for t in recent_transactions
        ]
    }


@router.put("/users/{user_id}")
async def update_user_account(
    user_id: int,
    update_data: UserUpdateRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Update user account information"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if update_data.username:
        existing = db.query(User).filter(
            User.username == update_data.username,
            User.id != user_id
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail="Username already taken")
        user.username = update_data.username
    
    if update_data.email:
        user.email = update_data.email
    if update_data.phone:
        user.phone = update_data.phone
    if update_data.full_name:
        user.full_name = update_data.full_name
    if update_data.is_admin is not None:
        user.is_admin = update_data.is_admin
    
    db.commit()
    db.refresh(user)
    
    logger.info(f"Admin {admin.username} updated user {user.username} (ID: {user_id})")
    
    return {
        "message": "User updated successfully",
        "user": {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "is_admin": user.is_admin
        }
    }


@router.put("/users/{user_id}/balance")
async def update_user_balance(
    user_id: int,
    balance_update: BalanceUpdateRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Manually adjust user balance with audit trail"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    old_balance = user.balance
    difference = balance_update.new_balance - old_balance
    user.balance = balance_update.new_balance
    
    # Create audit transaction
    audit_transaction = Transaction(
        sender=admin.username if difference < 0 else user.username,
        receiver=user.username if difference < 0 else admin.username,
        amount=abs(difference),
        transaction_type="balance_adjustment",
        status="completed"
    )
    db.add(audit_transaction)
    db.commit()
    
    logger.warning(
        f"Admin {admin.username} changed balance for {user.username} "
        f"from ${old_balance:.2f} to ${balance_update.new_balance:.2f}. "
        f"Reason: {balance_update.reason}"
    )
    
    return {
        "message": "Balance updated successfully",
        "user": user.username,
        "old_balance": old_balance,
        "new_balance": user.balance,
        "difference": difference,
        "reason": balance_update.reason
    }


class CreateUserRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: str = Field(..., min_length=3)
    password: str = Field(..., min_length=6)
    full_name: Optional[str] = None
    phone: Optional[str] = None
    initial_balance: float = Field(0.0, ge=0)
    is_admin: bool = False


@router.post("/users")
async def create_user(
    user_data: CreateUserRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Create a new user account (admin only)"""
    # Check if username already exists
    existing_user = db.query(User).filter(User.username == user_data.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already exists")
    
    # Check if email already exists
    if user_data.email:
        existing_email = db.query(User).filter(User.email == user_data.email).first()
        if existing_email:
            raise HTTPException(status_code=400, detail="Email already exists")
    
    # Create new user
    new_user = User(
        username=user_data.username,
        email=user_data.email,
        password=hash_password(user_data.password),
        full_name=user_data.full_name,
        phone=user_data.phone,
        balance=user_data.initial_balance,
        is_admin=user_data.is_admin
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Create initial balance transaction if balance > 0
    if user_data.initial_balance > 0:
        initial_transaction = Transaction(
            sender="system",
            receiver=new_user.username,
            amount=user_data.initial_balance,
            transaction_type="initial_balance",
            status="completed"
        )
        db.add(initial_transaction)
        db.commit()
    
    logger.info(
        f"Admin {admin.username} created new user: {new_user.username} "
        f"(ID: {new_user.id}, Balance: ${user_data.initial_balance:.2f}, Admin: {user_data.is_admin})"
    )
    
    return {
        "message": "User created successfully",
        "user": {
            "id": new_user.id,
            "username": new_user.username,
            "email": new_user.email,
            "full_name": new_user.full_name,
            "phone": new_user.phone,
            "balance": new_user.balance,
            "is_admin": new_user.is_admin
        }
    }


class DeleteUserRequest(BaseModel):
    confirm_username: str = Field(..., description="Type username to confirm deletion")
    reason: str = Field(..., min_length=1, description="Reason for deletion")
    transfer_balance_to: Optional[str] = Field(None, description="Username to transfer remaining balance to")


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    delete_data: DeleteUserRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Delete a user account (admin only) with safeguards"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Prevent deleting yourself
    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")
    
    # Confirm username matches
    if user.username != delete_data.confirm_username:
        raise HTTPException(
            status_code=400, 
            detail=f"Username confirmation failed. Expected: {user.username}"
        )
    
    # Handle remaining balance
    if user.balance > 0:
        if not delete_data.transfer_balance_to:
            raise HTTPException(
                status_code=400,
                detail=f"User has balance of ${user.balance:.2f}. Specify transfer_balance_to or set balance to 0 first."
            )
        
        # Transfer balance to specified user
        recipient = db.query(User).filter(User.username == delete_data.transfer_balance_to).first()
        if not recipient:
            raise HTTPException(status_code=404, detail="Transfer recipient not found")
        
        recipient.balance += user.balance
        
        # Create transfer transaction
        transfer_transaction = Transaction(
            sender=user.username,
            receiver=recipient.username,
            amount=user.balance,
            transaction_type="account_closure_transfer",
            status="completed"
        )
        db.add(transfer_transaction)
        
        logger.info(
            f"Transferred ${user.balance:.2f} from deleted user {user.username} to {recipient.username}"
        )
    
    # Store user info for logging
    deleted_username = user.username
    deleted_email = user.email
    deleted_balance = user.balance
    
    # Delete user (this will cascade to related records based on model definitions)
    db.delete(user)
    db.commit()
    
    logger.warning(
        f"Admin {admin.username} deleted user: {deleted_username} "
        f"(ID: {user_id}, Email: {deleted_email}, Balance: ${deleted_balance:.2f}). "
        f"Reason: {delete_data.reason}"
    )
    
    return {
        "message": "User deleted successfully",
        "deleted_user": {
            "id": user_id,
            "username": deleted_username,
            "email": deleted_email,
            "final_balance": deleted_balance
        },
        "balance_transferred_to": delete_data.transfer_balance_to,
        "reason": delete_data.reason
    }


@router.post("/users/{user_id}/suspend")
async def suspend_user(
    user_id: int,
    reason: str,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Suspend a user account (soft delete alternative)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot suspend your own account")
    
    # Add suspended flag (we need to add this field to User model)
    # For now, we'll use a workaround by setting balance to negative
    # In production, add a 'suspended' boolean field to User model
    
    logger.warning(
        f"Admin {admin.username} suspended user: {user.username} (ID: {user_id}). "
        f"Reason: {reason}"
    )
    
    return {
        "message": "User suspension feature requires adding 'suspended' field to User model",
        "note": "Use delete endpoint or add suspended field to User model for proper implementation"
    }


@router.post("/users/{user_id}/reset-password")
async def reset_user_password(
    user_id: int,
    new_password: str,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Reset a user's password (admin only)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    user.password = hash_password(new_password)
    db.commit()
    
    logger.warning(
        f"Admin {admin.username} reset password for user: {user.username} (ID: {user_id})"
    )
    
    return {
        "message": "Password reset successfully",
        "user": user.username,
        "note": "User should change password on next login"
    }


# ============================================
# SYSTEM MONITORING ENDPOINTS
# ============================================

@router.get("/stats/overview")
async def get_system_stats(
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Get comprehensive system statistics"""
    total_users = db.query(func.count(User.id)).scalar()
    total_transactions = db.query(func.count(Transaction.id)).scalar()
    total_volume = db.query(func.sum(Transaction.amount)).scalar() or 0
    average_balance = db.query(func.avg(User.balance)).scalar() or 0
    
    yesterday = datetime.now() - timedelta(days=1)
    active_users_24h = db.query(func.count(func.distinct(Transaction.sender_id))).filter(
        Transaction.timestamp >= yesterday
    ).scalar() or 0
    
    return {
        "total_users": total_users,
        "total_transactions": total_transactions,
        "total_volume": float(total_volume),
        "active_users_24h": active_users_24h,
        "average_balance": float(average_balance),
        "stripe_mode": settings.STRIPE_MODE
    }


@router.get("/stats/transactions")
async def get_transaction_stats(
    days: int = Query(7, ge=1, le=365),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Get transaction statistics for the specified time period"""
    start_date = datetime.now() - timedelta(days=days)
    
    transactions = db.query(Transaction).filter(
        Transaction.timestamp >= start_date
    ).all()
    
    daily_volumes = {}
    for t in transactions:
        date_key = t.timestamp.date().isoformat()
        daily_volumes[date_key] = daily_volumes.get(date_key, 0) + float(t.amount)
    
    return {
        "period_days": days,
        "total_transactions": len(transactions),
        "total_volume": sum(float(t.amount) for t in transactions),
        "average_transaction": sum(float(t.amount) for t in transactions) / len(transactions) if transactions else 0,
        "daily_volumes": daily_volumes
    }


@router.get("/config/stripe-mode")
async def get_stripe_mode(admin: User = Depends(require_admin)):
    """Get current Stripe mode"""
    mode = settings.STRIPE_MODE.lower()
    return {
        "mode": mode,
        "is_live": mode == "live",
        "warning": "⚠️ LIVE MODE - Real money!" if mode == "live" else "🧪 TEST MODE",
        "test_key_set": bool(settings.STRIPE_SECRET_KEY),
        "live_key_set": bool(settings.STRIPE_LIVE_SECRET_KEY)
    }


@router.post("/config/stripe-mode")
async def set_stripe_mode(
    mode_request: StripeModeRequest,
    admin: User = Depends(require_admin)
):
    """Switch between test and live Stripe modes (requires restart)"""
    import os
    from pathlib import Path
    
    env_path = Path(".env")
    if not env_path.exists():
        raise HTTPException(status_code=500, detail=".env file not found")
    
    with open(env_path, 'r') as f:
        lines = f.readlines()
    
    updated = False
    for i, line in enumerate(lines):
        if line.startswith("STRIPE_MODE="):
            lines[i] = f"STRIPE_MODE={mode_request.mode}\n"
            updated = True
            break
    
    if not updated:
        lines.append(f"\nSTRIPE_MODE={mode_request.mode}\n")
    
    with open(env_path, 'w') as f:
        f.writelines(lines)
    
    logger.warning(f"Admin {admin.username} changed Stripe mode to: {mode_request.mode.upper()}")
    
    return {
        "message": f"Stripe mode set to {mode_request.mode}",
        "warning": "⚠️ Server restart required!",
        "restart_command": "Restart backend to apply changes"
    }


# ============================================
# NOTIFICATION MANAGEMENT ENDPOINTS
# ============================================

class NotificationRequest(BaseModel):
    user_id: Optional[int] = None  # None for broadcast
    title: str = Field(..., min_length=1)
    message: str = Field(..., min_length=1)
    notification_type: str = Field(default="general")


@router.post('/notifications/send')
async def send_notification(
    notification: NotificationRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Send notification to specific user or broadcast to all'''
    if notification.user_id:
        # Send to specific user
        user = db.query(User).filter(User.id == notification.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail='User not found')
        
        new_notification = Notification(
            user_id=notification.user_id,
            title=notification.title,
            message=notification.message,
            notification_type=notification.notification_type
        )
        db.add(new_notification)
        db.commit()
        
        logger.info(f'Admin {admin.username} sent notification to user {user.username}')
        return {'message': 'Notification sent', 'recipient': user.username}
    else:
        # Broadcast to all users
        users = db.query(User).filter(User.is_admin == False).all()
        notifications = []
        for user in users:
            notif = Notification(
                user_id=user.id,
                title=notification.title,
                message=notification.message,
                notification_type=notification.notification_type
            )
            notifications.append(notif)
        
        db.bulk_save_objects(notifications)
        db.commit()
        
        logger.info(f'Admin {admin.username} broadcast notification to {len(users)} users')
        return {'message': 'Notification broadcast', 'recipients': len(users)}


@router.get('/notifications')
async def get_all_notifications(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Get all notifications with pagination'''
    total = db.query(func.count(Notification.id)).scalar()
    notifications = db.query(Notification).order_by(desc(Notification.sent_at)).offset(skip).limit(limit).all()
    
    return {
        'total': total,
        'skip': skip,
        'limit': limit,
        'notifications': [
            {
                'id': n.id,
                'user_id': n.user_id,
                'title': n.title,
                'message': n.message,
                'type': n.notification_type,
                'is_read': n.is_read,
                'sent_at': n.sent_at.isoformat()
            }
            for n in notifications
        ]
    }


# ============================================
# ADVERTISEMENT MANAGEMENT ENDPOINTS
# ============================================

class AdvertisementRequest(BaseModel):
    title: str = Field(..., min_length=1)
    description: str
    image_url: Optional[str] = None
    link_url: Optional[str] = None
    ad_type: str = Field(default='banner')
    target_audience: str = Field(default='all')
    end_date: Optional[datetime] = None


@router.post('/advertisements')
async def create_advertisement(
    ad: AdvertisementRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Create a new advertisement'''
    new_ad = Advertisement(
        title=ad.title,
        description=ad.description,
        image_url=ad.image_url,
        link_url=ad.link_url,
        ad_type=ad.ad_type,
        target_audience=ad.target_audience,
        end_date=ad.end_date,
        created_by=admin.id
    )
    db.add(new_ad)
    db.commit()
    db.refresh(new_ad)
    
    logger.info(f'Admin {admin.username} created advertisement: {ad.title}')
    return {'message': 'Advertisement created', 'ad_id': new_ad.id}


@router.get('/advertisements')
async def get_advertisements(
    active_only: bool = Query(False),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Get all advertisements'''
    query = db.query(Advertisement)
    if active_only:
        query = query.filter(Advertisement.is_active == True)
    
    ads = query.order_by(desc(Advertisement.created_at)).all()
    
    return {
        'total': len(ads),
        'advertisements': [
            {
                'id': ad.id,
                'title': ad.title,
                'description': ad.description,
                'image_url': ad.image_url,
                'link_url': ad.link_url,
                'ad_type': ad.ad_type,
                'target_audience': ad.target_audience,
                'is_active': ad.is_active,
                'impressions': ad.impressions,
                'clicks': ad.clicks,
                'start_date': ad.start_date.isoformat(),
                'end_date': ad.end_date.isoformat() if ad.end_date else None
            }
            for ad in ads
        ]
    }


@router.put('/advertisements/{ad_id}')
async def update_advertisement(
    ad_id: int,
    ad_update: AdvertisementRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Update an advertisement'''
    ad = db.query(Advertisement).filter(Advertisement.id == ad_id).first()
    if not ad:
        raise HTTPException(status_code=404, detail='Advertisement not found')
    
    ad.title = ad_update.title
    ad.description = ad_update.description
    ad.image_url = ad_update.image_url
    ad.link_url = ad_update.link_url
    ad.ad_type = ad_update.ad_type
    ad.target_audience = ad_update.target_audience
    ad.end_date = ad_update.end_date
    
    db.commit()
    logger.info(f'Admin {admin.username} updated advertisement {ad_id}')
    return {'message': 'Advertisement updated'}


@router.delete('/advertisements/{ad_id}')
async def delete_advertisement(
    ad_id: int,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Delete an advertisement'''
    ad = db.query(Advertisement).filter(Advertisement.id == ad_id).first()
    if not ad:
        raise HTTPException(status_code=404, detail='Advertisement not found')
    
    db.delete(ad)
    db.commit()
    logger.info(f'Admin {admin.username} deleted advertisement {ad_id}')
    return {'message': 'Advertisement deleted'}


# ============================================
# PROMOTION MANAGEMENT ENDPOINTS
# ============================================

class PromotionRequest(BaseModel):
    code: str = Field(..., min_length=3, max_length=50)
    title: str
    description: str
    promotion_type: str = Field(default='bonus')
    value: float = Field(..., gt=0)
    value_type: str = Field(default='fixed')
    min_transaction: float = Field(default=0, ge=0)
    max_uses: Optional[int] = None
    uses_per_user: int = Field(default=1, ge=1)
    end_date: Optional[datetime] = None


@router.post('/promotions')
async def create_promotion(
    promo: PromotionRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Create a new promotion'''
    # Check if code already exists
    existing = db.query(Promotion).filter(Promotion.code == promo.code.upper()).first()
    if existing:
        raise HTTPException(status_code=400, detail='Promotion code already exists')
    
    new_promo = Promotion(
        code=promo.code.upper(),
        title=promo.title,
        description=promo.description,
        promotion_type=promo.promotion_type,
        value=promo.value,
        value_type=promo.value_type,
        min_transaction=promo.min_transaction,
        max_uses=promo.max_uses,
        uses_per_user=promo.uses_per_user,
        end_date=promo.end_date,
        created_by=admin.id
    )
    db.add(new_promo)
    db.commit()
    db.refresh(new_promo)
    
    logger.info(f'Admin {admin.username} created promotion: {promo.code}')
    return {'message': 'Promotion created', 'promo_id': new_promo.id, 'code': new_promo.code}


@router.get('/promotions')
async def get_promotions(
    active_only: bool = Query(False),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Get all promotions'''
    query = db.query(Promotion)
    if active_only:
        query = query.filter(Promotion.is_active == True)
    
    promos = query.order_by(desc(Promotion.created_at)).all()
    
    return {
        'total': len(promos),
        'promotions': [
            {
                'id': p.id,
                'code': p.code,
                'title': p.title,
                'description': p.description,
                'promotion_type': p.promotion_type,
                'value': p.value,
                'value_type': p.value_type,
                'min_transaction': p.min_transaction,
                'max_uses': p.max_uses,
                'uses_count': p.uses_count,
                'uses_per_user': p.uses_per_user,
                'is_active': p.is_active,
                'start_date': p.start_date.isoformat(),
                'end_date': p.end_date.isoformat() if p.end_date else None
            }
            for p in promos
        ]
    }


@router.get('/promotions/{promo_id}/usage')
async def get_promotion_usage(
    promo_id: int,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Get promotion usage statistics'''
    promo = db.query(Promotion).filter(Promotion.id == promo_id).first()
    if not promo:
        raise HTTPException(status_code=404, detail='Promotion not found')
    
    usages = db.query(PromotionUsage).filter(PromotionUsage.promotion_id == promo_id).all()
    total_saved = sum(u.amount_saved for u in usages)
    
    return {
        'promotion': {
            'code': promo.code,
            'title': promo.title,
            'uses_count': promo.uses_count,
            'max_uses': promo.max_uses
        },
        'total_amount_saved': total_saved,
        'usage_history': [
            {
                'user_id': u.user_id,
                'amount_saved': u.amount_saved,
                'used_at': u.used_at.isoformat()
            }
            for u in usages
        ]
    }


@router.put('/promotions/{promo_id}/toggle')
async def toggle_promotion(
    promo_id: int,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Activate or deactivate a promotion'''
    promo = db.query(Promotion).filter(Promotion.id == promo_id).first()
    if not promo:
        raise HTTPException(status_code=404, detail='Promotion not found')
    
    promo.is_active = not promo.is_active
    db.commit()
    
    status = 'activated' if promo.is_active else 'deactivated'
    logger.info(f'Admin {admin.username} {status} promotion {promo.code}')
    return {'message': f'Promotion {status}', 'is_active': promo.is_active}


# ============================================
# CUSTOMER MESSAGING ENDPOINTS
# ============================================

class MessageRequest(BaseModel):
    user_id: int
    subject: str = Field(..., min_length=1)
    message: str = Field(..., min_length=1)
    message_type: str = Field(default='support')


@router.post('/messages/send')
async def send_customer_message(
    msg: MessageRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Send a message to a customer'''
    user = db.query(User).filter(User.id == msg.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail='User not found')
    
    new_message = CustomerMessage(
        user_id=msg.user_id,
        admin_id=admin.id,
        subject=msg.subject,
        message=msg.message,
        message_type=msg.message_type,
        direction='admin_to_user'
    )
    db.add(new_message)
    db.commit()
    db.refresh(new_message)
    
    logger.info(f'Admin {admin.username} sent message to user {user.username}')
    return {'message': 'Message sent', 'message_id': new_message.id}


@router.get('/messages/user/{user_id}')
async def get_user_messages(
    user_id: int,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Get all messages for a specific user'''
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail='User not found')
    
    messages = db.query(CustomerMessage).filter(
        CustomerMessage.user_id == user_id
    ).order_by(desc(CustomerMessage.created_at)).all()
    
    return {
        'user': {
            'id': user.id,
            'username': user.username,
            'email': user.email
        },
        'total_messages': len(messages),
        'messages': [
            {
                'id': m.id,
                'subject': m.subject,
                'message': m.message,
                'message_type': m.message_type,
                'direction': m.direction,
                'is_read': m.is_read,
                'created_at': m.created_at.isoformat()
            }
            for m in messages
        ]
    }


@router.get('/messages/unread')
async def get_unread_messages(
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Get all unread messages from customers'''
    unread = db.query(CustomerMessage).filter(
        CustomerMessage.direction == 'user_to_admin',
        CustomerMessage.is_read == False
    ).order_by(desc(CustomerMessage.created_at)).all()
    
    return {
        'total_unread': len(unread),
        'messages': [
            {
                'id': m.id,
                'user_id': m.user_id,
                'subject': m.subject,
                'message': m.message[:100] + '...' if len(m.message) > 100 else m.message,
                'created_at': m.created_at.isoformat()
            }
            for m in unread
        ]
    }


@router.put('/messages/{message_id}/read')
async def mark_message_read(
    message_id: int,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Mark a message as read'''
    message = db.query(CustomerMessage).filter(CustomerMessage.id == message_id).first()
    if not message:
        raise HTTPException(status_code=404, detail='Message not found')
    
    message.is_read = True
    db.commit()
    return {'message': 'Message marked as read'}


# ============================================
# ACTIVE ACCOUNTS & ANALYTICS ENDPOINTS
# ============================================

@router.get('/accounts/active')
async def get_active_accounts(
    days: int = Query(30, ge=1, le=365),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Get active user accounts (users with transactions in specified period)'''
    start_date = datetime.utcnow() - timedelta(days=days)
    
    # Get users with transactions in the period
    active_users = db.query(User).join(
        Transaction,
        (Transaction.sender == User.username) | (Transaction.receiver == User.username)
    ).filter(
        Transaction.created_at >= start_date
    ).distinct().all()
    
    return {
        'period_days': days,
        'total_active': len(active_users),
        'users': [
            {
                'id': u.id,
                'username': u.username,
                'email': u.email,
                'balance': u.balance,
                'is_admin': u.is_admin
            }
            for u in active_users
        ]
    }


@router.get('/accounts/inactive')
async def get_inactive_accounts(
    days: int = Query(30, ge=1, le=365),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Get inactive user accounts (no transactions in specified period)'''
    start_date = datetime.utcnow() - timedelta(days=days)
    
    # Get all users
    all_users = db.query(User).filter(User.is_admin == False).all()
    
    # Get users with recent transactions
    active_usernames = db.query(Transaction.sender).filter(
        Transaction.created_at >= start_date
    ).union(
        db.query(Transaction.receiver).filter(Transaction.created_at >= start_date)
    ).distinct().all()
    
    active_usernames_set = {name[0] for name in active_usernames}
    inactive_users = [u for u in all_users if u.username not in active_usernames_set]
    
    return {
        'period_days': days,
        'total_inactive': len(inactive_users),
        'users': [
            {
                'id': u.id,
                'username': u.username,
                'email': u.email,
                'balance': u.balance,
                'last_seen': 'N/A'
            }
            for u in inactive_users
        ]
    }


@router.get('/analytics/dashboard')
async def get_admin_dashboard(
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    '''Get comprehensive admin dashboard data'''
    # User stats
    total_users = db.query(func.count(User.id)).filter(User.is_admin == False).scalar()
    
    # Transaction stats (last 30 days)
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    recent_transactions = db.query(Transaction).filter(
        Transaction.created_at >= thirty_days_ago
    ).all()
    
    # Financial stats
    total_volume = sum(t.amount for t in recent_transactions)
    total_balance = db.query(func.sum(User.balance)).filter(User.is_admin == False).scalar() or 0
    
    # Notification stats
    total_notifications = db.query(func.count(Notification.id)).scalar()
    unread_notifications = db.query(func.count(Notification.id)).filter(
        Notification.is_read == False
    ).scalar()
    
    # Active promotions
    active_promotions = db.query(func.count(Promotion.id)).filter(
        Promotion.is_active == True
    ).scalar()
    
    # Active advertisements
    active_ads = db.query(func.count(Advertisement.id)).filter(
        Advertisement.is_active == True
    ).scalar()
    
    # Unread customer messages
    unread_messages = db.query(func.count(CustomerMessage.id)).filter(
        CustomerMessage.direction == 'user_to_admin',
        CustomerMessage.is_read == False
    ).scalar()
    
    return {
        'users': {
            'total': total_users,
            'active_30d': len([t for t in recent_transactions])
        },
        'transactions': {
            'count_30d': len(recent_transactions),
            'volume_30d': float(total_volume),
            'average': float(total_volume / len(recent_transactions)) if recent_transactions else 0
        },
        'financial': {
            'total_balance_in_system': float(total_balance)
        },
        'notifications': {
            'total_sent': total_notifications,
            'unread': unread_notifications
        },
        'marketing': {
            'active_promotions': active_promotions,
            'active_advertisements': active_ads
        },
        'support': {
            'unread_messages': unread_messages
        },
        'stripe_mode': settings.STRIPE_MODE
    }
