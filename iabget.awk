#!/data/project/farotbot/local/bin/gawk -bE

# The MIT License (MIT)
#
# Copyright (c) 2017 by User:Green Cardamom (at en.wikipedia.org)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,         
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

@include "getopt.awk"
@include "readfile"
@load "filefuncs"

BEGIN {

 # SETUP BEGIN

  # Directory where iabget is located w/ trailing slash

  Home = "/data/project/farotbot/bin/"

  # External programs. Add full path if needed
  #  If script is called from cron a full path is recommended

  Exe["timeout"] = "/usr/bin/timeout"
  Exe["wget"] = "/usr/bin/wget"
  Exe["jq"] = "/usr/bin/jq"
  Exe["rm"] = "/bin/rm"
  Exe["awk"] = "/data/project/farotbot/local/bin/gawk"
  Exe["php"] = "/usr/bin/php"

  # Default wiki language

  lang = "en"

  # Turn on/off debugging (1 = on)

  debug = 0

  # Setup OAuth Secrets and Keys 
  #
  #  Login to https://meta.wikimedia.org with the userid the script will be using
  #  If the userid is new and doesn't have Confirmed user permissions, apply for it in two places:
  #    enwiki: Wikipedia:Requests for permissions/Confirmed 
  #    meta  : https://meta.wikimedia.org/wiki/Steward_requests/Miscellaneous
  #  Apply for a OAuth consumer owner-only registration:
  #    https://meta.wikimedia.org/wiki/Special:OAuthConsumerRegistration/propose
  #     . Check the box "This consumer is for use only by.."
  #     . IP Ranges and Public RSA Key should be left empty 
  #  Add the provided Keys and Secrets below

  # Oauth Keys and Secrets 
  consumerKey = ""
  consumerSecret = ""
  accessKey = ""
  accessSecret = ""

  # String included with http requests shows in remote logs. Include name of program and your contact info.

  Agent = "http://en.wikipedia.org/wiki/User:FARotBot"

 # SETUP END

  IGNORECASE = 1
  TIMEOUT = Exe["timeout"] " 40s " 
  Exe["phpGenerateHeader"] = Exe["php"] " " Home "MWOAuthGenerateHeader.php"
  Exe["phpDecodePayload"]  = Exe["php"] " " Home "MWOAuthDecodePayload.php"

  cookiejar = Home "cookieiabget"
  # cookiejar = "/tmp/cookiejar"
  if(!exists(cookiejar))
    cookieopt = " --save-cookies=\"" cookiejar "\""
  else 
    cookieopt = " --save-cookies=\"" cookiejar "\" --load-cookies=\"" cookiejar "\""
  
  # Default wget options (include lead/trail spaces)

  Wget_opts = cookieopt " --ignore-length --user-agent=\"" Agent "\" --no-check-certificate --tries=5 --timeout=120 --waitretry=60 --retry-connrefused "

  main()

}

function main() {

  while ((C = getopt(ARGC, ARGV, "wehd:r:a:l:p:o:f:j:")) != -1) {
    opts++
    if(C == "l")                                     # -l <language>       Wiki language code. Default = en 
      lang = verifyval(Optarg)
    if(C == "r")                                     # -r <offset>         Page offset number of multi-page requests
      pagenumber = verifyval(Optarg)
    if(C == "a")                                     # -a <action code>    Action to make (see API doc for names)
      action = verifyval(Optarg)   
    if(C == "p")                                     # -p <parameter>      Parameter=value string (see API doc for names)
      parameter = verifyval(Optarg)   
    if(C == "f")                                     # -f <filename>       Postdata filename (used with -a submitbotjob)
      postfile = verifyval(Optarg)   
    if(C == "j")                                     # -j <id>             Job ID (returned by -a submitbotjob)
      jobid = verifyval(Optarg)
    if(C == "d")                                      # -d                 Turn on debugging
      debug = verifyval(Optarg)
    if(C == "e")                                      # -e                 Send error msg to stdout (default: stderr)
      stdOut = 1
    if(C == "w")                                      # -w                 Show raw JSON instead of select CSV
      rawJSON = 1
    if(C == "o")                                      # -o                 Original URL -- dummy parameter used by imp
      origurl = verifyval(Optarg)
    if(c == "h") {
      help()
      exit
    }
  }

  if(opts < 1) {
    print "Error: no opts"
    help()
    exit
  }
  if(empty(action)) {
    print "Error: Must specify -a option\n"
    help()
    exit
  }

  if(debug == 2)
    db = " -d "

  identifyURL = "https://" lang ".wikipedia.org/w/index.php?title=Special:OAuth/identify"
  iabotURL = "https://tools.wmflabs.org/iabot/api.php"

  if(! loginMediaWiki()) {
    print "Error: Unable to login to MediaWiki"
    exit
  }

  if( ! empty(pagenumber) ) {
    if(pagenumber ~ /[+]$/) {
      gsub(/[+]$/,"",pagenumber)
      pageplus = 1
    }
  }

  parameter = encodeParams(parameter)

  if(action == "searchurlfrompage") 
    searchurlfrompage()
  if(action == "searchpagefromurl") 
    searchpagefromurl()
  if(action == "searchurldata") 
    searchurldata()
  if(action == "modifyurl") 
    modifyurl()
  if(action == "submitbotjob") 
    botjob(postfile)
  if(action == "getbotjob")
    getbotjob(jobid)

}

function help() {
   print ""
   print " iabapi - InternetArchiveBot API command-line interface\n"
   print "           -a     <action>         Action (see API doc): "
   print "                                     searchpagefromurl"                
   print "                                     searchurlfrompage"                
   print "                                     searchurldata"
   print "                                     modifyurl"
   print "                                     submitbotjob (use w/ -f not -p)"
   print "                                     getbotjob"
   print "           -p     <parameter>      Parameter=value string (see API doc)."
   print "                                     Separating & between paramters should be {&} to disambig from & in URLs"
   print "                                     eg. -p \"urlid=55{&}archiveurl=http://..\""
   print "           -f     <filename>       Filename containing the postdata encoded"
   print "           -r     <pagenumber>     Show results for this page number only (optional)"
   print "                                     Use a plus sign eg. -r 2+ to continue downloading until end"
   print "           -l     <language>       Wiki language code (default: en)"
   print "           -d     <level>          Turn on debugging. 1 = level1 2 = level2"
   print "           -e                      Send error msgs to stdout (default: stderr)"
   print "           -w                      Show raw JSON"
   print "           -h                      help"
   print ""
   print " API doc: https://meta.wikimedia.org/wiki/InternetArchiveBot/API"
   print " IABot  : https://tools.wmflabs.org/iabot/index.php"
   print " GreenC : https://tools.wmflabs.org/iabot/index.php?page=metausers&username=GreenC+bot"
   print ""
}

#
# Return list of link IDs in article ID
#
#   To get article ID: https://en.wikipedia.org/w/api.php?action=query&titles=Albert%20Einstein&prop=info
#
function searchurlfrompage(  pn,oheader,wgetcommand,jqcommand) {

  if(parameter !~ /pageids[=]/) {
    print "Error: Parameter required: pageids"
    exit
  }
  if( ! empty(pagenumber)) 
    pn = "offset=" pagenumber "&"

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote(pn "action=searchurlfrompage&" parameter) " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)  
  jqcommand = Exe["jq"] " -r '.urls | map([.id, .url, .live_state, .archive, .snapshottime, .accesstime] | join(\" \")) | join(\"\\n\")' " 
  coreReader(wgetcommand, jqcommand, oheader)

}

#
# Return list of article names containing a url or urlid
#
function searchpagefromurl(  pn,oheader,wgetcommand,jqcommand) {

  if(parameter !~ /url[=]|urlid[=]/) {
    print "Error: Parameter required: url or urlid"
    exit
  }
  if( ! empty(pagenumber)) 
    pn = "offset=" pagenumber "&"

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote(pn "action=searchpagefromurl&" parameter) " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)  
  jqcommand = Exe["jq"] " -r '.pages [] |.page_title' | " Exe["awk"] " '{gsub(/_/,\" \", $0); print $0}'"  
  coreReader(wgetcommand, jqcommand, oheader)

}

#
# Return URL data in <space> separated CSV format: id url livestate archiveurl snapshotYMD snapshotTime accesstime
#  1 line for each record.
#
function searchurldata(  pn,oheader,wgetcommand,jqcommand) {

  if(parameter !~ /urls[=]|hasarchive[=]|urlids[=]|livestate[=]|isarchived[=]|reviewed[=]/) {
    print "Error: Parameter required: urls, hasarchive, urlids, livestate, isarchived, reviewed"
    exit
  }
  if( ! empty(pagenumber)) 
    pn = "offset=" pagenumber "&"

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote(pn "action=searchurldata&" parameter) " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)   
  jqcommand = Exe["jq"] " -r '.urls | map([.id, .url, .live_state, .archive, .snapshottime, .accesstime] | join(\" \")) | join(\"\\n\")' " 
  coreReader(wgetcommand, jqcommand, oheader)

}

#
# Write data to IAB
#
function modifyurl(  oheader,wgetcommand,op) {

  if(parameter !~ /urlid[=]/) {
    print "Error: Parameter required: urlid"
    exit
  }

  if( empty(Checksum) || empty(CSRF) ) 
    getTokensFresh()
  
  parameter = parameter "&token=" CSRF "&checksum=" Checksum

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote("action=modifyurl&" parameter ) " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)   
  op = getAPIpage(wgetcommand)

  if(sys2varPipe(op, Exe["jq"] " -r '. .result'") == "success") {
    if(rawJSON) print op
    return
  }
  else {
    if(rawJSON) 
      print op
    else 
      stdErrO("Error: Unable to post data.")
    return
  }
  
}

#
# Submit bot job
#
function botjob(postfile,  p,oheader,wgetcommand,op) {

  if( empty(postfile) ) {
    print "Error: Unknown -f postfile" 
    exit
  }
  if( ! exists(postfile) ) {
    print "Error: Unable to find postfile: " postfile
    exit
  }

  if( empty(Checksum) || empty(CSRF) ) 
    getTokensFresh()

  p = readfile(postfile)
  if(empty(strip(p))) return
  p = "action=submitbotjob{&}token=" CSRF "{&}checksum=" Checksum "{&}pagelist=" p
  p = encodeParams(p)
  gsub(/(%0A){0,}$/,"",p)                            # Remove trailing \n ie. %0A an artifact of unix files always end with \n
  printf("%s", p) > postfile ".wget"
  close(postfile ".wget")

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-file=" shquote(postfile ".wget") " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)   

  op = getAPIpage(wgetcommand)

  if(sys2varPipe(op, Exe["jq"] " -r '. .result'") == "success") {
    if(rawJSON) 
      print op
    else {
      print "success " sys2varPipe(op, Exe["jq"] " -r '. .id'")  # Print 'sucess 56878' where the number is a job ID
    }
    return
  }
  else {
    if(rawJSON) 
      print op
    else 
      stdErrO("Error: Unable to submit job.")
    return
  }
  
}

#   
# Get bot job info.                    
#
#   Returns status only unless used with -w then full json                                               
#
function getbotjob(id,  oheader,wgetcommand,jqcommand) {

  if(parameter !~ /id[=]/) {
    print "Error: Parameter required: jobid"
    exit
  }       

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data=" shquote("action=getbotjob&" parameter) " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(oheader) " -q -O- " shquote(iabotURL)
  jqcommand = Exe["jq"] " -r '. .status' "
  coreReader(wgetcommand, jqcommand, oheader)

}         

#
# Core routine to download read results, handle paging
#
function coreReader(wgetcommand, jqcommand, oheader,    op, jsonfile, orig,dest) {

  if(empty(parameter)) {
    print "Error: parameter=value string required. See docs."
    exit 
  }

 # Get the first page of results starting at pagenumber (default: 1)

  op = getAPIpage(wgetcommand)

  if(debug == 1)
    print op

  if(op ~ /The requested query didn't yield any results/) {
    stdErrO("Error: No results found.")
    exit
  }

  if(rawJSON)
    print op
  else
    print sys2varPipe(op, jqcommand)

 # Exit if it was the only page or single pagenumber request. But keep going if there is a "+" 

  if(empty(Continue) || (! empty(pagenumber) && empty(pageplus) ) ) 
    return

 # Display to stderr page number working on

  if( ! empty(pagenumber) && ! empty(pageplus) ) 
    stdErr("Offset " Continue " ", "n")
  else
    stdErr("Offset " Continue, "n") 

  delayer() # be nice on large requests

 # Get rest of pages 

  while( ! empty(Continue) ) {

   # Build proper "offset=<string>" 
    if(match(wgetcommand, /[-][-]post[-]data[=]'offset[=][^&]*[^&]/, dest)) {
      orig = dest[0]
      gsub(/offset[=][^$]*$/, "offset=" Continue, dest[0])
      wgetcommand = subs(orig, dest[0], wgetcommand)
    }
    else if(match(wgetcommand, /[-][-]post[-]data[=]'action[=]/, dest)) {
      orig = dest[0]
      wgetcommand = subs(orig, "--post-data='offset=" Continue "&action=", wgetcommand)
    }

   # Freshen header
    if(index(wgetcommand, oheader) > 0) 
      wgetcommand = freshHeader(wgetcommand)
      
    op = getAPIpage(wgetcommand)

    if(rawJSON)
      print op
    else
      print sys2varPipe(op, jqcommand)

    if(! empty(Continue) ) {
      stdErr("Offset " Continue " ", "n") 
      delayer() # be nice on 1000-record requests
    }
    else {
      stdErrO("Error: Continue code not found. End of data? See JSON " jsonfile)
      bell()
      exit
    }
  }
}


#
# Main loop to get API result
#
function getAPIpage(command,   op, i,j,k) {

  # print sys2var("date") > "/dev/stderr"

  Continue = ""
  gsub(/\\n/,"\n",command)

  if(debug == 1) 
    print "\nCOMMAND = " command

  op = sys2var("timeout 40s " freshHeader(command))

 # Try up to j times 
  j = 5
  k = j + 1
  for(i = 1; i < k; i++) {
    if(op ~ /csrf["][ ]*[:][ ]*["][^}]*[}]$/) break
    if(i == j && op !~ /csrf["][ ]*[:][ ]*["][^}]*[}]$/) {
      stdErr(op) 
      stdErrO("Error: JSON or auth problem. Aborted. ")
      bell()
      exit
    }
    stdErr(" API retry " i)

    if(! loginMediaWiki()) {
      print "Error: Unable to login to MediaWiki"
      exit
    }

    if(op !~ /csrf["][ ]*[:][ ]*["][^}]*[}]$/) {
      op = sys2var("timeout 40s " freshHeader(command) )
      op = getAPIpageTimeout(command, op, "Timeout connecting to API (" i "). Aborted.", i)
    }
  }

  Continue = getContinue(op)  
  getTokensJSON(op)

  return op

}

#
# Loop to retry if API returns blank (timeout)
#
function getAPIpageTimeout(command, op, errmsg, loc,   i, timo) {

  for(i = 2; 1 < 6 ; i++) {
    if(! empty(op)) break
    if(i == 5 && empty(strip(op)) ) {
      if(loc >= 5) {
        stdErrO("Error: " errmsg)
        bell()
        exit
      }
      else
        return ""
    }

    if(i == 3) gsub("timeout 40s", "timeout 60s", command)
    if(i == 4 && loc < 4) gsub("timeout 60s", "timeout 90s", command)
    if(i == 4 && loc >= 4) gsub("timeout 60s", "timeout 900s", command)

    match(command, /[ ][0-9]{2,3}s[ ]/, timo)

    if(empty(strip(op))) {
      sleep(1)
      stdErr("  Timeout try " (i - 1) " (API retry=" loc ", timeout=" strip(timo[0]) ")")
      command = freshTokens(freshHeader(command))
      op = sys2var(command)

      if(debug == 1) 
        print "\nCOMMAND = " command
    }
  }
  return op

}

#
# Get continue code from API JSON result
#
function getContinue(s,  dest) {

  match(s, /"continue"[ ]*[:][ ]*"[^"]*"/, dest)
  if( ! empty(dest[0]) ) {
    gsub(/^"continue"[ ]*[:][ ]*"/,"",dest[0])
    gsub(/"$/,"",dest[0])
    return strip(dest[0])
  }
  return ""
}


#
# Generate OAuth header
#
function oauthHeader(  command, sp) {
  command = Exe["phpGenerateHeader"] " " shquote(consumerKey) " " shquote(consumerSecret) " " shquote(accessKey) " " shquote(accessSecret) " " shquote(identifyURL) 
  sp = sys2var(command)
  return sp  
}

#
# Add a fresh header to existing wget command string
#
function freshHeader(command,  dest) {

  # --header='Authorization .. '
  if(match(command, /[']Authorization[^']*[']/, dest) > 0) {
    newhead = "'" strip(oauthHeader()) "'"
    return subs(dest[0], newhead, command)
  }
  return command
}

#
# Add fresh Checksum and CSRF to existing wget command string
#
function freshTokens(command  ,s, dest) {

 # "&token=" CSRF "&checksum=" Checksum
  if(command ~ /[&]checksum[=]/ && command ~ /[&]token[=]/) {

    getTokensFresh()

    match(command, /[&]token[=][^&']*[^&']/, dest)
    s = dest[0]
    gsub(/^[&]token[=]/, "", s)
    s = "&token=" CSRF
    command = subs(dest[0], s, command)
    
    match(command, /[&]checksum[=][^&']*[^&']/, dest)
    s = dest[0]
    gsub(/^[&]checksum[=]/, "", s)
    s = "&checksum=" Checksum
    command = subs(dest[0], s, command)
    
  }

  return command

}

#
# Get Checksum and CSRF tokens with a fresh request
#
function getTokensFresh() {

  oheader = strip(oauthHeader())
  wgetcommand = TIMEOUT Exe["wget"] Wget_opts db " --post-data='action=noaction' --header='Content-Type: application/x-www-form-urlencoded' --header='" oheader "' -q -O- '" iabotURL "'"  
  jqcommand = Exe["jq"] " -r '.arguments | map([.checksum, .csrf] | join(\" \")) | join(\"\\n\")' " 

  op = getAPIpage(wgetcommand)

  if(debug == 1)
    print op

}

#
# Get Checksum and CSRF from existing JSON 
#
function getTokensJSON(op  ,jqcommand, jsonfile) {

  jqcommand = Exe["jq"] " -r '. .checksum' "
  Checksum = sys2varPipe(op, jqcommand)
  jqcommand = Exe["jq"] " -r '. .csrf' "
  CSRF = sys2varPipe(op, jqcommand)

}

#
# Log into MediaWiki
#
function loginMediaWiki(  command, sp, payload) {

  return 1  # informed by Cyberpower678 this is not needed since the API handles MW login

  command = TIMEOUT Exe["wget"] Wget_opts db " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(strip(oauthHeader())) " -q -O- " shquote(identifyURL) 
  sp = sys2var(command)
  payload = decryptIABot(sp)
  if( ! empty(payload) )
    return 1
  else
    return 0  
}

#
# Decrypt payload
#
function decryptIABot(s,   command, sp) {
  if( ! empty(s) > 0) {
    command = Exe["phpDecodePayload"] " " shquote(consumerSecret) " " shquote(s) 
    sp = sys2var(command)
    if(sp ~ /Invalid identify response/)  # error by MWOAuthDecodePayload.php
      return ""
    return sp
  }
  return ""
}


#
# URL encode paramters but not the separating '&' or '=' or '\n', and only params that use string values 
#
function encodeParams(s ,c,i,fields,sep) {

  c = patsplit(s, fields, /[{][&][}]/, sep)
  if(c == 0) 
    s = encodeParamsHelper(s)
  else {
    while(i++ < c) 
      sep[i] = encodeParamsHelper(sep[i])
    if(! empty(sep[0]) ) 
      sep[0] = encodeParamsHelper(sep[0])
    s = unpatsplit(fields, sep)
  }
  s = gsubs("{&}","&",s)
  return s
}
function encodeParamsHelper(s ,j,fieldnew,a,dest) {

  j = split(s, a, "=")
  if(a[1] ~ /reason|urls|url|archiveurl|fplist|pagesearch|pagelist/) {
    if(match(s, a[1] "=", dest) > 0) {
      fieldnew = s
#      fieldnew = urlencodeawk(urldecodeawk(gsubs(dest[0], "", fieldnew)))
      fieldnew = urlencodeawk(gsubs(dest[0], "", fieldnew))
      fieldnew = gsubs("%5Cn","\n", fieldnew)
      s = dest[0] fieldnew
    }
  }
  return s
}


# [____________________ UTILITIES ________________________________________________________________]

# 
# Run a system command and store result in a variable     
#   eg. googlepage = sys2var("wget -q -O- http://google.com")
# Supports pipes inside command string. Stderr is sent to null.             
# If command fails (errno) return null               
#
function sys2var(command        ,fish, scale, ship) {

         # command = command " 2>/dev/null"
         while ( (command | getline fish) > 0 ) {
             if ( ++scale == 1 )
                 ship = fish
             else
                 ship = ship "\n" fish
         }
         close(command)
         system("")
         return ship
}

#
# Supports piping data into a program eg, echo <data> | <command>
#
function sys2varPipe(data, command,   fish, scale, ship) {

         print data |& command
         close(command, "to")   

         while ( (command |& getline fish) > 0 ) {
             if ( ++scale == 1 )
                 ship = fish
             else
                 ship = ship "\n" fish
         }
         close(command)
         return ship
}

#
# Percent encode a string for use in a URL
#  Credit: Rosetta Code May 2015
#  GNU Awk needs -b to encode extended ascii eg. "ł"
#
function urlencodeawk(str,  c, len, res, i, ord) {

        for (i = 0; i <= 255; i++)
                ord[sprintf("%c", i)] = i
        len = length(str)             
        res = ""
        for (i = 1; i <= len; i++) {
                c = substr(str, i, 1);
                if (c ~ /[0-9A-Za-z]/)
                        res = res c
                else
                        res = res "%" sprintf("%02X", ord[c])
        }
        return res
}

#  
# Strip leading/trailing whitespace                 
#
function strip(str, opt) {
       return gensub(/^[[:space:]]+|[[:space:]]+$/,"","g",str)
}

#
# Return 0 if string is 0-length      
#
function empty(s) {                
  if(length(s) == 0)
    return 1
  return 0
}                 

# A helper function to subs()
function insert_subs(str,spos,len,newstr) {
        return substr(str,1,spos-1) newstr substr(str,spos+len)
}  

# subs is like sub, except that no regular expression handling is done
function subs(pat,rep,str,        t) {
        if (str == "") return
        if(t = index(str,pat)) {
          return insert_subs(str,t,length(pat),rep)
        }
        else {
          return str
        }
#       return (t = index(str,pat)) ? insert_subs(str,t,length(pat),rep) : str
}                                  

# gsubs is like gsub, except that no regular expression handling is done
function gsubs(pat,rep,str) {
        while( countsubstring(str,pat) > 0) {
          str = subs(pat,rep,str)
        }
        return str        
}

#
# Reverse a patsplit()
#
function unpatsplit(field,sep,   c,o) {

  if(length(field) > length(sep)) return

  o = sep[0]
  c = 1
  while(c < length(field) + 1) {
#    print "field[" c "] = " field[c]
#    print "sep[" c "] = " sep[c]
    o = o field[c] sep[c]
    c++
  }

  return o                
}

# 
# countsubstring
#   Returns number of occurances of pattern in str.
#   Pattern treated as a literal string, regex char safe
# 
#   Example: print countsubstring("[do&d?run*d!run>run*", "run*")
#            2
# 
#   To count substring using regex use gsub ie. total += gsub("[.]","",str)
#
function countsubstring(str, pat,    len, i, c) {
  c = 0
  if( ! (len = length(pat) ) ) {
    return 0
  }
  while(i = index(str, pat)) {
    str = substr(str, i + len)
    c++
  }
  return c
}


#
# Make string safe for shell
#  print shquote("Hello' There")    produces 'Hello'\'' There'
#  echo 'Hello'\'' There'           produces Hello' There
#
function shquote(str,  safe) {
        safe = str
        gsub(/'/, "'\\''", safe)  
        gsub(/’/, "'\\’'", safe)
        return "'" safe "'"         
}

#
# Remove file
#
function removefile(str) {

      if( checkexists(str) )
        sys2var( Exe["rm"] " -- " shquote(str) )
      if( checkexists(str) ) {
        prnt("Error: unable to delete " str ", aborting.")
        exit          
      }              
      system("") # Flush buffer
}      

#
# Print some dots
#
function delayer() {
  stdErr(".","n")
  sleep(0)
  stdErr(".","n") 
  sleep(0)
  stdErr(".") 
}

#
# Ring da bell - disabled for farotbot, add one if desired
#
function bell() {
      return
      # system("/home/adminuser/scripts/bell")
      # sleep(1)
}


#
# Check for file existence. Return 1 if exists, 0 otherwise.                  
#  Requires GNU Awk: @load "filefuncs"               
#
function exists(name    ,fd) {
    if ( stat(name, fd) == -1)
      return 0
    else
      return 1
}

#
# Print to /dev/stderr
#  if flag = "n" then no newline                     
#
function stdErr(s, flag) {
  if(flag == "n")
    printf("%s",s) > "/dev/stderr"
  else  
    printf("%s\n",s) > "/dev/stderr"
  close("/dev/stderr")
}              

function stdErrO(s) {
  if(stdOut == 1)
    print s
  else
    stdErr(s)
}

# 
# Verify any argument has valid value                
#
function verifyval(val) {
  if(val == "" || substr(val,1,1) ~/^[-]/) {
    stdErrO("Command line argument has an empty value when it should have something.")
    exit
  }
  return val
}              


