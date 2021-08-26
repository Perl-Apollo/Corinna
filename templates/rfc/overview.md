Pursuant to [the new RFC process Perl is experimenting with](https://github.com/Perl/RFCs), we will create an RFC for Corinna.

This is an incomplete WIP that will be worked on as we have time. It is VERY alpha.

---

# Preamble

    Author:  Curtis "Ovid" Poe <curtis.poe@gmail.com>
    Sponsor: Paul "LeoNerd" Evans
    ID:      OVID
    Status:  Proposal
    Title:   Corinna—Bring Effective Object-Oriented Programming (OOP) to the Perl core

# Abstract

It's time to bring effective OOP to the Perl core, but we still plan to keep Perl being Perl.

# Motivation

I'm going to be blunt, and then I'll move on.

> Inside the echo chamber: "It's so easy to do X in Perl that there's no need to add X to core."
> 
> Outside the echo chamber: "Perl's missing many features that modern languages need."

The above points of view are not attracting people to the Perl language. I believe we're losing more developers than we gain. It's time to turn that around.

Moving along ...

Depending on what you call an OOP system, the CPAN appears to have 80+ contenders. It's a bewildering array of buggy, half-implemented systems. Even the best of them have limitations, largely imposed by the Perl language itself. If you've not already done so, I strongly recommend reading [The Lisp Curse](http://winestockwebdesign.com/Essays/Lisp_Curse.html). That explains our mess in spades.

We're trying to solve the ever-present problem with "what OOP system do I use?" coupled with "Perl looks ancient."

Existing syntax is hurting Perl, not helping it. While we don't propose changing or removing `bless`, it's the "assembly language of OO." It allows you to build powerful things on top of it, but everyone who does is spending time repeating lots of boilerplate code, rewriting the same bugs, and implementing different OO systems with different semantics, making it harder for a developer to learn the quirks.

Of the existing CPAN modules, Moo/se seems to have won, but they have numerous issues, partly due to limitations imposed by the Perl language itself.

# Rationale

The syntax of Corinna is clear, concise, and makes it easier to write safe code, along with avoiding some of the mistakes inherent in Moo/se. Further, by having a clear set of semantics up front, once developers "learn" Corinna syntax, it's the same everywhere. Java was designed to be portable across architectures. Corinna is designed to be portable across developers.

But why not another system? As we understand it, Moose has already been rejected because it would pull in a large number of modules into the Perl core and P5P does not wish to maintain them.

Moo is faster and smaller, but thanks to how the `meta` method works, it's easy to try metaprogramming and get your Moo class inflated to Moose. Thus, including Moo in the core would force us to either include Moose or to break backwards compatibility.

Further, Moo/se:

* Uses blessed hashrefs and this doesn't encapsulate/isolate your data
* The attributes make it hard to _not_ expose them to consumers (including subclasses), making it more difficult to minimize your contract
* It's natural to write mutable objects in Moo/se, creating reference structures with strange action at a distance
* Moo/se _encourages_ creating "builders" which allow [subclasses to override parent class data which should be private](https://ovid.github.io/articles/the-problem-with-builder.html)
* Due to legacy code, we have to allow both hashrefs and key value pairs in constructors, unnecessarily complicating the implementation and breaking poorly-implemented `BUILDARGS`.

There's more which can be said, but the Moo/se issues have taught us a huge amount about what we would like in OO, but come with considerable baggage. I'm sure we can easily troll through the innumerable alternatives on the CPAN and find similar issues.

Stevan Little's [Moxie](https://metacpan.org/pod/Moxie) is of great interest, but the syntax is unfortunate and it's still tied to Perl's limitations.

# Specification

The specification would be daunting for the RFC. It's largely based on [our MVC description](https://github.com/Ovid/Cor/wiki/Corinna-Overview) and the [Object::Pad](https://metacpan.org/pod/Object::Pad) test suite.

There a few signficant things worth noting, First, Corinna is only single inheritance. Code reuse of OO behavior is done via compositing roles or delegation. Corinna offers native support for delegation:

```
slot $created :handles(*) = DateTime->now;
```

[The full grammar of the Corinna MVC can be found here](grammar.md).

# Backwards Compatibility

Currently, Corinna's syntax is generally backwards-compatible because the code does not parse on older Perls that `use strict`. This is helped tremendously by requiring a postfix block syntax which encapsulates the changes, rather than the standard `class Foo is Bar; slot ...` syntax.

```
$ perl -Mstrict -Mwarnings -E 'class Foo { slot $x; }'
Global symbol "$x" requires explicit package name (did you forget to declare "my $x"?) at -e line 1.
syntax error at -e line 1, near "; }"
Execution of -e aborted due to compilation errors.
```

Various incantations all cause the same failures. If `strict` is not used, you will get runtime failures with strange error messages due to indirect object syntax:

```
$ perl -e 'class Foo { slot $x }'
Can't call method "slot" on an undefined value at -e line 1.
```

In an unlikely case, you use `strict` but you have an empty class or role body, you will also get errors due to indirect object syntax because Perl will think the block delimiters, `{ ... }` are a hashref and not a block.

In an edge case, if have `class Foo { ... }` and you _already_ have a class by that name defined (and loaded) elsewhere, then Perl will try an indirect object method call and that might succeed, leading to strange errors:

```perl
package Foo {
    sub class { print "darn it\n" }
};

class Foo {}  # prints "darn it"
```

Note that we also intend for the block to have strict and warnings, along with disabling indirect method calls. Because those pragmas are file scoped without a block, requiring a block limits the damage, so to speak.

As for tooling, we hope that [`B::Deparse`](https://metacpan.org/pod/B::Deparse), [`Devel::Cover`](https://metacpan.org/pod/Devel::Cover), and [`Devel::NYTProf`](https://metacpan.org/pod/Devel::NYTProf), won't be impacted too strongly. However, this has not yet been tested.

[`PPI`](https://metacpan.org/pod/PPI) (and thus [`Perl::Critic`](https://metacpan.org/pod/Perl::Critic) and friends) will be impacted, but we have defined a regular grammar for Corinna, making parsing much easier.

Paul "LeoNerd" Evans intends to release `Feature::Compat::Class` along the same lines as [`Feature::Compat::Try`](https://metacpan.org/pod/Feature::Compat::Try). That would allow Corinna to be accessible to Perls as old as v5.18.0 (the earliest Perl version that supports Object::Pad).

# Security Implications

Most of what we plan leverages Perl's current capabilities, but with a different grammar. We don't anticipate particular security issues. In fact, due to increased encapsulation, Corinna might actually be a bit more secure (in terms of data it exposes).

# Examples

Here is an LRU cache demonstrating many of the features of Corinna (but not roles):

```perl
use feature 'class';

class Cache::LRU v0.1.0 {
    use Hash::Ordered;
    use Carp 'croak';

    my $num_caches                                 = 0;
    slot    $cache     :handles(qw/exists delete/) = Hash::Ordered->new;
    slot    $max_size  :param  :reader             = 20;
    slot    $created   :reader                     = time;

    ADJUST { # called after new()
        $num_caches++;
        if ( $max_size < 1 ) {
            croak(...);
        }
    }
    DESTRUCT ($destruction) { $num_caches-- }

    common method num_caches () { $num_caches }

    method set ( $key, $value ) {
        if ( $self->exists($key) ) {
            $self->delete($key);
        }
        elsif ( $cache->keys > $max_size ) {
            $cache->shift;
        }
        $cache->set( $key, $value );  # new values in front
    }

    method get($key) {
        if ( $self->exists($key) ) {
            my $value = $cache->get($key);
            $self->set( $key, $value );  # put it at the front
            return $value;
        }
        return;
    }
}
```

# Prototype Implementation

Paul "LeoNerd" Evans has been using [Object::Pad](https://metacpan.org/pod/Object::Pad) as a test bed for many of these ideas, though he's included many things we don't intend for V1. However, we understand that Object::Pad is already stable enough that at least [one company is using it in production](https://metacpan.org/pod/Myriad). [Here's an great discussion of what they discovered](https://www.reddit.com/r/perl/comments/nyuid5/were_starting_the_rfc_for_bringing_modern_oo_to/h1plagk/).

# Benefits of this approach

## Compile-time failures

In Moo/se and alternatives, calling `$self->{feild}` is often a silent failure leading to mysterious bugs. Calling `$self->feild` is a runtime failure. In Corinna, accessing an non-existent `$feild` is a compile-time failure:

```perl
slot $field;

method foo () {
    say $feild; # compile-time failure, baby!
}
```

## Encapsulation

No more getting a 3AM phone call because a batch job failed due to some dev writing `$object->{sekret}->do_stuff`. In Corinna, class and instance data is _fully_ encapsulated unless you choose to explicitly make it public.

## Less Code

Every code example I've written in Corinna is much smaller than raw Perl or even Moo/se. The production company above mentioned that their classes appear to be 10% smaller with Object::Pad.

Because Corinna is largely declarative and requires writing less code, almost by definition, you write fewer bugs. And that makes it easier to understand, too.

## Cleaner Interfaces

In Moo/se, it's hard to create attributes in such a way that you don't publicly expose them in some way. This means that they become part of your contract and if you need to change them later, too bad. In Corinna, we expose _no_ attributes by default. You have to explicitly do that. This is because, unlike Moo/se's `has`, the `slot` in Corinna declares the slot and nothing else.

## No MRO Pain

Due to single inheritance, MRO complications go away. Paul Evans has already reported that it's easier to implement with single inheritance and this implies there will be fewer bugs.

# FAQ

## Why not Moo/se or alternatives in the core?

The MVP for Corinna is designed to be the smallest possible _useful_ OOP that we can get into the Perl core. We don't want to do too much in the MVP, lest we get tied down with bad design decisions we can't easily walk back. The best alternatives we see now are very feature complete and thus might violate the idea of "minimum" viable concept.

P5P has (as we understand it) already rejected Moose in the core due to its huge non-core dependency list. Moo in the core would have to break backwards-compatibility with the `meta` method, leading to potential wide scale breakage of the darkpan.

Further, even with [Moxie](https://metacpan.org/pod/Moxie), we find that the implementation is limited by the syntax of the Perl language itself. There are no true methods. It's tied to a blessed hashref, making it easy to violate encapsulation (and this is needed because without public readers/writers, the instance needs to reach into the hashref to get its data). The syntax is still a bit clumsy, requiring readers/writers to be declared separately from their slots.

We actually find [Zydeco](https://metacpan.org/pod/Zydeco) and [Dios](https://metacpan.org/pod/Dios) interesting, but the scope of those projects is probably far larger than what could go into the core (and we haven't reviewed them thoroughly enough to sure they're appropriate).

# Open Issues

The astute reader will note that between this and the [Overview](https://github.com/Ovid/Cor/wiki/Corinna-Overview) (MVP) document, there are a few things that are not specified. For example, while we have an [extremely detailed specification for object construction](https://gist.github.com/Ovid/accb0c7c8444bdd150b5c7509809477f), we have not defined objects, classes, or methods. Some terms are so common that repeating definitions everywhere would take months.

Other things, such as the exact nature of the destruction object that `DESTRUCT` takes, or whether or not `DESTRUCT` is even a phaser. We're torn on this.

We want the specification to be detailed enough that P5P can make a decision, but want it to be loose enough that if we need to change some aspects, we don't want P5P to feel like we've pulled a bait and switch.

So we're hoping to get approval for an iterative, agile approach. With the great feedback from so many people, we've gotten most of those beaten into a solid shape and we're comfortable with it, but no matter how careful we are, we're going to make mistakes and we don't want to go down the waterfall approach of specifying everything to the nth degree and committing ourselves to a bad design.

# Scope for future work

Corinna v.0.1.0 is intended to be "the simplest thing that can possibly work." By "possibly work," we mean "is useful enough for a production environment." However, it the list of things we _could_ add to Corinna is extensive and should likely be guided by the new RFC process after the initial exposure to Corinna gives people an idea of how effective OO can be.

There are numerous things we could do in the future.

* Create a native Object type (OV?) instead of using a blessed array reference (performance)
* Ability to declare individual classes and methods as `final` (performance. See also, [sealed lexicals](https://www.sunstarsys.com/essays/perl7-sealed-lexicals))
* Types (focused on correctness and readability, but this is a cross-cutting concern)
* Declare Authority (`class Foo authority cpan:OVID { ... }`)
* Nested classes
* Anonymous classes
* Multidispatch
* Etc.

# Contributors

The [list of contributors is on the wiki](https://github.com/Ovid/Cor/wiki/Contributors).

# Copyright

Copyright (C) 2021, Curtis "Ovid" Poe

This document and code and documentation within it may be used, redistributed and/or modified under the same terms as Perl itself.
