"""
Production Middleware for Security, Rate Limiting, and Monitoring
"""
import time
import logging
from typing import Callable
from fastapi import Request, Response, HTTPException, status
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from starlette.middleware.gzip import GZipMiddleware
from prometheus_client import Counter, Histogram
import secrets

from config import settings

logger = logging.getLogger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter(
    'http_requests_total', 
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint']
)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Add security headers to all responses"""
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        response = await call_next(request)
        
        # Security headers
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['X-XSS-Protection'] = '1; mode=block'
        response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
        response.headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'
        
        # HSTS (HTTP Strict Transport Security)
        if settings.SSL_ENABLED:
            hsts_value = f'max-age={settings.HSTS_MAX_AGE}'
            if settings.HSTS_INCLUDE_SUBDOMAINS:
                hsts_value += '; includeSubDomains'
            response.headers['Strict-Transport-Security'] = hsts_value
        
        # Content Security Policy
        csp = (
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
            "style-src 'self' 'unsafe-inline'; "
            "img-src 'self' data: https:; "
            "font-src 'self' data:; "
            "connect-src 'self' https://api.stripe.com; "
            "frame-ancestors 'none';"
        )
        response.headers['Content-Security-Policy'] = csp
        
        return response


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Add unique request ID to each request for tracing"""
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        request_id = secrets.token_hex(16)
        request.state.request_id = request_id
        
        response = await call_next(request)
        response.headers['X-Request-ID'] = request_id
        
        return response


class LoggingMiddleware(BaseHTTPMiddleware):
    """Log all requests and responses"""
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.time()
        
        # Log request
        logger.info(
            "Request started",
            extra={
                "request_id": getattr(request.state, "request_id", "unknown"),
                "method": request.method,
                "url": str(request.url),
                "client": request.client.host if request.client else "unknown",
            }
        )
        
        try:
            response = await call_next(request)
            
            # Calculate duration
            duration = time.time() - start_time
            
            # Update Prometheus metrics
            REQUEST_COUNT.labels(
                method=request.method,
                endpoint=request.url.path,
                status=response.status_code
            ).inc()
            
            REQUEST_DURATION.labels(
                method=request.method,
                endpoint=request.url.path
            ).observe(duration)
            
            # Log response
            logger.info(
                "Request completed",
                extra={
                    "request_id": getattr(request.state, "request_id", "unknown"),
                    "method": request.method,
                    "url": str(request.url),
                    "status_code": response.status_code,
                    "duration": f"{duration:.3f}s",
                }
            )
            
            return response
            
        except Exception as e:
            duration = time.time() - start_time
            logger.error(
                "Request failed",
                extra={
                    "request_id": getattr(request.state, "request_id", "unknown"),
                    "method": request.method,
                    "url": str(request.url),
                    "error": str(e),
                    "duration": f"{duration:.3f}s",
                },
                exc_info=True
            )
            raise


class IPWhitelistMiddleware(BaseHTTPMiddleware):
    """Optional IP whitelist for admin endpoints"""
    
    def __init__(self, app, whitelist: list = None):
        super().__init__(app)
        self.whitelist = whitelist or []
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Only check admin routes
        if request.url.path.startswith("/admin"):
            client_ip = request.client.host if request.client else "unknown"
            
            if self.whitelist and client_ip not in self.whitelist:
                logger.warning(
                    f"Blocked admin access from {client_ip}",
                    extra={"client_ip": client_ip, "path": request.url.path}
                )
                return JSONResponse(
                    status_code=status.HTTP_403_FORBIDDEN,
                    content={"detail": "Access forbidden"}
                )
        
        return await call_next(request)


class DDoSProtectionMiddleware(BaseHTTPMiddleware):
    """Basic DDoS protection - detect suspicious patterns"""
    
    def __init__(self, app, max_requests_per_second: int = 10):
        super().__init__(app)
        self.max_requests = max_requests_per_second
        self.request_counts = {}
        self.last_reset = time.time()
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        client_ip = request.client.host if request.client else "unknown"
        current_time = time.time()
        
        # Reset counters every second
        if current_time - self.last_reset >= 1.0:
            self.request_counts = {}
            self.last_reset = current_time
        
        # Count requests from this IP
        self.request_counts[client_ip] = self.request_counts.get(client_ip, 0) + 1
        
        # Block if exceeds threshold
        if self.request_counts[client_ip] > self.max_requests:
            logger.warning(
                f"DDoS protection triggered for {client_ip}",
                extra={
                    "client_ip": client_ip,
                    "request_count": self.request_counts[client_ip]
                }
            )
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content={"detail": "Too many requests. Please slow down."}
            )
        
        return await call_next(request)


# Rate limiter setup
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[f"{settings.RATE_LIMIT_PER_MINUTE}/minute"],
    enabled=settings.RATE_LIMIT_ENABLED,
    storage_uri=settings.REDIS_URL if settings.REDIS_ENABLED else "memory://"
)


def get_rate_limiter():
    """Get rate limiter instance"""
    return limiter


def setup_middleware(app):
    """Setup all middleware for the application"""
    
    # Trust proxy headers (important for production behind reverse proxy)
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=["*"]  # Configure appropriately for production
    )
    
    # GZip compression
    app.add_middleware(GZipMiddleware, minimum_size=1000)
    
    # Custom middleware (order matters!)
    app.add_middleware(DDoSProtectionMiddleware, max_requests_per_second=10)
    app.add_middleware(IPWhitelistMiddleware, whitelist=[])  # Configure as needed
    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(RequestIDMiddleware)
    app.add_middleware(LoggingMiddleware)
    
    # Rate limiter
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
    
    logger.info("All middleware configured successfully")
