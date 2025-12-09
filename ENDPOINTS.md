## API Endpoints

### Authentication Flow
- `POST /auth/request-otp`
  - **Auth:** آزاد
  - **Body:** `{ "phone": "<شماره>" }`
  - **Description:** تولید و ارسال کد OTP با سرویس Pattern IPPanel. خروجی شامل `otp_token` است که باید در هدر Authorization مرحلهٔ بعد استفاده شود.
  - **Response:** `{ "detail": "...", "otp_token": "<jwt>" }`
  - **Sample Request**
    ```http
    POST /auth/request-otp
    Content-Type: application/json

    {
      "phone": "+989120000000"
    }
    ```
  - **Sample Response**
    ```json
    {
      "detail": "کد تایید ارسال شد.",
      "otp_token": "eyJhbGciOiJIUzI1NiIs..."
    }
    ```

- `POST /auth/verify-otp`
  - **Auth:** `Authorization: Bearer <otp_token>` (نوع otp)
  - **Body:** `{ "phone": "<شماره>", "code": "<کد 6 رقمی>" }`
  - **Description:** صحت‌سنجی OTP، ساخت یا به‌روزرسانی کاربر و تولید توکن دسترسی.
  - **Response:** `{ "token": "<access_jwt>", "user_id": 1, "phone": "+989..." }`
  - **Sample Request**
    ```http
    POST /auth/verify-otp
    Authorization: Bearer eyJhbGciOiJI...
    Content-Type: application/json

    {
      "phone": "+989120000000",
      "code": "482913"
    }
    ```
  - **Sample Response**
    ```json
    {
      "token": "eyJhbGciOiJIUzI1NiIs...",
      "user_id": 1,
      "phone": "+989120000000"
    }
    ```

### Protected Endpoints (JWT نوع access)
برای تمامی مسیرهای زیر هدر `Authorization: Bearer <token>` الزامی است.

- `POST /chat/stream`
  - **Body:** مطابق `ChatRequest` (لیست پیام‌ها، session_id، web_search و ...)
  - **Description:** چت استریمی با fallback chain مدل‌ها و امکان وب‌سرچ.
  - **Response:** SSE شامل توکن‌ها، meta، warn، done و ...
  - **Sample Request (body)**
    ```json
    {
      "session_id": "abc123",
      "web_search": false,
      "messages": [
        { "role": "user", "content": "سلام، یه کپشن انگیزشی بده" }
      ]
    }
    ```
  - **Sample SSE Events**
    ```
    event: token
    data: {"text":"سلام! "}

    event: done
    data: {"latency_ms":2300,"model":"gpt-4o","text":"سلام! ..."}
    ```

- `POST /instagram/ideas`
  - **Body:** `{ "topic": "...", "audience": "...", "goals": "...", "language": "fa" }`
  - **Description:** ساخت ایده‌های نیچ اینستاگرام با استفاده از مدل هوش مصنوعی. همیشه JSON ساختاریافته بازمی‌گرداند.
  - **Response:** `InstagramIdeaResponse` شامل `ideas` و متن خام.
  - **Sample Request**
    ```json
    {
      "topic": "آموزش فیتنس خانگی",
      "audience": "خانم‌های ۲۰ تا ۳۵ سال",
      "goals": "افزایش فروش برنامه آنلاین",
      "language": "fa"
    }
    ```
  - **Sample Response**
    ```json
    {
      "topic": "آموزش فیتنس خانگی",
      "ideas": [
        {
          "niche_name": "چالش ۳۰ روزه صبحگاهی",
          "angle": "پیش از شروع روز، ۱۵ دقیقه تمرین",
          "why_it_works": "پایداری بالا و قابل‌اشتراک",
          "sample_content": "روز اول: گرم‌کردن و ۵ حرکت پایه",
          "monetization": "پکیج اختصاصی برای شرکت‌کننده‌ها"
        }
      ],
      "raw_text": "{\"ideas\": [...]} "
    }
    ```

- `POST /instagram/content-calendar`
  - **Body:** `{ "idea": "...", "duration_weeks": 4, "posts_per_week": 3, "pillars": ["..."], "include_reels": true, "language": "fa" }`
  - **Description:** تولید تقویم محتوایی با هوک، فرمت، Outline، CTA و Notes.
  - **Response:** `ContentCalendarResponse` با لیست `entries`.
  - **Sample Request**
    ```json
    {
      "idea": "برند شخصی مربی تغذیه",
      "duration_weeks": 4,
      "posts_per_week": 3,
      "pillars": ["آموزش تغذیه", "لایف‌استایل"],
      "include_reels": true,
      "language": "fa"
    }
    ```
  - **Sample Response**
    ```json
    {
      "idea": "برند شخصی مربی تغذیه",
      "duration_weeks": 4,
      "posts_per_week": 3,
      "entries": [
        {
          "day": "هفته ۱ - روز ۱",
          "hook": "همه می‌گن صبح ناشتا آب بخور، اما چرا؟",
          "format": "Reel",
          "outline": "۱) معرفی باور غلط، ۲) توضیح علمی، ۳) نکته کاربردی",
          "cta": "در کامنت بگو صبح‌ها چی می‌خوری",
          "notes": "استفاده از ترند موزیک ملایم"
        }
      ],
      "raw_text": "{\"entries\": [...]} "
    }
    ```

- `POST /research/deep`
  - **Body:** `{ "query": "...", "depth": "summary|detailed|comprehensive", "audience": "...", "language": "fa", "include_outline": true, "include_sources": true }`
  - **Description:** تحقیق عمیق با امکان خلاصه‌سازی، بخش‌بندی، آوت‌لاین و فهرست منابع.
  - **Response:** `DeepResearchResponse` با `summary`, `sections`, `outline`, `sources`.
  - **Sample Request**
    ```json
    {
      "query": "تأثیر هوش مصنوعی بر استراتژی بازاریابی 2025",
      "depth": "comprehensive",
      "audience": "مدیران بازاریابی",
      "language": "fa",
      "include_outline": true,
      "include_sources": true
    }
    ```
  - **Sample Response**
    ```json
    {
      "query": "تأثیر هوش مصنوعی بر استراتژی بازاریابی 2025",
      "depth": "comprehensive",
      "summary": "هوش مصنوعی باعث ...",
      "sections": [
        {
          "title": "تحلیل داده‌های پیش‌بینی",
          "summary": "برندها با مدل‌های پیش‌بینی بهتر رفتار مشتری را ...",
          "takeaways": [
            "اولویت‌بندی لید با مدل‌های propensity",
            "شخصی‌سازی real-time با AI"
          ],
          "sources": [
            { "title": "McKinsey 2024", "url": "https://..." }
          ]
        }
      ],
      "outline": [
        "مقدمه",
        "نقش AI در تحلیل داده",
        "آینده کمپین‌های خودکار"
      ],
      "sources": [
        { "title": "Gartner AI Marketing", "url": "https://..." }
      ],
      "raw_text": "{\"summary\":...}"
    }
    ```

- `POST /agents/tasks`
  - **Body:** `{ "title": "...", "brief": "...", "audience": "...", "tone": "...", "language": "fa", "outline": ["..."], "word_count": 1200, "include_research": true }`
  - **Description:** تعریف تسک برای ایجنت تولید محتوای لانگ‌فرم (Markdown) با امکان تحقیق اولیه.
  - **Response:** `AgentTaskResponse` شامل مشخصات و متن نهایی (در صورت آماده بودن).
  - **Sample Request**
    ```json
    {
      "title": "مقاله لانگ‌فرم درباره برندسازی شخصی برای فریلنسرها",
      "brief": "پوشش روندهای 2025، شبکه‌سازی، ساخت فانل محتوا",
      "audience": "فریلنسرهای ایرانی",
      "tone": "دوستانه",
      "language": "fa",
      "outline": ["مقدمه", "اهمیت برند شخصی", "استراتژی محتوا", "نتیجه‌گیری"],
      "word_count": 1500,
      "include_research": true
    }
    ```
  - **Sample Response**
    ```json
    {
      "id": 12,
      "title": "مقاله لانگ‌فرم درباره برندسازی شخصی برای فریلنسرها",
      "status": "completed",
      "language": "fa",
      "outline": [
        "مقدمه",
        "اهمیت برند شخصی",
        "استراتژی محتوا",
        "نتیجه‌گیری"
      ],
      "result_text": "# مقدمه ...",
      "created_at": "2025-11-27T09:25:00Z",
      "updated_at": "2025-11-27T09:26:10Z",
      "last_error": null
    }
    ```

- `GET /agents/tasks`
  - **Description:** لیست همه تسک‌های کاربر جاری.
  - **Sample Response**
    ```json
    [
      {
        "id": 12,
        "title": "مقاله لانگ‌فرم درباره برندسازی شخصی",
        "status": "completed",
        "language": "fa",
        "outline": [...],
        "result_text": "# مقدمه ...",
        "created_at": "2025-11-27T09:25:00Z",
        "updated_at": "2025-11-27T09:26:10Z",
        "last_error": null
      }
    ]
    ```

- `GET /agents/tasks/{task_id}`
  - **Description:** دریافت جزئیات کامل یک تسک شامل متن خروجی و آخرین وضعیت.
  - **Sample Response**
    ```json
    {
      "id": 12,
      "title": "مقاله لانگ‌فرم درباره برندسازی شخصی",
      "status": "completed",
      "language": "fa",
      "outline": [...],
      "result_text": "# مقدمه ...",
      "created_at": "2025-11-27T09:25:00Z",
      "updated_at": "2025-11-27T09:26:10Z",
      "last_error": null
    }
    ```

### Environment Variables
برای اجرای سرویس، فایل `.env` یا مشابه با مقادیر زیر لازم است (نمونه در `.env.example`):
- `DATABASE_URL`
- `AUTH_SECRET`
- `AUTH_TOKEN_EXPIRES`
- `OTP_EXPIRES_SECONDS`
- `OTP_RESEND_COOLDOWN`
- `OTP_MAX_ATTEMPTS`
- `IPPANEL_API_TOKEN`
- `IPPANEL_FROM_NUMBER`
- `IPPANEL_PATTERN_CODE`
- `IPPANEL_BASE_URL`
- `PUTER_API_KEY`
- `HAR_COOKIE_DIR`

