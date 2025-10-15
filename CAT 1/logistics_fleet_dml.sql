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



