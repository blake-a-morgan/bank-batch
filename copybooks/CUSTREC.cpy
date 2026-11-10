      *=================================================================
      * COPYBOOK NAME: CUSTREC.CPY
      * DESCRIPTION: This copybook defines the layout of the customer
      * record.
      * CUSTOMER RECORD LAYOUT
      * RECORD LENGTH: 200
      * KEY: CUST-ACC-NO
      *=================================================================
      * Author: Blake Morgan
      * Date:   2026-11-10
      *=================================================================
         01  CUST-RECORD.
           05  CUST-ACC-NO               PIC X(12).
           05  CUST-NAME                 PIC X(30).
           05  CUST-ADDRESS.
               10  CUST-STREET           PIC X(30).
               10  CUST-CITY             PIC X(20).
               10  CUST-STATE            PIC X(2).
               10  CUST-ZIP              PIC X(5).
           05  CUST-BALANCE              PIC S9(7)V99  COMP-3.
           05  CUST-CREDIT-LIMIT         PIC S9(7)V99  COMP-3.
           05  CUST-ACCT-STATUS          PIC X(1).
               88 ACCT-ACTIVE            VALUE 'A'.
               88 ACCT-FROZEN            VALUE 'F'.
               88 ACCT-CLOSED            VALUE 'C'.
               88 ACCT-STATUS-VALID      VALUE 'A', 'F', 'C'.
           05  CUST-ACCT-OPEN-DATE       PIC 9(8).
           05  CUST-ACCT-LAST-ACT-DATE   PIC 9(8).
           05  FILLER                    PIC X(74).
      *=================================================================
      * Record Length: 200
      *=================================================================
      