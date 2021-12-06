use Object::Pad 0.58;

package Corinna::RFC::Writer v0.1.0; # tooling needs this to pick up the version number

class Corinna::RFC::Writer :does(Corinna::RFC::Role::File) {
    use Carp 'croak';
    use File::Basename 'basename';
    use File::Spec::Functions qw(catfile catdir);
    use Corinna::RFC::Config::Reader;
    use Template::Tiny::Strict;

    # TODO Replace `has` with `field`
    has $FILE    :param(file);
    has $VERBOSE :param(verbose) = 0;
    has $CONFIG;
    has @TOC;

    ADJUST {
        unless ( -e $FILE ) {
            croak("$FILE does not exist");
        }

        # TODO Per the spec, this should be possible via a default assignement to $CONFIG
        my $reader = Corinna::RFC::Config::Reader->new( file => $FILE );
        $CONFIG = $reader->config;
        $self->_rewrite_config;
    }

    method generate_rfcs() {
        $self->_write_readme;
        $self->_write_rfcs;
        $self->_write_toc;
    }

    # TODO Use private subs
    method _write_toc() {
        my $toc_file      = $CONFIG->{rfcs}[0]{file};      # toc is always first
        my $toc_list      = join "\n" => @TOC;
        my $FILE_contents = $self->_slurp($toc_file);
        my $marker        = $CONFIG->{main}{toc_marker};
        unless ( $FILE_contents =~ /\Q$marker\E/ ) {
            croak("TOC marker '$marker' not found in toc file: $toc_file");
        }
        $FILE_contents =~ s/\Q$marker\E/$toc_list/;
        $self->_splat( $toc_file, $FILE_contents );
    }

    method _write_readme() {
        my $readme_template = $CONFIG->{main}{readme_template};
        my $readme          = $CONFIG->{main}{readme};
        print "Processing $readme_template\n" if $VERBOSE;
        my $tts = Template::Tiny::Strict->new(
            forbid_undef  => 1,
            forbid_unused => 1,
            name          => 'README',
        );
        my $template = $self->_slurp($readme_template);
        $tts->process(
            \$template,
            {
                templates => $CONFIG->{rfcs},
                config    => $CONFIG->{main},
            },
            \my $out,
        );
        $self->_splat( $readme, $out );
    }

    method _write_rfcs {
        my $rfcs    = $CONFIG->{rfcs};
        my $default = { name => 'README', basename => '/README.md' };
        foreach my $i ( 0 .. $#$rfcs ) {
            my $prev = $i > 0 ? $rfcs->[ $i - 1 ] : $default;
            my $rfc  = $rfcs->[$i];
            my $next = $rfcs->[ $i + 1 ] || $default;

            my $FILE = $rfc->{file};
            print "Processing $rfc->{source}\n" if $VERBOSE;
            my $tts = Template::Tiny::Strict->new(
                forbid_undef  => 1,
                forbid_unused => 1,
            );
            my $template = $self->_get_rfc_template($rfc);
            $tts->process(
                \$template,
                {
                    prev   => $prev,
                    rfc    => $rfc,
                    next   => $next,
                    config => $CONFIG->{main},
                },
                \my $out
            );
            $self->_splat( $FILE, $out );
        }
    }

    method _rewrite_config() {
        my $rfcs            = $CONFIG->{rfcs};
        my $readme_template = $CONFIG->{main}{readme}
          or die "No readme found in [main] for config";
        my $toc_template = $CONFIG->{main}{toc}
          or die "No toc found in [main] for config";
        $self->_assert_template_name( $readme_template,
            $CONFIG->{main}{template_dir} );
        $CONFIG->{main}{readme_template} =
          catfile( $CONFIG->{main}{template_dir}, $readme_template );
        $CONFIG->{main}{toc_template} = catfile(
            $CONFIG->{main}{template_dir},
            $CONFIG->{main}{rfc_dir},
            $toc_template
        );

        my $index = 1;

        unshift @$rfcs => {
            key   => 'Table of Contents',
            value => $CONFIG->{main}{toc},
        };

        foreach my $rfc (@$rfcs) {
            my $FILEname = $rfc->{value};
            $self->_assert_template_name(
                $FILEname,
                $CONFIG->{main}{template_dir},
                $CONFIG->{main}{rfc_dir}
            );
            delete $rfc->{value};
            $rfc->{name}   = delete $rfc->{key};
            $rfc->{source} = catfile( $CONFIG->{main}{template_dir},
                $CONFIG->{main}{rfc_dir}, $FILEname );
            $rfc->{file}     = catfile( $CONFIG->{main}{rfc_dir}, $FILEname );
            $rfc->{basename} = $FILEname;
            $rfc->{index}    = $index;
            $index++;
        }
    }

    method _assert_template_name( $FILEname, @dirs ) {
        unless ( $FILEname =~ /\.md$/ ) {
            croak("Template filename must end in '.md': $FILEname");
        }
        my $location = catfile( @dirs, $FILEname );
        unless ( -e $location ) {
            croak("Template '$location' does not exist");
        }
    }

    method _get_rfc_template($rfc) {
        my $template = $self->_renumbered_headings($rfc);
        return <<"END";
Prev: [[% prev.name %]]([% prev.basename %])   
Next: [[% next.name %]]([% next.basename %])

---

# Section [% rfc.index %]: [% rfc.name %]

**This file is automatically generated. If you wish to submit a PR, do not
edit this file directly. Please edit
[[% rfc.source %]]([% config.github %]/tree/master/[% rfc.source %]) instead.**

---

$template

---

Prev: [[% prev.name %]]([% prev.basename %])   
Next: [[% next.name %]]([% next.basename %])
END
    }

    method _renumbered_headings($rfc) {
        my $template = $self->_slurp( $rfc->{source} );

        push @TOC =>
          "\n# [Section: $rfc->{index}: $rfc->{name}]($rfc->{basename})\n";

        # XXX fix me. Put this in config
        return $template if $rfc->{name} eq 'Changes';

        my $rewritten = '';
        my @lines     = split /\n/ => $template;

        my %levels = map { $_ => 0 } 1 .. 4;

        my $last_level = 1;

        my $in_code = 0;
      LINE: foreach my $line (@lines) {
            if ( $line =~ /^```/ ) {
                if ( !$in_code ) {
                    $in_code = 1;
                }
                else {
                    $in_code = 0;
                }
                $rewritten .= "$line\n";
            }
            elsif ( $line =~ /^(#+)\s+(.*)/ && !$in_code ) {
                my $hashes = $1;
                my $title  = $2;
                my $level  = length $hashes;
                if ( $last_level == $level ) {

                    # ## 1.2
                    # ## 1.3
                    $levels{$level}++;
                }
                elsif ( $last_level < $level ) {

                    # #
                    # ##
                    $levels{$level} = 1;
                }
                else {
                    # ##
                    # #
                    $levels{1}++;
                    for my $i ( 2 .. $level ) {
                        $levels{$i} = 1;
                    }
                }
                $last_level = $level;
                if ( $levels{1} == 0 ) {
                    croak("$rfc->{source} didn't start with a level 1 header");
                }
                my $section_num = join '.' => $rfc->{index},
                  map { $levels{$_} } 1 .. $level;
                my $num_dots = $section_num =~ tr/\././;
                my $leader   = $num_dots ? '..' x $num_dots : '';
                push @TOC => "* `$leader` $section_num $title";
                $rewritten .= "$hashes $section_num $title";
            }
            else {
                $rewritten .= "$line\n";
            }
        }
        return $rewritten;
    }
}

__END__

=head1 NAME

Corinna::RFC::Writer - Generate navigable pages for Corinna RFC

=head1 SYNOPSIS

    use Corinna::RFC::Writer;
    my $writer = Corinna::RFC::Writer->new(
        file    => 'config/rfcs',
        verbose => 1,
    );
    $writer->generate_rfcs;

=head1 DESCRIPTION

=head2 Overview

This is being written using L<Object::Pad>, a module being used as a testbed
for many of the ideas in the Corinna RFC. Over time, we'd like to gradually
migrate this to Corinna itself.

There aren't really any user-serviceable parts in this codebase, but it's
worth browsing through the code to get a "feel" for how object-oriented
programming is evolving in Perl.

=head2 Behavior

When an instance of C<Corinna::RFC::Writer> is loaded, it uses
C<Corinna::RFC::Config::Reader> to load the C<config/rfcs> file. We then
rewrite the config data to be more useful, internally.

=head3 README.md

When C<< $writer-> generate_rfcs >> is called, we first write out our
C<README.md> file, using the files listed in C<config/rfcs> as a quick
synopsis of the RFC.

=head3 RFC Sections

Then we iterate through the RFCs sections in the order listed C<config/rfcs>
and using the correcsponding RFC document in F<templates/rfcs> and we write
the result to the C<rfcs> directory. The resulting document will have a title
and navigation added, along with a warning to not edit it directly.

Every RFC section listed in C<templates/rfcs> should use markdown headers to
indicate structure. When we read the templates, we will use these to generate
section and subsection numbers.  For example, for section number C<X>, we
might have this:

    # X.1
    # X.2
    ## X.2.1
    ## X.2.2
    #### X.2.2.1
    ## X.2.3
    # X.3

While the RFC is being developed, those will change. When the RFC is finally
delivered, we will strive to preserve the numbering to make it easier for people
to refer to sections of the RFC.

=head3 Table of Contents

Once all of the RFC sections have been written, we take the accumulated data
from the section numbering and using this to write out a table of contents, a portion
of which may look like this:

    Section: 4: Classes
    .. 4.1 Overview
    .. 4.2 Discussion
    .... 4.2.1 Versions
    .... 4.2.2 Inheritance
    .... 4.2.3 Roles
    .... 4.2.4 Abstract Classes
    .... 4.2.5 Subroutines versus Methods
    Section: 5: Class Construction
    .. 5.1 Overview
    .. 5.2 Steps
    .... 5.2.1 Step 1 Verify even-sized list of args
    .... 5.2.2 Step 2 Constructor keys may not be references
    .... 5.2.3 Step 3 Find constructor args
    .... 5.2.4 Step 4 Err out on unknown keys
    .... 5.2.5 Step 5 new()
    .... 5.2.6 Step 6 ADJUST
    .. 5.3 MOP Pseudocode
