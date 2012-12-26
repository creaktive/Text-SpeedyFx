#!/usr/bin/env perl
use autodie;
use bytes;
use strict;
use warnings;

use Benchmark qw(cmpthese :hireswallclock);
use File::Map qw(map_file);
use Text::SpeedyFx;

map_file
    my $data,
    q(enwik8);

my $sfx = Text::SpeedyFx->new(1, 8);

cmpthese(10 => {
    hash        => sub { $sfx->hash($data) },
    hash_fv     => sub { $sfx->hash_fv($data, 100) },
    hash_min    => sub { $sfx->hash_min($data) },
});
