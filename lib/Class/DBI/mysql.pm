package Class::DBI::mysql;

=head1 NAME

Class::DBI::mysql - Extensions to Class::DBI for MySQL

=head1 SYNOPSIS

  package Film.pm;
  use base 'Class::DBI::mysql';
  __PACKAGE__->set_db('Main', 'dbi:mysql:dbname', 'user', 'password');
  __PACKAGE__->set_up_table("film");

  # Somewhere else ...

  my $howmany = Film->count;

  my $tonights_viewing  = Film->retrieve_random;

  my @results = Film->search_match($key => $value);
  my @letters = Film->initials('title');

=head1 DESCRIPTION

This is an extension to Class::DBI, containing several functions and
optimisations for the MySQL database. Instead of setting Class::DBI
as your base class, use this instead.

=cut

use strict;
use base 'Class::DBI';

use vars qw($VERSION);
$VERSION = '0.13';

sub _die { require Carp; Carp::croak(@_); } 

=head2 set_up_table

  __PACKAGE__->set_up_table("table_name");

Traditionally, to use Class::DBI, you have to set up the columns:

  __PACKAGE__->columns(All => qw/list of columns/);
  __PACKAGE__->columns(Primary => 'column_name');

Whilst this allows for more flexibility if you're going to arrange your
columns into a variety of groupings, sometimes you just want to create the
'all columns' list. Well, this information is really simple to extract
from MySQL itself, so why not just use that?

This call will extract the list of all the columns, and the primary key
and set them up for you. It will die horribly if the table contains
no primary key, or has a composite primary key.

=cut

__PACKAGE__->set_sql('desc', 'DESCRIBE %s');

sub set_up_table {
  my $class = shift;
  my $table = shift;
  my $ref = $class->db_Main->selectall_arrayref("DESCRIBE $table");
  my (@cols, $primary);
  foreach my $row (@$ref) {
    my ($col) = $row->[0] =~ /(\w+)/;
    push @cols, $col;
    next unless ($row->[3] eq "PRI");
    _die "$table has composite primary key" if $primary;
    $primary = $col;
  }
  _die "$table has no primary key" unless $primary;
  $class->table($table);
  $class->columns(Primary => $primary);
  $class->columns(All => @cols);
}

=head1 column_type

  my $type = $class->column_type('column_name');

This returns the 'type' of this table (VARCHAR(20), BIGINT, etc.)

=cut

sub column_type {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $col = shift or die "Need a column for column_type";
  my $sth = $class->sql_desc($class->table);
     $sth->execute;
  my($series) = grep $_->[0] eq $col, $sth->fetchall;
  return $series->[1];
}

=head1 enum_vals

  my @allowed = $class->enum_vals('column_name');

This returns a list of the allowable values for an ENUM column.

=cut

sub enum_vals {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $col = shift or die "Need a column for enum vals";
  my $sth = $class->sql_desc($class->table);
     $sth->execute;
  my($series) = grep $_->[0] eq $col, $sth->fetchall;
  $series->[1] =~ /enum\((.*?)\)/ or die "$col is not an ENUM column";
  (my $enum = $1) =~ s/'//g;
  return split /,/, $enum;
}

=head2 count

  $howmany = Film->count;

This will count how many of these there are. You could get the
same effect by doing a 'select all', but this avoids the overhead
of having to fetch them all back by using MySQL's highly optimised
COUNT(*) function instead.

=cut

__PACKAGE__->set_sql('countem', <<"");
SELECT COUNT(*)
FROM   %s

sub count {
    my($proto) = @_;
    my($class) = ref $proto || $proto;
    my $data;
    eval {
        my $sth = $class->sql_countem($class->table);
        $sth->execute();
        $data = $sth->fetchrow_array;
        $sth->finish;
    };
    if ($@) {
        $class->DBIwarn('countem');
        return;
    }
    return $data;
}

=head2 retrieve_random

  my $film = Film->retrieve_random;

This will select a random row from the database, and return you
the relevant object.

(MySQL 3.23 and higher only, at this point)

=cut

__PACKAGE__->set_sql('GetRandom', <<"");
SELECT %s
FROM   %s
ORDER BY RAND()
LIMIT 1

sub retrieve_random {
    my($proto) = @_;
    my($class) = ref $proto || $proto;
    my $data;
    eval {
        my $sth = $class->sql_GetRandom(join(', ', $class->columns('Essential')),
                                    $class->table,
                                   );
        $sth->execute();
        $data = $sth->fetchrow_hashref;
        $sth->finish;
    };
    if ($@) {
        $class->DBIwarn('GetRandom');
        return;
    }
    return unless defined $data;
    return $class->construct($data);
}

=head2 search_match

  @results = Film->search_match($key => $value);

This is like search, but using the MySQL 'full text matching' capabilities.

=cut

__PACKAGE__->make_filter(search_match => 'MATCH %s AGAINST (?)');

=head2 initials

  my @letters = Film->initials('title');

This will return a (sorted) list of the initial letters of 
the title of each film.

=cut

__PACKAGE__->set_sql('GetInits', <<"");
SELECT LOWER(LEFT(%s, 1)) as initial
FROM %s
GROUP BY initial

sub initials {
    my($proto, $key) = @_;
    _die "You must fetch the initials of some value" unless $key;
    my($class) = ref $proto || $proto;
    $class->normalize_one(\$key);
    _die "$key is not a column" unless ($class->is_column($key));
    my $sth;
    eval {
        $sth = $class->sql_GetInits($key, $class->table);
        $sth->execute();
    };
    if($@) {
        $class->DBIwarn("GetInits");
        return;
    }
    return map $_->[0], @{$sth->fetchall_arrayref};
} 

=head1 CURDATE() / CURTIME() / NOW()

Due to the way in which placeholders work under DBI, it's currently very
difficult to translate a query like the following to Class::DBI

  UPDATE foo
     SET flibble = "bar", since = CURDATE()

Rather than having to convert all your columns to timestamps, this module
allows you to specify CURDATE(), CURTIME() or NOW() as values:
  
  $foo->flibble("bar") and $foo->since("CURDATE()") and $foo->commit;

CAVEAT: Note that until you've called 'commit', the value of this
field will be set to this B<string>, and not the translation of it. For
objects which are going to make use of this feature, consider turning
autocommit on.

=cut

__PACKAGE__->set_sql('commitall', <<"", 'Main');
UPDATE %s
SET    %s
WHERE  %s = ?

{
  my @magic = qw/CURDATE() CURTIME() NOW()/;
  my %magic = map { $_ => 1 } @magic;

  sub _commit_line {
    my $self = shift;
    join ", ", map { 
      $magic{$self->{$_}} ? "$_ = $self->{$_}" : "$_ = ?";
    } $self->is_changed;
  }

  sub _commit_vals {
    my $self = shift;
    map { $magic{$self->{$_}} ? () : $self->{$_} } $self->is_changed;
  }
}

=head1 COPYRIGHT

Copyright (C) 2001 Tony Bowden. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Tony Bowden, E<lt>mysql@tmtm.comE<gt>.

=head1 SEE ALSO

L<Class::DBI>. MySQL (http://www.mysql.com/)

=cut

1;