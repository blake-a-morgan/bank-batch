      *=================================================================
      * Author: Blake Morgan
      * Purpose: UPDATE CUSTMAST WITH NEW TRANSACTIONS
      * Input: TRANIN I/O: CUSTMAST, Output: REJOUT 
      * Date: 2026-11-17
      *=================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTUPD.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
              SELECT CUST-MASTER ASSIGN TO CUSTMAST
                ORGANIZATION IS INDEXED
                ACCESS MODE IS RANDOM
                RECORD KEY IS CUST-ACC-NO
                FILE STATUS IS WS-CUSTMAST-STATUS.
    
              SELECT UPD-TRAN ASSIGN TO TRANIN
                ORGANIZATION IS SEQUENTIAL
                ACCESS MODE IS SEQUENTIAL
                FILE STATUS IS WS-TRANIN-STATUS.

              SELECT UPD-REJECT ASSIGN TO REJOUT
                ORGANIZATION IS SEQUENTIAL
                ACCESS MODE IS SEQUENTIAL
                FILE STATUS IS WS-REJOUT-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  CUST-MASTER.
           COPY CUSTREC.
       FD  UPD-TRAN
           RECORDING MODE IS F.
           COPY TRANREC.    
       FD  UPD-REJECT
           RECORDING MODE IS F.
           COPY REJREC.

       WORKING-STORAGE SECTION.
       01  WS-CUSTMAST-STATUS               PIC X(02).
           88 WS-CUSTMAST-OK                VALUE '00'.
           88 WS-CUSTMAST-NOT-FOUND         VALUE '23'.
       01  WS-TRANIN-STATUS                 PIC X(02).
           88 WS-TRANIN-OK                  VALUE '00'.
           88 WS-TRANIN-EOF                 VALUE '10'.
       01  WS-REJOUT-STATUS                 PIC X(02).
           88 WS-REJOUT-OK                  VALUE '00'.
       01  WS-COUNTERS.
           05 WS-RECORDS-READ               PIC 9(05) VALUE 0.
           05 WS-RECORDS-APPLIED            PIC 9(05) VALUE 0.
           05 WS-RECORDS-REJECTED           PIC 9(05) VALUE 0.
       01  WS-REJOUT-RECORD.
           05 WS-REJOUT-CODE                PIC X(3).
           05 WS-REJOUT-DESC                PIC X(40).
       01  WS-TRAN-SWITCH                   PIC X(1).
           88 WS-TRAN-VALID                 VALUE 'Y'.
           88 WS-TRAN-INVALID               VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-RECORDS UNTIL WS-TRANIN-EOF
           PERFORM 3000-TERMINATE
           GOBACK.

       1000-INITIALIZE.
           OPEN I-O CUST-MASTER
           IF NOT WS-CUSTMAST-OK
               DISPLAY 'CUSTMAST OPEN ERROR: ' WS-CUSTMAST-STATUS
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           OPEN INPUT UPD-TRAN
           IF NOT WS-TRANIN-OK
               DISPLAY 'TRANIN OPEN ERROR: ' WS-TRANIN-STATUS
               MOVE 16 TO RETURN-CODE
               CLOSE CUST-MASTER
               STOP RUN
           END-IF
           OPEN OUTPUT UPD-REJECT
           IF NOT WS-REJOUT-OK
               DISPLAY 'REJOUT OPEN ERROR: ' WS-REJOUT-STATUS
               MOVE 16 TO RETURN-CODE
               CLOSE CUST-MASTER, UPD-TRAN
               STOP RUN
           END-IF
           PERFORM 8000-READ-TRAN.

       2000-PROCESS-RECORDS.
           SET WS-TRAN-VALID TO TRUE
           PERFORM 2100-LOOKUP-ACCOUNT
           IF WS-TRAN-VALID
              PERFORM 2200-VALIDATE-COMMON
           END-IF
           IF WS-TRAN-VALID
              PERFORM 2300-VALIDATE-BY-TYPE
           END-IF
           IF WS-TRAN-VALID
              PERFORM 2400-APPLY-TRANSACTION    
           ELSE
            PERFORM 2900-REJECT-TRANSACTION
           END-IF
           PERFORM 8000-READ-TRAN.

       2100-LOOKUP-ACCOUNT.
           MOVE TRAN-ACC-NO TO CUST-ACC-NO
           READ CUST-MASTER
           EVALUATE TRUE
             WHEN WS-CUSTMAST-OK
               CONTINUE
             WHEN WS-CUSTMAST-NOT-FOUND
               MOVE 'R01' TO WS-REJOUT-CODE
               MOVE 'ACCOUNT NOT FOUND' TO WS-REJOUT-DESC
               SET WS-TRAN-INVALID TO TRUE
             WHEN OTHER
               MOVE 16 TO RETURN-CODE
               DISPLAY 'CUSTMAST READ ERROR: ' WS-CUSTMAST-STATUS
               PERFORM 3000-TERMINATE
               GOBACK
            END-EVALUATE.
            
       2200-VALIDATE-COMMON.
           CONTINUE. 

       2300-VALIDATE-BY-TYPE.
           CONTINUE.

       2400-APPLY-TRANSACTION.
           Continue.

       2900-REJECT-TRANSACTION.
           MOVE SPACES TO REJ-RECORD
           MOVE TRAN-RECORD TO REJ-TRAN-DATA
           MOVE WS-REJOUT-CODE TO REJ-REASON-CODE
           MOVE WS-REJOUT-DESC TO REJ-REASON-DESC
           WRITE REJ-RECORD
           IF NOT WS-REJOUT-OK
               DISPLAY 'REJOUT WRITE ERROR: ' WS-REJOUT-STATUS
               MOVE 16 TO RETURN-CODE
               PERFORM 3000-TERMINATE
               GOBACK
           END-IF
           ADD 1 TO WS-RECORDS-REJECTED.
           




           

       3000-TERMINATE.
           CLOSE CUST-MASTER, UPD-TRAN, UPD-REJECT
           DISPLAY 'RECORDS READ: ' WS-RECORDS-READ
           DISPLAY 'RECORDS APPLIED: ' WS-RECORDS-APPLIED
           DISPLAY 'RECORDS REJECTED: ' WS-RECORDS-REJECTED
           IF RETURN-CODE = 16
               DISPLAY 'CUSTUPD ENDED WITH ERROR: ' RETURN-CODE
           ELSE
            IF WS-RECORDS-REJECTED > 0
               MOVE 4 TO RETURN-CODE
            ELSE
             DISPLAY 'TRANSACTIONS PROCESSED SUCCESSFULLY'
             END-IF
           END-IF.


       8000-READ-TRAN.
           READ UPD-TRAN
               AT END
                   SET WS-TRANIN-EOF TO TRUE
               NOT AT END
                   ADD 1 TO WS-RECORDS-READ
           END-READ.

