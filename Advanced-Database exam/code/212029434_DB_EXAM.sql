-- CASE STUDY: Advanced-Database exam

-- Question A1: Fragment & Recombine Main Fact
-- A1. 1: Create horizontally fragmented tables Shipment_A on Node_A and Shipment_B on Node_B using a deterministic rule (HASH or RANGE on a natural key).

-- Horizantally Fragments the shipments table using a status column
-- Shipment_A  contains all shipment that has status of either 'Pending','Canceled'

CREATE TABLE Shipment_A (
    shipment_id SERIAL PRIMARY KEY,
    vehicle_id INT NOT NULL,
    driver_id INT NOT NULL,
    route_id INT NOT NULL,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    status VARCHAR(20) NOT NULL CHECK (status IN ('Pending', 'Canceled')),
    CONSTRAINT fk_shipmentA_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id),
    CONSTRAINT fk_shipmentA_driver FOREIGN KEY (driver_id) REFERENCES drivers(driver_id),
    CONSTRAINT fk_shipmentA_route FOREIGN KEY (route_id) REFERENCES routes(route_id)
);

-- Shipment_B  contains all shipment that has status of either 'In Transit', 'Delivered'
CREATE TABLE Shipment_B (
    shipment_id SERIAL PRIMARY KEY,
    vehicle_id INT NOT NULL,
    driver_id INT NOT NULL,
    route_id INT NOT NULL,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    status VARCHAR(20) NOT NULL CHECK (status IN ('In Transit', 'Delivered')),
    CONSTRAINT fk_shipmentA_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id),
    CONSTRAINT fk_shipmentA_driver FOREIGN KEY (driver_id) REFERENCES drivers(driver_id),
    CONSTRAINT fk_shipmentA_route FOREIGN KEY (route_id) REFERENCES routes(route_id)
);


-- Since shipment table dependes on base table like vehicles,drivers,routes.We will need to define those additional table too

-- 1. DDL for vehicles tables
CREATE TABLE IF NOT EXISTS vehicles (
    vehicle_id SERIAL PRIMARY KEY,  -- Unique identifier for each vehicle
    model VARCHAR(100) NOT NULL,    -- Vehicle model name
    plate_no VARCHAR(20) NOT NULL UNIQUE, -- Unique license plate number
    type VARCHAR(50) NOT NULL,      -- Vehicle type (e.g., Truck, Van)
    status VARCHAR(20) NOT NULL CHECK (status IN ('Active', 'In Transit', 'Under Maintenance','Retired')), -- Current status of the vehicle
    capacity INT NOT NULL CHECK (capacity > 0) -- Maximum load capacity
);

-- 2.  DDL for Drivers Table: Stores driver details
CREATE TABLE IF NOT EXISTS drivers (
    driver_id SERIAL PRIMARY KEY,   -- Unique identifier for each driver
    full_name VARCHAR(100) NOT NULL,  -- full name of the driver
    license_no VARCHAR(50) NOT NULL UNIQUE, -- Driver's license number
    contact VARCHAR(50),            -- Contact information
    experience_years INT NOT NULL CHECK (experience_years >= 0) -- Experience in years
);


-- 3.  DDL for Routes Table: Stores predefined delivery routes
CREATE TABLE IF NOT EXISTS routes (
    route_id SERIAL PRIMARY KEY,    -- Unique route identifier
    start_location VARCHAR(100) NOT NULL, -- Starting point
    end_location VARCHAR(100) NOT NULL,   -- Destination
    distance_km DECIMAL(10,2) NOT NULL CHECK (distance_km > 0), -- Distance in kilometers with precision of 10 and 2 digits after decimal point
    type VARCHAR(50) NOT NULL CHECK (type IN ('Urban','Rural','Long-Haul')) -- Route type classification
);

-- 4.  DDL for Maintenance Table: Tracks vehicle maintenance activities
CREATE TABLE IF NOT EXISTS maintenance (
    maintenance_id SERIAL PRIMARY KEY, -- Unique maintenance record
    vehicle_id INT NOT NULL,           -- Vehicle undergoing maintenance
    maintenance_date TIMESTAMP NOT NULL, 
    cost DECIMAL(10,2) NOT NULL CHECK (cost >= 0), -- Maintenance cost
    description TEXT ,               -- Optional details about maintenance
	
	CONSTRAINT fk_vehicle_maitenance FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id)
);

-- 5.  DDL for Payments Table: Stores payments linked to shipments
CREATE TABLE IF NOT EXISTS payments (
    payment_id SERIAL PRIMARY KEY,     -- Unique payment identifier
    shipment_id INT NOT NULL UNIQUE,   -- Each shipment can have only one payment
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0), -- Payment amount
    method VARCHAR(50) NOT NULL CHECK (method IN ('Cash','Bank','Mobile Money')), -- Payment method
    payment_date TIMESTAMP NOT NULL   -- Date of payment
	
	CONSTRAINT fk_shipment_payment FOREIGN KEY (shipment_id) REFERENCES Shipment_A(shipment_id)
);

-- A1.2: Insert a TOTAL of ≤10 committed rows split across the two fragments 

-- Let insert 5 rows in Shipment_A, ensure status either 'Pending','Canceled'
INSERT INTO Shipment_A (vehicle_id, driver_id, route_id, start_date, end_date, status)
VALUES
(1, 2, 3, '2025-10-20 08:00:00',NULL,'Pending'),
(2, 1, 1, '2025-10-21 09:30:00',NULL,'Pending'),
(3, 3, 2,  '2025-10-18 07:45:00','2025-10-19 16:20:00', 'Canceled'),
(4, 4, 4, '2025-10-22 10:15:00', NULL,'Pending'),
(5, 1, 2, '2025-10-15 06:10:00','2025-10-15 18:40:00', 'Canceled');

-- check if the insert was made sucessfully
SELECT * FROM Shipment_A LIMIT 5

-- Let insert 5 rows in Shipment_B, ensure status either 'In Transit', 'Delivered'
INSERT INTO Shipment_B (vehicle_id, driver_id, route_id, start_date, end_date, status)
VALUES
(1, 2, 3, '2025-10-18 07:00:00', NULL, 'In Transit'),
(2, 1, 1, '2025-10-14 08:45:00', '2025-10-14 20:15:00', 'Delivered'),
(3, 3, 2, '2025-10-16 09:10:00', NULL, 'In Transit'),
(4, 4, 4, '2025-10-17 07:30:00', '2025-10-17 19:00:00', 'Delivered'),
(5, 1, 2, '2025-10-23 06:50:00', NULL, 'In Transit');

-- check if the insert was made sucessfully
SELECT * FROM Shipment_B LIMIT 5


-- A1.3: On Node_A, create view Shipment_ALL as UNION ALL of Shipment_A and
-- Shipment_B

-- since Shipment_A is on local node(Node_A), and Shipment_B  on remote one(Node_B).
-- We’ll use PostgreSQL’s dblink extension to pull data from the remote Node_B.

-- On Node_A, ensure the dblink extension is enabled:
CREATE EXTENSION IF NOT EXISTS dblink;

-- Create a global view combining local and remote fragments
-- Shipment_A is local on Node_A
-- Shipment_B is remote on Node_B, accessed via dblink
CREATE OR REPLACE VIEW Shipment_ALL AS
-- Select all rows from local fragment
SELECT * 
FROM Shipment_A

UNION ALL  -- Combine with remote fragment, keeping duplicates if any

-- Fetch remote fragment Shipment_B using dblink
SELECT *
FROM dblink(
    -- Connection string to remote Node_B database
    'host=localhost port=5432 dbname=Node_B user=postgres password=postgres',
    
    -- SQL query to run on the remote database
    'SELECT shipment_id, vehicle_id, driver_id, route_id, start_date, end_date, status FROM Shipment_B'
) AS remote_shipments(
    -- Define column names and data types for the remote query result
    shipment_id INT,
    vehicle_id INT,
    driver_id INT,
    route_id INT,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    status VARCHAR(20)
);

-- Display data from our view
SELECT * FROM Shipment_ALL


-- A1.4:Validate with COUNT(*) and a checksum on a key column (e.g., SUM(MOD(primary_key,97))) :results must match fragments vs Shipment_ALL.

-- Validate Checksum on Primary Key
-- Local fragment
SELECT SUM(MOD(shipment_id, 97)) AS checksum_local FROM Shipment_A;

-- Remote fragment via dblink
SELECT SUM(MOD(shipment_id, 97)) AS checksum_remote
FROM dblink(
    'host=localhost port=5432 dbname=Node_B user=postgres password=postgres',
    'SELECT shipment_id FROM Shipment_B'
) AS remote_shipments(shipment_id INT);


-- Checksum for global view
SELECT SUM(MOD(shipment_id, 97)) AS checksum_global FROM Shipment_ALL;



-- Question A2 :Database Link & Cross-Node
-- A2.1. From Node_A, create a database link  to Node_B.

-- to allow to both two databases to communicate we use Foreign Data Wrapper(FDW) 
-- FDW enable access to tables in another database as if they were local
-- FDW stores metadata about how to access the remote table and actual data remains in the remote database

CREATE EXTENSION IF NOT EXISTS postgres_fdw;
-- Create a foreign server 
CREATE SERVER NodeB_connect
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (
    host 'localhost',       -- host where FleetOperations is running
    dbname 'Node_B',  -- remote db to connect to
    port '5432'
);
-- create a user mapping(Map a local user in FleetSupport node  to a user in FleetOperations node)
CREATE USER MAPPING FOR postgres  -- or your local user
SERVER NodeB_connect
OPTIONS (
    user 'postgres',         -- FleetOperations username
    password 'postgres'       -- FleetOperations password
);
-- import  foreign tables from FleetOperations
IMPORT FOREIGN SCHEMA public
LIMIT TO (Shipment_B)
FROM SERVER NodeB_connect INTO public;

-- A2.2. Run remote SELECT on Shipment_B showing up to 5 sample rows.
SELECT *  FROM Shipment_B
LIMIT 5


-- A2.3. Run a distributed join: remote Shipment_B (or base Shipment) joined with a local vehicle
SELECT s.status,COUNT(v.vehicle_id) FROM Shipment_B s
INNER JOIN vehicles v ON v.vehicle_id = s.vehicle_id
GROUP BY 1



-- A3: Parallel vs Serial Aggregation (≤10 rows data)
-- A3.1. 1. Run a SERIAL aggregation on Shipment_ALL over the small dataset (e.g., totals by a domain
-- column). Ensure result has 3–10 groups/rows.


SET max_parallel_workers_per_gather = 0;   -- Disable parallelism
EXPLAIN ANALYZE
SELECT -- Aggregate total shipments by status
    status,
    COUNT(*) AS total_shipments
FROM Shipment_ALL
GROUP BY status
ORDER BY status;

-- Question A3. Parallel vs Serial Aggregation

-- A3.2. Run the same aggregation with /*+ PARALLEL(Shipment_A,8) PARALLEL(Shipment_B,8) */
-- to force a parallel plan despite small size.

SET max_parallel_workers_per_gather = 8;   -- Enable parallelism  and use 8 workers as per instruction
EXPLAIN ANALYZE
SELECT -- Aggregate total shipments by status
    status,
    COUNT(*) AS total_shipments
FROM Shipment_ALL
GROUP BY status
ORDER BY status;

-- A3.3 Capture execution plans with DBMS_XPLAN and show AUTOTRACE statistics; timings may
--Since we are using PostgreSQL, we did not use DBMS_XPLAN (which is specific to Oracle). 
--Instead, we used the EXPLAIN ANALYZE command. This keyword provides detailed execution statistics
-- Run the following query to get execution statistics
EXPLAIN ANALYZE
SELECT -- Aggregate total shipments by status
    status,
    COUNT(*) AS total_shipments
FROM Shipment_ALL
GROUP BY status
ORDER BY status;



-- Question A4 :Two-Phase Commit & Recovery (2 rows)
-- A4.1. Write one PL/SQL block that inserts ONE local row (related Shipment) on Node_A and ONE remote row into payments; then COMMIT.

-- In this section we are going to simulate two phase commit 
-- inserts data on both nodes and committing once. Verify atomicity
-- let create a PL block that create a shipments and then report its corresponding payment
-- the whole operation is atomic which mean the operation will be full completed or not compelete at all in case anything goes wrong

DO $$
DECLARE
    -- Define variable to store the shipment_id generated by the local insert
    new_shipment_id INT;
	
	-- Define variable to hold the remote SQL statement for dblink execution
    remote_sql TEXT; 
BEGIN
    -- Insert a new shipment into the 'shipments' table at Node 1(local DB)
    INSERT INTO Shipment_A (vehicle_id, driver_id, route_id, start_date, end_date, status)
    VALUES (3, 3, 4, CURRENT_DATE, CURRENT_DATE + INTERVAL '2 days', 'Pending')
    RETURNING shipment_id INTO new_shipment_id; -- captures the generated shipment_id into a PL/pgSQL variable

    -- Log the newly generated shipment_id for debugging
    RAISE NOTICE 'New shipment_id = %', new_shipment_id;

    -- Prepare the remote SQL for inserting a payment into Node 2
    -- Use format() with %L to safely quote the shipment_id literal
    remote_sql := format($sql$
        INSERT INTO payments (shipment_id, amount, method, payment_date)
        VALUES (%L, 10000, 'Mobile Money', CURRENT_DATE);
    $sql$, new_shipment_id);

    -- Execute the remote insert using dblink_exec
    PERFORM dblink_exec(
        'dbname=Node_B user=postgres password=postgres host=localhost port=5432',
        remote_sql
    );

    -- Confirm both inserts succeeded
    RAISE NOTICE 'Data inserted successfully on both nodes.';

EXCEPTION
    -- Exception handling: log the error and re-raise it for further debugging
    WHEN OTHERS THEN
        RAISE NOTICE 'Transaction failed: %', SQLERRM;
        RAISE;
END;
$$;


-- A4.2. Induce a failure in a second run (e.g., disable the link between inserts) to create an in-doubt transaction.
-- here we are going to cut connection to Node_B (this is done through providing wrong credentials)
-- We will connect to db using username =postgres password=post, which is incorrect

DO $$
DECLARE
    local_shipment_id INT;   -- Variable to hold the newly inserted shipment ID
    remote_sql TEXT;         -- Variable to hold dynamically generated remote SQL command
    remote_gid TEXT;         -- Global transaction ID (GID) for the remote database transaction
    local_gid TEXT;          -- Global transaction ID (GID) for the local database transaction
BEGIN
    -- Step 1: Insert a new shipment record locally in the 'shipments' table.
    -- The generated shipment_id is captured into the 'local_shipment_id' variable.
    INSERT INTO Shipment_A (vehicle_id, driver_id, route_id, start_date, end_date, status)
    VALUES (3, 3, 4, CURRENT_DATE, CURRENT_DATE + INTERVAL '2 days', 'Canceled')
    RETURNING shipment_id INTO local_shipment_id;

    -- Step 2: Generate unique transaction identifiers (GIDs) for both local and remote transactions.
    -- These identifiers are important for managing distributed transactions using two-phase commit.
    local_gid := format('local_tx_%s', local_shipment_id);
    remote_gid := format('remote_tx_%s', local_shipment_id);

    -- Step 3: Log the generated identifiers for tracking.
    RAISE NOTICE 'Local shipment_id = %, local_gid = %, remote_gid = %',
                 local_shipment_id, local_gid, remote_gid;

    -- Step 4: Simulate a remote failure, by connecting using wrong credentials
    -- to trigger an error, representing a remote database failure scenario.
    remote_sql := format($remote$
        BEGIN;
        INSERT INTO payments (shipment_id, amount, method, payment_date)
        VALUES (%L, 10000, 'Mobile Money', CURRENT_DATE);
        PREPARE TRANSACTION %L;
    $remote$, local_shipment_id, remote_gid);

    BEGIN
        -- Step 5: Attempt to execute the remote transaction using dblink.
        -- If the remote SQL fails (due to the invalid table), the exception block will capture it.
        PERFORM dblink_exec(
            'dbname=Node_B user=postgres password=post host=localhost port=5432',
            remote_sql
        );
    EXCEPTION
        WHEN OTHERS THEN
            -- Step 6: Log the simulated failure for debugging and visibility.
            -- The error message (SQLERRM) will describe the cause of failure.
            RAISE NOTICE '⚠Remote transaction failed: %', SQLERRM;
    END;

    -- Step 7: The local transaction remains unprepared.
    -- It can later be manually prepared or rolled back using its GID if needed.
END;
$$;

-- manually prepare the transaction 
-- this is achieved by runningh PREPARE TRANSACTION outside of DO block and 
-- assign a unique GID(Global identifier)
BEGIN;
PREPARE TRANSACTION 'remote_tx_14';


-- A4.3 3. Query DBA_2PC_PENDING; then issue COMMIT FORCE or ROLLBACK FORCE; re-verify consistency on both nodes.

--Since we used postgres  we didn’t  query DBA_2PC_PENDING, instead we queried  pg_prepared_xacts
--The following is the query to retrieve all unresolved transaction
SELECT * FROM pg_prepared_xacts;

-- ROLLBACK FORCE
ROLLBACK PREPARED 'remote_tx_14’ --- remote_tx_14 specify the GID (global identify for that specific transaction).

-- A4.4 Repeat a clean run to show there are no pending transactions.
-- Run the following query to check if all prepared transaction were fixed.
SELECT * FROM pg_prepared_xacts;


-- Question A5 :Distributed Lock Conflict & Diagnosis

-- A5.1.1. Open Session 1 on Node_A: UPDATE a single row in Maintenance and keep the transaction open. 
-- On Node_A, initiate a transaction for updating maintenance cost of a for  vehicle_id = 3. 
-- Below is the query to achieve this
BEGIN;
-- Lock the record by updating it (but don’t commit yet)
UPDATE maintenance
SET cost = 10000
WHERE vehicle_id = 3;

-- A5.2. Open Session 2 from Node_B to update the same logical row
-- Since we are going to update remote table maintenance which is on node A, so on node B 
-- we are going to create a transaction that remotely updates the record in maintenance table

BEGIN;
SELECT dblink_exec( -- Execute the remote update using dblink
    'dbname=Node_A user=postgres password=postgres host=localhost port=5432',
    $remote$
        UPDATE maintenance
		SET cost = 10000
		WHERE vehicle_id = 3;
    $remote$
);

-- A5.3 Query lock views (DBA_BLOCKERS/DBA_WAITERS/V$LOCK) from Node_A to show the waiting session.
-- Since we used postgres lock views are stored in pg_locks table, 
-- so to get all locked records on maintenance we run following query
SELECT
    pid,
    locktype,
    relation::regclass AS table_name,
    page,
    tuple,
    virtualtransaction,
    mode,
    granted
FROM pg_locks l
JOIN pg_class c ON l.relation = c.oid
WHERE c.relname = 'maintenance';

A5.4. Release the lock; show Session 2 completes. Do not insert more rows; reuse the existing ≤10.
-- For this task we ROLLBACK the transaction because we didn’t the data be persisted.
ROLLBACK;

-- Question A6.Declarative Rules Hardening

-- B6.1 On tables Vehicle and Maintenance, add/verify NOT NULL and domain CHECK constraints

-- vehicle table defintion with constraints requested
CREATE TABLE IF NOT EXISTS vehicles (
    vehicle_id SERIAL PRIMARY KEY,  -- Unique identifier for each vehicle
    model VARCHAR(100) NOT NULL,    -- Vehicle model name
    plate_no VARCHAR(20) NOT NULL UNIQUE, -- Unique license plate number
    type VARCHAR(50) NOT NULL,      -- Vehicle type (e.g., Truck, Van)
    status VARCHAR(20) NOT NULL CHECK (status IN ('Active', 'In Transit', 'Under Maintenance','Retired')), -- Current status of the vehicle
    capacity INT NOT NULL CHECK (capacity > 0) -- Maximum load capacity
);

-- maintenance table defintion with constraints requested
CREATE TABLE IF NOT EXISTS maintenance (
    maintenance_id SERIAL PRIMARY KEY, -- Unique maintenance record
    vehicle_id INT NOT NULL,           -- Vehicle undergoing maintenance
    maintenance_date TIMESTAMP NOT NULL, 
    cost DECIMAL(10,2) NOT NULL CHECK (cost >= 0), -- Maintenance cost
    description TEXT                -- Optional details about maintenance
);



-- A6.2. Prepare 2 failing and 2 passing INSERTs per table to validate rules, but wrap failing ones in a
block and ROLLBACK so committed rows stay within ≤10 total.

-- PASSING INSERTS FOR vehicles TABLE
INSERT INTO vehicles (model, plate_no, type, status, capacity)
VALUES 
('Toyota Hilux', 'RAD123A', 'Truck', 'Active', 3000),
('Isuzu NPR', 'RAD456B', 'Van', 'In Transit', 2500);

-- Check is data persist
SELECT * FROM vehicles


-- FAILING INSERTS FOR vehicles TABLE (Wrapped in a ROLLBACK Block)

BEGIN;

-- Fails due to invalid status (not in allowed list)
INSERT INTO vehicles (model, plate_no, type, status, capacity)
VALUES ('Mitsubishi Fuso', 'RAD789C', 'Truck', 'Broken', 4000);

-- Fails due to negative capacity (violates CHECK constraint)
INSERT INTO vehicles (model, plate_no, type, status, capacity)
VALUES ('Nissan Caravan', 'RAD999D', 'Van', 'Active', -500);

ROLLBACK;  -- Undo the failing inserts so only valid rows remain




-- PASSING INSERTS FOR maintenance TABLE

INSERT INTO maintenance (vehicle_id, maintenance_date, cost, description)
VALUES 
(3, NOW() - INTERVAL '10 days', 150000.00, 'Engine service'),
(4, NOW() - INTERVAL '3 days', 35000.00, 'Brake pad replacement');

-- check if insert persisted
SELECT * FROM maintenance


--- FAILING INSERTS FOR maintenance TABLE (Wrapped in a ROLLBACK Block)

BEGIN;

-- Fails due to negative cost (violates CHECK constraint)
INSERT INTO maintenance (vehicle_id, maintenance_date, cost, description)
VALUES (1, NOW(), -10000.00, 'Oil change');

-- Fails due to missing vehicle_id (NULL not allowed)
INSERT INTO maintenance (vehicle_id, maintenance_date, cost, description)
VALUES (NULL, NOW(), 8000.00, 'Tire replacement');

ROLLBACK;  -- Undo invalid inserts


B7.1. Create an audit table Vehicle_AUDIT(bef_total NUMBER, aft_total NUMBER, changed_at TIMESTAMP, key_col VARCHAR2(64)).

-- Vehicle_AUDIT Table Definition

CREATE TABLE IF NOT EXISTS vehicle_audit (
    bef_total NUMERIC,             -- Total before the change
    aft_total NUMERIC,             -- Total after the change
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- When the change occurred
    key_col VARCHAR(64)            -- Key or identifier of the affected record
);

B7. 2. Implement a statement-level AFTER INSERT/UPDATE/DELETE trigger on Maintenance that recomputes denormalized totals in Vehicle once per statement.

-- Step 1: Add a column to vehicles to hold the total maintenance cost
ALTER TABLE vehicles 
ADD COLUMN total_maintenance_cost NUMERIC(10,2) DEFAULT 0;

-- Step 2: Create the trigger function
-- PURPOSE:
--     Automatically recalculates the total maintenance cost for each
--     vehicle whenever any maintenance record is inserted, updated,
--     or deleted in the `maintenance` table.

CREATE OR REPLACE FUNCTION recompute_vehicle_totals()
RETURNS TRIGGER AS $$
BEGIN
    -- Recompute and update each vehicle’s total maintenance cost
    -- The subquery calculates the SUM of all maintenance costs per vehicle.
    -- COALESCE ensures that if a vehicle has no maintenance records,
    -- its total_maintenance_cost is set to 0 instead of NULL.
    UPDATE vehicles v
    SET total_maintenance_cost = COALESCE((
        SELECT SUM(m.cost)
        FROM maintenance m
        WHERE m.vehicle_id = v.vehicle_id
    ), 0);

    -- Since this function will be used in a statement-level trigger,
    -- it does not process individual rows — returning NULL is required.
    -------------------------------------------------------------------
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Invoke procedure defined below AFTER INSERT, UPDATE, or DELETE

CREATE TRIGGER trg_recompute_vehicle_totals
AFTER INSERT OR UPDATE OR DELETE ON maintenance
FOR EACH STATEMENT
EXECUTE FUNCTION recompute_vehicle_totals();

-- check result from vehicles table after statement is made
SELECT * FROM vehicles
LIMIT 5

B7.3. Execute a small mixed DML script on CHILD affecting at most 4 rows in total; ensure net committed rows across the project remain ≤10.

-- MIXED DML transaction: Controlled maintenance record modifications
BEGIN;

-- Insert 2 new maintenance records (simulate new services)
INSERT INTO maintenance (vehicle_id, maintenance_date, cost, description)
VALUES
    (1, CURRENT_TIMESTAMP - INTERVAL '2 days', 450.00, 'Engine oil replacement'),
    (2, CURRENT_TIMESTAMP - INTERVAL '1 day', 300.00, 'Brake pad replacement');

-- Update 1 existing maintenance record (adjust cost)
UPDATE maintenance
SET cost = cost + 50.00, description = 'Cost adjusted after inspection'
WHERE maintenance_id = 3;

-- Delete 1 old or invalid record (simulate data cleanup)
DELETE FROM maintenance
WHERE maintenance_id = 4;

-- Commit the transaction to apply the net 4 changes
COMMIT;




-- Validation: Check total committed rows remain ≤ 10
SELECT COUNT(*) AS total_committed_maintenance_records
FROM maintenance;

-- B7.4.Log before/after totals to the audit table (2–3 audit rows).

-- step 1. Log before totals
INSERT INTO vehicle_audit (bef_total, aft_total, key_col)
SELECT
    total_maintenance_cost AS bef_total,
    NULL AS aft_total,           -- No after value yet
    vehicle_id AS key_col
FROM vehicles
WHERE vehicle_id IN (1,2,3);

-- Step 2: Make updates
UPDATE vehicles
SET total_maintenance_cost = total_maintenance_cost * 1.1
WHERE vehicle_id IN (1,2,3);

-- check result before totals
SELECT * FROM vehicle_audit

-- Step 3: Log after totals
UPDATE vehicle_audit a
SET aft_total = v.total_maintenance_cost
FROM vehicles v
WHERE CAST(a.key_col AS INTEGER) = v.vehicle_id
  AND a.aft_total IS NULL;
  
 -- check result after totals
SELECT * FROM vehicle_audit


-- B8.1.Create table HIER(parent_id, child_id) for a natural hierarchy (domain-specific).
-- below is HIER Table table definition
CREATE TABLE HIER (
    parent_id INT NOT NULL,
    child_id INT NOT NULL,
    PRIMARY KEY (parent_id, child_id)
);



-- B8.2 Insert 6–10 Rows Forming a 3-Level Hierarchy
INSERT INTO HIER (parent_id, child_id) VALUES
(1, 3),   -- Root 1 → Sub 3
(1, 4),   -- Root 1 → Sub 4
(2, 5),   -- Root 2 → Sub 5
(3, 6),   -- Sub 3 → Product 6
(3, 7),   -- Sub 3 → Product 7
(4, 8);   -- Sub 4 → Product 8


WITH RECURSIVE hier_rollup AS (
    -- Base case: immediate parent-child links
    SELECT
        child_id,
        parent_id AS root_id,
        1 AS depth
    FROM HIER
    
    UNION ALL
    
    -- Recursive step: climb up the hierarchy
    SELECT
        h.child_id,
        r.root_id,
        r.depth + 1
    FROM HIER h
    JOIN hier_rollup r
      ON h.parent_id = r.child_id
)
SELECT child_id, root_id, depth
FROM hier_rollup
ORDER BY root_id, depth;

B9.1 Create table TRIPLE(s VARCHAR2(64), p VARCHAR2(64), o VARCHAR2(64)).

--- DDL defintion to create TRIPLE Table
CREATE TABLE TRIPLE (
    s VARCHAR(64) NOT NULL,  -- Subject
    p VARCHAR(64) NOT NULL,  -- Predicate
    o VARCHAR(64) NOT NULL,  -- Object
    PRIMARY KEY (s, p, o)
);

-- B9.2 Insert 8–10 domain facts relevant to your project (e.g., simple type hierarchy or rule
implications).


INSERT INTO TRIPLE (s, p, o) VALUES
('Laptop', 'isA', 'Computer'),
('Desktop', 'isA', 'Computer'),
('Computer', 'isA', 'Electronics'),
('Tablet', 'isA', 'Electronics'),
('Electronics', 'isA', 'Device'),
('Mouse', 'isA', 'Peripheral'),
('Keyboard', 'isA', 'Peripheral'),
('Peripheral', 'isA', 'Device');

-- check result after the above insert statement
select * from TRIPLE

-- 9.3. Write a recursive inference query implementing transitive isA*; apply labels to base records and return up to 10 labeled rows.

WITH RECURSIVE isa_inference AS (
    -- Base case: direct isA relationships
    SELECT s, o, 1 AS depth
    FROM TRIPLE
    WHERE p = 'isA'
    
    UNION ALL
    
    -- Recursive step: infer transitive isA
    SELECT i.s, t.o, i.depth + 1
    FROM isa_inference i
    JOIN TRIPLE t
      ON i.o = t.s
    WHERE t.p = 'isA'
)
SELECT s AS subject, o AS inferred_object, depth
FROM isa_inference
ORDER BY s, depth
LIMIT 10;  -- limit output to ≤10 rows

-- B10 1. Create BUSINESS_LIMITS(rule_key VARCHAR(64), threshold NUMBER, active CHAR(1)
CHECK(active IN('Y','N'))) and seed exactly one active rule.

-- Step 1: Create the table
CREATE TABLE BUSINESS_LIMITS (
    rule_key VARCHAR(64) PRIMARY KEY,
    threshold NUMERIC NOT NULL,
    active CHAR(1) NOT NULL CHECK (active IN ('Y','N'))
);

-- Step 2: Seed exactly one active rule
INSERT INTO BUSINESS_LIMITS (rule_key, threshold, active)
VALUES ('LIMIT_001', 100000, 'Y');

-- Verify the insert
SELECT * FROM BUSINESS_LIMITS;

10.2 . Implement function fn_should_alert(...) that reads BUSINESS_LIMITS and inspects current data
in Maintenance or Vehicle to decide a violation (return 1/0).

CREATE OR REPLACE FUNCTION fn_should_alert(p_vehicle_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_threshold NUMERIC;
    v_metric NUMERIC;
BEGIN
    -- Step 1: Read active threshold
    SELECT threshold
      INTO v_threshold
      FROM business_limits
     WHERE active = 'Y'
     LIMIT 1;  -- In case there are multiple active rules

    -- Step 2: Calculate metric (total maintenance cost)
    SELECT COALESCE(SUM(cost), 0)
      INTO v_metric
      FROM maintenance
     WHERE vehicle_id = p_vehicle_id;

    -- Step 3: Compare with threshold
    IF v_metric > v_threshold THEN
        RETURN 1; -- Violation
    ELSE
        RETURN 0; -- No violation
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;  -- No active rule, assume no alert
    WHEN OTHERS THEN
        RETURN 0;  -- Other errors
END;
$$ LANGUAGE plpgsql;


-- invoke the function and pass foreign key value of the vehicle
SELECT fn_should_alert(1) AS alert_flag;


-- 10.3 3. Create a BEFORE INSERT OR UPDATE trigger on Maintenance (or relevant table) that raises an application error when fn_should_alert returns 1.

-- Define a procedural function
CREATE OR REPLACE FUNCTION trg_check_business_limit()
RETURNS TRIGGER AS $$
DECLARE
    v_alert INTEGER;
BEGIN
    -- Step 1: Call fn_should_alert with the vehicle being modified
    v_alert := fn_should_alert(NEW.vehicle_id);

    -- Step 2: If a violation occurs, raise an error
    IF v_alert = 1 THEN
        RAISE EXCEPTION
            'Business limit violation: total maintenance cost for vehicle % exceeds threshold.',
            NEW.vehicle_id
            USING ERRCODE = 'P0001';  -- Custom application error
    END IF;

    -- Step 3: Allow insert/update if within limit
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to invoke the procedure function defined below
CREATE TRIGGER check_business_limit
BEFORE INSERT OR UPDATE
ON maintenance
FOR EACH ROW
EXECUTE FUNCTION trg_check_business_limit();


-- Insert a maintenance record that causes the total to exceed the limit
INSERT INTO maintenance (vehicle_id, maintenance_date, cost, description)
VALUES (1, NOW(), 12000000, 'Oil change');

10. 4. Demonstrate 2 failing and 2 passing DML cases; rollback the failing ones so total committed
rows remain within the ≤10 budget.

-- Two passing cases on maintenance table ensure cost <=100000
INSERT INTO maintenance (vehicle_id, maintenance_date, cost, description)
VALUES (1, NOW(), 1000, 'Oil change'),
(1, NOW(), 200, 'Oil change');

-- Two failing DML cases (cost exceed threshold)
BEGIN;
INSERT INTO maintenance (vehicle_id, maintenance_date, cost, description)
VALUES (1, NOW(), 5000000, 'Oil change'),
(1, NOW(),4000000, 'Oil change');
ROLLBACK;  -- rollback failing case












































