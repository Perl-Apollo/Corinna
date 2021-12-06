package Object::Types::Factory;
use 5.26.0;
use warnings;
use Carp;
no warnings 'uninitialized';

use Object::Pad 0.58;

## no critic (ProhibitMultiplePackages)

sub create {
    my ( $class, $type_name, @args ) = @_;
    my $factory_class = "Object::Types::Concrete::$type_name";
    unless ( $factory_class->DOES('Object::Types::Role::Core') ) {
        croak("Unknown type '$type_name'");
    }
    return $factory_class->new( type_name => $type_name, @args );
}

# Set up the core roles we need
role Object::Types::Role::Elements {
    requires _is_type;

    # TODO: I assume that has $foo = []; is getting the same reference per instance. This should be fixed.
    has $elements     :reader :param = undef;
    has $element_hash :reader :param = undef;
    has $has_types    :reader;

    ADJUST {
        $elements     //= [];
        $element_hash //= {};
    }

    BUILD {
        $has_types = 0;
        ELEMENT: foreach my $element ( $elements->@* ) {
            if ( ref $element && $self->_is_type($element) ) {
                $has_types = 1;
                last ELEMENT;
            }
        }
        unless (keys $element_hash->%*) { 
            $element_hash = { map { $_ => 1 } @{ $self->elements } };
        }
    }
}

role Object::Types::Role::Core {
    use Carp;
    use Scalar::Util 'blessed';
    our @CARP_NOT;

    # TODO allow roles to require protected/trusted methods. This should not be part of the API
    requires _validate;

    has $non_fatal :param         = 0;
    has $contains  :param :reader = undef; # does => 'Object::Types::Role::Core',

    BUILD {
        unless (@CARP_NOT) {

            # find all of the Object::Types:* namespaces and make
            # sure that Carp doesn't report the error from there
            @CARP_NOT = $self->_find_namespaces_in("Object::Types");
        }
    }

    method _is_type ($thing) {
        return blessed($thing) && $thing->DOES(__PACKAGE__);
    }

    method type_name () {
        my $name = ref $self;
        $name =~ s/^Object::Types::Concrete:://;
        return $name;
    }

    method validate ($value, $var_name='$data') {
        $self->_validate( $value, $var_name ) && return 1;
        $value //= '<undef>';
        my $type_name = $self->type_name;
        $self->_report_error("Validation for '$var_name' failed for type $type_name with value '$value'");
        return;
    }

    method _report_error ($message) {
        return if $Object::Types::Factory::Test::Mode;
        if ( $non_fatal ) {
            carp $message unless $Object::Types::Factory::ShutUp::For::Testing;
        }
        else {
            croak $message;
        }
        return;
    }

    # TODO common methods
    # TODO export $class in additionto $self with methods
    method _find_namespaces_in ($package) {
        $package .= '::' unless $package =~ /::$/;
        my @namespaces = map {s/::$//r} $self->_recursively_find_namespaces($package);
        return @namespaces;
    }

    method _recursively_find_namespaces ($package) {
        my @namespaces = ();
        my %namespace  = eval "%$package";

        # the grep ensures we're only picking up package names and not
        # package variables such as ::isa
        foreach my $key ( grep {/::$/} keys %namespace ) {
            push @namespaces, "$package$key", $self->_recursively_find_namespaces("$package$key");
        }
        return @namespaces;
    }
}

# now create our type classes
class Object::Types::Concrete::Any :does(Object::Types::Role::Core) {
    method _validate ($value, $var_name) { return 1 }
}


class Object::Types::Concrete::Int :does(Object::Types::Role::Core) {
    use Regexp::Common;

    method _validate ($value, $var_name) {
        return if !defined $value || ref $value;
        return $value =~ /^$RE{num}{int}$/;
    }
}

class Object::Types::Concrete::Num :does(Object::Types::Role::Core) {
    use Regexp::Common;

    method _validate ($value, $var_name) {
        return if !defined $value || ref $value;
        return ( $value // '' ) =~ /^$RE{num}{real}$/;
    }
}

class Object::Types::Concrete::Str :does(Object::Types::Role::Core) {

    # our version requires at least one white-space character
    method _validate( $value, $var_name ) {
        return if !defined $value || ref $value;
        return ( $value // '' ) =~ /\S/;
    }
}

class Object::Types::Concrete::Regex :does(Object::Types::Role::Core) {
    has $regex :param;

    method _validate ($value, $name) {
        return if !defined $value || ref $value;
        return ( $value // '' ) =~ /$regex/;
    }
}

class Object::Types::Concrete::Enum
  :does(Object::Types::Role::Core)
  :does(Object::Types::Role::Elements)
{
    use Carp;

    BUILD {
        if ( !keys $self->element_hash->%* ) {
            croak("Empty enums are not allowed");
        }
    }

    method _validate( $value, $name ) {
        if ( $self->has_types ) {
            foreach my $element ( $self->elements->@* ) {
                if ( !ref $element ) {
                    return 1 if $value eq $element;
                }
                elsif ( $self->_is_type($element) ) {
                    return 1 if $element->_validate( $value, $name );
                }
                else {
                    croak("I don't know how to validate a $element");
                }
            }
            return 0;
        }
        else {
            return exists $self->element_hash->{$value};
        }
    }
}

class Object::Types::Concrete::ArrayRef :does(Object::Types::Role::Core) {
    method _validate ($value, $name) {
        return unless 'ARRAY' eq ref $value;
        my $contains = $self->contains or return 1;    # it can contain anything
        return 1 if !@$value;                          # and it can be empty
        my $success = 1;
        foreach my $i ( 0 ... $#$value ) {
            $success = 0
              unless $contains->validate( $value->[$i], "$name\[$i]" );
        }
        return $success;
    }
}

class Object::Types::Concrete::HashRef
  :does(Object::Types::Role::Core)
  :does(Object::Types::Role::Elements)
{
    # restricted hashes only allow the keys declared in the types
    has $restricted : param = 0;

    method _quote_key($key) {
        my $quoted_key = $key;
        if ( $key =~ /'/ && $key =~ /"/ ) {
            $quoted_key =~ s/'/\'/;
        }
        elsif ( $key =~ /'/ ) {
            $quoted_key = qq'"$quoted_key"';
        }
        else {
            $quoted_key = "'$quoted_key'";
        }
        return $quoted_key;
    }

    method _validate( $value, $name ) {
        return unless 'HASH' eq ref $value;
        my $contains = $self->contains;
        if ( !$contains && !keys $self->element_hash->%* ) {
            return 1;    # it can contain anything
        }
        my @keys = keys $value->%*;
        return 1 if !@keys && !$restricted;    # and it can be empty
        my $success = 1;

        # if we have elements, it means that each key
        # in the hash much match the type
        my $elements = $self->element_hash;
        undef $elements unless %$elements;
        my $restricted = $restricted;
        my $type_name  = $self->type_name;

        if ($elements) {

            # fail if we have missing keys
            foreach my $key ( keys $elements->%* ) {
                if (   !exists $value->{$key}
                    && !$elements->{$key}
                    ->isa('Object::Types::Concrete::Optional') )
                {
                    $key = $self->_quote_key($key);
                    my $var_name = "$name\{$key}";
                    return $self->_report_error(
"Validation for '$var_name' failed for $type_name with missing key: $key"
                    );
                }
            }
        }
      KEY: foreach my $key (@keys) {
            my $quoted_key = $self->_quote_key($key);
            my $var_name   = "$name\{$quoted_key}";
            if ($elements) {
                if ( !exists $elements->{$key} ) {
                    if ($restricted) {
                        return $self->_report_error(
"Validation for '$var_name' failed for restricted $type_name with illegal key: '$key'"
                        );
                    }
                    else {    # not a restricted hash, so ignore unknown keys
                        next KEY;
                    }
                }
                elsif ( $self->_is_type( $elements->{$key} ) ) {

                    # We have different types of values specified for every
                    # key
                    $success = 0
                      unless $elements->{$key}
                      ->validate( $value->{$key}, $var_name );
                }
            }
            else {
                $success = 0
                  unless $contains->validate( $value->{$key}, $var_name );
            }
        }
        return $success;
    }
}

class Object::Types::Concrete::Maybe :does(Object::Types::Role::Core) {
    method _validate( $value, $name ) {
        return 1 if !defined $value;    # and it can be empty
        return $self->contains->validate( $value, "$name" );
    }
}

class Object::Types::Concrete::Optional :does(Object::Types::Role::Core) {
    method _validate ($value, $name) {
        return 1 if !defined $value;    # and it can be empty
        return $self->contains->validate( $value, "$name" );
    }
}


# We use a parent class for the role target methods because otherwise, we get
# method collisions
class Object::Types::Concrete::_Coerce :does(Object::Types::Role::Core) {
    method _validate( $value, $name ) { }
}

class Object::Types::Concrete::Coerce :isa(Object::Types::Concrete::_Coerce) {
    require Carp;
    has $via : param;

    BUILD {
        croak("Not a code reference for via") unless 'CODE' eq ref $via;
    }

    # TODO allow aliasing/excluding methods from roles to avoid this subclassing hack
    method validate ($value, $var_name='$data') {

        # use the value from the original @_ array to ensure we have an alias
        # to the original variable. This allows the coercion to change the
        # calling data's value
        $self->_validate( $_[0], $var_name ) && return 1;
        $value //= '<undef>';
        my $type_name = $self->type_name;
        $self->_report_error("Validation for '$var_name' failed for type $type_name with value '$value'");
        return;
    }
    method _validate( $value, $name ) {
        my $success = $self->contains->validate( $value, "$name" );
        if ($success) {
            $_[0] = $via->($value);
        }
        return $success;
    }
}

1;

__END__

=head1 NAME

Object::Types::Factory - No user-serviceable parts inside.

=head1 DESCRIPTION

See L<Object::Types::Functions> for the public interface.
