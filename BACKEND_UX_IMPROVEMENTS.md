# پیشنهادات بهبود UX از طریق بک‌اند

این سند شامل پیشنهادات برای بهبود تجربه کاربری از طریق تغییرات در بک‌اند (FastAPI) است.

## 📋 فهرست مطالب
1. [بهبودهای API Response](#بهبودهای-api-response)
2. [بهبودهای Streaming](#بهبودهای-streaming)
3. [بهبودهای Error Handling](#بهبودهای-error-handling)
4. [بهبودهای Performance](#بهبودهای-performance)
5. [اضافه کردن Features جدید](#اضافه-کردن-features-جدید)

---

## بهبودهای API Response

### 1. اضافه کردن Metadata به Response ها

**مشکل فعلی:**
- Response ها فقط داده خام برمی‌گردانند
- هیچ اطلاعاتی درباره زمان پردازش، مدل استفاده شده، و غیره نیست

**پیشنهاد:**
```python
# اضافه کردن metadata به تمام response ها
class EnhancedResponse(BaseModel):
    data: Any
    metadata: ResponseMetadata

class ResponseMetadata(BaseModel):
    processing_time_ms: float
    model_used: Optional[str] = None
    provider_used: Optional[str] = None
    timestamp: datetime
    request_id: str
    cache_hit: bool = False
```

**مزایا:**
- کاربران می‌توانند ببینند چقدر طول کشیده
- می‌توانند ببینند از چه مدلی استفاده شده
- برای debugging مفید است

---

### 2. اضافه کردن Progress Indicators

**پیشنهاد:**
برای عملیات‌های طولانی (مثل agent tasks، research)، progress events ارسال شود:

```python
# در SSE stream
{
    "event": "progress",
    "data": {
        "stage": "researching",  # researching, writing, finalizing
        "progress": 45,  # 0-100
        "message": "در حال جستجوی منابع..."
    }
}
```

**مزایا:**
- کاربران می‌دانند چه اتفاقی می‌افتد
- احساس انتظار کمتر می‌شود
- UX بهتر

---

### 3. بهبود Response Format برای Chat

**پیشنهاد:**
اضافه کردن fields بیشتر به chat response:

```python
{
    "event": "done",
    "data": {
        "text": "...",
        "model": "...",
        "provider": "...",
        "sources": [...],
        "tokens_used": 150,
        "processing_time_ms": 2500,
        "suggested_followups": [  # پیشنهاد سوالات بعدی
            "آیا می‌خواهید بیشتر بدانید؟",
            "سوال دیگری دارید؟"
        ]
    }
}
```

---

## بهبودهای Streaming

### 1. اضافه کردن Typing Indicator Events

**پیشنهاد:**
قبل از شروع streaming، event ارسال شود:

```python
{
    "event": "typing",
    "data": {
        "status": "thinking"  # thinking, searching, generating
    }
}
```

**مزایا:**
- کاربر می‌داند که سیستم در حال کار است
- UX بهتر از loading ساده

---

### 2. بهبود Error Events در Stream

**پیشنهاد:**
Error events را با جزئیات بیشتر ارسال کنید:

```python
{
    "event": "error",
    "data": {
        "code": "PROVIDER_TIMEOUT",
        "message": "زمان اتصال به سرور به پایان رسید",
        "retryable": true,
        "suggested_action": "لطفاً دوباره تلاش کنید",
        "fallback_available": true
    }
}
```

---

### 3. اضافه کردن Partial Results

**پیشنهاد:**
برای عملیات‌های طولانی، partial results ارسال شود:

```python
{
    "event": "partial",
    "data": {
        "type": "research_section",
        "content": {
            "title": "...",
            "summary": "..."
        },
        "complete": false
    }
}
```

---

## بهبودهای Error Handling

### 1. Error Codes استاندارد

**پیشنهاد:**
استفاده از error codes استاندارد:

```python
class ErrorCode(str, Enum):
    INVALID_INPUT = "INVALID_INPUT"
    AUTHENTICATION_FAILED = "AUTHENTICATION_FAILED"
    RATE_LIMIT_EXCEEDED = "RATE_LIMIT_EXCEEDED"
    PROVIDER_UNAVAILABLE = "PROVIDER_UNAVAILABLE"
    TIMEOUT = "TIMEOUT"
    INTERNAL_ERROR = "INTERNAL_ERROR"

class APIError(BaseModel):
    code: ErrorCode
    message: str
    details: Optional[Dict[str, Any]] = None
    retryable: bool = False
    suggested_action: Optional[str] = None
```

**مزایا:**
- فرانت‌اند می‌تواند error handling بهتری داشته باشد
- می‌تواند messages مناسب به کاربر نشان دهد
- می‌تواند retry logic پیاده کند

---

### 2. Rate Limiting با Response Headers

**پیشنهاد:**
اضافه کردن rate limit info به headers:

```python
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

**مزایا:**
- فرانت‌اند می‌تواند به کاربر نشان دهد چقدر request باقی مانده
- می‌تواند warning نشان دهد قبل از تمام شدن

---

### 3. Retry-After Header

**پیشنهاد:**
برای rate limiting و cooldown periods:

```python
Retry-After: 60  # seconds
```

---

## بهبودهای Performance

### 1. Response Caching

**پیشنهاد:**
برای queries تکراری، cache اضافه کنید:

```python
@lru_cache(maxsize=1000)
async def cached_completion(messages_hash: str, temperature: float):
    # ...
```

**مزایا:**
- پاسخ سریع‌تر برای queries تکراری
- کاهش هزینه API calls
- UX بهتر

---

### 2. Compression برای Large Responses

**پیشنهاد:**
برای responses بزرگ، compression استفاده کنید:

```python
from fastapi.responses import Response
import gzip

@app.post("/research/deep")
async def deep_research(...):
    data = await _run_deep_research(...)
    compressed = gzip.compress(json.dumps(data).encode())
    return Response(
        content=compressed,
        media_type="application/json",
        headers={"Content-Encoding": "gzip"}
    )
```

---

### 3. Pagination برای Lists

**پیشنهاد:**
برای endpoints که list برمی‌گردانند:

```python
class PaginatedResponse(BaseModel):
    items: List[Any]
    total: int
    page: int
    page_size: int
    has_next: bool
    has_prev: bool
```

---

## اضافه کردن Features جدید

### 1. Endpoint برای Suggested Prompts

**پیشنهاد:**
```python
@app.get("/chat/suggested-prompts")
async def get_suggested_prompts(
    category: Optional[str] = None,
    language: str = "fa",
    limit: int = 5
):
    """
    برمی‌گرداند لیستی از suggested prompts بر اساس category
    """
    # ...
```

**استفاده در فرانت:**
- می‌تواند در empty state نمایش داده شود
- می‌تواند بر اساس context تغییر کند

---

### 2. Endpoint برای Message History

**پیشنهاد:**
```python
@app.get("/chat/sessions/{session_id}/messages")
async def get_session_messages(
    session_id: str,
    page: int = 1,
    page_size: int = 50,
    current_user: User = Depends(get_current_user)
):
    """
    برمی‌گرداند تاریخچه پیام‌های یک session با pagination
    """
    # ...
```

---

### 3. Endpoint برای Search در Messages

**پیشنهاد:**
```python
@app.get("/chat/search")
async def search_messages(
    query: str,
    session_id: Optional[str] = None,
    current_user: User = Depends(get_current_user)
):
    """
    جستجو در تمام پیام‌های کاربر
    """
    # ...
```

---

### 4. Endpoint برای Analytics

**پیشنهاد:**
```python
@app.get("/user/analytics")
async def get_user_analytics(
    current_user: User = Depends(get_current_user)
):
    """
    آمار استفاده کاربر:
    - تعداد پیام‌ها
    - تعداد sessions
    - زمان استفاده
    - محبوب‌ترین features
    """
    # ...
```

**استفاده در فرانت:**
- می‌تواند dashboard نمایش دهد
- می‌تواند achievements نشان دهد
- می‌تواند gamification اضافه کند

---

### 5. WebSocket برای Real-time Updates

**پیشنهاد:**
برای agent tasks و عملیات‌های طولانی:

```python
@app.websocket("/ws/tasks/{task_id}")
async def websocket_task_updates(websocket: WebSocket, task_id: int):
    await websocket.accept()
    # ارسال updates در real-time
```

**مزایا:**
- کاربر می‌تواند progress را در real-time ببیند
- نیازی به polling نیست
- UX بهتر

---

### 6. Endpoint برای Export

**پیشنهاد:**
```python
@app.get("/chat/sessions/{session_id}/export")
async def export_session(
    session_id: str,
    format: str = "json",  # json, markdown, pdf
    current_user: User = Depends(get_current_user)
):
    """
    Export یک session به فرمت‌های مختلف
    """
    # ...
```

---

### 7. Endpoint برای Share

**پیشنهاد:**
```python
@app.post("/chat/sessions/{session_id}/share")
async def create_share_link(
    session_id: str,
    expires_in: Optional[int] = 3600,  # seconds
    current_user: User = Depends(get_current_user)
):
    """
    ایجاد لینک share برای یک session
    """
    # ...
```

---

## بهبودهای امنیتی و UX

### 1. Input Validation بهتر

**پیشنهاد:**
استفاده از Pydantic validators:

```python
from pydantic import validator

class ChatRequest(BaseModel):
    messages: List[Message]
    
    @validator('messages')
    def validate_messages(cls, v):
        if not v:
            raise ValueError('حداقل یک پیام لازم است')
        if len(v) > 100:
            raise ValueError('حداکثر 100 پیام مجاز است')
        return v
```

---

### 2. Rate Limiting بهتر

**پیشنهاد:**
Rate limiting بر اساس user و endpoint:

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.post("/chat/stream")
@limiter.limit("10/minute")
async def chat_stream(...):
    # ...
```

---

### 3. Request ID برای Tracking

**پیشنهاد:**
اضافه کردن request ID به تمام responses:

```python
import uuid

@app.middleware("http")
async def add_request_id(request: Request, call_next):
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response
```

**مزایا:**
- برای debugging مفید است
- می‌تواند در error messages استفاده شود
- برای support بهتر است

---

## اولویت‌بندی

### اولویت بالا
1. ✅ اضافه کردن metadata به responses
2. ✅ بهبود error handling با codes
3. ✅ اضافه کردن progress indicators
4. ✅ اضافه کردن suggested prompts endpoint

### اولویت متوسط
1. ✅ اضافه کردن message history endpoint
2. ✅ اضافه کردن search endpoint
3. ✅ بهبود rate limiting
4. ✅ اضافه کردن caching

### اولویت پایین
1. ✅ اضافه کردن WebSocket
2. ✅ اضافه کردن analytics endpoint
3. ✅ اضافه کردن export/share endpoints
4. ✅ اضافه کردن compression

---

## نتیجه‌گیری

این بهبودها به شما کمک می‌کند تا:
- ✅ تجربه کاربری بهتری ارائه دهید
- ✅ عملکرد بهتری داشته باشید
- ✅ قابلیت‌های بیشتری اضافه کنید
- ✅ debugging و support را آسان‌تر کنید

شروع با اولویت‌های بالا و سپس حرکت به سمت اولویت‌های پایین‌تر توصیه می‌شود.

