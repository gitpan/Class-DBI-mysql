#!/usr/bin/perl -w

use strict;
use Test::More tests => 8;
use Class::DBI::mysql;

#-------------------------------------------------------------------------
# Let the testing begin
#-------------------------------------------------------------------------

package Foo;

use base 'Class::DBI::mysql';

# Find a test database to use.

my $db   = $ENV{DBD_MYSQL_DBNAME} || 'test';
my $user = $ENV{DBD_MYSQL_USER}   || '';
my $pass = $ENV{DBD_MYSQL_PASSWD} || '';
my $tbl  = $ENV{DBD_MYSQL_TABLE}  || 'tbcdbitest';

__PACKAGE__->set_db(Main => "dbi:mysql:$db", $user => $pass);
__PACKAGE__->drop_table;
__PACKAGE__->create_table;
END { __PACKAGE__->drop_table }
__PACKAGE__->set_up_table($tbl);

sub drop_table {
	my $class = shift;
	$class->db_Main->do("DROP TABLE IF EXISTS $tbl");
}

sub create_table {
	my $class = shift;
	my $dbh   = $class->db_Main;
	$dbh->do(
		qq{
    CREATE TABLE $tbl (
      id mediumint not null auto_increment primary key,
      Name varchar(50) not null default '',
      val  smallint unsigned default 'A' not null,
      mydate date default '' not null,
      Myvals enum('foo', 'bar')
    )
  }
	);

	$dbh->do(
		qq{
		INSERT INTO $tbl (name) VALUES
		('MySQL has now support'), ( 'for full-text search'),
		('Full-text indexes'), ( 'are called collections'),
		('Only MyISAM tables'), ('support collections'),
		('Function MATCH ... AGAINST()'), ('is used to do a search'),
		('Full-text search in MySQL'), ( 'implements vector space model')
	}
	);
}

#-------------------------------------------------------------------------

package main;

ok(Foo->can('name'), "We're set up OK");

{
	local $SIG{__WARN__} = sub { pass("count deprecated") };
	is(Foo->count, 10, "We have 10 rows from count()");
}

my @all = Foo->retrieve_all;
is(scalar @all, 10, "And 10 results from retrieve_all()");

# Test random. Is there a sensible way to test this is actually
# random? For now we'll just ensure that we get something back.
my $obj = Foo->retrieve_random;
isa_ok $obj => "Foo", "Retrieve a random row";

# Test coltype
my $type = Foo->column_type('Myvals');
like $type, qr/^enum/i, "Myvals is an enum";

my @vals = sort Foo->enum_vals('Myvals');
ok eq_array(\@vals, [qw/bar foo/]), "Enum vals OK";
eval { Foo->enum_vals('mydate') };
ok $@, $@;

