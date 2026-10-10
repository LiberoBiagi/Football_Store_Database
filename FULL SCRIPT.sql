-- 0. creare DB
DROP DATABASE IF exists shirts_fc;
CREATE DATABASE IF NOT EXISTS shirts_fc;
USE shirts_fc;

-- CREATE THE SCHEMA

-- 1. customers
CREATE TABLE customers (
  customer_id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(60) NOT NULL,
  last_name VARCHAR(60) NOT NULL,
  email VARCHAR(150) UNIQUE NOT NULL,
  phone VARCHAR(30),
  street VARCHAR(150),
  city VARCHAR(80),
  postal_code VARCHAR(20),
  country VARCHAR(60),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 3. suppliers
CREATE TABLE suppliers (
  supplier_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  contact_email VARCHAR(150),
  phone VARCHAR(30)
);
-- 2. teams
CREATE TABLE teams (
  team_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  country VARCHAR(60),
  founded INT,
  supplier_id INT, -- collegamento al fornitore
  UNIQUE(name),
  FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);



-- 4. products (base product: model/season/team)
CREATE TABLE products (
  product_id INT AUTO_INCREMENT PRIMARY KEY,
  team_id INT NOT NULL,
  model VARCHAR(150) NOT NULL,         -- e.g., "Home Jersey 24/25"
  season VARCHAR(20),                  -- e.g., "2024/2025"
  description TEXT,
  base_price DECIMAL(10,2) NOT NULL,
  sku_base VARCHAR(60),
  FOREIGN KEY (team_id) REFERENCES teams(team_id)
);

-- 5. product_variants (sold units: size/color)
CREATE TABLE product_variants (
  variant_id INT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  sku VARCHAR(80) UNIQUE NOT NULL,
  size ENUM('XS','S','M','L','XL','XXL') NOT NULL,
  color VARCHAR(40),
  price DECIMAL(10,2) NOT NULL, 
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(product_id)
);
-- 6. inventory
CREATE TABLE inventory (
  variant_id INT PRIMARY KEY, -- 1:1 with product_variant for stock
  stock INT NOT NULL DEFAULT 0,
  restock_threshold INT NOT NULL DEFAULT 5,
  last_restock DATETIME,
  FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id)
);

-- 7. orders
CREATE TABLE orders (
  order_id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  order_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status ENUM('CREATED','PAID','SHIPPED','CANCELLED','REFUNDED') NOT NULL DEFAULT 'CREATED',
  shipping_address VARCHAR(250),
  total_amount DECIMAL(12,2) DEFAULT 0.00,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- 8. order_items
CREATE TABLE order_items (
  order_item_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  variant_id INT NOT NULL,
  quantity INT NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10,2) NOT NULL,
  line_total DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price) VIRTUAL,
  FOREIGN KEY (order_id) REFERENCES orders(order_id),
  FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id)
);

-- 9. payments
CREATE TABLE payments (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  paid_amount DECIMAL(12,2) NOT NULL,
  paid_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  method ENUM('CARD','PAYPAL','BANK_TRANSFER','CASH') DEFAULT 'CARD',
  status ENUM('SUCCESS','FAILED','PENDING') DEFAULT 'SUCCESS',
  FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- 10. ratings
CREATE TABLE ratings (
  rating_id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  variant_id INT NOT NULL,
  rating TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  rated_on DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id)
);

-- 11. logs
CREATE TABLE logs (
  log_id INT AUTO_INCREMENT PRIMARY KEY,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  source_table VARCHAR(80),
  action VARCHAR(20),
  description TEXT
);

-- CREATE THE TRIGGERS-- 

DELIMITER $$
CREATE TRIGGER trg_after_insert_order_item
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
  DECLARE cur_stock INT;

  SELECT stock INTO cur_stock 
  FROM inventory 
  WHERE variant_id = NEW.variant_id 
  FOR UPDATE;

  IF cur_stock IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory record not found';
  END IF;

  IF cur_stock < NEW.quantity THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough stock';
  END IF;

  UPDATE inventory
    SET stock = stock - NEW.quantity
    WHERE variant_id = NEW.variant_id;
END$$
DELIMITER ;
------------------------------
DELIMITER $$
CREATE TRIGGER trg_log_insert_order_item
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
  INSERT INTO logs (source_table, action, description)
  VALUES (
    'order_items', 
    'INSERT', 
    CONCAT(
      'OrderItem ', NEW.order_item_id,
      ' added to order ', NEW.order_id,
      ', variant ', NEW.variant_id,
      ', qty ', NEW.quantity
    )
  );
END$$
DELIMITER ;

-- =====================================================
-- COMPLETE DATA INSERT SCRIPT - SHIRTS_FC DATABASE
-- Spanning 2023-2025 with consistent data structure
-- =====================================================

USE shirts_fc;

-- =====================
-- 1. SUPPLIERS (Insert first - no dependencies)
-- =====================
INSERT INTO suppliers (name, contact_email, phone) VALUES
('Magliette S.p.A.','sales@magliettespa.it','+39 081000000'),
('SportWear Ltd','orders@sportwear.fr','+33 14000000'),
('EuroSports GmbH','contact@eurosports.de','+49 800123456'),
('Global Textiles Inc','info@globaltextiles.com','+1 555-0100'),
('Asian Sports Co','contact@asiansports.cn','+86 10 8888 9999'),
('South American Gear','ventas@sagear.com.br','+55 11 3000-4000');

-- =====================
-- 2. TEAMS (Depends on suppliers)
-- =====================
INSERT INTO teams (name, country, founded, supplier_id) VALUES
('FC Napoli','Italy',1926,1),
('PSG','France',1970,2),
('Manchester United','England',1878,1),
('Real Madrid','Spain',1902,3),
('Liverpool','England',1892,2),
('Bayern Munich','Germany',1900,3),
('FC Barcelona','Spain',1899,4),
('Juventus','Italy',1897,1),
('Chelsea','England',1905,5),
('AC Milan','Italy',1899,1),
('Borussia Dortmund','Germany',1909,3),
('Atletico Madrid','Spain',1903,6);

-- =====================
-- 3. PRODUCTS (Depends on teams)
-- =====================
INSERT INTO products (team_id, model, season, description, base_price, sku_base) VALUES
-- 2023/2024 Season
(1,'Home Jersey','2023/2024','Maglia Home 2023/24 Napoli',50.00,'NAP-H-23'),
(2,'Away Jersey','2023/2024','Maglia Away 2023/24 PSG',55.00,'PSG-A-23'),
(4,'Third Jersey','2023/2024','Maglia Third 2023/24 Real Madrid',58.00,'RM-T-23'),
(5,'Away Jersey','2023/2024','Maglia Away 2023/24 Liverpool',57.00,'LIV-A-23'),
-- 2024/2025 Season
(1,'Home Jersey','2024/2025','Maglia Home 2024/25 Napoli',55.00,'NAP-H-24'),
(2,'Home Jersey','2024/2025','Maglia Home 2024/25 PSG',60.00,'PSG-H-24'),
(3,'Away Jersey','2024/2025','Away 24/25 Manchester United',58.50,'MU-A-24'),
(4,'Home Jersey','2024/2025','Maglia Home 2024/25 Real Madrid',65.00,'RM-H-24'),
(5,'Home Jersey','2024/2025','Maglia Home 2024/25 Liverpool',62.00,'LIV-H-24'),
(6,'Home Jersey','2024/2025','Maglia Home 2024/25 Bayern',63.00,'BAY-H-24'),
(7,'Home Jersey','2024/2025','Maglia Home 2024/25 Barcelona',67.00,'BAR-H-24'),
(8,'Home Jersey','2024/2025','Maglia Home 2024/25 Juventus',64.00,'JUV-H-24'),
(9,'Home Jersey','2024/2025','Maglia Home 2024/25 Chelsea',66.00,'CHE-H-24'),
(10,'Away Jersey','2024/2025','Maglia Away 2024/25 AC Milan',61.00,'MIL-A-24'),
(11,'Home Jersey','2024/2025','Maglia Home 2024/25 Dortmund',59.00,'DOR-H-24'),
(12,'Third Jersey','2024/2025','Maglia Third 2024/25 Atletico',60.00,'ATM-T-24');

-- =====================
-- 4. PRODUCT VARIANTS (Depends on products)
-- =====================
INSERT INTO product_variants (product_id, sku, size, color, price) VALUES
-- 2023/2024 Season Variants
(1,'NAP-H-23-M-001','M','Blue',50.00),
(1,'NAP-H-23-L-002','L','Blue',50.00),
(1,'NAP-H-23-XL-003','XL','Blue',50.00),
(2,'PSG-A-23-M-004','M','White',55.00),
(2,'PSG-A-23-L-005','L','White',55.00),
(3,'RM-T-23-M-006','M','Black',58.00),
(3,'RM-T-23-S-007','S','Black',58.00),
(4,'LIV-A-23-M-008','M','White/Green',57.00),
(4,'LIV-A-23-L-009','L','White/Green',57.00),
-- 2024/2025 Season Variants
(5,'NAP-H-24-M-010','M','Blue',55.00),
(5,'NAP-H-24-L-011','L','Blue',55.00),
(5,'NAP-H-24-S-012','S','Blue',55.00),
(6,'PSG-H-24-M-013','M','Blue/Red',60.00),
(6,'PSG-H-24-L-014','L','Blue/Red',60.00),
(7,'MU-A-24-M-015','M','White',58.50),
(7,'MU-A-24-XL-016','XL','White',58.50),
(8,'RM-H-24-M-017','M','White',65.00),
(8,'RM-H-24-L-018','L','White',65.00),
(9,'LIV-H-24-M-019','M','Red',62.00),
(9,'LIV-H-24-L-020','L','Red',62.00),
(10,'BAY-H-24-M-021','M','Red/White',63.00),
(10,'BAY-H-24-L-022','L','Red/White',63.00),
(11,'BAR-H-24-M-023','M','Blue/Red',67.00),
(11,'BAR-H-24-L-024','L','Blue/Red',67.00),
(11,'BAR-H-24-XL-025','XL','Blue/Red',67.00),
(12,'JUV-H-24-M-026','M','Black/White',64.00),
(12,'JUV-H-24-L-027','L','Black/White',64.00),
(13,'CHE-H-24-M-028','M','Blue',66.00),
(13,'CHE-H-24-S-029','S','Blue',66.00),
(14,'MIL-A-24-M-030','M','White',61.00),
(14,'MIL-A-24-L-031','L','White',61.00),
(15,'DOR-H-24-M-032','M','Yellow/Black',59.00),
(15,'DOR-H-24-L-033','L','Yellow/Black',59.00),
(16,'ATM-T-24-M-034','M','Blue/White',60.00),
(16,'ATM-T-24-L-035','L','Blue/White',60.00);

-- =====================
-- 5. INVENTORY (Depends on product_variants)
-- =====================
INSERT INTO inventory (variant_id, stock, restock_threshold, last_restock) VALUES
-- 2023/2024 season inventory
(1, 25, 5, '2023-08-10'),
(2, 45, 5, '2023-08-15'),
(3, 35, 5, '2023-09-20'),
(4, 50, 5, '2023-10-05'),
(5, 40, 5, '2023-11-12'),
(6, 30, 5, '2023-12-01'),
(7, 20, 5, '2024-01-15'),
(8, 55, 5, '2024-02-20'),
(9, 60, 5, '2024-03-10'),
-- 2024/2025 season inventory
(10, 50, 5, '2024-07-15'),
(11, 50, 5, '2024-07-15'),
(12, 40, 5, '2024-07-15'),
(13, 60, 5, '2024-08-01'),
(14, 30, 5, '2024-08-01'),
(15, 45, 5, '2024-08-20'),
(16, 20, 5, '2024-08-20'),
(17, 50, 5, '2024-09-01'),
(18, 50, 5, '2024-09-01'),
(19, 30, 5, '2024-09-01'),
(20, 30, 5, '2024-09-01'),
(21, 40, 5, '2024-09-15'),
(22, 40, 5, '2024-09-15'),
(23, 35, 5, '2024-10-01'),
(24, 30, 5, '2024-10-01'),
(25, 50, 5, '2024-11-15'),
(26, 45, 5, '2024-11-15'),
(27, 40, 5, '2024-10-20'),
(28, 30, 5, '2024-10-20'),
(29, 50, 5, '2024-09-25'),
(30, 35, 5, '2024-09-25'),
(31, 45, 5, '2024-08-30'),
(32, 40, 5, '2024-08-30'),
(33, 30, 5, '2024-07-15'),
(34, 25, 5, '2024-07-15');

-- =====================
-- 6. CUSTOMERS (No dependencies)
-- =====================
INSERT INTO customers (first_name,last_name,email,phone,street,city,postal_code,country) VALUES
('Luca','Rossi','luca.rossi@example.com','+39 3331112222','Via Italia 1','Napoli','80100','Italy'),
('Ana','Silva','ana.silva@example.com','+33 611222333','Rue de Paris 4','Paris','75001','France'),
('John','Smith','john.smith@example.com','+44 700000111','10 Downing','Manchester','M1 1AA','UK'),
('Maria','Garcia','maria.garcia@example.com','+34 600111222','Calle Madrid 3','Madrid','28001','Spain'),
('Marco','Bianchi','marco.bianchi@example.it','+39 3334445555','Via Roma 45','Milan','20100','Italy'),
('Sophie','Dubois','sophie.dubois@example.fr','+33 612345678','Avenue des Champs 8','Lyon','69001','France'),
('James','Wilson','james.wilson@example.uk','+44 7700900123','Baker Street 221B','London','NW1 6XE','UK'),
('Carlos','Martinez','carlos.martinez@example.es','+34 611223344','Gran Via 100','Barcelona','08001','Spain'),
('Emma','Johnson','emma.johnson@example.com','+1 555-0199','5th Avenue 350','New York','10001','USA'),
('Hans','Mueller','hans.mueller@example.de','+49 170 1234567','Hauptstrasse 12','Munich','80331','Germany'),
('Isabella','Romano','isabella.romano@example.it','+39 3339876543','Corso Italia 88','Rome','00100','Italy'),
('Pierre','Laurent','pierre.laurent@example.fr','+33 623456789','Rue Victor Hugo 5','Marseille','13001','France'),
('Oliver','Brown','oliver.brown@example.uk','+44 7800123456','Oxford Street 50','Birmingham','B1 1AA','UK'),
('Diego','Lopez','diego.lopez@example.es','+34 622334455','Calle Mayor 22','Seville','41001','Spain');

-- =====================
-- 7. ORDERS (Depends on customers) - Spanning 2023-2025
-- =====================
INSERT INTO orders (customer_id, order_date, status, shipping_address) VALUES
-- 2023 Orders (August - December)
(5,'2023-08-15 14:30:00','PAID','Via Roma 45, Milan'),
(6,'2023-09-22 10:15:00','PAID','Avenue des Champs 8, Lyon'),
(7,'2023-10-10 16:45:00','PAID','Baker Street 221B, London'),
(8,'2023-11-05 11:20:00','PAID','Gran Via 100, Barcelona'),
(9,'2023-12-01 09:30:00','PAID','5th Avenue 350, New York'),
(10,'2023-12-20 15:00:00','PAID','Hauptstrasse 12, Munich'),
-- 2024 Orders (January - December)
(11,'2024-01-15 10:00:00','PAID','Corso Italia 88, Rome'),
(12,'2024-02-20 14:30:00','PAID','Rue Victor Hugo 5, Marseille'),
(13,'2024-03-10 11:45:00','PAID','Oxford Street 50, Birmingham'),
(14,'2024-04-05 16:20:00','PAID','Calle Mayor 22, Seville'),
(1,'2024-05-12 10:30:00','PAID','Via Italia 1, Napoli'),
(2,'2024-06-18 15:45:00','PAID','Rue de Paris 4, Paris'),
(3,'2024-07-22 12:00:00','PAID','10 Downing, Manchester'),
(4,'2024-08-30 09:15:00','PAID','Calle Madrid 3, Madrid'),
(5,'2024-09-10 14:00:00','PAID','Via Roma 45, Milan'),
(6,'2024-10-05 11:30:00','PAID','Avenue des Champs 8, Lyon'),
(7,'2024-11-12 16:00:00','PAID','Baker Street 221B, London'),
(8,'2024-12-01 10:45:00','PAID','Gran Via 100, Barcelona'),
-- 2025 Orders (January - February)
(1,'2025-01-05 10:00:00','PAID','Via Italia 1, Napoli'),
(2,'2025-01-07 15:00:00','PAID','Rue de Paris 4, Paris'),
(3,'2025-01-08 11:00:00','PAID','10 Downing, Manchester'),
(4,'2025-01-09 12:00:00','PAID','Calle Madrid 3, Madrid'),
(1,'2025-01-10 13:00:00','CREATED','Via Italia 1, Napoli'),
(2,'2025-01-11 14:00:00','PAID','Rue de Paris 4, Paris'),
(9,'2025-01-20 14:30:00','PAID','5th Avenue 350, New York'),
(10,'2025-01-25 11:00:00','CREATED','Hauptstrasse 12, Munich'),
(11,'2025-02-05 15:30:00','SHIPPED','Corso Italia 88, Rome'),
(12,'2025-02-10 10:20:00','PAID','Rue Victor Hugo 5, Marseille');

-- =====================
-- 8. ORDER ITEMS (Depends on orders and product_variants)
-- =====================
INSERT INTO order_items (order_id, variant_id, quantity, unit_price) VALUES
-- 2023 Orders Items
(1,2,2,50.00),    -- Order 1: 2x Napoli 2023 L
(1,3,1,50.00),    -- Order 1: 1x Napoli 2023 XL
(2,5,3,55.00),    -- Order 2: 3x PSG Away 2023 L
(3,4,1,55.00),    -- Order 3: 1x PSG Away 2023 M
(3,6,2,58.00),    -- Order 3: 2x Real Madrid Third M
(4,8,1,57.00),    -- Order 4: 1x Liverpool Away M
(4,9,2,57.00),    -- Order 4: 2x Liverpool Away L
(5,10,2,55.00),   -- Order 5: 2x Napoli 2024 M
(5,13,1,60.00),   -- Order 5: 1x PSG 2024 M
(6,9,1,57.00),    -- Order 6: 1x Liverpool Away L
(6,2,2,50.00),    -- Order 6: 2x Napoli 2023 L
-- 2024 Orders Items
(7,1,1,50.00),    -- Order 7: 1x Napoli 2023 M
(7,23,2,67.00),   -- Order 7: 2x Barcelona M
(8,24,1,67.00),   -- Order 8: 1x Barcelona L
(8,25,1,67.00),   -- Order 8: 1x Barcelona XL
(9,26,3,64.00),   -- Order 9: 3x Juventus M
(10,27,2,64.00),  -- Order 10: 2x Juventus L
(10,28,1,66.00),  -- Order 10: 1x Chelsea M
(11,29,1,66.00),  -- Order 11: 1x Chelsea S
(11,30,2,61.00),  -- Order 11: 2x AC Milan M
(12,31,1,61.00),  -- Order 12: 1x AC Milan L
(12,32,1,59.00),  -- Order 12: 1x Dortmund M
(13,33,2,59.00),  -- Order 13: 2x Dortmund L
(14,34,1,60.00),  -- Order 14: 1x Atletico M
(14,10,2,55.00),  -- Order 14: 2x Napoli 2024 M
(15,11,1,55.00),  -- Order 15: 1x Napoli 2024 L
(15,17,2,65.00),  -- Order 15: 2x Real Madrid M
(16,19,3,62.00),  -- Order 16: 3x Liverpool M
(17,21,1,63.00),  -- Order 17: 1x Bayern M
(17,23,1,67.00),  -- Order 17: 1x Barcelona M
(18,24,2,67.00),  -- Order 18: 2x Barcelona L
-- 2025 Orders Items
(19,10,2,55.00),  -- Order 19: 2x Napoli 2024 M
(19,13,1,60.00),  -- Order 19: 1x PSG M
(20,11,3,55.00),  -- Order 20: 3x Napoli L
(20,14,2,60.00),  -- Order 20: 2x PSG L
(21,15,1,58.50),  -- Order 21: 1x Man United M
(21,17,2,65.00),  -- Order 21: 2x Real Madrid M
(22,19,1,62.00),  -- Order 22: 1x Liverpool M
(22,21,2,63.00),  -- Order 22: 2x Bayern M
(23,10,1,55.00),  -- Order 23: 1x Napoli M
(23,12,1,55.00),  -- Order 23: 1x Napoli S
(24,11,1,55.00),  -- Order 24: 1x Napoli L
(24,14,1,60.00),  -- Order 24: 1x PSG L
(25,25,1,67.00),  -- Order 25: 1x Barcelona XL
(25,26,2,64.00),  -- Order 25: 2x Juventus M
(26,28,1,66.00),  -- Order 26: 1x Chelsea M
(26,29,1,66.00),  -- Order 26: 1x Chelsea S
(27,30,2,61.00),  -- Order 27: 2x AC Milan M
(27,32,1,59.00),  -- Order 27: 1x Dortmund M
(28,10,1,55.00),  -- Order 28: 1x Napoli M
(28,14,1,60.00);  -- Order 28: 1x PSG L

-- =====================
-- 9. PAYMENTS (Depends on orders)
-- =====================
INSERT INTO payments (order_id, paid_amount, paid_on, method, status) VALUES
-- 2023 Payments
(1,150.00,'2023-08-15 14:45:00','CARD','SUCCESS'),
(2,165.00,'2023-09-22 10:30:00','PAYPAL','SUCCESS'),
(3,171.00,'2023-10-10 17:00:00','CARD','SUCCESS'),
(4,171.00,'2023-11-05 11:35:00','BANK_TRANSFER','SUCCESS'),
(5,170.00,'2023-12-01 09:45:00','CARD','SUCCESS'),
(6,157.00,'2023-12-20 15:20:00','PAYPAL','SUCCESS'),
-- 2024 Payments
(7,184.00,'2024-01-15 10:30:00','CARD','SUCCESS'),
(8,134.00,'2024-02-20 15:00:00','PAYPAL','SUCCESS'),
(9,192.00,'2024-03-10 12:00:00','CARD','SUCCESS'),
(10,194.00,'2024-04-05 16:40:00','BANK_TRANSFER','SUCCESS'),
(11,188.00,'2024-05-12 11:00:00','CARD','SUCCESS'),
(12,120.00,'2024-06-18 16:00:00','PAYPAL','SUCCESS'),
(13,118.00,'2024-07-22 12:30:00','CARD','SUCCESS'),
(14,170.00,'2024-08-30 09:45:00','CARD','SUCCESS'),
(15,185.00,'2024-09-10 14:30:00','PAYPAL','SUCCESS'),
(16,186.00,'2024-10-05 12:00:00','CARD','SUCCESS'),
(17,130.00,'2024-11-12 16:30:00','BANK_TRANSFER','SUCCESS'),
(18,134.00,'2024-12-01 11:15:00','CARD','SUCCESS'),
-- 2025 Payments
(19,170.00,'2025-01-05 10:30:00','CARD','SUCCESS'),
(20,285.00,'2025-01-07 15:20:00','PAYPAL','SUCCESS'),
(21,188.50,'2025-01-08 11:20:00','CARD','SUCCESS'),
(22,188.00,'2025-01-09 12:30:00','BANK_TRANSFER','SUCCESS'),
(23,55.00,'2025-01-10 13:10:00','CARD','SUCCESS'),
(24,115.00,'2025-01-11 14:20:00','PAYPAL','SUCCESS'),
(25,195.00,'2025-01-20 15:00:00','CARD','SUCCESS'),
(28,115.00,'2025-02-10 10:45:00','PAYPAL','SUCCESS');
-- Note: Orders 26, 27 have no payments (CREATED/SHIPPED status)

-- =====================
-- 10. RATINGS (Depends on customers and product_variants)
-- =====================
INSERT INTO ratings (customer_id, variant_id, rating, comment, rated_on) VALUES
-- 2023 Ratings
(5,2,5,'Perfect fit, great quality','2023-08-20'),
(6,5,4,'Nice jersey, fast delivery','2023-09-25'),
(7,4,5,'Amazing quality!','2023-10-15'),
(8,9,3,'Good but expensive','2023-11-10'),
(9,10,5,'Best purchase ever','2023-12-05'),
(10,9,4,'Very satisfied','2023-12-25'),
-- 2024 Ratings
(11,1,5,'Excellent material','2024-01-20'),
(12,23,5,'Love Barcelona colors','2024-02-25'),
(13,26,4,'Good jersey','2024-03-15'),
(14,28,5,'Chelsea fan here, perfect!','2024-04-10'),
(1,29,4,'Good quality','2024-05-17'),
(2,31,5,'AC Milan forever','2024-06-22'),
(3,33,4,'Nice design','2024-07-26'),
(4,34,3,'Average quality','2024-09-05'),
(5,10,5,'Bought again, still great','2024-09-15'),
(6,11,4,'Good product','2024-10-10'),
(7,17,5,'Real Madrid quality','2024-11-18'),
(8,23,4,'Nice Barcelona jersey','2024-12-05'),
-- 2025 Ratings
(1,10,5,'Excellent quality','2025-01-12'),
(2,11,4,'Good','2025-01-13'),
(3,15,3,'Average','2025-01-14'),
(4,21,5,'Love it!','2025-01-15'),
(9,25,5,'Great purchase','2025-01-25'),
(12,28,4,'Chelsea looks good','2025-02-12');

-- =====================
-- 11. UPDATE TOTAL_AMOUNT FOR ALL ORDERS
-- =====================
SET SQL_SAFE_UPDATES = 0;

UPDATE orders o
JOIN (
    SELECT order_id, SUM(quantity*unit_price) AS total
    FROM order_items
    GROUP BY order_id
) oi_sum ON o.order_id = oi_sum.order_id
SET o.total_amount = oi_sum.total;

SET SQL_SAFE_UPDATES = 1;

-- VIEWS-- 

-- HEAD: single view per ordine (one row per order)
CREATE OR REPLACE VIEW view_invoice_head AS
SELECT
  o.order_id,
  o.order_date,
  o.status,
  o.customer_id,
  CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
  c.email AS customer_email,
  o.shipping_address,
  COALESCE(SUM(oi.quantity * oi.unit_price),0) AS sub_total,
  COALESCE((SELECT SUM(p.paid_amount) FROM payments p WHERE p.order_id = o.order_id), 0) AS amount_paid,
  COALESCE(SUM(oi.quantity * oi.unit_price),0) - COALESCE((SELECT SUM(p.paid_amount) FROM payments p WHERE p.order_id = o.order_id), 0) AS balance_due
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id;

-- DETAILS: one row per order_item
CREATE OR REPLACE VIEW view_invoice_details AS
SELECT
  oi.order_id,
  oi.order_item_id,
  pv.sku,
  p.model,
  t.name AS team_name,
  pv.size,
  pv.color,
  oi.quantity,
  oi.unit_price,
  (oi.quantity * oi.unit_price) AS line_total
FROM order_items oi
JOIN product_variants pv ON oi.variant_id = pv.variant_id
JOIN products p ON pv.product_id = p.product_id
LEFT JOIN teams t ON p.team_id = t.team_id;

-- QUERIES--


-- Top five products

SELECT p.product_id, p.model, t.name AS team_name,
       SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN product_variants pv ON oi.variant_id = pv.variant_id
JOIN products p ON pv.product_id = p.product_id
JOIN teams t ON p.team_id = t.team_id
GROUP BY p.product_id, p.model, t.name
ORDER BY revenue DESC
LIMIT 1;

-- Monthly sellings
SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS `year_month`,
       SUM(oi.quantity * oi.unit_price) AS monthly_revenue,
       COUNT(DISTINCT o.order_id) AS orders_count
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE YEAR(o.order_date) = 2023
GROUP BY `year_month`
ORDER BY `year_month`;


-- top customers

SELECT c.customer_id, CONCAT(c.first_name,' ',c.last_name) AS customer,
       SUM(oi.quantity * oi.unit_price) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 1;

-- products that are finishing

SELECT pv.variant_id, pv.sku, p.model, t.name AS team_name, i.stock, i.restock_threshold
FROM inventory i
JOIN product_variants pv ON i.variant_id = pv.variant_id
JOIN products p ON pv.product_id = p.product_id
JOIN teams t ON p.team_id = t.team_id
WHERE i.stock <= i.restock_threshold;

SELECT * FROM inventory LIMIT 5;

UPDATE inventory
SET stock = 4
WHERE variant_id = 3;

-- rating per team 

SELECT t.team_id, t.name AS team, AVG(r.rating) AS avg_rating, COUNT(r.rating_id) AS num_ratings
FROM ratings r
JOIN product_variants pv ON r.variant_id = pv.variant_id
JOIN products p ON pv.product_id = p.product_id
JOIN teams t ON p.team_id = t.team_id
GROUP BY t.team_id, t.name
ORDER BY avg_rating DESC;

SELECT * 
FROM logs
ORDER BY created_at DESC;


