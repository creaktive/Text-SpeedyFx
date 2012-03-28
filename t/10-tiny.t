use strict;
use utf8;
use warnings;

use Test::More;

use_ok(q(Text::SpeedyFx));

my $sfx = Text::SpeedyFx->new(42);
isa_ok($sfx, qw(Text::SpeedyFx));
can_ok($sfx, qw(hash));

my $r = $sfx->hash(q(
    À noite, vovô Kowalsky vê o ímã cair no pé do pingüim
    queixoso e vovó põe açúcar no chá de tâmaras do jabuti feliz.
));
isa_ok($r, q(HASH));

my $expect = {
    106041279   => 2,
    446277518   => 1,
    567119914   => 1,
    692962479   => 1,
    1060523967  => 1,
    1068328043  => 1,
    1310293311  => 2,
    1481219519  => 1,
    1707943522  => 1,
    1752231868  => 1,
    1779264938  => 1,
    2172581055  => 1,
    2193894889  => 1,
    2765318993  => 1,
    2793878206  => 1,
    2931454150  => 1,
    2963223177  => 1,
    3114580310  => 1,
    3337863185  => 1,
    3980716046  => 1,
    4007692458  => 1,
    4068256105  => 1,
};
my $n = scalar keys %$expect;

ok(
    scalar keys %$r == $n,
    q(same # of tokens)
);

ok(
    $r->{$_} == $expect->{$_},
    qq(key $_ match)
) for keys %$expect;

done_testing(5 + $n);
