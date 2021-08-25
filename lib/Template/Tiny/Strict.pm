package Template::Tiny::Strict;

# ABSTRACT: Template Toolkit reimplemented in as little code as possible

# Load overhead: 40k

use strict;

our $VERSION = '1.18';

# Evaluatable expression
my $EXPR = qr/ [a-z_][\w.]* /xs;

# Opening [% tag including whitespace chomping rules
my $LEFT = qr/
	(?:
		(?: (?:^|\n) [ \t]* )? \[\%\-
		|
		\[\% \+?
	) \s*
/xs;

# Closing %] tag including whitespace chomping rules
my $RIGHT = qr/
	\s* (?:
		\+? \%\]
		|
		\-\%\] (?: [ \t]* \n )?
	)
/xs;

# Preparsing run for nesting tags
my $PREPARSE = qr/
	$LEFT ( IF | UNLESS | FOREACH ) \s+
		(
			(?: \S+ \s+ IN \s+ )?
		\S+ )
	$RIGHT
	(?!
		.*?
		$LEFT (?: IF | UNLESS | FOREACH ) \b
	)
	( .*? )
	(?:
		$LEFT ELSE $RIGHT
		(?!
			.*?
			$LEFT (?: IF | UNLESS | FOREACH ) \b
		)
		( .+? )
	)?
	$LEFT END $RIGHT
/xs;

# Condition set
my $CONDITION = qr/
	\[\%\s
		( ([IUF])\d+ ) \s+
		(?:
			([a-z]\w*) \s+ IN \s+
		)?
		( $EXPR )
	\s\%\]
	( .*? )
	(?:
		\[\%\s \1 \s\%\]
		( .+? )
	)?
	\[\%\s \1 \s\%\]
/xs;

sub new {
    my ( $class, %arg_for ) = @_;
    return bless {
        TRIM          => $arg_for{TRIM},
        forbid_undef  => $arg_for{forbid_undef},
        forbid_unused => $arg_for{forbid_unused},
        name          => ( $arg_for{name} || 'template' ),
        _undefined    => {},
        _used         => {},
    } => $class;
}

sub name { $_[0]->{name} }

# Copy and modify
sub preprocess {
    my $self = shift;
    my $text = shift;
    $self->_preprocess( \$text );
    return $text;
}

sub process {
    my $self  = shift;
    my $copy  = ${ shift() };
    my $stash = shift || {};
    $self->{_undefined} = {};
    $self->{_used}      = {};

    local $^W = 0;

    # Preprocess to establish unique matching tag sets
    $self->_preprocess( \$copy );

    # Process down the nested tree of conditions
    my $result = $self->_process( $stash, $copy );
    my $errors = '';
    if ( $self->{forbid_undef} ) {
        if ( my %errors = %{ $self->{_undefined} } ) {
            $errors = join "\n" => sort keys %errors;
        }
    }
    if ( $self->{forbid_unused} ) {
        my @unused;
        foreach my $var ( keys %$stash ) {
            unless ( $self->{_used}{$var} ) {
                push @unused => $var;
            }
        }
        if ( my $unused = join ', ' => sort @unused ) {
            $errors
              .= "\nThe following variables were passed to the template but unused: '$unused'";
        }
    }
    if ($errors) {
        require Carp;
        my $name = $self->name;
        my $class = ref $self;
        $errors = "$class processing for '$name' failed:\n$errors";
        Carp::croak($errors);
    }

    if (@_) {
        ${ $_[0] } = $result;
    }
    elsif ( defined wantarray ) {
        require Carp;
        Carp::carp(
            'Returning of template results is deprecated in Template::Tiny::Strict 0.11'
        );
        return $result;
    }
    else {
        print $result;
    }
}

######################################################################
# Support Methods

# The only reason this is a standalone is so we can
# do more in-depth testing.
sub _preprocess {
    my $self = shift;
    my $copy = shift;

    # Preprocess to establish unique matching tag sets
    my $id = 0;
    1 while $$copy =~ s/
		$PREPARSE
	/
		my $tag = substr($1, 0, 1) . ++$id;
		"\[\% $tag $2 \%\]$3\[\% $tag \%\]"
		. (defined($4) ? "$4\[\% $tag \%\]" : '');
	/sex;
}

sub _process {
    my ( $self, $stash, $text ) = @_;

    $text =~ s/
		$CONDITION
	/
		($2 eq 'F')
			? $self->_foreach($stash, $3, $4, $5)
			: eval {
				$2 eq 'U'
				xor
				!! # Force boolification
				$self->_expression($stash, $4)
			}
				? $self->_process($stash, $5)
				: $self->_process($stash, $6)
	/gsex;

    # Resolve expressions
    $text =~ s/
		$LEFT ( $EXPR ) $RIGHT
	/
		eval {
			$self->_expression($stash, $1)
			. '' # Force stringification
		}
	/gsex;

    # Trim the document
    $text =~ s/^\s*(.+?)\s*\z/$1/s if $self->{TRIM};

    return $text;
}

# Special handling for foreach
sub _foreach {
    my ( $self, $stash, $term, $expr, $text ) = @_;

    # Resolve the expression
    my $list = $self->_expression( $stash, $expr );
    unless ( ref $list eq 'ARRAY' ) {
        return '';
    }

    # Iterate
    return join '',
      map { $self->_process( { %$stash, $term => $_ }, $text ) } @$list;
}

# Evaluates a stash expression
sub _expression {
    my $cursor = $_[1];
    my @path   = split /\./, $_[2];
    $_[0]->{_used}{ $path[0] } = 1;
    foreach (@path) {

        # Support for private keys
        return undef if substr( $_, 0, 1 ) eq '_';

        # Split by data type
        my $type = ref $cursor;
        if ( $type eq 'ARRAY' ) {
            return '' unless /^(?:0|[0-9]\d*)\z/;
            $cursor = $cursor->[$_];
        }
        elsif ( $type eq 'HASH' ) {
            $cursor = $cursor->{$_};
        }
        elsif ($type) {
            $cursor = $cursor->$_();
        }
        else {
            return '';
        }
    }
    if ( $_[0]->{forbid_undef} && !defined $cursor ) {
        my $path = join '.' => @path;
        $_[0]->{_undefined}{"Undefined value in template path '$path'"} = 1;
        return '';
    }

    return $cursor;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Template::Tiny::Strict - Template Toolkit reimplemented in as little code as possible

=head1 VERSION

version 1.18

=head1 SYNOPSIS

    my $template = Template::Tiny::Strict->new(
        TRIM          => 1,
        forbid_undef  => $optional_boolean,
        forbid_unused => $optional_boolean,
        name          => $optional_string,
    );

    # Print the template results to STDOUT
    $template->process( <<'END_TEMPLATE', { foo => 'World' } );
    Hello [% foo %]!
    END_TEMPLATE

    # Fatal: Unused variable
    $template->process( <<'END_TEMPLATE', { foo => 'World', bar => 'Hello' } );
    Hello [% foo %]!
    END_TEMPLATE

    # Fatal: Undefined variable
    $template->process( <<'END_TEMPLATE', { foo => undef } );
    Hello [% foo %]!
    END_TEMPLATE

=head1 DESCRIPTION

B<Template::Tiny::Strict> is a drop-in replacement for L<Template::Tiny>. By default,
the behavior is identical. However, we have new I<optional> arguments you can pass
to the constructor:

=over 4

=item * C<forbid_undef>

If true, I<any> access of an undefined value in the template will cause the code to C<croak>
with an error such as:

    Undefined value in template path 'items.1'

=item * C<forbid_unused>

If true, I<any> variable passed in the stash that is not used will cause the coad to
C<croak> with an error such as:

    The following variables were passed to the template but unused: 'name'

=item * C<name>

Accepts a string as the "name" of the template. Errors will be reported with
this name. Make it easier to track down the errant template if you are
generating plenty of them.

=back

All errors are gathered and reported at once.

B<Note>: what follows is the remainder of the original POD.

It is intended for use in light-usage, low-memory, or low-cpu templating
situations, where you may need to upgrade to the full feature set in the
future, or if you want the retain the familiarity of TT-style templates.

For the subset of functionality it implements, it has fully-compatible template
and stash API. All templates used with B<Template::Tiny::Strict> should be able to be
transparently upgraded to full Template Toolkit.

Unlike Template Toolkit, B<Template::Tiny::Strict> will process templates without a
compile phase (but despite this is still quicker, owing to heavy use of
the Perl regular expression engine.

=head2 SUPPORTED USAGE

Only the default C<[% %]> tag style is supported.

Both the C<[%+ +%]> style explicit whitespace and the C<[%- -%]> style
explicit chomp B<are> supported, although the C<[%+ +%]> version is unneeded
in practice as B<Template::Tiny::Strict> does not support default-enabled C<PRE_CHOMP>
or C<POST_CHOMP>.

Variable expressions in the form C<[% foo.bar.baz %]> B<are> supported.

Appropriate simple behaviours for C<ARRAY> references, C<HASH> references and
objects are supported. "VMethods" such as [% array.length %] are B<not>
supported at this time.

C<IF>, C<ELSE> and C<UNLESS> conditional blocks B<are> supported, but only with
simple C<[% foo.bar.baz %]> conditions.

Support for looping (or rather iteration) is available in simple
C<[% FOREACH item IN list %]> form B<is> supported. Other loop structures are
B<not> supported. Because support for arbitrary or infinite looping is not
available, B<Template::Tiny::Strict> templates are not turing complete. This is
intentional.

All of the four supported control structures C<IF>/C<ELSE>/C<UNLESS>/C<FOREACH>
can be nested to arbitrary depth.

The treatment of C<_private> hash and method keys is compatible with
L<Template> Toolkit, returning null or false rather than the actual content
of the hash key or method.

Anything beyond the above is currently out of scope.

=head1 METHODS

=head2 new

  my $template = Template::Tiny::Strict->new(
      TRIM => 1,
  );

The C<new> constructor is provided for compatibility with Template Toolkit.

The only parameter it currently supports is C<TRIM> (which removes leading
and trailing whitespace from processed templates).

Additional parameters can be provided without error, but will be ignored.

=head2 process

  # DEPRECATED: Return tempy C<STDOUT>) for compatibility with L<Template>.

=head1 SEE ALSO

L<Config::Tiny>, L<CSS::Tiny>, L<YAML::Tiny>

=head1 AUTHOR

Adam Kennedy <adamk@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Adam Kennedy.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
