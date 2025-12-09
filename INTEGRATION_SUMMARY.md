# خلاصه هماهنگ‌سازی Flutter و بک‌اند

این سند شامل خلاصه تغییرات انجام شده برای هماهنگ‌سازی Flutter با بک‌اند است.

## ✅ تغییرات انجام شده در Flutter

### 1. اضافه کردن Suggested Prompts API
- ✅ متد `getSuggestedPrompts` به `ApiClient` اضافه شد
- ✅ `_EmptyState` به `StatefulWidget` تبدیل شد
- ✅ لود کردن dynamic prompts از API اضافه شد
- ✅ Fallback به static prompts در صورت خطا

**فایل‌های تغییر یافته:**
- `lib/services/api_client.dart`
- `lib/features/chat/chat_page.dart`

### 2. اضافه کردن Typing Events
- ✅ `ChatTypingEvent` به models اضافه شد
- ✅ پشتیبانی از typing events در `ChatSseEvent.fromEvent`
- ✅ نمایش typing status در `ChatController`
- ✅ Reset کردن typing status هنگام دریافت token

**فایل‌های تغییر یافته:**
- `lib/models/chat_models.dart`
- `lib/controllers/chat_controller.dart`

### 3. بهبود ChatDoneEvent
- ✅ اضافه کردن `suggestedFollowups` به `ChatDoneEvent`

**فایل‌های تغییر یافته:**
- `lib/models/chat_models.dart`

---

## 📝 تغییرات لازم در بک‌اند

### 1. اضافه کردن Endpoint برای Suggested Prompts

**فایل:** `E:/ai/app.py`

**بعد از خط 2987 (بعد از `get_me` endpoint) اضافه کنید:**

```python
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

@app.get("/chat/suggested-prompts")
async def get_suggested_prompts(
    category: Optional[str] = None,
    language: str = "fa",
    limit: int = 5,
    current_user: User = Depends(get_current_user)
):
    """برمی‌گرداند لیستی از suggested prompts بر اساس category"""
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
    
    return {"prompts": result}
```

---

### 2. اضافه کردن Typing Events به Chat Stream

**فایل:** `E:/ai/app.py`

**در تابع `_stream_attempt` (حدود خط 2170) اضافه کنید:**

```python
async def _stream_attempt(
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
    """Stream a single provider attempt using the AsyncClient interface."""
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

    # اضافه کردن typing events
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
            # ... (بقیه کد موجود)
```

---

### 3. اضافه کردن Suggested Followups به Done Event

**فایل:** `E:/ai/app.py`

**در تابع `_stream_attempt` (بعد از خط 2235) تغییر دهید:**

```python
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
        done_payload["suggested_followups"] = [
            "آیا می‌خواهید بیشتر بدانید؟",
            "سوال دیگری دارید؟",
        ]
    
    yield _sse_event("done", json.dumps(done_payload))
```

---

## 🧪 تست کردن

### 1. تست Suggested Prompts Endpoint

```bash
curl -X GET "https://wqai.morvism.ir/chat/suggested-prompts?limit=5" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**پاسخ مورد انتظار:**
```json
{
  "prompts": [
    {"text": "یک برنامه روزانه برای افزایش بهره‌وری بنویس", "category": "general"},
    ...
  ]
}
```

### 2. تست Typing Events

در Flutter app، هنگام ارسال پیام باید typing events را ببینید:
- `typing` event با status `thinking`
- اگر web_search فعال باشد: `typing` event با status `searching`
- `typing` event با status `generating`
- سپس `token` events

### 3. تست Suggested Followups

در `ChatDoneEvent` باید `suggestedFollowups` را ببینید.

---

## 📋 چک‌لیست نهایی

### Flutter ✅
- [x] اضافه کردن `getSuggestedPrompts` به ApiClient
- [x] اضافه کردن `ChatTypingEvent` به models
- [x] اضافه کردن `suggestedFollowups` به `ChatDoneEvent`
- [x] استفاده از suggested prompts در empty state
- [x] نمایش typing status در controller

### بک‌اند ⏳
- [ ] اضافه کردن endpoint `/chat/suggested-prompts`
- [ ] اضافه کردن typing events به chat stream
- [ ] اضافه کردن suggested followups به done event

---

## 🚀 مراحل بعدی (اختیاری)

### اولویت بالا
1. اضافه کردن metadata به responses
2. بهبود error handling با error codes
3. اضافه کردن rate limit headers

### اولویت متوسط
1. اضافه کردن request ID middleware
2. اضافه کردن caching برای suggested prompts
3. اضافه کردن analytics endpoint

### اولویت پایین
1. اضافه کردن WebSocket برای real-time updates
2. اضافه کردن export/share endpoints
3. اضافه کردن message history endpoint

---

## 📚 فایل‌های مرجع

- `FLUTTER_BACKEND_INTEGRATION.md` - راهنمای کامل integration
- `BACKEND_UX_IMPROVEMENTS.md` - پیشنهادات بهبود بک‌اند
- `E:/ai/backend_improvements.py` - کدهای نمونه برای بک‌اند

---

## ⚠️ نکات مهم

1. **تست کردن:** قبل از deploy، تمام endpointها را تست کنید
2. **Error Handling:** اطمینان حاصل کنید که error handling درست کار می‌کند
3. **Performance:** monitoring کنید که آیا typing events performance را تحت تأثیر قرار می‌دهند
4. **Backward Compatibility:** اطمینان حاصل کنید که تغییرات با version قدیمی Flutter سازگار هستند

---

## 🎉 نتیجه

با این تغییرات:
- ✅ Flutter می‌تواند dynamic prompts از API دریافت کند
- ✅ کاربران typing status را می‌بینند
- ✅ UX بهتر می‌شود
- ✅ آماده برای features بیشتر است

