At the present time, some final details of phasers are still being decided.
For Corinna, we have two new phasers, `ADJUST` and `DESTRUCT`.

# `ADJUST`

The `ADJUST` phaser is called just after object construction (`new(..)`) but
before the object is returned. This allows the developer to apply additional
logic which cannot be cleanly represented by merely assigning values to fields.

All class and instance data is available in the `ADJUST` phaser.

#  `DESTRUCT`

The `DESTRUCT` phaser is called when the current instance goes out of scope.

```perl
DESTRUCT {
    if  ( 'DESTRUCT' eq ${^GLOBAL_PHASE} ) {
        ...
    }
    ...
}
```

There is ongoing discussion about whether a boolean "in global destruction"
argument should be provided, or a possible destruction object should be
provided. However, no phases currently take arguments, so it's an open
question.

One possible use of a destruction object is that it could check if a
`PERL_DESTRUCT_TRACE` (or similar)  environment variable is true and capture a
stack trace of where it went out of scope. This would be very useful for
debugging.

## Deterministic Destruction

Currently, `DESTROY` run on standard Perl objects tends to destroy your state
in random order. It's easy to try to use the object in `DESTROY` and find that
it's incomplete.

In Corinna, fields are indended to be destroyed in reverse order of
declaration, instance fields and then class (common) fields, from parent to
child. Consider the following (note that the syntax for `:common` might
change):

```perl
class Parent {
    field $one;
    field $two;
    field $three :common;
}

class Child :isa(Parent) {
    field $four;
    field $five :common;
    field $six;
}
```

The destruction order should be guaranteed to be:

1. `$six`
2. `$four`
3. `$five` # class data
4. `$two`
5. `$one`
6. `$three` # class data

## Incomplete Destruction

Sometimes you have code that *must* use a `DESTRUCT`, but it's unclear if the
object has been set up properly (perhaps it through an exception in `ADJUST`,
for example). Running `DESTRUCT` on data that doesn't exist is fraught with
bugs. The following  is one way of handling that:

```perl
class MyClass {
    field $constructed;

    ADJUST {
        ...
        $constructed = 1;
    }

    DESTRUCT {
        return unless $constructed;
        ...
    }
}
```

# Phaser Call Order

Class `ADJUST` phasers are called on the root class before its roles `ADJUST`
phasers which are called before child `ADJUST` phasers and its roles phaswers.

`DESTRUCT` role phasers are called before class `DESTRUCT` phasers which are
called before parent `DESTRUCT` phasers.

**Important**: for a given level of the inheritance hierarchy, if more than
one role is consumed, the order in which its `ADJUST` and `DESTRUCT` phasers
are called is not guaranteed. This is deliberate to prevent people from
assuming they can rely on role consumption order.
