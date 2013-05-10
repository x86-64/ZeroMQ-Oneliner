package ZeroMQ::Oneliner::LibZMQ2;

use 5.006;
use strict;
use warnings FATAL => 'all';
use ZMQ;
use ZMQ::Constants qw/:all/;

=head1 NAME

ZeroMQ::Oneliner::LibZMQ2 - The great new ZeroMQ::Oneliner::LibZMQ2!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

our $types = {
	"push" => ZMQ_PUSH,
	"pull" => ZMQ_PULL,
	"req"  => ZMQ_REQ,
	"rep"  => ZMQ_REP,
	"pub"  => ZMQ_PUB,
	"sub"  => ZMQ_SUB,
};
our $opts = {
	"hwm"         => ZMQ_HWM,
	"swap"        => ZMQ_SWAP,
	"identity"    => ZMQ_IDENTITY,
	"subscribe"   => ZMQ_SUBSCRIBE,
	"rate"        => ZMQ_RATE,
	"recovery"    => ZMQ_RECOVERY_IVL,
	"sndbuf"      => ZMQ_SNDBUF,
	"rcvbuf"      => ZMQ_RCVBUF,
	"linger"      => ZMQ_LINGER,
	"reconnect"   => ZMQ_RECONNECT_IVL,
	"backlog"     => ZMQ_BACKLOG,
};

my $ctx = ZMQ::Context->new(1);

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use ZeroMQ::Oneliner::LibZMQ2;

    my $foo = ZeroMQ::Oneliner::LibZMQ2->new("bind-tcp://*:6667/push?hwm=100");
    print $foo "send message";
    
    my $bar = ZeroMQ::Oneliner::LibZMQ2->new("connect-tcp://*:6667/pull");
    print <$bar>; # recv message

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

sub TIEHANDLE {
    (
        ( defined( $_[1] ) && UNIVERSAL::isa( $_[1], __PACKAGE__ ) )
        ? $_[1]
        : shift->new(@_)
    );	
}

sub PRINT {    my $self = shift; *$self->{socket}->send(@_);      } 
sub READLINE { my $self = shift; my $msg = *$self->{socket}->recv(); $msg->data(); }
sub CLOSE {    my $self = shift; *$self->{socket}->close();      }

sub socket {
	my $self = shift;
	return *$self->{socket};
}

sub type {
	my $self = shift;
	return *$self->{type};
}

sub new {
	my ($class, $name) = @_;
	
	my $self = bless \do { local *FH }, $class;
	tie *$self, $class, $self;
	
	my ($socket);
	
	if($name =~ m@(bind|connect)-((?:inproc|ipc|tcp|pgm|epgm)://[[:alnum:].*]+:[0-9]+)/(re[qp]|push|pull|[ps]ub)[?]?([[:alnum:]=&]+)?@i){
		my ($bc, $zmq_address, $s_type, $s_options) = ($1, $2, $3, $4);
		
		*$self->{type} = $s_type;
		$socket = $ctx->socket($types->{$s_type});
		
		if($s_options){
			foreach my $option (split /&/, $s_options){
				my ($k, $v) = split /=/, $option;
				
				$k = $opts->{$k};
				$v = int($v) if $v =~ /^\d+$/;
				
				$socket->setsockopt($k, $v);
			}
		}
		
		if($bc eq "bind"){    $socket->bind($zmq_address);    }
		if($bc eq "connect"){ $socket->connect($zmq_address); }
		
		*$self->{socket} = $socket;
	}
	return $self;
}

sub new_device {
	my ($class, $sock1, $sock2) = @_;
	
	my $type;
	if($sock1->type() eq "rep" and $sock2->type() eq "req"){
		$type = ZMQ_QUEUE;
	}elsif($sock1->type() eq "sub" and $sock2->type() eq "pub"){
		$type = ZMQ_FORWARDER;
	}elsif($sock1->type() eq "pull" and $sock2->type() eq "push"){
		$type = ZMQ_STREAMER;
	}
	ZMQ::call("zmq_device", $type, $sock1->socket()->{_socket}, $sock2->socket()->{_socket});
}

=head1 AUTHOR

x86, C<< <x86mail at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-zeromq-oneliner at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=ZeroMQ-Oneliner::LibZMQ2>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc ZeroMQ::Oneliner::LibZMQ2


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=ZeroMQ-Oneliner::LibZMQ2>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/ZeroMQ-Oneliner::LibZMQ2>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/ZeroMQ-Oneliner::LibZMQ2>

=item * Search CPAN

L<http://search.cpan.org/dist/ZeroMQ-Oneliner::LibZMQ2/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 x86.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this program.  If not, see
L<http://www.gnu.org/licenses/>.


=cut

1; # End of ZeroMQ::Oneliner::LibZMQ2