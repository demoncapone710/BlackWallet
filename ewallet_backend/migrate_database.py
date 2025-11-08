"""
Database Migration Script
Adds new user fields: email, phone, full_name, password_reset_token, reset_token_expiry
"""
import sqlite3
import logging

logger = logging.getLogger(__name__)

def migrate_database():
    """Add new columns to the users table"""
    try:
        # Connect to SQLite database
        conn = sqlite3.connect('blackwallet.db')
        cursor = conn.cursor()
        
        # Check if columns already exist
        cursor.execute("PRAGMA table_info(users)")
        columns = [column[1] for column in cursor.fetchall()]
        
        migrations_applied = []
        
        # Add email column if it doesn't exist
        if 'email' not in columns:
            cursor.execute("ALTER TABLE users ADD COLUMN email TEXT")
            cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email)")
            migrations_applied.append('email')
            logger.info("Added email column to users table")
        
        # Add phone column if it doesn't exist
        if 'phone' not in columns:
            cursor.execute("ALTER TABLE users ADD COLUMN phone TEXT")
            cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone ON users(phone)")
            migrations_applied.append('phone')
            logger.info("Added phone column to users table")
        
        # Add full_name column if it doesn't exist
        if 'full_name' not in columns:
            cursor.execute("ALTER TABLE users ADD COLUMN full_name TEXT")
            migrations_applied.append('full_name')
            logger.info("Added full_name column to users table")
        
        # Add password_reset_token column if it doesn't exist
        if 'password_reset_token' not in columns:
            cursor.execute("ALTER TABLE users ADD COLUMN password_reset_token TEXT")
            migrations_applied.append('password_reset_token')
            logger.info("Added password_reset_token column to users table")
        
        # Add reset_token_expiry column if it doesn't exist
        if 'reset_token_expiry' not in columns:
            cursor.execute("ALTER TABLE users ADD COLUMN reset_token_expiry DATETIME")
            migrations_applied.append('reset_token_expiry')
            logger.info("Added reset_token_expiry column to users table")
        
        # Commit changes
        conn.commit()
        conn.close()
        
        if migrations_applied:
            logger.info(f"Migration completed! Added columns: {', '.join(migrations_applied)}")
            return True, f"Successfully added {len(migrations_applied)} new columns"
        else:
            logger.info("No migration needed - all columns already exist")
            return True, "Database is already up to date"
    
    except Exception as e:
        logger.error(f"Migration failed: {e}")
        return False, f"Migration failed: {str(e)}"

if __name__ == "__main__":
    # Setup basic logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    print("=" * 60)
    print("BlackWallet Database Migration")
    print("=" * 60)
    print()
    
    success, message = migrate_database()
    
    print()
    if success:
        print("✅ " + message)
    else:
        print("❌ " + message)
    
    print()
    print("=" * 60)
