# Overview 

You have questions? We have answers. Note that this is a work-in-progress.
More may be added later.

## Why can't I inherit from blessed objects?

Post-MVP this decision might be revisited, but for the MVP, we needed to
constrain the problem space. Just some of the issues being faced:

* `class` will understand the difference between methods and subroutines and
  when the MVP is more fleshed out, will not allow you to call subroutines as
  methods. What do you do when the parent class is `blessed`ed and all you
  have are subs?
* `class` is single-inheritance and `bless` is multiple inheritance. Having to
  switch the MRO back and forth as you walk the inheritance hierarchy is
  begging for bugs.
* Ultimately, `class` might need a different base class, such as
  `UNIVERSAL::Class`. If we inherit from a `bless`ed object, which base class
  wins?
* Many awesome tools have been written for
  [Moose](https://metacpan.org/pod/Moose) and they assume
  [Class::MOP](https://metacpan.org/pod/Class::MOP) works. We cannot make that
  assumption, so we don't.

Post-MVP, we might revision this decision, but for the MVP, there's a huge
amount of work to do and trying to make sure we didn't screw up anywhere is
much harder if we try to slurp in the entire `bless`ed ecosystem. Bear with
us.

Otherwise, you can try the [Object::Pad](https://metacpan.org/pod/Object::Pad)
module. That's been the test bed for Corinna and it _does_ allow inheriting
from legacy objects. Caveat Emptor.

## But I _need_ to inherit from a blessed object!

No, you can't. Sorry. You can try `Object::Pad`, not use `class`, or
investigate composition over inheritance:

```perl
class My::Class;
    use Some::Bless::Class;

    field $arg_for_blessed :param(arg);
    field $delegate = Some::Bless::Class->new($arg_for_blessed);

    method to_delegate (@args) {
        return $delegate->some_method(@args);
    }
}
```

None of those answers are satisfactory, but this is an MVP.

## Why can't I use subroutines for methods?

If you write this:

```perl
class My::Class {
    field $name;
    sub get_name ($self) { $name }
}
```

That's a syntax error because we can't access the instance variable `$name`
from a subroutine. They don't know what instance variables are. Or consider
these;

```perl

class Example1 {
    sub sum ($self) { ... }
}

class Example2 {
    use List::Util 'sum';
}
```

In both cases, we have a `sum` subroutine, but for the first, it's clearly
intended to be a method and not a helper function. From the outside, we have
no way of knowing that. `class` makes a clear distinction between methods and
subroutines and when the MVP is complete, `$class->can('sum')` should return
false if `sum` is a subroutine and not a method.

## Will `class` break existing code?

No. Well, if you tried to slap it into an existing procedural code and you had subroutines
with conflicting names to the keywords, _maybe_. Or you could use a lexical
block and it should be perfectly safe:

```perl
# lots of code here
{
    use feature 'class';
    class Foo ...
}
# more code here, but it doesn't see `class` behavior
```

Otherwise, `class` objects can call methods on `bless` objects and vice-versa
without problem.

## How can I rewrite existing objects with `class`?

Er, you probably shouldn't. If you wanted to experiment, keep this in mind: A
`class` cannot inherit from `bless`ed objects, but as of this writing, a
`bless`ed object _can_ inherit from a `class` object. So go to the root of
your object hierarchy and look at converting that to a `class` and see what
happens.

For any decent-sized system, you're going to have too many edge cases for this
to be easy (or sane). For example, `class` constructors require an even-sized
list of key/value pairs. Many other constructors don't. You may need to
rethink your constructor strategy.

At the end of the day, trying to gradually mix-and-match an OOP hierarchy from `bless`
to `class` is like trying to use motorcycle parts to fix a car. Maybe you'll
get lucky and it works, but probably not for larger codebases (at least, not
without a lot of heavy lifting).

## Are there any interesting projects being written with `class`?

Yes! Check out Chris "peregrin" Prather's [Rougelike
tutorial](https://chris.prather.org/menu/roguelike). It's pretty amazing and
shows that `class` is more powerful than your author suspected (I thought we'd
need more features to get this far. I was wrong).

Stevan "damnit" Little is writing [Stella](https://github.com/stevan/Stella),
an actor model written with `class`. So far, he's been very pleased with how
easy `class` is to work with.

## Is there a tutorial?

There's a tutorial at
[perlclasstut.pod](https://github.com/Ovid/Cor/blob/master/pod/perlclasstut.pod).

Note that this tutorial is for the full MVP. If you're reading this before the
full MVP is released, some of the features in that tutorial won't yet be
working. I don't know what version of Perl you have installed, so you'll need
to consult your documentation.

If you prefer, [here's a gist of the tutorial, formatted via
markdown](https://gist.github.com/Ovid/4cc649c1eb3142b6a856d94c54b1d4ed). It's
not guaranteed to be kept up-to-date.
