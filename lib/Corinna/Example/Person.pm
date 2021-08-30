use Object::Pad 0.52;

class Corinna::Example::Person {
    use Time::HiRes 'time';

    # TODO Do not yet have the 'slot' keyword
    has $name  :param;              # must be passed to customer (:param)
    has $title :param = undef;      # optionally passed to constructor     (:param, but with default)
    has $created :reader;           # cannot be passed to constructor (no :param)

    my $num_people = 0;              # class data, defaults to 0 (common, with hand-rolled reader method)

	# TODO class method, but we cannot yet declare them
    # common method num_people () { $num_people }
    method num_people () { $num_people }

    ADJUST   {
        $num_people++;

        # TODO cannot use has $created = time; because that's assigned
        # at compile-time, not instantiation time
        $created = time;
    }

	# TODO DESTRUCT does not yet exist
    DESTROY { $num_people-- }             # destructor

    method name () {                 # instance method
        return defined $title ? "$title $name" : $name;
    }
}

__END__

=head1 NAME

Corinna::Example::Person - Example of a "Person" class

=head1 SYNOPSIS

    use Corinna::Example::Person;
    my $villain = Person->new( title => 'Dr.', name => 'Zacharary Smith' );
    my $boy     = Person->new( name => 'Will Robinson' );

    say $villain->name;   # Dr. Zacharary Smith
    say $boy->name;       # Will Robinson
    say $boy->created;    # time() of creation
    say $boy->num_people; # how many people objects exist

Note that C<num_people> is a class method but we cannot yet call C<< Corinna::Example::Person->num_people >>.

=head1 SOURCE

See "4.2 Discussion" in L<https://github.com/Ovid/Cor/blob/master/rfc/classes.md>.
