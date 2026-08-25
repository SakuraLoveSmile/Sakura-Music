// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ServersTable extends Servers with TableInfo<$ServersTable, Server> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passwordMeta = const VerificationMeta(
    'password',
  );
  @override
  late final GeneratedColumn<String> password = GeneratedColumn<String>(
    'password',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
    'token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    baseUrl,
    username,
    password,
    token,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Server> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('password')) {
      context.handle(
        _passwordMeta,
        password.isAcceptableOrUnknown(data['password']!, _passwordMeta),
      );
    } else if (isInserting) {
      context.missing(_passwordMeta);
    }
    if (data.containsKey('token')) {
      context.handle(
        _tokenMeta,
        token.isAcceptableOrUnknown(data['token']!, _tokenMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Server map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Server(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      password: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password'],
      )!,
      token: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ServersTable createAlias(String alias) {
    return $ServersTable(attachedDatabase, alias);
  }
}

class Server extends DataClass implements Insertable<Server> {
  final int id;
  final String name;
  final String baseUrl;
  final String username;
  final String password;
  final String? token;
  final DateTime createdAt;
  const Server({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.password,
    this.token,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    map['username'] = Variable<String>(username);
    map['password'] = Variable<String>(password);
    if (!nullToAbsent || token != null) {
      map['token'] = Variable<String>(token);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ServersCompanion toCompanion(bool nullToAbsent) {
    return ServersCompanion(
      id: Value(id),
      name: Value(name),
      baseUrl: Value(baseUrl),
      username: Value(username),
      password: Value(password),
      token: token == null && nullToAbsent
          ? const Value.absent()
          : Value(token),
      createdAt: Value(createdAt),
    );
  }

  factory Server.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Server(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      username: serializer.fromJson<String>(json['username']),
      password: serializer.fromJson<String>(json['password']),
      token: serializer.fromJson<String?>(json['token']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'username': serializer.toJson<String>(username),
      'password': serializer.toJson<String>(password),
      'token': serializer.toJson<String?>(token),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Server copyWith({
    int? id,
    String? name,
    String? baseUrl,
    String? username,
    String? password,
    Value<String?> token = const Value.absent(),
    DateTime? createdAt,
  }) => Server(
    id: id ?? this.id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    username: username ?? this.username,
    password: password ?? this.password,
    token: token.present ? token.value : this.token,
    createdAt: createdAt ?? this.createdAt,
  );
  Server copyWithCompanion(ServersCompanion data) {
    return Server(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      username: data.username.present ? data.username.value : this.username,
      password: data.password.present ? data.password.value : this.password,
      token: data.token.present ? data.token.value : this.token,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Server(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('username: $username, ')
          ..write('password: $password, ')
          ..write('token: $token, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, baseUrl, username, password, token, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Server &&
          other.id == this.id &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.username == this.username &&
          other.password == this.password &&
          other.token == this.token &&
          other.createdAt == this.createdAt);
}

class ServersCompanion extends UpdateCompanion<Server> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<String> username;
  final Value<String> password;
  final Value<String?> token;
  final Value<DateTime> createdAt;
  const ServersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.username = const Value.absent(),
    this.password = const Value.absent(),
    this.token = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ServersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String baseUrl,
    required String username,
    required String password,
    this.token = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       baseUrl = Value(baseUrl),
       username = Value(username),
       password = Value(password);
  static Insertable<Server> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? username,
    Expression<String>? password,
    Expression<String>? token,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (token != null) 'token': token,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ServersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? baseUrl,
    Value<String>? username,
    Value<String>? password,
    Value<String?>? token,
    Value<DateTime>? createdAt,
  }) {
    return ServersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (password.present) {
      map['password'] = Variable<String>(password.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('username: $username, ')
          ..write('password: $password, ')
          ..write('token: $token, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RecentPlaysTable extends RecentPlays
    with TableInfo<$RecentPlaysTable, RecentPlay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentPlaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    songId,
    serverId,
    title,
    artist,
    playedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_plays';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentPlay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecentPlay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentPlay(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}played_at'],
      )!,
    );
  }

  @override
  $RecentPlaysTable createAlias(String alias) {
    return $RecentPlaysTable(attachedDatabase, alias);
  }
}

class RecentPlay extends DataClass implements Insertable<RecentPlay> {
  final int id;
  final String songId;
  final int serverId;
  final String? title;
  final String? artist;
  final DateTime playedAt;
  const RecentPlay({
    required this.id,
    required this.songId,
    required this.serverId,
    this.title,
    this.artist,
    required this.playedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['song_id'] = Variable<String>(songId);
    map['server_id'] = Variable<int>(serverId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    map['played_at'] = Variable<DateTime>(playedAt);
    return map;
  }

  RecentPlaysCompanion toCompanion(bool nullToAbsent) {
    return RecentPlaysCompanion(
      id: Value(id),
      songId: Value(songId),
      serverId: Value(serverId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      playedAt: Value(playedAt),
    );
  }

  factory RecentPlay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentPlay(
      id: serializer.fromJson<int>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      serverId: serializer.fromJson<int>(json['serverId']),
      title: serializer.fromJson<String?>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'songId': serializer.toJson<String>(songId),
      'serverId': serializer.toJson<int>(serverId),
      'title': serializer.toJson<String?>(title),
      'artist': serializer.toJson<String?>(artist),
      'playedAt': serializer.toJson<DateTime>(playedAt),
    };
  }

  RecentPlay copyWith({
    int? id,
    String? songId,
    int? serverId,
    Value<String?> title = const Value.absent(),
    Value<String?> artist = const Value.absent(),
    DateTime? playedAt,
  }) => RecentPlay(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    serverId: serverId ?? this.serverId,
    title: title.present ? title.value : this.title,
    artist: artist.present ? artist.value : this.artist,
    playedAt: playedAt ?? this.playedAt,
  );
  RecentPlay copyWithCompanion(RecentPlaysCompanion data) {
    return RecentPlay(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentPlay(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, songId, serverId, title, artist, playedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentPlay &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.serverId == this.serverId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.playedAt == this.playedAt);
}

class RecentPlaysCompanion extends UpdateCompanion<RecentPlay> {
  final Value<int> id;
  final Value<String> songId;
  final Value<int> serverId;
  final Value<String?> title;
  final Value<String?> artist;
  final Value<DateTime> playedAt;
  const RecentPlaysCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.playedAt = const Value.absent(),
  });
  RecentPlaysCompanion.insert({
    this.id = const Value.absent(),
    required String songId,
    required int serverId,
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.playedAt = const Value.absent(),
  }) : songId = Value(songId),
       serverId = Value(serverId);
  static Insertable<RecentPlay> custom({
    Expression<int>? id,
    Expression<String>? songId,
    Expression<int>? serverId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<DateTime>? playedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (serverId != null) 'server_id': serverId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (playedAt != null) 'played_at': playedAt,
    });
  }

  RecentPlaysCompanion copyWith({
    Value<int>? id,
    Value<String>? songId,
    Value<int>? serverId,
    Value<String?>? title,
    Value<String?>? artist,
    Value<DateTime>? playedAt,
  }) {
    return RecentPlaysCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      playedAt: playedAt ?? this.playedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentPlaysCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaybackStatesTable extends PlaybackStates
    with TableInfo<$PlaybackStatesTable, PlaybackState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _queueJsonMeta = const VerificationMeta(
    'queueJson',
  );
  @override
  late final GeneratedColumn<String> queueJson = GeneratedColumn<String>(
    'queue_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentIndexMeta = const VerificationMeta(
    'currentIndex',
  );
  @override
  late final GeneratedColumn<int> currentIndex = GeneratedColumn<int>(
    'current_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loopModeMeta = const VerificationMeta(
    'loopMode',
  );
  @override
  late final GeneratedColumn<String> loopMode = GeneratedColumn<String>(
    'loop_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('off'),
  );
  static const VerificationMeta _shuffleMeta = const VerificationMeta(
    'shuffle',
  );
  @override
  late final GeneratedColumn<bool> shuffle = GeneratedColumn<bool>(
    'shuffle',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("shuffle" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<double> volume = GeneratedColumn<double>(
    'volume',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    queueJson,
    currentIndex,
    positionMs,
    loopMode,
    shuffle,
    volume,
    speed,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('queue_json')) {
      context.handle(
        _queueJsonMeta,
        queueJson.isAcceptableOrUnknown(data['queue_json']!, _queueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_queueJsonMeta);
    }
    if (data.containsKey('current_index')) {
      context.handle(
        _currentIndexMeta,
        currentIndex.isAcceptableOrUnknown(
          data['current_index']!,
          _currentIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentIndexMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('loop_mode')) {
      context.handle(
        _loopModeMeta,
        loopMode.isAcceptableOrUnknown(data['loop_mode']!, _loopModeMeta),
      );
    }
    if (data.containsKey('shuffle')) {
      context.handle(
        _shuffleMeta,
        shuffle.isAcceptableOrUnknown(data['shuffle']!, _shuffleMeta),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackState(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      queueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}queue_json'],
      )!,
      currentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_index'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      loopMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loop_mode'],
      )!,
      shuffle: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}shuffle'],
      )!,
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}volume'],
      )!,
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaybackStatesTable createAlias(String alias) {
    return $PlaybackStatesTable(attachedDatabase, alias);
  }
}

class PlaybackState extends DataClass implements Insertable<PlaybackState> {
  final int id;
  final int? serverId;
  final String queueJson;
  final int currentIndex;
  final int positionMs;
  final String loopMode;
  final bool shuffle;
  final double volume;
  final double speed;
  final DateTime updatedAt;
  const PlaybackState({
    required this.id,
    this.serverId,
    required this.queueJson,
    required this.currentIndex,
    required this.positionMs,
    required this.loopMode,
    required this.shuffle,
    required this.volume,
    required this.speed,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['queue_json'] = Variable<String>(queueJson);
    map['current_index'] = Variable<int>(currentIndex);
    map['position_ms'] = Variable<int>(positionMs);
    map['loop_mode'] = Variable<String>(loopMode);
    map['shuffle'] = Variable<bool>(shuffle);
    map['volume'] = Variable<double>(volume);
    map['speed'] = Variable<double>(speed);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaybackStatesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackStatesCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      queueJson: Value(queueJson),
      currentIndex: Value(currentIndex),
      positionMs: Value(positionMs),
      loopMode: Value(loopMode),
      shuffle: Value(shuffle),
      volume: Value(volume),
      speed: Value(speed),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackState(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      queueJson: serializer.fromJson<String>(json['queueJson']),
      currentIndex: serializer.fromJson<int>(json['currentIndex']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      loopMode: serializer.fromJson<String>(json['loopMode']),
      shuffle: serializer.fromJson<bool>(json['shuffle']),
      volume: serializer.fromJson<double>(json['volume']),
      speed: serializer.fromJson<double>(json['speed']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'queueJson': serializer.toJson<String>(queueJson),
      'currentIndex': serializer.toJson<int>(currentIndex),
      'positionMs': serializer.toJson<int>(positionMs),
      'loopMode': serializer.toJson<String>(loopMode),
      'shuffle': serializer.toJson<bool>(shuffle),
      'volume': serializer.toJson<double>(volume),
      'speed': serializer.toJson<double>(speed),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaybackState copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    String? queueJson,
    int? currentIndex,
    int? positionMs,
    String? loopMode,
    bool? shuffle,
    double? volume,
    double? speed,
    DateTime? updatedAt,
  }) => PlaybackState(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    queueJson: queueJson ?? this.queueJson,
    currentIndex: currentIndex ?? this.currentIndex,
    positionMs: positionMs ?? this.positionMs,
    loopMode: loopMode ?? this.loopMode,
    shuffle: shuffle ?? this.shuffle,
    volume: volume ?? this.volume,
    speed: speed ?? this.speed,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaybackState copyWithCompanion(PlaybackStatesCompanion data) {
    return PlaybackState(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      queueJson: data.queueJson.present ? data.queueJson.value : this.queueJson,
      currentIndex: data.currentIndex.present
          ? data.currentIndex.value
          : this.currentIndex,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      loopMode: data.loopMode.present ? data.loopMode.value : this.loopMode,
      shuffle: data.shuffle.present ? data.shuffle.value : this.shuffle,
      volume: data.volume.present ? data.volume.value : this.volume,
      speed: data.speed.present ? data.speed.value : this.speed,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackState(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('queueJson: $queueJson, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('positionMs: $positionMs, ')
          ..write('loopMode: $loopMode, ')
          ..write('shuffle: $shuffle, ')
          ..write('volume: $volume, ')
          ..write('speed: $speed, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    queueJson,
    currentIndex,
    positionMs,
    loopMode,
    shuffle,
    volume,
    speed,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackState &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.queueJson == this.queueJson &&
          other.currentIndex == this.currentIndex &&
          other.positionMs == this.positionMs &&
          other.loopMode == this.loopMode &&
          other.shuffle == this.shuffle &&
          other.volume == this.volume &&
          other.speed == this.speed &&
          other.updatedAt == this.updatedAt);
}

class PlaybackStatesCompanion extends UpdateCompanion<PlaybackState> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<String> queueJson;
  final Value<int> currentIndex;
  final Value<int> positionMs;
  final Value<String> loopMode;
  final Value<bool> shuffle;
  final Value<double> volume;
  final Value<double> speed;
  final Value<DateTime> updatedAt;
  const PlaybackStatesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.queueJson = const Value.absent(),
    this.currentIndex = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.loopMode = const Value.absent(),
    this.shuffle = const Value.absent(),
    this.volume = const Value.absent(),
    this.speed = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaybackStatesCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required String queueJson,
    required int currentIndex,
    required int positionMs,
    this.loopMode = const Value.absent(),
    this.shuffle = const Value.absent(),
    this.volume = const Value.absent(),
    this.speed = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : queueJson = Value(queueJson),
       currentIndex = Value(currentIndex),
       positionMs = Value(positionMs);
  static Insertable<PlaybackState> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<String>? queueJson,
    Expression<int>? currentIndex,
    Expression<int>? positionMs,
    Expression<String>? loopMode,
    Expression<bool>? shuffle,
    Expression<double>? volume,
    Expression<double>? speed,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (queueJson != null) 'queue_json': queueJson,
      if (currentIndex != null) 'current_index': currentIndex,
      if (positionMs != null) 'position_ms': positionMs,
      if (loopMode != null) 'loop_mode': loopMode,
      if (shuffle != null) 'shuffle': shuffle,
      if (volume != null) 'volume': volume,
      if (speed != null) 'speed': speed,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaybackStatesCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<String>? queueJson,
    Value<int>? currentIndex,
    Value<int>? positionMs,
    Value<String>? loopMode,
    Value<bool>? shuffle,
    Value<double>? volume,
    Value<double>? speed,
    Value<DateTime>? updatedAt,
  }) {
    return PlaybackStatesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      queueJson: queueJson ?? this.queueJson,
      currentIndex: currentIndex ?? this.currentIndex,
      positionMs: positionMs ?? this.positionMs,
      loopMode: loopMode ?? this.loopMode,
      shuffle: shuffle ?? this.shuffle,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (queueJson.present) {
      map['queue_json'] = Variable<String>(queueJson.value);
    }
    if (currentIndex.present) {
      map['current_index'] = Variable<int>(currentIndex.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (loopMode.present) {
      map['loop_mode'] = Variable<String>(loopMode.value);
    }
    if (shuffle.present) {
      map['shuffle'] = Variable<bool>(shuffle.value);
    }
    if (volume.present) {
      map['volume'] = Variable<double>(volume.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackStatesCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('queueJson: $queueJson, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('positionMs: $positionMs, ')
          ..write('loopMode: $loopMode, ')
          ..write('shuffle: $shuffle, ')
          ..write('volume: $volume, ')
          ..write('speed: $speed, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryTable extends SearchHistory
    with TableInfo<$SearchHistoryTable, SearchHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _keywordMeta = const VerificationMeta(
    'keyword',
  );
  @override
  late final GeneratedColumn<String> keyword = GeneratedColumn<String>(
    'keyword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchedAtMeta = const VerificationMeta(
    'searchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> searchedAt = GeneratedColumn<DateTime>(
    'searched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, keyword, searchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('keyword')) {
      context.handle(
        _keywordMeta,
        keyword.isAcceptableOrUnknown(data['keyword']!, _keywordMeta),
      );
    } else if (isInserting) {
      context.missing(_keywordMeta);
    }
    if (data.containsKey('searched_at')) {
      context.handle(
        _searchedAtMeta,
        searchedAt.isAcceptableOrUnknown(data['searched_at']!, _searchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      keyword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keyword'],
      )!,
      searchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}searched_at'],
      )!,
    );
  }

  @override
  $SearchHistoryTable createAlias(String alias) {
    return $SearchHistoryTable(attachedDatabase, alias);
  }
}

class SearchHistoryData extends DataClass
    implements Insertable<SearchHistoryData> {
  final int id;
  final String keyword;
  final DateTime searchedAt;
  const SearchHistoryData({
    required this.id,
    required this.keyword,
    required this.searchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['keyword'] = Variable<String>(keyword);
    map['searched_at'] = Variable<DateTime>(searchedAt);
    return map;
  }

  SearchHistoryCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryCompanion(
      id: Value(id),
      keyword: Value(keyword),
      searchedAt: Value(searchedAt),
    );
  }

  factory SearchHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryData(
      id: serializer.fromJson<int>(json['id']),
      keyword: serializer.fromJson<String>(json['keyword']),
      searchedAt: serializer.fromJson<DateTime>(json['searchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'keyword': serializer.toJson<String>(keyword),
      'searchedAt': serializer.toJson<DateTime>(searchedAt),
    };
  }

  SearchHistoryData copyWith({
    int? id,
    String? keyword,
    DateTime? searchedAt,
  }) => SearchHistoryData(
    id: id ?? this.id,
    keyword: keyword ?? this.keyword,
    searchedAt: searchedAt ?? this.searchedAt,
  );
  SearchHistoryData copyWithCompanion(SearchHistoryCompanion data) {
    return SearchHistoryData(
      id: data.id.present ? data.id.value : this.id,
      keyword: data.keyword.present ? data.keyword.value : this.keyword,
      searchedAt: data.searchedAt.present
          ? data.searchedAt.value
          : this.searchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryData(')
          ..write('id: $id, ')
          ..write('keyword: $keyword, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, keyword, searchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryData &&
          other.id == this.id &&
          other.keyword == this.keyword &&
          other.searchedAt == this.searchedAt);
}

class SearchHistoryCompanion extends UpdateCompanion<SearchHistoryData> {
  final Value<int> id;
  final Value<String> keyword;
  final Value<DateTime> searchedAt;
  const SearchHistoryCompanion({
    this.id = const Value.absent(),
    this.keyword = const Value.absent(),
    this.searchedAt = const Value.absent(),
  });
  SearchHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String keyword,
    this.searchedAt = const Value.absent(),
  }) : keyword = Value(keyword);
  static Insertable<SearchHistoryData> custom({
    Expression<int>? id,
    Expression<String>? keyword,
    Expression<DateTime>? searchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (keyword != null) 'keyword': keyword,
      if (searchedAt != null) 'searched_at': searchedAt,
    });
  }

  SearchHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? keyword,
    Value<DateTime>? searchedAt,
  }) {
    return SearchHistoryCompanion(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      searchedAt: searchedAt ?? this.searchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (keyword.present) {
      map['keyword'] = Variable<String>(keyword.value);
    }
    if (searchedAt.present) {
      map['searched_at'] = Variable<DateTime>(searchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryCompanion(')
          ..write('id: $id, ')
          ..write('keyword: $keyword, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _seedColorValueMeta = const VerificationMeta(
    'seedColorValue',
  );
  @override
  late final GeneratedColumn<int> seedColorValue = GeneratedColumn<int>(
    'seed_color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xfff48fb1),
  );
  static const VerificationMeta _equalizerEnabledMeta = const VerificationMeta(
    'equalizerEnabled',
  );
  @override
  late final GeneratedColumn<bool> equalizerEnabled = GeneratedColumn<bool>(
    'equalizer_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("equalizer_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _equalizerGainsJsonMeta =
      const VerificationMeta('equalizerGainsJson');
  @override
  late final GeneratedColumn<String> equalizerGainsJson =
      GeneratedColumn<String>(
        'equalizer_gains_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[0,0,0,0,0]'),
      );
  static const VerificationMeta _equalizerPresetMeta = const VerificationMeta(
    'equalizerPreset',
  );
  @override
  late final GeneratedColumn<String> equalizerPreset = GeneratedColumn<String>(
    'equalizer_preset',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('flat'),
  );
  static const VerificationMeta _listenBrainzTokenMeta = const VerificationMeta(
    'listenBrainzToken',
  );
  @override
  late final GeneratedColumn<String> listenBrainzToken =
      GeneratedColumn<String>(
        'listen_brainz_token',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _listenBrainzEnabledMeta =
      const VerificationMeta('listenBrainzEnabled');
  @override
  late final GeneratedColumn<bool> listenBrainzEnabled = GeneratedColumn<bool>(
    'listen_brainz_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("listen_brainz_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lyricsOverlayEnabledMeta =
      const VerificationMeta('lyricsOverlayEnabled');
  @override
  late final GeneratedColumn<bool> lyricsOverlayEnabled = GeneratedColumn<bool>(
    'lyrics_overlay_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("lyrics_overlay_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _statusBarLyricsEnabledMeta =
      const VerificationMeta('statusBarLyricsEnabled');
  @override
  late final GeneratedColumn<bool> statusBarLyricsEnabled = GeneratedColumn<bool>(
    'status_bar_lyrics_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("status_bar_lyrics_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _safeAudioModeMeta = const VerificationMeta(
    'safeAudioMode',
  );
  @override
  late final GeneratedColumn<bool> safeAudioMode = GeneratedColumn<bool>(
    'safe_audio_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("safe_audio_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _localeCodeMeta = const VerificationMeta(
    'localeCode',
  );
  @override
  late final GeneratedColumn<String> localeCode = GeneratedColumn<String>(
    'locale_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('zh'),
  );
  static const VerificationMeta _membershipActiveMeta = const VerificationMeta(
    'membershipActive',
  );
  @override
  late final GeneratedColumn<bool> membershipActive = GeneratedColumn<bool>(
    'membership_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("membership_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _membershipMethodMeta = const VerificationMeta(
    'membershipMethod',
  );
  @override
  late final GeneratedColumn<String> membershipMethod = GeneratedColumn<String>(
    'membership_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    themeMode,
    seedColorValue,
    equalizerEnabled,
    equalizerGainsJson,
    equalizerPreset,
    listenBrainzToken,
    listenBrainzEnabled,
    lyricsOverlayEnabled,
    statusBarLyricsEnabled,
    safeAudioMode,
    localeCode,
    membershipActive,
    membershipMethod,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('seed_color_value')) {
      context.handle(
        _seedColorValueMeta,
        seedColorValue.isAcceptableOrUnknown(
          data['seed_color_value']!,
          _seedColorValueMeta,
        ),
      );
    }
    if (data.containsKey('equalizer_enabled')) {
      context.handle(
        _equalizerEnabledMeta,
        equalizerEnabled.isAcceptableOrUnknown(
          data['equalizer_enabled']!,
          _equalizerEnabledMeta,
        ),
      );
    }
    if (data.containsKey('equalizer_gains_json')) {
      context.handle(
        _equalizerGainsJsonMeta,
        equalizerGainsJson.isAcceptableOrUnknown(
          data['equalizer_gains_json']!,
          _equalizerGainsJsonMeta,
        ),
      );
    }
    if (data.containsKey('equalizer_preset')) {
      context.handle(
        _equalizerPresetMeta,
        equalizerPreset.isAcceptableOrUnknown(
          data['equalizer_preset']!,
          _equalizerPresetMeta,
        ),
      );
    }
    if (data.containsKey('listen_brainz_token')) {
      context.handle(
        _listenBrainzTokenMeta,
        listenBrainzToken.isAcceptableOrUnknown(
          data['listen_brainz_token']!,
          _listenBrainzTokenMeta,
        ),
      );
    }
    if (data.containsKey('listen_brainz_enabled')) {
      context.handle(
        _listenBrainzEnabledMeta,
        listenBrainzEnabled.isAcceptableOrUnknown(
          data['listen_brainz_enabled']!,
          _listenBrainzEnabledMeta,
        ),
      );
    }
    if (data.containsKey('lyrics_overlay_enabled')) {
      context.handle(
        _lyricsOverlayEnabledMeta,
        lyricsOverlayEnabled.isAcceptableOrUnknown(
          data['lyrics_overlay_enabled']!,
          _lyricsOverlayEnabledMeta,
        ),
      );
    }
    if (data.containsKey('status_bar_lyrics_enabled')) {
      context.handle(
        _statusBarLyricsEnabledMeta,
        statusBarLyricsEnabled.isAcceptableOrUnknown(
          data['status_bar_lyrics_enabled']!,
          _statusBarLyricsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('safe_audio_mode')) {
      context.handle(
        _safeAudioModeMeta,
        safeAudioMode.isAcceptableOrUnknown(
          data['safe_audio_mode']!,
          _safeAudioModeMeta,
        ),
      );
    }
    if (data.containsKey('locale_code')) {
      context.handle(
        _localeCodeMeta,
        localeCode.isAcceptableOrUnknown(data['locale_code']!, _localeCodeMeta),
      );
    }
    if (data.containsKey('membership_active')) {
      context.handle(
        _membershipActiveMeta,
        membershipActive.isAcceptableOrUnknown(
          data['membership_active']!,
          _membershipActiveMeta,
        ),
      );
    }
    if (data.containsKey('membership_method')) {
      context.handle(
        _membershipMethodMeta,
        membershipMethod.isAcceptableOrUnknown(
          data['membership_method']!,
          _membershipMethodMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      seedColorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed_color_value'],
      )!,
      equalizerEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}equalizer_enabled'],
      )!,
      equalizerGainsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equalizer_gains_json'],
      )!,
      equalizerPreset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equalizer_preset'],
      )!,
      listenBrainzToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}listen_brainz_token'],
      ),
      listenBrainzEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}listen_brainz_enabled'],
      )!,
      lyricsOverlayEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}lyrics_overlay_enabled'],
      )!,
      statusBarLyricsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}status_bar_lyrics_enabled'],
      )!,
      safeAudioMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}safe_audio_mode'],
      )!,
      localeCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale_code'],
      )!,
      membershipActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}membership_active'],
      )!,
      membershipMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}membership_method'],
      ),
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final int id;
  final String themeMode;
  final int seedColorValue;
  final bool equalizerEnabled;
  final String equalizerGainsJson;
  final String equalizerPreset;
  final String? listenBrainzToken;
  final bool listenBrainzEnabled;
  final bool lyricsOverlayEnabled;

  /// When enabled, the currently playing song and its timed lyrics are pushed
  /// to the Lyricon status-bar lyrics center service. Degrades silently when
  /// Lyricon is not installed on the device.
  final bool statusBarLyricsEnabled;

  /// When enabled, the Android equalizer `AudioPipeline` is not attached to the
  /// audio player. Used as a diagnostic toggle to rule out the equalizer as the
  /// cause of silent playback on some devices.
  final bool safeAudioMode;

  /// `zh`, `en`, or `system`. Defaults to simplified Chinese.
  final String localeCode;
  final bool membershipActive;
  final String? membershipMethod;
  const Setting({
    required this.id,
    required this.themeMode,
    required this.seedColorValue,
    required this.equalizerEnabled,
    required this.equalizerGainsJson,
    required this.equalizerPreset,
    this.listenBrainzToken,
    required this.listenBrainzEnabled,
    required this.lyricsOverlayEnabled,
    required this.statusBarLyricsEnabled,
    required this.safeAudioMode,
    required this.localeCode,
    required this.membershipActive,
    this.membershipMethod,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['theme_mode'] = Variable<String>(themeMode);
    map['seed_color_value'] = Variable<int>(seedColorValue);
    map['equalizer_enabled'] = Variable<bool>(equalizerEnabled);
    map['equalizer_gains_json'] = Variable<String>(equalizerGainsJson);
    map['equalizer_preset'] = Variable<String>(equalizerPreset);
    if (!nullToAbsent || listenBrainzToken != null) {
      map['listen_brainz_token'] = Variable<String>(listenBrainzToken);
    }
    map['listen_brainz_enabled'] = Variable<bool>(listenBrainzEnabled);
    map['lyrics_overlay_enabled'] = Variable<bool>(lyricsOverlayEnabled);
    map['status_bar_lyrics_enabled'] = Variable<bool>(statusBarLyricsEnabled);
    map['safe_audio_mode'] = Variable<bool>(safeAudioMode);
    map['locale_code'] = Variable<String>(localeCode);
    map['membership_active'] = Variable<bool>(membershipActive);
    if (!nullToAbsent || membershipMethod != null) {
      map['membership_method'] = Variable<String>(membershipMethod);
    }
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      themeMode: Value(themeMode),
      seedColorValue: Value(seedColorValue),
      equalizerEnabled: Value(equalizerEnabled),
      equalizerGainsJson: Value(equalizerGainsJson),
      equalizerPreset: Value(equalizerPreset),
      listenBrainzToken: listenBrainzToken == null && nullToAbsent
          ? const Value.absent()
          : Value(listenBrainzToken),
      listenBrainzEnabled: Value(listenBrainzEnabled),
      lyricsOverlayEnabled: Value(lyricsOverlayEnabled),
      statusBarLyricsEnabled: Value(statusBarLyricsEnabled),
      safeAudioMode: Value(safeAudioMode),
      localeCode: Value(localeCode),
      membershipActive: Value(membershipActive),
      membershipMethod: membershipMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(membershipMethod),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      id: serializer.fromJson<int>(json['id']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      seedColorValue: serializer.fromJson<int>(json['seedColorValue']),
      equalizerEnabled: serializer.fromJson<bool>(json['equalizerEnabled']),
      equalizerGainsJson: serializer.fromJson<String>(
        json['equalizerGainsJson'],
      ),
      equalizerPreset: serializer.fromJson<String>(json['equalizerPreset']),
      listenBrainzToken: serializer.fromJson<String?>(
        json['listenBrainzToken'],
      ),
      listenBrainzEnabled: serializer.fromJson<bool>(
        json['listenBrainzEnabled'],
      ),
      lyricsOverlayEnabled: serializer.fromJson<bool>(
        json['lyricsOverlayEnabled'],
      ),
      statusBarLyricsEnabled: serializer.fromJson<bool>(
        json['statusBarLyricsEnabled'],
      ),
      safeAudioMode: serializer.fromJson<bool>(json['safeAudioMode']),
      localeCode: serializer.fromJson<String>(json['localeCode']),
      membershipActive: serializer.fromJson<bool>(json['membershipActive']),
      membershipMethod: serializer.fromJson<String?>(json['membershipMethod']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'themeMode': serializer.toJson<String>(themeMode),
      'seedColorValue': serializer.toJson<int>(seedColorValue),
      'equalizerEnabled': serializer.toJson<bool>(equalizerEnabled),
      'equalizerGainsJson': serializer.toJson<String>(equalizerGainsJson),
      'equalizerPreset': serializer.toJson<String>(equalizerPreset),
      'listenBrainzToken': serializer.toJson<String?>(listenBrainzToken),
      'listenBrainzEnabled': serializer.toJson<bool>(listenBrainzEnabled),
      'lyricsOverlayEnabled': serializer.toJson<bool>(lyricsOverlayEnabled),
      'statusBarLyricsEnabled': serializer.toJson<bool>(statusBarLyricsEnabled),
      'safeAudioMode': serializer.toJson<bool>(safeAudioMode),
      'localeCode': serializer.toJson<String>(localeCode),
      'membershipActive': serializer.toJson<bool>(membershipActive),
      'membershipMethod': serializer.toJson<String?>(membershipMethod),
    };
  }

  Setting copyWith({
    int? id,
    String? themeMode,
    int? seedColorValue,
    bool? equalizerEnabled,
    String? equalizerGainsJson,
    String? equalizerPreset,
    Value<String?> listenBrainzToken = const Value.absent(),
    bool? listenBrainzEnabled,
    bool? lyricsOverlayEnabled,
    bool? statusBarLyricsEnabled,
    bool? safeAudioMode,
    String? localeCode,
    bool? membershipActive,
    Value<String?> membershipMethod = const Value.absent(),
  }) => Setting(
    id: id ?? this.id,
    themeMode: themeMode ?? this.themeMode,
    seedColorValue: seedColorValue ?? this.seedColorValue,
    equalizerEnabled: equalizerEnabled ?? this.equalizerEnabled,
    equalizerGainsJson: equalizerGainsJson ?? this.equalizerGainsJson,
    equalizerPreset: equalizerPreset ?? this.equalizerPreset,
    listenBrainzToken: listenBrainzToken.present
        ? listenBrainzToken.value
        : this.listenBrainzToken,
    listenBrainzEnabled: listenBrainzEnabled ?? this.listenBrainzEnabled,
    lyricsOverlayEnabled: lyricsOverlayEnabled ?? this.lyricsOverlayEnabled,
    statusBarLyricsEnabled: statusBarLyricsEnabled ?? this.statusBarLyricsEnabled,
    safeAudioMode: safeAudioMode ?? this.safeAudioMode,
    localeCode: localeCode ?? this.localeCode,
    membershipActive: membershipActive ?? this.membershipActive,
    membershipMethod: membershipMethod.present
        ? membershipMethod.value
        : this.membershipMethod,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      id: data.id.present ? data.id.value : this.id,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      seedColorValue: data.seedColorValue.present
          ? data.seedColorValue.value
          : this.seedColorValue,
      equalizerEnabled: data.equalizerEnabled.present
          ? data.equalizerEnabled.value
          : this.equalizerEnabled,
      equalizerGainsJson: data.equalizerGainsJson.present
          ? data.equalizerGainsJson.value
          : this.equalizerGainsJson,
      equalizerPreset: data.equalizerPreset.present
          ? data.equalizerPreset.value
          : this.equalizerPreset,
      listenBrainzToken: data.listenBrainzToken.present
          ? data.listenBrainzToken.value
          : this.listenBrainzToken,
      listenBrainzEnabled: data.listenBrainzEnabled.present
          ? data.listenBrainzEnabled.value
          : this.listenBrainzEnabled,
      lyricsOverlayEnabled: data.lyricsOverlayEnabled.present
          ? data.lyricsOverlayEnabled.value
          : this.lyricsOverlayEnabled,
      statusBarLyricsEnabled: data.statusBarLyricsEnabled.present
          ? data.statusBarLyricsEnabled.value
          : this.statusBarLyricsEnabled,
      safeAudioMode: data.safeAudioMode.present
          ? data.safeAudioMode.value
          : this.safeAudioMode,
      localeCode: data.localeCode.present
          ? data.localeCode.value
          : this.localeCode,
      membershipActive: data.membershipActive.present
          ? data.membershipActive.value
          : this.membershipActive,
      membershipMethod: data.membershipMethod.present
          ? data.membershipMethod.value
          : this.membershipMethod,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('seedColorValue: $seedColorValue, ')
          ..write('equalizerEnabled: $equalizerEnabled, ')
          ..write('equalizerGainsJson: $equalizerGainsJson, ')
          ..write('equalizerPreset: $equalizerPreset, ')
          ..write('listenBrainzToken: $listenBrainzToken, ')
          ..write('listenBrainzEnabled: $listenBrainzEnabled, ')
          ..write('lyricsOverlayEnabled: $lyricsOverlayEnabled, ')
           ..write('statusBarLyricsEnabled: $statusBarLyricsEnabled, ')
          ..write('safeAudioMode: $safeAudioMode, ')
          ..write('localeCode: $localeCode, ')
          ..write('membershipActive: $membershipActive, ')
          ..write('membershipMethod: $membershipMethod')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    themeMode,
    seedColorValue,
    equalizerEnabled,
    equalizerGainsJson,
    equalizerPreset,
    listenBrainzToken,
    listenBrainzEnabled,
    lyricsOverlayEnabled,
    statusBarLyricsEnabled,
    safeAudioMode,
    localeCode,
    membershipActive,
    membershipMethod,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.id == this.id &&
          other.themeMode == this.themeMode &&
          other.seedColorValue == this.seedColorValue &&
          other.equalizerEnabled == this.equalizerEnabled &&
          other.equalizerGainsJson == this.equalizerGainsJson &&
          other.equalizerPreset == this.equalizerPreset &&
          other.listenBrainzToken == this.listenBrainzToken &&
          other.listenBrainzEnabled == this.listenBrainzEnabled &&
          other.lyricsOverlayEnabled == this.lyricsOverlayEnabled &&
          other.statusBarLyricsEnabled == this.statusBarLyricsEnabled &&
          other.safeAudioMode == this.safeAudioMode &&
          other.localeCode == this.localeCode &&
          other.membershipActive == this.membershipActive &&
          other.membershipMethod == this.membershipMethod);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<int> id;
  final Value<String> themeMode;
  final Value<int> seedColorValue;
  final Value<bool> equalizerEnabled;
  final Value<String> equalizerGainsJson;
  final Value<String> equalizerPreset;
  final Value<String?> listenBrainzToken;
  final Value<bool> listenBrainzEnabled;
  final Value<bool> lyricsOverlayEnabled;
  final Value<bool> statusBarLyricsEnabled;
  final Value<bool> safeAudioMode;
  final Value<String> localeCode;
  final Value<bool> membershipActive;
  final Value<String?> membershipMethod;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.seedColorValue = const Value.absent(),
    this.equalizerEnabled = const Value.absent(),
    this.equalizerGainsJson = const Value.absent(),
    this.equalizerPreset = const Value.absent(),
    this.listenBrainzToken = const Value.absent(),
    this.listenBrainzEnabled = const Value.absent(),
    this.lyricsOverlayEnabled = const Value.absent(),
    this.statusBarLyricsEnabled = const Value.absent(),
    this.safeAudioMode = const Value.absent(),
    this.localeCode = const Value.absent(),
    this.membershipActive = const Value.absent(),
    this.membershipMethod = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.seedColorValue = const Value.absent(),
    this.equalizerEnabled = const Value.absent(),
    this.equalizerGainsJson = const Value.absent(),
    this.equalizerPreset = const Value.absent(),
    this.listenBrainzToken = const Value.absent(),
    this.listenBrainzEnabled = const Value.absent(),
    this.lyricsOverlayEnabled = const Value.absent(),
    this.statusBarLyricsEnabled = const Value.absent(),
    this.safeAudioMode = const Value.absent(),
    this.localeCode = const Value.absent(),
    this.membershipActive = const Value.absent(),
    this.membershipMethod = const Value.absent(),
  });
  static Insertable<Setting> custom({
    Expression<int>? id,
    Expression<String>? themeMode,
    Expression<int>? seedColorValue,
    Expression<bool>? equalizerEnabled,
    Expression<String>? equalizerGainsJson,
    Expression<String>? equalizerPreset,
    Expression<String>? listenBrainzToken,
    Expression<bool>? listenBrainzEnabled,
    Expression<bool>? lyricsOverlayEnabled,
    Expression<bool>? statusBarLyricsEnabled,
    Expression<bool>? safeAudioMode,
    Expression<String>? localeCode,
    Expression<bool>? membershipActive,
    Expression<String>? membershipMethod,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeMode != null) 'theme_mode': themeMode,
      if (seedColorValue != null) 'seed_color_value': seedColorValue,
      if (equalizerEnabled != null) 'equalizer_enabled': equalizerEnabled,
      if (equalizerGainsJson != null)
        'equalizer_gains_json': equalizerGainsJson,
      if (equalizerPreset != null) 'equalizer_preset': equalizerPreset,
      if (listenBrainzToken != null) 'listen_brainz_token': listenBrainzToken,
      if (listenBrainzEnabled != null)
        'listen_brainz_enabled': listenBrainzEnabled,
      if (lyricsOverlayEnabled != null)
        'lyrics_overlay_enabled': lyricsOverlayEnabled,
      if (statusBarLyricsEnabled != null)
        'status_bar_lyrics_enabled': statusBarLyricsEnabled,
      if (safeAudioMode != null) 'safe_audio_mode': safeAudioMode,
      if (localeCode != null) 'locale_code': localeCode,
      if (membershipActive != null) 'membership_active': membershipActive,
      if (membershipMethod != null) 'membership_method': membershipMethod,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? themeMode,
    Value<int>? seedColorValue,
    Value<bool>? equalizerEnabled,
    Value<String>? equalizerGainsJson,
    Value<String>? equalizerPreset,
    Value<String?>? listenBrainzToken,
    Value<bool>? listenBrainzEnabled,
    Value<bool>? lyricsOverlayEnabled,
    Value<bool>? statusBarLyricsEnabled,
    Value<bool>? safeAudioMode,
    Value<String>? localeCode,
    Value<bool>? membershipActive,
    Value<String?>? membershipMethod,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      themeMode: themeMode ?? this.themeMode,
      seedColorValue: seedColorValue ?? this.seedColorValue,
      equalizerEnabled: equalizerEnabled ?? this.equalizerEnabled,
      equalizerGainsJson: equalizerGainsJson ?? this.equalizerGainsJson,
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      listenBrainzToken: listenBrainzToken ?? this.listenBrainzToken,
      listenBrainzEnabled: listenBrainzEnabled ?? this.listenBrainzEnabled,
      lyricsOverlayEnabled: lyricsOverlayEnabled ?? this.lyricsOverlayEnabled,
      statusBarLyricsEnabled: statusBarLyricsEnabled ?? this.statusBarLyricsEnabled,
      safeAudioMode: safeAudioMode ?? this.safeAudioMode,
      localeCode: localeCode ?? this.localeCode,
      membershipActive: membershipActive ?? this.membershipActive,
      membershipMethod: membershipMethod ?? this.membershipMethod,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (seedColorValue.present) {
      map['seed_color_value'] = Variable<int>(seedColorValue.value);
    }
    if (equalizerEnabled.present) {
      map['equalizer_enabled'] = Variable<bool>(equalizerEnabled.value);
    }
    if (equalizerGainsJson.present) {
      map['equalizer_gains_json'] = Variable<String>(equalizerGainsJson.value);
    }
    if (equalizerPreset.present) {
      map['equalizer_preset'] = Variable<String>(equalizerPreset.value);
    }
    if (listenBrainzToken.present) {
      map['listen_brainz_token'] = Variable<String>(listenBrainzToken.value);
    }
    if (listenBrainzEnabled.present) {
      map['listen_brainz_enabled'] = Variable<bool>(listenBrainzEnabled.value);
    }
    if (lyricsOverlayEnabled.present) {
      map['lyrics_overlay_enabled'] = Variable<bool>(
        lyricsOverlayEnabled.value,
      );
    }
    if (statusBarLyricsEnabled.present) {
      map['status_bar_lyrics_enabled'] = Variable<bool>(
        statusBarLyricsEnabled.value,
      );
    }
    if (safeAudioMode.present) {
      map['safe_audio_mode'] = Variable<bool>(safeAudioMode.value);
    }
    if (localeCode.present) {
      map['locale_code'] = Variable<String>(localeCode.value);
    }
    if (membershipActive.present) {
      map['membership_active'] = Variable<bool>(membershipActive.value);
    }
    if (membershipMethod.present) {
      map['membership_method'] = Variable<String>(membershipMethod.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('seedColorValue: $seedColorValue, ')
          ..write('equalizerEnabled: $equalizerEnabled, ')
          ..write('equalizerGainsJson: $equalizerGainsJson, ')
          ..write('equalizerPreset: $equalizerPreset, ')
          ..write('listenBrainzToken: $listenBrainzToken, ')
          ..write('listenBrainzEnabled: $listenBrainzEnabled, ')
          ..write('lyricsOverlayEnabled: $lyricsOverlayEnabled, ')
           ..write('statusBarLyricsEnabled: $statusBarLyricsEnabled, ')
          ..write('safeAudioMode: $safeAudioMode, ')
          ..write('localeCode: $localeCode, ')
          ..write('membershipActive: $membershipActive, ')
          ..write('membershipMethod: $membershipMethod')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, Download> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverArtIdMeta = const VerificationMeta(
    'coverArtId',
  );
  @override
  late final GeneratedColumn<String> coverArtId = GeneratedColumn<String>(
    'cover_art_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extMeta = const VerificationMeta('ext');
  @override
  late final GeneratedColumn<String> ext = GeneratedColumn<String>(
    'ext',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('mp3'),
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('downloading'),
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    songId,
    serverId,
    title,
    artist,
    album,
    filePath,
    coverArtId,
    ext,
    bytes,
    status,
    progress,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<Download> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('cover_art_id')) {
      context.handle(
        _coverArtIdMeta,
        coverArtId.isAcceptableOrUnknown(
          data['cover_art_id']!,
          _coverArtIdMeta,
        ),
      );
    }
    if (data.containsKey('ext')) {
      context.handle(
        _extMeta,
        ext.isAcceptableOrUnknown(data['ext']!, _extMeta),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {songId};
  @override
  Download map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Download(
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      coverArtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_art_id'],
      ),
      ext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ext'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }
}

class Download extends DataClass implements Insertable<Download> {
  final String songId;
  final int serverId;
  final String title;
  final String? artist;
  final String? album;
  final String filePath;
  final String? coverArtId;
  final String ext;
  final int bytes;
  final String status;
  final double progress;
  final DateTime createdAt;
  const Download({
    required this.songId,
    required this.serverId,
    required this.title,
    this.artist,
    this.album,
    required this.filePath,
    this.coverArtId,
    required this.ext,
    required this.bytes,
    required this.status,
    required this.progress,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['song_id'] = Variable<String>(songId);
    map['server_id'] = Variable<int>(serverId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || coverArtId != null) {
      map['cover_art_id'] = Variable<String>(coverArtId);
    }
    map['ext'] = Variable<String>(ext);
    map['bytes'] = Variable<int>(bytes);
    map['status'] = Variable<String>(status);
    map['progress'] = Variable<double>(progress);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      songId: Value(songId),
      serverId: Value(serverId),
      title: Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      filePath: Value(filePath),
      coverArtId: coverArtId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverArtId),
      ext: Value(ext),
      bytes: Value(bytes),
      status: Value(status),
      progress: Value(progress),
      createdAt: Value(createdAt),
    );
  }

  factory Download.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Download(
      songId: serializer.fromJson<String>(json['songId']),
      serverId: serializer.fromJson<int>(json['serverId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      filePath: serializer.fromJson<String>(json['filePath']),
      coverArtId: serializer.fromJson<String?>(json['coverArtId']),
      ext: serializer.fromJson<String>(json['ext']),
      bytes: serializer.fromJson<int>(json['bytes']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<double>(json['progress']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'songId': serializer.toJson<String>(songId),
      'serverId': serializer.toJson<int>(serverId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'filePath': serializer.toJson<String>(filePath),
      'coverArtId': serializer.toJson<String?>(coverArtId),
      'ext': serializer.toJson<String>(ext),
      'bytes': serializer.toJson<int>(bytes),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<double>(progress),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Download copyWith({
    String? songId,
    int? serverId,
    String? title,
    Value<String?> artist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    String? filePath,
    Value<String?> coverArtId = const Value.absent(),
    String? ext,
    int? bytes,
    String? status,
    double? progress,
    DateTime? createdAt,
  }) => Download(
    songId: songId ?? this.songId,
    serverId: serverId ?? this.serverId,
    title: title ?? this.title,
    artist: artist.present ? artist.value : this.artist,
    album: album.present ? album.value : this.album,
    filePath: filePath ?? this.filePath,
    coverArtId: coverArtId.present ? coverArtId.value : this.coverArtId,
    ext: ext ?? this.ext,
    bytes: bytes ?? this.bytes,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    createdAt: createdAt ?? this.createdAt,
  );
  Download copyWithCompanion(DownloadsCompanion data) {
    return Download(
      songId: data.songId.present ? data.songId.value : this.songId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      coverArtId: data.coverArtId.present
          ? data.coverArtId.value
          : this.coverArtId,
      ext: data.ext.present ? data.ext.value : this.ext,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Download(')
          ..write('songId: $songId, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('filePath: $filePath, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('ext: $ext, ')
          ..write('bytes: $bytes, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    songId,
    serverId,
    title,
    artist,
    album,
    filePath,
    coverArtId,
    ext,
    bytes,
    status,
    progress,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Download &&
          other.songId == this.songId &&
          other.serverId == this.serverId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.filePath == this.filePath &&
          other.coverArtId == this.coverArtId &&
          other.ext == this.ext &&
          other.bytes == this.bytes &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.createdAt == this.createdAt);
}

class DownloadsCompanion extends UpdateCompanion<Download> {
  final Value<String> songId;
  final Value<int> serverId;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<String> filePath;
  final Value<String?> coverArtId;
  final Value<String> ext;
  final Value<int> bytes;
  final Value<String> status;
  final Value<double> progress;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.songId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.filePath = const Value.absent(),
    this.coverArtId = const Value.absent(),
    this.ext = const Value.absent(),
    this.bytes = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String songId,
    required int serverId,
    required String title,
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    required String filePath,
    this.coverArtId = const Value.absent(),
    this.ext = const Value.absent(),
    this.bytes = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : songId = Value(songId),
       serverId = Value(serverId),
       title = Value(title),
       filePath = Value(filePath);
  static Insertable<Download> custom({
    Expression<String>? songId,
    Expression<int>? serverId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? filePath,
    Expression<String>? coverArtId,
    Expression<String>? ext,
    Expression<int>? bytes,
    Expression<String>? status,
    Expression<double>? progress,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (songId != null) 'song_id': songId,
      if (serverId != null) 'server_id': serverId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (filePath != null) 'file_path': filePath,
      if (coverArtId != null) 'cover_art_id': coverArtId,
      if (ext != null) 'ext': ext,
      if (bytes != null) 'bytes': bytes,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith({
    Value<String>? songId,
    Value<int>? serverId,
    Value<String>? title,
    Value<String?>? artist,
    Value<String?>? album,
    Value<String>? filePath,
    Value<String?>? coverArtId,
    Value<String>? ext,
    Value<int>? bytes,
    Value<String>? status,
    Value<double>? progress,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DownloadsCompanion(
      songId: songId ?? this.songId,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      filePath: filePath ?? this.filePath,
      coverArtId: coverArtId ?? this.coverArtId,
      ext: ext ?? this.ext,
      bytes: bytes ?? this.bytes,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (coverArtId.present) {
      map['cover_art_id'] = Variable<String>(coverArtId.value);
    }
    if (ext.present) {
      map['ext'] = Variable<String>(ext.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('songId: $songId, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('filePath: $filePath, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('ext: $ext, ')
          ..write('bytes: $bytes, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedAlbumsTable extends CachedAlbums
    with TableInfo<$CachedAlbumsTable, CachedAlbum> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedAlbumsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    albumId,
    payload,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_albums';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedAlbum> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    } else if (isInserting) {
      context.missing(_albumIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedAlbum map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedAlbum(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      )!,
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CachedAlbumsTable createAlias(String alias) {
    return $CachedAlbumsTable(attachedDatabase, alias);
  }
}

class CachedAlbum extends DataClass implements Insertable<CachedAlbum> {
  final int id;
  final int serverId;
  final String albumId;
  final String payload;
  final DateTime fetchedAt;
  const CachedAlbum({
    required this.id,
    required this.serverId,
    required this.albumId,
    required this.payload,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['server_id'] = Variable<int>(serverId);
    map['album_id'] = Variable<String>(albumId);
    map['payload'] = Variable<String>(payload);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedAlbumsCompanion toCompanion(bool nullToAbsent) {
    return CachedAlbumsCompanion(
      id: Value(id),
      serverId: Value(serverId),
      albumId: Value(albumId),
      payload: Value(payload),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedAlbum.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedAlbum(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int>(json['serverId']),
      albumId: serializer.fromJson<String>(json['albumId']),
      payload: serializer.fromJson<String>(json['payload']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int>(serverId),
      'albumId': serializer.toJson<String>(albumId),
      'payload': serializer.toJson<String>(payload),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedAlbum copyWith({
    int? id,
    int? serverId,
    String? albumId,
    String? payload,
    DateTime? fetchedAt,
  }) => CachedAlbum(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    albumId: albumId ?? this.albumId,
    payload: payload ?? this.payload,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CachedAlbum copyWithCompanion(CachedAlbumsCompanion data) {
    return CachedAlbum(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      payload: data.payload.present ? data.payload.value : this.payload,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedAlbum(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('albumId: $albumId, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, serverId, albumId, payload, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedAlbum &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.albumId == this.albumId &&
          other.payload == this.payload &&
          other.fetchedAt == this.fetchedAt);
}

class CachedAlbumsCompanion extends UpdateCompanion<CachedAlbum> {
  final Value<int> id;
  final Value<int> serverId;
  final Value<String> albumId;
  final Value<String> payload;
  final Value<DateTime> fetchedAt;
  const CachedAlbumsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.albumId = const Value.absent(),
    this.payload = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  CachedAlbumsCompanion.insert({
    this.id = const Value.absent(),
    required int serverId,
    required String albumId,
    required String payload,
    this.fetchedAt = const Value.absent(),
  }) : serverId = Value(serverId),
       albumId = Value(albumId),
       payload = Value(payload);
  static Insertable<CachedAlbum> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<String>? albumId,
    Expression<String>? payload,
    Expression<DateTime>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (albumId != null) 'album_id': albumId,
      if (payload != null) 'payload': payload,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  CachedAlbumsCompanion copyWith({
    Value<int>? id,
    Value<int>? serverId,
    Value<String>? albumId,
    Value<String>? payload,
    Value<DateTime>? fetchedAt,
  }) {
    return CachedAlbumsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      albumId: albumId ?? this.albumId,
      payload: payload ?? this.payload,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedAlbumsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('albumId: $albumId, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }
}

class $CachedArtistsTable extends CachedArtists
    with TableInfo<$CachedArtistsTable, CachedArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    artistId,
    payload,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedArtist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      )!,
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CachedArtistsTable createAlias(String alias) {
    return $CachedArtistsTable(attachedDatabase, alias);
  }
}

class CachedArtist extends DataClass implements Insertable<CachedArtist> {
  final int id;
  final int serverId;
  final String artistId;
  final String payload;
  final DateTime fetchedAt;
  const CachedArtist({
    required this.id,
    required this.serverId,
    required this.artistId,
    required this.payload,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['server_id'] = Variable<int>(serverId);
    map['artist_id'] = Variable<String>(artistId);
    map['payload'] = Variable<String>(payload);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedArtistsCompanion toCompanion(bool nullToAbsent) {
    return CachedArtistsCompanion(
      id: Value(id),
      serverId: Value(serverId),
      artistId: Value(artistId),
      payload: Value(payload),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedArtist(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int>(json['serverId']),
      artistId: serializer.fromJson<String>(json['artistId']),
      payload: serializer.fromJson<String>(json['payload']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int>(serverId),
      'artistId': serializer.toJson<String>(artistId),
      'payload': serializer.toJson<String>(payload),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedArtist copyWith({
    int? id,
    int? serverId,
    String? artistId,
    String? payload,
    DateTime? fetchedAt,
  }) => CachedArtist(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    artistId: artistId ?? this.artistId,
    payload: payload ?? this.payload,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CachedArtist copyWithCompanion(CachedArtistsCompanion data) {
    return CachedArtist(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      payload: data.payload.present ? data.payload.value : this.payload,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedArtist(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('artistId: $artistId, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, serverId, artistId, payload, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedArtist &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.artistId == this.artistId &&
          other.payload == this.payload &&
          other.fetchedAt == this.fetchedAt);
}

class CachedArtistsCompanion extends UpdateCompanion<CachedArtist> {
  final Value<int> id;
  final Value<int> serverId;
  final Value<String> artistId;
  final Value<String> payload;
  final Value<DateTime> fetchedAt;
  const CachedArtistsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.payload = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  CachedArtistsCompanion.insert({
    this.id = const Value.absent(),
    required int serverId,
    required String artistId,
    required String payload,
    this.fetchedAt = const Value.absent(),
  }) : serverId = Value(serverId),
       artistId = Value(artistId),
       payload = Value(payload);
  static Insertable<CachedArtist> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<String>? artistId,
    Expression<String>? payload,
    Expression<DateTime>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (artistId != null) 'artist_id': artistId,
      if (payload != null) 'payload': payload,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  CachedArtistsCompanion copyWith({
    Value<int>? id,
    Value<int>? serverId,
    Value<String>? artistId,
    Value<String>? payload,
    Value<DateTime>? fetchedAt,
  }) {
    return CachedArtistsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      artistId: artistId ?? this.artistId,
      payload: payload ?? this.payload,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedArtistsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('artistId: $artistId, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServersTable servers = $ServersTable(this);
  late final $RecentPlaysTable recentPlays = $RecentPlaysTable(this);
  late final $PlaybackStatesTable playbackStates = $PlaybackStatesTable(this);
  late final $SearchHistoryTable searchHistory = $SearchHistoryTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $CachedAlbumsTable cachedAlbums = $CachedAlbumsTable(this);
  late final $CachedArtistsTable cachedArtists = $CachedArtistsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    servers,
    recentPlays,
    playbackStates,
    searchHistory,
    settings,
    downloads,
    cachedAlbums,
    cachedArtists,
  ];
}

typedef $$ServersTableCreateCompanionBuilder =
    ServersCompanion Function({
      Value<int> id,
      required String name,
      required String baseUrl,
      required String username,
      required String password,
      Value<String?> token,
      Value<DateTime> createdAt,
    });
typedef $$ServersTableUpdateCompanionBuilder =
    ServersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> baseUrl,
      Value<String> username,
      Value<String> password,
      Value<String?> token,
      Value<DateTime> createdAt,
    });

class $$ServersTableFilterComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get password => $composableBuilder(
    column: $table.password,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServersTableOrderingComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get password => $composableBuilder(
    column: $table.password,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get password =>
      $composableBuilder(column: $table.password, builder: (column) => column);

  GeneratedColumn<String> get token =>
      $composableBuilder(column: $table.token, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ServersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServersTable,
          Server,
          $$ServersTableFilterComposer,
          $$ServersTableOrderingComposer,
          $$ServersTableAnnotationComposer,
          $$ServersTableCreateCompanionBuilder,
          $$ServersTableUpdateCompanionBuilder,
          (Server, BaseReferences<_$AppDatabase, $ServersTable, Server>),
          Server,
          PrefetchHooks Function()
        > {
  $$ServersTableTableManager(_$AppDatabase db, $ServersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> password = const Value.absent(),
                Value<String?> token = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ServersCompanion(
                id: id,
                name: name,
                baseUrl: baseUrl,
                username: username,
                password: password,
                token: token,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String baseUrl,
                required String username,
                required String password,
                Value<String?> token = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ServersCompanion.insert(
                id: id,
                name: name,
                baseUrl: baseUrl,
                username: username,
                password: password,
                token: token,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServersTable,
      Server,
      $$ServersTableFilterComposer,
      $$ServersTableOrderingComposer,
      $$ServersTableAnnotationComposer,
      $$ServersTableCreateCompanionBuilder,
      $$ServersTableUpdateCompanionBuilder,
      (Server, BaseReferences<_$AppDatabase, $ServersTable, Server>),
      Server,
      PrefetchHooks Function()
    >;
typedef $$RecentPlaysTableCreateCompanionBuilder =
    RecentPlaysCompanion Function({
      Value<int> id,
      required String songId,
      required int serverId,
      Value<String?> title,
      Value<String?> artist,
      Value<DateTime> playedAt,
    });
typedef $$RecentPlaysTableUpdateCompanionBuilder =
    RecentPlaysCompanion Function({
      Value<int> id,
      Value<String> songId,
      Value<int> serverId,
      Value<String?> title,
      Value<String?> artist,
      Value<DateTime> playedAt,
    });

class $$RecentPlaysTableFilterComposer
    extends Composer<_$AppDatabase, $RecentPlaysTable> {
  $$RecentPlaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentPlaysTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentPlaysTable> {
  $$RecentPlaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentPlaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentPlaysTable> {
  $$RecentPlaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);
}

class $$RecentPlaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentPlaysTable,
          RecentPlay,
          $$RecentPlaysTableFilterComposer,
          $$RecentPlaysTableOrderingComposer,
          $$RecentPlaysTableAnnotationComposer,
          $$RecentPlaysTableCreateCompanionBuilder,
          $$RecentPlaysTableUpdateCompanionBuilder,
          (
            RecentPlay,
            BaseReferences<_$AppDatabase, $RecentPlaysTable, RecentPlay>,
          ),
          RecentPlay,
          PrefetchHooks Function()
        > {
  $$RecentPlaysTableTableManager(_$AppDatabase db, $RecentPlaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentPlaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentPlaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentPlaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> serverId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
              }) => RecentPlaysCompanion(
                id: id,
                songId: songId,
                serverId: serverId,
                title: title,
                artist: artist,
                playedAt: playedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String songId,
                required int serverId,
                Value<String?> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
              }) => RecentPlaysCompanion.insert(
                id: id,
                songId: songId,
                serverId: serverId,
                title: title,
                artist: artist,
                playedAt: playedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentPlaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentPlaysTable,
      RecentPlay,
      $$RecentPlaysTableFilterComposer,
      $$RecentPlaysTableOrderingComposer,
      $$RecentPlaysTableAnnotationComposer,
      $$RecentPlaysTableCreateCompanionBuilder,
      $$RecentPlaysTableUpdateCompanionBuilder,
      (
        RecentPlay,
        BaseReferences<_$AppDatabase, $RecentPlaysTable, RecentPlay>,
      ),
      RecentPlay,
      PrefetchHooks Function()
    >;
typedef $$PlaybackStatesTableCreateCompanionBuilder =
    PlaybackStatesCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      required String queueJson,
      required int currentIndex,
      required int positionMs,
      Value<String> loopMode,
      Value<bool> shuffle,
      Value<double> volume,
      Value<double> speed,
      Value<DateTime> updatedAt,
    });
typedef $$PlaybackStatesTableUpdateCompanionBuilder =
    PlaybackStatesCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<String> queueJson,
      Value<int> currentIndex,
      Value<int> positionMs,
      Value<String> loopMode,
      Value<bool> shuffle,
      Value<double> volume,
      Value<double> speed,
      Value<DateTime> updatedAt,
    });

class $$PlaybackStatesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get queueJson => $composableBuilder(
    column: $table.queueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loopMode => $composableBuilder(
    column: $table.loopMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get shuffle => $composableBuilder(
    column: $table.shuffle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get queueJson => $composableBuilder(
    column: $table.queueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loopMode => $composableBuilder(
    column: $table.loopMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get shuffle => $composableBuilder(
    column: $table.shuffle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get queueJson =>
      $composableBuilder(column: $table.queueJson, builder: (column) => column);

  GeneratedColumn<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loopMode =>
      $composableBuilder(column: $table.loopMode, builder: (column) => column);

  GeneratedColumn<bool> get shuffle =>
      $composableBuilder(column: $table.shuffle, builder: (column) => column);

  GeneratedColumn<double> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackStatesTable,
          PlaybackState,
          $$PlaybackStatesTableFilterComposer,
          $$PlaybackStatesTableOrderingComposer,
          $$PlaybackStatesTableAnnotationComposer,
          $$PlaybackStatesTableCreateCompanionBuilder,
          $$PlaybackStatesTableUpdateCompanionBuilder,
          (
            PlaybackState,
            BaseReferences<_$AppDatabase, $PlaybackStatesTable, PlaybackState>,
          ),
          PlaybackState,
          PrefetchHooks Function()
        > {
  $$PlaybackStatesTableTableManager(
    _$AppDatabase db,
    $PlaybackStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> queueJson = const Value.absent(),
                Value<int> currentIndex = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<String> loopMode = const Value.absent(),
                Value<bool> shuffle = const Value.absent(),
                Value<double> volume = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PlaybackStatesCompanion(
                id: id,
                serverId: serverId,
                queueJson: queueJson,
                currentIndex: currentIndex,
                positionMs: positionMs,
                loopMode: loopMode,
                shuffle: shuffle,
                volume: volume,
                speed: speed,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required String queueJson,
                required int currentIndex,
                required int positionMs,
                Value<String> loopMode = const Value.absent(),
                Value<bool> shuffle = const Value.absent(),
                Value<double> volume = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PlaybackStatesCompanion.insert(
                id: id,
                serverId: serverId,
                queueJson: queueJson,
                currentIndex: currentIndex,
                positionMs: positionMs,
                loopMode: loopMode,
                shuffle: shuffle,
                volume: volume,
                speed: speed,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackStatesTable,
      PlaybackState,
      $$PlaybackStatesTableFilterComposer,
      $$PlaybackStatesTableOrderingComposer,
      $$PlaybackStatesTableAnnotationComposer,
      $$PlaybackStatesTableCreateCompanionBuilder,
      $$PlaybackStatesTableUpdateCompanionBuilder,
      (
        PlaybackState,
        BaseReferences<_$AppDatabase, $PlaybackStatesTable, PlaybackState>,
      ),
      PlaybackState,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryTableCreateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<int> id,
      required String keyword,
      Value<DateTime> searchedAt,
    });
typedef $$SearchHistoryTableUpdateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<int> id,
      Value<String> keyword,
      Value<DateTime> searchedAt,
    });

class $$SearchHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get keyword =>
      $composableBuilder(column: $table.keyword, builder: (column) => column);

  GeneratedColumn<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => column,
  );
}

class $$SearchHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoryTable,
          SearchHistoryData,
          $$SearchHistoryTableFilterComposer,
          $$SearchHistoryTableOrderingComposer,
          $$SearchHistoryTableAnnotationComposer,
          $$SearchHistoryTableCreateCompanionBuilder,
          $$SearchHistoryTableUpdateCompanionBuilder,
          (
            SearchHistoryData,
            BaseReferences<
              _$AppDatabase,
              $SearchHistoryTable,
              SearchHistoryData
            >,
          ),
          SearchHistoryData,
          PrefetchHooks Function()
        > {
  $$SearchHistoryTableTableManager(_$AppDatabase db, $SearchHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> keyword = const Value.absent(),
                Value<DateTime> searchedAt = const Value.absent(),
              }) => SearchHistoryCompanion(
                id: id,
                keyword: keyword,
                searchedAt: searchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String keyword,
                Value<DateTime> searchedAt = const Value.absent(),
              }) => SearchHistoryCompanion.insert(
                id: id,
                keyword: keyword,
                searchedAt: searchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoryTable,
      SearchHistoryData,
      $$SearchHistoryTableFilterComposer,
      $$SearchHistoryTableOrderingComposer,
      $$SearchHistoryTableAnnotationComposer,
      $$SearchHistoryTableCreateCompanionBuilder,
      $$SearchHistoryTableUpdateCompanionBuilder,
      (
        SearchHistoryData,
        BaseReferences<_$AppDatabase, $SearchHistoryTable, SearchHistoryData>,
      ),
      SearchHistoryData,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String> themeMode,
      Value<int> seedColorValue,
      Value<bool> equalizerEnabled,
      Value<String> equalizerGainsJson,
      Value<String> equalizerPreset,
      Value<String?> listenBrainzToken,
      Value<bool> listenBrainzEnabled,
      Value<bool> lyricsOverlayEnabled,
      Value<bool> safeAudioMode,
      Value<String> localeCode,
      Value<bool> membershipActive,
      Value<String?> membershipMethod,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String> themeMode,
      Value<int> seedColorValue,
      Value<bool> equalizerEnabled,
      Value<String> equalizerGainsJson,
      Value<String> equalizerPreset,
      Value<String?> listenBrainzToken,
      Value<bool> listenBrainzEnabled,
      Value<bool> lyricsOverlayEnabled,
      Value<bool> safeAudioMode,
      Value<String> localeCode,
      Value<bool> membershipActive,
      Value<String?> membershipMethod,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seedColorValue => $composableBuilder(
    column: $table.seedColorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get equalizerEnabled => $composableBuilder(
    column: $table.equalizerEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equalizerGainsJson => $composableBuilder(
    column: $table.equalizerGainsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equalizerPreset => $composableBuilder(
    column: $table.equalizerPreset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listenBrainzToken => $composableBuilder(
    column: $table.listenBrainzToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get listenBrainzEnabled => $composableBuilder(
    column: $table.listenBrainzEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lyricsOverlayEnabled => $composableBuilder(
    column: $table.lyricsOverlayEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get safeAudioMode => $composableBuilder(
    column: $table.safeAudioMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localeCode => $composableBuilder(
    column: $table.localeCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get membershipActive => $composableBuilder(
    column: $table.membershipActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get membershipMethod => $composableBuilder(
    column: $table.membershipMethod,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seedColorValue => $composableBuilder(
    column: $table.seedColorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get equalizerEnabled => $composableBuilder(
    column: $table.equalizerEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equalizerGainsJson => $composableBuilder(
    column: $table.equalizerGainsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equalizerPreset => $composableBuilder(
    column: $table.equalizerPreset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listenBrainzToken => $composableBuilder(
    column: $table.listenBrainzToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get listenBrainzEnabled => $composableBuilder(
    column: $table.listenBrainzEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lyricsOverlayEnabled => $composableBuilder(
    column: $table.lyricsOverlayEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get safeAudioMode => $composableBuilder(
    column: $table.safeAudioMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localeCode => $composableBuilder(
    column: $table.localeCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get membershipActive => $composableBuilder(
    column: $table.membershipActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get membershipMethod => $composableBuilder(
    column: $table.membershipMethod,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<int> get seedColorValue => $composableBuilder(
    column: $table.seedColorValue,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get equalizerEnabled => $composableBuilder(
    column: $table.equalizerEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get equalizerGainsJson => $composableBuilder(
    column: $table.equalizerGainsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get equalizerPreset => $composableBuilder(
    column: $table.equalizerPreset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get listenBrainzToken => $composableBuilder(
    column: $table.listenBrainzToken,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get listenBrainzEnabled => $composableBuilder(
    column: $table.listenBrainzEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get lyricsOverlayEnabled => $composableBuilder(
    column: $table.lyricsOverlayEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get safeAudioMode => $composableBuilder(
    column: $table.safeAudioMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localeCode => $composableBuilder(
    column: $table.localeCode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get membershipActive => $composableBuilder(
    column: $table.membershipActive,
    builder: (column) => column,
  );

  GeneratedColumn<String> get membershipMethod => $composableBuilder(
    column: $table.membershipMethod,
    builder: (column) => column,
  );
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<int> seedColorValue = const Value.absent(),
                Value<bool> equalizerEnabled = const Value.absent(),
                Value<String> equalizerGainsJson = const Value.absent(),
                Value<String> equalizerPreset = const Value.absent(),
                Value<String?> listenBrainzToken = const Value.absent(),
                Value<bool> listenBrainzEnabled = const Value.absent(),
                Value<bool> lyricsOverlayEnabled = const Value.absent(),
                Value<bool> safeAudioMode = const Value.absent(),
                Value<String> localeCode = const Value.absent(),
                Value<bool> membershipActive = const Value.absent(),
                Value<String?> membershipMethod = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                themeMode: themeMode,
                seedColorValue: seedColorValue,
                equalizerEnabled: equalizerEnabled,
                equalizerGainsJson: equalizerGainsJson,
                equalizerPreset: equalizerPreset,
                listenBrainzToken: listenBrainzToken,
                listenBrainzEnabled: listenBrainzEnabled,
                lyricsOverlayEnabled: lyricsOverlayEnabled,
                safeAudioMode: safeAudioMode,
                localeCode: localeCode,
                membershipActive: membershipActive,
                membershipMethod: membershipMethod,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<int> seedColorValue = const Value.absent(),
                Value<bool> equalizerEnabled = const Value.absent(),
                Value<String> equalizerGainsJson = const Value.absent(),
                Value<String> equalizerPreset = const Value.absent(),
                Value<String?> listenBrainzToken = const Value.absent(),
                Value<bool> listenBrainzEnabled = const Value.absent(),
                Value<bool> lyricsOverlayEnabled = const Value.absent(),
                Value<bool> safeAudioMode = const Value.absent(),
                Value<String> localeCode = const Value.absent(),
                Value<bool> membershipActive = const Value.absent(),
                Value<String?> membershipMethod = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                themeMode: themeMode,
                seedColorValue: seedColorValue,
                equalizerEnabled: equalizerEnabled,
                equalizerGainsJson: equalizerGainsJson,
                equalizerPreset: equalizerPreset,
                listenBrainzToken: listenBrainzToken,
                listenBrainzEnabled: listenBrainzEnabled,
                lyricsOverlayEnabled: lyricsOverlayEnabled,
                safeAudioMode: safeAudioMode,
                localeCode: localeCode,
                membershipActive: membershipActive,
                membershipMethod: membershipMethod,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$DownloadsTableCreateCompanionBuilder =
    DownloadsCompanion Function({
      required String songId,
      required int serverId,
      required String title,
      Value<String?> artist,
      Value<String?> album,
      required String filePath,
      Value<String?> coverArtId,
      Value<String> ext,
      Value<int> bytes,
      Value<String> status,
      Value<double> progress,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$DownloadsTableUpdateCompanionBuilder =
    DownloadsCompanion Function({
      Value<String> songId,
      Value<int> serverId,
      Value<String> title,
      Value<String?> artist,
      Value<String?> album,
      Value<String> filePath,
      Value<String?> coverArtId,
      Value<String> ext,
      Value<int> bytes,
      Value<String> status,
      Value<double> progress,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ext =>
      $composableBuilder(column: $table.ext, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadsTable,
          Download,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (Download, BaseReferences<_$AppDatabase, $DownloadsTable, Download>),
          Download,
          PrefetchHooks Function()
        > {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> songId = const Value.absent(),
                Value<int> serverId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String?> coverArtId = const Value.absent(),
                Value<String> ext = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion(
                songId: songId,
                serverId: serverId,
                title: title,
                artist: artist,
                album: album,
                filePath: filePath,
                coverArtId: coverArtId,
                ext: ext,
                bytes: bytes,
                status: status,
                progress: progress,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String songId,
                required int serverId,
                required String title,
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                required String filePath,
                Value<String?> coverArtId = const Value.absent(),
                Value<String> ext = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion.insert(
                songId: songId,
                serverId: serverId,
                title: title,
                artist: artist,
                album: album,
                filePath: filePath,
                coverArtId: coverArtId,
                ext: ext,
                bytes: bytes,
                status: status,
                progress: progress,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadsTable,
      Download,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (Download, BaseReferences<_$AppDatabase, $DownloadsTable, Download>),
      Download,
      PrefetchHooks Function()
    >;
typedef $$CachedAlbumsTableCreateCompanionBuilder =
    CachedAlbumsCompanion Function({
      Value<int> id,
      required int serverId,
      required String albumId,
      required String payload,
      Value<DateTime> fetchedAt,
    });
typedef $$CachedAlbumsTableUpdateCompanionBuilder =
    CachedAlbumsCompanion Function({
      Value<int> id,
      Value<int> serverId,
      Value<String> albumId,
      Value<String> payload,
      Value<DateTime> fetchedAt,
    });

class $$CachedAlbumsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedAlbumsTable> {
  $$CachedAlbumsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedAlbumsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedAlbumsTable> {
  $$CachedAlbumsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedAlbumsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedAlbumsTable> {
  $$CachedAlbumsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get albumId =>
      $composableBuilder(column: $table.albumId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedAlbumsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedAlbumsTable,
          CachedAlbum,
          $$CachedAlbumsTableFilterComposer,
          $$CachedAlbumsTableOrderingComposer,
          $$CachedAlbumsTableAnnotationComposer,
          $$CachedAlbumsTableCreateCompanionBuilder,
          $$CachedAlbumsTableUpdateCompanionBuilder,
          (
            CachedAlbum,
            BaseReferences<_$AppDatabase, $CachedAlbumsTable, CachedAlbum>,
          ),
          CachedAlbum,
          PrefetchHooks Function()
        > {
  $$CachedAlbumsTableTableManager(_$AppDatabase db, $CachedAlbumsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedAlbumsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedAlbumsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedAlbumsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> serverId = const Value.absent(),
                Value<String> albumId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
              }) => CachedAlbumsCompanion(
                id: id,
                serverId: serverId,
                albumId: albumId,
                payload: payload,
                fetchedAt: fetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int serverId,
                required String albumId,
                required String payload,
                Value<DateTime> fetchedAt = const Value.absent(),
              }) => CachedAlbumsCompanion.insert(
                id: id,
                serverId: serverId,
                albumId: albumId,
                payload: payload,
                fetchedAt: fetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedAlbumsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedAlbumsTable,
      CachedAlbum,
      $$CachedAlbumsTableFilterComposer,
      $$CachedAlbumsTableOrderingComposer,
      $$CachedAlbumsTableAnnotationComposer,
      $$CachedAlbumsTableCreateCompanionBuilder,
      $$CachedAlbumsTableUpdateCompanionBuilder,
      (
        CachedAlbum,
        BaseReferences<_$AppDatabase, $CachedAlbumsTable, CachedAlbum>,
      ),
      CachedAlbum,
      PrefetchHooks Function()
    >;
typedef $$CachedArtistsTableCreateCompanionBuilder =
    CachedArtistsCompanion Function({
      Value<int> id,
      required int serverId,
      required String artistId,
      required String payload,
      Value<DateTime> fetchedAt,
    });
typedef $$CachedArtistsTableUpdateCompanionBuilder =
    CachedArtistsCompanion Function({
      Value<int> id,
      Value<int> serverId,
      Value<String> artistId,
      Value<String> payload,
      Value<DateTime> fetchedAt,
    });

class $$CachedArtistsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedArtistsTable> {
  $$CachedArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedArtistsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedArtistsTable> {
  $$CachedArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedArtistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedArtistsTable> {
  $$CachedArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get artistId =>
      $composableBuilder(column: $table.artistId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedArtistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedArtistsTable,
          CachedArtist,
          $$CachedArtistsTableFilterComposer,
          $$CachedArtistsTableOrderingComposer,
          $$CachedArtistsTableAnnotationComposer,
          $$CachedArtistsTableCreateCompanionBuilder,
          $$CachedArtistsTableUpdateCompanionBuilder,
          (
            CachedArtist,
            BaseReferences<_$AppDatabase, $CachedArtistsTable, CachedArtist>,
          ),
          CachedArtist,
          PrefetchHooks Function()
        > {
  $$CachedArtistsTableTableManager(_$AppDatabase db, $CachedArtistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> serverId = const Value.absent(),
                Value<String> artistId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
              }) => CachedArtistsCompanion(
                id: id,
                serverId: serverId,
                artistId: artistId,
                payload: payload,
                fetchedAt: fetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int serverId,
                required String artistId,
                required String payload,
                Value<DateTime> fetchedAt = const Value.absent(),
              }) => CachedArtistsCompanion.insert(
                id: id,
                serverId: serverId,
                artistId: artistId,
                payload: payload,
                fetchedAt: fetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedArtistsTable,
      CachedArtist,
      $$CachedArtistsTableFilterComposer,
      $$CachedArtistsTableOrderingComposer,
      $$CachedArtistsTableAnnotationComposer,
      $$CachedArtistsTableCreateCompanionBuilder,
      $$CachedArtistsTableUpdateCompanionBuilder,
      (
        CachedArtist,
        BaseReferences<_$AppDatabase, $CachedArtistsTable, CachedArtist>,
      ),
      CachedArtist,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServersTableTableManager get servers =>
      $$ServersTableTableManager(_db, _db.servers);
  $$RecentPlaysTableTableManager get recentPlays =>
      $$RecentPlaysTableTableManager(_db, _db.recentPlays);
  $$PlaybackStatesTableTableManager get playbackStates =>
      $$PlaybackStatesTableTableManager(_db, _db.playbackStates);
  $$SearchHistoryTableTableManager get searchHistory =>
      $$SearchHistoryTableTableManager(_db, _db.searchHistory);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$CachedAlbumsTableTableManager get cachedAlbums =>
      $$CachedAlbumsTableTableManager(_db, _db.cachedAlbums);
  $$CachedArtistsTableTableManager get cachedArtists =>
      $$CachedArtistsTableTableManager(_db, _db.cachedArtists);
}
