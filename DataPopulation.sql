-- ==========================
-- 1. CLASS
-- ==========================
INSERT INTO Class(class_id, class_code, class_name, base_fare_multiplier)
VALUES
(1, 'SL', 'Sleeper', 1.0),
(2, '3A', 'AC 3-Tier', 1.5),
(3, '2A', 'AC 2-Tier', 2.0),
(4, '1A', 'First AC', 2.5),
(5, 'CC', 'Chair Car', 1.2);

-- ==========================
-- 2. STATION
-- ==========================
INSERT INTO Station(station_id, station_name, station_code, city, state)
VALUES
(101, 'Mumbai Central', 'BCT', 'Mumbai', 'Maharashtra'),
(102, 'New Delhi', 'NDLS', 'Delhi', 'Delhi'),
(103, 'Chennai Central', 'MAS', 'Chennai', 'Tamil Nadu'),
(104, 'Howrah Junction', 'HWH', 'Kolkata', 'West Bengal'),
(105, 'Bengaluru City', 'SBC', 'Bengaluru', 'Karnataka');

-- ==========================
-- 3. TRAIN_ROUTES
-- ==========================
INSERT INTO Train_Routes(route_id, source_station, destination_station, distance)
VALUES
(201, 'Mumbai Central', 'New Delhi', 1384),
(202, 'New Delhi', 'Howrah Junction', 1530),
(203, 'Mumbai Central', 'Chennai Central', 1278),
(204, 'Chennai Central', 'Howrah Junction', 1663),
(205, 'Howrah Junction', 'Bengaluru City', 1860);

-- ==========================
-- 4. TRAIN
-- ==========================
INSERT INTO Train(train_id, train_name, train_number, train_type, total_seats, operating_days, is_active)
VALUES
(301, 'Mumbai Rajdhani', '12951', 'Rajdhani', 1000, 'Daily', TRUE),
(302, 'New Delhi Duronto', '12274', 'Duronto', 1200, 'Thu,Sun', TRUE),
(303, 'Chennai Express', '12163', 'Superfast', 900, 'Mon,Wed,Fri', TRUE),
(304, 'Howrah Mail', '12809', 'Mail', 800, 'Daily', TRUE),
(305, 'Bengaluru Express', '16506', 'Express', 700, 'Tue,Sat', TRUE);

-- ==========================
-- 5. SCHEDULE
-- (references TRAIN, TRAIN_ROUTES)
-- ==========================
INSERT INTO Schedule(schedule_id, train_id, route_id)
VALUES
(401, 301, 201),
(402, 302, 202),
(403, 303, 203),
(404, 304, 204),
(405, 305, 205);

-- ==========================
-- 6. STATION_CONNECTS
-- (references TRAIN_ROUTES, STATION)
-- ==========================
INSERT INTO Station_Connects(route_id, station_id, sequence_number, distance_from_source)
VALUES
(201, 101, 1, 0),       -- route 201 starts at station_id=101 (Mumbai Central)
(201, 102, 2, 1384),    -- route 201 ends at station_id=102 (New Delhi)
(202, 102, 1, 0),       -- route 202 starts at NDLS
(202, 104, 2, 1530),    -- route 202 ends at Howrah
(203, 101, 1, 0),
(203, 103, 2, 1278);

-- ==========================
-- 7. OFFERS
-- (references TRAIN, CLASS)
-- ==========================
INSERT INTO Offers(train_id, class_id, available_seats, booking_status)
VALUES
(301, 1, 200, 'Open'),
(301, 2, 150, 'Open'),
(302, 2, 200, 'Open'),
(303, 3, 100, 'Open'),
(305, 5, 100, 'Open');

-- ==========================
-- 8. RESERVED_ON
-- (references TRAIN, CLASS)
-- ==========================
INSERT INTO Reserved_On(train_id, coach_number, seat_number, class_id)
VALUES
(301, 'S1',  '01', 1),
(301, 'S1',  '02', 1),
(302, 'A1',  '01', 2),
(303, 'A2',  '05', 3),
(305, 'CC1', '10', 5);

-- ==========================
-- 9. STOPS_AT
-- (references TRAIN, STATION)
-- ==========================
INSERT INTO Stops_At(train_id, station_id, day_of_journey, arrival_time, departure_time)
VALUES
(301, 101, 1, '09:00:00', '09:10:00'),
(301, 102, 2, '12:00:00', '12:10:00'),
(302, 102, 1, '08:00:00', '08:05:00'),
(302, 104, 2, '15:00:00', '15:10:00'),
(303, 103, 1, '10:00:00', '10:05:00');

-- ==========================
-- 10. PASSENGER
-- ==========================
INSERT INTO Passenger(passenger_id, passenger_name, passenger_age, passenger_gender)
VALUES
(501, 'Ravi Kumar', 30, 'M'),
(502, 'Anita Sharma', 45, 'F'),
(503, 'Vijay Singh', 25, 'M'),
(504, 'Neha Gupta', 34, 'F'),
(505, 'Rahul Das', 19, 'M');

-- ==========================
-- 11. TICKET
-- ==========================
INSERT INTO Ticket (
  ticket_id, 
  pnr_number, 
  journey_date, 
  booking_status, 
  fare_amount, 
  ticket_type,
  concession_category,
  class_id
)
VALUES
(601, 'PNR1234561', '2025-05-01', 'Confirmed', 1500.00, 'Adult', 'None',    302),
(602, 'PNR1234562', '2025-05-02', 'WL',        1200.00, 'Adult', 'None',    301),
(603, 'PNR1234563', '2025-05-03', 'Confirmed', 800.00,  'Child', 'Student', 302),
(604, 'PNR1234564', '2025-05-04', 'RAC',       1000.00, 'Adult', 'Senior',  303),
(605, 'PNR1234565', '2025-05-05', 'Confirmed', 2000.00, 'Adult', 'None',    304);

-- ==========================
-- 12. TICKET_PASSENGER
-- (references TICKET, PASSENGER)
-- ==========================
INSERT INTO Ticket_Passenger(ticket_id, passenger_id, seat_number, booking_status)
VALUES
(601, 501, 'S1-05', 'Confirmed'),
(602, 502, NULL,    'WL'),
(603, 503, 'A1-12', 'Confirmed'),
(604, 504, 'A2-10', 'RAC'),
(605, 505, 'S1-15', 'Confirmed');

-- ==========================
-- 13. CUSTOMER
-- ==========================
INSERT INTO Customer(customer_id, customer_name, customer_mobile, customer_email, customer_address, login_id, password_hash)
VALUES
(701, 'Raj Verma',  '9876543210', 'raj@example.com',   'Delhi, India',     'rajv',   'hash1'),
(702, 'Sneha Rao',  '9123456780', 'sneha@example.com', 'Bengaluru, India','sraoo',  'hash2'),
(703, 'Amit Patel', '9012345678', 'amit@example.com',  'Mumbai, India',   'amitp',  'hash3'),
(704, 'Meera Iyer', '9112233445', 'meera@example.com', 'Chennai, India',  'meera',  'hash4'),
(705, 'Rohan Roy',  '9222334455', 'rohan@example.com', 'Kolkata, India',  'rohanr', 'hash5');

-- ==========================
-- 14. BOOKING
-- ==========================
INSERT INTO Booking(booking_id, booking_type, booking_date, total_amount, booking_status)
VALUES
(801, 'Online',  '2025-04-15 10:30:00', 1500.00, 'Confirmed'),
(802, 'Counter', '2025-04-16 11:00:00', 1200.00, 'Confirmed'),
(803, 'Online',  '2025-04-17 09:15:00', 800.00,  'Cancelled'),
(804, 'Counter', '2025-04-18 12:45:00', 1000.00, 'Confirmed'),
(805, 'Online',  '2025-04-19 14:00:00', 2000.00, 'Confirmed');

-- ==========================
-- 15. BOOKING_TICKET
-- (references BOOKING, TICKET)
-- ==========================
INSERT INTO Booking_Ticket(booking_id, ticket_id)
VALUES
(801, 601),
(802, 602),
(803, 603),
(804, 604),
(805, 605);

-- ==========================
-- 16. PAYMENT
-- (references BOOKING)
-- ==========================
INSERT INTO Payment (
  payment_id,
  booking_id,
  payment_date,
  payment_amount,
  payment_mode,
  transaction_status,
  refund_amount,
  refund_date
)
VALUES
(901, 801, '2025-04-15 10:31:00', 1500.00, 'Credit Card', 'Success',    0.00,   NULL),
(902, 802, '2025-04-16 11:05:00', 1200.00, 'Cash',        'Success',    0.00,   NULL),
(903, 803, '2025-04-17 09:20:00', 800.00,  'UPI',         'Success',  200.00, '2025-04-17 10:00:00'),
(904, 804, '2025-04-18 12:50:00', 1000.00, 'Debit Card',  'Success',    0.00,   NULL),
(905, 805, '2025-04-19 14:05:00', 2000.00, 'Credit Card', 'Success',    0.00,   NULL);

-- ==========================
-- 17. PAYS
-- (references CUSTOMER, PAYMENT)
-- ==========================
INSERT INTO Pays(customer_id, payment_id)
VALUES
(701, 901),
(702, 902),
(703, 903),
(704, 904),
(705, 905);

-- ==========================
-- 18. CUSTOMER_TICKET
-- (references CUSTOMER, TICKET)
-- ==========================
INSERT INTO Customer_Ticket(customer_id, ticket_id, booking_date)
VALUES
(701, 601, '2025-04-15 10:30:00'),
(702, 602, '2025-04-16 11:00:00'),
(703, 603, '2025-04-17 09:15:00'),
(704, 604, '2025-04-18 12:45:00'),
(705, 605, '2025-04-19 14:00:00');