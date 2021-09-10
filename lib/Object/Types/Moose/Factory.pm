package Object::Types::Moose::Factory;

use 5.26.0;
use warnings;

sub create {
    my ( $class, $type_name, @args ) = @_;
    my $factory_class = "Object::Types::Moose::Concrete::$type_name";
    unless ( $factory_class->DOES('Object::Types::Moose::Role::Core') ) {
        croak("Unknown type '$type_name'");
    }
    return $factory_class->new( type_name => $type_name, @args );
}

# Set up the core roles we need
package Object::Types::Moose::Role::Elements {
    use Moose::Role;

    requires '_is_type';

    has elements => (
        is      => 'ro',
        isa     => 'ArrayRef',
        default => sub { [] },
    );

    has element_hash => (
        is      => 'ro',
        isa     => 'HashRef',
        lazy    => 1,
        builder => '_build_element_hash',
    );

    has _has_types => (
        is      => 'ro',
        isa     => 'Bool',
        lazy    => 1,
        default => sub {
            my $self = shift;
            foreach my $element ( $self->elements->@* ) {
                return 1 if ref $element && $self->_is_type($element);
            }
            return 0;
        },
    );

    sub _build_element_hash {
        my $self   = shift;
        my %lookup = map { $_ => 1 } @{ $self->elements };
        return \%lookup;
    }

    no Moose::Role;
}

package Object::Types::Moose::Role::Core {
    use Moose::Role;
    use Carp;
    use Scalar::Util 'blessed';
    our @CARP_NOT;

    requires qw(_validate);

    sub BUILD {
        my $self = shift;
        state $spaces;
        unless ($spaces) {

            # find all of the Object::Type:* namespaces and make
            # sure that Carp doesn't report the error from there
            @CARP_NOT = $self->_find_namespaces_in("Object::Types");
            $spaces   = \@CARP_NOT;
        }
    }

    has non_fatal => (
        is      => 'ro',
        isa     => 'Bool',
        default => 0,
    );

    has contains => (
        is   => 'ro',
        does => 'Object::Types::Moose::Role::Core',
    );

    sub _is_type {
        my ( $self, $thing ) = @_;
        return blessed($thing) && $thing->DOES(__PACKAGE__);
    }

    sub type_name {
        my $self = shift;
        my $name = ref $self;
        $name =~ s/^Object::Types::Moose::Concrete:://;
        return $name;
    }

    sub validate {
        my ( $self, $value, $var_name ) = @_;
        $var_name //= '$data';
        $self->_validate( $value, $var_name ) && return 1;
        $value //= '<undef>';
        my $type_name = $self->type_name;
        $self->_report_error(
"Validation for '$var_name' failed for type $type_name with value '$value'"
        );
        return;
    }

    sub _report_error {
        my ( $self, $message ) = @_;
        if ( $self->non_fatal || $Object::Types::Moose::Factory::Test::Mode ) {
            carp $message;
        }
        else {
            croak $message;
        }
        return;
    }

    sub _find_namespaces_in {
        my ( $class, $package ) = @_;
        $package .= '::' unless $package =~ /::$/;
        my @namespaces =
          map { s/::$//r } $class->_recursively_find_namespaces($package);
        return @namespaces;
    }

    sub _recursively_find_namespaces {
        my ( $class, $package ) = @_;
        my @namespaces = ();
        my %namespace  = eval "%$package";

        # the grep ensures we're only picking up package names and not
        # package variables such as ::isa
        foreach my $key ( grep { /::$/ } keys %namespace ) {
            push @namespaces, "$package$key",
              $class->_recursively_find_namespaces("$package$key");
        }
        return @namespaces;
    }

    no Moose::Role;
}

# now create our type classes

package Object::Types::Moose::Concrete::Any {
    use Moose;
    with 'Object::Types::Moose::Role::Core';

    sub _validate { return 1 }
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

package Object::Types::Moose::Concrete::Int {
    use Moose;
    use Regexp::Common;
    with 'Object::Types::Moose::Role::Core';

    sub _validate {
        my ( $self, $value, $name ) = @_;
        return if !defined $value || ref $value;
        return $value =~ /^$RE{num}{int}$/;
    }
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

package Object::Types::Moose::Concrete::Num {
    use Moose;
    use Regexp::Common;
    with 'Object::Types::Moose::Role::Core';

    sub _validate {
        my ( $self, $value, $name ) = @_;
        return if !defined $value || ref $value;
        return $value =~ /^$RE{num}{real}$/;
    }
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

package Object::Types::Moose::Concrete::Str {
    use Moose;
    with 'Object::Types::Moose::Role::Core';

    sub _validate {
        my ( $self, $value, $name ) = @_;
        return if !defined $value || ref $value;
        return $value =~ /\w/;
    }
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

package Object::Types::Moose::Concrete::Regex {
    use Moose;
    with 'Object::Types::Moose::Role::Core';

    has regex => (
        is       => 'ro',
        isa      => 'Regexp',
        required => 1,
    );

    sub _validate {
        my ( $self, $value, $name ) = @_;
        return if !defined $value || ref $value;
        my $regex = $self->regex;
        $value //= '';
        return $value =~ /$regex/;
    }
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

package Object::Types::Moose::Concrete::Enum {
    use Moose;
    use Carp;
    with qw(
      Object::Types::Moose::Role::Core
      Object::Types::Moose::Role::Elements
    );

    sub BUILD {
        my $self = shift;
        if ( !keys $self->element_hash->%* ) {
            croak("Empty enums are not allowed");
        }
    }

    sub _validate {
        my ( $self, $value, $name ) = @_;
        if ( $self->_has_types ) {
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
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

package Object::Types::Moose::Concrete::ArrayRef {
    use Moose;
    with 'Object::Types::Moose::Role::Core';

    sub _validate {
        my ( $self, $value, $name ) = @_;
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
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

package Object::Types::Moose::Concrete::HashRef {
    use Moose;
    with qw(
      Object::Types::Moose::Role::Core
      Object::Types::Moose::Role::Elements
    );

    # restricted hashes only allow the keys declared in the types
    has restricted => (
        is      => 'ro',
        isa     => 'Bool',
        default => 0,
    );

    sub _quote_key {
        my ( $self, $key ) = @_;
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

    sub _validate {
        my ( $self, $value, $name ) = @_;
        return unless 'HASH' eq ref $value;
        my $contains = $self->contains;
        if ( !$contains && !keys $self->element_hash->%* ) {
            return 1;    # it can contain anything
        }
        my @keys = keys $value->%*;
        return 1 if !@keys && !$self->restricted;    # and it can be empty
        my $success = 1;

        # if we have elements, it means that each key
        # in the hash much match the type
        my $elements = $self->element_hash;
        undef $elements unless %$elements;
        my $restricted = $self->restricted;
        my $type_name  = $self->type_name;

        if ($elements) {

            # fail if we have missing keys
            foreach my $key ( keys $elements->%* ) {
                if (   !exists $value->{$key}
                    && !$elements->{$key}
                    ->isa('Object::Types::Moose::Concrete::Optional') )
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
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

package Object::Types::Moose::Concrete::Maybe {
    use Moose;
    with 'Object::Types::Moose::Role::Core';

    has contains => (
        is       => 'ro',
        does     => 'Object::Types::Moose::Role::Core',
        required => 1,
    );

    sub _validate {
        my ( $self, $value, $name ) = @_;
        my $contains = $self->contains;
        return 1 if !defined $value;    # and it can be empty
        return $contains->validate( $value, "$name" );
    }
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

package Object::Types::Moose::Concrete::Optional {
    use Moose;
    with 'Object::Types::Moose::Role::Core';

    has contains => (
        is       => 'ro',
        does     => 'Object::Types::Moose::Role::Core',
        required => 1,
    );

    sub _validate {
        my ( $self, $value, $name ) = @_;
        my $contains = $self->contains;
        return 1 if !defined $value;    # and it can be empty
        return $contains->validate( $value, "$name" );
    }
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

package Object::Types::Moose::Concrete::Coerce {
    use Moose;
    with 'Object::Types::Moose::Role::Core';

    has contains => (
        is       => 'ro',
        does     => 'Object::Types::Moose::Role::Core',
        required => 1,
    );

    has via => (
        is       => 'ro',
        isa      => 'CodeRef',
        required => 1,
    );

    sub validate {
        my ( $self, $value, $var_name ) = @_;
        $var_name //= '$data';

        # use the value from the original @_ array to ensure we have an alias
        # to the original variable. This allows the coercion to change the
        # calling data's value
        $self->_validate( $_[1], $var_name ) && return 1;
        $value //= '<undef>';
        my $type_name = $self->type_name;
        $self->_report_error(
"Validation for '$var_name' failed for type $type_name with value '$value'"
        );
        return;
    }

    sub _validate {
        my ( $self, $value, $name ) = @_;
        my $contains = $self->contains;
        my $success  = $contains->validate( $value, "$name" );
        if ($success) {
            $_[1] = $self->via->($value);
        }
        return $success;
    }
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

