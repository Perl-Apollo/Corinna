use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
    NAME               => 'Corinna::RFC::Writer',
    AUTHOR             => q{Curtis "Ovid" Poe <ovid@allaroundtheworld.fr>},
    VERSION_FROM       => 'lib/Corinna/RFC/Writer.pm',
    ABSTRACT_FROM      => 'lib/Corinna/RFC/Writer.pm',
    LICENSE            => 'artistic_2',
    MIN_PERL_VERSION   => '5.026',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    TEST_REQUIRES => {
        'Test::Most'           => '0.37',
        'Keyword::DEVELOPMENT' => '0.07',
    },
    PREREQ_PM => {
        'Object::Pad'            => '0.52',
        'Moose'                  => '2.2014',
        'Moo'                    => '2.005003',
        'Syntax::Keyword::Try'   => '0.25',
        'Template::Tiny::Strict' => '1.18',
        'Regexp::Common'         => '2017060201',
        'Readonly'               => '2.05',
        'Type::Tiny'             => '1.012004',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Corinna-RFC-Writer-*' },
    test  => {
        TESTS =>
          't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t t/*/*/*/*/*.t t/*/*/*/*/*/*.t'
    }
);

# Compatibility with old versions of ExtUtils::MakeMaker
unless ( eval { ExtUtils::MakeMaker->VERSION('6.64'); 1 } ) {
    my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES} || {};
    @{ $WriteMakefileArgs{PREREQ_PM} }{ keys %$test_requires } =
      values %$test_requires;
}

unless ( eval { ExtUtils::MakeMaker->VERSION('6.55_03'); 1 } ) {
    my $build_requires = delete $WriteMakefileArgs{BUILD_REQUIRES} || {};
    @{ $WriteMakefileArgs{PREREQ_PM} }{ keys %$build_requires } =
      values %$build_requires;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION('6.52'); 1 };
delete $WriteMakefileArgs{MIN_PERL_VERSION}
  unless eval { ExtUtils::MakeMaker->VERSION('6.48'); 1 };
delete $WriteMakefileArgs{LICENSE}
  unless eval { ExtUtils::MakeMaker->VERSION('6.31'); 1 };

WriteMakefile(%WriteMakefileArgs);
