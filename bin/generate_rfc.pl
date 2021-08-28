#!/usr/bin/env perl

use lib 'lib';
use strict;
use warnings;
use RFC::Writer;

my $writer = RFC::Writer->new( file => 'config/rfcs', verbose => 1 );
$writer->generate_rfcs;

__END__

=head1 NAME

bin/generate_rfc.pl - regenerate the Corinna RFC

=head1 SYNOPSIS

    perl bin/generate_rfc.pl

=head1 DESCRIPTION

This program reads the `config/rfcs` to determine what files in the
`templates` directory should be read and written out as part of the full RFCs.
It reads each of the files in the `templates/rfc` directory and will rewrite
each markdown `^#` header with a corresponding section number such as `3.2.3`.
This will make it easier, later, to refer to different portions of the RFC
when it's presented.

