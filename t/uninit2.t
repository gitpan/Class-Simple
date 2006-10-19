# $Id: uninit2.t,v 1.1 2006/10/18 19:41:14 sullivan Exp $

package Foo;
use base qw(Class::Simple);

Foo->uninitialized();

1;

package Foobie;
use base qw(Foo);

use Test::More tests => 2;
BEGIN { use_ok('Class::Simple') };

my $f = Foo->new();
eval { $f->bar };
like($@, qr/is not set/, 'Inherited uninitialized was caught.');

1;
