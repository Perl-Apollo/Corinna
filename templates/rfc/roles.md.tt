# Background

Roles in Corinna are based on the [Traits, composable units of
behavior](http://scg.unibe.ch/archive/papers/Scha02bTraits.pdf)
paper, we particularly find interest in [Traits: the formal
model](http://scg.unibe.ch/archive/papers/Scha02cTraitsModel.pdf).

In particular, according to the formal model, traits are designed to be both
commutative (`a+b=b+a`) and associative (`(a+b)+c=a+(b+c)`). While we cannot
perfectly guarantee this in the face of method modifiers, we will see to
return to this model.

# Overview

Roles are designed to share small sets of behaviors which address
cross-cutting concerns. Roles may consume other roles, but they may not
inherit from classes, nor may they be inherited from.

```
ROLE        ::= 'role' NAMESPACE ROLES
                DECLARATION BLOCK
NAMESPACE   ::= IDENTIFIER { '::' IDENTIFIER } VERSION?
DECLARATION ::= ROLES?
ROLES       ::= 'does' NAMESPACE { ',' NAMESPACE } ','?
IDENTIFIER  ::= [:alpha:] {[:alnum:]}
VERSION     ::= 'v' DIGIT {DIGIT} '.' DIGIT {DIGIT} '.' DIGIT {DIGIT}
DIGIT       ::= [0-9]
BLOCK       ::= # Perl +/- Extras
```

Roles may require one or more methods to be implemented. All abstract methods
in roles are considered to be required. For Corinna, any forward declaration
of a method is considered an abstract method.

```perl
role SomeRole {
    method foo();
    common method bar ();
    abstract method baz (); # abstract is optional
    ...
}
```

Any non-private methods with method bodies are considered to be methods the
role provides. These may be both class and instance methods.

```perl
role SomeRole P
    method foo ()         { ... } # instance method provided
    common method bar ()  { ... } # class method provided
    private method baz () { ... } # private methods are not provided
}
```

Any slots declared in the role are completely private unless standard
slot attributes are used.

```perl
role SomeRole {
    has $name :reader; # ->name is provided
    has $age;          # private to this role
}
```

Roles may _not_ access the slots or methods of the class the
role is consumed into unless those have already been exposed in the public
interface.

# Example

It is entirely possible, for example, to want to have an identical mechanism
to provide unique, repeatable UUIDs to different classes. It might look like
this:

```perl
role Role::UUID {
    use Data::UUID;

    # these are private to this role
    common $uuid           = Data::UUID->new;
    common $namespace_uuid = $uuid->create_str;

    # abtract methods in roles are required
    method name();

    method uuid () {
        return $uuid->create_from_name_str( $namespace_uuid, $self->name );
    }
}
```

And to use that in your class:

```perl
class Person does Role::UUID {
    has $name :param :reader;
}
```

And using that:

```perl
my $alice = Person->new(name => 'Alice');
say $alice->uuid;
```

The above will create a unique, repeatable UUID for a given `Person.name`
(only repeats in a single process due to how UUIDs work).

Roles may consume other roles and classes may consume one or more roles. Any
method name conflicts are fatal, if and only if the methods come from
different namespaces.

```perl
role A does C { method a () { ... } }
role B does C { method b () { ... } }
role C        { method c () { ... } }

class SomeClass does A, B { ... }
```

Thus, in the above example, though A and B both pull in the `c()` method from
role C, there is no conflict because it is the same method.

However, if `SomeClass` defined a `c()` method, there will be a conflict.

# Aliasing and Excluding

For the MVP, we will not be providing aliasing and excluding of methods.

# `ADJUST` and `DESTRUCT`

Both the `ADJUST` and `DESTRUCT` [phasers](phasers.md) will be allowed in
roles. Class `ADJUST` phasers are called before its roles `ADJUST` phasers
which are called before child `ADJUST` phasers and its roles phaswers.

`DESTRUCT` role phasers are called before class `DESTRUCT` phasers which are
called before parent `DESTRUCT` phasers.

**Important**: for a given level of the inheritance hierarchy, if more than
one role is consumed, the order in which its `ADJUST` and `DESTRUCT` phasers
are called is not guaranteed.
