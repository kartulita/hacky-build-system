#!/bin/bash

set -euo pipefail

declare -i PORT=0
declare SRCDIR OUTDIR
declare -a FILES= TESTS= EXTERNALS= HTMLHEAD= HTMLBODY=

function configure {

	PORT=1337

	cd "$(realpath "$(dirname "$0")/../")"
	SRCDIR="src"
	OUTDIR="out/tests"

	# Source files
	FILES=( "$SRCDIR"/*/*.js )

	# Tests to include
	TESTS=( "$SRCDIR"/*/tests/*.js )

	# External dependencies (to download)
	EXTERNALS=(
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

	# HTML source
	HTMLHEAD=(
		'<meta charset="utf-8">'
		'<title>Tests</title>'
	)

	# HTML source
	HTMLBODY=(
		'<div id="debug"></div>'
		'<div id="mocha"><p><a href=".">Unit tests for Wheatley</a></p></div>'
		'<div id="messages"></div>'
		'<div id="fixtures"></div>'
	)

}

# For sources: module/file-name.js => module_file-name.js
function makeFileName {
	local FILENAME="$1"
	echo -n "$(basename "$(dirname "$FILENAME")")_$(basename "$FILENAME")"
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
	local FILENAME NOINCLUDE DEPDIR="dep"
	local -a PIDS=
	section 'Dependencies'
	mkdir -p "$OUTDIR/$DEPDIR"
	for EXT in "${EXTERNALS[@]}"; do
		INCLUDE=1
		if [[ "$EXT" =~ ^\+ ]]; then
			EXT="${EXT:1:${#EXT}}"
			INCLUDE=0
		fi
		FILENAME="$DEPDIR/$(basename "$EXT")"
		item "$FILENAME"
		if ! [ -e "$OUTDIR/$FILENAME" ]; then
			extra "Downloading..."
			wget "$EXT" -O "$OUTDIR/$FILENAME" --quiet & PIDS+=( $! )
		fi
		if (( INCLUDE )); then
			if [[ "$FILENAME" =~ \.css$ ]]; then
				HTMLHEAD+=( '<link rel="stylesheet" href="'"$FILENAME"'">' )
			elif [[ "$FILENAME" =~ \.js$ ]]; then
				HTMLBODY+=( '<script src="'"$FILENAME"'"></script>' )
			fi
		fi
	done
	if (( ${#PIDS[@]} )); then
		wait ${PIDS[@]} >/dev/null 2>&1 || true
	fi
}

function modules {
	local FILENAME MODDIR="src"
	section "Module headers"
	mkdir -p "$OUTDIR/$MODDIR"
	for SRC in "${FILES[@]}"; do
		if ! [[ "$SRC" =~ module\.js$ ]]; then
			continue
		fi
		FILENAME="$MODDIR/$(makeFileName "$SRC")"
		item "$FILENAME"
		cp "$SRC" "$OUTDIR/$FILENAME"
		HTMLBODY+=( '<script src="'"$FILENAME"'"></script>' )
	done
	HTMLBODY+=( "<script>mocha.setup('bdd');</script>" )
}

function sources {
	local FILENAME SRCDIR="src"
	section "Sources"
	mkdir -p "$OUTDIR/$SRCDIR"
	for SRC in "${FILES[@]}"; do
		if [[ "$SRC" =~ module\.js$ ]]; then
			continue
		fi
		FILENAME="$SRCDIR/$(makeFileName "$SRC")"
		item "$FILENAME"
		cp "$SRC" "$OUTDIR/$FILENAME"
		HTMLBODY+=( '<script src="'"$FILENAME"'"></script>' )
	done
}

function tests {
	local FILENAME TESTDIR="test"
	section "Tests"
	mkdir -p "$OUTDIR/$TESTDIR"
	for TEST in "${TESTS[@]}"; do
		FILENAME="$TESTDIR/$(makeFileName "$(echo "$TEST" | sed -r 'y/\//_/')" | sed -r 's/\._//g')"
		item "$FILENAME"
		cp "$TEST" "$OUTDIR/$FILENAME"
		HTMLBODY+=( '<script src="'"$FILENAME"'"></script>' )
	done
}

function html {
	local FILENAME HTMLDIR="."
	section "Html interface"
	mkdir -p "$OUTDIR/$HTMLDIR"
	FILENAME="$HTMLDIR/index.html"
	item "$FILENAME"
	local -a HTML=(
		'<!DOCTYPE html>'
		'<html>'
		'<head>'
		"${HTMLHEAD[@]}"
		'</head>'
		'<body>'
		"${HTMLBODY[@]}"
		'</body>'
		'</html>'
	)
	printf -- "%s\n" "${HTML[@]}" > "$OUTDIR/$FILENAME"
}

declare -i SERVERPID=0
function startServer {
	section "Server"
	cd "$OUTDIR"
	"$NPM_HTTP" ./ -p $PORT -s -i0 & SERVERPID=$!
	sleep 0.2
	if ! kill -s 0 $SERVERPID; then
		item "Server failed to start"
		exit 1
	fi
	item "Listening on port $PORT"
	item "Point your browser to $(hostname -s):$PORT to run the tests"
}

function stopServer {
	if (( SERVERPID )) && kill -s 0 $SERVERPID >/dev/null 2>&1; then
		item "Stopping server"
		kill $SERVERPID >/dev/null 2>&1 && wait $SERVERPID >/dev/null 2>&1 || true
		item "Server stopped"
	fi
}

function main {

	configure

	echo -e "\e[1;37mOutput directory: $OUTDIR\e[0m"
	echo ""

	test -d "$SRCDIR"
	mkdir -p "$OUTDIR"

	dependencies
	modules
	sources
	HTMLBODY+=( '<script>mocha.setup("tdd");</script>' )
	HTMLBODY+=(
		'<script>'
		'	window.expect = chai.expect;'
		'	window.assert = chai.assert;'
		'	/* chai.should(); */'
		'</script>'
	)
	HTMLBODY+=( '<script src="dep/angular-mocks.js"></script>' )
	HTMLBODY+=( '<script>var tests = [];</script>' )
	tests
	HTMLBODY+=(
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
	HTMLBODY+=( '<script>mocha.run();</script>' )
	html

	startServer
	trap stopServer EXIT

	read -sn 1 CHAR
	stopServer

	if [ "$CHAR" == "q" ]; then
		exit 127
	fi
}

if (( $# == 0 )); then
	main || true
elif [ "$1" == "--loop" ]; then
	clear
	echo -e "\e[1;37mTest loop.  Press 'q' or Ctrl+C to quit, any key to re-build tests.\e[0m"
	echo ""
	if ( main ); then
		exec "$0" "$@"
	fi
else
	echo "Unknown parameter: $@"
	exit 1
fi
