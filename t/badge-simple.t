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
use XML::LibXML ();
use Imager ();

## no critic (RequireCarping)

use Test::More tests=>8;

BEGIN {
	diag "This is Perl $] at $^X on $^O";
	use_ok 'Badge::Simple', 'badge';
}
is $Badge::Simple::VERSION, '0.04', 'Badge::Simple version matches tests';

my $fontfile = catfile($FindBin::Bin,updir,'lib','Badge','Simple','DejaVuSans.ttf');

{
	diag "Imager::Font version is $Imager::Font::VERSION, available formats are: ",
		join(', ', grep { $Imager::formats{$_} } qw/ tt t1 w32 ft2 /);  ## no critic (ProhibitPackageVars)
	die "Font file $fontfile doesn't exist" unless -e $fontfile;
	diag "Attempting to load font ", explain $fontfile;
	my $font = Imager::Font->new( file => $fontfile )
		or die "failed to load font: ".Imager->errstr;
	diag "Imager::Font class is ", ref $font;
	for my $str ('foo','Yadda yadda','The quick brown fox jumps over the lazy dog.') {
		diag "display_width of '$str' is ",$font->bounding_box(size=>11, string=>$str)->display_width;
	}
}

sub is_svg_similar ($$;$);  ## no critic (ProhibitSubroutinePrototypes)

subtest 'is_svg_similar' => \&test_is_svg_similar;

{
	my $exp = XML::LibXML->load_xml(
		location => catfile($FindBin::Bin, 'hello.svg'),
		no_blanks=>1 );
	my $got = badge( left => "Hello", right => "World!", color => "yellow", font=>$fontfile );
	is_svg_similar $got, $exp, 'hello.svg';
}

{
	my $exp = XML::LibXML->load_xml(
		location => catfile($FindBin::Bin, 'cpt100.svg'),
		no_blanks=>1 );
	my $got = badge( left=>'CPAN Testers', right=>'100%', color=>'brightgreen', font=>$fontfile );
	is_svg_similar $got, $exp, 'cpt100.svg';
}

{
	my $exp = XML::LibXML->load_xml(
		location => catfile($FindBin::Bin, 'foo.svg'),
		no_blanks=>1 );
	my $got = badge( left=>'foo', right=>'bar', color=>'#e542f4', font=>$fontfile, style=>"flat" );
	is_svg_similar $got, $exp, 'foo.svg';
}

subtest 'CLI' => sub {
	plan $] ge '5.008' ? ( tests=>2 ) : ( skip_all=>'bin/badge requires perl 5.008' );
	
	my ($tfh, $outfile) = tempfile(UNLINK=>1);
	close $tfh;
	
	my $script = catfile($FindBin::Bin, updir, 'bin', 'badge');
	#TODO: should probably inspect STDOUT and STDERR here
	is system($^X, $script, qw/ --left Hello --right World!
		--color yellow --out /, $outfile, '--font', $fontfile ),
		0, 'bin/badge';
	
	my $exp = XML::LibXML->load_xml(
		location => catfile($FindBin::Bin, 'hello.svg'),
		no_blanks=>1 );
	my $got = XML::LibXML->load_xml(
		location => $outfile, no_blanks=>1 );
	is_svg_similar $got, $exp, 'hello.svg';
};

sub exception (&) {  ## no critic (ProhibitSubroutinePrototypes)
	return eval { shift->(); 1 } ? undef : ($@ || die "\$@ was false");
}

subtest 'errors' => sub {
	like exception { badge("foo") }, qr/\bbad number of arguments\b/i, 'bad number of arguments';
	like exception { badge(foo=>"bar") }, qr/\bunknown argument\b/i, 'unknown argument';
	like exception { badge() }, qr/\bmust specify '(?:left|right)'/i, 'missing arguments';
	like exception { badge(left=>"foo",right=>"bar",color=>"quz") }, qr/\bbad color\b/i, 'bad color name';
	like exception { badge(left=>"foo",right=>"bar",color=>"#a") }, qr/\bbad color\b/i, 'bad hex color 1';
	like exception { badge(left=>"foo",right=>"bar",color=>"#xyzabc") }, qr/\bbad color\b/i, 'bad hex color 2';
	like exception { badge(left=>"foo",right=>"bar",style=>"foo") }, qr/\bbad style\b/i, 'bad style';
	like exception { badge(left=>"foo",right=>"bar",font=>"this_file_shouldnt_exist") }, qr/\bunable to find font file\b/i, 'bad font';
	like exception { badge(left=>"foo",right=>"bar",font=>$0) }, qr/\bfailed to load font\b/i, 'invalid font';
	local $Badge::Simple::DEFAULT_FONT = undef;
	like exception { badge(left=>"foo",right=>"bar") }, qr/\bno font specified and failed to load default font\b/i, 'no font at all';
};
badge(left=>"foo",right=>"bar"); # for now, this is just here to make code coverage happy (default color)

=begin comment

CPAN Testers has shown that there are slight variations in the
calculation of the font widths. I'm currently assuming this is
because of differences in the underlying font libraries. An
analysis by F<scrape_cpantesters.pl> on 2018-11-04 showed the
differences as recorded in the C<%samples> hash below.

Disclaimer: I don't like this solution, but here it is anyway. If
you can think of a better way to handle this, please let me know.

In C<pick_apart_svg>, I pull all the relevant width attributes
that were generated by C<Badge::Simple::badge()> back out of the
XML. Then, I check that the widths are within some deltas that I
derived from the CPAN Testers reports. At the moment, these deltas
seem fairly large to me, but I'll have to see what CPAN Testers
reports back about this version of the tests and go from there.

=end comment

=cut


sub test_is_svg_similar { # testing our tests...
	my %samples = (
		"hello.svg"  => { exp  => "<svg xmlns=\"http://www.w3.org/2000/svg\" height=\"20\" width=\"83\" ><linearGradient id=\"smooth\" x2=\"0\" y2=\"100%\"><stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"></stop><stop offset=\"1\" stop-opacity=\".1\"></stop></linearGradient><clipPath id=\"round\"><rect fill=\"#fff\" height=\"20\" rx=\"3\" width=\"83\" ></rect></clipPath><g clip-path=\"url(#round)\"><rect fill=\"#555\" height=\"20\" width=\"38\"></rect><rect fill=\"#dfb317\" height=\"20\" width=\"45\" x=\"38\"></rect><rect fill=\"url(#smooth)\" height=\"20\" width=\"83\" ></rect></g><g fill=\"#fff\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\" text-anchor=\"middle\"><text fill=\"#010101\" fill-opacity=\".3\" x=\"20\"   y=\"15\">Hello</text>       <text x=\"20\"   y=\"14\">Hello</text>       <text fill=\"#010101\" fill-opacity=\".3\" x=\"59.5\"  y=\"15\">World!</text><text x=\"59.5\"  y=\"14\">World!</text></g></svg>",
		                  got1 => "<svg xmlns=\"http://www.w3.org/2000/svg\" height=\"20\" width=\"87\" ><linearGradient id=\"smooth\" x2=\"0\" y2=\"100%\"><stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"></stop><stop offset=\"1\" stop-opacity=\".1\"></stop></linearGradient><clipPath id=\"round\"><rect fill=\"#fff\" height=\"20\" rx=\"3\" width=\"87\" ></rect></clipPath><g clip-path=\"url(#round)\"><rect fill=\"#555\" height=\"20\" width=\"39\"></rect><rect fill=\"#dfb317\" height=\"20\" width=\"48\" x=\"39\"></rect><rect fill=\"url(#smooth)\" height=\"20\" width=\"87\" ></rect></g><g fill=\"#fff\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\" text-anchor=\"middle\"><text fill=\"#010101\" fill-opacity=\".3\" x=\"20.5\" y=\"15\">Hello</text>       <text x=\"20.5\" y=\"14\">Hello</text>       <text fill=\"#010101\" fill-opacity=\".3\" x=\"62\"    y=\"15\">World!</text><text x=\"62\"    y=\"14\">World!</text></g></svg>",
		                  got2 => "<svg xmlns=\"http://www.w3.org/2000/svg\" height=\"20\" width=\"87\" ><linearGradient id=\"smooth\" x2=\"0\" y2=\"100%\"><stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"></stop><stop offset=\"1\" stop-opacity=\".1\"></stop></linearGradient><clipPath id=\"round\"><rect fill=\"#fff\" height=\"20\" rx=\"3\" width=\"87\" ></rect></clipPath><g clip-path=\"url(#round)\"><rect fill=\"#555\" height=\"20\" width=\"40\"></rect><rect fill=\"#dfb317\" height=\"20\" width=\"47\" x=\"40\"></rect><rect fill=\"url(#smooth)\" height=\"20\" width=\"87\" ></rect></g><g fill=\"#fff\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\" text-anchor=\"middle\"><text fill=\"#010101\" fill-opacity=\".3\" x=\"21\"   y=\"15\">Hello</text>       <text x=\"21\"   y=\"14\">Hello</text>       <text fill=\"#010101\" fill-opacity=\".3\" x=\"62.5\"  y=\"15\">World!</text><text x=\"62.5\"  y=\"14\">World!</text></g></svg>" },
		"cpt100.svg" => { exp  => "<svg xmlns=\"http://www.w3.org/2000/svg\" height=\"20\" width=\"129\"><linearGradient id=\"smooth\" x2=\"0\" y2=\"100%\"><stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"></stop><stop offset=\"1\" stop-opacity=\".1\"></stop></linearGradient><clipPath id=\"round\"><rect fill=\"#fff\" height=\"20\" rx=\"3\" width=\"129\"></rect></clipPath><g clip-path=\"url(#round)\"><rect fill=\"#555\" height=\"20\" width=\"88\"></rect><rect fill=\"#4c1\"    height=\"20\" width=\"41\" x=\"88\"></rect><rect fill=\"url(#smooth)\" height=\"20\" width=\"129\"></rect></g><g fill=\"#fff\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\" text-anchor=\"middle\"><text fill=\"#010101\" fill-opacity=\".3\" x=\"45\"   y=\"15\">CPAN Testers</text><text x=\"45\"   y=\"14\">CPAN Testers</text><text fill=\"#010101\" fill-opacity=\".3\" x=\"107.5\" y=\"15\">100%</text>  <text x=\"107.5\" y=\"14\">100%</text>  </g></svg>",
		                  got1 => "<svg xmlns=\"http://www.w3.org/2000/svg\" height=\"20\" width=\"131\"><linearGradient id=\"smooth\" x2=\"0\" y2=\"100%\"><stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"></stop><stop offset=\"1\" stop-opacity=\".1\"></stop></linearGradient><clipPath id=\"round\"><rect fill=\"#fff\" height=\"20\" rx=\"3\" width=\"131\"></rect></clipPath><g clip-path=\"url(#round)\"><rect fill=\"#555\" height=\"20\" width=\"89\"></rect><rect fill=\"#4c1\"    height=\"20\" width=\"42\" x=\"89\"></rect><rect fill=\"url(#smooth)\" height=\"20\" width=\"131\"></rect></g><g fill=\"#fff\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\" text-anchor=\"middle\"><text fill=\"#010101\" fill-opacity=\".3\" x=\"45.5\" y=\"15\">CPAN Testers</text><text x=\"45.5\" y=\"14\">CPAN Testers</text><text fill=\"#010101\" fill-opacity=\".3\" x=\"109\"   y=\"15\">100%</text>  <text x=\"109\"   y=\"14\">100%</text>  </g></svg>",
		                  got2 => "<svg xmlns=\"http://www.w3.org/2000/svg\" height=\"20\" width=\"132\"><linearGradient id=\"smooth\" x2=\"0\" y2=\"100%\"><stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"></stop><stop offset=\"1\" stop-opacity=\".1\"></stop></linearGradient><clipPath id=\"round\"><rect fill=\"#fff\" height=\"20\" rx=\"3\" width=\"132\"></rect></clipPath><g clip-path=\"url(#round)\"><rect fill=\"#555\" height=\"20\" width=\"89\"></rect><rect fill=\"#4c1\"    height=\"20\" width=\"43\" x=\"89\"></rect><rect fill=\"url(#smooth)\" height=\"20\" width=\"132\"></rect></g><g fill=\"#fff\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\" text-anchor=\"middle\"><text fill=\"#010101\" fill-opacity=\".3\" x=\"45.5\" y=\"15\">CPAN Testers</text><text x=\"45.5\" y=\"14\">CPAN Testers</text><text fill=\"#010101\" fill-opacity=\".3\" x=\"109.5\" y=\"15\">100%</text>  <text x=\"109.5\" y=\"14\">100%</text>  </g></svg>" },
		"foo.svg"    => { exp  => "<svg xmlns=\"http://www.w3.org/2000/svg\" height=\"20\" width=\"59\" ><linearGradient id=\"smooth\" x2=\"0\" y2=\"100%\"><stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"></stop><stop offset=\"1\" stop-opacity=\".1\"></stop></linearGradient><clipPath id=\"round\"><rect fill=\"#fff\" height=\"20\" rx=\"3\" width=\"59\" ></rect></clipPath><g clip-path=\"url(#round)\"><rect fill=\"#555\" height=\"20\" width=\"29\"></rect><rect fill=\"#e542f4\" height=\"20\" width=\"30\" x=\"29\"></rect><rect fill=\"url(#smooth)\" height=\"20\" width=\"59\" ></rect></g><g fill=\"#fff\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\" text-anchor=\"middle\"><text fill=\"#010101\" fill-opacity=\".3\" x=\"15.5\" y=\"15\">foo</text>         <text x=\"15.5\" y=\"14\">foo</text>         <text fill=\"#010101\" fill-opacity=\".3\" x=\"43\"    y=\"15\">bar</text>   <text x=\"43\"    y=\"14\">bar</text>   </g></svg>",
		                  got1 => "<svg xmlns=\"http://www.w3.org/2000/svg\" height=\"20\" width=\"60\" ><linearGradient id=\"smooth\" x2=\"0\" y2=\"100%\"><stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"></stop><stop offset=\"1\" stop-opacity=\".1\"></stop></linearGradient><clipPath id=\"round\"><rect fill=\"#fff\" height=\"20\" rx=\"3\" width=\"60\" ></rect></clipPath><g clip-path=\"url(#round)\"><rect fill=\"#555\" height=\"20\" width=\"30\"></rect><rect fill=\"#e542f4\" height=\"20\" width=\"30\" x=\"30\"></rect><rect fill=\"url(#smooth)\" height=\"20\" width=\"60\" ></rect></g><g fill=\"#fff\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\" text-anchor=\"middle\"><text fill=\"#010101\" fill-opacity=\".3\" x=\"16\"   y=\"15\">foo</text>         <text x=\"16\"   y=\"14\">foo</text>         <text fill=\"#010101\" fill-opacity=\".3\" x=\"44\"    y=\"15\">bar</text>   <text x=\"44\"    y=\"14\">bar</text>   </g></svg>",
		                  got2 => "<svg xmlns=\"http://www.w3.org/2000/svg\" height=\"20\" width=\"61\" ><linearGradient id=\"smooth\" x2=\"0\" y2=\"100%\"><stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"></stop><stop offset=\"1\" stop-opacity=\".1\"></stop></linearGradient><clipPath id=\"round\"><rect fill=\"#fff\" height=\"20\" rx=\"3\" width=\"61\" ></rect></clipPath><g clip-path=\"url(#round)\"><rect fill=\"#555\" height=\"20\" width=\"30\"></rect><rect fill=\"#e542f4\" height=\"20\" width=\"31\" x=\"30\"></rect><rect fill=\"url(#smooth)\" height=\"20\" width=\"61\" ></rect></g><g fill=\"#fff\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\" text-anchor=\"middle\"><text fill=\"#010101\" fill-opacity=\".3\" x=\"16\"   y=\"15\">foo</text>         <text x=\"16\"   y=\"14\">foo</text>         <text fill=\"#010101\" fill-opacity=\".3\" x=\"44.5\"  y=\"15\">bar</text>   <text x=\"44.5\"  y=\"14\">bar</text>   </g></svg>" },
	);
	for my $k (sort keys %samples) {
		for my $bk ( sort keys %{$samples{$k}} ) {
			is_svg_similar(
				XML::LibXML->load_xml( string => $samples{$k}{$bk} ),
				XML::LibXML->load_xml( string => $samples{$k}{exp} ),
				"is_svg_similar $k $bk" );
		}
	}
	return;
}

sub is_svg_similar ($$;$) {  ## no critic (ProhibitSubroutinePrototypes)
	my ($got_doc,$exp_doc,$name) = @_;
	return subtest $name => sub {
		if ($exp_doc->toStringC14N eq $got_doc->toStringC14N) {
			pass "toStringC14N *exact* match";
			return } # else:
		my $exp = pick_apart_svg($exp_doc);
		my $got = pick_apart_svg($got_doc);
		is $got->{xml}, $exp->{xml}, 'NO exact match; cleaned XML matches';
		for my $k (qw/ total_w l_w r_w l_txt_c r_txt_c /) {
			my $delta = abs( $exp->{$k} - $got->{$k} );
			my $max_err = $k eq 'total_w' ? 8 : 4; #TODO Later: Can we make these smaller? (see misc/scrape_cpantesters.pl for equation)
			if ($exp->{$k}<100) # for lengths of <100 pixels, apply error to pixel count
				{ ok $delta<=$max_err, "$k: exp $$exp{$k}, got $$got{$k}, delta $delta is <= ${max_err}px" }
			else { # for lengths of >=100 pixels, apply error to percentage difference
				my $percent = sprintf "%0.1f", 100*$delta/$exp->{$k};
				ok $percent<=$max_err, "$k: exp $$exp{$k}, got $$got{$k}, delta $delta ($percent%) <= $max_err%";
			}
		}
	};
}

sub pick_apart_svg {
	my $dom = shift;
	my $xpc = XML::LibXML::XPathContext->new($dom);
	$xpc->registerNs('s', 'http://www.w3.org/2000/svg');
	my (%attr,%out);
	
	# $total_w shows up three times:
	$attr{total_w_1} = $xpc->find('/s:svg/@width')->get_node(0);
	$attr{total_w_2} = $xpc->find('/s:svg/s:clipPath/s:rect/@width')->get_node(0);
	die $attr{total_w_2} unless $attr{total_w_2}->value eq $attr{total_w_1}->value;
	$attr{total_w_3} = $xpc->find('/s:svg/s:g[1]/s:rect[3]/@width')->get_node(0);
	die $attr{total_w_3} unless $attr{total_w_3}->value eq $attr{total_w_1}->value;
	$out{total_w} = $attr{total_w_1}->value;
	$attr{"total_w_$_"}->setValue('total_w') for 1..3;
	
	# $l_w shows up twice:
	$attr{l_w_1} = $xpc->find('/s:svg/s:g[1]/s:rect[1]/@width')->get_node(0);
	$attr{l_w_2} = $xpc->find('/s:svg/s:g[1]/s:rect[2]/@x')->get_node(0);
	die $attr{l_w_2} unless $attr{l_w_2}->value eq $attr{l_w_1}->value;
	$out{l_w} = $attr{l_w_1}->value;
	$attr{"l_w_$_"}->setValue('l_w') for 1..2;
	
	# $r_w shows up once:
	$attr{r_w_1} = $xpc->find('/s:svg/s:g[1]/s:rect[2]/@width')->get_node(0);
	$out{r_w} = $attr{r_w_1}->value;
	$attr{"r_w_1"}->setValue('r_w');
	
	# $l_txt_c shows up twice:
	$attr{l_txt_c_1} = $xpc->find('/s:svg/s:g[2]/s:text[1]/@x')->get_node(0);
	$attr{l_txt_c_2} = $xpc->find('/s:svg/s:g[2]/s:text[2]/@x')->get_node(0);
	die $attr{l_txt_c_2} unless $attr{l_txt_c_2}->value eq $attr{l_txt_c_1}->value;
	$out{l_txt_c} = $attr{l_txt_c_1}->value;
	$attr{"l_txt_c_$_"}->setValue('l_txt_c') for 1..2;
	
	# $r_txt_c shows up twice:
	$attr{r_txt_c_1} = $xpc->find('/s:svg/s:g[2]/s:text[3]/@x')->get_node(0);
	$attr{r_txt_c_2} = $xpc->find('/s:svg/s:g[2]/s:text[4]/@x')->get_node(0);
	die $attr{r_txt_c_2} unless $attr{r_txt_c_2}->value eq $attr{r_txt_c_1}->value;
	$out{r_txt_c} = $attr{r_txt_c_1}->value;
	$attr{"r_txt_c_$_"}->setValue('r_txt_c') for 1..2;
	
	$out{xml} = $dom->toStringC14N();
	
	return \%out;
}
