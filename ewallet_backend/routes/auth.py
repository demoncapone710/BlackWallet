"""
Authentication Routes for BlackWallet
Handles password reset, user lookup by email/phone
"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import secrets
import re
import logging
from database import SessionLocal
from models import User, Transaction
from schemas import ForgotPasswordRequest, VerifyResetCode, ResetPassword, SendMoneyByContact
from utils.security import hash_password
from auth import get_current_user
from notification_service import notification_service

logger = logging.getLogger(__name__)
router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def generate_reset_code() -> str:
    """Generate a secure 6-digit code"""
    return ''.join([str(secrets.randbelow(10)) for _ in range(6)])

def is_email(identifier: str) -> bool:
    """Check if identifier is an email"""
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(email_pattern, identifier) is not None

def is_phone(identifier: str) -> bool:
    """Check if identifier is a phone number (digits only)"""
    phone = re.sub(r'\D', '', identifier)
    return len(phone) >= 10 and len(phone) <= 15

@router.post("/forgot-password")
async def forgot_password(request: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """
    Request password reset code via email or phone
    
    Args:
        identifier: Email address or phone number
    
    Returns:
        Success message and method used (email or sms)
    """
    try:
        identifier = request.identifier.strip()
        
        # Determine if it's email or phone
        is_email_input = is_email(identifier)
        is_phone_input = is_phone(identifier)
        
        if not is_email_input and not is_phone_input:
            raise HTTPException(
                status_code=400,
                detail="Invalid email or phone number format"
            )
        
        # Find user by email or phone
        user = None
        method = None
        
        if is_email_input:
            user = db.query(User).filter(User.email == identifier).first()
            method = 'email'
        elif is_phone_input:
            # Normalize phone number (remove non-digits)
            phone = re.sub(r'\D', '', identifier)
            user = db.query(User).filter(User.phone == phone).first()
            method = 'sms'
        
        if not user:
            # For security, don't reveal if user exists
            logger.warning(f"Password reset requested for non-existent user: {identifier}")
            return {
                "message": "If an account exists with this information, a reset code has been sent.",
                "method": method
            }
        
        # Generate reset code
        reset_code = generate_reset_code()
        
        # Save reset code and expiry (15 minutes)
        user.password_reset_token = reset_code
        user.reset_token_expiry = datetime.utcnow() + timedelta(minutes=15)
        db.commit()
        
        # Send reset code
        sent = await notification_service.send_password_reset_code(
            identifier=identifier,
            code=reset_code,
            method=method
        )
        
        if not sent:
            logger.error(f"Failed to send reset code to {identifier}")
            # Don't fail the request, but log it
        
        logger.info(f"Password reset code sent to {identifier} via {method}")
        
        return {
            "message": "If an account exists with this information, a reset code has been sent.",
            "method": method
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in forgot_password: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@router.post("/verify-reset-code")
async def verify_reset_code(request: VerifyResetCode, db: Session = Depends(get_db)):
    """
    Verify the password reset code
    
    Args:
        identifier: Email or phone
        code: 6-digit verification code
    
    Returns:
        Success message if code is valid
    """
    try:
        identifier = request.identifier.strip()
        code = request.code.strip()
        
        # Find user
        is_email_input = is_email(identifier)
        user = None
        
        if is_email_input:
            user = db.query(User).filter(User.email == identifier).first()
        else:
            phone = re.sub(r'\D', '', identifier)
            user = db.query(User).filter(User.phone == phone).first()
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Check if code matches and hasn't expired
        if user.password_reset_token != code:
            raise HTTPException(status_code=400, detail="Invalid reset code")
        
        if not user.reset_token_expiry or user.reset_token_expiry < datetime.utcnow():
            raise HTTPException(status_code=400, detail="Reset code has expired")
        
        logger.info(f"Reset code verified for user: {user.username}")
        
        return {"message": "Reset code verified successfully"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in verify_reset_code: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@router.post("/reset-password")
async def reset_password(request: ResetPassword, db: Session = Depends(get_db)):
    """
    Reset password using verified code
    
    Args:
        identifier: Email or phone
        code: 6-digit verification code
        new_password: New password
    
    Returns:
        Success message
    """
    try:
        identifier = request.identifier.strip()
        code = request.code.strip()
        new_password = request.new_password
        
        # Find user
        is_email_input = is_email(identifier)
        user = None
        
        if is_email_input:
            user = db.query(User).filter(User.email == identifier).first()
        else:
            phone = re.sub(r'\D', '', identifier)
            user = db.query(User).filter(User.phone == phone).first()
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Verify code
        if user.password_reset_token != code:
            raise HTTPException(status_code=400, detail="Invalid reset code")
        
        if not user.reset_token_expiry or user.reset_token_expiry < datetime.utcnow():
            raise HTTPException(status_code=400, detail="Reset code has expired")
        
        # Update password
        user.password = hash_password(new_password)
        user.password_reset_token = None
        user.reset_token_expiry = None
        db.commit()
        
        logger.info(f"Password reset successfully for user: {user.username}")
        
        return {"message": "Password reset successfully"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in reset_password: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@router.post("/send-money-by-contact")
async def send_money_by_contact(
    request: SendMoneyByContact,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user)
):
    """
    Send money to a user by their phone number or email
    If user doesn't exist, send them an invitation
    
    Args:
        contact: Phone number or email
        amount: Amount to send
        contact_type: 'phone' or 'email'
    
    Returns:
        Success message and whether invitation was sent
    """
    try:
        contact = request.contact.strip()
        amount = request.amount
        contact_type = request.contact_type.lower()
        
        if amount <= 0:
            raise HTTPException(status_code=400, detail="Amount must be positive")
        
        # Get sender
        sender = db.query(User).filter(User.username == user["username"]).first()
        if not sender:
            raise HTTPException(status_code=404, detail="Sender not found")
        
        if sender.balance < amount:
            raise HTTPException(status_code=400, detail="Insufficient balance")
        
        # Find recipient by contact
        recipient = None
        if contact_type == 'email':
            recipient = db.query(User).filter(User.email == contact).first()
        elif contact_type == 'phone':
            phone = re.sub(r'\D', '', contact)
            recipient = db.query(User).filter(User.phone == phone).first()
        else:
            raise HTTPException(status_code=400, detail="Invalid contact type")
        
        if recipient:
            # User exists - process transfer
            sender.balance -= amount
            recipient.balance += amount
            
            # Create transaction record
            transaction = Transaction(
                sender=sender.username,
                receiver=recipient.username,
                amount=amount,
                transaction_type="internal",
                status="completed",
                extra_data={
                    "method": "contact_transfer",
                    "contact_type": contact_type,
                    "contact": contact
                }
            )
            db.add(transaction)
            db.commit()
            
            # Send notification to recipient
            method = 'email' if contact_type == 'email' else 'sms'
            await notification_service.send_money_notification(
                identifier=contact,
                sender_name=sender.full_name or sender.username,
                amount=amount,
                method=method
            )
            
            logger.info(f"Money sent from {sender.username} to {recipient.username} via {contact_type}")
            
            return {
                "message": f"Successfully sent ${amount:.2f} to {recipient.username}",
                "recipient_exists": True,
                "invitation_sent": False
            }
        else:
            # User doesn't exist - deduct from sender and send invitation
            sender.balance -= amount
            
            # Create pending transaction record
            transaction = Transaction(
                sender=sender.username,
                receiver=f"pending:{contact}",
                amount=amount,
                transaction_type="internal",
                status="pending",
                extra_data={
                    "method": "contact_transfer",
                    "contact_type": contact_type,
                    "contact": contact,
                    "invitation_sent": True
                }
            )
            db.add(transaction)
            db.commit()
            
            # Send invitation with money notification
            method = 'email' if contact_type == 'email' else 'sms'
            await notification_service.send_money_notification(
                identifier=contact,
                sender_name=sender.full_name or sender.username,
                amount=amount,
                method=method
            )
            
            logger.info(f"Invitation sent to {contact} with ${amount:.2f} from {sender.username}")
            
            return {
                "message": f"Invitation sent to {contact} with ${amount:.2f}",
                "recipient_exists": False,
                "invitation_sent": True
            }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in send_money_by_contact: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@router.get("/user-by-contact/{contact}")
async def get_user_by_contact(
    contact: str,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user)
):
    """
    Look up user by phone or email
    
    Args:
        contact: Phone number or email
    
    Returns:
        User info if found
    """
    try:
        contact = contact.strip()
        
        # Try email first
        user = db.query(User).filter(User.email == contact).first()
        
        # Try phone if not found
        if not user:
            phone = re.sub(r'\D', '', contact)
            user = db.query(User).filter(User.phone == phone).first()
        
        if not user:
            return {"found": False}
        
        return {
            "found": True,
            "username": user.username,
            "full_name": user.full_name,
            "email": user.email if user.email else None
        }
    
    except Exception as e:
        logger.error(f"Error in get_user_by_contact: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")
