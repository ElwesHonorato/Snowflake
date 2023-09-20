CREATE OR REPLACE PROCEDURE 
    YOUR_tempCatalogName.YOUR_tempSchemaName.YOUR_tempTableName(
                                                                        search_catalog STRING, -- Input: Catalog (Database) to search in    
                                                                        search_schema  STRING, -- Input: Schema to search in                OR 'ALL'
                                                                        search_table   STRING, -- Input: Table to search in                 OR 'ALL'               
                                                                        search_type    STRING, -- Input: Table type (e.g., 'BASE TABLE')    OR 'ALL'
                                                                        search_value   STRING  -- Input: Value to search for                                                                                      
                                                                        )
RETURNS STRING
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
'
// Hardcoded Variables: [tempCatalogName, tempSchemaName, tempTableName, TempVWSchemasTablesColumns]
// These variables are hardcoded to ensure that only one temporary table is used,
// which persists after the procedure call to accumulate search results*. *View TempVWSchemasTablesColumns will not persist after the procedure call
// This approach avoids creating multiple temporary tables.
var tempCatalogName              = "YOUR_tempCatalogName"        ; // Temporary table name
var tempSchemaName               = "YOUR_tempSchemaName"         ; // Temporary schema name
var tempTableName                = "YOUR_tempTableName"          ; // Temporary view name
var TempVWSchemasTablesColumns   = "TempVWSchemasTablesColumns"  ; // Temporary view name


// Assigning input values to variables
var search_catalog = SEARCH_CATALOG;
var search_schema  = SEARCH_SCHEMA;
var search_table   = SEARCH_TABLE;
var search_type    = SEARCH_TYPE;
var search_value   = SEARCH_VALUE;


// Create a transient table to store the results
// Snowflake supports creating transient tables that persist until explicitly dropped and are available to all 
// users with the appropriate privileges. Transient tables are similar to permanent tables with the key difference 
// that they do not have a Fail-safe period. As a result, transient tables are specifically designed for transitory 
// data that needs to be maintained beyond each session (in contrast to temporary tables), but does not need the same 
// level of data protection and recovery provided by permanent tables.
var createTempTableSQL = `
    CREATE OR REPLACE TRANSIENT TABLE 
        ${tempCatalogName}.${tempSchemaName}.${tempTableName} (SCHEMA_NAME STRING, TABLE_NAME STRING, COLUMN_NAME STRING);`;
snowflake.execute({sqlText: createTempTableSQL});


// Create or replace a view to retrieve column and table information
var createTempVWSchemasTablesColumns = `
    create or replace view ${tempCatalogName}.${tempSchemaName}.${TempVWSchemasTablesColumns}(
    TABLE_CATALOG,
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    TABLE_TYPE
) as (
    SELECT 
        COLS.TABLE_CATALOG,
        COLS.TABLE_SCHEMA,
        COLS.TABLE_NAME,
        COLS.COLUMN_NAME,
        COLS.DATA_TYPE,
        TABLES.TABLE_TYPE
    FROM        "${search_catalog}".INFORMATION_SCHEMA.COLUMNS AS COLS
    LEFT JOIN   "${search_catalog}".INFORMATION_SCHEMA.TABLES  AS TABLES
           ON   
                 COLS.TABLE_CATALOG = TABLES.TABLE_CATALOG AND
                 COLS.TABLE_SCHEMA  = TABLES.TABLE_SCHEMA  AND
                 COLS.TABLE_NAME    = TABLES.TABLE_NAME 
    WHERE
        1 = 1
        AND 
            (
                COLS.TABLE_CATALOG   = \'${search_catalog}\'   OR
                \'${search_catalog}\'= \'ALL\'
            )  
        AND 
            (
                COLS.TABLE_SCHEMA    = \'${search_schema}\'    OR
                \'${search_schema}\' = \'ALL\'
            )  
        AND 
            (
                COLS.TABLE_NAME      = \'${search_table}\'     OR
                \'${search_table}\'  = \'ALL\'
            ) 
     )
     `;
snowflake.execute({sqlText: createTempVWSchemasTablesColumns});


// Truncate the temporary table to ensure it is empty
var truncateTempTableSQL = `
    TRUNCATE TABLE 
        ${tempCatalogName}.${tempSchemaName}.${tempTableName};`;
snowflake.execute({sqlText: truncateTempTableSQL});


// Execute a query to select information from the view
var sql_command    = 
    `
    SELECT 
        TABLE_SCHEMA, 
        TABLE_NAME, 
        COLUMN_NAME  
    FROM 
        ${tempCatalogName}.${tempSchemaName}.${TempVWSchemasTablesColumns}  
    WHERE 
        1 = 1
        AND 
            (
                TABLE_CATALOG        = \'${search_catalog}\'   OR
                \'${search_catalog}\'= \'ALL\'
            )  
        AND 
            (
                TABLE_SCHEMA         = \'${search_schema}\'    OR
                \'${search_schema}\' = \'ALL\'
            )  
        AND 
            (
                TABLE_NAME           = \'${search_table}\'     OR
                \'${search_table}\'  = \'ALL\'
            )        
        AND 
            (
                TABLE_TYPE           = \'${search_type}\'      OR
                \'${search_type}\'  = \'ALL\'
            ) 
     `;
var tables_cursor = snowflake.execute({sqlText: sql_command, binds: [search_catalog, search_schema, search_table]});


// Iterate through results and insert distinct rows into the temporary table
while (tables_cursor.next()) {
    var schema_name = tables_cursor.getColumnValue(1);
    var table_name  = tables_cursor.getColumnValue(2);
    var column_name = tables_cursor.getColumnValue(3);

    // Construct the search query with template literals
    sql_command = 
           `
           INSERT INTO ${tempCatalogName}.${tempSchemaName}.${tempTableName} (SCHEMA_NAME, TABLE_NAME, COLUMN_NAME)
           SELECT 
                \'${schema_name}\'  AS SCHEMA_NAME,
                \'${table_name}\'   AS TABLE_NAME, 
                \'${column_name}\'  AS COLUMN_NAME   
            FROM 
                "${search_catalog}"."${schema_name}"."${table_name}" 
            WHERE 
                CAST("${column_name}" AS VARCHAR) = \'${search_value}\'
            LIMIT 1
            `;
                
    // Execute the search query
    snowflake.execute({sqlText: sql_command, binds: [schema_name, table_name, column_name, search_value]});


    // Close the search_cursor
    search_cursor = null;
}


// Delete the view to clean up
var deleteTempVWSchemasTablesColumns = `DROP VIEW ${tempCatalogName}.${tempSchemaName}.${TempVWSchemasTablesColumnsgit}`;
snowflake.execute({sqlText: deleteTempVWSchemasTablesColumns});

//Return a success message
return `Search completed successfully | Query Results on -> ${tempCatalogName}.${tempSchemaName}.${tempTableName}         /-/-/-/->         
After use Run | DROP TABLE ${tempCatalogName}.${tempSchemaName}.${tempTableName}
        `
';
GRANT USAGE ON SCHEMA YOUR_tempCatalogName.YOUR_tempSchemaName TO ROLE YOUR_Role;
-- Call the procedure to search for the value 
CALL YOUR_tempCatalogName.YOUR_tempSchemaName.YOUR_tempTableName(
                                                                    'CATALOG_to_query',  --CATALOG
                                                                    'SCHEMA_to_query' ,  --SCHEMA
                                                                    'TABLE_to_query'  ,  --TABLE
                                                                    'TYPE_to_query'   ,  --TYPE  'BASE TABLE' OR 'VIEW'
                                                                    'VALUE_to_query');   --VALUE TO SEARCH

SELECT * FROM YOUR_tempCatalogName.YOUR_tempSchemaName.YOUR_tempTableName;