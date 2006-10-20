#$Id: Simple.pm,v 1.11 2006/10/20 18:42:55 sullivan Exp $

package Class::Simple;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.03';

use Scalar::Util qw(refaddr);
use Carp;
use Class::ISA;

my %STORAGE;
my %PRIVATE;
my %READONLY;
my %TYPO;

our $AUTOLOAD;

sub AUTOLOAD
{
my $self = shift;

	no strict 'refs';

	$AUTOLOAD =~ /(.*)::(([^_]+)_)?(\w+)/;
	my $pkg = $1;
	my $full_method = $AUTOLOAD;
	my $prefix = $3 || '';
	my $attrib = $4;
	my $store_as = $attrib;
	$store_as =~ s/^_// unless $prefix;

	if ($prefix eq 'set')
	{
		*{$AUTOLOAD} = sub
		{
		my $self = shift;

			my $ref = refaddr($self);
			croak("$attrib is readonly:  cannot set.")
			  if ($READONLY{$ref}->{$store_as});
			return ($STORAGE{$ref}->{$store_as} = shift(@_));
		};
	}
	elsif ($prefix eq 'get')
	{
		*{$AUTOLOAD} = sub
		{
		my $self = shift;

			my $ref = refaddr($self);
			croak("$attrib is not set!")
			  if ($STORAGE{$ref}->{TYPO}
			   && !exists($STORAGE{$ref}->{$store_as}));
			return ($STORAGE{$ref}->{$store_as});
		};
	}
	elsif ($prefix eq 'clear')
	{
		my $setter = "set_$attrib";
		*{$AUTOLOAD} = sub
		{
		my $self = shift;

			return ($self->$setter(undef));
		};
	}
	elsif ($prefix eq 'raise')
	{
		my $setter = "set_$attrib";
		*{$AUTOLOAD} = sub
		{
		my $self = shift;

			return ($self->$setter(1));
		};
	}
	elsif ($prefix eq 'readonly')
	{
		my $setter = "set_$attrib";
		*{$AUTOLOAD} = sub
		{
		my $self = shift;

			my $ret = $self->$setter(@_);
			my $ref = refaddr($self);
			$READONLY{$ref}->{$store_as} = 1;
			return ($ret);
		};
	}
	#
	#	All methods starting with '_' can only be called from
	#	within their package.  Not inheritable, which makes
	#	the test easier than something privatized..
	#
	elsif (!$prefix && ($attrib =~ /^_/))
	{
		my $setter = "set_$store_as";
		my $getter = "get_$store_as";
		*{$AUTOLOAD} = sub
		{
		my $self = shift;

			croak("Cannot call $attrib:  Private method to $pkg.")
			  unless ($pkg eq Class::Simple::_my_caller());
			return (scalar(@_)
			  ? $self->$setter(@_)
			  : $self->$getter());
		};
	}
	else
	{
		my $setter = "set_$store_as";
		my $getter = "get_$store_as";
		*{$AUTOLOAD} = sub
		{
		my $self = shift;

			return (scalar(@_)
			  ? $self->$setter(@_)
			  : $self->$getter());
		};
	}
	return (&{$AUTOLOAD}($self, @_));
}



#
#	Call all the DEMOLISH()es and then delete from %STORAGE.
#
sub DESTROY
{
my $self = shift;

	$self->travel_isa('DESTROY', 'DEMOLISH');
	my $ref = refaddr($self);
	delete($STORAGE{$ref}) if exists($STORAGE{$ref});
	delete($READONLY{$ref}) if exists($READONLY{$ref});
}



#
#	Travel up the class's @ISA and run $func, if we can.
#	To keep from running a sub more than once we flag
#	$storage in %STORAGE.
#
sub travel_isa
{
my $self = shift;
my $storage = shift;
my $func = shift;

	my $ref = refaddr($self);
	$STORAGE{$ref}->{$storage}= {} unless exists($STORAGE{$ref}->{$storage});
	my @path = Class::ISA::super_path($self->CLASS);
	foreach my $c (@path)
	{
		next if ($c eq __PACKAGE__);
		next if $STORAGE{$ref}->{$storage}->{$c}++;

		my $cn = "${c}::can";
		if (my $in = $self->$cn($func))
		{
			$self->$in(@_);
		}
	}
	$self->$func(@_) if $self->can($func);;
}



#
#	Very simple.  Make a scalar, bless it, call init.
#
sub new
{
my $class = shift;

	#
	#	This is how you get an anonymous scalar.
	#
	my $self = \do{my $anon_scalar};
	bless($self, $class);
	$self->readonly_CLASS($class);

	foreach my $k (%TYPO)
	{
		next unless ($class)->isa($k);
		$self->readonly_TYPO(1);
		last;
	}

	$self->init(@_);
	return ($self);
}



#
#	Flag that this class should croak if an uninitialized attribute
#	is accessed.
#
sub uninitialized
{
my $class = shift;

	$TYPO{$class} = 1;
}



#
#	Flag the given method(s) as being private to the class
#	(and its children unless overridden).
#
sub privatize
{
my $class = shift;

	foreach my $method (@_)
	{
		no strict 'refs';

		#
		#	Can't privatize something that is already private
		#	from an ancestor.
		#
		foreach my $private_class (keys(%PRIVATE))
		{
			next unless $PRIVATE{$private_class}->{$method};
			croak("Cannot privatize ${class}::$method:  already private in $private_class.")
			  unless $private_class->isa($class);
		}

		#
		#	Can't retroactively make privatize something.
		#
		my $called_by = _my_caller();
		croak("Attempt to privatize ${class}::$method from $called_by.  Can only privatize in your own class.")
		  if ($class ne $called_by);
		$PRIVATE{$class}->{$method} = 1;

		#
		#	Although it is duplication of code (which I hope
		#	to come up with a clever way to avoid at some point),
		#	it is a better solution to have privatize() create
		#	these subs now.  Otherwise, having the private test
		#	done in AUTOLOAD gets to be fairly convoluted.
		#	Defining them here makes the tests a lot simpler.
		#
		my $getter = "${class}::get_$method";
		my $setter = "${class}::set_$method";
		my $generic = "${class}::$method";
		*{$getter} = sub
		{
		my $self = shift;

			no strict 'refs';
			croak("Cannot call $getter:  Private method to $class.")
			  unless $class->isa(Class::Simple::_my_caller());
			my $ref = refaddr($self);
			croak("$method is not set!")
			  if ($STORAGE{$ref}->{TYPO}
			   && !exists($STORAGE{$ref}->{$method}));
			return ($STORAGE{$ref}->{$method});
		};
		*$setter = sub
		{
		my $self = shift;

			no strict 'refs';
			croak("Cannot call $setter:  Private method to $class.")
			  unless $class->isa(Class::Simple::_my_caller());
			my $ref = refaddr($self);
			croak("$method is readonly:  cannot set.")
			  if ($READONLY{$ref}->{$method});
			return ($STORAGE{$ref}->{$method} = shift(@_));
		};
		*$generic = sub
		{
		my $self = shift;

			no strict 'refs';
			croak("Cannot call $generic:  Private method to $class.")
			  unless $class->isa(Class::Simple::_my_caller());
			my $ref = refaddr($self);
			return (scalar(@_)
			  ? $self->$setter(@_)
			  : $self->$getter());
		};
		my $ugen = "_${generic}";
		*$ugen = *$generic;
	}
}



#
#	Bubble up the caller() stack until we leave this package.
#
sub _my_caller
{
	for (my $i = 0; my $c = caller($i); ++$i)
	{
		return ($c) unless $c eq __PACKAGE__;
	}
	return (__PACKAGE__); # Shouldn't get here but just in case
}



#
#	This will not be called if the child classes have
#	their own.  In case they don't, this is a default.
#
sub init
{
my $self = shift;

	$self->travel_isa('init', 'BUILD', @_);
	return ($self);
}



use Data::Dumper;

sub DUMP
{
my $self = shift;
my $name = shift || 'obj';

	my $ref = refaddr($self);
	my $d = Data::Dumper->new([$STORAGE{$ref}], [$name]);
	return ($d->Dump());
}



sub SLURP
{
my $self = shift;
my $str = shift;

	return $self unless $str;

	my $obj;
	{
		$obj = eval "my $str";
	}

	my $ref = refaddr($self);
	$STORAGE{$ref} = $obj;

	return ($self);
}

1;
__END__

=head1 NAME

Class::Simple - Simple Object-Oriented Base Class

=head1 SYNOPSIS

  package Foo:
  use base qw(Class::Simple);

  INIT
  {
	Foo->privatize(qw(attrib1 attrib2)); # ...or not.
  }
  my $obj = Foo->new();

  $obj->attrib(1);     # The same as...
  $obj->set_attrib(1); # ...this.

  my $var = $obj->get_attrib(); # The same as...
  $var = $obj->attrib;          # ...this.

  $obj->raise_attrib(); # The same as...
  $obj->set_attrib(1);  # ...this.

  $obj->clear_attrib();    # The same as...
  $obj->set_attrib(undef); # ...this
  $obj->attrib(undef);     # ...and this.

  $obj->readonly_attrib(4);

  sub foo
  {
  my $self = shift;
  my $value = shift;

    $self->_foo($value);
    do_other_things(@_);
    ...
  }

  my $str = $obj->DUMP;
  my $new_obj = Foo->new();
  $new_obj->SLURP($str);

  sub BUILD
  {
  my $self = shift;

    # Various initializations
  }

=head1 DESCRIPTION

This is a simple object-oriented base class.  There are plenty of others
that are much more thorough and whatnot but sometimes I want something
simple so I can get just going (no doubt because I am a simple guy)
so I use this.

What do I mean by simple?  First off, I don't want to have to list out
all my methods beforehand.  I just want to use them (Yeah, yeah, it doesn't
catch typos--that's what testing and Class::Std are for :-).
Next, I want to be able to
call my methods by $obj->foo(1) or $obj->set_foo(1), by $obj->foo() or
$obj->get_foo().  Don't tell ME I have to use get_ and set_ (I would just
override that restriction in Class::Std anyway).  Simple!

I did want some neat features, though, so these are inside-out objects
(meaning the object isn't simply a hash so you can't just go in and
muck with attributtes outside of methods),
privatization of methods is supported, as is serialization out and back
in again.

It's important to note, though, that one does not have to use the extra
features to use B<Class::Simple>.  All you need to get going is:

	package MyPackage;
	use base qw(Class::Simple);

And that's it.  To use it?:

	use MyPackage;

	my $obj = MyPackage->new();
	$obj->set_attr($value);

Heck, you don't even need that much:

	use Class::Simple;

	my $obj = Class::Simple->new();
	$obj->set_attr($value);

I don't know why one would want to use an anonymous object but you can.

=head2 Garbage Collection

Garbage collection is handled automatically by B<Class::Simple>.
The only thing the user has to worry about is cleaning up dangling
and circular references.

Example:

	my $a = Foo->new();
	{
		my $b = Foo->new();
		$b->set_yell('Ouch!');
		$a->next = $b;
	}
	print $a->next->yell;

Even though B<$b> goes out of scope when the block exits,
B<$a->next()> still refers to it so B<DESTROY> is never called on B<$b>
and "Ouch!" is printed.
Why is B<$a> referring to an out-of-scope object in the first place?
Programmer error--there is only so much that B<Class::Simple> can fix :-).

=head1 METHODS

=head2 Class Methods

=over 4

=item B<new()>

Returns the object and calls B<BUILD()>.

=item B<privatize(>qw(method1 method2 ...B<)>

Mark the given methods as being private to the class.
They will only be accessible to the class or its ancestors.
Make sure this is called before you start instantiating objects.
It should probably be put in a B<BEGIN> or B<INIT> block.

=item B<uninitialized()>

Did I say we can't catch typos?
Well, that's only partially true.
If B<uninitialized()> is called, any attempt to access an attribute
that has not been defined (even if that definition is B<undef>)
will result in a fatal error.
So we won't catch typos on sets but we will on gets
(and if you typo a set, the error on the get will be a good clue).

=back

=head2 Optional User-defined Methods

=over 4

=item B<BUILD()>

If there is initialization that you would like to do after an
object is created, this is the place to do it.

=item B<DEMOLISH()>

If you want to write your own DESTROY, don't.
Do it here in DEMOLISH, which will be called by DESTROY.

=back

=head2 Object Methods

=over 4

=item B<init()>

I lied above when I wrote that B<new()> called B<BUILD()>.
It really calls B<init()> and B<init()> calls B<BUILD()>.
Actually, it calls all the B<BUILD()>s of all the ancestor classes
(in a recursive, left-to-right fashion).
If, for some reason, you do not want to do that,
simply write your own B<init()> and this will be short-circuited.

=item B<DUMP(>['name']B<)>

Return a serialization of the given object.
If the optional 'name' parameter is given, the variable in the serialization
will be named 'name'.  Otherwise it will be named 'obj'.

=item B<SLURP(>$strB<)>

Put the given B<DUMP()> output into the object.
Obviously someone can short-circuit things by manipulating a B<DUMP()>
and B<SLURP()>ing that in.
If you're that paranoid and/or your users are that sneaky,
perhaps you shouldn't use a module as simple as this.

=item B<CLASS>

The class this object was blessed in.
Really used for internal housekeeping but I might as well let you
know about it in case it would be helpful.
It is readonly (see below).

=back

If you want an attribute named "foo", just start using the following
(no pre-declaration is needed):

=over 4

=item B<foo(>[val]B<)>

Without any parameters, it returns the value of foo.
With a parameter, it sets foo to the value of the parameter and returns it.
Even if that value is undef.

=item B<get_foo()>

Returns the value of foo.

=item B<set_foo(>valB<)>

Sets foo to the value of the given parameter and returns it.

=item B<raise_foo()>

The idea is that if foo is a flag, this raises the flag by
setting foo to 1 and returns it.

=item B<clear_foo()>

Set foo to undef and returns it.

=item B<readonly_foo(>valB<)>

Set foo to the given value, then disallow any further changing of foo.
Returns the value.

=item B<_foo(>[val]B<)>

If you have an attribute foo but you want to override the default method,
you can use B<_foo> to keep the data.
That way you don't have to roll your own way of storing the data,
possibly breaking inside-out.
Underscore methods are automatically privatized.

=back

=head1 CAVEATS

If an ancestor class has a B<foo> attribute, children cannot have their
own B<foo>.  They get their parent's B<foo>.

I don't actually have a need for DUMP and SLURP but I thought they
would be nice to include.
If you know how I can make them useful for someone who would actually
use them, let me know.

=head1 SEE ALSO

L<Class::Std> is an excellent introduction to the concept
of inside-out objects in Perl
(they are referred to as the "flyweight pattern" in Damian Conway's
I<Object Oriented Perl>).
Many things here, like the name B<DEMOLISH()>, were shamelessly stolen from it.
Standing on the shoulders of giants and all that.

=head1 AUTHOR

Michael Sullivan, E<lt>perldude@mac.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Michael Sullivan

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
