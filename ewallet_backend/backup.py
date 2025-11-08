"""
Automated Database Backup System
Handles scheduled backups, compression, and retention policy
"""
import os
import shutil
import sqlite3
import gzip
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import List
import asyncio

from config import settings

logger = logging.getLogger(__name__)


class BackupManager:
    """Manages database backups with rotation and compression"""
    
    def __init__(self):
        self.backup_dir = Path(settings.BACKUP_DIRECTORY)
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = "ewallet.db"  # SQLite database
        
    def create_backup(self) -> str:
        """Create a compressed backup of the database"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_name = f"blackwallet_backup_{timestamp}.db"
            backup_path = self.backup_dir / backup_name
            compressed_path = self.backup_dir / f"{backup_name}.gz"
            
            logger.info(f"Starting database backup: {backup_name}")
            
            # For SQLite: Use backup API for consistent snapshot
            if os.path.exists(self.db_path):
                source_conn = sqlite3.connect(self.db_path)
                backup_conn = sqlite3.connect(str(backup_path))
                
                # Perform backup
                with backup_conn:
                    source_conn.backup(backup_conn)
                
                source_conn.close()
                backup_conn.close()
                
                # Compress the backup
                with open(backup_path, 'rb') as f_in:
                    with gzip.open(compressed_path, 'wb', compresslevel=9) as f_out:
                        shutil.copyfileobj(f_in, f_out)
                
                # Remove uncompressed backup
                os.remove(backup_path)
                
                file_size = os.path.getsize(compressed_path) / (1024 * 1024)  # MB
                logger.info(
                    f"Backup completed successfully: {compressed_path.name} ({file_size:.2f} MB)"
                )
                
                return str(compressed_path)
            else:
                logger.warning(f"Database file not found: {self.db_path}")
                return None
                
        except Exception as e:
            logger.error(f"Backup failed: {e}", exc_info=True)
            return None
    
    def cleanup_old_backups(self):
        """Remove backups older than retention period"""
        try:
            cutoff_date = datetime.now() - timedelta(days=settings.BACKUP_RETENTION_DAYS)
            removed_count = 0
            
            for backup_file in self.backup_dir.glob("blackwallet_backup_*.db.gz"):
                # Extract timestamp from filename
                try:
                    timestamp_str = backup_file.stem.replace('blackwallet_backup_', '').replace('.db', '')
                    file_date = datetime.strptime(timestamp_str, "%Y%m%d_%H%M%S")
                    
                    if file_date < cutoff_date:
                        backup_file.unlink()
                        removed_count += 1
                        logger.info(f"Removed old backup: {backup_file.name}")
                except ValueError:
                    logger.warning(f"Could not parse date from backup file: {backup_file.name}")
            
            if removed_count > 0:
                logger.info(f"Cleaned up {removed_count} old backups")
                
        except Exception as e:
            logger.error(f"Backup cleanup failed: {e}", exc_info=True)
    
    def list_backups(self) -> List[dict]:
        """List all available backups"""
        backups = []
        
        for backup_file in sorted(self.backup_dir.glob("blackwallet_backup_*.db.gz"), reverse=True):
            try:
                timestamp_str = backup_file.stem.replace('blackwallet_backup_', '').replace('.db', '')
                file_date = datetime.strptime(timestamp_str, "%Y%m%d_%H%M%S")
                file_size = os.path.getsize(backup_file) / (1024 * 1024)  # MB
                
                backups.append({
                    "filename": backup_file.name,
                    "date": file_date.isoformat(),
                    "size_mb": round(file_size, 2),
                    "path": str(backup_file)
                })
            except Exception as e:
                logger.warning(f"Error processing backup file {backup_file.name}: {e}")
        
        return backups
    
    def restore_backup(self, backup_filename: str) -> bool:
        """Restore database from a backup"""
        try:
            backup_path = self.backup_dir / backup_filename
            
            if not backup_path.exists():
                logger.error(f"Backup file not found: {backup_filename}")
                return False
            
            # Create a safety backup of current database
            if os.path.exists(self.db_path):
                safety_backup = f"{self.db_path}.before_restore_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                shutil.copy2(self.db_path, safety_backup)
                logger.info(f"Created safety backup: {safety_backup}")
            
            # Decompress backup
            temp_db = f"{self.db_path}.temp"
            with gzip.open(backup_path, 'rb') as f_in:
                with open(temp_db, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)
            
            # Replace current database
            if os.path.exists(self.db_path):
                os.remove(self.db_path)
            shutil.move(temp_db, self.db_path)
            
            logger.info(f"Database restored successfully from {backup_filename}")
            return True
            
        except Exception as e:
            logger.error(f"Restore failed: {e}", exc_info=True)
            return False


# Background backup task
async def backup_scheduler():
    """Run periodic backups in the background"""
    backup_manager = BackupManager()
    
    while True:
        try:
            if settings.BACKUP_ENABLED:
                logger.info("Starting scheduled backup")
                backup_manager.create_backup()
                backup_manager.cleanup_old_backups()
                logger.info(f"Next backup in {settings.BACKUP_INTERVAL_HOURS} hours")
            
            # Wait for next backup interval
            await asyncio.sleep(settings.BACKUP_INTERVAL_HOURS * 3600)
            
        except Exception as e:
            logger.error(f"Backup scheduler error: {e}", exc_info=True)
            await asyncio.sleep(300)  # Wait 5 minutes before retry


def get_backup_manager() -> BackupManager:
    """Get backup manager instance"""
    return BackupManager()
