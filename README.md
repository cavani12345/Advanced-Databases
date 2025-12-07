# Logistics Fleet and Maintenance Monitoring System

##  Introduction

The **Logistics Fleet and Maintenance Monitoring System** is designed to efficiently manage a logistics company’s operational data, covering **vehicles**, **drivers**, **routes**, **shipments**, **maintenance**, and **payments**.  
The system ensures smooth coordination across transportation processes — from dispatching shipments to maintaining fleet health and recording payments — while maintaining a consistent and reliable source of truth for operational analytics and decision-making.

### Purpose

The main purpose of this project is to build a **centralized database system** that supports fleet management, shipment tracking, and maintenance oversight. It provides structured and relational data storage for all core logistics activities, ensuring that every vehicle, driver, and shipment can be tracked, audited, and analyzed efficiently.


## System Overview

This system maintains structured data for six key entities:
- **Vehicle** — fleet inventory and capacity management.  
- **Driver** — driver registration, licensing, and experience tracking.  
- **Route** — route definition, distance, and type classification.  
- **Shipment** — movement of goods assigned to vehicles and drivers.  
- **Maintenance** — vehicle servicing records and costs.  
- **Payment** — shipment-specific financial transactions.




### Entity Relationship Diagram and Database Relationships Description
![image](./CAT%201/images/logistic-fleets-ERD.png)

## Database Relationships

| Relationship | Type | Description |
|---------------|------|--------------|
| Vehicle → Shipment | 1:N | A vehicle can handle multiple shipments |
| Driver → Shipment | 1:N | A driver can handle multiple shipments |
| Route → Shipment | 1:N | A route can serve multiple shipments |
| Vehicle → Maintenance | 1:N | A vehicle can have multiple maintenance records |
| Shipment → Payment | 1:1 | Each shipment is associated with one payment |

## Task 1,2: Create tables with FK and CHECK constraints, Apply CASCADE DELETE for Vehicle → Maintenance.

Below are the **six core tables** along with screenshots of their definitions.


### 1. Vehicle (VehicleID, Model, PlateNo, Type, Status, Capacity)
```sql
CREATE TABLE IF NOT EXISTS vehicles (
    vehicle_id SERIAL PRIMARY KEY,  -- Unique identifier for each vehicle
    model VARCHAR(100) NOT NULL,    -- Vehicle model name
    plate_no VARCHAR(20) NOT NULL UNIQUE, -- Unique license plate number
    type VARCHAR(50) NOT NULL,      -- Vehicle type (e.g., Truck, Van)
    status VARCHAR(20) NOT NULL CHECK (status IN ('Active', 'In Transit', 'Under Maintenance','Retired')), -- Current status of the vehicle
    capacity INT NOT NULL CHECK (capacity > 0) -- Maximum load capacity
);
```

---

### 2. Driver (DriverID, FullName, LicenseNo, Contact, ExperienceYears)
```sql
CREATE TABLE IF NOT EXISTS drivers (
    driver_id SERIAL PRIMARY KEY,   -- Unique identifier for each driver
    full_name VARCHAR(100) NOT NULL,  -- full name of the driver
    license_no VARCHAR(50) NOT NULL UNIQUE, -- Driver's license number
    contact VARCHAR(50),            -- Contact information
    experience_years INT NOT NULL CHECK (experience_years >= 0) -- Experience in years
);

```

---

### 3. Route (RouteID, StartLocation, EndLocation, DistanceKM, Type)
```sql 
CREATE TABLE IF NOT EXISTS routes (
    route_id SERIAL PRIMARY KEY,    -- Unique route identifier
    start_location VARCHAR(100) NOT NULL, -- Starting point
    end_location VARCHAR(100) NOT NULL,   -- Destination
	-- Distance in kilometers with precision of 10 and 2 digits after decimal point
    distance_km DECIMAL(10,2) NOT NULL CHECK (distance_km > 0), 
    type VARCHAR(50) NOT NULL CHECK (type IN ('Urban','Rural','Long-Haul')) -- Route type classification
);
```

---

### 4. Shipment (ShipmentID, VehicleID, DriverID, RouteID, StartDate, EndDate, Status)
```sql
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

```

---

### 5. Maintenance (MaintenanceID, VehicleID, Date, Cost, Description)
```sql
CREATE TABLE IF NOT EXISTS maintenance (
    maintenance_id SERIAL PRIMARY KEY, -- Unique maintenance record
    vehicle_id INT NOT NULL,           -- Vehicle undergoing maintenance
    maintenance_date TIMESTAMP NOT NULL, 
    cost DECIMAL(10,2) NOT NULL CHECK (cost >= 0), -- Maintenance cost
    description TEXT,                  -- Optional details about maintenance

    
    CONSTRAINT fk_maintenance_vehicle FOREIGN KEY (vehicle_id) -- Foreign key with CASCADE DELETE: If a vehicle is deleted, its maintenance records are automatically removed
        REFERENCES vehicles(vehicle_id) 
        ON DELETE CASCADE
); 
```

---

### 6. Payment (PaymentID, ShipmentID, Amount, Method, PaymentDate)
```sql
CREATE TABLE IF NOT EXISTS payments (
    payment_id SERIAL PRIMARY KEY,     -- Unique payment identifier
    shipment_id INT NOT NULL UNIQUE,   -- Each shipment can have only one payment
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0), -- Payment amount
    method VARCHAR(50) NOT NULL CHECK (method IN ('Cash','Bank','Mobile Money')), -- Payment method
    payment_date TIMESTAMP NOT NULL,   -- Date of payment

    CONSTRAINT fk_payment_shipment FOREIGN KEY (shipment_id) -- - Ensures that each payment references a valid shipment;
        REFERENCES shipments(shipment_id)
);
```


 
CREATE TRIGGER mark_vehicle_unavailable_trg
AFTER INSERT ON maintenance              -- Fires after a new maintenance record is inserted
FOR EACH ROW                             -- Execute once per inserted row
EXECUTE FUNCTION mark_vehicle_under_maintenance();  -- Calls the function to update the vehicle's status

```
