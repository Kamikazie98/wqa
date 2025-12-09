# 🔐 ChatAnalysisService Token Management

**تاریخ**: دسامبر 6، 2025
**موضوع**: مدیریت توکن دسترسی

---

## 🎯 مشکل

`ChatAnalysisService` برای ارتباط با Backend API نیاز به توکن دسترسی دارد، اما:
- توکن زمان ورود دریافت می‌شود
- توکن ممکن است refresh شود
- سرویس باید همیشه توکن جدید داشته باشد

---

## ✅ راه‌حل

### گزینه 1: Direct Reference
```dart
// در main.dart
final chatAnalysisService = ChatAnalysisService();

// بعد هر auth تغییر
authController.addListener(() {
  chatAnalysisService.setAccessToken(authController.token);
});
```

### گزینه 2: Token Getter Callback (توصیه شده)
```dart
// بهتر: تغییر ChatAnalysisService

class ChatAnalysisService extends ChangeNotifier {
  final String Function() tokenProvider;
  
  ChatAnalysisService({required this.tokenProvider});
  
  Future<String> _sendChatRequest(String prompt) async {
    final token = tokenProvider(); // همیشه توکن جدید
    // ... rest of code
  }
}

// در main.dart
final chatAnalysisService = ChatAnalysisService(
  tokenProvider: () => authController.token,
);
```

### گزینه 3: API Client استفاده
```dart
// استفاده از موجود ApiClient

class ChatAnalysisService extends ChangeNotifier {
  final ApiClient apiClient;
  
  ChatAnalysisService({required this.apiClient});
  
  Future<String> _sendChatRequest(String prompt) async {
    // ApiClient خود مدیریت توکن می‌کند
    final response = await apiClient.post('/chat/stream', body: ...);
  }
}
```

---

## 🏆 پیشنهاد بهترین راه‌حل

استفاده از **ApiClient** که از قبل در پروژه است:

```dart
// lib/services/chat_analysis_service.dart (بروزرسانی)

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../models/message_models.dart';
import 'api_client.dart';

class ChatAnalysisService extends ChangeNotifier {
  final ApiClient apiClient;
  
  ChatAnalysisService({required this.apiClient});

  /// ارسال درخواست به Chat API
  Future<String> _sendChatRequest(String prompt) async {
    try {
      final body = {
        'session_id': 'message_analysis_${DateTime.now().millisecondsSinceEpoch}',
        'web_search': false,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
      };

      // ApiClient تولید درخواست می‌کند و توکن مدیریت می‌کند
      final uri = Uri.parse('${apiClient.baseUrl}/chat/stream');
      
      final request = http.StreamedRequest('POST', uri)
        ..headers.addAll({
          'Authorization': 'Bearer ${apiClient.getToken()}', // توکن خودکار
          'Content-Type': 'application/json',
        })
        ..write(jsonEncode(body));

      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode != 200) {
        throw Exception('API error: ${streamedResponse.statusCode}');
      }

      String fullResponse = '';
      
      await streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
        if (line.startsWith('data: ')) {
          try {
            final json = jsonDecode(line.substring(6));
            if (json['text'] != null) {
              fullResponse += json['text'];
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }
      });

      return fullResponse;
    } catch (e) {
      print('Error in chat request: $e');
      rethrow;
    }
  }

  // ... بقیه methods بدون تغییر
}
```

---

## 🔄 تکامل main.dart

```dart
// قدیم
final messageAnalysisService = MessageAnalysisService(
  nlp: localNLP,
  prefs: prefs,
);

// جدید
final chatAnalysisService = ChatAnalysisService(
  apiClient: apiClient, // ApiClient از قبل موجود است
);
```

---

## 📋 مزایای این راه‌حل

✅ **خودکار**: توکن همیشه تازه است
✅ **متحد**: از ApiClient موجود استفاده می‌کند
✅ **ایمن**: Centralized token management
✅ **سادگی**: کم تغییر لازم است
✅ **Refresh**: اگر توکن refresh شود، خودکار به‌روز می‌شود

---

## 🛠️ Implementation Steps

### Step 1: بروزرسانی ChatAnalysisService
استفاده از ApiClient به جای مستقیم HTTP

### Step 2: بروزرسانی main.dart
```dart
final chatAnalysisService = ChatAnalysisService(
  apiClient: apiClient,
);
```

### Step 3: بروزرسانی providers
```dart
ChangeNotifierProvider<ChatAnalysisService>.value(
  value: chatAnalysisService,
)
```

---

## ✅ Result

```
Authentication Flow:
├─ User logs in
├─ AuthController gets token from API
├─ Token automatically used by ChatAnalysisService
├─ Token refresh automatically handled
└─ Always latest token! ✅
```

---

**Status**: Ready to Implement
**Time Required**: 5 minutes
**Complexity**: Low

