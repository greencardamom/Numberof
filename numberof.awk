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
               version   = 1.5 \
               copyright = 2025"

  asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")
  BotName = "numberof"
  Home = G["home"]
  Agent = "User:GreenC_bot numberof BotWikiAwk" 
  Engine = 3
  G["email"] = strip(readfile(G["emailfp"]))

  G["datas"] = G["home"] "data.tab"
  G["datah"] = G["home"] "datah.tab" # hourly.tab for Russian Module:NumberOf
  G["datac"] = G["home"] "datac.tab"
  G["datar"] = G["home"] "datar.tab"
  G["apitail1"]  = "&format=json&formatversion=2&maxlag=4"
  G["apitail"] = "&format=json&formatversion=2"

  # 1-off special sites with no language sub-domains
  # eg. site www.wikidata is represented here as www=wikidata
  G["specials"] = "www=wikifunctions&www=wikidata&www=wikisource&meta=wikimedia&commons=wikimedia&incubator=wikimedia&foundation=wikimedia&wikimania=wikimedia&wikitech=wikimedia&donate=wikimedia&species=wikimedia&beta=wikiversity"

  # CLI option that creates parallel set of data files on Commons where ties are resolved
  G["resolveties"] = 0

  # CLI option that creates the Russian-wiki "daily" data file on Commons, once per day per cron
  G["makedaily"] = 0

  # Set to 0 and it won't upload to Commons, for testing
  G["doupload"] = 1

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
# Abort and email if unable to retrieve page to avoid corrupting data.tab
#
function getpage(s,status,  fp,i) {

  for(i = 1; i <= 50; i++) {
      if(i == 2 && status ~ "closed")          # If closed site MW API may not have data available..
          return readfile(G["home"] "apiclosed.json") # Return manufactured JSON with data values of 0
      fp = sys2var(s)
      if(! empty(fp) && fp ~ "(schema|statistics|sitematrix)")
          return fp
      sleep(2, "unix")
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
function dataconfig(datac,  a,i,s,sn,jsona,configfp,language,site,status,countofsites,desc,source,header,url,dtf,dtl,dtn) {

  desc   = "Meta statistics for Wikimedia projects. Last update: " currenttimeUTC() 
  source = "Data source: Calculated from [[:mw:API:Sitematrix]] and posted by [https://github.com/greencardamom/Numberof Numberof bot]. This page is generated automatically, manual changes will be overwritten."
  header = "language=string&project=string&status=string"
  jsonhead(desc, source, header, datac)

  configfp = getpage(Exe["wget"] " --user-agent=" shquote(Agent) " -q -O- " shquote("https://en.wikipedia.org/w/api.php?action=sitematrix" G["apitail"]), "")
  if(query_json(configfp, jsona) >= 0) {

      for(i = 0; i <= jsona["sitematrix","count"]; i++) {
          language = jsona["sitematrix",i,"code"]
   
          # For the below see https://meta.wikimedia.org/wiki/List_of_Wikipedias#Nonstandard_language_codes

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

              # Some sites ("mo") have zero sites, skip
              if(countofsites > 0) {
                  for(sn = 1; sn <= countofsites; sn++) {
                      site = jsona["sitematrix",i,"site",sn,"code"]
                      if(site == "wiki") site = "wikipedia"
                      status = "active"
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
      email(Exe["from_email"], Exe["to_email"], "ABORTED: Numberof failed in dataconfig()", "")
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

  # print "\n\t]\n}" >> datac
  close(datac)

  dtf = readfile(datac)
  dtl = length(dtf)
  dtn = "datac.tab." dateeight() "." dtl

  # Sanity check JSON sz to avoid corruption. Such as if API:SiteMatrix returns missing sites.
  if(int(dtl) < 30000) {
      email(Exe["from_email"], Exe["to_email"], "NUMBEROF FAILED - CORRUPTED datac.tab (" dtn ")", "")
      print dtf > dtn
      close(dtn)
  }
  else {
      if(G["doupload"])
          upload(readfile(datac), "Data:Wikipedia statistics/meta.tab", "Update statistics", G["home"] "log", BotName, "commons", "wikimedia")
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
            statsfp = getpage(Exe["wget"] " --user-agent=" shquote(Agent) " -q -O- " shquote("https://" lang "." site ".org/w/api.php?action=query&meta=siteinfo&siprop=statistics" G["apitail2"]), status)
          else
            statsfp = getpage(Exe["wget"] " --user-agent=" shquote(Agent) " -q -O- " shquote("https://" lang "." site ".org/w/api.php?action=query&meta=siteinfo&siprop=statistics" G["apitail"]), status)
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

