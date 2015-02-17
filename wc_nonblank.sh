#!/bin/bash

set -euo pipefail 

declare -a argv=( "$@" )
declare -i argc=${#argv[@]}
declare file=

if (( argc > 1 )) && ! [[ "${argv[${argc}-1]}" =~ ^- ]]; then
	file="${argv[${argc}-1]}"
	unset argv[${argc}-1]
	exec <"${file}"
fi

declare result="$(perl -ne 's/^\s*|\s*$//; print unless /^$/;' | wc "${argv[@]}")"

if [ "${file}" ]; then
	echo "${result} ${file}"
else
	echo "${result}"
fi
