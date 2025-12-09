# 🤖 Chat Analysis Service - راهنمای استفاده

**تاریخ**: دسامبر 6، 2025
**وضعیت**: ✅ Chat API Integration Ready

---

## 📝 خلاصه

`ChatAnalysisService` جایگزین `MessageAnalysisService` است که:
- از **FastAPI Backend Chat Endpoint** استفاده می‌کند
- از **Large Language Models** (GPT-4, Claude, etc.) استفاده می‌کند
- **دقیق‌تر و بهتر** از NLP محلی است
- **streaming** پاسخ‌ها برای بهتر بودن UX

---

## 🔄 تغییرات انجام شده

### ❌ قدیم (LocalNLP)
```dart
final messageAnalysisService = MessageAnalysisService(
  nlp: localNLP,  // محلی و محدود
  prefs: prefs,
);
```

### ✅ جدید (Chat API)
```dart
final chatAnalysisService = ChatAnalysisService(
  accessToken: authController.token,  // API token
);
```

---

## 📋 Methods موجود

### 1. تحلیل کامل پیام
```dart
final result = await chatAnalysisService.analyzeMessage(message);
// Returns:
// {
//   'priority': MessagePriority.high,
//   'summary': 'خلاصه پیام',
//   'needsReply': true,
//   'keyPoints': ['نکته 1', 'نکته 2'],
//   'suggestedActions': ['reply', 'save']
// }
```

### 2. استخراج نکات مهم
```dart
final keyPoints = await chatAnalysisService.extractKeyPoints(message);
// Returns: ['نکته 1', 'نکته 2', 'نکته 3']
```

### 3. تشخیص اولویت
```dart
final priority = await chatAnalysisService.detectPriority(message);
// Returns: MessagePriority.high / medium / low
```

### 4. خلاصه‌سازی
```dart
final summary = await chatAnalysisService.getSummary(message);
// Returns: 'خلاصه یک‌جمله‌ای'
```

### 5. بررسی نیاز به پاسخ
```dart
final needsReply = await chatAnalysisService.needsReply(message);
// Returns: true / false
```

### 6. استخراج اطلاعات شخصی
```dart
final info = await chatAnalysisService.extractPersonalInfo(message);
// Returns: ExtractedMessageInfo
// {
//   names: ['علی', 'فاطمه'],
//   locations: ['تهران'],
//   dates: ['فردا'],
//   times: ['ساعت 3'],
//   phoneNumbers: ['+989123456789'],
//   emails: ['example@gmail.com'],
//   emotions: ['خوشحالی', 'اسف']
// }
```

---

## 🎯 کیف استفاده در UI

### مثال 1: در RemindersManagementPage
```dart
Consumer<ChatAnalysisService>(
  builder: (context, analyzer, _) {
    return FutureBuilder(
      future: analyzer.analyzeMessage(message),
      builder: (ctx, snapshot) {
        if (snapshot.hasData) {
          final analysis = snapshot.data!;
          return Column(
            children: [
              Text('اولویت: ${analysis['priority']}'),
              Text('خلاصه: ${analysis['summary']}'),
              Text('نیاز به پاسخ: ${analysis['needsReply']}'),
            ],
          );
        }
        return const CircularProgressIndicator();
      },
    );
  }
)
```

### مثال 2: در ChatPage
```dart
final analyzer = context.read<ChatAnalysisService>();

// دریافت پیام و تحلیل آن
final response = await analyzer.analyzeMessage(incomingMessage);
print('Priority: ${response['priority']}');
print('Suggested Actions: ${response['suggestedActions']}');
```

### مثال 3: Batch Analysis
```dart
final analyzer = context.read<ChatAnalysisService>();

for (final message in messages) {
  final analysis = await analyzer.analyzeMessage(message);
  // ... استفاده از تحلیل
}
```

---

## ⚙️ تنظیم Backend URL

در `chat_analysis_service.dart` تغییر دهید:

```dart
static const String _baseUrl = 'http://localhost:8000';
// یا
static const String _baseUrl = 'https://your-api.com';
```

---

## 🔐 توکن دسترسی

توکن باید تنظیم شود:

```dart
// در main.dart
final chatAnalysisService = ChatAnalysisService(
  accessToken: authController.token,
);

// یا بعد‌تر
chatAnalysisService.setAccessToken(newToken);
```

---

## 📡 API Flow

```
Flutter App
    ↓ analyzeMessage(message)
ChatAnalysisService
    ↓ _buildAnalysisPrompt()
FastAPI /chat/stream
    ↓ streaming response
LLM (GPT-4, Claude, etc.)
    ↓ analysis result
    ↑
ChatAnalysisService
    ↓ _parseAnalysisResponse()
Flutter App
    ↓ display result
```

---

## ✨ مزایا

✅ **دقیق‌تر**: LLM بسیار بهتر از NLP محلی است
✅ **انعطاف‌پذیر**: می‌تواند به هر نوع پیام پاسخ دهد
✅ **Streaming**: پاسخ‌ها به‌صورت streaming دریافت می‌شوند
✅ **Bilingual**: فارسی و انگلیسی را درک می‌کند
✅ **Context-Aware**: متن کامل را درک می‌کند
✅ **Fallback**: اگر API down باشد، fallback methods استفاده می‌شود

---

## ⚠️ محدودیت‌ها

❌ نیاز به Internet دارد
❌ API timeout ممکن است
❌ API rate limiting ممکن است
❌ هزینه API (اگر استفاده از OpenAI باشد)

---

## 🔧 Error Handling

```dart
try {
  final result = await chatAnalysisService.analyzeMessage(message);
  print(result);
} catch (e) {
  print('Error: $e');
  // Automatically falls back to default analysis
}
```

همیشه fallback methods استفاده می‌شود اگر مشکل پیش بیاید.

---

## 📊 Performance

```
Local NLP:        ~50-100ms (سریع)
Chat API:         ~500-2000ms (کند‌تر اما دقیق‌تر)
```

برای بهتر بودن UX، می‌توانید:
- Streaming نشان دهید
- Loading indicator نشان دهید
- Background میں اجرا کنید

---

## 🎯 بهترین Practices

### ✅ درست
```dart
// Streaming در background
_performAnalysis() async {
  final result = await analyzer.analyzeMessage(message);
  setState(() {
    analysis = result;
  });
}

// یا با Builder
FutureBuilder(
  future: analyzer.analyzeMessage(message),
  builder: (ctx, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    return Text(snapshot.data['summary']);
  }
)
```

### ❌ غلط
```dart
// نه! در UI thread نباید مسدود شود
final result = await analyzer.analyzeMessage(message);
// ... خطرناک!
```

---

## 🔄 Integration با RemindersManagementPage

```dart
// در _buildReminderCard
FutureBuilder<Map<String, dynamic>>(
  future: context.read<ChatAnalysisService>()
      .analyzeMessage(reminder.relatedMessage),
  builder: (ctx, snapshot) {
    if (snapshot.hasData) {
      final priority = snapshot.data!['priority'];
      return Chip(
        label: Text(priority.toString()),
        backgroundColor: priority == MessagePriority.high 
          ? Colors.red 
          : Colors.blue,
      );
    }
    return CircularProgressIndicator();
  }
)
```

---

## 🚀 مرحله‌های بعد

1. تست کردن Chat API با واقعی messages
2. اضافه کردن caching برای نتایج (اختیاری)
3. اضافه کردن timeout handling
4. اضافه کردن retry logic
5. Monitoring و logging

---

## 📞 تکنیکی‌‌

### Request Format
```json
{
  "session_id": "message_analysis_1701857400000",
  "web_search": false,
  "messages": [
    {
      "role": "user",
      "content": "سوال یا متنی برای تحلیل"
    }
  ]
}
```

### Response Format (SSE)
```
event: token
data: {"text":"جواب"}

event: token
data: {"text":"جواب"}

event: done
data: {"latency_ms":2300,"model":"gpt-4o","text":"جواب کامل"}
```

---

## ✅ Checklist

- [x] ChatAnalysisService ایجاد شد
- [x] HTTP requests پیاده‌سازی شد
- [x] SSE streaming پیاده‌سازی شد
- [x] Fallback methods اضافه شد
- [x] Integration با main.dart انجام شد
- [x] RemindersManagementPage ready است
- [ ] Testing on real device
- [ ] Rate limiting handling
- [ ] Caching implementation

---

## 🎊 خلاصه

**قدیم**: محلی NLP → محدود و کند
**جدید**: Chat API + LLM → دقیق و هوشمند

**Status**: ✅ Ready to Use

---

*Last Updated: December 6, 2025*

