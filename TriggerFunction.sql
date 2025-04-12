-- Creates a new booking, inserts tickets, updates seat availability, etc.

DELIMITER $$

CREATE PROCEDURE sp_create_booking(
  IN p_customer_id INT,
  IN p_train_id INT,
  IN p_class_id INT,
  IN p_journey_date DATE,
  IN p_total_passengers INT,
  IN p_booking_type VARCHAR(20)
)
BEGIN
  DECLARE v_booking_id INT;
  DECLARE v_ticket_id INT;
  DECLARE v_current_date DATETIME DEFAULT NOW();
  DECLARE v_available_seats INT;
  DECLARE v_counter INT DEFAULT 0;
  
  -- 1) Create a new booking record
  INSERT INTO Booking (booking_type, booking_date, total_amount, booking_status)
  VALUES (p_booking_type, v_current_date, 0, 'Confirmed');
  
  SET v_booking_id = LAST_INSERT_ID();

  -- 2) Check seat availability from Offers
  SELECT available_seats 
    INTO v_available_seats
    FROM Offers
   WHERE train_id = p_train_id
     AND class_id = p_class_id;
     
  IF v_available_seats < p_total_passengers THEN
    -- Not enough seats for all. For simplicity, throw an error:
    SIGNAL SQLSTATE '45000' 
      SET MESSAGE_TEXT = 'Not enough seats available!';
  END IF;
  
  -- 3) Create a Ticket record
  INSERT INTO Ticket (pnr_number, journey_date, booking_status, fare_amount, 
                      ticket_type, concession_category, class_id)
  VALUES (NULL, p_journey_date, 'Confirmed', 0, 'Adult', 'None', p_class_id);
  
  SET v_ticket_id = LAST_INSERT_ID();
  
  -- 4) Link the ticket to the booking
  INSERT INTO Booking_Ticket (booking_id, ticket_id)
  VALUES (v_booking_id, v_ticket_id);
  
  -- 5) Link the ticket to the customer (assuming one ticket per booking in this example)
  INSERT INTO Customer_Ticket (customer_id, ticket_id, booking_date)
  VALUES (p_customer_id, v_ticket_id, v_current_date);
  
  -- 6) Decrement seats in Offers by the number of passengers
  UPDATE Offers
     SET available_seats = available_seats - p_total_passengers
   WHERE train_id = p_train_id
     AND class_id = p_class_id;

  -- 7) (Optional) For demonstration, create multiple passenger records 
  --    in Ticket_Passenger. In real life, you'd pass a list of passenger IDs or details.
  SET v_counter = 1;
  WHILE v_counter <= p_total_passengers DO
    INSERT INTO Ticket_Passenger (ticket_id, passenger_id, seat_number, booking_status)
    VALUES (v_ticket_id, (500 + v_counter), CONCAT('S1-', v_counter), 'Confirmed'); 
    SET v_counter = v_counter + 1;
  END WHILE;

  -- 8) End
  SELECT v_booking_id AS NewBookingID, v_ticket_id AS NewTicketID;
END$$

DELIMITER ;


--Cancels a booking, updates statuses, frees seats, and processes refunds if applicable.

DELIMITER $$

CREATE PROCEDURE sp_cancel_booking(
  IN p_booking_id INT
)
BEGIN
  DECLARE v_ticket_id INT;
  DECLARE done INT DEFAULT 0;
  DECLARE cur CURSOR FOR 
    SELECT ticket_id FROM Booking_Ticket WHERE booking_id = p_booking_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
  
  -- Mark the booking as Cancelled
  UPDATE Booking
     SET booking_status = 'Cancelled'
   WHERE booking_id = p_booking_id;
  
  -- For each ticket in the booking, do the following
  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO v_ticket_id;
    IF done = 1 THEN
      LEAVE read_loop;
    END IF;
    
    -- Cancel the ticket
    UPDATE Ticket
       SET booking_status = 'Cancelled'
     WHERE ticket_id = v_ticket_id;
    
    -- Optionally free seats. 
    -- For simplicity, we'll assume each ticket only accounts for 1 seat here. 
    -- If multiple passengers were on the ticket, you'd sum them up from Ticket_Passenger.
    UPDATE Offers
       JOIN Ticket t ON t.class_id = Offers.class_id
                    AND t.ticket_id = v_ticket_id
       SET Offers.available_seats = Offers.available_seats + 1
     WHERE Offers.train_id = (SELECT train_id FROM Schedule s 
                              JOIN Booking_Ticket bt ON bt.ticket_id = t.ticket_id
                              JOIN Booking b ON b.booking_id = bt.booking_id
                              WHERE b.booking_id = p_booking_id
                              LIMIT 1)
       -- Adjust logic to find correct train_id
       AND t.ticket_id = v_ticket_id;
    
    -- (Optional) Record a refund in Payment 
    UPDATE Payment
       SET refund_amount = payment_amount, 
           refund_date = NOW()
     WHERE booking_id = p_booking_id
       AND refund_amount = 0; -- If not already refunded
  END LOOP;
  CLOSE cur;
  
END$$

DELIMITER ;


--Promotes waitlisted or RAC tickets if seats become available.
DELIMITER $$

CREATE PROCEDURE sp_update_waitlist(
  IN p_train_id INT,
  IN p_class_id INT
)
BEGIN
  DECLARE v_waitlist_ticket INT;
  DECLARE v_seats INT;
  
  -- Check how many seats are currently free
  SELECT available_seats INTO v_seats
    FROM Offers
   WHERE train_id = p_train_id
     AND class_id = p_class_id;
  
  IF v_seats <= 0 THEN
    -- No seats available to promote
    LEAVE sp_update_waitlist;
  END IF;
  
  -- "Promote" the earliest WL or RAC ticket 
  -- (This is a simple approach; real logic might track booking timestamps)
  SELECT t.ticket_id
    INTO v_waitlist_ticket
    FROM Ticket t
   WHERE t.class_id = p_class_id
     AND t.booking_status IN ('WL', 'RAC')
     -- Possibly filter by train_id if you store it in the ticket or a linked table
   ORDER BY t.ticket_id ASC
   LIMIT 1;
  
  IF v_waitlist_ticket IS NOT NULL THEN
    UPDATE Ticket
       SET booking_status = 'Confirmed'
     WHERE ticket_id = v_waitlist_ticket;
    
    UPDATE Offers
       SET available_seats = available_seats - 1
     WHERE train_id = p_train_id
       AND class_id = p_class_id;
  END IF;

END$$

DELIMITER ;


--Prints out or returns an itemized summary for a booking or ticket.
DELIMITER $$

CREATE PROCEDURE sp_generate_invoice(
  IN p_booking_id INT
)
BEGIN
  -- Example: We'll return a result set with relevant info
  SELECT 
    b.booking_id,
    b.booking_type,
    b.booking_date,
    b.total_amount,
    b.booking_status,
    t.ticket_id,
    t.pnr_number,
    t.journey_date,
    t.booking_status AS ticket_status,
    t.fare_amount,
    c.customer_name,
    c.customer_email
  FROM Booking b
  JOIN Booking_Ticket bt ON b.booking_id = bt.booking_id
  JOIN Ticket t ON bt.ticket_id = t.ticket_id
  JOIN Customer_Ticket ct ON ct.ticket_id = t.ticket_id
  JOIN Customer c ON c.customer_id = ct.customer_id
  WHERE b.booking_id = p_booking_id;
END$$

DELIMITER ;


--Finds trains between two stations.

DELIMITER $$

CREATE PROCEDURE sp_search_trains_by_route(
  IN p_source_station VARCHAR(50),
  IN p_destination_station VARCHAR(50)
)
BEGIN
  /*
    This approach assumes we can match Train_Routes or Station_Connects
    from source_station to destination_station. 
    Simplified logic: search in Train_Routes first.
  */
  SELECT 
    tr.route_id,
    tr.source_station,
    tr.destination_station,
    tr.distance,
    s.schedule_id,
    t.train_id,
    t.train_name,
    t.train_number,
    t.operating_days
  FROM Train_Routes tr
  JOIN Schedule s      ON tr.route_id = s.route_id
  JOIN Train t         ON s.train_id = t.train_id
  WHERE tr.source_station = p_source_station
    AND tr.destination_station = p_destination_station;
END$$

DELIMITER ;


--Creates a new route and populates station connects, then links with a train.

DELIMITER $$

CREATE PROCEDURE sp_add_train_route(
  IN p_train_id INT,
  IN p_source_station VARCHAR(50),
  IN p_destination_station VARCHAR(50),
  IN p_distance INT,
  IN p_station_list TEXT  -- or JSON, e.g. station:sequence:distance
)
BEGIN
  DECLARE v_route_id INT;
  
  -- 1) Create route
  INSERT INTO Train_Routes (source_station, destination_station, distance)
  VALUES (p_source_station, p_destination_station, p_distance);
  SET v_route_id = LAST_INSERT_ID();
  
  -- 2) For simplicity, skip parsing station_list. 
  --    In real usage, you'd parse p_station_list, then insert each row in Station_Connects.
  
  -- 3) Link route to train in Schedule
  INSERT INTO Schedule (train_id, route_id)
  VALUES (p_train_id, v_route_id);
  
  SELECT v_route_id AS NewRouteID;
END$$

DELIMITER ;


--Given a ticket or PNR, returns train info, passengers, seats, etc.

DELIMITER $$

CREATE PROCEDURE sp_print_ticket_details(
  IN p_ticket_id INT
)
BEGIN
  SELECT 
    t.ticket_id,
    t.pnr_number,
    t.journey_date,
    t.booking_status AS ticket_status,
    t.fare_amount,
    cl.class_name,
    cl.class_code,
    tp.passenger_id,
    p.passenger_name,
    tp.seat_number,
    tp.booking_status AS passenger_status,
    tr.train_name,
    tr.train_number
  FROM Ticket t
  JOIN Class cl ON t.class_id = cl.class_id
  JOIN Ticket_Passenger tp ON t.ticket_id = tp.ticket_id
  JOIN Passenger p ON tp.passenger_id = p.passenger_id
  -- Potentially need to link to train_id:
  JOIN Schedule sc ON sc.schedule_id = (
       SELECT s.schedule_id 
         FROM Schedule s
         JOIN Train_Routes r ON r.route_id = s.route_id
         -- This is schema-dependent; adapt to how you link ticket->train
         LIMIT 1
  )
  JOIN Train tr ON tr.train_id = sc.train_id
  WHERE t.ticket_id = p_ticket_id;
END$$

DELIMITER ;


--Aggregates total paid amounts by class for a given date range.

DELIMITER $$

CREATE PROCEDURE sp_generate_revenue_report_by_class(
  IN p_start_date DATE,
  IN p_end_date DATE
)
BEGIN
  SELECT 
    cl.class_name,
    SUM(pm.payment_amount) AS total_revenue
  FROM Payment pm
  JOIN Booking bk ON pm.booking_id = bk.booking_id
  JOIN Booking_Ticket bt ON bk.booking_id = bt.booking_id
  JOIN Ticket t ON bt.ticket_id = t.ticket_id
  JOIN Class cl ON t.class_id = cl.class_id
  WHERE pm.payment_date BETWEEN p_start_date AND p_end_date
    AND pm.transaction_status = 'Success'
  GROUP BY cl.class_name
  ORDER BY total_revenue DESC;
END$$

DELIMITER ;


--Specifically moves RAC passengers to Confirmed.

DELIMITER $$

CREATE PROCEDURE sp_promote_RAC_to_confirmed(
  IN p_train_id INT,
  IN p_class_id INT
)
BEGIN
  DECLARE v_seats INT DEFAULT 0;
  DECLARE v_ticket_id INT;
  
  SELECT available_seats 
    INTO v_seats
    FROM Offers
   WHERE train_id = p_train_id
     AND class_id = p_class_id;
     
  IF v_seats <= 0 THEN
    LEAVE sp_promote_RAC_to_confirmed;
  END IF;
  
  -- Example: find one ticket that is in RAC
  SELECT ticket_id
    INTO v_ticket_id
    FROM Ticket
   WHERE booking_status = 'RAC'
     AND class_id = p_class_id
   LIMIT 1;
   
  IF v_ticket_id IS NOT NULL THEN
    UPDATE Ticket
       SET booking_status = 'Confirmed'
     WHERE ticket_id = v_ticket_id;
    
    UPDATE Offers
       SET available_seats = available_seats - 1
     WHERE train_id = p_train_id
       AND class_id = p_class_id;
  END IF;
  
END$$

DELIMITER ;


--Utility procedure to insert multiple stations at once.

DELIMITER $$

CREATE PROCEDURE sp_bulk_add_stations(
  IN p_station_list TEXT
)
BEGIN
  -- This is a simple approach that splits on semicolons for example:
  -- e.g. "Mumbai Central,BCT,Mumbai,Maharashtra;Delhi,NDLS,Delhi,Delhi"
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_entry TEXT;
  DECLARE v_curpos INT DEFAULT 1;
  
  CREATE TEMPORARY TABLE tmp_stations (
    station_name VARCHAR(100),
    station_code VARCHAR(10),
    city VARCHAR(50),
    state VARCHAR(50)
  );
  
  label1: LOOP
    IF v_curpos > LENGTH(p_station_list) THEN
      LEAVE label1;
    END IF;
    
    SET v_entry = SUBSTRING_INDEX(SUBSTRING(p_station_list, v_curpos), ';', 1);
    
    INSERT INTO tmp_stations (station_name, station_code, city, state)
    SELECT 
      SUBSTRING_INDEX(v_entry, ',', 1),
      SUBSTRING_INDEX(SUBSTRING_INDEX(v_entry, ',', 2), ',', -1),
      SUBSTRING_INDEX(SUBSTRING_INDEX(v_entry, ',', 3), ',', -1),
      SUBSTRING_INDEX(SUBSTRING_INDEX(v_entry, ',', 4), ',', -1);
      
    SET v_curpos = v_curpos + LENGTH(v_entry) + 1;
  END LOOP;
  
  -- Now insert from tmp_stations into Station
  INSERT INTO Station (station_name, station_code, city, state)
  SELECT station_name, station_code, city, state
  FROM tmp_stations;
  
  DROP TABLE tmp_stations;
  
END$$

DELIMITER ;


--2. USER-DEFINED FUNCTIONS

--Calculates final fare from distance, class multiplier, and concession.

DELIMITER $$

CREATE FUNCTION fn_calculate_fare(
  p_distance INT,
  p_class_id INT,
  p_concession_category VARCHAR(50)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
  DECLARE v_multiplier DECIMAL(5,2);
  DECLARE v_base_fare DECIMAL(10,2);
  DECLARE v_discount DECIMAL(5,2) DEFAULT 0;
  DECLARE v_final DECIMAL(10,2);
  
  -- Suppose base fare is 1.0 per km
  SET v_base_fare = p_distance * 1.0;
  
  SELECT base_fare_multiplier
    INTO v_multiplier
    FROM Class
   WHERE class_id = p_class_id;
   
  SET v_final = v_base_fare * v_multiplier;
  
  -- Apply a discount for certain concession categories
  IF p_concession_category = 'Senior' THEN
    SET v_discount = 0.4;  -- 40% discount example
  ELSEIF p_concession_category = 'Student' THEN
    SET v_discount = 0.2;  -- 20% discount
  END IF;
  
  SET v_final = v_final * (1 - v_discount);
  
  RETURN v_final;
END$$

DELIMITER ;


--Returns how many seats are available for a train/class/date.

DELIMITER $$

CREATE FUNCTION fn_seat_availability(
  p_train_id INT,
  p_class_id INT,
  p_journey_date DATE
)
RETURNS INT
DETERMINISTIC
BEGIN
  DECLARE v_seats INT DEFAULT 0;
  
  -- For simplicity, ignore the date dimension and just return Offers.available_seats
  SELECT available_seats
    INTO v_seats
    FROM Offers
   WHERE train_id = p_train_id
     AND class_id = p_class_id;
  
  RETURN v_seats;
END$$

DELIMITER ;


--Translates an integer age into a textual category.

DELIMITER $$

CREATE FUNCTION fn_get_passenger_age_category(
  p_age INT
)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
  IF p_age < 12 THEN
    RETURN 'Child';
  ELSEIF p_age >= 60 THEN
    RETURN 'Senior';
  ELSE
    RETURN 'Adult';
  END IF;
END$$

DELIMITER ;


--Looks up station distances from a route and returns the difference.

DELIMITER $$

CREATE FUNCTION fn_get_distance_between_stations(
  p_route_id INT,
  p_station_id_start INT,
  p_station_id_end INT
)
RETURNS INT
DETERMINISTIC
BEGIN
  DECLARE v_start_dist INT DEFAULT 0;
  DECLARE v_end_dist INT DEFAULT 0;
  
  SELECT distance_from_source
    INTO v_start_dist
    FROM Station_Connects
   WHERE route_id = p_route_id
     AND station_id = p_station_id_start;
     
  SELECT distance_from_source
    INTO v_end_dist
    FROM Station_Connects
   WHERE route_id = p_route_id
     AND station_id = p_station_id_end;
     
  RETURN ABS(v_end_dist - v_start_dist);
END$$

DELIMITER ;


--Counts how many passengers are linked to a given ticket.

DELIMITER $$

CREATE FUNCTION fn_get_total_passengers_on_ticket(
  p_ticket_id INT
)
RETURNS INT
DETERMINISTIC
BEGIN
  DECLARE v_count INT;
  
  SELECT COUNT(*)
    INTO v_count
    FROM Ticket_Passenger
   WHERE ticket_id = p_ticket_id;
   
  RETURN v_count;
END$$

DELIMITER ;


--Converts a code like "Mon,Wed,Fri" into a more user-friendly string (example).

DELIMITER $$

CREATE FUNCTION fn_format_operating_days(
  p_days VARCHAR(50)
)
RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
  -- For demonstration, we just return the original. 
  -- Real logic might parse abbreviations and expand them.
  RETURN CONCAT('Operating on: ', p_days);
END$$

DELIMITER ;


--3. TRIGGERS

--When a ticket or passenger is inserted/updated to “Confirmed,” reduce seat availability.


DELIMITER $$

CREATE TRIGGER trg_decrement_seats_on_confirm
AFTER INSERT
ON Ticket
FOR EACH ROW
BEGIN
  IF NEW.booking_status = 'Confirmed' THEN
    UPDATE Offers
       SET available_seats = available_seats - 1
     WHERE class_id = NEW.class_id
       -- Possibly need train_id from somewhere else
       -- e.g., if you store train_id in Ticket or link it via Schedule
       -- We'll assume you have a `train_id` column in Ticket for this demonstration
       AND train_id = (SELECT train_id FROM Ticket WHERE ticket_id = NEW.ticket_id LIMIT 1);
  END IF;
END$$

DELIMITER ;


--When a ticket status changes from “Confirmed” to “Cancelled,” free up seats.

DELIMITER $$

CREATE TRIGGER trg_increment_seats_on_cancel
AFTER UPDATE
ON Ticket
FOR EACH ROW
BEGIN
  IF OLD.booking_status = 'Confirmed' 
     AND NEW.booking_status = 'Cancelled' THEN
    UPDATE Offers
       SET available_seats = available_seats + 1
     WHERE class_id = NEW.class_id
       -- again referencing how to get train_id 
       AND train_id = (SELECT train_id FROM Ticket WHERE ticket_id = NEW.ticket_id LIMIT 1);
  END IF;
END$$

DELIMITER ;


--Automatically fills payment_date if none given.

DELIMITER $$

CREATE TRIGGER trg_insert_payment_timestamp
BEFORE INSERT
ON Payment
FOR EACH ROW
BEGIN
  IF NEW.payment_date IS NULL THEN
    SET NEW.payment_date = CURRENT_TIMESTAMP();
  END IF;
END$$

DELIMITER ;


--When a booking or ticket is cancelled, automatically fill in refund_amount in Payment.

DELIMITER $$

CREATE TRIGGER trg_auto_compute_refund
AFTER UPDATE
ON Booking
FOR EACH ROW
BEGIN
  IF OLD.booking_status <> 'Cancelled'
     AND NEW.booking_status = 'Cancelled' THEN
    -- Simple approach: refund entire payment_amount
    UPDATE Payment
       SET refund_amount = payment_amount,
           refund_date = CURRENT_TIMESTAMP()
     WHERE booking_id = NEW.booking_id
       AND refund_amount = 0;
  END IF;
END$$

DELIMITER ;


--Generates a PNR if none is provided.

DELIMITER $$

CREATE TRIGGER trg_auto_generate_pnr
BEFORE INSERT
ON Ticket
FOR EACH ROW
BEGIN
  IF NEW.pnr_number IS NULL OR NEW.pnr_number = '' THEN
    SET NEW.pnr_number = CONCAT('PNR', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), LPAD(NEW.ticket_id, 3, '0'));
  END IF;
END$$

DELIMITER ;


--Prevents inserting a new ticket if seats are not available.

DELIMITER $$

CREATE TRIGGER trg_validate_seat_availability
BEFORE INSERT
ON Ticket
FOR EACH ROW
BEGIN
  DECLARE v_seats INT;
  
  IF NEW.booking_status = 'Confirmed' THEN
    SELECT available_seats 
      INTO v_seats
      FROM Offers
     WHERE class_id = NEW.class_id
       -- again referencing train_id
       AND train_id = (SELECT train_id FROM Schedule LIMIT 1);
       -- Simplify: adapt to your table structure
       
    IF v_seats <= 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No seats available for this class.';
    END IF;
  END IF;
END$$

DELIMITER ;


--Recalculate Booking.total_amount whenever you add/remove a ticket in Booking_Ticket.

DELIMITER $$

CREATE TRIGGER trg_update_booking_total
AFTER INSERT
ON Booking_Ticket
FOR EACH ROW
BEGIN
  DECLARE v_sum DECIMAL(10,2);
  
  SELECT SUM(t.fare_amount)
    INTO v_sum
    FROM Booking_Ticket bt
    JOIN Ticket t ON bt.ticket_id = t.ticket_id
   WHERE bt.booking_id = NEW.booking_id;
   
  UPDATE Booking
     SET total_amount = IFNULL(v_sum, 0)
   WHERE booking_id = NEW.booking_id;
END$$

DELIMITER ;


--Logs changes to Payment in a separate audit table.

-- First, create an audit table
CREATE TABLE IF NOT EXISTS Payment_Audit (
  audit_id INT AUTO_INCREMENT PRIMARY KEY,
  payment_id INT,
  old_payment_amount DECIMAL(10,2),
  new_payment_amount DECIMAL(10,2),
  old_status VARCHAR(20),
  new_status VARCHAR(20),
  change_timestamp DATETIME
);

DELIMITER $$

CREATE TRIGGER trg_audit_payment_changes
AFTER UPDATE
ON Payment
FOR EACH ROW
BEGIN
  INSERT INTO Payment_Audit(
    payment_id,
    old_payment_amount,
    new_payment_amount,
    old_status,
    new_status,
    change_timestamp
  ) VALUES (
    OLD.payment_id,
    OLD.payment_amount,
    NEW.payment_amount,
    OLD.transaction_status,
    NEW.transaction_status,
    NOW()
  );
END$$

DELIMITER ;


--Prevents booking with a suspiciously old or invalid date.

DELIMITER $$

CREATE TRIGGER trg_block_future_backdate_booking
BEFORE INSERT
ON Booking
FOR EACH ROW
BEGIN
  IF NEW.booking_date < (CURRENT_TIMESTAMP() - INTERVAL 365 DAY) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Booking date is too far in the past.';
  END IF;
END$$

DELIMITER ;
-----------


-- --1. Trigger to Decrement Seat Availability in Offers (When Ticket is Confirmed)

-- DELIMITER $$

-- CREATE TRIGGER trg_decrement_seats_on_ticket_confirm
-- AFTER INSERT
-- ON Ticket
-- FOR EACH ROW
-- BEGIN
--   IF NEW.booking_status = 'Confirmed' THEN
--     UPDATE Offers
--        SET available_seats = available_seats - 1
--      WHERE train_id = NEW.train_id
--        AND class_id = NEW.class_id;
       
--     -- Optionally also update Reserved_On if you assign a specific seat
--     -- e.g., mark it 'Booked'
--   END IF;
-- END$$

-- DELIMITER ;


-- --2. Trigger to Free Seat on Ticket Cancellation

-- DELIMITER $$

-- CREATE TRIGGER trg_increment_seats_on_cancel
-- AFTER UPDATE
-- ON Ticket
-- FOR EACH ROW
-- BEGIN
--   IF OLD.booking_status = 'Confirmed'
--      AND NEW.booking_status = 'Cancelled' THEN
--     UPDATE Offers
--        SET available_seats = available_seats + 1
--      WHERE train_id = NEW.train_id
--        AND class_id = NEW.class_id;
    
--     -- Also call your procedure to do chain promotions from RAC -> Confirmed, WL -> RAC
--     CALL sp_chain_promotions(NEW.train_id, NEW.class_id);
--   END IF;
-- END$$

-- DELIMITER ;


-- --1. sp_chain_promotions (Waitlist/RAC → Confirmed)

-- DELIMITER $$

-- CREATE PROCEDURE sp_chain_promotions(
--   IN p_train_id INT,
--   IN p_class_id INT
-- )
-- BEGIN
--   DECLARE v_avail INT;
--   DECLARE v_rac_ticket INT;
--   DECLARE done INT DEFAULT 0;
  
--   promotion_loop: LOOP
--     -- Check how many seats are available
--     SELECT available_seats INTO v_avail
--       FROM Offers
--      WHERE train_id = p_train_id
--        AND class_id = p_class_id
--      LIMIT 1;
     
--     IF v_avail <= 0 THEN
--       LEAVE promotion_loop; -- No seats left to promote
--     END IF;
    
--     -- Find earliest RAC ticket
--     SELECT ticket_id
--       INTO v_rac_ticket
--       FROM Ticket
--      WHERE train_id = p_train_id
--        AND class_id = p_class_id
--        AND booking_status = 'RAC'
--      ORDER BY request_time ASC
--      LIMIT 1;
     
--     IF v_rac_ticket IS NULL THEN
--       LEAVE promotion_loop; -- no RAC tickets left
--     END IF;
    
--     -- Promote to Confirmed
--     UPDATE Ticket
--        SET booking_status = 'Confirmed'
--      WHERE ticket_id = v_rac_ticket;
    
--     UPDATE Offers
--        SET available_seats = available_seats - 1
--      WHERE train_id = p_train_id
--        AND class_id = p_class_id;
     
--   END LOOP promotion_loop;
  
--   -- Next, if you want WL → RAC, do a smaller step:
--   UPDATE Ticket
--      SET booking_status = 'RAC'
--    WHERE ticket_id = (
--     SELECT ticket_id
--       FROM Ticket
--      WHERE train_id = p_train_id
--        AND class_id = p_class_id
--        AND booking_status = 'WL'
--      ORDER BY request_time ASC
--      LIMIT 1
--    )
--    LIMIT 1;
-- END$$

-- DELIMITER ;


-- --Goal: Show how to create a booking, ticket, and also link Customer → Ticket via Customer_Ticket.

-- DELIMITER $$

-- CREATE PROCEDURE sp_create_booking_with_customer_ticket(
--   IN p_customer_id INT,
--   IN p_train_id INT,
--   IN p_class_id INT,
--   IN p_journey_date DATE,
--   IN p_fare DECIMAL(10,2)
-- )
-- BEGIN
--   DECLARE v_booking_id INT;
--   DECLARE v_ticket_id INT;
  
--   -- 1) Insert into Booking
--   INSERT INTO Booking (booking_type, booking_date, total_amount, booking_status)
--   VALUES ('Online', NOW(), p_fare, 'Confirmed');
--   SET v_booking_id = LAST_INSERT_ID();
  
--   -- 2) Insert into Ticket
--   INSERT INTO Ticket (pnr_number, journey_date, booking_status, fare_amount, class_id, train_id, request_time)
--   VALUES (NULL, p_journey_date, 'Confirmed', p_fare, p_class_id, p_train_id, NOW());
--   SET v_ticket_id = LAST_INSERT_ID();
  
--   -- 3) Link booking & ticket
--   INSERT INTO Booking_Ticket (booking_id, ticket_id)
--   VALUES (v_booking_id, v_ticket_id);
  
--   -- 4) Link customer & ticket
--   INSERT INTO Customer_Ticket (customer_id, ticket_id, booking_date)
--   VALUES (p_customer_id, v_ticket_id, NOW());
  
--   -- 5) Payment can be inserted as well
--   INSERT INTO Payment (booking_id, payment_date, payment_amount, payment_mode, transaction_status)
--   VALUES (v_booking_id, NOW(), p_fare, 'Card', 'Success');
  
--   INSERT INTO Pays (customer_id, payment_id)
--   VALUES (p_customer_id, LAST_INSERT_ID());
  
--   -- 6) Adjust seat availability in Offers
--   UPDATE Offers
--      SET available_seats = available_seats - 1
--    WHERE train_id = p_train_id
--      AND class_id = p_class_id;
  
--   SELECT v_booking_id AS booking_id, v_ticket_id AS ticket_id;
-- END$$

-- DELIMITER ;


-- --Goal: Return one free seat (coach+seat_number) for a given train/class, if available.

-- DELIMITER $$

-- CREATE FUNCTION fn_find_free_seat_in_reserved_on(
--   p_train_id INT,
--   p_class_id INT
-- )
-- RETURNS VARCHAR(20)
-- DETERMINISTIC
-- BEGIN
--   DECLARE v_seat_info VARCHAR(20);

--   SELECT CONCAT(coach_number, '-', seat_number)
--     INTO v_seat_info
--     FROM Reserved_On
--    WHERE train_id = p_train_id
--      AND class_id = p_class_id
--      AND availability_status = 'Available'
--    LIMIT 1;
   
--   RETURN v_seat_info;  -- Might be NULL if no seat is available
-- END$$

-- DELIMITER ;


-- --Goal: Count how many bookings a customer has made (via bridging tables).

-- DELIMITER $$

-- CREATE FUNCTION fn_get_customer_booking_count(
--   p_customer_id INT
-- )
-- RETURNS INT
-- DETERMINISTIC
-- BEGIN
--   DECLARE v_count INT DEFAULT 0;
  
--   SELECT COUNT(DISTINCT b.booking_id)
--     INTO v_count
--     FROM Customer_Ticket ct
--     JOIN Ticket t         ON ct.ticket_id = t.ticket_id
--     JOIN Booking_Ticket bt ON t.ticket_id = bt.ticket_id
--     JOIN Booking b         ON bt.booking_id = b.booking_id
--    WHERE ct.customer_id = p_customer_id;
   
--   RETURN v_count;
-- END$$

-- DELIMITER ;