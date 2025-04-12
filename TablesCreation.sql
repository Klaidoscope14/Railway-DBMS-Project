-- ============================
-- 1. TRAIN
-- ============================
CREATE TABLE Train (
  train_id       INT PRIMARY KEY,
  train_name     VARCHAR(100),
  train_number   VARCHAR(10),
  train_type     VARCHAR(50),
  total_seats    INT,
  operating_days VARCHAR(50),  -- e.g., "Mon, Wed, Fri"
  is_active      BOOLEAN
);

-- ============================
-- 2. TRAIN_ROUTES
-- ============================
CREATE TABLE Train_Routes (
  route_id           INT PRIMARY KEY,
  source_station     VARCHAR(50),
  destination_station VARCHAR(50),
  distance           INT
);

-- ============================
-- 3. SCHEDULE
-- (Train ↔️ Train_Routes linkage)
-- ============================
CREATE TABLE Schedule (
  schedule_id INT PRIMARY KEY,
  train_id    INT,
  route_id    INT,
  FOREIGN KEY (train_id) REFERENCES Train(train_id),
  FOREIGN KEY (route_id) REFERENCES Train_Routes(route_id)
);

-- ============================
-- 4. STATION
-- ============================
CREATE TABLE Station (
  station_id    INT PRIMARY KEY,
  station_name  VARCHAR(100),
  station_code  VARCHAR(10),
  city          VARCHAR(50),
  state         VARCHAR(50)
);

-- ============================
-- 5. STATION_CONNECTS
-- (Route ↔️ Station with sequence info)
-- ============================
CREATE TABLE Station_Connects (
  route_id            INT,
  station_id          INT,
  sequence_number     INT,
  distance_from_source INT,
  PRIMARY KEY (route_id, station_id),
  FOREIGN KEY (route_id)   REFERENCES Train_Routes(route_id),
  FOREIGN KEY (station_id) REFERENCES Station(station_id)
);

-- ============================
-- 6. CLASS 
-- (Different travel classes)
-- ============================
CREATE TABLE Class (
  class_id             INT PRIMARY KEY,
  class_code           VARCHAR(10),
  class_name           VARCHAR(50),
  base_fare_multiplier DECIMAL(5,2)
);

-- ============================
-- 7. PASSENGER
-- ============================
CREATE TABLE Passenger (
  passenger_id     INT PRIMARY KEY,
  passenger_name   VARCHAR(100),
  passenger_age    INT,
  passenger_gender CHAR(1)    -- e.g., 'M'/'F'/'O'
);

-- ============================
-- 8. CUSTOMER
-- (User who actually makes the booking)
-- ============================
CREATE TABLE Customer (
  customer_id      INT PRIMARY KEY,
  customer_name    VARCHAR(100),
  customer_mobile  VARCHAR(15),
  customer_email   VARCHAR(100),
  customer_address TEXT,
  login_id         VARCHAR(50),
  password_hash    VARCHAR(255)
);

-- ============================
-- 9. TICKET
-- (Includes PNR, Journey date, Concession category, etc.)
-- ============================
CREATE TABLE Ticket (
  ticket_id            INT PRIMARY KEY,
  pnr_number           VARCHAR(20) UNIQUE,
  journey_date         DATE,
  booking_status       VARCHAR(20),    -- e.g. 'Confirmed', 'WL', 'RAC', 'Cancelled'
  fare_amount          DECIMAL(10,2),
  ticket_type          VARCHAR(20),    -- 'Adult', 'Child', etc.
  concession_category  VARCHAR(50),    -- 'Senior', 'Student', etc.
  
  -- NEW: link to Class for this ticket
  class_id             INT,
  FOREIGN KEY (class_id) REFERENCES Class(class_id)
);

-- ============================
-- 10. BOOKING
-- (Tracks overall booking info)
-- ============================
CREATE TABLE Booking (
  booking_id     INT PRIMARY KEY,
  booking_type   VARCHAR(20),   -- e.g. 'Online', 'Counter'
  booking_date   DATETIME,
  total_amount   DECIMAL(10,2),
  booking_status VARCHAR(20)    -- e.g. 'Confirmed', 'Cancelled'
);

-- ============================
-- 11. PAYMENT
-- (Now includes refund details)
-- ============================
CREATE TABLE Payment (
  payment_id        INT PRIMARY KEY,
  booking_id        INT,
  payment_date      DATETIME,
  payment_amount    DECIMAL(10,2),
  payment_mode      VARCHAR(20),  -- e.g. 'Credit Card', 'UPI', 'Cash'
  transaction_status VARCHAR(20), -- e.g. 'Success', 'Failed', 'Pending'
  
  -- NEW columns for cancellation refunds
  refund_amount     DECIMAL(10,2) DEFAULT 0,
  refund_date       DATETIME      NULL,
  
  FOREIGN KEY (booking_id) REFERENCES Booking(booking_id)
);

-- ============================
-- 12. RESERVED_ON
-- (Train-level seat mapping)
-- ============================
CREATE TABLE Reserved_On (
  train_id     INT,
  coach_number VARCHAR(10),
  seat_number  VARCHAR(10),
  class_id     INT,
  
  PRIMARY KEY (train_id, coach_number, seat_number),
  FOREIGN KEY (train_id) REFERENCES Train(train_id),
  FOREIGN KEY (class_id) REFERENCES Class(class_id)
);

-- ============================
-- 13. STOPS_AT
-- (Train ↔️ Station schedule details)
-- ============================
CREATE TABLE Stops_At (
  train_id       INT,
  station_id     INT,
  day_of_journey INT,
  arrival_time   TIME,
  departure_time TIME,
  
  PRIMARY KEY (train_id, station_id, day_of_journey),
  FOREIGN KEY (train_id)   REFERENCES Train(train_id),
  FOREIGN KEY (station_id) REFERENCES Station(station_id)
);

-- ============================
-- 14. TICKET_PASSENGER
-- (Which passenger(s) are on which ticket + seat)
-- ============================
CREATE TABLE Ticket_Passenger (
  ticket_id       INT,
  passenger_id    INT,
  seat_number     VARCHAR(10),
  booking_status  VARCHAR(20),    -- e.g. 'Confirmed', 'WL', 'RAC'
  
  PRIMARY KEY (ticket_id, passenger_id),
  FOREIGN KEY (ticket_id)   REFERENCES Ticket(ticket_id),
  FOREIGN KEY (passenger_id) REFERENCES Passenger(passenger_id)
);

-- ============================
-- 15. CUSTOMER_TICKET
-- (Which customer owns which ticket?)
-- ============================
CREATE TABLE Customer_Ticket (
  customer_id   INT,
  ticket_id     INT,
  booking_date  DATETIME,
  
  PRIMARY KEY (customer_id, ticket_id),
  FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
  FOREIGN KEY (ticket_id)   REFERENCES Ticket(ticket_id)
);

-- ============================
-- 16. BOOKING_TICKET
-- (Junction between Booking and Ticket)
-- ============================
CREATE TABLE Booking_Ticket (
  booking_id INT,
  ticket_id  INT,
  
  PRIMARY KEY (booking_id, ticket_id),
  FOREIGN KEY (booking_id) REFERENCES Booking(booking_id),
  FOREIGN KEY (ticket_id)  REFERENCES Ticket(ticket_id)
);

-- ============================
-- 17. OFFERS
-- (Train ↔️ Class seat availability)
-- ============================
CREATE TABLE Offers (
  train_id       INT,
  class_id       INT,
  available_seats INT,
  booking_status VARCHAR(20),  -- e.g. 'Open', 'Full', 'RAC', 'WL'
  
  PRIMARY KEY (train_id, class_id),
  FOREIGN KEY (train_id) REFERENCES Train(train_id),
  FOREIGN KEY (class_id) REFERENCES Class(class_id)
);

-- ============================
-- 18. PAYS
-- (Customer ↔️ Payment)
-- ============================
CREATE TABLE Pays (
  customer_id INT,
  payment_id  INT,
  
  PRIMARY KEY (customer_id, payment_id),
  FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
  FOREIGN KEY (payment_id)  REFERENCES Payment(payment_id)
);