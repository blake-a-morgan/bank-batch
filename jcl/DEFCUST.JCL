//DEFCUST JOB (ACCT),CLASS=A,MSGCLASS=X,NOTIFY=&SYSUID
//STEP10 EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN DD *
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