#!/usr/bin/perl
use strict;
use warnings;

if (scalar @ARGV == 0) {
	die "No input files specified";
}

my @modules = grep { /\/module\.js$/ } @ARGV;
my @sources = grep { !/\/module\.js$/ } @ARGV;

foreach my $file ((@modules, @sources)) {
	print "<script src=\"$file\"></script>\n";
}
