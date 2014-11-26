#!/usr/bin/perl
#DEPRECATED, use ngdoc
use strict;
use warnings;

$_ = shift;
s/&/\&amp;/g;
s/>/\&gt;/g;
s/</\&lt;/g;
s/\"/\&quot;/g;
s/\'/\&apos;/g;
my $title = $_;

my $count = 2;

while (<>) {
	$count-- if ($count and s/^\t?<(h1|title)>.*?\<\/\1\>/"<$1>$title<\/$1>"/e);
	print $_;
}
