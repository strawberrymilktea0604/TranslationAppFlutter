// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_result_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetQuizResultModelCollection on Isar {
  IsarCollection<QuizResultModel> get quizResultModels => this.collection();
}

const QuizResultModelSchema = CollectionSchema(
  name: r'QuizResultModel',
  id: -((665828683 << 32) + 3283474081),
  properties: {
    r'answers': PropertySchema(
      id: 0,
      name: r'answers',
      type: IsarType.objectList,

      target: r'QuizAnswerItem',
    ),
    r'backendId': PropertySchema(
      id: 1,
      name: r'backendId',
      type: IsarType.string,
    ),
    r'bankBackendId': PropertySchema(
      id: 2,
      name: r'bankBackendId',
      type: IsarType.string,
    ),
    r'bankTitle': PropertySchema(
      id: 3,
      name: r'bankTitle',
      type: IsarType.string,
    ),
    r'completedAt': PropertySchema(
      id: 4,
      name: r'completedAt',
      type: IsarType.dateTime,
    ),
    r'correctAnswers': PropertySchema(
      id: 5,
      name: r'correctAnswers',
      type: IsarType.long,
    ),
    r'durationSeconds': PropertySchema(
      id: 6,
      name: r'durationSeconds',
      type: IsarType.long,
    ),
    r'isSynced': PropertySchema(id: 7, name: r'isSynced', type: IsarType.bool),
    r'score': PropertySchema(id: 8, name: r'score', type: IsarType.double),
    r'status': PropertySchema(id: 9, name: r'status', type: IsarType.string),
    r'totalQuestions': PropertySchema(
      id: 10,
      name: r'totalQuestions',
      type: IsarType.long,
    ),
  },

  estimateSize: _quizResultModelEstimateSize,
  serialize: _quizResultModelSerialize,
  deserialize: _quizResultModelDeserialize,
  deserializeProp: _quizResultModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'backendId': IndexSchema(
      id: ((2044660984 << 32) + 84847146),
      name: r'backendId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'backendId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'bankBackendId': IndexSchema(
      id: ((1745530775 << 32) + 1252529469),
      name: r'bankBackendId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'bankBackendId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'completedAt': IndexSchema(
      id: -((734951116 << 32) + 4078984416),
      name: r'completedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'completedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {r'QuizAnswerItem': QuizAnswerItemSchema},

  getId: _quizResultModelGetId,
  getLinks: _quizResultModelGetLinks,
  attach: _quizResultModelAttach,
  version: '3.3.2',
);

int _quizResultModelEstimateSize(
  QuizResultModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.answers.length * 3;
  {
    final offsets = allOffsets[QuizAnswerItem]!;
    for (var i = 0; i < object.answers.length; i++) {
      final value = object.answers[i];
      bytesCount += QuizAnswerItemSchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
    }
  }
  bytesCount += 3 + object.backendId.length * 3;
  bytesCount += 3 + object.bankBackendId.length * 3;
  bytesCount += 3 + object.bankTitle.length * 3;
  bytesCount += 3 + object.status.length * 3;
  return bytesCount;
}

void _quizResultModelSerialize(
  QuizResultModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeObjectList<QuizAnswerItem>(
    offsets[0],
    allOffsets,
    QuizAnswerItemSchema.serialize,
    object.answers,
  );
  writer.writeString(offsets[1], object.backendId);
  writer.writeString(offsets[2], object.bankBackendId);
  writer.writeString(offsets[3], object.bankTitle);
  writer.writeDateTime(offsets[4], object.completedAt);
  writer.writeLong(offsets[5], object.correctAnswers);
  writer.writeLong(offsets[6], object.durationSeconds);
  writer.writeBool(offsets[7], object.isSynced);
  writer.writeDouble(offsets[8], object.score);
  writer.writeString(offsets[9], object.status);
  writer.writeLong(offsets[10], object.totalQuestions);
}

QuizResultModel _quizResultModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = QuizResultModel(
    answers:
        reader.readObjectList<QuizAnswerItem>(
          offsets[0],
          QuizAnswerItemSchema.deserialize,
          allOffsets,
          QuizAnswerItem(),
        ) ??
        const [],
    backendId: reader.readString(offsets[1]),
    bankBackendId: reader.readString(offsets[2]),
    bankTitle: reader.readString(offsets[3]),
    completedAt: reader.readDateTime(offsets[4]),
    correctAnswers: reader.readLong(offsets[5]),
    durationSeconds: reader.readLong(offsets[6]),
    isSynced: reader.readBoolOrNull(offsets[7]) ?? false,
    score: reader.readDouble(offsets[8]),
    status: reader.readString(offsets[9]),
    totalQuestions: reader.readLong(offsets[10]),
  );
  object.id = id;
  return object;
}

P _quizResultModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readObjectList<QuizAnswerItem>(
                offset,
                QuizAnswerItemSchema.deserialize,
                allOffsets,
                QuizAnswerItem(),
              ) ??
              const [])
          as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 8:
      return (reader.readDouble(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _quizResultModelGetId(QuizResultModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _quizResultModelGetLinks(QuizResultModel object) {
  return [];
}

void _quizResultModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  QuizResultModel object,
) {
  object.id = id;
}

extension QuizResultModelByIndex on IsarCollection<QuizResultModel> {
  Future<QuizResultModel?> getByBackendId(String backendId) {
    return getByIndex(r'backendId', [backendId]);
  }

  QuizResultModel? getByBackendIdSync(String backendId) {
    return getByIndexSync(r'backendId', [backendId]);
  }

  Future<bool> deleteByBackendId(String backendId) {
    return deleteByIndex(r'backendId', [backendId]);
  }

  bool deleteByBackendIdSync(String backendId) {
    return deleteByIndexSync(r'backendId', [backendId]);
  }

  Future<List<QuizResultModel?>> getAllByBackendId(
    List<String> backendIdValues,
  ) {
    final values = backendIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'backendId', values);
  }

  List<QuizResultModel?> getAllByBackendIdSync(List<String> backendIdValues) {
    final values = backendIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'backendId', values);
  }

  Future<int> deleteAllByBackendId(List<String> backendIdValues) {
    final values = backendIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'backendId', values);
  }

  int deleteAllByBackendIdSync(List<String> backendIdValues) {
    final values = backendIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'backendId', values);
  }

  Future<Id> putByBackendId(QuizResultModel object) {
    return putByIndex(r'backendId', object);
  }

  Id putByBackendIdSync(QuizResultModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'backendId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByBackendId(List<QuizResultModel> objects) {
    return putAllByIndex(r'backendId', objects);
  }

  List<Id> putAllByBackendIdSync(
    List<QuizResultModel> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'backendId', objects, saveLinks: saveLinks);
  }
}

extension QuizResultModelQueryWhereSort
    on QueryBuilder<QuizResultModel, QuizResultModel, QWhere> {
  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhere> anyCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'completedAt'),
      );
    });
  }
}

extension QuizResultModelQueryWhere
    on QueryBuilder<QuizResultModel, QuizResultModel, QWhereClause> {
  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause>
  backendIdEqualTo(String backendId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'backendId', value: [backendId]),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause>
  backendIdNotEqualTo(String backendId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'backendId',
                lower: [],
                upper: [backendId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'backendId',
                lower: [backendId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'backendId',
                lower: [backendId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'backendId',
                lower: [],
                upper: [backendId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause>
  bankBackendIdEqualTo(String bankBackendId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'bankBackendId',
          value: [bankBackendId],
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause>
  bankBackendIdNotEqualTo(String bankBackendId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'bankBackendId',
                lower: [],
                upper: [bankBackendId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'bankBackendId',
                lower: [bankBackendId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'bankBackendId',
                lower: [bankBackendId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'bankBackendId',
                lower: [],
                upper: [bankBackendId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause>
  completedAtEqualTo(DateTime completedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'completedAt',
          value: [completedAt],
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause>
  completedAtNotEqualTo(DateTime completedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'completedAt',
                lower: [],
                upper: [completedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'completedAt',
                lower: [completedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'completedAt',
                lower: [completedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'completedAt',
                lower: [],
                upper: [completedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause>
  completedAtGreaterThan(DateTime completedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'completedAt',
          lower: [completedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause>
  completedAtLessThan(DateTime completedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'completedAt',
          lower: [],
          upper: [completedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterWhereClause>
  completedAtBetween(
    DateTime lowerCompletedAt,
    DateTime upperCompletedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'completedAt',
          lower: [lowerCompletedAt],
          includeLower: includeLower,
          upper: [upperCompletedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension QuizResultModelQueryFilter
    on QueryBuilder<QuizResultModel, QuizResultModel, QFilterCondition> {
  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  answersLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'answers', length, true, length, true);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  answersIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'answers', 0, true, 0, true);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  answersIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'answers', 0, false, 999999, true);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  answersLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'answers', 0, true, length, include);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  answersLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'answers', length, include, 999999, true);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  answersLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'answers',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  backendIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'backendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  backendIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'backendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  backendIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'backendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  backendIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'backendId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  backendIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'backendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  backendIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'backendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  backendIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'backendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  backendIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'backendId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  backendIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'backendId', value: ''),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  backendIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'backendId', value: ''),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankBackendIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'bankBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankBackendIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bankBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankBackendIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bankBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankBackendIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bankBackendId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankBackendIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'bankBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankBackendIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'bankBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankBackendIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'bankBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankBackendIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'bankBackendId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankBackendIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'bankBackendId', value: ''),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankBackendIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'bankBackendId', value: ''),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankTitleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'bankTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankTitleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bankTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankTitleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bankTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankTitleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bankTitle',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankTitleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'bankTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankTitleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'bankTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankTitleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'bankTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankTitleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'bankTitle',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankTitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'bankTitle', value: ''),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  bankTitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'bankTitle', value: ''),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  completedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'completedAt', value: value),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  completedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'completedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  completedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'completedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  completedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'completedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  correctAnswersEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'correctAnswers', value: value),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  correctAnswersGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'correctAnswers',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  correctAnswersLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'correctAnswers',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  correctAnswersBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'correctAnswers',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  durationSecondsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'durationSeconds', value: value),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  durationSecondsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'durationSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  durationSecondsLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'durationSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  durationSecondsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'durationSeconds',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isSynced', value: value),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  scoreEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'score',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  scoreGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'score',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  scoreLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'score',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  scoreBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'score',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  statusEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'status',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  statusStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  statusEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'status',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  totalQuestionsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'totalQuestions', value: value),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  totalQuestionsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalQuestions',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  totalQuestionsLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalQuestions',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  totalQuestionsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalQuestions',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension QuizResultModelQueryObject
    on QueryBuilder<QuizResultModel, QuizResultModel, QFilterCondition> {
  QueryBuilder<QuizResultModel, QuizResultModel, QAfterFilterCondition>
  answersElement(FilterQuery<QuizAnswerItem> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'answers');
    });
  }
}

extension QuizResultModelQueryLinks
    on QueryBuilder<QuizResultModel, QuizResultModel, QFilterCondition> {}

extension QuizResultModelQuerySortBy
    on QueryBuilder<QuizResultModel, QuizResultModel, QSortBy> {
  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByBackendId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByBackendIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByBankBackendId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bankBackendId', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByBankBackendIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bankBackendId', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByBankTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bankTitle', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByBankTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bankTitle', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByCompletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByCorrectAnswers() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correctAnswers', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByCorrectAnswersDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correctAnswers', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByDurationSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSeconds', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByDurationSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSeconds', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy> sortByScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByTotalQuestions() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalQuestions', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  sortByTotalQuestionsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalQuestions', Sort.desc);
    });
  }
}

extension QuizResultModelQuerySortThenBy
    on QueryBuilder<QuizResultModel, QuizResultModel, QSortThenBy> {
  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByBackendId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByBackendIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByBankBackendId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bankBackendId', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByBankBackendIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bankBackendId', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByBankTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bankTitle', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByBankTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bankTitle', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByCompletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByCorrectAnswers() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correctAnswers', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByCorrectAnswersDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correctAnswers', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByDurationSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSeconds', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByDurationSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSeconds', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy> thenByScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByTotalQuestions() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalQuestions', Sort.asc);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QAfterSortBy>
  thenByTotalQuestionsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalQuestions', Sort.desc);
    });
  }
}

extension QuizResultModelQueryWhereDistinct
    on QueryBuilder<QuizResultModel, QuizResultModel, QDistinct> {
  QueryBuilder<QuizResultModel, QuizResultModel, QDistinct>
  distinctByBackendId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'backendId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QDistinct>
  distinctByBankBackendId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'bankBackendId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QDistinct>
  distinctByBankTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bankTitle', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QDistinct>
  distinctByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedAt');
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QDistinct>
  distinctByCorrectAnswers() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'correctAnswers');
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QDistinct>
  distinctByDurationSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'durationSeconds');
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QDistinct>
  distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QDistinct> distinctByScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'score');
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QDistinct> distinctByStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QuizResultModel, QuizResultModel, QDistinct>
  distinctByTotalQuestions() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalQuestions');
    });
  }
}

extension QuizResultModelQueryProperty
    on QueryBuilder<QuizResultModel, QuizResultModel, QQueryProperty> {
  QueryBuilder<QuizResultModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<QuizResultModel, List<QuizAnswerItem>, QQueryOperations>
  answersProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'answers');
    });
  }

  QueryBuilder<QuizResultModel, String, QQueryOperations> backendIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'backendId');
    });
  }

  QueryBuilder<QuizResultModel, String, QQueryOperations>
  bankBackendIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bankBackendId');
    });
  }

  QueryBuilder<QuizResultModel, String, QQueryOperations> bankTitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bankTitle');
    });
  }

  QueryBuilder<QuizResultModel, DateTime, QQueryOperations>
  completedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedAt');
    });
  }

  QueryBuilder<QuizResultModel, int, QQueryOperations>
  correctAnswersProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'correctAnswers');
    });
  }

  QueryBuilder<QuizResultModel, int, QQueryOperations>
  durationSecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'durationSeconds');
    });
  }

  QueryBuilder<QuizResultModel, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<QuizResultModel, double, QQueryOperations> scoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'score');
    });
  }

  QueryBuilder<QuizResultModel, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<QuizResultModel, int, QQueryOperations>
  totalQuestionsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalQuestions');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const QuizAnswerItemSchema = Schema(
  name: r'QuizAnswerItem',
  id: ((820738751 << 32) + 3447932909),
  properties: {
    r'correctAnswer': PropertySchema(
      id: 0,
      name: r'correctAnswer',
      type: IsarType.string,
    ),
    r'isCorrect': PropertySchema(
      id: 1,
      name: r'isCorrect',
      type: IsarType.bool,
    ),
    r'questionBackendId': PropertySchema(
      id: 2,
      name: r'questionBackendId',
      type: IsarType.string,
    ),
    r'selectedAnswer': PropertySchema(
      id: 3,
      name: r'selectedAnswer',
      type: IsarType.string,
    ),
  },

  estimateSize: _quizAnswerItemEstimateSize,
  serialize: _quizAnswerItemSerialize,
  deserialize: _quizAnswerItemDeserialize,
  deserializeProp: _quizAnswerItemDeserializeProp,
);

int _quizAnswerItemEstimateSize(
  QuizAnswerItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.correctAnswer.length * 3;
  bytesCount += 3 + object.questionBackendId.length * 3;
  bytesCount += 3 + object.selectedAnswer.length * 3;
  return bytesCount;
}

void _quizAnswerItemSerialize(
  QuizAnswerItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.correctAnswer);
  writer.writeBool(offsets[1], object.isCorrect);
  writer.writeString(offsets[2], object.questionBackendId);
  writer.writeString(offsets[3], object.selectedAnswer);
}

QuizAnswerItem _quizAnswerItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = QuizAnswerItem(
    correctAnswer: reader.readStringOrNull(offsets[0]) ?? '',
    isCorrect: reader.readBoolOrNull(offsets[1]) ?? false,
    questionBackendId: reader.readStringOrNull(offsets[2]) ?? '',
    selectedAnswer: reader.readStringOrNull(offsets[3]) ?? '',
  );
  return object;
}

P _quizAnswerItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 1:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 2:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 3:
      return (reader.readStringOrNull(offset) ?? '') as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension QuizAnswerItemQueryFilter
    on QueryBuilder<QuizAnswerItem, QuizAnswerItem, QFilterCondition> {
  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  correctAnswerEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'correctAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  correctAnswerGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'correctAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  correctAnswerLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'correctAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  correctAnswerBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'correctAnswer',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  correctAnswerStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'correctAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  correctAnswerEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'correctAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  correctAnswerContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'correctAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  correctAnswerMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'correctAnswer',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  correctAnswerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'correctAnswer', value: ''),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  correctAnswerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'correctAnswer', value: ''),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  isCorrectEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isCorrect', value: value),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  questionBackendIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'questionBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  questionBackendIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'questionBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  questionBackendIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'questionBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  questionBackendIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'questionBackendId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  questionBackendIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'questionBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  questionBackendIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'questionBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  questionBackendIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'questionBackendId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  questionBackendIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'questionBackendId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  questionBackendIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'questionBackendId', value: ''),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  questionBackendIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'questionBackendId', value: ''),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  selectedAnswerEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'selectedAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  selectedAnswerGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'selectedAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  selectedAnswerLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'selectedAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  selectedAnswerBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'selectedAnswer',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  selectedAnswerStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'selectedAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  selectedAnswerEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'selectedAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  selectedAnswerContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'selectedAnswer',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  selectedAnswerMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'selectedAnswer',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  selectedAnswerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'selectedAnswer', value: ''),
      );
    });
  }

  QueryBuilder<QuizAnswerItem, QuizAnswerItem, QAfterFilterCondition>
  selectedAnswerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'selectedAnswer', value: ''),
      );
    });
  }
}

extension QuizAnswerItemQueryObject
    on QueryBuilder<QuizAnswerItem, QuizAnswerItem, QFilterCondition> {}
