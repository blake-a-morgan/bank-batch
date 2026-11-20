# Bank Batch: Customer Master System on z/OS

A mainframe batch system for a small retail bank, written in **Enterprise COBOL** and **JCL** and run on a real **IBM z/OS** system (IBM Z Xplore). It maintains a **VSAM KSDS** customer master file. Each night, a job stream loads, updates and reports on customer accounts.

The project follows the patterns used in production mainframe shops: shared copybooks, jobs that are safe to rerun, FILE STATUS checking on every I/O, and return codes that later job steps can act on.

---

## Tech stack

| Area | Tools |
|---|---|
| Language | Enterprise COBOL |
| Job control | JCL, IDCAMS |
| Data | VSAM KSDS, sequential (QSAM) files |
| Platform | IBM z/OS (IBM Z Xplore) |
| Tooling | VS Code, IBM Z Open Editor, Zowe CLI, Git |

---

## Project status

- [x] **Customer record design:** the `CUSTREC` copybook (200-byte fixed record, COMP-3 money fields)
- [x] **VSAM KSDS definition:** a rerunnable IDCAMS job (`DEFCUST`)
- [x] **Seed input layout and test data:** the `CUSTIN` copybook and `data/CUSTIN.txt`
- [x] **Load program written:** `CUSTLOAD` (sequential load into the KSDS)
- [x] **Compile/link JCL, and run CUSTLOAD on z/OS:** `CUSTCMP` compiles and links `CUSTLOAD` then `CUSTRUN` loads the custin data into the CUSTMAST KSDS. `PRTCUST` dumps the output into a sysprint to verify data was successfully loaded.
- [x] **Daily transaction update:** the `TRANREC` / `REJREC` copybooks, the `CUSTUPD` program (random-access VSAM update with 10 business rules and a reject file), and the `UPDCMP` / `UPDRUN` jobs. Verified against a 23-transaction test plan.
- [ ] Customer report with control breaks and totals
- [ ] A single job stream: SORT, condition codes, GDGs
- [ ] Automation with Zowe CLI

---

## How it works

```
 1. DEFCUST   IDCAMS DELETE / DEFINE CLUSTER ──────► empty KSDS BANK.CUSTMAST

 2. CUSTCMP   IGYWCL (compile + link-edit)
              BANK.COBOL(CUSTLOAD) ─┐
              BANK.COPYLIB ─────────┴──► BANK.LOADLIB(CUSTLOAD)

 3. CUSTRUN   EXEC PGM=CUSTLOAD  (STEPLIB = BANK.LOADLIB)
              BANK.CUSTIN ──READ──► CUSTLOAD ──WRITE──► BANK.CUSTMAST
              (DD CUSTIN, text)        │               (DD CUSTMAST, KSDS)
                                       ▼
                      SYSOUT: read / written / rejected counts
                      RETURN-CODE: 0 / 4 / 16

 4. PRTCUST   IDCAMS PRINT ... DUMP ──► hex + character dump of every record

 5. UPDCMP    IGYWCL ──► BANK.LOADLIB(CUSTUPD)

 6. UPDRUN    STEP05  IEFBR14: delete yesterday's reject file (if any)
              STEP10  EXEC PGM=CUSTUPD
                                         ┌──READ by key──┐
              BANK.TRANIN ──READ──► CUSTUPD          BANK.CUSTMAST
              (DD TRANIN)              │  └──REWRITE───┘  (DD CUSTMAST, I-O)
                                       │
                        valid ◄────────┴────────► invalid
                    balance/status                 BANK.TRANREJ
                    updated in KSDS                (DD REJOUT: txn + reason code)
                                       ▼
                      SYSOUT: read / applied / rejected counts
                      RETURN-CODE: 0 / 4 / 16

 7. PRTCUST   dump again and compare against the expected results
```

---

## Repository layout

```
bank-batch/
├── copybooks/
│   ├── CUSTREC.cpy     Customer master record (KSDS layout)
│   ├── CUSTIN.cpy      Seed input record (text layout)
│   ├── TRANREC.cpy     Daily transaction record (41 bytes)
│   └── REJREC.cpy      Rejected transaction record (86 bytes)
├── data/
│   ├── CUSTIN.txt      Sample customers (fixed-width, 136 bytes/record)
│   └── TRANIN.txt      Test transactions (fixed-width, 41 bytes/record)
├── jcl/
│   ├── DEFCUST.JCL     Delete and redefine the customer master KSDS
│   ├── CUSTCMP.JCL     Compile and link-edit CUSTLOAD
│   ├── CUSTRUN.JCL     Run CUSTLOAD to load the KSDS
│   ├── PRTCUST.JCL     Dump the KSDS contents for verification
│   ├── UPDCMP.JCL      Compile and link-edit CUSTUPD
│   └── UPDRUN.JCL      Run CUSTUPD to apply the day's transactions
└── src/
    ├── CUSTLOAD.cbl    Load the KSDS from the seed file
    └── CUSTUPD.cbl     Apply transactions to the KSDS, write rejects
```

---

## Components

### `DEFCUST.JCL`: define the customer master

Runs **IDCAMS** to (re)create the KSDS `Z89616.BANK.CUSTMAST`.

- **Safe to rerun.** The job deletes the cluster first. If the delete fails only because the file doesn't exist yet (condition code 8), the job resets `MAXCC` to 0, so the first run and every later run both end with `CC 0000`.
- **Cluster attributes**

  | Attribute | Value | Why |
  |---|---|---|
  | `INDEXED` | KSDS | Direct access by account number |
  | `KEYS(12 0)` | 12-byte key at offset 0 | `CUST-ACC-NO` |
  | `RECORDSIZE(200 200)` | Fixed 200 bytes | Matches `CUSTREC` |
  | `FREESPACE(20 10)` | 20% CI / 10% CA | Room for inserts without CI/CA splits |
  | `SHAREOPTIONS(2 3)` | Many readers + one writer | Reports can run while updates are applied |

### `CUSTLOAD.cbl`: load the customer master

Reads the text seed file and writes each customer to the KSDS in key order.

- **Batch structure:** initialize, then a processing loop, then terminate, using the **priming read** pattern, so an empty input file is handled correctly.
- **Format conversion:** the money fields in the input are readable text (`SIGN LEADING SEPARATE`). Numeric `MOVE`s convert them to **COMP-3**, the packed format used in the master file.
- **FILE STATUS checked on every OPEN and WRITE**, with 88-level condition names:

  | Status | Meaning | Action |
  |---|---|---|
  | `00` | Success | Count as written |
  | `21` | Key out of sequence | Log account, count as rejected, continue |
  | `22` | Duplicate key | Log account, count as rejected, continue |
  | other | I/O failure | Log, close files, RC 16, stop |

- **Return codes** let later job steps decide whether to run:

  | RC | Meaning |
  |---|---|
  | 0 | All records loaded |
  | 4 | Load finished, but some records were rejected (review SYSOUT) |
  | 16 | Open or I/O failure, so the load is incomplete |

  A warning code never overwrites a more serious one that has already been set.

### `CUSTCMP.JCL`: compile and link-edit

Calls IBM's **`IGYWCL`** procedure and overrides its DD statements to point at the project libraries:

| Override | Points to |
|---|---|
| `COBOL.SYSIN` | Source member `BANK.COBOL(CUSTLOAD)` |
| `COBOL.SYSLIB` | `BANK.COPYLIB`, resolving `COPY CUSTIN` / `COPY CUSTREC` |
| `LKED.SYSLMOD` | Output program object `BANK.LOADLIB(CUSTLOAD)` |

Dataset names use `&SYSUID`, so the job works for any user ID without editing.

### `CUSTRUN.JCL`: run the load

| DD | Dataset | DISP | Why |
|---|---|---|---|
| `STEPLIB` | `BANK.LOADLIB` | `SHR` | Where z/OS finds `CUSTLOAD` (otherwise abend S806) |
| `CUSTIN` | `BANK.CUSTIN` | `SHR` | Read-only input; safe to share |
| `CUSTMAST` | `BANK.CUSTMAST` | `OLD` | Exclusive use, so no job can read a half-loaded file |
| `SYSOUT` | `SYSOUT=*` | | Run summary from `DISPLAY` |

DD names match the program's `ASSIGN TO` clauses.

### `PRTCUST.JCL`: verify the load

Runs `IDCAMS PRINT INDATASET(...) DUMP`, which prints every KSDS record in hex and characters. This checks the load independently of the program's own counts. In particular, it shows that the money fields really are packed decimal.

### `CUSTUPD.cbl`: apply the day's transactions

Reads the transaction file in sequence. For each transaction it reads the matching customer **by key** (`ACCESS RANDOM`, `OPEN I-O`), validates the transaction, then either updates the record with `REWRITE` or writes it to the reject file with a reason code. One bad transaction never stops the run.

**Transaction types**

| Type | Meaning | Effect on the customer record |
|---|---|---|
| `D` | Deposit | balance + amount |
| `W` | Withdrawal | balance − amount |
| `F` | Fee | balance − amount |
| `I` | Interest | balance + amount |
| `S` | Status change | status ← new status (`A` / `F` / `C`) |

Every applied transaction also sets the last-activity date to the transaction's date. The program uses the **business date**, not the system clock, so reruns and after-midnight runs stamp the correct day.

**Business rules:** the first rule that fails decides the reject reason.

| Code | Applies to | Reject when |
|---|---|---|
| R01 | all | Account not found (VSAM status `23`) |
| R02 | all | Transaction type is not D/W/F/I/S |
| R03 | D, W, F, I | Amount is non-numeric or zero |
| R04 | D, W, F, I | Account is closed |
| R05 | W | Account is frozen |
| R06 | W | Balance is already negative |
| R07 | W | New balance would be below −(credit limit) |
| R08 | I | Account is frozen or the balance is negative |
| R09 | S | New status is not A/F/C |
| R10 | S | Closing an account with a non-zero balance |

**Design points**

- **Layered validation with a single switch.** `2100` looks up the account, `2200` runs the checks common to all types, and `2300` runs the type-specific checks. Each layer runs only if the transaction is still valid. One final `IF` either applies it (`2400`) or rejects it (`2900`), so each counter and each write happens in exactly one place.
- **No S0C7 on bad input.** The amount is checked with a `NUMERIC` class test *before* any comparison or arithmetic. The test data includes a non-numeric amount (`00012AB00`), which is rejected with R03 instead of abending the job.
- **The reject record keeps the original transaction.** All 41 bytes are copied with one group `MOVE`, so the record can be corrected and resubmitted. Copying it as plain bytes also means bad numeric data can't cause an abend.
- **FILE STATUS is checked after every READ, REWRITE and WRITE.** Status `23` on the master is a business reject (R01). Any other unexpected status is fatal: the program displays it, closes all files, and ends with RC 16.

| RC | Meaning |
|---|---|
| 0 | All transactions applied |
| 4 | Run finished, but some transactions were rejected (see `BANK.TRANREJ`) |
| 16 | Open or I/O failure, so the run is incomplete |

### `UPDRUN.JCL`: run the update

| Step | DD | Dataset | DISP | Why |
|---|---|---|---|---|
| `STEP05` (`IEFBR14`) | `REJOUT` | `BANK.TRANREJ` | `(MOD,DELETE,DELETE)` | Deletes the previous reject file whether or not it exists, so the job is safe to rerun |
| `STEP10` (`CUSTUPD`) | `STEPLIB` | `BANK.LOADLIB` | `SHR` | Program location |
| | `TRANIN` | `BANK.TRANIN` | `SHR` | Read-only input |
| | `CUSTMAST` | `BANK.CUSTMAST` | `OLD` | Exclusive, because the master is being updated |
| | `REJOUT` | `BANK.TRANREJ` | `(NEW,CATLG,DELETE)` | Created by the step; deleted if the step abends |

`UPDCMP.JCL` is the same as `CUSTCMP.JCL`, but it compiles `CUSTUPD`.

---

## Results

`CUSTRUN` output (`CC 0000`):

```
 RECORDS READ: 00006
 RECORDS WRITTEN: 00006
 RECORDS REJECTED: 00000
 ALL RECORDS PROCESSED SUCCESSFULLY
```

`PRTCUST` dump excerpt for account `000000100002`. The balance at offset 99 (`X'63'`) is `00 00 07 55 0D`, packed decimal for **−75.50** (sign nibble `D` = negative):

```
 000060  F2F0F500 0007550D 00025000 0CC1F2F0 ...   *205.......&..A20...*
```

IDCAMS reported `NUMBER OF RECORDS PROCESSED WAS 6`, which matches the program's count.

### Transaction update (`UPDRUN`)

`data/TRANIN.txt` is a test plan: 23 transactions, each designed to test one rule, with the expected outcome worked out **before** the program was run. It covers every reject code, plus these cases:

- **Order matters:** a withdrawal from a frozen account is rejected (R05). A status change then unfreezes the account, and the same withdrawal is applied. This shows that each transaction sees the updated record.
- **Exact boundary:** a withdrawal that leaves the balance *exactly* at −(credit limit) is applied, while one that goes 1 cent past it is rejected (R07).
- **Rules apply only to their own types:** status changes carry a zero amount and must *not* be rejected by R03.

`UPDRUN` output (`STEP05 CC 0000`, `STEP10 CC 0004`):

```
 RECORDS READ: 00023
 RECORDS APPLIED: 00011
 RECORDS REJECTED: 00012
```

Reject file `BANK.TRANREJ` (original transaction, reason code, description):

```
000000100001X000001000 20261116T000000004 R02 INVALID TRANSACTION TYPE
000000100001D000000000 20261116T000000005 R03 AMOUNT MUST BE GREATER THAN ZERO
000000100001D00012AB00 20261116T000000006 R03 AMOUNT NOT NUMERIC
000000100001W001483014 20261116T000000007 R07 WITHDRAWAL EXCEEDS CREDIT LIMIT
000000100002W000001000 20261116T000000009 R06 INSUFFICIENT FUNDS FOR WITHDRAWAL
000000100002I000000100 20261116T000000010 R08 NO INTEREST: FROZEN OR NEGATIVE BALANCE
000000100003W000010000 20261116T000000011 R05 WITHDRAWAL NOT ALLOWED: FROZEN ACCOUNT
000000100003I000002000 20261116T000000013 R08 NO INTEREST: FROZEN OR NEGATIVE BALANCE
000000100004D000010000 20261116T000000016 R04 INVALID ACTIONS FOR CLOSED ACCOUNT
000000100004S000000000C20261116T000000019 R10 CANNOT CLOSE ACCOUNT:NON ZERO BALANCE
000000100005S000000000X20261116T000000021 R09 INVALID NEW STATUS
999999999999D000010000 20261116T000000023 R01 ACCOUNT NOT FOUND
```

Customer master before and after, decoded from the `PRTCUST` hex dumps. All six records match the expected results, and every record's last-activity date was set to `20261116`:

| Account | Before | After | Status | Packed balance after (offset 99) |
|---|---:|---:|---|---|
| Chen | 4,525.30 | 4,830.13 | A | `00 04 83 01 3C` |
| Okafor | −75.50 | −100.50 | A | `00 00 10 05 0D` |
| Martinez | 21,500.00 | 21,650.00 | F → **A** | `00 21 65 00 0C` |
| Whitaker | 0.00 | 50.00 | C → **A** | `00 00 05 00 0C` |
| Nair | 988.12 | −3,000.00 | A | `00 03 00 00 0D` |
| Hayes | −1,200.00 | −1,235.00 | F | `00 01 23 50 0D` |

---

## Mainframe datasets

| Dataset | Type | RECFM | LRECL | BLKSIZE | Contents |
|---|---|---|---|---|---|
| `BANK.COBOL` | PDSE | FB | 80 | 27920 | COBOL source |
| `BANK.COPYLIB` | PDSE | FB | 80 | 27920 | Copybooks |
| `BANK.JCL` | PDSE | FB | 80 | 27920 | JCL |
| `BANK.LOADLIB` | PDSE | U | 0 | 32760 | Program objects (Enterprise COBOL V5+ requires PDSE) |
| `BANK.CUSTIN` | PS | FB | 136 | 27880 | Seed input data |
| `BANK.CUSTMAST` | VSAM KSDS | | 200 | | Customer master |
| `BANK.TRANIN` | PS | FB | 41 | 27962 | Daily transactions |
| `BANK.TRANREJ` | PS | FB | 86 | 27950 | Rejected transactions (created by `UPDRUN`) |

Block sizes are the largest multiple of LRECL that fits in a 3390 half-track (27998 bytes).

---

## Record layouts

### Customer master: `CUSTREC` (VSAM KSDS, 200 bytes)

| Offset | Len | Field | PIC | Notes |
|---:|---:|---|---|---|
| 0 | 12 | `CUST-ACC-NO` | `X(12)` | **Key** |
| 12 | 30 | `CUST-NAME` | `X(30)` | |
| 42 | 30 | `CUST-STREET` | `X(30)` | Part of `CUST-ADDRESS` |
| 72 | 20 | `CUST-CITY` | `X(20)` | |
| 92 | 2 | `CUST-STATE` | `X(2)` | |
| 94 | 5 | `CUST-ZIP` | `X(5)` | Text, so leading zeros are kept |
| 99 | 5 | `CUST-BALANCE` | `S9(7)V99 COMP-3` | Packed decimal |
| 104 | 5 | `CUST-CREDIT-LIMIT` | `S9(7)V99 COMP-3` | Packed decimal |
| 109 | 1 | `CUST-ACCT-STATUS` | `X(1)` | `A` active, `F` frozen, `C` closed |
| 110 | 8 | `CUST-ACCT-OPEN-DATE` | `9(8)` | `YYYYMMDD` |
| 118 | 8 | `CUST-ACCT-LAST-ACT-DATE` | `9(8)` | `YYYYMMDD` |
| 126 | 74 | `FILLER` | `X(74)` | Reserved for future fields |

### Seed input: `CUSTIN` (sequential text, 136 bytes)

The same fields as `CUSTREC`, but every field is plain text, so the file can be written in an editor and uploaded with EBCDIC conversion. Each money field takes 10 bytes: a sign character followed by 9 digits, with an implied decimal point (e.g. `-000007550` = −$75.50).

| Columns | Field |
|---|---|
| 1–12 | Account number |
| 13–42 | Name |
| 43–72 | Street |
| 73–92 | City |
| 93–94 | State |
| 95–99 | ZIP |
| 100–109 | Balance |
| 110–119 | Credit limit |
| 120 | Status |
| 121–128 | Open date |
| 129–136 | Last activity date |

### Transaction: `TRANREC` (sequential text, 41 bytes)

| Columns | Field | PIC | Notes |
|---|---|---|---|
| 1–12 | `TRAN-ACC-NO` | `X(12)` | Customer key |
| 13 | `TRAN-TYPE` | `X(1)` | `D` `W` `F` `I` `S` (88-levels) |
| 14–22 | `TRAN-AMOUNT` | `9(7)V99` | Unsigned; the type decides the direction |
| 23 | `TRAN-NEW-STATUS` | `X(1)` | Used only by `S` transactions |
| 24–31 | `TRAN-DATE` | `9(8)` | `YYYYMMDD`, the business date |
| 32–41 | `TRAN-ID` | `X(10)` | Unique transaction reference |

### Rejected transaction: `REJREC` (sequential text, 86 bytes)

| Columns | Field | PIC | Notes |
|---|---|---|---|
| 1–41 | `REJ-TRAN-DATA` | `X(41)` | The original transaction, byte for byte |
| 42 | `FILLER` | `X(1)` | Space |
| 43–45 | `REJ-REASON-CODE` | `X(3)` | `R01`–`R10` |
| 46 | `FILLER` | `X(1)` | Space |
| 47–86 | `REJ-REASON-DESC` | `X(40)` | Readable explanation |

### Sample data

The six test customers in `data/CUSTIN.txt` cover a normal account, negative balances, frozen and closed accounts, a zero balance, an account over its credit limit, and a ZIP code with a leading zero. The 23 transactions in `data/TRANIN.txt` are described under [Results](#transaction-update-updrun).

---

## Running it

Prerequisites: Zowe CLI configured with a z/OSMF profile for your z/OS system, and the libraries above allocated. Replace `Z89616` with your own high-level qualifier in `DEFCUST.JCL`, `PRTCUST.JCL` and the commands below. The other jobs use `&SYSUID`.

```powershell
# 1. Upload source, copybooks and seed data
zowe zos-files upload file-to-data-set "src/CUSTLOAD.cbl"     "Z89616.BANK.COBOL(CUSTLOAD)"
zowe zos-files upload file-to-data-set "copybooks/CUSTIN.cpy"  "Z89616.BANK.COPYLIB(CUSTIN)"
zowe zos-files upload file-to-data-set "copybooks/CUSTREC.cpy" "Z89616.BANK.COPYLIB(CUSTREC)"
zowe zos-files upload file-to-data-set "data/CUSTIN.txt"       "Z89616.BANK.CUSTIN"

# 2. Define (or redefine) the customer master KSDS
zowe zos-jobs submit local-file "jcl/DEFCUST.JCL" --view-all-spool-content

# 3. Compile and link-edit CUSTLOAD
zowe zos-jobs submit local-file "jcl/CUSTCMP.JCL" --view-all-spool-content

# 4. Load the KSDS
zowe zos-jobs submit local-file "jcl/CUSTRUN.JCL" --view-all-spool-content

# 5. Verify the contents
zowe zos-jobs submit local-file "jcl/PRTCUST.JCL" --view-all-spool-content

# 6. Upload the transaction program, copybooks and test transactions
zowe zos-files upload file-to-data-set "src/CUSTUPD.cbl"       "Z89616.BANK.COBOL(CUSTUPD)"
zowe zos-files upload file-to-data-set "copybooks/TRANREC.cpy" "Z89616.BANK.COPYLIB(TRANREC)"
zowe zos-files upload file-to-data-set "copybooks/REJREC.cpy"  "Z89616.BANK.COPYLIB(REJREC)"
zowe zos-files upload file-to-data-set "data/TRANIN.txt"       "Z89616.BANK.TRANIN"

# 7. Compile CUSTUPD, apply the transactions, and verify
zowe zos-jobs submit local-file "jcl/UPDCMP.JCL" --view-all-spool-content
zowe zos-jobs submit local-file "jcl/UPDRUN.JCL" --view-all-spool-content
zowe zos-files view data-set "Z89616.BANK.TRANREJ"
zowe zos-jobs submit local-file "jcl/PRTCUST.JCL" --view-all-spool-content
```

> **Rerunning the load:** run `DEFCUST` before `CUSTRUN`. `CUSTLOAD` opens the KSDS for `OUTPUT`, which expects an empty cluster.
>
> **Rerunning the update:** run `DEFCUST`, then `CUSTRUN`, then `UPDRUN`. Applying the same transactions twice to the same master would post them twice (for example, a second +$500 deposit).

---

## Author

**Blake Morgan**, building toward a mainframe engineering role.
[LinkedIn](https://www.linkedin.com/in/blake-morgan-123589164/)
