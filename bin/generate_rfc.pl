#!/usr/bin/env perl

use lib 'lib';
use strict;
use warnings;
use Data::Dumper;
use Carp 'croak';
use File::Basename 'basename';
use File::Spec::Functions qw(catfile catdir);
use Config::Tiny::Ordered;
use Template::Tiny::Strict;

local $Data::Dumper::Indent   = 0;
local $Data::Dumper::Terse    = 1;
local $Data::Dumper::Sortkeys = 1;

my $config = Config::Tiny::Ordered->read('config/rfcs');
rewrite_config($config);
write_readme($config);
write_rfcs($config);
exit;

sub write_rfcs {
    my $config  = shift;
    my $rfcs    = $config->{rfcs};
    my $default = { name => 'README', basename => '/README.md' };
    foreach my $i ( 0 .. $#$rfcs ) {
        my $prev = $i > 0 ? $rfcs->[ $i - 1 ] : $default;
        my $rfc  = $rfcs->[$i];
        my $next = $rfcs->[ $i + 1 ] || $default;

        my $file   = $rfc->{file};
        my $tts    = Template::Tiny::Strict->new(
            forbid_undef  => 1,
            forbid_unused => 1,
        );
        my $template = get_rfc_template($rfc);
        $tts->process(
            \$template,
            {
                prev => $prev,
                rfc  => $rfc,
                next => $next,
            },
            \my $out
        );
        splat( $file, $out );
    }
}

sub get_rfc_template {
    my $rfc   = shift;
    my $template = renumbered_headings($rfc);
    return <<"END";
Prev: [[% prev.name %]]([% prev.basename %])   
Next: [[% next.name %]]([% next.basename %])

---

# Section [% rfc.index %]: [% rfc.name %]

$template

---

Prev: [[% prev.name %]]([% prev.basename %])   
Next: [[% next.name %]]([% next.basename %])
END
}

sub renumbered_headings {
    my $rfc = shift;
    my $template = slurp($rfc->{source});
    my $rewritten = '';
    my @lines = split /\n/ => $template;

    my %levels = map { $_ => 0 } 1 .. 4;

    my $last_level = 1;

    my $in_code = 0;
    LINE: foreach my $line (@lines) {
        if ( $line =~ /^```/ ) {
            if ( !$in_code) {
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
                for my $i (2..$level) {
                    $levels{$i} = 1;
                }
            }
            $last_level = $level;
            if ($levels{1} ==0) {
                croak("$rfc->{source} didn't start with a level 1 header");
            }
            my $section_num = join '.' => $rfc->{index}, map { $levels{$_} }  1..$level;
            $rewritten .= "$hashes $section_num $title";
        }
        else {
            $rewritten .= "$line\n";
        }
    }
    return $rewritten;
}

sub write_readme {
    my $config          = shift;
    my $readme_template = $config->{main}{readme_template};
    my $readme          = $config->{main}{readme};
    my $tts             = Template::Tiny::Strict->new(
        forbid_undef  => 1,
        forbid_unused => 1,
        name          => 'README',
    );
    my $template = slurp($readme_template);
    $tts->process( \$template, { templates => $config->{rfcs} }, \my $out, );
    splat( $readme, $out );
}

sub rewrite_config {
    my $config = shift;
    my $rfcs   = $config->{rfcs};
    my %main;
    foreach my $entry ( @{ $config->{main} } ) {
        $main{ $entry->{key} } = $entry->{value};
    }
    my $readme_template = $main{readme}
      or die "No readme found in [main] for config";
    assert_template_name( $readme_template, $main{template_dir} );
    $main{readme_template} = catfile( $main{template_dir}, $readme_template );
    $main{readme} =~ s/\.tt$//;

    $config->{main} = \%main;
    my $index = 1;
    foreach my $rfc (@$rfcs) {
        my $filename = $rfc->{value};
        assert_template_name( $filename, $main{template_dir}, $main{rfc_dir} );
        delete $rfc->{value};
        $rfc->{name} = delete $rfc->{key};
        $rfc->{source} =
          catfile( $main{template_dir}, $main{rfc_dir}, $filename );
        $filename =~ s/\.tt$//;
        $rfc->{file}     = catfile( $main{rfc_dir}, $filename );
        $rfc->{basename} = $filename;
        $rfc->{index}    = $index;
        $index++;
    }
}

sub assert_template_name {
    my ( $filename, @dirs ) = @_;
    unless ( $filename =~ /\.md\.tt$/ ) {
        croak("Template filename must end in '.md\.tt': $filename");
    }
    my $location = catfile( @dirs, $filename );
    unless ( -e $location ) {
        croak("Template '$location' does not exist");
    }
}

sub slurp {
    my $file = shift;
    open my $fh, '<', $file or die "Cannot open $file for reading: $!";
    return do { local $/; <$fh> };
}

sub splat {
    my ( $file, $data ) = @_;
    if ( ref $data ) {
        croak("Data for splat '$file' must not be a reference ($data)");
    }
    open my $fh, '>', $file or die "Cannot open $file for writing: $!";
    print {$fh} $data;
}
