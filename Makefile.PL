use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'			=> 'Parse::CPAN::Distributions',
    'VERSION_FROM'	=> 'lib/Parse/CPAN/Distributions.pm',
    'PREREQ_PM'		=> {
        CPAN::DistnameInfo  => 0,
        File::Basename      => 0,
        File::Path          => 0,
        File::Slurp         => 0,
        File::Temp          => 0,
        IO::File            => 0,
        IO::Zlib            => 0,
        LWP::UserAgent      => 0,
		Test::More	        => 0.70,	# for testing
        version             => 0,
	},
	NO_META			=> 1,

    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT	=> 'Provides an index for current CPAN distributions',
       AUTHOR	=> 'Barbie <barbie@cpan.org>') : ()),
);
