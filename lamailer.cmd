/**********************************************************************
   LaMailer.cmd - Mail Delivery Agent for LaMail        
   Copyright - Anonymous Software
   J.Poltorak@bradford.ac.uk
 
   Modified by Claudio Fahey for popclient for OS/2
   e-mail: claudio@uclink.berkeley.edu
   Modified again by Clark Gaylord for popclient 2.21a
   e-mail: cgaylord@vt.edu                     
                                               
   2.21a: Add PMPOPUP support.  Use POPUPBIFF environment variable.
            If POPUPBIFF='YES' and pmpopup.exe is in the path, then
            pop up a message about incoming mail.
   2.21b: Unique file name (thanks to Mike Baum, baum@micf.nist.gov)
          Escape '&' in 'from' and 'subject' before calling pmpopup
   2.21c: Handle multi-line from: and subject: per Mike Baum.
   2.21d and e: No changes to LaMailer.cmd
   2.21f: Take out POPUPBIFF support; this is now part or PopCliD.cmd
**********************************************************************/

call RxFuncAdd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
call SysLoadFuncs

parse arg '-dest ' maildir ' -to ' to
/* 'To' is not used. */

date = date('o')
time = time()
mailbox = maildir
inbox  = mailbox'\inbox.ndx'

/**********************************************************************
Here's where we get a unique filename.  The need to be careful was 
pointed out by Mike Baum.
We let SysTempFileName pull its weight.
**********************************************************************/
parse value date time with  2 yy'/'mon'/'dd  hh':'+1 m +1 mm':'ss
msg = SysTempFileName( mailbox'\'mon || dd || yy || hh || m'.'mm || '??' )

/**********************************************************************
I'll leave Mike's code here in case anyone wants to use it.  CKG

fexist.0 = 1
msg =  mailbox'\'mon || dd || yy || hh || m'.'mm || ss
do while fexist.0                     
    call SysFileTree msg,fexist,'F'
    if fexist.0 then do
        ss = ss + 1
        msg = mailbox'\'mon || dd || yy || hh || m'.'mm || right(ss,2,'0')
    end
end
**********************************************************************/


header_state = 1
flag. = 0           /* Work flags - building the From: or Subject: fields. */
subject = ''

do while lines() \= 0
    line=linein()
    if line = '' then header_state = 0
    if (header_state) then do
        token=word(line,1)
        if (substr(token,length(token))=':') then do
            /* If this is a header tag reset the work flags.   */
            flag. = 0
        end
        Select
            when token = 'From:' then do
                /* Start to build From: field */
                fromline = subword(line,2)      
                flag.f = 1                      
                /* Build-in-progress */ 
                end
            when token = 'Subject:' then do
                /* Start to build Subject: field */
                subject = strip(subword(line,2))
                flag.s = 1
                end
            when flag.f = 1 then
                /* Still working on From: ... */
                fromline = fromline||line
            when flag.s = 1 then
                /* Still working on Subject: ... */
                subject = subject' 'strip(line)
            Otherwise NOP
        end
    end

    call lineout msg, line
end

parse var fromline fullname '<' from '>'
if from = '' then do
    from = word(fullname,1)
    fullname = ''
end

call index
call lineout msg

/* I added this section.  CKG */
SAY 'Mail:' From Subject
SAY PopUpExe
SAY From
SAY Subject
SAY Mailbox
SAY Inbox

/* Do we want BIFF and is PMPOPUP available */
/**********************************************************************
This feature is now moved to PopCliD.cmd ... if you want a message-by-
message BIFF, then uncomment this part.  Note that you still get a list
in the text-window; I've just taken out the PMPOPUP messages.

PopUpBiff = Value('POPUPBIFF',,'OS2ENVIRONMENT')
IF (PopUpBiff = 'YES') THEN DO
    PopUpExe = SysSearchPath( 'PATH', 'pmpopup.exe')
    IF (PopUpExe\='') THEN DO
        From = RmPipe( From )
        Subject = RmPipe( Subject )
        IF (Subject = '') THEN
            "@start" PopUpExe "New mail from" From
        ELSE
            "@start" PopUpExe "New mail from" From "about" Subject
    END
END
**********************************************************************/

EXIT

index:
   nickname = copies(' ',8)
   fullname = strip(fullname)
   from = strip(from)
   parse value from with userid '@' nodename '.'
   size = copies(' ',12)
   f1 = copies(' ',8)
   seen = ' '
   from_to = ' '
   f2 = ' '
   call lineout inbox, nickname,
       left(userid,8),
       left(nodename,8),
       translate(filespec('n',msg),' ','.'),
       size,
       date,
       substr(time,1,5),
       f1,
       seen,
       from_to,
       f2,
       fullname'01'x ||subject'0101'x ||from
return

EscChar:
    PARSE ARG Needle, Haystack
    OutString = ''
    DO Until (Length(Haystack) = 0)
        IF (Pos(Needle, Haystack) > 0) THEN DO
            OutString = ,
                OutString ||,
                Left( Haystack, Pos(Needle, Haystack)-1 ) ||,
                ' ^' ||,
                Needle
            Haystack = SubStr( Haystack, Pos(Needle, Haystack)+1 )
        END
        ELSE DO
            OutString = OutString || Haystack
            Haystack = ''
        END
    end  
    Return OutString

RmPipe:
    PARSE ARG String
    String = EscChar( '&', String )
    String = EscChar( '|', String )
    String = EscChar( '>', String )
    String = EscChar( '<', String )
    Return String
