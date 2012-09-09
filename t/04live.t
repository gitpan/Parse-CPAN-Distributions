#!/usr/bin/perl -w
use strict;

use LWP::UserAgent;
use Parse::CPAN::Distributions;
use Test::More  tests => 6;

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
 
my $response = $ua->get('http://www.cpan.org');

SKIP: {
    skip "No connection", 6 unless($response->is_success);
    {
        my $obj = Parse::CPAN::Distributions->new(file => '');
        isa_ok($obj,'Parse::CPAN::Distributions');
        is($obj->author_of('CPAN-WWW-Testers-Generator','0.31'),'BARBIE');
    }
    {
        my $obj = Parse::CPAN::Distributions->new();
        isa_ok($obj,'Parse::CPAN::Distributions');
        is($obj->author_of('CPAN-WWW-Testers-Generator','0.31'),'BARBIE');
    }
    {
        my $obj = Parse::CPAN::Distributions->new(file => 't/samples/nofile');
        isa_ok($obj,'Parse::CPAN::Distributions');
        is($obj->author_of('CPAN-WWW-Testers-Generator','0.31'),'BARBIE');
    }
}
