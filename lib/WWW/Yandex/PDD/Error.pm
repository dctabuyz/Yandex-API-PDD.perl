package WWW::Yandex::PDD::Error;

use strict;
use warnings;

use base "Exporter";

use constant HTTP_ERROR          => 'HTTP_ERROR';

use constant NOT_AUTHENTICATED   => 'NOT_AUTHENTICATED';
use constant INVALID_RESPONSE    => 'INVALID_RESPONSE';
use constant REQUEST_FAILED      => 'REQUEST_FAILED';

use constant USER_NOT_FOUND      => 'USER_NOT_FOUND';
use constant LOGIN_OCCUPIED      => 'LOGIN_OCCUPIED';
use constant LOGIN_TOO_SHORT     => 'LOGIN_TOO_SHORT';
use constant LOGIN_TOO_LONG      => 'LOGIN_TOO_LONG';
use constant INVALID_LOGIN       => 'INVALID_LOGIN';

use constant INVALID_PASSWORD    => 'INVALID_PASSWORD';
use constant PASSWORD_TOO_SHORT  => 'PASSWORD_TOO_SHORT';
use constant PASSWORD_TOO_LONG   => 'PASSWORD_TOO_LONG';

use constant CANT_CREATE_ACCOUNT => 'CANT_CREATE_ACCOUNT';
use constant USER_LIMIT_EXCEEDED => 'USER_LIMIT_EXCEEDED';

use constant NO_IMPORT_SETTINGS  => 'NO_IMPORT_SETTINGS';

use constant SERVICE_ERROR       => 'SERVICE_ERROR';
use constant UNKNOWN_ERROR       => 'UNKNOWN_ERROR';

my @ERR = qw(   
		HTTP_ERROR

		NOT_AUTHENTICATED
		INVALID_RESPONSE
		REQUEST_FAILED
                                                  
		USER_NOT_FOUND
		LOGIN_OCCUPIED
		LOGIN_TOO_SHORT
		LOGIN_TOO_LONG

		PASSWORD_TOO_SHORT
		PASSWORD_TOO_LONG

		CANT_CREATE_ACCOUNT

		USER_LIMIT_EXCEEDED

		NO_IMPORT_SETTINGS
		NO_IMPORT_INFO

		SERVICE_ERROR
		UNKNOWN_ERROR
);


my %ERR_R = (   
		'not authenticated'           => NOT_AUTHENTICATED,
		'no_login'                    => INVALID_LOGIN,
		'bad_login'                   => INVALID_LOGIN,
		'no_user'                     => USER_NOT_FOUND,
		'not_found'                   => USER_NOT_FOUND,
		'user_not_found'              => USER_NOT_FOUND,
		'no such user registered'     => USER_NOT_FOUND,
		'occupied'                    => LOGIN_OCCUPIED,
		'login_short'                 => LOGIN_TOO_SHORT,
		'badlogin_length'             => LOGIN_TOO_LONG,
		'passwd-badpasswd'            => INVALID_PASSWORD,
		'passwd-tooshort'             => PASSWORD_TOO_SHORT,
		'passwd-toolong'              => PASSWORD_TOO_LONG,
		'hundred_users_limit'         => USER_LIMIT_EXCEEDED,

		'no-passwd_cryptpasswd'       => INVALID_PASSWORD,
		'cant_create_account'         => CANT_CREATE_ACCOUNT,

		'no_import_settings'          => NO_IMPORT_SETTINGS,
		'no import info on this user' => USER_NOT_FOUND,
                'unknown'                     => REQUEST_FAILED,
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
