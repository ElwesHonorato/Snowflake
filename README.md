# Snowflake Dynamic Search Procedure

As the world of data continues to evolve, so do the tools and platforms we use to manage and analyze it. Snowflake, a popular cloud data warehousing solution, empowers users with its scalability, flexibility, and performance. One of Snowflake’s unique features is the ability to execute JavaScript within SQL-stored procedures. In this article, we’ll dive into a complex Snowflake stored procedure that dynamically searches for specific values within database tables.

## The Scenario

Imagine you’re working on a data analytics project in Snowflake, and you need to find all instances of a specific value across multiple tables and schemas within a database.

Writing individual SQL queries for each table is not only time-consuming but also impractical when dealing with a large number of tables.

This is where a Snowflake stored procedure comes to the rescue.

## Understanding the Code

Let’s break down the code step by step:

### Procedure Parameters

The procedure takes five input parameters: `search_catalog`, `search_schema`, `search_table`, `search_type`, and `search_value`. These parameters allow you to specify where and what to search for in the database.

### Hardcoded Variables

Variables like `tempCatalogName`, `tempSchemaName`, `tempTableName`, and `TempVWSchemasTablesColumns` are hardcoded. These are used to ensure that only one temporary table and view are used to accumulate search results. The approach avoids creating multiple temporary tables.

### Creating a Temporary Table

A transient table is created to store the results. Transient tables in Snowflake persist until explicitly dropped and are available to all users with the appropriate privileges.

### Creating a View

A view named `TempVWSchemasTablesColumns` is created to retrieve column and table information from the database. This view acts as a bridge between the user’s search criteria and the actual database tables.

### Truncating the Transient Table

The transient table `tempTableName` is truncated to ensure it’s empty before inserting search results.

### Executing the Query

The procedure then executes a query on the `TempVWSchemasTablesColumns` view, filtering results based on the input parameters provided by the user.

### Inserting Distinct Rows

It iterates through the query results and inserts distinct rows into the temporary table, accumulating the search results.

### Cleaning Up

After the search is completed, the view `TempVWSchemasTablesColumns` is dropped to clean up resources.

### Returning Results

Finally, the procedure returns a success message along with the location of the search results.
