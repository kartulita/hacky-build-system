#!/usr/bin/perl

use strict;
use warnings;

my @files = @ARGV;

# Put module header(s) first
my $nfiles = scalar(@files);
for (my $i = $nfiles - 1; $i >= 0; $i--) {
	unshift(@files, splice(@files, $i, 1)) if $files[$i] =~ /\/module\.js$/;
}

# Concatenate files, put a defensive semicolon before each one
for my $filename (@files) {
	open(my $file, '<', $filename)
		or die "Failed to open file '$filename'";
	print ';';
	while (<$file>) {
		print $_;
	}
	close($file);
}
