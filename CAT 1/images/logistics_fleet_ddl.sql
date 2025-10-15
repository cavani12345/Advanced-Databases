-- ========================================
-- DATABASE: logistics_fleet_db
-- Purpose: Manage vehicles, drivers, routes, shipments, maintenance, and payments
-- ========================================

-- 0. Create database if it does not exist (PostgreSQL syntax)
-- Note: PostgreSQL uses "CREATE DATABASE ...;" only once per DB; 


--CREATE DATABASE IF NOT EXISTS logistics_fleet_db;

-- 1. Vehicles Table: Stores fleet information
CREATE TABLE IF NOT EXISTS vehicles (
    vehicle_id SERIAL PRIMARY KEY,  -- Unique identifier for each vehicle
    model VARCHAR(100) NOT NULL,    -- Vehicle model name
    plate_no VARCHAR(20) NOT NULL UNIQUE, -- Unique license plate number
    type VARCHAR(50) NOT NULL,      -- Vehicle type (e.g., Truck, Van)
    status VARCHAR(20) NOT NULL CHECK (status IN ('Active', 'In Transit', 'Under Maintenance','Retired')), -- Current status of the vehicle
    capacity INT NOT NULL CHECK (capacity > 0) -- Maximum load capacity
);

-- 2. Drivers Table: Stores driver details
CREATE TABLE IF NOT EXISTS drivers (
    driver_id SERIAL PRIMARY KEY,   -- Unique identifier for each driver
    full_name VARCHAR(100) NOT NULL,  -- full name of the driver
    license_no VARCHAR(50) NOT NULL UNIQUE, -- Driver's license number
    contact VARCHAR(50),            -- Contact information
    experience_years INT NOT NULL CHECK (experience_years >= 0) -- Experience in years
);

-- 3. Routes Table: Stores predefined delivery routes
CREATE TABLE IF NOT EXISTS routes (
    route_id SERIAL PRIMARY KEY,    -- Unique route identifier
    start_location VARCHAR(100) NOT NULL, -- Starting point
    end_location VARCHAR(100) NOT NULL,   -- Destination
    distance_km DECIMAL(10,2) NOT NULL CHECK (distance_km > 0), -- Distance in kilometers with precision of 10 and 2 digits after decimal point
    type VARCHAR(50) NOT NULL CHECK (type IN ('Urban','Rural','Long-Haul')) -- Route type classification
);

-- 4. Shipments Table: Tracks cargo shipments
CREATE TABLE IF NOT EXISTS shipments (
    shipment_id SERIAL PRIMARY KEY,  -- Unique shipment identifier
    vehicle_id INT NOT NULL,         -- Vehicle assigned to shipment
    driver_id INT NOT NULL,          -- Driver assigned
    route_id INT NOT NULL,           -- Route assigned
    start_date TIMESTAMP,            -- Shipment start date
    end_date TIMESTAMP,              -- Shipment end date
    status VARCHAR(20) NOT NULL CHECK (status IN ('Pending','In Transit','Delivered','Cancelled')), -- Current status of shipment

    -- Foreign key constraints
    CONSTRAINT fk_shipment_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id), -- Ensures each shipment is assigned to a valid vehicle; prevents orphan shipments if the vehicle does not exist
    CONSTRAINT fk_shipment_driver FOREIGN KEY (driver_id) REFERENCES drivers(driver_id),  -- Ensures each shipment is assigned to a valid driver; prevents assignment to non-existent drivers
    CONSTRAINT fk_shipment_route FOREIGN KEY (route_id) REFERENCES routes(route_id) -- Ensures each shipment uses a valid route; maintains route integrity
);

-- 5. Maintenance Table: Tracks vehicle maintenance activities
CREATE TABLE IF NOT EXISTS maintenance (
    maintenance_id SERIAL PRIMARY KEY, -- Unique maintenance record
    vehicle_id INT NOT NULL,           -- Vehicle undergoing maintenance
    maintenance_date TIMESTAMP NOT NULL, 
    cost DECIMAL(10,2) NOT NULL CHECK (cost >= 0), -- Maintenance cost
    description TEXT,                  -- Optional details about maintenance

    -- Foreign key with CASCADE DELETE: If a vehicle is deleted, its maintenance records are automatically removed
    CONSTRAINT fk_maintenance_vehicle FOREIGN KEY (vehicle_id) 
        REFERENCES vehicles(vehicle_id) 
        ON DELETE CASCADE
);

-- 6. Payments Table: Stores payments linked to shipments
CREATE TABLE IF NOT EXISTS payments (
    payment_id SERIAL PRIMARY KEY,     -- Unique payment identifier
    shipment_id INT NOT NULL UNIQUE,   -- Each shipment can have only one payment
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0), -- Payment amount
    method VARCHAR(50) NOT NULL CHECK (method IN ('Cash','Bank','Mobile Money')), -- Payment method
    payment_date TIMESTAMP NOT NULL,   -- Date of payment

    CONSTRAINT fk_payment_shipment FOREIGN KEY (shipment_id) -- - Ensures that each payment references a valid shipment;
        REFERENCES shipments(shipment_id)
);
