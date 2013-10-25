use 5.008007;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'WWW::Yandex::PDD',
    VERSION           => '0.0.1',
    PREREQ_PM         => { LWP::UserAgent => 0, XML::LibXML => 0 },
    ( $] >= 5.005 ?
      (
          ABSTRACT_FROM  => 'lib/WWW/Yandex/PDD.pm', # retrieve abstract from module
          AUTHOR         => 'dctabuyz <dctabuyz@yandex.ru>', 'Andrei Lukovenko <aluck@cpan.org>'
      ) : 
      ()
    ),
);
