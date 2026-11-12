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
- [ ] Compile/link JCL, and run CUSTLOAD on z/OS
- [ ] Daily transaction file and update program
- [ ] Customer report with control breaks and totals
- [ ] A single job stream: SORT, condition codes, GDGs
- [ ] Automation with Zowe CLI

---

## How it works

```
                 ┌──────────────┐
                 │   DEFCUST    │  IDCAMS: DELETE / DEFINE CLUSTER
                 │   (JCL)      │
                 └──────┬───────┘
                        │ creates
                        ▼
 data/CUSTIN.txt   ┌──────────┐        ┌────────────────────────┐
 (text seed file) ─►│ CUSTLOAD │──WRITE─►│ Z89616.BANK.CUSTMAST   │
   DD: CUSTIN      │ (COBOL)  │        │ VSAM KSDS, key = acct # │
                   └──────────┘        │ DD: CUSTMAST           │
                        │              └────────────────────────┘
                        ▼
              SYSOUT: read / written / rejected counts
              RETURN-CODE: 0 / 4 / 16
```

---

## Repository layout

```
bank-batch/
├── copybooks/
│   ├── CUSTREC.cpy     Customer master record (KSDS layout)
│   └── CUSTIN.cpy      Seed input record (text layout)
├── data/
│   └── CUSTIN.txt      Sample customers (fixed-width, 136 bytes/record)
├── jcl/
│   └── DEFCUST.JCL     Delete and redefine the customer master KSDS
└── src/
    └── CUSTLOAD.cbl    Load the KSDS from the seed file
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

### Sample data

The six test customers in `data/CUSTIN.txt` cover a normal account, negative balances, frozen and closed accounts, a zero balance, an account over its credit limit, and a ZIP code with a leading zero.

---

## Running it

Prerequisites: Zowe CLI configured with a z/OSMF profile for your z/OS system. Replace `Z89616` in the JCL with your own high-level qualifier.

```powershell
# Define (or redefine) the customer master KSDS
zowe zos-jobs submit local-file "jcl/DEFCUST.JCL" --view-all-spool-content

# Confirm the cluster and its DATA/INDEX components exist
zowe zos-files list data-set "Z89616.BANK.**"
```

Compile and run steps for `CUSTLOAD` will be added in the next milestone.

---

## Author

**Blake Morgan**, building toward a mainframe engineering role.
<!-- https://www.linkedin.com/in/blake-morgan-123589164/ -->
