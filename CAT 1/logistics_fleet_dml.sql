-- This sql script cover all DML queries for adding new recors, updating the existing one and delete where necessary

-- Task 3: Insert at least 5 vehicles and 3 drivers.
-- 3.1 insert 5 records in vehicles table
INSERT INTO vehicles (model, plate_no, type, status, capacity)
VALUES
('Mitsubishi Fuso', 'RWA-654E', 'Truck', 'Retired', 15000),
('Mercedes-Benz Actros', 'RWA-789C', 'Truck', 'Under Maintenance', 20000),
('Toyota Hiace', 'RWA-456B', 'Van', 'Active', 1500),
('Volvo FH16', 'RWA-123A', 'Truck', 'Active', 18000),
('Isuzu NPR', 'RWA-321D', 'Truck', 'Active', 12000);

-- check if the insert was made
SELECT * FROM vehicles
LIMIT 5

-- 3.2 insert 4 records in vehicles table
INSERT INTO drivers (full_name, license_no, contact, experience_years)
VALUES
('John Ngarukiye', 'RW123456', '+250788123456', 5),
('Eddy Ishimwe', 'RW654321', '+250788654321', 8),
('David Indekwe', 'RW987654', '+250788987654', 3),
('William Mugangwa', 'RW987959', '+250788987654', 3);

-- check if the insert was made
SELECT * FROM drivers
LIMIT 5

-- Task 4: Retrieve total revenue per vehicle type.
-- to make the above computation we need to insert data into the following tables routes,shipments, and payments
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

INSERT INTO payments (shipment_id, amount, method, payment_date)
VALUES
(1, 5000.00, 'Bank', '2025-10-12 20:00:00'),          -- payment for Shipment 1
(2, 1200.00, 'Cash', '2025-10-11 18:00:00'),          -- payment for Shipment 2
(3, 3000.00, 'Bank', '2025-10-12 13:00:00'),          -- payment for Shipment 3
(4, 2500.00, 'Mobile Money', '2025-10-13 15:00:00'),  -- payment for Shipment 4
(5, 1800.00, 'Cash', '2025-10-14 17:00:00');          -- payment for Shipment 5 

-- Compute Total Revenue per Vehicle Type
SELECT 
    ve.type AS vehicle_type,
    SUM(pa.amount) AS total_revenue
FROM payments pa
JOIN shipments sh ON pa.shipment_id = sh.shipment_id
JOIN vehicles ve ON sh.vehicle_id = ve.vehicle_id
GROUP BY ve.type
ORDER BY ve.type DESC;

-- Task 5: Update maintenance cost and observe vehicle downtime.
-- Let first insert same into maintainace tables and then later on do update

INSERT INTO maintenance (vehicle_id, maintenance_date, cost, description)
VALUES
(1, '2025-10-05', 500.00, 'Oil change and filter replacement'),
(2, '2025-10-07', 1200.00, 'Brake system overhaul'),
(3, '2025-10-08', 2000.00, 'Engine diagnostics and repair'),
(1, '2025-10-12', 750.00, 'Tire replacement'),
(4, '2025-10-10', 600.00, 'Suspension check and repair');

SELECT * FROM maintenance
LIMIT 5

-- 5.1. Update maintenance cost
UPDATE maintenance
SET cost = cost + (cost * 0.1) -- let increase maintenance cost by 10% for a specific vehicle
WHERE vehicle_id = 2;  

-- 5.2 Compoute vehicles Downtime (number of maintenance days)
-- assume each maintenance is completed on the same day, the downtime will be considered as the number of maintenance days for a vehicle
SELECT 
    vehicle_id,
    COUNT(DISTINCT DATE(maintenance_date)) AS downtime_count
FROM maintenance
GROUP BY 1;


-- Task 6: Identify most efficient driver by completed shipments
SELECT 
    d.driver_id,                     -- Select driver ID
    d.full_name,                     -- Select driver full name
    COUNT(s.shipment_id) AS total_completed_shipments  -- Count number of completed shipments per driver
FROM drivers d
JOIN shipments s 
    ON d.driver_id = s.driver_id     -- Join shipments with drivers to link each shipment to its driver
WHERE s.status = 'Delivered'         -- Only consider shipments that have been completed
GROUP BY d.driver_id, d.full_name    -- Group results by each driver to aggregate shipment counts
ORDER BY total_completed_shipments DESC  -- Sort drivers by total completed shipments (most first)
LIMIT 1;                             -- Return only the top-performing (most efficient) driver


-- Task 7: Create a view summarizing cost and income balance per vehicle.

CREATE OR REPLACE VIEW vehicle_financial_summary AS
SELECT 
    v.vehicle_id,
    v.model,
    v.type,
    -- Sum of maintenance costs per vehicle
	---use COALESCE(..., 0) replaces NULL with 0 so balance calculations work correctly.
	-- use FILTER to exclude vehicles which did'nt undergone any maintainance in the SUM calculation.
    COALESCE(SUM(m.cost) FILTER (WHERE m.vehicle_id IS NOT NULL), 0) AS total_maintenance_cost,
    
    -- Sum of payments received for shipments handled by this vehicle
    COALESCE(SUM(p.amount), 0) AS total_income,
    
    -- Net balance (income minus cost)
    COALESCE(SUM(p.amount), 0) - COALESCE(SUM(DISTINCT m.cost) FILTER (WHERE m.vehicle_id IS NOT NULL), 0) AS net_balance

FROM vehicles v
LEFT JOIN shipments s ON v.vehicle_id = s.vehicle_id
LEFT JOIN payments p ON s.shipment_id = p.shipment_id
LEFT JOIN maintenance m ON v.vehicle_id = m.vehicle_id
GROUP BY 1,2,3;

SELECT * FROM vehicle_financial_summary
LIMIT 5

-- Task 8: Implement a trigger that marks vehicles unavailable during maintenance
-- first let create a function that automatically marks a vehicle as Under Maintenance whenever a maintenance record is inserted
-- the create function will be triggered whenever a new insert is made in maintenance table

CREATE OR REPLACE FUNCTION mark_vehicle_under_maintenance()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the status of the vehicle associated with the newly inserted maintenance record
    -- 'NEW.vehicle_id' refers to the vehicle_id of the maintenance record that was just inserted
    UPDATE vehicles
    SET status = 'Under Maintenance'  -- Set the vehicle status to indicate it is unavailable
    WHERE vehicle_id = NEW.vehicle_id; -- Apply the update to the correct vehicle

    -- Return the new maintenance row so the INSERT operation can complete successfully
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;  -- Specify that this is a PL/pgSQL procedural language function


-- Once the procedure is defined, the create a event trigger on maintenance that will invoke the created predecure
 -- The trigger will fires the function after a new row is inserted 
 
CREATE TRIGGER mark_vehicle_unavailable_trg
AFTER INSERT ON maintenance              -- Fires after a new maintenance record is inserted
FOR EACH ROW                             -- Execute once per inserted row
EXECUTE FUNCTION mark_vehicle_under_maintenance();  -- Calls the function to update the vehicle's status




