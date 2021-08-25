package Config::Tiny::Ordered;

# If you thought Config::Tiny was small...

use base 'Config::Tiny';
use strict;

our $VERSION = '1.03';

BEGIN
{
	require 5.004;

	$Config::Tiny::Ordered::errstr  = '';
}

# Create an empty object.

sub new
{
	return $_[0] -> SUPER::new();
}

# Create an object from a string.

sub read_string
{
	my($class) = ref $_[0] ? ref shift : shift;
	my($self)  = bless {}, $class;

	return undef unless defined $_[0];

	# Parse the data.

	my $ns      = '_';
	my $counter = 0;

	for (split /(?:\015{1,2}\012|\015|\012)/, shift)
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

			$self->{$ns = $1} ||= [];

			next;
		}

		# Handle properties.

		if ( /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ )
		{
			push @{$self->{$ns} }, {key => $1, value => $2};
			next;
		}

		return $self->_error( "Syntax error at line $counter: '$_'" );
	}

	return $self;

} # End of read_string.

# Save an object to a string.

sub write_string
{
	my($self) = shift;

	my $contents = '';

	for my $section (sort { (($b eq '_') <=> ($a eq '_')) || ($a cmp $b) } keys %$self)
	{
		my $block = $self->{$section};
		$contents .= "\n" if length $contents;
		$contents .= "[$section]\n" unless $section eq '_';

		for my $property ( @$block )
		{
			$contents .= "$$property{'key'}=$$property{'value'}\n";
		}
	}

	return $contents;

} # End of write_string.

1;

=pod

=head1 NAME

Config::Tiny::Ordered - Read/Write ordered .ini style files with as little code as possible

=head1 SYNOPSIS

    # In your configuration file:
    rootproperty=blah

    [section]
    reg_exp_1=High Priority
    reg_exp_2=Low Priority
    three= four
    Foo =Bar
    empty=

    # In your program:
    use Config::Tiny::Ordered;

    # Create a config:
    my $Config = Config::Tiny::Ordered->new();

    # Open the config:
    $Config = Config::Tiny::Ordered->read( 'file.conf' );

    # Reading properties:
    my $rootproperty = $Config->{_}->{rootproperty};
    my $section = $Config->{section}; # An arrayref of hashrefs,
    my $key = $$section[0]{'key'};    # where the format is:
    my $re1 = $$section[0]{'value'};  # [{key => ..., value => ...},
    my $re2 = $$section[1]{'value'};  #  {key => ..., value => ...},
    my $Foo = $$section[3]{'value'};  #  ...].

    # Changing data:
    $Config->{newsection} = { this => 'that' }; # Add a section
    $Config->{section}->{Foo} = 'Not Bar!';     # Change a value
    delete $Config->{_};                        # Delete a value or section

    # Save a config:
    $Config->write( 'new.conf' );

=head1 DESCRIPTION

C<Config::Tiny::Ordered> is a perl class to read and write .ini style configuration
files with as little code as possible.

Read more in the docs for C<Config::Tiny>.

This module is primarily for reading human written files, and anything we
write shouldn't need to have documentation/comments. If you need something with more power,
move up to L<Config::Tiny>, L<Config::IniFiles>, L<Config::Simple>, L<Config::General> or one of
the many other C<Config::*> modules.

Note: L<Config::Tiny::Ordered> does B<not> preserve your comments or whitespace.

This module differs from C<Config::Tiny> in that here the data within a section is stored
in memory in the same order as it appears in the input file or string.

C<Config::Tiny::Ordered> does this by storing the keys and values in an arrayref
rather than, as most config modules do, in a hashref.

This arrayref consists of an ordered set of hashrefs, and these hashrefs use the keys
'key' and 'value'.

So, in memory, the data in the synopsis, for the section called 'section', looks like:

	[
	{key => 'reg_exp_1', value => 'High Priority'},
	{key => 'reg_exp_2', vlaue => 'Low Priority'},
	etc
	]

This means the config file can be used in situations such as with business rules
which must be applied in a specific order.

=head1 CONFIGURATION FILE SYNTAX

Files are the same format as for windows .ini files. For example:

	[section]
	var1=value1
	var2=value2

If a property is outside of a section at the beginning of a file, it will
be assigned to the C<"root section">, available at C<$Config-E<gt>{_}>.

Lines starting with C<'#'> or C<';'> are considered comments and ignored,
as are blank lines.

=head1 METHODS

=head2 new

The constructor C<new> creates and returns an empty C<Config::Tiny::Ordered> object.

=head2 read $filename

The C<read> constructor reads a config file, and returns a new
C<Config::Tiny::Ordered> object containing the properties in the file.

Returns the object on success, or C<undef> on error.

When C<read> fails, C<Config::Tiny::Ordered> sets an error message internally,
which you can recover via C<<Config::Tiny::Ordered->errstr>>. Although in B<some>
cases a failed C<read> will also set the operating system error
variable C<$!>, not all errors do and you should not rely on using
the C<$!> variable.

=head2 read_string $string;

The C<read_string> method takes, as an argument, the contents of a config file
as a string and returns the C<Config::Tiny::Ordered> object for it.

=head2 write $filename

The C<write> method generates the file content for the properties, and
writes it to disk to the filename specified.

Returns true on success or C<undef> on error.

=head2 write_string

Generates the file content for the object and returns it as a string.

=head2 errstr

When an error occurs, you can retrieve the error message either from the
C<$Config::Tiny::Ordered::errstr> variable, or using the C<errstr()> method.

=head1 Repository

L<https://github.com/ronsavage/Config-Tiny-Ordered.git>

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<https://github.com/ronsavage/Config-Tiny-Ordered/issues>

For other issues, or commercial enhancement or support, contact the author.

=head1 AUTHORS

Adam Kennedy E<lt>adamk@cpan.orgE<gt>, Ron Savage E<lt>rsavage@cpan.orgE<gt>

=head1 ACKNOWLEGEMENTS

This module is 99% as per L<Config::Tiny> by Adam Kennedy.

Ron Savage made some tiny changes to suppport the preservation of key order.

The test suite was likewise adapted.

=head1 SEE ALSO

L<Config::Tiny>, L<Config::IniFiles>, L<Config::Simple>, L<Config::General>, L<ali.as>

=head1 Copyright

	Copyright 2002 - 2008 Adam Kennedy.

	Australian copyright (c) 2009,  Ron Savage.
	All Programs of Ron's are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	the Artistic or the GPL licences, copies of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
