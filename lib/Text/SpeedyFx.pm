package Text::SpeedyFx;
# ABSTRACT: tokenize/hash large amount of strings efficiently

use strict;
use utf8;
use warnings;

use base q(Exporter);

# VERSION

require XSLoader;
XSLoader::load('Text::SpeedyFx', $VERSION);

1;
__END__

=head1 SYNOPSIS

    use Data::Dumper;
    use Text::SpeedyFx;

    my $sfx = Text::SpeedyFx->new;

    my $words_bag = $sfx->hash('To be or not to be?');
    print Dumper $words_bag;
    #$VAR1 = {
    #          '1422534433' => '1',
    #          '4120516737' => '2',
    #          '1439817409' => '2',
    #          '3087870273' => '1'
    #        };

    my $feature_vector = $sfx->hash_fv("thats the question", 8);
    print unpack('b*', $feature_vector);
    # 01001000

=head1 DESCRIPTION

XS implementation of a very fast combined parser/hasher which works well on a variety of I<bag-of-word> problems.

L<Original implementation|http://www.hpl.hp.com/techreports/2008/HPL-2008-91R1.pdf> is in Java and was adapted for a better Unicode compliance.

=method new([$seed])

Initialize parser/hasher, optionally using a specified C<$seed> (default: 1).

=method hash($string)

Parses C<$string> and returns a hash reference where keys are the hashed tokens and values are their respective count.
Note that this is the slowest form due to the (computational) complexity of the Perl hash structure itself:
C<hash_fv()> is up to 400% faster, while C<hash_min()> is up to 420% faster.

=method hash_fv($string, $n)

Parses C<$string> and returns a feature vector (string of bits) with length C<$n>.
C<$n> is supposed to be a multiplier of 8, as the length of the resulting feature vector is C<ceil($n / 8)>.
See the included utilities L<cosine_sim> and L<uniq_wc>.

=method hash_min($string)

Parses C<$string> and returns the hash with the lowest value.
Useful in L<MinHash|http://en.wikipedia.org/wiki/MinHash> implementation.
See also the included L<minhash_cmp> utility.

=head1 BENCHMARK

The test platform configuration:

=for :list
* Intel® Core™ i7-2600 CPU @ 3.40GHz with 8 GB RAM;
* Ubuntu 11.10 (64-bit);
* Perl v5.16.2 (installed via L<perlbrew>);
* F<enwik8> from the L<Large Text Compression Benchmark|https://cs.fit.edu/~mmahoney/compression/text.html>.

                      Rate    hash hash_min_utf8  hash_fv  hash_min
    hash           18.9 MB/s    --          -66%     -80%      -81%
    hash_min_utf8  55.4 MB/s  193%            --     -41%      -44%
    hash_fv        94.1 MB/s  397%           70%       --       -4%
    hash_min       98.1 MB/s  419%           77%       4%        --

=head1 REFERENCES

=for :list
* L<Extremely Fast Text Feature Extraction for Classification and Indexing|http://www.hpl.hp.com/techreports/2008/HPL-2008-91R1.pdf> by L<George Forman|http://www.hpl.hp.com/personal/George_Forman/> and L<Evan Kirshenbaum|http://www.kirshenbaum.net/evan/index.htm>
* L<MinHash — выявляем похожие множества|http://habrahabr.ru/post/115147/>
* L<Фильтр Блума|http://habrahabr.ru/post/112069/>

=cut
