use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'Class::DBI::mysql',
    'VERSION_FROM'	=> 'lib/Class/DBI/mysql.pm', 
    'PREREQ_PM'		=> { 
      'Class::DBI' => 0.91, 
      'Test::More' => 0.45, 
      'DBD::mysql' => 0, 
    },
    ($] >= 5.005 ?    
      (ABSTRACT_FROM => 'lib/Class/DBI/mysql.pm', 
       AUTHOR     => 'Tony Bowden <tony@tmtm.com>') : ()),
);
