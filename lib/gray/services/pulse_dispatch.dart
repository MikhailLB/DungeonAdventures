import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'runtime_cache.dart';
import 'secure_http.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {}

String? _extractUrl(Map<String, dynamic> data) {
  for (final key in ['url', 'link', 'target', 'deeplink', 'deep_link']) {
    final v = data[key] as String?;
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

class PulseDispatch {
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final RuntimeCache _cache;
  FirebaseMessaging? _fm;
  String? _token;
  bool _initialized = false;
  bool _permissionRequesting = false;

  Function(String url)? onPushDestination;
  Function(String token)? onTokenRefresh;

  PulseDispatch(this._cache);

  String? get token => _token;

  Future<void> bootstrap() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      _fm = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_bgHandler);

      await _initLocal();

      _token = await _fm!.getToken();
      _fm!.onTokenRefresh.listen((t) {
        _token = t;
        onTokenRefresh?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onBackground);

      final init = await _fm!.getInitialMessage();
      if (init != null) _onColdStart(init);

      _initialized = true;
    } catch (_) {}
  }

  Future<void> _initLocal() async {
    const android = AndroidInitializationSettings('@drawable/ic_pulse_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) {
          try {
            final data = jsonDecode(r.payload!) as Map<String, dynamic>;
            final url = _extractUrl(data);
            if (url != null) onPushDestination?.call(url);
          } catch (_) {}
        }
      },
    );

    if (Platform.isAndroid) {
      final ap = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await ap?.createNotificationChannel(const AndroidNotificationChannel(
        'gray_pulse_channel',
        'Notifications',
        description: 'App push notifications',
        importance: Importance.high,
      ));
    }
  }

  Future<bool> askConsent() async {
    if (_fm == null || _permissionRequesting) return false;
    _permissionRequesting = true;
    try {
      final s = await _fm!.requestPermission(
          alert: true, badge: true, sound: true, provisional: false);
      final granted = s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
      await _cache.setNotifGranted(granted);
      await _cache.setNotifSysDenied(!granted);
      return granted;
    } catch (_) {
      return false;
    } finally {
      _permissionRequesting = false;
    }
  }

  void _onForeground(RemoteMessage msg) async {
    final notif = msg.notification;
    if (notif == null) return;

    final imgUrl = Platform.isAndroid
        ? msg.notification?.android?.imageUrl
        : msg.notification?.apple?.imageUrl;

    AndroidNotificationDetails? details;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      final pic = await _fetchImage(imgUrl);
      if (pic != null) {
        details = AndroidNotificationDetails(
          'gray_pulse_channel',
          'Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_pulse_notification',
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(pic),
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }
    details ??= const AndroidNotificationDetails(
      'gray_pulse_channel',
      'Notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_pulse_notification',
    );

    final payload = msg.data.isNotEmpty ? jsonEncode(msg.data) : null;
    await _local.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(android: details, iOS: const DarwinNotificationDetails()),
      payload: payload,
    );
  }

  void _onBackground(RemoteMessage msg) {
    final url = _extractUrl(msg.data);
    if (url != null) onPushDestination?.call(url);
  }

  void _onColdStart(RemoteMessage msg) {
    final url = _extractUrl(msg.data);
    if (url != null) _cache.stashOneShotPush(url);
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final r = await secureHttp
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }
}
