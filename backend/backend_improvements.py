# بهبودهای بک‌اند برای هماهنگی با Flutter
# این فایل شامل کدهای جدید برای اضافه کردن به app.py است

from typing import List, Optional, Dict, Any
from pydantic import BaseModel
from fastapi import Depends, HTTPException, status
from datetime import datetime
import uuid

# ============================================================================
# 1. MODELS جدید برای Suggested Prompts
# ============================================================================

class SuggestedPromptRequest(BaseModel):
    category: Optional[str] = None  # general, coding, writing, research, etc.
    language: str = "fa"
    limit: int = 5

class SuggestedPromptResponse(BaseModel):
    prompts: List[Dict[str, str]]  # [{"text": "...", "category": "..."}]

# ============================================================================
# 2. MODELS جدید برای Enhanced Responses
# ============================================================================

class ResponseMetadata(BaseModel):
    processing_time_ms: float
    model_used: Optional[str] = None
    provider_used: Optional[str] = None
    timestamp: datetime
    request_id: str
    cache_hit: bool = False

class EnhancedWebSearchResponse(BaseModel):
    query: str
    answer: str
    model: Optional[str] = None
    provider: Optional[str] = None
    sources: Optional[List[Dict[str, Any]]] = None
    metadata: ResponseMetadata
    suggested_followups: Optional[List[str]] = None

# ============================================================================
# 3. ENDPOINT برای Suggested Prompts
# ============================================================================

SUGGESTED_PROMPTS = {
    "general": [
        "یک برنامه روزانه برای افزایش بهره‌وری بنویس",
        "راه‌های کاهش استرس را توضیح بده",
        "بهترین روش‌های یادگیری برنامه‌نویسی چیست؟",
        "یک دستور پخت ساده پیشنهاد بده",
        "راهنمای شروع کسب‌وکار آنلاین",
    ],
    "coding": [
        "چگونه یک REST API با Python بسازم؟",
        "بهترین practices برای Git چیست؟",
        "تفاوت بین async و sync در JavaScript چیست؟",
        "چگونه یک database schema طراحی کنم؟",
        "بهترین framework برای Flutter چیست؟",
    ],
    "writing": [
        "چگونه یک مقاله جذاب بنویسم؟",
        "ساختار یک داستان کوتاه چیست؟",
        "چگونه محتوای SEO-friendly بنویسم؟",
        "نکات مهم برای نوشتن ایمیل حرفه‌ای",
        "چگونه یک pitch deck بنویسم؟",
    ],
    "research": [
        "تحقیق درباره هوش مصنوعی و آینده آن",
        "تأثیر شبکه‌های اجتماعی بر سلامت روان",
        "راه‌های کاهش آلودگی محیط زیست",
        "تاریخچه و آینده انرژی‌های تجدیدپذیر",
        "تأثیر فناوری بر اقتصاد جهانی",
    ],
}

@app.get("/chat/suggested-prompts", response_model=SuggestedPromptResponse)
async def get_suggested_prompts(
    category: Optional[str] = None,
    language: str = "fa",
    limit: int = 5,
    current_user: User = Depends(get_current_user)
):
    """
    برمی‌گرداند لیستی از suggested prompts بر اساس category
    """
    prompts_list = []
    
    if category and category in SUGGESTED_PROMPTS:
        prompts_list = SUGGESTED_PROMPTS[category]
    else:
        # ترکیب همه categories
        for cat_prompts in SUGGESTED_PROMPTS.values():
            prompts_list.extend(cat_prompts)
    
    # محدود کردن به limit
    prompts_list = prompts_list[:limit]
    
    # تبدیل به format مورد نظر
    result = [
        {"text": prompt, "category": category or "general"}
        for prompt in prompts_list
    ]
    
    return SuggestedPromptResponse(prompts=result)

# ============================================================================
# 4. بهبود Chat Stream با Progress Events
# ============================================================================

async def _stream_attempt_with_progress(
    client: AsyncClient,
    model: str,
    provider: Optional[Any],
    provider_label: Optional[str],
    messages: List[Message],
    request: Request,
    web_search: bool = False,
    sources: Optional[List[Dict[str, Any]]] = None,
    provider_kwargs: Optional[Dict[str, Any]] = None,
) -> AsyncGenerator[bytes, None]:
    """نسخه بهبود یافته stream_attempt با progress events"""
    stream_client = client or AsyncClient()
    
    start = time.time()
    request_messages = [m.dict() for m in messages]
    kwargs = {"model": model, "messages": request_messages}
    if provider:
        kwargs["provider"] = provider
    if web_search:
        kwargs["web_search"] = True
    if provider_kwargs:
        kwargs.update(provider_kwargs)
    
    # ارسال typing indicator
    yield _sse_event("typing", json.dumps({
        "status": "thinking",
        "message": "در حال پردازش..."
    }))
    
    if web_search:
        yield _sse_event("typing", json.dumps({
            "status": "searching",
            "message": "در حال جستجوی منابع..."
        }))
    
    stream = stream_client.chat.completions.stream(**kwargs)
    agen = stream.__aiter__()
    last_ping = start
    
    collected_chunks: List[str] = []
    
    try:
        # ارسال typing indicator برای generating
        yield _sse_event("typing", json.dumps({
            "status": "generating",
            "message": "در حال تولید پاسخ..."
        }))
        
        while True:
            try:
                chunk = await asyncio.wait_for(agen.__anext__(), timeout=PER_ATTEMPT_TIMEOUT)
            except StopAsyncIteration:
                break
            
            if await request.is_disconnected():
                log.info("Client disconnected; aborting stream.")
                return
            
            text_piece = _normalize_token_piece(_extract_text_piece(chunk))
            if text_piece:
                collected_chunks.append(text_piece)
                yield _sse_event("token", json.dumps({"text": text_piece}))
            
            now = time.time()
            if now - last_ping >= STREAM_PING_EVERY:
                last_ping = now
                yield _sse_event("ping", json.dumps({"t": int(now)}))
    except asyncio.TimeoutError:
        raise
    finally:
        close_callable = getattr(stream, "aclose", None) or getattr(agen, "aclose", None)
        if callable(close_callable):
            try:
                await close_callable()
            except Exception:
                pass
    
    latency_ms = int((time.time() - start) * 1000)
    done_payload = {
        "latency_ms": latency_ms,
        "model": model,
        "provider": provider_label,
        "text": "".join(collected_chunks),
    }
    if sources:
        done_payload["sources"] = sources
    
    # اضافه کردن suggested followups
    if collected_chunks:
        # می‌توانید از یک مدل کوچک برای تولید followups استفاده کنید
        done_payload["suggested_followups"] = [
            "آیا می‌خواهید بیشتر بدانید؟",
            "سوال دیگری دارید؟",
        ]
    
    yield _sse_event("done", json.dumps(done_payload))

# ============================================================================
# 5. بهبود Error Handling با Error Codes
# ============================================================================

from enum import Enum

class ErrorCode(str, Enum):
    INVALID_INPUT = "INVALID_INPUT"
    AUTHENTICATION_FAILED = "AUTHENTICATION_FAILED"
    RATE_LIMIT_EXCEEDED = "RATE_LIMIT_EXCEEDED"
    PROVIDER_UNAVAILABLE = "PROVIDER_UNAVAILABLE"
    TIMEOUT = "TIMEOUT"
    INTERNAL_ERROR = "INTERNAL_ERROR"
    NOT_FOUND = "NOT_FOUND"

class APIError(BaseModel):
    code: ErrorCode
    message: str
    details: Optional[Dict[str, Any]] = None
    retryable: bool = False
    suggested_action: Optional[str] = None

def _create_error_response(
    code: ErrorCode,
    message: str,
    details: Optional[Dict[str, Any]] = None,
    retryable: bool = False,
    suggested_action: Optional[str] = None,
    status_code: int = 400
) -> HTTPException:
    """ایجاد error response با format استاندارد"""
    error = APIError(
        code=code,
        message=message,
        details=details,
        retryable=retryable,
        suggested_action=suggested_action,
    )
    return HTTPException(
        status_code=status_code,
        detail=error.dict()
    )

# ============================================================================
# 6. Middleware برای Request ID
# ============================================================================

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response

# اضافه کردن middleware به app:
# app.add_middleware(RequestIDMiddleware)

# ============================================================================
# 7. بهبود Web Search Response با Metadata
# ============================================================================

async def tool_web_search_enhanced(
    body: MCPWebSearchRequest,
    current_user: User = Depends(get_current_user),
    request: Request = None
) -> EnhancedWebSearchResponse:
    """نسخه بهبود یافته web search با metadata"""
    start_time = time.time()
    request_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    
    query = body.query.strip()
    if not query:
        raise _create_error_response(
            ErrorCode.INVALID_INPUT,
            "عبارت جست‌وجو خالی است.",
            status_code=400
        )
    
    try:
        search_prompt, sources = await _google_search_summary(
            query,
            fetch_pages=True,
            max_pages=max(1, body.max_sources)
        )
        
        # ... (بقیه کد web search)
        
        processing_time = (time.time() - start_time) * 1000
        
        metadata = ResponseMetadata(
            processing_time_ms=processing_time,
            model_used=model,
            provider_used=provider,
            timestamp=datetime.utcnow(),
            request_id=request_id,
            cache_hit=False,
        )
        
        return EnhancedWebSearchResponse(
            query=query,
            answer=answer,
            model=model,
            provider=provider,
            sources=sources,
            metadata=metadata,
            suggested_followups=[
                f"اطلاعات بیشتری درباره {query}",
                "منابع دیگری هم هست؟",
            ],
        )
    except Exception as e:
        raise _create_error_response(
            ErrorCode.INTERNAL_ERROR,
            "خطا در پردازش درخواست",
            details={"error": str(e)},
            retryable=True,
            suggested_action="لطفاً دوباره تلاش کنید",
            status_code=500
        )

# ============================================================================
# 8. Rate Limiting Headers
# ============================================================================

from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@app.post("/chat/stream")
@limiter.limit("10/minute")
async def chat_stream_with_rate_limit(
    request: Request,
    body: ChatRequest,
    current_user: User = Depends(get_current_user)
):
    """Chat stream با rate limiting"""
    # اضافه کردن rate limit headers
    response = StreamingResponse(
        _fallback_stream(...),
        media_type="text/event-stream"
    )
    response.headers["X-RateLimit-Limit"] = "10"
    response.headers["X-RateLimit-Remaining"] = str(limiter.get_window_stats(...))
    return response

# ============================================================================
# 9. Endpoint برای Message History (برای آینده)
# ============================================================================

class MessageHistoryRequest(BaseModel):
    session_id: str
    page: int = 1
    page_size: int = 50

class PaginatedMessagesResponse(BaseModel):
    messages: List[Dict[str, Any]]
    total: int
    page: int
    page_size: int
    has_next: bool
    has_prev: bool

@app.get("/chat/sessions/{session_id}/messages", response_model=PaginatedMessagesResponse)
async def get_session_messages(
    session_id: str,
    page: int = 1,
    page_size: int = 50,
    current_user: User = Depends(get_current_user)
):
    """
    برمی‌گرداند تاریخچه پیام‌های یک session با pagination
    TODO: پیاده‌سازی با database
    """
    # این endpoint نیاز به database schema برای sessions دارد
    # فعلاً placeholder است
    return PaginatedMessagesResponse(
        messages=[],
        total=0,
        page=page,
        page_size=page_size,
        has_next=False,
        has_prev=False,
    )

# ============================================================================
# 10. Endpoint برای Search در Messages (برای آینده)
# ============================================================================

class MessageSearchRequest(BaseModel):
    query: str
    session_id: Optional[str] = None
    limit: int = 20

@app.get("/chat/search", response_model=List[Dict[str, Any]])
async def search_messages(
    query: str,
    session_id: Optional[str] = None,
    limit: int = 20,
    current_user: User = Depends(get_current_user)
):
    """
    جستجو در تمام پیام‌های کاربر
    TODO: پیاده‌سازی با database
    """
    # این endpoint نیاز به database schema برای sessions دارد
    # فعلاً placeholder است
    return []

