#!/usr/bin/perl

# Syntax: ./scope-imports.pl [file] [file] [file]
#
# Example: ./scope-imports.pl src/*.js src/*/*.js
#
# Looks for IIFE end and prefixes any parameters which match the regex with
# "window.".  Prompts for each replacement.
#
# Example:
#     })(angular, document, window, potato, my.thing);
#   transformed to:
#     })(window.angular, document, window, window.potato, my.thing);
#

use strict;
no warnings; # I'm lazy, see the map expression.

use File::Copy;

my @files = @ARGV;

foreach my $filename (@files) {
	my $changed = 0;
	my $tmpfile = $filename . '.tmp';
	open my $file, '<', $filename or die "Failed to open file $filename";
	open my $out, '>', $tmpfile or die "Failed to open temp file $tmpfile";
	while (<$file>) {
		chomp;
		# Is end of IIFE?
		if (/^}(\)?)\((.*)\);$/) {
			my $old = $_;
			my $brak = $1;
			my @args = $2 =~ /[^\s,]+/g;
			my $any = 0;
			# Map arguments
			@args = map { /^(?!window|document)\w+$/ ? (($any = 1) and "window.$_") : "$_" } @args;
			if ($any) {
				my $new = "}$brak(" . join(', ', @args) . ");";
				# Prompt replace?
				print STDOUT "\n$filename:\n\n\tCurrent:\n\t\t$old\n\n\tRecommend:\n\t\t$new\n\n\tReplace (Yn)?\n";
				my $yn;
				do {
					$yn = ' ';
					sysread STDIN, $yn, 1;
				} until ($yn =~ /^[yn]?$/i);
				if ($yn =~ /^(y(es)?)?$/i) {
					$_ = $new;
					$changed = 1;
				}
			}
		}
		$_ .= "\n" unless eof;
		print $out "$_";
	}
	close $out;
	close $file;
	if ($changed) {
		move($tmpfile, $filename) or die "Failed to move temp file $tmpfile over original $filename";
		print STDOUT "Modified $filename";
	} else {
		unlink($tmpfile) or warn "Failed to remove temp file $tmpfile";
	}
}
