#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use RFC::Config::Reader;

my $Config = RFC::Config::Reader->new('t/test.conf');

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
bless $expected, 'RFC::Config::Reader';
is_deeply( $Config, $expected, 'Config structure matches expected' );

done_testing;
