#!/usr/bin/env perl
use ExtUtils::MakeMaker 6.52;  # need >=6.52 for CONFIGURE_REQUIRES
# and in CONFIGURE_REQUIRES, we require >=6.64 for TEST_REQUIRES
WriteMakefile(
	NAME           => 'Badge::Simple',
	AUTHOR         => 'Hauke D <haukex@zero-g.net>',
	LICENSE        => 'perl_5',
	VERSION_FROM   => 'lib/Badge/Simple.pm', # finds $VERSION
	ABSTRACT_FROM  => 'lib/Badge/Simple.pm',
	MIN_PERL_VERSION => '5.6.0',
	META_MERGE     => {
		'meta-spec'  => { version => 2 },
		provides     => {
			'Badge::Simple' => {
				file    => 'lib/Badge/Simple.pm',
				version => '0.03',
			},
		},
		resources    => {
			homepage    => 'https://github.com/haukex/Badge-Simple',
			repository  => {
				type       => 'git',
				url        => 'https://github.com/haukex/Badge-Simple.git',
				web        => 'https://github.com/haukex/Badge-Simple',
			},
			bugtracker  => {
				web        => 'https://github.com/haukex/Badge-Simple/issues',
				#mailto     => '',
			},
		},
		prereqs      => {
			runtime    => {
				recommends => { # "strongly encouraged and should be satisfied except in resource constrained environments"
				},
				suggests   => { # "optional, but are suggested for enhanced operation"
				},
			},
		},
	},
	EXE_FILES => [
		( $] ge '5.008' ? 'bin/badge' : () ),
	],
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker'    => '6.64',
	},
	PREREQ_PM      => {
		# CPAN
		'Imager'                 => '1.000',
		'XML::LibXML'            => '2.0122',
		# Perl core modules
		'Carp'                   => 0,
		'Exporter'               => 0,
		'File::Basename'         => 0,
		'File::Spec::Functions'  => 0,
	},
	TEST_REQUIRES  => {
		# CPAN - none
		# Perl core modules
		'Test::More'             => '1.302096',
		'FindBin'                => 0,
		'File::Temp'             => 0,
		'File::Glob'             => 0,
		# note I haven't included modules needed for author tests here
	},
);
