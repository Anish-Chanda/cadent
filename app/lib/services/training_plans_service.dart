import 'dart:developer';

import 'package:dio/dio.dart';

import '../models/training_plan.dart';
import 'http_client.dart';

class TrainingPlansServiceException implements Exception {
  final String message;

  const TrainingPlansServiceException(this.message);

  @override
  String toString() => message;
}

class TrainingPlansService {
  TrainingPlansService._();

  static final TrainingPlansService instance = TrainingPlansService._();

  Future<List<TrainingPlan>> getTrainingPlans({
    String? query,
    TrainingPlanActivityTypeFilter activityType =
        TrainingPlanActivityTypeFilter.all,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      final normalizedQuery = query?.trim();

      if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
        queryParams['q'] = normalizedQuery;
      }
      if (activityType != TrainingPlanActivityTypeFilter.all) {
        queryParams['activity_type'] = activityType.apiValue;
      }

      final response = await HttpClient.instance.dio.get(
        '/api/v1/training-plans',
        queryParameters: queryParams,
      );

      if (response.statusCode != 200 || response.data is! List<dynamic>) {
        throw const TrainingPlansServiceException(
          'Failed to load training plans.',
        );
      }

      return (response.data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(TrainingPlan.fromJson)
          .toList();
    } on DioException catch (e) {
      log('Error fetching training plans: $e');
      throw TrainingPlansServiceException(_extractErrorMessage(e));
    } catch (e) {
      log('Error fetching training plans: $e');
      if (e is TrainingPlansServiceException) {
        rethrow;
      }
      throw const TrainingPlansServiceException(
        'Failed to load training plans.',
      );
    }
  }

  Future<List<TrainingPlanWorkout>> getTrainingPlanWorkouts(
    String planId,
  ) async {
    try {
      final response = await HttpClient.instance.dio.get(
        '/api/v1/training-plans/$planId/workouts',
      );

      if (response.statusCode != 200 || response.data is! List<dynamic>) {
        throw const TrainingPlansServiceException(
          'Failed to load training plan workouts.',
        );
      }

      return (response.data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(TrainingPlanWorkout.fromJson)
          .toList();
    } on DioException catch (e) {
      log('Error fetching training plan workouts: $e');
      throw TrainingPlansServiceException(_extractErrorMessage(e));
    } catch (e) {
      log('Error fetching training plan workouts: $e');
      if (e is TrainingPlansServiceException) {
        rethrow;
      }
      throw const TrainingPlansServiceException(
        'Failed to load training plan workouts.',
      );
    }
  }

  Future<TrainingPlanPreviewResponse> importTrainingPlanDryRun(
    String planId,
    ImportTrainingPlanDryRunRequest request,
  ) async {
    try {
      final response = await HttpClient.instance.dio.post(
        '/api/v1/training-plans/$planId/import/dry-run',
        data: request.toJson(),
      );

      if (response.statusCode != 200 ||
          response.data is! Map<String, dynamic>) {
        throw const TrainingPlansServiceException(
          'Failed to build import preview.',
        );
      }

      return TrainingPlanPreviewResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      log('Error running training plan dry-run: $e');
      throw TrainingPlansServiceException(_extractErrorMessage(e));
    } catch (e) {
      log('Error running training plan dry-run: $e');
      if (e is TrainingPlansServiceException) {
        rethrow;
      }
      throw const TrainingPlansServiceException(
        'Failed to build import preview.',
      );
    }
  }

  Future<ImportTrainingPlanResponse> importTrainingPlan(
    String planId,
    ImportTrainingPlanRequest request,
  ) async {
    try {
      final response = await HttpClient.instance.dio.post(
        '/api/v1/training-plans/$planId/import',
        data: request.toJson(),
      );

      if ((response.statusCode != 200 && response.statusCode != 201) ||
          response.data is! Map<String, dynamic>) {
        throw const TrainingPlansServiceException(
          'Failed to import training plan.',
        );
      }

      return ImportTrainingPlanResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      log('Error importing training plan: $e');
      throw TrainingPlansServiceException(_extractErrorMessage(e));
    } catch (e) {
      log('Error importing training plan: $e');
      if (e is TrainingPlansServiceException) {
        rethrow;
      }
      throw const TrainingPlansServiceException(
        'Failed to import training plan.',
      );
    }
  }

  String _extractErrorMessage(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final message = responseData['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    final rawMessage = error.message;
    if (rawMessage != null && rawMessage.trim().isNotEmpty) {
      return rawMessage;
    }

    return 'Request failed. Please try again.';
  }
}
