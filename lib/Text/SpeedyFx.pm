package Text::SpeedyFx;
# ABSTRACT: Extremely Fast Text Feature Extraction for Classification and Indexing

use strict;
use utf8;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

#our %EXPORT_TAGS = (all => []);
#our @EXPORT_OK = (@{$EXPORT_TAGS{all}});
#our @EXPORT = qw();

# VERSION

require XSLoader;
XSLoader::load('Text::SpeedyFx', $VERSION);

1;
__END__

=head1 SYNOPSIS

    ...

=head1 DESCRIPTION

...

=head1 REFERENCES

=for :list
* L<Extremely Fast Text Feature Extraction for Classification and Indexing|http://www.hpl.hp.com/techreports/2008/HPL-2008-91R1.pdf> by L<George Forman|http://www.hpl.hp.com/personal/George_Forman/> and L<Evan Kirshenbaum|http://www.kirshenbaum.net/evan/index.htm>

=method new

...

=method hash

...

=method hash_fv

...

=cut
