"""
Migration script to add money invite system and transaction tracking
Adds MoneyInvite table and new fields to Transaction table
"""
import sqlite3
from datetime import datetime

def migrate():
    conn = sqlite3.connect('ewallet.db')
    cursor = conn.cursor()
    
    print("Starting migration for invite system and transaction tracking...")
    
    try:
        # Add new fields to transactions table
        print("Adding new fields to transactions table...")
        
        # Add invite_id field
        try:
            cursor.execute("ALTER TABLE transactions ADD COLUMN invite_id INTEGER")
            print("✓ Added invite_id column")
        except sqlite3.OperationalError as e:
            if "duplicate column name" in str(e):
                print("  - invite_id column already exists")
            else:
                raise
        
        # Add invite_method field
        try:
            cursor.execute("ALTER TABLE transactions ADD COLUMN invite_method TEXT")
            print("✓ Added invite_method column")
        except sqlite3.OperationalError as e:
            if "duplicate column name" in str(e):
                print("  - invite_method column already exists")
            else:
                raise
        
        # Add invite_recipient field
        try:
            cursor.execute("ALTER TABLE transactions ADD COLUMN invite_recipient TEXT")
            print("✓ Added invite_recipient column")
        except sqlite3.OperationalError as e:
            if "duplicate column name" in str(e):
                print("  - invite_recipient column already exists")
            else:
                raise
        
        # Update status field to include new statuses (already text, just document)
        print("✓ Transaction status field supports: pending, completed, failed, queued_offline, refunded")
        
        conn.commit()
        
        # Create money_invites table
        print("\nCreating money_invites table...")
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS money_invites (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sender_id INTEGER NOT NULL,
                sender_username TEXT NOT NULL,
                recipient_method TEXT NOT NULL,
                recipient_contact TEXT NOT NULL,
                recipient_user_id INTEGER,
                amount REAL NOT NULL,
                message TEXT,
                transaction_id INTEGER,
                refund_transaction_id INTEGER,
                status TEXT DEFAULT 'pending',
                invite_token TEXT UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                delivered_at TIMESTAMP,
                opened_at TIMESTAMP,
                responded_at TIMESTAMP,
                expires_at TIMESTAMP NOT NULL,
                refunded_at TIMESTAMP,
                notification_sent BOOLEAN DEFAULT 0,
                notification_delivered BOOLEAN DEFAULT 0,
                email_sent BOOLEAN DEFAULT 0,
                sms_sent BOOLEAN DEFAULT 0,
                extra_data TEXT
            )
        """)
        print("✓ Created money_invites table")
        
        # Create indexes for better performance
        print("\nCreating indexes...")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_money_invites_sender ON money_invites(sender_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_money_invites_recipient ON money_invites(recipient_contact)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_money_invites_status ON money_invites(status)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_money_invites_token ON money_invites(invite_token)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_money_invites_expires ON money_invites(expires_at)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_transactions_invite ON transactions(invite_id)")
        print("✓ Created indexes")
        
        conn.commit()
        
        print("\n✅ Migration completed successfully!")
        print("\nNew features enabled:")
        print("  - Send money via email or phone")
        print("  - Track invite delivery status")
        print("  - Track when recipient opens invite")
        print("  - Auto-refund after 24 hours if not accepted")
        print("  - Transaction status tracking (pending/complete)")
        
    except Exception as e:
        print(f"\n❌ Migration failed: {e}")
        conn.rollback()
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()
