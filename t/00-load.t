#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'ZeroMQ::Oneliner' ) || print "Bail out!\n";
}

diag( "Testing ZeroMQ::Oneliner $ZeroMQ::Oneliner::VERSION, Perl $], $^X" );
