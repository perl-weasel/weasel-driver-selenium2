
=head1 NAME

Weasel::Driver::Selenium2 - Weasel driver wrapping Selenium::Remote::Driver

=head1 VERSION

0.01

=head1 SYNOPSIS

  use Weasel;
  use Weasel::Session;
  use Weasel::Driver::Selenium2;

  my %opts = (
    wait_timeout => 3000,    # 3000 msec == 3s
    window_size => '1024x1280',
    caps => {
      port => 4443,
      # ... and other Selenium::Remote::Driver capabilities options
    },
  );
  my $weasel = Weasel->new(
       default_session => 'default',
       sessions => {
          default => Weasel::Session->new(
            driver => Weasel::Driver::Selenium2->new(%opts),
          ),
       });

  $weasel->session->get('http://localhost/index');


=head1 DESCRIPTION

This module implements the C<Weasel::DriverRole> protocol, wrapping
Selenium::Remote::Driver.

=cut

package Weasel::Driver::Selenium2;

use strict;
use warnings;

use Moose;
use Selenium::Remote::Driver;
use Selenium::Waiter;
use Weasel::DriverRole;

with 'Weasel::DriverRole';

=head1 ATTRIBUTES

=over

=item _driver

Internal. Holds the reference to the C<Selenium::Remote::Driver> instance.

=cut

has '_driver' => (is => 'rw',
                 isa => 'Selenium::Remote::Driver',
                 );

=item wait_timeout

The number of miliseconds to wait before failing to find a tag
or completing a wait condition, turns into an error.

Change by calling C<set_wait_timeout>.

=cut


has 'wait_timeout' => (is => 'rw',
                       writer => '_set_wait_timeout',
                       isa => 'Int',
                       );

=item window_size

String holding '<height>x<width>', the window size to be used. E.g., to
set the window size to 1280(wide) by 1024(high), set to: '1024x1280'.

Change by calling C<set_window_size>.

=cut

has 'window_size' => (is => 'rw',
                      writer => '_set_window_size',
                      );

=item caps

Capabilities to be passed to the Selenium::Remote::Driver constructor
when C<start> is being called.  Changes won't take effect until the
session is stopped and started or restarted.

=cut

has 'caps' => (is => 'ro',
               isa => 'HashRef',
               required => 1);

=back

=head1 IMPLEMENTATION OF Weasel::DriverRole

=over

=item implements

=cut

sub implements {
    return '0.01';
}

=item start

=cut

sub start {
    my $self = shift;
    my $driver = Selenium::Remote::Driver->new(%{$self->caps});

    $self->_driver($driver);
    $self->set_wait_timeout($self->wait_timeout);
    $self->set_window_size($self->window_size);
    $self->started(1);
}

=item stop

=cut

sub stop {
    my $self = shift;
    my $driver = $self->_driver;

    $driver->quit if defined $driver;
    $self->started(0);
}

=item find_all

=cut

sub find_all {
    my ($self, $parent_id, $locator, $scheme) = @_;
    # $parent_id is either a string containing an xpath
    #   or a native Selenium::Remote::WebElement
    $parent_id = $self->_resolve_id($parent_id);

    return $self->_driver->find_child_elements($parent_id, $locator, $scheme);
}

=item get

=cut

sub get {
    my ($self, $url) = @_;

    $self->_driver->get($url);
}

=item wait_for

=cut

sub wait_for {
    my ($self, $callback) = @_;

    Selenium::Waiter::wait_until { $callback->() };
}

=item click

=cut

sub click {
    my ($self, $element_id) = @_;

    if (defined $element_id) {
        $self->_scroll($self->_resolve_id($element_id))->click;
    }
    else {
        $self->_driver->click;
    }
}

=item dblclick

=cut

sub dblclick {
    my ($self) = @_;

    $self->_driver->dblclick;
}

=item get_attribute($id, $att_name)

=cut

sub get_attribute {
    my ($self, $id, $att) = @_;

    return $self->_resolve_id($id)->get_attribute($att);
}

=item set_attribute($id, $att_name, $value)

=cut

sub set_attribute {
    my ($self, $id, $att, $value) = @_;

    $self->_resolve_id($id)->set_attribute($att, $value);
}

=item get_selected($id)

=cut

sub get_selected {
    my ($self, $id) = @_;

    return $self->_resolve_id($id)->get_selected;
}

=item set_selected($id, $value)

=cut

sub set_selected {
    my ($self, $id, $value) = @_;

    # Note: we're using a deprecated method here, but...
    # as long as it's there... why not?
    # The other solution is to use is_selected to verify the current state
    # and toggling by click()ing
    $self->_resolve_id($id)->set_selected($value);
}


=back

=head1 METHODS

This module implements the following methods in addition to the
Weasel::DriverRole protocol methods:

=over

=item set_wait_timeout

Sets the C<wait_timeut> attribute of the object as well as
of the Selenium::Remote::Driver object, if a session has been
started.

=cut

sub set_wait_timeout {
    my ($self, $value) = @_;
    my $driver = $self->_driver;

    $driver->set_implicit_wait_timeout($value)
        if defined $driver;
    $self->_set_wait_timeout($value);
}

=item set_window_size

Sets the C<window_size> attribute of the object as well as the
window size of the currently active window of the Selenium::Remote::Driver
object, if a session has been started.

=cut

sub set_window_size {
    my ($self, $value) = @_;
    my $driver = $self->_driver;

    $driver->set_window_size(split /x/, $value)
        if defined $driver;
    $self->_set_window_size($value);
}

=back

=cut

# PRIVATE IMPLEMENTATIONS


sub _resolve_id {
    my ($self, $id) = @_;

    return (ref $id) ? $id :
        (shift @{ $self->_driver->find_elements($id,'xpath') });
}

sub _scroll {
    my ($self, $id) = @_;

    $self->_driver->execute_script('arguments[0].scrollIntoView(true);',
                                   $id);
    return $id;
}

=head1 CONTRIBUTORS

Erik Huelsmann

=head1 MAINTAINERS

Erik Huelsmann

=head1 BUGS

Bugs can be filed in the GitHub issue tracker for the Weasel project:
 https://github.com/perl-weasel/weasel-driver-selenium2/issues

=head1 SOURCE

The source code repository for Weasel is at
 https://github.com/perl-weasel/weasel-driver-selenium2

=head1 SUPPORT

Community support is available through
L<perl-weasel@googlegroups.com|mailto:perl-weasel@googlegroups.com>.

=head1 COPYRIGHT

 (C) 2016  Erik Huelsmann

Licensed under the same terms as Perl.

=cut

1;
