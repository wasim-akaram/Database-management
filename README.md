# Bank Account Management System  

## Domain  
Banking  

## Project Description  
The Bank Account Management System is a PL/SQL-driven application that simulates  
core banking operations such as customer creation, account handling, deposits,  
withdrawals, and transaction logging with full validation and exception handling.  

## Features  
- Customer creation  
- Bank account creation  
- Deposit money  
- Withdraw money  
- Balance inquiry  
- Transaction history  
- Insufficient balance handling  
- Account status validation  

## Database Tables  
- customers  
- accounts  
- transactions  
 
## PL/SQL Concepts Used  
- Stored Procedures (deposit, withdraw, customer creation)  
- Functions (balance inquiry)  
- Triggers (transaction notification and validation)  
- Cursors (transaction history)  
- Exception handling  
- Sequences  
- Constraints  

## System Requirements  
- Oracle Database XE 21c  
- Oracle SQL Developer  
- Windows OS  

## How to Run  
1. Connect to Oracle Database using SQL Developer  
2. Execute table and sequence scripts  
3. Compile procedures, functions, and triggers  
4. Insert test customers and accounts  
5. Perform deposit and withdrawal operations  

## Sample Operations  
- Deposit money into a n account  
- Withdraw money with balance validation 
- Check balance using function  
- View transaction history using cursor  

## Use Case  
This system models real-world banking operations and is suitable for academic projects and practical examinations.  

## Author  
Wasim Akaram  



# Inventory & Stock Management System  

## Domain  
Retail / Warehouse  

## Project Description  
The Inventory & Stock Management System is a PL/SQL-based application designed to manage products,   
suppliers, and stock movement in a retail or warehouse environment. It automates stock updates,   
maintains transaction history, and provides alerts for low stock conditions.  

## Features  
- Product entry and management  
- Stock in and stock out operations  
- Automatic stock update  
- Low stock alert  
- Supplier-wise stock tracking  
- Sales and stock transaction record  
- Error handling for insufficient stock  

## Database Tables  
- products  
- suppliers  
- stock_transactions  

## PL/SQL Concepts Used  
- Stored Procedures (stock in, stock out)  
- Functions (check available stock)  
- Triggers (automatic stock update and low-stock alert)  
- Cursors (low-stock report)  
- Exception handling  
- Sequences  

## System Requirements  
- Oracle Database XE 21c  
- Oracle SQL Developer  
- Windows OS  
 
## How to Run  
1. Open Oracle SQL Developer  
2. Create a database connection  
3. Run table creation scripts  
4. Create sequences  
5. Compile procedures, functions, triggers  
6. Insert sample data  
7. Execute procedures to test stock operations  

## Sample Operations  
- Add stock using stock_in procedure  
- Reduce stock using stock_out procedure  
- View low stock report using cursor  
- Check available stock using function  

## Use Case  
This system is suitable for small retail shops, warehouses, and inventory-based institutions.  

## Author  
Wasim Akaram  

