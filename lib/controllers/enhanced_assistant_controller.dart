import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/conversation_memory_service.dart';
import '../services/smart_cache_service.dart';
import '../services/local_nlp_processor.dart';
import '../services/analytics_service.dart';
import '../services/assistant_service.dart';
import '../services/confidence_service.dart';
import '../models/assistant_models.dart';
import '../widgets/confidence_indicator.dart';

/// Enhanced assistant controller with new AI features
class EnhancedAssistantController extends ChangeNotifier {
  EnhancedAssistantController({
    required AssistantService assistantService,
    required ConversationMemoryService conversationMemory,
    required SmartCacheService smartCache,
    required LocalNLPProcessor localNLP,
    required AnalyticsService analytics,
  })  : _assistantService = assistantService,
        _conversationMemory = conversationMemory,
        _smartCache = smartCache,
        _localNLP = localNLP,
        _analytics = analytics;

  final AssistantService _assistantService;
  final ConversationMemoryService _conversationMemory;
  final SmartCacheService _smartCache;
  final LocalNLPProcessor _localNLP;
  final AnalyticsService _analytics;

  bool _isProcessing = false;
  EnhancedAIResponse? _lastResponse;
  String? _error;

  bool get isProcessing => _isProcessing;
  EnhancedAIResponse? get lastResponse => _lastResponse;
  String? get error => _error;

  /// Process user input with enhanced AI features
  Future<void> processInput(String userInput) async {
    if (userInput.trim().isEmpty) return;

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Check smart cache
      final cached = _smartCache.getCachedResponse(userInput);
      if (cached != null) {
        _handleResponse(userInput, cached, fromCache: true);
        return;
      }

      // Step 2: Try local NLP first
      final localIntent = _localNLP.classifyIntentLocally(userInput);
      if (localIntent != null &&
          (localIntent['confidence'] as double) >= 0.85) {
        // High confidence local classification
        await _handleLocalIntent(userInput, localIntent);
        return;
      }

      // Step 3: Enhance prompt with conversation context
      final enhancedPrompt = _conversationMemory.enhancePrompt(userInput);

      // Step 4: Call API with enhanced context
      final result = await _assistantService.smartIntent(
        SmartIntentRequest(
          text: enhancedPrompt,
          timezone: DateTime.now().timeZoneName,
          now: DateTime.now(),
          context: _conversationMemory.getCurrentContext(),
        ),
      );

      final responseMap = {
        'action': smartActionToString(result.action),
        'payload': result.payload,
        'raw_text': result.rawText,
      };

      // Step 5: Calculate confidence score
      final confidence = ConfidenceService.calculateConfidence(
        userInput: userInput,
        aiResponse: responseMap,
        context: _conversationMemory.getCurrentContext(),
      );

      final confidenceBreakdown = ConfidenceService.getConfidenceBreakdown(
        userInput: userInput,
        aiResponse: responseMap,
        context: _conversationMemory.getCurrentContext(),
      );

      final enhancedResponse = EnhancedAIResponse(
        action: result.action,
        payload: result.payload,
        confidence: confidence,
        confidenceBreakdown: confidenceBreakdown,
        rawText: result.rawText,
      );

      _lastResponse = enhancedResponse;

      // Step 6: Save to conversation memory
      await _conversationMemory.addConversation(
        userInput: userInput,
        aiResponse: result.rawText ?? smartActionToString(result.action),
        metadata: {
          'confidence': confidence,
          'action': smartActionToString(result.action),
        },
      );

      // Step 7: Cache the response
      await _smartCache.cacheResponse(userInput, responseMap);

      // Step 8: Track analytics
      await _analytics.trackAction(
        actionType: smartActionToString(result.action),
        success: true,
        metadata: {'confidence': confidence},
      );

      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isProcessing = false;

      // Track failed action
      await _analytics.trackAction(
        actionType: 'unknown',
        success: false,
      );

      notifyListeners();
    }
  }

  /// Handle local NLP intent
  Future<void> _handleLocalIntent(
    String userInput,
    Map<String, dynamic> localIntent,
  ) async {
    final action = smartActionFromString(localIntent['action'] as String);
    final payload = localIntent['payload'] as Map<String, dynamic>;
    final confidence = localIntent['confidence'] as double;

    final enhancedResponse = EnhancedAIResponse(
      action: action,
      payload: payload,
      confidence: confidence,
      reasoning: 'Classified locally using pattern matching',
    );

    _lastResponse = enhancedResponse;

    await _conversationMemory.addConversation(
      userInput: userInput,
      aiResponse: 'Local: ${smartActionToString(action)}',
      metadata: {
        'confidence': confidence,
        'local': true,
      },
    );

    await _analytics.trackAction(
      actionType: smartActionToString(action),
      success: true,
      metadata: {'confidence': confidence, 'local': true},
    );

    _isProcessing = false;
    notifyListeners();
  }

  /// Handle API response
  void _handleResponse(
    String userInput,
    Map<String, dynamic> response, {
    bool fromCache = false,
  }) {
    final action =
        smartActionFromString(response['action']?.toString() ?? 'suggestion');
    final payload = response['payload'] as Map<String, dynamic>? ?? {};

    final confidence = ConfidenceService.calculateConfidence(
      userInput: userInput,
      aiResponse: response,
      context: _conversationMemory.getCurrentContext(),
    );

    _lastResponse = EnhancedAIResponse(
      action: action,
      payload: payload,
      confidence: confidence,
      reasoning: fromCache ? 'Retrieved from cache' : null,
      rawText: response['raw_text']?.toString(),
    );

    _isProcessing = false;
    notifyListeners();
  }

  /// Clear conversation history
  Future<void> clearHistory() async {
    await _conversationMemory.clearHistory();
    notifyListeners();
  }

  /// Get conversation statistics
  Map<String, dynamic> getConversationStats() {
    return _conversationMemory.getStatistics();
  }

  /// Get analytics insights
  List<String> getInsights() {
    return _analytics.getInsights();
  }

  /// Get productivity score
  int getProductivityScore() {
    return _analytics.calculateProductivityScore();
  }
}

/// Example usage widget
class EnhancedAssistantExample extends StatefulWidget {
  const EnhancedAssistantExample({super.key});

  @override
  State<EnhancedAssistantExample> createState() =>
      _EnhancedAssistantExampleState();
}

class _EnhancedAssistantExampleState extends State<EnhancedAssistantExample> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // You would need to create an instance of EnhancedAssistantController
    // and provide it through Provider or create it here

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.pushNamed(context, '/analytics');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildResponseCard(),
                const SizedBox(height: 16),
                _buildConversationStats(),
                const SizedBox(height: 16),
                _buildInsights(),
              ],
            ),
          ),
          _buildInputSection(),
        ],
      ),
    );
  }

  Widget _buildResponseCard() {
    // Example response display with confidence indicator
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'AI Response',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ConfidenceIndicator(
                  confidence: 0.85,
                  showLabel: true,
                  size: IndicatorSize.small,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Your response will appear here with confidence scoring.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationStats() {
    final conversationMemory = context.read<ConversationMemoryService>();
    final stats = conversationMemory.getStatistics();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conversation Stats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Total: ${stats['total_conversations']}'),
            Text('Context age: ${stats['context_age_minutes']} min'),
            Text('Topics: ${stats['topics_tracked']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights() {
    final analytics = context.read<AnalyticsService>();
    final insights = analytics.getInsights();

    if (insights.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...insights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $insight'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Ask me anything...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    // Implementation would call EnhancedAssistantController
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Example: controller.processInput(text);
    _controller.clear();
  }
}
