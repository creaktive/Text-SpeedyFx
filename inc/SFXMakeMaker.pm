package inc::SFXMakeMaker;
use Moose;

extends q(Dist::Zilla::Plugin::MakeMaker::Awesome);

override _build_WriteMakefile_args => sub { +{
    %{ super() },
    OPTIMIZE => q(-Ofast),
} };

__PACKAGE__->meta->make_immutable;

1;
