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

@load "filefuncs"

BEGIN {

  Email           = ""                                 # For notifying of errors. Set blank to disable send.
  Home            = "/data/project/farotbot/"          # Home directory of farotbot.awk with trailing slash
  BinDir          = Home "bin/"
  DataDir         = Home "data/"
  MetaDir         = Home "meta/"
  Lang            = "en"                               # wiki language site code
  StopButtonPage  = "User:FA RotBot/button"            # Location of pages on-wiki
  ExcludeListPage = "User:FA RotBot/exclude"
  IncludeListPage = "User:FA RotBot/include"
  Cats[1]         = "Category:Featured articles"       # Categories to process. Add any more here
  Cats[2]         = "Category:Featured lists"

  Exe["wget"]     = "/usr/bin/wget"
  Exe["timeout"]  = "/usr/bin/timeout"
  Exe["rm"]       = "/bin/rm"
  Exe["sleep"]    = "/bin/sleep"
  Exe["date"]     = "/bin/date"
  Exe["mkdir"]    = "/bin/mkdir"
  Exe["gzip"]     = "/bin/gzip"
  Exe["tail"]     = "/usr/bin/tail"
  Exe["mailx"]    = "/usr/bin/mailx"

  Exe["wikiget"]  = BinDir "wikiget.awk"
  Exe["iabget"]   = BinDir "iabget.awk"

  IGNORECASE      = 1         # All regex will be case insenstive
  StdOut          = 1         # Error messages to stdout (1) or stderr (0)

  TestingLimit    = 1         # Max number of articles to process. Set to 0 to disable (ie. process all articles)

  delete ExcludeA             # Create associative arrays to hold excluded and included article titles
  delete IncludeA

  delete MasterList           # Create associative array master list of articles

  main()

}

function main(  k, id) {

  if(stopbutton() == "RUN") {


   # Check last run is 'complete'

    if(! jobcompleted()) {
      stdErrO("farotbot.awk: unable to run due to last job still active")
      exit
    }

   # Create data directory for logging

    id = sys2var( Exe["date"] " +\"%m%d%H%M%S\"") substr(sys2var( Exe["date"] " +\"%N\""), 1, 5)
    rb_data = DataDir "rb-" id "/"
    if(!mkdir(rb_data)) {
      email("NOTICE: Error in farotbot: unable to create temp dir.")
      stdErrO("farotbot.awk: unable to create temp dir " rb_data)
      exit
    }

   # Get data from wiki into MasterList[]

    if(getlist("exclude") == 0) {
      stdErrO("farotbot.awk: exiting due to unable to retrieve excludelist")
      exit
    }
    if(getlist("include") == 0) {
      stdErrO("farotbot.awk: exiting due to unable to retrieve includelist")
      exit
    }
    if(getcats() == 0) {
      stdErrO("farotbot.awk: exiting due to unable to error getting categories")
      exit
    }

   # Add/subtract articles from MasterList

    includearticles()
    excludearticles()

   # Save raw postfile data from MasterList

    history(MasterList, "postfile", 1)

   # Run IABot

    iabot()

  }
  else {
    stdErrO("farotbot.awk: exiting due to stopbutton")
    exit
  }
}

#
# Run IABot
#
function iabot(   command,op,a,dest) {

  command = Exe["iabget"] " -w -a submitbotjob -f " rb_data "postfile"
  op = sys2var(command)
  print op > rb_data "json"
  close(rb_data "json")
  if(op ~ /"result"[:] "success"/) {
    if(match(op, /"id"[:] "[^\"]*"/, dest)) {
      split(dest[0], a, "\"")
      print a[4] "|" rb_data >> MetaDir "index"
      close(MetaDir "index")
    }
    else {
      email("NOTICE: Error in FARotBot unable to run IABot (1)", rb_data "json")
      stdErrO("farotbot.awk: Error running IABot.")
    }
  }
  else {
    email("NOTICE: Error in FARotBot unable to run IABot (2)", rb_data "json")
    stdErrO("farotbot.awk: Error running IABot.")
  }
}

#
# Add IncludeA[] to MasterList[]
#
function includearticles(  i) {

  for(i in IncludeA) {
    MasterList[i] = 1
  }
}

#
# Subtract ExcludeA[] from MasterList[]
#
function excludearticles(  i,j) {

  for(i in MasterList) {
    for(j in ExcludeA) {
      if(strip(i) == strip(j) )
        delete MasterList[i]
    }
  }
}

#
# Get lists of articles from categories and copy into MasterList[]
#
function getcats(  command,o,u,i,a,j,k) {

  for(i in Cats) {
    command = Exe["wikiget"] " -c " shquote(Cats[i]) " -n " shquote(Lang)
    o = o "\n" sys2var(command)
  }
  u = uniq(o)
  if( empty(strip(u))) {
    email("NOTICE: Error in farotbot: uniq returned empty result. Max lag exceeded?")
    stdErrO("farotbot.awk: uniq returned empty result. Max lag exceeded?")
    return 0
  }

 # Copy into MasterList
  if(split(u, a, "\n") > 0) {
    for(j in a) {
      MasterList[a[j]] = 1
      if(TestingLimit != 0) {
        k++
        if(k == TestingLimit) break
      }
    }
  }

 # Save copy for history
  history(MasterList, "listcats")
  print o > rb_data "wikiget"
  close(rb_data "wikiget")
  sys2var(Exe["gzip"] " " rb_data "wikiget")

  return 1

}

#
# Get include and exclude lists. Articles to be included or excluded from processing.
#
#   Note: it's good to have the existing wiki pages with instructions, even if no articles are listed, to avoid timeouts.
#   The format of the pages: each article is listed with '*' as the first character of the line. Anything else is ignored as a comment.
#
function getlist(list,  listdata,command,a,c,i,msg,page,k,j,listtry) {

  if(list == "exclude") {
    page = ExcludeListPage
    msg = "Excludelist"
  }
  if(list == "include")  {
    page = IncludeListPage
    msg = "Includelist"
  }

  command = Exe["timeout"] " 20s " Exe["wget"]  " -q -O- \"https://" Lang ".wikipedia.org/w/index.php?title=" page "&action=raw\""
  listdata = sys2var(command)

  listtry[2] = 2
  listtry[3] = 20
  listtry[4] = 60
  for(j in listtry) {
    if(length(listdata) < 2) {
      stdErrO(msg " try " j " - ", "n")
      sleep(listtry[j])
      listdata = sys2var(command)
    }
    else
      break
  }
  if(length(listdata) < 2)
    return 0

  c = split(listdata, a, "\n")
  while(i++ < c) {
    a[i] = strip(a[i])
    if(a[i] !~ /^[*]/) continue
    gsub(/^[*][ ]{0,}/,"",a[i])
    a[i] = strip(a[i])
    if(list == "exclude")
      ExcludeA[a[i]] = 1
    else if(list == "include")
      IncludeA[a[i]] = 1
  }

 # Save copy for history

  if(list == "exclude")
    history( ExcludeA, "listexclude")
  if(list == "include")
    history( IncludeA, "listinclude")

  return 1
}

#
# Check last job has completed
#  Return 1 if completed
#
function jobcompleted(  command,a,msg,json,op) {

  command = Exe["tail"] " -n 1 " MetaDir "index"
  if(split(sys2var(command), a, "|") == 2) {
    a[1] = strip(a[1]); a[2] = strip(a[2])
    if(! empty(a[1])) {
      command = Exe["iabget"] " -a getbotjob -p \"id=" a[1] "\""
      op = sys2var(command)
      if(op == "complete") {
        command =  Exe["iabget"] " -a getbotjob -p \"id=" a[1] "\" -w"
        json = sys2var(command)
        print json >> a[2] "json.completed"
        close(a[2] "json.completed")
        return 1
      }
      else
        msg = op
    }
    else
      msg = "no id"
  }
  else
    msg = "no index"

  if(empty(msg))
    msg = "unknown error"
  email("NOTICE: Error in FARotBot: jobcompleted() (" msg ")")
  return 0

}

#
# Check status of stop button page
#
#  return RUN or STOP
#
function stopbutton(  button,command,i,buttry) {

  command = Exe["timeout"] " 20s " Exe["wget"]  " -q -O- \"https://en.wikipedia.org/w/index.php?title=" StopButtonPage "&action=raw\""
  button = sys2var(command)

  if(button ~ /action[ ]{0,}[=][ ]{0,}run/)
    return "RUN"

  buttry[2] = 2
  buttry[3] = 20
  buttry[4] = 60
  buttry[5] = 240

  for(i in buttry) {
    if(length(button) < 2) {
      stdErrO("Button try " i " - ", "n")
      sleep(buttry[i])
      button = sys2var(command)
    }
    else
      break
  }

  if(length(button) < 2) {
    email("NOTICE: Error in farotbot: Aborted Button (page blank? wikipedia down?")
    stdErrO("Aborted Button (page blank? wikipedia down?) - ", "n")
    return "STOP"
  }

  if(button ~ /action[ ]{0,}[=][ ]{0,}run/)
    return "RUN"

  email("NOTICE: Error in farotbot: ABORTED by stop button page.")
  stdErrO("farotbot.awk: ABORTED by stop button page.")
  return "STOP"

}

#
# Save a copy for history. If opt set, don't gzip
#
function history(listarray, listname, opt,    k) {

    for(k in listarray)
      print k >> rb_data listname
    close(rb_data listname)
    if(empty(opt))
      sys2var(Exe["gzip"] " " rb_data listname)
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
# Merge an array of strings into a single string. Array indice are strings.
#
function join2(arr, sep         ,i,lobster) {

        for ( lobster in arr ) {
            if(++i == 1) {
                result = lobster
                continue
            }
            result = result sep lobster
        }
        return result
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

      if( exists(str) )
        sys2var( Exe["rm"] " -- " shquote(str) )
      if( exists(str) ) {
        prnt("Error: unable to delete " str ", aborting.")
        exit
      }
      system("") # Flush buffer
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
# Sleep
#
function sleep(seconds) {
  if(seconds > 0)
    sys2var( Exe["sleep"] " " seconds)
}

#
# Make a directory ("mkdir -p dir")
#
function mkdir(dir,    ret, var, cwd, command) {

  command = Exe["mkdir"] " -p \"" dir "\" 2>/dev/null"
  sys2var(command)
  cwd = ENVIRON["PWD"]
  ret = chdir(dir)
  if (ret < 0) {
    stdErrO(sprintf("Could not create %s (%s)\n", dir, ERRNO))
    return 0
  }
  ret  = chdir(cwd)
  if (ret < 0) {
    stdErrO(sprintf("Could not chdir to %s (%s)\n", cwd, ERRNO))
    return 0
  }
  return 1
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


#
# Send an email, if an address is set
#
function email(subject, body) {

    if(empty(Email)) return

    if(! empty(body))
      sys2var(Exe["mailx"] " -s \"" subject "\" " Email " < " body)
    else
      sys2var(Exe["mailx"] " -s \"" subject "\" " Email " < /dev/null")

}

#
# Uniq a list of \n separated names
#
function uniq(names,    b,c,i,x) {

        c = split(names, b, "\n")
        names = "" # free memory
        while (i++ < c) {
            gsub(/\\["]/,"\"",b[i])
            if(b[i] ~ "for API usage") { # Max lag exceeded.
                # errormsg("\nMax lag (" G["maxlag"] ") exceeded - aborting. Try again when API servers are less busy, or increase Maxlag (-m)")
                # exit
                return ""
            }
            if(b[i] == "")
                continue
            if(x[b[i]] == "")
                x[b[i]] = b[i]
        }
        delete b # free memory
        return join2(x,"\n")
}

