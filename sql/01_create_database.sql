/*
    Creates the sample database for carrier-line order management.
    Safe to run more than once. Requires permission to create databases.
*/
IF DB_ID(N'TransportOrders') IS NULL
BEGIN
    CREATE DATABASE TransportOrders;
END
GO

ALTER DATABASE TransportOrders SET RECOVERY SIMPLE;
GO
