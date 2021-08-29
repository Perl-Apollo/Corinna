#!/usr/bin/env perl

use utf8;
use Test::Most;
use Object::Pad;
use File::Temp 'tempfile';

class Example does Corinna::RFC::Role::File {
    method write_it( $filename, $string ) {
        $self->_splat( $filename, $string );
    }

    method read_it($filename) {
        $self->_slurp($filename);
    }
}

my ( $fh, $filename ) = tempfile();

my $string = <<'END';
This is
	a test string
		with réally 
	weïrd
content.
END

explain "As of Object::Pad .52, we cannot call methods on non-instances";
my $example = Example->new;
ok $example->write_it( $filename, $string ),
  'We should be able to write data to a file';
ok my $result = $example->read_it($filename), '... and read it back out';
is $result, $string, '... and have it unchanged';

done_testing;
