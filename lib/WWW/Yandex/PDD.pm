package WWW::Yandex::PDD;

use strict;
use warnings;

use LWP::UserAgent; # also required: Crypt::SSLeay or IO::Socket::SSL
use LWP::ConnCache;
use XML::LibXML;
use XML::LibXML::XPathContext; # explicit use is required in some cases

use Yandex::API::PDD::Error;

use constant API_URL => 'https://pddimp.yandex.ru/';

sub new
{
	my $class = shift;
	my %data  = @_;

	my $self = {};

	bless $self, $class;

	return undef unless $self -> __init(\%data);

	return $self;
}

sub __init
{
	my $self = shift;
	my $data = shift;

	return undef unless $data;
	return undef unless $data -> {token};

	$self -> {token}  = $data -> {token};

	$ENV{HTTPS_CA_FILE} = $data -> {cert_file} if ($data -> {cert_file});

	$self -> {ua} = new LWP::UserAgent;
	$self -> {ua} -> conn_cache(new LWP::ConnCache);

	$self -> {parser} = new XML::LibXML;
	$self -> {xpath}  = new XML::LibXML::XPathContext;

	return 1;
}

sub __reset_error
{
	my $self = shift;

	$self -> {error}      = undef;
	$self -> {http_error} = undef;
}

sub __set_error
{
	my $self = shift;

	my ($code, $info, $is_http) = @_;

	$self -> __reset_error();

	if ($is_http)
	{
		$self -> {error}      = { code => &Yandex::API::PDD::Error::HTTP_ERROR };
		$self -> {http_error} = { code => $code, info => $info };
	}
	else
	{
		$self -> {error}      = { code => $code, info => $info };
	}
}

sub __handle_error
{
	my $self = shift;

	$self -> __set_error( Yandex::API::PDD::Error::identify( $self -> {_error} ), $self -> {_error} );
}

sub __handle_http_error
{
	my $self = shift;

	$self -> __set_error( $self -> {r} -> code(),
			      $self -> {r} -> decoded_content(),
			      &Yandex::API::PDD::Error::HTTP_ERROR
	);
}

sub __unknown_error
{
	my $self = shift;

	$self -> __set_error( &Yandex::API::PDD::Error::UNKNOWN_ERROR,
			      $self -> {r} -> decoded_content()
	);

	return undef;
}

sub __get_nodelist
{
	my $self  = shift;
	my $xpath = shift;
	my $xml   = shift || $self -> {xml};

	return '' unless ($xpath and $xml); # TODO die

	return $self -> {xpath} -> findnodes($xpath, $xml);
}

sub __get_node_text
{
	my $self  = shift;
	my $xpath = shift;
	my $xml   = shift || $self -> {xml};

	return '' unless ($xpath and $xml); # TODO die

	return $self -> {xpath} -> findvalue($xpath, $xml);
}

sub __parse_response
{
	my $self = shift;

	my $xml;

	eval
	{
		$xml = $self -> {parser} -> parse_string( $self -> {r} -> decoded_content() );
	};

	if ($@)
	{
		$self -> __set_error(&Yandex::API::PDD::Error::INVALID_RESPONSE);
		return undef;
	}

	unless ($xml)
	{
		$self -> __set_error(&Yandex::API::PDD::Error::INVALID_RESPONSE);
		return undef;
	}

	$self -> {xml} = $xml;

	if ( $self -> {_error} = $self -> __get_node_text('/page/error/@reason') )
	{
		$self -> __handle_error();
		return undef;
	}

	if ( $self -> __get_node_text('/page/xscript_invoke_failed/@error') )
	{
		my $info = '';

		for ( qw{ error block method object exception } )
		{
			my $s = '/page/xscript_invoke_failed/@' . $_;

			$info .= $_ . ': "' . $self -> __get_node_text($s) . '" ';
		}

		$self -> __set_error(&Yandex::API::PDD::Error::SERVICE_ERROR, $info);
		return undef;
	}

	return 1 unless ( $self -> {_error} );
}

sub __make_request
{
	my $self = shift;
	my $url  = shift;

	$self -> __reset_error();

	$self -> {r} = $self -> {ua} -> get($url);

	unless ($self -> {r} -> is_success)
	{
		$self -> __handle_http_error();
		return undef;
	}

	return $self -> __parse_response();
}

sub is_user_exists
{
	my $self  = shift;
	my $login = shift;

	my $url = API_URL . 'check_user.xml?token=' . $self -> {token} . '&login=' . $login;

	return undef unless $self -> __make_request($url);

	if ( my $result = $self -> __get_node_text('/page/result/text()') )
	{
		return 1 if ( 'exists' eq $result );
		return 0 if ( 'nouser' eq $result );
	}

	return $self -> __unknown_error();
}

sub create_user
{
	my $self  = shift;
	my $login = shift;
	my $pass  = shift;
	my $encr  = shift;

	my $url;

	if ($encr)
	{
		$url = API_URL . 'reg_user_crypto.xml?token=' . $self -> {token} . '&login='    . $login
										 . '&password=' . $pass;
	}
	else
	{
		$url = API_URL . 'reg_user_token.xml?token=' . $self -> {token} . '&u_login='    . $login
										. '&u_password=' . $pass;
	}

	return undef unless $self -> __make_request($url);

	if ( my $uid = $self -> __get_node_text('/page/ok/@uid') )
	{
		return $uid;
	}

	return $self -> __unknown_error();
}

sub create_user_encryped
{
	my $self  = shift;
	my $login = shift;
	my $pass  = shift;

	return $self -> create_user($login, $pass, 'encryped');
}

sub update_user
{
	my $self  = shift;
	my $login = shift;
	my %data  = @_;

	my $url = API_URL . '/edit_user.xml?token=' . $self -> {token}  . '&login='    . $login
									. '&password=' . $data{password} || ''
									. '&iname='    . $data{iname}    || ''
									. '&fname='    . $data{fname}    || ''
									. '&sex='      . $data{sex}      || ''
									. '&hintq='    . $data{hintq}    || ''
									. '&hinta='    . $data{hinta}    || '';


	return undef unless $self -> __make_request($url);

	if ( my $uid = $self -> __get_node_text('/page/ok/@uid') )
	{
		return $uid;
	}

	return $self -> __unknown_error();
}

sub import_user
{
	my $self     = shift;
	my $login    = shift;
	my $password = shift;
	my %data     = @_;

	$data{save_copy} = ($data{save_copy} and $data{save_copy} ne 'no') ? '1' : '0';

	my $url = API_URL . 'reg_and_imp.xml?token='    . $self -> {token}
							. '&login='        . $login
							. '&inn_password=' . $password
							. '&ext_login='    . ( $data{ext_login} || $login )
							. '&ext_password=' .   $data{ext_password}
							. '&fwd_email='    . ( $data{forward_to} || '' )
							. '&fwd_copy='     .   $data{save_copy};

	return undef unless $self -> __make_request($url);

	if ( $self -> __get_nodelist('/page/ok') -> [0] )
	{
		return 1;
	}

	return $self -> __unknown_error();
}

sub delete_user
{
	my $self  = shift;
	my $login = shift;

	my $url = API_URL . 'delete_user.xml?token=' . $self -> {token}  . '&login=' . $login;

	return undef unless $self -> __make_request($url);

	if ( $self -> __get_nodelist('/page/ok') -> [0] )
	{
		return 1;
	}

	return $self -> __unknown_error();
}

sub set_forward
{
	my $self      = shift;
	my $login     = shift;
	my $address   = shift;
	my $save_copy = shift;
	
	$save_copy = ($save_copy and $save_copy ne 'no') ? 'yes' : 'no';

	my $url = API_URL . 'set_forward.xml?token=' . $self -> {token} . '&login='   . $login
									. '&address=' . $address
									. '&copy='    . $save_copy;

	return undef unless $self -> __make_request($url);

	if ( $self -> __get_nodelist('/page/ok') -> [0] )
	{
		return 1;
	}

	return $self -> __unknown_error();
}

sub get_user
{
	my $self    = shift;
	my $login   = shift;

	my $url = API_URL . 'get_user_info.xml?token=' . $self -> {token} . '&login=' . $login;

	return undef unless $self -> __make_request($url);

	my %user =
	(
		domain      => $self -> __get_node_text('/page/domain/name/text()'),
		login       => $self -> __get_node_text('/page/domain/user/login/text()'),
		birth_date  => $self -> __get_node_text('/page/domain/user/birth_date/text()'),
		fname       => $self -> __get_node_text('/page/domain/user/fname/text()'),
		iname       => $self -> __get_node_text('/page/domain/user/iname/text()'),
		hinta       => $self -> __get_node_text('/page/domain/user/hinta/text()'),
		hintq       => $self -> __get_node_text('/page/domain/user/hintq/text()'),
		mail_format => $self -> __get_node_text('/page/domain/user/mail_format/text()'),
		charset     => $self -> __get_node_text('/page/domain/user/charset/text()'),
		nickname    => $self -> __get_node_text('/page/domain/user/nickname/text()'),
		sex         => $self -> __get_node_text('/page/domain/user/sex/text()'),
		enabled     => $self -> __get_node_text('/page/domain/user/enabled/text()'),
		signed_eula => $self -> __get_node_text('/page/domain/user/signed_eula/text()'),
	);

	return \%user;
}

sub get_unread_count
{
	my $self  = shift;
	my $login = shift;

	my $url = API_URL . 'get_mail_info.xml?token=' . $self -> {token} . '&login=' . $login;

	return undef unless $self -> __make_request($url);

	my $count = $self -> __get_node_text('/page/ok/@new_messages');

	if ( defined $count )
	{
		return $count;
	}

	return $self -> __unknown_error();
}

sub get_user_list
{
	my $self     = shift;
	my $page     = shift || 1;
	my $per_page = shift || 100;

	my $url = API_URL . 'get_domain_users.xml?token=' . $self -> {token}
							  . '&page= '    . $page # HACK XXX
							  . '&per_page=' . $per_page;
	return undef unless $self -> __make_request($url);

	my @emails = ();

	for ( $self -> __get_nodelist('/page/domains/domain/emails/email/name') )
	{
		push( @emails, $_ -> textContent );
	}

	$self -> {info} =
	{
		'action-status'    =>  $self -> __get_node_text('/page/domains/domain/emails/action-status/text()'),
		'found'            =>  $self -> __get_node_text('/page/domains/domain/emails/found/text()'),
		'total'            =>  $self -> __get_node_text('/page/domains/domain/emails/total/text()'),
		'domain'           =>  $self -> __get_node_text('/page/domains/domain/name/text()'),
		'status'           =>  $self -> __get_node_text('/page/domains/domain/status/text()'),
		'emails-max-count' =>  $self -> __get_node_text('/page/domains/domain/emails-max-count/text()'),
		'emails'           =>  \@emails,
	};

	return $self -> {info};
}

sub prepare_import
{
	my $self   = shift;
	my $server = shift;
	my %data   = @_;

	unless ($data{method} or $data{method} !~ /^pop3|imap$/i)
	{
		$data{method} = 'pop3';
	}

	my $url = API_URL . 'set_domain.xml?token='     . $self -> {token}
							. '&ext_serv='  .  $server
							. '&method='    .  $data{method}
							. '&callback='  .  $data{callback};

	$url .= '&ext_port=' . $data{port} if $data{port};

	$url .= '&isssl=no' unless $data{use_ssl};

	return undef unless $self -> __make_request($url);

	if ( $self -> __get_nodelist('/page/ok') -> [0] )
	{
		return 1;
	}

	return $self -> __unknown_error();
}

sub start_import
{
	my $self  = shift;
	my $login = shift;
	my %data  = @_;

	my $url = API_URL . 'start_import.xml?token='   . $self -> {token}
							. '&login='     .  $login
							. '&ext_login=' . ($data{login} || $login)
							. '&password='  .  $data{password};

	return undef unless $self -> __make_request($url);

	if ( $self -> __get_nodelist('/page/ok') -> [0] )
	{
		return 1;
	}

	return $self -> __unknown_error();
}

sub get_import_status
{
	my $self  = shift;
	my $login = shift;

	my $url = API_URL . 'check_import.xml?token=' . $self -> {token}  . '&login=' . $login;

	return undef unless $self -> __make_request($url);

	my $data =
	{
		last_check => $self -> __get_node_text('/page/ok/@last_check'),
		imported   => $self -> __get_node_text('/page/ok/@imported'),
		state      => $self -> __get_node_text('/page/ok/@state'),
	};

	return $data;
}

sub stop_import
{
	my $self  = shift;
	my $login = shift;

	return undef unless ($login);

	my $url = API_URL . 'stop_import.xml?token=' . $self -> {token}  . '&login=' . $login;

	return undef unless $self -> __make_request($url);

	if ( $self -> __get_nodelist('/page/ok') -> [0] )
	{
		return 1;
	}

	return $self -> __unknown_error();
}

# fails for existing accounts
#sub import_imap_folder
#{
#	my $self     = shift;
#	my $login    = shift;
#	my $password = shift;
#
#	my $ext_login    = shift;
#	my $ext_password = shift;
#
#	my $url = API_URL . 'import_imap.xml?token='    . $self -> {token}
#							. '&login='           . $login
#							. '&ext_login='       . $ext_login
#							. '&ext_password='    . $ext_password;
#
#	$url .= '&int_password=' . $password if ($password);
#
#	return undef unless $self -> __make_request($url);
#
#	if ( $self -> __get_nodelist('/page/ok') -> [0] )
#	{
#		return 1;
#	}
#
#	return $self -> __unknown_error();
#}

=head1 NAME

WWW::Yandex::PDD - Perl extension for Yandex mailhosting

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

use WWW::Yandex::PDD;
blah blah blah

TBD


=head1 DESCRIPTION

TBD

Blah blah blah.


=head1 SEE ALSO

http://pdd.yandex.ru/


=head1 AUTHOR

dctabuyz, C<< <dctabuyz@ya.ru> >>
Andrei Lukovenko, C<< <aluck at cpan.org> >>


=head1 BUGS

Please report any bugs or feature requests to C<bug-www-yandex-pdd at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Yandex-PDD>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Yandex::PDD


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Yandex-PDD>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Yandex-PDD>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Yandex-PDD>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Yandex-PDD/>

=back


=head1 COPYRIGHT AND LICENSE

    Copyright (c) 2010 by dctabuyz@ya.ru
    Copyright (c) 2013 by aluck@cpan.org
    
    This library is free software; you can redistribute it and/or modify
    it under the same terms as Perl itself, either Perl version 5.8.7 or,
    at your option, any later version of Perl 5 you may have available.

=cut

1;
