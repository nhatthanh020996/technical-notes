## 1. Foundation: Transactions & Table-Level Locking (1995–1997)

**Timeline & Versions**

* PostgreSQL (originally Postgres95) added SQL support in 1995.
* The first official release, **PostgreSQL 6.0**, arrived on **January 29, 1997**, introducing proper SQL, unique indexes, ACID-compliant transactions, and Write-Ahead Logging (WAL) for crash recovery ([Wikipedia][1], [Wikipedia][2]).

**Early Concurrency Model**

* At this stage, PostgreSQL supported:

  * `BEGIN/COMMIT/ABORT` along with WAL for durability.
  * Table-level locking with simple read (share) and write (exclusive) modes.
  * Basic deadlock detection to prevent circular waits.

```sql
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
-- exclusive table lock
INSERT INTO transaction_log VALUES (...);
COMMIT;
-- lock released
```

**Limitations**

* Lock granularity at table level led to performance bottlenecks under concurrency.
* Readers and writers blocked each other, limiting scalability.

**Example**

```sql
-- Transaction A: Reading accounts
BEGIN;
SELECT * FROM accounts;  -- Acquires READ (SHARE) lock on entire table

-- Transaction B (concurrent): Trying to update one account
BEGIN;
UPDATE accounts SET balance = balance + 100 WHERE id = 5;
-- BLOCKS waiting for Transaction A to complete
-- even though they're accessing different rows

-- Only after Transaction A commits/aborts:
COMMIT;  -- Transaction B can finally proceed
```

This example demonstrates how even a simple read operation could block updates to unrelated rows under table-level locking.

---

## 2. Fine-Grained Locking & Transaction Enhancements (1999–2005)

**Row-Level Locking Arrives**

* Introduced in **PostgreSQL 7.0 (May 2000)**, row-level locks allowed finer control and reduced contention ([PostgreSQL][3], [PostgreSQL][4]).
* Subsequent developments (7.2 and 8.0) added more lock modes (e.g., `ROW SHARE`, `ROW EXCLUSIVE`) and features like `SELECT FOR UPDATE` and `FOR SHARE` ([PostgreSQL][3]).

**Transaction Features**

* WAL improved crash recovery robustness in **v7.1 (2001)**.
* **PostgreSQL 8.0 (2005)** introduced savepoints, tablespaces, and point-in-time recovery ([Wikipedia][2]).

```sql
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
-- row-level lock
UPDATE accounts SET balance = balance + 50 WHERE id = 2;
COMMIT;
```

**Improvements**

* Reduced lock contention by enabling concurrent operations on different rows.
* Readers and writers still blocked each other if targeting the same row.

---

## 3. MVCC Revolution (1999–2001)

**Historical Milestone**

* **PostgreSQL 6.5**, released **June 9, 1999**, introduced full MVCC support, marking a major shift in concurrency control ([PostgreSQL][4]).

**MVCC Mechanics**

* Every row carries hidden system columns: `xmin` (creating transaction ID) and `xmax` (deleting transaction ID).
* Writers produce new versions, readers view consistent snapshots—never blocked by writes ([Wikipedia][5]).

```sql
-- Txn A updates row: new version created
-- Txn B reads original version (snapshot)
-- After A commits, Txn C sees updated version
```

**Benefits**

* Readers and writers no longer blocked each other.
* Achieved high concurrency and throughput.

---

## 4. Integrated Modern Concurrency Model (2001–Present)

**MVCC + Locking + Transactions**

* PostgreSQL combines MVCC with locks to manage write-write conflicts, schema changes, DDL, and explicit locking strategies.
* Supports standard SQL isolation levels: Read Committed, Repeatable Read, and Serializable.

**Advanced Isolation**

* **PostgreSQL 9.1 (2011)** introduced **Serializable Snapshot Isolation (SSI)**, offering true serializability by detecting dangerous patterns and aborting conflicting transactions ([Reddit][6], [Wikipedia][2], [Wikipedia][7]).

**Maintenance & Cleanup**

* Dead row versions (tombstones) are cleaned via `VACUUM` and `autovacuum`.
* Improvements in vacuum effectiveness continue through PostgreSQL 17 ([tldp.org][8], [PostgreSQL][9]).

**Example of Concurrent Use Today**

```sql
-- Long-running snapshot (Repeatable Read)
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM accounts WHERE balance > 1000;
-- Concurrent updates happen without blocking
COMMIT;
```

---

## ✅ Summary Table

| Phase                | Timeline     | Key Features                                                                                         |
| -------------------- | ------------ | ---------------------------------------------------------------------------------------------------- |
| **Basic Locking**    | 1995–1997    | Table-level locks, ACID transactions, WAL                                                            |
| **Improved Locking** | 1999–2005    | Row-level locks, lock modes, savepoints, WAL enhancements                                            |
| **MVCC Era**         | 1999–2001    | Snapshot isolation, non-blocking reads/writes, xmin/xmax versioning                                  |
| **Modern Model**     | 2001–present | MVCC + locks, SSI (v9.1), VACUUM/autovacuum, full SQL isolation support, schema and advisory locking |

---

## 🧠 Final Take

Your original content was fundamentally solid. Here are the key clarifications added:

* **6.0** launched in **Jan 1997** with foundational features ([PostgreSQL][10], [PostgreSQL][4]).
* **Row-level locks** began rolling out in **v7.0 (2000)** and matured through **8.0** .
* **MVCC** was introduced in **v6.5 (June 1999)**, not 2000 .
* **SSI** arrived in **v9.1 (2011)** to support true serializability .

If you'd like, I can polish this further or help integrate these revisions back into your document.

[1]: https://ru.wikipedia.org/wiki/PostgreSQL?utm_source=chatgpt.com "PostgreSQL"
[2]: https://en.wikipedia.org/wiki/PostgreSQL?utm_source=chatgpt.com "PostgreSQL"
[3]: https://www.postgresql.org/docs/8.0/explicit-locking.html?utm_source=chatgpt.com "PostgreSQL: Documentation: 8.0: Explicit Locking"
[4]: https://www.postgresql.org/docs/9.6/explicit-locking.html?utm_source=chatgpt.com "PostgreSQL: Documentation: 9.6: Explicit Locking"
[5]: https://en.wikipedia.org/wiki/Multiversion_concurrency_control?utm_source=chatgpt.com "Multiversion concurrency control"
[6]: https://www.reddit.com/r/HomeworkHelp/comments/1i472eh?utm_source=chatgpt.com "[University: Database concept and design] Can you help me understand the question how do i compare the concurrency control mechanism because all system it give have same mechanism which is mvcc. Also what the other criteria am i supposed to give"
[7]: https://en.wikipedia.org/wiki/Snapshot_isolation?utm_source=chatgpt.com "Snapshot isolation"
[8]: https://tldp.org/LDP/LG/issue68/mitchell.html?utm_source=chatgpt.com "The Opening of the Field: PostgreSQL's Multi-Version Concurrency Control LG #68"
[9]: https://www.postgresql.org/docs/9.1/mvcc-intro.html?utm_source=chatgpt.com "PostgreSQL: Documentation: 9.1: Introduction"
[10]: https://www.postgresql.org/docs/current/explicit-locking.html?utm_source=chatgpt.com "PostgreSQL: Documentation: 17: 13.3. Explicit Locking"
