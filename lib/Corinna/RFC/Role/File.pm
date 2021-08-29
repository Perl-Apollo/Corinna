use Object::Pad;

role Corinna::RFC::Role::File {
    method _slurp($file) {
        open my $fh, '<:encoding(UTF-8)', $file or die "Cannot open $file for reading: $!";
        return do { local $/; <$fh> };
    }

    method _splat( $file, $string ) {
        if ( ref $string ) {
            croak("Data for splat '$file' must not be a reference ($string)");
        }
        open my $fh, '>:encoding(UTF-8)', $file or die "Cannot open $file for writing: $!";
        print {$fh} $string;
    }
}

__END__

=head1 NAME

Corinna::RFC::Role::File - Read and write files

=head1 SYNOPSIS

	class Foo does Corinna::RFC::Role::File {
		...
	}


Class C<Foo> can now use C<_slurp($filename)> and C<_splat($filename, $string)>. Both assume
C<:encoding(UTF-8)>.

Note that these methods have a leading underscore and should be "private" to
the consuming class, but Perl doesn't yet support that. It would be nice to do this:

	role Some::Role {
		trusted method do_something () {
			...
		}
	}

And have that method be available for flattening into a consumer, but I<not> available outside
the class. This is similar to C<protected> methods in Java.

It also raises an interesting issue with roles: if a methods exported by a role is public, but
the consumer does not wish to expose that part of its interface, should it have a way to adjust the
access level to C<private> or C<trusted>?

=head1 REQUIRES

Nothing.

=head1 PROVIDES

Note: while both methods are class methods, as of C<Object::Pad> 0.52, we cannot call these methods
on non-instances.

=head2 C<_slurp($filename)>

	my $contents = $class->_slurp($filename);

Class method. Reads the entire contents of C<$filename> and returns it.

=head2 C<_splat($filename, $string)>

	$class->_splat( $filename, $string );

Class method. Writes the contents of C<$string> to C<$filename>.
