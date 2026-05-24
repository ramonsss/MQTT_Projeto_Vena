class TelemetryPoint {
  const TelemetryPoint({
    required this.ts,
    this.ambientT,
    this.ambientH,
    this.dissT,
    this.dissH,
    this.setpoint,
    this.pidOut,
  });

  final int ts; // Unix timestamp in seconds
  final double? ambientT;
  final double? ambientH;
  final double? dissT;
  final double? dissH;
  final double? setpoint;
  final double? pidOut;

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) => TelemetryPoint(
        ts: json['ts'] as int,
        ambientT: (json['ambient_t'] as num?)?.toDouble(),
        ambientH: (json['ambient_h'] as num?)?.toDouble(),
        dissT: (json['diss_t'] as num?)?.toDouble(),
        dissH: (json['diss_h'] as num?)?.toDouble(),
        setpoint: (json['setpoint'] as num?)?.toDouble(),
        pidOut: (json['pid_out'] as num?)?.toDouble(),
      );
}
