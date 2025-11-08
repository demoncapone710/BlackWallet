"""
Enhanced Models for Quick Win Features
"""
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base


class Favorite(Base):
    """Favorite recipients for quick transfers"""
    __tablename__ = "favorites"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    recipient_username = Column(String)
    recipient_type = Column(String)  # username, phone, email, bank
    recipient_identifier = Column(String)  # The actual identifier
    nickname = Column(String, nullable=True)  # Custom name
    last_used = Column(DateTime, nullable=True)
    use_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)


class ScheduledPayment(Base):
    """Scheduled/recurring payments"""
    __tablename__ = "scheduled_payments"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    recipient_username = Column(String)
    recipient_type = Column(String)  # username, phone, email, bank
    recipient_identifier = Column(String)
    amount = Column(Float)
    note = Column(String, nullable=True)
    
    # Scheduling
    schedule_type = Column(String)  # once, daily, weekly, monthly, biweekly
    scheduled_date = Column(DateTime)  # When to execute
    next_execution = Column(DateTime)  # Next execution time
    last_execution = Column(DateTime, nullable=True)
    
    # Status
    status = Column(String, default="pending")  # pending, completed, failed, cancelled
    is_recurring = Column(Boolean, default=False)
    execution_count = Column(Integer, default=0)
    
    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class PaymentLink(Base):
    """Shareable payment links"""
    __tablename__ = "payment_links"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    link_code = Column(String, unique=True, index=True)  # Short code for URL
    
    # Payment details
    amount = Column(Float, nullable=True)  # Null = variable amount
    description = Column(String, nullable=True)
    
    # Limits
    max_uses = Column(Integer, nullable=True)  # Null = unlimited
    current_uses = Column(Integer, default=0)
    expires_at = Column(DateTime, nullable=True)
    
    # Status
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Statistics
    total_collected = Column(Float, default=0.0)


class TransactionTag(Base):
    """Tags for categorizing transactions"""
    __tablename__ = "transaction_tags"
    
    id = Column(Integer, primary_key=True, index=True)
    transaction_id = Column(Integer, ForeignKey("transactions.id"))
    tag = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)


class SubWallet(Base):
    """Multiple wallets per user (Personal, Business, Savings)"""
    __tablename__ = "sub_wallets"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String)  # Personal, Business, Savings, etc.
    wallet_type = Column(String)  # personal, business, savings
    balance = Column(Float, default=0.0)
    
    # Settings
    icon = Column(String, default="wallet")
    color = Column(String, default="#DC143C")
    is_default = Column(Boolean, default=False)
    
    # Limits
    spending_limit = Column(Float, nullable=True)  # Daily spending limit
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class QRPaymentLimit(Base):
    """Security limits for QR code payments"""
    __tablename__ = "qr_payment_limits"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True)
    
    # Limits
    max_per_transaction = Column(Float, default=500.0)
    daily_limit = Column(Float, default=1000.0)
    require_auth_above = Column(Float, default=100.0)  # Require biometric above this
    
    # Today's stats
    today_total = Column(Float, default=0.0)
    today_date = Column(DateTime, default=datetime.utcnow)
    
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
