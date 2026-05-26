// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocabulary_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetVocabularyModelCollection on Isar {
  IsarCollection<VocabularyModel> get vocabularyModels => this.collection();
}

const VocabularyModelSchema = CollectionSchema(
  name: r'VocabularyModel',
  id: -408305115005495936,
  properties: {
    r'backendId': PropertySchema(
      id: 0,
      name: r'backendId',
      type: IsarType.string,
    ),
    r'category': PropertySchema(
      id: 1,
      name: r'category',
      type: IsarType.string,
    ),
    r'categoryId': PropertySchema(
      id: 2,
      name: r'categoryId',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'example': PropertySchema(id: 4, name: r'example', type: IsarType.string),
    r'isDeleted': PropertySchema(
      id: 5,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isStarred': PropertySchema(
      id: 6,
      name: r'isStarred',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(id: 7, name: r'isSynced', type: IsarType.bool),
    r'lastTestedAt': PropertySchema(
      id: 8,
      name: r'lastTestedAt',
      type: IsarType.dateTime,
    ),
    r'masteryLevel': PropertySchema(
      id: 9,
      name: r'masteryLevel',
      type: IsarType.long,
    ),
    r'pronunciation': PropertySchema(
      id: 10,
      name: r'pronunciation',
      type: IsarType.string,
    ),
    r'sourceLanguage': PropertySchema(
      id: 11,
      name: r'sourceLanguage',
      type: IsarType.string,
    ),
    r'targetLanguage': PropertySchema(
      id: 12,
      name: r'targetLanguage',
      type: IsarType.string,
    ),
    r'translation': PropertySchema(
      id: 13,
      name: r'translation',
      type: IsarType.string,
    ),
    r'translationId': PropertySchema(
      id: 14,
      name: r'translationId',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 15,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'word': PropertySchema(id: 16, name: r'word', type: IsarType.string),
  },

  estimateSize: _vocabularyModelEstimateSize,
  serialize: _vocabularyModelSerialize,
  deserialize: _vocabularyModelDeserialize,
  deserializeProp: _vocabularyModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'backendId': IndexSchema(
      id: 8781752057772026880,
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
    r'category': IndexSchema(
      id: -7560358558326324224,
      name: r'category',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'category',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'createdAt': IndexSchema(
      id: -3433535483987302400,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _vocabularyModelGetId,
  getLinks: _vocabularyModelGetLinks,
  attach: _vocabularyModelAttach,
  version: '3.3.2',
);

int _vocabularyModelEstimateSize(
  VocabularyModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.backendId.length * 3;
  bytesCount += 3 + object.category.length * 3;
  {
    final value = object.example;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.pronunciation;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sourceLanguage.length * 3;
  bytesCount += 3 + object.targetLanguage.length * 3;
  bytesCount += 3 + object.translation.length * 3;
  bytesCount += 3 + object.word.length * 3;
  return bytesCount;
}

void _vocabularyModelSerialize(
  VocabularyModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.backendId);
  writer.writeString(offsets[1], object.category);
  writer.writeLong(offsets[2], object.categoryId);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeString(offsets[4], object.example);
  writer.writeBool(offsets[5], object.isDeleted);
  writer.writeBool(offsets[6], object.isStarred);
  writer.writeBool(offsets[7], object.isSynced);
  writer.writeDateTime(offsets[8], object.lastTestedAt);
  writer.writeLong(offsets[9], object.masteryLevel);
  writer.writeString(offsets[10], object.pronunciation);
  writer.writeString(offsets[11], object.sourceLanguage);
  writer.writeString(offsets[12], object.targetLanguage);
  writer.writeString(offsets[13], object.translation);
  writer.writeLong(offsets[14], object.translationId);
  writer.writeDateTime(offsets[15], object.updatedAt);
  writer.writeString(offsets[16], object.word);
}

VocabularyModel _vocabularyModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = VocabularyModel(
    backendId: reader.readString(offsets[0]),
    category: reader.readStringOrNull(offsets[1]) ?? 'Chưa phân loại',
    categoryId: reader.readLongOrNull(offsets[2]),
    createdAt: reader.readDateTime(offsets[3]),
    example: reader.readStringOrNull(offsets[4]),
    isDeleted: reader.readBoolOrNull(offsets[5]) ?? false,
    isStarred: reader.readBoolOrNull(offsets[6]) ?? false,
    isSynced: reader.readBoolOrNull(offsets[7]) ?? false,
    lastTestedAt: reader.readDateTimeOrNull(offsets[8]),
    masteryLevel: reader.readLongOrNull(offsets[9]) ?? 0,
    pronunciation: reader.readStringOrNull(offsets[10]),
    sourceLanguage: reader.readString(offsets[11]),
    targetLanguage: reader.readString(offsets[12]),
    translation: reader.readString(offsets[13]),
    translationId: reader.readLongOrNull(offsets[14]),
    updatedAt: reader.readDateTime(offsets[15]),
    word: reader.readString(offsets[16]),
  );
  object.id = id;
  return object;
}

P _vocabularyModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset) ?? 'Chưa phân loại') as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 6:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 7:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 8:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 9:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readLongOrNull(offset)) as P;
    case 15:
      return (reader.readDateTime(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _vocabularyModelGetId(VocabularyModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _vocabularyModelGetLinks(VocabularyModel object) {
  return [];
}

void _vocabularyModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  VocabularyModel object,
) {
  object.id = id;
}

extension VocabularyModelByIndex on IsarCollection<VocabularyModel> {
  Future<VocabularyModel?> getByBackendId(String backendId) {
    return getByIndex(r'backendId', [backendId]);
  }

  VocabularyModel? getByBackendIdSync(String backendId) {
    return getByIndexSync(r'backendId', [backendId]);
  }

  Future<bool> deleteByBackendId(String backendId) {
    return deleteByIndex(r'backendId', [backendId]);
  }

  bool deleteByBackendIdSync(String backendId) {
    return deleteByIndexSync(r'backendId', [backendId]);
  }

  Future<List<VocabularyModel?>> getAllByBackendId(
    List<String> backendIdValues,
  ) {
    final values = backendIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'backendId', values);
  }

  List<VocabularyModel?> getAllByBackendIdSync(List<String> backendIdValues) {
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

  Future<Id> putByBackendId(VocabularyModel object) {
    return putByIndex(r'backendId', object);
  }

  Id putByBackendIdSync(VocabularyModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'backendId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByBackendId(List<VocabularyModel> objects) {
    return putAllByIndex(r'backendId', objects);
  }

  List<Id> putAllByBackendIdSync(
    List<VocabularyModel> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'backendId', objects, saveLinks: saveLinks);
  }
}

extension VocabularyModelQueryWhereSort
    on QueryBuilder<VocabularyModel, VocabularyModel, QWhere> {
  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }
}

extension VocabularyModelQueryWhere
    on QueryBuilder<VocabularyModel, VocabularyModel, QWhereClause> {
  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause> idBetween(
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause>
  backendIdEqualTo(String backendId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'backendId', value: [backendId]),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause>
  categoryEqualTo(String category) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'category', value: [category]),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause>
  categoryNotEqualTo(String category) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'category',
                lower: [],
                upper: [category],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'category',
                lower: [category],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'category',
                lower: [category],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'category',
                lower: [],
                upper: [category],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause>
  createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'createdAt', value: [createdAt]),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause>
  createdAtNotEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause>
  createdAtGreaterThan(DateTime createdAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [createdAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause>
  createdAtLessThan(DateTime createdAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [],
          upper: [createdAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterWhereClause>
  createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [lowerCreatedAt],
          includeLower: includeLower,
          upper: [upperCreatedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension VocabularyModelQueryFilter
    on QueryBuilder<VocabularyModel, VocabularyModel, QFilterCondition> {
  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  backendIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'backendId', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  backendIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'backendId', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'category',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'category',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'category', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'category', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'categoryId'),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'categoryId'),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'categoryId', value: value),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryIdGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'categoryId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryIdLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'categoryId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  categoryIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'categoryId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'example'),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'example'),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'example',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'example',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'example',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'example',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'example',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'example',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'example',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'example',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'example', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  exampleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'example', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
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

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isDeleted', value: value),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  isStarredEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isStarred', value: value),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isSynced', value: value),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  lastTestedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastTestedAt'),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  lastTestedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastTestedAt'),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  lastTestedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastTestedAt', value: value),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  lastTestedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastTestedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  lastTestedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastTestedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  lastTestedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastTestedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  masteryLevelEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'masteryLevel', value: value),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  masteryLevelGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'masteryLevel',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  masteryLevelLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'masteryLevel',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  masteryLevelBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'masteryLevel',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'pronunciation'),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'pronunciation'),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'pronunciation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pronunciation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pronunciation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pronunciation',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'pronunciation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'pronunciation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'pronunciation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'pronunciation',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pronunciation', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  pronunciationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pronunciation', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  sourceLanguageEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  sourceLanguageGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  sourceLanguageLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  sourceLanguageBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceLanguage',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  sourceLanguageStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sourceLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  sourceLanguageEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sourceLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  sourceLanguageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sourceLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  sourceLanguageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sourceLanguage',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  sourceLanguageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceLanguage', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  sourceLanguageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sourceLanguage', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  targetLanguageEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'targetLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  targetLanguageGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'targetLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  targetLanguageLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'targetLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  targetLanguageBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'targetLanguage',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  targetLanguageStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'targetLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  targetLanguageEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'targetLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  targetLanguageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'targetLanguage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  targetLanguageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'targetLanguage',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  targetLanguageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'targetLanguage', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  targetLanguageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'targetLanguage', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'translation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'translation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'translation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'translation',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'translation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'translation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'translation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'translation',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'translation', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'translation', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'translationId'),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'translationId'),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'translationId', value: value),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationIdGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'translationId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationIdLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'translationId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  translationIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'translationId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  updatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  wordEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'word',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  wordGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'word',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  wordLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'word',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  wordBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'word',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  wordStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'word',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  wordEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'word',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  wordContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'word',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  wordMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'word',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  wordIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'word', value: ''),
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterFilterCondition>
  wordIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'word', value: ''),
      );
    });
  }
}

extension VocabularyModelQueryObject
    on QueryBuilder<VocabularyModel, VocabularyModel, QFilterCondition> {}

extension VocabularyModelQueryLinks
    on QueryBuilder<VocabularyModel, VocabularyModel, QFilterCondition> {}

extension VocabularyModelQuerySortBy
    on QueryBuilder<VocabularyModel, VocabularyModel, QSortBy> {
  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByBackendId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByBackendIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByCategoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByCategoryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy> sortByExample() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'example', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByExampleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'example', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByIsStarred() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isStarred', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByIsStarredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isStarred', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByLastTestedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTestedAt', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByLastTestedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTestedAt', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByMasteryLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'masteryLevel', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByMasteryLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'masteryLevel', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByPronunciation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pronunciation', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByPronunciationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pronunciation', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortBySourceLanguage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLanguage', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortBySourceLanguageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLanguage', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByTargetLanguage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLanguage', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByTargetLanguageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLanguage', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByTranslation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translation', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByTranslationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translation', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByTranslationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translationId', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByTranslationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translationId', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy> sortByWord() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'word', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  sortByWordDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'word', Sort.desc);
    });
  }
}

extension VocabularyModelQuerySortThenBy
    on QueryBuilder<VocabularyModel, VocabularyModel, QSortThenBy> {
  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByBackendId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByBackendIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByCategoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByCategoryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy> thenByExample() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'example', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByExampleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'example', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByIsStarred() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isStarred', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByIsStarredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isStarred', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByLastTestedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTestedAt', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByLastTestedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTestedAt', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByMasteryLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'masteryLevel', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByMasteryLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'masteryLevel', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByPronunciation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pronunciation', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByPronunciationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pronunciation', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenBySourceLanguage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLanguage', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenBySourceLanguageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLanguage', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByTargetLanguage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLanguage', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByTargetLanguageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLanguage', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByTranslation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translation', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByTranslationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translation', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByTranslationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translationId', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByTranslationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'translationId', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy> thenByWord() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'word', Sort.asc);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QAfterSortBy>
  thenByWordDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'word', Sort.desc);
    });
  }
}

extension VocabularyModelQueryWhereDistinct
    on QueryBuilder<VocabularyModel, VocabularyModel, QDistinct> {
  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByBackendId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'backendId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct> distinctByCategory({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByCategoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categoryId');
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct> distinctByExample({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'example', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByIsStarred() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isStarred');
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByLastTestedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastTestedAt');
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByMasteryLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'masteryLevel');
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByPronunciation({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'pronunciation',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctBySourceLanguage({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'sourceLanguage',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByTargetLanguage({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'targetLanguage',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByTranslation({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'translation', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByTranslationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'translationId');
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<VocabularyModel, VocabularyModel, QDistinct> distinctByWord({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'word', caseSensitive: caseSensitive);
    });
  }
}

extension VocabularyModelQueryProperty
    on QueryBuilder<VocabularyModel, VocabularyModel, QQueryProperty> {
  QueryBuilder<VocabularyModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<VocabularyModel, String, QQueryOperations> backendIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'backendId');
    });
  }

  QueryBuilder<VocabularyModel, String, QQueryOperations> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<VocabularyModel, int?, QQueryOperations> categoryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categoryId');
    });
  }

  QueryBuilder<VocabularyModel, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<VocabularyModel, String?, QQueryOperations> exampleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'example');
    });
  }

  QueryBuilder<VocabularyModel, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<VocabularyModel, bool, QQueryOperations> isStarredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isStarred');
    });
  }

  QueryBuilder<VocabularyModel, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<VocabularyModel, DateTime?, QQueryOperations>
  lastTestedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastTestedAt');
    });
  }

  QueryBuilder<VocabularyModel, int, QQueryOperations> masteryLevelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'masteryLevel');
    });
  }

  QueryBuilder<VocabularyModel, String?, QQueryOperations>
  pronunciationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pronunciation');
    });
  }

  QueryBuilder<VocabularyModel, String, QQueryOperations>
  sourceLanguageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceLanguage');
    });
  }

  QueryBuilder<VocabularyModel, String, QQueryOperations>
  targetLanguageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetLanguage');
    });
  }

  QueryBuilder<VocabularyModel, String, QQueryOperations>
  translationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'translation');
    });
  }

  QueryBuilder<VocabularyModel, int?, QQueryOperations>
  translationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'translationId');
    });
  }

  QueryBuilder<VocabularyModel, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<VocabularyModel, String, QQueryOperations> wordProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'word');
    });
  }
}
