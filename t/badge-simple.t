#!/usr/bin/env perl
use warnings;
use strict;

=head1 Synopsis

Tests for the Perl module L<Badge::Simple>.

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
use File::Spec::Functions qw/catfile updir/;
use File::Temp qw/tempfile/;
use XML::LibXML;

use Test::More tests=>6;

BEGIN {
	diag "This is Perl $] at $^X on $^O";
	use_ok 'Badge::Simple', 'badge';
}
is $Badge::Simple::VERSION, '0.02', 'Badge::Simple version matches tests';

my $fontfile = catfile($FindBin::Bin,updir,'lib','Badge','Simple','DejaVuSans.ttf');

{
	my $exp = XML::LibXML->load_xml(
		location => catfile($FindBin::Bin, 'hello.svg'),
		no_blanks=>1 );
	my $got = badge( left => "Hello", right => "World!", color => "yellow", font=>$fontfile );
	is $got->toStringC14N(), $exp->toStringC14N(), 'hello.svg';
}

{
	my $exp = XML::LibXML->load_xml(
		location => catfile($FindBin::Bin, 'cpt100.svg'),
		no_blanks=>1 );
	my $got = badge( left=>'CPAN Testers', right=>'100%', color=>'brightgreen', font=>$fontfile );
	is $got->toStringC14N(), $exp->toStringC14N(), 'cpt100.svg';
}

{
	my $exp = XML::LibXML->load_xml(
		location => catfile($FindBin::Bin, 'foo.svg'),
		no_blanks=>1 );
	my $got = badge( left=>'foo', right=>'bar', color=>'#e542f4', font=>$fontfile );
	is $got->toStringC14N(), $exp->toStringC14N(), 'foo.svg';
}

subtest 'CLI' => sub {
	plan $] ge '5.008' ? ( tests=>2 ) : ( skip_all=>'bin/badge requires perl 5.008' );
	
	my ($tfh, $outfile) = tempfile(UNLINK=>1);
	close $tfh;
	
	my $script = catfile($FindBin::Bin, updir, 'bin', 'badge');
	is system($^X, $script, qw/ --left Hello --right World!
		--color yellow --out /, $outfile, '--font', $fontfile ),
		0, 'bin/badge';
	
	my $exp = XML::LibXML->load_xml(
		location => catfile($FindBin::Bin, 'hello.svg'),
		no_blanks=>1 );
	my $got = XML::LibXML->load_xml(
		location => $outfile, no_blanks=>1 );
	is $got->toStringC14N(), $exp->toStringC14N(), 'hello.svg';
};

