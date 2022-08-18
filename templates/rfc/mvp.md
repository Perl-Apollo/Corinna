# MMVP

A Corinna MVP has been accepted and work on integrating Corinna into the Perl
core has begun.

This is an MMVP (Minimally Minimal Viable Product). This is written after
guidance provided by the Perl Steering committee. This addresses a few
concerns.

* The more we push into core, the more bugs there will be
* The more we push into core, the more time it will take
* The more we push into core, the more people might rely on misfeatures

Thus, Corinna development for core will be staged, with subsequent work to
realize the full MVP. 

Thus, we want the simplest thing that could possibly work in the first release.

What follows is a minimal description of what we'd like for the MMVP. The plan
is to implement this in seven stages. Each stage will be pushed separately,
giving us time to test and verify that it does what we need. Note that some
features are specified, in terms of semantics, but in the spirit of "no plan
survives first contact with the enemy," we will nail some of the syntax down as
we write tests to verify the behavior and solicit feedback from those playing
with it.

# The Seven Stages

## 1. Classes

Initial `use feature 'class'` to add basic `class`, `field`, abd `method` keywords.
This wll include `ADJUST` and `ADJUSTPARAMS` phasers.

No roles, no class/slot/method attrs, no MOP.

## 2. Class inheritance - class :isa() attr

## 3. Roles, and class/role :does() attr

The current implementation of required methods is to simply create a forward
declaration: `method foo;` without listing the signature. Signatures are
currently not introspectable, so we cannot use them to verify that the correct
required method is present, so we only use the name. Including a signature in
the forward declaration might be self-documenting, but for now, we'd prefer to
omit it because this might impact forward compatibility.

## 4. Various "convenience" attributes -

```
field :reader :writer :accessor :mutator
field :weak
field :param
method :overrides()
```

At this stage, most of the basics are in place and we have a useful system.

## 5. Slot initialiser blocks

## 6. MOP

## 7. Method modifiers (around, before, after)

# Missing Features

Obviously, quite a few features are missing from this RFC of Corinna. Our
intent is to roll them out as quickly as is feasible, but to ensure the
foundation is stable.

# Potentially Breaking Changes

The following features are not planned for the MMVP and might break your code
in subsequent releases.

* Error on unknown constructor parameters
* Deterministic destruction might cause issues when introduced
* Many other features (see the github repo)

There are a ton of other feature omitted, but have been not mentioned here
because they're not even part of the Corinna MVP (role exclusion and aliasing
being a perfect example).
