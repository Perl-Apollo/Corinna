#!/usr/bin/env perl

use Test::Most;
use Corinna::RFC::Config::Reader;

my $reader   = Corinna::RFC::Config::Reader->new( file => 't/test.conf' );
my $expected = {
    rfcs => [
        { value => 'overview.md', key   => 'Overview' },
        { key   => 'Grammar',     value => 'grammar.md' },
        { key   => 'Classes',     value => 'classes.md' },
        { key   => 'Attributes',  value => 'attributes.md' },
        { value => 'methods.md',  key   => 'Methods' }
    ],
    main => {
        toc_marker   => '{{TOC}}',
        rfc_dir      => 'rfc',
        template_dir => 'templates',
        github       => 'https://github.com/Ovid/Cor',
        toc          => 'toc.md',
        readme       => 'README.md'
    }
};

my $config = $reader->config;
eq_or_diff $config, $expected, 'Config structure matches expected';
delete $config->{rfcs};
eq_or_diff $reader->config, $expected,
'Mutating the reference returned by ->config should not mutate the underlying ddta';

# Long-term, we should be able to add tests to verify that private methods are
# not returned by ->can, nor should exported functions.

done_testing;
