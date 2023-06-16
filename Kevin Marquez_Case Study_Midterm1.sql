-- CaseStudy1 Initial Database b1 - Enter Your Student Name Here : Kevin Marquez 
-- ADD YOUR Midterm Practical CaseStudy1 SQL Code AT the Bottom of this SQL DDL Code ... based on the Business Requirements ... :
--/*
USE MASTER;
GO

DROP DATABASE CaseStudy1
GO
--*/

CREATE DATABASE CaseStudy1;
GO

USE CaseStudy1;
GO

-- Station
CREATE TABLE dbo.Station (
    StationID   INT IDENTITY CONSTRAINT PK_Station PRIMARY KEY,
    StationName NVARCHAR(50) NOT NULL,  
    MaxCapacity INT NOT NULL,
       CONSTRAINT AK_Station_StationName UNIQUE ( StationName ),
       CONSTRAINT CK_Station_MaxCapacity_1 CHECK ( MaxCapacity >= 0 )
    -- NOTE: Current count should not be included since it would Violate 3NF.
);

-- WorkSchoolOrg
CREATE TABLE dbo.WorkSchoolOrg (
    WorkSchoolOrgID    INT IDENTITY CONSTRAINT PK_WorkSchoolOrg PRIMARY KEY,
    WorkSchoolOrgName  NVARCHAR(75) NOT NULL 

);
CREATE INDEX IX_WorkSchoolOrg_WorkSchoolOrgName ON dbo.WorkSchoolOrg ( WorkSchoolOrgName );

-- Pilot
CREATE TABLE dbo.Pilot (
    PilotID          INT IDENTITY CONSTRAINT PK_Pilot PRIMARY KEY,   
    FirstName        NVARCHAR(50) NOT NULL,
    LastName         NVARCHAR(50) NOT NULL,
    TransportCanadaCertNumber    NVARCHAR(75) NOT NULL, 
    PilotSIN         CHAR(9) NOT NULL, 
    DateOfBirth      DATE NOT NULL,
    WorkSchoolOrgID  INT NULL
       CONSTRAINT FK_Pilot_WorkSchoolOrg FOREIGN KEY ( WorkSchoolOrgID  ) REFERENCES dbo.WorkSchoolOrg ( WorkSchoolOrgID ),
       CONSTRAINT AK_Pilot_PilotSIN UNIQUE ( PilotSIN ),
       CONSTRAINT CK_Pilot_DateOfBirth_1 CHECK ( DateOfBirth <= GETDATE() )
);

CREATE INDEX FK_Pilot_WorkSchoolOrg ON dbo.Pilot ( WorkSchoolOrgID );

-- EquipmentType
CREATE TABLE dbo.EquipmentType (
    EquipmentTypeID   INT IDENTITY CONSTRAINT PK_EquipmentType PRIMARY KEY,
    EquipmentTypeName NVARCHAR(50) NOT NULL 

);
-- Manufacturer
CREATE TABLE dbo.Manufacturer (
    ManufacturerID   INT IDENTITY CONSTRAINT PK_Manufacturer PRIMARY KEY,
    ManufacturerName NVARCHAR(75) NOT NULL 

);
-- Model
CREATE TABLE dbo.Model (
    ModelID          INT IDENTITY CONSTRAINT PK_Model PRIMARY KEY,
    ModelName        NVARCHAR(75) NOT NULL,
    ManufacturerID   INT NULL CONSTRAINT FK_Manufacturer  REFERENCES dbo.Manufacturer  (ManufacturerID ), 

);
CREATE INDEX FK_Model_Manufacturer ON dbo.Model ( ManufacturerID );

-- DroneEquipment
CREATE TABLE dbo.DroneEquipment (
    DroneEquipmentID INT IDENTITY CONSTRAINT PK_DroneEquipment PRIMARY KEY,
    HomeStationID    INT NOT NULL CONSTRAINT FK_DroneEquipment_Station_Home REFERENCES dbo.Station ( StationID ),
    CurrentStationID INT NOT NULL CONSTRAINT FK_DroneEquipment_Station_Current REFERENCES dbo.Station ( StationID ),
    PilotID          INT NULL CONSTRAINT FK_DroneEquipment_Pilot REFERENCES dbo.Pilot ( PilotID ),
    EquipmentTypeID  INT NULL CONSTRAINT FK_DroneEquipment_EquipmentTypeID  REFERENCES dbo.EquipmentType ( EquipmentTypeID  ),
    TransportCanadaDroneIdentMarking    NVARCHAR(75) NULL,    -- Accessory equipment does not have to have this marking, so can be NULL...
    ModelID          INT NULL CONSTRAINT FK_DroneEquipment_Model  REFERENCES dbo.Model ( ModelID ),
    SerialNumber     NVARCHAR(50) NOT NULL,
    ManufacturedDate DATETIME NULL,
	 CONSTRAINT AK_DroneEquipment_SerialNumber UNIQUE ( SerialNumber )
);
CREATE INDEX FK_DroneEquipment_Station_Home ON dbo.DroneEquipment ( HomeStationID );
CREATE INDEX FK_DroneEquipment_Station_Current ON dbo.DroneEquipment ( CurrentStationID );
CREATE INDEX FK_DroneEquipment_Pilot ON dbo.DroneEquipment ( PilotID );
CREATE INDEX FK_DroneEquipment_EquipmentType ON dbo.DroneEquipment ( EquipmentTypeID );
CREATE INDEX FK_DroneEquipment_Model ON dbo.DroneEquipment ( ModelID );

-- Account
CREATE TABLE dbo.Account (
    AccountID       INT IDENTITY CONSTRAINT PK_Accounts PRIMARY KEY,
    AccountNumber   CHAR(15) NOT NULL,
    CurrentBalance  MONEY NOT NULL CONSTRAINT DF_Account_CurrentBalance DEFAULT 0,
    AccountOpenDate DATE NOT NULL CONSTRAINT DF_Account_AccountOpenDate DEFAULT GETDATE(),
	CONSTRAINT AK_Account_AccountNumber UNIQUE ( AccountNumber ),
	CONSTRAINT CK_Account_AccountOpenDate_1 CHECK ( AccountOpenDate <= GETDATE() )
);

-- Address
CREATE TABLE dbo.Address (
    AddressID INT IDENTITY CONSTRAINT PK_Address PRIMARY KEY,
    Street    NVARCHAR(50),
    City      NVARCHAR(50) CONSTRAINT DF_Address_City DEFAULT 'London',
    Province  NVARCHAR(50) CONSTRAINT DF_Address_Province DEFAULT 'Ontario',
    Postal    CHAR(6)
);
CREATE INDEX IX_Address_City_Postal ON dbo.Address ( City, Postal );
CREATE INDEX IX_Address_Postal ON dbo.Address ( Postal );

-- PilotAccount
CREATE TABLE dbo.PilotAccount (
    PilotAccountID INT IDENTITY,
    PilotID        INT NOT NULL,
    AccountID      INT NOT NULL,
    PilotAccountStartDate DATE NOT NULL,

    -- Just an example of a different sytnax for creating constraints
       CONSTRAINT PK_PilotAccount PRIMARY KEY ( PilotAccountID ),    
       CONSTRAINT FK_PilotAccount_Pilot FOREIGN KEY ( PilotID ) REFERENCES dbo.Pilot ( PilotID ),
       CONSTRAINT FK_PilotAccount_Account FOREIGN KEY ( AccountID ) REFERENCES dbo.Account ( AccountID )
);
CREATE INDEX IX_PilotAccount_PilotID_AccountID ON dbo.PilotAccount ( PilotID, AccountID );
CREATE INDEX IX_PilotAccount_AccountID_PilotID ON dbo.PilotAccount ( AccountID, PilotID );

-- PilotAddress
CREATE TABLE dbo.PilotAddress (
    PilotAddressID INT IDENTITY,
    PilotID        INT NOT NULL,
    AddressID      INT NOT NULL,
    PilotAddressStartDate DATE NOT NULL,

       CONSTRAINT PK_PilotAddress PRIMARY KEY ( PilotAddressID ),
       CONSTRAINT FK_PilotAddress_Pilot FOREIGN KEY ( PilotID ) REFERENCES dbo.Pilot ( PilotID ),
       CONSTRAINT FK_PilotAddress_Address FOREIGN KEY ( AddressID ) REFERENCES dbo.Address ( AddressID )
);
GO
CREATE INDEX IX_PilotAddress_PilotID_AddressID ON dbo.PilotAddress ( PilotID, AddressID );
CREATE INDEX IX_PilotAddress_AddressID_PilotID ON dbo.PilotAddress ( AddressID, PilotID );

--  ADD YOUR Midterm Practical CaseStudy1 SQL Code Here ... based on the Business Requirements ... :
--Technician 
CREATE TABLE dbo.Technician (
	TechnicianID INT IDENTITY CONSTRAINT PK_Technician PRIMARY KEY,
	FirstName	NVARCHAR(50) NOT NULL,
	LastName	NVARCHAR(50) NOT NULL,
	TechnicianSIN	CHAR(9) NOT NULL,
	HourlyRate		MONEY NOT NULL CONSTRAINT DF_Technician_HourlyRate DEFAULT 19,
	StationID		INT NOT NULL,

	CONSTRAINT FK_Technician_Station FOREIGN KEY (StationID) REFERENCES dbo.Station (StationID),
	CONSTRAINT AK_Technician_TechnicianSIN UNIQUE (TechnicianSIN),
	CONSTRAINT CK_Technician_HourlyRate_1 CHECK (HourlyRate >= 19)
);
CREATE INDEX FK_Technician_HomeStationID ON dbo.Technician(StationID);
CREATE INDEX IX_Technician_LastName_FirstName ON dbo.Technician(LastName, FirstName);
CREATE INDEX IX_Technician_FirstName ON dbo.Technician(FirstName);

--Phone
CREATE TABLE dbo.Phone (
	PhoneID INT IDENTITY CONSTRAINT PK_PilotPhones PRIMARY KEY,
	PilotID		INT NOT NULL,
	PhoneNum CHAR(10) NOT NULL,
	PhoneType NVARCHAR(50) NOT NULL CONSTRAINT DF_Phones_PhoneType DEFAULT 'Mobile'

	CONSTRAINT FK_Phone_Pilot FOREIGN KEY (PilotID) REFERENCES dbo.Pilot (PilotID),
	CONSTRAINT AK_Phone_PhoneNum UNIQUE (PhoneNum)
);
CREATE INDEX FK_PilotPhone_PilotID ON dbo.Phone(PilotID);

--RepairDescription
CREATE TABLE dbo.RepairDescription (
	RepairDescriptionID INT IDENTITY CONSTRAINT PK_RepairDescription PRIMARY KEY,
	RepairDescription NVARCHAR(100) NOT NULL
);

--Part
CREATE TABLE Part (
	PartID INT IDENTITY CONSTRAINT PK_Part PRIMARY KEY, 
	PartName	NVARCHAR(50) NOT NULL,
	ManufacturerID INT NOT NULL,
	SerialNum	INT NOT NULL

	CONSTRAINT FK_Part_Manufacturer FOREIGN KEY (ManufacturerID) REFERENCES dbo.Manufacturer (ManufacturerID),
	CONSTRAINT AK_Part_SerialNum UNIQUE (SerialNum)
);
CREATE INDEX FK_Part_ManufacturerID ON dbo.Part(ManufacturerID);

--TechnicianDrone
CREATE TABLE dbo.TechnicianDrone (
	TechnicianDroneID INT IDENTITY,
	TechnicianID INT NOT NULL,
	DroneEquipmentID INT NOT NULL,
	RepairDescriptionID INT NOT NULL,
	PartID INT NOT NULL

	CONSTRAINT PK_TechnicianDrone PRIMARY KEY ( TechnicianDroneID ),
    CONSTRAINT FK_TechnicianDrone_Technician FOREIGN KEY ( TechnicianID ) REFERENCES dbo.Technician ( TechnicianID ),
    CONSTRAINT FK_TechnicianDrone_DroneEquipment FOREIGN KEY ( DroneEquipmentID ) REFERENCES dbo.DroneEquipment ( DroneEquipmentID ),
	CONSTRAINT FK_TechnicianDrone_RepairDescription FOREIGN KEY (RepairDescriptionID) REFERENCES dbo.RepairDescription (RepairDescriptionID),
	CONSTRAINT FK_TechnicianDrone_PartID FOREIGN KEY (PartID) REFERENCES dbo.Part(PartID)
);
CREATE INDEX IX_TechnicianDrone_TechnicianID_DroneEquipmentID ON dbo.TechnicianDrone (TechnicianID, DroneEquipmentID);
CREATE INDEX IX_TechnicianDrone_DroneEquipmentID_TechnicianID ON dbo.TechnicianDrone (DroneEquipmentID, TechnicianID);
CREATE INDEX FK_TechnicianDrone_RepairDescriptionID ON dbo.TechnicianDrone (RepairDescriptionID);
CREATE INDEX FK_TechnicianDrone_PartID ON dbo.TechnicianDrone (PartID);


