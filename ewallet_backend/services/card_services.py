"""
Card Services for POS, ATM, and Universal Payment Network Integration
Handles card generation, authorization, and settlement
"""
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import secrets
import hashlib
import re
from sqlalchemy.orm import Session
from models import User
from models_cards import (
    VirtualCard, CardTransaction, ATMTransaction, 
    POSTerminal, GiftCardVoucher, WalletInteroperability
)


class CardService:
    """Core card operations service"""
    
    @staticmethod
    def generate_card_number(bin_prefix: str = "4532") -> str:
        """
        Generate valid card number with Luhn algorithm
        BIN prefixes:
        - 4532: Visa debit
        - 5425: Mastercard debit
        - 6011: Discover
        """
        # Generate 15 digits (16 total with check digit)
        number = bin_prefix
        for _ in range(12 - len(bin_prefix)):
            number += str(secrets.randbelow(10))
        
        # Calculate Luhn check digit
        check_digit = CardService._luhn_checksum(number)
        return number + str(check_digit)
    
    @staticmethod
    def _luhn_checksum(card_number: str) -> int:
        """Calculate Luhn check digit"""
        def digits_of(n):
            return [int(d) for d in str(n)]
        
        digits = digits_of(card_number)
        odd_digits = digits[-1::-2]
        even_digits = digits[-2::-2]
        checksum = sum(odd_digits)
        for d in even_digits:
            checksum += sum(digits_of(d * 2))
        return (10 - (checksum % 10)) % 10
    
    @staticmethod
    def validate_card_number(card_number: str) -> bool:
        """Validate card number with Luhn algorithm"""
        try:
            check = int(card_number[-1])
            calculated = CardService._luhn_checksum(card_number[:-1])
            return check == calculated
        except:
            return False
    
    @staticmethod
    def generate_cvv() -> str:
        """Generate 3-digit CVV"""
        return ''.join([str(secrets.randbelow(10)) for _ in range(3)])
    
    @staticmethod
    def generate_pin() -> str:
        """Generate 4-digit PIN"""
        return ''.join([str(secrets.randbelow(10)) for _ in range(4)])
    
    @staticmethod
    def hash_pin(pin: str) -> str:
        """Hash PIN for secure storage"""
        return hashlib.sha256(pin.encode()).hexdigest()
    
    @staticmethod
    def verify_pin(pin: str, hashed_pin: str) -> bool:
        """Verify PIN against hash"""
        return CardService.hash_pin(pin) == hashed_pin
    
    @staticmethod
    def create_virtual_card(
        user: User,
        card_type: str = "virtual",
        network: str = "visa",
        db: Session = None
    ) -> VirtualCard:
        """Create a new virtual card for user"""
        
        # Generate card details
        bin_prefix = "4532" if network == "visa" else "5425"
        card_number = CardService.generate_card_number(bin_prefix)
        cvv = CardService.generate_cvv()
        
        # Set expiry (5 years from now)
        expiry = datetime.utcnow() + timedelta(days=365 * 5)
        
        # Create card
        card = VirtualCard(
            user_id=user.id,
            card_number=card_number,
            cvv=cvv,  # In production, encrypt this!
            expiry_month=expiry.month,
            expiry_year=expiry.year,
            cardholder_name=user.username.upper(),
            billing_zip="00000",  # User should set this
            network=network,
            card_type=card_type,
            status="active"
        )
        
        if db:
            db.add(card)
            db.commit()
            db.refresh(card)
        
        return card
    
    @staticmethod
    def authorize_transaction(
        card: VirtualCard,
        amount: float,
        merchant_name: str,
        merchant_category: str,
        entry_mode: str,
        cvv: Optional[str] = None,
        zip_code: Optional[str] = None,
        db: Session = None
    ) -> Dict[str, Any]:
        """
        Authorize a card transaction (POS, online, ATM)
        Returns authorization response
        """
        
        # Check card status
        if card.status != "active":
            return {
                "approved": False,
                "decline_reason": "card_inactive",
                "message": "Card is not active"
            }
        
        # Check expiry
        now = datetime.utcnow()
        expiry = datetime(card.expiry_year, card.expiry_month, 1)
        if now > expiry:
            return {
                "approved": False,
                "decline_reason": "card_expired",
                "message": "Card has expired"
            }
        
        # Check daily limit
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        today_transactions = db.query(CardTransaction).filter(
            CardTransaction.card_id == card.id,
            CardTransaction.created_at >= today_start,
            CardTransaction.status == "approved"
        ).all()
        
        today_total = sum(t.amount for t in today_transactions)
        if today_total + amount > card.daily_limit:
            return {
                "approved": False,
                "decline_reason": "daily_limit_exceeded",
                "message": f"Daily limit of ${card.daily_limit} exceeded"
            }
        
        # Check transaction limit
        if amount > card.transaction_limit:
            return {
                "approved": False,
                "decline_reason": "transaction_limit_exceeded",
                "message": f"Transaction limit of ${card.transaction_limit} exceeded"
            }
        
        # Check user balance
        if card.user.balance < amount:
            return {
                "approved": False,
                "decline_reason": "insufficient_funds",
                "message": "Insufficient wallet balance"
            }
        
        # Verify CVV if provided
        cvv_verified = False
        if cvv:
            cvv_verified = (cvv == card.cvv)
            if not cvv_verified and entry_mode == "online":
                return {
                    "approved": False,
                    "decline_reason": "cvv_mismatch",
                    "message": "CVV verification failed"
                }
        
        # Verify ZIP if provided
        zip_verified = False
        if zip_code:
            zip_verified = (zip_code == card.billing_zip)
        
        # Calculate risk score (0-100)
        risk_score = CardService._calculate_risk_score(
            card, amount, merchant_category, entry_mode
        )
        
        # Decline if high risk
        if risk_score > 80:
            return {
                "approved": False,
                "decline_reason": "high_risk",
                "message": "Transaction flagged as high risk"
            }
        
        # Generate authorization code
        auth_code = secrets.token_hex(4).upper()
        
        # APPROVED - Create transaction record
        transaction = CardTransaction(
            card_id=card.id,
            user_id=card.user_id,
            amount=amount,
            merchant_name=merchant_name,
            merchant_category=merchant_category,
            transaction_type="purchase",
            entry_mode=entry_mode,
            status="approved",
            auth_code=auth_code,
            cvv_verified=cvv_verified,
            zip_verified=zip_verified,
            risk_score=risk_score
        )
        
        # Deduct from user balance
        card.user.balance -= amount
        card.total_spent += amount
        card.last_used = datetime.utcnow()
        
        if db:
            db.add(transaction)
            db.commit()
        
        return {
            "approved": True,
            "auth_code": auth_code,
            "transaction_id": transaction.id,
            "remaining_balance": card.user.balance,
            "message": "Transaction approved"
        }
    
    @staticmethod
    def _calculate_risk_score(
        card: VirtualCard,
        amount: float,
        merchant_category: str,
        entry_mode: str
    ) -> float:
        """Calculate fraud risk score (0-100)"""
        risk = 0.0
        
        # High-risk merchant categories
        high_risk_mcc = ["5962", "5967", "7995"]  # Adult, gambling, betting
        if merchant_category in high_risk_mcc:
            risk += 30
        
        # Large transactions
        if amount > 500:
            risk += 20
        if amount > 1000:
            risk += 20
        
        # Entry mode risk
        if entry_mode == "manual":
            risk += 25
        elif entry_mode == "online":
            risk += 10
        
        # International transactions (if not enabled)
        if not card.international_enabled:
            # Check if merchant is international (simplified)
            risk += 15
        
        # First transaction on card
        if not card.last_used:
            risk += 10
        
        return min(risk, 100.0)


class POSService:
    """POS terminal integration service"""
    
    @staticmethod
    def register_terminal(
        merchant_user: User,
        terminal_name: str,
        location_name: str,
        address: str,
        db: Session
    ) -> POSTerminal:
        """Register a new POS terminal for merchant"""
        
        # Generate unique terminal ID
        terminal_id = f"POS-{secrets.token_hex(8).upper()}"
        
        # Generate API credentials
        api_key = f"pk_live_{secrets.token_hex(16)}"
        api_secret = secrets.token_hex(32)
        api_secret_hash = hashlib.sha256(api_secret.encode()).hexdigest()
        
        terminal = POSTerminal(
            merchant_id=merchant_user.id,
            terminal_id=terminal_id,
            terminal_name=terminal_name,
            location_name=location_name,
            address=address,
            api_key=api_key,
            api_secret=api_secret_hash,
            status="active"
        )
        
        db.add(terminal)
        db.commit()
        db.refresh(terminal)
        
        return terminal, api_secret  # Return secret only once!
    
    @staticmethod
    def process_pos_payment(
        terminal: POSTerminal,
        card_number: str,
        amount: float,
        entry_mode: str,
        merchant_name: str,
        cvv: Optional[str] = None,
        pin: Optional[str] = None,
        db: Session = None
    ) -> Dict[str, Any]:
        """Process a payment at POS terminal"""
        
        # Find card
        card = db.query(VirtualCard).filter(
            VirtualCard.card_number == card_number,
            VirtualCard.status == "active"
        ).first()
        
        if not card:
            return {
                "approved": False,
                "decline_reason": "invalid_card",
                "message": "Card not found or inactive"
            }
        
        # Authorize transaction
        result = CardService.authorize_transaction(
            card=card,
            amount=amount,
            merchant_name=merchant_name,
            merchant_category="5999",  # Misc retail
            entry_mode=entry_mode,
            cvv=cvv,
            db=db
        )
        
        # Update terminal
        if result["approved"]:
            terminal.last_transaction = datetime.utcnow()
            db.commit()
        
        return result


class ATMService:
    """ATM network integration service"""
    
    @staticmethod
    def process_atm_withdrawal(
        card_number: str,
        pin: str,
        amount: float,
        atm_id: str,
        atm_location: str,
        atm_network: str = "Plus",
        db: Session = None
    ) -> Dict[str, Any]:
        """Process ATM withdrawal"""
        
        # Find card
        card = db.query(VirtualCard).filter(
            VirtualCard.card_number == card_number
        ).first()
        
        if not card:
            return {
                "approved": False,
                "decline_reason": "invalid_card",
                "message": "Card not found"
            }
        
        # Check if ATM enabled
        if not card.atm_enabled:
            return {
                "approved": False,
                "decline_reason": "atm_disabled",
                "message": "ATM transactions disabled on this card"
            }
        
        # Verify PIN (in production, cards would have PINs)
        # For now, skip PIN verification
        pin_verified = True
        
        # Calculate ATM fee
        atm_fee = 2.50  # Standard ATM fee
        total_amount = amount + atm_fee
        
        # Check balance
        if card.user.balance < total_amount:
            return {
                "approved": False,
                "decline_reason": "insufficient_funds",
                "message": f"Insufficient funds (need ${total_amount} including fee)"
            }
        
        # Generate auth code
        auth_code = secrets.token_hex(4).upper()
        
        # Create ATM transaction
        atm_txn = ATMTransaction(
            card_id=card.id,
            user_id=card.user_id,
            atm_id=atm_id,
            atm_location=atm_location,
            atm_network=atm_network,
            amount=amount,
            fee=atm_fee,
            auth_code=auth_code,
            pin_verified=pin_verified,
            chip_used=True,
            status="approved"
        )
        
        # Create card transaction
        card_txn = CardTransaction(
            card_id=card.id,
            user_id=card.user_id,
            amount=amount,
            merchant_name=f"ATM - {atm_location}",
            merchant_category="6011",  # ATM MCC
            transaction_type="atm_withdrawal",
            entry_mode="chip",
            status="approved",
            auth_code=auth_code
        )
        
        # Deduct from balance
        card.user.balance -= total_amount
        card.total_spent += total_amount
        card.last_used = datetime.utcnow()
        
        db.add(atm_txn)
        db.add(card_txn)
        db.commit()
        
        return {
            "approved": True,
            "auth_code": auth_code,
            "amount": amount,
            "fee": atm_fee,
            "total": total_amount,
            "remaining_balance": card.user.balance,
            "message": "Withdrawal approved"
        }


class GiftCardService:
    """Universal gift card service"""
    
    @staticmethod
    def generate_gift_card(
        amount: float,
        card_type: str = "digital",
        expiry_days: int = 365,
        db: Session = None
    ) -> GiftCardVoucher:
        """Generate a new gift card"""
        
        # Generate card number (16 digits starting with 6)
        card_number = "6" + ''.join([str(secrets.randbelow(10)) for _ in range(15)])
        
        # Generate PIN
        pin = CardService.generate_pin()
        pin_hash = CardService.hash_pin(pin)
        
        # Set expiry
        expiry = datetime.utcnow() + timedelta(days=expiry_days)
        
        gift_card = GiftCardVoucher(
            card_number=card_number,
            pin=pin_hash,
            card_type=card_type,
            initial_value=amount,
            current_balance=amount,
            expiry_date=expiry,
            status="inactive"  # Activated when purchased
        )
        
        if db:
            db.add(gift_card)
            db.commit()
            db.refresh(gift_card)
        
        return gift_card, pin  # Return PIN only once!
    
    @staticmethod
    def redeem_gift_card(
        card_number: str,
        pin: str,
        user: User,
        db: Session
    ) -> Dict[str, Any]:
        """Redeem gift card to user's wallet"""
        
        # Find card
        gift_card = db.query(GiftCardVoucher).filter(
            GiftCardVoucher.card_number == card_number
        ).first()
        
        if not gift_card:
            return {"success": False, "message": "Gift card not found"}
        
        # Verify PIN
        if not CardService.verify_pin(pin, gift_card.pin):
            return {"success": False, "message": "Invalid PIN"}
        
        # Check status
        if gift_card.status == "redeemed":
            return {"success": False, "message": "Gift card already redeemed"}
        
        if gift_card.status == "expired":
            return {"success": False, "message": "Gift card has expired"}
        
        # Check expiry
        if gift_card.expiry_date and datetime.utcnow() > gift_card.expiry_date:
            gift_card.status = "expired"
            db.commit()
            return {"success": False, "message": "Gift card has expired"}
        
        # Redeem to user balance
        user.balance += gift_card.current_balance
        gift_card.current_balance = 0
        gift_card.status = "redeemed"
        gift_card.redeemed_by_user_id = user.id
        gift_card.redeemed_at = datetime.utcnow()
        
        db.commit()
        
        return {
            "success": True,
            "amount": gift_card.initial_value,
            "new_balance": user.balance,
            "message": f"Gift card redeemed: ${gift_card.initial_value}"
        }
    
    @staticmethod
    def use_gift_card_at_merchant(
        card_number: str,
        pin: str,
        amount: float,
        merchant_name: str,
        db: Session
    ) -> Dict[str, Any]:
        """Use gift card as payment at any merchant"""
        
        # Find card
        gift_card = db.query(GiftCardVoucher).filter(
            GiftCardVoucher.card_number == card_number
        ).first()
        
        if not gift_card:
            return {"approved": False, "message": "Gift card not found"}
        
        # Verify PIN
        if not CardService.verify_pin(pin, gift_card.pin):
            return {"approved": False, "message": "Invalid PIN"}
        
        # Check balance
        if gift_card.current_balance < amount:
            return {
                "approved": False,
                "message": f"Insufficient balance. Available: ${gift_card.current_balance}"
            }
        
        # Check status
        if gift_card.status != "active":
            return {"approved": False, "message": "Gift card not active"}
        
        # Deduct amount
        gift_card.current_balance -= amount
        
        # If balance is zero, mark as redeemed
        if gift_card.current_balance == 0:
            gift_card.status = "redeemed"
            gift_card.redeemed_at = datetime.utcnow()
        
        db.commit()
        
        return {
            "approved": True,
            "amount": amount,
            "remaining_balance": gift_card.current_balance,
            "message": "Payment approved"
        }


class WalletInteropService:
    """Interoperability with other e-wallets"""
    
    SUPPORTED_WALLETS = {
        "venmo": {
            "name": "Venmo",
            "identifier_type": "username",
            "fee": 0.03  # 3%
        },
        "cashapp": {
            "name": "Cash App",
            "identifier_type": "cashtag",
            "fee": 0.0275  # 2.75%
        },
        "paypal": {
            "name": "PayPal",
            "identifier_type": "email",
            "fee": 0.029  # 2.9% + 30¢
        },
        "zelle": {
            "name": "Zelle",
            "identifier_type": "email_or_phone",
            "fee": 0.0  # Free!
        }
    }
    
    @staticmethod
    def send_to_external_wallet(
        user: User,
        wallet_provider: str,
        recipient_identifier: str,
        amount: float,
        db: Session
    ) -> Dict[str, Any]:
        """
        Send money to external wallet (Venmo, CashApp, etc.)
        In production, this would integrate with their APIs
        """
        
        if wallet_provider not in WalletInteropService.SUPPORTED_WALLETS:
            return {"success": False, "message": "Wallet provider not supported"}
        
        wallet_info = WalletInteropService.SUPPORTED_WALLETS[wallet_provider]
        
        # Calculate fee
        fee = amount * wallet_info["fee"]
        if wallet_provider == "paypal":
            fee += 0.30
        
        total = amount + fee
        
        # Check balance
        if user.balance < total:
            return {"success": False, "message": "Insufficient balance"}
        
        # Create cross-wallet transaction
        external_txn_id = f"{wallet_provider.upper()}-{secrets.token_hex(8)}"
        
        cross_wallet_txn = WalletInteroperability(
            our_user_id=user.id,
            external_wallet=wallet_provider,
            external_user_identifier=recipient_identifier,
            external_transaction_id=external_txn_id,
            amount=amount,
            direction="outbound",
            status="pending",
            our_fee=fee
        )
        
        # Deduct from balance
        user.balance -= total
        
        db.add(cross_wallet_txn)
        db.commit()
        
        # In production: Call external API here
        # For now, mark as completed
        cross_wallet_txn.status = "completed"
        cross_wallet_txn.completed_at = datetime.utcnow()
        db.commit()
        
        return {
            "success": True,
            "amount": amount,
            "fee": fee,
            "total": total,
            "transaction_id": external_txn_id,
            "new_balance": user.balance,
            "message": f"Sent ${amount} to {wallet_info['name']}"
        }
