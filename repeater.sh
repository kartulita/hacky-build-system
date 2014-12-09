#!/bin/false
# Source this

declare -x repeater_auto="${repeater_auto:-0}"

declare repeater_pwd="${PWD}"
declare repeater_self="$0"
declare -a repeater_args=( "bash_arrays_suck" "$@" )

function repeater {
	local char= callback="${1:-true}"

	echo "Press [q] to quit, [r] to re-run, [l] to loop"

	local read_timeout=

	if (( repeater_auto )); then
		read_timeout="-t ${repeater_auto}"
		echo "Loop interval = ${repeater_auto}s"
	fi

	while true; do
		if ! read ${read_timeout} -sn 1 char && (( repeater_auto )); then
			char="r"
		fi
		if [[ ${char} =~ ^[qrl]$ ]]; then
			break
		fi
	done

	"${callback}" "${char}"

	case "${char}" in
		q) repeater_quit;;
		r) repeater_rerun;;
		l) repeater_loop;;
	esac
}

function repeater_quit {
	exit 0
}

function repeater_rerun {
	cd "${repeater_pwd}"
	exec "${repeater_self}" "${repeater_args[@]:1}"
}

function repeater_loop {
	local secs
	while ! read -p "Loop interval (s): " -n 1 secs; do
		if [[ ${secs} =~ ^[[:digit:]]$ ]]; then
			break
		else
			echo "Number required"
		fi
	done
	repeater_auto="${secs}"
	repeater_rerun
}
