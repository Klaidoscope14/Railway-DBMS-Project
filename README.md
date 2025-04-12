# Indian Railway Ticket Reservation System

## 1. Prerequisites & Environment

- **RDBMS**: MySQL 8 (or higher)
- **SQL Client**: MySQL Shell, MySQL Workbench, phpMyAdmin, or any MySQL-compatible tool
- **Operating System**: Any OS that supports MySQL (Windows, Linux, macOS)
- **User Privileges**: Must have `CREATE`, `INSERT`, `UPDATE`, `DELETE`, and `EXECUTE` privileges for schema creation, table creation, and routine definition

## 2. Project Files

1. **schema_18_tables.sql**: Contains `CREATE TABLE` statements for all 18 tables
2. **procedures_functions_triggers.sql**: Contains `CREATE PROCEDURE`, `CREATE FUNCTION`, and `CREATE TRIGGER` statements
3. **populate_data.sql**: Contains `INSERT` statements to populate all tables with sample data
4. *(Optional)* A PDF or LaTeX report containing full project documentation

## 3. Creating the Database and Tables

1. Start the MySQL server and open your SQL client or IDE.
2. Create a new database (schema) and switch to it:
   ```sql
   CREATE DATABASE IF NOT EXISTS RailwayDB;
   USE RailwayDB;
   ```
3. Run the `schema_18_tables.sql` script to create the 18 tables:
   ```sql
   SOURCE /path/to/schema_18_tables.sql;
   ```
4. Verify that the tables (Train, Train_Routes, Schedule, Station, Station_Connects, Class, Passenger, Customer, Ticket, Booking, Payment, Reserved_On, Stops_At, Ticket_Passenger, Customer_Ticket, Booking_Ticket, Offers, Pays) have been created successfully.

## 4. Installing Stored Procedures, Functions, and Triggers

1. Ensure you’re still using the `RailwayDB` database:
   ```sql
   USE RailwayDB;
   ```
2. Run the `procedures_functions_triggers.sql` file:
   ```sql
   SOURCE /path/to/procedures_functions_triggers.sql;
   ```
3. Confirm the routines and triggers:
   ```sql
   SHOW PROCEDURE STATUS WHERE Db='RailwayDB';
   SHOW TRIGGERS;
   ```

## 5. Populating the Database

1. Run the `populate_data.sql` script to insert sample rows into all tables:
   ```sql
   SOURCE /path/to/populate_data.sql;
   ```
2. Check each table to confirm data insertion, for example:
   ```sql
   SELECT COUNT(*) FROM Customer;
   SELECT COUNT(*) FROM Ticket;
   ```
3. Tables populated: 
   - `Customer`, `Passenger`, `Train`, `Train_Routes`, `Schedule`, `Station`, `Station_Connects`, `Class`, `Offers`, `Booking`, `Ticket`, `Booking_Ticket`, `Payment`, `Pays`, `Ticket_Passenger`, `Reserved_On`, `Stops_At`

## 6. Testing & Usage

### 6.1 Stored Procedures

- **Example**: Creating a booking  
  ```sql
  CALL sp_create_booking_with_customer_ticket(
      /* arguments */
  );
  ```
- **Example**: Canceling a booking  
  ```sql
  CALL sp_cancel_booking(booking_id_value);
  ```
- **Example**: Promoting RAC & Waitlist  
  ```sql
  CALL sp_chain_promotions(train_id_value, class_id_value);
  ```

### 6.2 Queries & Triggers

- **PNR Status**:
  ```sql
  SELECT * 
    FROM Ticket 
   WHERE pnr_number = 'PNR1234565';
  ```
- **Available Seats**:
  ```sql
  SELECT * 
    FROM Offers 
   WHERE train_id = 201
     AND class_id = 302;
  ```
- **Triggers**: 
  - Inserting a ticket with `booking_status='Confirmed'` should decrement seat availability in `Offers`.  
  - Updating a ticket from `'Confirmed'` to `'Cancelled'` should increment seats and possibly trigger partial refund logic.

## 7. Common Troubleshooting

- **Duplicate routine names**: If you already have procedures or triggers with the same name, drop or rename them first.
- **Foreign key constraints**: Insert data in the correct order or temporarily disable constraints if necessary:
  ```sql
  SET FOREIGN_KEY_CHECKS=0;
  ... insert statements ...
  SET FOREIGN_KEY_CHECKS=1;
  ```
- **Insufficient privileges**: Make sure the MySQL user can create and execute procedures, triggers, and functions.

## 8. Conclusion

You now have a complete Indian Railway Ticket Reservation System in MySQL, with:

- An 18-table schema
- Stored procedures for booking and cancellation
- Triggers handling seat availability and refunds
- User-defined functions for various calculations

Refer to the project’s main documentation or PDF report for detailed explanations of logic flows, advanced seat assignments, partial refunds, eWallet usage, and more.