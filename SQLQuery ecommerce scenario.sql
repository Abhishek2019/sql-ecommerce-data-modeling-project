--create database scenario_ecommerce;

use scenario_ecommerce;

Create table Customer(
customer_id int primary key,
customer_name varchar(100) not null,
email varchar(100) not null check(email like '_%@_%._%'),
phone varchar(10) not null check(phone like '[1-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
);

Create table Orders(
Order_id int primary key,
Customer_id int foreign key references customer(customer_id),
Order_date date,
Status varchar(100) check(status in ('Pending', 'Confirmed', 'Shipped', 'Delivered', 'Cancelled'))
);


Create table Product(
Product_id int primary key,
Product_name varchar(100) not null,
category varchar(100) not null,
unit_price decimal(10,2) check(unit_price >=0)
);

Create table Shipping(
shipping_id int primary key,
order_id int foreign key references orders(order_id),
shipped_date date,
shipping_status varchar(100) check(shipping_status in ('Processing', 'Shipped', 'In Transit', 'Delivered', 'Delayed')),
delivery_date date
);

Create table Order_item(
product_id int foreign key references product(product_id),
order_id int foreign key references orders(order_id),
quantity int not null check(quantity > 0)

constraint pk_prod_order
primary key (order_id, product_id)
);

create table Payment (
payment_id int primary key,
order_id int not null unique,
payment_date date not null,
payment_status varchar(50) not null check (payment_status in ('Pending', 'Completed', 'Failed', 'Refunded')),
payment_method VARCHAR(50) not null check (payment_method in ('Credit Card', 'Debit Card', 'UPI', 'Net Banking', 'Cash')),
constraint fk_payment_order foreign key (order_id) references Orders(order_id)
);


-------------------------------------------------------------------------------------------------------

GO 
create OR alter procedure dbo.sp_PlaceCustomerOrder
(
    @order_id int,
    @customer_id int,
    @order_date date = NULL,
    @order_items_json nvarchar(MAX), 
    -- example:
    -- [{"product_id":1,"quantity":2},{"product_id":3,"quantity":1}]

    @payment_id int,
    @payment_method varchar(50),
    @payment_status varchar(50) = 'Completed',

    @shipping_id int,
    @shipping_status varchar(50) = 'Processing',
    @delivery_date date = NULL,

    @order_status varchar(50) = 'Confirmed'
)
as
begin
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    begin try
        begin transaction;

        declare @final_order_date date = isnull(@order_date, cast(getdate() AS DATE));
        declare @total_amount decimal(18,2);

        ------------------------------------------------------------
        -- validate customer
        ------------------------------------------------------------
        if not exists
        (
            select 1
            from Customer
            where customer_id = @customer_id
        )
        begin
            throw 50001, 'Customer does not exist.', 1;
        end;

        ------------------------------------------------------------
        -- validate duplicate keys
        ------------------------------------------------------------
        if exists
        (
            select 1
            from Orders
            where order_id = @order_id
        )
        begin
            throw 50002, 'Order ID already exists.', 1;
        end

        if exists        (
            select 1
            from Payment
            where payment_id = @payment_id
        )
        begin
            throw 50003, 'Payment ID already exists.', 1;
        end;

        if exists
        (
            select 1
            from Shipping
            where shipping_id = @shipping_id
        )
        begin
            throw 50004, 'Shipping ID already exists.', 1;
        end;


        ------------------------------------------------------------
        -- load JSON items
        ------------------------------------------------------------
        if object_id('tempdb..#OrderItems') IS NOT NULL
            DROP TABLE #OrderItems;

        create table #OrderItems
        (
            product_id int not null,
            quantity int not null
        );

        insert into #OrderItems (product_id, quantity)
        select
            product_id,
            quantity
        from openjson(@order_items_json)
        with
        (
            product_id int '$.product_id',
            quantity   int '$.quantity'
        );

        if not exists(select 1 from #OrderItems)
        begin
            throw 50009, 'No order items were provided.', 1;
        end;

        if exists
        (
            select 1 from #OrderItems
            where product_id is null
               or quantity is null
               or quantity <= 0
        )
        begin
            throw 50010, 'Each order item must have a valid product_id and quantity > 0.', 1;
        end;
		------------------------------------------------------------
		-- validate products
		------------------------------------------------------------
		if exists
		(
			select 1
			from #OrderItems oi
			left join Product p
				on oi.product_id = p.product_id
			where p.product_id is null
		)
		begin
			throw 50011, 'One or more products do not exist.', 1;
		end;

		------------------------------------------------------------
		-- calculate total order amount
		------------------------------------------------------------
		select
			@total_amount = sum(cast(oi.quantity * p.unit_price as decimal(18,2)))
		from #OrderItems oi
		inner join Product p
			on oi.product_id = p.product_id;

		if @total_amount is null or @total_amount <= 0
		begin
			throw 50012, 'Total order amount must be greater than 0.', 1;
		end;
        ------------------------------------------------------------
        -- date consistency checks
        ------------------------------------------------------------
        if @shipping_status = 'Delivered' and @delivery_date is null
        begin
            throw 50013, 'Delivery date is required when shipping status is Delivered.', 1;
        end;

        if @delivery_date is not null and @delivery_date < @final_order_date
        begin
            THROW 50014, 'Delivery date cannot be earlier than order date.', 1;
        end;

        ------------------------------------------------------------
        -- insert into Orders
        ------------------------------------------------------------
        insert into Orders
        (
            order_id,
            customer_id,
            order_date,
            status
        )
        values
        (
            @order_id,
            @customer_id,
            @final_order_date,
            @order_status
        );

        ------------------------------------------------------------
        -- insert into Order_Item
        ------------------------------------------------------------

		insert into Order_Item
		(
			order_id,
			product_id,
			quantity
		)
		select
			@order_id,
			oi.product_id,
			oi.quantity
		from #OrderItems oi;

        ------------------------------------------------------------
        -- insert into Payment
        ------------------------------------------------------------
        insert into Payment
        (
            payment_id,
            order_id,
            payment_date,
            payment_status,
            payment_method
        )
        values
        (
            @payment_id,
            @order_id,
            @final_order_date,
            @payment_status,
            @payment_method
        );

        ------------------------------------------------------------
        -- insert into Shipping
        ------------------------------------------------------------
        insert into Shipping
        (
            shipping_id,
            order_id,
            shipped_date,
            shipping_status,
            delivery_date
        )
        values
        (
            @shipping_id,
            @order_id,
            case 
                when @shipping_status in ('Shipped', 'In Transit', 'Delivered') 
                    then @final_order_date
                else null
            end,
            @shipping_status,
            @delivery_date
        );

        ------------------------------------------------------------
        -- return summary
        ------------------------------------------------------------
        select
            @order_id as order_id,
            @customer_id as customer_id,
            @final_order_date as order_date,
            @total_amount as total_amount,
            @payment_method as payment_method,
            @payment_status as payment_status,
            @shipping_status as shipping_status,
            @order_status as order_status,
            'Order placed successfully' AS message;

        commit transaction;
    
	end try

    begin catch
		print 'Error Found ---------------------'
        IF @@trancount > 0
            rollback transaction;

        throw;
    end catch
end;
GO


-----------------------------------------------------------------
---- add customers
-------------------------------------------------------------------

insert into Customer
(
    customer_id,
    customer_name,
    email,
    phone
)
values
(
    1,
    'abc',
    'abc@example.com',
    '9876543210'
);

insert into Customer
(
    customer_id,
    customer_name,
    email,
    phone
)
values
(
    2,
    'xyz',
    'xyz@example.com',
    '9123456780'
);



-----------------------------------------------------------------
---- add products
-------------------------------------------------------------------
insert into Product
(
    product_id,
    product_name,
    category,
    unit_price
)
values
    (1, 'Pen', 'Stationery', 10.00),
    (2, 'Notebook', 'Stationery', 50.00),
    (3, 'Bottle', 'Accessories', 120.00),
    (4, 'Bag', 'Accessories', 850.00),
    (5, 'Mouse', 'Electronics', 499.00);


-----------------------------------------------------------------
---- place an order
-------------------------------------------------------------------

exec dbo.sp_PlaceCustomerOrder
@order_id = 1001,
@customer_id = 3,
@order_date = '2026-03-24',
@order_items_json = N'[
    {"product_id": 1, "quantity": 2},
    {"product_id": 3, "quantity": 1}
]',
@payment_id = 5001,
@payment_method = 'Credit Card',
@payment_status = 'Completed',
@shipping_id = 7001,
@shipping_status = 'Processing',
@delivery_date = '2026-03-28',
@order_status = 'Confirmed';




exec dbo.sp_PlaceCustomerOrder
@order_id = 1003,
@customer_id = 2,
@order_date = '2026-03-24',
@order_items_json = N'[
    {"product_id": 5, "quantity": 2}
]',
@payment_id = 5003,
@payment_method = 'Debit Card',
@payment_status = 'Completed',
@shipping_id = 7003,
@shipping_status = 'Delivered',
@delivery_date = '2026-03-26',
@order_status = 'Confirmed';


-----------------------------------------------------------------
---- View for repeat customers
-------------------------------------------------------------------
GO
Create view vw_RepeatCustomers with encryption
As
Select 
c.customer_id,
c.customer_name,
count(o.Order_id) as total_orders
From customer c
Inner join 
Orders o on c.customer_id= o.customer_id
Group by c.customer_id, c.customer_name
Having count(o.order_id) >1

select * from vw_RepeatCustomers

-----------------------------------------------------------------
---- View for product sales summary
-------------------------------------------------------------------

GO
Create view vw_ProductSalesSummary
as
select
p.product_id,
p.product_name,
p.category,
sum(oi.quantity) as total_units_sold,
sum(oi.quantity * p.unit_price) as total_sales
from Product p
inner join Order_Item oi
on p.product_id = oi.product_id
group by
p.product_id,
p.product_name,
p.category

select * from vw_ProductSalesSummary;



-----------------------------------------------------------------
---- UDF: total amount for one order
-------------------------------------------------------------------

GO
Create function udf_GetOrderTotal(@order_id int)
returns decimal(10,2)
as
begin
declare @total decimal(10,2)

select @total = sum(oi.quantity * p.unit_price)
from Order_Item oi
inner join Product p
on oi.product_id = p.product_id
where oi.order_id = @order_id

return isnull(@total, 0)
end

-----------------------------------------------------------------
---- UDF: customer order count
-------------------------------------------------------------------
GO
create function udf_GetCustomerOrderCount(@customer_id int)
returns int
as
begin
declare @order_count int

select @order_count = count(*)
from Orders
where customer_id = @customer_id

return isnull(@order_count, 0)
end

GO

select
dbo.udf_GetOrderTotal(1001) AS total_order_amount,
dbo.udf_GetCustomerOrderCount(1) AS customer_order_count;



-----------------------------------------------------------------
---- Optimization (Indexing)
-------------------------------------------------------------------

create nonclustered index ix_orders_customerid
on Orders(customer_id);


create nonclustered index ix_orders_status
on Orders(status);


create nonclustered index ix_orders_orderdate
on Orders(order_date);


create nonclustered index ix_shipping_orderid
on Shipping(order_id);


create nonclustered index ix_shipping_status
on Shipping(shipping_status);


create nonclustered index ix_product_category
on Product(category);


create nonclustered index ix_orderitem_productid
on Order_Item(product_id);


create nonclustered index ix_orders_customer_covering
on Orders(customer_id)
include(order_date, status);


create nonclustered index ix_shipping_order_covering
on Shipping(order_id)
include(shipped_date, shipping_status, delivery_date);
