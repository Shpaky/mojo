package Mojolicious::Commands;
use Mojo::Base 'Mojolicious::Command';

use Getopt::Long 'GetOptions';
use Mojo::Server;
use Mojo::Util 'tablify';

has hint => <<EOF;

See 'APPLICATION help COMMAND' for more information on a specific command.
EOF
has message    => sub { shift->extract_usage . "\nCommands:\n" };
has namespaces => sub { ['Mojolicious::Command'] };

sub detect {
  my ($self, $guess) = @_;

  # PSGI (Plack only for now)
  return 'psgi' if defined $ENV{PLACK_ENV};

  # CGI
  return 'cgi' if defined $ENV{PATH_INFO} || defined $ENV{GATEWAY_INTERFACE};

  # Nothing
  return $guess;
}

# Command line options for MOJO_HELP, MOJO_HOME and MOJO_MODE
BEGIN {
  Getopt::Long::Configure(qw(no_auto_abbrev no_ignore_case pass_through));
  GetOptions(
    'h|help'   => sub { $ENV{MOJO_HELP} = 1 },
    'home=s'   => sub { $ENV{MOJO_HOME} = $_[1] },
    'm|mode=s' => sub { $ENV{MOJO_MODE} = $_[1] }
  ) unless __PACKAGE__->detect;
  Getopt::Long::Configure('default');
}

sub run {
  my ($self, $name, @args) = @_;

  # Application loader
  return $self->app if defined $ENV{MOJO_APP_LOADER};

  # Try to detect environment
  $name = $self->detect($name) unless $ENV{MOJO_NO_DETECT};

  # Run command
  if ($name && $name =~ /^\w+$/ && ($name ne 'help' || $args[0])) {

    # Help
    $name = shift @args if my $help = $name eq 'help';
    $help = $ENV{MOJO_HELP} = $ENV{MOJO_HELP} ? 1 : $help;

    my $module;
    $module = _command("${_}::$name", 1) and last for @{$self->namespaces};

    # Unknown command
    die qq{Unknown command "$name", maybe you need to install it?\n}
      unless $module;

    # Run command
    my $command = $module->new(app => $self->app);
    return $help ? $command->help(@args) : $command->run(@args);
  }

  # Hide list for tests
  return 1 if $ENV{HARNESS_ACTIVE};

  # Find all available commands
  my (@commands, %seen);
  my $loader = Mojo::Loader->new;
  for my $ns (@{$self->namespaces}) {
    for my $module (@{$loader->search($ns)}) {
      next unless my $command = _command($module);
      $command =~ s/^${ns}:://;
      push @commands, [$command => $module] unless $seen{$command}++;
    }
  }

  # Print list of all available commands
  my $rows = [];
  push @$rows, [' ' . $_->[0], $_->[1]->new->description]
    for sort { $a->[0] cmp $b->[0] } @commands;
  return print $self->message, tablify($rows), $self->hint;
}

sub start_app {
  my $self = shift;
  return Mojo::Server->new->build_app(shift)->start(@_);
}

sub _command {
  my ($module, $fatal) = @_;
  return $module->isa('Mojolicious::Command') ? $module : undef
    unless my $e = Mojo::Loader->new->load($module);
  $fatal && ref $e ? die $e : return undef;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Commands - Command line interface

=head1 SYNOPSIS

  Usage: APPLICATION COMMAND [OPTIONS]

  Tip: CGI and PSGI environments can be automatically detected very often and
       work without commands.

  Options (for all commands):
    -h, --help          Get more information on a specific command.
        --home <path>   Path to your applications home directory, defaults to
                        the value of MOJO_HOME or auto detection.
    -m, --mode <name>   Operating mode for your application, defaults to the
                        value of MOJO_MODE/PLACK_ENV or "development".

=head1 DESCRIPTION

L<Mojolicious::Commands> is the interactive command line interface for the
L<Mojolicious> framework. It will automatically detect available commands in
the C<Mojolicious::Command> namespace.

=head1 COMMANDS

These commands are available by default.

=head2 cgi

  $ ./myapp.pl cgi

Use L<Mojolicious::Command::cgi> to start application with CGI backend,
usually auto detected.

=head2 cpanify

  $ mojo cpanify -u sri -p secr3t Mojolicious-Plugin-Fun-0.1.tar.gz

Use L<Mojolicious::Command::cpanify> for uploading files to CPAN.

=head2 daemon

  $ ./myapp.pl daemon

Use L<Mojolicious::Command::daemon> to start application with standalone HTTP
and WebSocket server.

=head2 eval

  $ ./myapp.pl eval 'say app->home'

Use L<Mojolicious::Command::eval> to run code against application.

=head2 generate

  $ mojo generate
  $ mojo generate help
  $ ./myapp.pl generate help

List available generator commands with short descriptions.

  $ mojo generate help <generator>
  $ ./myapp.pl generate help <generator>

List available options for generator command with short descriptions.

=head2 generate app

  $ mojo generate app <AppName>

Use L<Mojolicious::Command::generate::app> to generate application directory
structure for a fully functional L<Mojolicious> application.

=head2 generate lite_app

  $ mojo generate lite_app

Use L<Mojolicious::Command::generate::lite_app> to generate a fully functional
L<Mojolicious::Lite> application.

=head2 generate makefile

  $ mojo generate makefile
  $ ./myapp.pl generate makefile

Use L<Mojolicious::Command::generate::makefile> to generate C<Makefile.PL>
file for application.

=head2 generate plugin

  $ mojo generate plugin <PluginName>

Use L<Mojolicious::Command::generate::plugin> to generate directory structure
for a fully functional L<Mojolicious> plugin.

=head2 get

  $ mojo get http://mojolicio.us
  $ ./myapp.pl get /foo

Use L<Mojolicious::Command::get> to perform requests to remote host or local
application.

=head2 help

  $ mojo
  $ mojo help
  $ ./myapp.pl help

List available commands with short descriptions.

  $ mojo help <command>
  $ ./myapp.pl help <command>

List available options for the command with short descriptions.

=head2 inflate

  $ ./myapp.pl inflate

Use L<Mojolicious::Command::inflate> to turn templates and static files
embedded in the C<DATA> sections of your application into real files.

=head2 prefork

  $ ./myapp.pl prefork

Use L<Mojolicious::Command::prefork> to start application with standalone
preforking HTTP and WebSocket server.

=head2 psgi

  $ ./myapp.pl psgi

Use L<Mojolicious::Command::psgi> to start application with PSGI backend,
usually auto detected.

=head2 routes

  $ ./myapp.pl routes

Use L<Mojolicious::Command::routes> to list application routes.

=head2 test

  $ ./myapp.pl test
  $ ./myapp.pl test t/fun.t

Use L<Mojolicious::Command::test> to run application tests from the C<t>
directory.

=head2 version

  $ mojo version
  $ ./myapp.pl version

Use L<Mojolicious::Command::version> to show version information for installed
core and optional modules, very useful for debugging.

=head1 ATTRIBUTES

L<Mojolicious::Commands> inherits all attributes from L<Mojolicious::Command>
and implements the following new ones.

=head2 hint

  my $hint  = $commands->hint;
  $commands = $commands->hint('Foo!');

Short hint shown after listing available commands.

=head2 message

  my $msg   = $commands->message;
  $commands = $commands->message('Hello World!');

Short usage message shown before listing available commands.

=head2 namespaces

  my $namespaces = $commands->namespaces;
  $commands      = $commands->namespaces(['MyApp::Command']);

Namespaces to load commands from, defaults to C<Mojolicious::Command>.

  # Add another namespace to load commands from
  push @{$commands->namespaces}, 'MyApp::Command';

=head1 METHODS

L<Mojolicious::Commands> inherits all methods from L<Mojolicious::Command> and
implements the following new ones.

=head2 detect

  my $env = $commands->detect;
  my $env = $commands->detect($guess);

Try to detect environment.

=head2 run

  $commands->run;
  $commands->run(@ARGV);

Load and run commands. Automatic deployment environment detection can be
disabled with the MOJO_NO_DETECT environment variable.

=head2 start_app

  Mojolicious::Commands->start_app('MyApp');
  Mojolicious::Commands->start_app(MyApp => @ARGV);

Load application and start the command line interface for it.

  # Always start daemon for application and ignore @ARGV
  Mojolicious::Commands->start_app('MyApp', 'daemon', '-l', 'http://*:8080');

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
