#!/bin/bash

set -euo pipefail

declare SOURCE="$1"
declare SRCDIR="$2"
declare TARGET="$3"

declare NAME="${SOURCE%.*}"
NAME="$SRCDIR/${SOURCE##*/}"

if ! [ -f "$SOURCE" ]; then
	echo "Source not found: $SOURCE" >&2
	exit 2
fi

if [ -z "$NAME" ]; then
	echo "Could not get demo name from $SOURCE"
fi

mkdir -p "$TARGET"

"$(dirname "$0")"/extract-demo-code.pl "$TARGET" <"$SOURCE"

declare -a DEPS=

DEPS+=( $(perl -ne 'while (<>) { next unless /^Dependencies:\s+(.*)$/; s/^Dependencies:\s+//g; s/[,\s]\s*/\n/g; chomp; print "$_"; }' < "$SOURCE" | sort | uniq) )

declare DEP
for DEP in "${DEPS[@]}"; do
	if [ -z "$DEP" ]; then
		continue;
	fi
	if ! [ -f "$SRCDIR/$DEP/module.js" ]; then
		echo "Dependency not found: $DEP!" >&2
		exit 3
	fi
	cp -Rt "$TARGET" "$SRCDIR/$DEP"
done

# Clean up if we didn't generate anything
rmdir --ignore-fail-on-non-empty "$TARGET"
