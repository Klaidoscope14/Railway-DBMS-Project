--Goal: Given a PNR number, retrieve ticket status, route/station details, and passenger info – referencing bridging tables where needed.

SELECT
  t.ticket_id,
  t.pnr_number,
  t.booking_status AS ticket_status,
  t.journey_date,
  -- Subquery #1: Class name from Class table
  (SELECT c.class_name 
     FROM Class c
    WHERE c.class_id = t.class_id
    LIMIT 1
  ) AS class_name,
  -- Subquery #2: Train name
  (SELECT tr.train_name
     FROM Train tr
    WHERE tr.train_id = t.train_id
    LIMIT 1
  ) AS train_name,
  -- Subquery #3: All passenger names + seat_number for this ticket
  (
    SELECT GROUP_CONCAT(CONCAT(p.passenger_name, ' (Seat: ', tp.seat_number, ')')
                        SEPARATOR '; ')
      FROM Ticket_Passenger tp
      JOIN Passenger p ON tp.passenger_id = p.passenger_id
     WHERE tp.ticket_id = t.ticket_id
  ) AS passenger_details
FROM Ticket t
WHERE t.pnr_number = :pnrNumber;


--Goal: Given a train number, list stations (in order) with arrival/departure times from Stops_At, also referencing the route from Train_Routes via Schedule.

SELECT 
  sa.train_id,
  tr.train_name,
  tr.train_number,
  st.station_name,
  st.station_code,
  sa.day_of_journey,
  sa.arrival_time,
  sa.departure_time,
  -- Subquery #1: route name from Train_Routes via Schedule
  (
    SELECT r.route_name
      FROM Schedule sch
      JOIN Train_Routes r ON sch.route_id = r.route_id
     WHERE sch.train_id = sa.train_id
     LIMIT 1
  ) AS route_name
FROM Stops_At sa
JOIN Train tr    ON sa.train_id   = tr.train_id
JOIN Station st  ON sa.station_id = st.station_id
WHERE tr.train_number = :trainNumber
ORDER BY sa.day_of_journey, sa.arrival_time;


--Goal: For a given train, date, and class, check seat availability. We can reference both Offers for total seats and Reserved_On for seat-level details.

SELECT
  o.train_id,
  t.train_name,
  o.class_id,
  c.class_name,
  o.available_seats,
  -- Subquery #1: how many seats are physically in Reserved_On for that class/coach
  (
    SELECT COUNT(*)
      FROM Reserved_On ro
     WHERE ro.train_id = o.train_id
       AND ro.class_id = o.class_id
  ) AS total_physical_seats,
  CASE WHEN o.available_seats > 0 THEN 'Seats Available'
       ELSE 'Fully Booked' END AS seat_status
FROM Offers o
JOIN Train t ON o.train_id = t.train_id
JOIN Class c ON o.class_id = c.class_id
WHERE o.train_id = :trainId
  AND o.class_id = :classId
  -- If you also store date-specific availability, you'd join or filter by the date.
;


--Goal: Given (train_id, journey_date), list all passengers (name, seat) plus bridging references to Booking or Customer_Ticket if needed.

SELECT 
  p.passenger_name,
  tp.seat_number,
  tp.passenger_status,
  t.ticket_id,
  t.pnr_number,
  t.booking_status,
  b.booking_id,
  -- Subquery: check if there's a direct link from Customer_Ticket to this ticket
  (
    SELECT GROUP_CONCAT(c.customer_name SEPARATOR ', ')
      FROM Customer_Ticket ct
      JOIN Customer c ON ct.customer_id = c.customer_id
     WHERE ct.ticket_id = t.ticket_id
  ) AS buyers
FROM Ticket t
JOIN Ticket_Passenger tp ON t.ticket_id = tp.ticket_id
JOIN Passenger p        ON tp.passenger_id = p.passenger_id
JOIN Booking_Ticket bt ON t.ticket_id = bt.ticket_id
JOIN Booking b         ON bt.booking_id = b.booking_id
WHERE t.train_id       = :trainId
  AND t.journey_date   = :journeyDate
  AND t.booking_status IN ('Confirmed','RAC','WL')
ORDER BY p.passenger_name;


--SELECT
  t.ticket_id,
  t.pnr_number,
  t.booking_status AS main_status,
  GROUP_CONCAT(p.passenger_name SEPARATOR ', ') AS passenger_list,
  t.journey_date,
  c.class_name,
  tr.train_name
FROM Ticket t
JOIN Ticket_Passenger tp ON t.ticket_id = tp.ticket_id
JOIN Passenger p        ON tp.passenger_id = p.passenger_id
JOIN Class c            ON t.class_id = c.class_id
JOIN Train tr           ON t.train_id = tr.train_id
WHERE t.booking_status IN ('WL','RAC')
  AND t.train_id = :trainId
  AND t.class_id = :classId
  AND t.journey_date = :journeyDate
GROUP BY t.ticket_id, t.pnr_number, t.booking_status, t.journey_date,
         c.class_name, tr.train_name;


--5. Retrieve Waitlisted/RAC Passengers

SELECT
  t.ticket_id,
  t.pnr_number,
  t.booking_status AS main_status,
  GROUP_CONCAT(p.passenger_name SEPARATOR ', ') AS passenger_list,
  t.journey_date,
  c.class_name,
  tr.train_name
FROM Ticket t
JOIN Ticket_Passenger tp ON t.ticket_id = tp.ticket_id
JOIN Passenger p        ON tp.passenger_id = p.passenger_id
JOIN Class c            ON t.class_id = c.class_id
JOIN Train tr           ON t.train_id = tr.train_id
WHERE t.booking_status IN ('WL','RAC')
  AND t.train_id = :trainId
  AND t.class_id = :classId
  AND t.journey_date = :journeyDate
GROUP BY t.ticket_id, t.pnr_number, t.booking_status, t.journey_date,
         c.class_name, tr.train_name;


--6. Total Refund Amount for Cancelling a Train

SELECT
  SUM(pm.refund_amount) AS total_refund
FROM Payment pm
JOIN Booking b           ON pm.booking_id = b.booking_id
JOIN Booking_Ticket bt  ON b.booking_id  = bt.booking_id
JOIN Ticket t           ON bt.ticket_id  = t.ticket_id
WHERE t.train_id = :trainId
  AND t.booking_status = 'Cancelled';


--7. Total Revenue Over a Period

SELECT
  COALESCE(SUM(pm.payment_amount - pm.refund_amount), 0) AS net_revenue
FROM Payment pm
JOIN Booking b          ON pm.booking_id = b.booking_id
WHERE pm.payment_date BETWEEN :startDate AND :endDate
  AND pm.transaction_status = 'Success';


--8. Cancellation Records with Refund Status

SELECT
  b.booking_id,
  b.booking_date,
  b.booking_status,
  t.ticket_id,
  t.pnr_number,
  t.booking_status AS ticket_status,
  pm.payment_id,
  pm.payment_amount,
  pm.refund_amount,
  pm.refund_date,
  pm.transaction_status
FROM Booking b
JOIN Booking_Ticket bt ON b.booking_id = bt.booking_id
JOIN Ticket t         ON bt.ticket_id = t.ticket_id
JOIN Payment pm       ON b.booking_id = pm.booking_id
WHERE b.booking_status = 'Cancelled'
   OR t.booking_status = 'Cancelled'
ORDER BY b.booking_date DESC;


--10. Itemized Bill for a Ticket

SELECT
  t.ticket_id,
  t.pnr_number,
  t.booking_status,
  t.fare_amount,
  c.class_name,
  tr.train_name,
  b.booking_id,
  b.booking_date,
  pm.payment_amount,
  pm.refund_amount,
  (pm.payment_amount - pm.refund_amount) AS net_paid,
  -- Subquery: gather passenger details
  (
    SELECT GROUP_CONCAT(CONCAT(p.passenger_name, ' (Seat: ', tp.seat_number, ')') SEPARATOR '; ')
      FROM Ticket_Passenger tp
      JOIN Passenger p ON tp.passenger_id = p.passenger_id
     WHERE tp.ticket_id = t.ticket_id
  ) AS passenger_list
FROM Ticket t
JOIN Class c         ON t.class_id = c.class_id
JOIN Train tr        ON t.train_id = tr.train_id
JOIN Booking_Ticket bt ON t.ticket_id = bt.ticket_id
JOIN Booking b       ON bt.booking_id = b.booking_id
JOIN Payment pm      ON b.booking_id = pm.booking_id
WHERE t.ticket_id = :ticketId;


--11. Extended Ideas (e.g., Frequent Travelers Using Customer_Ticket)

SELECT
  c.customer_id,
  c.customer_name,
  COUNT(ct.ticket_id) AS total_tickets_purchased
FROM Customer c
JOIN Customer_Ticket ct ON c.customer_id = ct.customer_id
-- Optionally filter by paid + successful bookings
JOIN Ticket t           ON ct.ticket_id = t.ticket_id
WHERE t.booking_status IN ('Confirmed','RAC','WL')
GROUP BY c.customer_id
ORDER BY total_tickets_purchased DESC
LIMIT 5;


--