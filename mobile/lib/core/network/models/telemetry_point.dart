/// One sample in a history response.
///
/// `ts` is seconds since epoch (UTC). The backend `HistoryResponse` ships
/// datetimes as ISO-8601 strings (when aggregated) or already-numeric
/// timestamps (some legacy paths); both are normalised here.
///
/// The optional `*_min` / `*_max` and [sampleCount] fields are populated
/// only when the response came from an aggregated bucket (`1m` / `1h` / `1d`).
class TelemetryPoint {
  const TelemetryPoint({
    required this.ts,
    this.ambientT,
    this.ambientH,
    this.dissT,
    this.dissH,
    this.setpoint,
    this.pidOut,
    this.ambientTMin,
    this.ambientTMax,
    this.ambientHMin,
    this.ambientHMax,
    this.dissTMin,
    this.dissTMax,
    this.dissHMin,
    this.dissHMax,
    this.sampleCount,
  });

  final int ts; // Unix timestamp in seconds
  final double? ambientT;
  final double? ambientH;
  final double? dissT;
  final double? dissH;
  final double? setpoint;
  final double? pidOut;

  // Aggregated extras (null when bucket == '5s').
  final double? ambientTMin;
  final double? ambientTMax;
  final double? ambientHMin;
  final double? ambientHMax;
  final double? dissTMin;
  final double? dissTMax;
  final double? dissHMin;
  final double? dissHMax;
  final int? sampleCount;

  /// True when this sample carries aggregated min/max for ambient temp/humidity.
  bool get hasAmbientBand => ambientTMin != null && ambientTMax != null;
  bool get hasHumidityBand => ambientHMin != null && ambientHMax != null;

  static int _parseTs(dynamic raw) {
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) {
      // Backend ships ISO-8601 (e.g. "2026-05-23T00:00:00Z").
      final dt = DateTime.parse(raw);
      return dt.millisecondsSinceEpoch ~/ 1000;
    }
    throw FormatException('Unsupported ts value: $raw');
  }

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) => TelemetryPoint(
        ts: _parseTs(json['ts']),
        ambientT: (json['ambient_t'] as num?)?.toDouble(),
        ambientH: (json['ambient_h'] as num?)?.toDouble(),
        dissT: (json['diss_t'] as num?)?.toDouble(),
        dissH: (json['diss_h'] as num?)?.toDouble(),
        setpoint: (json['setpoint'] as num?)?.toDouble(),
        pidOut: (json['pid_out'] as num?)?.toDouble(),
        ambientTMin: (json['ambient_t_min'] as num?)?.toDouble(),
        ambientTMax: (json['ambient_t_max'] as num?)?.toDouble(),
        ambientHMin: (json['ambient_h_min'] as num?)?.toDouble(),
        ambientHMax: (json['ambient_h_max'] as num?)?.toDouble(),
        dissTMin: (json['diss_t_min'] as num?)?.toDouble(),
        dissTMax: (json['diss_t_max'] as num?)?.toDouble(),
        dissHMin: (json['diss_h_min'] as num?)?.toDouble(),
        dissHMax: (json['diss_h_max'] as num?)?.toDouble(),
        sampleCount: (json['sample_count'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'ts': ts,
        if (ambientT != null) 'ambient_t': ambientT,
        if (ambientH != null) 'ambient_h': ambientH,
        if (dissT != null) 'diss_t': dissT,
        if (dissH != null) 'diss_h': dissH,
        if (setpoint != null) 'setpoint': setpoint,
        if (pidOut != null) 'pid_out': pidOut,
        if (ambientTMin != null) 'ambient_t_min': ambientTMin,
        if (ambientTMax != null) 'ambient_t_max': ambientTMax,
        if (ambientHMin != null) 'ambient_h_min': ambientHMin,
        if (ambientHMax != null) 'ambient_h_max': ambientHMax,
        if (dissTMin != null) 'diss_t_min': dissTMin,
        if (dissTMax != null) 'diss_t_max': dissTMax,
        if (dissHMin != null) 'diss_h_min': dissHMin,
        if (dissHMax != null) 'diss_h_max': dissHMax,
        if (sampleCount != null) 'sample_count': sampleCount,
      };
}

