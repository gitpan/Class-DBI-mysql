#!/usr/bin/perl -w

use strict;
use Test::More tests => 8;
use Class::DBI::mysql;

#-------------------------------------------------------------------------
# Let the testing begin
#-------------------------------------------------------------------------

# Find a test database to use.

my ($dbname, $user, $pass) = ("test", "", "");
my $dbh = DBI->connect("dbi:mysql:$dbname", $user, $pass);

SETUP: while (not $dbh) {
  ($dbname, $user, $pass) = get_db("I cannot connect to a test MySQL database.");
  $dbh = DBI->connect("dbi:mysql:$dbname", $user, $pass);
}

# Find a suitable table to play with, by finding the last table,
# and going beyond it - we can't magically autoincrement in case
# the table name has an underscore in it, so we prepend a z. 
my @tables = sort @{ $dbh->selectcol_arrayref(qq{
  SHOW TABLES
})};
my $table = $tables[-1] || "aaa";
   $table = "z$table";

my $version = get_mysql_version($dbh);
my $FULLTEXT = 32323;
my $RANDORDER = 32302;
eval {
  my $text = ($version >= $FULLTEXT) ?  " , FULLTEXT(name) " : "";
  my $create = qq{
    CREATE TABLE $table (
      id mediumint not null auto_increment primary key,
      name varchar(50) not null default '',
      val  smallint unsigned default 'A' not null,
      mydate date default '' not null,
      myvals enum('foo', 'bar')
      $text
    )
  };
  $dbh->do($create);
};
# Uggh.
if ($@) { undef $dbh; warn "I cannot write to that database\n"; goto SETUP; }

$dbh->do(qq{
  INSERT INTO $table (name) VALUES
  ('MySQL has now support'), ( 'for full-text search'),
  ('Full-text indexes'), ( 'are called collections'),
  ('Only MyISAM tables'), ('support collections'),
  ('Function MATCH ... AGAINST()'), ('is used to do a search'),
  ('Full-text search in MySQL'), ( 'implements vector space model')
});


package Foo;
use base 'Class::DBI::mysql';
__PACKAGE__->set_db('Main', "dbi:mysql:$dbname", $user, $pass);
__PACKAGE__->set_up_table($table);

package main;

ok(Foo->can('name'), "We're set up OK");
is(Foo->count, 10, "We have 10 rows");
my @all = Foo->retrieve_all;
is(scalar @all, 10,  "And 10 results from retrieve all");

# Test random. Is there a sensible way to test this is actually
# random? For now we'll just ensure that we get something back.
if ($version >= $RANDORDER) {
  my $obj = Foo->retrieve_random;
  ok($obj && $obj->id, "We can retrieve a random row");
} else {
  ok(1, "SKIPPED: ORDER BY rand introduced in 3.23.2");
}

#-------------------------------------------------------------------------
# Test coltype
#-------------------------------------------------------------------------
my $type = Foo->column_type('myvals');
like $type, qr/^enum/i, "Myvals is an enum";

my @vals = sort Foo->enum_vals('myvals');
ok eq_array(\@vals, [qw/bar foo/]), "Enum vals OK";
eval { Foo->enum_vals('mydate') };
ok $@, $@;

#-------------------------------------------------------------------------
# Test initials
#-------------------------------------------------------------------------
my $inits = join "", Foo->initials("name");
is($inits, "afimos", "Initials OK");

sub get_db {
  my $msg = shift;
  my $old_fh = select(STDERR);
  print "\n$msg\n";
  my $dbname = "";
  while (!$dbname) {
    print "Please specify the name of a writable database: ";
    $dbname    = <STDIN>; chomp $dbname;
  }
  print " A username to access this data source: ";
  my $user = <STDIN>; chomp $user;
  print " And a password: ";
  my $pass = <STDIN>; chomp $pass;
  select($old_fh);
  return ($dbname, $user, $pass);
}

sub get_mysql_version {
  my $dbh = shift;
  my %var = map { $_->[0] => $_->[1] } @{ $dbh->selectall_arrayref(qq{
    SHOW VARIABLES
  })};
	my ($num) = split /-/, $var{version};
  my @version = split /\./, $num;
  return sprintf "%01d%02d%02d", @version[0..2];
}

# Clean up after ourselves.
END {
  $dbh->do("DROP TABLE $table");
  $dbh->disconnect;
}

