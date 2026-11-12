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
               FILE STATUS IS WS-CUSTM-STATUS.
