"""
Virtual Card System for BlackWallet
Generates virtual cards that work with POS, ATM, and online merchants
Compatible with Visa/Mastercard networks through tokenization
"""
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime, timedelta
import secrets
import hashlib


class VirtualCard(Base):
    """Virtual debit card linked to user's wallet balance"""
    __tablename__ = "virtual_cards"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    
    # Card details (PCI compliant storage needed in production)
    card_number = Column(String, unique=True, index=True)  # 16 digits
    cvv = Column(String)  # 3-4 digits (encrypted in production)
    expiry_month = Column(Integer)
    expiry_year = Column(Integer)
    
    # Card holder info
    cardholder_name = Column(String)
    billing_zip = Column(String)
    
    # Card status
    status = Column(String, default="active")  # active, frozen, expired, closed
    card_type = Column(String, default="virtual")  # virtual, physical
    network = Column(String, default="visa")  # visa, mastercard
    
    # Limits and controls
    daily_limit = Column(Float, default=1000.00)
    transaction_limit = Column(Float, default=500.00)
    atm_enabled = Column(Boolean, default=True)
    online_enabled = Column(Boolean, default=True)
    contactless_enabled = Column(Boolean, default=True)
    international_enabled = Column(Boolean, default=False)
    
    # Tracking
    created_at = Column(DateTime, default=datetime.utcnow)
    last_used = Column(DateTime)
    total_spent = Column(Float, default=0.0)
    
    # Relationships
    user = relationship("User", foreign_keys=[user_id])  # No back_populates - one-way relationship
    transactions = relationship("CardTransaction", back_populates="card")


class CardTransaction(Base):
    """Track all card transactions from POS, ATM, online"""
    __tablename__ = "card_transactions"
    
    id = Column(Integer, primary_key=True, index=True)
    card_id = Column(Integer, ForeignKey("virtual_cards.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    
    # Transaction details
    amount = Column(Float)
    currency = Column(String, default="USD")
    merchant_name = Column(String)
    merchant_category = Column(String)  # MCC code
    merchant_location = Column(String)
    
    # Transaction type
    transaction_type = Column(String)  # purchase, atm_withdrawal, refund, reversal
    entry_mode = Column(String)  # chip, swipe, contactless, online, atm
    
    # Status and verification
    status = Column(String)  # pending, approved, declined, reversed
    decline_reason = Column(String, nullable=True)
    auth_code = Column(String)  # Authorization code
    
    # Security
    risk_score = Column(Float)  # 0-100, fraud detection score
    three_ds_verified = Column(Boolean, default=False)  # 3D Secure
    cvv_verified = Column(Boolean, default=False)
    zip_verified = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    settled_at = Column(DateTime, nullable=True)
    
    # Relationships
    card = relationship("VirtualCard", back_populates="transactions")
    user = relationship("User", foreign_keys=[user_id])  # One-way relationship


class InteracWalletConnection(Base):
    """Connect with other e-wallets for interoperability"""
    __tablename__ = "interac_connections"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    
    # Connected wallet info
    wallet_provider = Column(String)  # venmo, cashapp, paypal, zelle, etc.
    wallet_identifier = Column(String)  # username, email, phone
    connection_token = Column(String)  # OAuth token or API key
    
    # Status
    status = Column(String, default="pending")  # pending, active, suspended
    verified = Column(Boolean, default=False)
    
    # Limits
    daily_send_limit = Column(Float, default=500.00)
    daily_receive_limit = Column(Float, default=2000.00)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    last_sync = Column(DateTime)


class ATMTransaction(Base):
    """Specific tracking for ATM withdrawals"""
    __tablename__ = "atm_transactions"
    
    id = Column(Integer, primary_key=True, index=True)
    card_id = Column(Integer, ForeignKey("virtual_cards.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    
    # ATM details
    atm_id = Column(String)
    atm_location = Column(String)
    atm_network = Column(String)  # Plus, Cirrus, Allpoint, etc.
    
    # Transaction
    amount = Column(Float)
    fee = Column(Float, default=0.0)  # ATM fee
    auth_code = Column(String)
    
    # Security
    pin_verified = Column(Boolean)
    chip_used = Column(Boolean)
    
    status = Column(String)  # approved, declined
    decline_reason = Column(String, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)


class POSTerminal(Base):
    """Register POS terminals for merchants"""
    __tablename__ = "pos_terminals"
    
    id = Column(Integer, primary_key=True, index=True)
    merchant_id = Column(Integer, ForeignKey("users.id"))
    
    # Terminal info
    terminal_id = Column(String, unique=True, index=True)
    terminal_name = Column(String)
    terminal_type = Column(String)  # fixed, mobile, online
    
    # Location
    location_name = Column(String)
    address = Column(String)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    
    # Configuration
    accepts_contactless = Column(Boolean, default=True)
    accepts_chip = Column(Boolean, default=True)
    accepts_swipe = Column(Boolean, default=True)
    accepts_manual = Column(Boolean, default=False)
    
    # Status
    status = Column(String, default="active")  # active, inactive, suspended
    
    # API keys for integration
    api_key = Column(String, unique=True)
    api_secret = Column(String)  # Hashed
    
    created_at = Column(DateTime, default=datetime.utcnow)
    last_transaction = Column(DateTime, nullable=True)


class GiftCardVoucher(Base):
    """Universal gift cards/vouchers that work anywhere"""
    __tablename__ = "gift_cards"
    
    id = Column(Integer, primary_key=True, index=True)
    
    # Card details
    card_number = Column(String, unique=True, index=True)  # 16-19 digits
    pin = Column(String)  # 4-6 digit PIN (hashed)
    card_type = Column(String)  # physical, digital, promotional
    
    # Value
    initial_value = Column(Float)
    current_balance = Column(Float)
    currency = Column(String, default="USD")
    
    # Ownership
    purchased_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    redeemed_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    
    # Restrictions
    merchant_restricted = Column(Boolean, default=False)
    allowed_merchants = Column(String, nullable=True)  # JSON list
    
    # Validity
    activation_date = Column(DateTime, default=datetime.utcnow)
    expiry_date = Column(DateTime, nullable=True)
    
    # Status
    status = Column(String, default="active")  # inactive, active, redeemed, expired, frozen
    
    # For retail sale
    batch_id = Column(String, nullable=True)
    retail_price = Column(Float, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    redeemed_at = Column(DateTime, nullable=True)


class WalletInteroperability(Base):
    """Cross-wallet transaction records"""
    __tablename__ = "cross_wallet_transactions"
    
    id = Column(Integer, primary_key=True, index=True)
    
    # Our side
    our_user_id = Column(Integer, ForeignKey("users.id"))
    
    # Other wallet
    external_wallet = Column(String)  # venmo, cashapp, etc.
    external_user_identifier = Column(String)
    external_transaction_id = Column(String)
    
    # Transaction
    amount = Column(Float)
    direction = Column(String)  # inbound, outbound
    status = Column(String)  # pending, completed, failed
    
    # Fees
    our_fee = Column(Float, default=0.0)
    external_fee = Column(Float, default=0.0)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)


# Add to User model relationships
"""
Add to models.py User class:

virtual_cards = relationship("VirtualCard", back_populates="user")
"""
