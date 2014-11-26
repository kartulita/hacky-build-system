#!/usr/bin/perl
#DEPRECATED, use ngdoc instead
use strict;
use warnings;

my $lang = '';

while (<>) {
	if (/<h(\d)[^>]*>[\w\-_]+\.(\w+)<\/h\1>/) {
		$lang = 'javascript' if ($2 eq 'js');
		$lang = 'markup' if ($2 eq 'html');
		$lang = 'css' if ($2 eq 'css');
	}
	if (/<pre><code>/ and $lang ne '') {
		s/<code/"<code class=\"language-$lang\""/e;
	}
	$lang = 'none' if (/<\/code>/);
	print $_;
}
