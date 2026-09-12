import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'equipment_models.dart';

class EquipmentException implements Exception {
  const EquipmentException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class EquipmentRepository {
  EquipmentRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<EquipmentData>> getEquipmentCatalog() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/equipment');

      return _asJsonList(response.data)
          .map((item) => EquipmentData.fromJson(_asJsonObject(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _toEquipmentException(error);
    }
  }

  Future<List<EquipmentData>> getUserEquipment() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/equipment/me');

      final data = _asJsonObject(response.data);
      final equipment = data['equipment'];

      return _asJsonList(equipment)
          .map((item) => EquipmentData.fromJson(_asJsonObject(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _toEquipmentException(error);
    }
  }

  Future<List<EquipmentData>> updateUserEquipment(
    Set<String> equipmentCodes,
  ) async {
    try {
      final codes = equipmentCodes.toList()..sort();

      final response = await _apiClient.dio.put<dynamic>(
        '/equipment/me',
        data: {'equipment_codes': codes},
      );

      final data = _asJsonObject(response.data);
      final equipment = data['equipment'];

      return _asJsonList(equipment)
          .map((item) => EquipmentData.fromJson(_asJsonObject(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _toEquipmentException(error);
    }
  }

  List<dynamic> _asJsonList(dynamic value) {
    if (value is List) {
      return value;
    }

    throw const EquipmentException('Unexpected response from FORGE server.');
  }

  Map<String, dynamic> _asJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const EquipmentException('Unexpected response from FORGE server.');
  }

  EquipmentException _toEquipmentException(DioException error) {
    return EquipmentException(
      _extractErrorMessage(error),
      statusCode: error.response?.statusCode,
    );
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;

    if (data is Map) {
      final detail = data['detail'];

      if (detail is String && detail.isNotEmpty) {
        return detail;
      }

      if (detail is List && detail.isNotEmpty) {
        final firstError = detail.first;

        if (firstError is Map) {
          final message = firstError['msg'];

          if (message is String && message.isNotEmpty) {
            return message;
          }
        }
      }
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Could not connect to FORGE server.';
    }

    if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection to FORGE server timed out.';
    }

    return 'Something went wrong while communicating with FORGE.';
  }
}
