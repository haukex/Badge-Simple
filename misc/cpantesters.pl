#!/usr/bin/env perl
use warnings;
use strict;
use re '/aa';
use Getopt::Std 'getopts';
use URI ();
use HTTP::Tiny ();
use JSON::PP qw/decode_json/;
use File::Spec::Functions qw/curdir catfile splitdir/;
use Badge::Simple qw/badge/;
use File::Replace 'replace3';
$|=1;  # for better logging

# Generate "CPAN Testers" badges for a CPAN author's modules
# for an example usage see https://github.com/haukex/my-badges

my $MAX_RETRYCOUNT = 12;
my $RETRY_DELAY_S = 15;

my $USAGE = "Usage: $0 [-vdq] [-o OUTDIR] [-h HTMLOUT] CPANAUTHOR\n";
$Getopt::Std::STANDARD_HELP_VERSION=1;
getopts('vdqo:k:h:', \my %opts) or die $USAGE;
my $VERBOSE = !!$opts{v};
my $DEBUG = !!$opts{d};
my $QUIET = !!$opts{q};
my $OUTDIR = defined($opts{o}) ? $opts{o} : curdir;
die "not a directory: $OUTDIR" unless -d $OUTDIR;
die "Kwalitee badge generation removed, please use the native service at\n"
	."https://cpants.cpanauthors.org/dist/Dist-Name.svg\n" if $opts{k};
my $HTMLOUT;
if ($opts{h}) {
	die "please specify a filename without path for HTMLOUT"
		if @{[splitdir $opts{h}]}!=1;
	$HTMLOUT = catfile($OUTDIR,$opts{h});
	die "not a file: $HTMLOUT" if -e $HTMLOUT && !-f $HTMLOUT;
}
@ARGV==1 or die $USAGE;
my $AUTHOR = uc $ARGV[0];
die "bad author $AUTHOR" unless $AUTHOR=~/\A\w+\z/;

if ($DEBUG) { require Data::Dump; Data::Dump->import("dd") }

my $http = HTTP::Tiny->new();

my @dists = do {
	my $uri = URI->new('https://fastapi.metacpan.org/v1/release/_search');
	$uri->query_form({ q=>"author:$AUTHOR AND status:latest",
		fields=>"distribution,version", size=>5000 });
	my $resp = $http->get("$uri");
	$$resp{success} or die "$uri: $$resp{status} "
		.( $$resp{status}==599 ? $$resp{content} : $$resp{reason} );
	print STDERR "$uri: $$resp{status} $$resp{reason}\n" if $VERBOSE;
	my $data = decode_json($resp->{content});
	$DEBUG and dd($data);
	warn "WARNING: Module list was truncated at ".@{$data->{hits}{hits}}
		.", though ".$data->{hits}{total}." results are available.\n"
		if $data->{hits}{total} != @{$data->{hits}{hits}};
	sort { $$a[0] cmp $$b[0] }
		map { [ $_->{fields}{distribution}, $_->{fields}{version} ] }
		@{$data->{hits}{hits}};
};
die "Sorry, no hits for author $AUTHOR\n" unless @dists;
print STDERR "Found ",0+@dists," dists for $AUTHOR\n" unless $QUIET;

my $htmlo;
if ($HTMLOUT) {
	$htmlo = File::Replace->new($HTMLOUT, ':raw:encoding(UTF-8)', perms=>0644, debug=>$DEBUG);
	print {$htmlo->out_fh} <<"END HTML";
<!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<title>CPAN Testers Badges for $AUTHOR</title>
</head>
<body>
<h1>CPAN Testers Badges for $AUTHOR</h1>
<ul>
END HTML
}

for my $dist (@dists) {
	$$dist[0]=~/\A[\w\-]+\z/ or die "bad dist: $$dist[0]";
	$$dist[1]=~/\A[\w\-\.]+\z/ or die "bad version: $$dist[1]";
	my $uri = URI->new('https://api.cpantesters.org/v3/release/dist');
	$uri->path_segments( $uri->path_segments, $$dist[0], $$dist[1] );
	sleep 2;  # don't hit the API too hard, it doesn't seem to like that
	my $retrycount = 0;
	my $resp = $http->get("$uri");
	while (!$$resp{success}) {
		my $msg = "$uri: $$resp{status} "
			.( $$resp{status}==599 ? $$resp{content} : $$resp{reason} );
		die $msg if ++$retrycount > $MAX_RETRYCOUNT;
		warn "$msg, retrying in ${RETRY_DELAY_S}s\n";
		sleep $RETRY_DELAY_S;
		$resp = $http->get("$uri");
	}
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
	my $basename = "$$data{dist}.svg";
	my $outfile = catfile($OUTDIR,$basename);
	my (undef,$outfh,$repl) = replace3($outfile, perms=>0644, debug=>$DEBUG);
	print {$outfh} badge( left=>"CPAN Testers", right=>$text, color=>$color )
		->toString;
	$repl->finish;
	print STDERR "Wrote $outfile ($text $color)\n" unless $QUIET;
	print STDERR "Suggested link: http://matrix.cpantesters.org/?dist=$$data{dist}\n" unless $QUIET;
	print {$htmlo->out_fh}
		qq{\t<li>$$data{dist}: <a href="http://matrix.cpantesters.org/?dist=$$data{dist}">}
		.qq{<img src="$basename" alt="$$data{dist} CPAN Testers: $text"></a></li>\n} if $htmlo;
}

if ($htmlo) {
	print {$htmlo->out_fh} <<"END HTML";
</ul>
</body>
</html>
END HTML
	$htmlo->finish;
	print STDERR "Wrote $HTMLOUT\n" unless $QUIET;
}
