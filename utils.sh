# Functions for piratec main script

source config

vers="0.0 testing 5"

#If colors used - variable readed from config
if [ "$colors" == "ON" ]; then 
	col0="\033[0m"      #color off
	colb="\033[1;34m"   #color blue
	coly="\033[1;33m"	#color yellow
	colg="\033[1;32m"	#color green
	colr="\033[1;31m"	#color red
	colm="\e[1;35m" #color magenta
	fntb="\033[1m"		#font bold

	#Add color for grep listing
	export GREP_COLOR='1;33'

fi


#====================================================================
#
# HELP ETC. 
#
#====================================================================

version() {
	echo -e \\n"${colg}The Piratebay Commandline Tool $vers $col0"\\n
}

usage() {
echo -e "
Usage: piratec -h | --help
       piratec -s | --search \"search string\".
       piratec -a | --about
       piratec -v | --version
       not implemented: {piratec -c | --category ${coly}TESTING!${col0}
	  
	   Example: piratec -s archlinux

       Categories: 100 music, 200 movies, 300 apps, 400 games}
       
	   Example: piratec -c 300,400 -s linux

       Menu:  After search, hits are shown in a numbered list. You may download
       correspondin torrent by it's number, by hitting 'd'.
       'N' and 'p' used to switch pages. 
       Hit 'h' for this help, and obviously 'q' for quits.

Misc:  - Using \"piratec -s\" without string parameter shows recent additions to site.
         Consider it as bug;).
       - You should edit piratec-file to change settings.
       - In crash or ctrl-c quits temporary files are not deleted until next run.
"}

}


#====================================================================
#
# EXIT FUNCTIONS
#
#====================================================================

function error_exit {
    usage
    exit 1
}

function normal_exit {
	rm $pirateseeds $piratetotal $piratetmp $piratefound $piratelinks $pirateinfo
	exit 0
}


#====================================================================
#
# DATA COLLECTION RELATED SCRIPTS 
#
#====================================================================

load_config_data() {
	
	#Temporary files
	piratetmp="$torrentdir/.piratetmp.tmp"
	piratefound="$torrentdir/.piratefound.tmp"
	piratelinks="$torrentdir/.piratelinks.tmp"
    pirateinfo="$torrentdir/.pirateinfo.tmp"
	pirateseeds="$torrentdir/.pirateseeds.tmp"
	piratefull="$torrentdir/.piratefull.tmp"
	piratedetails="$torrentdir/.piratedetails.tmp"

	#Removes old tmp-files if last session was forced quit or crashed.
	if [ -f $piratetmp ]; then
		rm $piratetmp $piratefound $piratelinks $pirateinfo $pirateseeds \
		$piratefull $piratedetails
	fi

	#Makes new temporary files
	touch $pirateinfo $pirateseeds $piratefull $piratetmp $piratefound $piratelinks\
	$piratedetails
}

#LOADS NEEDED DATA FROM HTML:S
function load_torrent_data {

	#downloads first page of searched item and push to file
	wget --quiet --continue $tpbsite/search/$sstring/$page/ -O $piratetmp
	
	#If "no hits" match found from tmp quits
	if search_not_found=$(cat $piratetmp | grep -o "No hits\(\)")
		then echo -e \\n"No hits for $sstring"\\n
		exit
	fi	

	#NAMES
	grep "<div class=\"detName\"" $piratetmp | \
	awk '{gsub(/<[^>]*>|^[ \t]*|\\|;|&amp*|€/,"");print}' |sed 's/$/                                      /' |cut -c1-43 > $piratefound

	#LINKS
	grep 'http://torrents.thepiratebay.org/' $piratetmp |cut -d '=' -f2 \
		|cut -d '"' -f2 > $piratelinks

	#SIZE
	grep "<font class=\"detDesc\">" $piratetmp | \
 		awk '{gsub(/&nbsp;/,""); gsub(/Size/,""); print}' |cut -d ' ' -f5 | \
		cut -d ',' -f1 | cut -c1-20 |sed 's/$/            /' \
		|cut -c1-9 > $pirateinfo	

	#SEEDS
	grep "<td align=\"right\">" $piratetmp | \
	awk '{gsub(/<[^>]*>|^[ \t]*/,""); print}' |sed -n 'p;N' \
	|cut -c1-5 > $pirateseeds

	#Merges all files to one
	paste $piratefound $pirateinfo $pirateseeds > $piratefull
		
	}

#===================================================================
#
# DATA USAGE
#
#===================================================================

load_torrent_details() {
	
	echo -en "${coly}Number: ${col0}"
	read dname
	
	echo $dname | grep "[^0-9]" > /dev/null 2>&1 #grep returns either 0 or 1
		
	if [ "$?" -eq "0" ]; then
  			echo -e \\n"Sorry, only numbers allowed."\\n
  	   		normal_exit
		
		elif [ "$dname" == "" ]; then
			
			tput cuu 1
			tput cuf 11
			tput el
			if_main_query
		
		#if number under 31 start downloading corresponding file
		elif [ "$dname" -lt "31" ]; then
	
				dname=`expr $dname + 1`	
				funky=`grep "detName" $piratetmp |cut -d ' ' -f3 | \
				awk '{gsub(/href="/,""); print}' |cut -d '"' -f1 |sed -n "${dname}p"`
				wget --quiet --continue http://thepiratebay.org$funky \
				--output-document=$piratedetails		
		
				echo
	    		cat $piratedetails |sed -n '/<pre>/,/\/pre/p' \
				|awk '{gsub(/<pre>/,""); gsub(/<\/pre>/,""); print}' |less 

				#RETURN TO MAIN MENU
			if_main_list
			if_main_menu
			if_main_query
				
		else
			echo -e \\n"Nothing done."\\n
			normal_exit
	fi

exit 1

}



download_torrent() {

	echo -en "${coly}Number: ${col0}"
	read tname
	
	echo $tname | grep "[^0-9]" > /dev/null 2>&1 #grep returns either 0 or 1
		
	if [ "$?" -eq "0" ]; then
  			#echo -e \\n"Sorry, only numbers allowed."\\n
			tput cuu 1
			tput cuf 11
			tput el
			if_main_query
		
		elif [ "$tname" == "" ]; then
			tput cuu 1
			tput cuf 11
			tput el 
			if_main_query
		#if number under 31 start downloading corresponding file
		elif [ "$tname" -lt "31" ]; then
			torrdown=`cat $piratelinks |sed -n "${tname}p"`
			wget -q $torrdown -P $torrentdir
			echo -e \\n"Torrent saved to $torrentdir"\\n
			normal_exit #Normal exit-function
		
		else
			tput cuu 1
			tput cuf 11
			tput el
			if_main_query
	fi

exit 1
}


#===================================================================
#
# INTERFACE STUFF
#
#===================================================================

#Ties all to one function to use in menu and such
if_main_all() {
	load_config_data
	load_torrent_data
	if_main_list
	if_main_menu
	if_main_query
}


#Add numbers to torrent listing and shows searched items
if_main_list() {

	echo -e \\n"Number  Name 					        Size            Seeds"
	echo -e "${colb}-----------------------------------------------------------------------------${col0}"
		
	nl $piratefull |grep --color=auto '    \<[0-9]\?[0-9]\>' 

	echo -e \\n ${colg}
	grep "hits from" $piratetmp | \
	awk '{gsub(/<[^>]*>|^[ \t]*/,""); gsub(/&nbsp;/,". "); print}'

}

if_main_menu() {

	echo -e \\n"${col0}\
## 'd' download | 'n' next page | 'p' previous page | 'i' details
## 'h' help     | 'q' quit."

	page=`expr $page + 1` #monkey code:DD
	echo -en \\n"Page ${colg}${page} ${coly}==> ${col0}"
	page=`expr $page - 1`
}

if_main_query() {
read -s -n 1 sel
	case $sel in
		["D","d"]*)
			download_torrent
			;;
		["P","p"]*)
			while [ "$page" -gt "0" ]; do
				page=`expr $page - 1`
				if_main_all
			done
			if_main_query
			;;
		["N","n"]*)
			page=`expr $page + 1`
			if_main_all
			;;
		["H","h"]*)
			echo
			usage
			exit
			;;
		["I","i"]*)
			load_torrent_details
			;;
		["Q","q"]*)
			echo -e \\n\\n"Exit.."\\n
			normal_exit
			;;
	*) 
	if_main_query
	esac
}
