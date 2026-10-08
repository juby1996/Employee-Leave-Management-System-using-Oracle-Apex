--Package name :PKG_LEAVE(contains Specification and body)

	--Specification of the package

	create or replace PACKAGE PKG_LEAVE AS
         -- Global variable: holds the manager's EMP_ID for the duration of an approve/reject call, so TRG_LEAVE_REQUESTS_AUDIT can read
            -- "who made this change" without needing a parameter.
    
    G_CURRENT_MANAGER_ID LEAVE_AUDIT.CHANGED_BY%TYPE;

    -- Creates a new leave request after validating business rules
    PROCEDURE CREATE_LEAVE (
        p_emp_id        IN LEAVE_REQUESTS.EMP_ID%TYPE,
        p_type_id       IN LEAVE_REQUESTS.TYPE_ID%TYPE,
        p_from_date     IN LEAVE_REQUESTS.FROM_DATE%TYPE,
        p_to_date       IN LEAVE_REQUESTS.TO_DATE%TYPE,
        p_reason        IN LEAVE_REQUESTS.REASON%TYPE,
        p_request_id    OUT LEAVE_REQUESTS.REQUEST_ID%TYPE
    );

    -- Approves a pending leave request
    PROCEDURE APPROVE_LEAVE (
        p_request_id    IN LEAVE_REQUESTS.REQUEST_ID%TYPE,
        p_manager_id    IN EMPLOYEES.EMP_ID%TYPE,
        p_remark        IN LEAVE_REQUESTS.MANAGER_REMARK%TYPE DEFAULT NULL
    );

    -- Rejects a pending leave request
    PROCEDURE REJECT_LEAVE (
        p_request_id    IN LEAVE_REQUESTS.REQUEST_ID%TYPE,
        p_manager_id    IN EMPLOYEES.EMP_ID%TYPE,
        p_remark        IN LEAVE_REQUESTS.MANAGER_REMARK%TYPE DEFAULT NULL
    );

 
    FUNCTION GET_LEAVE_BALANCE (
        p_emp_id        IN LEAVE_REQUESTS.EMP_ID%TYPE,
        p_type_id       IN LEAVE_REQUESTS.TYPE_ID%TYPE
    ) RETURN NUMBER;

END PKG_LEAVE;
/

--package body
create or replace PACKAGE BODY PKG_LEAVE AS

    --------------------------------------------------------------
    -- GET_LEAVE_BALANCE
    -- MAX_DAYS (from LEAVE_TYPES) minus days already taken/approved
    -- this calendar year for that leave type
    --------------------------------------------------------------
    FUNCTION GET_LEAVE_BALANCE (
        p_emp_id        IN LEAVE_REQUESTS.EMP_ID%TYPE,
        p_type_id       IN LEAVE_REQUESTS.TYPE_ID%TYPE
    ) RETURN NUMBER
    IS
        v_max_days      LEAVE_TYPES.MAX_DAYS%TYPE;
        v_used_days     NUMBER := 0;
    BEGIN
        SELECT MAX_DAYS
        INTO   v_max_days
        FROM   LEAVE_TYPES
        WHERE  TYPE_ID = p_type_id;

        SELECT NVL(SUM(TOTAL_DAYS), 0)
        INTO   v_used_days
        FROM   LEAVE_REQUESTS
        WHERE  EMP_ID = p_emp_id
        AND    TYPE_ID = p_type_id
        AND    STATUS IN ('APPROVED', 'PENDING')     -- reserve balance for pending too
        AND    EXTRACT(YEAR FROM FROM_DATE) = EXTRACT(YEAR FROM SYSDATE);

        RETURN v_max_days - v_used_days;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END GET_LEAVE_BALANCE;


    --------------------------------------------------------------
    -- CREATE_LEAVE
    -- Validates business rules, then inserts the request
    --------------------------------------------------------------
    PROCEDURE CREATE_LEAVE (
        p_emp_id        IN LEAVE_REQUESTS.EMP_ID%TYPE,
        p_type_id       IN LEAVE_REQUESTS.TYPE_ID%TYPE,
        p_from_date     IN LEAVE_REQUESTS.FROM_DATE%TYPE,
        p_to_date       IN LEAVE_REQUESTS.TO_DATE%TYPE,
        p_reason        IN LEAVE_REQUESTS.REASON%TYPE,
        p_request_id    OUT LEAVE_REQUESTS.REQUEST_ID%TYPE
    )
    IS
        v_join_date     EMPLOYEES.JOIN_DATE%TYPE;
        v_days_requested NUMBER;
        v_balance       NUMBER;
    BEGIN
        -- Rule 1: cannot apply before join date
        SELECT JOIN_DATE INTO v_join_date
        FROM   EMPLOYEES
        WHERE  EMP_ID = p_emp_id;

        IF p_from_date < v_join_date THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Leave cannot start before employee join date.');
        END IF;

        -- Rule 2: end date cannot be before start date
        IF p_to_date < p_from_date THEN
            RAISE_APPLICATION_ERROR(-20002,
                'To Date cannot be earlier than From Date.');
        END IF;

        v_days_requested := (p_to_date - p_from_date) + 1;

        -- Rule 3: max 30 days per request
        IF v_days_requested > 30 THEN
            RAISE_APPLICATION_ERROR(-20003,
                'A single leave request cannot exceed 30 days.');
        END IF;

        -- Rule 4: cannot exceed available balance
        v_balance := GET_LEAVE_BALANCE(p_emp_id, p_type_id);

        IF v_days_requested > v_balance THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Requested days exceed available leave balance (' || v_balance || ' days left).');
        END IF;

        -- All validations passed -> insert
        INSERT INTO LEAVE_REQUESTS (
            REQUEST_ID, EMP_ID, TYPE_ID, FROM_DATE, TO_DATE,
             REASON, STATUS
        ) VALUES (
            LEAVE_REQUESTS_SEQ.NEXTVAL, p_emp_id, p_type_id, p_from_date, p_to_date, p_reason, 'PENDING'
        )
        RETURNING REQUEST_ID INTO p_request_id;

    END CREATE_LEAVE;


    --------------------------------------------------------------
    -- APPROVE_LEAVE
    -- Updates status + writes an audit row
    --------------------------------------------------------------
    PROCEDURE APPROVE_LEAVE (
        p_request_id    IN LEAVE_REQUESTS.REQUEST_ID%TYPE,
        p_manager_id    IN EMPLOYEES.EMP_ID%TYPE,
        p_remark        IN LEAVE_REQUESTS.MANAGER_REMARK%TYPE DEFAULT NULL
    )
    IS
        v_old_status LEAVE_REQUESTS.STATUS%TYPE;
    BEGIN
        SELECT STATUS INTO v_old_status
        FROM   LEAVE_REQUESTS
        WHERE  REQUEST_ID = p_request_id
        FOR UPDATE;  -- lock the row to avoid race conditions

        IF v_old_status != 'PENDING' THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Only Pending requests can be approved.');
        END IF;
  -- Make manager id available to the trigger
        G_CURRENT_MANAGER_ID := p_manager_id;

        UPDATE LEAVE_REQUESTS
        SET    STATUS = 'APPROVED',
               MANAGER_REMARK = p_remark
        WHERE  REQUEST_ID = p_request_id;

      -- (no need to insert value into audit table the trigger will do it)TRG_LEAVE_REQUESTS_AUDIT fires here automatically

    END APPROVE_LEAVE;


    --------------------------------------------------------------
    -- REJECT_LEAVE
    -- Updates status + writes an audit row
    --------------------------------------------------------------
    PROCEDURE REJECT_LEAVE (
        p_request_id    IN LEAVE_REQUESTS.REQUEST_ID%TYPE,
        p_manager_id    IN EMPLOYEES.EMP_ID%TYPE,
        p_remark        IN LEAVE_REQUESTS.MANAGER_REMARK%TYPE DEFAULT NULL
    )
    IS
        v_old_status LEAVE_REQUESTS.STATUS%TYPE;
    BEGIN
        SELECT STATUS INTO v_old_status
        FROM   LEAVE_REQUESTS
        WHERE  REQUEST_ID = p_request_id
        FOR UPDATE;

        IF v_old_status != 'PENDING' THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Only Pending requests can be rejected.');
        END IF;

        
        G_CURRENT_MANAGER_ID := p_manager_id;

        UPDATE LEAVE_REQUESTS
        SET    STATUS = 'REJECTED',
               MANAGER_REMARK = p_remark
        WHERE  REQUEST_ID = p_request_id;

      
    END REJECT_LEAVE;

END PKG_LEAVE;
/