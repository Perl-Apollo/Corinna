package Object::Types;
use 5.26.0;
use warnings;
use experimental 'signatures';
no warnings 'experimental';
use Object::Types::Factory;
use base 'Exporter';

our @EXPORT_OK = qw(
  Any
  ArrayRef
  Coerce
  Dict
  Enum
  HashRef
  Int
  Maybe
  Num
  Optional
  Regex
  Str
);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub _create (@args) {
    return Object::Types::Factory->create(@args);
}

sub Any ()           { _create('Any') }
sub Int ()           { _create('Int') }
sub Num ()           { _create('Num') }
sub Str ()           { _create('Str') }
sub Regex ($re)      { _create( 'Regex', regex => $re ) }
sub Enum (@elements) { _create( 'Enum', elements => [@elements] ) }

sub ArrayRef ($type=undef) {
    if ( defined $type ) {
        _create( 'ArrayRef', contains => $type );
    }
    else {
        _create('ArrayRef');
    }
}

sub HashRef(@elements) {
    if ( 1 == @elements ) {
        _create( 'HashRef', contains => $elements[0] );
    }
    elsif ( !@elements ) {
        _create('HashRef');
    }
    else {
        _create( 'HashRef', element_hash => {@elements} );
    }
}

sub Dict(%elements) {
    _create( 'HashRef', element_hash => {%elements}, restricted => 1 );
}

sub Maybe($type)    { _create( 'Maybe',    contains => $type ) }
sub Optional($type) { _create( 'Optional', contains => $type ) }

sub Coerce ( $type, $code ) {
    _create( 'Coerce', contains => $type, via => $code );
}

1;

__END__

=head1 NAME

Object::Types - Types::Standard-like functions with better error reporting

=head1 SYNOPSIS

    use Object::Types qw(:all);
    my $true_false     = Enum(qw/true false/);
    my $YAMLBool       = Coerce( $true_false, sub { $_[0] eq 'true' ? 1 : 0 } );
    my $data_structure = Dict(
        routes => Dict(
            requires_proof    => $YAMLBool,
            list_of_coercions => ArrayRef( ArrayRef($YAMLBool) ),
        ),
    );
    $data_structure->validate($some_data);

=head1 DESCRIPTION

This is a limited subset of a reimplemenation of L<Types::Standard> due to two
serious issues. First, the error messages in C<Types::Standard> are almost
impossible to read:

    Reference {"maybe_true" => "true","not_a_hashref" => "asdf"} did not pass type constraint "Dict[maybe_true=>YAMLBool,not_a_hashref=>Optional[HashRef]]" (in $_[0]) at fail.pl line 18
        Reference {"maybe_true" => "true","not_a_hashref" => "asdf"} did not pass type constraint "Dict[maybe_true=>YAMLBool,not_a_hashref=>Optional[HashRef]]" (in $_[0])
        "Dict[maybe_true=>YAMLBool,not_a_hashref=>Optional[HashRef]]" constrains value at key "maybe_true" of hash with "YAMLBool"
        "YAMLBool" is a subtype of "Bool"
        Value "true" did not pass type constraint "Bool" (in $_[0]->{"maybe_true"})
        "Bool" is defined as: (!ref $_ and (!defined $_ or $_ eq q() or $_ eq '0' or $_ eq '1'))
    
Second, not only is the above error message very hard to parse (and that's a
simple example), it also turns out to be wrong. See
L<https://github.com/tobyink/p5-type-tiny/issues/81> for more detail.

For this code, we can trivially reproduce the error:

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
    $check->validate($minimal);

And the error message is both correct and easy to understand:

    Validation for '$data{not_a_hashref}' failed for type HashRef with value 'abcd'

=head1 LIMITED FUNCTIONALITY

This mostly mimics basic behavior of L<Types::Standard>. However, many
features are missing because I only implemented what I needed.

=head1 FUNCTIONS

All functions are exportabe on-demand, or via C<:all>. Further, they can be c
composed to arbitrary depths.

If a call to C<validate($value)> fails, the code will C<croak> with an
appropriate error message, giving you enough information to diagnose the
error:

    Validation for '$data{routes}[0]{'auth'}' failed for type HashRef with value 'abcd'

The structure of the failure is:

    Validation for '$path_to_data' failed for type $type with value 'offending value'

By default, the variable name in the error is C<$data>. You may pass a second
argument to C<validate> with any string you desire and that will be used as
the variable names instead:

    $something->validate($json, '$json');

=head2 C<Any>

    my $any = Any;
    $any->validate($something); # always succeeds

=head2 C<ArrayRef>

    my $aref = ArrayRef;
    $aref->validate( [] );            # good
    $aref->validate( \@anything );    # good
    $aref->validate(2);               # boom!

    my $aref_of_ints = ArrayRef(Int);
    $aref->validate( [] );                 # good
    $aref->validate( [ 2, 3, -1500 ] );    # good!
    $aref->validate( ['ovid'] );           # boom!
    $aref->validate(2);                    # boom!

=head2 C<Coerce>

    my $inc = Coerce( Int, sub { $_[0] + 1 } );
    my $num = 4;
    $inc->validate($num);
    say $num;    # 5

Easily coerce data. Note that we use C<$_[0]> instead of C<$_> for the
coercion value.

B<Important>: this will I<mutate> the data you pass in. If you need the data
unchanged, clone the data before passing it.

=head2 C<Enum>

    my $colors = Enum(qw/red white blue/);
    $colors->validate('red'); # good
    $colors->validate('green')' # bad

As a convenience, C<Enum> can also take types, and even nest enums.

    my $true_false = Enum(qw/true false/);
    my $typed_enum = Enum($true_false, Num, 'Ovid');

C<$typed_enum> will match any of C<true>, C<false>, C<Ovid>, or a number.

=head2 C<HashRef>

    # this is the same as HashRef(Any);
    my $hashref = HashRef;

This has three modes.

The first is matching I<any> hashref:

    my $hashref = HashRef;

The second is passing a single type, requiring all values to be of that type:

    my $hashref_of_arrayref_of_ints = HashRef(ArrayRef(Int));

The third is passing a list of keys whose values are the desired types. Any
extra keys will be ignored. If you want extra keys to be fatal, use C<Dict>
instead:

    my $hashref = HashRef(
        name   => Str,
        colors => Enum(qw/red white blue/),
        json   => {
            order_ids => ArrayRef(Int),
            payload   => Any,
        },
    );

=head2 C<Dict>

    my $dict = Dict(
        name   => Str,
        colors => Enum(qw/red white blue/),
        json   => {
            order_ids => ArrayRef(Int),
            payload   => Any,
        },
    );

Like C<HashRef>, but extra keys are fatal. If you want some keys to be
I<optional>, see C<Optional>. Otherwise, if you want some values to be
optional (in other words, to allow C<undef>), use C<Maybe>.

=head2 C<Int>

Ints. Duh.

=head2 C<Num>

Any number.

=head2 C<Str>

Matches strings. Unlike C<Str> from C<Types::Standard>, this will fail
validation unless there is at least one word character.

=head2 C<Regex>

    my $re = Re(qr/ab*c/);

Matches regular expressions.

=head2 C<Maybe> and C<Optional>

    my $maybe_int = Maybe(Int);
    $maybe_int->validate(3);         # good
    $maybe_int->validate(undef);     # good
    $maybe_int->validate('Ovid');    # boom!

These two functions behave identically most of the time. However, when used on
the I<keys of a HashRef or Dict>, C<Maybe> says "the value may be undefined"
and C<Optional> says "the key may be missing."
