import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/device_model.dart';
import '../models/telemetry_model.dart';
import 'http_client.dart';

class DevicesApi {
  final ApiClient apiClient;

  DevicesApi({required this.apiClient});

  Dio get _dio => apiClient.dio;

  /// Generate a 6-digit pairing code for desktop pairing
  /// POST /devices/pairing_code -> { code: "123456" }
  Future<String> getPairingCode() async {
    try {
      final response = await _dio.post(ApiConstants.pairingCode);
      if (response.data is Map && response.data['code'] != null) {
        return response.data['code'].toString();
      }
      throw 'Invalid response format from pairing code endpoint';
    } on DioException catch (e) {
      throw apiClient.formatDioError(e);
    }
  }

  /// Get list of paired devices
  /// GET /devices -> [ { id, hostname, ... } ]
  Future<List<DeviceModel>> getDevices() async {
    try {
      final response = await _dio.get(ApiConstants.devices);
      if (response.data is List) {
        return (response.data as List)
            .map((item) => DeviceModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw apiClient.formatDioError(e);
    }
  }

  /// Get details of a single device
  /// GET /devices/{device_id}
  Future<DeviceModel> getDevice(String deviceId) async {
    try {
      final response = await _dio.get(ApiConstants.device(deviceId));
      return DeviceModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw apiClient.formatDioError(e);
    }
  }

  /// Get telemetry of a single device
  /// GET /devices/{device_id}/telemetry
  Future<TelemetryModel> getDeviceTelemetry(String deviceId) async {
    try {
      final response = await _dio.get(ApiConstants.deviceTelemetry(deviceId));
      if (response.data is Map) {
        return TelemetryModel.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
      return TelemetryModel(rawData: {});
    } on DioException catch (e) {
      throw apiClient.formatDioError(e);
    }
  }
}
