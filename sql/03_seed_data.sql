/*
    Loads five fictional customers, five vehicles, and five transport orders.
    Deletes previous rows in these tables before inserting, so it can be run again.
    Company names, tax ids, and plates are invented sample data.
*/
USE TransportOrders;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM dbo.TransportOrders;
    DELETE FROM dbo.Vehicles;
    DELETE FROM dbo.Customers;

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
        (N'CUS-001', N'Aceros del Norte SA de CV', N'AND850101AB1', N'Laura Méndez', N'+52 81 1000 1001', N'laura.mendez@aceros-norte.example', N'Monterrey', 1),
        (N'CUS-002', N'Alimentos del Bajío SA de CV', N'ADB900215CD2', N'Jorge Salinas', N'+52 33 2000 2002', N'jorge.salinas@alimentos-bajio.example', N'Guadalajara', 1),
        (N'CUS-003', N'Químicos del Golfo SA de CV', N'QDG880712EF3', N'Patricia Nava', N'+52 229 300 3003', N'patricia.nava@quimicos-golfo.example', N'Veracruz', 1),
        (N'CUS-004', N'Textiles Maya SA de CV', N'TMA750330GH4', N'Ricardo Pool', N'+52 999 400 4004', N'ricardo.pool@textiles-maya.example', N'Mérida', 1),
        (N'CUS-005', N'Refacciones Pacífico SA de CV', N'RPA010918IJ5', N'Sofía Beltrán', N'+52 664 500 5005', N'sofia.beltran@refacciones-pacifico.example', N'Tijuana', 1);

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
        (N'ABC-101-A', N'Tractor', N'Kenworth', N'T680', 2022, 28.00, N'Available', 1),
        (N'DEF-202-B', N'Tractor', N'Freightliner', N'Cascadia', 2021, 30.00, N'InTransit', 1),
        (N'GHI-303-C', N'Trailer', N'Utility', N'3000R', 2020, 24.00, N'Available', 1),
        (N'JKL-404-D', N'Van', N'Mercedes-Benz', N'Sprinter', 2023, 3.50, N'Available', 1),
        (N'MNO-505-E', N'Tractor', N'International', N'LT', 2019, 26.00, N'Maintenance', 1);

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
    SELECT
        N'ORD-2026-0001',
        c.CustomerId,
        v.VehicleId,
        N'Monterrey',
        N'Ciudad de México',
        N'Bobinas de acero',
        18500.00,
        48500.00,
        'MXN',
        N'InTransit',
        '2026-11-03',
        NULL,
        N'Unidad en ruta por carretera federal.'
    FROM dbo.Customers AS c
    INNER JOIN dbo.Vehicles AS v
        ON v.PlateNumber = N'DEF-202-B'
    WHERE c.CustomerCode = N'CUS-001'
    UNION ALL
    SELECT
        N'ORD-2026-0002',
        c.CustomerId,
        v.VehicleId,
        N'Guadalajara',
        N'León',
        N'Alimentos secos en tarima',
        2800.00,
        9200.00,
        'MXN',
        N'Assigned',
        '2026-11-06',
        NULL,
        N'Asignada. La unidad sigue disponible hasta la salida.'
    FROM dbo.Customers AS c
    INNER JOIN dbo.Vehicles AS v
        ON v.PlateNumber = N'JKL-404-D'
    WHERE c.CustomerCode = N'CUS-002'
    UNION ALL
    SELECT
        N'ORD-2026-0003',
        c.CustomerId,
        NULL,
        N'Veracruz',
        N'Puebla',
        N'Tambores de solvente',
        12000.00,
        31000.00,
        'MXN',
        N'Created',
        '2026-11-08',
        NULL,
        N'Sin unidad asignada.'
    FROM dbo.Customers AS c
    WHERE c.CustomerCode = N'CUS-003'
    UNION ALL
    SELECT
        N'ORD-2026-0004',
        c.CustomerId,
        v.VehicleId,
        N'Mérida',
        N'Villahermosa',
        N'Rollos de tela',
        8600.00,
        15400.00,
        'MXN',
        N'Delivered',
        '2026-10-20',
        '2026-10-22',
        N'Entrega confirmada en destino.'
    FROM dbo.Customers AS c
    INNER JOIN dbo.Vehicles AS v
        ON v.PlateNumber = N'ABC-101-A'
    WHERE c.CustomerCode = N'CUS-004'
    UNION ALL
    SELECT
        N'ORD-2026-0005',
        c.CustomerId,
        v.VehicleId,
        N'Tijuana',
        N'Hermosillo',
        N'Refacciones automotrices',
        6400.00,
        18750.00,
        'USD',
        N'Cancelled',
        '2026-11-01',
        NULL,
        N'Cancelada por el cliente antes de la recolección.'
    FROM dbo.Customers AS c
    INNER JOIN dbo.Vehicles AS v
        ON v.PlateNumber = N'GHI-303-C'
    WHERE c.CustomerCode = N'CUS-005';

    IF (SELECT COUNT(*) FROM dbo.Customers) <> 5
        OR (SELECT COUNT(*) FROM dbo.Vehicles) <> 5
        OR (SELECT COUNT(*) FROM dbo.TransportOrders) <> 5
        THROW 50900, 'Seed data did not load five rows in each table.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
