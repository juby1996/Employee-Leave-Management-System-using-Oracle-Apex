# Performance Notes — Employee Leave Management System

This document records the indexing review and query tuning carried out for
the Employee Leave Management System, including a real issue found and
fixed using `EXPLAIN PLAN`.

---

## 1. Index Review

Checked existing indexes against the columns most heavily used in joins,
filters, and sorts (`USER_IND_COLUMNS`). Most foreign key and lookup columns
were already indexed from earlier development:

| Table            | Column       | Index            |
|-------------------|--------------|-------------------|
| LEAVE_REQUESTS     | EMP_ID       | EMPID_LEAVE_IDX   |
| LEAVE_REQUESTS     | STATUS       | STATUS_LEAVE_IDX  |
| LEAVE_REQUESTS     | TYPE_ID      | TYPEID_LEAVE_IDX  |
| LEAVE_REQUESTS     | REQUEST_ID   | PK (system-named) |
| EMPLOYEES          | DEPT_ID      | EMP_DEPT_IDX      |
| EMPLOYEES          | EMP_ID       | PK (system-named) |
| LEAVE_TYPES        | TYPE_ID      | PK (system-named) |
| DEPARTMENTS        | DEPT_ID      | PK (system-named) |
| LEAVE_AUDIT        | AUDIT_ID     | PK_AUDIT_ID       |

**Gap found:** `LEAVE_AUDIT.REQUEST_ID` had no index, despite being the join
column back to `LEAVE_REQUESTS` on the Approval page's audit trail.

```sql
CREATE INDEX REQID_AUDIT_IDX ON LEAVE_AUDIT(REQUEST_ID);
```

Note: foreign key columns are **not** automatically indexed by Oracle
(unlike primary keys, which get one from their constraint) — this is a
common gap to check for in any schema review.

---

## 2. EXPLAIN PLAN Finding

Ran `EXPLAIN PLAN` on the Task 9 "Approved Leaves" report query (joins
LEAVE_REQUESTS, EMPLOYEES, LEAVE_TYPES, filtered on STATUS):

```sql
SELECT lr.REQUEST_ID, e.EMP_NAME, lt.TYPE_NAME,
       TO_CHAR(lr.FROM_DATE,'DD-MM-YYYY') AS FROM_DATE,
       TO_CHAR(lr.TO_DATE,'DD-MM-YYYY') AS TO_DATE,
       lr.REASON, lr.STATUS
FROM LEAVE_REQUESTS lr
JOIN EMPLOYEES e ON e.EMP_ID = lr.EMP_ID
JOIN LEAVE_TYPES lt ON lt.TYPE_ID = lr.TYPE_ID
WHERE UPPER(lr.STATUS) = 'APPROVED';
```

**Before fix:** the plan showed `TABLE ACCESS STORAGE FULL` on
`LEAVE_REQUESTS`, even though `STATUS_LEAVE_IDX` already existed on that
column. Oracle's own plan output explained why, under "SQL Analysis
Report":

> *The following columns have predicates which preclude their use as keys
> in index range scan... STATUS*

**Root cause:** wrapping an indexed column in a function (`UPPER(STATUS)`)
prevents Oracle from using a standard index on the raw column, because the
index stores the unmodified values, not the function's result. This
pattern is used throughout the app (adopted during earlier case-sensitivity
bug fixes), so it was worth confirming its actual cost.

**Fix — function-based index:**

```sql
CREATE INDEX STATUS_UPPER_IDX ON LEAVE_REQUESTS (UPPER(STATUS));
```

This indexes the *result* of `UPPER(STATUS)` directly, so queries filtering
on `UPPER(STATUS) = ...` can use an index range scan instead of a full
table scan. Re-running `EXPLAIN PLAN` after creating the index confirmed
the full table scan was eliminated.

---

## 3. Takeaways

- Primary keys get an index automatically; foreign keys do not — check
  them explicitly.
- A function applied to an indexed column (`UPPER()`, `TRUNC()`, etc.)
  silently disables normal index usage on that column unless a matching
  function-based index exists.
- `EXPLAIN PLAN` plus `DBMS_XPLAN.DISPLAY` is the direct way to confirm
  whether a query is using the indexes you think it is, rather than
  assuming based on what indexes exist.
