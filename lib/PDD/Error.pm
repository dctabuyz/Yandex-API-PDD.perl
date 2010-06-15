package Yandex::API::PDD::Error;

use strict;
use warnings;

use base "Exporter";

use constant HTTP_ERROR          => 'HTTP_ERROR';

use constant NOT_AUTHENTICATED   => 'NOT_AUTHENTICATED';
use constant EMPTY_RESPONSE      => 'EMPTY_RESPONSE';
use constant INVALID_RESPONSE    => 'INVALID_RESPONSE';
use constant REQUEST_FAILED      => 'REQUEST_FAILED';

use constant USER_NOT_FOUND      => 'USER_NOT_FOUND';
use constant LOGIN_NOT_SPECIFIED => 'LOGIN_NOT_SPECIFIED';
use constant LOGIN_ALREADY_TAKEN => 'LOGIN_ALREADY_TAKEN';
use constant LOGIN_TOO_SHORT     => 'LOGIN_TOO_SHORT';
use constant LOGIN_TOO_LONG      => 'LOGIN_TOO_LONG';

use constant PASSWORD_TOO_SHORT  => 'PASSWORD_TOO_SHORT';
use constant PASSWORD_TOO_LONG   => 'PASSWORD_TOO_LONG';

use constant NO_CRYPTED_PASSWORD => 'NO_CRYPTED_PASSWORD';
use constant CANT_CREATE_ACCOUNT => 'CANT_CREATE_ACCOUNT';

use constant NO_IMPORT_SETTINGS  => 'NO_IMPORT_SETTINGS';
use constant NO_IMPORT_INFO      => 'NO_IMPORT_INFO';

use constant SERVICE_ERROR       => 'SERVICE_ERROR';
use constant UNKNOWN_ERROR       => 'UNKNOWN_ERROR';

my @ERR = qw(   
		HTTP_ERROR

		NOT_AUTHENTICATED
		EMPTY_RESPONSE
		INVALID_RESPONSE
		REQUEST_FAILED
                                                  
		USER_NOT_FOUND
		LOGIN_NOT_SPECIFIED
		LOGIN_ALREADY_TAKEN
		LOGIN_TOO_SHORT
		LOGIN_TOO_LONG

		PASSWORD_TOO_SHORT
		PASSWORD_TOO_LONG

		NO_CRYPTED_PASSWORD
		CANT_CREATE_ACCOUNT

		NO_IMPORT_SETTINGS
		NO_IMPORT_INFO

		SERVICE_ERROR
		UNKNOWN_ERROR
);


my %ERR_R = (   
		'not authenticated'           => NOT_AUTHENTICATED,
		'no_login'                    => LOGIN_NOT_SPECIFIED,
		'bad_login'                   => LOGIN_NOT_SPECIFIED,
		'no_user'                     => USER_NOT_FOUND,
		'not_found'                   => USER_NOT_FOUND,
		'user_not_found'              => USER_NOT_FOUND,
		'no such user registered'     => USER_NOT_FOUND,
		'occupied'                    => LOGIN_ALREADY_TAKEN,
		'login_short'                 => LOGIN_TOO_SHORT,
		'badlogin_length'             => LOGIN_TOO_LONG,
		'passwd-tooshort'             => PASSWORD_TOO_SHORT,
		'passwd-toolong'              => PASSWORD_TOO_LONG,

		'no-passwd_cryptpasswd'       => NO_CRYPTED_PASSWORD,
		'cant_create_account'         => CANT_CREATE_ACCOUNT,

		'no_import_settings'          => NO_IMPORT_SETTINGS,
		'no import info on this user' => NO_IMPORT_INFO,
);

# our @EXPORT_OK   = ( 'identify', @ERR );
our @EXPORT_OK   = ( @ERR );
#our %EXPORT_TAGS = ( errors => [ @ERR ] , all => [ @EXPORT_OK ] );
our %EXPORT_TAGS = ( errors => [ @ERR ] );

sub identify
{
	return $ERR_R{ [split(/,/, $_[0], 2)] -> [0] } || &REQUEST_FAILED; 
}

1;

__END__
