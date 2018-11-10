#!/usr/bin/env perl
use warnings;
use strict;
use re '/aa';
use Getopt::Std 'getopts';
use URI ();
use HTTP::Tiny ();
use JSON::MaybeXS qw/decode_json/;
use File::Spec::Functions qw/curdir catfile/;
use Badge::Simple qw/badge/;
use File::Replace 'replace3';

# Generate "CPAN Testers" (and "Kwalitee") badges for a CPAN author's modules

my $USAGE = "Usage: $0 [-vdq] [-o OUTDIR] [-k KWALDIR] CPANAUTHOR\n";
$Getopt::Std::STANDARD_HELP_VERSION=1;
getopts('vdqo:k:', \my %opts) or die $USAGE;
my $VERBOSE = !!$opts{v};
my $DEBUG = !!$opts{d};
my $QUIET = !!$opts{q};
my $OUTDIR = defined($opts{o}) ? $opts{o} : curdir;
die "not a directory: $OUTDIR" unless -d $OUTDIR;
my $KWALDIR = $opts{k};
die "not a directory: $KWALDIR" if defined($KWALDIR) && !-d $KWALDIR;
warn "Warning: OUTDIR and KWALDIR shouldn't be the same\n"
	if defined($KWALDIR) && $KWALDIR eq $OUTDIR;
@ARGV==1 or die $USAGE;
my $AUTHOR = uc $ARGV[0];
die "bad author $AUTHOR" unless $AUTHOR=~/\A\w+\z/;

if ($DEBUG) { require Data::Dump; Data::Dump->import("dd") }

my $http = HTTP::Tiny->new();

my @dists = do {
	my $uri = URI->new('http://fastapi.metacpan.org/v1/release/_search');
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
	$$dist[0]=~/\A[\w\-]+\z/ or die "bad dist: $$dist[0]";
	$$dist[1]=~/\A[\w\-\.]+\z/ or die "bad version: $$dist[1]";
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
		$percent = 1 if $percent<1 && $pass+$fail>0; # round up from 0%
		$text = "$percent%";
		if    ($percent>=100) { $color="brightgreen" }
		elsif ($percent>=90)  { $color="green"       }
		elsif ($percent>=50)  { $color="yellow"      }
		else                  { $color="red"         }
	}
	my $outfile = catfile($OUTDIR,"$$data{dist}.svg");
	my (undef,$outfh,$repl) = replace3($outfile, perms=>0644, debug=>$DEBUG);
	print {$outfh} badge( left=>"CPAN Testers", right=>$text, color=>$color )
		->toString;
	$repl->finish;
	print STDERR "Wrote $outfile ($text $color)\n" unless $QUIET;
	print STDERR "Suggested link: http://matrix.cpantesters.org/?dist=$$data{dist}\n" unless $QUIET;
}

if (defined $KWALDIR) {
	my $uri = "https://cpants.cpanauthors.org/author/HAUKEX.json";
	my $resp = $http->get("$uri");
	die "$uri: $$resp{status} $$resp{reason}" unless $resp->{success};
	print STDERR "$uri: $$resp{status} $$resp{reason}\n" if $VERBOSE;
	my $data = decode_json($resp->{content});
	$DEBUG and dd($data);
	for my $kd ( @{ $data->{cpan_distributions} } ) {
		my ($name,$score) = @$kd{'name','score'};
		$name=~/\A[\w\-]+\z/ or die "bad dist: $name";
		$score=~/\A\d+(?:\.\d+)?\z/ or die "bad score: $score";
		my $color;
		# looking at https://cpants.cpanauthors.org/ranking,
		# it seems we should probably set the cutoffs pretty high
		if    ($score>=100) { $color="brightgreen" }
		elsif ($score>=95)  { $color="green"       }
		elsif ($score>=80)  { $color="yellow"      }
		else                { $color="red"         }
		my $outfile = catfile($KWALDIR,"$name.svg");
		my (undef,$outfh,$repl) = replace3($outfile, perms=>0644, debug=>$DEBUG);
		print {$outfh} badge( left=>"kwalitee", right=>$score, color=>$color )
			->toString;
		$repl->finish;
		print STDERR "Wrote $outfile ($score $color)\n" unless $QUIET;
		print STDERR "Suggested link: https://cpants.cpanauthors.org/dist/$name\n" unless $QUIET;
	}
}

