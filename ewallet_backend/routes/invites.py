"""
Money Invite System Routes
Send money via email/phone with invite tracking
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime, timedelta
import secrets
import re

from database import get_db
from models import User, Transaction, MoneyInvite, Notification
from auth import get_current_user
from logger import get_logger

logger = get_logger(__name__)

router = APIRouter()


# ============= REQUEST/RESPONSE MODELS =============

class SendInviteRequest(BaseModel):
    method: str  # email, phone, username
    contact: str  # Email address, phone number, or username
    amount: float
    message: Optional[str] = None


class InviteResponse(BaseModel):
    id: int
    recipient_method: str
    recipient_contact: str
    amount: float
    status: str
    created_at: datetime
    expires_at: datetime
    delivered: bool
    opened: bool


class AcceptInviteRequest(BaseModel):
    invite_token: str


# ============= HELPER FUNCTIONS =============

def validate_email(email: str) -> bool:
    """Validate email format"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))


def validate_phone(phone: str) -> bool:
    """Validate phone format (US/international)"""
    # Remove common formatting characters
    cleaned = re.sub(r'[\s\-\(\)\+]', '', phone)
    # Check if it's 10-15 digits
    return bool(re.match(r'^\d{10,15}$', cleaned))


def generate_invite_token() -> str:
    """Generate unique secure token for invite"""
    return secrets.token_urlsafe(32)


def send_invite_notification(db: Session, invite: MoneyInvite):
    """Send notification for money invite"""
    try:
        # Check if recipient already has an account
        recipient_user = None
        if invite.recipient_method == "username":
            recipient_user = db.query(User).filter(User.username == invite.recipient_contact).first()
        elif invite.recipient_method == "email":
            recipient_user = db.query(User).filter(User.email == invite.recipient_contact).first()
        elif invite.recipient_method == "phone":
            recipient_user = db.query(User).filter(User.phone == invite.recipient_contact).first()
        
        # Create in-app notification if user exists
        if recipient_user:
            notification = Notification(
                user_id=recipient_user.id,
                title=f"💰 Money Invite from {invite.sender_username}",
                message=f"You've received ${invite.amount:.2f}! Tap to accept.",
                notification_type="transaction",
                extra_data={
                    "invite_id": invite.id,
                    "invite_token": invite.invite_token,
                    "amount": invite.amount,
                    "sender": invite.sender_username
                }
            )
            db.add(notification)
            db.commit()
            
            invite.notification_sent = True
            invite.delivered_at = datetime.utcnow()
            invite.status = "delivered"
            db.commit()
            
            logger.info(f"In-app notification sent for invite {invite.id} to user {recipient_user.id}")
        
        # TODO: Send email notification
        if invite.recipient_method == "email":
            # In production, integrate with email service (SendGrid, AWS SES, etc.)
            invite.email_sent = True
            logger.info(f"Email would be sent to {invite.recipient_contact} for invite {invite.id}")
        
        # TODO: Send SMS notification
        if invite.recipient_method == "phone":
            # In production, integrate with SMS service (Twilio, AWS SNS, etc.)
            invite.sms_sent = True
            logger.info(f"SMS would be sent to {invite.recipient_contact} for invite {invite.id}")
        
        db.commit()
        
    except Exception as e:
        logger.error(f"Error sending invite notification: {e}")


# ============= ENDPOINTS =============

@router.post("/send-invite", response_model=InviteResponse)
async def send_money_invite(
    request: SendInviteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Send money via email, phone, or username
    Creates an invite that recipient must accept within 24 hours
    """
    # Validate amount
    if request.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be greater than 0")
    
    if request.amount > 10000:
        raise HTTPException(status_code=400, detail="Maximum invite amount is $10,000")
    
    # Check sender balance
    if current_user.balance < request.amount:
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient balance. You have ${current_user.balance:.2f}"
        )
    
    # Validate method and contact
    method = request.method.lower()
    contact = request.contact.strip()
    
    if method == "email":
        if not validate_email(contact):
            raise HTTPException(status_code=400, detail="Invalid email address")
    elif method == "phone":
        if not validate_phone(contact):
            raise HTTPException(status_code=400, detail="Invalid phone number")
        # Normalize phone number
        contact = re.sub(r'[\s\-\(\)\+]', '', contact)
    elif method == "username":
        # Check if user exists
        recipient = db.query(User).filter(User.username == contact).first()
        if not recipient:
            raise HTTPException(status_code=404, detail="User not found")
        if recipient.id == current_user.id:
            raise HTTPException(status_code=400, detail="Cannot send invite to yourself")
    else:
        raise HTTPException(status_code=400, detail="Method must be 'email', 'phone', or 'username'")
    
    # Deduct funds from sender (held until accepted or refunded)
    current_user.balance -= request.amount
    
    # Create transaction record (pending)
    transaction = Transaction(
        sender=current_user.username,
        receiver=contact,
        amount=request.amount,
        transaction_type="money_invite",
        status="pending",
        invite_method=method,
        invite_recipient=contact,
        extra_data={
            "message": request.message,
            "method": method
        }
    )
    db.add(transaction)
    db.flush()  # Get transaction ID
    
    # Create money invite
    invite_token = generate_invite_token()
    expires_at = datetime.utcnow() + timedelta(hours=24)
    
    invite = MoneyInvite(
        sender_id=current_user.id,
        sender_username=current_user.username,
        recipient_method=method,
        recipient_contact=contact,
        amount=request.amount,
        message=request.message,
        transaction_id=transaction.id,
        invite_token=invite_token,
        expires_at=expires_at,
        status="pending"
    )
    db.add(invite)
    db.commit()
    db.refresh(invite)
    
    # Link invite to transaction
    transaction.invite_id = invite.id
    db.commit()
    
    # Send notification
    send_invite_notification(db, invite)
    
    logger.info(f"Money invite created: {invite.id} from {current_user.username} to {contact} for ${request.amount}")
    
    return InviteResponse(
        id=invite.id,
        recipient_method=invite.recipient_method,
        recipient_contact=invite.recipient_contact,
        amount=invite.amount,
        status=invite.status,
        created_at=invite.created_at,
        expires_at=invite.expires_at,
        delivered=invite.notification_delivered or invite.email_sent or invite.sms_sent,
        opened=invite.opened_at is not None
    )


@router.get("/invites/sent")
async def get_sent_invites(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all invites sent by current user"""
    invites = db.query(MoneyInvite).filter(
        MoneyInvite.sender_id == current_user.id
    ).order_by(MoneyInvite.created_at.desc()).all()
    
    return {
        "invites": [
            {
                "id": inv.id,
                "recipient_method": inv.recipient_method,
                "recipient_contact": inv.recipient_contact,
                "amount": inv.amount,
                "message": inv.message,
                "status": inv.status,
                "created_at": inv.created_at,
                "expires_at": inv.expires_at,
                "delivered_at": inv.delivered_at,
                "opened_at": inv.opened_at,
                "responded_at": inv.responded_at,
                "refunded_at": inv.refunded_at
            }
            for inv in invites
        ]
    }


@router.get("/invites/received")
async def get_received_invites(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all pending invites for current user"""
    # Check by username, email, and phone
    invites = db.query(MoneyInvite).filter(
        MoneyInvite.status.in_(["pending", "delivered", "opened"]),
        (
            (MoneyInvite.recipient_method == "username") & (MoneyInvite.recipient_contact == current_user.username) |
            (MoneyInvite.recipient_method == "email") & (MoneyInvite.recipient_contact == current_user.email) |
            (MoneyInvite.recipient_method == "phone") & (MoneyInvite.recipient_contact == current_user.phone)
        )
    ).order_by(MoneyInvite.created_at.desc()).all()
    
    return {
        "invites": [
            {
                "id": inv.id,
                "sender_username": inv.sender_username,
                "amount": inv.amount,
                "message": inv.message,
                "status": inv.status,
                "created_at": inv.created_at,
                "expires_at": inv.expires_at,
                "invite_token": inv.invite_token
            }
            for inv in invites
        ]
    }


@router.post("/invites/{invite_id}/open")
async def mark_invite_opened(
    invite_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Mark invite as opened by recipient"""
    invite = db.query(MoneyInvite).filter(MoneyInvite.id == invite_id).first()
    if not invite:
        raise HTTPException(status_code=404, detail="Invite not found")
    
    # Check if current user is recipient
    is_recipient = (
        (invite.recipient_method == "username" and invite.recipient_contact == current_user.username) or
        (invite.recipient_method == "email" and invite.recipient_contact == current_user.email) or
        (invite.recipient_method == "phone" and invite.recipient_contact == current_user.phone)
    )
    
    if not is_recipient:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    # Update opened status
    if not invite.opened_at and invite.status in ["pending", "delivered"]:
        invite.opened_at = datetime.utcnow()
        invite.status = "opened"
        db.commit()
        
        # Notify sender
        sender = db.query(User).filter(User.id == invite.sender_id).first()
        if sender:
            notification = Notification(
                user_id=sender.id,
                title="👀 Invite Opened",
                message=f"{current_user.username} opened your ${invite.amount:.2f} invite",
                notification_type="transaction"
            )
            db.add(notification)
            db.commit()
        
        logger.info(f"Invite {invite_id} opened by {current_user.username}")
    
    return {"message": "Invite marked as opened"}


@router.post("/invites/accept")
async def accept_money_invite(
    request: AcceptInviteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Accept a money invite and receive funds"""
    invite = db.query(MoneyInvite).filter(
        MoneyInvite.invite_token == request.invite_token
    ).first()
    
    if not invite:
        raise HTTPException(status_code=404, detail="Invite not found")
    
    if invite.status not in ["pending", "delivered", "opened"]:
        raise HTTPException(status_code=400, detail=f"Invite already {invite.status}")
    
    # Check if expired
    if datetime.utcnow() > invite.expires_at:
        raise HTTPException(status_code=400, detail="Invite has expired")
    
    # Check if current user is recipient
    is_recipient = (
        (invite.recipient_method == "username" and invite.recipient_contact == current_user.username) or
        (invite.recipient_method == "email" and invite.recipient_contact == current_user.email) or
        (invite.recipient_method == "phone" and invite.recipient_contact == current_user.phone)
    )
    
    if not is_recipient:
        raise HTTPException(status_code=403, detail="This invite is not for you")
    
    # Add funds to recipient
    current_user.balance += invite.amount
    
    # Update invite status
    invite.status = "accepted"
    invite.responded_at = datetime.utcnow()
    invite.recipient_user_id = current_user.id
    
    # Update original transaction
    transaction = db.query(Transaction).filter(Transaction.id == invite.transaction_id).first()
    if transaction:
        transaction.status = "completed"
        transaction.receiver = current_user.username
        transaction.processed_at = datetime.utcnow()
    
    db.commit()
    
    # Notify sender
    sender = db.query(User).filter(User.id == invite.sender_id).first()
    if sender:
        notification = Notification(
            user_id=sender.id,
            title="✅ Money Accepted",
            message=f"{current_user.username} accepted your ${invite.amount:.2f} invite!",
            notification_type="transaction"
        )
        db.add(notification)
        db.commit()
    
    logger.info(f"Invite {invite.id} accepted by {current_user.username}")
    
    return {
        "message": "Invite accepted successfully",
        "amount": invite.amount,
        "new_balance": current_user.balance
    }


@router.post("/invites/{invite_id}/decline")
async def decline_money_invite(
    invite_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Decline a money invite and refund sender"""
    invite = db.query(MoneyInvite).filter(MoneyInvite.id == invite_id).first()
    if not invite:
        raise HTTPException(status_code=404, detail="Invite not found")
    
    if invite.status not in ["pending", "delivered", "opened"]:
        raise HTTPException(status_code=400, detail=f"Invite already {invite.status}")
    
    # Check if current user is recipient
    is_recipient = (
        (invite.recipient_method == "username" and invite.recipient_contact == current_user.username) or
        (invite.recipient_method == "email" and invite.recipient_contact == current_user.email) or
        (invite.recipient_method == "phone" and invite.recipient_contact == current_user.phone)
    )
    
    if not is_recipient:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    # Refund sender
    sender = db.query(User).filter(User.id == invite.sender_id).first()
    if sender:
        sender.balance += invite.amount
        
        # Create refund transaction
        refund_transaction = Transaction(
            sender="system",
            receiver=sender.username,
            amount=invite.amount,
            transaction_type="money_invite",
            status="completed",
            processed_at=datetime.utcnow(),
            extra_data={
                "reason": "invite_declined",
                "original_invite_id": invite.id
            }
        )
        db.add(refund_transaction)
        db.flush()
        
        invite.refund_transaction_id = refund_transaction.id
        
        # Notify sender
        notification = Notification(
            user_id=sender.id,
            title="❌ Invite Declined",
            message=f"Your ${invite.amount:.2f} invite was declined. Funds refunded.",
            notification_type="transaction"
        )
        db.add(notification)
    
    # Update invite status
    invite.status = "declined"
    invite.responded_at = datetime.utcnow()
    
    # Update original transaction
    transaction = db.query(Transaction).filter(Transaction.id == invite.transaction_id).first()
    if transaction:
        transaction.status = "refunded"
    
    db.commit()
    
    logger.info(f"Invite {invite_id} declined by {current_user.username}, sender refunded")
    
    return {"message": "Invite declined, sender refunded"}


@router.get("/invites/{invite_id}/status")
async def get_invite_status(
    invite_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get detailed status of an invite"""
    invite = db.query(MoneyInvite).filter(MoneyInvite.id == invite_id).first()
    if not invite:
        raise HTTPException(status_code=404, detail="Invite not found")
    
    # Check authorization
    is_sender = invite.sender_id == current_user.id
    is_recipient = (
        (invite.recipient_method == "username" and invite.recipient_contact == current_user.username) or
        (invite.recipient_method == "email" and invite.recipient_contact == current_user.email) or
        (invite.recipient_method == "phone" and invite.recipient_contact == current_user.phone)
    )
    
    if not (is_sender or is_recipient):
        raise HTTPException(status_code=403, detail="Not authorized")
    
    return {
        "id": invite.id,
        "sender_username": invite.sender_username,
        "recipient_method": invite.recipient_method,
        "recipient_contact": invite.recipient_contact if is_sender else "***",
        "amount": invite.amount,
        "message": invite.message,
        "status": invite.status,
        "created_at": invite.created_at,
        "delivered_at": invite.delivered_at,
        "opened_at": invite.opened_at,
        "responded_at": invite.responded_at,
        "expires_at": invite.expires_at,
        "refunded_at": invite.refunded_at,
        "notification_sent": invite.notification_sent,
        "notification_delivered": invite.notification_delivered,
        "email_sent": invite.email_sent,
        "sms_sent": invite.sms_sent
    }
