# Forked from Config::Tiny::Ordered

use v5.26.0;
use lib 'lib';
use Object::Pad 0.58;

class Corinna::RFC::Config::Reader :does(Corinna::RFC::Role::File) {
    use Syntax::Keyword::Try;
    use Storable 'dclone';
    use Object::Types qw(ArrayRef HashRef Str Dict);
    use Carp 'croak';

    has $FILE :param(file);
    has $CONFIG = {};

    BUILD {
        $self->_read_string;
        $self->_validate;
    }

    method config() {

        # by doing this, the caller can mutate $CONFIG to their
        # heart's content, but internaly we're "safe"
        return dclone($CONFIG);
    }

    method _validate() {
        state $check = Dict(
            rfcs => ArrayRef( Dict( key => Str, value => Str ), ),
            main => Dict(
                template_dir => Str,
                rfc_dir      => Str,
                readme       => Str,
                toc          => Str,
                toc_marker   => Str,
                github       => Str,
            ),
        );
        try {
            $check->validate($CONFIG);
        }
        catch ($error) {
            croak("Config file error: $error");
        }
    }

    method _read_string() {
        my $config_data = $self->_slurp($FILE);

        my $line_number = 0;
        my $namespace   = '_';    # Catch-all in case they add extra stuff
        $CONFIG->{$namespace} = [];

      LINE: for ( split /\n/, $config_data ) {
            $line_number++;

            # Skip comments and empty lines.
            next LINE if /^\s*(?:\#|\;|$)/;

            # Remove inline comments.
            s/\s\;\s.+$//g;

            # Handle section headers.
            if (/^ \s* \[ (?<is_list>\@)? \s* (?<namespace>.+?) \s* \] \s*$/x) {
                if ( $+{is_list} ) {    # they want a list
                    $CONFIG->{ $namespace = $+{namespace} } ||= [];
                }
                else {                  # they want k/v pairs
                    $CONFIG->{ $namespace = $+{namespace} } ||= {};
                }
                next LINE;
            }

            # Handle properties.
            if (/^ \s* (?<key>[^=]+?) \s* = \s* (?<value>.*?) \s* $/x) {
                my $section = $CONFIG->{$namespace};
                if ( 'ARRAY' eq ref $section ) {
                    push $section->@*, { key => $+{key}, value => $+{value} };
                }
                else {
                    $section->{ $+{key} } = $+{value};
                }
                next LINE;
            }
            die "Syntax error at line $line_number '$_'";
        }
        delete $CONFIG->{_} unless $CONFIG->{_}->@*;
    }
}

__END__

=pod

=head1 NAME

Corinna::RFC::Config::Reader - Immutable object to read the Corinna RFC generator config

=head1 SYNOPSIS

In your configuration file:

    # see Corinna::RFC::Config::Reader for syntax
    [@rfcs]                            ; the @ means 'preserve the order of these values
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

    [main]                             ; k/v pairs: $config->{main}{readme} = README.md
    template_dir=templates             ; where the templates are stored
    rfc_dir=rfc                        ; where the rfcs will be saved
    readme=README.md                   ; name of the README.md file
    toc=toc.md                         ; name we'll use for our table of contents file
    toc_marker={{TOC}}                 ; the marker in the toc file for post-process insertion of table of contents
    github=https://github.com/Ovid/Cor ; url of this repo

In your program:

    use Corinna::RFC::Config::Reader;

    # Create a config:
    my $reader = Corinna::RFC::Config::Reader->new( file => 'file.conf' );
    my $config = $reader->config;

Your config will contain:

    {
        main => {
            github       => 'https://github.com/Ovid/Cor',
            readme       => 'README.md',
            rfc_dir      => 'rfc',
            template_dir => 'templates',
            toc          => 'toc.md',
            toc_marker   => '{{TOC}}'
        },
        rfcs => [
            { key => 'Overview',           value => 'overview.md' },
            { key => 'Grammar',            value => 'grammar.md' },
            { key => 'Classes',            value => 'classes.md' },
            { key => 'Class Construction', value => 'class-construction.md' },
            { key => 'Attributes',         value => 'attributes.md' },
            { key => 'Methods',            value => 'methods.md' },
            { key => 'Roles',              value => 'roles.md' },
            { key => 'Phasers',            value => 'phasers.md' },
            { key => 'Questions',          value => 'questions.md' },
            { key => 'Quotes',             value => 'quotes.md' },
            { key => 'Changes',            value => 'major-changes.md' }
        ]
    };

=head1 DESCRIPTION

C<Corinna::RFC::Config::Reader> is a perl class to read Corinna RFC .ini style configuration
file.

This module differs from C<Config::Tiny> in that if there is a data section
whose name begins with an C<@> symbol, the data is stored in memory in the
same order as it appears in the input file or string.

Futher, there is a grammar for the resulting config data that is defined via
C<Types::Standard>.

=head1 CONFIGURATION FILE SYNTAX

Files are the same format as for windows .ini files. For example:

	[section]
	var1=value1
	var2=value2

Lines starting with C<'#'> or C<';'> are considered comments and ignored,
as are blank lines.

Sections started with an `@` symbol are preserved in order:

    [@rfcs]
    Overview=overview.md
    Grammar=grammar.md
    Classes=classes.md

=head1 METHODS

=head2 C<new( file => $config_file )>

    my $config = Corinna::RFC::Config::Reader->new(file => $file);

Returns a new C<Corinna::RFC::Config::Reader> object.

=head2 C<config>

Returns a I<cloned> hashref of the config. Because we clone the data before we return it,
you may call C<< $reader->config >> multiple times and always get the same response.
=head1 Repository

https://github.com/Ovid/Cor

=head1 DESIGN NOTES

This module is rather interesting for new developers in that it:

=over 4

=item * Consumes a role (L<Corinna::RFC::Role::File>)

=item * Is immutable

=item * The internal C<_validate> method shows how to apply type constraints

=back

=head1 SUPPORT

Bugs should be reported via https://github.com/Ovid/Cor/issues

=head1 AUTHORS

Curtis "Ovid" Poe E<lt>ovid@allaroundtheworld.frE<gt>, based on code by Adam
Kennedy E<lt>adamk@cpan.orgE<gt> and Ron Savage E<lt>rsavage@cpan.orgE<gt>.

=head1 SEE ALSO

L<Config::Tiny::Ordered>, L<Config::Tiny>, L<Config::IniFiles>,
L<Config::Simple>, L<Config::General>, L<ali.as>

=head1 Copyright and License

This software is copyright (c) 2021 by Curtis "Ovid" Poe.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.

=cut
