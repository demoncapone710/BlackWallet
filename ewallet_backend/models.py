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
    
    # Basic Information
    email = Column(String, unique=True, nullable=True)
    phone = Column(String, unique=True, nullable=True)
    full_name = Column(String, nullable=True)
    
    # Address Information (required for Stripe Connect)
    address_line1 = Column(String, nullable=True)
    address_line2 = Column(String, nullable=True)
    city = Column(String, nullable=True)
    state = Column(String, nullable=True)
    postal_code = Column(String, nullable=True)
    country = Column(String, default="US")
    
    # Personal Information (required for identity verification)
    date_of_birth = Column(String, nullable=True)  # YYYY-MM-DD format
    ssn_last_4 = Column(String, nullable=True)  # Last 4 digits only for security
    
    # Business Information (optional, for business accounts)
    business_name = Column(String, nullable=True)
    business_type = Column(String, default="individual")  # individual, company, non_profit
    business_tax_id = Column(String, nullable=True)  # EIN for businesses
    
    # Account Status
    profile_complete = Column(Boolean, default=False)
    kyc_verified = Column(Boolean, default=False)  # Know Your Customer verification status
    account_created_at = Column(DateTime, default=datetime.utcnow)
    last_login_at = Column(DateTime, nullable=True)
    
    # Password reset fields
    password_reset_token = Column(String, nullable=True)
    reset_token_expiry = Column(DateTime, nullable=True)
    
    # Offline mode support
    offline_mode_enabled = Column(Boolean, default=True)
    last_sync_at = Column(DateTime, nullable=True)
    
    # Relationships (commented out - defined in separate model files)
    # virtual_cards = relationship("VirtualCard", back_populates="user")
    # pos_terminals = relationship("POSTerminal", back_populates="merchant")

class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(Integer, primary_key=True)
    sender = Column(String)
    receiver = Column(String)
    amount = Column(Float)
    transaction_type = Column(String, default="internal")  # internal, deposit, withdrawal, transfer, topup, nfc_payment, money_invite
    external_provider = Column(String, nullable=True)  # stripe, paypal, etc.
    external_transaction_id = Column(String, nullable=True)  # ID from external provider
    stripe_payment_id = Column(String, nullable=True)  # Stripe PaymentIntent ID
    stripe_transfer_id = Column(String, nullable=True)  # Stripe Transfer ID
    stripe_payout_id = Column(String, nullable=True)  # Stripe Payout ID
    status = Column(String, default="completed")  # pending, completed, failed, queued_offline, refunded
    created_at = Column(DateTime, default=datetime.utcnow)
    processed_at = Column(DateTime, nullable=True)  # When transaction was actually processed
    is_offline = Column(Boolean, default=False)  # Created while offline
    device_id = Column(String, nullable=True)  # Device that created offline transaction
    
    # Invite tracking fields
    invite_id = Column(Integer, nullable=True)  # Link to MoneyInvite if this is an invite transaction
    invite_method = Column(String, nullable=True)  # email, phone, username
    invite_recipient = Column(String, nullable=True)  # Email, phone, or username
    
    extra_data = Column(JSON, nullable=True)  # Additional info (renamed from metadata)


class MoneyInvite(Base):
    """Money invites sent via email or phone"""
    __tablename__ = "money_invites"
    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer)  # User ID of sender
    sender_username = Column(String)  # Username of sender
    
    # Recipient information
    recipient_method = Column(String)  # email, phone, username
    recipient_contact = Column(String)  # Email address, phone number, or username
    recipient_user_id = Column(Integer, nullable=True)  # Set when recipient accepts
    
    # Transaction details
    amount = Column(Float)
    message = Column(String, nullable=True)  # Optional message from sender
    transaction_id = Column(Integer, nullable=True)  # Initial transaction (funds held)
    refund_transaction_id = Column(Integer, nullable=True)  # Refund transaction if expired
    
    # Status tracking
    status = Column(String, default="pending")  # pending, delivered, opened, accepted, declined, expired, refunded
    invite_token = Column(String, unique=True)  # Unique token for invite link
    
    # Tracking timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    delivered_at = Column(DateTime, nullable=True)  # When notification was delivered
    opened_at = Column(DateTime, nullable=True)  # When recipient opened the invite
    responded_at = Column(DateTime, nullable=True)  # When recipient accepted/declined
    expires_at = Column(DateTime)  # 24 hours from creation
    refunded_at = Column(DateTime, nullable=True)  # When funds were returned
    
    # Notification tracking
    notification_sent = Column(Boolean, default=False)
    notification_delivered = Column(Boolean, default=False)
    email_sent = Column(Boolean, default=False)
    sms_sent = Column(Boolean, default=False)
    
    extra_data = Column(JSON, nullable=True)  # Additional metadata


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


class Notification(Base):
    """Push notifications sent to users"""
    __tablename__ = "notifications"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=True)  # NULL for broadcast to all users
    title = Column(String)
    message = Column(String)
    notification_type = Column(String, default="general")  # general, transaction, promotion, system
    is_read = Column(Boolean, default=False)
    sent_at = Column(DateTime, default=datetime.utcnow)
    extra_data = Column(JSON, nullable=True)  # Additional metadata


class Advertisement(Base):
    """Advertisements displayed in the app"""
    __tablename__ = "advertisements"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String)
    description = Column(String)
    image_url = Column(String, nullable=True)
    link_url = Column(String, nullable=True)
    ad_type = Column(String, default="banner")  # banner, popup, interstitial
    target_audience = Column(String, default="all")  # all, new_users, active_users, custom
    is_active = Column(Boolean, default=True)
    impressions = Column(Integer, default=0)  # Number of times displayed
    clicks = Column(Integer, default=0)  # Number of times clicked
    start_date = Column(DateTime, default=datetime.utcnow)
    end_date = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    created_by = Column(Integer)  # Admin user ID


class Promotion(Base):
    """Promotional offers and campaigns"""
    __tablename__ = "promotions"
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True)  # Promo code (e.g., SUMMER2025)
    title = Column(String)
    description = Column(String)
    promotion_type = Column(String, default="bonus")  # bonus, discount, cashback, referral
    value = Column(Float)  # Amount or percentage
    value_type = Column(String, default="fixed")  # fixed, percentage
    min_transaction = Column(Float, default=0)  # Minimum transaction to qualify
    max_uses = Column(Integer, nullable=True)  # Max number of uses (NULL = unlimited)
    uses_count = Column(Integer, default=0)  # Current number of uses
    uses_per_user = Column(Integer, default=1)  # Max uses per user
    is_active = Column(Boolean, default=True)
    start_date = Column(DateTime, default=datetime.utcnow)
    end_date = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    created_by = Column(Integer)  # Admin user ID


class CustomerMessage(Base):
    """Messages between admin and customers"""
    __tablename__ = "customer_messages"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer)  # Customer user ID
    admin_id = Column(Integer, nullable=True)  # Admin who sent/replied
    subject = Column(String)
    message = Column(String)
    message_type = Column(String, default="support")  # support, marketing, notification
    direction = Column(String, default="admin_to_user")  # admin_to_user, user_to_admin
    is_read = Column(Boolean, default=False)
    parent_message_id = Column(Integer, nullable=True)  # For threading replies
    created_at = Column(DateTime, default=datetime.utcnow)
    extra_data = Column(JSON, nullable=True)


class PromotionUsage(Base):
    """Track promotion code usage by users"""
    __tablename__ = "promotion_usage"
    id = Column(Integer, primary_key=True, index=True)
    promotion_id = Column(Integer)
    user_id = Column(Integer)
    transaction_id = Column(Integer, nullable=True)
    amount_saved = Column(Float)  # Amount saved/earned
    used_at = Column(DateTime, default=datetime.utcnow)
