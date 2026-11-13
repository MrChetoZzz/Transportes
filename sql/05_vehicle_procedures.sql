/*
    CRUD procedures for fleet vehicles.
    Deletes are rejected while a transport order still references the vehicle.
*/
USE TransportOrders;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Vehicles_Create
    @PlateNumber  NVARCHAR(15),
    @VehicleType  NVARCHAR(40),
    @Brand        NVARCHAR(50),
    @Model        NVARCHAR(50),
    @ModelYear    SMALLINT,
    @CapacityTons DECIMAL(8, 2),
    @Status       NVARCHAR(20),
    @IsActive     BIT = 1,
    @VehicleId    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @PlateNumber = UPPER(LTRIM(RTRIM(@PlateNumber)));
    SET @VehicleType = LTRIM(RTRIM(@VehicleType));
    SET @Brand = LTRIM(RTRIM(@Brand));
    SET @Model = LTRIM(RTRIM(@Model));
    SET @Status = LTRIM(RTRIM(@Status));

    IF NULLIF(@PlateNumber, N'') IS NULL
        OR NULLIF(@VehicleType, N'') IS NULL
        OR NULLIF(@Brand, N'') IS NULL
        OR NULLIF(@Model, N'') IS NULL
        OR NULLIF(@Status, N'') IS NULL
        THROW 50011, 'Plate number, vehicle type, brand, model, and status are required.', 1;

    IF @ModelYear < 1990 OR @ModelYear > 2100
        THROW 50012, 'Model year must be between 1990 and 2100.', 1;

    IF @CapacityTons <= 0
        THROW 50013, 'Capacity in tons must be greater than zero.', 1;

    IF @Status NOT IN (N'Available', N'InTransit', N'Maintenance', N'OutOfService')
        THROW 50014, 'Vehicle status is not valid.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Vehicles WHERE PlateNumber = @PlateNumber)
        THROW 50015, 'A vehicle with this plate number already exists.', 1;

    INSERT INTO dbo.Vehicles
    (
        PlateNumber,
        VehicleType,
        Brand,
        Model,
        ModelYear,
        CapacityTons,
        Status,
        IsActive
    )
    VALUES
    (
        @PlateNumber,
        @VehicleType,
        @Brand,
        @Model,
        @ModelYear,
        @CapacityTons,
        @Status,
        @IsActive
    );

    SET @VehicleId = CAST(SCOPE_IDENTITY() AS INT);
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Vehicles_GetById
    @VehicleId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        VehicleId,
        PlateNumber,
        VehicleType,
        Brand,
        Model,
        ModelYear,
        CapacityTons,
        Status,
        IsActive,
        CreatedAt
    FROM dbo.Vehicles
    WHERE VehicleId = @VehicleId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Vehicles_GetAll
    @Status   NVARCHAR(20) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        VehicleId,
        PlateNumber,
        VehicleType,
        Brand,
        Model,
        ModelYear,
        CapacityTons,
        Status,
        IsActive,
        CreatedAt
    FROM dbo.Vehicles
    WHERE (@Status IS NULL OR Status = @Status)
      AND (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY PlateNumber;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Vehicles_Update
    @VehicleId    INT,
    @PlateNumber  NVARCHAR(15),
    @VehicleType  NVARCHAR(40),
    @Brand        NVARCHAR(50),
    @Model        NVARCHAR(50),
    @ModelYear    SMALLINT,
    @CapacityTons DECIMAL(8, 2),
    @Status       NVARCHAR(20),
    @IsActive     BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @PlateNumber = UPPER(LTRIM(RTRIM(@PlateNumber)));
    SET @VehicleType = LTRIM(RTRIM(@VehicleType));
    SET @Brand = LTRIM(RTRIM(@Brand));
    SET @Model = LTRIM(RTRIM(@Model));
    SET @Status = LTRIM(RTRIM(@Status));

    IF NULLIF(@PlateNumber, N'') IS NULL
        OR NULLIF(@VehicleType, N'') IS NULL
        OR NULLIF(@Brand, N'') IS NULL
        OR NULLIF(@Model, N'') IS NULL
        OR NULLIF(@Status, N'') IS NULL
        THROW 50011, 'Plate number, vehicle type, brand, model, and status are required.', 1;

    IF @ModelYear < 1990 OR @ModelYear > 2100
        THROW 50012, 'Model year must be between 1990 and 2100.', 1;

    IF @CapacityTons <= 0
        THROW 50013, 'Capacity in tons must be greater than zero.', 1;

    IF @Status NOT IN (N'Available', N'InTransit', N'Maintenance', N'OutOfService')
        THROW 50014, 'Vehicle status is not valid.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Vehicles WHERE VehicleId = @VehicleId)
        THROW 50016, 'Vehicle was not found.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Vehicles
        WHERE PlateNumber = @PlateNumber
          AND VehicleId <> @VehicleId
    )
        THROW 50015, 'A vehicle with this plate number already exists.', 1;

    UPDATE dbo.Vehicles
    SET
        PlateNumber = @PlateNumber,
        VehicleType = @VehicleType,
        Brand = @Brand,
        Model = @Model,
        ModelYear = @ModelYear,
        CapacityTons = @CapacityTons,
        Status = @Status,
        IsActive = @IsActive
    WHERE VehicleId = @VehicleId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Vehicles_Delete
    @VehicleId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Vehicles WITH (UPDLOCK, HOLDLOCK) WHERE VehicleId = @VehicleId)
            THROW 50016, 'Vehicle was not found.', 1;

        IF EXISTS (SELECT 1 FROM dbo.TransportOrders WITH (UPDLOCK, HOLDLOCK) WHERE VehicleId = @VehicleId)
            THROW 50017, 'Cannot delete a vehicle that is still referenced by a transport order.', 1;

        DELETE FROM dbo.Vehicles
        WHERE VehicleId = @VehicleId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
GO
