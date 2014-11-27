#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/../"

declare FILTER='*.js'
declare WIDTH=$(( $(stty size | cut -f2 -d\ ) - 2))
declare BUNDLE="out/bundle.js"
declare GZIP_LEVEL=--best

function table {
	local HEAD=1
	column -t -s"	" -o' | ' -c$WIDTH | \
	while read LINE; do
		if (( HEAD )); then
			echo -n "+"; printf -- '-%.0s' $(seq 1 $WIDTH); echo "+"
			echo -ne "| "
			echo -ne "\e[1m"
			echo -n "$LINE"
			echo -ne "\e[0m"
			echo -e "\r\e[$((WIDTH + 1))C|"
			echo -n "+"; printf -- '-%.0s' $(seq 1 $WIDTH); echo "+"
		else
			if [[ $LINE =~ TOTAL ]]; then
				echo -n "+"; printf -- '-%.0s' $(seq 1 $WIDTH); echo "+"
			fi
			echo -n "| $LINE"
			echo -e "\r\e[$((WIDTH))C |"
		fi
		HEAD=0
	done
	echo -ne "+"
	printf -- '-%.0s' $(seq 1 $WIDTH)
	echo -ne "+"

	echo ""
}

################################################################################

function submodules {
	echo -e "\n\e[1mSubmodules\e[0m\n"

	local SUBS="$(
		echo -e "Module\tLines\tChars\tMinified\t%\tGzip\t%\t"

		local MOD
		for MOD in src/*/
		do
			(
				echo "$MOD" | perl -pe 's!^.*src/([^/]+)/?$!$1!'
				find $MOD -name "$FILTER" -exec cat {} \; | wc -l
				local CHARS=$(find $MOD -name "$FILTER" -exec cat {} \; | wc -c)
				echo "$CHARS"
				local MINIFIED="${MOD%%/}"
				MINIFIED="out/${MINIFIED##*/}.js"
				if [ -e "$MINIFIED" ]; then
					local MINI=$(wc -c < "$MINIFIED")
					local GZIP=$(gzip $GZIP_LEVEL < "$MINIFIED" | wc -c)
					echo "$MINI"
					echo "100 * $MINI / $CHARS" | bc
					echo "$GZIP"
					echo "100 * $GZIP / $CHARS" | bc
				else
					echo ""
					echo ""
					echo ""
				fi
			) | tr "\n" "\t"
			echo ""
		done
	)"

	local LOC="$(echo "$SUBS" | tail -n +2 | cut -f2 | paste -sd+ | bc)"
	local CHARS="$(echo "$SUBS" | tail -n +2 | cut -f3 | paste -sd+ | bc)"
	local MINI="$(echo "$SUBS" | tail -n +2 | cut -f4 | paste -sd+ | sed -e s/\++/+/g | bc)"
	local MINIPC="$(echo "100 * $MINI / $CHARS" | bc)"
	local GZIP GZIPPC
	if [ -e "$BUNDLE" ]; then
		GZIP="$(gzip $GZIP_LEVEL < "$BUNDLE" | wc -c)"
		GZIPPC="$(echo "100 * $GZIP / $CHARS" | bc)"
	fi

	(
		echo "$SUBS"
		echo -e "TOTAL\t$LOC\t$CHARS\t$MINI\t$MINIPC\t$GZIP\t$GZIPPC\t"
	) | table
}

################################################################################

function project {
	local RANKS=10

	echo -e "\n\e[1mProject statistics - top $RANKS\e[0m\n"

	local RANKLIST=( "Rank" $(seq 1 $RANKS) "TOTAL")

	IFS=$'\n'

	local -a LOC=( "$(
		echo -e "Lines of code"
		(cd src && find . -name "$FILTER" -exec wc -l {} \;) | sort -n | tail -n $((RANKS+1)) | tac | tail -n +2 | sed -E 's/^\s+//g; s/\s+/\t/g' | column -t -s"	"
		(cd src && find . -name "$FILTER" -exec cat {} \;) | wc -l
	)" )

	local -a CHARS=( "$(
		echo -e "Total characters"
		(cd src && find . -name "$FILTER" -exec wc -c {} \;) | sort -n | tail -n $((RANKS+1)) | tac | tail -n +2 | sed -E 's/^\s+//g; s/\s+/\t/g' | column -t -s"	"
		(cd src && find . -name "$FILTER" -exec cat {} \;) | wc -c
	)" )

	local -a LONGLINES=( "$(
		echo -e "Longest lines"
		(cd src && find . -name "$FILTER" -exec wc -L {} \;) | sort -n | tail -n $((RANKS+1)) | tac | tail -n +2 | sed -E 's/^\s+//g; s/\s+/\t/g' | column -t -s"	"
		(cd src && find . -name "$FILTER" -exec cat {} \;) | wc -L
	)" )

	paste -d"	" \
		<(printf -- "%s\n" "${RANKLIST[@]}") \
		<(printf -- "%s\n" "${LOC[@]}") \
		<(printf -- "%s\n" "${CHARS[@]}") \
		<(printf -- "%s\n" "${LONGLINES[@]}") \
		| table
}

################################################################################

function commits {
	local COMMITS=$(git log --all --oneline | wc -l)
	echo -e "\n\e[1mGit graph ($COMMITS total commits)\e[0m\n"

	git log --graph --all --oneline --decorate --full-history --color --pretty=format:"%x1b[31m%h%x09%x1b[32m%d%x1b[0m%x20%s"
}

if !(($#)); then
	submodules
	project
	commits
else
	while [ "$1" ]; do
		"$1"
		shift
	done
fi

echo ""
echo ""
