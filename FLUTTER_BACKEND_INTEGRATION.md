# راهنمای هماهنگ‌سازی Flutter با بک‌اند

این سند شامل تغییرات لازم برای هماهنگ‌سازی Flutter با بک‌اند بهبود یافته است.

## 📋 تغییرات لازم

### 1. اضافه کردن Endpoint برای Suggested Prompts

**در بک‌اند (app.py):**
```python
# اضافه کردن به app.py بعد از endpointهای موجود

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
    ],
    # ... (بقیه categories)
}

@app.get("/chat/suggested-prompts")
async def get_suggested_prompts(
    category: Optional[str] = None,
    language: str = "fa",
    limit: int = 5,
    current_user: User = Depends(get_current_user)
):
    prompts_list = []
    if category and category in SUGGESTED_PROMPTS:
        prompts_list = SUGGESTED_PROMPTS[category]
    else:
        for cat_prompts in SUGGESTED_PROMPTS.values():
            prompts_list.extend(cat_prompts)
    
    prompts_list = prompts_list[:limit]
    result = [
        {"text": prompt, "category": category or "general"}
        for prompt in prompts_list
    ]
    return {"prompts": result}
```

**در Flutter (lib/services/api_client.dart):**
```dart
Future<List<Map<String, String>>> getSuggestedPrompts({
  String? category,
  String language = 'fa',
  int limit = 5,
}) async {
  final query = <String, String>{
    if (category != null) 'category': category,
    'language': language,
    'limit': limit.toString(),
  };
  
  final response = await getJson(
    '/chat/suggested-prompts',
    query: query,
  );
  
  final prompts = response['prompts'] as List<dynamic>? ?? [];
  return prompts
      .map((item) => Map<String, String>.from(item as Map))
      .toList();
}
```

**استفاده در Flutter (lib/features/chat/chat_page.dart):**
```dart
// در _EmptyState
Future<void> _loadSuggestedPrompts() async {
  try {
    final api = context.read<ApiClient>();
    final prompts = await api.getSuggestedPrompts(limit: 5);
    setState(() {
      _suggestedPrompts = prompts
          .map((p) => p['text'] ?? '')
          .where((text) => text.isNotEmpty)
          .toList();
    });
  } catch (e) {
    // fallback to static prompts
    setState(() {
      _suggestedPrompts = _defaultPrompts;
    });
  }
}
```

---

### 2. بهبود Chat Stream با Typing Events

**در بک‌اند (app.py):**
```python
# در _stream_attempt function، قبل از شروع streaming:
yield _sse_event("typing", json.dumps({
    "status": "thinking",
    "message": "در حال پردازش..."
}))

if web_search:
    yield _sse_event("typing", json.dumps({
        "status": "searching",
        "message": "در حال جستجوی منابع..."
    }))

# قبل از شروع generating:
yield _sse_event("typing", json.dumps({
    "status": "generating",
    "message": "در حال تولید پاسخ..."
}))
```

**در Flutter (lib/models/chat_models.dart):**
```dart
class ChatTypingEvent extends ChatSseEvent {
  const ChatTypingEvent(this.status, this.message);
  
  final String status; // thinking, searching, generating
  final String message;
}

// در ChatSseEvent.fromEvent:
case 'typing':
  final dataMap = _safeDecodeMap(data);
  return ChatTypingEvent(
    dataMap['status']?.toString() ?? 'thinking',
    dataMap['message']?.toString() ?? '',
  );
```

**استفاده در Flutter (lib/controllers/chat_controller.dart):**
```dart
String? _typingStatus;
String? _typingMessage;

String? get typingStatus => _typingStatus;
String? get typingMessage => _typingMessage;

// در sendMessage:
await for (final event in _apiClient.streamChat(request)) {
  if (event is ChatTypingEvent) {
    _typingStatus = event.status;
    _typingMessage = event.message;
    notifyListeners();
  } else if (event is ChatTokenEvent) {
    _typingStatus = null;
    _typingMessage = null;
    // ... (بقیه کد)
  }
}
```

---

### 3. اضافه کردن Metadata به Responses

**در بک‌اند (app.py):**
```python
from datetime import datetime
import uuid

class ResponseMetadata(BaseModel):
    processing_time_ms: float
    model_used: Optional[str] = None
    provider_used: Optional[str] = None
    timestamp: datetime
    request_id: str
    cache_hit: bool = False

# در endpointها:
start_time = time.time()
request_id = str(uuid.uuid4())

# ... (پردازش)

processing_time = (time.time() - start_time) * 1000
metadata = ResponseMetadata(
    processing_time_ms=processing_time,
    model_used=model,
    provider_used=provider,
    timestamp=datetime.utcnow(),
    request_id=request_id,
    cache_hit=False,
)
```

**در Flutter (lib/models/chat_models.dart):**
```dart
class ResponseMetadata {
  final double processingTimeMs;
  final String? modelUsed;
  final String? providerUsed;
  final DateTime timestamp;
  final String requestId;
  final bool cacheHit;
  
  ResponseMetadata({
    required this.processingTimeMs,
    this.modelUsed,
    this.providerUsed,
    required this.timestamp,
    required this.requestId,
    this.cacheHit = false,
  });
  
  factory ResponseMetadata.fromJson(Map<String, dynamic> json) {
    return ResponseMetadata(
      processingTimeMs: (json['processing_time_ms'] as num?)?.toDouble() ?? 0,
      modelUsed: json['model_used']?.toString(),
      providerUsed: json['provider_used']?.toString(),
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      requestId: json['request_id']?.toString() ?? '',
      cacheHit: json['cache_hit'] as bool? ?? false,
    );
  }
}
```

---

### 4. بهبود Error Handling

**در بک‌اند (app.py):**
```python
from enum import Enum

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

# در error handling:
raise HTTPException(
    status_code=400,
    detail=APIError(
        code=ErrorCode.INVALID_INPUT,
        message="عبارت جست‌وجو خالی است.",
        retryable=False,
    ).dict()
)
```

**در Flutter (lib/services/exceptions.dart):**
```dart
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final bool retryable;
  final String? suggestedAction;
  
  ApiException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.retryable = false,
    this.suggestedAction,
  });
  
  factory ApiException.fromJson(Map<String, dynamic> json) {
    return ApiException(
      json['message']?.toString() ?? 'خطای ناشناخته',
      errorCode: json['code']?.toString(),
      retryable: json['retryable'] as bool? ?? false,
      suggestedAction: json['suggested_action']?.toString(),
    );
  }
}

// در api_client.dart:
String? _extractErrorMessage(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      // اگر error format جدید است
      if (decoded.containsKey('code')) {
        final error = ApiException.fromJson(decoded);
        return error.message;
      }
      // format قدیمی
      return decoded['detail']?.toString() ??
          decoded['message']?.toString() ??
          body;
    }
  } catch (_) {}
  return body;
}
```

---

### 5. اضافه کردن Rate Limit Headers

**در بک‌اند (app.py):**
```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.post("/chat/stream")
@limiter.limit("10/minute")
async def chat_stream(...):
    # ... (کد موجود)
    response = StreamingResponse(...)
    # اضافه کردن headers
    response.headers["X-RateLimit-Limit"] = "10"
    response.headers["X-RateLimit-Remaining"] = str(...)
    response.headers["X-RateLimit-Reset"] = str(...)
    return response
```

**در Flutter (lib/services/api_client.dart):**
```dart
class RateLimitInfo {
  final int limit;
  final int remaining;
  final DateTime? resetAt;
  
  RateLimitInfo({
    required this.limit,
    required this.remaining,
    this.resetAt,
  });
}

RateLimitInfo? _rateLimitInfo;

RateLimitInfo? get rateLimitInfo => _rateLimitInfo;

Map<String, dynamic> _handleResponse(http.Response response) {
  // استخراج rate limit headers
  final limit = int.tryParse(response.headers['x-ratelimit-limit'] ?? '');
  final remaining = int.tryParse(response.headers['x-ratelimit-remaining'] ?? '');
  final reset = int.tryParse(response.headers['x-ratelimit-reset'] ?? '');
  
  if (limit != null && remaining != null) {
    _rateLimitInfo = RateLimitInfo(
      limit: limit,
      remaining: remaining,
      resetAt: reset != null 
          ? DateTime.fromMillisecondsSinceEpoch(reset * 1000)
          : null,
    );
  }
  
  // ... (بقیه کد)
}
```

---

### 6. اضافه کردن Request ID

**در بک‌اند (app.py):**
```python
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
import uuid

class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response

app.add_middleware(RequestIDMiddleware)
```

**در Flutter (lib/services/api_client.dart):**
```dart
String? _lastRequestId;

String? get lastRequestId => _lastRequestId;

Map<String, dynamic> _handleResponse(http.Response response) {
  _lastRequestId = response.headers['x-request-id'];
  // ... (بقیه کد)
}
```

---

## 📝 چک‌لیست پیاده‌سازی

### بک‌اند (app.py)
- [ ] اضافه کردن endpoint `/chat/suggested-prompts`
- [ ] اضافه کردن typing events به chat stream
- [ ] اضافه کردن metadata به responses
- [ ] بهبود error handling با error codes
- [ ] اضافه کردن rate limit headers
- [ ] اضافه کردن request ID middleware

### Flutter
- [ ] اضافه کردن `getSuggestedPrompts` به ApiClient
- [ ] اضافه کردن `ChatTypingEvent` به models
- [ ] اضافه کردن `ResponseMetadata` به models
- [ ] بهبود `ApiException` برای error codes
- [ ] اضافه کردن rate limit info به ApiClient
- [ ] استفاده از suggested prompts در empty state
- [ ] نمایش typing status در UI

---

## 🚀 مراحل بعدی

1. **تست کردن endpointهای جدید**
2. **به‌روزرسانی Flutter برای استفاده از features جدید**
3. **اضافه کردن error handling بهتر**
4. **اضافه کردن logging برای debugging**
5. **بهینه‌سازی performance**

---

## 📚 منابع

- FastAPI Documentation: https://fastapi.tiangolo.com/
- Flutter HTTP Package: https://pub.dev/packages/http
- SSE Specification: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events

