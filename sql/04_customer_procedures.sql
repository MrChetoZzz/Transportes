/*
    CRUD procedures for customers.
    Deletes are rejected while the customer still has transport orders.
*/
USE TransportOrders;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Customers_Create
    @CustomerCode NVARCHAR(20),
    @CompanyName  NVARCHAR(150),
    @TaxId        NVARCHAR(20),
    @ContactName  NVARCHAR(100),
    @Phone        NVARCHAR(30),
    @Email        NVARCHAR(150),
    @City         NVARCHAR(80),
    @IsActive     BIT = 1,
    @CustomerId   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @CustomerCode = LTRIM(RTRIM(@CustomerCode));
    SET @CompanyName = LTRIM(RTRIM(@CompanyName));
    SET @TaxId = LTRIM(RTRIM(@TaxId));
    SET @ContactName = LTRIM(RTRIM(@ContactName));
    SET @Phone = LTRIM(RTRIM(@Phone));
    SET @Email = LTRIM(RTRIM(@Email));
    SET @City = LTRIM(RTRIM(@City));

    IF NULLIF(@CustomerCode, N'') IS NULL
        OR NULLIF(@CompanyName, N'') IS NULL
        OR NULLIF(@TaxId, N'') IS NULL
        OR NULLIF(@ContactName, N'') IS NULL
        OR NULLIF(@Phone, N'') IS NULL
        OR NULLIF(@Email, N'') IS NULL
        OR NULLIF(@City, N'') IS NULL
        THROW 50001, 'Customer code, company name, tax id, contact, phone, email, and city are required.', 1;

    IF @Email NOT LIKE N'%_@_%._%'
        THROW 50002, 'Customer email is not valid.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerCode = @CustomerCode)
        THROW 50003, 'A customer with this code already exists.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Customers WHERE TaxId = @TaxId)
        THROW 50004, 'A customer with this tax id already exists.', 1;

    INSERT INTO dbo.Customers
    (
        CustomerCode,
        CompanyName,
        TaxId,
        ContactName,
        Phone,
        Email,
        City,
        IsActive
    )
    VALUES
    (
        @CustomerCode,
        @CompanyName,
        @TaxId,
        @ContactName,
        @Phone,
        @Email,
        @City,
        @IsActive
    );

    SET @CustomerId = CAST(SCOPE_IDENTITY() AS INT);
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Customers_GetById
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CustomerId,
        CustomerCode,
        CompanyName,
        TaxId,
        ContactName,
        Phone,
        Email,
        City,
        IsActive,
        CreatedAt
    FROM dbo.Customers
    WHERE CustomerId = @CustomerId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Customers_GetAll
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CustomerId,
        CustomerCode,
        CompanyName,
        TaxId,
        ContactName,
        Phone,
        Email,
        City,
        IsActive,
        CreatedAt
    FROM dbo.Customers
    WHERE @IsActive IS NULL
       OR IsActive = @IsActive
    ORDER BY CompanyName;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Customers_Update
    @CustomerId   INT,
    @CustomerCode NVARCHAR(20),
    @CompanyName  NVARCHAR(150),
    @TaxId        NVARCHAR(20),
    @ContactName  NVARCHAR(100),
    @Phone        NVARCHAR(30),
    @Email        NVARCHAR(150),
    @City         NVARCHAR(80),
    @IsActive     BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @CustomerCode = LTRIM(RTRIM(@CustomerCode));
    SET @CompanyName = LTRIM(RTRIM(@CompanyName));
    SET @TaxId = LTRIM(RTRIM(@TaxId));
    SET @ContactName = LTRIM(RTRIM(@ContactName));
    SET @Phone = LTRIM(RTRIM(@Phone));
    SET @Email = LTRIM(RTRIM(@Email));
    SET @City = LTRIM(RTRIM(@City));

    IF NULLIF(@CustomerCode, N'') IS NULL
        OR NULLIF(@CompanyName, N'') IS NULL
        OR NULLIF(@TaxId, N'') IS NULL
        OR NULLIF(@ContactName, N'') IS NULL
        OR NULLIF(@Phone, N'') IS NULL
        OR NULLIF(@Email, N'') IS NULL
        OR NULLIF(@City, N'') IS NULL
        THROW 50001, 'Customer code, company name, tax id, contact, phone, email, and city are required.', 1;

    IF @Email NOT LIKE N'%_@_%._%'
        THROW 50002, 'Customer email is not valid.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerId = @CustomerId)
        THROW 50005, 'Customer was not found.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Customers
        WHERE CustomerCode = @CustomerCode
          AND CustomerId <> @CustomerId
    )
        THROW 50003, 'A customer with this code already exists.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Customers
        WHERE TaxId = @TaxId
          AND CustomerId <> @CustomerId
    )
        THROW 50004, 'A customer with this tax id already exists.', 1;

    UPDATE dbo.Customers
    SET
        CustomerCode = @CustomerCode,
        CompanyName = @CompanyName,
        TaxId = @TaxId,
        ContactName = @ContactName,
        Phone = @Phone,
        Email = @Email,
        City = @City,
        IsActive = @IsActive
    WHERE CustomerId = @CustomerId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Customers_Delete
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Customers WITH (UPDLOCK, HOLDLOCK) WHERE CustomerId = @CustomerId)
            THROW 50005, 'Customer was not found.', 1;

        IF EXISTS (SELECT 1 FROM dbo.TransportOrders WITH (UPDLOCK, HOLDLOCK) WHERE CustomerId = @CustomerId)
            THROW 50006, 'Cannot delete a customer that still has transport orders.', 1;

        DELETE FROM dbo.Customers
        WHERE CustomerId = @CustomerId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
GO
