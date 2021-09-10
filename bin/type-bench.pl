#!/usr/bin/env perl

use 5.26.0;
use warnings;
use lib 'lib';
use YAML::Tiny;
use Benchmark 'cmpthese';

my $sample_data    = YAML::Tiny->read_string( yaml() )->[0];
my $o_pad          = Object::Pad::Test->get_definition();
my $moose          = Moose::Test->get_definition();
my $moo            = Moo::Test->get_definition();
my $types_standard = Types::Standard::Test->get_definition();

cmpthese(
    50_000,
    {
        'Object::Pad'     => sub { $o_pad->validate($sample_data) },
        'Moose'           => sub { $moose->validate($sample_data) },
        'Moo'             => sub { $moo->validate($sample_data) },
        'Types::Standard' => sub { $types_standard->($sample_data) },
        'O:P/construct'   => sub { Object::Pad::Test->get_definition->validate($sample_data) },
        'Moose/construct' => sub { Moose::Test->get_definition->validate($sample_data) },
        'Moo/construct'   => sub { Moose::Test->get_definition->validate($sample_data) },
        'T:S/construct'   => sub { Types::Standard::Test->get_definition->($sample_data) },
    }
);

sub yaml {
    my $yaml = <<~'END';
    doe: "a deer, a female deer"
    ray: "a drop of golden sun"
    pi: 3.14159
    xmas: true
    french-hens: 3
    calling-birds:
      - huey
      - dewey
      - louie
      - fred
    xmas-fifth-day:
      calling-birds: four
      french-hens: 3
      golden-rings: 5
      partridges:
        count: 1
        location: "a pear tree"
      turtle-doves: two
END
}

package Object::Pad::Test {
    use Object::Types ':all';

    sub get_definition {
        Dict(
            doe              => Str,
            ray              => Str,
            pi               => Num,
            xmas             => Enum(qw/true false/),
            'french-hens'    => Int,
            'calling-birds'  => ArrayRef( Enum(qw/huey dewey louie fred/) ),
            'xmas-fifth-day' => Dict(
                'calling-birds' => Str,
                'french-hens'   => Int,
                'golden-rings'  => Int,
                partridges      => Dict(
                    count             => Int,
                    location          => Str,
                    'lords-a-leaping' => Optional(Int),
                ),
                'turtle-doves' => Str,
            )
        );
    }
}

package Moose::Test {
    use Object::Types::Moose ':all';

    sub get_definition {
        Dict(
            doe              => Str,
            ray              => Str,
            pi               => Num,
            xmas             => Enum(qw/true false/),
            'french-hens'    => Int,
            'calling-birds'  => ArrayRef( Enum(qw/huey dewey louie fred/) ),
            'xmas-fifth-day' => Dict(
                'calling-birds' => Str,
                'french-hens'   => Int,
                'golden-rings'  => Int,
                partridges      => Dict(
                    count             => Int,
                    location          => Str,
                    'lords-a-leaping' => Optional(Int),
                ),
                'turtle-doves' => Str,
            )
        );
    }
}

package Moo::Test {
    use Object::Types::Moose ':all';

    sub get_definition {
        Dict(
            doe              => Str,
            ray              => Str,
            pi               => Num,
            xmas             => Enum(qw/true false/),
            'french-hens'    => Int,
            'calling-birds'  => ArrayRef( Enum(qw/huey dewey louie fred/) ),
            'xmas-fifth-day' => Dict(
                'calling-birds' => Str,
                'french-hens'   => Int,
                'golden-rings'  => Int,
                partridges      => Dict(
                    count             => Int,
                    location          => Str,
                    'lords-a-leaping' => Optional(Int),
                ),
                'turtle-doves' => Str,
            )
        );
    }
}

package Types::Standard::Test {
    use Types::Standard qw( Str Int Enum ArrayRef Dict Num Optional );
    use Type::Params qw( compile );

    sub get_definition {
        compile(
            Dict [
                doe           => Str,
                ray           => Str,
                pi            => Num,
                xmas          => Enum [qw/true false/],
                'french-hens' => Int,
                'calling-birds' =>
                  ArrayRef [ Enum [qw/huey dewey louie fred/] ],
                'xmas-fifth-day' => Dict [
                    'calling-birds' => Str,
                    'french-hens'   => Int,
                    'golden-rings'  => Int,
                    partridges      => Dict [
                        count             => Int,
                        location          => Str,
                        'lords-a-leaping' => Optional [Int],
                    ],
                    'turtle-doves' => Str,
                ]
            ]
        );
    }
}

__END__

=head1 NAME

bin/type-bench.pl - Benchmarks for Object::Pad (and ultimately, Corinna)

=head1 SYNOPSIS

    $ time perl bin/type-bench.pl
                       Rate T:S/construct Moo/construct Moose/construct O:P/construct   Moo Moose Object::Pad Types::Standard
    T:S/construct     693/s            --          -65%            -65%          -79%  -80%  -81%        -86%            -99%
    Moo/construct    1983/s          186%            --             -0%          -39%  -42%  -47%        -60%            -97%
    Moose/construct  1983/s          186%            0%              --          -39%  -42%  -47%        -60%            -97%
    O:P/construct    3234/s          366%           63%             63%            --   -6%  -13%        -35%            -96%
    Moo              3448/s          397%           74%             74%            7%    --   -7%        -31%            -96%
    Moose            3709/s          435%           87%             87%           15%    8%    --        -25%            -95%
    Object::Pad      4975/s          618%          151%            151%           54%   44%   34%          --            -94%
    Types::Standard 78125/s        11169%         3839%           3839%         2316% 2166% 2006%       1470%              -- 

    real    3m3.179s
    user    2m59.690s
    sys     0m1.171s

=head1 DESCRIPTION

To get a serious, real-world benchmark, we have re-implemented a subset of L<Types::Standard>
in L<Object::Pad>, L<Moose>, and L<Moo>. In short, this somewhat complex type constraint
is used to validate a data structure 50,000 times:

    Dict [
        doe              => Str,
        ray              => Str,
        pi               => Num,
        xmas             => Enum [qw/true false/],
        'french-hens'    => Int,
        'calling-birds'  => ArrayRef [ Enum [qw/huey dewey louie fred/] ],
        'xmas-fifth-day' => Dict [
            'calling-birds' => Str,
            'french-hens'   => Int,
            'golden-rings'  => Int,
            partridges      => Dict [
                count             => Int,
                location          => Str,
                'lords-a-leaping' => Optional [Int],
            ],
            'turtle-doves' => Str,
        ]
    ];

Unsurprisingly, C<Types::Standard> wins, hands down. However, we see
C<Object::Pad> is considerably faster than both C<Moose> and C<Moo>.
Interestingly, if you also include the "construct" step, C<Object::Pad> is far
and away the fastest, while C<Types::Standard> is the slowest.

If someone wants to contribute a C<bless> version to compare against, that
would be interesting.

There are tests for behavior in the C<t/> directory. They have been
cut-n-pasted, but could stand to be rewritten into a single test file.
