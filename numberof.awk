#!/usr/local/bin/awk -bE

# Populate 'Data:Wikipedia stats/*' on Commons for use with 'Template:NUMBEROF', 'Module:NUMBEROF', 'Template:NumberOf' (ruwiki)
#                      
# Copyright (c) User:GreenC (on en.wikipeda.org)
# 2020-2024
# License: MIT 
#

BEGIN { # Bot cfg

  _defaults = "home      = /home/greenc/toolforge/numberof/ \
               emailfp   = /home/greenc/toolforge/scripts/secrets/greenc.email \
               userid    = User:GreenC \
               version   = 1.5 \
               copyright = 2025"

  asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")
  BotName = "numberof"
  Home = G["home"]
  Engine = 3

  # Agent string format non-compliance could result in 429 (too many requests) rejections by WMF API
  Agent = BotName "-" G["version"] "-" G["copyright"] " (" G["userid"] "; mailto:" strip(readfile(G["emailfp"])) ")"
  
  G["email"] = strip(readfile(G["emailfp"]))

  G["datas"] = G["home"] "data.tab"
  G["datah"] = G["home"] "datah.tab" # hourly.tab for Russian Module:NumberOf
  G["datac"] = G["home"] "datac.tab"
  G["datar"] = G["home"] "datar.tab"
  G["apitail1"]  = "&format=json&formatversion=2&maxlag=4"
  G["apitail"] = "&format=json&formatversion=2"

  Exe["wikiget"] = "/home/greenc/scripts/wikiget.awk"

  # 1-off special sites with no language sub-domains
  # eg. site www.wikidata is represented here as www=wikidata
  G["specials"] = "www=wikifunctions&www=wikidata&www=wikisource&meta=wikimedia&commons=wikimedia&incubator=wikimedia&foundation=wikimedia&wikimania=wikimedia&wikitech=wikimedia&donate=wikimedia&species=wikimedia&beta=wikiversity"

  # CLI option that creates parallel set of data files on Commons where ties are resolved
  G["resolveties"] = 0

  # CLI option that creates the Russian-wiki "daily" data file on Commons, once per day per cron
  G["makedaily"] = 0

  # Set to 0 and it won't upload to Commons, for testing
  G["doupload"] = 1

  G["botpassfp"] = "/home/greenc/toolforge/scripts/secrets/greencbot_botpass.txt"
  G["initcache"] = G["home"] "initialized_wikis.txt"

  # Load known wikis into memory so we don't re-initialize them
  if (checkexists(G["initcache"])) {
      while ((getline line < G["initcache"]) > 0) {
          if (!empty(line)) InitCache[strip(line)] = 1
      }
      close(G["initcache"])
  }


}

@include "botwiki"
@include "library"
@include "json"

BEGIN { # Bot run

    # an empty json template 
    if( ! checkexists(G["home"] "apiclosed.json")) {
        print "Unable to find " G["home"] "apiclosed.json"
        exit
    }

    # set to "commons" and it will read conf.tab on Commons .. otherwise "api" generates from API:SiteMatrix
    #  . determined by enwiki Template:NUMBEROF/conf
    G["confloc"] = getconf()

    Optind = Opterr = 1
    while ((C = getopt(ARGC, ARGV, "td")) != -1) {
      if(C == "t")
        G["resolveties"] = 1
      if(C == "d")
        G["makedaily"] = 1         # create daily.tab
    }

    dataconfig(G["datac"])    # create what used to be Data:Wikipedia_statistics/config.tab via API:SiteMatrix
    datatab(G["datas"])       # create Data:Wikipedia_statistics/data.tab
    datatabrus(G["datah"])    # create Data:Wikipedia_statistics/hourly.tab for Russian Module:NumberOf .. must follow datatab()
    dataranktab(G["datar"])   # create Data:Wikipedia_statistics/datarank.tab

    # See enwiki Template:NUMBEROF/conf
    # sys2var(Exe["cp"] " " shquote(G["datac"]) " " shquote("/data/project/botwikiawk/www/static/config.tab.json") )

    healthcheckwatch()

}

#
# Ping Healthcheckwatch API
#
# Git: https://github.com/greencardamom/HealthcheckWatch
# Install: acre:[/home/greenc/toolforge/healthcheckwatch]
# Library: ~/BotWikiAwk/lib/syscfg.awk
# Wrapper: ~/scripts/healthcheckwatchping.sh
#
function healthcheckwatch() {

  hcw_ping("acre-numberof", 4, "NOTIFY (HCW): numberof.awk", "acre: /home/greenc/toolforge/numberof/numberof.awk (no response)")
  exit

}

#
# Currrent date/time in UTC
#
function currenttimeUTC() {
  return gsubi("GMT", "UTC", strftime(PROCINFO["strftime"], systime(), 1))
}

#
# Generate n-number of tabs
#
function t(n, r,i) {
  for(i = 1; i <= n; i++)
    r = r "\t"
  return r
}

#
# Auto-initialize new wikis via CentralAuth before OAuth queries them
#
function ensure_initialized(cmd_str,  domain, cmd, cookies, token, pass, secdir, success, maxlags, pauses, i, http_code) {
    # Extract the domain from the wikiget command string
    if (match(cmd_str, /https:\/\/([^/"'\\]+)/, m)) {
        domain = m[1]
        
        # If we have never seen this wiki before...
        if (!(domain in InitCache)) {
            
            # 1. Fetch the Global Skeleton Key only ONCE per script run
            if (!("centralauth_cookies" in G)) {
                print "\n[AUTO-INIT] [" domain "] Uncached wiki encountered. Triggering Skeleton Key fetch..." > "/dev/stderr"
                
                secdir = "/home/greenc/toolforge/scripts/secrets/"
                
                # Strip newline from password and safely dump it INSIDE the restricted directory
                pass = strip(readfile(secdir "greencbot.password"))
                printf "%s", pass > (secdir ".wmf_pass")
                close(secdir ".wmf_pass")
                
                print "[AUTO-INIT] [" domain "] -> Requesting Meta-Wiki login token..." > "/dev/stderr"
                cmd = "curl -L -m 15 -s -A " shquote(Agent) " -c /tmp/meta_cookie.txt \"https://meta.wikimedia.org/w/api.php?action=query&meta=tokens&type=login&format=json\" | jq -r .query.tokens.logintoken"
                token = strip(sys2var(cmd))
                printf "%s", token > (secdir ".wmf_token")
                close(secdir ".wmf_token")
                
                print "[AUTO-INIT] [" domain "] -> POSTing credentials to Meta-Wiki..." > "/dev/stderr"
                cmd = "curl -L -m 15 -A " shquote(Agent) " -s -b /tmp/meta_cookie.txt -c /tmp/meta_cookie.txt " \
                      "--data-urlencode action=login " \
                      "--data-urlencode \"lgname=GreenC bot\" " \
                      "--data-urlencode lgpassword@" secdir ".wmf_pass " \
                      "--data-urlencode lgtoken@" secdir ".wmf_token " \
                      "--data-urlencode format=json " \
                      "\"https://meta.wikimedia.org/w/api.php\" > /dev/null"
                system(cmd)
                
                # Immediately destroy the temporary payload files
                system("rm -f " secdir ".wmf_pass " secdir ".wmf_token")
                
                # Extract cookies bypassing cross-domain rules and save to memory
                cmd = "awk '/centralauth/ {printf \"%s=%s; \", $6, $7}' /tmp/meta_cookie.txt"
                G["centralauth_cookies"] = strip(sys2var(cmd))
            }
            
            cookies = G["centralauth_cookies"]
            
            # 2. Use the Skeleton Key to unlock the local wiki
            if (cookies != "") {
                print "[AUTO-INIT] [" domain "] -> Key acquired. Unlocking local account..." > "/dev/stderr"
                
                success = 0
                maxlags[1] = 10; pauses[1] = 12
                maxlags[2] = 20; pauses[2] = 15
                
                for (i = 1; i <= 2; i++) {
                    # Send payload, enforce 15s timeout, capture HTTP status
                    cmd = "curl -L -m 15 -s -A " shquote(Agent) " -o /dev/null -w \"%{http_code}\" -H 'Cookie: " cookies "' \"https://" domain "/w/api.php?action=query&maxlag=" maxlags[i] "&meta=userinfo&format=json\""
                    http_code = strip(sys2var(cmd))
                    
                    if (http_code == "200") {
                        print "[AUTO-INIT] [" domain "] -> SUCCESS (HTTP 200). Added to cache." > "/dev/stderr"
                        success = 1
                        break
                    } else if (http_code == "000") {
                        print "[AUTO-INIT] [" domain "] -> Connection timed out or dropped. Backing off " pauses[i] "s..." > "/dev/stderr"
                    } else {
                        print "[AUTO-INIT] [" domain "] -> Blocked (HTTP " http_code "). Backing off " pauses[i] "s..." > "/dev/stderr"
                    }
                    
                    sleep(pauses[i], "unix")
                }
                
                if (success) {
                    InitCache[domain] = 1
                    print domain >> G["initcache"]
                    close(G["initcache"])
                    sleep(6, "unix") 
                } else {
                    print "[AUTO-INIT] [" domain "] -> CRITICAL: Abandoning after max retries." > "/dev/stderr"
                }
            } else {
                print "[AUTO-INIT] [" domain "] -> ERROR: Meta-Wiki failed to return cookies. WMF might be hard-dropping us." > "/dev/stderr"
            }
        }
    }
}

#
# Abort and email if unable to retrieve page to avoid corrupting data.tab
#
function getpage(s,status,  fp,i) {
    

  # --- CLOSED WIKI BYPASS ---
  # Closed wikis cannot generate local OAuth accounts.
  # Inject the -O flag to tell wikiget to fetch anonymously.
  if(status ~ "closed") {
      sub(Exe["wikiget"], Exe["wikiget"] " -O", s)
  }
    
  # Automatically snowplow brand new active wikis before attempting OAuth!
  ensure_initialized(s)
    
  for(i = 1; i <= 3; i++) {
      sleep(0.5, "unix")
      fp = sys2var(s)
      
      if(! empty(fp) && fp ~ /(schema|statistics|sitematrix)/)
          return fp
          
      sleep(1.5, "unix")
  }

  email(Exe["from_email"], Exe["to_email"], "NUMBEROF COMPLETELY ABORTED ITS RUN because it failed to getpage(" s ")", "")
  exit
}

#
# Determine where to read configuration from, API:SiteMatrix or conf.tab on Commons
#   Reads from Template:NUMBEROF/conf at enwiki
#
function getconf( fp,i,a) {

  fp = getpage(Exe["wikiget"] " -l en -w 'Template:NUMBEROF/conf'")
  for(i = 1; i <= splitn(fp, a, i); i++) {
      if(a[i] ~ "^[*][ ]*[Cc]ommons")
          return "commons"
  }
  return "api"
}

#
# Generate JSON header
#
function jsonhead(description, sources, header, dataf,  c,i,a,b) {

  print "{" > dataf
  print t(1) "\"license\": \"CC0-1.0\"," >> dataf
  print t(1) "\"description\": {" >> dataf
  print t(2) "\"en\": \"" description "\"" >> dataf
  print t(1) "}," >> dataf
  print t(1) "\"sources\": \"" sources "\"," >> dataf
  print t(1) "\"schema\": {" >> dataf
  print t(2) "\"fields\": [" >> dataf

  c = split(header, a, /[&]/)
  for(i = 1; i <= c; i++) {
      split(a[i], b, /[=]/)
      print t(3) "{" >> dataf
      print t(4) "\"name\": \"" b[1] "\"," >> dataf
      print t(4) "\"type\": \"" b[2] "\"," >> dataf
      print t(4) "\"title\": {" >> dataf
      print t(5) "\"en\": \"" b[1] "\"" >> dataf
      print t(4) "}" >> dataf
      printf t(3) "}" >> dataf
      if(i != c) print "," >> dataf
      else print "" >> dataf
  }

  print t(2) "]" >> dataf
  print t(1) "}," >> dataf
  print t(1) "\"data\": [" >> dataf

}


#
# Generate conf.tab
#   see files sitematrix.json and sitematrix.awkjson for example layout
#
function dataconfig(datac,  a,i,s,sn,jsona,configfp,language,site,print_lang,status,countofsites,desc,source,header,url,dtf,dtl,dtn) {

  desc   = "Meta statistics for Wikimedia projects. Last update: " currenttimeUTC() 
  source = "Data source: Calculated from [[:mw:API:Sitematrix]] and posted by [https://github.com/greencardamom/Numberof Numberof bot]. This page is generated automatically, manual changes will be overwritten."
  header = "language=string&project=string&status=string"
  jsonhead(desc, source, header, datac)

  configfp = getpage(Exe["wikiget"] " -U " shquote("https://en.wikipedia.org/w/api.php?action=sitematrix" G["apitail"]), "")
  
  if(query_json(configfp, jsona) >= 0) {

      # --- SITEMATRIX SAFETY CATCH ---
      # Prevents generating a corrupt datac.tab if Sitematrix returns a JSON error payload
      if (jsona["error", "code"] != "") {
          email(Exe["from_email"], Exe["to_email"], "ABORTED: Sitematrix API returned an error: " jsona["error", "code"], "")
          exit
      }

      for(i = 0; i <= jsona["sitematrix","count"]; i++) {
          language = jsona["sitematrix",i,"code"]
   
          # 1. Global Language Overrides (Applies to all sister projects)
          if(language == "be-x-old") language = "be-tarask"
          else if(language == "gsw") language = "als"
          else if(language == "lzh") language = "zh-classical"
          else if(language == "nan") language = "zh-min-nan"
          else if(language == "rup") language = "roa-rup"
          else if(language == "sgs") language = "bat-smg"
          else if(language == "vro") language = "fiu-vro"
          else if(language == "yue") language = "zh-yue"

          # Avoid Commons entries
          if(!empty(language)) {
              countofsites = jsona["sitematrix",i,"site","0"]

              if(countofsites > 0) {
                  for(sn = 1; sn <= countofsites; sn++) {
                      
                      site = jsona["sitematrix",i,"site",sn,"code"]
                      print_lang = language
                      
                      # 2. Site Normalization
                      if(site == "wiki") site = "wikipedia"
                      
                      # 3. Project-Specific Split-Brain Overrides
                      if(print_lang == "zh-yue" && site == "wiktionary") {
                          print_lang = "yue"
                      }
                      
                      # 4. Status Check
                      status = "active"
                      if(jsona["sitematrix",i,"site",sn,"closed"] == 1) {
                          status = "closed"
                      }
                      
                      # 5. Output
                      print t(2) "[\"" print_lang "\",\"" site "\",\"" status "\"]," >> datac
                  }
              }
          }
      }

      # specials
      s = split(G["specials"], a, /[&]/)
      for(i = 1; i <= s; i++) {
          split(a[i], b, /[=]/)
          printf t(2) "[\"" b[1] "\",\"" b[2] "\",\"active\"]" >> datac
          if(i < s) print "," >> datac
          else print "" >> datac
      }

  } else {
      email(Exe["from_email"], Exe["to_email"], "ABORTED: Numberof failed in dataconfig() (Failed to parse JSON)", "")
      exit
  }

  print "\n" >> datac
  print t(1) "]," >> datac
  print t(1) "\"mediawikiCategories\": [" >> datac
  print t(2) "{" >> datac
  print t(3) "\"name\": \"Wikimedia-related tabular data\"," >> datac
  print t(3) "\"sort\": \"statistics\"" >> datac
  print t(2) "}" >> datac
  print t(1) "]" >> datac
  print "}" >> datac

  close(datac)

  dtf = readfile(datac)
  dtl = length(dtf)
  dtn = "datac.tab." dateeight() "." dtl

  # Sanity check JSON sz to avoid corruption.
  if(int(dtl) < 30000) {
      email(Exe["from_email"], Exe["to_email"], "NUMBEROF FAILED - CORRUPTED datac.tab (" dtn ")", "")
      print dtf > dtn
      close(dtn)
  } else {
      if(G["doupload"]) {
          upload(readfile(datac), "Data:Wikipedia statistics/meta.tab", "Update statistics", G["home"] "log", BotName, "commons", "wikimedia")
      }
  }
  
}

#
# Generate a replacement file for https://commons.wikimedia.org/wiki/Data:NumberOf/hourly.tab used on Ruwiki and several others
#
function datatabrus(data,   rank,edits,pages,articles,subdepth,depth,hasdepth,c,i,lang,stat,desc,source,header) {

  desc = "Wikipedia Site Statistics. May or may not be updated hourly, see page history for schedule. Meant for use with Module:NumberOf located on ru,uk,by,uz,av, and possibly others. For everyone else, please see Data:Wikipedia statistics/data.tab -- Last update: " currenttimeUTC() 
  source = "Data source: Calculated from [[:mw:API:Siteinfo]] and posted by [https://github.com/greencardamom/Numberof Numberof bot]. This page is generated automatically, manual changes will be overwritten."
  header = "lang=string&pos=number&activeusers=number&admins=number&articles=number&edits=number&files=number&pages=number&users=number&depth=number&date=string"
  jsonhead(desc, source, header, data)

  # Generate "pos" column ie. ranking by number of articles. Ties are not resolved. Only for Wikipedia sites.
  delete POS
  rank = 0
  for(lang in RUS) 
    POS[lang] = int(RUS[lang]["articles"])
  PROCINFO["sorted_in"] = "@val_num_desc" # sort order largest to smallest number
  for(lang in POS) {
    RUS[lang]["pos"] = ++rank
  }
  PROCINFO["sorted_in"] = "@unsorted"

  # Generate "depth" column
  # https://meta.wikimedia.org/wiki/Wikipedia_article_depth
  # Depth: {{#expr:{{NUMBEROF|EDITS|ce}}/{{NUMBEROF|PAGES|ce}}*(({{NUMBEROF|PAGES|ce}}-{{NUMBEROF|ARTICLES|ce}})/{{NUMBEROF|ARTICLES|ce}})^2 round 2}}
  for(lang in RUS) {
    edits = int(RUS[lang]["edits"])
    pages = int(RUS[lang]["pages"])
    articles = int(RUS[lang]["articles"])
    if(pages < 100 || articles < 100) {
      RUS[lang]["depth"] = 0
      continue
    }
    subdepth = (pages - articles) / articles
    depth = (edits / pages) * (subdepth * subdepth)
    RUS[lang]["depth"] = depth
  }

  # Generate "date" column 
  for(lang in RUS) 
    RUS[lang]["date"] = "null"

  c = split("pos|activeusers|admins|articles|edits|images|pages|users|depth", stat, "|")

  PROCINFO["sorted_in"] = "@ind_str_asc" # sort order a->z
  delete TRUS
  for(lang in RUS) {
    printf t(2) "[\"" lang "\"," >> data
    for(i = 1; i <= c; i++) {
      printf RUS[lang][stat[i]] "," >> data
      TRUS[stat[i]] = TRUS[stat[i]] + RUS[lang][stat[i]]        # totals ticker
    }
    printf "null" >> data
    print "]," >> data
  }
  PROCINFO["sorted_in"] = "@unsorted"

  # Total langsites that have a depth > 0
  for(lang in RUS) 
    if(RUS[lang]["depth"] > 0) hasdepth++

  # Total row
  TRUS["pos"] = 0
  TRUS["depth"] = int(int(TRUS["depth"]) / int(hasdepth) )
  TRUS["date"] = "\"@" systime() "\""
  printf t(2) "[\"total\"," >> data
  for(i = 1; i <= c; i++) 
    printf TRUS[stat[i]] "," >> data
  printf TRUS["date"] >> data


  print "]\n" >> data
  print t(1) "]," >> data
  print t(1) "\"mediawikiCategories\": [" >> data
  print t(2) "{" >> data
  print t(3) "\"name\": \"Wikimedia-related tabular data\"," >> data
  print t(3) "\"sort\": \"statistics\"" >> data
  print t(2) "}" >> data
  print t(1) "]" >> data
  print "}" >> data

  close(data)

  if(G["doupload"]) {
      upload(readfile(data), "Data:Wikipedia statistics/hourly.tab", "Update statistics", G["home"] "log", BotName, "commons", "wikimedia")
      if(G["makedaily"])
        upload(readfile(data), "Data:Wikipedia statistics/daily.tab", "Update statistics", G["home"] "log", BotName, "commons", "wikimedia")
  }

}

#
# Generate data.tab statistics
#
function datatab(data,  c,i,cfgfp,k,lang,site,status,statsfp,jsona,jsonb,stat,desc,source,header,dtl,dtn,dtf) {

  desc = "Wikipedia Site Statistics. Last update: " currenttimeUTC()
  source = "Data source: Calculated from [[:mw:API:Siteinfo]] and posted by [https://github.com/greencardamom/Numberof Numberof bot]. This page is generated automatically, manual changes will be overwritten."
  header = "site=string&activeusers=number&admins=number&articles=number&edits=number&files=number&pages=number&users=number"
  jsonhead(desc, source, header, data)
  
  # Get the configuration JSON
  if(G["confloc"] == "api")
      cfgfp = readfile(G["datac"])
  else
      cfgfp = getpage(Exe["wikiget"] " -l commons -w 'Data:Wikipedia statistics/config.tab'")

  c = split("activeusers|admins|articles|edits|images|pages|users", stat, "|")

  if( query_json(cfgfp, jsona) >= 0) {                   # Convert JSON cfgfp to awk associate array jsona[]  
      for(k = 1; k <= jsona["data","0"]; k++) {
          lang = jsona["data",k,"1"]
          site = jsona["data",k,"2"]
          status = jsona["data",k,"3"]
          if(lang == "total") continue
          if(site == "placeholder")  # maxlag problem for some sites. Placeholder means none ie. all are OK
            statsfp = getpage(Exe["wikiget"] " -U " shquote("https://" lang "." site ".org/w/api.php?action=query&meta=siteinfo&siprop=statistics" G["apitail2"]), status)
          else
            statsfp = getpage(Exe["wikiget"] " -U " shquote("https://" lang "." site ".org/w/api.php?action=query&meta=siteinfo&siprop=statistics" G["apitail"]), status)
          if( query_json(statsfp, jsonb) >= 0) {
              printf t(2) "[\"" lang "." site "\"," >> data
              for(i = 1; i <= c; i++) { 
                  T[site][stat[i]] = T[site][stat[i]] + jsonb["query","statistics",stat[i]]        # totals ticker (active and closed)
                  if(status == "active") {
                      TA[site][stat[i]] = TA[site][stat[i]] + jsonb["query","statistics",stat[i]]  # totals ticker (active only)
                      TR[site][lang][stat[i]] = jsonb["query","statistics",stat[i]]                # for use with dataranktab()
                  }
                  if(status == "closed")
                      TC[site][stat[i]] = TC[site][stat[i]] + jsonb["query","statistics",stat[i]]  # totals ticker (closed only)
                  printf jsonb["query","statistics",stat[i]] >> data
                  if(site == "wikipedia")
                    RUS[lang][stat[i]] = jsonb["query","statistics",stat[i]]                   # for use with datatabrus()
                  if(i != c) printf "," >> data
              }
              print "]," >> data
          }
      }
  }
  
  # Totals active and closed
  for(siteT in T) {
      printf t(2) "[\"total." siteT "\"," >> data
      for(i = 1; i <= c; i++) {
          printf T[siteT][stat[i]] >> data
          TT[stat[i]] = TT[stat[i]] + T[siteT][stat[i]]  # Grand total ticker
          if(i != c) printf "," >> data
      }
      print "]," >> data
  }

  # Totals active only
  for(siteT in TA) {
      printf t(2) "[\"totalactive." siteT "\"," >> data
      for(i = 1; i <= c; i++) {
          printf TA[siteT][stat[i]] >> data
          if(i != c) printf "," >> data
      }
      print "]," >> data
  }

  # Totals closed only
  for(siteT in TC) {
      printf t(2) "[\"totalclosed." siteT "\"," >> data
      for(i = 1; i <= c; i++) {
          printf TC[siteT][stat[i]] >> data
          if(i != c) printf "," >> data
      }
      print "]," >> data
  }

  # Grand total all sites combined, active and closed
  printf t(2) "[\"total.all\"," >> data
  for(i = 1; i <= c; i++) {
      printf TT[stat[i]] >> data
      if(i != c) printf "," >> data
  }

  print "]\n" >> data
  print t(1) "]," >> data
  print t(1) "\"mediawikiCategories\": [" >> data
  print t(2) "{" >> data
  print t(3) "\"name\": \"Wikimedia-related tabular data\"," >> data
  print t(3) "\"sort\": \"statistics\"" >> data
  print t(2) "}" >> data
  print t(1) "]" >> data
  print "}" >> data

  # print "]\n\t]\n}" >> data
  close(data)

  dtf = readfile(data)
  dtl = length(dtf)
  dtn = "data.tab." dateeight() "." dtl

  # Sanity check JSON sz to avoid corruption. Such as if API:SiteMatrix returns missing sites.
  if(int(dtl) < 50000) {
      email(Exe["from_email"], Exe["to_email"], "NUMBEROF FAILED - CORRUPTED data.tab (" dtn ")", "")
      print dtf > dtn
      close(dtn)
  }
  else {
    if(G["doupload"])
        upload(readfile(data), "Data:Wikipedia statistics/data.tab", "Update statistics", G["home"] "log", BotName, "commons", "wikimedia")
  }

}

#
# Generate rank pages: Data:Wikipedia_statistics/rank/wikinews.tab, wikivoyage.tab etc..
#   depends on TR[] populated in datatab() which runs first
#
function dataranktab(datar,  c,i,s,si,k,fp,siteT,siteU,site,stat,rank,NTT,NTA,desc,source,header,absolute,final,prevfinal) {

  s = split("wikipedia|wikisource|wikibooks|wikiquote|wikivoyage|wikinews|wikiversity|wiktionary", site, "|")

  for(si = 1; si <= s; si++) {

      if(G["resolveties"])
        desc   = toupper(substr(site[si],1,1)) tolower(substr(site[si],2)) " Site Rankings. Includes active sites for *." site[si] ".org - Ties are equal rank - Last update: " currenttimeUTC()
      else
        desc   = toupper(substr(site[si],1,1)) tolower(substr(site[si],2)) " Site Rankings. Includes active sites for *." site[si] ".org - Ties are not equal rank - Last update: " currenttimeUTC()
      source = "Data source: Calculated from [[Data:Wikipedia_statistics/data.tab]] and posted by [https://github.com/greencardamom/Numberof Numberof bot]. This page is generated automatically, manual changes will be overwritten."
      header = "site=string&activeusers=number&admins=number&articles=number&edits=number&files=number&pages=number&users=number"
      jsonhead(desc, source, header, datar)

      delete NTA
      c = split("activeusers|admins|articles|edits|images|pages|users", stat, "|")

      # Totals active only - populated by datatab()

      for(i = 1; i <= c; i++) {

          delete NTT
          rank = 0

          PROCINFO["sorted_in"] = "@unsorted"
          for(siteT in TR) {
              if(siteT == site[si]) {
                  for(siteU in TR[siteT]) {
                      if(siteU ~ /^total/) continue
                      NTT[siteU] = int(TR[siteT][siteU][stat[i]])
                  }
              }
          }


          # Display ties as equal rank, or not. 
          # Ties are resolved this way: 122256689 not this way: 122234456
          # Per User:-jem- at https://commons.wikimedia.org/wiki/User_talk:GreenC#Ties
          if(G["resolveties"]) {

            previous = -1
            absolute = 0
            final = 0
            prevfinal = 0

            PROCINFO["sorted_in"] = "@val_num_desc" # sort order largest to smallest number
            for(siteU in NTT) {

                absolute++

                if(previous != -1) {
                  if(NTT[siteU] != previous) {
                    final = absolute
                    prevfinal = final
                  }
                  else
                    final = prevfinal
                }
                else
                  final = absolute

                # print "S:" site[si] "-" siteU "-" stat[i] " A:" absolute " R:" rank " P:" previous " V:" NTT[siteU] " F:" final >> "debug.txt"

                NTA[siteU][stat[i]] = final
                previous = int(NTT[siteU])

            }
            PROCINFO["sorted_in"] = "@unsorted"
          } 
          else {

            PROCINFO["sorted_in"] = "@val_type_desc" # sort order largest to smallest number
            for(siteU in NTT) {
              rank++
              NTA[siteU][stat[i]] = rank
            }
            PROCINFO["sorted_in"] = "@unsorted"
          }
      }   

      # Ranking active sites only

      k = 0
      PROCINFO["sorted_in"] = "@ind_str_asc" # sort order a->z
      for(siteU in NTA) {
          if(++k != 1) print "," >> datar
          printf t(2) "[\"" siteU "\"," >> datar
          for(i = 1; i <= c; i++) {
              printf NTA[siteU][stat[i]] >> datar
              if(i != c) printf "," >> datar
          }
          printf "]" >> datar
      }
      PROCINFO["sorted_in"] = "@unsorted"

      print "\n" >> datar
      print t(1) "]," >> datar
      print t(1) "\"mediawikiCategories\": [" >> datar
      print t(2) "{" >> datar
      print t(3) "\"name\": \"Wikimedia-related tabular data\"," >> datar
      print t(3) "\"sort\": \"statistics\"" >> datar
      print t(2) "}" >> datar
      print t(1) "]" >> datar
      print "}" >> datar

      # print "\n\t]\n}" >> datar
      close(datar)

      if(G["doupload"]) {
          fp = site[si]
          if(G["resolveties"])
            fp = fp "-ties"
          upload(readfile(datar), "Data:Wikipedia statistics/rank/" fp ".tab", "Update statistics", G["home"] "log", BotName, "commons", "wikimedia")
      }

  }

}

