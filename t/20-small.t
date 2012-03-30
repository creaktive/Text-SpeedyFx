use strict;
use utf8;
use warnings;

use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use Test::More;

use Text::SpeedyFx;

my $sfx = Text::SpeedyFx->new(42);

my $str = q(
    À noite, vovô Kowalsky vê o ímã cair no pé do pingüim
    queixoso e vovó põe açúcar no chá de tâmaras do jabuti feliz.
);
my $r = $sfx->hash($str);
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
    qq(same # of tokens ($n))
);

my $err = 0;
ok(
    $r->{$_} == $expect->{$_},
    qq(key $_ match)
) or ++$err for keys %$expect;

$Data::Dumper::Sortkeys = sub { [ sort { $a <=> $b } keys %{$_[0]} ] };
$err and diag(Dumper $r);

$r = $sfx->hash_fv($str, 16);
isa_ok($r, q(ARRAY));

ok(
    scalar @$r == 16,
    qq(same feature vector length (@{[ scalar @$r ]}))
);

ok(
    join('', @$r) eq q(0110001001111011),
    q(feature vector match)
);

$r = $sfx->hash_min($str);
ok(
    looks_like_number($r),
    qq(hash_min is number ($r))
);

ok(
    $r == 106041279,
    qq(hash_min match ($r))
);

done_testing(7 + $n);
