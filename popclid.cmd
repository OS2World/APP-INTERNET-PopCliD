/**********************************************************************
PopCliD.cmd - popclient Daemon                
Copyright:
    Claudio Fahey claudio@uclink.berkeley.edu, 1994 and 
    Clark Gaylord (cgaylord@vt.edu), 1995.

User is licensed to use this program, associated programs, and
documentation in any way provided that:
1) attribution of program source is maintained
2) copyright notices are maintained
3) changes made by user are clearly documented.
Note that popclient.exe, popclient.c, and associated files are 
copyright by Carl Harris; see the documentation for further 
information regarding the licensing of popclient itself.
                                              
Procedures GetArg, ArgCheck, Help, Elm support and other changes:                       
Clark K. Gaylord (cgaylord@vt.edu)
Version 2.21a: 18 January 1995
        2.21b: 25 March 1995
        2.21c:  8 April 1995
        2.21d: 25 May 1995
        2.21e: 26 May 1995
        2.21f: 31 May 1995
        2.21g:  2 June 1995
        2.21h:  7 June 1995

See README.OS2 for more details.
**********************************************************************/
CALL RxFuncAdd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
CALL SysLoadFuncs
SIGNAL ON HALT  /* don't display REXX error message when user breaks out */

TmpDir = Value( 'TMP', , 'OS2ENVIRONMENT' )

/**********************************************************************
New argument processing.  I moved Claudios' original
to the bottom with label 'Changed:'.                    CKG
**********************************************************************/
PARSE ARG Args
IF (Pos( '-?', Args )>0) THEN SIGNAL HELP
CALL GetArg Args

/**********************************************************************
Write the process ID to a file for use by other programs.
**********************************************************************/
GotPID = 0
"@ps.exe|rxqueue"
DO Until (GotPID)
    PULL PID . . . . . . Program
    IF Program = 'CMD.EXE' THEN
        GotPID = 1
END
CALL FlushQueue

CALL SysFileDelete TmpDir'\PopClid.pid'
SAY 'PID =' PID
CALL Lineout TmpDir'\PopCliD.pid', PID
CALL Lineout TmpDir'\PopCliD.pid'

/**********************************************************************
Set environment variable POPSOUND=YES if you want to be notified that
mail has arrived.  Also NEWMAILSOUNDFILE and ERRORSOUNDFILE to WAV 
files to play.  Sound files can be specified on command line, but not
POPSOUND.                                                   RLW 6/5/95
**********************************************************************/
ErrorSoundFileExists = 0
NewMailSoundFileExists = 0
mmpm = 0
IF (Sound="Y") THEN DO
    Sound=1

    mmbase = value('MMBASE',,OS2ENVIRONMENT)
    IF mmbase='' THEN DO
        say 'MMPM is not present.'
        mmpm=0
    END
    ELSE DO
        mmpm=1
        IF NewMailSoundFile<>'' THEN DO
            IF Stream(NewMailSoundFile,'c','Query Exists')='' THEN
                NewMailSoundFileExists=0
            ELSE
                NewMailSoundFileExists=1
        END
        ELSE
            NewMailSoundFileExists=0

        IF ErrorSoundFile<>'' THEN DO
            IF Stream(ErrorSoundFile,'c','Query Exists')='' THEN
                ErrorSoundFileExists=0
            ELSE
                ErrorSoundFileExists=1
        END
        ELSE
            ErrorSoundFileExists=0
    END
END
ELSE DO
   Sound = 0
end  

/**********************************************************************
Set environment variable POPUPBIFF=YES if you want to be notified that
mail has arrived.
**********************************************************************/
/*  Can we use PMPOPUP at all? */
PopupExe = SysSearchPath( 'PATH', 'pmpopup.exe')
IF (PopupExe='') THEN
   PopUp = 0
ELSE
   PopUp = 1

PopUpBiff = Value( 'POPUPBIFF', ,'OS2ENVIRONMENT' )
/*  If = YES then notify of incoming mail via PMPOPUP  */

/*  Is it POPCLIEN.EXE (FAT) or POPCLIENT.EXE (HPFS)?  */
PopClient = SysSearchPath( 'PATH', 'popclient.exe')
IF (PopClient = '') THEN
   PopClient = SysSearchPath( 'PATH', 'popclien.exe')
IF (PopClient = '') THEN DO
    IF (PopUp) THEN
        "@start" PopupExe "Could not find POPCLIENT executable."
    ELSE
        SAY 'Could not find POPCLIENT executable.'
    EXIT
END

IF (Mailer='U') THEN DO
    mda_path = 'UMAILER.EXE'
    mda_args = '-dest' inbasket '-to $u'
END
ELSE IF (Mailer='E') THEN DO
    mda_path = 'filter.exe'
    mda_args = '-u' loginname
END
ELSE DO
    mda_path = value('COMSPEC',,'OS2ENVIRONMENT')
    mda_args = '/C LaMailer.cmd -dest' inbasket '-to $u'
END

/**********************************************************************
   When mail arrives, popclient runs the mail delivery agent
   specified by MDA_PATH with arguments MDA_ARGS.  This
   sets the environment to the correct MDA.
**********************************************************************/
rc = Value('MDA_PATH',mda_path,'OS2ENVIRONMENT')
rc = Value('MDA_ARGS',mda_args,'OS2ENVIRONMENT')

Counter = 0
DO Until (Delay=0 | Counter>10)
    SAY Time()
/**********************************************************************
This was used to write directly to the elm mailbox, bypasing filter.
It is now obsolete.  Using filter is more stable than writing directly
to mbox; maybe someday we'll have something better than filter, too.
    IF ((Mailer='E') | (Mailer='e')) THEN
        '@'PopClient '-u' Loginname '-p' Password,
            ' -o' Inbasket Host
    ELSE
**********************************************************************/

    TmpFile = SysTempFileName( TmpDir'\PopJunk.???' )

    "@"PopClient "-u" Loginname "-p" Password OtherArgs Host "2>" TmpFile

    /* If there's an error, just beep and continue, but keep count. */
    IF rc > 1 THEN DO
        IF (PopUp) THEN
            "@start" PopupExe "POPCLID.CMD: POPCLIENT.EXE returned error(",
                               rc")"
        ELSE
            say 'POPCLID.CMD: POPCLIENT.EXE returned error ('rc')'
        /* Does user want to "hear" it?  RLW 6/5/95 */
        IF (Sound) THEN DO
            IF (mmpm & ErrorSoundFileExists) THEN
                CALL "PLAY.CMD" "File="ErrorSoundFile
            ELSE
                CALL Beep 400, 500
            END
        Counter = Counter + 1
        END
    ELSE
        Counter = 0

    NumMsgs = 0
    Line = Linein( TmpFile )
    Line = Linein( TmpFile )
    CALL Lineout TmpFile
    "@type" TmpFile
    CALL SysFileDelete TmpFile
    PARSE Value(Line) WITH 1 NumMsgs 'messages'
    IF (NumMsgs > 0) THEN DO
        IF (PopUp & (Translate(PopUpBiff)='YES')) THEN
            "@start" PopupExe "You have" NumMsgs"new messages."
        ELSE
            SAY "You have" NumMsgs"new messages."
        /* Does user want "hear" about newmail RLW 6/5/95 */
        IF (Sound & NewMailSoundFileExists) THEN 
            CALL "PLAY.CMD" "File="NewMailSoundFile
        ELSE IF (Sound) THEN DO
            CALL Beep 200, 100
            CALL Beep 400, 200
            END
    END

    /* wait for a specified number of seconds */
    CALL SysSleep Delay

IF (Counter>1) THEN DO
    IF (PopUp) THEN
       "@start" PopupExe "POPCLID.CMD aborted with too many errors."
    ELSE
        say 'POPCLID.CMD aborted with too many errors.'
    END
END

halt:
   exit

GetArg:
/**********************************************************************
    Parse arguments
**********************************************************************/
PARSE ARG Args
PARSE Value(Args) WITH Args '-o' otherargs
PARSE Value(Args) WITH  1 '-h' host .       1 '-l' loginname .      ,
    1 '-p' password .   1 '-d' delay .      1 '-b' inbasket .       ,
    1 '-m' mailer .     1 '-u' user .       1 '-s' sound .          ,
    1 '-n' newmailsoundfile .               1 '-e' errorsoundfile .

host      = ArgCheck( host, 'POPHOST', '' )
loginname = ArgCheck( loginname, 'POPUSER', '' )
password  = ArgCheck( password, 'POPPASS', '' )
delay     = ArgCheck( delay, 'POPDELAY', '0' )
inbasket  = ArgCheck( inbasket, 'INBASKET', '.' )
mailer    = Translate( Left( ArgCheck( mailer, 'MDA_PROG', 'LAMAIL' ), 1 ) )
user      = ArgCheck( user, 'USER', 'root' )
/*  Added for Sound capability  RLW 6/5/95 */
sound     = Translate( Left( ArgCheck( sound, 'POPSOUND', 'NO' ), 1 ) )
newmailsoundfile = ArgCheck( newmailsoundfile, 'NEWMAILSOUNDFILE', '' )
errorsoundfile = ArgCheck( errorsoundfile, 'ERRORSOUNDFILE', '' )

IF ((host='') | (loginname='') | (password='')) THEN SIGNAL HELP
RETURN

ArgCheck:
/**********************************************************************
    Check whether the arg was passed; if not get from OS/2 env var; if
    that's empty, use default.
**********************************************************************/
PARSE ARG RexxVar, OS2Var, Default
IF (RexxVar = '') THEN DO
   RexxVar = value(OS2Var,,'OS2ENVIRONMENT')
   IF (RexxVar = '') THEN
      RexxVar = Default
END
RETURN RexxVar

Help:
/**********************************************************************
    This gets displayed if required parms are missing or if -? is a
    parm.
**********************************************************************/
SAY ''
SAY 'PopCliD: OS/2 frontend for Carl Harris'' popclient'
SAY '   by Claudio Fahey and Clark Gaylord'
SAY ' '
SAY 'Usage:'
SAY 'popclid -h pophost -l loginname -p password [-d delay] [-b inbasket]'
SAY '           [-m L|U|E] [-u user] [-n NewMailSound] [-e ErrorSound]'
SAY '           [-o otherargs]'
SAY ' '
SAY 'The following environment variables can be used:'
SAY '   POPHOST  for pophost'
SAY '   POPUSER  for loginname'
SAY '   POPPASS  for password'
SAY '   POPDELAY for delay, defaults to 0, i.e., retrieve mail once only'
SAY '   INBASKET for inbasket, defaults to current directory, should be'
SAY '            SERVER''s inbox for UltiMail Lite, incoming mbox for Elm.'
SAY '   MDA_PROG LaMail, Ultimail, or Elm; only first letter significant'
SAY '   USER     for Ultimail inbasket, defaults to root.'
SAY '   L|U|E    for LaMail (default), Ultimail, or Elm'
/* Follow added to describe MMPM options  RLW 6/5/95 */
SAY '   POPSOUND for making noise on errors and new mail'
SAY '   NEWMAILSOUNDFILE for specifing which sound file to play on new mail'
SAY '   ERRORSOUNDFILE for specifing which sound file to play on error'
EXIT

PlaySoundFile: Procedure
/**********************************************************************
    Routine to "play" a WAV file from REXX using MMPM/2   RLW 6/5/95 
    Even though we don't use this anymore, I'm keeping it in for 
    future generations.     CKG
**********************************************************************/
   Parse Arg FileName
   if FileName='' then return
   if Stream(FileName,'c','query exist')='' then return
   Call mciSendString 'open waveaudio alias sound wait'
   Call mciSendString 'set sound time format ms wait'
   Call mciSendString 'load sound' FileName 'wait'
   Call mciSendString 'play sound wait'
   Call mciSendString 'close sound wait'
   call mciRxExit
Return

mciSendString: Procedure
/* Helper routine for playing WAV files RLW 6/5/95 */
   Parse Arg string
   if string='' then return
   rc = mciRxSendString(string, 'RetStr', '0', '0')
return

FlushQueue: Procedure
/**********************************************************************
   Flush the REXX queue.   CKG
**********************************************************************/
    DO While (Queued() > 0)
        PULL null
    END
    RETURN

Changed:
/**********************************************************************
   These lines are only for reference; the program never gets here.   
   CKG
**********************************************************************/
/*********************************************************/
/* Edit the following lines to configure this program:   */
/*********************************************************/
host = 'pop.server'                 /* POP host name                */
loginname = 'loginnameonpop'        /* Login name on the host       */
password = 'password'               /* Password on the host         */
delay = 600                         /* Seconds between mail checks  */
