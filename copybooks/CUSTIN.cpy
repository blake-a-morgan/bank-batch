      *=================================================================
      * COPYBOOK NAME: CUSTIN.CPY
      * DESCRIPTION: Input layout for customer seed file 
      * (text, no packed fields)
      * RECORD LENGTH: 136
      *=================================================================
      * Author: Blake Morgan
      * Date:   2026-11-12
      *=================================================================
         01  IN-RECORD.
           05  IN-ACC-NO                 PIC X(12).
           05  IN-NAME                   PIC X(30).
           05  IN-ADDRESS.
               10  IN-STREET             PIC X(30).
               10  IN-CITY               PIC X(20).
               10  IN-STATE              PIC X(2).
               10  IN-ZIP                PIC X(5).
           05  IN-BALANCE                PIC S9(7)V99 
                                         SIGN LEADING SEPARATE.
           05  IN-CREDIT-LIMIT           PIC S9(7)V99  
                                         SIGN LEADING SEPARATE.
           05  IN-ACCT-STATUS            PIC X(1).
           05  IN-ACCT-OPEN-DATE         PIC 9(8).
           05  IN-ACCT-LAST-ACT-DATE     PIC 9(8).
      *=================================================================
      * Record Length: 12+30+57+10+10+1+8+8 = 136
      *=================================================================