use ExtUtils::MakeMaker;

$PACKAGE = "Class::DBI::mysql";
$LAST_API_CHANGE = 0.16;

eval "require $PACKAGE";

unless ($@) { # Make sure we did find the module.
	my $inst_version = ${$PACKAGE.'::VERSION'};
    print <<"CHANGE_WARN" if $inst_version < $LAST_API_CHANGE;

NOTE: There have been API changes since your installed version
($inst_version)!  Please check carefully if these will impact on you:

Significant changes:

  0.16 - removed search_match() and initials(). 
       - deprecated count() in favour of count_all();

  0.14 - no longer support CURDATE() etc.

CHANGE_WARN
}

WriteMakefile(
    'NAME'		=> $PACKAGE,
    'VERSION_FROM'	=> 'lib/Class/DBI/mysql.pm', 
    'PREREQ_PM'		=> { 
      'Class::DBI' => 0.94, 
      'Test::More' => 0.45, 
      'DBD::mysql' => 0, 
    },
    ($] >= 5.005 ?    
      (ABSTRACT_FROM => 'lib/Class/DBI/mysql.pm', 
       AUTHOR     => 'Tony Bowden <tony@tmtm.com>') : ()),
);
