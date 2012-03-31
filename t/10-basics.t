#! perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Differences;
use Test::Exception;

use Carp qw/croak/;
use File::Spec::Functions qw/catfile/;
use File::Basename qw/dirname/;
use File::Path qw/mkpath rmtree/;
use List::MoreUtils qw/first_index/;

use Build::Simple;

my $spew = sub { next_is($_[0]); spew($_[0], $_[0]) };
my $poke = sub { next_is('poke') };
my $noop = sub { next_is($_[0]) };

my $dirname = '_testing';
END { rmtree $dirname }
$SIG{INT} = sub { rmtree $dirname; die "Interrupted\n" };

my $graph = Build::Simple->new;

my $source1_filename = catfile($dirname, 'source1');
$graph->add_file($source1_filename, action => sub { $poke->(); $spew->(@_)});

my $source2_filename = catfile($dirname, 'source2');
$graph->add_file($source2_filename, action => $spew, dependencies => [ $source1_filename ]);

my $source3_filename = catfile($dirname, 'source3.foo');
#$graph->add_file($source3_filename);
my $source4_filename = catfile($dirname, 'source3.bar');
$graph->add_file($source4_filename, action => $spew);
$graph->add_pattern('*.foo', subst => [ qr/\.foo$/, '.bar' ], action => $spew);

$graph->add_phony('build', action => $noop, dependencies => [ $source1_filename, $source2_filename, $source3_filename ]);
$graph->add_phony('test', action => $noop, dependencies => [ 'build' ]);
$graph->add_phony('install', action => $noop, dependencies => [ 'build' ]);

$graph->add_phony('loop1', dependencies => ['loop2']);
$graph->add_phony('loop2', dependencies => ['loop1']);

my @sorted = $graph->_sort_nodes('build');

eq_or_diff \@sorted, [ $source1_filename, $source2_filename, $source4_filename, $source3_filename, 'build' ], 'topological sort is ok';

my @runs     = qw/build test install/;
my %expected = (
	build => [
		[qw{poke _testing/source1 _testing/source2 _testing/source3.bar _testing/source3.foo build}],
		[qw/build/],

		sub { rmtree $dirname },
		[qw{poke _testing/source1 _testing/source2 _testing/source3.bar _testing/source3.foo build}],
		[qw/build/],

		sub { unlink $source2_filename or die "Couldn't remove $source2_filename: $!" },
		[qw{_testing/source2 build}],
		[qw/build/],

		sub { unlink $source3_filename },
		[qw{_testing/source3.foo build}],
		[qw/build/],

		sub { unlink $source4_filename },
		[qw{_testing/source3.bar _testing/source3.foo build}],
		[qw/build/],

		sub { unlink $source1_filename },
		[qw{poke _testing/source1 _testing/source2 build}],
		[qw/build/],
	],
	test    => [
		[qw{poke _testing/source1 _testing/source2 _testing/source3.bar _testing/source3.foo build test}],
		[qw/build test/],
	],
	install => [
		[qw{poke _testing/source1 _testing/source2 _testing/source3.bar _testing/source3.foo build install}],
		[qw/build install/],
	],
);

my ($run, @expected);
sub next_is {
	my $gotten   = shift;
	my $index    = first_index { $_ eq $gotten } @expected;
	my $expected = $expected[0];
	splice @expected, $index, 1 if $index > -1;
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	is $gotten, $expected, sprintf "Expecting %s", (defined $expected ? "'$expected'" : 'undef');
}

for my $runner (sort keys %expected) {
	rmtree $dirname;
	$run = $runner;
	for my $runpart (@{ $expected{$runner} }) {
		if (ref($runpart) eq 'CODE') {
			$runpart->();
		}
		else {
			@expected = @{$runpart};
			$graph->run($run, verbosity => 1);
			eq_or_diff \@expected, [], "\@expected is empty at the end of run $run";
			diag(sprintf "Still expecting %s", join ', ', map { "'$_'" } @expected) if @expected;
			sleep 1;
		}
	}
}

throws_ok { $graph->run('loop1') } qr/loop1 has a circular dependency, aborting/, 'Looping gives an error';

done_testing();

sub spew {
	my ($filename, $content) = @_;
	open my $fh, '>', $filename or croak "Couldn't open file '$filename' for writing: $!\n";
	print $fh $content;
	close $fh or croak "couldn't close $filename: $!\n";
	return;
}

