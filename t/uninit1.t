# $Id: uninit1.t,v 1.1 2006/10/18 19:41:09 sullivan Exp $

package Foo;
use Test::More tests => 3;
BEGIN { use_ok('Class::Simple') };		##

use base qw(Class::Simple);

Foo->uninitialized();
my $f = Foo->new();
eval { $f->bar };
like($@, qr/is not set/, 'Uninitialized was caught.');
$f->set_snork(undef);
eval { $f->snork };
ok(!$@, 'Uninitialized is cool with undefs.');

1;
