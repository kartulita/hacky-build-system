#!/bin/bash

set -euo pipefail

function fmtOut {
	while read LINE; do
	 	echo "$LINE" | perl -pe '
			s/^FAIL(ED)?:\s*/\e[1;31mFailed: \e[0m/i;
			s/^ERROR:\s*/\e[1;31mError: \e[0m/i;
			s/^WARN(ING)?:\s*/\e[1;33mWarning: \e[0m/i;
			s/(Line \d+):/\e[1;36m\1:\e[0m/;
			print "   - ";'
	done
}

function check {
	local SOURCE="$1"
	($NGANNOTATE < "$SOURCE" | $UGLIFY) 2>&1 1>/dev/null
	"$(dirname "$0")/check.pl" -q "$SOURCE" 2>&1
}

function syntaxCheck {
	echo -e "\e[1mSyntax check starting\e[0m"
	for SOURCE in "$@"; do
		echo -e "\e[1;32m * Checking \e[0m$SOURCE"
		if ! (check "$SOURCE" | fmtOut); then
			echo -e "   - \e[1;31mFailed: \e[0;37m$SOURCE"
		fi
	done
	echo -e "\e[1mSyntax check complete\e[0m"
}

if (( $# > 0 )) && [ "$1" == "--loop" ]; then
	shift
	clear
	if ( syntaxCheck "$@" ); then
		read -sn 1 CHAR
		if ! [ "$CHAR" == "q" ]; then
			exec "$0" "--loop" "$@"
		fi
	fi
else
	syntaxCheck "$@"
fi
