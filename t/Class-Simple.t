# $Id: Class-Simple.t,v 1.3 2006/10/19 17:40:40 sullivan Exp $
#
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Class-Simple.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 45;
BEGIN { use_ok('Class::Simple') };

#########################

my $destroyed;
INIT
{
	$destroyed = 0;
}

sub run_tests
{
my $f = shift;
my $package = shift;

	diag("Package is $package.");
	isa_ok($f, $package);					##
	can_ok($f, 'new');					##
	can_ok($f, 'privatize');				##
	can_ok($f, 'uninitialized');				##
	can_ok($f, 'DESTROY');					##
	can_ok($f, 'AUTOLOAD');					##
	can_ok($f, 'DUMP');					##
	can_ok($f, 'SLURP');					##
	
	is($f->zomba, 333, 'BUILD initialized');		##
	$f->foo(1);
	can_ok($f, 'foo');					##
	is($f->foo, 1, 'set with bare word');			##
	is($f->set_foo(2), 2, 'set returns right thing');	##
	is($f->foo, 2, 'returns with bare word');		##
	is($f->get_foo, 2, 'returns with get');			##
	$f->clear_foo();
	ok(!$f->get_foo, 'unset');				##
	$f->raise_foo();
	ok($f->get_foo, 'raise');				##
	
	eval { $f->bar(1) };
	ok($@, 'bar is private in main');			##
	my $h2;
	$main::destroyed = 0;
	{
		my $h = $package->new();
	}
	is($main::destroyed, 1, 'destroyed');			##

	is($f->readonly_chumba(2), 2, 'readonly set');
	is($f->chumba, 2, 'readonly set set the val');		##
	eval { $f->set_chumba(4) };
	like($@, qr/readonly/, 'setting a readonly fails');	##
	is($f->chumba, 2, 'readonly still set');		##
}


package Foo;
use base qw(Class::Simple);

Foo->privatize(qw(bar));
my $f = Foo->new();
main::run_tests($f, __PACKAGE__);

sub DEMOLISH
{
	$main::destroyed = 1;
}

sub BUILD
{
my $self = shift;

	$self->zomba(333);
}

1;


#
#	Inheritance
#

package Foobie;
use base qw(Foo);

my $fb = Foobie->new();
main::run_tests($fb, __PACKAGE__);

1;
