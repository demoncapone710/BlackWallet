"""
Stripe Connect Integration for Real Money Transfers
Enables users to link bank accounts and make real transactions
"""
import stripe
from typing import Dict, Optional
import logging
from config import settings

logger = logging.getLogger(__name__)

# Initialize Stripe based on mode
stripe_mode = settings.STRIPE_MODE.lower()
if stripe_mode == "live":
    stripe.api_key = settings.STRIPE_LIVE_SECRET_KEY
    if not stripe.api_key:
        raise ValueError("STRIPE_LIVE_SECRET_KEY is required when STRIPE_MODE=live")
    logger.info("🔴 Stripe Connect initialized in LIVE mode")
else:
    stripe.api_key = settings.STRIPE_SECRET_KEY
    if not stripe.api_key:
        raise ValueError("STRIPE_SECRET_KEY is required when STRIPE_MODE=test")
    logger.info("🧪 Stripe Connect initialized in TEST mode")


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
    
    @staticmethod
    async def get_account_status(stripe_account_id: str) -> Dict:
        """
        Get comprehensive account status for dashboard display
        """
        try:
            account = stripe.Account.retrieve(stripe_account_id)
            
            return {
                "onboarding_complete": account.details_submitted,
                "charges_enabled": account.charges_enabled,
                "payouts_enabled": account.payouts_enabled,
                "requirements_due": account.requirements.currently_due if account.requirements else [],
                "requirements_eventually_due": account.requirements.eventually_due if account.requirements else [],
                "disabled_reason": account.requirements.disabled_reason if account.requirements else None
            }
        except stripe.error.StripeError as e:
            logger.error(f"Failed to get account status: {e}")
            raise Exception(f"Failed to get account status: {str(e)}")
    
    @staticmethod
    async def list_bank_accounts(stripe_account_id: str) -> list:
        """
        List all bank accounts connected to user's Stripe account
        """
        try:
            account = stripe.Account.retrieve(stripe_account_id)
            external_accounts = stripe.Account.list_external_accounts(
                stripe_account_id,
                object="bank_account",
                limit=10
            )
            
            return [
                {
                    "id": ba.id,
                    "bank_name": ba.bank_name,
                    "last4": ba.last4,
                    "currency": ba.currency,
                    "status": ba.status,
                    "default": ba.default_for_currency
                }
                for ba in external_accounts.data
            ]
        except stripe.error.StripeError as e:
            logger.error(f"Failed to list bank accounts: {e}")
            raise Exception(f"Failed to list bank accounts: {str(e)}")
    
    @staticmethod
    async def process_deposit(user_id: int, amount: float, payment_method_id: str, stripe_account_id: str) -> Dict:
        """
        Process a deposit: charge user's payment method and add to wallet
        """
        try:
            amount_cents = int(amount * 100)
            
            # Create payment intent to charge the user
            payment_intent = stripe.PaymentIntent.create(
                amount=amount_cents,
                currency="usd",
                payment_method=payment_method_id,
                confirmation_method="automatic",
                confirm=True,
                metadata={
                    "user_id": str(user_id),
                    "type": "wallet_deposit",
                    "stripe_account_id": stripe_account_id
                }
            )
            
            logger.info(f"Deposit processed for user {user_id}: ${amount}")
            
            return {
                "transaction_id": payment_intent.id,
                "status": payment_intent.status,
                "amount": amount
            }
        except stripe.error.StripeError as e:
            logger.error(f"Deposit failed: {e}")
            raise Exception(f"Deposit failed: {str(e)}")
    
    @staticmethod
    async def process_withdrawal(user_id: int, amount: float, stripe_account_id: str) -> Dict:
        """
        Process a withdrawal: transfer from platform to user's bank account
        """
        try:
            amount_cents = int(amount * 100)
            
            # Create a payout to user's bank account
            payout = stripe.Payout.create(
                amount=amount_cents,
                currency="usd",
                stripe_account=stripe_account_id,
                metadata={
                    "user_id": str(user_id),
                    "type": "wallet_withdrawal"
                }
            )
            
            logger.info(f"Withdrawal processed for user {user_id}: ${amount}")
            
            return {
                "transaction_id": payout.id,
                "status": payout.status,
                "estimated_arrival": payout.arrival_date
            }
        except stripe.error.StripeError as e:
            logger.error(f"Withdrawal failed: {e}")
            raise Exception(f"Withdrawal failed: {str(e)}")
    
    @staticmethod
    async def get_transaction_history(stripe_account_id: str, limit: int = 10) -> list:
        """
        Get recent transactions (charges and payouts) for the account
        """
        try:
            # Get charges (deposits)
            charges = stripe.Charge.list(
                limit=limit,
                stripe_account=stripe_account_id
            )
            
            # Get payouts (withdrawals)
            payouts = stripe.Payout.list(
                limit=limit,
                stripe_account=stripe_account_id
            )
            
            transactions = []
            
            # Add charges
            for charge in charges.data:
                transactions.append({
                    "id": charge.id,
                    "type": "deposit",
                    "amount": charge.amount / 100,
                    "currency": charge.currency,
                    "status": charge.status,
                    "created": charge.created
                })
            
            # Add payouts
            for payout in payouts.data:
                transactions.append({
                    "id": payout.id,
                    "type": "withdrawal",
                    "amount": payout.amount / 100,
                    "currency": payout.currency,
                    "status": payout.status,
                    "created": payout.created,
                    "arrival_date": payout.arrival_date
                })
            
            # Sort by creation date (newest first)
            transactions.sort(key=lambda x: x["created"], reverse=True)
            
            return transactions[:limit]
        except stripe.error.StripeError as e:
            logger.error(f"Failed to get transaction history: {e}")
            raise Exception(f"Failed to get transaction history: {str(e)}")


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
