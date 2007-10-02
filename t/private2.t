# $Id: private2.t,v 1.9 2007/10/02 23:04:48 sullivan Exp $

package Foo;
use base qw(Class::Simple);

Foo->privatize(qw(bar));
my $foo = Foo->new();
sub bomp
{
my $self = shift;

	$self->moo(1);
}
$foo->_mongo(1);

1;

package Foobie;
use base qw(Foo);

use Test::More tests => 13;
BEGIN { use_ok('Class::Simple') };

my $f = Foobie->new();
eval { $f->bar(1) };
# diag($@) if $@;
like($@, qr/Private method/, 'bar is private from Foobie');	##
eval { Foobie->privatize(qw(bar)) };
# diag($@) if $@;
like($@, qr/already private/, 'cannot privatize bar in Foobie');

use constant TEST_STR => 'abcdef';
$f->foo(TEST_STR);
my $str = $f->DUMP('moo');
# diag("dump is $str");
my $g = Foobie->new();
ok(!$g->SLURP('foo'), 'SLURP caught bad input');		##
$g->SLURP($str);
is($g->foo, TEST_STR, 'DUMP and SLURP seem to work');		##

SKIP:
{
	eval { require JSON::XS };
	skip('JSON::XS not installed.', 1);

	my $js = $f->toJson();
	my $jsF = Foobie->new();
	$jsF->fromJson($js);
	is($jsF->foo, TEST_STR, 'toJson and fromJson seem to work');	##
}

Foobie->privatize(qw(moo));
eval { $g->bomp() };
diag($@) if $@;
ok(!$@, 'Privatizing does not work on ancestors');

eval { Foo->privatize(qw(snork)) };
# diag($@) if $@;
like($@, qr/privatize in your own class/,'Can only privatize in current class');

eval { $g->_mongo() };
like($@, qr/Private method/, 'Reading _mongo is private from Foobie');	##
eval { $g->_mongo(2) };
like($@, qr/Private method/, 'Setting _mongo is private from Foobie');	##
eval { $g->set__mongo(3) };
like($@, qr/Private method/, 'set__mongo is private to Foobie');	##
eval { $g->get__mongo };
like($@, qr/Private method/, 'get__mongo is private to Foobie');	##


sub set_recurse
{
my $self = shift;

	return ($self->_recurse(@_));
}

my $rec = Foobie->new();
eval { $rec->_recurse(1) };
diag($@) if $@;
ok(!$@, 'Defining own set_foo and using _foo works.');		##

1;
