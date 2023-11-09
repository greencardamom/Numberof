Numberof
===================
by User:GreenC (en.wikipedia.org)

June 2020

MIT License

Files
========

Numberof is a Wikipedia bot that creates and maintains these files:

* [Commons:Data:Wikipedia_statistics/data.tab](https://commons.wikimedia.org/wiki/Data:Wikipedia_statistics/data.tab) 
* [Commons:Data:Wikipedia_statistics/rank/*.tab](https://commons.wikimedia.org/wiki/Special:PrefixIndex?prefix=Wikipedia+statistics%2Frank%2F&namespace=486)
* [Commons:Data:Wikipedia_statistics/meta.tab](https://commons.wikimedia.org/wiki/Data:Wikipedia_statistics/meta.tab)

..which are pages used by [{{Wikipedia rank by size}}](https://en.wikipedia.org/wiki/Template:Wikipedia_rank_by_size), [{{NUMBEROF}}](https://en.wikipedia.org/wiki/Template:NUMBEROF) and [Module:NUMBEROF](https://en.wikipedia.org/wiki/Module:NUMBEROF) across many wiki languages and projects.

In addition, the bot creates .tab pages for Module:NumberOf hosted on Ruwiki and a few others. NumberOf is a peer of NUMBEROF, with its own features and requirements. The files are:

* [Commons:Data:Wikipedia_statistics/daily.tab](https://commons.wikimedia.org/wiki/Data:Wikipedia_statistics/daily.tab) 
* [Commons:Data:Wikipedia_statistics/hourly.tab](https://commons.wikimedia.org/wiki/Data:Wikipedia_statistics/hourly.tab) 

Finally, the bot creates forks of the ranking files which are sorted with ties showing equal rank (eg. two wikis can both be ranked #42 if they are tied for that spot). Equal ranking is not supported by Module:NUMBEROF but the data is made available for use such as other templates:

* [Commons:Data:Wikipedia_statistics/rank/*-ties.tab](https://commons.wikimedia.org/wiki/Special:PrefixIndex?prefix=Wikipedia+statistics%2Frank%2F&namespace=486)

Dependencies 
========
* GNU Awk 4.1+
* [BotWikiAwk](https://github.com/greencardamom/BotWikiAwk) (version Jan 2019 +)
* A bot User account with bot permissions on Commons

Installation
========

1. Install BotWikiAwk following setup instructions. 

2. Add OAuth credentials to wikiget (installed with BotWikiAwk), which is the utility that uploads pages to Commons. See [EDITSETUP](https://github.com/greencardamom/Wikiget/blob/master/EDITSETUP).

3. Clone Numberof. For example:
	git clone https://github.com/greencardamom/Numberof

4. Edit ~/BotWikiAwk/lib/botwiki.awk

	A. Set local URLs in section #1 and #2 

	B. Create a new 'case' entry in section #3, adjust the Home bot path created in step 2:

		case "numberof":                                             # Custom bot paths
			Home = "/data/project/projectname/numberof/"         # path ends in "/"
			Agent = UserPage " (ask me about " BotName ")"
			Engine = 3
			break


5. Set ~/Numberof/numberof.awk to mode 750, and change the first shebang line to the location of awk.

6. In numberof.awk in the "BEGIN {" section is a place for an email address for error reports.

Running
========

1. See the file toolforge.txt for how to run on Toolforge. Adjust to your local system if not on Toolforge.

