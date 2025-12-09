import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';

import '../models/user_models.dart';
import 'api_client.dart';
import 'notification_service.dart';

/// Location-based reminder service using geofencing
class LocationReminderService {
  final ApiClient apiClient;
  final NotificationService notificationService;

  late StreamSubscription<Position> _positionStream;
  Map<String, GeoFence> _activeGeofences = {};
  Map<String, DateTime> _lastNotificationTime = {};
  bool _isMonitoring = false;

  // Debounce duration to prevent multiple notifications
  static const _notificationDebounce = Duration(seconds: 30);

  LocationReminderService({
    required this.apiClient,
    required this.notificationService,
  });

  /// Initialize location monitoring with high accuracy
  Future<void> startLocationMonitoring() async {
    if (_isMonitoring) return;

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('مجوز دسترسی به موقعیت مکانی رد شده است');
      }

      // Load active geofences from API
      await _loadActiveGeofences();

      if (_activeGeofences.isEmpty) {
        return;
      }

      _isMonitoring = true;

      // Start high-accuracy position stream
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
          timeLimit: Duration(minutes: 5),
        ),
      ).listen(
        _onLocationUpdate,
        onError: (error) {
          print('Location stream error: $error');
          _isMonitoring = false;
        },
      );

      // Also register background task for periodic checks
      await Workmanager().registerPeriodicTask(
        'location_geofence_check',
        'checkLocationGeofences',
        frequency: const Duration(minutes: 15),
      );

      print('Location monitoring started');
    } catch (e) {
      print('Error starting location monitoring: $e');
      rethrow;
    }
  }

  /// Stop location monitoring
  Future<void> stopLocationMonitoring() async {
    try {
      await _positionStream.cancel();
      await Workmanager().cancelByTag('location_geofence_check');
      _isMonitoring = false;
      _activeGeofences.clear();
      print('Location monitoring stopped');
    } catch (e) {
      print('Error stopping location monitoring: $e');
    }
  }

  /// Load active geofences from backend
  Future<void> _loadActiveGeofences() async {
    try {
      final response = await apiClient.getJson('/user/geofences');

      if (response['geofences'] != null) {
        final geofences =
            parseGeofences(response['geofences'] as List<dynamic>);
        _activeGeofences = {for (var gf in geofences) gf.geofenceId: gf};
        print('Loaded ${_activeGeofences.length} active geofences');
      }
    } catch (e) {
      print('Error loading geofences: $e');
    }
  }

  /// Handle location updates and check geofences
  Future<void> _onLocationUpdate(Position position) async {
    for (final geofence in _activeGeofences.values) {
      if (!geofence.isActive) continue;

      final isWithin =
          geofence.isLocationWithin(position.latitude, position.longitude);
      final lastNotification = _lastNotificationTime[geofence.geofenceId];
      final shouldNotify = lastNotification == null ||
          DateTime.now().difference(lastNotification) > _notificationDebounce;

      if (isWithin && shouldNotify && geofence.entryAction != 'silent') {
        await _triggerGeofenceNotification(geofence, 'entry');
        _lastNotificationTime[geofence.geofenceId] = DateTime.now();
      }
    }
  }

  /// Trigger notification for geofence entry/exit
  Future<void> _triggerGeofenceNotification(
      GeoFence geofence, String action) async {
    try {
      // Get task details
      final taskResponse = await apiClient.getJson('/tasks/${geofence.taskId}');
      final task = UserTask.fromJson(taskResponse);

      String title = 'یادآوری: ${geofence.name}';
      String body = task.title;

      if (geofence.entryAction == 'remind') {
        await notificationService.showLocalNow(
          title: title,
          body: body,
          payload: jsonEncode({
            'type': 'geofence_reminder',
            'geofence_id': geofence.geofenceId,
            'task_id': geofence.taskId,
            'action': action,
          }),
        );
      } else if (geofence.entryAction == 'notify') {
        // Silent notification - just log to backend
        await apiClient
            .postJson('/user/geofences/${geofence.geofenceId}/checkin', body: {
          'latitude': 0, // Would be from position
          'longitude': 0,
          'action': action,
        });
      }

      // Log the checkin to backend
      await _logGeofenceCheckin(geofence.geofenceId, action);
    } catch (e) {
      print('Error triggering geofence notification: $e');
    }
  }

  /// Log geofence check-in to backend
  Future<void> _logGeofenceCheckin(String geofenceId, String action) async {
    try {
      final position = await Geolocator.getCurrentPosition();
      await apiClient.postJson('/user/geofences/$geofenceId/checkin', body: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'action': action,
        'accuracy': position.accuracy,
      });
    } catch (e) {
      print('Error logging geofence checkin: $e');
    }
  }

  /// Create a new geofence for a task
  Future<GeoFence?> createGeofence({
    required String taskId,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    String entryAction = 'remind',
    String? exitAction,
  }) async {
    try {
      final response = await apiClient.postJson('/user/geofences', body: {
        'task_id': taskId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'entry_action': entryAction,
        'exit_action': exitAction,
      });

      final geofence = GeoFence.fromJson(response);
      _activeGeofences[geofence.geofenceId] = geofence;
      return geofence;
    } catch (e) {
      print('Error creating geofence: $e');
      return null;
    }
  }

  /// Update geofence settings
  Future<GeoFence?> updateGeofence(
    String geofenceId, {
    String? name,
    double? radiusMeters,
    String? entryAction,
    String? exitAction,
    bool? isActive,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (radiusMeters != null) body['radius_meters'] = radiusMeters;
      if (entryAction != null) body['entry_action'] = entryAction;
      if (exitAction != null) body['exit_action'] = exitAction;
      if (isActive != null) body['is_active'] = isActive;

      final response =
          await apiClient.putJson('/user/geofences/$geofenceId', body: body);
      final geofence = GeoFence.fromJson(response);
      _activeGeofences[geofenceId] = geofence;
      return geofence;
    } catch (e) {
      print('Error updating geofence: $e');
      return null;
    }
  }

  /// Delete a geofence
  Future<bool> deleteGeofence(String geofenceId) async {
    try {
      await apiClient.deleteJson('/user/geofences/$geofenceId');
      _activeGeofences.remove(geofenceId);
      _lastNotificationTime.remove(geofenceId);
      return true;
    } catch (e) {
      print('Error deleting geofence: $e');
      return false;
    }
  }

  /// Get all active geofences for user
  Future<List<GeoFence>> getActiveGeofences() async {
    try {
      await _loadActiveGeofences();
      return _activeGeofences.values.toList();
    } catch (e) {
      print('Error fetching geofences: $e');
      return [];
    }
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
      );
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Get nearby geofences for current location
  Future<List<GeoFence>> getNearbyGeofences({double radiusKm = 5}) async {
    try {
      final position = await getCurrentLocation();
      if (position == null) return [];

      final nearby = <GeoFence>[];
      final radiusMeters = radiusKm * 1000;

      for (final geofence in _activeGeofences.values) {
        final distance = _calculateDistance(
          position.latitude,
          position.longitude,
          geofence.latitude,
          geofence.longitude,
        );

        if (distance <= radiusMeters) {
          nearby.add(geofence);
        }
      }

      return nearby;
    } catch (e) {
      print('Error getting nearby geofences: $e');
      return [];
    }
  }

  /// Calculate distance between two coordinates in meters
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000; // Earth's radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * (pi / 180);

  /// Dispose resources
  Future<void> dispose() async {
    await stopLocationMonitoring();
  }

  bool get isMonitoring => _isMonitoring;
}
