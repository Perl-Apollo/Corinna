use Object::Pad 0.56;

class Corinna::Example::Person {
    use Time::HiRes 'time';

    # TODO Rename `has` to `field`
    field $name  :param;              # must be passed to customer (:param)
    field $title :param = undef;      # optionally passed to constructor     (:param, but with default)
    field $created :reader;           # cannot be passed to constructor (no :param)

    my $num_people = 0;              # class data, defaults to 0 (common, with hand-rolled reader method)

	# TODO Add ability to declare class methods: common method num_people () { $num_people }
    method num_people () { $num_people }

    ADJUST   {
        $num_people++;

        # TODO Allow `field $created = time;` (or similar) to allow default at instantiation time
        $created = time;
    }

	# TODO Implement `DESTRUCT` for a destructor
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
