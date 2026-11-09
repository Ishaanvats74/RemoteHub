/// RemoteHub – Central configuration.
///
/// Change [baseUrl] here (or via the Settings screen at runtime) to point
/// the app at a different server.
///
/// Android emulator default: `http://10.0.2.2:8000`
/// Real device on LAN:       `http://<PC_LAN_IP>:8000`
/// Production:               `https://your-domain.com`   (use HTTPS + WSS)
///
/// NOTE: The `android/app/src/main/res/xml/network_security_config.xml`
/// file allows cleartext (HTTP) traffic to 10.0.2.2 and local IPs for
/// development builds only.  Production builds should always use HTTPS.
class AppConfig {
  AppConfig._();

  // ──────────────────────────────────────────────
  // Server
  // ──────────────────────────────────────────────

  /// Default REST base URL.
  /// Can be overridden at runtime via [ServerSettingsNotifier].
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';

  /// Derives the WebSocket base URL from a given HTTP URL.
  /// Replaces "http" with "ws" (or "https" with "wss").
  static String wsBaseUrl(String httpBase) {
    if (httpBase.startsWith('https://')) {
      return httpBase.replaceFirst('https://', 'wss://');
    }
    return httpBase.replaceFirst('http://', 'ws://');
  }

  // ──────────────────────────────────────────────
  // Timeouts
  // ──────────────────────────────────────────────

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // ──────────────────────────────────────────────
  // Auth
  // ──────────────────────────────────────────────

  /// How many seconds before expiry to proactively refresh the access token.
  static const int tokenRefreshBufferSeconds = 60;

  // ──────────────────────────────────────────────
  // WebSocket reconnect
  // ──────────────────────────────────────────────

  static const int wsMaxReconnectDelaySeconds = 30;

  // ──────────────────────────────────────────────
  // Pairing
  // ──────────────────────────────────────────────

  static const int pairingCodeExpireMinutes = 10;

  // ──────────────────────────────────────────────
  // Telemetry rolling buffer
  // ──────────────────────────────────────────────

  /// Maximum number of telemetry samples held in memory per device.
  static const int telemetryBufferSize = 120;

  // ──────────────────────────────────────────────
  // Command timeout
  // ──────────────────────────────────────────────

  static const int commandResultTimeoutSeconds = 10;
}
