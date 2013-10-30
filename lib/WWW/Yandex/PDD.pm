package WWW::Yandex::PDD;

use strict;
use warnings;

our $VERSION = '0.04';

use LWP::UserAgent; # also required: Crypt::SSLeay or IO::Socket::SSL
use LWP::ConnCache;
use XML::LibXML;
use XML::LibXML::XPathContext; # explicit use is required in some cases

use WWW::Yandex::PDD::Error;

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
		$self -> {error}      = { code => &WWW::Yandex::PDD::Error::HTTP_ERROR };
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

	$self -> __set_error( WWW::Yandex::PDD::Error::identify( $self -> {_error} ), $self -> {_error} );
}

sub __handle_http_error
{
	my $self = shift;

	$self -> __set_error( $self -> {r} -> code(),
			      $self -> {r} -> decoded_content(),
			      &WWW::Yandex::PDD::Error::HTTP_ERROR
	);
}

sub __unknown_error
{
	my $self = shift;

	$self -> __set_error( &WWW::Yandex::PDD::Error::UNKNOWN_ERROR,
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
		$self -> __set_error(&WWW::Yandex::PDD::Error::INVALID_RESPONSE);
		return undef;
	}

	unless ($xml)
	{
		$self -> __set_error(&WWW::Yandex::PDD::Error::INVALID_RESPONSE);
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

		$self -> __set_error(&WWW::Yandex::PDD::Error::SERVICE_ERROR, $info);
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

#TODO: reg_user, 
sub create_user
{
	my $self  = shift;
	my $login = shift;
	my $pass  = shift;
	my $encr  = shift;

	my $url;

	if ($encr)
	{
		$url = API_URL . 'reg_user_crypto.xml?token=' . $self -> {token} . '&login=' . $login
										 . '&password=' . $pass;
	}
	else
	{
		$url = API_URL . 'reg_user_token.xml?token=' . $self -> {token} . '&u_login=' . $login
										. '&u_password=' . $pass;
	}

	return undef unless $self -> __make_request($url);

	if ( my $uid = $self -> __get_node_text('/page/ok/@uid') )
	{
		return $uid;
	}

	return $self -> __unknown_error();
}

sub update_user
{
	my $self  = shift;
	my $login = shift;
	my %data  = @_;

	my $url = API_URL . '/edit_user.xml?token=' . $self -> {token} . '&login=' . $login
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

	my $url = API_URL . 'reg_and_imp.xml?token=' . $self -> {token}
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
							. '&ext_login=' . ($data{ext_login} || $login)
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


=head1 SYNOPSIS

	use WWW::Yandex::PDD;

	my $pdd = WWW::Yandex::PDD->new( token => 'abcdefghijklmnopqrstuvwxyz01234567890abcdefghijklmnopqrs' );
	$pdd->create_user( 'mynewuser', 'mysecretpassword' );


=head1 DESCRIPTION

L<WWW::Yandex::PDD> allows to manage user mail accounts on Yandex mailhosting


=head1 METHODS

=over

=item $pdd->new( token => $token );

=item $pdd->new( token => $token, cert_file => $cert_file );

Construct a new L<WWW::Yandex::PDD> object

	$token A string obtained at L<http://api.yandex.ru/pdd/doc/api-pdd/reference/get-token.xml#get-token>

	$cert_file New $ENV{HTTPS_CA_FILE} value


=item $pdd->create_user( $login, $password );

=item $pdd->create_user( $login, $encrypted_password, 'encrypted' );

	$encrypted_password is MD5-CRYPT password hash: "$1$" + 8 character salt [a-zA-Z0-9./] + "$" + 22 character checksum [a-zA-Z0-9./]


=item $pdd->update_user( $login, password => $password, iname => $iname, fname => $fname, sex => $sex, hintq => $hintq, hinta => $hinta )

See L<$pdd->get_user> for parameters meaning

Returns UID if success, undef otherwise


=item $pdd->delete_user( $login )

Returns 1 if success


=item $pdd->get_unread_count($login)

Returns number of unread messages, undef if error


=item $pdd->get_user( $login )

Returns undef if fail, or the following structure if success: 

	$result = {
		domain      => 'mydomain.org',
		login       => 'username',
		birth_date  => '1900-01-01',
		iname       => 'John',
		fname       => 'Doe',
		hintq       => 'Your mother\'s maiden name?', # utf-8
		hinta       => '*****',
		mail_format => '', # preferred mail format
		charset     => '', # preferred charset
		nickname    => 'johnny',
		sex         => 1, # 0 - N/A, 1 - male, 2 - female
		enabled     => 1, # 1 - normal, mail accepted; 0 - locked, mail rejected
		signed_eula => 1, # user accepted EULA: 1 - yes, 0 - no
	};


=item $pdd->get_user_list($page, $per_page)

Returns domain information and user list, undef if error

	$page Page number.

	$per_page Number of mailbox records on a single page; cannot be more than 100; 100 records by default.

	$result = {
		'action-status'    =>  '',				# error message
		'found'            =>  18, 				# number of users returned
		'total'            =>  18, 				# total number of users in this domain
		'domain'           =>  'mydomain.org',
		'status'           =>  'added', 		# added, mx-activate, domain-activate
		'emails-max-count' =>  1000,			# maximum users for this domain
		'emails'           =>  [ 'jdoe', 'mkay' ], # user list
	}


=item $pdd->import_user( $login, $password, ext_login => $ext_login, ext_password => $ext_password, forward_to => $forward, save_copy => $save_copy )

Register a new user and import all the mail from another server

$ext_login login name on the source server, defaults to $login
$ext_password user's password on the source server, defaults to $password
$forward_to optional, set forwarding for this new mailbox
$save_copy works only if forwarding is on; 0 - do not save copies in the local mailbox, 1 - save copies and forward


=item $pdd->is_user_exists( $login )

Returns 0 if exists, 1 if doesn't exist, undef if error


=item $pdd->set_forward( $login, $forward_to, $save_copy )

Sets forwarding to $forward_to

$save_copy: "yes", "no"

Returns 1 if OK, undef if error


=item $pdd->prepare_import( $server, method => $method, port => $port, callback = $callback, use_ssl => $use_ssl )

Set import options for the domain

	$method: 'pop3', 'imap', default 'pop3'

	$port: 100 POP3 w/o SSL, 995 POP3 with SSL; optional

	$use_ssl: 'yes'/'no'; default 'no'

	$callback: URL. If not empty, an HTTP request will be made to this address 
	with login="imported user's login" parameter after finishing import

Returns 1 if OK, undef if error


=item $pdd->get_import_status( $login )

	$result = {
		last_check => $last_check,
		imported   => $imported,
		state      => $state
	};


=item $pdd->start_import( $login, ext_login => $ext_login, password => $password )

	$ext_login login on the source, defaults to $login
	$password on the source

Returns 1 if OK, undef if error


=item $pdd->stop_import($login)

Returns 1 if OK, undef if error


=back


=head1 SEE ALSO

L<http://pdd.yandex.ru/>
L<http://api.yandex.ru/pdd/doc/api-pdd/concepts/general.xml>


=head1 AUTHORS

dctabuyz, <dctabuyz at ya.ru>
Andrei Lukovenko, <aluck at cpan.org>


=head1 BUGS

Please report any bugs or feature requests to C<bug-www-yandex-pdd at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Yandex-PDD>. I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 HISTORY

Original version by dctabuyz: L<https://github.com/dctabuyz/Yandex-API-PDD.perl>


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

    Copyright (c) 2010 <dctabuyz at ya.ru>
    Copyright (c) 2013 <aluck at cpan.org>

    This library is free software; you can redistribute it and/or modify
    it under the same terms as Perl itself, either Perl version 5.8.7 or,
    at your option, any later version of Perl 5 you may have available.

=cut

1;
