# $Id: private2.t,v 1.2 2006/10/10 21:29:10 sullivan Exp $

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

use Test::More tests => 7;
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
$g->SLURP($str);
is($g->foo, TEST_STR, 'DUMP and SLURP seem to work');

Foobie->privatize(qw(moo));
eval { $g->bomp() };
diag($@) if $@;
ok(!$@, 'Privatizing does not work on ancestors');

eval { Foo->privatize(qw(snork)) };
# diag($@) if $@;
like($@, qr/privatize in your own class/,'Can only privatize in current class');

eval { $g->_mongo() };
like($@, qr/Private method/, '_mongo is private from Foobie');	##

1;
