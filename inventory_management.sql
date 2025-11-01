--TABLE Creation

CREATE TABLE suppliers (
  supplier_id NUMBER PRIMARY KEY,
  supplier_name VARCHAR2(100),
  contact_no VARCHAR2(15),
  city VARCHAR2(50)
);

CREATE TABLE products (
  product_id NUMBER PRIMARY KEY,
  product_name VARCHAR2(100),
  supplier_id NUMBER REFERENCES suppliers(supplier_id),
  category VARCHAR2(50),
  unit_price NUMBER(10,2),
  stock_qty NUMBER,
  reorder_level NUMBER
);


CREATE TABLE customers (
  customer_id NUMBER PRIMARY KEY,
  customer_name VARCHAR2(100),
  email VARCHAR2(100),
  city VARCHAR2(50)
);

CREATE TABLE orders (
  order_id NUMBER PRIMARY KEY,
  customer_id NUMBER REFERENCES customers(customer_id),
  order_date DATE DEFAULT SYSDATE,
  total_amount NUMBER(10,2)
);

CREATE TABLE order_items (
  order_item_id NUMBER PRIMARY KEY,
  order_id NUMBER REFERENCES orders(order_id),
  product_id NUMBER REFERENCES products(product_id),
  quantity NUMBER,
  subtotal NUMBER(10,2)
);

CREATE TABLE stock_transactions (
  txn_id NUMBER PRIMARY KEY,
  product_id NUMBER REFERENCES products(product_id),
  txn_date DATE DEFAULT SYSDATE,
  txn_type VARCHAR2(20),
  quantity NUMBER
);

CREATE TABLE reorder_alerts (
  alert_id NUMBER PRIMARY KEY,
  product_id NUMBER REFERENCES products(product_id),
  alert_date DATE DEFAULT SYSDATE,
  message VARCHAR2(255)
);

--Sequence Creation

CREATE SEQUENCE orders_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE order_items_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE stock_txn_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE reorder_alerts_seq START WITH 1 INCREMENT BY 1;

-- DATA

INSERT INTO suppliers VALUES (201, 'TechMart Pvt Ltd', '9823012234', 'Pune');
INSERT INTO suppliers VALUES (202, 'Gadget World', '9102341123', 'Mumbai');
INSERT INTO suppliers VALUES (203, 'Vision Electronics', '9822123498', 'Bangalore');
INSERT INTO suppliers VALUES (204, 'Smart Systems', '9108821345', 'Delhi');
INSERT INTO suppliers VALUES (205, 'Digital Hub', '9887765432', 'Chennai');

COMMIT;

INSERT INTO products VALUES (101, 'Laptop', 201, 'Electronics', 65000, 25, 10);
INSERT INTO products VALUES (102, 'Keyboard', 202, 'Accessories', 1200, 80, 15);
INSERT INTO products VALUES (103, 'Mouse', 202, 'Accessories', 800, 60, 10);
INSERT INTO products VALUES (104, 'Printer', 201, 'Electronics', 15000, 8, 5);
INSERT INTO products VALUES (105, 'Monitor', 203, 'Electronics', 12000, 12, 5);
INSERT INTO products VALUES (106, 'Webcam', 204, 'Accessories', 3500, 20, 8);
INSERT INTO products VALUES (107, 'External Hard Drive', 205, 'Storage', 5000, 40, 10);
INSERT INTO products VALUES (108, 'USB Flash Drive', 205, 'Storage', 800, 100, 20);
INSERT INTO products VALUES (109, 'Projector', 203, 'Electronics', 35000, 6, 3);
INSERT INTO products VALUES (110, 'Headphones', 202, 'Accessories', 2500, 30, 10);

COMMIT;

INSERT INTO customers VALUES (301, 'Akash Singh', 'akash@gmail.com', 'Delhi');
INSERT INTO customers VALUES (302, 'Riya Mehta', 'riya@yahoo.com', 'Pune');
INSERT INTO customers VALUES (303, 'Rohit Patel', 'rohitp@outlook.com', 'Mumbai');
INSERT INTO customers VALUES (304, 'Sanya Rao', 'sanya.rao@gmail.com', 'Bangalore');
INSERT INTO customers VALUES (305, 'Kunal Desai', 'kunal.desai@gmail.com', 'Chennai');
INSERT INTO customers VALUES (306, 'Priya Sharma', 'priya.sharma@gmail.com', 'Delhi');
INSERT INTO customers VALUES (307, 'Vikram Nair', 'vikram.nair@gmail.com', 'Kochi');
INSERT INTO customers VALUES (308, 'Megha Joshi', 'megha.joshi@gmail.com', 'Pune');
INSERT INTO customers VALUES (309, 'Neha Verma', 'neha.verma@gmail.com', 'Jaipur');
INSERT INTO customers VALUES (310, 'Ankit Yadav', 'ankit.yadav@gmail.com', 'Lucknow');

COMMIT;


--Package Creation.

CREATE OR REPLACE PACKAGE pkg_inventory AS
  PROCEDURE place_order(p_customer_id NUMBER, p_product_id NUMBER, p_qty NUMBER);
  PROCEDURE restock_product(p_product_id NUMBER, p_qty NUMBER);
  PROCEDURE check_reorder(p_product_id NUMBER);
END pkg_inventory;
/

-- Package Body Creation.
-- Procedure for placing order,restocking products and creating an alert entry for restocking needs.

CREATE or REPLACE PACKAGE BODY pkg_inventory AS    

    PROCEDURE place_order(p_customer_id NUMBER, p_product_id NUMBER, p_qty NUMBER) AS
        v_price NUMBER;
        v_stock NUMBER;
        v_total NUMBER;
        v_order_id NUMBER;
    BEGIN
       SELECT unit_price, stock_qty INTO v_price, v_stock 
    FROM products WHERE product_id = p_product_id;

    IF v_stock < p_qty THEN
      RAISE_APPLICATION_ERROR(-20001, 'Insufficient stock');
    END IF;

    v_total := v_price * p_qty;
    v_order_id := orders_seq.NEXTVAL;

    INSERT INTO orders(order_id, customer_id, total_amount)
    VALUES (v_order_id, p_customer_id, v_total);

    INSERT INTO order_items(order_item_id, order_id, product_id, quantity, subtotal)
    VALUES (order_items_seq.NEXTVAL, v_order_id, p_product_id, p_qty, v_total);

    UPDATE products SET stock_qty = stock_qty - p_qty WHERE product_id = p_product_id;

    INSERT INTO stock_transactions(txn_id, product_id, txn_type, quantity)
    VALUES (stock_txn_seq.NEXTVAL, p_product_id, 'SALE', p_qty);

    check_reorder(p_product_id);
    COMMIT;
  END;

  PROCEDURE restock_product(p_product_id NUMBER, p_qty NUMBER) AS
  BEGIN
    UPDATE products SET stock_qty = stock_qty + p_qty WHERE product_id = p_product_id;
    INSERT INTO stock_transactions(txn_id, product_id, txn_type, quantity)
    VALUES (stock_txn_seq.NEXTVAL, p_product_id, 'PURCHASE', p_qty);
    COMMIT;
  END;

  PROCEDURE check_reorder(p_product_id NUMBER) AS
    v_stock NUMBER;
    v_reorder NUMBER;
  BEGIN
    SELECT stock_qty, reorder_level INTO v_stock, v_reorder
    FROM products WHERE product_id = p_product_id;

    IF v_stock <= v_reorder THEN
      INSERT INTO reorder_alerts(alert_id, product_id, message)
      VALUES (reorder_alerts_seq.NEXTVAL, p_product_id, 
              'Stock low for Product ID ' || p_product_id);
    END IF;
  END;


END pkg_inventory;
/

--Trigger to do same thig as procedure check_reorder.

CREATE or REPLACE TRIGGER trg_check_reorder
AFTER UPDATE OF stock_qty ON products
FOR EACH ROW
WHEN (NEW.stock_qty < NEW.reorder_level)
BEGIN
      INSERT INTO reorder_alerts(alert_id, product_id, message)
  VALUES (reorder_alerts_seq.NEXTVAL, :NEW.product_id, 'Auto alert: Stock below threshold');
END;
/

BEGIN
    pkg_inventory.place_order(305,110,1);
END;
/

SELECT * from REORDER_ALERTS;

--View Creation to see monthly report.

CREATE OR REPLACE VIEW v_monthly_sales AS
SELECT TO_CHAR(order_date, 'YYYY-MM') AS month,
       SUM(total_amount) AS total_sales
FROM orders
GROUP BY TO_CHAR(order_date, 'YYYY-MM');
/

SELECT * from v_monthly_sales;
