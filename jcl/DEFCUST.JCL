//**********************************************************************
//* JOB: DEFCUST
//* PURPOSE: DELETE AND REDEFINE CUSTOMER MASTER FILE
//* NOTE: SAFE TO RERUN - DELETE NOT FOUND (RC 8) IS IGNORED
//* AUTHOR: BLAKE MORGAN
//* DATE: 2026-11-12
//**********************************************************************
//DEFCUST JOB (ACCT),CLASS=A,MSGCLASS=X,NOTIFY=&SYSUID
//STEP10 EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN DD *
  DELETE Z89616.BANK.CUSTMAST CLUSTER PURGE
  IF LASTCC <= 8 THEN -
    DO
        SET MAXCC = 0
    END
  DEFINE CLUSTER (NAME(Z89616.BANK.CUSTMAST) -
         INDEXED                             -
         KEYS(12 0)                          -
         RECORDSIZE(200 200)                 -
         TRACKS(5 5)                         -
         SHAREOPTIONS(2 3)                   -
         FREESPACE(20 10)                    -
          )                                  -
          INDEX                              -
         (NAME(Z89616.BANK.CUSTMAST.INDEX))  -
         DATA                                -
         (NAME(Z89616.BANK.CUSTMAST.DATA))
/*
//