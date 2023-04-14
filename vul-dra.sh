#!/bin/sh
# Help menu
if [ "$1" = "-h" -o "$1" = "--help" ]; then
	echo "usage: ./$(basename "$0") John 3
	./$(basename "$0") John 3 16
	./$(basename "$0") John 3 16-21
	For books of the bible that has a numbering before it, e.g 1 Peter
	./$(basename "$0") 1Peter 1
	./$(basename "$0") 1Corinthians 1 5
	./$(basename "$0") 1Thessalonians 1 1-10"
	exit 1
fi

# Checks if user input uses verse(s) or not
if [ -z "$3" ];then
	verse_range=$(curl -s "https://www.biblegateway.com/passage/?search=$1+$2&version=VULGATE")
	verse_range=$(printf "%s" "$verse_range" | sed -n 's/.*<div class="passage-table" data-osis="\(.*\)".*/\1/p')
	prefix=$(printf "%s" "$verse_range" | sed -n 's/^\([^\.]*\)\..*/\1/p')
	verse_range=$(printf "%s" "$verse_range" | sed 's/'"$prefix"'\.'"$2"'\.\(.\+\)-'"$prefix"'\.'"$2"'\.\(.\+\)/\1-\2/')
else
	verse_range=$(printf "%s" "$3" | grep -oE "[0-9]+-[0-9]+")
fi

if [ -n "$verse_range" ]; then
	number1=$(printf "%s" "$verse_range" | cut -d'-' -f1)
	number2=$(printf "%s" "$verse_range" | cut -d'-' -f2)
fi
# Request to biblegateway and parse response
request_and_parse(){
	bible=$(curl -s "https://www.biblegateway.com/passage/?search=$1+$2:$3&version=$4")
	verse_text=$(printf "%s" "$bible" | sed -n 's/.*<meta property="og:description" content="\(.*\)".*/\1/p')
	verse_result="${verse_result} ${verse_text}"
	printf "%s\n" "$verse_result"
}

# Checks and adjustments for a certain scraping block
scraping_block(){
	verse_result=$(request_and_parse "$1" "$2" "$number1-$((number1+4))" "$version")
	while [ $((number1+5)) -le $number2 ]; do
		number1=$((number1+5))
		verse_result=$(request_and_parse "$1" "$2" "$number1-$number2" "$version")
	done
	printf "%s\n" "$verse_result"
}

display(){
  	printf "%-50s%s\n" "LATIN VULGATE" "DOUAY RHEIMS"
  	printf "%-50s%s\n" "-------------" "---------------------------"
	VULGATE_DISPLAY=$(printf "%s" "$VULGATE" | fmt -w 50)
	DRA_DISPLAY=$(printf "%s" "$DRA" | fmt -w 50)
	
	mkfifo vulgate_pipe dra_pipe
	printf '%s\n' "$VULGATE_DISPLAY" > vulgate_pipe &
	printf '%s\n' "$DRA_DISPLAY" > dra_pipe &
	paste vulgate_pipe dra_pipe | awk -F'\t' '{printf("%-50s%s\n", $1, $2)}'
	rm vulgate_pipe dra_pipe
  	exit 0
}

range_count=$((number2 - number1))
printf "%s" "Requesting..."
if [ $range_count -ge 5 ]; then
	version="VULGATE"
	VULGATE=$(scraping_block "$1" "$2" "$version")
	version="DRA"
	DRA=$(scraping_block "$1" "$2" "$version")
else
	VULGATE=$(request_and_parse "$1" "$2" "$3" "VULGATE")
	DRA=$(request_and_parse "$1" "$2" "$3" "DRA")
fi
clear
display
