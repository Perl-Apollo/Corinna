#!/usr/bin/env perl

use Test::Most;
use Time::HiRes 'nanosleep';
use Corinna::Example::Person;

my $villain =
  Corinna::Example::Person->new( title => 'Dr.', name => 'Zacharary Smith' );
is $villain->num_people, 1, 'We should have one person';

nanosleep 5;
my $boy = Corinna::Example::Person->new( name => 'Will Robinson' );
is $villain->num_people, 2, 'We should have two people';
cmp_ok $boy->created, '>', $villain->created, 'The boy should be created after the villain';

is $villain->name, 'Dr. Zacharary Smith',
  'name() should include a title if it exists';
is $boy->name, 'Will Robinson', '... and skip the title if it does not exist';

undef $villain;
is $boy->num_people, 1,
  'We should have one person left after killing the villain';

done_testing;
