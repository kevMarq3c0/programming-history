--For the Practical Final -> Be sure to use xabort, not try catch
use master;
GO
Alter database Project3  set single_user with rollback immediate;
GO
/*
DROP Database Project3;
GO 

CREATE DATABASE Project3;
GO
*/
USE Project3;
GO

--Departments
CREATE TABLE dbo.Departments (
    DepartmentID       INT IDENTITY PRIMARY KEY,
    DepartmentName NVARCHAR(50),
    DepartmentDesc  NVARCHAR(150) NOT NULL CONSTRAINT DF_DFDeptDesc DEFAULT 'Dept. Desc to be determined'
);

CREATE TABLE dbo.Employees (
    EmployeeID               INT IDENTITY PRIMARY KEY,
    DepartmentID            INT CONSTRAINT FK_Employee_Department FOREIGN KEY REFERENCES dbo.Departments ( DepartmentID ),
    ManagerEmployeeID INT CONSTRAINT FK_Employee_Manager FOREIGN KEY REFERENCES dbo.Employees ( EmployeeID ),
    FirstName                  NVARCHAR(50),
    LastName                  NVARCHAR(50),
    Salary                        MONEY CONSTRAINT CK_EmployeeSalary CHECK ( Salary >= 0 ),
    CommissionBonus    MONEY CONSTRAINT CK_EmployeeCommission CHECK ( CommissionBonus >= 0 ),
    FileFolder                  NVARCHAR(256) CONSTRAINT DF_FileFolder DEFAULT 'ToBeCreated'
);

GO
INSERT INTO dbo.Departments ( DepartmentName, DepartmentDesc )
VALUES ( 'Management', 'Executive Management' ),
       ( 'HR', 'Human Resources' ),
       ( 'DatabaseMgmt', 'Database Management'),
       ( 'Support', 'Product Support' ),
       ( 'Software', 'Software Sales' ),
       ( 'Marketing', 'Digital Marketing' );
GO

SET IDENTITY_INSERT dbo.Employees ON;
GO

INSERT INTO dbo.Employees ( EmployeeID, DepartmentID, ManagerEmployeeID, FirstName, LastName, Salary, CommissionBonus, FileFolder )
VALUES ( 1, 4, NULL, 'Sarah', 'Campbell', 78000, NULL, 'SarahCampbell' ),
       ( 2, 3, 1, 'James', 'Donoghue',     68000 , NULL, 'JamesDonoghue'),
       ( 3, 1, 1, 'Hank', 'Braby',        76000 , NULL, 'HankBraby'),
       ( 4, 2, 1, 'Samantha', 'Jonus',    72000, NULL , 'SamanthaJonus'),
       ( 5, 3, 4, 'Fred', 'Judd',         44000, 5000, 'FredJudd'),
       ( 6, 3, NULL, 'Hanah', 'Grant',   65000, 4000 ,  'HanahGrant'),
       ( 7, 3, 4, 'Dhruv', 'Patel',       66000, 2000 ,  'DhruvPatel'),
       ( 8, 4, 3, 'Dash', 'Mansfeld',     54000, 5000 ,  'DashMansfeld');
GO

SET IDENTITY_INSERT dbo.Employees OFF;
GO

CREATE FUNCTION dbo.GetEmployeeID (
    -- Parameter datatype and scale match their targets
    @FirstName NVARCHAR(50),
    @LastName  NVARCHAR(50) )
RETURNS INT
AS
BEGIN;


    DECLARE @ID INT;

    SELECT @ID = EmployeeID
    FROM dbo.Employees
    WHERE FirstName = @FirstName
          AND LastName = @LastName;

    -- Note that it is not necessary to initialize @ID or test for NULL, 
    -- NULL is the default, so if it is not overwritten by the select statement
    -- above, NULL will be returned.
    RETURN @ID;
END;
GO

/* REQUIREMENT 1*/
--Create a stored procedure to insert into dbo.Departments -- Complete
CREATE PROCEDURE dbo.Insert_Department (@Name NVARCHAR(50), @Desc NVARCHAR(150)) AS
BEGIN;
	SET NOCOUNT ON;

	INSERT INTO dbo.Departments ( DepartmentName, DepartmentDesc )
	VALUES ( @Name, @Desc);
END; 
GO

--Write a script that will execute the procedure created in requirement 1, thereby testing it 
--Test if procedure has succeeded 
SELECT * FROM dbo.Departments;

--Post using the procedure to insert the stored procedure
DECLARE @DepartmentName VARCHAR(50) = 'QA'
DECLARE @DepartmentDesc VARCHAR(150) = 'Software Testing and Quality Assurance'
EXECUTE dbo.Insert_Department @DepartmentName, @DepartmentDesc

EXECUTE dbo.Insert_Department 'SysDev', 'Systems Design and Development'
EXECUTE dbo.Insert_Department 'Development', 'Development and Production Support'
EXECUTE dbo.Insert_Department 'TechSupport', 'Online Technical Support';

--Create a function to get a Department_ID by name (not DESC) - Should use one parameter to reference DepartmentName and return an INT for DepartmentID 
--If not found, return null -- Complete
GO
CREATE FUNCTION dbo.GetDepartmentID (@DepartmentName VARCHAR(50))
RETURNS INT 
AS 
BEGIN
	DECLARE @DepartmentID INT;

	SELECT @DepartmentID = DepartmentID
	FROM dbo.Departments
	WHERE DepartmentName = @DepartmentName;

	RETURN @DepartmentID;
END;
GO

SELECT * FROM dbo.Employees;

GO


--Create a stored procedure that will insert a record into dbo.Employees, should accept the following parameters 
--DepartmentName, EmployeeFirstName, EmployeeLastName, Salary (optional, if not specified, default 48000), FileFolder, ManagerFirstName, ManagerLastName, 
--CommissionBonus (optional, if not specified, default 4500) -- Complete
CREATE PROCEDURE dbo.CreateEmployeeRecord (
	@DepartmentName NVARCHAR(50),
	@EmployeeFirstName NVARCHAR(50),
	@EmployeeLastName NVARCHAR(50),
	@Salary MONEY = 48000,
	@FileFolder NVARCHAR(256), 
	@ManagerFirstName NVARCHAR(50),
	@ManagerLastName NVARCHAR(50),
	@CommissionBonus MONEY = 4500
)
AS 
BEGIN;
	SET NOCOUNT ON;

	--Declare variables to store the Department and ManagerEmployee ID to be used in our insert statement
	DECLARE @DepartmentID INT;
	DECLARE @ManagerID INT;
	
	--Commit a Transaction to make sure all actions are considered in one transaction and are executed
	--Commit a Try in case we run into an exception with one of the variables or the inserts 
	BEGIN TRANSACTION;
	BEGIN TRY;
			--Check if the function for GetDepartmentID returns null with the DepartmentName, if it does, create that Department
			SELECT @DepartmentID = dbo.GetDepartmentID(@DepartmentName);
			IF @DepartmentID IS NULL
			BEGIN;
				EXECUTE dbo.Insert_Department @DepartmentName, @DepartmentName;

				--Try again with the function to record the newly made Department to use in our Insert statement
				SELECT @DepartmentID = dbo.GetDepartmentID(@DepartmentName);
			END;

			--Check if the function for GetEmployeeID returns null with our manager first and last name, if it does, create that manager 
			SELECT @ManagerID = dbo.GetEmployeeID(@ManagerFirstName, @ManagerLastName);
			IF @ManagerID IS NULL
			BEGIN;
				--The FileFolder for this entry should be a concatenation of the Manager first and last name 
				SELECT @FileFolder = CONCAT(@ManagerFirstName, @ManagerLastName);

				INSERT INTO dbo.Employees(DepartmentID, ManagerEmployeeID, FirstName, LastName, Salary, CommissionBonus, FileFolder)
				VALUES(@DepartmentID, NULL, @ManagerFirstName, @ManagerLastName, @Salary, @CommissionBonus, @FileFolder);

				--Record and return the last identity value created in the scope of this Insert statement
				SET @ManagerID = SCOPE_IDENTITY();
			END;

			--Concatenate the Employee First and Last name to represent the FileFolder
			SELECT @FileFolder = CONCAT(@EmployeeFirstName, @EmployeeLastName);

			INSERT INTO dbo.Employees(DepartmentID, ManagerEmployeeID, FirstName, LastName, Salary, CommissionBonus, FileFolder)
			VALUES(@DepartmentID, @ManagerID, @EmployeeFirstName, @EmployeeLastName, @Salary, @CommissionBonus, @FileFolder);

		--Commit the Transaction if the Employee insert was successful
		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH;
		ROLLBACK TRANSACTION;
		THROW;
	END CATCH;
END;
GO
--Test and execute dbo.CreateEmployeeRecord
EXECUTE dbo.CreateEmployeeRecord 
	@DepartmentName = 'Infrastructure',
	@EmployeeFirstName = 'Wherewolf',
	@EmployeeLastName = 'Waldo',
	@FileFolder = 'KevinMarquez', 
	@ManagerFirstName = 'Kevin',
	@ManagerLastName = 'Marquez';

EXECUTE dbo.CreateEmployeeRecord 
	@DepartmentName = 'Support',
	@EmployeeFirstName = 'Kevin',
	@EmployeeLastName = 'Marquez',
	@Salary = 42000,
	@FileFolder = 'KevinMarquez', 
	@ManagerFirstName = 'Sarah',
	@ManagerLastName = 'Campbell',
	@CommissionBonus = 1500;

SELECT * FROM dbo.Employees;
SELECT * FROM dbo.Departments;

--Write a table value function that will return a table displaying all the employee and department data (without the ID values) for employees 
--greater than a commission value - Only execute the select if the commission is >= 0 -- Complete
GO
CREATE FUNCTION dbo.GetEmployeesAboveCommission (
	@CommissionBenchmark MONEY
)
--Return this given table 
RETURNS @EmployeeCommission TABLE (
	EmployeeFirstName NVARCHAR(50),
	EmployeeLastName NVARCHAR(50),
	EmployeeSalary MONEY, 
	EmployeeCommission MONEY,
	EmployeeFileFolder NVARCHAR(256),
	DepartmentName NVARCHAR(50),
	DepartmentDesc NVARCHAR(150)
)
AS
BEGIN
	--Ensure the Select only happens if the given Commission parameter is greater than or equal to zero 
	IF @CommissionBenchmark >= 0
	BEGIN; 
		--Insert the results of the Select into the EmployeeCommission table 
		INSERT INTO @EmployeeCommission
		SELECT emp.FirstName, emp.LastName, emp.Salary, emp.CommissionBonus, emp.FileFolder,
		dep.DepartmentName, dep.DepartmentDesc FROM dbo.Employees emp
		INNER JOIN dbo.Departments dep ON emp.DepartmentID = dep.DepartmentID
		WHERE emp.CommissionBonus >= @CommissionBenchmark 
	END;
	--Return the table
	RETURN;
END;
GO

--Test the Multi-statement Table valued function 
DECLARE @CommissionBench MONEY = 4500;
SELECT * FROM dbo.GetEmployeesAboveCommission(@CommissionBench);

DECLARE @CommissionBenchZero MONEY = 0;
SELECT * FROM dbo.GetEmployeesAboveCommission(@CommissionBenchZero);

DECLARE @CommissionBenchBad MONEY = -1;
SELECT * FROM dbo.GetEmployeesAboveCommission(@CommissionBenchBad);

--Write a window function that will rank employees by department, based on descending Salary - the query should also get the name and salary of the 
--person above them - include the average salary that shows how each person and department compares to each other 
--Add a TotalCompensation column that shows the total of Salary + CommissionBonus -- Completed
WITH EmployeesByDepartment AS (
	--Prepare columns that can be used in the window function from the Employees and Departments table 
	SELECT CONCAT(emp.FirstName, ' ', emp.LastName) AS EmployeeName,
		emp.Salary, emp.CommissionBonus, dep.DepartmentName
	FROM dbo.Employees emp
	INNER JOIN dbo.Departments dep ON emp.DepartmentID = dep.DepartmentID
)
--Get the ranks partitioned by the department sorted by the salaries desc 
SELECT RANK() OVER (PARTITION BY DepartmentName ORDER BY Salary DESC) AS DepartmentRank,
	   EmployeeName,
	   DepartmentName,
	   Salary,
	   --Get the next leading name and salary of the person above them and also them below them
	   LEAD(Salary) OVER (PARTITION BY DepartmentName ORDER BY DepartmentName, Salary DESC) AS NextLowest,
	   LEAD(EmployeeName) OVER (PARTITION BY DepartmentName ORDER BY DepartmentName, Salary DESC) AS NextLowestEmployee,
	   LAG(Salary) OVER (PARTITION BY DepartmentName ORDER BY DepartmentName, Salary DESC) AS NextHighest,
	   LAG(EmployeeName) OVER (PARTITION BY DepartmentName ORDER BY DepartmentName, Salary DESC) AS NextHighestEmployee,
	   --Get the average salary by each department to compare with the salary of the employee 
	   AVG(Salary) OVER ( PARTITION BY DepartmentName) AS AvgSalaryByDepartment,
	   --Change CommissionBonus null with 0
	   ISNULL(CommissionBonus, 0) AS CommissionBonus,
	   --Add up the total compensation 
	   SUM(Salary + ISNULL(CommissionBonus, 0)) OVER (ORDER BY Salary DESC) AS TotalCompensation
FROM EmployeesByDepartment
ORDER BY DepartmentName DESC;

--Write a recursive CTE that will get employees by their manager 
--Include the Employee LastName, Employee FirstName, DepartmentID, FileFolder, Manager LastName, and Manager FirstName
--Include a File Path to see who each employee reports to directly --Completed
WITH ManagersByEmployee (EmployeeID, EmployeeLastName, EmployeeFirstName, DepartmentID, FileFolder, FilePath, ManagerLastName, ManagerFirstName, ManagerEmployeeID) AS 
(
	--Provide an Anchor member where it stops once the given Employee has no Managers, it does not reference our CTE
	SELECT EmployeeID, 
		   LastName AS EmployeeLastName,
		   FirstName AS EmployeeFirstName,
		   DepartmentID,
		   FileFolder,
		   --Cast the FileFolder as a VARCHAR(MAX) that can be used in our Recursive Member known as FilePath
		   CAST(FileFolder AS VARCHAR(MAX)) AS FilePath, 
		   LastName AS ManagerLastName,
		   FirstName AS ManagerFirstName,
		   ManagerEmployeeID
		   FROM dbo.Employees
		   WHERE ManagerEmployeeID IS NULL

	--Recursive Member, joined by using UNION ALL and references our CTE
	UNION ALL
	SELECT emp.EmployeeID, 
	emp.LastName AS EmployeeLastName,
	emp.FirstName AS EmployeeFirstName,
	emp.DepartmentID,
	emp.FileFolder,
	--Generate the full FilePath for this employee and each manager they report to and who their manager reports to 
	magEmp.FilePath + '\ ' + CAST(emp.FileFolder AS VARCHAR(MAX)) AS FilePath, 
	magEmp.EmployeeLastName AS ManagerLastName,
	magEmp.EmployeeFirstName AS ManagerFirstName,
	emp.ManagerEmployeeID FROM dbo.Employees emp
	INNER JOIN ManagersByEmployee magEmp ON emp.ManagerEmployeeID = magEmp.EmployeeID
)
SELECT * 
FROM ManagersByEmployee
WHERE ManagerEmployeeID IS NOT NULL
ORDER BY EmployeeID

--These are to keep checking with the Database tables to compare results to see if they are accurate or have been updated
SELECT * FROM dbo.Employees;
SELECT * FROM dbo.Departments;