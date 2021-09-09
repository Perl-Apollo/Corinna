#!/usr/bin/env perl

use Test::Most;
use Storable 'dclone';
use Object::Types ':all';

sub error_like {
    my ( $sub, $var_name, $type_name, $value, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    eval {
        $sub->();
        fail "Exception was not thrown. $message";
        1;
    } or do {
        chomp( my $error = $@ // '<zombie error>' );
        my $expected = "Validation for '$var_name' failed for type $type_name with value '$value";
        my $start    = index $error, $expected;
        ok 0 == $start, $message or do {
            diag <<~"END";
            Note: the "have" is allowed to be longer than the "Want"
            Have: $error
            Want: $expected
            END
        };
    };
}

subtest 'Basic function tests' => sub {
    my $Int = Int;
    ok $Int->validate(3), 'integers should match Int';
    error_like(
        sub { $Int->validate(undef) },
        '$data', 'Int', '<undef>',
        'undefined values should not match Int'
    );
    error_like(
        sub { $Int->validate('foo') },
        '$data', 'Int', 'foo',
        'string values should not match Int'
    );

    my $Str = Str;
    ok $Str->validate(3), 'strings should match Str';
    error_like(
        sub { $Str->validate(' ') },
        '$data', 'Str', ' ',
        '... but we do not allow empty strings'
    );
    error_like(
        sub { $Str->validate( {} ) },
        '$data', 'Str', 'HASH',
        '... or references'
    );

    my $red_white_blue = Enum(qw/red white blue/);
    ok $red_white_blue->validate('white'), 'Enums should match values contained in them';
    error_like(
        sub { $red_white_blue->validate('black') },
        '$data', 'Enum', 'black',
        'Enums should not accept values not defined for them'
    );

    my $any_array = ArrayRef;
    ok $any_array->validate( [] ), 'empty array matches ArrayRef';
    ok $any_array->validate( [ 1, 2, {}, 4 ] ), '... and untyped arrays can contain anything';
    error_like(
        sub { $any_array->validate( {} ) },
        '$data', 'ArrayRef', 'HASH',
        '... HashRef does not match ArrayRef'
    );

    my $int_array = ArrayRef(Int);
    ok $any_array->validate( [] ), 'empty array matches ArrayRef(Int)';
    ok $int_array->validate( [ 1, 2, 3, 4 ] ), 'arrays of integers should match ArrayRef(Int)';

    error_like(
        sub { $int_array->validate( [ 1, 2, 3, 'Ovid', 4 ] ) },
        '$data[3]', 'Int', 'Ovid',
        'Errors should tell us exactly where in the data structure they are'
    );

    error_like(
        sub { $int_array->validate( {} ) },
        '$data', 'ArrayRef', 'HASH',
        'You should not be able to substitute a hash for an array'
    );

    my $int_of_int_array = ArrayRef( ArrayRef(Int) );
    ok $int_of_int_array->validate( [] ), 'Empty arrays should match ArrayRef(ArrayRef(Int))';
    ok $int_of_int_array->validate( [ [ 1, 2, 2 ], [-3], [] ] ), '... as should arrays of arrays of intgers';

    error_like(
        sub { $int_of_int_array->validate( [ [ 1, 2, 'Ovid' ] ] ) },
        '$data[0][2]', 'Int', 'Ovid',
        'And even complex data structures should tells us where the error is'

    );

    my $hash = HashRef;
    ok $hash->validate( {} ), 'Empty hashes should match HashRef';
    ok $hash->validate( { foo => 1 } ), '... as should non-empty ones';

    my $typed_hash = HashRef($red_white_blue);
    ok $typed_hash->validate( {} ), 'Typed hashes can be empty';
    ok $typed_hash->validate( { foo => 'red' } ), '... but if they are not empty, all values must match the type';
    error_like(
        sub { $typed_hash->validate( { foo => 1 } ) },
        '$data{\'foo\'}', 'Enum', '1',
        '... and again, we see exactly where the error is'
    );

    my $dict = Dict(
        this  => $Int,
        that  => Maybe($Str),
        color => Optional($red_white_blue),
    );

    ok $dict->validate( { this => 1, that => 'Ovid', color => 'red' } ),
      'Valid dicts are valid';

    throws_ok { $dict->validate( { extra => 1, this => 1, that => 'Ovid', color => 'red' } ) }
    qr/^Validation for '\$data\{'extra'\}' failed for restricted HashRef with illegal key: 'extra'/,
      'Extra keys in dicts are invalid';
    throws_ok { $dict->validate( { that => 'Ovid', color => 'red' } ) }
    qr/^Validation for '\$data\{'this'\}' failed for HashRef with missing key: 'this'/,
      'Missing keys in dicts are invalid';
    ok $dict->validate( { this => 1, that => 'Ovid' } ),
      'Optional keys in dicts are not required to be present';
    ok $dict->validate( { this => 1, that => undef } ),
      'Maybe() keys in dicts are required to be present, but may be undef';
    throws_ok { $dict->validate( { this => 1, color => 'red' } ) }
    qr/^Validation for '\$data\{'that'\}' failed for HashRef with missing key: 'that'/,
      'Missing Maybe() keys in dicts are invalid';

    error_like(
        sub { $dict->validate( { this => 'not an int', that => 'Ovid', color => 'red' } ) },
        '$data{\'this\'}', 'Int', 'not an int',
        'Invalid types in Dicts are invalid',
    );

    my $open_dict = HashRef(
        this  => $Int,
        that  => $Str,
        color => $red_white_blue,
    );

    ok $open_dict->validate( { this => 1, that => 'Ovid', color => 'red' } ),
      'Valid dicts are valid';
    ok $open_dict->validate( { extra => 1, this => 1, that => 'Ovid', color => 'red' } ),
      'Extra keys in unrestricted dicts are valid';
    error_like(
        sub { $open_dict->validate( { this => 'not an int', that => 'Ovid', color => 'red' } ) },
        '$data{\'this\'}', 'Int', 'not an int',
        'Invalid types in hashed are invalid',
    );

    my $maybe_int = Maybe(Int);
    ok $maybe_int->validate(3),     'integers should match Maybe(Int)';
    ok $maybe_int->validate(undef), '... as should undef values';
    error_like(
        sub { $maybe_int->validate('foo') },
        '$data', 'Int', 'foo',
        '... but invalid types are still invalid in maybe values'
    );

    my $true_false = Enum(qw/true false/);
    my $YAMLBool   = Coerce( $true_false, sub { $_[0] eq 'true' ? 1 : 0 } );
    my $example    = 'true';
    ok $YAMLBool->validate($example), '"true" should be a valid value for our coercion';
    is $example, 1, '... and the resulting value should be coerced to "1"';

    my $typed_enum = Enum( $true_false, Num, 'Ovid' );
    ok $typed_enum->validate('false'),   'We should be able to populate an enum with types instead of constants';
    ok $typed_enum->validate('Ovid'),    '... but still match constant strings';
    ok $typed_enum->validate(3.1415927), '... and floating points';
    throws_ok { $typed_enum->validate('not found') }
    qr/^Validation for '\$data' failed for type Enum with value 'not found'/,
      '... and still reject values that do not match our types';

    my $re = Regex(qr/ab*c/);
    ok $re->validate('ac'),     'Regex types should match what we expect';
    ok $re->validate('abbbbc'), '... ditto';
    throws_ok { $re->validate('not found') }
    qr/^Validation for '\$data' failed for type Regex with value 'not found'/,
      '... and reject values that do not match our regex';
};

subtest 'Complex example with coercion' => sub {
    my $true_false     = Enum(qw/true false/);
    my $YAMLBool       = Coerce( $true_false, sub { $_[0] eq 'true' ? 1 : 0 } );
    my $data_structure = Dict(
        routes => Dict(
            requires_proof    => $YAMLBool,
            list_of_coercions => ArrayRef( ArrayRef($YAMLBool) ),
        ),
    );
    my $data = {
        routes => {
            requires_proof    => 'true',
            list_of_coercions => [ [], [qw/true false true/] ],
        }
    };
    my $good = dclone($data);
    ok $data_structure->validate($good), 'We can validate complex structures';

    my $expected = {
        routes => {
            requires_proof    => 1,
            list_of_coercions => [ [], [ 1, 0, 1 ] ],
        }
    };
    eq_or_diff $good, $expected, '... and see that our coercions have been coerced';

    $data->{routes}{list_of_coercions}[1][-1] = 'ovid';
    my $bad = dclone($data);
    $bad->{routes}{list_of_coercions}[1][-1] = 'ovid';
    throws_ok { $data_structure->validate($bad) }
    qr/Validation for '\$data\{'routes'\}\{'list_of_coercions'\}\[1\]\[2\]' failed for type Enum with value 'ovid/,
      '... but complex data structures throwing errors should tell us the correct error and where it is';

    my $inc = Coerce( Int, sub { $_[0] + 1 } );
    my $num = 4;
    $inc->validate($num);
    is $num, 5, 'Test an example from our docs';
};

subtest 'Avoids Types::Standard error' => sub {
    # https://github.com/tobyink/p5-type-tiny/issues/81

    my $true_false = Enum(qw/true false/);
    my $YAMLBool   = Coerce( $true_false, sub { $_[0] eq 'true' ? 1 : 0 } );
    my $check      = Dict(
        maybe_true    => $YAMLBool,
        not_a_hashref => Optional(HashRef),
    );

    my $minimal = {
        maybe_true    => 'true',
        not_a_hashref => 'abcd',
    };
    throws_ok { $check->validate($minimal) }
    qr/^Validation for '\$data\{'not_a_hashref'\}' failed for type HashRef with value 'abcd'/,
      'The Types::Standard bug does not affect us';
};

done_testing;
