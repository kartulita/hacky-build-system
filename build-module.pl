#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use IPC::Run qw( run );

select STDERR;

my $verbose = 0;
if ($ARGV[0] eq '-v') {
	$verbose = 1;
	shift @ARGV;
}

my $module = $ARGV[0];

my $srcdir = "$ENV{'SRCDIR'}/$module";

if ($verbose) {
	print "Building module \"$module\" from \"$srcdir\"\n\n";
}

my $header = "$srcdir/module.js";
my @sources = ();
my @templates = ();
my @styles = ();

# Scan for input files
{
	find(
		sub {
			my $file = $File::Find::name;
			return if $file =~ /\/(bower_components|node_modules|demos|tests)\//;
			return if $file eq $header;
			push(@sources, $file) if /.js$/i;
			push(@templates, $file) if /.html$/i;
			push(@styles, $file) if /.(css|less)$/i;
		},
		$srcdir);

	if ($verbose) {
		print "Header:\n * $header\n\n";
		print "Sources:" . join("\n * ", ('', @sources)) . "\n\n";
		print "Templates:" . join("\n * ", ('', @templates)) . "\n\n";
		print "Styles:" . join("\n * ", ('', @styles)) . "\n\n";
	}
}

# Get angular module name
my $angular_name;
{
	open my $fh_header, '<', $header or die "Failed to open $header\n";
	while (<$fh_header>) {
		if (/angular\.module\([\'\"]([^\'\"]+)[\'\"]\s*,/) {
			$angular_name = $1;
			last;
		}
	}
	close $fh_header;
	$angular_name or die "Failed to extract angular module name from $header\n";
	if ($verbose) {
		print "Angular module name:\n * $angular_name\n\n";
	}
}

# Prepend header file to list of sources
unshift(@sources, $header);

# Render output
{
	select STDOUT;
	# Write sources into ngAnnotate
	foreach my $source (@sources) {
		print STDERR "Processing source $source\n" if $verbose;
		open my $fh_source, '<', $source or die "Failed to open $source\n";
		print ';';
		while (<$fh_source>) {
			print $_;
		}
		close $fh_source;
	}
	# Write templates into ngAnnotate
	for my $template (@templates) {
		print STDERR "Processing template $template\n" if $verbose;
		my $template_name = $template =~ s/^.*\///r;
		open my $fh_template, '<', $template or die "Failed to open $template\n";
		print join("\n", (
				';(function (angular) {',
				'	\'use strict\';',
				'',
				'	var html = ['
			)) . "\n";
		while (<$fh_template>) {
			chomp;
			s/^\s*|\s*$//g;
			s/\\/\\\\/g;
			s/'/\\'/g;
			s/$/ / unless /\>$/;
			print '		\'' . $_ . '\'';
			print ' +' unless eof;
			print "\n";
		}
		print join("\n", (
				'	];',
				'',
				"	angular.module('$angular_name')",
				'		.run(function ($templateCache) {',
				'			$templateCache.put(\'' . $template_name . '\', html)',
				'		});',
				'',
				'})(window.angular);'
			));
		close $fh_template;
	}
	select STDERR;
}

# Tail
if ($verbose) {
	print "Done!\n\n";
}
