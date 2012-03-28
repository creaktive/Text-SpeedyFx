use strict;
use utf8;
use warnings;

use Test::More tests => 1;

BEGIN {
    use_ok(q(Text::SpeedyFx));
};

diag(qq(Testing Text::SpeedyFx v$Text::SpeedyFx::VERSION, Perl $], $^X));
