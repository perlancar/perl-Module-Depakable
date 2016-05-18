package Module::Depakable;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter::Rinci qw(import);

our %SPEC;

$SPEC{module_depakable} = {
    v => 1.1,
    summary => 'Check whether a module (or modules) is (are) depakable',
    description => <<'_',

This routine tries to answer if a module is "depakable" (i.e. fatpackable or
datapackable). The module should be pure-perl and its recursive dependencies
must all be either core or pure-perl too. To check this, the module must be
installed because to guess if the module is pure-perl, `Module::XSOrPP` is used
and it requires analyzing the module's source code. Also, `lcpan` is required to
read the recursive dependencies.

_
    args => {
        modules => {
            schema => ['array*', of => 'str*', min_len=>1],
            req => 1,
            pos => 0,
            greedy => 1,
            'x.schema.element_entity' => 'modulename',
        },
    },
    examples => [
        {
            args => { modules=>[qw/Data::Sah WWW::PAUSE::Simple/] },
            test => 0,
            'x.doc.show_result' => 0,
        },
    ],
};
sub module_depakable {
    require App::lcpan::Call;
    require Module::XSOrPP;

    my %args = @_;

    my $mods = $args{modules};

    for my $mod (@$mods) {
        my $xs_or_pp;
        unless ($xs_or_pp = Module::XSOrPP::xs_or_pp($mod)) {
            return [500, "Can't determine whether '$mod' is XS/PP ".
                        "(probably not installed?)"];
        }
        unless ($xs_or_pp =~ /pp/) {
            return [500, "Module '$mod' is XS"];
        }
    }

    my $res = App::lcpan::Call::call_lcpan_script(argv=>[
        "deps",
        #"--phase", "runtime", "--rel", "requires", # the default
        "-R", "--with-xs-or-pp",
        @$mods]);
    return $res unless $res->[0] == 200;

    for my $entry (@{$res->[2]}) {
        my $mod = $entry->{module};
        $mod =~ s/^\s+//;
        next if $mod eq 'perl';
        if (!$entry->{xs_or_pp}) {
            return [500, "Prerequisite module '$mod' is not installed ".
                "or cannot be guessed whether it's XS/PP"];
        }
        if (!$entry->{is_core} && $entry->{xs_or_pp} !~ /pp/) {
            return [500, "Prerequisite module '$mod' is not PP nor core"];
        }
    }

    [200, "OK (all modules are depakable)"];
}

1;
# ABSTRACT:
