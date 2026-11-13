/*
    Reads the sample rows, then runs a customer, vehicle, and order CRUD cycle.
    The cycle is rolled back, so the five seed rows stay in place.
*/
USE TransportOrders;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @@TRANCOUNT <> 0
    THROW 51000, 'Close the open transaction before running this script.', 1;

EXEC dbo.usp_Customers_GetAll;
EXEC dbo.usp_Vehicles_GetAll;
EXEC dbo.usp_TransportOrders_GetAll @Status = N'InTransit';

BEGIN TRANSACTION;

DECLARE @DemoCustomerId INT;
DECLARE @DemoVehicleId INT;
DECLARE @DemoOrderId INT;

EXEC dbo.usp_Customers_Create
    @CustomerCode = N'CUS-900',
    @CompanyName = N'Cliente Demo SA de CV',
    @TaxId = N'CDE260101AA1',
    @ContactName = N'Ana Demo',
    @Phone = N'+52 55 1000 0001',
    @Email = N'ana.demo@example.com',
    @City = N'Puebla',
    @CustomerId = @DemoCustomerId OUTPUT;

EXEC dbo.usp_Customers_Update
    @CustomerId = @DemoCustomerId,
    @CustomerCode = N'CUS-900',
    @CompanyName = N'Cliente Demo Actualizado SA de CV',
    @TaxId = N'CDE260101AA1',
    @ContactName = N'Ana Demo',
    @Phone = N'+52 55 1000 0002',
    @Email = N'ana.demo@example.com',
    @City = N'Puebla',
    @IsActive = 1;

EXEC dbo.usp_Vehicles_Create
    @PlateNumber = N'tst-900-a',
    @VehicleType = N'Tractor',
    @Brand = N'Kenworth',
    @Model = N'T680',
    @ModelYear = 2024,
    @CapacityTons = 20.00,
    @Status = N'Available',
    @VehicleId = @DemoVehicleId OUTPUT;

EXEC dbo.usp_TransportOrders_Create
    @OrderNumber = N'ORD-DEMO-0001',
    @CustomerId = @DemoCustomerId,
    @OriginCity = N'Puebla',
    @DestinationCity = N'Querétaro',
    @CargoDescription = N'Carga de demostración',
    @WeightKg = 5000.00,
    @FreightAmount = 8000.00,
    @Status = N'Created',
    @PickupDate = '2026-11-10',
    @OrderId = @DemoOrderId OUTPUT;

EXEC dbo.usp_TransportOrders_Update
    @OrderId = @DemoOrderId,
    @OrderNumber = N'ORD-DEMO-0001',
    @CustomerId = @DemoCustomerId,
    @VehicleId = @DemoVehicleId,
    @OriginCity = N'Puebla',
    @DestinationCity = N'Querétaro',
    @CargoDescription = N'Carga de demostración',
    @WeightKg = 5000.00,
    @FreightAmount = 8500.00,
    @CurrencyCode = 'MXN',
    @Status = N'InTransit',
    @PickupDate = '2026-11-10',
    @DeliveryDate = NULL,
    @Notes = N'Ejemplo reversible';

EXEC dbo.usp_TransportOrders_GetById @OrderId = @DemoOrderId;

EXEC dbo.usp_TransportOrders_Update
    @OrderId = @DemoOrderId,
    @OrderNumber = N'ORD-DEMO-0001',
    @CustomerId = @DemoCustomerId,
    @VehicleId = @DemoVehicleId,
    @OriginCity = N'Puebla',
    @DestinationCity = N'Querétaro',
    @CargoDescription = N'Carga de demostración',
    @WeightKg = 5000.00,
    @FreightAmount = 8500.00,
    @CurrencyCode = 'MXN',
    @Status = N'Delivered',
    @PickupDate = '2026-11-10',
    @DeliveryDate = '2026-11-12',
    @Notes = N'Ejemplo reversible';

EXEC dbo.usp_TransportOrders_Delete @OrderId = @DemoOrderId;
EXEC dbo.usp_Vehicles_Delete @VehicleId = @DemoVehicleId;
EXEC dbo.usp_Customers_Delete @CustomerId = @DemoCustomerId;

ROLLBACK TRANSACTION;
GO

SELECT
    (SELECT COUNT(*) FROM dbo.Customers) AS Customers,
    (SELECT COUNT(*) FROM dbo.Vehicles) AS Vehicles,
    (SELECT COUNT(*) FROM dbo.TransportOrders) AS TransportOrders;
GO
