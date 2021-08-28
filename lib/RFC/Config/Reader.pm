
# Forked from Config::Tiny::Ordered to give us both
# list and hash config entries
# If you thought Config::Tiny was small...

use Object::Pad;

class RFC::Config::Reader does RFC::Role::File {
    has $file   :param;
    has $config :reader = {};

    BUILD {
        $self->_read_string;
    }

    method _read_string {
        my $config_data = $self->_slurp($file);

        # Parse the data.
        my $ns      = '_';
        my $counter = 0;
        $config->{$ns} = [];

      LINE: for ( split /(?:\015{1,2}\012|\015|\012)/, $config_data ) {
            $counter++;

            # Skip comments and empty lines.
            next if /^\s*(?:\#|\;|$)/;

            # Remove inline comments.
            s/\s\;\s.+$//g;

            # Handle section headers.
            if (/^\s*\[(\@)?\s*(.+?)\s*\]\s*$/) {
                if ( '@' eq ( $1 || '' ) ) {    # they want a list
                    $config->{ $ns = $2 } ||= [];
                }
                else {                          # they want k/v pairs
                    $config->{ $ns = $2 } ||= {};
                }
                next LINE;
            }

            # Handle properties.
            if (/^\s*([^=]+?)\s*=\s*(.*?)\s*$/) {
                my $section = $config->{$ns};
                if ( 'ARRAY' eq ref $section ) {
                    push @$section, { key => $1, value => $2 };
                }
                else {
                    $section->{$1} = $2;
                }
                next;
            }
            die "Syntax error at line $counter: '$_'";
        }
    }
}

__END__

=pod

=head1 NAME

RFC::Config::Reader - Read RFC config files. For internal use only

=head1 SYNOPSIS

In your configuration file:

    root=something
    
    # the following section is ordered
    [@section]
    one=two
    one=three
    Foo=Bar
    this=Your Mother!
    blank=
    
    # the following section will be stored as k/v pairs
    [Section Two]
    something else=blah
       remove = whitespace  

In your program:

    use RFC::Config::Reader;

    # Create a config:
    my $Config = Config::Tiny::Ordered->new('file.conf');

Your config will contain:

    {
        '_'     => [ { key => 'root', value => 'something' }, ],
        section => [
            { key => 'one',   value => 'two' },
            { key => 'one',   value => 'three' },
            { key => 'Foo',   value => 'Bar' },
            { key => 'this',  value => 'Your Mother!' },
            { key => 'blank', value => '' },
        ],
        'Section Two' => {
            'something else' => 'blah',
            'remove'         => 'whitespace'
        },
    }

=head1 DESCRIPTION

C<RFC::Config::Reader> is a perl class to read .ini style configuration
files with as little code as possible.

Read more in the docs for C<Config::Tiny>.

This module is primarily for reading human written files, and anything we
write shouldn't need to have documentation/comments. If you need something with more power,
move up to L<Config::Tiny>, L<Config::IniFiles>, L<Config::Simple>, L<Config::General> or one of
the many other C<Config::*> modules.

This module differs from C<Config::Tiny> in that if there is a data section
whose name begins with an C<@> symbol, the data is stored in memory in the
same order as it appears in the input file or string.

C<RFC::Config::Reader> does this by storing the keys and values in an arrayref
rather than, as most config modules do, in a hashref.

The arrayref sections consists of an ordered set of hashrefs, and these
hashrefs use the keys 'key' and 'value'.

So, in memory, the data in the synopsis, for the section called 'section',
looks like:

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

Sections started with an `@` symbol are preserved in order:

    [@rfcs]
    Overview=overview.md
    Grammar=grammar.md
    Classes=classes.md
    Class Construction=class-construction.md
    Attributes=attributes.md
    Methods=methods.md
    Roles=roles.md
    Phasers=phasers.md
    Questions=questions.md
    Quotes=quotes.md
    Changes=major-changes.md

=head1 METHODS

=head2 new

The constructor C<new> creates and returns an empty C<Config::Tiny::Ordered> object.

If you pass it the name of the file to read, it will read that config.

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

=head2 errstr

When an error occurs, you can retrieve the error message either from the
C<$Config::Tiny::Ordered::errstr> variable, or using the C<errstr()> method.

=head1 Repository

...

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

...

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
