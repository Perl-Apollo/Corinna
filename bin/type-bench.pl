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
        'Object::Pad with construct' =>
          sub { Object::Pad::Test->get_definition->validate($sample_data) },
        'Moose with construct' =>
          sub { Moose::Test->get_definition->validate($sample_data) },
        'Moo with construct' =>
          sub { Moose::Test->get_definition->validate($sample_data) },
        'Types::Standard with construct' =>
          sub { Types::Standard::Test->get_definition->($sample_data) },
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
    use Type::Params qw( construct );

    sub get_definition {
        construct(
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
                                    Rate Types::Standard with construct Moo with construct Moose with construct Object::Pad with construct   Moo Moose Object::Pad Types::Standard
    Types::Standard with construct   686/s                           --             -63%               -65%                     -78%  -79%  -82%        -86%            -99%
    Moo with construct              1860/s                         171%               --                -4%                     -42%  -44%  -51%        -62%            -98%
    Moose with construct            1940/s                         183%               4%                 --                     -39%  -41%  -49%        -60%            -98%
    Object::Pad with construct      3189/s                         365%              71%                64%                       --   -4%  -16%        -34%            -96%
    Moo                             3305/s                         381%              78%                70%                       4%    --  -13%        -32%            -96%
    Moose                           3779/s                         451%             103%                95%                      19%   14%    --        -22%            -95%
    Object::Pad                     4864/s                         609%             161%               151%                      53%   47%   29%          --            -94%
    Types::Standard                83333/s                       12042%            4380%              4195%                    2513% 2422% 2105%       1613%              --
    
    real    3m3.179s
    user    2m59.690s
    sys     0m1.171s

=head1 DESCRIPTION

To get a serious, real-world benchmark, we have re-implemented a subset of L<Types::Standard>
in L<Object::Pad>, L<Moose>, and L<Moo>. In short, this somewhat complex type constraint
has is used to validate a data structure 50,000 times:

        construct(
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
            ]
        );

Unsurprisingly, C<Types::Standard> wins, hands down. However, we see
C<Object::Pad> is considerably faster than both C<Moose> and C<Moo>.
Interestingly, if you also include the "construct" step, C<Object::Pad> is far
and away the fastest, while C<Types::Standard> is the slowest.

If someone wants to contribute a C<bless> version to compare against, that
would be interesting.

There are tests for behavior in the C<t/> directory. They have been
cut-n-pasted, but could stand to be rewritten into a single test file.
