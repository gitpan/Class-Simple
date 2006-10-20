# $Id: private3.t,v 1.1 2006/10/20 17:36:04 sullivan Exp $

package Foo;
use base qw(Class::Simple);

Foo->privatize(qw(bar));

1;

package Bar;
use base qw(Class::Simple);

1;

use Test::More tests => 6;
BEGIN { use_ok('Class::Simple') };			##

my $bar = Bar->new();
eval { $bar->set_bar(1) };
diag($@) if $@;
ok(!$@, 'Privatization separates classes.');		##

Bar->privatize(qw(milk hamburger));
Bar->uninitialized();

my $cow = Bar->new();
ok($cow, 'We have a cow, man.');			##
$cow->readonly_milk(1);
ok($cow->milk, "Cow's milk is okay, man.");		##
eval { $cow->set_milk(2); };
like($@, qr/readonly/, "Don't mess with a cow's milk, man.");	##

eval { $cow->hamburger };
like($@, qr/not set/, 'Hamburger is not set first.');	##
