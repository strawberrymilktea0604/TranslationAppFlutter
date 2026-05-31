// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_cursor_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSyncCursorModelCollection on Isar {
  IsarCollection<SyncCursorModel> get syncCursorModels => this.collection();
}

const SyncCursorModelSchema = CollectionSchema(
  name: r'SyncCursorModel',
  id: -5633630139823007711,
  properties: {
    r'cursorValue': PropertySchema(
      id: 0,
      name: r'cursorValue',
      type: IsarType.string,
    ),
    r'lastSyncAt': PropertySchema(
      id: 1,
      name: r'lastSyncAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _syncCursorModelEstimateSize,
  serialize: _syncCursorModelSerialize,
  deserialize: _syncCursorModelDeserialize,
  deserializeProp: _syncCursorModelDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _syncCursorModelGetId,
  getLinks: _syncCursorModelGetLinks,
  attach: _syncCursorModelAttach,
  version: '3.3.2',
);

int _syncCursorModelEstimateSize(
  SyncCursorModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cursorValue.length * 3;
  return bytesCount;
}

void _syncCursorModelSerialize(
  SyncCursorModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cursorValue);
  writer.writeDateTime(offsets[1], object.lastSyncAt);
}

SyncCursorModel _syncCursorModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SyncCursorModel(
    cursorValue: reader.readString(offsets[0]),
    lastSyncAt: reader.readDateTime(offsets[1]),
  );
  object.id = id;
  return object;
}

P _syncCursorModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _syncCursorModelGetId(SyncCursorModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _syncCursorModelGetLinks(SyncCursorModel object) {
  return [];
}

void _syncCursorModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  SyncCursorModel object,
) {
  object.id = id;
}

extension SyncCursorModelQueryWhereSort
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QWhere> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SyncCursorModelQueryWhere
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QWhereClause> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhereClause>
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

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterWhereClause> idBetween(
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
}

extension SyncCursorModelQueryFilter
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QFilterCondition> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  cursorValueEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'cursorValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  cursorValueGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cursorValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  cursorValueLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cursorValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  cursorValueBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cursorValue',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  cursorValueStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'cursorValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  cursorValueEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'cursorValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  cursorValueContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'cursorValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  cursorValueMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'cursorValue',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  cursorValueIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cursorValue', value: ''),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  cursorValueIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cursorValue', value: ''),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
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

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
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

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
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

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  lastSyncAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSyncAt', value: value),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  lastSyncAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSyncAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  lastSyncAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSyncAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterFilterCondition>
  lastSyncAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSyncAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SyncCursorModelQueryObject
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QFilterCondition> {}

extension SyncCursorModelQueryLinks
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QFilterCondition> {}

extension SyncCursorModelQuerySortBy
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QSortBy> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  sortByCursorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cursorValue', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  sortByCursorValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cursorValue', Sort.desc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  sortByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  sortByLastSyncAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.desc);
    });
  }
}

extension SyncCursorModelQuerySortThenBy
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QSortThenBy> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  thenByCursorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cursorValue', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  thenByCursorValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cursorValue', Sort.desc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  thenByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QAfterSortBy>
  thenByLastSyncAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.desc);
    });
  }
}

extension SyncCursorModelQueryWhereDistinct
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QDistinct> {
  QueryBuilder<SyncCursorModel, SyncCursorModel, QDistinct>
  distinctByCursorValue({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cursorValue', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncCursorModel, SyncCursorModel, QDistinct>
  distinctByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSyncAt');
    });
  }
}

extension SyncCursorModelQueryProperty
    on QueryBuilder<SyncCursorModel, SyncCursorModel, QQueryProperty> {
  QueryBuilder<SyncCursorModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SyncCursorModel, String, QQueryOperations>
  cursorValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cursorValue');
    });
  }

  QueryBuilder<SyncCursorModel, DateTime, QQueryOperations>
  lastSyncAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSyncAt');
    });
  }
}
