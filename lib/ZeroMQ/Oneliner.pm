package ZeroMQ::Oneliner;

use 5.006;
use strict;
use warnings FATAL => 'all';

BEGIN { $ENV{PERL_ZMQ_BACKEND} = 'ZMQ::LibZMQ2'; }

use URI;
use ZMQ;
use ZMQ::Message;
use ZMQ::Constants qw/:all/;

=head1 NAME

ZeroMQ::Oneliner - The great new ZeroMQ::Oneliner!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.02';

our $ZMQ_INFO = {
	"req"           => { type => ZMQ_REQ,       port_correction => 0 },
	"rep"           => { type => ZMQ_REP,       port_correction => 0 },
	"pub"           => { type => ZMQ_PUB,       port_correction => 0 },
	"sub"           => { type => ZMQ_SUB,       port_correction => 0 },
	"push"          => { type => ZMQ_PUSH,      port_correction => 0 },
	"pull"          => { type => ZMQ_PULL,      port_correction => 0 },
	
	"queue"         => { type => ZMQ_QUEUE,     left => "device-rep",  right => "device-req"   },
	"forwarder"     => { type => ZMQ_FORWARDER, left => "device-sub",  right => "device-pub"   },
	"streamer"      => { type => ZMQ_STREAMER,  left => "device-pull", right => "device-push"  },
	
	"device-req"    => { type => ZMQ_REQ,       port_correction => 2 },
	"device-rep"    => { type => ZMQ_REP,       port_correction => 1 },
	"device-pub"    => { type => ZMQ_PUB,       port_correction => 2 },
	"device-sub"    => { type => ZMQ_SUB,       port_correction => 1 },
	"device-push"   => { type => ZMQ_PUSH,      port_correction => 2 },
	"device-pull"   => { type => ZMQ_PULL,      port_correction => 1 },
	
	"queue-req"     => { type => ZMQ_REQ,       port_correction => 1 },
	"queue-rep"     => { type => ZMQ_REP,       port_correction => 2 },
	"forwarder-pub" => { type => ZMQ_PUB,       port_correction => 1 },
	"forwarder-sub" => { type => ZMQ_SUB,       port_correction => 2 },
	"streamer-push" => { type => ZMQ_PUSH,      port_correction => 1 },
	"streamer-pull" => { type => ZMQ_PULL,      port_correction => 2 },
};
our $ZMQ_SETSOCKOPT = {
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

my $CTX = ZMQ::Context->new(1);

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use ZeroMQ::Oneliner;

    my $foo = ZeroMQ::Oneliner->new("bind-tcp://*:6667/push?hwm=100");
    print $foo "send message";
    
    my $bar = ZeroMQ::Oneliner->new("connect-tcp://*:6667/pull");
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

sub PRINT {    my $self = shift; *$self->{socket}->send(@_); } 
sub READLINE { my $self = shift; my $msg = *$self->{socket}->recv(); $msg->data(); }
sub CLOSE {    my $self = shift; *$self->{socket}->close();      }

sub socket {
	my $self = shift;
	return *$self->{socket};
}

sub new {
	my ($class, $uri) = @_;
	
	my $uri_obj = URI->new($uri);
	my ($bindconnect, $proto) = ($uri_obj->scheme =~ /(bind|connect)-([^:]+)/);
	my ($zmq_host, $zmq_port) = split /:/, $uri_obj->authority;
	my $zmq_type      = $uri_obj->path; $zmq_type =~ s@^/@@;
	my $zmq_options   = { $uri_obj->query_form };
	
	my $info = $ZMQ_INFO->{$zmq_type};
	
	if($zmq_type ~~ [ "queue", "forwarder", "streamer" ]){
		my $sock1_uri = $uri_obj->clone;
		my $sock2_uri = $uri_obj->clone;
		$sock1_uri->path(sprintf("/%s", $info->{left}));
		$sock2_uri->path(sprintf("/%s", $info->{right}));
		my $sock1 = $class->new("".$sock1_uri);
		my $sock2 = $class->new("".$sock2_uri);
		
		ZMQ::call("zmq_device", $info->{type}, $sock1->socket()->{_socket}, $sock2->socket()->{_socket});
		exit;
	}else{
		my $socket = $CTX->socket($info->{type});
		
		my $zmq_address = sprintf("%s://%s:%s", 
			$proto,
			$zmq_host,
			$zmq_port + $info->{port_correction}
		);
		
		while(my ($k, $v) = each %$zmq_options){
			$v = int($v) if $v =~ /^\d+$/;
			
			$socket->setsockopt($ZMQ_SETSOCKOPT->{$k}, $v);
		}
		
		if($bindconnect eq "bind"){    $socket->bind($zmq_address);    }
		if($bindconnect eq "connect"){ $socket->connect($zmq_address); }
		
		my $self = bless \do { local *FH }, $class;
		tie *$self, $class, $self;
		*$self->{socket} = $socket;
		return $self;
	}
}

=head1 AUTHOR

x86, C<< <x86mail at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-zeromq-oneliner at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=ZeroMQ-Oneliner>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc ZeroMQ::Oneliner


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=ZeroMQ-Oneliner>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/ZeroMQ-Oneliner>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/ZeroMQ-Oneliner>

=item * Search CPAN

L<http://search.cpan.org/dist/ZeroMQ-Oneliner/>

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

1; # End of ZeroMQ::Oneliner
