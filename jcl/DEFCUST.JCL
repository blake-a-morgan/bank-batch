//**********************************************************************
//* DEFINE CUSTOMER MASTER FILE
//* This JCL defines the customer master file cluster and its index.
//* It deletes any existing cluster and defines a new one with the specified index and data components.
//* The cluster is defined with a key of 12 bytes and a record size of 200 bytes.
//* The index component is named Z89616.BANK.CUSTMAST.INDEX and the data component is named Z89616.BANK.CUSTMAST.DATA.
//* The cluster is allocated with 5 tracks for both the index and data components.
//* The IDCAMS utility is used to delete and define the cluster.
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
          )                                  -
          INDEX                              -
         (NAME(Z89616.BANK.CUSTMAST.INDEX))  -
         DATA                                -
         (NAME(Z89616.BANK.CUSTMAST.DATA))
/*
//