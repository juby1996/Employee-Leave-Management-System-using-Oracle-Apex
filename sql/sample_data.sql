--------------------------------------------------------------------------
-- SAMPLE DATA — fictional, for demo/portfolio use only
-- Run in this order (respects foreign key dependencies).
-- EMP_ID / DEPT_ID are assumed auto-generated (IDENTITY columns), so they
-- are not listed explicitly; later inserts look them up by name instead.
--------------------------------------------------------------------------

-- 1. Departments
INSERT INTO DEPARTMENTS (DEPT_NAME, LOCATION) VALUES ('IT', 'Riyadh');
INSERT INTO DEPARTMENTS (DEPT_NAME, LOCATION) VALUES ('HR', 'Dubai');
INSERT INTO DEPARTMENTS (DEPT_NAME, LOCATION) VALUES ('Finance', 'Kuwait City');
COMMIT;

-- 2. Employees
-- One manager per department (MANAGER_ID = NULL), then staff reporting to them.
INSERT INTO EMPLOYEES (EMP_NAME, EMAIL, PHONE, DEPT_ID, MANAGER_ID, JOIN_DATE, STATUS)
VALUES ('Omar Farouk', 'omar.farouk@demo.com', '0500000001',
        (SELECT DEPT_ID FROM DEPARTMENTS WHERE DEPT_NAME = 'IT'),
        NULL, DATE '2021-03-01', 'ACTIVE');

INSERT INTO EMPLOYEES (EMP_NAME, EMAIL, PHONE, DEPT_ID, MANAGER_ID, JOIN_DATE, STATUS)
VALUES ('Lina Haddad', 'lina.haddad@demo.com', '0500000002',
        (SELECT DEPT_ID FROM DEPARTMENTS WHERE DEPT_NAME = 'HR'),
        NULL, DATE '2020-06-15', 'ACTIVE');

INSERT INTO EMPLOYEES (EMP_NAME, EMAIL, PHONE, DEPT_ID, MANAGER_ID, JOIN_DATE, STATUS)
VALUES ('Amira Patel', 'amira.patel@demo.com', '0500000003',
        (SELECT DEPT_ID FROM DEPARTMENTS WHERE DEPT_NAME = 'IT'),
        (SELECT EMP_ID FROM EMPLOYEES WHERE EMP_NAME = 'Omar Farouk'),
        DATE '2022-09-10', 'ACTIVE');

INSERT INTO EMPLOYEES (EMP_NAME, EMAIL, PHONE, DEPT_ID, MANAGER_ID, JOIN_DATE, STATUS)
VALUES ('Sara Ahmed', 'sara.ahmed@demo.com', '0500000004',
        (SELECT DEPT_ID FROM DEPARTMENTS WHERE DEPT_NAME = 'IT'),
        (SELECT EMP_ID FROM EMPLOYEES WHERE EMP_NAME = 'Omar Farouk'),
        DATE '2023-01-20', 'ACTIVE');

INSERT INTO EMPLOYEES (EMP_NAME, EMAIL, PHONE, DEPT_ID, MANAGER_ID, JOIN_DATE, STATUS)
VALUES ('Youssef Nasser', 'youssef.nasser@demo.com', '0500000005',
        (SELECT DEPT_ID FROM DEPARTMENTS WHERE DEPT_NAME = 'Finance'),
        NULL, DATE '2019-11-05', 'ACTIVE');
COMMIT;

-- 3. Leave Types
INSERT INTO LEAVE_TYPES (TYPE_NAME, MAX_DAYS) VALUES ('Annual', 20);
INSERT INTO LEAVE_TYPES (TYPE_NAME, MAX_DAYS) VALUES ('Sick', 10);
INSERT INTO LEAVE_TYPES (TYPE_NAME, MAX_DAYS) VALUES ('Emergency', 5);
COMMIT;

-- 4. App Users (login accounts, one per role, linked to the employees above)
-- PWD values below are placeholders — replace with properly hashed
-- passwords matching whatever your authentication scheme expects.
INSERT INTO APP_USER (USER_NAME, PWD, ROLE, EMP_ID)
VALUES ('admin', 'CHANGE_ME', 'ADMIN', NULL);

INSERT INTO APP_USER (USER_NAME, PWD, ROLE, EMP_ID)
VALUES ('omar.manager', 'CHANGE_ME', 'MANAGER',
        (SELECT EMP_ID FROM EMPLOYEES WHERE EMP_NAME = 'Omar Farouk'));

INSERT INTO APP_USER (USER_NAME, PWD, ROLE, EMP_ID)
VALUES ('lina.hr', 'CHANGE_ME', 'HR',
        (SELECT EMP_ID FROM EMPLOYEES WHERE EMP_NAME = 'Lina Haddad'));

INSERT INTO APP_USER (USER_NAME, PWD, ROLE, EMP_ID)
VALUES ('amira.user', 'CHANGE_ME', 'USER',
        (SELECT EMP_ID FROM EMPLOYEES WHERE EMP_NAME = 'Amira Patel'));

INSERT INTO APP_USER (USER_NAME, PWD, ROLE, EMP_ID)
VALUES ('sara.user', 'CHANGE_ME', 'USER',
        (SELECT EMP_ID FROM EMPLOYEES WHERE EMP_NAME = 'Sara Ahmed'));
COMMIT;

-- 5. Sample Leave Requests
-- Inserted via PKG_LEAVE.CREATE_LEAVE so the triggers (TOTAL_DAYS,
-- CREATED_DATE) populate exactly as they do in normal application use.
DECLARE
    v_request_id LEAVE_REQUESTS.REQUEST_ID%TYPE;
BEGIN
    PKG_LEAVE.CREATE_LEAVE(
        p_emp_id     => (SELECT EMP_ID FROM EMPLOYEES WHERE EMP_NAME = 'Amira Patel'),
        p_type_id    => (SELECT TYPE_ID FROM LEAVE_TYPES WHERE TYPE_NAME = 'Annual'),
        p_from_date  => TRUNC(SYSDATE) + 10,
        p_to_date    => TRUNC(SYSDATE) + 12,
        p_reason     => 'Family trip',
        p_request_id => v_request_id
    );

    PKG_LEAVE.CREATE_LEAVE(
        p_emp_id     => (SELECT EMP_ID FROM EMPLOYEES WHERE EMP_NAME = 'Sara Ahmed'),
        p_type_id    => (SELECT TYPE_ID FROM LEAVE_TYPES WHERE TYPE_NAME = 'Sick'),
        p_from_date  => TRUNC(SYSDATE) + 2,
        p_to_date    => TRUNC(SYSDATE) + 3,
        p_reason     => 'Doctor appointment',
        p_request_id => v_request_id
    );
END;
/

-- 6. Verify
SELECT EMP_ID, EMP_NAME, JOIN_DATE, MANAGER_ID FROM EMPLOYEES ORDER BY EMP_ID;
SELECT USER_NAME, ROLE, EMP_ID FROM APP_USER ORDER BY USER_ID;
SELECT REQUEST_ID, EMP_ID, TYPE_ID, FROM_DATE, TO_DATE, TOTAL_DAYS, STATUS FROM LEAVE_REQUESTS ORDER BY REQUEST_ID;
