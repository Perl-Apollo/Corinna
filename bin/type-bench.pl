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
        'Moo/construct'   => sub { Moo::Test->get_definition->validate($sample_data) },
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
    use Object::Types::Moo ':all';

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
                       Rate T:S/construct Moose/construct Moo/construct O:P/construct Moose Object::Pad   Moo Types::Standard
    T:S/construct     716/s            --            -66%          -78%          -78%  -82%        -86%  -87%            -99%
    Moose/construct  2098/s          193%              --          -35%          -37%  -48%        -59%  -60%            -97%
    Moo/construct    3218/s          350%             53%            --           -3%  -20%        -38%  -39%            -96%
    O:P/construct    3327/s          365%             59%            3%            --  -17%        -35%  -37%            -96%
    Moose            4023/s          462%             92%           25%           21%    --        -22%  -24%            -95%
    Object::Pad      5155/s          620%            146%           60%           55%   28%          --   -3%            -94%
    Moo              5302/s          641%            153%           65%           59%   32%          3%    --            -93%
    Types::Standard 79365/s        10989%           3683%         2367%         2286% 1873%       1440% 1397%              --

    real    3m3.179s
    user    2m59.690s
    sys     0m1.171s

=head1 DESCRIPTION

To get a heavier-duty benchmark than simply creating objects and changing a
few values, we have re-implemented a subset of L<Types::Standard> in
L<Object::Pad>, L<Moose>, and L<Moo>. In short, this somewhat complex type
constraint is used to validate a data structure 50,000 times:

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
C<Object::Pad> is considerably faster than both C<Moose> and C<Moo> if you
include object construction. Otherwise, C<Object::Pad> and C<Moo> are about
neck and neck as of this writing (September 10, 2021);

If someone wants to contribute a C<bless> version to compare against, that
would be interesting.

There are tests for behavior in the C<t/> directory. They have been
cut-n-pasted, but could stand to be rewritten into a single test file.
