from pathlib import Path

path = Path("lib/features/tools/tools_page.dart")
text = path.read_text(encoding="utf-8")
marker = "  void _showError(Object error) {\n"
block = """  Row _cardHeader({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _runDailyBriefing() async {
    final assistant = context.read<AssistantService>();
    setState(() {
      _briefingLoading = true;
      _opsError = null;
    });
    try {
      final now = DateTime.now();
      final contextMap = _decodeContext(_briefingNotesController.text);
      final result = await assistant.dailyBriefing(
        DailyBriefingRequest(
          timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
          now: now,
          context: contextMap,
        ),
      );
      setState(() => _dailyBriefingResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _briefingLoading = false);
    }
  }

  Future<void> _runNextAction() async {
    final assistant = context.read<AssistantService>();
    final minutes = int.tryParse(_nextMinutesController.text.trim());
    if (minutes == null || minutes <= 0) {
      setState(() => _opsError = '???? ???? ??????? ???');
      return;
    }
    setState(() {
      _nextActionLoading = true;
      _opsError = null;
    });
    try {
      final tasks = _lines(_nextTasksController.text);
      final result = await assistant.nextAction(
        NextActionRequest(
          availableMinutes: minutes,
          energy: _energy,
          mode: _mode,
          tasks: tasks,
        ),
      );
      setState(() => _nextActionResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _nextActionLoading = false);
    }
  }

  Future<void> _runModeDecision() async {
    final assistant = context.read<AssistantService>();
    setState(() {
      _modeLoading = true;
      _opsError = null;
    });
    try {
      final now = DateTime.now();
      final contextMap = _decodeContext(_modeContextController.text);
      final result = await assistant.decideMode(
        ModeDecisionRequest(
          text: _modeTextController.text.trim(),
          timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
          now: now,
          mode: _mode,
          energy: _energy,
          context: contextMap,
        ),
      );
      setState(() => _modeDecisionResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _modeLoading = false);
    }
  }

  Future<void> _runInboxIntel() async {
    final assistant = context.read<AssistantService>();
    setState(() {
      _inboxLoading = true;
      _opsError = null;
    });
    try {
      final result = await assistant.inboxIntel(
        InboxIntelRequest(
          message: _inboxMessageController.text.trim(),
          channel: _inboxChannelController.text.trim().isEmpty
              ? 'sms'
              : _inboxChannelController.text.trim(),
        ),
      );
      setState(() => _inboxIntelResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _inboxLoading = false);
    }
  }

  Future<void> _runNotificationTriage() async {
    final assistant = context.read<AssistantService>();
    setState(() {
      _triageLoading = true;
      _opsError = null;
    });
    try {
      final jsonList = jsonDecode(_triageInputController.text.trim());
      final items = List<Map<String, dynamic>>.from(
        (jsonList as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final now = DateTime.now();
      final result = await assistant.classifyNotifications(
        NotificationTriageRequest(
          notifications: items,
          mode: _triageMode,
          timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
        ),
      );
      setState(() => _triageResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _triageLoading = false);
    }
  }

  Future<void> _runWeeklySchedule() async {
    final assistant = context.read<AssistantService>();
    setState(() {
      _weeklyLoading = true;
      _opsError = null;
    });
    try {
      final goals = _lines(_weeklyGoalsController.text);
      final hardEventsJson = _weeklyEventsController.text.trim().isEmpty
          ? <dynamic>[]
          : jsonDecode(_weeklyEventsController.text.trim());
      final hardEvents = List<Map<String, dynamic>>.from(
        (hardEventsJson as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final now = DateTime.now();
      final result = await assistant.weeklySchedule(
        WeeklyScheduleRequest(
          goals: goals,
          hardEvents: hardEvents,
          timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
          now: now,
        ),
      );
      setState(() => _weeklyResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _weeklyLoading = false);
    }
  }

  Future<void> _runMemoryUpsert() async {
    final assistant = context.read<AssistantService>();
    final facts = _lines(_memoryFactsController.text);
    if (_memoryKeyController.text.trim().isEmpty || facts.isEmpty) {
      setState(() => _opsError = '???? ? ????? ?? Fact ???? ???');
      return;
    }
    setState(() {
      _memoryUpserting = true;
      _opsError = null;
    });
    try {
      final result = await assistant.memoryUpsert(
        MemoryUpsertRequest(
          facts: facts,
          key: _memoryKeyController.text.trim(),
        ),
      );
      setState(() => _memorySavedCount = result.saved);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _memoryUpserting = false);
    }
  }

  Future<void> _runMemorySearch() async {
    final assistant = context.read<AssistantService>();
    if (_memoryQueryController.text.trim().isEmpty) {
      setState(() => _opsError = '????? ????? ???? ???');
      return;
    }
    setState(() {
      _memorySearching = true;
      _opsError = null;
    });
    try {
      final result = await assistant.memorySearch(
        MemorySearchRequest(query: _memoryQueryController.text.trim()),
      );
      setState(() => _memorySearchResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _memorySearching = false);
    }
  }

  Map<String, dynamic> _decodeContext(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>):
        return decoded
      return <String, dynamic>{}
    except Exception:
      return {'notes': raw}

  List<String> _lines(String raw) {
    return raw.split('\n')
        .map(lambda e: e.strip())
        .filter(lambda e: e)
  }

"""
text = text.replace(marker, block + marker)
path.write_text(text, encoding="utf-8")
