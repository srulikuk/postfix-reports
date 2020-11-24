# postfix-reports
Automated reports from postfix log files using pflogsumm to generate daily / weekly / monthly reports and email a report summary.

pflogsumm must be installed for it to work.  

Optional reporting for amavis, `logwatch` must be installed, to enable this report set the var `run_logwatch` to `1` in the vars file.

The script will gather the mail logs which contain the period of the report and concatenate then into a single file for pflogsumm.

The daily email reports help easily identify legitimate senders blocked by RBLDNS services so you can take action.

Uses python to send the email summary (send.py file).



**IMPORTANT:**  
All the configurable parameters for the bash script are set in `report.vars` file, it's advisable to copy it to `lc_report.vars` (prefix `'lc_'` is in `.gitignore`) so the the configured parameters do not get overwritten when executing a git stash / pull.  

Same applies to `send.py`, copy it to `lc_send.py` to ensure it does not get overwritten **and crucially not to push changes to git as it contains mailserver user/pass**.  


**USAGE:**  
Call the script with argument `daily / weekly / monthly` for the type of report required.  

  - `daily` will generate a report for yesterday (the date cannot be set, its always yesterday)
  - `weekly` will generate a report for last week (*previous week Monday at 00:00:00 until Sunday 23:59:59*)
  - `monthly` will generate a report for last month (*first day of previous month at 00:00:00 until last day of month 23:59:59*)


**CRONTAB:**  
*Use the following in your crontab to run all three report types.*
```bash
0 8 * * * /<path>/postfix-reports/report.sh daily # every day at 08:00
0 1 * * 0 /<path>/postfix-reports/report.sh weekly # every Monday at 01:00
0 2 1 * * /<path>/postfix-reports/report.sh monthly # first day of each month at 02:00
```  

#### Example email report.
___
```
daily Mail report:
------------------
   Report period: 2020-11-19
   Server Name:   mail.example.tld
   Server IP:     x.x.x.x
   WAN IP:        x.x.x.x

 Log files path
 ---------------
   Summary log:   /var/log/pflogs/daily/2020-11-19_summary.log

Grand Totals
------------
messages

   1564   received
   1600   delivered
      0   forwarded
     16   deferred  (272  deferrals)
      0   bounced
    303   rejected (15%)
      0   reject warnings
      0   held
      0   discarded (0%)

 520627k  bytes received
    515m  bytes delivered
    353   senders
    229   sending hosts/domains
     71   recipients
     35   recipient hosts/domains


1 Bad Logins
------------
         1   unknown[x.x.x.x]: SASL PLAIN authentication failed: auth...


message deferral detail
-----------------------
  local (total: 262)
       262   alias database unavailable
  smtp (total: 10)
        10   lost connection with redacted.com[x.x.x.x] while receiving...

message bounce detail (by relay): none

message reject detail
---------------------
  RCPT
    blocked using all.spamrats.com (total: 1)
           1   falemais.net.br
    blocked using b.barracudacentral.org (total: 27)
           2   bm-hc.com
           2   softbox.co.in
           2   host-82-185-180-134.business.telecomitalia.it
           1   rjinternet.net.br
           1   dingqugame.com
           1   myvzw.com
           1   restel.com
           1   tanggera.com
           1   connect.com.fj
           1   78-1-135-119.adsl.net.t-com.hr
           1   host-80-21-190-42.business.telecomitalia.it
           1   emailsendingeasy.net
           1   mailgun.net
           1   neolane.net
           1   tagmaindia.net
           1   totalplay.net
           1   brain.net.pk
           1   89-64-51-17.dynamic.chello.pl
           1   apn-31-0-1-6.dynamic.gprs.plus.pl
           1   titaniumrelayjoopyter.pro
           1   inet.co.th
           1   amebusinesstraining.co.uk
           1   ip204.ip-51-81-126.us
           1   anteldata.net.uy
    blocked using bl.spamcop.net (total: 5)
           1   acemsrvc.com
           1   constantcontact.com
           1   mail.thevalentin.info
           1   inmoo.net
           1   ukeyeopeners.co.uk
    blocked using dnsbl.justspam.org (total: 14)
           3   ryanairemail.com
           1   acemsc2.com
           1   confirmedcc.com
           1   constantcontact.com
           1   createsend.com
           1   exacttarget.com
           1   biz-constant.email
           1   chtah.net
           1   mcdlv.net
           1   mcsv.net
           1   perfora.net
           1   secureserver.net
    blocked using ix.dnsbl.manitu.net (total: 1)
           1   tiersunk.net
    cannot find your hostname (total: 153)


message reject warning detail: none

message hold detail: none

message discard detail: none

smtp delivery failures: none

Fatal Errors: none

Panics: none

Master daemon messages: none



--------------------- Amavisd-new Begin ------------------------

      7   Miscellaneous warnings

  10711   Total messages scanned ------------------  100.00%
  4.059G  Total bytes scanned                  4,358,591,053
========   ==================================================

   1423   Blocked ---------------------------------   13.29%
   1423     Spam blocked                              13.29%

   9288   Passed ----------------------------------   86.71%
    208     Spammy passed                              1.94%
     94     Bad header passed                          0.88%
   8986     Clean passed                              83.90%
========   ==================================================

   1631   Spam ------------------------------------   15.23%
    208     Spammy passed                              1.94%
   1423     Spam blocked                              13.29%

   9080   Ham -------------------------------------   84.77%
     94     Bad header passed                          0.88%
   8986     Clean passed                              83.90%
========   ==================================================

      4   MIME error
   1135   Extra code modules loaded at runtime
      4   SpamAssassin diagnostics

==================================================================================
Spam Score Percentiles        0%       50%       90%       95%       98%      100%
----------------------------------------------------------------------------------
Score Ham (9080)         -22.018    -1.899     0.268     1.403     3.616     6.179
Score Spam (1631)          5.257    12.274    19.839    24.070    25.955    45.596
==================================================================================

======================================================================================================
Spam Score Frequency      <= -10     <= -5      <= 0      <= 5     <= 10     <= 20     <= 30      > 30
------------------------------------------------------------------------------------------------------
Hits (10711)                 321       698      6888      1133       574       938       144        15
Percent of Hits            3.00%     6.52%    64.31%    10.58%     5.36%     8.76%     1.34%     0.14%
======================================================================================================


---------------------- Amavisd-new End -------------------------

```
___
#### (Amavisd-new report is only included if logwatch is installed and its enabled in the vars file)
