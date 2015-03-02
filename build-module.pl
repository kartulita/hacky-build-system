#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Find;
use IPC::Open2;
use IPC::Pipeline;

select STDOUT;

my $verbose = 0;
if ($ARGV[0] eq '-v') {
	$verbose = 1;
	shift @ARGV;
}

if ($ENV{'verbose'}) {
	$verbose = 1;
}

if (!scalar(@ARGV)) {
	print "Syntax: build-module.pl [-v] <module-name> <source-dir> <output-dir>\n";
	print "Set environment variable 'verbose' to non-empty as alternative to setting '-v'\n";
	die;
}

my ($module, $srcdir, $outdir) = @ARGV;

if ($verbose) {
	print "Building module \"$module\" from \"$srcdir\" to \"$outdir\"\n\n";
}

my $header = "$srcdir/$module/module.js";
my @sources = ();
my @templates = ();
my @css = ();
my @less = ();

# Scan for input files
{
	find(
		sub {
			my $file = $File::Find::name;
			return if $file =~ /\/(bower_components|node_modules|demos|tests|utils)\//;
			return if $file eq $header;
			push(@sources, $file) if /\.js$/i;
			push(@templates, $file) if /template\.html$/i;
			push(@css, $file) if /\.css$/i;
			push(@less, $file) if /\.less$/i;
		},
		"$srcdir/$module");

	if ($verbose) {
		print "Header:\n * $header\n\n";
		print "Sources:" . join("\n * ", ('', @sources)) . "\n\n";
		print "Templates:" . join("\n * ", ('', @templates)) . "\n\n";
		print "Stylesheets:" . join("\n * ", ('', @css)) . "\n\n";
		print "Stylesheet templates:" . join("\n * ", ('', @less)) . "\n\n";
	}
}

# Returns a PID and a handle.  Data written to the handle is piped through the
# specified command, then output to the specified file.
sub pipe_out {
	my ($mode, $out, @cmd) = @_;
	pipe my $from_parent, my $to_child;
	if (my $pid = fork) {
		close $from_parent;
		return ($pid, $to_child);
	} elsif (defined $pid) {
		close $to_child;
		open STDOUT, $mode, $out or die "Failed to open output file $out";
		open STDIN, '<&'.fileno($from_parent) or die "Failed to connect pipe for $cmd[0]";
		exec @cmd or die "Failed to start $cmd[0]";
	} else {
		die "Fork failed for $cmd[0]";
	}
}

sub prelude {
	print "\n/*** This file is generated automatically, do not edit it as changes will not be preserved ***/\n";
}

sub reset_file {
	my ($filename) = @_;
	open my $truncate, '>', $filename or die "Failed to reset output file $filename";
	close $truncate;
}

# Bundle JS/HTML
{
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

	# Render output
	{
		my $modulejs = "$outdir/$module.js";

		my $annotate_pid = undef;
		my $annotate = undef;
		my $annotating = undef;

		sub begin_annotate {
			($annotating) = @_;
			($annotate_pid, $annotate) =
				pipe_out ">>", $modulejs, 'node_modules/.bin/ng-annotate', '--add', '--single-quotes', '-';
			select $annotate;
			return ($annotate_pid, $annotate);
		}

		sub end_annotate {
			select STDOUT;
			close $annotate;
			waitpid $annotate_pid, 0;
			if (my $err = $?) {
				if ($err == -1) {
					print "waitpid returned -1 for child process, unsure if error occured\n";
				} else {
					die "Failed to annotate $annotating, ng-annotate returned $err";
				}
			}
			$annotate = undef;
			$annotate_pid = undef;
			$annotating = undef;
		}

		reset_file $modulejs;
		begin_annotate '(prelude)';
		prelude;
		end_annotate
		print "\n\n/*!** Module: $module ***/\n";
		# Write header
		{
			my $source = $header;
			print "Processing source $source\n" if $verbose;
			begin_annotate $source;
			print "\n\n/*!** Source: $source ***/\n\n";
			open my $fh_source, '<', $source or die "Failed to open $source\n";
			print ';';
			print while (<$fh_source>);
			close $fh_source;
			end_annotate;
		}
		# Write templates
		for my $template (@templates) {
			print "Processing template $template\n" if $verbose;
			begin_annotate $template;
			print "\n\n/*!** Template: $template ***/\n\n";
			my $template_name = $template =~ s/^.*\///r;
			open my $fh_template, '<', $template or die "Failed to open $template\n";
			print join("\n", (
					';(function (angular) {',
					'	\'use strict\';',
					'',
					'	var html =',
					''
				)) . "\n";
			while (<$fh_template>) {
				chomp;
				s/^\s*|\s*$//g;
				s/\\/\\\\/g;
				s/'/\\'/g;
				s/$/ / unless /\>$/;
				print "		'$_'";
				print " +\n" unless eof;
			}
			print join("\n", (
					';',
					'',
					"	angular.module('$angular_name')",
					'		.run(function ($templateCache) {',
					'			$templateCache.put(\'' . $template_name . '\', html)',
					'		});',
					'',
					'})(window.angular);'
				));
			close $fh_template;
			end_annotate;
		}
		# Write sources
		foreach my $source (@sources) {
			print "Processing source $source\n" if $verbose;
			begin_annotate $source;
			print "\n\n/*!** Source: $source ***/\n\n";
			open my $fh_source, '<', $source or die "Failed to open $source\n";
			print ';';
			print while (<$fh_source>);
			close $fh_source;
			end_annotate;
		}
	}
}

# Bundle CSS
{
	open my $css_out, '>', "$outdir/$module.css" or die "Failed to open CSS output file";
	select $css_out;
	prelude;
	print "/*** Module: $module ***/\n";
	# Write CSS
	foreach my $source (@css) {
		print STDOUT "Processing stylesheet $source\n" if $verbose;
		print "\n/*** Stylesheet: $source ***/\n\n";
		open my $fh_source, '<', $source or die "Failed to open $source\n";
		print while (<$fh_source>);
		close $fh_source;
	}
	select STDOUT;
	close $css_out;
}

# Bundle LESS
{
	# Write LESS
	open my $less_out, '>', "$outdir/$module.less" or die "Failed to open LESS output file";
	select $less_out;
	prelude;
	print "/*** Module: $module ***/\n";
	foreach my $source (@less) {
		print STDOUT "Processing stylesheet template $source\n" if $verbose;
		print "\n/*** Stylesheet template: $source ***/\n\n";
		open my $fh_source, '<', $source or die "Failed to open $source\n";
		print while (<$fh_source>);
		close $fh_source;
	}
	select STDOUT;
	close $less_out;
}

# Compile/minify
#{
#}

# Tail
print "Done!\n\n" if $verbose;
