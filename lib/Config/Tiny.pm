package Config::Tiny;

# If you thought Config::Simple was small...

use strict;

# Warning: There is another version line, in t/02.main.t.

our $VERSION = '2.26';

BEGIN {
	require 5.008001; # For the utf8 stuff.
	$Config::Tiny::errstr  = '';
}

# Create an empty object.

sub new { return bless {}, shift }

# Create an object from a file.

sub read
{
	my($class)           = ref $_[0] ? ref shift : shift;
	my($file, $encoding) = @_;

	return $class -> _error('No file name provided') if (! defined $file || ($file eq '') );

	# Slurp in the file.

	$encoding = $encoding ? "<:$encoding" : '<';
	local $/  = undef;

	open( CFG, $encoding, $file ) or return $class -> _error( "Failed to open file '$file' for reading: $!" );
	my $contents = <CFG>;
	close( CFG );

	return $class -> _error("Reading from '$file' returned undef") if (! defined $contents);

	return $class -> read_string( $contents );

} # End of read.

# Create an object from a string.

sub read_string
{
	my($class) = ref $_[0] ? ref shift : shift;
	my($self)  = bless {}, $class;

	return undef unless defined $_[0];

	# Parse the file.

	my $ns      = '_';
	my $counter = 0;

	foreach ( split /(?:\015{1,2}\012|\015|\012)/, shift )
	{
		$counter++;

		# Skip comments and empty lines.

		next if /^\s*(?:\#|\;|$)/;

		# Remove inline comments.

		s/\s\;\s.+$//g;

		# Handle section headers.

		if ( /^\s*\[\s*(.+?)\s*\]\s*$/ )
		{
			# Create the sub-hash if it doesn't exist.
			# Without this sections without keys will not
			# appear at all in the completed struct.

			$self->{$ns = $1} ||= {};

			next;
		}

		# Handle properties.

		if ( /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ )
		{
			$self->{$ns}->{$1} = $2;

			next;
		}

		return $self -> _error( "Syntax error at line $counter: '$_'" );
	}

	return $self;
}

# Save an object to a file.

sub write
{
	my($self)            = shift;
	my($file, $encoding) = @_;

	return $self -> _error('No file name provided') if (! defined $file or ($file eq '') );

	$encoding = $encoding ? ">:$encoding" : '>';

	# Write it to the file.

	my($string) = $self->write_string;

	return undef unless defined $string;

	open( CFG, $encoding, $file ) or return $self->_error("Failed to open file '$file' for writing: $!");
	print CFG $string;
	close CFG;

	return 1;

} # End of write.

# Save an object to a string.

sub write_string
{
	my($self)     = shift;
	my($contents) = '';

	for my $section ( sort { (($b eq '_') <=> ($a eq '_')) || ($a cmp $b) } keys %$self )
	{
		# Check for several known-bad situations with the section
		# 1. Leading whitespace
		# 2. Trailing whitespace
		# 3. Newlines in section name.

		return $self->_error("Illegal whitespace in section name '$section'") if $section =~ /(?:^\s|\n|\s$)/s;

		my $block = $self->{$section};
		$contents .= "\n" if length $contents;
		$contents .= "[$section]\n" unless $section eq '_';

		for my $property ( sort keys %$block )
		{
			return $self->_error("Illegal newlines in property '$section.$property'") if $block->{$property} =~ /(?:\012|\015)/s;

			$contents .= "$property=$block->{$property}\n";
		}
	}

	return $contents;

} # End of write_string.

# Error handling.

sub errstr { $Config::Tiny::errstr }
sub _error { $Config::Tiny::errstr = $_[1]; undef }

1;

__END__

=pod

=head1 NAME

Config::Tiny - Read/Write .ini style files with as little code as possible

=head1 SYNOPSIS

	# In your configuration file
	rootproperty=blah

	[section]
	one=twp
	three= four
	Foo =Bar
	empty=

	# In your program
	use Config::Tiny;

	# Create a config
	my $Config = Config::Tiny->new;

	# Open the config
	$Config = Config::Tiny->read( 'file.conf' );
	$Config = Config::Tiny->read( 'file.conf', 'utf8' ); # Neither ':' nor '<:' prefix!
	$Config = Config::Tiny->read( 'file.conf', 'encoding(iso-8859-1)');

	# Reading properties
	my $rootproperty = $Config->{_}->{rootproperty};
	my $one = $Config->{section}->{one};
	my $Foo = $Config->{section}->{Foo};

	# Changing data
	$Config->{newsection} = { this => 'that' }; # Add a section
	$Config->{section}->{Foo} = 'Not Bar!';     # Change a value
	delete $Config->{_};                        # Delete a value or section

	# Save a config
	$Config->write( 'file.conf' );
	$Config->write( 'file.conf', 'utf8' ); # Neither ':' nor '>:' prefix!

	# Shortcuts
	my($rootproperty) = $$Config{_}{rootproperty};

	my($config) = Config::Tiny -> read_string('alpha=bet');
	my($value)  = $$config{_}{alpha}; # $value is 'bet'.

	my($config) = Config::Tiny -> read_string("[init]\nalpha=bet");
	my($value)  = $$config{init}{alpha}; # $value is 'bet'.

=head1 DESCRIPTION

C<Config::Tiny> is a Perl class to read and write .ini style configuration
files with as little code as possible, reducing load time and memory overhead.

Most of the time it is accepted that Perl applications use a lot of memory and modules.

The C<*::Tiny> family of modules is specifically intended to provide an ultralight alternative
to the standard modules.

This module is primarily for reading human written files, and anything we write shouldn't need to
have documentation/comments. If you need something with more power move up to L<Config::Simple>,
L<Config::General> or one of the many other C<Config::*> modules.

Lastly, L<Config::Tiny> does B<not> preserve your comments, whitespace, or the order of your config
file.

See L<Config::Tiny::Ordered> (and possibly others) for the preservation of the order of the entries
in the file.

=head1 CONFIGURATION FILE SYNTAX

Files are the same format as for MS Windows C<*.ini> files. For example:

	[section]
	var1=value1
	var2=value2

If a property is outside of a section at the beginning of a file, it will
be assigned to the C<"root section">, available at C<$Config-E<gt>{_}>.

Lines starting with C<'#'> or C<';'> are considered comments and ignored,
as are blank lines.

When writing back to the config file, all comments, custom whitespace,
and the ordering of your config file elements are discarded. If you need
to keep the human elements of a config when writing back, upgrade to
something better, this module is not for you.

=head1 METHODS

=head2 errstr()

Returns a string representing the most recent error, or the empty string.

You can also retrieve the error message from the C<$Config::Tiny::errstr> variable.

=head2 new()

The constructor C<new> creates and returns an empty C<Config::Tiny> object.

=head2 read($filename, [$encoding])

Here, the [] indicate an optional parameter.

The C<read> constructor reads a config file, $filename, and returns a new
C<Config::Tiny> object containing the properties in the file.

$encoding may be used to indicate the encoding of the file, e.g. 'utf8' or 'encoding(iso-8859-1)'.

Do not add a prefix to $encoding, such as '<' or '<:'.

Returns the object on success, or C<undef> on error.

When C<read> fails, C<Config::Tiny> sets an error message internally
you can recover via C<Config::Tiny-E<gt>errstr>. Although in B<some>
cases a failed C<read> will also set the operating system error
variable C<$!>, not all errors do and you should not rely on using
the C<$!> variable.

See t/04.utf8.t and t/04.utf8.txt.

=head2 read_string($string)

The C<read_string> method takes as art intend.

This conforms to the syntax discussed in L</CONFIGUR
	my($value)  = $$config{_}{alpha}; # $value is 'bet'.

Or even, a bit ridiculously:

	my($value) = ${Config::Tiny -> read_strough for me :).

=head1 SEE ALSO

See, amongst many: L<Config::Simple> and L<Config::General>.

See L<Config::Tiny::Ordered> (and possibly others) for the preservation of the order of the entries
in the file.

L<IOD>. Ini On Drugs.

L<IOD::Examples>

L<App::IODUtils>

L<Config::IOD::Reader>

L<Config::Perl::V>. Config data from Perl itself.

L<Config::Onion>

L<Config::IniFiles>

L<Config::INIPlus>

L<Config::Hash>. Allows nested data.

L<Config::MVP>. Author: RJBS. Uses Moose. Extremely complex.

L<Config::TOML>. See next few lines:

L<https://github.com/dlc/toml>

L<https://github.com/alexkalderimis/config-toml.pl>. 1 Star rating.

L<https://github.com/toml-lang/toml>

=head1 COPYRIGHT

Copyright 2002 - 2011 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
