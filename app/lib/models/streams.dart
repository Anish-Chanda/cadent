class StreamSummaryStat {
  final double? min;
  final double? max;
  final double? avg;
  final double? std;
  final double? totalAscent;
  final double? totalDescent;

  StreamSummaryStat({
    this.min,
    this.max,
    this.avg,
    this.std,
    this.totalAscent,
    this.totalDescent,
  });

  factory StreamSummaryStat.fromJson(Map<String, dynamic> j) {
    return StreamSummaryStat(
      min: (j['min'] as num?)?.toDouble(),
      max: (j['max'] as num?)?.toDouble(),
      avg: (j['avg'] as num?)?.toDouble(),
      std: (j['std'] as num?)?.toDouble(),
      totalAscent: (j['totalAscent'] as num?)?.toDouble(),
      totalDescent: (j['totalDescent'] as num?)?.toDouble(),
    );
  }
}

class StreamsModel {
  final String activityId;
  final String indexBy;
  final String lod;
  final Map<String, dynamic>? used;
  final Map<String, List<dynamic>> streams;
  final Map<String, StreamSummaryStat>? summary;

  StreamsModel({
    required this.activityId,
    required this.indexBy,
    required this.lod,
    this.used,
    required this.streams,
    this.summary,
  });

  factory StreamsModel.fromJson(Map<String, dynamic> j) {
    final rawStreams = <String, List<dynamic>>{};
    // Accept either a map-of-arrays or a list of {type, values} objects.
    final streamsRaw = j['streams'];
    if (streamsRaw is Map) {
      streamsRaw.forEach((k, v) {
        if (v is List) rawStreams[k as String] = List<dynamic>.from(v);
      });
    } else if (streamsRaw is List) {
      for (final item in streamsRaw) {
        if (item is Map && item['type'] != null && item['values'] is List) {
          rawStreams[item['type'] as String] = List<dynamic>.from(item['values'] as List);
        }
      }
    }

    final summaryMap = <String, StreamSummaryStat>{};
    if (j['summary'] is Map) {
      (j['summary'] as Map).forEach((k, v) {
        if (v is Map) summaryMap[k as String] = StreamSummaryStat.fromJson(Map<String, dynamic>.from(v));
      });
    }

    // support snake_case keys from backend
    final activityId = j['activityId'] as String? ?? j['activity_id'] as String? ?? '';
    final indexBy = j['indexBy'] as String? ?? j['index_by'] as String? ?? 'time';
    final lod = j['lod'] as String? ?? j['lod'] as String? ?? 'auto';
    final used = (j['used'] is Map) ? Map<String, dynamic>.from(j['used'] as Map) : null;

    return StreamsModel(
      activityId: activityId,
      indexBy: indexBy,
      lod: lod,
      used: used,
      streams: rawStreams,
      summary: summaryMap.isEmpty ? null : summaryMap,
    );
  }

  // Helpers
  /// Returns the raw numeric series for [name].
  List<double> numericSeries(String name) {
    final s = streams[name];
    if (s == null) return [];
    return s.map<double>((e) {
      if (e is num) return e.toDouble();
      return double.tryParse(e.toString()) ?? 0.0;
    }).toList();
  }

  /// When the streams use a relative `time` series (seconds offsets from
  /// activity start), return those offsets as seconds (double).
  List<double> timeOffsetsSeconds() {
    final s = streams['time'];
    if (s == null) return [];
    return s.map<double>((e) {
      if (e is num) return e.toDouble();
      return double.tryParse(e.toString()) ?? 0.0;
    }).toList();
  }

  /// Build DateTime timestamps by adding the stream's time offsets (in
  /// seconds) to [base]. This is useful when the backend returns relative
  /// offsets instead of absolute epoch times.
  List<DateTime> timeStampsFrom(DateTime base) {
    final offsets = timeOffsetsSeconds();
    return offsets.map((s) => base.add(Duration(milliseconds: (s * 1000).round()))).toList();
  }
}
