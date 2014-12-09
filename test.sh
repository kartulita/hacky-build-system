#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/repeater.sh"

declare -i port=0
declare srcdir="${SRCDIR}" testdir="${TESTDIR}"
declare -a files= tests= externals= htmlhead= htmlbody=
declare source_predicates="${SOURCEPREDICATES}"

function configure {

	port=1337

	cd "$(realpath "$(dirname "$0")/../")"

	# Source files
	files=( $(eval find "${srcdir}" ${source_predicates}) )

	# Tests to include
	tests=( "${srcdir}"/*/tests/*.js )

	# External dependencies (to download)
	externals=(
		'https://github.com/visionmedia/mocha/raw/master/mocha.css'
		'https://github.com/visionmedia/mocha/raw/master/mocha.js'

		'http://chaijs.com/chai.js'

		'https://code.jquery.com/jquery-1.11.1.min.js'

		'http://cdnjs.cloudflare.com/ajax/libs/toastr.js/2.0.2/js/toastr.min.js'
		'http://cdnjs.cloudflare.com/ajax/libs/toastr.js/2.0.2/css/toastr.min.css'

		'http://cdnjs.cloudflare.com/ajax/libs/underscore.js/1.7.0/underscore-min.js'

		'http://cdnjs.cloudflare.com/ajax/libs/angular.js/1.2.20/angular.js'
		'http://cdnjs.cloudflare.com/ajax/libs/angular.js/1.2.20/angular-resource.js'
		'http://cdnjs.cloudflare.com/ajax/libs/angular.js/1.2.20/angular-route.js'
		
		'http://cdnjs.cloudflare.com/ajax/libs/angular-ui-bootstrap/0.11.2/ui-bootstrap-tpls.js'

		'+http://cdnjs.cloudflare.com/ajax/libs/angular.js/1.2.20/angular-mocks.js'

	)

	# html source
	htmlhead=(
		'<meta charset="utf-8">'
		'<title>Tests</title>'
	)

	# html source
	htmlbody=(
		'<div id="debug"></div>'
		'<div id="mocha"><p><a href=".">Unit tests for Wheatley</a></p></div>'
		'<div id="messages"></div>'
		'<div id="fixtures"></div>'
	)

}

# For sources: module/file-name.js => module_file-name.js
function makeFileName {
	local filename="$1"
	echo -n "$(basename "$(dirname "${filename}")")_$(basename "${filename}")"
}

function section {
	echo ""
	echo -e "\e[1;35m$@\e[0;37m"
}

function item {
	echo -e " - \e[0;36m$@\e[0;37m"
}

function extra {
	echo -e "   \e[0;33m$@\e[0;37m"
}

function dependencies {
	local filename include depdir="dep"
	local -a pids=
	section 'Dependencies'
	mkdir -p "${testdir}/${depdir}"
	for ext in "${externals[@]}"; do
		include=1
		if [[ "${ext}" =~ ^\+ ]]; then
			ext="${ext:1:${#ext}}"
			include=0
		fi
		filename="${depdir}/$(basename "${ext}")"
		item "${filename}"
		if ! [ -e "${testdir}/${filename}" ]; then
			extra "Downloading..."
			wget "${ext}" -O "${testdir}/${filename}" --quiet & pids+=( $! )
		fi
		if (( include )); then
			if [[ "${filename}" =~ \.css$ ]]; then
				htmlhead+=( '<link rel="stylesheet" href="'"${filename}"'">' )
			elif [[ "${filename}" =~ \.js$ ]]; then
				htmlbody+=( '<script src="'"${filename}"'"></script>' )
			fi
		fi
	done
	if (( ${#pids[@]} )); then
		wait ${pids[@]} >/dev/null 2>&1 || true
	fi
}

function modules {
	local filename moddir="src"
	section "Module headers"
	mkdir -p "${testdir}/${moddir}"
	for src in "${files[@]}"; do
		if ! [[ "${src}" =~ module\.js$ ]]; then
			continue
		fi
		filename="${moddir}/$(makeFileName "${src}")"
		item "${filename}"
		cp "${src}" "${testdir}/${filename}"
		htmlbody+=( '<script src="'"${filename}"'"></script>' )
	done
	htmlbody+=( "<script>mocha.setup('bdd');</script>" )
}

function sources {
	local filename srcdir="src"
	section "Sources"
	mkdir -p "${testdir}/${srcdir}"
	for src in "${files[@]}"; do
		if [[ "${src}" =~ module\.js$ ]]; then
			continue
		fi
		filename="${srcdir}/$(makeFileName "${src}")"
		item "${filename}"
		cp "${src}" "${testdir}/${filename}"
		htmlbody+=( '<script src="'"${filename}"'"></script>' )
	done
}

function tests {
	local filename testfiledir="test"
	section "Tests"
	mkdir -p "${testdir}/${testfiledir}"
	for test in "${tests[@]}"; do
		filename="${testfiledir}/$(makeFileName "$(echo "${test}" | sed -r 'y/\//_/')" | sed -r 's/\._//g')"
		item "${filename}"
		cp "${test}" "${testdir}/${filename}"
		htmlbody+=( '<script src="'"${filename}"'"></script>' )
	done
}

function html {
	local filename htmldir="."
	section "Html interface"
	mkdir -p "${testdir}/${htmldir}"
	filename="${htmldir}/index.html"
	item "${filename}"
	local -a html=(
		'<!DOCTYPE html>'
		'<html>'
		'<head>'
		"${htmlhead[@]}"
		'</head>'
		'<body>'
		"${htmlbody[@]}"
		'</body>'
		'</html>'
	)
	printf -- "%s\n" "${html[@]}" > "${testdir}/${filename}"
}

declare -i serverpid=0
function startServer {
	section "Server"
	cd "${testdir}"
	"${NPM_HTTP}" ./ -p ${port} -s -i0 & serverpid=$!
	sleep 0.2
	if ! kill -s 0 ${serverpid}; then
		item "Server failed to start"
		exit 1
	fi
	item "Listening on port ${port}"
	item "Point your browser to $(hostname -s):${port} to run the tests"
}

function stopServer {
	if (( serverpid )) && kill -s 0 ${serverpid} >/dev/null 2>&1; then
		item "Stopping server"
		kill ${serverpid} >/dev/null 2>&1 && wait ${serverpid} >/dev/null 2>&1 || true
		item "Server stopped"
	fi
}

function main {

	configure

	echo -e "\e[1;37mOutput directory: ${testdir}\e[0m"
	echo ""

	test -d "${srcdir}"
	mkdir -p "${testdir}"

	dependencies
	modules
	sources
	htmlbody+=( '<script>mocha.setup("tdd");</script>' )
	htmlbody+=(
		'<script>'
		'	window.expect = chai.expect;'
		'	window.assert = chai.assert;'
		'	/* chai.should(); */'
		'</script>'
	)
	htmlbody+=( '<script src="dep/angular-mocks.js"></script>' )
	htmlbody+=( '<script>var tests = [];</script>' )
	tests
	htmlbody+=(
		'<script>'
		'(function () {'
		'	/* Resolve inter-test order-dependencies */'
		'	var groups = _(tests).chain()'
		'		.groupBy("group")'
		'		.pairs()'
		'		.map(function (kv) { return { name: kv[0], tests: resolve(kv[1]) }; })'
		'		.value();'
		'	function resolve(unordered) {'
		'		var order_cycles = unordered.length;'
		'		var ordered = [];'
		'		while (unordered.length) {'
		'			unordered = unordered.filter(function (test) {'
		'				var after = test.after;'
		'				if (_(after).every(function (dep) { return _(ordered).findWhere({ name: dep }); })) {'
		'					ordered.push(test);'
		'					return false;'
		'				} else {'
		'					return true;'
		'				}'
		'			});'
		'			if (order_cycles-- < 0) {'
		'				throw new Error("Failed to resolve test inter-dependencies");'
		'			}'
		'		}'
		'		return ordered;'
		'	}'
		'	/* Run each angular test with its own injector */'
		'	groups.forEach(function (group) {'
		'		describe("Test group: " + (group.name || "(no name)"), function () {'
		'			group.tests.forEach(function (test) {'
		'				test.modules.push("ng");'
		'				var injector = angular.bootstrap(document.createElement("div"), test.modules);'
		'				injector.invoke(test.test);'
		'			});'
		'		});'
		'	});'
		'})();'
		'</script>'
	)
	htmlbody+=( '<script>mocha.run();</script>' )
	html

	startServer
	trap stopServer EXIT

	repeater stopServer
}

clear
main
