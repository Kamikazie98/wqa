# Smart Assistant Feature Plan

This document maps the requested assistant abilities to the current Flutter client and the backend endpoints that already exist. All times are ISO 8601 and should be converted to `ZonedDateTime` before scheduling on device.

## Backend endpoints to call
- `POST /assistant/intent` → detects action + payload from free text or speech-to-text.
- `POST /assistant/daily-briefing` → builds the 9 AM briefing card/notification.
- `POST /assistant/next-action` → answers “what should I do now?”.
- `POST /assistant/modes/decide` → proposes work/home/focus/travel/sleep.
- `POST /assistant/notifications/classify` → triage incoming notifications.
- `POST /assistant/inbox/intel` → summarise a message and suggest actions.
- `POST /assistant/scheduler/weekly` → weekly plan from goals + hard events.
- `POST /assistant/memory/upsert` and `/assistant/memory/search` → long-term memory.

## Client building blocks (added in code)
- `lib/models/assistant_models.dart` defines SmartAction enum + request/response models for all endpoints.
- `lib/services/assistant_service.dart` wraps the endpoints with typed methods.
- `AssistantService` is registered in `main.dart` via Provider, so pages/controllers can inject it.

## Execution plan by capability
- **NLP reminders + follow-ups**: speech/text → `assistantService.smartIntent()`; if `action=reminder|follow_up`, schedule via `flutter_local_notifications` + `WorkManager` (use `payload.datetime|deadline`). Keep a lightweight local DB/box for pending jobs so WorkManager can reschedule after reboot.
- **Phone actions (call/message/open apps)**: map intent payload to platform intents. SMS: `ACTION_VIEW smsto:` with `suggested_text`; WhatsApp/Telegram: deep link with prefill; call: `ACTION_DIAL`; open app/link/camera/gallery: `Intent` with appropriate action and `url_launcher` fallback.
- **Daily briefing (9 AM)**: WorkManager periodic task → call `/assistant/daily-briefing` with tasks/messages/context → render a notification + Today page card (tone from payload). Cache latest briefing for offline view.
- **“What now?” suggestions**: UI card calls `/assistant/next-action` with available minutes, mode, energy, tasks. Show primary suggestion + two alternatives with quick actions (reply/remind/navigate).
- **Modes**: run `/assistant/modes/decide` when GPS/WiFi/time triggers fire; update app state (e.g., focus mode hides noisy prompts). Persist preferred schedule and last mode locally.
- **Notification intelligence**: Android Notification Listener service → batch recent notifications into `/assistant/notifications/classify`; show inline chips: critical/important/normal/spam + suggested action (e.g., create reminder).
- **Inbox intelligence**: per message → `/assistant/inbox/intel`; surface summary + suggested reply/reminder/note CTA inside chat detail screen.
- **Smart scheduler**: goals + hard events → `/assistant/scheduler/weekly`; generate local calendar inserts + reminders, handle conflicts list in UI.
- **Memory**: every confirmed fact → `/assistant/memory/upsert`; before answering personalised prompts, query `/assistant/memory/search`. Keep a local cache keyed by `context` to reduce calls when offline.
- **Routines/automation**: treat as `action=routine|automation` from `/assistant/intent`; store conditions (time, location, WiFi, driving) locally and execute via WorkManager/foreground services.

## Offline + multi-agent notes
- **Offline first**: before calling backend, optional small on-device model can draft a fallback (summary/rough intent). Use it only for latency reduction; always sync with server when back online to normalise payloads.
- **Multi-agent**: set `context.agent` (reminder|messaging|contact|scheduling|notification|memory) when the UI knows the intent to steer the backend prompt without extra switches in the client.

## Minimal next steps to ship
- Wire Home/Chat input to `AssistantService.smartIntent` with voice input using existing speech-to-text module, then dispatch by `SmartAction`.
- Build an `ActionExecutor` helper that maps each `SmartAction` to local side-effects (notifications, WorkManager jobs, intents, calendar inserts).
- Add WorkManager tasks: `daily_briefing` (09:00 local), `follow_up` checks at deadline, and reschedule after reboot.
- Create slim UI surfaces: reminder confirmation sheet, quick-send message sheet (prefilled), and “what now?” card with 1 primary + 2 alternatives.
