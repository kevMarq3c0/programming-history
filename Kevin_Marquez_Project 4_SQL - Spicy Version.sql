use master;
GO

DROP Database WWIDM;
GO

CREATE DATABASE WWIDM; 
GO

USE WWIDM;
GO

--Requirement 1 - Dimensional Model Tables
--Create all Dimension Tables
CREATE TABLE dbo.DimDate (
	DateKey INT NOT NULL,
	DateValue DATE NOT NULL,
	Year SMALLINT NOT NULL,
	Month TINYINT NOT NULL,
	Day TINYINT NOT NULL,
	Quarter TINYINT NOT NULL,
	StartOfMonth DATE NOT NULL,
	EndOfMonth DATE NOT NULL,
	--We want the data to be easy for business people in the data warehouse 
	MonthName VARCHAR(9) NOT NULL,
	DayOfWeekName VARCHAR(9) NOT NULL,
	CONSTRAINT PK_DimDate PRIMARY KEY ( DateKey )
);
--Cities Dimensions - Type 2 SCD
CREATE TABLE dbo.DimCities(
	CityKey INT NOT NULL,
	CityName NVARCHAR(50) NULL,
	StateProvCode NVARCHAR(5) NULL,
	StateProvName NVARCHAR(50) NULL,
	CountryName NVARCHAR(60) NULL,
	CountryFormalName NVARCHAR(60) NULL,
	CONSTRAINT PK_DimCities PRIMARY KEY CLUSTERED ( CityKey )
);
--Customers Dimensions - Type 2 SCD
CREATE TABLE dbo.DimCustomers(
	CustomerKey INT NOT NULL,
	CustomerName NVARCHAR(100) NULL,
	CustomerCategoryName NVARCHAR(50) NULL,
	DeliveryCityName NVARCHAR(50) NULL,
	DeliveryStateProvCode NVARCHAR(5) NULL,
	DeliveryCountryName NVARCHAR(50) NULL,
	PostalCityName NVARCHAR(50) NULL,
	PostalStateProvCode NVARCHAR(5) NULL,
	PostalCountryName NVARCHAR(50) NULL,
	StartDate DATE NOT NULL,
	EndDate DATE NULL,
	CONSTRAINT PK_DimCustomers PRIMARY KEY CLUSTERED ( CustomerKey )
);
--Products Dimensions - Type 2 SCD
CREATE TABLE dbo.DimProducts(
	ProductKey INT NOT NULL,
	ProductName NVARCHAR(100) NULL,
	ProductColour NVARCHAR(20) NULL,
	ProductBrand NVARCHAR(50) NULL,
	ProductSize NVARCHAR(20) NULL,
	StartDate DATE NOT NULL,
	EndDate DATE NULL,
	CONSTRAINT PK_DimProducts PRIMARY KEY CLUSTERED ( ProductKey )
);
--Sales People Dimensions - Type 1 SCD
CREATE TABLE dbo.DimSalesPeople(
	SalespersonKey INT NOT NULL,
	FullName NVARCHAR(50) NULL,
	PreferredName NVARCHAR(50) NULL,
	LogonName NVARCHAR(50) NULL,
	PhoneNumber NVARCHAR(20) NULL,
	FaxNumber NVARCHAR(20) NULL,
	EmailAddress NVARCHAR(256) NULL,
	CONSTRAINT PK_DimSalesPeople PRIMARY KEY CLUSTERED (SalespersonKey)
);
--Suppliers Dimensions - Type 2 SCD
CREATE TABLE dbo.DimSuppliers(
	SupplierKey INT NOT NULL,
	FullName NVARCHAR(50) NULL,
	SupplierCategoryName NVARCHAR(50) NULL,
	PhoneNumber NVARCHAR(20) NULL,
	FaxNumber NVARCHAR(20) NULL,
	WebsiteURL NVARCHAR(50) NULL,
	StartDate DATE NOT NULL,
	EndDate DATE NULL,
	CONSTRAINT PK_DimSuppliers PRIMARY KEY CLUSTERED (SupplierKey)
);

--Create All Fact Orders
CREATE TABLE dbo.FactOrders(
	CustomerKey INT NOT NULL,
	CityKey INT NOT NULL,
	ProductKey INT NOT NULL,
	SalespersonKey INT NOT NULL,
	SupplierKey INT NOT NULL,
	DateKey INT NOT NULL,
	Quantity INT NOT NULL,
	UnitPrice DECIMAL(18, 2) NOT NULL,
	TaxRate DECIMAL(18, 3) NOT NULL,
	TotalBeforeTax DECIMAL(18, 2) NOT NULL,
	TotalAfterTax DECIMAL(18, 2) NOT NULL,
	--Include the foreign keys for all the Dimensions to give context to the FactOrders table
	CONSTRAINT FK_FactOrders_DimCities FOREIGN KEY(CityKey) REFERENCES dbo.DimCities (CityKey),
	CONSTRAINT FK_FactOrders_DimCustomers FOREIGN KEY(CustomerKey) REFERENCES dbo.DimCustomers
	(CustomerKey),
	CONSTRAINT FK_FactOrders_DimDate FOREIGN KEY(DateKey) REFERENCES dbo.DimDate (DateKey),
	CONSTRAINT FK_FactOrders_DimProducts FOREIGN KEY(ProductKey) REFERENCES dbo.DimProducts
	(ProductKey),
	CONSTRAINT FK_FactOrders_DimSalesPeople FOREIGN KEY(SalespersonKey) REFERENCES
	dbo.DimSalesPeople (SalespersonKey),
	CONSTRAINT FK_FactOrders_DimSuppliers FOREIGN KEY (SupplierKey) REFERENCES 
	dbo.DimSuppliers (SupplierKey)
);

--Create Indexes, we only need indexes to the foreign keys of the Dimensions, no need for clustered indexes
CREATE INDEX IX_FactOrders_CustomerKey ON dbo.FactOrders(CustomerKey);
CREATE INDEX IX_FactOrders_CityKey ON dbo.FactOrders(CityKey);
CREATE INDEX IX_FactOrders_ProductKey ON dbo.FactOrders(ProductKey);
CREATE INDEX IX_FactOrders_SalespersonKey ON dbo.FactOrders(SalespersonKey);
CREATE INDEX IX_FactOrders_DateKey ON dbo.FactOrders(DateKey);
CREATE INDEX IX_FactOrders_SupplierKey ON dbo.FactOrders(SupplierKey);

--Requirement 2 - Date dimension & Create Stored Procedures
--Unique, we can calculate the date by passing a date value
GO
CREATE PROCEDURE dbo.DimDate_Load
	@DateValue DATE
AS
BEGIN;
	INSERT INTO dbo.DimDate
	SELECT CAST( YEAR(@DateValue) * 10000 + MONTH(@DateValue) * 100 + DAY(@DateValue) AS INT),
	@DateValue,
	YEAR(@DateValue),
	MONTH(@DateValue),
	DAY(@DateValue),
	DATEPART(qq,@DateValue),
	DATEADD(DAY,1,EOMONTH(@DateValue,-1)),
	EOMONTH(@DateValue),
	DATENAME(mm,@DateValue),
	DATENAME(dw,@DateValue);
END;
GO

--Requirement 3 - Create Compelling Warehouse Query -> Can be a Select Query, CTE procedure, regular procedure, Window Function
--Table function that will return all needed facts from the Data Mart
GO
CREATE FUNCTION dbo.GetOrderFactsByAndAboveDate ( 
	@OrderDate DATE
)
RETURNS @OrderFactDetails TABLE (
	CustomerKey INT NOT NULL,
	CustomerName NVARCHAR(100) NULL, 
	CustomerCategoryName NVARCHAR(50) NULL, 
	--End of Customer Dimension Information
	CityKey INT NOT NULL,
	CityName NVARCHAR(50) NULL,
	StateProvName NVARCHAR(50) NULL,
	CountryFormalName NVARCHAR(60) NULL, 
	CustomerCategoryRank BIGINT NULL,
	--End of City Dimension Information
	SalespersonKey INT NOT NULL,
	SalesPersonFullName NVARCHAR(50) NULL,
	PreferredName NVARCHAR(50) NULL,
	LogonName NVARCHAR(50) NULL,
	PhoneNumber NVARCHAR(20) NULL,
	EmailAddress NVARCHAR(256) NULL, 
	--End of Sales Person Dimension Information
	ProductKey INT NOT NULL,
	ProductName NVARCHAR(100) NULL,
	ProductColour NVARCHAR(20) NULL,
	ProductBrand NVARCHAR(50) NULL,
	ProductSize NVARCHAR(20) NULL, 
	-- End of Product Dimension Information
	SupplierKey INT NOT NULL,
	SupplierFullName NVARCHAR(50) NULL,
	SupplierPhoneNumber NVARCHAR(20) NULL,
	WebsiteURL NVARCHAR(50) NULL, 
	-- End of Supplier Dimension Information
	DateKey INT NOT NULL,
	DateValue DATE NOT NULL,
	Year SMALLINT NOT NULL,
	MonthName VARCHAR(9) NOT NULL,
	DayOfWeekName VARCHAR(9) NOT NULL, 
	--End of Date Dimension Information
	UnitPrice DECIMAL(18, 2) NOT NULL,
	TaxRate DECIMAL(18, 3) NOT NULL,
	TotalBeforeTax DECIMAL(18, 2) NOT NULL,
	TotalAfterTax DECIMAL(18, 2) NOT NULL, --End of Orders Facts
	AvgByDate INT NOT NULL
)
AS
BEGIN
	BEGIN;
		INSERT INTO @OrderFactDetails
		SELECT cus.CustomerKey, cus.CustomerName, cus.CustomerCategoryName,
			   cit.CityKey, cit.CityName, cit.StateProvName, cit.CountryFormalName, 
			   RANK() OVER (PARTITION BY cus.CustomerCategoryName ORDER BY ord.TotalAfterTax, dat.DateValue) AS CustomerCategoryRank,
			   sal.Salespersonkey, sal.FullName, sal.PreferredName, sal.LogonName, sal.PhoneNumber, sal.EmailAddress,
			   prod.ProductKey, prod.ProductName, prod.ProductColour, prod.ProductBrand, prod.ProductSize,
			   sup.SupplierKey, sup.FullName, sup.PhoneNumber, sup.WebsiteURL,
			   dat.DateKey, dat.DateValue, dat.Year, dat.MonthName, dat.DayOfWeekName,
			   ord.UnitPrice, ord.TaxRate, ord.TotalBeforeTax, ord.TotalAfterTax,
			   AVG(ord.TotalAfterTax) OVER (PARTITION BY cus.CustomerName ORDER BY dat.DateValue) AS AvgByDate
			   FROM dbo.FactOrders ord
			   INNER JOIN dbo.DimCustomers cus ON ord.CustomerKey = cus.CustomerKey
			   INNER JOIN dbo.DimCities cit ON ord.CityKey = cit.CityKey
			   INNER JOIN dbo.DimSalesPeople sal ON ord.SalespersonKey = sal.SalespersonKey
			   INNER JOIN dbo.DimProducts prod ON ord.ProductKey = prod.ProductKey
			   INNER JOIN dbo.DimSuppliers sup ON ord.SupplierKey = sup.SupplierKey
			   INNER JOIN dbo.DimDate dat ON ord.DateKey = dat.DateKey
			   WHERE dat.DateValue >= @OrderDate --Find all dates above the given date parameter 
			   ORDER BY dat.DateValue;
	END;
	RETURN;
END;
GO

--Requirement 4 - Extracts 
GO
--Create the Stages
--Customer Stage
CREATE TABLE dbo.Customers_Stage (
	CustomerName NVARCHAR(100),
	CustomerCategoryName NVARCHAR(50),
	DeliveryCityName NVARCHAR(50),
	DeliveryStateProvinceCode NVARCHAR(5),
	DeliveryStateProvinceName NVARCHAR(50),
	DeliveryCountryName NVARCHAR(50),
	DeliveryFormalName NVARCHAR(60),
	PostalCityName NVARCHAR(50),
	PostalStateProvinceCode NVARCHAR(5),
	PostalStateProvinceName NVARCHAR(50),
	PostalCountryName NVARCHAR(50),
	PostalFormalName NVARCHAR(60)
);

--Products_Stage
CREATE TABLE dbo.Products_Stage (
	StockItemName NVARCHAR(100),
	Brand NVARCHAR(50),
	Size NVARCHAR(20),
	ColorName NVARCHAR(20)
);

--Sales Peoples Stage
CREATE TABLE dbo.SalesPeoples_Stage (
	FullName NVARCHAR(50),
	PreferredName NVARCHAR(50),
	LogonName NVARCHAR(50),
	PhoneNumber NVARCHAR(20),
	FaxNumber NVARCHAR(20),
	EmailAddress NVARCHAR(256)
);

--Orders Stage
CREATE TABLE dbo.Orders_Stage (
	OrderDate DATE,
	Quantity INT,
	UnitPrice DECIMAL(18,2),
	TaxRate DECIMAL(18,3),
	CustomerName NVARCHAR(100),
	CityName NVARCHAR(50),
	StateProvinceName NVARCHAR(50),
	CountryName NVARCHAR(60),
	StockItemName NVARCHAR(100),
	LogonName NVARCHAR(50),
	SupplierName NVARCHAR(50)
);

--Suppliers Stage
CREATE TABLE dbo.Suppliers_Stage (
	SupplierName NVARCHAR(50),
	PhoneNumber NVARCHAR(20),
	FaxNumber NVARCHAR(20),
	WebsiteURL NVARCHAR(50),
	SupplierCategoryName NVARCHAR(50)
);

--Execute Stored Procedures including the loads
--Then the extractions 
--Procedure to extract data for Customers 
GO
CREATE PROCEDURE dbo.Customers_Extract
AS
	BEGIN;
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @RowCt INT;

	--Truncate instead of delete, we don't need a WHERE clause as there is no identity or foreign keys
	TRUNCATE TABLE dbo.Customers_Stage;
	--Build up the city details in a CTE and use the results twice to maintain a more simple form of code
	WITH CityDetails AS (
		SELECT ci.CityID,
		ci.CityName,
		sp.StateProvinceCode,
		sp.StateProvinceName,
		co.CountryName,
		co.FormalName
		FROM WideWorldImporters.Application.Cities ci
		LEFT JOIN WideWorldImporters.Application.StateProvinces sp
			ON ci.StateProvinceID = sp.StateProvinceID
		LEFT JOIN WideWorldImporters.Application.Countries co
			ON sp.CountryID = co.CountryID )

	INSERT INTO dbo.Customers_Stage (
		CustomerName,
		CustomerCategoryName,
		DeliveryCityName,
		DeliveryStateProvinceCode,
		DeliveryStateProvinceName,
		DeliveryCountryName,
		DeliveryFormalName,
		PostalCityName,
		PostalStateProvinceCode,
		PostalStateProvinceName,
		PostalCountryName,
		PostalFormalName )
	SELECT cust.CustomerName,
			cat.CustomerCategoryName,
			dc.CityName,
			dc.StateProvinceCode,
			dc.StateProvinceName,
			dc.CountryName,
			dc.FormalName,
			pc.CityName,
			pc.StateProvinceCode,
			pc.StateProvinceName,
			pc.CountryName,
			pc.FormalName
	FROM WideWorldImporters.Sales.Customers cust
	LEFT JOIN WideWorldImporters.Sales.CustomerCategories cat --Use left outer joins for future proofing against nullable, id must not be nullable 
	ON cust.CustomerCategoryID = cat.CustomerCategoryID
	LEFT JOIN CityDetails dc
	ON cust.DeliveryCityID = dc.CityID
	LEFT JOIN CityDetails pc
	ON cust.PostalCityID = pc.CityID;

	SET @RowCt = @@ROWCOUNT;
	IF @RowCt = 0
	BEGIN;
		THROW 50001, 'No records found. Check with source system.', 1; --If the RowCt returns zero, throw an error to show no records were found
	END;
END;
GO
EXECUTE dbo.Customers_Extract; --Execute the extraction

--Stored procedure to extract data for Products 
GO
CREATE PROCEDURE dbo.Products_Extract
AS 
	BEGIN;
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @RowCt INT;
	--Truncate the Products stage table
	TRUNCATE TABLE dbo.Products_Stage;
	
	INSERT INTO dbo.Products_Stage (
		StockItemName,
		Brand,
		Size,
		ColorName)
	SELECT prod.StockItemName,
		   prod.Brand,
		   prod.Size,
		   col.ColorName
	FROM WideWorldImporters.Warehouse.StockItems prod
	LEFT JOIN WideWorldImporters.Warehouse.Colors col ON prod.ColorID = col.ColorID; --Join the products by their colours

	SET @RowCt = @@ROWCOUNT;
	IF @RowCt = 0
	BEGIN;
		THROW 50001, 'No records found. Check with source system.', 1;
	END;
END;
GO
EXECUTE dbo.Products_Extract;

--Stored Procedure to extract data for Sales People
GO
CREATE PROCEDURE dbo.SalesPeople_Extract
AS 
	BEGIN;
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @RowCt INT;

	TRUNCATE TABLE dbo.SalesPeoples_Stage;

	--Insert into the Salespeople stage only entries found in WideWorldImporters that are a known salesperson 
	INSERT INTO dbo.SalesPeoples_Stage (
		FullName,
		PreferredName,
		LogonName,
		PhoneNumber,
		FaxNumber,
		EmailAddress 
	)
	SELECT salp.FullName,
		   salp.PreferredName,
		   salp.LogonName,
		   salp.PhoneNumber,
		   salp.FaxNumber,
		   salp.EmailAddress
	FROM WideWorldImporters.Application.People salp
	WHERE IsSalesperson = 1;

	SET @RowCt = @@ROWCOUNT;
	IF @RowCt = 0
	BEGIN;
		THROW 50001, 'No records found. Check with source system.', 1;
	END;
END;
GO
EXECUTE dbo.SalesPeople_Extract;

--Stored Procedure to extract data for Orders (Fact Table), asks for parameter of a particular date
GO 
CREATE PROCEDURE dbo.Orders_Extract (@OrderDate DATE)
AS 
	BEGIN;
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @RowCT INT;

	--Truncate the Orders stage
	TRUNCATE TABLE dbo.Orders_Stage; 
	--Include a CTE of the CityDetails 
	WITH CityDetails AS (
		SELECT ci.CityID,
		ci.CityName,
		sp.StateProvinceCode,
		sp.StateProvinceName,
		co.CountryName,
		co.FormalName
		FROM WideWorldImporters.Application.Cities ci
		LEFT JOIN WideWorldImporters.Application.StateProvinces sp
			ON ci.StateProvinceID = sp.StateProvinceID
		LEFT JOIN WideWorldImporters.Application.Countries co
			ON sp.CountryID = co.CountryID )

	INSERT INTO dbo.Orders_Stage(
		OrderDate,
		Quantity,
		UnitPrice,
		TaxRate,
		CustomerName,
		CityName,
		StateProvinceName,
		CountryName,
		StockItemName,
		LogonName,
		SupplierName
	)
	SELECT ord.OrderDate,
		   ordlin.Quantity,
		   ordlin.UnitPrice,
		   ordlin.TaxRate,
		   cust.CustomerName,
		   cdu.CityName,
		   cdu.StateProvinceName,
		   cdu.CountryName,
		   warh.StockItemName,
		   pep.LogonName,
		   sup.SupplierName
	FROM WideWorldImporters.Sales.Orders ord
	LEFT JOIN WideWorldImporters.Sales.OrderLines ordlin		--Include left outer joins of each WideWorldImporters table applicable for their ids
	ON ord.OrderID = ordlin.OrderID
	LEFT JOIN WideWorldImporters.Sales.Customers cust 
	ON ord.CustomerID = cust.CustomerID
	LEFT JOIN CityDetails cdu 
	ON cust.DeliveryCityID = cdu.CityID
	LEFT JOIN WideWorldImporters.Warehouse.StockItems warh
	ON ordlin.StockItemID = warh.StockItemID
	LEFT JOIN WideWorldImporters.Application.People pep 
	ON ord.SalespersonPersonID = pep.PersonID
	LEFT JOIN WideWorldImporters.Purchasing.Suppliers sup
	ON warh.SupplierID = sup.SupplierID
	WHERE ord.OrderDate = @OrderDate;			--Find entries where the date is the same as the given date parameter

	SET @RowCt = @@ROWCOUNT;
	IF @RowCt = 0
	BEGIN;
		THROW 50001, 'No records found. Check with source system.', 1;
	END;	   
END;
GO
EXECUTE dbo.Orders_Extract @OrderDate = '2013-01-01';

--Stored procedure that extracts data for Suppliers 
GO
CREATE PROCEDURE dbo.Suppliers_Extract
AS
	BEGIN;
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @RowCt INT;

	TRUNCATE TABLE dbo.Suppliers_Stage;
	--Join Suppliers and SupplierCategories as it is suggested that SupplierCategory might influence sales orders 
	INSERT INTO dbo.Suppliers_Stage(
		SupplierName,
		PhoneNumber,
		FaxNumber,
		WebsiteURL,
		SupplierCategoryName
	)
	SELECT sup.SupplierName,
		   sup.PhoneNumber,
		   sup.FaxNumber,
		   sup.WebsiteUrl,
		   cat.SupplierCategoryName
	FROM WideWorldImporters.Purchasing.Suppliers sup
	LEFT JOIN WideWorldImporters.Purchasing.SupplierCategories cat
	ON sup.SupplierCategoryID = cat.SupplierCategoryID;

	SET @RowCt = @@ROWCOUNT;
	IF @RowCt = 0
	BEGIN;
		THROW 50001, 'No records found. Check with source system.', 1;
	END;	
END;
GO
EXECUTE dbo.Suppliers_Extract;

--Require 5 - Transforms
--Preload tables
--Cities Preload table
GO 
CREATE TABLE dbo.Cities_Preload (
	CityKey INT NOT NULL,
	CityName NVARCHAR(50) NULL,
	StateProvCode NVARCHAR(5) NULL,
	StateProvName NVARCHAR(50) NULL,
	CountryName NVARCHAR(60) NULL,
	CountryFormalName NVARCHAR(60) NULL,
	CONSTRAINT PK_Cities_Preload PRIMARY KEY CLUSTERED (CityKey)
);
--Customers Preload table
CREATE TABLE dbo.Customers_Preload (
	CustomerKey INT NOT NULL,
	CustomerName NVARCHAR(100) NULL,
	CustomerCategoryName NVARCHAR(50) NULL,
	DeliveryCityName NVARCHAR(50) NULL,
	DeliveryStateProvCode NVARCHAR(5) NULL,
	DeliveryCountryName NVARCHAR(50) NULL,
	PostalCityName NVARCHAR(50) NULL,
	PostalStateProvCode NVARCHAR(5) NULL,
	PostalCountryName NVARCHAR(50) NULL,
	StartDate DATE NOT NULL,
	EndDate DATE NULL,
	CONSTRAINT PK_Customers_Preload PRIMARY KEY CLUSTERED ( CustomerKey )
);
--Products Preload Table
CREATE TABLE dbo.Products_Preload (
	ProductKey INT NOT NULL,
	ProductName NVARCHAR(100) NULL,
	ProductColour NVARCHAR(20) NULL,
	ProductBrand NVARCHAR(50) NULL,
	ProductSize NVARCHAR(20) NULL,
	StartDate DATE NOT NULL,
	EndDate DATE NULL,
	CONSTRAINT PK_Products_Preload PRIMARY KEY CLUSTERED ( ProductKey )
);
--Sales People Preload Table
CREATE TABLE dbo.SalesPeople_Preload (
	SalespersonKey INT NOT NULL,
	FullName NVARCHAR(50) NULL,
	PreferredName NVARCHAR(50) NULL,
	LogonName NVARCHAR(50) NULL,
	PhoneNumber NVARCHAR(20) NULL,
	FaxNumber NVARCHAR(20) NULL,
	EmailAddress NVARCHAR(256) NULL,
	CONSTRAINT PK_SalesPeople_Preload PRIMARY KEY CLUSTERED (SalespersonKey )
);
--Suppliers Preload Table
CREATE TABLE dbo.Suppliers_Preload (
	SupplierKey INT NOT NULL,
	FullName NVARCHAR(50) NULL,
	SupplierCategoryName NVARCHAR(50) NULL,
	PhoneNumber NVARCHAR(20) NULL,
	FaxNumber NVARCHAR(20) NULL,
	WebsiteURL NVARCHAR(50) NULL,
	StartDate DATE NOT NULL,
	EndDate DATE NULL,
	CONSTRAINT PK_Suppliers_Preload PRIMARY KEY CLUSTERED (SupplierKey)
);
--Orders Preload Table
CREATE TABLE dbo.Orders_Preload (
	CustomerKey INT NOT NULL,
	CityKey INT NOT NULL,
	ProductKey INT NOT NULL,
	SalespersonKey INT NOT NULL,
	SupplierKey INT NOT NULL,
	DateKey INT NOT NULL,
	Quantity INT NOT NULL,
	UnitPrice DECIMAL(18, 2) NOT NULL,
	TaxRate DECIMAL(18, 3) NOT NULL,
	TotalBeforeTax DECIMAL(18, 2) NOT NULL,
	TotalAfterTax DECIMAL(18, 2) NOT NULL
);
--Sequence of Keys as they will not be able to affected by Truncate, and it allows us to use a mix of generated and existing keys
CREATE SEQUENCE dbo.CityKey START WITH 1;
CREATE SEQUENCE dbo.CustomerKey START WITH 1;
CREATE SEQUENCE dbo.ProductKey START WITH 1;
CREATE SEQUENCE dbo.SalespersonKey START WITH 1;
CREATE SEQUENCE dbo.SupplierKey START WITH 1;

--Transforms 
--City Transform - Type 1 SCD
GO
CREATE PROCEDURE dbo.Cities_Transform
	AS 
	BEGIN;
		SET NOCOUNT ON;
		SET XACT_ABORT ON;
		--Start by truncating the Cities_Preload table
		TRUNCATE TABLE dbo.Cities_Preload;
		BEGIN TRANSACTION;
			--Create new surrogate keys if no entry exists
			INSERT INTO dbo.Cities_Preload /* Column list excluded for brevity */
			SELECT NEXT VALUE FOR dbo.CityKey AS CityKey,	--Use the CityKey to match records 
								  cu.DeliveryCityName,
								  cu.DeliveryStateProvinceCode,
								  cu.DeliveryStateProvinceName,
								  cu.DeliveryCountryName,
								  cu.DeliveryFormalName
			FROM dbo.Customers_Stage cu
			WHERE NOT EXISTS ( SELECT 1
			FROM dbo.DimCities ci
			WHERE cu.DeliveryCityName = ci.CityName
				AND cu.DeliveryStateProvinceName = ci.StateProvName
				AND cu.DeliveryCountryName = ci.CountryName );
			
			--We are using existing keys if it already exists 
			INSERT INTO dbo.Cities_Preload /* Column list excluded for brevity */
				SELECT ci.CityKey,
					   cu.DeliveryCityName,
					   cu.DeliveryStateProvinceCode,
					   cu.DeliveryStateProvinceName,
					   cu.DeliveryCountryName,
					   cu.DeliveryFormalName
				FROM dbo.Customers_Stage cu
				JOIN dbo.DimCities ci
				ON cu.DeliveryCityName = ci.CityName
					AND cu.DeliveryStateProvinceName = ci.StateProvName
					AND cu.DeliveryCountryName = ci.CountryName;
	COMMIT TRANSACTION;
END;

--Customers Transform - Type 2 SCD
GO
CREATE PROCEDURE dbo.Customers_Transform
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
	TRUNCATE TABLE dbo.Customers_Preload;
	--Get the StartDate and EndDate to satisfy the needed requirements for a Type 2 SCD
	DECLARE @StartDate DATE = GETDATE();
	DECLARE @EndDate DATE = DATEADD(dd,-1,GETDATE());
	BEGIN TRANSACTION;
		-- Add updated records
		INSERT INTO dbo.Customers_Preload /* Column list excluded for brevity */
		SELECT NEXT VALUE FOR dbo.CustomerKey AS CustomerKey,
							stg.CustomerName,
							stg.CustomerCategoryName,
							stg.DeliveryCityName,
							stg.DeliveryStateProvinceCode,
							stg.DeliveryCountryName,
							stg.PostalCityName,
							stg.PostalStateProvinceCode,
							stg.PostalCountryName,
							@StartDate,
							NULL --The end date 
						FROM dbo.Customers_Stage stg
						JOIN dbo.DimCustomers cu
							ON stg.CustomerName = cu.CustomerName
							AND cu.EndDate IS NULL
						WHERE stg.CustomerCategoryName <> cu.CustomerCategoryName
							OR stg.DeliveryCityName <> cu.DeliveryCityName
							OR stg.DeliveryStateProvinceCode <> cu.DeliveryStateProvCode
							OR stg.DeliveryCountryName <> cu.DeliveryCountryName
							OR stg.PostalCityName <> cu.PostalCityName
							OR stg.PostalStateProvinceCode <> cu.PostalStateProvCode
							OR stg.PostalCountryName <> cu.PostalCountryName;
		
		-- Add existing records, and expire as necessary
		INSERT INTO dbo.Customers_Preload /* Column list excluded for brevity */
			SELECT cu.CustomerKey,
				cu.CustomerName,
				cu.CustomerCategoryName,
				cu.DeliveryCityName,
				cu.DeliveryStateProvCode,
				cu.DeliveryCountryName,
				cu.PostalCityName,
				cu.PostalStateProvCode,
				cu.PostalCountryName,
				cu.StartDate,
			CASE
				WHEN pl.CustomerName IS NULL THEN NULL
				ELSE @EndDate
			END AS EndDate
			FROM dbo.DimCustomers cu
			LEFT JOIN dbo.Customers_Preload pl
				ON pl.CustomerName = cu.CustomerName
				AND cu.EndDate IS NULL;

			-- Create new records
			INSERT INTO dbo.Customers_Preload /* Column list excluded for brevity */
			SELECT NEXT VALUE FOR dbo.CustomerKey AS CustomerKey,
					stg.CustomerName,
					stg.CustomerCategoryName,
					stg.DeliveryCityName,
					stg.DeliveryStateProvinceCode,
					stg.DeliveryCountryName,
					stg.PostalCityName,
					stg.PostalStateProvinceCode,
					stg.PostalCountryName,
					@StartDate,
					NULL
			FROM dbo.Customers_Stage stg
			WHERE NOT EXISTS ( SELECT 1 FROM dbo.DimCustomers cu WHERE stg.CustomerName = cu.CustomerName );

			-- Expire missing records
			INSERT INTO dbo.Customers_Preload /* Column list excluded for brevity */
				SELECT cu.CustomerKey,
					cu.CustomerName,
					cu.CustomerCategoryName,
					cu.DeliveryCityName,
					cu.DeliveryStateProvCode,
					cu.DeliveryCountryName,
					cu.PostalCityName,
					cu.PostalStateProvCode,
					cu.PostalCountryName,
					cu.StartDate,
					@EndDate
				FROM dbo.DimCustomers cu
				WHERE NOT EXISTS ( SELECT 1 FROM dbo.Customers_Stage stg WHERE stg.CustomerName = cu.CustomerName )
					AND cu.EndDate IS NULL;
	COMMIT TRANSACTION;
END;


--Products Transform - Type 2 SCD
GO 
CREATE PROCEDURE dbo.Products_Transform
AS
BEGIN;
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
		TRUNCATE TABLE dbo.Products_Preload;
		--Get the Start and End dates to satisfy needs of Type 2 SCD
		DECLARE @StartDate DATE = GETDATE();
		DECLARE @EndDate DATE = DATEADD(dd, -1, GETDATE());
		BEGIN TRANSACTION;
			--Add in updated records 
			INSERT INTO dbo.Products_Preload
				SELECT NEXT VALUE for dbo.ProductKey AS ProductKey,
									stg.StockItemName,
									stg.ColorName,
									stg.Brand,
									stg.Size,
									@StartDate,
									NULL --The end date
								FROM dbo.Products_Stage stg
								JOIN dbo.DimProducts prod
									ON stg.StockItemName = prod.ProductName
									AND prod.EndDate IS NULL
								WHERE stg.ColorName <> prod.ProductColour
									  OR stg.Brand <> prod.ProductBrand
									  OR stg.Size <> prod.ProductSize;
				--Add in existing records and expire if necessary
				INSERT INTO dbo.Products_Preload
					SELECT prod.ProductKey,
						   prod.ProductName,
						   prod.ProductColour,
						   prod.ProductBrand,
						   prod.ProductSize,
						   prod.StartDate,
					CASE
						WHEN pl.ProductName IS NULL THEN NULL
						ELSE @EndDate
					END AS EndDate
					FROM dbo.DimProducts prod
					LEFT JOIN dbo.Products_Preload pl
						ON pl.ProductName = prod.ProductName
						AND prod.EndDate IS NULL;
		
		--Create New Records 
		INSERT INTO dbo.Products_Preload 
		SELECT NEXT VALUE FOR dbo.ProductKey AS ProductKey,
									stg.StockItemName,
									stg.ColorName,
									stg.Brand,
									stg.Size,
									@StartDate,
									NULL
						  FROM dbo.Products_Stage stg
						  WHERE NOT EXISTS (SELECT 1 FROM dbo.DimProducts prod WHERE stg.StockItemName = prod.ProductName);
			
		-- Expire missing records
		INSERT INTO dbo.Products_Preload 
			SELECT prod.ProductKey,
				   prod.ProductName,
				   prod.ProductColour,
				   prod.ProductBrand,
				   prod.ProductSize,
				   prod.StartDate,
				   @EndDate
			FROM dbo.DimProducts prod
			WHERE NOT EXISTS ( SELECT 1 FROM dbo.Products_Stage stg WHERE stg.StockItemName = prod.ProductName)
				AND prod.EndDate IS NULL;
	 COMMIT TRANSACTION;
END;

--Salespeople Transform - Type 1 
GO 
CREATE PROCEDURE dbo.SalesPeople_Transform
AS 
	BEGIN;
		SET NOCOUNT ON;
		SET XACT_ABORT ON;
		TRUNCATE TABLE dbo.SalesPeople_Preload;
		BEGIN TRANSACTION;
		--Create new surrogate keys if no entry exists
			INSERT INTO dbo.SalesPeople_Preload
				SELECT NEXT VALUE FOR dbo.SalespersonKey AS SalespersonKey,
										sal.FullName,
										sal.PreferredName,
										sal.LogonName,
										sal.PhoneNumber,
										sal.FaxNumber,
										sal.EmailAddress
				FROM dbo.SalesPeoples_Stage sal
				WHERE NOT EXISTS ( SELECT 1 
					FROM dbo.DimSalesPeople salpe
				WHERE sal.FullName = salpe.FullName
					  AND sal.PreferredName = salpe.PreferredName
					  AND sal.LogonName = salpe.LogonName );

			--We are using existing keys if it already exists 
		   INSERT INTO dbo.SalesPeople_Preload
				SELECT salpe.SalespersonKey,
					   sal.FullName,
					   sal.PreferredName,
					   sal.LogonName,
					   sal.PhoneNumber,
					   sal.FaxNumber,
					   sal.EmailAddress
				FROM dbo.SalesPeoples_Stage sal
				JOIN dbo.DimSalesPeople salpe
					ON sal.FullName = salpe.FullName
						AND sal.PreferredName = salpe.PreferredName
						AND sal.LogonName = salpe.LogonName;
	COMMIT TRANSACTION;
END;

--Suppliers Transform - Type 2 SCD
GO 
CREATE PROCEDURE dbo.Suppliers_Transform
AS 
	BEGIN;
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
		TRUNCATE TABLE dbo.Suppliers_Preload;
		--Get Start Dates and End Dates to satisfy Type 2 SCD
		DECLARE @StartDate DATE = GETDATE();
		DECLARE @EndDate DATE = DATEADD(dd, -1, GETDATE());
		BEGIN TRANSACTION;
		--Add in updated records 
			INSERT INTO dbo.Suppliers_Preload
			SELECT NEXT VALUE for dbo.SupplierKey AS SupplierKey,
									stg.SupplierName,
									stg.SupplierCategoryName,
									stg.PhoneNumber,
									stg.FaxNumber,
									stg.WebsiteURL,
									@StartDate,
									NULL
						FROM dbo.Suppliers_Stage stg
						JOIN dbo.DimSuppliers sup
							ON stg.SupplierName = sup.FullName
							AND sup.EndDate IS NULL
						WHERE stg.SupplierCategoryName <> sup.SupplierCategoryName
							  OR stg.PhoneNumber <> sup.PhoneNumber
							  OR stg.FaxNumber <> sup.FaxNumber
							  OR stg.WebsiteURL <> sup.WebsiteURL;
			
			--Add existing records and expire as necessary
			INSERT INTO dbo.Suppliers_Preload
				SELECT sup.SupplierKey,
					   sup.FullName,
					   sup.SupplierCategoryName,
					   sup.PhoneNumber,
					   sup.FaxNumber,
					   sup.WebsiteURL,
					   sup.StartDate,
				CASE
						WHEN pl.FullName IS NULL THEN NULL
						ELSE @EndDate
				END AS EndDate
				FROM dbo.DimSuppliers sup
				LEFT JOIN dbo.Suppliers_Preload pl
						ON pl.FullName = sup.FullName
						AND sup.EndDate IS NULL;
		  --Create new records
		  INSERT INTO dbo.Suppliers_Preload
				SELECT NEXT VALUE FOR dbo.SupplierKey AS SupplierKey,
						stg.SupplierName,
						stg.SupplierCategoryName,
						stg.PhoneNumber,
						stg.FaxNumber,
						stg.WebsiteURL,
						@StartDate,
						NULL
				FROM dbo.Suppliers_Stage stg
				WHERE NOT EXISTS ( SELECT 1 FROM dbo.DimSuppliers sup WHERE stg.SupplierName = sup.FullName) 

		  --Expire records if necessary
		  INSERT INTO dbo.Suppliers_Preload
				SELECT sup.SupplierKey,
					   sup.FullName,
					   sup.SupplierCategoryName,
					   sup.PhoneNumber,
					   sup.FaxNumber,
					   sup.WebsiteURL,
					   sup.StartDate,
					   @EndDate
		        FROM dbo.DimSuppliers sup
				WHERE NOT EXISTS ( SELECT 1 FROM dbo.Suppliers_Stage stg WHERE stg.SupplierName = sup.FullName)
								AND sup.EndDate IS NULL;
		COMMIT TRANSACTION;
END;

--Orders Transform Procedure
GO 
CREATE PROCEDURE dbo.Orders_Transform
AS 
	BEGIN;
		SET NOCOUNT ON;
		SET XACT_ABORT ON;
		--Truncate the Orders Preload then insert again
		TRUNCATE TABLE dbo.Orders_Preload;
		--Utilize the other preload tables to match with the surrogate keys by their business key
		INSERT INTO dbo.Orders_Preload
		SELECT cu.CustomerKey,
			   ci.CityKey,
			   pr.ProductKey,
			   sp.SalespersonKey,
			   sup.SupplierKey,
			   --Aggregate our data for each measure
			   CAST(YEAR(ord.OrderDate) * 10000 + MONTH(ord.OrderDate) * 100 + DAY(ord.OrderDate) AS INT),
			   (ord.Quantity) AS Quantity,
			   (ord.UnitPrice) AS UnitPrice,
			   (ord.TaxRate) AS TaxRate,
			   (ord.Quantity * ord.UnitPrice) AS TotalBeforeTax,
			   (ord.Quantity * ord.UnitPrice * (1 + ord.TaxRate/100)) AS TotalAfterTax
		FROM dbo.Orders_Stage ord
		JOIN dbo.Customers_Preload cu
			ON ord.CustomerName = cu.CustomerName
		JOIN dbo.Cities_Preload ci
			ON ord.CityName = ci.CityName
			AND ord.StateProvinceName = ci.StateProvName
			AND ord.CountryName = ci.CountryName
		JOIN dbo.Products_Preload pr
			ON ord.StockItemName = pr.ProductName
		JOIN dbo.SalesPeople_Preload sp
			ON ord.LogonName = sp.LogonName
		JOIN dbo.Suppliers_Preload sup
			ON ord.SupplierName = sup.FullName;
END;

--Requirement 6 - Create ETL Loads 
--Customers Load
GO
CREATE PROCEDURE dbo.Customers_Load
	AS
	BEGIN;
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	BEGIN TRANSACTION;
		DELETE cu
		FROM dbo.DimCustomers cu
		JOIN dbo.Customers_Preload pl
			ON cu.CustomerKey = pl.CustomerKey;
		INSERT INTO dbo.DimCustomers /* Columns excluded for brevity */
		SELECT * /* Columns excluded for brevity */
			FROM dbo.Customers_Preload;
	COMMIT TRANSACTION;
END;
--Products Load
GO
CREATE PROCEDURE dbo.Products_Load
	AS
	BEGIN;
		SET NOCOUNT ON;
		SET XACT_ABORT ON;
		BEGIN TRANSACTION;
			DELETE prod
			FROM dbo.DimProducts prod
			JOIN dbo.Products_Preload pl
				ON prod.ProductKey = pl.ProductKey;
		INSERT INTO dbo.DimProducts
		SELECT * FROM dbo.Products_Preload;
	COMMIT TRANSACTION;
END;
--SalesPeople Load
GO
CREATE PROCEDURE dbo.SalesPeople_Load
	AS
	BEGIN;
		SET NOCOUNT ON;
		SET XACT_ABORT ON;
		BEGIN TRANSACTION;
		DELETE sal
		FROM dbo.DimSalesPeople sal
		JOIN dbo.SalesPeople_Preload pl
			ON sal.SalespersonKey = pl.SalespersonKey;
		INSERT INTO dbo.DimSalesPeople
		SELECT * FROM dbo.SalesPeople_Preload;
	COMMIT TRANSACTION;
END;
-- Cities Load 
GO
CREATE PROCEDURE dbo.Cities_Load
	AS
	BEGIN;
		SET NOCOUNT ON;
		SET XACT_ABORT ON;
		BEGIN TRANSACTION;
		DELETE cit 
		FROM dbo.DimCities cit
		JOIN dbo.Cities_Preload pl
			ON cit.CityKey = pl.CityKey;
		INSERT INTO dbo.DimCities
		SELECT * FROM dbo.Cities_Preload;
	COMMIT TRANSACTION;
END;
--Suppliers Load
GO 
CREATE PROCEDURE dbo.Suppliers_Load
	AS 
	BEGIN;
		SET NOCOUNT ON;
		SET XACT_ABORT ON;
		BEGIN TRANSACTION;
		DELETE sup
		FROM dbo.DimSuppliers sup
		JOIN dbo.Suppliers_Preload pl
			ON sup.SupplierKey = sup.SupplierKey;
		INSERT INTO dbo.DimSuppliers 
		SELECT * FROM dbo.Suppliers_Preload;
	COMMIT TRANSACTION;
END;
--Order Load
GO
CREATE PROCEDURE dbo.Orders_Load
AS
	BEGIN;
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	INSERT INTO dbo.FactOrders /* Columns excluded for brevity */
	SELECT * /* Columns excluded for brevity */
		FROM dbo.Orders_Preload;
END;

--Requirement 7 - Load rest of data to DWH and Query
--Execute the transforms
GO
EXECUTE dbo.Cities_Transform;

GO
EXECUTE dbo.Customers_Transform;

GO 
EXECUTE dbo.Products_Transform;

GO
EXECUTE dbo.SalesPeople_Transform;

GO
EXECUTE dbo.Suppliers_Transform;

GO 
EXECUTE dbo.Orders_Transform;

--Execute the Loads
GO
EXECUTE dbo.Cities_Load;

GO
EXECUTE dbo.Customers_Load;

GO
EXECUTE dbo.Products_Load;

GO
EXECUTE dbo.SalesPeople_Load;

GO
EXECUTE dbo.Suppliers_Load;

--Load 4 days worth of data from 2013-01-01 to 2013-01-04 into the Data Warehouse, this requires we execute each order procedure 3 more times
-- and execute DimDate_Load 4 times 
GO
DECLARE @OrderDate DATE = '2013-01-01'
EXECUTE dbo.DimDate_Load @OrderDate;
GO
EXECUTE dbo.Orders_Load;

--2013-01-02
GO
DECLARE @OrderDate DATE = '2013-01-02'
EXECUTE dbo.DimDate_Load @OrderDate;
GO
EXECUTE dbo.Orders_Extract @OrderDate = '2013-01-02';
GO 
EXECUTE dbo.Orders_Transform;
GO
EXECUTE dbo.Orders_Load;

--2013-01-03
GO
DECLARE @OrderDate DATE = '2013-01-03'
EXECUTE dbo.DimDate_Load @OrderDate;
EXECUTE dbo.Orders_Extract @OrderDate = '2013-01-03';
GO 
EXECUTE dbo.Orders_Transform;
GO
EXECUTE dbo.Orders_Load;

--2013-01-04
GO
DECLARE @OrderDate DATE = '2013-01-04'
EXECUTE dbo.DimDate_Load @OrderDate;
GO
EXECUTE dbo.Orders_Extract @OrderDate = '2013-01-04';
GO 
EXECUTE dbo.Orders_Transform;
GO
EXECUTE dbo.Orders_Load;

--Execute the Interesting Query
DECLARE @OrderDate DATE = '2013-01-01';
SELECT * FROM dbo.GetOrderFactsByAndAboveDate(@OrderDate);
