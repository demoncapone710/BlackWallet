"""
Stripe Connect Integration for Real Money Transfers
Enables users to link bank accounts and make real transactions
"""
import stripe
from typing import Dict, Optional
import logging
from config import settings

logger = logging.getLogger(__name__)

# Initialize Stripe
stripe.api_key = settings.STRIPE_SECRET_KEY


class StripePaymentService:
    """Handle real money transactions via Stripe Connect"""
    
    @staticmethod
    async def create_connected_account(user_id: int, email: str, country: str = "US") -> Dict:
        """
        Create a Stripe Connect account for a user
        This allows them to receive payments
        """
        try:
            account = stripe.Account.create(
                type="express",  # or "standard" for more control
                country=country,
                email=email,
                capabilities={
                    "card_payments": {"requested": True},
                    "transfers": {"requested": True},
                },
                business_type="individual",
                metadata={"user_id": str(user_id)}
            )
            
            logger.info(f"Created Stripe account for user {user_id}: {account.id}")
            return {
                "stripe_account_id": account.id,
                "onboarding_required": True
            }
        except stripe.error.StripeError as e:
            logger.error(f"Stripe account creation failed: {e}")
            raise Exception(f"Failed to create payment account: {str(e)}")
    
    @staticmethod
    async def create_account_link(stripe_account_id: str, refresh_url: str, return_url: str) -> str:
        """
        Generate onboarding link for user to complete Stripe setup
        User needs to provide business info, bank account, etc.
        """
        try:
            account_link = stripe.AccountLink.create(
                account=stripe_account_id,
                refresh_url=refresh_url,
                return_url=return_url,
                type="account_onboarding",
            )
            return account_link.url
        except stripe.error.StripeError as e:
            logger.error(f"Account link creation failed: {e}")
            raise Exception(f"Failed to create onboarding link: {str(e)}")
    
    @staticmethod
    async def add_bank_account(user_id: int, stripe_account_id: str, bank_token: str) -> Dict:
        """
        Add a bank account to user's Stripe account
        bank_token comes from Stripe.js on frontend
        """
        try:
            # Create external account (bank account)
            account = stripe.Account.create_external_account(
                stripe_account_id,
                external_account=bank_token,
            )
            
            logger.info(f"Added bank account for user {user_id}")
            return {
                "bank_id": account.id,
                "last4": account.last4,
                "bank_name": account.bank_name,
                "status": account.status
            }
        except stripe.error.StripeError as e:
            logger.error(f"Bank account addition failed: {e}")
            raise Exception(f"Failed to add bank account: {str(e)}")
    
    @staticmethod
    async def create_transfer(
        sender_id: int,
        recipient_stripe_account: str,
        amount: float,
        currency: str = "usd",
        description: str = ""
    ) -> Dict:
        """
        Transfer real money from platform to user's connected account
        Amount in dollars (will be converted to cents)
        """
        try:
            amount_cents = int(amount * 100)  # Convert to cents
            
            transfer = stripe.Transfer.create(
                amount=amount_cents,
                currency=currency,
                destination=recipient_stripe_account,
                description=description,
                metadata={"sender_id": str(sender_id)}
            )
            
            logger.info(f"Transfer created: {transfer.id} for ${amount}")
            return {
                "transfer_id": transfer.id,
                "amount": amount,
                "status": "completed",
                "created": transfer.created
            }
        except stripe.error.StripeError as e:
            logger.error(f"Transfer failed: {e}")
            raise Exception(f"Transfer failed: {str(e)}")
    
    @staticmethod
    async def create_payment_intent(
        user_id: int,
        amount: float,
        currency: str = "usd",
        payment_method: Optional[str] = None
    ) -> Dict:
        """
        Create a payment intent for user to add money to their wallet
        This charges their card/bank and credits your platform
        """
        try:
            amount_cents = int(amount * 100)
            
            intent = stripe.PaymentIntent.create(
                amount=amount_cents,
                currency=currency,
                payment_method=payment_method,
                confirmation_method="automatic",
                confirm=True if payment_method else False,
                metadata={"user_id": str(user_id), "type": "wallet_topup"}
            )
            
            logger.info(f"Payment intent created for user {user_id}: ${amount}")
            return {
                "intent_id": intent.id,
                "client_secret": intent.client_secret,
                "status": intent.status,
                "amount": amount
            }
        except stripe.error.StripeError as e:
            logger.error(f"Payment intent failed: {e}")
            raise Exception(f"Payment failed: {str(e)}")
    
    @staticmethod
    async def create_payout(stripe_account_id: str, amount: float, currency: str = "usd") -> Dict:
        """
        Withdraw money from user's Stripe balance to their bank account
        """
        try:
            amount_cents = int(amount * 100)
            
            payout = stripe.Payout.create(
                amount=amount_cents,
                currency=currency,
                stripe_account=stripe_account_id
            )
            
            logger.info(f"Payout created: {payout.id} for ${amount}")
            return {
                "payout_id": payout.id,
                "amount": amount,
                "status": payout.status,
                "arrival_date": payout.arrival_date
            }
        except stripe.error.StripeError as e:
            logger.error(f"Payout failed: {e}")
            raise Exception(f"Payout failed: {str(e)}")
    
    @staticmethod
    async def verify_account_status(stripe_account_id: str) -> Dict:
        """
        Check if user has completed onboarding and can receive payments
        """
        try:
            account = stripe.Account.retrieve(stripe_account_id)
            
            return {
                "account_id": account.id,
                "charges_enabled": account.charges_enabled,
                "payouts_enabled": account.payouts_enabled,
                "details_submitted": account.details_submitted,
                "requirements": account.requirements.currently_due if account.requirements else []
            }
        except stripe.error.StripeError as e:
            logger.error(f"Account verification failed: {e}")
            raise Exception(f"Failed to verify account: {str(e)}")
    
    @staticmethod
    async def get_balance(stripe_account_id: str) -> Dict:
        """
        Get user's Stripe balance (pending and available)
        """
        try:
            balance = stripe.Balance.retrieve(
                stripe_account=stripe_account_id
            )
            
            available = sum([b.amount for b in balance.available]) / 100
            pending = sum([b.amount for b in balance.pending]) / 100
            
            return {
                "available": available,
                "pending": pending,
                "currency": balance.available[0].currency if balance.available else "usd"
            }
        except stripe.error.StripeError as e:
            logger.error(f"Balance retrieval failed: {e}")
            raise Exception(f"Failed to get balance: {str(e)}")


class PlaidBankService:
    """
    Alternative: Use Plaid for direct bank transfers (ACH)
    More complex but lower fees than Stripe
    """
    
    @staticmethod
    async def create_link_token(user_id: int) -> str:
        """
        Create a link token for Plaid Link (bank account connection)
        Requires PLAID_CLIENT_ID and PLAID_SECRET
        """
        # Implementation would use plaid-python library
        # This is a placeholder showing the concept
        pass
    
    @staticmethod
    async def exchange_public_token(public_token: str) -> Dict:
        """
        Exchange public token from Plaid Link for access token
        """
        pass
    
    @staticmethod
    async def initiate_ach_transfer(
        sender_account_id: str,
        recipient_account_id: str,
        amount: float
    ) -> Dict:
        """
        Initiate ACH transfer between two bank accounts
        Takes 1-3 business days
        """
        pass
