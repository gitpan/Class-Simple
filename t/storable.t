# $Id: storable.t,v 1.2 2007/12/31 19:59:36 sullivan Exp $
#
#	Testing the Storable hooks.

use Test::More tests => 4;
BEGIN { use_ok('Class::Simple') };				##

SKIP:
{
	eval { require Storable };
	skip('Storable not installed.', 1) if $@;

	my $f = Foo->new();
	$f->set_foo(12345);
	my $serialized = Storable::freeze($f);
	my $new_f = Storable::thaw($serialized);
	is($new_f->foo, 12345, 'Storable freezing and thawing seem to work'); ##

	my $g = Storable::dclone($f);
	is($g->foo, 12345, 'Storable cloning seems to work');	##
	$f->set_bar(345);
	isnt($g->foo, 345, 'Storable cloning did not just link'); ##
}

package Foo;
use base qw(Class::Simple);

1;
