      *=================================================================
      * Author: Blake Morgan
      * Purpose: Load customer master KSDS from seed file, 
      *          INPUT: CUSTIN OUTPUT: CUSTMAST
      * Date: 2026-11-12
      *=================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTLOAD.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CUSTIN-FILE ASSIGN TO CUSTIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-CUSTIN-STATUS.

           SELECT CUST-MASTER ASSIGN TO CUSTMAST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS SEQUENTIAL
               RECORD KEY IS CUST-ACC-NO
               FILE STATUS IS WS-CUSTMAST-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  CUSTIN-FILE
           RECORDING MODE IS F.
           COPY CUSTIN.
       FD  CUST-MASTER.
           COPY CUSTREC.
       WORKING-STORAGE SECTION.
       01  WS-CUSTIN-STATUS                 PIC X(02).
           88 CUSTIN-OK                     VALUE '00'.
           88 CUSTIN-EOF                    VALUE '10'.
       01  WS-CUSTMAST-STATUS               PIC X(02).
           88 CUSTMAST-OK                   VALUE '00'.
           88 CUSTMAST-SEQUENCE-ERROR       VALUE '21'.
           88 CUSTMAST-DUPLICATE-KEY        VALUE '22'.
       01  WS-COUNTERS.
           05 WS-RECORDS-READ               PIC 9(05) VALUE 0.
           05 WS-RECORDS-WRITTEN            PIC 9(05) VALUE 0.
           05 WS-RECORDS-REJECTED           PIC 9(05) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-RECORDS UNTIL CUSTIN-EOF
           PERFORM 3000-TERMINATE
           GOBACK.
          
       1000-INITIALIZE.
           OPEN INPUT CUSTIN-FILE
           IF NOT CUSTIN-OK
               DISPLAY 'CUSTIN OPEN ERROR: ' WS-CUSTIN-STATUS
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           OPEN OUTPUT CUST-MASTER
           IF NOT CUSTMAST-OK
               DISPLAY 'CUSTMAST OPEN ERROR: ' WS-CUSTMAST-STATUS
               MOVE 16 TO RETURN-CODE
               CLOSE CUSTIN-FILE
               STOP RUN
           END-IF
           PERFORM 8000-READ-RECORD.

           

       2000-PROCESS-RECORDS.
           MOVE SPACES TO CUST-RECORD
           MOVE IN-ACC-NO TO CUST-ACC-NO
           MOVE IN-NAME TO CUST-NAME
           MOVE IN-ADDRESS TO CUST-ADDRESS
           MOVE IN-BALANCE TO CUST-BALANCE
           MOVE IN-CREDIT-LIMIT TO CUST-CREDIT-LIMIT
           MOVE IN-ACCT-STATUS TO CUST-ACCT-STATUS
           MOVE IN-ACCT-OPEN-DATE TO CUST-ACCT-OPEN-DATE
           MOVE IN-ACCT-LAST-ACT-DATE TO CUST-ACCT-LAST-ACT-DATE 
           WRITE CUST-RECORD
           EVALUATE TRUE
              WHEN CUSTMAST-OK
                  ADD 1 TO WS-RECORDS-WRITTEN
              WHEN CUSTMAST-SEQUENCE-ERROR
                  DISPLAY 'SEQUENCE ERROR ON ACCOUNT: '
                      IN-ACC-NO
                  ADD 1 TO WS-RECORDS-REJECTED
              WHEN CUSTMAST-DUPLICATE-KEY
                  DISPLAY 'DUPLICATE KEY ON ACCOUNT: '
                      IN-ACC-NO
                  ADD 1 TO WS-RECORDS-REJECTED
              WHEN OTHER
                  MOVE 16 TO RETURN-CODE
                  DISPLAY 'WRITE ERROR ON ACCOUNT: '
                      IN-ACC-NO
                  DISPLAY 'FILE STATUS ' WS-CUSTMAST-STATUS
                  PERFORM 3000-TERMINATE
                  GOBACK
           END-EVALUATE
           PERFORM 8000-READ-RECORD.




       3000-TERMINATE.
           CLOSE CUSTIN-FILE
           CLOSE CUST-MASTER
           DISPLAY 'RECORDS READ: ' WS-RECORDS-READ
           DISPLAY 'RECORDS WRITTEN: ' WS-RECORDS-WRITTEN
           DISPLAY 'RECORDS REJECTED: ' WS-RECORDS-REJECTED
           IF RETURN-CODE = 16
               DISPLAY RETURN-CODE
           ELSE
               IF WS-RECORDS-REJECTED > 0
                   MOVE 4 TO RETURN-CODE
               ELSE
                   DISPLAY 'ALL RECORDS PROCESSED SUCCESSFULLY'
               END-IF
           END-IF.
           
           
       


       8000-READ-RECORD.
           READ CUSTIN-FILE
               AT END
                    SET CUSTIN-EOF TO TRUE
               NOT AT END
                   ADD 1 TO WS-RECORDS-READ
           END-READ.
        
       
           
