<#--
// Licensed to the Apache Software Foundation (ASF) under one or more
// contributor license agreements.  See the NOTICE file distributed with
// this work for additional information regarding copyright ownership.
// The ASF licenses this file to you under the Apache License, Version 2.0
// (the "License"); you may not use this file except in compliance with
// the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
-->

SqlCharStringLiteral createStringLiteral(String s, SqlParserPos pos) :
{
}
{
    { return SqlLiteral.createCharString(SqlParserUtil.parseString(s), pos); }
}

/**
* Parse a "Show Databases" metadata query command.
*/
SqlShowDatabases SqlShowDatabases() :
{
}
{
    <SHOW> <DATABASES>
    {
        return new SqlShowDatabases(getPos());
    }
}

SqlUseDatabase SqlUseDatabase() :
{
    SqlIdentifier databaseName;
    SqlParserPos pos;
}
{
    <USE> { pos = getPos();}
    databaseName = CompoundIdentifier()
    {
        return new SqlUseDatabase(pos, databaseName);
    }
}

/**
* Parses a create database statement.
*/
SqlCreate SqlCreateDatabase(Span s, boolean replace) :
{
    SqlParserPos startPos;
    SqlIdentifier databaseName;
    SqlCharStringLiteral comment = null;
    SqlCharStringLiteral location = null;
    SqlNodeList propertyList;
    boolean ifNotExists = false;
}
{
    ( <DATABASE> | <SCHEMA> )
      {
        startPos = getPos();
        propertyList = new SqlNodeList(startPos);
      }
    [ LOOKAHEAD(3)
      <IF> <NOT> <EXISTS> { ifNotExists = true; }
    ]
    databaseName = CompoundIdentifier()
    [ <COMMENT> <QUOTED_STRING>
        {
            comment = createStringLiteral(token.image, getPos());
        }
    ]
    [
      <LOCATION> <QUOTED_STRING>
        {
            location = createStringLiteral(token.image, getPos());
        }
    ]
    [
        <WITH> <DBPROPERTIES>
        propertyList = TableProperties()
    ]

    { return new SqlCreateHiveDatabase(startPos.plus(getPos()),
                    databaseName,
                    propertyList,
                    comment,
                    location,
                    ifNotExists); }

}

SqlAlterDatabase SqlAlterDatabase() :
{
    SqlParserPos startPos;
    SqlIdentifier databaseName;
    SqlNodeList propertyList;
    SqlAlterDatabase alter;
    String ownerType;
    SqlIdentifier ownerName;
}
{
    <ALTER> ( <DATABASE> | <SCHEMA> ) { startPos = getPos(); }
    databaseName = CompoundIdentifier()
    <SET>
    (
        <DBPROPERTIES>
        propertyList = TableProperties()
            {
                alter = new SqlAlterHiveDatabaseProps(startPos.plus(getPos()), databaseName, propertyList);
            }
        |
        <LOCATION> <QUOTED_STRING>
            {
                SqlCharStringLiteral location = createStringLiteral(token.image, getPos());
                alter = new SqlAlterHiveDatabaseLocation(startPos.plus(getPos()), databaseName, location);
            }
        |
        <OWNER>
            (   <USER> { ownerType = SqlAlterHiveDatabaseOwner.USER_OWNER; }
                |
                <ROLE> { ownerType = SqlAlterHiveDatabaseOwner.ROLE_OWNER; }
            )
            ownerName = SimpleIdentifier()
            {
                alter = new SqlAlterHiveDatabaseOwner(startPos.plus(getPos()), databaseName, ownerType, ownerName);
            }
    )

    {
        return alter;
    }
}

SqlDrop SqlDropDatabase(Span s, boolean replace) :
{
    SqlIdentifier databaseName = null;
    boolean ifExists = false;
    boolean cascade = false;
}
{
    ( <DATABASE> | <SCHEMA> )

    (
        <IF> <EXISTS> { ifExists = true; }
    |
        { ifExists = false; }
    )

    databaseName = CompoundIdentifier()
    [
                <RESTRICT> { cascade = false; }
        |
                <CASCADE>  { cascade = true; }
    ]

    {
         return new SqlDropDatabase(s.pos(), databaseName, ifExists, cascade);
    }
}

SqlDescribeDatabase SqlDescribeDatabase() :
{
    SqlIdentifier databaseName;
    SqlParserPos pos;
    boolean isExtended = false;
}
{
    <DESCRIBE> ( <DATABASE> | <SCHEMA> ) { pos = getPos();}
    [ <EXTENDED> { isExtended = true;} ]
    databaseName = CompoundIdentifier()
    {
        return new SqlDescribeDatabase(pos, databaseName, isExtended);
    }

}

/** Parse a table properties. */
SqlNodeList TableProperties():
{
    SqlNode property;
    final List<SqlNode> proList = new ArrayList<SqlNode>();
    final Span span;
}
{
    <LPAREN> { span = span(); }
    [
        property = TableOption()
        {
            proList.add(property);
        }
        (
            <COMMA> property = TableOption()
            {
                proList.add(property);
            }
        )*
    ]
    <RPAREN>
    {  return new SqlNodeList(proList, span.end(this)); }
}

SqlNode TableOption() :
{
    SqlNode key;
    SqlNode value;
    SqlParserPos pos;
}
{
    key = StringLiteral()
    { pos = getPos(); }
    <EQ> value = StringLiteral()
    {
        return new SqlTableOption(key, value, getPos());
    }
}


SqlCreate SqlCreateTemporary(Span s, boolean replace) :
{
  boolean isTemporary = false;
  SqlCreate create;
}
{
  [ <TEMPORARY>   {isTemporary = true;} ]

  create = SqlCreateTable(s, isTemporary)
  {
    return create;
  }
}

/**
* Parse a "Show Tables" metadata query command.
*/
SqlShowTables SqlShowTables() :
{
}
{
    <SHOW> <TABLES>
    {
        return new SqlShowTables(getPos());
    }
}

/**
 * Here we add Rich in className to distinguish from calcite's original SqlDescribeTable.
 */
SqlRichDescribeTable SqlRichDescribeTable() :
{
    SqlIdentifier tableName;
    SqlParserPos pos;
    boolean extended = false;
    boolean formatted = false;
}
{
    <DESCRIBE> { pos = getPos();}
    [ LOOKAHEAD(2)
      ( <EXTENDED> { extended = true; }
        |
        <FORMATTED> { formatted = true; }
      )
    ]
    tableName = CompoundIdentifier()
    {
        return new SqlDescribeHiveTable(pos, tableName, extended, formatted);
    }
}

SqlCreate SqlCreateTable(Span s, boolean isTemporary) :
{
    final SqlParserPos startPos = s.pos();
    SqlIdentifier tableName;
    SqlNodeList primaryKeyList = SqlNodeList.EMPTY;
    List<SqlNodeList> uniqueKeysList = new ArrayList<SqlNodeList>();
    SqlNodeList columnList = SqlNodeList.EMPTY;
	SqlCharStringLiteral comment = null;

    SqlNodeList propertyList;
    SqlNodeList partitionColumns = SqlNodeList.EMPTY;
    SqlParserPos pos = startPos;
    boolean isExternal = false;
    HiveTableRowFormat rowFormat = null;
    HiveTableStoredAs storedAs = null;
    SqlCharStringLiteral location = null;
    HiveTableCreationContext ctx = new HiveTableCreationContext();
}
{
    [ <EXTERNAL> { isExternal = true; } ]
    <TABLE> { propertyList = new SqlNodeList(getPos()); }

    tableName = CompoundIdentifier()
    [
        <LPAREN> { pos = getPos(); }
        TableColumn(ctx)
        (
            <COMMA> TableColumn(ctx)
        )*
        {
            pos = pos.plus(getPos());
            columnList = new SqlNodeList(ctx.columnList, pos);
        }
        <RPAREN>
    ]
    [ <COMMENT> <QUOTED_STRING> {
        comment = createStringLiteral(token.image, getPos());
    }]
    [
        <PARTITIONED> <BY>
        <LPAREN>
          {
            List<SqlNode> partCols = new ArrayList();
            if ( columnList == SqlNodeList.EMPTY ) {
              columnList = new SqlNodeList(pos.plus(getPos()));
            }
          }
          PartColumnDef(partCols)
          (
            <COMMA> PartColumnDef(partCols)
          )*
          {
            partitionColumns = new SqlNodeList(partCols, pos.plus(getPos()));
          }
        <RPAREN>
    ]
    [
      <ROW> <FORMAT>
      rowFormat = TableRowFormat(getPos())
    ]
    [
      <STORED> <AS>
      storedAs = TableStoredAs(getPos())
    ]
    [
      <LOCATION> <QUOTED_STRING>
      { location = createStringLiteral(token.image, getPos()); }
    ]
    [
        <TBLPROPERTIES>
        {
          SqlNodeList props = TableProperties();
          for (SqlNode node : props) {
            propertyList.add(node);
          }
        }
    ]
    {
        return new SqlCreateHiveTable(startPos.plus(getPos()),
                tableName,
                columnList,
                ctx,
                propertyList,
                partitionColumns,
                comment,
                isTemporary,
                isExternal,
                rowFormat,
                storedAs,
                location);
    }
}

SqlDrop SqlDropTable(Span s, boolean replace) :
{
    SqlIdentifier tableName = null;
    boolean ifExists = false;
}
{
    <TABLE>

    (
        <IF> <EXISTS> { ifExists = true; }
    |
        { ifExists = false; }
    )

    tableName = CompoundIdentifier()

    {
         return new SqlDropTable(s.pos(), tableName, ifExists, false);
    }
}

void TableColumn2(List<SqlNode> list) :
{
    SqlParserPos pos;
    SqlIdentifier name;
    SqlDataTypeSpec type;
    SqlCharStringLiteral comment = null;
}
{
    name = SimpleIdentifier()
    type = ExtendedDataType()
    [ <COMMENT> <QUOTED_STRING> {
        comment = createStringLiteral(token.image, getPos());
    }]
    {
        SqlTableColumn tableColumn = new SqlTableColumn(name, type, null, comment, getPos());
        list.add(tableColumn);
    }
}

void PartColumnDef(List<SqlNode> list) :
{
    SqlParserPos pos;
    SqlIdentifier name;
    SqlDataTypeSpec type;
    SqlCharStringLiteral comment = null;
}
{
    name = SimpleIdentifier()
    type = DataType()
    [ <COMMENT> <QUOTED_STRING> {
        comment = createStringLiteral(token.image, getPos());
    }]
    {
        type = type.withNullable(true);
        SqlTableColumn tableColumn = new SqlTableColumn(name, type, null, comment, getPos());
        list.add(tableColumn);
    }
}

void TableColumn(HiveTableCreationContext context) :
{
}
{
    (LOOKAHEAD(2)
        TableColumnWithConstraint(context)
    |
        TableConstraint(context)
    )
}

/** Parses a table constraint for CREATE TABLE. */
void TableConstraint(HiveTableCreationContext context) :
{
  SqlIdentifier constraintName = null;
  final SqlLiteral spec;
  final SqlNodeList columns;
}
{
  [ constraintName = ConstraintName() ]
  spec = TableConstraintSpec()
  columns = ParenthesizedSimpleIdentifierList()
  context.pkTrait = ConstraintTrait()
  {
      SqlTableConstraint tableConstraint = new SqlTableConstraint(
                                            constraintName,
                                            spec,
                                            columns,
                                            SqlConstraintEnforcement.NOT_ENFORCED.symbol(getPos()),
                                            true,
                                            getPos());
      context.constraints.add(tableConstraint);
  }
}

SqlLiteral TableConstraintSpec() :
{
    SqlLiteral spec;
}
{
    <PRIMARY> <KEY>
    {
        spec = SqlUniqueSpec.PRIMARY_KEY.symbol(getPos());
        return spec;
    }
}

SqlIdentifier ConstraintName() :
{
    SqlIdentifier constraintName;
}
{
    <CONSTRAINT> constraintName = SimpleIdentifier() {
        return constraintName;
    }
}

void TableColumnWithConstraint(HiveTableCreationContext context) :
{
    SqlParserPos pos;
    SqlIdentifier name;
    SqlDataTypeSpec type;
    SqlCharStringLiteral comment = null;
    SqlHiveConstraintTrait constraintTrait;
}
{
    name = SimpleIdentifier()
    type = ExtendedDataType()
    constraintTrait = ConstraintTrait()
    {
        // we have NOT NULL column constraint here
        if (!type.getNullable()) {
            if (context.notNullTraits == null) {
                context.notNullTraits = new ArrayList();
                context.notNullCols = new ArrayList();
            }
            context.notNullTraits.add(constraintTrait);
            context.notNullCols.add(name);
        }
        SqlTableColumn tableColumn = new SqlTableColumn(name, type, null, comment, getPos());
        context.columnList.add(tableColumn);
    }
    [ <COMMENT> <QUOTED_STRING> {
        comment = createStringLiteral(token.image, getPos());
    }]
}

SqlHiveConstraintTrait ConstraintTrait() :
{
  // a constraint is by default ENABLE NOVALIDATE RELY
  SqlLiteral enable = SqlHiveConstraintEnable.ENABLE.symbol(getPos());
  SqlLiteral validate = SqlHiveConstraintValidate.NOVALIDATE.symbol(getPos());
  SqlLiteral rely = SqlHiveConstraintRely.RELY.symbol(getPos());
}
{
  [
    <ENABLE>  { enable = SqlHiveConstraintEnable.ENABLE.symbol(getPos()); }
    |
    <DISABLE> { enable = SqlHiveConstraintEnable.DISABLE.symbol(getPos()); }
  ]
  [
    <NOVALIDATE>  { validate = SqlHiveConstraintValidate.NOVALIDATE.symbol(getPos()); }
    |
    <VALIDATE> { validate = SqlHiveConstraintValidate.VALIDATE.symbol(getPos()); }
  ]
  [
    <RELY>  { rely = SqlHiveConstraintRely.RELY.symbol(getPos()); }
    |
    <NORELY> { rely = SqlHiveConstraintRely.NORELY.symbol(getPos()); }
  ]
  {  return new SqlHiveConstraintTrait(enable, validate, rely); }
}

/**
* Different with {@link #DataType()}, we support a [ NULL | NOT NULL ] suffix syntax for both the
* collection element data type and the data type itself.
*
* <p>See {@link #SqlDataTypeSpec} for the syntax details of {@link #DataType()}.
*/
SqlDataTypeSpec ExtendedDataType() :
{
    SqlTypeNameSpec typeName;
    final Span s;
    boolean elementNullable = true;
    boolean nullable = true;
}
{
    <#-- #DataType does not take care of the nullable attribute. -->
    typeName = TypeName() {
        s = span();
    }
    (
        LOOKAHEAD(3)
        elementNullable = NullableOptDefaultTrue()
        typeName = ExtendedCollectionsTypeName(typeName, elementNullable)
    )*
    nullable = NullableOptDefaultTrue()
    {
        return new SqlDataTypeSpec(typeName, s.end(this)).withNullable(nullable);
    }
}

HiveTableStoredAs TableStoredAs(SqlParserPos pos) :
{
  SqlIdentifier fileFormat = null;
  SqlCharStringLiteral inputFormat = null;
  SqlCharStringLiteral outputFormat = null;
}
{
  (
    LOOKAHEAD(2)
    <INPUTFORMAT> <QUOTED_STRING> { inputFormat = createStringLiteral(token.image, getPos()); }
    <OUTPUTFORMAT> <QUOTED_STRING> { outputFormat = createStringLiteral(token.image, getPos()); }
    { return HiveTableStoredAs.ofInputOutputFormat(pos, inputFormat, outputFormat); }
    |
    fileFormat = SimpleIdentifier()
    { return HiveTableStoredAs.ofFileFormat(pos, fileFormat); }
  )
}

HiveTableRowFormat TableRowFormat(SqlParserPos pos) :
{
  SqlCharStringLiteral fieldsTerminator = null;
  SqlCharStringLiteral escape = null;
  SqlCharStringLiteral collectionTerminator = null;
  SqlCharStringLiteral mapKeyTerminator = null;
  SqlCharStringLiteral linesTerminator = null;
  SqlCharStringLiteral nullAs = null;
  SqlCharStringLiteral serdeClass = null;
  SqlNodeList serdeProps = null;
}
{
  (
    <DELIMITED>
      [ <FIELDS> <TERMINATED> <BY> <QUOTED_STRING>
        { fieldsTerminator = createStringLiteral(token.image, getPos()); }
        [ <ESCAPED> <BY> <QUOTED_STRING> { escape = createStringLiteral(token.image, getPos()); } ]
      ]
      [ <COLLECTION> <ITEMS> <TERMINATED> <BY> <QUOTED_STRING> { collectionTerminator = createStringLiteral(token.image, getPos()); } ]
      [ <MAP> <KEYS> <TERMINATED> <BY> <QUOTED_STRING> { mapKeyTerminator = createStringLiteral(token.image, getPos()); } ]
      [ <LINES> <TERMINATED> <BY> <QUOTED_STRING> { linesTerminator = createStringLiteral(token.image, getPos()); } ]
      [ <NULL> <DEFINED> <AS> <QUOTED_STRING> { nullAs = createStringLiteral(token.image, getPos()); } ]
      { return HiveTableRowFormat.withDelimited(pos, fieldsTerminator, escape, collectionTerminator, mapKeyTerminator, linesTerminator, nullAs); }
    |
    <SERDE> <QUOTED_STRING>
    {
      serdeClass = createStringLiteral(token.image, getPos());
    }
    [ <WITH> <SERDEPROPERTIES> serdeProps = TableProperties() ]
    { return HiveTableRowFormat.withSerDe(pos, serdeClass, serdeProps); }
  )
}

/**
* A sql type name extended basic data type, it has a counterpart basic
* sql type name but always represents as a special alias compared with the standard name.
*
* <p>For example, STRING is synonym of VARCHAR(INT_MAX).
*/
SqlTypeNameSpec ExtendedSqlBasicTypeName() :
{
    final SqlTypeName typeName;
    final String typeAlias;
    int precision = -1;
}
{
    <STRING>
    {
        typeName = SqlTypeName.VARCHAR;
        typeAlias = token.image;
        precision = Integer.MAX_VALUE;
        return new SqlAlienSystemTypeNameSpec(typeAlias, typeName, precision, getPos());
    }
}

SqlTypeNameSpec CustomizedCollectionsTypeName() :
{
    final SqlTypeName collectionTypeName;
    final SqlTypeNameSpec elementTypeName;
    boolean elementNullable = true;
}
{
    (
        <ARRAY> {
            collectionTypeName = SqlTypeName.ARRAY;
        }
    |
        <MULTISET> {
            collectionTypeName = SqlTypeName.MULTISET;
        }
    )
    <LT>
    elementTypeName = TypeName()
    elementNullable = NullableOptDefaultTrue()
    <GT>
    {
        return new ExtendedSqlCollectionTypeNameSpec(
            elementTypeName,
            elementNullable,
            collectionTypeName,
            false,
            getPos());
    }
}

SqlTypeNameSpec ExtendedCollectionsTypeName(
        SqlTypeNameSpec elementTypeName,
        boolean elementNullable) :
{
    final SqlTypeName collectionTypeName;
}
{
    (
        <MULTISET> { collectionTypeName = SqlTypeName.MULTISET; }
    |
         <ARRAY> { collectionTypeName = SqlTypeName.ARRAY; }
    )
    {
        return new ExtendedSqlCollectionTypeNameSpec(
             elementTypeName,
             elementNullable,
             collectionTypeName,
             true,
             getPos());
    }
}

SqlTypeNameSpec SqlMapTypeName() :
{
    SqlDataTypeSpec keyType;
    SqlDataTypeSpec valType;
    boolean nullable = true;
}
{
    <MAP>
    <LT>
    keyType = ExtendedDataType()
    <COMMA>
    valType = ExtendedDataType()
    <GT>
    {
        return new SqlMapTypeNameSpec(keyType, valType, getPos());
    }
}

void ExtendedFieldNameTypeCommaList(
        List<SqlIdentifier> fieldNames,
        List<SqlDataTypeSpec> fieldTypes,
        List<SqlCharStringLiteral> comments) :
{
    SqlIdentifier fName;
    SqlDataTypeSpec fType;
    boolean nullable;
}
{
    fName = SimpleIdentifier() <COLON> fType = ExtendedDataType()
    {
        fieldNames.add(fName);
        fieldTypes.add(fType);
    }
    (
        <QUOTED_STRING> {
            comments.add(createStringLiteral(token.image, getPos()));
        }
    |
        { comments.add(null); }
    )
    (
        <COMMA>
        fName = SimpleIdentifier() <COLON> fType = ExtendedDataType()
        {
            fieldNames.add(fName);
            fieldTypes.add(fType);
        }
        (
            <QUOTED_STRING> {
                comments.add(createStringLiteral(token.image, getPos()));
            }
        |
            { comments.add(null); }
        )
    )*
}

SqlTypeNameSpec ExtendedSqlRowTypeName() :
{
    List<SqlIdentifier> fieldNames = new ArrayList<SqlIdentifier>();
    List<SqlDataTypeSpec> fieldTypes = new ArrayList<SqlDataTypeSpec>();
    List<SqlCharStringLiteral> comments = new ArrayList<SqlCharStringLiteral>();
}
{
    <STRUCT> <LT> ExtendedFieldNameTypeCommaList(fieldNames, fieldTypes, comments) <GT>
    {
        return new ExtendedHiveStructTypeNameSpec(
            getPos(),
            fieldNames,
            fieldTypes,
            comments);
    }
}

/**
* Parses a partition specifications statement for insert statement.
*/
void InsertPartitionSpec(SqlNodeList allPartKeys, SqlNodeList staticSpec) :
{
    SqlIdentifier key;
    SqlNode value;
    SqlParserPos pos;
}
{
    <LPAREN>
    key = SimpleIdentifier()
    { pos = getPos(); allPartKeys.add(key); }
    [ <EQ> value = Literal()
      {
          staticSpec.add(new SqlProperty(key, value, pos));
      }
    ]
    (
        <COMMA> key = SimpleIdentifier()
        { pos = getPos(); allPartKeys.add(key); }
        [ <EQ> value = Literal()
          {
              staticSpec.add(new SqlProperty(key, value, pos));
          }
        ]
    )*
    <RPAREN>
}

/**
* Parses an INSERT statement.
*/
SqlNode RichSqlInsert() :
{
    final List<SqlLiteral> keywords = new ArrayList<SqlLiteral>();
    final SqlNodeList keywordList;
    final List<SqlLiteral> extendedKeywords = new ArrayList<SqlLiteral>();
    final SqlNodeList extendedKeywordList;
    SqlNode table;
    SqlNodeList extendList = null;
    SqlNode source;
    final SqlNodeList allPartKeys = new SqlNodeList(getPos());
    final SqlNodeList staticSpec = new SqlNodeList(getPos());
    SqlNodeList columnList = null;
    final Span s;
}
{
    (
        <INSERT>
    |
        <UPSERT> { keywords.add(SqlInsertKeyword.UPSERT.symbol(getPos())); }
    )
    (
        <INTO>
    |
        <OVERWRITE> {
            if (RichSqlInsert.isUpsert(keywords)) {
                throw SqlUtil.newContextException(getPos(),
                    ParserResource.RESOURCE.overwriteIsOnlyUsedWithInsert());
            }
            extendedKeywords.add(RichSqlInsertKeyword.OVERWRITE.symbol(getPos()));
        }
    )
    [ <TABLE> ]
    { s = span(); }
    SqlInsertKeywords(keywords) {
        keywordList = new SqlNodeList(keywords, s.addAll(keywords).pos());
        extendedKeywordList = new SqlNodeList(extendedKeywords, s.addAll(extendedKeywords).pos());
    }
    table = CompoundIdentifier()
    [
        LOOKAHEAD(5)
        [ <EXTEND> ]
        extendList = ExtendList() {
            table = extend(table, extendList);
        }
    ]
    [
        LOOKAHEAD(2)
        { final Pair<SqlNodeList, SqlNodeList> p; }
        p = ParenthesizedCompoundIdentifierList() {
            if (p.right.size() > 0) {
                table = extend(table, p.right);
            }
            if (p.left.size() > 0) {
                columnList = p.left;
            }
        }
    ]
    [
        <PARTITION> InsertPartitionSpec(allPartKeys, staticSpec)
    ]
    source = OrderedQueryOrExpr(ExprContext.ACCEPT_QUERY) {
        return new RichSqlHiveInsert(s.end(source), keywordList, extendedKeywordList, table, source,
            columnList, staticSpec, allPartKeys);
    }
}

/**
 * Those methods should not be used in SQL. They are good for parsing identifiers
 * in Table API. The difference between those identifiers and CompoundIdentifer is
 * that the Table API identifiers ignore any keywords. They are also strictly limited
 * to three part identifiers. The quoting still works the same way.
 */
SqlIdentifier TableApiIdentifier() :
{
    final List<String> nameList = new ArrayList<String>();
    final List<SqlParserPos> posList = new ArrayList<SqlParserPos>();
}
{
    TableApiIdentifierSegment(nameList, posList)
    (
        LOOKAHEAD(2)
        <DOT>
        TableApiIdentifierSegment(nameList, posList)
    )?
    (
        LOOKAHEAD(2)
        <DOT>
        TableApiIdentifierSegment(nameList, posList)
    )?
    <EOF>
    {
        SqlParserPos pos = SqlParserPos.sum(posList);
        return new SqlIdentifier(nameList, null, pos, posList);
    }
}

void TableApiIdentifierSegment(List<String> names, List<SqlParserPos> positions) :
{
    final String id;
    char unicodeEscapeChar = BACKSLASH;
    final SqlParserPos pos;
    final Span span;
}
{
    (
        <QUOTED_IDENTIFIER> {
            id = SqlParserUtil.strip(getToken(0).image, DQ, DQ, DQDQ,
                quotedCasing);
            pos = getPos().withQuoting(true);
        }
    |
        <BACK_QUOTED_IDENTIFIER> {
            id = SqlParserUtil.strip(getToken(0).image, "`", "`", "``",
                quotedCasing);
            pos = getPos().withQuoting(true);
        }
    |
        <BRACKET_QUOTED_IDENTIFIER> {
            id = SqlParserUtil.strip(getToken(0).image, "[", "]", "]]",
                quotedCasing);
            pos = getPos().withQuoting(true);
        }
    |
        <UNICODE_QUOTED_IDENTIFIER> {
            span = span();
            String image = getToken(0).image;
            image = image.substring(image.indexOf('"'));
            image = SqlParserUtil.strip(image, DQ, DQ, DQDQ, quotedCasing);
        }
        [
            <UESCAPE> <QUOTED_STRING> {
                String s = SqlParserUtil.parseString(token.image);
                unicodeEscapeChar = SqlParserUtil.checkUnicodeEscapeChar(s);
            }
        ]
        {
            pos = span.end(this).withQuoting(true);
            SqlLiteral lit = SqlLiteral.createCharString(image, "UTF16", pos);
            lit = lit.unescapeUnicode(unicodeEscapeChar);
            id = lit.toValue();
        }
    |
        {

            id = getNextToken().image;
            pos = getPos();
        }
    )
    {
        if (id.length() > this.identifierMaxLength) {
            throw SqlUtil.newContextException(pos,
                RESOURCE.identifierTooLong(id, this.identifierMaxLength));
        }
        names.add(id);
        if (positions != null) {
            positions.add(pos);
        }
    }
}
