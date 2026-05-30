// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DevicesTable extends Devices with TableInfo<$DevicesTable, Device> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
      'alias', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('offline'));
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<int> lastSeenAt = GeneratedColumn<int>(
      'last_seen_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _fwVersionMeta =
      const VerificationMeta('fwVersion');
  @override
  late final GeneratedColumn<String> fwVersion = GeneratedColumn<String>(
      'fw_version', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _storedContentMeta =
      const VerificationMeta('storedContent');
  @override
  late final GeneratedColumn<String> storedContent = GeneratedColumn<String>(
      'stored_content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [deviceId, alias, status, lastSeenAt, fwVersion, storedContent];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(Insertable<Device> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
          _aliasMeta, alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
    }
    if (data.containsKey('fw_version')) {
      context.handle(_fwVersionMeta,
          fwVersion.isAcceptableOrUnknown(data['fw_version']!, _fwVersionMeta));
    }
    if (data.containsKey('stored_content')) {
      context.handle(
          _storedContentMeta,
          storedContent.isAcceptableOrUnknown(
              data['stored_content']!, _storedContentMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  Device map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Device(
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      alias: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alias'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_seen_at']),
      fwVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fw_version']),
      storedContent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stored_content']),
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class Device extends DataClass implements Insertable<Device> {
  final String deviceId;
  final String alias;
  final String status;
  final int? lastSeenAt;
  final String? fwVersion;
  final String? storedContent;
  const Device(
      {required this.deviceId,
      required this.alias,
      required this.status,
      this.lastSeenAt,
      this.fwVersion,
      this.storedContent});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['alias'] = Variable<String>(alias);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<int>(lastSeenAt);
    }
    if (!nullToAbsent || fwVersion != null) {
      map['fw_version'] = Variable<String>(fwVersion);
    }
    if (!nullToAbsent || storedContent != null) {
      map['stored_content'] = Variable<String>(storedContent);
    }
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      deviceId: Value(deviceId),
      alias: Value(alias),
      status: Value(status),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      fwVersion: fwVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(fwVersion),
      storedContent: storedContent == null && nullToAbsent
          ? const Value.absent()
          : Value(storedContent),
    );
  }

  factory Device.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Device(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      alias: serializer.fromJson<String>(json['alias']),
      status: serializer.fromJson<String>(json['status']),
      lastSeenAt: serializer.fromJson<int?>(json['lastSeenAt']),
      fwVersion: serializer.fromJson<String?>(json['fwVersion']),
      storedContent: serializer.fromJson<String?>(json['storedContent']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'alias': serializer.toJson<String>(alias),
      'status': serializer.toJson<String>(status),
      'lastSeenAt': serializer.toJson<int?>(lastSeenAt),
      'fwVersion': serializer.toJson<String?>(fwVersion),
      'storedContent': serializer.toJson<String?>(storedContent),
    };
  }

  Device copyWith(
          {String? deviceId,
          String? alias,
          String? status,
          Value<int?> lastSeenAt = const Value.absent(),
          Value<String?> fwVersion = const Value.absent(),
          Value<String?> storedContent = const Value.absent()}) =>
      Device(
        deviceId: deviceId ?? this.deviceId,
        alias: alias ?? this.alias,
        status: status ?? this.status,
        lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
        fwVersion: fwVersion.present ? fwVersion.value : this.fwVersion,
        storedContent:
            storedContent.present ? storedContent.value : this.storedContent,
      );
  Device copyWithCompanion(DevicesCompanion data) {
    return Device(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      alias: data.alias.present ? data.alias.value : this.alias,
      status: data.status.present ? data.status.value : this.status,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
      fwVersion: data.fwVersion.present ? data.fwVersion.value : this.fwVersion,
      storedContent: data.storedContent.present
          ? data.storedContent.value
          : this.storedContent,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Device(')
          ..write('deviceId: $deviceId, ')
          ..write('alias: $alias, ')
          ..write('status: $status, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('fwVersion: $fwVersion, ')
          ..write('storedContent: $storedContent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      deviceId, alias, status, lastSeenAt, fwVersion, storedContent);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Device &&
          other.deviceId == this.deviceId &&
          other.alias == this.alias &&
          other.status == this.status &&
          other.lastSeenAt == this.lastSeenAt &&
          other.fwVersion == this.fwVersion &&
          other.storedContent == this.storedContent);
}

class DevicesCompanion extends UpdateCompanion<Device> {
  final Value<String> deviceId;
  final Value<String> alias;
  final Value<String> status;
  final Value<int?> lastSeenAt;
  final Value<String?> fwVersion;
  final Value<String?> storedContent;
  final Value<int> rowid;
  const DevicesCompanion({
    this.deviceId = const Value.absent(),
    this.alias = const Value.absent(),
    this.status = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.fwVersion = const Value.absent(),
    this.storedContent = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String deviceId,
    this.alias = const Value.absent(),
    this.status = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.fwVersion = const Value.absent(),
    this.storedContent = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId);
  static Insertable<Device> custom({
    Expression<String>? deviceId,
    Expression<String>? alias,
    Expression<String>? status,
    Expression<int>? lastSeenAt,
    Expression<String>? fwVersion,
    Expression<String>? storedContent,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (alias != null) 'alias': alias,
      if (status != null) 'status': status,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (fwVersion != null) 'fw_version': fwVersion,
      if (storedContent != null) 'stored_content': storedContent,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith(
      {Value<String>? deviceId,
      Value<String>? alias,
      Value<String>? status,
      Value<int?>? lastSeenAt,
      Value<String?>? fwVersion,
      Value<String?>? storedContent,
      Value<int>? rowid}) {
    return DevicesCompanion(
      deviceId: deviceId ?? this.deviceId,
      alias: alias ?? this.alias,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      fwVersion: fwVersion ?? this.fwVersion,
      storedContent: storedContent ?? this.storedContent,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<int>(lastSeenAt.value);
    }
    if (fwVersion.present) {
      map['fw_version'] = Variable<String>(fwVersion.value);
    }
    if (storedContent.present) {
      map['stored_content'] = Variable<String>(storedContent.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('alias: $alias, ')
          ..write('status: $status, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('fwVersion: $fwVersion, ')
          ..write('storedContent: $storedContent, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LatestStatesTable extends LatestStates
    with TableInfo<$LatestStatesTable, LatestState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LatestStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
      'ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _ambientTMeta =
      const VerificationMeta('ambientT');
  @override
  late final GeneratedColumn<double> ambientT = GeneratedColumn<double>(
      'ambient_t', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _ambientHMeta =
      const VerificationMeta('ambientH');
  @override
  late final GeneratedColumn<double> ambientH = GeneratedColumn<double>(
      'ambient_h', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _dissTMeta = const VerificationMeta('dissT');
  @override
  late final GeneratedColumn<double> dissT = GeneratedColumn<double>(
      'diss_t', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _dissHMeta = const VerificationMeta('dissH');
  @override
  late final GeneratedColumn<double> dissH = GeneratedColumn<double>(
      'diss_h', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _setpointMeta =
      const VerificationMeta('setpoint');
  @override
  late final GeneratedColumn<double> setpoint = GeneratedColumn<double>(
      'setpoint', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _pidOutMeta = const VerificationMeta('pidOut');
  @override
  late final GeneratedColumn<double> pidOut = GeneratedColumn<double>(
      'pid_out', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('mqtt'));
  static const VerificationMeta _onlineMeta = const VerificationMeta('online');
  @override
  late final GeneratedColumn<bool> online = GeneratedColumn<bool>(
      'online', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("online" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        deviceId,
        ts,
        ambientT,
        ambientH,
        dissT,
        dissH,
        setpoint,
        pidOut,
        source,
        online
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'latest_states';
  @override
  VerificationContext validateIntegrity(Insertable<LatestState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('ambient_t')) {
      context.handle(_ambientTMeta,
          ambientT.isAcceptableOrUnknown(data['ambient_t']!, _ambientTMeta));
    }
    if (data.containsKey('ambient_h')) {
      context.handle(_ambientHMeta,
          ambientH.isAcceptableOrUnknown(data['ambient_h']!, _ambientHMeta));
    }
    if (data.containsKey('diss_t')) {
      context.handle(
          _dissTMeta, dissT.isAcceptableOrUnknown(data['diss_t']!, _dissTMeta));
    }
    if (data.containsKey('diss_h')) {
      context.handle(
          _dissHMeta, dissH.isAcceptableOrUnknown(data['diss_h']!, _dissHMeta));
    }
    if (data.containsKey('setpoint')) {
      context.handle(_setpointMeta,
          setpoint.isAcceptableOrUnknown(data['setpoint']!, _setpointMeta));
    }
    if (data.containsKey('pid_out')) {
      context.handle(_pidOutMeta,
          pidOut.isAcceptableOrUnknown(data['pid_out']!, _pidOutMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('online')) {
      context.handle(_onlineMeta,
          online.isAcceptableOrUnknown(data['online']!, _onlineMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  LatestState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LatestState(
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts'])!,
      ambientT: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}ambient_t']),
      ambientH: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}ambient_h']),
      dissT: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}diss_t']),
      dissH: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}diss_h']),
      setpoint: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}setpoint']),
      pidOut: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}pid_out']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      online: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}online'])!,
    );
  }

  @override
  $LatestStatesTable createAlias(String alias) {
    return $LatestStatesTable(attachedDatabase, alias);
  }
}

class LatestState extends DataClass implements Insertable<LatestState> {
  final String deviceId;
  final int ts;
  final double? ambientT;
  final double? ambientH;
  final double? dissT;
  final double? dissH;
  final double? setpoint;
  final double? pidOut;
  final String source;
  final bool online;
  const LatestState(
      {required this.deviceId,
      required this.ts,
      this.ambientT,
      this.ambientH,
      this.dissT,
      this.dissH,
      this.setpoint,
      this.pidOut,
      required this.source,
      required this.online});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['ts'] = Variable<int>(ts);
    if (!nullToAbsent || ambientT != null) {
      map['ambient_t'] = Variable<double>(ambientT);
    }
    if (!nullToAbsent || ambientH != null) {
      map['ambient_h'] = Variable<double>(ambientH);
    }
    if (!nullToAbsent || dissT != null) {
      map['diss_t'] = Variable<double>(dissT);
    }
    if (!nullToAbsent || dissH != null) {
      map['diss_h'] = Variable<double>(dissH);
    }
    if (!nullToAbsent || setpoint != null) {
      map['setpoint'] = Variable<double>(setpoint);
    }
    if (!nullToAbsent || pidOut != null) {
      map['pid_out'] = Variable<double>(pidOut);
    }
    map['source'] = Variable<String>(source);
    map['online'] = Variable<bool>(online);
    return map;
  }

  LatestStatesCompanion toCompanion(bool nullToAbsent) {
    return LatestStatesCompanion(
      deviceId: Value(deviceId),
      ts: Value(ts),
      ambientT: ambientT == null && nullToAbsent
          ? const Value.absent()
          : Value(ambientT),
      ambientH: ambientH == null && nullToAbsent
          ? const Value.absent()
          : Value(ambientH),
      dissT:
          dissT == null && nullToAbsent ? const Value.absent() : Value(dissT),
      dissH:
          dissH == null && nullToAbsent ? const Value.absent() : Value(dissH),
      setpoint: setpoint == null && nullToAbsent
          ? const Value.absent()
          : Value(setpoint),
      pidOut:
          pidOut == null && nullToAbsent ? const Value.absent() : Value(pidOut),
      source: Value(source),
      online: Value(online),
    );
  }

  factory LatestState.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LatestState(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      ts: serializer.fromJson<int>(json['ts']),
      ambientT: serializer.fromJson<double?>(json['ambientT']),
      ambientH: serializer.fromJson<double?>(json['ambientH']),
      dissT: serializer.fromJson<double?>(json['dissT']),
      dissH: serializer.fromJson<double?>(json['dissH']),
      setpoint: serializer.fromJson<double?>(json['setpoint']),
      pidOut: serializer.fromJson<double?>(json['pidOut']),
      source: serializer.fromJson<String>(json['source']),
      online: serializer.fromJson<bool>(json['online']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'ts': serializer.toJson<int>(ts),
      'ambientT': serializer.toJson<double?>(ambientT),
      'ambientH': serializer.toJson<double?>(ambientH),
      'dissT': serializer.toJson<double?>(dissT),
      'dissH': serializer.toJson<double?>(dissH),
      'setpoint': serializer.toJson<double?>(setpoint),
      'pidOut': serializer.toJson<double?>(pidOut),
      'source': serializer.toJson<String>(source),
      'online': serializer.toJson<bool>(online),
    };
  }

  LatestState copyWith(
          {String? deviceId,
          int? ts,
          Value<double?> ambientT = const Value.absent(),
          Value<double?> ambientH = const Value.absent(),
          Value<double?> dissT = const Value.absent(),
          Value<double?> dissH = const Value.absent(),
          Value<double?> setpoint = const Value.absent(),
          Value<double?> pidOut = const Value.absent(),
          String? source,
          bool? online}) =>
      LatestState(
        deviceId: deviceId ?? this.deviceId,
        ts: ts ?? this.ts,
        ambientT: ambientT.present ? ambientT.value : this.ambientT,
        ambientH: ambientH.present ? ambientH.value : this.ambientH,
        dissT: dissT.present ? dissT.value : this.dissT,
        dissH: dissH.present ? dissH.value : this.dissH,
        setpoint: setpoint.present ? setpoint.value : this.setpoint,
        pidOut: pidOut.present ? pidOut.value : this.pidOut,
        source: source ?? this.source,
        online: online ?? this.online,
      );
  LatestState copyWithCompanion(LatestStatesCompanion data) {
    return LatestState(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      ts: data.ts.present ? data.ts.value : this.ts,
      ambientT: data.ambientT.present ? data.ambientT.value : this.ambientT,
      ambientH: data.ambientH.present ? data.ambientH.value : this.ambientH,
      dissT: data.dissT.present ? data.dissT.value : this.dissT,
      dissH: data.dissH.present ? data.dissH.value : this.dissH,
      setpoint: data.setpoint.present ? data.setpoint.value : this.setpoint,
      pidOut: data.pidOut.present ? data.pidOut.value : this.pidOut,
      source: data.source.present ? data.source.value : this.source,
      online: data.online.present ? data.online.value : this.online,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LatestState(')
          ..write('deviceId: $deviceId, ')
          ..write('ts: $ts, ')
          ..write('ambientT: $ambientT, ')
          ..write('ambientH: $ambientH, ')
          ..write('dissT: $dissT, ')
          ..write('dissH: $dissH, ')
          ..write('setpoint: $setpoint, ')
          ..write('pidOut: $pidOut, ')
          ..write('source: $source, ')
          ..write('online: $online')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deviceId, ts, ambientT, ambientH, dissT,
      dissH, setpoint, pidOut, source, online);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LatestState &&
          other.deviceId == this.deviceId &&
          other.ts == this.ts &&
          other.ambientT == this.ambientT &&
          other.ambientH == this.ambientH &&
          other.dissT == this.dissT &&
          other.dissH == this.dissH &&
          other.setpoint == this.setpoint &&
          other.pidOut == this.pidOut &&
          other.source == this.source &&
          other.online == this.online);
}

class LatestStatesCompanion extends UpdateCompanion<LatestState> {
  final Value<String> deviceId;
  final Value<int> ts;
  final Value<double?> ambientT;
  final Value<double?> ambientH;
  final Value<double?> dissT;
  final Value<double?> dissH;
  final Value<double?> setpoint;
  final Value<double?> pidOut;
  final Value<String> source;
  final Value<bool> online;
  final Value<int> rowid;
  const LatestStatesCompanion({
    this.deviceId = const Value.absent(),
    this.ts = const Value.absent(),
    this.ambientT = const Value.absent(),
    this.ambientH = const Value.absent(),
    this.dissT = const Value.absent(),
    this.dissH = const Value.absent(),
    this.setpoint = const Value.absent(),
    this.pidOut = const Value.absent(),
    this.source = const Value.absent(),
    this.online = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LatestStatesCompanion.insert({
    required String deviceId,
    required int ts,
    this.ambientT = const Value.absent(),
    this.ambientH = const Value.absent(),
    this.dissT = const Value.absent(),
    this.dissH = const Value.absent(),
    this.setpoint = const Value.absent(),
    this.pidOut = const Value.absent(),
    this.source = const Value.absent(),
    this.online = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : deviceId = Value(deviceId),
        ts = Value(ts);
  static Insertable<LatestState> custom({
    Expression<String>? deviceId,
    Expression<int>? ts,
    Expression<double>? ambientT,
    Expression<double>? ambientH,
    Expression<double>? dissT,
    Expression<double>? dissH,
    Expression<double>? setpoint,
    Expression<double>? pidOut,
    Expression<String>? source,
    Expression<bool>? online,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (ts != null) 'ts': ts,
      if (ambientT != null) 'ambient_t': ambientT,
      if (ambientH != null) 'ambient_h': ambientH,
      if (dissT != null) 'diss_t': dissT,
      if (dissH != null) 'diss_h': dissH,
      if (setpoint != null) 'setpoint': setpoint,
      if (pidOut != null) 'pid_out': pidOut,
      if (source != null) 'source': source,
      if (online != null) 'online': online,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LatestStatesCompanion copyWith(
      {Value<String>? deviceId,
      Value<int>? ts,
      Value<double?>? ambientT,
      Value<double?>? ambientH,
      Value<double?>? dissT,
      Value<double?>? dissH,
      Value<double?>? setpoint,
      Value<double?>? pidOut,
      Value<String>? source,
      Value<bool>? online,
      Value<int>? rowid}) {
    return LatestStatesCompanion(
      deviceId: deviceId ?? this.deviceId,
      ts: ts ?? this.ts,
      ambientT: ambientT ?? this.ambientT,
      ambientH: ambientH ?? this.ambientH,
      dissT: dissT ?? this.dissT,
      dissH: dissH ?? this.dissH,
      setpoint: setpoint ?? this.setpoint,
      pidOut: pidOut ?? this.pidOut,
      source: source ?? this.source,
      online: online ?? this.online,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (ambientT.present) {
      map['ambient_t'] = Variable<double>(ambientT.value);
    }
    if (ambientH.present) {
      map['ambient_h'] = Variable<double>(ambientH.value);
    }
    if (dissT.present) {
      map['diss_t'] = Variable<double>(dissT.value);
    }
    if (dissH.present) {
      map['diss_h'] = Variable<double>(dissH.value);
    }
    if (setpoint.present) {
      map['setpoint'] = Variable<double>(setpoint.value);
    }
    if (pidOut.present) {
      map['pid_out'] = Variable<double>(pidOut.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (online.present) {
      map['online'] = Variable<bool>(online.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LatestStatesCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('ts: $ts, ')
          ..write('ambientT: $ambientT, ')
          ..write('ambientH: $ambientH, ')
          ..write('dissT: $dissT, ')
          ..write('dissH: $dissH, ')
          ..write('setpoint: $setpoint, ')
          ..write('pidOut: $pidOut, ')
          ..write('source: $source, ')
          ..write('online: $online, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TelemetryCacheTable extends TelemetryCache
    with TableInfo<$TelemetryCacheTable, TelemetryCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TelemetryCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
      'ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _ambientTMeta =
      const VerificationMeta('ambientT');
  @override
  late final GeneratedColumn<double> ambientT = GeneratedColumn<double>(
      'ambient_t', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _ambientHMeta =
      const VerificationMeta('ambientH');
  @override
  late final GeneratedColumn<double> ambientH = GeneratedColumn<double>(
      'ambient_h', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _dissTMeta = const VerificationMeta('dissT');
  @override
  late final GeneratedColumn<double> dissT = GeneratedColumn<double>(
      'diss_t', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _dissHMeta = const VerificationMeta('dissH');
  @override
  late final GeneratedColumn<double> dissH = GeneratedColumn<double>(
      'diss_h', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [deviceId, ts, ambientT, ambientH, dissT, dissH];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'telemetry_cache';
  @override
  VerificationContext validateIntegrity(Insertable<TelemetryCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('ambient_t')) {
      context.handle(_ambientTMeta,
          ambientT.isAcceptableOrUnknown(data['ambient_t']!, _ambientTMeta));
    }
    if (data.containsKey('ambient_h')) {
      context.handle(_ambientHMeta,
          ambientH.isAcceptableOrUnknown(data['ambient_h']!, _ambientHMeta));
    }
    if (data.containsKey('diss_t')) {
      context.handle(
          _dissTMeta, dissT.isAcceptableOrUnknown(data['diss_t']!, _dissTMeta));
    }
    if (data.containsKey('diss_h')) {
      context.handle(
          _dissHMeta, dissH.isAcceptableOrUnknown(data['diss_h']!, _dissHMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId, ts};
  @override
  TelemetryCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TelemetryCacheData(
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts'])!,
      ambientT: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}ambient_t']),
      ambientH: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}ambient_h']),
      dissT: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}diss_t']),
      dissH: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}diss_h']),
    );
  }

  @override
  $TelemetryCacheTable createAlias(String alias) {
    return $TelemetryCacheTable(attachedDatabase, alias);
  }
}

class TelemetryCacheData extends DataClass
    implements Insertable<TelemetryCacheData> {
  final String deviceId;
  final int ts;
  final double? ambientT;
  final double? ambientH;
  final double? dissT;
  final double? dissH;
  const TelemetryCacheData(
      {required this.deviceId,
      required this.ts,
      this.ambientT,
      this.ambientH,
      this.dissT,
      this.dissH});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['ts'] = Variable<int>(ts);
    if (!nullToAbsent || ambientT != null) {
      map['ambient_t'] = Variable<double>(ambientT);
    }
    if (!nullToAbsent || ambientH != null) {
      map['ambient_h'] = Variable<double>(ambientH);
    }
    if (!nullToAbsent || dissT != null) {
      map['diss_t'] = Variable<double>(dissT);
    }
    if (!nullToAbsent || dissH != null) {
      map['diss_h'] = Variable<double>(dissH);
    }
    return map;
  }

  TelemetryCacheCompanion toCompanion(bool nullToAbsent) {
    return TelemetryCacheCompanion(
      deviceId: Value(deviceId),
      ts: Value(ts),
      ambientT: ambientT == null && nullToAbsent
          ? const Value.absent()
          : Value(ambientT),
      ambientH: ambientH == null && nullToAbsent
          ? const Value.absent()
          : Value(ambientH),
      dissT:
          dissT == null && nullToAbsent ? const Value.absent() : Value(dissT),
      dissH:
          dissH == null && nullToAbsent ? const Value.absent() : Value(dissH),
    );
  }

  factory TelemetryCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TelemetryCacheData(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      ts: serializer.fromJson<int>(json['ts']),
      ambientT: serializer.fromJson<double?>(json['ambientT']),
      ambientH: serializer.fromJson<double?>(json['ambientH']),
      dissT: serializer.fromJson<double?>(json['dissT']),
      dissH: serializer.fromJson<double?>(json['dissH']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'ts': serializer.toJson<int>(ts),
      'ambientT': serializer.toJson<double?>(ambientT),
      'ambientH': serializer.toJson<double?>(ambientH),
      'dissT': serializer.toJson<double?>(dissT),
      'dissH': serializer.toJson<double?>(dissH),
    };
  }

  TelemetryCacheData copyWith(
          {String? deviceId,
          int? ts,
          Value<double?> ambientT = const Value.absent(),
          Value<double?> ambientH = const Value.absent(),
          Value<double?> dissT = const Value.absent(),
          Value<double?> dissH = const Value.absent()}) =>
      TelemetryCacheData(
        deviceId: deviceId ?? this.deviceId,
        ts: ts ?? this.ts,
        ambientT: ambientT.present ? ambientT.value : this.ambientT,
        ambientH: ambientH.present ? ambientH.value : this.ambientH,
        dissT: dissT.present ? dissT.value : this.dissT,
        dissH: dissH.present ? dissH.value : this.dissH,
      );
  TelemetryCacheData copyWithCompanion(TelemetryCacheCompanion data) {
    return TelemetryCacheData(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      ts: data.ts.present ? data.ts.value : this.ts,
      ambientT: data.ambientT.present ? data.ambientT.value : this.ambientT,
      ambientH: data.ambientH.present ? data.ambientH.value : this.ambientH,
      dissT: data.dissT.present ? data.dissT.value : this.dissT,
      dissH: data.dissH.present ? data.dissH.value : this.dissH,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TelemetryCacheData(')
          ..write('deviceId: $deviceId, ')
          ..write('ts: $ts, ')
          ..write('ambientT: $ambientT, ')
          ..write('ambientH: $ambientH, ')
          ..write('dissT: $dissT, ')
          ..write('dissH: $dissH')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(deviceId, ts, ambientT, ambientH, dissT, dissH);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TelemetryCacheData &&
          other.deviceId == this.deviceId &&
          other.ts == this.ts &&
          other.ambientT == this.ambientT &&
          other.ambientH == this.ambientH &&
          other.dissT == this.dissT &&
          other.dissH == this.dissH);
}

class TelemetryCacheCompanion extends UpdateCompanion<TelemetryCacheData> {
  final Value<String> deviceId;
  final Value<int> ts;
  final Value<double?> ambientT;
  final Value<double?> ambientH;
  final Value<double?> dissT;
  final Value<double?> dissH;
  final Value<int> rowid;
  const TelemetryCacheCompanion({
    this.deviceId = const Value.absent(),
    this.ts = const Value.absent(),
    this.ambientT = const Value.absent(),
    this.ambientH = const Value.absent(),
    this.dissT = const Value.absent(),
    this.dissH = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TelemetryCacheCompanion.insert({
    required String deviceId,
    required int ts,
    this.ambientT = const Value.absent(),
    this.ambientH = const Value.absent(),
    this.dissT = const Value.absent(),
    this.dissH = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : deviceId = Value(deviceId),
        ts = Value(ts);
  static Insertable<TelemetryCacheData> custom({
    Expression<String>? deviceId,
    Expression<int>? ts,
    Expression<double>? ambientT,
    Expression<double>? ambientH,
    Expression<double>? dissT,
    Expression<double>? dissH,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (ts != null) 'ts': ts,
      if (ambientT != null) 'ambient_t': ambientT,
      if (ambientH != null) 'ambient_h': ambientH,
      if (dissT != null) 'diss_t': dissT,
      if (dissH != null) 'diss_h': dissH,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TelemetryCacheCompanion copyWith(
      {Value<String>? deviceId,
      Value<int>? ts,
      Value<double?>? ambientT,
      Value<double?>? ambientH,
      Value<double?>? dissT,
      Value<double?>? dissH,
      Value<int>? rowid}) {
    return TelemetryCacheCompanion(
      deviceId: deviceId ?? this.deviceId,
      ts: ts ?? this.ts,
      ambientT: ambientT ?? this.ambientT,
      ambientH: ambientH ?? this.ambientH,
      dissT: dissT ?? this.dissT,
      dissH: dissH ?? this.dissH,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (ambientT.present) {
      map['ambient_t'] = Variable<double>(ambientT.value);
    }
    if (ambientH.present) {
      map['ambient_h'] = Variable<double>(ambientH.value);
    }
    if (dissT.present) {
      map['diss_t'] = Variable<double>(dissT.value);
    }
    if (dissH.present) {
      map['diss_h'] = Variable<double>(dissH.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TelemetryCacheCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('ts: $ts, ')
          ..write('ambientT: $ambientT, ')
          ..write('ambientH: $ambientH, ')
          ..write('dissT: $dissT, ')
          ..write('dissH: $dissH, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HistoryCacheTable extends HistoryCache
    with TableInfo<$HistoryCacheTable, HistoryCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bucketMeta = const VerificationMeta('bucket');
  @override
  late final GeneratedColumn<String> bucket = GeneratedColumn<String>(
      'bucket', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rangeKeyMeta =
      const VerificationMeta('rangeKey');
  @override
  late final GeneratedColumn<String> rangeKey = GeneratedColumn<String>(
      'range_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _maxTsMeta = const VerificationMeta('maxTs');
  @override
  late final GeneratedColumn<int> maxTs = GeneratedColumn<int>(
      'max_ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [deviceId, bucket, rangeKey, payload, fetchedAt, maxTs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_cache';
  @override
  VerificationContext validateIntegrity(Insertable<HistoryCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('bucket')) {
      context.handle(_bucketMeta,
          bucket.isAcceptableOrUnknown(data['bucket']!, _bucketMeta));
    } else if (isInserting) {
      context.missing(_bucketMeta);
    }
    if (data.containsKey('range_key')) {
      context.handle(_rangeKeyMeta,
          rangeKey.isAcceptableOrUnknown(data['range_key']!, _rangeKeyMeta));
    } else if (isInserting) {
      context.missing(_rangeKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('max_ts')) {
      context.handle(
          _maxTsMeta, maxTs.isAcceptableOrUnknown(data['max_ts']!, _maxTsMeta));
    } else if (isInserting) {
      context.missing(_maxTsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId, bucket, rangeKey};
  @override
  HistoryCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryCacheData(
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      bucket: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bucket'])!,
      rangeKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}range_key'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}fetched_at'])!,
      maxTs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_ts'])!,
    );
  }

  @override
  $HistoryCacheTable createAlias(String alias) {
    return $HistoryCacheTable(attachedDatabase, alias);
  }
}

class HistoryCacheData extends DataClass
    implements Insertable<HistoryCacheData> {
  final String deviceId;
  final String bucket;
  final String rangeKey;
  final String payload;
  final int fetchedAt;
  final int maxTs;
  const HistoryCacheData(
      {required this.deviceId,
      required this.bucket,
      required this.rangeKey,
      required this.payload,
      required this.fetchedAt,
      required this.maxTs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['bucket'] = Variable<String>(bucket);
    map['range_key'] = Variable<String>(rangeKey);
    map['payload'] = Variable<String>(payload);
    map['fetched_at'] = Variable<int>(fetchedAt);
    map['max_ts'] = Variable<int>(maxTs);
    return map;
  }

  HistoryCacheCompanion toCompanion(bool nullToAbsent) {
    return HistoryCacheCompanion(
      deviceId: Value(deviceId),
      bucket: Value(bucket),
      rangeKey: Value(rangeKey),
      payload: Value(payload),
      fetchedAt: Value(fetchedAt),
      maxTs: Value(maxTs),
    );
  }

  factory HistoryCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryCacheData(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      bucket: serializer.fromJson<String>(json['bucket']),
      rangeKey: serializer.fromJson<String>(json['rangeKey']),
      payload: serializer.fromJson<String>(json['payload']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
      maxTs: serializer.fromJson<int>(json['maxTs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'bucket': serializer.toJson<String>(bucket),
      'rangeKey': serializer.toJson<String>(rangeKey),
      'payload': serializer.toJson<String>(payload),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
      'maxTs': serializer.toJson<int>(maxTs),
    };
  }

  HistoryCacheData copyWith(
          {String? deviceId,
          String? bucket,
          String? rangeKey,
          String? payload,
          int? fetchedAt,
          int? maxTs}) =>
      HistoryCacheData(
        deviceId: deviceId ?? this.deviceId,
        bucket: bucket ?? this.bucket,
        rangeKey: rangeKey ?? this.rangeKey,
        payload: payload ?? this.payload,
        fetchedAt: fetchedAt ?? this.fetchedAt,
        maxTs: maxTs ?? this.maxTs,
      );
  HistoryCacheData copyWithCompanion(HistoryCacheCompanion data) {
    return HistoryCacheData(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      bucket: data.bucket.present ? data.bucket.value : this.bucket,
      rangeKey: data.rangeKey.present ? data.rangeKey.value : this.rangeKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      maxTs: data.maxTs.present ? data.maxTs.value : this.maxTs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryCacheData(')
          ..write('deviceId: $deviceId, ')
          ..write('bucket: $bucket, ')
          ..write('rangeKey: $rangeKey, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('maxTs: $maxTs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(deviceId, bucket, rangeKey, payload, fetchedAt, maxTs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryCacheData &&
          other.deviceId == this.deviceId &&
          other.bucket == this.bucket &&
          other.rangeKey == this.rangeKey &&
          other.payload == this.payload &&
          other.fetchedAt == this.fetchedAt &&
          other.maxTs == this.maxTs);
}

class HistoryCacheCompanion extends UpdateCompanion<HistoryCacheData> {
  final Value<String> deviceId;
  final Value<String> bucket;
  final Value<String> rangeKey;
  final Value<String> payload;
  final Value<int> fetchedAt;
  final Value<int> maxTs;
  final Value<int> rowid;
  const HistoryCacheCompanion({
    this.deviceId = const Value.absent(),
    this.bucket = const Value.absent(),
    this.rangeKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.maxTs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HistoryCacheCompanion.insert({
    required String deviceId,
    required String bucket,
    required String rangeKey,
    required String payload,
    required int fetchedAt,
    required int maxTs,
    this.rowid = const Value.absent(),
  })  : deviceId = Value(deviceId),
        bucket = Value(bucket),
        rangeKey = Value(rangeKey),
        payload = Value(payload),
        fetchedAt = Value(fetchedAt),
        maxTs = Value(maxTs);
  static Insertable<HistoryCacheData> custom({
    Expression<String>? deviceId,
    Expression<String>? bucket,
    Expression<String>? rangeKey,
    Expression<String>? payload,
    Expression<int>? fetchedAt,
    Expression<int>? maxTs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (bucket != null) 'bucket': bucket,
      if (rangeKey != null) 'range_key': rangeKey,
      if (payload != null) 'payload': payload,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (maxTs != null) 'max_ts': maxTs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HistoryCacheCompanion copyWith(
      {Value<String>? deviceId,
      Value<String>? bucket,
      Value<String>? rangeKey,
      Value<String>? payload,
      Value<int>? fetchedAt,
      Value<int>? maxTs,
      Value<int>? rowid}) {
    return HistoryCacheCompanion(
      deviceId: deviceId ?? this.deviceId,
      bucket: bucket ?? this.bucket,
      rangeKey: rangeKey ?? this.rangeKey,
      payload: payload ?? this.payload,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      maxTs: maxTs ?? this.maxTs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (bucket.present) {
      map['bucket'] = Variable<String>(bucket.value);
    }
    if (rangeKey.present) {
      map['range_key'] = Variable<String>(rangeKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (maxTs.present) {
      map['max_ts'] = Variable<int>(maxTs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryCacheCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('bucket: $bucket, ')
          ..write('rangeKey: $rangeKey, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('maxTs: $maxTs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, action, payload, createdAt, synced];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final int id;
  final String action;
  final String payload;
  final DateTime createdAt;
  final bool synced;
  const OutboxData(
      {required this.id,
      required this.action,
      required this.payload,
      required this.createdAt,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['action'] = Variable<String>(action);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      action: Value(action),
      payload: Value(payload),
      createdAt: Value(createdAt),
      synced: Value(synced),
    );
  }

  factory OutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<int>(json['id']),
      action: serializer.fromJson<String>(json['action']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'action': serializer.toJson<String>(action),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  OutboxData copyWith(
          {int? id,
          String? action,
          String? payload,
          DateTime? createdAt,
          bool? synced}) =>
      OutboxData(
        id: id ?? this.id,
        action: action ?? this.action,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        synced: synced ?? this.synced,
      );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      action: data.action.present ? data.action.value : this.action,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, action, payload, createdAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.action == this.action &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<int> id;
  final Value<String> action;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<bool> synced;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.action = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String action,
    required String payload,
    required DateTime createdAt,
    this.synced = const Value.absent(),
  })  : action = Value(action),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<int>? id,
    Expression<String>? action,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (action != null) 'action': action,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
    });
  }

  OutboxCompanion copyWith(
      {Value<int>? id,
      Value<String>? action,
      Value<String>? payload,
      Value<DateTime>? createdAt,
      Value<bool>? synced}) {
    return OutboxCompanion(
      id: id ?? this.id,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $UserSessionTable extends UserSession
    with TableInfo<$UserSessionTable, UserSessionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSessionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_session';
  @override
  VerificationContext validateIntegrity(Insertable<UserSessionData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  UserSessionData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSessionData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $UserSessionTable createAlias(String alias) {
    return $UserSessionTable(attachedDatabase, alias);
  }
}

class UserSessionData extends DataClass implements Insertable<UserSessionData> {
  final String key;
  final String value;
  const UserSessionData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  UserSessionCompanion toCompanion(bool nullToAbsent) {
    return UserSessionCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory UserSessionData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSessionData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  UserSessionData copyWith({String? key, String? value}) => UserSessionData(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  UserSessionData copyWithCompanion(UserSessionCompanion data) {
    return UserSessionData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSessionData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSessionData &&
          other.key == this.key &&
          other.value == this.value);
}

class UserSessionCompanion extends UpdateCompanion<UserSessionData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const UserSessionCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserSessionCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<UserSessionData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserSessionCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return UserSessionCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSessionCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $LatestStatesTable latestStates = $LatestStatesTable(this);
  late final $TelemetryCacheTable telemetryCache = $TelemetryCacheTable(this);
  late final $HistoryCacheTable historyCache = $HistoryCacheTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $UserSessionTable userSession = $UserSessionTable(this);
  late final DeviceDao deviceDao = DeviceDao(this as AppDatabase);
  late final TelemetryDao telemetryDao = TelemetryDao(this as AppDatabase);
  late final OutboxDao outboxDao = OutboxDao(this as AppDatabase);
  late final HistoryCacheDao historyCacheDao =
      HistoryCacheDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        devices,
        latestStates,
        telemetryCache,
        historyCache,
        outbox,
        userSession
      ];
}

typedef $$DevicesTableCreateCompanionBuilder = DevicesCompanion Function({
  required String deviceId,
  Value<String> alias,
  Value<String> status,
  Value<int?> lastSeenAt,
  Value<String?> fwVersion,
  Value<String?> storedContent,
  Value<int> rowid,
});
typedef $$DevicesTableUpdateCompanionBuilder = DevicesCompanion Function({
  Value<String> deviceId,
  Value<String> alias,
  Value<String> status,
  Value<int?> lastSeenAt,
  Value<String?> fwVersion,
  Value<String?> storedContent,
  Value<int> rowid,
});

class $$DevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fwVersion => $composableBuilder(
      column: $table.fwVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get storedContent => $composableBuilder(
      column: $table.storedContent, builder: (column) => ColumnFilters(column));
}

class $$DevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fwVersion => $composableBuilder(
      column: $table.fwVersion, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get storedContent => $composableBuilder(
      column: $table.storedContent,
      builder: (column) => ColumnOrderings(column));
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => column);

  GeneratedColumn<String> get fwVersion =>
      $composableBuilder(column: $table.fwVersion, builder: (column) => column);

  GeneratedColumn<String> get storedContent => $composableBuilder(
      column: $table.storedContent, builder: (column) => column);
}

class $$DevicesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DevicesTable,
    Device,
    $$DevicesTableFilterComposer,
    $$DevicesTableOrderingComposer,
    $$DevicesTableAnnotationComposer,
    $$DevicesTableCreateCompanionBuilder,
    $$DevicesTableUpdateCompanionBuilder,
    (Device, BaseReferences<_$AppDatabase, $DevicesTable, Device>),
    Device,
    PrefetchHooks Function()> {
  $$DevicesTableTableManager(_$AppDatabase db, $DevicesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> deviceId = const Value.absent(),
            Value<String> alias = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int?> lastSeenAt = const Value.absent(),
            Value<String?> fwVersion = const Value.absent(),
            Value<String?> storedContent = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DevicesCompanion(
            deviceId: deviceId,
            alias: alias,
            status: status,
            lastSeenAt: lastSeenAt,
            fwVersion: fwVersion,
            storedContent: storedContent,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String deviceId,
            Value<String> alias = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int?> lastSeenAt = const Value.absent(),
            Value<String?> fwVersion = const Value.absent(),
            Value<String?> storedContent = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DevicesCompanion.insert(
            deviceId: deviceId,
            alias: alias,
            status: status,
            lastSeenAt: lastSeenAt,
            fwVersion: fwVersion,
            storedContent: storedContent,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DevicesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DevicesTable,
    Device,
    $$DevicesTableFilterComposer,
    $$DevicesTableOrderingComposer,
    $$DevicesTableAnnotationComposer,
    $$DevicesTableCreateCompanionBuilder,
    $$DevicesTableUpdateCompanionBuilder,
    (Device, BaseReferences<_$AppDatabase, $DevicesTable, Device>),
    Device,
    PrefetchHooks Function()>;
typedef $$LatestStatesTableCreateCompanionBuilder = LatestStatesCompanion
    Function({
  required String deviceId,
  required int ts,
  Value<double?> ambientT,
  Value<double?> ambientH,
  Value<double?> dissT,
  Value<double?> dissH,
  Value<double?> setpoint,
  Value<double?> pidOut,
  Value<String> source,
  Value<bool> online,
  Value<int> rowid,
});
typedef $$LatestStatesTableUpdateCompanionBuilder = LatestStatesCompanion
    Function({
  Value<String> deviceId,
  Value<int> ts,
  Value<double?> ambientT,
  Value<double?> ambientH,
  Value<double?> dissT,
  Value<double?> dissH,
  Value<double?> setpoint,
  Value<double?> pidOut,
  Value<String> source,
  Value<bool> online,
  Value<int> rowid,
});

class $$LatestStatesTableFilterComposer
    extends Composer<_$AppDatabase, $LatestStatesTable> {
  $$LatestStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get ambientT => $composableBuilder(
      column: $table.ambientT, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get ambientH => $composableBuilder(
      column: $table.ambientH, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get dissT => $composableBuilder(
      column: $table.dissT, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get dissH => $composableBuilder(
      column: $table.dissH, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get setpoint => $composableBuilder(
      column: $table.setpoint, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get pidOut => $composableBuilder(
      column: $table.pidOut, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get online => $composableBuilder(
      column: $table.online, builder: (column) => ColumnFilters(column));
}

class $$LatestStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $LatestStatesTable> {
  $$LatestStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get ambientT => $composableBuilder(
      column: $table.ambientT, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get ambientH => $composableBuilder(
      column: $table.ambientH, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get dissT => $composableBuilder(
      column: $table.dissT, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get dissH => $composableBuilder(
      column: $table.dissH, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get setpoint => $composableBuilder(
      column: $table.setpoint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get pidOut => $composableBuilder(
      column: $table.pidOut, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get online => $composableBuilder(
      column: $table.online, builder: (column) => ColumnOrderings(column));
}

class $$LatestStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LatestStatesTable> {
  $$LatestStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<double> get ambientT =>
      $composableBuilder(column: $table.ambientT, builder: (column) => column);

  GeneratedColumn<double> get ambientH =>
      $composableBuilder(column: $table.ambientH, builder: (column) => column);

  GeneratedColumn<double> get dissT =>
      $composableBuilder(column: $table.dissT, builder: (column) => column);

  GeneratedColumn<double> get dissH =>
      $composableBuilder(column: $table.dissH, builder: (column) => column);

  GeneratedColumn<double> get setpoint =>
      $composableBuilder(column: $table.setpoint, builder: (column) => column);

  GeneratedColumn<double> get pidOut =>
      $composableBuilder(column: $table.pidOut, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get online =>
      $composableBuilder(column: $table.online, builder: (column) => column);
}

class $$LatestStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LatestStatesTable,
    LatestState,
    $$LatestStatesTableFilterComposer,
    $$LatestStatesTableOrderingComposer,
    $$LatestStatesTableAnnotationComposer,
    $$LatestStatesTableCreateCompanionBuilder,
    $$LatestStatesTableUpdateCompanionBuilder,
    (
      LatestState,
      BaseReferences<_$AppDatabase, $LatestStatesTable, LatestState>
    ),
    LatestState,
    PrefetchHooks Function()> {
  $$LatestStatesTableTableManager(_$AppDatabase db, $LatestStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LatestStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LatestStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LatestStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> deviceId = const Value.absent(),
            Value<int> ts = const Value.absent(),
            Value<double?> ambientT = const Value.absent(),
            Value<double?> ambientH = const Value.absent(),
            Value<double?> dissT = const Value.absent(),
            Value<double?> dissH = const Value.absent(),
            Value<double?> setpoint = const Value.absent(),
            Value<double?> pidOut = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<bool> online = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LatestStatesCompanion(
            deviceId: deviceId,
            ts: ts,
            ambientT: ambientT,
            ambientH: ambientH,
            dissT: dissT,
            dissH: dissH,
            setpoint: setpoint,
            pidOut: pidOut,
            source: source,
            online: online,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String deviceId,
            required int ts,
            Value<double?> ambientT = const Value.absent(),
            Value<double?> ambientH = const Value.absent(),
            Value<double?> dissT = const Value.absent(),
            Value<double?> dissH = const Value.absent(),
            Value<double?> setpoint = const Value.absent(),
            Value<double?> pidOut = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<bool> online = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LatestStatesCompanion.insert(
            deviceId: deviceId,
            ts: ts,
            ambientT: ambientT,
            ambientH: ambientH,
            dissT: dissT,
            dissH: dissH,
            setpoint: setpoint,
            pidOut: pidOut,
            source: source,
            online: online,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LatestStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LatestStatesTable,
    LatestState,
    $$LatestStatesTableFilterComposer,
    $$LatestStatesTableOrderingComposer,
    $$LatestStatesTableAnnotationComposer,
    $$LatestStatesTableCreateCompanionBuilder,
    $$LatestStatesTableUpdateCompanionBuilder,
    (
      LatestState,
      BaseReferences<_$AppDatabase, $LatestStatesTable, LatestState>
    ),
    LatestState,
    PrefetchHooks Function()>;
typedef $$TelemetryCacheTableCreateCompanionBuilder = TelemetryCacheCompanion
    Function({
  required String deviceId,
  required int ts,
  Value<double?> ambientT,
  Value<double?> ambientH,
  Value<double?> dissT,
  Value<double?> dissH,
  Value<int> rowid,
});
typedef $$TelemetryCacheTableUpdateCompanionBuilder = TelemetryCacheCompanion
    Function({
  Value<String> deviceId,
  Value<int> ts,
  Value<double?> ambientT,
  Value<double?> ambientH,
  Value<double?> dissT,
  Value<double?> dissH,
  Value<int> rowid,
});

class $$TelemetryCacheTableFilterComposer
    extends Composer<_$AppDatabase, $TelemetryCacheTable> {
  $$TelemetryCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get ambientT => $composableBuilder(
      column: $table.ambientT, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get ambientH => $composableBuilder(
      column: $table.ambientH, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get dissT => $composableBuilder(
      column: $table.dissT, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get dissH => $composableBuilder(
      column: $table.dissH, builder: (column) => ColumnFilters(column));
}

class $$TelemetryCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $TelemetryCacheTable> {
  $$TelemetryCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get ambientT => $composableBuilder(
      column: $table.ambientT, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get ambientH => $composableBuilder(
      column: $table.ambientH, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get dissT => $composableBuilder(
      column: $table.dissT, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get dissH => $composableBuilder(
      column: $table.dissH, builder: (column) => ColumnOrderings(column));
}

class $$TelemetryCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $TelemetryCacheTable> {
  $$TelemetryCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<double> get ambientT =>
      $composableBuilder(column: $table.ambientT, builder: (column) => column);

  GeneratedColumn<double> get ambientH =>
      $composableBuilder(column: $table.ambientH, builder: (column) => column);

  GeneratedColumn<double> get dissT =>
      $composableBuilder(column: $table.dissT, builder: (column) => column);

  GeneratedColumn<double> get dissH =>
      $composableBuilder(column: $table.dissH, builder: (column) => column);
}

class $$TelemetryCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TelemetryCacheTable,
    TelemetryCacheData,
    $$TelemetryCacheTableFilterComposer,
    $$TelemetryCacheTableOrderingComposer,
    $$TelemetryCacheTableAnnotationComposer,
    $$TelemetryCacheTableCreateCompanionBuilder,
    $$TelemetryCacheTableUpdateCompanionBuilder,
    (
      TelemetryCacheData,
      BaseReferences<_$AppDatabase, $TelemetryCacheTable, TelemetryCacheData>
    ),
    TelemetryCacheData,
    PrefetchHooks Function()> {
  $$TelemetryCacheTableTableManager(
      _$AppDatabase db, $TelemetryCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TelemetryCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TelemetryCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TelemetryCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> deviceId = const Value.absent(),
            Value<int> ts = const Value.absent(),
            Value<double?> ambientT = const Value.absent(),
            Value<double?> ambientH = const Value.absent(),
            Value<double?> dissT = const Value.absent(),
            Value<double?> dissH = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TelemetryCacheCompanion(
            deviceId: deviceId,
            ts: ts,
            ambientT: ambientT,
            ambientH: ambientH,
            dissT: dissT,
            dissH: dissH,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String deviceId,
            required int ts,
            Value<double?> ambientT = const Value.absent(),
            Value<double?> ambientH = const Value.absent(),
            Value<double?> dissT = const Value.absent(),
            Value<double?> dissH = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TelemetryCacheCompanion.insert(
            deviceId: deviceId,
            ts: ts,
            ambientT: ambientT,
            ambientH: ambientH,
            dissT: dissT,
            dissH: dissH,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TelemetryCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TelemetryCacheTable,
    TelemetryCacheData,
    $$TelemetryCacheTableFilterComposer,
    $$TelemetryCacheTableOrderingComposer,
    $$TelemetryCacheTableAnnotationComposer,
    $$TelemetryCacheTableCreateCompanionBuilder,
    $$TelemetryCacheTableUpdateCompanionBuilder,
    (
      TelemetryCacheData,
      BaseReferences<_$AppDatabase, $TelemetryCacheTable, TelemetryCacheData>
    ),
    TelemetryCacheData,
    PrefetchHooks Function()>;
typedef $$HistoryCacheTableCreateCompanionBuilder = HistoryCacheCompanion
    Function({
  required String deviceId,
  required String bucket,
  required String rangeKey,
  required String payload,
  required int fetchedAt,
  required int maxTs,
  Value<int> rowid,
});
typedef $$HistoryCacheTableUpdateCompanionBuilder = HistoryCacheCompanion
    Function({
  Value<String> deviceId,
  Value<String> bucket,
  Value<String> rangeKey,
  Value<String> payload,
  Value<int> fetchedAt,
  Value<int> maxTs,
  Value<int> rowid,
});

class $$HistoryCacheTableFilterComposer
    extends Composer<_$AppDatabase, $HistoryCacheTable> {
  $$HistoryCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bucket => $composableBuilder(
      column: $table.bucket, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rangeKey => $composableBuilder(
      column: $table.rangeKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxTs => $composableBuilder(
      column: $table.maxTs, builder: (column) => ColumnFilters(column));
}

class $$HistoryCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoryCacheTable> {
  $$HistoryCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bucket => $composableBuilder(
      column: $table.bucket, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rangeKey => $composableBuilder(
      column: $table.rangeKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxTs => $composableBuilder(
      column: $table.maxTs, builder: (column) => ColumnOrderings(column));
}

class $$HistoryCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoryCacheTable> {
  $$HistoryCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => column);

  GeneratedColumn<String> get rangeKey =>
      $composableBuilder(column: $table.rangeKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<int> get maxTs =>
      $composableBuilder(column: $table.maxTs, builder: (column) => column);
}

class $$HistoryCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HistoryCacheTable,
    HistoryCacheData,
    $$HistoryCacheTableFilterComposer,
    $$HistoryCacheTableOrderingComposer,
    $$HistoryCacheTableAnnotationComposer,
    $$HistoryCacheTableCreateCompanionBuilder,
    $$HistoryCacheTableUpdateCompanionBuilder,
    (
      HistoryCacheData,
      BaseReferences<_$AppDatabase, $HistoryCacheTable, HistoryCacheData>
    ),
    HistoryCacheData,
    PrefetchHooks Function()> {
  $$HistoryCacheTableTableManager(_$AppDatabase db, $HistoryCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> deviceId = const Value.absent(),
            Value<String> bucket = const Value.absent(),
            Value<String> rangeKey = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> fetchedAt = const Value.absent(),
            Value<int> maxTs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HistoryCacheCompanion(
            deviceId: deviceId,
            bucket: bucket,
            rangeKey: rangeKey,
            payload: payload,
            fetchedAt: fetchedAt,
            maxTs: maxTs,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String deviceId,
            required String bucket,
            required String rangeKey,
            required String payload,
            required int fetchedAt,
            required int maxTs,
            Value<int> rowid = const Value.absent(),
          }) =>
              HistoryCacheCompanion.insert(
            deviceId: deviceId,
            bucket: bucket,
            rangeKey: rangeKey,
            payload: payload,
            fetchedAt: fetchedAt,
            maxTs: maxTs,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HistoryCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HistoryCacheTable,
    HistoryCacheData,
    $$HistoryCacheTableFilterComposer,
    $$HistoryCacheTableOrderingComposer,
    $$HistoryCacheTableAnnotationComposer,
    $$HistoryCacheTableCreateCompanionBuilder,
    $$HistoryCacheTableUpdateCompanionBuilder,
    (
      HistoryCacheData,
      BaseReferences<_$AppDatabase, $HistoryCacheTable, HistoryCacheData>
    ),
    HistoryCacheData,
    PrefetchHooks Function()>;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  required String action,
  required String payload,
  required DateTime createdAt,
  Value<bool> synced,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  Value<String> action,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<bool> synced,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$OutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()> {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              OutboxCompanion(
            id: id,
            action: action,
            payload: payload,
            createdAt: createdAt,
            synced: synced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String action,
            required String payload,
            required DateTime createdAt,
            Value<bool> synced = const Value.absent(),
          }) =>
              OutboxCompanion.insert(
            id: id,
            action: action,
            payload: payload,
            createdAt: createdAt,
            synced: synced,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()>;
typedef $$UserSessionTableCreateCompanionBuilder = UserSessionCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$UserSessionTableUpdateCompanionBuilder = UserSessionCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$UserSessionTableFilterComposer
    extends Composer<_$AppDatabase, $UserSessionTable> {
  $$UserSessionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$UserSessionTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSessionTable> {
  $$UserSessionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$UserSessionTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSessionTable> {
  $$UserSessionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$UserSessionTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserSessionTable,
    UserSessionData,
    $$UserSessionTableFilterComposer,
    $$UserSessionTableOrderingComposer,
    $$UserSessionTableAnnotationComposer,
    $$UserSessionTableCreateCompanionBuilder,
    $$UserSessionTableUpdateCompanionBuilder,
    (
      UserSessionData,
      BaseReferences<_$AppDatabase, $UserSessionTable, UserSessionData>
    ),
    UserSessionData,
    PrefetchHooks Function()> {
  $$UserSessionTableTableManager(_$AppDatabase db, $UserSessionTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSessionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSessionTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSessionTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserSessionCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              UserSessionCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserSessionTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserSessionTable,
    UserSessionData,
    $$UserSessionTableFilterComposer,
    $$UserSessionTableOrderingComposer,
    $$UserSessionTableAnnotationComposer,
    $$UserSessionTableCreateCompanionBuilder,
    $$UserSessionTableUpdateCompanionBuilder,
    (
      UserSessionData,
      BaseReferences<_$AppDatabase, $UserSessionTable, UserSessionData>
    ),
    UserSessionData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$LatestStatesTableTableManager get latestStates =>
      $$LatestStatesTableTableManager(_db, _db.latestStates);
  $$TelemetryCacheTableTableManager get telemetryCache =>
      $$TelemetryCacheTableTableManager(_db, _db.telemetryCache);
  $$HistoryCacheTableTableManager get historyCache =>
      $$HistoryCacheTableTableManager(_db, _db.historyCache);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$UserSessionTableTableManager get userSession =>
      $$UserSessionTableTableManager(_db, _db.userSession);
}
