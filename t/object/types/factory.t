#!/usr/bin/env perl

use Test::Most;
use Storable 'dclone';
use Scalar::Util 'refaddr';
use Object::Types::Factory;
$Object::Types::Factory::Test::Mode = 1;

subtest 'Any' => sub {
    my $Any = Object::Types::Concrete::Any->new;
    ok $Any->validate(undef), 'Any() always passes';
};

subtest 'Int' => sub {
    my $Int = Object::Types::Concrete::Int->new;
    ok $Int->validate(37), 'Int() should validate ints';
    ok !$Int->validate(32.8), '... but not non-ints';
};

subtest 'Num' => sub {
    my $Num = Object::Types::Concrete::Num->new;
    ok $Num->validate(37),   'Num() should validate ints';
    ok $Num->validate(32.8), '... and floats';
    ok !$Num->validate("Ovid"), '... but not non-numbers';
};

subtest 'Str' => sub {
    my $Str = Object::Types::Concrete::Str->new;
    ok $Str->validate(37),     'Str() should validate ints';
    ok $Str->validate(32.8),   '... and floats';
    ok $Str->validate("Ovid"), '... and non-numbers';
    ok !$Str->validate('    '), '... but not empty strings';
};

subtest 'Regex' => sub {
    my $Regex = Object::Types::Concrete::Regex->new( regex => qr/ab*c/ );
    ok $Regex->validate('ac'), 'Strings matching the regex should valiadate';
    ok !$Regex->validate('axc'),
      '... and strings not matching the regex should not valiadate';
    $Regex = Object::Types::Concrete::Regex->new( regex => qr/x/ );
    ok !$Regex->validate( [] ), 'Regexes can never validate references';
};

subtest 'Enum' => sub {
    my $Enum =
      Object::Types::Concrete::Enum->new( elements => [ 1, 2, 'Ovid' ] );
    ok $Enum->validate('Ovid'), 'Values in our enum should validate';
    ok $Enum->validate(1),      '... no matter which they are';
    ok !$Enum->validate(42), '... values not in the enum should not validate';

    my $Enum_with_types = Object::Types::Concrete::Enum->new(
        elements => [ 'Ovid', Object::Types::Concrete::Int->new ] );
    ok $Enum_with_types->validate('Ovid'), 'Values in our enum should validate';
    ok $Enum_with_types->validate(7), '... as should values matching types';
    ok !$Enum_with_types->validate(7.3),
      '... but not values not matching either values or types';
};

subtest 'ArrayRef' => sub {
    my $ArrayRef = Object::Types::Concrete::ArrayRef->new;
    ok $ArrayRef->validate( [] ),
      'All arrayrefs match an empty array reference';
    ok $ArrayRef->validate( [ 1, 3.14, {}, [], 'Ovid' ] ),
      '... no matter what they contain';
    ok !$ArrayRef->validate( {} ),
'... but they will not validate against things that are not array references';

    my $ArrayRef_of_ints = Object::Types::Concrete::ArrayRef->new(
        contains => Object::Types::Concrete::Int->new );
    ok $ArrayRef_of_ints->validate( [] ),
      'arrayrefs of ints match an empty array reference';
    ok $ArrayRef_of_ints->validate( [ 1, 4 ] ), '... or an arrayref of ints';
    ok !$ArrayRef_of_ints->validate( [ 4, undef ] ),
      '... but not an array ref which contains something that is not an int';
};

subtest 'HashRef' => sub {
    my $HashRef = Object::Types::Concrete::HashRef->new;
    ok $HashRef->validate( {} ), 'HashRef validates against empty hashrefs';
    ok $HashRef->validate( { foo => 1 } ),
      'HashRef validates against anything in a hashref';
    ok !$HashRef->validate( [] ),
      'HashRef does not validate against non-hashrefs';

    my $HashRef_of_ints = Object::Types::Concrete::HashRef->new(
        contains => Object::Types::Concrete::Int->new );
    ok $HashRef_of_ints->validate( {} ),
      'HashRef of ints validates against empty hashrefs';
    ok $HashRef_of_ints->validate( { foo => 1, baz => 2 } ),
      'HashRef of ints validates against a hashref with ints for values';
    ok !$HashRef_of_ints->validate( { foo => 'bar', baz => 2 } ),
      'HashRef of ints validates against a hashref with non-ints for values';
};

subtest 'Maybe' => sub {
    my $Maybe = Object::Types::Concrete::Maybe->new(
        contains => Object::Types::Concrete::Str->new );
    ok $Maybe->validate(undef), 'Maybe(Str) accepts undef values';
    ok $Maybe->validate('Foo'), '... and non-empty strings';
    ok !$Maybe->validate(''), '... but not non-empty strings';
};

subtest 'Optional' => sub {
    my $Optional = Object::Types::Concrete::Optional->new(
        contains => Object::Types::Concrete::Str->new );
    ok $Optional->validate(undef), 'Optional(Str) accepts undef values';
    ok $Optional->validate('Foo'), '... and non-empty strings';
    ok !$Optional->validate(''), '... but not non-empty strings';
};

subtest 'Coerce' => sub {
    my $true_false = Object::Types::Concrete::Enum->new(elements => [qw/true false/]);
    my $Coerce = Object::Types::Concrete::Coerce->new( contains => $true_false, via => sub { $_[0] eq 'true' ? 1 : 0 });
    my $true = 'true';
    ok $Coerce->validate($true), 'We should be able to validate "true"';
    is $true, 1, '... and have it coerced to the number `1`';
};

subtest 'Default values' => sub {
    my $h1 = Object::Types::Concrete::HashRef->new;
    my $h2 = Object::Types::Concrete::HashRef->new;
  TODO: {
        local $TODO = 'Default references shared :(';
        isnt refaddr( $h1->elements ), refaddr( $h2->elements ),
          'Default references should not be the same reference';
    }
};

done_testing;
