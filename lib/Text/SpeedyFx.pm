package Text::SpeedyFx;
# ABSTRACT: SpeedyFx

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Text::SpeedyFx ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = (all => []);
our @EXPORT_OK = (@{$EXPORT_TAGS{all}});
our @EXPORT = qw();

# VERSION

require XSLoader;
XSLoader::load('Text::SpeedyFx', $VERSION);

1;
