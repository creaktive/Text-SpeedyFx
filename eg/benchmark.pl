#!/usr/bin/env perl
use autodie;
use strict;
use utf8;
use warnings;

use Benchmark qw(cmpthese :hireswallclock);
use Text::SpeedyFx;

my $file = q(enwik8);
my $sfx = Text::SpeedyFx->new;

cmpthese(10 => {
    hash        => sub {
        open(my $fh, q(<:encoding(UTF-8)), $file);
        $sfx->hash($_)
            while <$fh>;
        close $fh;
    },
    hash_fv     => sub {
        open(my $fh, q(<:encoding(UTF-8)), $file);
        $sfx->hash_fv($_, 100)
            while <$fh>;
        close $fh;
    },
    hash_min    => sub {
        open(my $fh, q(<:encoding(UTF-8)), $file);
        $sfx->hash_min($_)
            while <$fh>;
        close $fh;
    },
});
