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

ZeroMQ::Oneliner - Create ZMQ sockets using URI as description

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

our $ZMQ_INFO = {
	"req"           => { type => ZMQ_REQ,       port_correction => 0, default_direction => "connect", default_port => 1040, },
	"rep"           => { type => ZMQ_REP,       port_correction => 0, default_direction => "bind",    default_port => 1040, },
	"pub"           => { type => ZMQ_PUB,       port_correction => 0, default_direction => "connect", default_port => 1041, },
	"sub"           => { type => ZMQ_SUB,       port_correction => 0, default_direction => "bind",    default_port => 1041, },
	"push"          => { type => ZMQ_PUSH,      port_correction => 0, default_direction => "connect", default_port => 1042, },
	"pull"          => { type => ZMQ_PULL,      port_correction => 0, default_direction => "bind",    default_port => 1042, },
	
	"queue"         => { type => ZMQ_QUEUE,     left => "_device-rep",  right => "_device-req",  },
	"forwarder"     => { type => ZMQ_FORWARDER, left => "_device-sub",  right => "_device-pub",  },
	"streamer"      => { type => ZMQ_STREAMER,  left => "_device-pull", right => "_device-push", },
	
	"_device-req"   => { type => ZMQ_REQ,       port_correction => 2, default_direction => "bind",    default_port => 1043, },
	"_device-rep"   => { type => ZMQ_REP,       port_correction => 1, default_direction => "bind",    default_port => 1043, },
	"_device-pub"   => { type => ZMQ_PUB,       port_correction => 2, default_direction => "bind",    default_port => 1046, },
	"_device-sub"   => { type => ZMQ_SUB,       port_correction => 1, default_direction => "bind",    default_port => 1046, },
	"_device-push"  => { type => ZMQ_PUSH,      port_correction => 2, default_direction => "bind",    default_port => 1049, },
	"_device-pull"  => { type => ZMQ_PULL,      port_correction => 1, default_direction => "bind",    default_port => 1049, },
	
	"queue-req"     => { type => ZMQ_REQ,       port_correction => 1, default_direction => "connect", default_port => 1043, },
	"queue-rep"     => { type => ZMQ_REP,       port_correction => 2, default_direction => "connect", default_port => 1043, },
	"forwarder-pub" => { type => ZMQ_PUB,       port_correction => 1, default_direction => "connect", default_port => 1046, },
	"forwarder-sub" => { type => ZMQ_SUB,       port_correction => 2, default_direction => "connect", default_port => 1046, },
	"streamer-push" => { type => ZMQ_PUSH,      port_correction => 1, default_direction => "connect", default_port => 1049, },
	"streamer-pull" => { type => ZMQ_PULL,      port_correction => 2, default_direction => "connect", default_port => 1049, },
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

=head1 SUPPORTED URLS

    bind-tcp://127.0.0.1:6667/push?hwm=100
    connect-tcp://127.0.0.1:6667/pull
    tcp://127.0.0.1:6777/push
    tcp://127.0.0.1/push
    push
    tcp://127.0.0.1/streamer
    tcp://127.0.0.1/streamer-push
    tcp://127.0.0.1/streamer-pull
    ...


=cut

sub TIEHANDLE {
    (
        ( defined( $_[1] ) && UNIVERSAL::isa( $_[1], __PACKAGE__ ) )
        ? $_[1]
        : shift->new(@_)
    );	
}
sub PRINT {    shift->send(@_); } 
sub READLINE { shift->recv(@_); }
sub CLOSE {    shift->close(@_); }


sub socket { my $self = shift; return *$self->{socket}; }
sub send   { my $self = shift; *$self->{socket}->send(@_); }
sub recv   { my $self = shift; my $msg = *$self->{socket}->recv(); $msg->data(); }
sub close  { my $self = shift; *$self->{socket}->close(); }


sub new {
	my ($class, $uri) = @_;
	
	my $uri_obj = URI->new($uri);
	my ($direction, $proto) = ( ($uri_obj->scheme || "") =~ /(?:(bind|connect)-)?([^:]+)/i);
	my ($zmq_host, $zmq_port) = split /:/, ($uri_obj->authority || "");
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
		
		$direction ||= $info->{default_direction};
		$proto     ||= "tcp";
		$zmq_host  ||= "127.0.0.1";
		$zmq_port  ||= $info->{default_port};
		
		my $zmq_address = sprintf("%s://%s:%s", 
			$proto,
			$zmq_host,
			$zmq_port + $info->{port_correction}
		);
		
		while(my ($k, $v) = each %$zmq_options){
			$v = int($v) if $v =~ /^\d+$/;
			
			$socket->setsockopt($ZMQ_SETSOCKOPT->{$k}, $v);
		}
		
		if($direction eq "bind"){    $socket->bind($zmq_address);    }
		if($direction eq "connect"){ $socket->connect($zmq_address); }
		
		my $self = bless \do { local *FH }, $class;
		tie *$self, $class, $self;
		*$self->{socket} = $socket;
		return $self;
	}
}

sub available_sockets {
	return 
		grep { not /^_/ }
		keys %$ZMQ_INFO;
}

sub available_options {
	return
		keys %$ZMQ_SETSOCKOPT;
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
