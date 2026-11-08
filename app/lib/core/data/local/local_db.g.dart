// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_db.dart';

// ignore_for_file: type=lint
class $OutboxEntriesTable extends OutboxEntries
    with TableInfo<$OutboxEntriesTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
    'shop_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fnMeta = const VerificationMeta('fn');
  @override
  late final GeneratedColumn<String> fn = GeneratedColumn<String>(
    'fn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paramsMeta = const VerificationMeta('params');
  @override
  late final GeneratedColumn<String> params = GeneratedColumn<String>(
    'params',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rejectedMeta = const VerificationMeta(
    'rejected',
  );
  @override
  late final GeneratedColumn<bool> rejected = GeneratedColumn<bool>(
    'rejected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("rejected" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    id,
    shopId,
    fn,
    params,
    createdAt,
    attempts,
    lastError,
    rejected,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(
        _shopIdMeta,
        shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('fn')) {
      context.handle(_fnMeta, fn.isAcceptableOrUnknown(data['fn']!, _fnMeta));
    } else if (isInserting) {
      context.missing(_fnMeta);
    }
    if (data.containsKey('params')) {
      context.handle(
        _paramsMeta,
        params.isAcceptableOrUnknown(data['params']!, _paramsMeta),
      );
    } else if (isInserting) {
      context.missing(_paramsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('rejected')) {
      context.handle(
        _rejectedMeta,
        rejected.isAcceptableOrUnknown(data['rejected']!, _rejectedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      shopId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shop_id'],
      )!,
      fn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fn'],
      )!,
      params: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}params'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      rejected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}rejected'],
      )!,
    );
  }

  @override
  $OutboxEntriesTable createAlias(String alias) {
    return $OutboxEntriesTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final int seq;
  final String id;
  final String shopId;
  final String fn;
  final String params;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  /// Set when the server refused the command; it stays for review instead of
  /// blocking the commands behind it.
  final bool rejected;
  const OutboxEntry({
    required this.seq,
    required this.id,
    required this.shopId,
    required this.fn,
    required this.params,
    required this.createdAt,
    required this.attempts,
    this.lastError,
    required this.rejected,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['id'] = Variable<String>(id);
    map['shop_id'] = Variable<String>(shopId);
    map['fn'] = Variable<String>(fn);
    map['params'] = Variable<String>(params);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['rejected'] = Variable<bool>(rejected);
    return map;
  }

  OutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return OutboxEntriesCompanion(
      seq: Value(seq),
      id: Value(id),
      shopId: Value(shopId),
      fn: Value(fn),
      params: Value(params),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      rejected: Value(rejected),
    );
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      seq: serializer.fromJson<int>(json['seq']),
      id: serializer.fromJson<String>(json['id']),
      shopId: serializer.fromJson<String>(json['shopId']),
      fn: serializer.fromJson<String>(json['fn']),
      params: serializer.fromJson<String>(json['params']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      rejected: serializer.fromJson<bool>(json['rejected']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'id': serializer.toJson<String>(id),
      'shopId': serializer.toJson<String>(shopId),
      'fn': serializer.toJson<String>(fn),
      'params': serializer.toJson<String>(params),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'rejected': serializer.toJson<bool>(rejected),
    };
  }

  OutboxEntry copyWith({
    int? seq,
    String? id,
    String? shopId,
    String? fn,
    String? params,
    DateTime? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    bool? rejected,
  }) => OutboxEntry(
    seq: seq ?? this.seq,
    id: id ?? this.id,
    shopId: shopId ?? this.shopId,
    fn: fn ?? this.fn,
    params: params ?? this.params,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    rejected: rejected ?? this.rejected,
  );
  OutboxEntry copyWithCompanion(OutboxEntriesCompanion data) {
    return OutboxEntry(
      seq: data.seq.present ? data.seq.value : this.seq,
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      fn: data.fn.present ? data.fn.value : this.fn,
      params: data.params.present ? data.params.value : this.params,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      rejected: data.rejected.present ? data.rejected.value : this.rejected,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('seq: $seq, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('fn: $fn, ')
          ..write('params: $params, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('rejected: $rejected')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    id,
    shopId,
    fn,
    params,
    createdAt,
    attempts,
    lastError,
    rejected,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.seq == this.seq &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.fn == this.fn &&
          other.params == this.params &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.rejected == this.rejected);
}

class OutboxEntriesCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<int> seq;
  final Value<String> id;
  final Value<String> shopId;
  final Value<String> fn;
  final Value<String> params;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<bool> rejected;
  const OutboxEntriesCompanion({
    this.seq = const Value.absent(),
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.fn = const Value.absent(),
    this.params = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rejected = const Value.absent(),
  });
  OutboxEntriesCompanion.insert({
    this.seq = const Value.absent(),
    required String id,
    required String shopId,
    required String fn,
    required String params,
    required DateTime createdAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rejected = const Value.absent(),
  }) : id = Value(id),
       shopId = Value(shopId),
       fn = Value(fn),
       params = Value(params),
       createdAt = Value(createdAt);
  static Insertable<OutboxEntry> custom({
    Expression<int>? seq,
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<String>? fn,
    Expression<String>? params,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<bool>? rejected,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (fn != null) 'fn': fn,
      if (params != null) 'params': params,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (rejected != null) 'rejected': rejected,
    });
  }

  OutboxEntriesCompanion copyWith({
    Value<int>? seq,
    Value<String>? id,
    Value<String>? shopId,
    Value<String>? fn,
    Value<String>? params,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<bool>? rejected,
  }) {
    return OutboxEntriesCompanion(
      seq: seq ?? this.seq,
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      fn: fn ?? this.fn,
      params: params ?? this.params,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      rejected: rejected ?? this.rejected,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (fn.present) {
      map['fn'] = Variable<String>(fn.value);
    }
    if (params.present) {
      map['params'] = Variable<String>(params.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rejected.present) {
      map['rejected'] = Variable<bool>(rejected.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntriesCompanion(')
          ..write('seq: $seq, ')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('fn: $fn, ')
          ..write('params: $params, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('rejected: $rejected')
          ..write(')'))
        .toString();
  }
}

class $ShopSnapshotsTable extends ShopSnapshots
    with TableInfo<$ShopSnapshotsTable, ShopSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShopSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
    'shop_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [shopId, json, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shop_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShopSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('shop_id')) {
      context.handle(
        _shopIdMeta,
        shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {shopId};
  @override
  ShopSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShopSnapshot(
      shopId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shop_id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $ShopSnapshotsTable createAlias(String alias) {
    return $ShopSnapshotsTable(attachedDatabase, alias);
  }
}

class ShopSnapshot extends DataClass implements Insertable<ShopSnapshot> {
  final String shopId;
  final String json;
  final DateTime savedAt;
  const ShopSnapshot({
    required this.shopId,
    required this.json,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['shop_id'] = Variable<String>(shopId);
    map['json'] = Variable<String>(json);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  ShopSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ShopSnapshotsCompanion(
      shopId: Value(shopId),
      json: Value(json),
      savedAt: Value(savedAt),
    );
  }

  factory ShopSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShopSnapshot(
      shopId: serializer.fromJson<String>(json['shopId']),
      json: serializer.fromJson<String>(json['json']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'shopId': serializer.toJson<String>(shopId),
      'json': serializer.toJson<String>(json),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  ShopSnapshot copyWith({String? shopId, String? json, DateTime? savedAt}) =>
      ShopSnapshot(
        shopId: shopId ?? this.shopId,
        json: json ?? this.json,
        savedAt: savedAt ?? this.savedAt,
      );
  ShopSnapshot copyWithCompanion(ShopSnapshotsCompanion data) {
    return ShopSnapshot(
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      json: data.json.present ? data.json.value : this.json,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShopSnapshot(')
          ..write('shopId: $shopId, ')
          ..write('json: $json, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(shopId, json, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShopSnapshot &&
          other.shopId == this.shopId &&
          other.json == this.json &&
          other.savedAt == this.savedAt);
}

class ShopSnapshotsCompanion extends UpdateCompanion<ShopSnapshot> {
  final Value<String> shopId;
  final Value<String> json;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const ShopSnapshotsCompanion({
    this.shopId = const Value.absent(),
    this.json = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShopSnapshotsCompanion.insert({
    required String shopId,
    required String json,
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : shopId = Value(shopId),
       json = Value(json),
       savedAt = Value(savedAt);
  static Insertable<ShopSnapshot> custom({
    Expression<String>? shopId,
    Expression<String>? json,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (shopId != null) 'shop_id': shopId,
      if (json != null) 'json': json,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShopSnapshotsCompanion copyWith({
    Value<String>? shopId,
    Value<String>? json,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return ShopSnapshotsCompanion(
      shopId: shopId ?? this.shopId,
      json: json ?? this.json,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShopSnapshotsCompanion(')
          ..write('shopId: $shopId, ')
          ..write('json: $json, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDb extends GeneratedDatabase {
  _$LocalDb(QueryExecutor e) : super(e);
  $LocalDbManager get managers => $LocalDbManager(this);
  late final $OutboxEntriesTable outboxEntries = $OutboxEntriesTable(this);
  late final $ShopSnapshotsTable shopSnapshots = $ShopSnapshotsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    outboxEntries,
    shopSnapshots,
  ];
}

typedef $$OutboxEntriesTableCreateCompanionBuilder =
    OutboxEntriesCompanion Function({
      Value<int> seq,
      required String id,
      required String shopId,
      required String fn,
      required String params,
      required DateTime createdAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<bool> rejected,
    });
typedef $$OutboxEntriesTableUpdateCompanionBuilder =
    OutboxEntriesCompanion Function({
      Value<int> seq,
      Value<String> id,
      Value<String> shopId,
      Value<String> fn,
      Value<String> params,
      Value<DateTime> createdAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<bool> rejected,
    });

class $$OutboxEntriesTableFilterComposer
    extends Composer<_$LocalDb, $OutboxEntriesTable> {
  $$OutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fn => $composableBuilder(
    column: $table.fn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get params => $composableBuilder(
    column: $table.params,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get rejected => $composableBuilder(
    column: $table.rejected,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxEntriesTableOrderingComposer
    extends Composer<_$LocalDb, $OutboxEntriesTable> {
  $$OutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fn => $composableBuilder(
    column: $table.fn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get params => $composableBuilder(
    column: $table.params,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get rejected => $composableBuilder(
    column: $table.rejected,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxEntriesTableAnnotationComposer
    extends Composer<_$LocalDb, $OutboxEntriesTable> {
  $$OutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get fn =>
      $composableBuilder(column: $table.fn, builder: (column) => column);

  GeneratedColumn<String> get params =>
      $composableBuilder(column: $table.params, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<bool> get rejected =>
      $composableBuilder(column: $table.rejected, builder: (column) => column);
}

class $$OutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $OutboxEntriesTable,
          OutboxEntry,
          $$OutboxEntriesTableFilterComposer,
          $$OutboxEntriesTableOrderingComposer,
          $$OutboxEntriesTableAnnotationComposer,
          $$OutboxEntriesTableCreateCompanionBuilder,
          $$OutboxEntriesTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<_$LocalDb, $OutboxEntriesTable, OutboxEntry>,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$OutboxEntriesTableTableManager(_$LocalDb db, $OutboxEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> shopId = const Value.absent(),
                Value<String> fn = const Value.absent(),
                Value<String> params = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> rejected = const Value.absent(),
              }) => OutboxEntriesCompanion(
                seq: seq,
                id: id,
                shopId: shopId,
                fn: fn,
                params: params,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                rejected: rejected,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String id,
                required String shopId,
                required String fn,
                required String params,
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> rejected = const Value.absent(),
              }) => OutboxEntriesCompanion.insert(
                seq: seq,
                id: id,
                shopId: shopId,
                fn: fn,
                params: params,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                rejected: rejected,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxEntriesTable, OutboxEntry>(table),
                  BaseReferences<_$LocalDb, $OutboxEntriesTable, OutboxEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $OutboxEntriesTable,
      OutboxEntry,
      $$OutboxEntriesTableFilterComposer,
      $$OutboxEntriesTableOrderingComposer,
      $$OutboxEntriesTableAnnotationComposer,
      $$OutboxEntriesTableCreateCompanionBuilder,
      $$OutboxEntriesTableUpdateCompanionBuilder,
      (
        OutboxEntry,
        BaseReferences<_$LocalDb, $OutboxEntriesTable, OutboxEntry>,
      ),
      OutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$ShopSnapshotsTableCreateCompanionBuilder =
    ShopSnapshotsCompanion Function({
      required String shopId,
      required String json,
      required DateTime savedAt,
      Value<int> rowid,
    });
typedef $$ShopSnapshotsTableUpdateCompanionBuilder =
    ShopSnapshotsCompanion Function({
      Value<String> shopId,
      Value<String> json,
      Value<DateTime> savedAt,
      Value<int> rowid,
    });

class $$ShopSnapshotsTableFilterComposer
    extends Composer<_$LocalDb, $ShopSnapshotsTable> {
  $$ShopSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShopSnapshotsTableOrderingComposer
    extends Composer<_$LocalDb, $ShopSnapshotsTable> {
  $$ShopSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShopSnapshotsTableAnnotationComposer
    extends Composer<_$LocalDb, $ShopSnapshotsTable> {
  $$ShopSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$ShopSnapshotsTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $ShopSnapshotsTable,
          ShopSnapshot,
          $$ShopSnapshotsTableFilterComposer,
          $$ShopSnapshotsTableOrderingComposer,
          $$ShopSnapshotsTableAnnotationComposer,
          $$ShopSnapshotsTableCreateCompanionBuilder,
          $$ShopSnapshotsTableUpdateCompanionBuilder,
          (
            ShopSnapshot,
            BaseReferences<_$LocalDb, $ShopSnapshotsTable, ShopSnapshot>,
          ),
          ShopSnapshot,
          PrefetchHooks Function()
        > {
  $$ShopSnapshotsTableTableManager(_$LocalDb db, $ShopSnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShopSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShopSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShopSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> shopId = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShopSnapshotsCompanion(
                shopId: shopId,
                json: json,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String shopId,
                required String json,
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => ShopSnapshotsCompanion.insert(
                shopId: shopId,
                json: json,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShopSnapshotsTable, ShopSnapshot>(table),
                  BaseReferences<_$LocalDb, $ShopSnapshotsTable, ShopSnapshot>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShopSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $ShopSnapshotsTable,
      ShopSnapshot,
      $$ShopSnapshotsTableFilterComposer,
      $$ShopSnapshotsTableOrderingComposer,
      $$ShopSnapshotsTableAnnotationComposer,
      $$ShopSnapshotsTableCreateCompanionBuilder,
      $$ShopSnapshotsTableUpdateCompanionBuilder,
      (
        ShopSnapshot,
        BaseReferences<_$LocalDb, $ShopSnapshotsTable, ShopSnapshot>,
      ),
      ShopSnapshot,
      PrefetchHooks Function()
    >;

class $LocalDbManager {
  final _$LocalDb _db;
  $LocalDbManager(this._db);
  $$OutboxEntriesTableTableManager get outboxEntries =>
      $$OutboxEntriesTableTableManager(_db, _db.outboxEntries);
  $$ShopSnapshotsTableTableManager get shopSnapshots =>
      $$ShopSnapshotsTableTableManager(_db, _db.shopSnapshots);
}
