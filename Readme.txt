Indian Railway Ticket Reservation System

Prerequisites & Environment

RDBMS: MySQL 8 (or higher).

SQL Client: MySQL Shell, MySQL Workbench, phpMyAdmin, or any MySQL-compatible client.

Operating System: Any OS that can run MySQL (Windows, Linux, macOS).

User Privileges: Must have CREATE, INSERT, UPDATE, DELETE, and EXECUTE privileges to create schemas, tables, procedures, triggers, etc.

Cloning / Copying the Project Files

schema_18_tables.sql (contains CREATE TABLE statements for all 18 tables)

procedures_functions_triggers.sql (contains CREATE PROCEDURE, CREATE FUNCTION, CREATE TRIGGER statements)

populate_data.sql (contains INSERT statements to populate all tables)

(Optional) A PDF or LaTeX report with full documentation

Creating the Database and Tables

Start your MySQL server and open a client or IDE.

Create the project database: CREATE DATABASE IF NOT EXISTS RailwayDB; USE RailwayDB;

Run the schema file: SOURCE /path/to/schema_18_tables.sql;

This will create Train, Train_Routes, Schedule, Station, Station_Connects, Class, Passenger, Customer, Ticket, Booking, Payment, Reserved_On, Stops_At, Ticket_Passenger, Customer_Ticket, Booking_Ticket, Offers, and Pays.

Installing Stored Procedures, Functions, and Triggers

Ensure you are in the same database: USE RailwayDB;

Run: SOURCE /path/to/procedures_functions_triggers.sql;

Verify success: SHOW PROCEDURE STATUS WHERE Db='RailwayDB'; SHOW TRIGGERS;

Populating the Database

Run the data-insertion script: SOURCE /path/to/populate_data.sql;

This script will INSERT rows into all tables (Customer, Passenger, Train, Class, Station, Train_Routes, Schedule, Offers, Booking, Ticket, Booking_Ticket, Payment, Pays, Station_Connects, Ticket_Passenger, Reserved_On, and so on).

Confirm each table is populated: SELECT COUNT() FROM Customer; SELECT COUNT() FROM Ticket; etc.

Testing the System

Calling a stored procedure: CALL sp_create_booking_with_customer_ticket(...);

Canceling a booking: CALL sp_cancel_booking(<booking_id>);

Promoting RAC and Waitlist: CALL sp_chain_promotions(<train_id>, <class_id>);

Running queries: SELECT ... FROM Ticket WHERE pnr_number = 'PNR1234565'; SELECT ... FROM Offers WHERE train_id = 201 AND class_id = 302;

Checking triggers:

Insert a new Ticket with booking_status='Confirmed' -> seat availability decrements automatically.

Update Ticket from 'Confirmed' to 'Cancelled' -> seat availability increments, partial refund logic triggers, etc.

Common Issues and Solutions

Duplicate routine names: DROP or rename old procedures/triggers if they conflict with new ones.

Foreign key constraints: Insert data in the right order, or temporarily disable constraints with SET FOREIGN_KEY_CHECKS=0; if necessary.

Permission errors: Ensure your MySQL user has privileges for procedures, triggers, functions, etc.

Conclusion

You now have a fully functional Indian Railway Ticket Reservation System in MySQL with all 18 tables, sample data, stored routines, triggers, and queries.

For detailed information on usage, logic flows, and extended capabilities, refer to the main documentation or LaTeX/PDF report.