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

my $sfx_ascii   = Text::SpeedyFx->new(1, 8);
my $sfx         = Text::SpeedyFx->new(1);

cmpthese(10 => {
    hash            => sub { $sfx_ascii->hash($data) },
    hash_fv         => sub { $sfx_ascii->hash_fv($data, 10240) },
    hash_min        => sub { $sfx_ascii->hash_min($data) },
    hash_min_utf8   => sub { $sfx->hash_min($data) },
});
