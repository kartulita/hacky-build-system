#!/usr/bin/perl

# ./check.pl [filename] [filename] ...
#
# Ensures that each JS source file is enclosed in an IIFE, that the IIFE uses
# strict mode.  If the IIFE reads arguments then these are displayed in the
# script's output.

use strict;
use warnings;

my $e = "\e[1;31m";
my $w = "\e[1;33m";
my $i = "\e[36m";
my $r = "\e[0;37m";
my $b = "\e[1;m";
my $n = "\n";

shift if my $quiet = $ARGV[0] eq '-q';

my @files = @ARGV > 0 ? @ARGV : <*/*.js>;

my $failed = 0;

foreach my $filename (@files) {
	print "Checking $filename... " unless $quiet;
	my $err = check($filename);
	if ($err) {
		$failed = 1;
		if ($quiet) {
			print 'Error: '.$err.$n;
		} else {
			print $n.$e.' - '.$err;
		}
	} else {
		print $i.' Pass!' unless $quiet;
	}
	print $r.$n unless $quiet;
}
exit $failed;

sub check {
	my ($filename) = @_;
	# Read first two lines and last line
	open(my $file, '<', $filename) or
		return 'Failed to open file';
	my $line = 0;
	my $fn;
	my $strict;
	my $last;
	while (<$file>) {
		chomp;
		/^\s*$/ and next;
		$line++;
		$fn = $_ if $line == 1;
		$strict = $_ if $line == 2;
		$last = $_;
	}
	close($file);
	my $bracketed;
	my $params;
	my $args;
	$fn =~ /^(\(?)function\ ?\(([^\)]*)\)\ ?{$/ or
		return 'Function wrapper not found';
	$bracketed = $1 eq '(';
	$params = $2;
	$strict =~ /^\s*(['"])use strict\1;$/ or
		return 'Strict mode string does not immediately follow function wrapper';
	$last =~ /^}(\)?)\(([^\)]*)\);$/ or
		return 'Function wrapper is not closed properly (or is not closed on the last line)';
	$args = $2;
	($bracketed == ($1 eq ')')) or
		return 'Function wrapper brackets don\'t match';
	if ($params ne '') {
		my @p = $params =~ /[^\s,]+/g;
		my @a = $args =~ /[^\s,]+/g;
		if (scalar @p != scalar @a) {
			return "Parameter count mismatch? ($params) <- ($args)";
		}
		for my $i (0 .. $#p) {
			if ($p[$i] ne $a[$i] and "window.$p[$i]" ne $a[$i]) {
				return "Parameter name mismatch? ($p[$i] <- $a[$i])";
			}
			if ($a[$i] =~ /^\w+$/) {
				return "Global scope import is not scoped (prefix with 'window.').  ($p[$i] <- $a[$i])";
			}
		}
	}
	return 0;
}
