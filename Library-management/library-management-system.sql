--to enable display of output messages run once
SET SERVEROUTPUT ON;

--table for tracking books and their availability
CREATE TABLE book_catalog (
    book_key NUMBER PRIMARY KEY,
    book_title VARCHAR2(120) NOT NULL,
    book_writer VARCHAR2(60),
    total_units NUMBER CHECK (total_units > 0),
    free_units NUMBER CHECK (free_units >= 0));


--table of library members
CREATE TABLE library_members (
    member_key NUMBER PRIMARY KEY,
    member_fullname VARCHAR2(60) NOT NULL,
    member_category VARCHAR2(20)
    CHECK (member_category IN ('STUDENT','STAFF')),
    membership_status VARCHAR2(10) DEFAULT 'ACTIVE',
    joined_on DATE DEFAULT SYSDATE);

--table to track the activity of members i.e who borrowed and returned
-- and fines 
CREATE TABLE borrow_register (
    borrow_key NUMBER PRIMARY KEY,
    book_key NUMBER,
    member_key NUMBER,
    borrow_date DATE,
    expected_return DATE,
    actual_return DATE,
    late_fee NUMBER DEFAULT 0,
    borrow_state VARCHAR2(15) DEFAULT 'ISSUED',
    CONSTRAINT fk_book_ref FOREIGN KEY (book_key) REFERENCES book_catalog(book_key),
    CONSTRAINT fk_member_ref FOREIGN KEY (member_key) REFERENCES library_members(member_key));

--sequences to auto generate book id member id etc
CREATE SEQUENCE seq_book START WITH 1;
CREATE SEQUENCE seq_member START WITH 1;
CREATE SEQUENCE seq_borrow START WITH 1001;


--function to calculate late fee [Rs 3/ day]
CREATE OR REPLACE FUNCTION calc_delay_fee (
    p_due DATE,
    p_return DATE ) RETURN NUMBER IS

BEGIN
    IF p_return <= p_due THEN
        RETURN 0;
    ELSE
        RETURN (p_return - p_due) * 3;
    END IF;
END;
/


--function to check availability of the book
CREATE OR REPLACE FUNCTION check_book_free_units (
    p_book_key NUMBER ) RETURN NUMBER IS
    v_units NUMBER;
BEGIN

    SELECT free_units INTO v_units
    FROM book_catalog
    WHERE book_key = p_book_key;

    RETURN v_units;
END;
/

--function to track the maximum number of books a member can borrow
-- to ensure availability of books for all
CREATE OR REPLACE FUNCTION member_can_borrow (
    p_member_key NUMBER
) RETURN BOOLEAN IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM borrow_register
    WHERE member_key = p_member_key
      AND borrow_state = 'ISSUED';

    RETURN v_count < 3;
END;
/

/* package for all library operations
enroll member
add new book
borrow book
return */
CREATE OR REPLACE PACKAGE library_ops AS
    PROCEDURE enroll_member(p_name VARCHAR2, p_type VARCHAR2);
    PROCEDURE add_new_book(p_title VARCHAR2, p_author VARCHAR2, p_qty NUMBER);
    PROCEDURE borrow_book(p_book_key NUMBER, p_member_key NUMBER);
    PROCEDURE return_book(p_borrow_key NUMBER);
END library_ops;
/

CREATE OR REPLACE PACKAGE BODY library_ops AS

    PROCEDURE enroll_member(p_name VARCHAR2, p_type VARCHAR2) IS
    BEGIN
        INSERT INTO library_members
        VALUES (seq_member.NEXTVAL, p_name, p_type, 'ACTIVE', SYSDATE);
        COMMIT;
    END;

    PROCEDURE add_new_book(p_title VARCHAR2, p_author VARCHAR2, p_qty NUMBER) IS
    BEGIN
        INSERT INTO book_catalog
        VALUES (seq_book.NEXTVAL, p_title, p_author, p_qty, p_qty);
        COMMIT;
    END;

    PROCEDURE borrow_book(p_book_key NUMBER, p_member_key NUMBER) IS
        v_units NUMBER;
    BEGIN
        IF NOT member_can_borrow(p_member_key) THEN
            RAISE_APPLICATION_ERROR(-20010, 'Borrow limit exceeded');
        END IF;

        v_units := check_book_free_units(p_book_key);
        IF v_units = 0 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Book currently unavailable');
        END IF;

        INSERT INTO borrow_register
        VALUES (
            seq_borrow.NEXTVAL,
            p_book_key,
            p_member_key,
            SYSDATE,
            SYSDATE + 7,
            NULL,
            0,
            'ISSUED' );

        UPDATE book_catalog
        SET free_units = free_units - 1
        WHERE book_key = p_book_key;

        COMMIT;
    END;

    PROCEDURE return_book(p_borrow_key NUMBER) IS
        v_book NUMBER;
        v_due DATE;
        v_fee NUMBER;
    BEGIN
        SELECT book_key, expected_return
        INTO v_book, v_due
        FROM borrow_register
        WHERE borrow_key = p_borrow_key
        FOR UPDATE;

        v_fee := calc_delay_fee(v_due, SYSDATE);

        UPDATE borrow_register
        SET actual_return = SYSDATE,
            late_fee = v_fee,
            borrow_state = 'RETURNED'
        WHERE borrow_key = p_borrow_key;

        UPDATE book_catalog
        SET free_units = free_units + 1
        WHERE book_key = v_book;

        COMMIT;
    END;

END library_ops;
/

--trigger to block in active members
CREATE OR REPLACE TRIGGER block_inactive_member
BEFORE INSERT ON borrow_register
FOR EACH ROW
DECLARE
    v_status library_members.membership_status%TYPE;
BEGIN
    SELECT membership_status INTO v_status
    FROM library_members
    WHERE member_key = :NEW.member_key;

    IF v_status <> 'ACTIVE' THEN
        RAISE_APPLICATION_ERROR(-20020, 'Inactive member cannot borrow');
    END IF;
END;
/

--trigger to update fine automatically
CREATE OR REPLACE TRIGGER fine_guard_trigger
BEFORE UPDATE OF actual_return ON borrow_register
FOR EACH ROW
BEGIN
    :NEW.late_fee := calc_delay_fee(:OLD.expected_return, :NEW.actual_return);
END;
/


--over due report [cursor] to find the books that haven't been returned in time
DECLARE
    CURSOR overdue_cursor IS
        SELECT b.book_title, m.member_fullname, r.expected_return
        FROM borrow_register r
        JOIN book_catalog b ON r.book_key = b.book_key
        JOIN library_members m ON r.member_key = m.member_key
        WHERE r.borrow_state = 'ISSUED'
          AND r.expected_return < SYSDATE;

    v_book VARCHAR2(120);
    v_member VARCHAR2(60);
    v_due DATE;
BEGIN
    OPEN overdue_cursor;
    LOOP
        FETCH overdue_cursor INTO v_book, v_member, v_due;
        EXIT WHEN overdue_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            v_book || ' | ' || v_member || ' | Due: ' || v_due
        );
    END LOOP;
    CLOSE overdue_cursor;
END;
/