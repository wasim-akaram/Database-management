SET SERVEROUTPUT ON;

--SUPPLIIERS TABLE

CREATE TABLE SUPPLIERS(
    supplier_id number PRIMARY KEY,
    supplier_name VARCHAR(30),
    contact_number VARCHAR(10));

--PRODUCTS TABLE

CREATE TABLE PRODUCTS (
    product_id NUMBER PRIMARY KEY,
    product_name VARCHAR(40),
    supplier_id NUMBER,
    quantity NUMBER,
    recorder_level NUMBER,
    CONSTRAINT fk_supplier
    FOREIGN KEY (supplier_id)
    REFERENCES SUPPLIERS(supplier_id)
);

--STOCK TRANSACTIONS TABLE

CREATE TAble STOCK_TRANSACTIONS(
    transaction_id NUMBER PRIMARY KEY,
    product_id number,
    transaction_type VARCHAR(20),
    trans_date DATE );

--sequence for transaction id

CREATE SEQUENCE stock_sequence
START WITH 1 INCREMENT BY 1;




--procedure for adding goods in stock

CREATE OR REPLACE PROCEDURE stock_in (
    p_product_id NUMBER,
    p_qty NUMBER) IS
BEGIN
    UPDATE PRODUCTS
    SET quantity = quantity + p_qty
    WHERE product_id = p_product_id;

    INSERT INTO STOCK_TRANSACTIONS
    VALUES (stock_sequence.NEXTVAL, p_product_id, 'IN', p_qty, SYSDATE);

    COMMIT;
END;
/


/* procedure for goods going out
updating sales record and handling exceptions */

CREATE OR REPLACE PROCEDURE stock_out (
    p_product_id NUMBER,
    p_qty NUMBER ) IS
    v_stock NUMBER;
BEGIN
    SELECT quantity INTO v_stock
    FROM PRODUCTS
    WHERE product_id = p_product_id;

    IF v_stock < p_qty THEN
        RAISE_APPLICATION_ERROR(-20001, 'Insufficient stock available');
    END IF;

    UPDATE PRODUCTS
    SET quantity = quantity - p_qty
    WHERE product_id = p_product_id;

    INSERT INTO STOCK_TRANSACTIONS
    VALUES (stock_sequence.NEXTVAL, p_product_id, 'OUT', p_qty, SYSDATE);

    COMMIT;
END;
/


-- function to check the status of the available stock

CREATE OR REPLACE FUNCTION get_available_stock (
    p_product_id NUMBER ) 
    RETURN NUMBER IS
    v_qty NUMBER;
BEGIN
    SELECT quantity INTO v_qty
    FROM PRODUCTS
    WHERE product_id = p_product_id;

    RETURN v_qty;
END;
/

--trigger for alerting the low stock

CREATE OR REPLACE TRIGGER low_stock_alert
AFTER UPDATE OF quantity ON PRODUCTS
FOR EACH ROW
BEGIN
    IF :NEW.quantity < :NEW.reorder_level THEN
        DBMS_OUTPUT.PUT_LINE(
            'LOW STOCK ALERT! Product ID: ' || :NEW.product_id
        );
    END IF;
END;
/

--cursor for low stock report

DECLARE
    CURSOR low_stock_cur IS
        SELECT product_id, product_name, quantity
        FROM PRODUCTS
        WHERE quantity < reorder_level;

    v_pid products.product_id%TYPE;
    v_name products.product_name%TYPE;
    v_qty products.quantity%TYPE;
BEGIN
    OPEN low_stock_cur;
    LOOP
        FETCH low_stock_cur INTO v_pid, v_name, v_qty;
        EXIT WHEN low_stock_cur%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            'Product: ' || v_name || ' | Stock: ' || v_qty
        );
    END LOOP;
    CLOSE low_stock_cur;
END;


/* tracking the stock supplier wise as stated
by joining supplier and product table */

SELECT s.supplier_name, p.product_name, p.quantity
FROM SUPPLIERS s
JOIN PRODUCTS p
ON s.supplier_id = p.supplier_id;