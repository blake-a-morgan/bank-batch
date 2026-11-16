      *=================================================================
      * COPYBOOK NAME: REJREC.CPY
      * DESCRIPTION: This copybook defines the layout of the rejected 
      *  transaction record.
      * RECORD LENGTH: 86
      *=================================================================
      * Author: Blake Morgan
      * Date:   2026-11-16
      *=================================================================
         01 REJ-RECORD.
           05 REJ-TRAN-DATA    PIC X(41).
           05 FILLER           PIC X(1).
           05 REJ-REASON-CODE  PIC X(3).
           05 FILLER           PIC X(1).
           05 REJ-REASON-DESC  PIC X(40).
      *=================================================================
      * Record Length: 41+1+3+1+40 = 86
      *=================================================================