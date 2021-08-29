#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Corinna::RFC::Config::Reader;

my $reader = Corinna::RFC::Config::Reader->new( file => 't/test.conf');

my $expected = {
    '_'     => [ { key => 'root', value => 'something' }, ],
    section => [
        { key => 'one',   value => 'two' },
        { key => 'one',   value => 'three' },
        { key => 'Foo',   value => 'Bar' },
        { key => 'this',  value => 'Your Mother!' },
        { key => 'blank', value => '' },
    ],
    'Section Two' => {
        'something else' => 'blah',
        'remove'         => 'whitespace'
    },
};
is_deeply( $reader->config, $expected, 'Config structure matches expected' );

done_testing;
