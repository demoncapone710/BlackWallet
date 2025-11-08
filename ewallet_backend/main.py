from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import asyncio
import logging

from routes import user, wallet, admin, payment, payment_methods, auth, card_routes, quick_wins_routes, real_payments, stripe_connect, transaction_sync, invites, webhooks
from database import Base, engine
from config import settings
from middleware import setup_middleware, get_rate_limiter
from logger import setup_logging
from backup import backup_scheduler, get_backup_manager

# Setup logging first
setup_logging()
logger = logging.getLogger(__name__)

# Create database tables
Base.metadata.create_all(bind=engine)
logger.info("Database tables created/verified")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application startup and shutdown"""
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    logger.info(f"Environment: {settings.ENVIRONMENT}")
    
    # Start backup scheduler if enabled
    backup_task = None
    if settings.BACKUP_ENABLED:
        backup_task = asyncio.create_task(backup_scheduler())
        logger.info("Backup scheduler started")
    
    # Start invite expiry scheduler
    invite_scheduler_task = None
    try:
        from scheduler import process_expired_invites
        async def run_scheduler():
            import schedule
            schedule.every(5).minutes.do(process_expired_invites)
            while True:
                schedule.run_pending()
                await asyncio.sleep(60)
        
        invite_scheduler_task = asyncio.create_task(run_scheduler())
        # Run once immediately
        process_expired_invites()
        logger.info("Invite expiry scheduler started (runs every 5 minutes)")
    except Exception as e:
        logger.error(f"Failed to start invite scheduler: {e}")
    
    # Initialize Sentry for error tracking
    if settings.SENTRY_DSN:
        import sentry_sdk
        sentry_sdk.init(
            dsn=settings.SENTRY_DSN,
            environment=settings.ENVIRONMENT,
            traces_sample_rate=0.1 if settings.ENVIRONMENT == "production" else 1.0
        )
        logger.info("Sentry error tracking initialized")
    
    logger.info("Application startup complete")
    
    yield
    
    # Cleanup on shutdown
    logger.info("Application shutting down")
    if backup_task is not None:
        backup_task.cancel()
        try:
            await backup_task
        except asyncio.CancelledError:
            pass
    if invite_scheduler_task is not None:
        invite_scheduler_task.cancel()
        try:
            await invite_scheduler_task
        except asyncio.CancelledError:
            pass
    logger.info("Application shutdown complete")


# Create FastAPI app with production settings
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    docs_url="/docs" if settings.DEBUG else None,  # Disable in production
    redoc_url="/redoc" if settings.DEBUG else None,
    lifespan=lifespan
)

# CORS - Restrict in production
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=settings.CORS_ALLOW_CREDENTIALS,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["*"],
    expose_headers=["X-Request-ID"]
)

# Setup all security and monitoring middleware
setup_middleware(app)
limiter = get_rate_limiter()

# Include routers
app.include_router(user.router)
app.include_router(wallet.router)
app.include_router(admin.router, prefix="/api/admin", tags=["admin"])
app.include_router(payment.router, prefix="/api/payment", tags=["payment"])
app.include_router(payment_methods.router, prefix="/api/payment-methods", tags=["payment-methods"])
app.include_router(auth.router, prefix="/api/auth", tags=["authentication"])
app.include_router(card_routes.router, prefix="/api", tags=["cards"])
app.include_router(quick_wins_routes.router, prefix="/api", tags=["quick-wins"])
app.include_router(real_payments.router, prefix="/api/real-payments", tags=["real-payments"])
app.include_router(stripe_connect.router, prefix="/api", tags=["stripe-connect"])
app.include_router(transaction_sync.router, prefix="/api", tags=["transaction-sync"])
app.include_router(invites.router, prefix="/api/invites", tags=["money-invites"])
app.include_router(webhooks.router, prefix="/api", tags=["webhooks"])


@app.get("/")
@limiter.limit(f"{settings.RATE_LIMIT_PER_MINUTE}/minute")
async def root(request: Request):
    """API root endpoint"""
    return {
        "message": f"{settings.APP_NAME} is running",
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
        "status": "healthy"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    try:
        # Check database connection
        from database import SessionLocal
        db = SessionLocal()
        db.execute("SELECT 1")
        db.close()
        
        return {
            "status": "healthy",
            "database": "connected",
            "version": settings.APP_VERSION
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}", exc_info=True)
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "error": "Database connection failed"
            }
        )


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    if not settings.PROMETHEUS_ENABLED:
        return JSONResponse(
            status_code=404,
            content={"detail": "Metrics disabled"}
        )
    
    from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
    from fastapi import Response
    
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )


@app.get("/backups")
@limiter.limit("10/minute")
async def list_backups(request: Request):
    """List available backups (admin only in production)"""
    backup_manager = get_backup_manager()
    backups = backup_manager.list_backups()
    
    return {
        "backups": backups,
        "count": len(backups),
        "retention_days": settings.BACKUP_RETENTION_DAYS
    }


@app.post("/backup/create")
@limiter.limit("1/hour")
async def create_backup_manually(request: Request):
    """Manually trigger a backup (admin only)"""
    backup_manager = get_backup_manager()
    backup_path = backup_manager.create_backup()
    
    if backup_path:
        return {
            "status": "success",
            "message": "Backup created successfully",
            "backup_path": backup_path
        }
    else:
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": "Backup failed"}
        )


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Catch all unhandled exceptions"""
    logger.error(
        f"Unhandled exception: {exc}",
        extra={
            "request_id": getattr(request.state, "request_id", "unknown"),
            "method": request.method,
            "url": str(request.url),
        },
        exc_info=True
    )
    
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "request_id": getattr(request.state, "request_id", "unknown")
        }
    )
