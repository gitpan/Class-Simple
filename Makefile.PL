use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
#
# $Id: Makefile.PL,v 1.5 2007/12/31 19:59:11 sullivan Exp $
WriteMakefile(
    NAME              => 'Class::Simple',
    VERSION_FROM      => 'lib/Class/Simple.pm', # finds $VERSION
    PREREQ_PM         =>
	{
		Class::ISA => 0.32,
		Scalar::Util => 0,
		List::Util => 0,
	}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Class/Simple.pm', # retrieve abstract from module
       AUTHOR         => 'Michael Sullivan <perldude@mac.com>') : ()),
);
