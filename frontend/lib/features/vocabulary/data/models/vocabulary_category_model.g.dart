// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocabulary_category_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetVocabularyCategoryModelCollection on Isar {
  IsarCollection<VocabularyCategoryModel> get vocabularyCategoryModels =>
      this.collection();
}

const VocabularyCategoryModelSchema = CollectionSchema(
  name: r'VocabularyCategoryModel',
  id: ((663710833 << 32) + 517665016),
  properties: {
    r'backendId': PropertySchema(
      id: 0,
      name: r'backendId',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'isDeleted': PropertySchema(
      id: 2,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(id: 3, name: r'isSynced', type: IsarType.bool),
    r'name': PropertySchema(id: 4, name: r'name', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 5,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _vocabularyCategoryModelEstimateSize,
  serialize: _vocabularyCategoryModelSerialize,
  deserialize: _vocabularyCategoryModelDeserialize,
  deserializeProp: _vocabularyCategoryModelDeserializeProp,
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
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'createdAt': IndexSchema(
      id: -((799432276 << 32) + 3200456888),
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

  getId: _vocabularyCategoryModelGetId,
  getLinks: _vocabularyCategoryModelGetLinks,
  attach: _vocabularyCategoryModelAttach,
  version: '3.3.2',
);

int _vocabularyCategoryModelEstimateSize(
  VocabularyCategoryModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _vocabularyCategoryModelSerialize(
  VocabularyCategoryModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.backendId);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeBool(offsets[2], object.isDeleted);
  writer.writeBool(offsets[3], object.isSynced);
  writer.writeString(offsets[4], object.name);
  writer.writeDateTime(offsets[5], object.updatedAt);
}

VocabularyCategoryModel _vocabularyCategoryModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = VocabularyCategoryModel(
    backendId: reader.readLong(offsets[0]),
    createdAt: reader.readDateTime(offsets[1]),
    isDeleted: reader.readBoolOrNull(offsets[2]) ?? false,
    isSynced: reader.readBoolOrNull(offsets[3]) ?? false,
    name: reader.readString(offsets[4]),
    updatedAt: reader.readDateTime(offsets[5]),
  );
  object.id = id;
  return object;
}

P _vocabularyCategoryModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 3:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _vocabularyCategoryModelGetId(VocabularyCategoryModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _vocabularyCategoryModelGetLinks(
  VocabularyCategoryModel object,
) {
  return [];
}

void _vocabularyCategoryModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  VocabularyCategoryModel object,
) {
  object.id = id;
}

extension VocabularyCategoryModelByIndex
    on IsarCollection<VocabularyCategoryModel> {
  Future<VocabularyCategoryModel?> getByBackendId(int backendId) {
    return getByIndex(r'backendId', [backendId]);
  }

  VocabularyCategoryModel? getByBackendIdSync(int backendId) {
    return getByIndexSync(r'backendId', [backendId]);
  }

  Future<bool> deleteByBackendId(int backendId) {
    return deleteByIndex(r'backendId', [backendId]);
  }

  bool deleteByBackendIdSync(int backendId) {
    return deleteByIndexSync(r'backendId', [backendId]);
  }

  Future<List<VocabularyCategoryModel?>> getAllByBackendId(
    List<int> backendIdValues,
  ) {
    final values = backendIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'backendId', values);
  }

  List<VocabularyCategoryModel?> getAllByBackendIdSync(
    List<int> backendIdValues,
  ) {
    final values = backendIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'backendId', values);
  }

  Future<int> deleteAllByBackendId(List<int> backendIdValues) {
    final values = backendIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'backendId', values);
  }

  int deleteAllByBackendIdSync(List<int> backendIdValues) {
    final values = backendIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'backendId', values);
  }

  Future<Id> putByBackendId(VocabularyCategoryModel object) {
    return putByIndex(r'backendId', object);
  }

  Id putByBackendIdSync(
    VocabularyCategoryModel object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'backendId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByBackendId(List<VocabularyCategoryModel> objects) {
    return putAllByIndex(r'backendId', objects);
  }

  List<Id> putAllByBackendIdSync(
    List<VocabularyCategoryModel> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'backendId', objects, saveLinks: saveLinks);
  }
}

extension VocabularyCategoryModelQueryWhereSort
    on QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QWhere> {
  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterWhere>
  anyBackendId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'backendId'),
      );
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterWhere>
  anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }
}

extension VocabularyCategoryModelQueryWhere
    on
        QueryBuilder<
          VocabularyCategoryModel,
          VocabularyCategoryModel,
          QWhereClause
        > {
  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
  idBetween(
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
  backendIdEqualTo(int backendId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'backendId', value: [backendId]),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
  backendIdNotEqualTo(int backendId) {
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
  backendIdGreaterThan(int backendId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'backendId',
          lower: [backendId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
  backendIdLessThan(int backendId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'backendId',
          lower: [],
          upper: [backendId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
  backendIdBetween(
    int lowerBackendId,
    int upperBackendId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'backendId',
          lower: [lowerBackendId],
          includeLower: includeLower,
          upper: [upperBackendId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
  createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'createdAt', value: [createdAt]),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterWhereClause
  >
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

extension VocabularyCategoryModelQueryFilter
    on
        QueryBuilder<
          VocabularyCategoryModel,
          VocabularyCategoryModel,
          QFilterCondition
        > {
  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  backendIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'backendId', value: value),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  backendIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'backendId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  backendIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'backendId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  backendIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'backendId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isDeleted', value: value),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isSynced', value: value),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    VocabularyCategoryModel,
    VocabularyCategoryModel,
    QAfterFilterCondition
  >
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
}

extension VocabularyCategoryModelQueryObject
    on
        QueryBuilder<
          VocabularyCategoryModel,
          VocabularyCategoryModel,
          QFilterCondition
        > {}

extension VocabularyCategoryModelQueryLinks
    on
        QueryBuilder<
          VocabularyCategoryModel,
          VocabularyCategoryModel,
          QFilterCondition
        > {}

extension VocabularyCategoryModelQuerySortBy
    on QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QSortBy> {
  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByBackendId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByBackendIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.desc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension VocabularyCategoryModelQuerySortThenBy
    on
        QueryBuilder<
          VocabularyCategoryModel,
          VocabularyCategoryModel,
          QSortThenBy
        > {
  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByBackendId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByBackendIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backendId', Sort.desc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension VocabularyCategoryModelQueryWhereDistinct
    on
        QueryBuilder<
          VocabularyCategoryModel,
          VocabularyCategoryModel,
          QDistinct
        > {
  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QDistinct>
  distinctByBackendId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'backendId');
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QDistinct>
  distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QDistinct>
  distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<VocabularyCategoryModel, VocabularyCategoryModel, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension VocabularyCategoryModelQueryProperty
    on
        QueryBuilder<
          VocabularyCategoryModel,
          VocabularyCategoryModel,
          QQueryProperty
        > {
  QueryBuilder<VocabularyCategoryModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<VocabularyCategoryModel, int, QQueryOperations>
  backendIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'backendId');
    });
  }

  QueryBuilder<VocabularyCategoryModel, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<VocabularyCategoryModel, bool, QQueryOperations>
  isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<VocabularyCategoryModel, bool, QQueryOperations>
  isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<VocabularyCategoryModel, String, QQueryOperations>
  nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<VocabularyCategoryModel, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
