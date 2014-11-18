#!/bin/bash

set -euo pipefail

exec 3<"$(dirname "$0")/docpage/index.html"

declare TITLE="$1"

function title {
	"$(dirname "$0")/doc-title.pl" "$TITLE"
}

function html_head {
	while read LINE; do
		if [[ $LINE =~ \<\/head\> ]]; then
			cat "$(dirname "$0")/doc-extra-html.html"
		fi
		echo "$LINE"
		if [[ $LINE =~ \<article\> ]]; then
			break;
		fi
	done <&3
}

function demos {
	echo "<h1>Live demos</h1>"
	echo "<ul>"

	(cd "$(dirname "$0")/../doc/demos/" && ls -1) | \
	while read DEMO; do
		echo "<li><a href=\"demos/$DEMO\">$DEMO</a></li>"
	done
	echo "</ul>"
}

function html_tail {
	local ECHO=0
	while read LINE; do
		if [[ $LINE =~ \</article\> ]]; then
			ECHO=1
		fi
		if (( ECHO )); then
			echo "$LINE"
		fi
	done <&3
}

function indent {
	sed -e 's/\t/    /g'
}

function nobr {
	sed -e 's/<br[^>]*>/ /g'
}

function highlight {
	"$(dirname "$0")/doc-highlight.pl"
}

(
	html_head | title
	cat | nobr | highlight
	demos
	html_tail
) | indent
