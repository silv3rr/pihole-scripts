# Pi-Hole Scripts

### [pihole.bat](pihole.bat) - Simple Windows Batch file wrapper for Pi-Hole API

Calls Pi-Hole API with cURL (or alternative) using options below.
It just adds the option to URL so if there are new API options in the
future which are not listed below they should also work.

- Requires "curl" and optionally "jq" (available from [Chocolatey.org](http://chocolatey.org)).
- If curl (and/or jq) cant be found it'll try to use wget or powershell.

Set "`auth=`" to your API Token. Get it from: http://pi.hole/admin > Login > Settings

USAGE: 

  `pihole.bat enable|disable [0|10|30|300|N]` ( 0=perm, default=10 seconds )

EXAMPLE: 

  `pihole.bat disable 60`

MORE OPTIONS: 

  `status type version summary summaryRaw recentBlocked overTimeData10mins`
  `topItems getQuerySources getForwardDestinations getQueryTypes getAllQueries` 
  
  ( ^ options on the first row do not require api token )
