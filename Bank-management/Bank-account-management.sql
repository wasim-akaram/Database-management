--to enable display of output messages run once
SET SERVEROUTPUT ON;

--creeate table customers

CREATE TABLE customers (
    customer_id NUMBER PRIMARY KEY,
    customer_name VARCHAR2(50) NOT NULL,
    phone VARCHAR2(15) UNIQUE,
    created_on DATE DEFAULT SYSDATE
);

--create table accounts
CREATE TABLE accounts (
    account_id NUMBER PRIMARY KEY,
    customer_id NUMBER NOT NULL,
    account_type VARCHAR2(20) CHECK (account_type IN ('SAVINGS','CURRENT')),
    balance NUMBER CHECK (balance >= 0),
    status VARCHAR2(10) DEFAULT 'ACTIVE',
    created_on DATE DEFAULT SYSDATE,
    CONSTRAINT fk_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);

--create transactions table to track transactions log
CREATE TABLE transactions (
    trans_id NUMBER PRIMARY KEY,
    account_id NUMBER,
    trans_type VARCHAR2(15),
    amount NUMBER,
    balance_after NUMBER,
    trans_date DATE DEFAULT SYSDATE
);

--sequences for generating IDs account number & transactions sequence
CREATE SEQUENCE cust_seq START WITH 1;
CREATE SEQUENCE acc_seq  START WITH 1001;
CREATE SEQUENCE trans_seq START WITH 1;

--procedure to create cutomer
CREATE OR REPLACE PROCEDURE create_customer (
    p_name VARCHAR2,
    p_phone VARCHAR2 ) IS
BEGIN
    INSERT INTO customers
    VALUES (cust_seq.NEXTVAL, p_name, p_phone, SYSDATE);

    COMMIT;
END;
/

--procedure to create account
CREATE OR REPLACE PROCEDURE create_account (
    p_customer_id NUMBER,
    p_type VARCHAR2,
    p_initial_balance NUMBER ) IS
BEGIN
    IF p_initial_balance < 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Initial balance cannot be negative');
    END IF;

    INSERT INTO accounts
    VALUES (acc_seq.NEXTVAL, p_customer_id, p_type, p_initial_balance, 'ACTIVE', SYSDATE);

    COMMIT;
END;
/

--procedure to deposit money
CREATE OR REPLACE PROCEDURE deposit_money (
    p_account_id NUMBER,
    p_amount NUMBER ) IS
    v_balance NUMBER;
BEGIN
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Deposit amount must be positive');
    END IF;

    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = p_account_id
    RETURNING balance INTO v_balance;

    INSERT INTO transactions
    VALUES (trans_seq.NEXTVAL, p_account_id, 'DEPOSIT', p_amount, v_balance, SYSDATE);

    COMMIT;
END;
/


--procedure to withdraw money from account with validation
CREATE OR REPLACE PROCEDURE withdraw_money (
    p_account_id NUMBER,
    p_amount NUMBER
) IS
    v_balance NUMBER;
BEGIN
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Withdraw amount must be positive');
    END IF;

    SELECT balance INTO v_balance
    FROM accounts
    WHERE account_id = p_account_id
    FOR UPDATE;

    IF v_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20004, 'Insufficient balance');
    END IF;

    UPDATE accounts
    SET balance = balance - p_amount
    WHERE account_id = p_account_id
    RETURNING balance INTO v_balance;

    INSERT INTO transactions
    VALUES (trans_seq.NEXTVAL, p_account_id, 'WITHDRAW', p_amount, v_balance, SYSDATE);

    COMMIT;
END;
/

--function for balance inquiry
CREATE OR REPLACE FUNCTION get_balance (
    p_account_id NUMBER ) RETURN NUMBER IS
    v_balance NUMBER;
BEGIN
    SELECT balance INTO v_balance
    FROM accounts
    WHERE account_id = p_account_id;

    RETURN v_balance;
END;
/

--trigger for preventing any operations on closed account
CREATE OR REPLACE TRIGGER prevent_closed_account
BEFORE UPDATE ON accounts
FOR EACH ROW
BEGIN
    IF :OLD.status = 'CLOSED' THEN
        RAISE_APPLICATION_ERROR(-20005, 'Account is closed');
    END IF;
END;
/

--trigger to confirm a transaction
CREATE OR REPLACE TRIGGER transaction_notify
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    DBMS_OUTPUT.PUT_LINE(
        'Transaction successful → Account: ' || :NEW.account_id ||
        ', Type: ' || :NEW.trans_type ||
        ', Amount: ' || :NEW.amount ||
        ', Balance: ' || :NEW.balance_after
    );
END;
/

--cursor for transaction history
DECLARE
    CURSOR trans_cur IS
        SELECT trans_type, amount, balance_after, trans_date
        FROM transactions
        WHERE account_id = 1001
        ORDER BY trans_date;

    v_type transactions.trans_type%TYPE;
    v_amt  transactions.amount%TYPE;
    v_bal  transactions.balance_after%TYPE;
    v_date transactions.trans_date%TYPE;
BEGIN
    OPEN trans_cur;
    LOOP
        FETCH trans_cur INTO v_type, v_amt, v_bal, v_date;
        EXIT WHEN trans_cur%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            v_type || ' | ' || v_amt || ' | Balance: ' || v_bal || ' | ' || v_date
        );
    END LOOP;
    CLOSE trans_cur;
END;
/