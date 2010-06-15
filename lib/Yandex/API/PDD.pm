package Yandex::API::PDD;

use strict;
use warnings;

use LWP::UserAgent; # also required: Crypt::SSLeay or IO::Socket::SSL
use LWP::ConnCache;
use XML::LibXML;
use XML::LibXML::XPathContext; # explicit use is required in some cases

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

	return undef unless ($data);

	$self -> {token} = $data -> {token};

	return undef unless $self -> {token};

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

sub __get_xpath_nodes
{
	my $self  = shift;
	my $xpath = shift;
	my $xml   = shift || $self -> {xml};

	return '' unless ($xpath and $xml); # TODO die

	return $self -> {xpath} -> findnodes($xpath, $xml);
}

sub __get_xpath_data
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
		$self -> __set_error(&Yandex::API::PDD::Error::EMPTY_RESPONSE);
		return undef;
	}

	$self -> {xml} = $xml;

	if ( $self -> {_error} = $self -> __get_xpath_data('/page/error/@reason') )
	{
		$self -> __handle_error();
		return undef;
	}

	if ( $self -> __get_xpath_data('/page/xscript_invoke_failed/@error') )
	{
		my $info = '';

		for ( qw{ error block method object exception } )
		{
			my $s = '/page/xscript_invoke_failed/@' . $_;

			$info .= $_ . ': "' . $self -> __get_xpath_data($s) . '" ';
		}

		$self -> __set_error(&Yandex::API::PDD::Error::SERVICE_ERROR, $info);
		return undef;
	}

	return 1 unless ( $self -> {_error} );
}

sub __make_request
{
	my $self = shift;
	my $uri  = shift;

	$self -> __reset_error();

	$self -> {r} = $self -> {ua} -> get($uri);

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

# TODO set error if login is empty
	return undef unless ($login);

	my $uri = API_URL . 'check_user.xml?token=' . $self -> {token} . '&login=' . $login;

	return undef unless $self -> __make_request($uri);

	return ( 'exists' eq $self -> __get_xpath_data('/page/result/text()') );
}

sub create_user
{
	my $self  = shift;
	my $login = shift;
	my $pass  = shift;
	my $encr  = shift;

# TODO set error if login is empty
#	return undef unless ($login and $pass);

	my $uri;

	if ($encr)
	{
		$uri = API_URL . 'reg_user_crypto.xml?token=' . $self -> {token} . '&login='    . $login
										 . '&password=' . $pass;
	}
	else
	{
		$uri = API_URL . 'reg_user_token.xml?token=' . $self -> {token} . '&u_login='    . $login
										. '&u_password=' . $pass;
	}

	return undef unless $self -> __make_request($uri);

	return ( $self -> __get_xpath_data('/page/ok/@uid') );
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
	my %data  = @_;

# TODO set error if login is empty

	my $uri = API_URL . '/edit_user.xml?token=' . $self -> {token}  . '&login='    . $data{login}
									. '&password=' . $data{password} || ''
									. '&iname='    . $data{iname}    || ''
									. '&fname='    . $data{fname}    || ''
									. '&sex='      . $data{sex}      || ''
									. '&hintq='    . $data{hintq}    || ''
									. '&hinta='    . $data{hinta}    || '';


	return undef unless $self -> __make_request($uri);

	return ( $self -> __get_xpath_data('/page/ok/@uid') );
}

sub import_user
{
	my $self = shift;
	my %data = @_;

	my $uri = API_URL . 'reg_and_imp.xml?token='    . $self -> {token}
							. '&login='        . $data{login}
							. '&ext_login='    . ( $data{ext_login} || $data{login} )
							. '&inn_password=' . $data{int_password}
							. '&ext_password=' . $data{ext_password}
							. '&fwd_email='    . ( $data{fwd_email} || '' )
							. '&fwd_copy='     . ( $data{fwd_copy} ? '1' : '0' );

	return undef unless $self -> __make_request($uri);

	return 1;
}

sub delete_user
{
	my $self  = shift;
	my $login = shift;

	return undef unless ($login);

	my $uri = API_URL . 'delete_user.xml?token=' . $self -> {token}  . '&login=' . $login;

	return undef unless $self -> __make_request($uri);

	return 1;
}

sub set_forward
{
	my $self    = shift;
	my $login   = shift;
	my $address = shift;

	my $copy    = (shift) ? 'yes' : 'no';

# TODO set error if login is empty
#	return undef unless ($login and $address);

	my $uri = API_URL . 'set_forward.xml?token=' . $self -> {token} . '&login='   . $login
									. '&address=' . $address
									. '&copy='    . $copy;

	return undef unless $self -> __make_request($uri);

	return 1;
}

sub get_user
{
	my $self    = shift;
	my $login   = shift;

# TODO set error if login is empty
	return undef unless ($login);

	my $uri = API_URL . 'get_user_info.xml?token=' . $self -> {token} . '&login=' . $login;

	return undef unless $self -> __make_request($uri);

	my %user =
	(
		domain      => $self -> __get_xpath_data('/page/domain/name/text()'),
		login       => $self -> __get_xpath_data('/page/domain/user/login/text()'),
		birth_date  => $self -> __get_xpath_data('/page/domain/user/birth_date/text()'),
		fname       => $self -> __get_xpath_data('/page/domain/user/fname/text()'),
		iname       => $self -> __get_xpath_data('/page/domain/user/iname/text()'),
		hinta       => $self -> __get_xpath_data('/page/domain/user/hinta/text()'),
		hintq       => $self -> __get_xpath_data('/page/domain/user/hintq/text()'),
		mail_format => $self -> __get_xpath_data('/page/domain/user/mail_format/text()'),
		charset     => $self -> __get_xpath_data('/page/domain/user/charset/text()'),
		nickname    => $self -> __get_xpath_data('/page/domain/user/nickname/text()'),
		sex         => $self -> __get_xpath_data('/page/domain/user/sex/text()'),
		enabled     => $self -> __get_xpath_data('/page/domain/user/enabled/text()'),
		signed_eula => $self -> __get_xpath_data('/page/domain/user/signed_eula/text()'),
	);

	return \%user;
}

sub get_unread_count
{
	my $self  = shift;
	my $login = shift;

# TODO set error if login is empty
	return undef unless ($login);

	my $uri = API_URL . 'get_mail_info.xml?token=' . $self -> {token} . '&login=' . $login;

	return undef unless $self -> __make_request($uri);

	return $self -> __get_xpath_data('/page/ok/@new_messages');
}

sub get_user_list
{
	my $self     = shift;
	my $page     = shift || 1;
	my $per_page = shift || 100;

	my $uri = API_URL . 'get_domain_users.xml?token=' . $self -> {token}
							  . '&page= '    . $page # HACK XXX
							  . '&per_page=' . $per_page;
	return undef unless $self -> __make_request($uri);

	my @emails = ();

	for ( $self -> __get_xpath_nodes('/page/domains/domain/emails/email/name') )
	{
		push( @emails, $_ -> textContent );
	}

	$self -> {info} =
	{
		'action-status'    =>  $self -> __get_xpath_data('/page/domains/domain/emails/action-status/text()'),
		'found'            =>  $self -> __get_xpath_data('/page/domains/domain/emails/found/text()'),
		'total'            =>  $self -> __get_xpath_data('/page/domains/domain/emails/total/text()'),
		'domain'           =>  $self -> __get_xpath_data('/page/domains/domain/name/text()'),
		'status'           =>  $self -> __get_xpath_data('/page/domains/domain/status/text()'),
		'emails-max-count' =>  $self -> __get_xpath_data('/page/domains/domain/emails-max-count/text()'),
		'emails'           =>  \@emails,
	};

	return 1;
}

sub prepare_import
{
	my $self = shift;
	my %data = @_;

	my $uri = API_URL . 'set_domain.xml?token='     . $self -> {token}
							. '&method='    . ($data{method} || 'pop3')
							. '&ext_serv='  .  $data{server}
							. '&ext_port='  .  $data{port}
							. '&isssl='     . ($data{use_ssl}  ? 'yes' : 'no')
							. '&callback='  . ($data{callback} ? 'yes' : 'no');

	return undef unless $self -> __make_request($uri);

	return 1;
}

sub start_import
{
	my $self = shift;
	my %data = @_;

	my $uri = API_URL . 'start_import.xml?token='   . $self -> {token}
							. '&login='     . ($data{login}        || '')
							. '&ext_login=' . ($data{ext_login}    || $data{login} || '')
							. '&password='  . ($data{ext_password} || '');

	return undef unless $self -> __make_request($uri);

	return 1;
}

sub get_import_status
{
	my $self  = shift;
	my $login = shift;

# TODO set error if login is empty
	return undef unless ($login);

	my $uri = API_URL . 'check_import.xml?token=' . $self -> {token}  . '&login=' . $login;

	return undef unless $self -> __make_request($uri);

	my $data =
	{
		last_check => $self -> __get_xpath_data('/page/ok/@last_check'),
		imported   => $self -> __get_xpath_data('/page/ok/@imported'),
		state      => $self -> __get_xpath_data('/page/ok/@state'),
	};

	return $data;
}

sub stop_import
{
	my $self  = shift;
	my $login = shift;

	return undef unless ($login);

	my $uri = API_URL . 'stop_import.xml?token=' . $self -> {token}  . '&login=' . $login;

	return undef unless $self -> __make_request($uri);

	return 1;
}

# fails for existing accounts
sub import_imap_folder
{
	my $self = shift;
	my %data = @_;

	my $uri = API_URL . 'import_imap.xml?token='    . $self -> {token}
							. '&login='           . $data{login}
							. '&ext_login='       . ( $data{ext_login} || $data{login} )
							. '&int_password='    . ( $data{int_password} || '' )
							. '&ext_password='    . $data{ext_password};

	return undef unless $self -> __make_request($uri);

	return 1;
}

1;

=head1 NAME

Yandex::API::PDD - Perl extension for Yandex mail hosting

=head1 SYNOPSIS

    use Yandex::API::PDD;
    blah blah blah

    TBD

=head1 DESCRIPTION

    TBD
    
    Blah blah blah.

=head1 SEE ALSO

    http://pdd.yandex.ru/

=head1 AUTHOR

    dctabuyz@ya.ru

=head1 COPYRIGHT AND LICENSE

    Copyright (C) 2010 by dctabuyz@ya.ru
    
    This library is free software; you can redistribute it and/or modify
    it under the same terms as Perl itself, either Perl version 5.8.7 or,
    at your option, any later version of Perl 5 you may have available.

=cut
