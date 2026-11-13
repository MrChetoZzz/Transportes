/*
    CRUD procedures for transport orders.
    Create and update keep a vehicle on at most one open order (Assigned or InTransit).
    Moving an order to InTransit marks the vehicle InTransit.
    When that vehicle has no InTransit order left, its status returns to Available.
    Status values are validated. The sequence of statuses is not enforced.
*/
USE TransportOrders;
GO

CREATE OR ALTER PROCEDURE dbo.usp_TransportOrders_Create
    @OrderNumber      NVARCHAR(20),
    @CustomerId       INT,
    @VehicleId        INT = NULL,
    @OriginCity       NVARCHAR(80),
    @DestinationCity  NVARCHAR(80),
    @CargoDescription NVARCHAR(200),
    @WeightKg         DECIMAL(10, 2),
    @FreightAmount    DECIMAL(12, 2),
    @CurrencyCode     CHAR(3) = 'MXN',
    @Status           NVARCHAR(20),
    @PickupDate       DATE,
    @DeliveryDate     DATE = NULL,
    @Notes            NVARCHAR(500) = NULL,
    @OrderId          INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @VehicleIsActive BIT;
    DECLARE @VehicleStatus NVARCHAR(20);
    DECLARE @CapacityTons DECIMAL(8, 2);

    SET @OrderNumber = LTRIM(RTRIM(@OrderNumber));
    SET @OriginCity = LTRIM(RTRIM(@OriginCity));
    SET @DestinationCity = LTRIM(RTRIM(@DestinationCity));
    SET @CargoDescription = LTRIM(RTRIM(@CargoDescription));
    SET @Status = LTRIM(RTRIM(@Status));
    SET @CurrencyCode = UPPER(LTRIM(RTRIM(@CurrencyCode)));
    SET @Notes = NULLIF(LTRIM(RTRIM(@Notes)), N'');

    IF NULLIF(@OrderNumber, N'') IS NULL
        OR NULLIF(@OriginCity, N'') IS NULL
        OR NULLIF(@DestinationCity, N'') IS NULL
        OR NULLIF(@CargoDescription, N'') IS NULL
        OR NULLIF(@Status, N'') IS NULL
        OR @PickupDate IS NULL
        THROW 50036, 'Order number, origin, destination, cargo, status, and pickup date are required.', 1;

    IF @OriginCity = @DestinationCity
        THROW 50027, 'Origin and destination cities must be different.', 1;

    IF @WeightKg <= 0
        THROW 50033, 'Weight in kilograms must be greater than zero.', 1;

    IF @FreightAmount < 0
        THROW 50032, 'Freight amount cannot be negative.', 1;

    IF @CurrencyCode NOT IN ('MXN', 'USD')
        THROW 50034, 'Currency must be MXN or USD.', 1;

    IF @Status NOT IN (N'Created', N'Assigned', N'InTransit', N'Delivered', N'Cancelled')
        THROW 50035, 'Order status is not valid.', 1;

    IF @DeliveryDate IS NOT NULL AND @DeliveryDate < @PickupDate
        THROW 50031, 'Delivery date cannot be earlier than the pickup date.', 1;

    IF @Status = N'Delivered' AND @DeliveryDate IS NULL
        THROW 50026, 'Delivery date is required when the order is delivered.', 1;

    IF @Status IN (N'Assigned', N'InTransit') AND @VehicleId IS NULL
        THROW 50025, 'A vehicle is required when the order is assigned or in transit.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerId = @CustomerId)
        THROW 50028, 'Customer was not found.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerId = @CustomerId AND IsActive = 1)
        THROW 50029, 'Inactive customers cannot receive new orders.', 1;

    IF EXISTS (SELECT 1 FROM dbo.TransportOrders WHERE OrderNumber = @OrderNumber)
        THROW 50037, 'An order with this number already exists.', 1;

    IF @VehicleId IS NOT NULL
    BEGIN
        SELECT
            @VehicleIsActive = IsActive,
            @VehicleStatus = Status,
            @CapacityTons = CapacityTons
        FROM dbo.Vehicles
        WHERE VehicleId = @VehicleId;

        IF @VehicleIsActive IS NULL
            THROW 50021, 'Vehicle was not found.', 1;

        IF @VehicleIsActive = 0
            THROW 50038, 'Inactive vehicles cannot be assigned to an order.', 1;

        IF @VehicleStatus IN (N'Maintenance', N'OutOfService')
            THROW 50023, 'Vehicle cannot be assigned while it is in maintenance or out of service.', 1;

        IF (@WeightKg / 1000.0) > @CapacityTons
            THROW 50022, 'Cargo weight exceeds the vehicle capacity.', 1;

        IF @Status IN (N'Assigned', N'InTransit')
           AND EXISTS
           (
               SELECT 1
               FROM dbo.TransportOrders
               WHERE VehicleId = @VehicleId
                 AND Status IN (N'Assigned', N'InTransit')
           )
            THROW 50024, 'Vehicle is already assigned to another open order.', 1;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TransportOrders
        (
            OrderNumber,
            CustomerId,
            VehicleId,
            OriginCity,
            DestinationCity,
            CargoDescription,
            WeightKg,
            FreightAmount,
            CurrencyCode,
            Status,
            PickupDate,
            DeliveryDate,
            Notes
        )
        VALUES
        (
            @OrderNumber,
            @CustomerId,
            @VehicleId,
            @OriginCity,
            @DestinationCity,
            @CargoDescription,
            @WeightKg,
            @FreightAmount,
            @CurrencyCode,
            @Status,
            @PickupDate,
            @DeliveryDate,
            @Notes
        );

        SET @OrderId = CAST(SCOPE_IDENTITY() AS INT);

        IF @VehicleId IS NOT NULL AND @Status = N'InTransit'
        BEGIN
            UPDATE dbo.Vehicles
            SET Status = N'InTransit'
            WHERE VehicleId = @VehicleId;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_TransportOrders_GetById
    @OrderId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        o.OrderId,
        o.OrderNumber,
        o.CustomerId,
        c.CustomerCode,
        c.CompanyName,
        o.VehicleId,
        v.PlateNumber,
        v.VehicleType,
        o.OriginCity,
        o.DestinationCity,
        o.CargoDescription,
        o.WeightKg,
        o.FreightAmount,
        o.CurrencyCode,
        o.Status,
        o.PickupDate,
        o.DeliveryDate,
        o.Notes,
        o.CreatedAt,
        o.UpdatedAt
    FROM dbo.TransportOrders AS o
    INNER JOIN dbo.Customers AS c
        ON c.CustomerId = o.CustomerId
    LEFT JOIN dbo.Vehicles AS v
        ON v.VehicleId = o.VehicleId
    WHERE o.OrderId = @OrderId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_TransportOrders_GetAll
    @Status      NVARCHAR(20) = NULL,
    @CustomerId  INT = NULL,
    @OrderNumber NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Status = NULLIF(LTRIM(RTRIM(@Status)), N'');
    SET @OrderNumber = NULLIF(LTRIM(RTRIM(@OrderNumber)), N'');

    SELECT
        o.OrderId,
        o.OrderNumber,
        o.CustomerId,
        c.CustomerCode,
        c.CompanyName,
        o.VehicleId,
        v.PlateNumber,
        v.VehicleType,
        o.OriginCity,
        o.DestinationCity,
        o.CargoDescription,
        o.WeightKg,
        o.FreightAmount,
        o.CurrencyCode,
        o.Status,
        o.PickupDate,
        o.DeliveryDate,
        o.Notes,
        o.CreatedAt,
        o.UpdatedAt
    FROM dbo.TransportOrders AS o
    INNER JOIN dbo.Customers AS c
        ON c.CustomerId = o.CustomerId
    LEFT JOIN dbo.Vehicles AS v
        ON v.VehicleId = o.VehicleId
    WHERE (@Status IS NULL OR o.Status = @Status)
      AND (@CustomerId IS NULL OR o.CustomerId = @CustomerId)
      AND (@OrderNumber IS NULL OR o.OrderNumber = @OrderNumber)
    ORDER BY o.PickupDate DESC, o.OrderId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_TransportOrders_Update
    @OrderId          INT,
    @OrderNumber      NVARCHAR(20),
    @CustomerId       INT,
    @VehicleId        INT,
    @OriginCity       NVARCHAR(80),
    @DestinationCity  NVARCHAR(80),
    @CargoDescription NVARCHAR(200),
    @WeightKg         DECIMAL(10, 2),
    @FreightAmount    DECIMAL(12, 2),
    @CurrencyCode     CHAR(3),
    @Status           NVARCHAR(20),
    @PickupDate       DATE,
    @DeliveryDate     DATE,
    @Notes            NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CurrentCustomerId INT;
    DECLARE @CurrentVehicleId INT;
    DECLARE @VehicleIsActive BIT;
    DECLARE @VehicleStatus NVARCHAR(20);
    DECLARE @CapacityTons DECIMAL(8, 2);

    SELECT
        @CurrentCustomerId = CustomerId,
        @CurrentVehicleId = VehicleId
    FROM dbo.TransportOrders
    WHERE OrderId = @OrderId;

    IF @CurrentCustomerId IS NULL
        THROW 50030, 'Transport order was not found.', 1;

    SET @OrderNumber = LTRIM(RTRIM(@OrderNumber));
    SET @OriginCity = LTRIM(RTRIM(@OriginCity));
    SET @DestinationCity = LTRIM(RTRIM(@DestinationCity));
    SET @CargoDescription = LTRIM(RTRIM(@CargoDescription));
    SET @Status = LTRIM(RTRIM(@Status));
    SET @CurrencyCode = UPPER(LTRIM(RTRIM(@CurrencyCode)));
    SET @Notes = NULLIF(LTRIM(RTRIM(@Notes)), N'');

    IF NULLIF(@OrderNumber, N'') IS NULL
        OR NULLIF(@OriginCity, N'') IS NULL
        OR NULLIF(@DestinationCity, N'') IS NULL
        OR NULLIF(@CargoDescription, N'') IS NULL
        OR NULLIF(@Status, N'') IS NULL
        OR @PickupDate IS NULL
        THROW 50036, 'Order number, origin, destination, cargo, status, and pickup date are required.', 1;

    IF @OriginCity = @DestinationCity
        THROW 50027, 'Origin and destination cities must be different.', 1;

    IF @WeightKg <= 0
        THROW 50033, 'Weight in kilograms must be greater than zero.', 1;

    IF @FreightAmount < 0
        THROW 50032, 'Freight amount cannot be negative.', 1;

    IF @CurrencyCode NOT IN ('MXN', 'USD')
        THROW 50034, 'Currency must be MXN or USD.', 1;

    IF @Status NOT IN (N'Created', N'Assigned', N'InTransit', N'Delivered', N'Cancelled')
        THROW 50035, 'Order status is not valid.', 1;

    IF @DeliveryDate IS NOT NULL AND @DeliveryDate < @PickupDate
        THROW 50031, 'Delivery date cannot be earlier than the pickup date.', 1;

    IF @Status = N'Delivered' AND @DeliveryDate IS NULL
        THROW 50026, 'Delivery date is required when the order is delivered.', 1;

    IF @Status IN (N'Assigned', N'InTransit') AND @VehicleId IS NULL
        THROW 50025, 'A vehicle is required when the order is assigned or in transit.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerId = @CustomerId)
        THROW 50028, 'Customer was not found.', 1;

    IF @CurrentCustomerId <> @CustomerId
       AND NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerId = @CustomerId AND IsActive = 1)
        THROW 50029, 'Inactive customers cannot receive new orders.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.TransportOrders
        WHERE OrderNumber = @OrderNumber
          AND OrderId <> @OrderId
    )
        THROW 50037, 'An order with this number already exists.', 1;

    IF @VehicleId IS NOT NULL
    BEGIN
        SELECT
            @VehicleIsActive = IsActive,
            @VehicleStatus = Status,
            @CapacityTons = CapacityTons
        FROM dbo.Vehicles
        WHERE VehicleId = @VehicleId;

        IF @VehicleIsActive IS NULL
            THROW 50021, 'Vehicle was not found.', 1;

        IF @VehicleIsActive = 0 AND (@CurrentVehicleId IS NULL OR @CurrentVehicleId <> @VehicleId)
            THROW 50038, 'Inactive vehicles cannot be assigned to an order.', 1;

        IF @VehicleStatus IN (N'Maintenance', N'OutOfService')
           AND (@CurrentVehicleId IS NULL OR @CurrentVehicleId <> @VehicleId)
            THROW 50023, 'Vehicle cannot be assigned while it is in maintenance or out of service.', 1;

        IF (@WeightKg / 1000.0) > @CapacityTons
            THROW 50022, 'Cargo weight exceeds the vehicle capacity.', 1;

        IF @Status IN (N'Assigned', N'InTransit')
           AND EXISTS
           (
               SELECT 1
               FROM dbo.TransportOrders
               WHERE VehicleId = @VehicleId
                 AND Status IN (N'Assigned', N'InTransit')
                 AND OrderId <> @OrderId
           )
            THROW 50024, 'Vehicle is already assigned to another open order.', 1;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.TransportOrders
        SET
            OrderNumber = @OrderNumber,
            CustomerId = @CustomerId,
            VehicleId = @VehicleId,
            OriginCity = @OriginCity,
            DestinationCity = @DestinationCity,
            CargoDescription = @CargoDescription,
            WeightKg = @WeightKg,
            FreightAmount = @FreightAmount,
            CurrencyCode = @CurrencyCode,
            Status = @Status,
            PickupDate = @PickupDate,
            DeliveryDate = @DeliveryDate,
            Notes = @Notes,
            UpdatedAt = SYSUTCDATETIME()
        WHERE OrderId = @OrderId;

        UPDATE dbo.Vehicles
        SET Status = N'Available'
        WHERE VehicleId IN (@CurrentVehicleId, @VehicleId)
          AND Status = N'InTransit'
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.TransportOrders AS o
              WHERE o.VehicleId = dbo.Vehicles.VehicleId
                AND o.Status = N'InTransit'
          );

        IF @VehicleId IS NOT NULL AND @Status = N'InTransit'
        BEGIN
            UPDATE dbo.Vehicles
            SET Status = N'InTransit'
            WHERE VehicleId = @VehicleId;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_TransportOrders_Delete
    @OrderId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @VehicleId INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @VehicleId = VehicleId
        FROM dbo.TransportOrders WITH (UPDLOCK, HOLDLOCK)
        WHERE OrderId = @OrderId;

        IF @@ROWCOUNT = 0
            THROW 50030, 'Transport order was not found.', 1;

        DELETE FROM dbo.TransportOrders
        WHERE OrderId = @OrderId;

        IF @VehicleId IS NOT NULL
        BEGIN
            UPDATE dbo.Vehicles
            SET Status = N'Available'
            WHERE VehicleId = @VehicleId
              AND Status = N'InTransit'
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM dbo.TransportOrders AS o
                  WHERE o.VehicleId = @VehicleId
                    AND o.Status = N'InTransit'
              );
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
GO
