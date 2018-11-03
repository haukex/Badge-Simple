#!/usr/bin/env perl
use warnings;
use strict;

=head1 Synopsis

Author tests for the Perl module L<Badge::Simple>.

=head1 Author, Copyright, and License

Copyright (c) 2018 Hauke Daempfling (haukex@zero-g.net).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5 itself.

For more information see the L<Perl Artistic License|perlartistic>,
which should have been distributed with your copy of Perl.
Try the command C<perldoc perlartistic> or see
L<http://perldoc.perl.org/perlartistic.html>.

=cut

use FindBin;
use File::Spec::Functions qw/catfile abs2rel catdir/;
use File::Glob 'bsd_glob';

our (@PODFILES,@PERLFILES);
BEGIN {
	@PERLFILES = (
		catfile($FindBin::Bin,qw/ .. lib Badge Simple.pm /),
		bsd_glob("$FindBin::Bin/*.t"),
		bsd_glob("$FindBin::Bin/*.pm"),
	);
	@PODFILES = (
		catfile($FindBin::Bin,qw/ .. lib Badge Simple.pm /),
	);
}

use Test::More $ENV{BADGE_SIMPLE_AUTHOR_TESTS}
	? ( tests => @PODFILES + 2*@PERLFILES )
	: (skip_all=>'author tests (set $ENV{BADGE_SIMPLE_AUTHOR_TESTS} to enable)');

use warnings FATAL=>'all';
use Carp::Always;

use Test::Perl::Critic -profile=>catfile($FindBin::Bin,'perlcriticrc');
use Test::MinimumVersion;
use Test::Pod;

for my $podfile (@PODFILES) {
	pod_file_ok($podfile);
}

my @tasks;
for my $file (@PERLFILES) {
	critic_ok($file);
	minimum_version_ok($file, '5.006');
	open my $fh, '<', $file or die "$file: $!";  ## no critic (RequireCarping)
	while (<$fh>) {
		s/\A\s+|\s+\z//g;
		push @tasks, [abs2rel($file,catdir($FindBin::Bin,'..')), $., $_] if /TO.?DO/i;
	}
	close $fh;
}
diag "To-","Do Report: ", 0+@tasks, " To-","Dos found";
diag "### TO","DOs ###" if @tasks;
diag "$$_[0]:$$_[1]: $$_[2]" for @tasks;
diag "### ###" if @tasks;

