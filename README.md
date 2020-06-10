Numberof
===================
by User:GreenC (en.wikipedia.org)

June 2020

MIT License

Info
========
Numberof is a Wikipedia bot that maintains 
* [Commons:Data:Wikipedia_statistics/data.tab](https://commons.wikimedia.org/wiki/Data:Wikipedia_statistics/data.tab) 
* [Commons:Data:Wikipedia_statistics/rank/*.tab](https://commons.wikimedia.org/wiki/Special:PrefixIndex?prefix=Wikipedia+statistics%2Frank%2F&namespace=486)

..which are pages used by [{{Wikipedia rank by size}}](https://en.wikipedia.org/wiki/Template:Wikipedia_rank_by_size), [{{NUMBEROF}}](https://en.wikipedia.org/wiki/Template:NUMBEROF) and [Module:NUMBEROF](https://en.wikipedia.org/wiki/Module:NUMBEROF) across many wiki languages and projects.

Dependencies 
========
* GNU Awk 4.1+
* [BotWikiAwk](https://github.com/greencardamom/BotWikiAwk) (version Jan 2019 +)
* A bot User account with bot permissions on Commons

Installation
========

1. Install BotWikiAwk following setup instructions. Add OAuth credentials to wikiget, see the [EDITSETUP](https://github.com/greencardamom/Wikiget/blob/master/EDITSETUP) instructions.

2. Clone Numberof. For example:
	git clone https://github.com/greencardamom/Numberof

3. Edit ~/BotWikiAwk/lib/botwiki.awk

	A. Set local URLs in section #1 and #2 

	B. Create a new 'case' entry in section #3, adjust the Home bot path created in step 2:

		case "numberof":                                             # Custom bot paths
			Home = "/data/project/projectname/numberof/"         # path ends in "/"
			Agent = UserPage " (ask me about " BotName ")"
			break

	C. In section #10, replace the two lines starting with "delete Config" with the following:

		if(BotName !~ /numberof/) {
			delete Config
			readprojectcfg()
		}

4. Set ~/Numberof/numberof.awk to mode 750, and change the first shebang line to the location of awk on your system

Running
========

1. See the file toolforge.txt for how to run on Toolforge. Adjust to your local system if not on Toolforge.

