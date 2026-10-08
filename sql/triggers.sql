--triggers

--trigger name:DEPT_TRG1
create or replace trigger dept_trg1
              before insert on dept
              for each row
              begin
                  if :new.deptno is null then
                      select dept_seq.nextval into :new.deptno from sys.dual;
                 end if;
              end;
/
--trigger name:emp_trg1
create or replace trigger emp_trg1
              before insert on emp
              for each row
              begin
                  if :new.empno is null then
                      select emp_seq.nextval into :new.empno from sys.dual;
                 end if;
              end;
/
--trigger name:"LTRG_LEAVE_REQUESTS_AUDIT"
create or replace trigger "LTRG_LEAVE_REQUESTS_AUDIT"
after
 update  on "LEAVE_AUDIT"
for each row
begin
    INSERT INTO LEAVE_AUDIT (
        REQUEST_ID, OLD_STATUS, NEW_STATUS, CHANGED_BY, CHANGED_DATE
    ) VALUES (
        :NEW.REQUEST_ID, :OLD.STATUS, :NEW.STATUS,
        PKG_LEAVE.G_CURRENT_MANAGER_ID, SYSDATE
    );
end;
/
--trigger name:TRG_LEAVE_AUDIT_ID
create or replace TRIGGER TRG_LEAVE_AUDIT_ID
BEFORE INSERT ON LEAVE_AUDIT
FOR EACH ROW
WHEN(NEW.AUDIT_ID IS NULL)
BEGIN
:NEW.AUDIT_ID := LEAVE_AUDIT_SEQ.NEXTVAL;
END;
/
--trigger name:"TRG_LEAVE_REQUESTS_AUDIT"
create or replace trigger "TRG_LEAVE_REQUESTS_AUDIT"
after
 update  OF STATUS ON "LEAVE_REQUESTS"
for each row
begin
    INSERT INTO LEAVE_AUDIT (
        REQUEST_ID, OLD_STATUS, NEW_STATUS, CHANGED_BY, CHANGED_DATE
    ) VALUES (
        :NEW.REQUEST_ID, :OLD.STATUS, :NEW.STATUS,
        PKG_LEAVE.G_CURRENT_MANAGER_ID, SYSDATE
    );
end;
/
--trigger name:"TRG_LEAVE_REQUESTS_BI"
create or replace trigger "TRG_LEAVE_REQUESTS_BI"
before 
insert on "LEAVE_REQUESTS"
for each row
begin
    -- Auto-calculate total days (inclusive of both start and end date)
      :NEW.TOTAL_DAYS := (:NEW.TO_DATE - :NEW.FROM_DATE) + 1;

-- Auto-store created date if not already supplied
IF:NEW.CREATED_DATE  IS NULL THEN
:NEW.CREATED_DATE  := SYSDATE;
END IF;

end;
/

--trigger name:TRG_LEAVE_REQUESTS_ID
create or replace TRIGGER TRG_LEAVE_REQUESTS_ID
BEFORE INSERT ON LEAVE_REQUESTS
FOR EACH ROW
WHEN (NEW.REQUEST_ID IS NULL)
BEGIN
    :NEW.REQUEST_ID := LEAVE_REQUESTS_SEQ.NEXTVAL;
END;
/