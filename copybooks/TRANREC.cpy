      *=================================================================
      * COPYBOOK NAME: TRANREC.CPY
      * DESCRIPTION: This copybook defines the layout of the transaction
      * record.
      * TRANSACTION RECORD LAYOUT
      * RECORD LENGTH: 41
      *=================================================================
      * Author: Blake Morgan
      * Date:   2026-11-16
      *=================================================================
         01  TRAN-RECORD.
           05  TRAN-ACC-NO               PIC X(12).
           05  TRAN-TYPE                 PIC X(1).
               88 TRAN-DEPOSIT           VALUE 'D'.
               88 TRAN-WITHDRAWAL        VALUE 'W'.
               88 TRAN-INTEREST          VALUE 'I'.
               88 TRAN-FEE               VALUE 'F'.
               88 TRAN-STATUS-CHANGE     VALUE 'S'.
               88 TRAN-TYPE-VALID        VALUE 'D', 'W', 'I', 'F', 'S'.
           05  TRAN-AMOUNT               PIC 9(7)V99.
           05  TRAN-NEW-STATUS           PIC X(1).
               88 TRAN-NEW-ACTIVE        VALUE 'A'.
               88 TRAN-NEW-FROZEN        VALUE 'F'.
               88 TRAN-NEW-CLOSED        VALUE 'C'.
               88 TRAN-NEW-STATUS-VALID  VALUE 'A', 'F', 'C'.
           05  TRAN-DATE                 PIC 9(8).
           05  TRAN-ID                   PIC X(10).
           
      *=================================================================
      * Record Length: 12+1+9+1+8+10 = 41
      *================================================================