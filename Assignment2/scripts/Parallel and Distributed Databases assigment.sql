-- Parallel and Distributed Databases Assignment
-- In this assigment we are reqested to split large database into two distributed nodes.


-- This is distributed vehicle fleet database management system, that split the database into two logical nodes using Vertical Fragmentation, where by fragment contains different sets of attributes, the created fragment are FleetOperations and FleetSupport
-- 1. FleetOperations: which manage Core logistics & transport operations
-- 2. FleetSupport: Maintenance & financial supports


-- Task 1. SQL scripts that create both schemas.
-- 1.1 Schema for Node 1(FleetOperations)
-- 1. Vehicles Table: Stores fleet information
CREATE TABLE IF NOT EXISTS vehicles (
    vehicle_id SERIAL PRIMARY KEY,  -- Unique identifier for each vehicle
    model VARCHAR(100) NOT NULL,    -- Vehicle model name
    plate_no VARCHAR(20) NOT NULL UNIQUE, -- Unique license plate number
    type VARCHAR(50) NOT NULL,      -- Vehicle type (e.g., Truck, Van)
    status VARCHAR(20) NOT NULL CHECK (status IN ('Active', 'In Transit', 'Under Maintenance','Retired')), -- Current status of the vehicle
    capacity INT NOT NULL CHECK (capacity > 0) -- Maximum load capacity
);
-- check if the table was created
SELECT * FROM vehicles
LIMIT 5

-- 2. Drivers Table: Stores driver details
CREATE TABLE IF NOT EXISTS drivers (
    driver_id SERIAL PRIMARY KEY,   -- Unique identifier for each driver
    full_name VARCHAR(100) NOT NULL,  -- full name of the driver
    license_no VARCHAR(50) NOT NULL UNIQUE, -- Driver's license number
    contact VARCHAR(50),            -- Contact information
    experience_years INT NOT NULL CHECK (experience_years >= 0) -- Experience in years
);
-- check if the table was created
SELECT * FROM drivers
LIMIT 5

-- 3. Routes Table: Stores predefined delivery routes
CREATE TABLE IF NOT EXISTS routes (
    route_id SERIAL PRIMARY KEY,    -- Unique route identifier
    start_location VARCHAR(100) NOT NULL, -- Starting point
    end_location VARCHAR(100) NOT NULL,   -- Destination
    distance_km DECIMAL(10,2) NOT NULL CHECK (distance_km > 0), -- Distance in kilometers with precision of 10 and 2 digits after decimal point
    type VARCHAR(50) NOT NULL CHECK (type IN ('Urban','Rural','Long-Haul')) -- Route type classification
);
-- check if the table was created
SELECT * FROM routes


-- 4. Shipments Table: Tracks cargo shipments
CREATE TABLE IF NOT EXISTS shipments (
    shipment_id SERIAL PRIMARY KEY,  -- Unique shipment identifier
    vehicle_id INT NOT NULL,         -- Vehicle assigned to shipment
    driver_id INT NOT NULL,          -- Driver assigned
    route_id INT NOT NULL,           -- Route assigned
    start_date TIMESTAMP,            -- Shipment start date
    end_date TIMESTAMP,              -- Shipment end date
    status VARCHAR(20) NOT NULL CHECK (status IN ('Pending','In Transit','Delivered','Cancelled')), -- Current status of shipment

	-- shipment_id,driver_id,route_id,start_date,end_date,status
    -- Foreign key constraints
    CONSTRAINT fk_shipment_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id), -- Ensures each shipment is assigned to a valid vehicle; prevents orphan shipments if the vehicle does not exist
    CONSTRAINT fk_shipment_driver FOREIGN KEY (driver_id) REFERENCES drivers(driver_id),  -- Ensures each shipment is assigned to a valid driver; prevents assignment to non-existent drivers
    CONSTRAINT fk_shipment_route FOREIGN KEY (route_id) REFERENCES routes(route_id) -- Ensures each shipment uses a valid route; maintains route integrity
);
-- check if the table was created
SELECT * FROM shipments
LIMIT 5

-- 1.2 Schema for node 2(FleetSupport)
-- 1. Maintenance Table: Tracks vehicle maintenance activities
CREATE TABLE IF NOT EXISTS maintenance (
    maintenance_id SERIAL PRIMARY KEY, -- Unique maintenance record
    vehicle_id INT NOT NULL,           -- Vehicle undergoing maintenance
    maintenance_date TIMESTAMP NOT NULL, 
    cost DECIMAL(10,2) NOT NULL CHECK (cost >= 0), -- Maintenance cost
    description TEXT                -- Optional details about maintenance
);
-- check if the table was created 
SELECT * FROM  maintenance
LIMIT 5

-- 2. Payments Table: Stores payments linked to shipments
CREATE TABLE IF NOT EXISTS payments (
    payment_id SERIAL PRIMARY KEY,     -- Unique payment identifier
    shipment_id INT NOT NULL UNIQUE,   -- Each shipment can have only one payment
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0), -- Payment amount
    method VARCHAR(50) NOT NULL CHECK (method IN ('Cash','Bank','Mobile Money')), -- Payment method
    payment_date TIMESTAMP NOT NULL   -- Date of payment
);

SELECT * FROM payments;


-- 1.3 Create triggered function that enforce referential integrity.
-- this triggered function ensure vehicle_id exists in vehicle(FleetOperations)
-- for the record being created in maintenance(FleetSupport) to avoid orphans rows
CREATE OR REPLACE FUNCTION enforce_vehicle_fk()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the vehicle exists in the imported foreign table
    IF NOT EXISTS (SELECT 1 FROM vehicles WHERE vehicle_id = NEW.vehicle_id) THEN
        RAISE EXCEPTION 'Foreign key violation: Vehicle % does not exist in FleetOperations', NEW.vehicle_id;
    END IF;
    RETURN NEW; -- Allow the insert/update if check passes
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_maintenance_vehicle
BEFORE INSERT OR UPDATE ON maintenance
FOR EACH ROW
EXECUTE FUNCTION enforce_vehicle_fk

-- create triggered function that simulate DELETE CASCADE for related tables
-- when row in base table is deleted
-- Enable dblink extension in local database
-- this allow to connect to and execute SQL statements on a remote PostgreSQL database from within your current database
CREATE EXTENSION IF NOT EXISTS dblink;

CREATE OR REPLACE FUNCTION cascade_delete_maintenance()
RETURNS TRIGGER AS $$
BEGIN
    -- Delete maintenance records in FleetSupport where vehicle_id matches
    PERFORM
        dblink_exec(
            'dbname=FleetSupport user=postgres password=postgres',
            'DELETE FROM maintenance WHERE vehicle_id = ' || OLD.vehicle_id
        );

    RETURN OLD; -- Proceed with deleting the vehicle
END;
$$ LANGUAGE plpgsql;


-- Create trigger on vehicles table
CREATE TRIGGER trg_cascade_delete_maintenance
AFTER DELETE ON vehicles
FOR EACH ROW
EXECUTE FUNCTION cascade_delete_maintenance();


-- 1.4 Insert sample data in each of the created node
-- insert 5 records in vehicles table
INSERT INTO vehicles (model, plate_no, type, status, capacity)
VALUES
('Mitsubishi Fuso', 'RWA-654E', 'Truck', 'Retired', 15000),
('Mercedes-Benz Actros', 'RWA-789C', 'Truck', 'Under Maintenance', 20000),
('Toyota Hiace', 'RWA-456B', 'Van', 'Active', 1500),
('Volvo FH16', 'RWA-123A', 'Truck', 'Active', 18000),
('Isuzu NPR', 'RWA-321D', 'Truck', 'Active', 12000);

-- insert 4 records in vehicles table
INSERT INTO drivers (full_name, license_no, contact, experience_years)
VALUES
('John Ngarukiye', 'RW123456', '+250788123456', 5),
('Eddy Ishimwe', 'RW654321', '+250788654321', 8),
('David Indekwe', 'RW987654', '+250788987654', 3),
('William Mugangwa', 'RW987959', '+250788987654', 3);

-- insert 4 records in routes table
INSERT INTO routes (start_location, end_location, distance_km, type)
VALUES
('Kigali', 'Nairobi', 1170.50, 'Long-Haul'),
('Kigali', 'Goma', 210.75, 'Urban'),
('Kigali', 'Musanze', 95.25, 'Urban'),
('Kigali', 'Kibuye', 130.40, 'Rural'),
('Kigali', 'Butare', 145.80, 'Rural');

INSERT INTO shipments (vehicle_id, driver_id, route_id, start_date, end_date, status)
VALUES
(1, 1, 1, '2025-10-10 08:00:00', '2025-10-12 18:00:00', 'Delivered'),
(2, 2, 2, '2025-10-11 09:00:00', '2025-10-11 17:00:00', 'Delivered'),
(3, 3, 3, '2025-10-12 07:30:00', '2025-10-12 12:00:00', 'In Transit'),
(4, 1, 4, '2025-10-13 06:00:00', '2025-10-13 14:00:00', 'Delivered'),
(1, 2, 5, '2025-10-14 08:00:00', '2025-10-14 16:00:00', 'In Transit');

-- Insert at least 5 records in maintance table
INSERT INTO maintenance (vehicle_id, maintenance_date, cost, description)
VALUES
    (100, '2025-10-21 10:30:00', 200.00, 'Brake inspection and replacement')
	



-- TASK 2: Create a database link between your two schemas. Demonstrate a successful remote SELECT and a distributed join between local and remote tables

-- 2. 1 database link
-- to allow to both two databases to communicate we use Foreign Data Wrapper(FDW) 
-- FDW enable access to tables in another database as if they were local
-- FDW stores metadata about how to access the remote table and actual data remains in the remote database
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Create a foreign server (This defines the connection to FleetOperations)
CREATE SERVER fleetops_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (
    host 'localhost',       -- host where FleetOperations is running
    dbname 'FleetOperations',  -- remote db to connect to
    port '5432'
);

-- create a user mapping(Map a local user in FleetSupport node  to a user in FleetOperations node)
CREATE USER MAPPING FOR postgres  -- or your local user
SERVER fleetops_server
OPTIONS (
    user 'postgres',         -- FleetOperations username
    password 'postgres'       -- FleetOperations password
);

-- import  foreign tables from FleetOperations
IMPORT FOREIGN SCHEMA public
LIMIT TO (vehicles, drivers, routes, shipments)
FROM SERVER fleetops_server INTO public;

-- 2.2 Demostrate a distributed join between local and remote tables

--metric to track: vehciles which was maintained several times
SELECT v.plate_no,COUNT(m.vehicle_id) FROM vehicles v
INNER JOIN maintenance m
ON v.vehicle_id = m.vehicle_id
GROUP BY 1 ORDER BY COUNT(m.vehicle_id) DESC LIMIT 1




-- TASK 3: Enable parallelism and Compare Serial vs Parallel Query Plans

-- 3.1 Enable parallelism
SET max_parallel_workers_per_gather = 4;   -- Default is 2
SET parallel_setup_cost = 0;               -- Reduce threshold for using parallel
SET parallel_tuple_cost = 0;               -- Encourage parallel plans
SET min_parallel_table_scan_size = '8MB';
SET min_parallel_index_scan_size = '8MB';


-- 3.2. Compare Serial vs Parallel Query Plans

-- 3.2.1 Serial Query Plans: to achieve set worker to
-- and then analyze query execution plan
SET max_parallel_workers_per_gather = 0;
EXPLAIN ANALYZE
SELECT vehicle_id, AVG(cost) AS avg_cost
FROM maintenance
GROUP BY vehicle_id
ORDER BY avg_cost DESC
LIMIT 10;


-- Parallel Query Execution
-- to achieven this set worker to a number great that 2 which is the default one
-- and then analyze query execution plan and compare the result with serial

SET max_parallel_workers_per_gather = 4;
EXPLAIN ANALYZE
SELECT vehicle_id, AVG(cost) AS avg_cost
FROM maintenance
GROUP BY vehicle_id
ORDER BY avg_cost DESC
LIMIT 10;



-- TASK 4: Write a PL/SQL block performing inserts on both nodes and committing once

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
    INSERT INTO shipments (vehicle_id, driver_id, route_id, start_date, end_date, status)
    VALUES (3, 3, 4, CURRENT_DATE, CURRENT_DATE + INTERVAL '2 days', 'In Transit')
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
        'dbname=FleetSupport user=postgres password=postgres host=localhost port=5432',
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


-- TASK 5: Simulate a remote failure during a distributed transaction. Check unresolved transactions and resolve them using ROLLBACK FORCE

-- 5.1 Simulate a remote failure during a distributed transaction
-- transaction in postgres should be either commited or rolled back automatically
-- to allow manually commit/rollback of transaction which must prepared transaction
-- by default prepared transaction are disable in postgers, therefore to enable this
-- functionality we are required to change max_prepared_transactions config varibale to a value >0 and then restart the server
-- confirm change has reflected by running : SHOW max_prepared_transactions;
-- prepared statement keep transactions in prepared state for manual resolution


-- 5. 1 remote failure is being simulated by inserting 
-- into wrong table from local node(invalid_payment)

DO $$
DECLARE
    local_shipment_id INT;   -- Variable to hold the newly inserted shipment ID
    remote_sql TEXT;         -- Variable to hold dynamically generated remote SQL command
    remote_gid TEXT;         -- Global transaction ID (GID) for the remote database transaction
    local_gid TEXT;          -- Global transaction ID (GID) for the local database transaction
BEGIN
    -- Step 1: Insert a new shipment record locally in the 'shipments' table.
    -- The generated shipment_id is captured into the 'local_shipment_id' variable.
    INSERT INTO shipments (vehicle_id, driver_id, route_id, start_date, end_date, status)
    VALUES (3, 3, 4, CURRENT_DATE, CURRENT_DATE + INTERVAL '2 days', 'In Transit')
    RETURNING shipment_id INTO local_shipment_id;

    -- Step 2: Generate unique transaction identifiers (GIDs) for both local and remote transactions.
    -- These identifiers are important for managing distributed transactions using two-phase commit.
    local_gid := format('local_tx_%s', local_shipment_id);
    remote_gid := format('remote_tx_%s', local_shipment_id);

    -- Step 3: Log the generated identifiers for tracking.
    RAISE NOTICE 'Local shipment_id = %, local_gid = %, remote_gid = %',
                 local_shipment_id, local_gid, remote_gid;

    -- Step 4: Simulate a remote failure.
    -- The remote SQL intentionally references a non-existent table 'invalid_payment'
    -- to trigger an error, representing a remote database failure scenario.
    remote_sql := format($remote$
        BEGIN;
        INSERT INTO invalid_payment (shipment_id, amount, method, payment_date)
        VALUES (%L, 10000, 'Mobile Money', CURRENT_DATE);
        PREPARE TRANSACTION %L;
    $remote$, local_shipment_id, remote_gid);

    BEGIN
        -- Step 5: Attempt to execute the remote transaction using dblink.
        -- If the remote SQL fails (due to the invalid table), the exception block will capture it.
        PERFORM dblink_exec(
            'dbname=FleetSupport user=postgres password=postgres host=localhost port=5432',
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
PREPARE TRANSACTION 'remote_tx_23';



-- 5.2 Check unresolved transactions on coordinator node, and log them
-- the following PL code generate all unresolved transactions in more customizable way

DO $$
DECLARE
    tx RECORD;  -- Variable to hold each prepared transaction retrieved from pg_prepared_xacts
BEGIN
  
    -- Log heading for unresolved prepared transaction
	-- indicates that the process of checking for unresolved (in-doubt) transactions is starting.
    RAISE NOTICE 'Checking unresolved prepared transactions...';
   
    -- Loop through pg_prepared_xacts to display in-doubt ones
    FOR tx IN
        SELECT gid, database, prepared, owner, transaction
        FROM pg_prepared_xacts
        ORDER BY prepared DESC  
    LOOP
        -- For each unresolved transaction found, display its details:
        --   GID,Database, Owner, and Timestamp when the transaction was prepared
        RAISE NOTICE 'GID: %, Database: %, Owner: %, Prepared at: %',
            tx.gid, tx.database, tx.owner, tx.prepared;
    END LOOP;

    -- If none found, show confirmation
    IF NOT FOUND THEN
        RAISE NOTICE 'No unresolved prepared transactions found.';
    ELSE
        -- If transactions were found, instruct the user to manually commit or roll them back.
        RAISE NOTICE 'Please Review and COMMIT or ROLLBACK these transactions manually.';
    END IF;
END;
$$;


-- 5.3 Resolve in-doubt transaction forcibly

-- Here, we simulate by manually  rolling back any unresolved prepared transaction
-- each transaction should have a unique GID
	
-- Roll back a transaxtion with GID of remote_tx_23
ROLLBACK PREPARED 'remote_tx_23';

-- Roll back a transaxtion with GID of remote_tx_24 	
ROLLBACK PREPARED 'remote_tx_24';


-- 5.4 Confirm cleanup
-- check if all prepared transaction was resolved
SELECT * FROM pg_prepared_xacts;



-- TASK 6: Demonstrate a lock conflict by running two sessions that update the same record from different nodes

-- 6.1 Demonstrate a lock conflict by updating same record in shipments table on two different node
-- Step 1: local node (FleetOperations): start explicit transaction (autocommit disabled)
 
BEGIN;
-- Lock the record by updating it (but don’t commit yet)
UPDATE shipments
SET status = 'Pending'
WHERE shipment_id = 5;


-- Step 2: remode node(FleetSupport): Simulates lock conflict by updating same record remotely
-- The follwing statement hangs (waits) indefinitely until transaction on node A is committed/rolled back.
BEGIN;
SELECT dblink_exec( -- Execute the remote update using dblink
    'dbname=FleetOperations user=postgres password=postgres host=localhost port=5432',
    $remote$
        UPDATE shipments
        SET status = 'Cancelled'
        WHERE shipment_id = 5
    $remote$
);

-- TASK 7: Perform parallel data aggregation or loading using PARALLEL DML. Compare runtime and document improvement in query cost and execution time.
 

-- 7.1 Run Aggregation Without Parallelism
SET max_parallel_workers_per_gather = 0;
EXPLAIN ANALYZE
SELECT route_id, COUNT(*) AS total_shipments
FROM shipments
GROUP BY route_id;


 -- 7.2 Enable parallelism
-- Ensure PostgreSQL is configured to allow parallel execution
-- Make sure the value for variables tha enable parallel execution are sufficient.
SET max_parallel_workers_per_gather = 4;
SET parallel_leader_participation = on;
EXPLAIN ANALYZE
SELECT route_id, COUNT(*) AS total_shipments
FROM shipments
GROUP BY route_id;


-- TASK 9: Distributed Query Optimization

-- 9.1. Analyze Distibuted query for counting vehicles with their maintenace number
-- Analyze Distributed query for counting vehicles with their maintenance number
-- The EXPLAIN command shows the execution plan that the optimizer chooses
-- ANALYZE runs the query and provides actual runtime statistics
-- COSTS includes estimated startup and total costs for each operation
-- VERBOSE displays detailed information about the plan

EXPLAIN (ANALYZE, COSTS, VERBOSE)
SELECT 
    v.plate_no,                   -- Select each vehicle’s plate number
    COUNT(m.vehicle_id)           -- Count how many maintenance records exist per vehicle
FROM vehicles v                   -- Base table containing all vehicles
INNER JOIN maintenance m          -- Join with the maintenance table
    ON v.vehicle_id = m.vehicle_id  -- Join condition using vehicle_id (foreign key relationship)
GROUP BY 1                         -- Group by the first column (plate_no)
ORDER BY COUNT(m.vehicle_id) DESC;  -- Sort results in descending order of maintenance count


-- TASK 10: Performance Benchmark 
-- Use EXPLAIN PLAN to analyze a distributed join

-- 10.1 Centralized (single process)
-- By default parallelism is enabled in postgres, to disable this behavior
-- change the number of workers to 0

SET max_parallel_workers_per_gather = 0;  -- Disable parallelism
EXPLAIN (ANALYZE, BUFFERS) 
SELECT v.plate_no, COUNT(m.vehicle_id)
FROM vehicles v
JOIN maintenance m
  ON v.vehicle_id = m.vehicle_id
GROUP BY 1 ORDER BY COUNT(m.vehicle_id) DESC;

-- 10.2 Parallel (intra-node parallelism)
-- enable parallelism set workers to a number different from 0
SET max_parallel_workers_per_gather = 8; -- Use 8 parallel workers  
EXPLAIN (ANALYZE, BUFFERS) 
SELECT v.plate_no, COUNT(m.vehicle_id)
FROM vehicles v
JOIN maintenance m
  ON v.vehicle_id = m.vehicle_id
GROUP BY 1
ORDER BY COUNT(m.vehicle_id) DESC;

