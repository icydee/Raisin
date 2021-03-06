package Raisin::API;

use strict;
use warnings;

use parent 'Exporter';

use Carp;

use Raisin;
use Raisin::Entity;

my @APP_CONF_METHODS = qw(api_default_format api_format api_version middleware mount plugin);
my @APP_EXEC_METHODS = qw(new run);
my @APP_METHODS = qw(req res param session present error);
my @HOOKS_METHODS = qw(before before_validation after_validation after);
my @HTTP_METHODS = qw(del get head options patch post put);
my @ROUTES_METHODS = qw(resource namespace route_param params include_missing);

my @SWAGGER_MERTHODS = qw(desc summary tags);

our @EXPORT = (
    @APP_CONF_METHODS,
    @APP_EXEC_METHODS,
    @APP_METHODS,
    @HOOKS_METHODS,
    @HTTP_METHODS,
    @ROUTES_METHODS,
    @SWAGGER_MERTHODS,
);

my %SETTINGS = ();
my @NS = ('');

my $app;

sub import {
    my $class = shift;
    $class->export_to_level(1, @_);

    strict->import;
    warnings->import;

    my $caller = caller;
    $app ||= Raisin->new(caller => $caller);
}

sub app { $app }

#
# Execution
#
sub new { $app->run }
sub run { $app->run }

#
# Compile
#
sub mount { $app->mount_package(@_) }
sub middleware { $app->add_middleware(@_) }

#
# Hooks
#
sub before { $app->add_hook('before', shift) }
sub before_validation { $app->add_hook('before_validation', shift) }

sub after_validation { $app->add_hook('after_validation', shift) }
sub after { $app->add_hook('after', shift) }

#
# Resource
#
sub resource {
    my ($name, $code, %args) = @_;

    if ($name) {
        $name =~ s{^/}{}msx;
        push @NS, $name;

        if ($SETTINGS{desc}) {
            $app->resource_desc($NS[-1], delete $SETTINGS{desc});
        }

        my %prev_settings = %SETTINGS;
        @SETTINGS{ keys %args } = values %args;

        # Going deeper
        $code->();

        pop @NS;
        %SETTINGS = ();
        %SETTINGS = %prev_settings;
    }

    (join '/', @NS) || '/';
}
sub namespace { resource(@_) }

sub route_param {
    my ($param, $code) = @_;
    resource(":$param", $code, named => delete $SETTINGS{params});
}

#
# Actions
#
sub del     { _add_route('delete', @_) }
sub get     { _add_route('get', @_) }
sub head    { _add_route('head', @_) }
sub options { _add_route('options', @_) }
sub patch   { _add_route('patch', @_) }
sub post    { _add_route('post', @_) }
sub put     { _add_route('put', @_) }

sub params { $SETTINGS{params} = \@_ }

# Swagger
sub desc    { $SETTINGS{desc} = shift }
sub summary { $SETTINGS{summary} = shift }
sub tags    { $SETTINGS{tags} = \@_ }

sub _add_route {
    my @params = @_;

    my $code = pop @params;

    my ($method, $path) = @params;
    my $r = resource();
    if ($r eq '/' && $path) {
        $path = $r . $path;
    }
    else {
        $path = $r . ($path ? "/$path" : '');
    }

    $app->add_route(
        code    => $code,
        method  => $method,
        path    => $path,
        params  => delete $SETTINGS{params},

        desc    => delete $SETTINGS{desc},
        summary => delete $SETTINGS{summary},
        tags    => delete $SETTINGS{tags},

        %SETTINGS,
    );

    join '/', @NS;
}

#
# Request and Response shortcuts
#
sub req { $app->req }
sub res { $app->res }
sub param {
    my $name = shift;
    return $app->req->parameters->mixed->{$name} if $name;
    $app->req->parameters->mixed;
}
sub session { $app->session(@_) }

sub present {
    my ($key, $data, %params) = @_;

    my $entity = $params{with} || 'Raisin::Entity::Default';
    my $value = Raisin::Entity->compile($entity, $data);

    my $body = res->body || {};
    my $representation = { $key => $value, %$body };

    res->body($representation);

    return;
}

sub include_missing {
    my $p = shift;
    my %pp = map { $_->name, $p->{ $_->name } } @{ $app->req->{'raisin.declared'} };
    \%pp;
}

#
# System
#
sub plugin { $app->load_plugin(@_) }

sub api_default_format { $app->api_default_format(@_) }
sub api_format { $app->api_format(@_) }

# TODO:
# prepend a resource with a version number
# http://example.com/api/1
sub api_version { $app->api_version(@_) }

#
# Render
#
sub error { $app->res->render_error(@_) }

1;

__END__

=head1 NAME

Raisin::API - Provides Raisin DSL.

=head1 DESCRIPTION

See L<Raisin>.

=head1 AUTHOR

Artur Khabibullin - rtkh E<lt>atE<gt> cpan.org

=head1 LICENSE

This module and all the modules in this package are governed by the same license
as Perl itself.

=cut
