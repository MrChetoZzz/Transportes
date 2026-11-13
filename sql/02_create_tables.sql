/*
    Creates the three tables for the carrier-line sample.
    Drops existing tables first so the script can be run again.
    Run 03 and 04-06 again after this script if you need data and procedures.
*/
USE TransportOrders;
GO

DROP TABLE IF EXISTS dbo.TransportOrders;
DROP TABLE IF EXISTS dbo.Vehicles;
DROP TABLE IF EXISTS dbo.Customers;
GO

CREATE TABLE dbo.Customers
(
    CustomerId   INT            IDENTITY(1, 1) NOT NULL,
    CustomerCode NVARCHAR(20)   NOT NULL,
    CompanyName  NVARCHAR(150)  NOT NULL,
    TaxId        NVARCHAR(20)   NOT NULL,
    ContactName  NVARCHAR(100)  NOT NULL,
    Phone        NVARCHAR(30)   NOT NULL,
    Email        NVARCHAR(150)  NOT NULL,
    City         NVARCHAR(80)   NOT NULL,
    IsActive     BIT            NOT NULL CONSTRAINT DF_Customers_IsActive DEFAULT (1),
    CreatedAt    DATETIME2(0)   NOT NULL CONSTRAINT DF_Customers_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (CustomerId),
    CONSTRAINT UQ_Customers_CustomerCode UNIQUE (CustomerCode),
    CONSTRAINT UQ_Customers_TaxId UNIQUE (TaxId)
);
GO

CREATE TABLE dbo.Vehicles
(
    VehicleId    INT            IDENTITY(1, 1) NOT NULL,
    PlateNumber  NVARCHAR(15)   NOT NULL,
    VehicleType  NVARCHAR(40)   NOT NULL,
    Brand        NVARCHAR(50)   NOT NULL,
    Model        NVARCHAR(50)   NOT NULL,
    ModelYear    SMALLINT       NOT NULL,
    CapacityTons DECIMAL(8, 2)  NOT NULL,
    Status       NVARCHAR(20)   NOT NULL,
    IsActive     BIT            NOT NULL CONSTRAINT DF_Vehicles_IsActive DEFAULT (1),
    CreatedAt    DATETIME2(0)   NOT NULL CONSTRAINT DF_Vehicles_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Vehicles PRIMARY KEY CLUSTERED (VehicleId),
    CONSTRAINT UQ_Vehicles_PlateNumber UNIQUE (PlateNumber),
    CONSTRAINT CK_Vehicles_CapacityTons CHECK (CapacityTons > 0),
    CONSTRAINT CK_Vehicles_ModelYear CHECK (ModelYear BETWEEN 1990 AND 2100),
    CONSTRAINT CK_Vehicles_Status CHECK (Status IN (N'Available', N'InTransit', N'Maintenance', N'OutOfService'))
);
GO

CREATE TABLE dbo.TransportOrders
(
    OrderId          INT            IDENTITY(1, 1) NOT NULL,
    OrderNumber      NVARCHAR(20)   NOT NULL,
    CustomerId       INT            NOT NULL,
    VehicleId        INT            NULL,
    OriginCity       NVARCHAR(80)   NOT NULL,
    DestinationCity  NVARCHAR(80)   NOT NULL,
    CargoDescription NVARCHAR(200)  NOT NULL,
    WeightKg         DECIMAL(10, 2) NOT NULL,
    FreightAmount    DECIMAL(12, 2) NOT NULL,
    CurrencyCode     CHAR(3)        NOT NULL CONSTRAINT DF_TransportOrders_CurrencyCode DEFAULT ('MXN'),
    Status           NVARCHAR(20)   NOT NULL,
    PickupDate       DATE           NOT NULL,
    DeliveryDate     DATE           NULL,
    Notes            NVARCHAR(500)  NULL,
    CreatedAt        DATETIME2(0)   NOT NULL CONSTRAINT DF_TransportOrders_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt        DATETIME2(0)   NULL,
    CONSTRAINT PK_TransportOrders PRIMARY KEY CLUSTERED (OrderId),
    CONSTRAINT UQ_TransportOrders_OrderNumber UNIQUE (OrderNumber),
    CONSTRAINT FK_TransportOrders_Customers FOREIGN KEY (CustomerId) REFERENCES dbo.Customers (CustomerId),
    CONSTRAINT FK_TransportOrders_Vehicles FOREIGN KEY (VehicleId) REFERENCES dbo.Vehicles (VehicleId),
    CONSTRAINT CK_TransportOrders_WeightKg CHECK (WeightKg > 0),
    CONSTRAINT CK_TransportOrders_FreightAmount CHECK (FreightAmount >= 0),
    CONSTRAINT CK_TransportOrders_CurrencyCode CHECK (CurrencyCode IN ('MXN', 'USD')),
    CONSTRAINT CK_TransportOrders_Status CHECK (Status IN (N'Created', N'Assigned', N'InTransit', N'Delivered', N'Cancelled')),
    CONSTRAINT CK_TransportOrders_Cities CHECK (OriginCity <> DestinationCity),
    CONSTRAINT CK_TransportOrders_DeliveryDate CHECK (DeliveryDate IS NULL OR DeliveryDate >= PickupDate)
);
GO

CREATE INDEX IX_TransportOrders_CustomerId
    ON dbo.TransportOrders (CustomerId);
GO

CREATE INDEX IX_TransportOrders_VehicleId
    ON dbo.TransportOrders (VehicleId);
GO

CREATE INDEX IX_TransportOrders_Status_PickupDate
    ON dbo.TransportOrders (Status, PickupDate);
GO
