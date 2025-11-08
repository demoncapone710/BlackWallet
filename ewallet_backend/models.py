from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True)
    password = Column(String)
    balance = Column(Float, default=0.0)
    is_admin = Column(Boolean, default=False)
    stripe_customer_id = Column(String, nullable=True)  # Stripe customer ID for payments
    stripe_account_id = Column(String, nullable=True)  # Stripe Connect account ID for receiving money
    # New fields for enhanced registration
    email = Column(String, unique=True, nullable=True)
    phone = Column(String, unique=True, nullable=True)
    full_name = Column(String, nullable=True)
    # Password reset fields
    password_reset_token = Column(String, nullable=True)
    reset_token_expiry = Column(DateTime, nullable=True)
    
    # Relationships (commented out - defined in separate model files)
    # virtual_cards = relationship("VirtualCard", back_populates="user")
    # pos_terminals = relationship("POSTerminal", back_populates="merchant")

class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(Integer, primary_key=True)
    sender = Column(String)
    receiver = Column(String)
    amount = Column(Float)
    transaction_type = Column(String, default="internal")  # internal, deposit, withdrawal, transfer, topup
    external_provider = Column(String, nullable=True)  # stripe, paypal, etc.
    external_transaction_id = Column(String, nullable=True)  # ID from external provider
    stripe_payment_id = Column(String, nullable=True)  # Stripe PaymentIntent ID
    stripe_transfer_id = Column(String, nullable=True)  # Stripe Transfer ID
    stripe_payout_id = Column(String, nullable=True)  # Stripe Payout ID
    status = Column(String, default="completed")  # pending, completed, failed
    created_at = Column(DateTime, default=datetime.utcnow)
    extra_data = Column(JSON, nullable=True)  # Additional info (renamed from metadata)

class PaymentMethod(Base):
    __tablename__ = "payment_methods"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    stripe_payment_method_id = Column(String)  # Stripe payment method ID
    method_type = Column(String)  # card, bank_account
    last4 = Column(String)  # Last 4 digits
    brand = Column(String, nullable=True)  # visa, mastercard, etc.
    is_default = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
