//PRTCUST JOB (ACCT),CLASS=A,MSGCLASS=X,NOTIFY=&SYSUID
//*********************************************************************
//* JOB: PRTCUST
//* PURPOSE: PRINT CUSTOMER MASTER DATA FROM CUSTMAST
//* AUTHOR: BLAKE MORGAN
//* DATE: 2026-11-16
//*********************************************************************
//STEP10   EXEC PGM=IDCAMS
//SYSPRINT DD   SYSOUT=*
//SYSIN    DD    *
    PRINT INDATASET(Z89616.BANK.CUSTMAST) DUMP
/*