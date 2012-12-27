#!/usr/bin/env perl
use autodie;
use strict;
use utf8;
use warnings;

use Benchmark qw(cmpthese :hireswallclock);
use Text::SpeedyFx;

my $data;
{
    local $/ = undef;
    open my $fh, q(<:mmap), q(enwik8);
    $data = <$fh>;
    close $fh;
}

my $sfx = Text::SpeedyFx->new(1, 8);

cmpthese(10 => {
    hash        => sub { $sfx->hash($data) },
    hash_fv     => sub { $sfx->hash_fv($data, 1024) },
    hash_min    => sub { $sfx->hash_min($data) },
});
