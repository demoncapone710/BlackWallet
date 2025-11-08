"""
Services for Quick Win Features
"""
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import secrets
import string
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func
from models import User, Transaction
from models_quick_wins import (
    Favorite, ScheduledPayment, PaymentLink, 
    TransactionTag, SubWallet, QRPaymentLimit
)


class FavoriteService:
    """Manage favorite recipients"""
    
    @staticmethod
    def add_favorite(
        user: User,
        recipient_type: str,
        recipient_identifier: str,
        nickname: str = None,
        db: Session = None
    ) -> Favorite:
        """Add recipient to favorites"""
        # Check if already exists
        existing = db.query(Favorite).filter(
            Favorite.user_id == user.id,
            Favorite.recipient_identifier == recipient_identifier
        ).first()
        
        if existing:
            return existing
        
        favorite = Favorite(
            user_id=user.id,
            recipient_type=recipient_type,
            recipient_identifier=recipient_identifier,
            nickname=nickname or recipient_identifier
        )
        
        db.add(favorite)
        db.commit()
        db.refresh(favorite)
        return favorite
    
    @staticmethod
    def remove_favorite(user: User, favorite_id: int, db: Session) -> bool:
        """Remove from favorites"""
        favorite = db.query(Favorite).filter(
            Favorite.id == favorite_id,
            Favorite.user_id == user.id
        ).first()
        
        if favorite:
            db.delete(favorite)
            db.commit()
            return True
        return False
    
    @staticmethod
    def get_favorites(user: User, db: Session) -> List[Favorite]:
        """Get user's favorites, sorted by most used"""
        return db.query(Favorite).filter(
            Favorite.user_id == user.id
        ).order_by(Favorite.use_count.desc()).all()
    
    @staticmethod
    def increment_usage(favorite_id: int, db: Session):
        """Increment usage counter"""
        favorite = db.query(Favorite).filter(Favorite.id == favorite_id).first()
        if favorite:
            favorite.use_count += 1
            favorite.last_used = datetime.utcnow()
            db.commit()


class ScheduledPaymentService:
    """Manage scheduled and recurring payments"""
    
    @staticmethod
    def create_scheduled_payment(
        user: User,
        recipient_type: str,
        recipient_identifier: str,
        amount: float,
        scheduled_date: datetime,
        schedule_type: str = "once",
        note: str = None,
        db: Session = None
    ) -> ScheduledPayment:
        """Create a scheduled payment"""
        payment = ScheduledPayment(
            user_id=user.id,
            recipient_type=recipient_type,
            recipient_identifier=recipient_identifier,
            amount=amount,
            note=note,
            schedule_type=schedule_type,
            scheduled_date=scheduled_date,
            next_execution=scheduled_date,
            is_recurring=(schedule_type != "once")
        )
        
        db.add(payment)
        db.commit()
        db.refresh(payment)
        return payment
    
    @staticmethod
    def get_pending_payments(db: Session) -> List[ScheduledPayment]:
        """Get payments ready to execute"""
        now = datetime.utcnow()
        return db.query(ScheduledPayment).filter(
            ScheduledPayment.status == "pending",
            ScheduledPayment.next_execution <= now
        ).all()
    
    @staticmethod
    def execute_payment(payment: ScheduledPayment, db: Session) -> Dict[str, Any]:
        """Execute a scheduled payment"""
        user = db.query(User).filter(User.id == payment.user_id).first()
        
        # Check balance
        if user.balance < payment.amount:
            payment.status = "failed"
            db.commit()
            return {"success": False, "error": "Insufficient funds"}
        
        # Find recipient
        recipient = None
        if payment.recipient_type == "username":
            recipient = db.query(User).filter(
                User.username == payment.recipient_identifier
            ).first()
        elif payment.recipient_type == "email":
            recipient = db.query(User).filter(
                User.email == payment.recipient_identifier
            ).first()
        elif payment.recipient_type == "phone":
            recipient = db.query(User).filter(
                User.phone == payment.recipient_identifier
            ).first()
        
        if not recipient:
            payment.status = "failed"
            db.commit()
            return {"success": False, "error": "Recipient not found"}
        
        # Execute transfer
        user.balance -= payment.amount
        recipient.balance += payment.amount
        
        # Create transaction record
        transaction = Transaction(
            sender=user.username,
            receiver=recipient.username,
            amount=payment.amount,
            transaction_type="scheduled",
            status="completed"
        )
        db.add(transaction)
        
        # Update scheduled payment
        payment.execution_count += 1
        payment.last_execution = datetime.utcnow()
        
        if payment.is_recurring:
            # Calculate next execution
            if payment.schedule_type == "daily":
                payment.next_execution = datetime.utcnow() + timedelta(days=1)
            elif payment.schedule_type == "weekly":
                payment.next_execution = datetime.utcnow() + timedelta(weeks=1)
            elif payment.schedule_type == "biweekly":
                payment.next_execution = datetime.utcnow() + timedelta(weeks=2)
            elif payment.schedule_type == "monthly":
                payment.next_execution = datetime.utcnow() + timedelta(days=30)
        else:
            payment.status = "completed"
        
        db.commit()
        return {"success": True, "transaction_id": transaction.id}
    
    @staticmethod
    def cancel_payment(user: User, payment_id: int, db: Session) -> bool:
        """Cancel a scheduled payment"""
        payment = db.query(ScheduledPayment).filter(
            ScheduledPayment.id == payment_id,
            ScheduledPayment.user_id == user.id
        ).first()
        
        if payment:
            payment.status = "cancelled"
            db.commit()
            return True
        return False


class PaymentLinkService:
    """Generate and manage payment links"""
    
    @staticmethod
    def generate_link_code() -> str:
        """Generate unique short code"""
        chars = string.ascii_letters + string.digits
        return ''.join(secrets.choice(chars) for _ in range(8))
    
    @staticmethod
    def create_payment_link(
        user: User,
        amount: float = None,
        description: str = None,
        max_uses: int = None,
        expires_in_hours: int = None,
        db: Session = None
    ) -> PaymentLink:
        """Create a shareable payment link"""
        link_code = PaymentLinkService.generate_link_code()
        
        # Ensure unique
        while db.query(PaymentLink).filter(PaymentLink.link_code == link_code).first():
            link_code = PaymentLinkService.generate_link_code()
        
        expires_at = None
        if expires_in_hours:
            expires_at = datetime.utcnow() + timedelta(hours=expires_in_hours)
        
        link = PaymentLink(
            user_id=user.id,
            link_code=link_code,
            amount=amount,
            description=description,
            max_uses=max_uses,
            expires_at=expires_at
        )
        
        db.add(link)
        db.commit()
        db.refresh(link)
        return link
    
    @staticmethod
    def get_link(link_code: str, db: Session) -> Optional[PaymentLink]:
        """Get payment link by code"""
        return db.query(PaymentLink).filter(
            PaymentLink.link_code == link_code
        ).first()
    
    @staticmethod
    def validate_link(link: PaymentLink) -> Dict[str, Any]:
        """Check if link is still valid"""
        if not link.is_active:
            return {"valid": False, "error": "Link is inactive"}
        
        if link.expires_at and link.expires_at < datetime.utcnow():
            return {"valid": False, "error": "Link has expired"}
        
        if link.max_uses and link.current_uses >= link.max_uses:
            return {"valid": False, "error": "Link usage limit reached"}
        
        return {"valid": True}
    
    @staticmethod
    def process_payment(
        link: PaymentLink,
        payer: User,
        amount: float = None,
        db: Session = None
    ) -> Dict[str, Any]:
        """Process payment via link"""
        # Validate link
        validation = PaymentLinkService.validate_link(link)
        if not validation["valid"]:
            return {"success": False, "error": validation["error"]}
        
        # Determine amount
        payment_amount = link.amount if link.amount else amount
        if not payment_amount:
            return {"success": False, "error": "Amount required"}
        
        # Check balance
        if payer.balance < payment_amount:
            return {"success": False, "error": "Insufficient funds"}
        
        # Get recipient
        recipient = db.query(User).filter(User.id == link.user_id).first()
        
        # Process payment
        payer.balance -= payment_amount
        recipient.balance += payment_amount
        
        # Create transaction
        transaction = Transaction(
            sender=payer.username,
            receiver=recipient.username,
            amount=payment_amount,
            transaction_type="payment_link",
            status="completed"
        )
        db.add(transaction)
        
        # Update link stats
        link.current_uses += 1
        link.total_collected += payment_amount
        
        db.commit()
        
        return {
            "success": True,
            "transaction_id": transaction.id,
            "amount": payment_amount
        }


class TransactionSearchService:
    """Search and filter transactions"""
    
    @staticmethod
    def search_transactions(
        user: User,
        query: str = None,
        min_amount: float = None,
        max_amount: float = None,
        start_date: datetime = None,
        end_date: datetime = None,
        transaction_type: str = None,
        tags: List[str] = None,
        db: Session = None
    ) -> List[Transaction]:
        """Search transactions with filters"""
        
        # Base query - user's transactions
        filters = [
            or_(
                Transaction.sender == user.username,
                Transaction.receiver == user.username
            )
        ]
        
        # Text search (recipient/sender name)
        if query:
            filters.append(
                or_(
                    Transaction.sender.ilike(f"%{query}%"),
                    Transaction.receiver.ilike(f"%{query}%")
                )
            )
        
        # Amount filters
        if min_amount is not None:
            filters.append(Transaction.amount >= min_amount)
        if max_amount is not None:
            filters.append(Transaction.amount <= max_amount)
        
        # Date filters
        if start_date:
            filters.append(Transaction.created_at >= start_date)
        if end_date:
            filters.append(Transaction.created_at <= end_date)
        
        # Type filter
        if transaction_type:
            filters.append(Transaction.transaction_type == transaction_type)
        
        results = db.query(Transaction).filter(
            and_(*filters)
        ).order_by(Transaction.created_at.desc()).all()
        
        # Tag filter (post-query since it's a join)
        if tags:
            filtered_results = []
            for txn in results:
                txn_tags = db.query(TransactionTag).filter(
                    TransactionTag.transaction_id == txn.id
                ).all()
                txn_tag_names = [t.tag for t in txn_tags]
                if any(tag in txn_tag_names for tag in tags):
                    filtered_results.append(txn)
            return filtered_results
        
        return results


class SubWalletService:
    """Manage multiple wallets per user"""
    
    @staticmethod
    def create_wallet(
        user: User,
        name: str,
        wallet_type: str,
        icon: str = "wallet",
        color: str = "#DC143C",
        db: Session = None
    ) -> SubWallet:
        """Create a new sub-wallet"""
        wallet = SubWallet(
            user_id=user.id,
            name=name,
            wallet_type=wallet_type,
            icon=icon,
            color=color
        )
        
        db.add(wallet)
        db.commit()
        db.refresh(wallet)
        return wallet
    
    @staticmethod
    def get_wallets(user: User, db: Session) -> List[SubWallet]:
        """Get all user's wallets"""
        return db.query(SubWallet).filter(
            SubWallet.user_id == user.id
        ).all()
    
    @staticmethod
    def transfer_between_wallets(
        user: User,
        from_wallet_id: int,
        to_wallet_id: int,
        amount: float,
        db: Session
    ) -> Dict[str, Any]:
        """Transfer money between user's wallets"""
        from_wallet = db.query(SubWallet).filter(
            SubWallet.id == from_wallet_id,
            SubWallet.user_id == user.id
        ).first()
        
        to_wallet = db.query(SubWallet).filter(
            SubWallet.id == to_wallet_id,
            SubWallet.user_id == user.id
        ).first()
        
        if not from_wallet or not to_wallet:
            return {"success": False, "error": "Wallet not found"}
        
        if from_wallet.balance < amount:
            return {"success": False, "error": "Insufficient funds"}
        
        from_wallet.balance -= amount
        to_wallet.balance += amount
        
        db.commit()
        
        return {
            "success": True,
            "from_balance": from_wallet.balance,
            "to_balance": to_wallet.balance
        }


class QRLimitService:
    """Manage QR payment limits"""
    
    @staticmethod
    def get_or_create_limits(user: User, db: Session) -> QRPaymentLimit:
        """Get user's QR limits or create defaults"""
        limits = db.query(QRPaymentLimit).filter(
            QRPaymentLimit.user_id == user.id
        ).first()
        
        if not limits:
            limits = QRPaymentLimit(user_id=user.id)
            db.add(limits)
            db.commit()
            db.refresh(limits)
        
        # Reset daily total if new day
        if limits.today_date.date() < datetime.utcnow().date():
            limits.today_total = 0.0
            limits.today_date = datetime.utcnow()
            db.commit()
        
        return limits
    
    @staticmethod
    def check_limit(
        user: User,
        amount: float,
        db: Session
    ) -> Dict[str, Any]:
        """Check if payment is within limits"""
        limits = QRLimitService.get_or_create_limits(user, db)
        
        # Check per-transaction limit
        if amount > limits.max_per_transaction:
            return {
                "allowed": False,
                "error": f"Amount exceeds per-transaction limit of ${limits.max_per_transaction}"
            }
        
        # Check daily limit
        if limits.today_total + amount > limits.daily_limit:
            return {
                "allowed": False,
                "error": f"Would exceed daily limit of ${limits.daily_limit}"
            }
        
        # Check if biometric required
        requires_auth = amount > limits.require_auth_above
        
        return {
            "allowed": True,
            "requires_biometric": requires_auth,
            "remaining_today": limits.daily_limit - limits.today_total
        }
    
    @staticmethod
    def record_payment(user: User, amount: float, db: Session):
        """Record a QR payment against limits"""
        limits = QRLimitService.get_or_create_limits(user, db)
        limits.today_total += amount
        db.commit()
