#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/../"

declare width=$(( $(stty size | cut -f2 -d\ ) - 2))
declare gzip_level=--best
declare source_predicates="-name '*.js' -not \( -path '*/bower_components/*' -or -path '*/node_modules/*' \)"

function table {
	local head=1
	column -t -s"	" -o' | ' -c${width} | \
	while read line; do
		if (( head )); then
			echo -n "+"; printf -- '-%.0s' $(seq 1 ${width}); echo "+"
			echo -ne "| "
			echo -ne "\e[1m"
			echo -n "${line}"
			echo -ne "\e[0m"
			echo -e "\r\e[$((width + 1))C|"
			echo -n "+"; printf -- '-%.0s' $(seq 1 ${width}); echo "+"
		else
			if [[ ${line} =~ TOTAL ]]; then
				echo -n "+"; printf -- '-%.0s' $(seq 1 ${width}); echo "+"
			fi
			echo -n "| ${line}"
			echo -e "\r\e[$((width))C |"
		fi
		head=0
	done
	echo -ne "+"
	printf -- '-%.0s' $(seq 1 ${width})
	echo -ne "+"

	echo ""
}

################################################################################

function submodules {
	echo -e "\n\e[1mSubmodules\e[0m\n"

	local subs="$(
		echo -e "Module\tFiles\tLines\tChars\tMini\t%\tGzip\t%\t"

		local mod
		for mod in src/*/
		do
			if ! [ -e "${mod}/module.js" ]; then
				continue;
			fi
			local module="$(echo "${mod}" | perl -pe 's!^.*src/([^/]+)/?$!$1!')"
			local files="$(eval find "${mod}" "${source_predicates}" | wc -l)"
			local combined="out/${module}.js"
			local minified="out/min/${module}.js"

			local lines_of_code="$(wc_nonblank.sh -l < "${combined}")"
			local total_chars="$(wc -c < "${combined}")"
			local mini="$(wc_nonblank.sh -c < "${minified}")"
			local minipc="$(echo "100 * ${mini} / ${total_chars}" | bc)"
			local gzip="$(gzip ${gzip_level} < "${minified}" | wc -c)"
			local gzippc="$(echo "100 * ${gzip} / ${total_chars}" | bc)"
			printf -- "%s\t" "${module}" "${files}" "${lines_of_code}" "${total_chars}" "${mini}" "${minipc}" "${gzip}" "${gzippc}"
			echo ""
		done
	)"

	local combined="out/bundle.js"
	local minified="out/min/bundle.js"

	local files="$(echo "${subs}" | tail -n +2 | cut -f2 | paste -sd+ | bc)"
	local lines_of_code="$(wc_nonblank.sh -l < "${combined}")"
	local total_chars="$(wc -c < "${combined}")"
	local mini="$(wc -c < "${minified}")"
	local minipc="$(echo "100 * ${mini} / ${total_chars}" | bc)"
	local gzip="$(gzip ${gzip_level} < "${minified}" | wc -c)"
	local gzippc="$(echo "100 * ${gzip} / ${total_chars}" | bc)"

	(
		echo "${subs}"
		printf -- "%s\t" "TOTAL/BUNDLE" "${files}" "${lines_of_code}" "${total_chars}" "${mini}" "${minipc}" "${gzip}" "${gzippc}"
		echo ""
	) | table
}

################################################################################

function project {
	local ranks=10

	echo -e "\n\e[1mProject statistics - top ${ranks}\e[0m\n"

	local rank_list=( "Rank" $(seq 1 ${ranks}) "TOTAL")

	IFS=$'\n'

	local -a lines_of_code=( "$(
		echo -e "Lines of code"
		(cd src && eval find . "${source_predicates}" '-exec wc_nonblank.sh -l {} \;') | sort -n | tail -n $((ranks+1)) | tac | tail -n +2 | sed -E 's/^\s+//g; s/\s+/\t/g' | column -t -s"	"
		(cd src && eval find . "${source_predicates}" '-exec cat {} \;') | wc_nonblank.sh -l
	)" )

	local -a total_chars=( "$(
		echo -e "Total characters"
		(cd src && eval find . "${source_predicates}" '-exec wc_nonblank.sh -c {} \;') | sort -n | tail -n $((ranks+1)) | tac | tail -n +2 | sed -E 's/^\s+//g; s/\s+/\t/g' | column -t -s"	"
		(cd src && eval find . "${source_predicates}" '-exec cat {} \;') | wc_nonblank.sh -c
	)" )

	local -a longest_line=( "$(
		echo -e "Longest lines"
		(cd src && eval find . "${source_predicates}" '-exec wc_nonblank.sh -L {} \;') | sort -n | tail -n $((ranks+1)) | tac | tail -n +2 | sed -E 's/^\s+//g; s/\s+/\t/g' | column -t -s"	"
		(cd src && eval find . "${source_predicates}" '-exec cat {} \;') | wc_nonblank.sh -L
	)" )

	paste -d"	" \
		<(printf -- "%s\n" "${rank_list[@]}") \
		<(printf -- "%s\n" "${lines_of_code[@]}") \
		<(printf -- "%s\n" "${total_chars[@]}") \
		<(printf -- "%s\n" "${longest_line[@]}") \
		| table
}

################################################################################

function commits {
	local commits=$(git log --all --oneline | wc -l)
	echo -e "\n\e[1mGit graph (${commits} total commits)\e[0m\n"

	git log --graph --all --oneline --decorate --full-history --color --pretty=format:"%x1b[31m%h%x09%x1b[32m%d%x1b[0m%x20%s"
}

################################################################################

if !(($#)); then
	set submodules project commits
fi

while (($#)); do
	"$1"
	shift
done
