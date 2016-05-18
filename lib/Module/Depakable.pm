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

This routine tries to determine if a module is "depakable" (i.e. fatpackable or
datapackable). That means, the module is pure-perl and its recursive
dependencies are all either core or pure-perl too.

When all the modules that a script requires are depakable, and after the script
is packed with its modules (and their recursive non-core dependencies), running
the script will only require core modules and the script can be deployed into a
fresh perl installation.

On the other hand, if a module is not depakable, that means the module itself is
XS, or one of its recursive dependencies is non-core XS. You cannot then
fatpack/datapack the module.

To check whether a module is depakable, the module must be installed (because to
guess if the module is pure-perl, `Module::XSOrPP` is used and it requires
analyzing the module's source code). Also, `lcpan` must be required to provide
the recursive dependencies information.

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
