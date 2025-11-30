import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
// dio is not referenced directly here but left intentionally in case callers
// want to catch DioError types. Removed direct usage to avoid lint.

import '../models/streams.dart';
import 'http_client.dart';

class StreamsService {
  StreamsService._();
  static final instance = StreamsService._();

  /// Try to fetch streams for an activity from backend. If not found
  /// or when `useDebugAsset` is true it will load the sample JSON from assets.
  Future<StreamsModel?> fetchStreamsForActivity(String activityId, {bool useDebugAsset = false, String lod = 'medium', List<String>? types}) async {
    if (useDebugAsset) {
      try {
        final raw = await rootBundle.loadString('assets/sample_streams.json');
        final map = json.decode(raw) as Map<String, dynamic>;
        return StreamsModel.fromJson(map);
      } catch (e) {
        rethrow;
      }
    }

    final dio = HttpClient.instance.dio;
    try {
      final path = '/v1/activities/$activityId/streams';
      final typesList = types ?? ['time', 'distance', 'elevation', 'speed'];
      final resp = await dio.get(path, queryParameters: {
        'lod': lod,
        'type': typesList.join(','),
      });
      if (resp.statusCode == 200 && resp.data != null) {
        final map = Map<String, dynamic>.from(resp.data as Map);
        return StreamsModel.fromJson(map);
      }

      // fallback: query streams endpoint
      final fallback = await dio.get('/v1/streams', queryParameters: {
        'activityId': activityId,
        'lod': lod,
        'type': (types ?? ['time', 'distance', 'elevation', 'speed']).join(','),
      });
      if (fallback.statusCode == 200 && fallback.data != null) {
        final map = Map<String, dynamic>.from(fallback.data as Map);
        return StreamsModel.fromJson(map);
      }
    } catch (_) {
      // bubble up to caller
      rethrow;
    }
    return null;
  }
}
