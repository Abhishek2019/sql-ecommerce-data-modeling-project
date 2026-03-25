# SQL E-Commerce Data Modeling Project

This repository contains a SQL Server–based e-commerce data modeling project designed for reporting, analytics, and future application development. The project models core business entities such as customers, orders, products, payments, shipping, and order items, and includes reusable SQL objects like views, user-defined functions, stored procedures, and indexes.

The solution is based on a business scenario where an e-commerce company needs to answer key questions such as which products sell the most by category, which customers are repeat buyers, and which orders are delayed in shipment. The data model is normalized and structured to reduce redundancy, improve data quality, and support scalable query performance.

## Recommended Repository Name

`sql-ecommerce-data-modeling-project`

Other good options:

- `ecommerce-sql-data-model`
- `sql-server-ecommerce-project`
- `ecommerce-db-design-sql`
- `abc-ecommerce-sql-project`

## Project Objective

The main objective of this project is to design a well-structured relational database for an e-commerce business and implement SQL objects that support business reporting, operational validations, and performance optimization. The project includes:

- physical data modeling using SQL Server tables
- normalization of transactional entities
- reusable views for repeat customers and product sales summary
- scalar UDFs for order totals and customer order counts
- a stored procedure for placing customer orders with validations and calculations
- indexes to improve join, filter, and reporting performance

## Business Questions Addressed

This project helps answer the following questions:

- Which products sell the most by category?
- Which customers are repeat buyers?
- Which orders are delayed in shipment?

## Database Objects Included

### 1. Tables

The project includes the following main tables:

- `Customer`
- `Orders`
- `Product`
- `Shipping`
- `Order_Item`
- `Payment`

These tables capture customer details, order transactions, product information, payment records, and shipment tracking.

### 2. Views

#### `vw_RepeatCustomers`
Returns customers who have placed more than one order.

#### `vw_ProductSalesSummary`
Provides a reusable summary of product-level sales using total quantity sold and total revenue.

### 3. User-Defined Functions

#### `udf_GetOrderTotal(@order_id int)`
Returns the total value of a given order.

#### `udf_GetCustomerOrderCount(@customer_id int)`
Returns the total number of orders placed by a customer.

### 4. Stored Procedure

#### `sp_PlaceCustomerOrder`
A reusable procedure to place an order with:

- customer validation
- duplicate key validation
- JSON-based order item parsing
- product validation
- total amount calculation
- payment and shipping inserts
- transaction handling with `TRY...CATCH`
- rollback support for invalid transactions

This procedure centralizes business logic and improves consistency in order processing.

### 5. Indexing Strategy

The project also includes nonclustered and covering indexes to improve query performance for joins, filters, and reporting queries on `Orders`, `Shipping`, `Product`, and `Order_Item`.

## Suggested Repository Structure

```text
sql-ecommerce-data-modeling-project/
│
├── README.md
├── sql/
│   ├── 01_create_database_and_tables.sql
│   ├── 02_views.sql
│   ├── 03_udfs.sql
│   ├── 04_stored_procedures.sql
│   ├── 05_indexes.sql
│   └── 06_sample_queries.sql
└── docs/
    └── data-model-notes.md
