#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/repeater.sh"

declare self="$0"

declare verbose=0
declare -a files=("")
declare srcdir="${SRCDIR}"
declare source_predicates="${SOURCEPREDICATES}"
declare ngannotate="${NGANNOTATE}"
declare uglify="${UGLIFY}"

function fmtOut {
	while read line; do
	 	echo "${line}" | perl -pe '
			s/^FAIL(ED)?:\s*/\e[1;31mFailed: \e[0m/i;
			s/^ERROR:\s*/\e[1;31mError: \e[0m/i;
			s/^WARN(ING)?:\s*/\e[1;33mWarning: \e[0m/i;
			s/(Line \d+):/\e[1;36m\1:\e[0m/;
			print "   ";'
	done
}

function parse {
	local file="$1"
	(${ngannotate} < "${file}" | ${uglify}) 2>&1 1>/dev/null
	"$(dirname "$0")/check.pl" -q "${file}" 2>&1
}

function check {
	local file="$1"
	local errs="$(parse "${file}" | fmtOut)"
	if (( verbose )); then
		echo -e "\e[1;32m * Pass: \e[0m${file}"
	fi
	if [ "${errs}" ]; then
		printf -- "\e[1;31m * Fail: \e[1;37m%s\n%s\n" "${file}" "${errs}"
	fi
}

function batchCheck {
	echo -e "\e[1mSyntax check starting\e[0m"
	echo "${files[@]}" | xargs -n1 -P16 "${self}"
	echo -e "\e[1mSyntax check complete\e[0m"

	repeater
}

function usage {
	echo "Javascript syntax checker"
	echo ""
	echo "    Usage: ./$(basename "$0") [-v] file1.js [file2.js ...]"
	echo ""
	echo "    -v: Verbose, display the name of each file checked"
	echo "        If not specified, only displays files which fail the check"
	echo ""
	echo "    fileN.js: javascript file(s) to check"
	echo ""
	exit 1
}

if (( $# )) && [ "$1" == "-h" ]; then
	usage
fi

if (( $# )) && [ "$1" == "-v" ]; then
	verbose=1
	shift
fi

files=( "$@" )

# No files specified in parameters?
if ! (( ${#files[@]} )); then
	while IFS= read -r -d $'\0' file; do
		if [ -f "${file%/*}/module.js" ];  then
			files+=("$file")
		fi
	done < <(eval find "${srcdir}" "${source_predicates}" -print0)
fi

if (( ${#files[@]} > 1 )); then
	clear
	batchCheck "${files[@]}"
elif (( ${#files[@]} == 1 )); then
	check "${files[0]}"
else
	usage
fi
