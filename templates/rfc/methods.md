# Overview

Corinna offers class methods and instance methods. You must also specify if
they override a parent method.

# Instance Methods

Instance methods are defined via `method $identifier (@args) { ... }`.  They
automatically have `$class` and `$self` variables injected into them. `$class`
contains the name of the class from which this method was called. `$self` is
an instance of the current class.

```perl
method name () {
    return defined $title ? "$title $name" : $name;
}
```

Instance methods can access both class data and instance data and call both
instance and class methods.

# Class Methods

Class methods are defined via `method $identifier :common (@args) { ... }`.
They automatically have a `$class` variable injected into them. This contains
the name of the class from which this method was called.

```perl
method foo :common () {
    say "We were called via the $class class";
}
```

Class methods cannot call instance methods (since they have no `$self`) and
referencing instance data in a class method should be a compile-time error.
Ths includes trying to reference `$self` in a class method.

# Overridden Methods

If a method in the current class overrides a method in a parent class, a warning
will be issued. To suppress that warning, use `:overrides`.

```perl
method name :overrides () {
    ...
}
```

Note that instance methods can only override instance methods and class
methods can only override class methods.

# Abstract Methods

Abstract methods are declared as forward declarations. That is, methods
without a method body.

```perl
method foo;
method bar :common;
```

They have two uses. Any class with an abstract method must declare itself as
abstract. Failure to do so would be a compile-time failure.

Abstract methods declared in [roles](roles.md) are "required" methods that
must be implemented by the consuming class or by other roles consumed at the
same time.

*Important* abstract methods must not be listed with arguments. These are a
syntax errors:

```perl
method foo ();
method bar ($baz);
```

## Checking Abstract Methods

When compiling code containing abstract methods, the check to see if the
method is overridden it should be compile time for a class and composition
time for a role. You should be able to compile an abstract class itself with a
standard `perl -c` check, but any class which inherits from the abstract class
and doesn't override the methods would either need to be declared `abstract`
or have a compile-time failure.

# Private Methods

Private methods are declared with the `private` keyword:

```perl
method foo :private () {...}
method bar :private :common () {...}
```

Private methods can only be called from methods defined in the namespace and file at _compile time_

* Private methods are not inherited
* If a class or role has a `:private` method with the name matching the name of
  the method being called, the dispatch is to that method.
* Even if a subclass has a public or private method with the same signature,
  the methods in a class will call its private method, not the inherited one
* Roles and classes cannot call each other's private methods

Note that this means:

* For the MVP, roles cannot require private methods
* A role's private methods can never conflict with another role or class's private methods
* You cannot use `:overrides` and `:private` on the same method

## Private Methods in Roles

There is nothing special about private methods in roles, but they are _not_
flattened into the consuming class and cannot conflict with class methods.
Private methods are bound to the namespace in which they are declared. This
gives us great encapsulation, but does it require the method be bound at
compile-time rather than runtime? If so, does Perl even support that? Or do we
need to do a runtime check every time?

Thus:

```
role SomeRole {
    method role_method () { $self->do_it }
    method do_it :private () { say "SomeRole" }
}
class SomeClass does SomeRole {
    method class_method () { $self->do_it }
    method do_it :private () { say "SomeClass" }
}
my $object = SomeClass->new;
say $object->class_method;
say $object->role_method;
```

The above `do_it` role does not conflict because it's not provided by the role.
It's strictly internal. Further, it cannot be aliased, excluded, or renamed by
the consumer. This gives role authors the ability to write a role and have
fine-grained control over its behavior. This is in sharp contrast to Moo/se:

```perl
#!/usr/bin/env perl
use Less::Boilerplate;

package Some::Role {
    use Moose::Role;
    use Less::Boilerplate;
    sub role_method ($self) { $self->_foo }
    sub _foo ($self)        { say __PACKAGE__ }
}

package Some::Class {
    use Moose;
    use Less::Boilerplate;
    with 'Some::Role' => { -exclude => '_foo' };
    sub _foo ($self) { say __PACKAGE__ }
}

Some::Class->role_method;
```

The above prints `Some::Class` even though the role author may have been
expecting `Some::Role`. So private methods are a huge win here.
