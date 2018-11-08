#!/usr/bin/env perl
use warnings;
use strict;
use Getopt::Std 'getopts';
use URI ();
use HTTP::Tiny ();
use JSON::MaybeXS qw/decode_json/;
use Badge::Simple qw/badge/;

# Generate "CPAN Testers" badges for a CPAN author's modules

my $USAGE = "Usage: $0 [-vdq] CPANAUTHOR\n";
$Getopt::Std::STANDARD_HELP_VERSION=1;
getopts('vdq', \my %opts) or die $USAGE;
my $VERBOSE = !!$opts{v};
my $DEBUG = !!$opts{d};
my $QUIET = !!$opts{q};
@ARGV==1 or die $USAGE;
my $AUTHOR = uc $ARGV[0];

if ($DEBUG) { require Data::Dump; Data::Dump->import("dd") }

my $http = HTTP::Tiny->new();

my @dists = do {
	my $uri = URI->new('http://fastapi.metacpan.org/v1/release/_search');
	die "bad author $AUTHOR" unless $AUTHOR=~/\A\w+\z/;
	$uri->query_form({ q=>"author:$AUTHOR AND status:latest",
		fields=>"distribution,version" });
	my $resp = $http->get("$uri");
	die "$uri: $$resp{status} $$resp{reason}" unless $resp->{success};
	print STDERR "$uri: $$resp{status} $$resp{reason}\n" if $VERBOSE;
	my $data = decode_json($resp->{content});
	$DEBUG and dd($data);
	sort { $$a[0] cmp $$b[0] }
		map { [ $_->{fields}{distribution}, $_->{fields}{version} ] }
		@{$data->{hits}{hits}};
};
die "Sorry, no hits for author $AUTHOR\n" unless @dists;

for my $dist (@dists) {
	$$dist[0]=~/\A[\w\-]+\z/aa or die "bad dist: $$dist[0]";
	$$dist[1]=~/\A[\w\-\.]+\z/aa or die "bad version: $$dist[1]";
	my $uri = URI->new('http://api.cpantesters.org/v3/release/dist');
	$uri->path_segments( $uri->path_segments, $$dist[0], $$dist[1] );
	my $resp = $http->get("$uri");
	die "$uri: $$resp{status} $$resp{reason}" unless $resp->{success};
	print STDERR "$uri: $$resp{status} $$resp{reason}\n" if $VERBOSE;
	my $data = decode_json($resp->{content});
	$DEBUG and dd($data);
	die "mismatch: $$data{dist}" unless $$data{dist} eq $$dist[0];
	die "mismatch: $$data{version}" unless $$data{version} eq $$dist[1];
	my ($pass,$fail) = ($$data{pass},$$data{fail});
	/\A\d+\z/ or die "bad int: $_" for $pass,$fail;
	my ($text,$color) = ("unknown","lightgrey");
	if ($pass+$fail>=4) { # want a somewhat decent percentage
		my $percent = int(100*$pass/($pass+$fail));
		$text = "$percent%";
		if    ($percent>=90) { $color="brightgreen" }
		elsif ($percent>=50) { $color="yellow"      }
		else                 { $color="red"         }
	}
	my $outfile = "$$data{dist}.svg";
	badge( left=>"CPAN Testers", right=>$text, color=>$color )
		->toFile($outfile);
	print STDERR "Wrote $outfile ($text $color)\n" unless $QUIET;
}

