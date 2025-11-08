"""
API Routes for Card Services, POS Integration, ATM, and Gift Cards
"""
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from database import get_db
from models import User, Transaction
from models_cards import VirtualCard, POSTerminal, GiftCardVoucher
from services.card_services import (
    CardService, POSService, ATMService, 
    GiftCardService, WalletInteropService
)
from utils.security import decode_token
from datetime import datetime

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


# ==================== Virtual Card Management ====================

class CreateCardRequest(BaseModel):
    card_type: str = "virtual"  # virtual or physical
    network: str = "visa"  # visa or mastercard

@router.post("/cards/create")
async def create_virtual_card(
    request: CreateCardRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new virtual card for user"""
    try:
        card = CardService.create_virtual_card(
            user=current_user,
            card_type=request.card_type,
            network=request.network,
            db=db
        )
        
        return {
            "message": "Card created successfully",
            "card": {
                "id": card.id,
                "card_number": card.card_number,
                "cvv": card.cvv,  # Only show once in real app!
                "expiry_month": card.expiry_month,
                "expiry_year": card.expiry_year,
                "cardholder_name": card.cardholder_name,
                "network": card.network,
                "daily_limit": card.daily_limit,
                "transaction_limit": card.transaction_limit
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/cards/list")
async def list_user_cards(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all cards for current user"""
    cards = db.query(VirtualCard).filter(
        VirtualCard.user_id == current_user.id
    ).all()
    
    return {
        "cards": [
            {
                "id": card.id,
                "last4": card.card_number[-4:],
                "network": card.network,
                "expiry": f"{card.expiry_month:02d}/{card.expiry_year}",
                "status": card.status,
                "total_spent": card.total_spent,
                "last_used": card.last_used
            }
            for card in cards
        ]
    }


class UpdateCardLimitsRequest(BaseModel):
    card_id: int
    daily_limit: Optional[float] = None
    transaction_limit: Optional[float] = None

@router.post("/cards/update-limits")
async def update_card_limits(
    request: UpdateCardLimitsRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update card spending limits"""
    card = db.query(VirtualCard).filter(
        VirtualCard.id == request.card_id,
        VirtualCard.user_id == current_user.id
    ).first()
    
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")
    
    if request.daily_limit:
        card.daily_limit = request.daily_limit
    if request.transaction_limit:
        card.transaction_limit = request.transaction_limit
    
    db.commit()
    
    return {"message": "Card limits updated"}


class FreezeCardRequest(BaseModel):
    card_id: int
    freeze: bool

@router.post("/cards/freeze")
async def freeze_card(
    request: FreezeCardRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Freeze or unfreeze a card"""
    card = db.query(VirtualCard).filter(
        VirtualCard.id == request.card_id,
        VirtualCard.user_id == current_user.id
    ).first()
    
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")
    
    card.status = "frozen" if request.freeze else "active"
    db.commit()
    
    return {"message": f"Card {'frozen' if request.freeze else 'unfrozen'}"}


# ==================== POS Terminal Integration ====================

class RegisterTerminalRequest(BaseModel):
    terminal_name: str
    location_name: str
    address: str

@router.post("/pos/register-terminal")
async def register_pos_terminal(
    request: RegisterTerminalRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Register a POS terminal for merchant"""
    try:
        terminal, api_secret = POSService.register_terminal(
            merchant_user=current_user,
            terminal_name=request.terminal_name,
            location_name=request.location_name,
            address=request.address,
            db=db
        )
        
        return {
            "message": "Terminal registered successfully",
            "terminal": {
                "terminal_id": terminal.terminal_id,
                "api_key": terminal.api_key,
                "api_secret": api_secret,  # ONLY shown once!
                "location": terminal.location_name
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


class POSPaymentRequest(BaseModel):
    terminal_id: str
    api_key: str
    card_number: str
    amount: float
    entry_mode: str  # chip, swipe, contactless, manual
    merchant_name: str
    cvv: Optional[str] = None

@router.post("/pos/process-payment")
async def process_pos_payment(
    request: POSPaymentRequest,
    db: Session = Depends(get_db)
):
    """Process a payment at POS terminal (called by merchant)"""
    
    # Verify terminal
    terminal = db.query(POSTerminal).filter(
        POSTerminal.terminal_id == request.terminal_id,
        POSTerminal.api_key == request.api_key,
        POSTerminal.status == "active"
    ).first()
    
    if not terminal:
        raise HTTPException(status_code=401, detail="Invalid terminal credentials")
    
    try:
        result = POSService.process_pos_payment(
            terminal=terminal,
            card_number=request.card_number,
            amount=request.amount,
            entry_mode=request.entry_mode,
            merchant_name=request.merchant_name,
            cvv=request.cvv,
            db=db
        )
        
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/pos/terminals")
async def list_terminals(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """List merchant's POS terminals"""
    terminals = db.query(POSTerminal).filter(
        POSTerminal.merchant_id == current_user.id
    ).all()
    
    return {
        "terminals": [
            {
                "terminal_id": t.terminal_id,
                "name": t.terminal_name,
                "location": t.location_name,
                "status": t.status,
                "last_transaction": t.last_transaction
            }
            for t in terminals
        ]
    }


# ==================== ATM Integration ====================

class ATMWithdrawalRequest(BaseModel):
    card_number: str
    pin: str
    amount: float
    atm_id: str
    atm_location: str

@router.post("/atm/withdraw")
async def atm_withdrawal(
    request: ATMWithdrawalRequest,
    db: Session = Depends(get_db)
):
    """Process ATM withdrawal (called by ATM network)"""
    try:
        result = ATMService.process_atm_withdrawal(
            card_number=request.card_number,
            pin=request.pin,
            amount=request.amount,
            atm_id=request.atm_id,
            atm_location=request.atm_location,
            db=db
        )
        
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/atm/locations")
async def get_atm_locations():
    """Get nearby ATM locations (mock data for now)"""
    # In production, integrate with ATM network APIs
    return {
        "atms": [
            {
                "atm_id": "ATM001",
                "name": "Bank of America",
                "address": "123 Main St",
                "network": "Plus",
                "fees": 2.50
            },
            {
                "atm_id": "ATM002",
                "name": "Chase",
                "address": "456 Oak Ave",
                "network": "Cirrus",
                "fees": 3.00
            }
        ]
    }


# ==================== Gift Card System ====================

class GenerateGiftCardRequest(BaseModel):
    amount: float
    quantity: int = 1
    card_type: str = "digital"

@router.post("/gift-cards/generate")
async def generate_gift_cards(
    request: GenerateGiftCardRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Generate gift cards (for admin or partners)"""
    
    if request.quantity > 100:
        raise HTTPException(status_code=400, detail="Max 100 cards per batch")
    
    cards = []
    for _ in range(request.quantity):
        card, pin = GiftCardService.generate_gift_card(
            amount=request.amount,
            card_type=request.card_type,
            db=db
        )
        cards.append({
            "card_number": card.card_number,
            "pin": pin,  # Only shown once!
            "amount": card.initial_value,
            "expiry_date": card.expiry_date
        })
    
    return {
        "message": f"Generated {request.quantity} gift cards",
        "cards": cards
    }


class RedeemGiftCardRequest(BaseModel):
    card_number: str
    pin: str

@router.post("/gift-cards/redeem")
async def redeem_gift_card(
    request: RedeemGiftCardRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Redeem gift card to wallet balance"""
    try:
        result = GiftCardService.redeem_gift_card(
            card_number=request.card_number,
            pin=request.pin,
            user=current_user,
            db=db
        )
        
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


class UseGiftCardRequest(BaseModel):
    card_number: str
    pin: str
    amount: float
    merchant_name: str

@router.post("/gift-cards/use")
async def use_gift_card(
    request: UseGiftCardRequest,
    db: Session = Depends(get_db)
):
    """Use gift card as payment (called by merchant)"""
    try:
        result = GiftCardService.use_gift_card_at_merchant(
            card_number=request.card_number,
            pin=request.pin,
            amount=request.amount,
            merchant_name=request.merchant_name,
            db=db
        )
        
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/gift-cards/balance/{card_number}")
async def check_gift_card_balance(
    card_number: str,
    db: Session = Depends(get_db)
):
    """Check gift card balance"""
    card = db.query(GiftCardVoucher).filter(
        GiftCardVoucher.card_number == card_number
    ).first()
    
    if not card:
        raise HTTPException(status_code=404, detail="Gift card not found")
    
    return {
        "card_number": card.card_number[-4:].rjust(16, '*'),
        "balance": card.current_balance,
        "status": card.status,
        "expiry_date": card.expiry_date
    }


# ==================== Cross-Wallet Integration ====================

class SendToExternalWalletRequest(BaseModel):
    wallet_provider: str  # venmo, cashapp, paypal, zelle
    recipient_identifier: str  # username, email, phone, cashtag
    amount: float

@router.post("/cross-wallet/send")
async def send_to_external_wallet(
    request: SendToExternalWalletRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Send money to external wallet (Venmo, CashApp, etc.)"""
    try:
        result = WalletInteropService.send_to_external_wallet(
            user=current_user,
            wallet_provider=request.wallet_provider,
            recipient_identifier=request.recipient_identifier,
            amount=request.amount,
            db=db
        )
        
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/cross-wallet/supported")
async def get_supported_wallets():
    """Get list of supported external wallets"""
    return {
        "wallets": [
            {
                "id": wallet_id,
                "name": info["name"],
                "identifier_type": info["identifier_type"],
                "fee": f"{info['fee'] * 100}%" if info['fee'] > 0 else "FREE"
            }
            for wallet_id, info in WalletInteropService.SUPPORTED_WALLETS.items()
        ]
    }


# ==================== Transaction History ====================

@router.get("/cards/{card_id}/transactions")
async def get_card_transactions(
    card_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get transaction history for a card"""
    
    from models_cards import CardTransaction
    
    # Verify card belongs to user
    card = db.query(VirtualCard).filter(
        VirtualCard.id == card_id,
        VirtualCard.user_id == current_user.id
    ).first()
    
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")
    
    transactions = db.query(CardTransaction).filter(
        CardTransaction.card_id == card_id
    ).order_by(CardTransaction.created_at.desc()).limit(100).all()
    
    return {
        "card": {
            "last4": card.card_number[-4:],
            "total_spent": card.total_spent
        },
        "transactions": [
            {
                "id": txn.id,
                "amount": txn.amount,
                "merchant": txn.merchant_name,
                "type": txn.transaction_type,
                "entry_mode": txn.entry_mode,
                "status": txn.status,
                "date": txn.created_at,
                "auth_code": txn.auth_code
            }
            for txn in transactions
        ]
    }
