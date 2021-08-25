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
    my $rfc_dir = $config->{main}{rfc_dir};

    my $rfcs = $config->{rfcs};
    my $default = { name => 'README', basename => '/README.md' };
    foreach my $i ( 0 .. $#$rfcs  ) {
        my $prev = $i > 0 ? $rfcs->[ $i - 1 ] : $default;
        my $rfc  = $rfcs->[$i];
        my $next = $rfcs->[ $i + 1 ] || $default;
            

        #{
        #    'file'   => 'rfc/overview.md',
        #    'index'  => 1,
        #    'name'   => 'Overview',
        #    'source' => 'templates/rfc/overview.md.tt'
        #}
        my $source = $rfc->{source};
        my $index  = $rfc->{index};
        my $name   = $rfc->{name};
        my $file   = $rfc->{file};
        my $tts             = Template::Tiny::Strict->new(
            forbid_undef  => 1,
            forbid_unused => 1,
            name          => $name,
        );
        my $template = get_rfc_template($source);
        $tts->process(
            \$template,
            {
                prev => $prev,
                name => $name,
                next => $next,
            },
            \my $out
        );
    }
}

sub get_rfc_template {
    my $source = shift;
    my $template = slurp($source);
    return <<"END";
Prev: [[% prev.name %]]([% prev.basename %])   
Next: [[% next.name %]]([% next.basename %])

---

$template

---

Prev: [[% prev.name %]]([% prev.basename %])   
Next: [[% next.name %]]([% next.basename %])
END
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
    my $main   = $config->{main};
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
