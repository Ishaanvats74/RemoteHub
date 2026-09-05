import 'package:flutter_test/flutter_test.dart';
import 'package:remote_ctrl/core/utils/date_formatter.dart';
import 'package:remote_ctrl/core/utils/validators.dart';
import 'package:remote_ctrl/models/auth_token.dart';
import 'package:remote_ctrl/models/device_model.dart';
import 'package:remote_ctrl/models/telemetry_model.dart';
import 'package:remote_ctrl/models/user_model.dart';
import 'package:remote_ctrl/models/ws_message.dart';

void main() {
  group('Validators tests', () {
    test('username validation', () {
      expect(Validators.validateUsername(''), 'Username is required');
      expect(Validators.validateUsername('ab'), 'Username must be at least 3 characters');
      expect(Validators.validateUsername('a' * 31), 'Username cannot exceed 30 characters');
      expect(Validators.validateUsername('valid_user-123'), isNull);
      expect(Validators.validateUsername('invalid user!'), isNotNull);
    });

    test('email validation', () {
      expect(Validators.validateEmail(''), 'Email is required');
      expect(Validators.validateEmail('invalid-email'), 'Please enter a valid email address');
      expect(Validators.validateEmail('user@domain.com'), isNull);
    });

    test('password validation', () {
      expect(Validators.validatePassword(''), 'Password is required');
      expect(Validators.validatePassword('12345'), 'Password must be at least 6 characters');
      expect(Validators.validatePassword('123456'), isNull);
    });

    test('server URL validation', () {
      expect(Validators.validateServerUrl(''), 'Server URL is required');
      expect(Validators.validateServerUrl('ftp://example.com'), isNotNull);
      expect(Validators.validateServerUrl('http://10.0.2.2:8000'), isNull);
      expect(Validators.validateServerUrl('https://remotehub.example.com'), isNull);
    });
  });

  group('DateFormatter tests', () {
    test('formatCountdown', () {
      expect(DateFormatter.formatCountdown(600), '10:00');
      expect(DateFormatter.formatCountdown(65), '01:05');
      expect(DateFormatter.formatCountdown(9), '00:09');
      expect(DateFormatter.formatCountdown(0), '00:00');
    });

    test('formatRelativeTime', () {
      expect(DateFormatter.formatRelativeTime(null), 'Never');
      final now = DateTime.now();
      expect(DateFormatter.formatRelativeTime(now), 'Just now');
      expect(DateFormatter.formatRelativeTime(now.subtract(const Duration(minutes: 5))), '5m ago');
      expect(DateFormatter.formatRelativeTime(now.subtract(const Duration(hours: 3))), '3h ago');
    });
  });

  group('Models serialization', () {
    test('AuthToken model', () {
      final token = AuthToken.fromJson({
        'access_token': 'test_access',
        'refresh_token': 'test_refresh',
        'token_type': 'bearer',
      });
      expect(token.accessToken, 'test_access');
      expect(token.refreshToken, 'test_refresh');
      expect(token.tokenType, 'bearer');
      expect(token.toJson()['access_token'], 'test_access');
    });

    test('UserModel model', () {
      final user = UserModel.fromJson({
        'id': 'usr-1',
        'username': 'admin',
        'email': 'admin@test.com',
      });
      expect(user.id, 'usr-1');
      expect(user.username, 'admin');
      expect(user.email, 'admin@test.com');
    });

    test('DeviceModel model', () {
      final device = DeviceModel.fromJson({
        'id': 'dev-1',
        'user_id': 'usr-1',
        'hostname': 'ThinkPad-X1',
        'os': 'Ubuntu 24.04',
        'platform': 'linux',
        'status': 'online',
        'last_seen': '2026-09-05T12:00:00Z',
      });
      expect(device.id, 'dev-1');
      expect(device.hostname, 'ThinkPad-X1');
      expect(device.isOnline, true);
      expect(device.platform, 'linux');
    });

    test('TelemetryModel parsing', () {
      final telemetry = TelemetryModel.fromJson({
        'cpu_percent': 34.5,
        'ram_percent': 68.2,
        'disk_percent': 45.0,
        'battery_percent': 92,
        'uptime': '3 days, 4 hours',
      });
      expect(telemetry.cpuPercent, 34.5);
      expect(telemetry.memoryPercent, 68.2);
      expect(telemetry.diskPercent, 45.0);
      expect(telemetry.batteryPercent, 92.0);
      expect(telemetry.uptime, '3 days, 4 hours');
    });

    test('WsIncomingMessage parsing', () {
      final cmdResult = WsIncomingMessage.fromJson({
        'type': 'command_result',
        'device_id': 'dev-1',
        'command': 'shutdown',
        'success': true,
        'message': 'Shutdown initiated',
      });
      expect(cmdResult, isA<WsCommandResultMessage>());
      final typed = cmdResult as WsCommandResultMessage;
      expect(typed.success, true);
      expect(typed.command, 'shutdown');

      final telem = WsIncomingMessage.fromJson({
        'type': 'telemetry',
        'device_id': 'dev-1',
        'data': {'cpu': 50.0},
      });
      expect(telem, isA<WsTelemetryMessage>());

      final status = WsIncomingMessage.fromJson({
        'type': 'device_status',
        'device_id': 'dev-1',
        'status': 'online',
      });
      expect(status, isA<WsDeviceStatusMessage>());
      expect((status as WsDeviceStatusMessage).isOnline, true);
    });
  });
}
