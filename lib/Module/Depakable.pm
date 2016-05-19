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

This routine tries to determine whether the module(s) you specify, when use-d by
a script, won't impair the ability to depak the script so that the script can
run with requiring only core perl modules installed. The word "depak-able"
(depak) comes from the name of the application that can pack a script using
fatpack/datapack technique.

Let's start with the aforementioned goal: making a script run with only
requiring core perl modules installed. All the other modules that the script
might use are packed along inside the script using fatpack (put inside a hash
variable) or datapack (put in the DATA section) technique. But XS modules cannot
be packed using this technique. And therefore, a module that requires non-core
XS modules (either directly or indirectly) also cannot be used.

So in other words, this routine checks that a module is PP (pure-perl) *and* all
of its (direct and indirect) dependencies are PP or core.

To check whether a module is PP/XS, `Module::XSOrPP` is used and this requires
that the module is installed because `Module::XSOrPP` guesses by analyzing the
module's source code.

To list all direct and indirect dependencies of a module, `lcpan` is used, so
that application must be installed and run first to download and index a local
CPAN/CPAN-like repository.

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
    require Module::CoreList::More;
    require Module::XSOrPP;

    my %args = @_;

    my $mods = $args{modules};

    for my $mod (@$mods) {
        my $xs_or_pp;
        unless ($xs_or_pp = Module::XSOrPP::xs_or_pp($mod)) {
            return [500, "Can't determine whether '$mod' is XS/PP ".
                        "(probably not installed?)"];
        }
        if ($args{_is_prereqs}) {
            unless ($xs_or_pp =~ /pp/ ||
                        Module::CoreList::More->is_still_core($mod)) {
            return [500, "Prerequisite '$mod' is not PP nor core"];
            }
        } else {
            unless ($xs_or_pp =~ /pp/) {
                return [500, "Module '$mod' is XS"];
            }
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
            return [500, "Prerequisite '$mod' is not installed ".
                "or cannot be guessed whether it's XS/PP"];
        }
        if (!$entry->{is_core} && $entry->{xs_or_pp} !~ /pp/) {
            return [500, "Prerequisite '$mod' is not PP nor core"];
        }
    }

    [200, "OK (all modules are depakable)"];
}

$SPEC{prereq_depakable} = {
    v => 1.1,
    summary => 'Check whether prereq (and their recursive prereqs) '.
        'are depakable',
    description => <<'_',

This routine is exactly like `module_depakable` except it allows the prereq(s)
themselves to be core XS, while `module_depakable` requires the modules
themselves be pure-perl.

_
    args => {
        prereqs => {
            schema => ['array*', of => 'str*', min_len=>1],
            req => 1,
            pos => 0,
            greedy => 1,
            'x.schema.element_entity' => 'modulename',
        },
    },
};
sub prereq_depakable {
    my %args = @_;
    module_depakable(modules => $args{prereqs}, _is_prereqs=>1);
}

1;
# ABSTRACT:

=head1 SEE ALSO

L<App::depak>

L<depakable>, CLI for this module.
