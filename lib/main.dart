
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'controllers/auth_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/assistant_controller.dart';
import 'controllers/habit_controller.dart';
import 'controllers/productivity_controller.dart';
import 'controllers/activity_controller.dart';
import 'controllers/groups_controller.dart';
import 'services/api_client.dart';
import 'services/assistant_service.dart';
import 'services/action_executor.dart';
import 'services/automation_service.dart';
import 'services/notification_service.dart';
import 'services/session_storage.dart';
import 'services/workmanager_service.dart';
import 'services/conversation_memory_service.dart';
import 'services/smart_cache_service.dart';
import 'services/proactive_automation_service.dart';
import 'services/local_nlp_processor.dart';
import 'services/analytics_service.dart';
import 'services/user_profile_service.dart';
import 'services/daily_program_service.dart';
import 'services/smart_scheduling_service.dart';
import 'services/message_reader_service.dart';
import 'services/message_analysis_service.dart';
import 'services/chat_analysis_service.dart';
import 'services/smart_reminders_service.dart';
import 'services/notification_triage_service.dart';
import 'screens/permissions_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/productivity_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/groups_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.initBackground();
  await NotificationService.showRemoteMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + FCM background handler
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // اینا می‌تونن مستقل از دسترسی‌ها آماده بشن
  await WorkmanagerService.initialize();
  await WorkmanagerService.scheduleDailyBriefing();
  await WorkmanagerService.scheduleNotificationTriage();
  await WorkmanagerService.scheduleInboxIntel();

  final prefs = await SharedPreferences.getInstance();

  final automationService = AutomationService(prefs: prefs);

  final authController = AuthController(prefs: prefs);
  final apiClient = ApiClient(tokenProvider: () => authController.token);
  final assistantService = AssistantService(apiClient: apiClient);
  authController.attachApiClient(apiClient);

  final notificationService = NotificationService();
  await notificationService.init();
  notificationService.onTokenRefresh(authController.updateDeviceToken);
  authController.attachNotificationService(notificationService);
  authController.updateDeviceToken(notificationService.token);
  authController.updateDevicePlatform(_resolvePlatform());

  if (authController.userId != null) {
    await notificationService.subscribeUserTopic(authController.userId!);
  }

  final sessionStorage = SessionStorage(prefs);
  final chatController = ChatController(
    apiClient: apiClient,
    storage: sessionStorage,
  );
  final assistantController =
      AssistantController(assistantService: assistantService);
  final actionExecutor = ActionExecutor(notificationService, assistantService);

  // Initialize new AI/NLP services
  final conversationMemory = ConversationMemoryService(prefs: prefs);
  final smartCache = SmartCacheService(prefs: prefs);
  final proactiveAutomation = ProactiveAutomationService(
    prefs: prefs,
  );
  final localNLP = LocalNLPProcessor();
  final analytics = AnalyticsService(prefs: prefs);

  // Initialize Phase 2 services (Daily Program & Smart Scheduling)
  final userProfileService = UserProfileService(apiClient: apiClient);
  final dailyProgramService = DailyProgramService(apiClient: apiClient);
  final smartSchedulingService = SmartSchedulingService();

  // Initialize Phase 3 services (Message & Reminder Features)
  final messageReaderService = MessageReaderService(prefs: prefs);
  final messageAnalysisService = MessageAnalysisService(nlp: localNLP);
  final chatAnalysisService = ChatAnalysisService(
    apiClient: apiClient,
  );
  final smartRemindersService = SmartRemindersService(
    prefs: prefs,
  );
  final notificationTriageService = NotificationTriageService(
    prefs: prefs,
    notificationService: notificationService,
    assistantService: assistantService,
  );
  await smartRemindersService.loadReminders();

  // Initialize message reader watching
  messageReaderService.startWatching();

  await automationService.restore();

  // Start proactive learning
  proactiveAutomation.startLearning();

  runApp(
    WaiqRootApp(
      authController: authController,
      apiClient: apiClient,
      assistantService: assistantService,
      notificationService: notificationService,
      automationService: automationService,
      chatController: chatController,
      assistantController: assistantController,
      actionExecutor: actionExecutor,
      conversationMemory: conversationMemory,
      smartCache: smartCache,
      proactiveAutomation: proactiveAutomation,
      localNLP: localNLP,
      analytics: analytics,
      userProfileService: userProfileService,
      dailyProgramService: dailyProgramService,
      smartSchedulingService: smartSchedulingService,
      messageReaderService: messageReaderService,
      messageAnalysisService: messageAnalysisService,
      chatAnalysisService: chatAnalysisService,
      smartRemindersService: smartRemindersService,
      notificationTriageService: notificationTriageService,
    ),
  );
}

/// روت اپ که هم Providerها رو ستاپ می‌کنه هم فلوی Permissions → App رو مدیریت می‌کنه.
class WaiqRootApp extends StatelessWidget {
  final AuthController authController;
  final ApiClient apiClient;
  final AssistantService assistantService;
  final NotificationService notificationService;
  final AutomationService automationService;
  final ChatController chatController;
  final AssistantController assistantController;
  final ActionExecutor actionExecutor;
  final ConversationMemoryService conversationMemory;
  final SmartCacheService smartCache;
  final ProactiveAutomationService proactiveAutomation;
  final LocalNLPProcessor localNLP;
  final AnalyticsService analytics;
  final UserProfileService userProfileService;
  final DailyProgramService dailyProgramService;
  final SmartSchedulingService smartSchedulingService;
  final MessageReaderService messageReaderService;
  final MessageAnalysisService messageAnalysisService;
  final ChatAnalysisService chatAnalysisService;
  final SmartRemindersService smartRemindersService;
  final NotificationTriageService notificationTriageService;

  const WaiqRootApp({
    super.key,
    required this.authController,
    required this.apiClient,
    required this.assistantService,
    required this.notificationService,
    required this.automationService,
    required this.chatController,
    required this.assistantController,
    required this.actionExecutor,
    required this.conversationMemory,
    required this.smartCache,
    required this.proactiveAutomation,
    required this.localNLP,
    required this.analytics,
    required this.userProfileService,
    required this.dailyProgramService,
    required this.smartSchedulingService,
    required this.messageReaderService,
    required this.messageAnalysisService,
    required this.chatAnalysisService,
    required this.smartRemindersService,
    required this.notificationTriageService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: authController),
        Provider<ApiClient>.value(value: apiClient),
        Provider<AssistantService>.value(value: assistantService),
        Provider<ActionExecutor>.value(value: actionExecutor),
        Provider<NotificationService>.value(value: notificationService),
        Provider<AutomationService>.value(value: automationService),
        ChangeNotifierProvider<ChatController>.value(value: chatController),
        ChangeNotifierProvider<AssistantController>.value(
          value: assistantController,
        ),
        ChangeNotifierProvider<HabitController>(
          create: (_) => HabitController(Provider.of<ApiService>(context, listen: false)),
        ),
        ChangeNotifierProvider<ProductivityController>(
          create: (_) => ProductivityController(Provider.of<ApiService>(context, listen: false)),
        ),
        ChangeNotifierProvider<ActivityController>(
          create: (_) => ActivityController(Provider.of<ApiService>(context, listen: false)),
        ),
        ChangeNotifierProvider<GroupsController>(
          create: (_) => GroupsController(Provider.of<ApiService>(context, listen: false)),
        ),
        // New AI/NLP services
        Provider<ConversationMemoryService>.value(value: conversationMemory),
        Provider<SmartCacheService>.value(value: smartCache),
        Provider<ProactiveAutomationService>.value(value: proactiveAutomation),
        Provider<LocalNLPProcessor>.value(value: localNLP),
        Provider<AnalyticsService>.value(value: analytics),
        // Phase 2 services (Daily Program & Smart Scheduling)
        ChangeNotifierProvider<UserProfileService>.value(
          value: userProfileService,
        ),
        ChangeNotifierProvider<DailyProgramService>.value(
          value: dailyProgramService,
        ),
        ChangeNotifierProvider<SmartSchedulingService>.value(
          value: smartSchedulingService,
        ),
        // Phase 3 services (Message & Reminder Features)
        Provider<MessageReaderService>.value(value: messageReaderService),
        Provider<MessageAnalysisService>.value(value: messageAnalysisService),
        ChangeNotifierProvider<ChatAnalysisService>.value(
          value: chatAnalysisService,
        ),
        ChangeNotifierProvider<SmartRemindersService>.value(
          value: smartRemindersService,
        ),
        Provider<NotificationTriageService>.value(
            value: notificationTriageService),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Waiq Assistant',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed:
              const Color(0xFF6750A4), // می‌تونی رنگ برند خودت رو بذاری
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF5F5F7),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        // فلوی حرفه‌ای: اول صفحه Permissionها، بعد خود اپ
        initialRoute: '/permissions',
        routes: {
          '/permissions': (context) => const PermissionsScreen(),
          '/': (context) => const WaiqApp(),
          '/habits': (context) => const HabitsScreen(),
          '/productivity': (context) => const ProductivityScreen(),
          '/activity': (context) => const ActivityScreen(),
          '/groups': (context) => const GroupsScreen(),
        },
      ),
    );
  }
}

String _resolvePlatform() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'ios',
    TargetPlatform.windows => 'web',
    TargetPlatform.linux => 'web',
    TargetPlatform.fuchsia => 'web',
  };
}
