#!/usr/bin/awk -bE

# Populate 'Data:Wikipedia stats/data.tab' on Commons for use with 'Template:NUMBEROF' and 'Module:NUMBEROF'
#
# Copyright (c) User:GreenC (on en.wikipeda.org)
# June 2020
# License: MIT
#

BEGIN {
  BotName = "numberof"
}

@include "botwiki"
@include "library"
@include "json"


#
# Generate n-number of tabs
#
function t(n, r,i) {
  for(i = 1; i <= n; i++)
    r = r "\t"
  return r
}

#
# Abort and email if unable to retrieve page to avoid corrupting data.tab
#
function getpage(s,status,  fp,i) {

  for(i = 1; i <= 10; i++) {
      if(i == 2 && status ~ "closed")          # If closed site MW API may not have data available..
          return readfile(G["home"] "apiclosed.json") # Return manufactured JSON with data values of 0
      fp = sys2var(s)
      if(! empty(fp) && fp ~ "(schema|statistics|sitematrix)")
          return fp
      sleep(30)
  }

  sys2var(Exe["mailx"] " -s \"NOTICE: Numberof failed to getpage(" s ")\" " G["email"] " < /dev/null")
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
function dataconfig(datac,  a,i,s,sn,jsona,configfp,language,site,status,countofsites,desc,source,header) {

  desc   = "Configuration for Template:Numberof - This page is for manual testing. It is not actively updated with new info."
  source = "N/A"
  header = "language=string&project=string&status=string"
  jsonhead(desc, source, header, datac)

  configfp = getpage(Exe["wget"] " -q -O- " shquote("https://en.wikipedia.org/w/api.php?action=sitematrix" G["apitail"]), "")
  if(query_json(configfp, jsona) >= 0) {

      for(i = 0; i <= jsona["sitematrix","count"]; i++) {
          language = jsona["sitematrix",i,"code"]

          # Avoid Commons entries
          if(!empty(language)) {
              countofsites = jsona["sitematrix",i,"site","0"]

              # Some sites ("mo") have zero sites, skip
              if(countofsites > 0) {
                  status = "active"
                  for(sn = 1; sn <= countofsites; sn++) {
                      site = jsona["sitematrix",i,"site",sn,"code"]
                      if(site == "wiki") site = "wikipedia"
                      if(jsona["sitematrix",i,"site",sn,"closed"] == 1) status = "closed"
                      print t(2) "[\"" language "\",\"" site "\",\"" status "\"]," >> datac
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

  }
  else {
      sys2var(Exe["mailx"] " -s \"NOTICE: Numberof failed in dataconfig()\" " G["email"] " < /dev/null")
      exit
  }

  print "\n\t]\n}" >> datac
  close(datac)

}

#
# Generate data.tab statistics
#
function datatab(data,  c,i,cfgfp,k,lang,site,status,statsfp,jsona,jsonb,stat,desc,source,header) {

  desc = "Wikipedia Site Statistics. Last update: " sys2var(Exe["date"] " \"+%c\"")
  source = "Data source: Calculated from [[:mw:API:Siteinfo]] and posted by [https://github.com/greencardamom/Numberof Numberof bot] - This page is generated auto, manual changes will be overwritten."
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
          statsfp = getpage(Exe["wget"] " -q -O- " shquote("https://" lang "." site ".org/w/api.php?action=query&meta=siteinfo&siprop=statistics" G["apitail"]), status)
          if( query_json(statsfp, jsonb) >= 0) {
              printf t(2) "[\"" lang "." site "\"," >> data
              for(i = 1; i <= c; i++) {
                  T[site][stat[i]] = T[site][stat[i]] + jsonb["query","statistics",stat[i]]      # totals ticker (active and closed)
                  if(status == "active") {
                      TA[site][stat[i]] = TA[site][stat[i]] + jsonb["query","statistics",stat[i]]  # totals ticker (active only)
                      TR[site][lang][stat[i]] = jsonb["query","statistics",stat[i]]                # for use with dataranktab()
                  }
                  if(status == "closed")
                      TC[site][stat[i]] = TC[site][stat[i]] + jsonb["query","statistics",stat[i]]  # totals ticker (closed only)
                  printf jsonb["query","statistics",stat[i]] >> data
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

  print "]\n\t]\n}" >> data
  close(data)

  if(G["doupload"])
      upload(readfile(data), "Data:Wikipedia statistics/data.tab", "Update statistics", G["home"] "log", BotName, "commons", "wikimedia")

}

#
# Generate rank pages: Data:Wikipedia_statistics/rank/wikinews.tab, wikivoyage.tab etc..
#   depends on TR[] populated in datatab() which runs first
#
function dataranktab(datar,  c,i,s,si,k,siteT,siteU,site,stat,rank,NTT,NTA,desc,source,header) {

  s = split("wikipedia|wikisource|wikibooks|wikiquote|wikivoyage|wikinews|wikiversity|wiktionary", site, "|")

  for(si = 1; si <= s; si++) {

      desc   = toupper(substr(site[si],1,1)) tolower(substr(site[si],2)) " Site Rankings. Includes active sites for *." site[si] ".org - Last update: " sys2var(Exe["date"] " \"+%c\"")
      source = "Data source: Calculated from [[Data:Wikipedia_statistics/data.tab]] and posted by [https://github.com/greencardamom/Numberof Numberof bot] - This page is generated auto, manual changes will be overwritten."
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
                      NTT[siteU] = TR[siteT][siteU][stat[i]]
                  }
              }
          }

          PROCINFO["sorted_in"] = "@val_type_desc" # sort order largest to smallest number
          for(siteU in NTT) {
              rank++
              NTA[siteU][stat[i]] = rank
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

      print "\n\t]\n}" >> datar
      close(datar)

      if(G["doupload"])
          upload(readfile(datar), "Data:Wikipedia statistics/rank/" site[si] ".tab", "Update statistics", G["home"] "log", BotName, "commons", "wikimedia")

      PROCINFO["sorted_in"] = "@unsorted"
  }

}


BEGIN {

    _defaults = "home      = /data/project/botwikiawk/numberof/ \
                 email     = user@example.com \
                 version   = 1.0 \
                 copyright = 2020"

    asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")

    G["datas"] = G["home"] "data.tab"
    G["datac"] = G["home"] "datac.tab"
    G["datar"] = G["home"] "datar.tab"
    G["apitail"] = "&format=json&formatversion=2&maxlag=4"

    # 1-off special sites with no language sub-domains
    G["specials"] = "meta=wikimedia&commons=wikimedia&foundation=wikimedia&wikimania=wikimedia&wikitech=wikimedia&donate=wikimedia&species=wikimedia"

    # set to "commons" and it will read conf.tab on Commons .. otherwise "api" generates from API:SiteMatrix
    #  . determined by enwiki Template:NUMBEROF/conf
    G["confloc"] = getconf()

    # Set to 0 and it won't upload to Commons, for testing
    G["doupload"] = 1

    # an empty json template
    if( ! checkexists(Home "apiclosed.json")) {
        print "Unable to find " Home "apiclosed.json"
        exit
    }

    dataconfig(G["datac"])    # create what used to be Data:Wikipedia_statistics/config.tab via API:SiteMatrix
    datatab(G["datas"])       # create Data:Wikipedia_statistics/data.tab
    dataranktab(G["datar"])   # create Data:Wikipedia_statistics/datarank.tab

    # See enwiki Template:NUMBEROF/conf
    sys2var(Exe["cp"] " " shquote(G["datac"]) " " shquote("/data/project/botwikiawk/www/static/config.tab.json") )

}

