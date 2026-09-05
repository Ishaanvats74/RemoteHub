class ApiConstants {
  // Default base URL. In Android emulator: 10.0.2.2 points to host machine.
  // In iOS simulator or web or desktop: localhost or 127.0.0.1.
  // Can be configured by the user dynamically via the server settings dialog.
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';
  
  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // Auth endpoints
  static const String register = '/auth/register';
  static const String token = '/token';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/users/me/';

  // Devices endpoints
  static const String pairingCode = '/devices/pairing_code';
  static const String devices = '/devices';
  static String device(String id) => '/devices/$id';
  static String deviceTelemetry(String id) => '/devices/$id/telemetry';

  // WebSocket endpoint
  static const String wsMobile = '/ws/mobile';

  // Pairing code settings
  static const int pairingCodeExpireMinutes = 10;
}
