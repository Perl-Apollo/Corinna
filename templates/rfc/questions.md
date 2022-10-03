# Open issues for the RFC

## Corinna v Other objects

What would be the easiest way to distinguish between Corinna and other kinds
of objects? I think having a base class of `OBJECT` solves this.

Thus, anyone could simply ask if `$thing isa OBJECT` and find out of it's
Corinna or not. This would be very useful if they want to use the MOP and
discover it doesn't work on a regular blessed reference.

## Multiple Variables Types In A Field

Can fields have more than one kind of variable?

```perl
field ($x, @y);
```

If so, do we disallow attributes?

## Twigils?

```perl
field $:x;

method inc ($x) {
    $:x += $x;
}
```

Pros:

* You can't accidentally shadow class/instance data.
* Great Huffman encoding for "this is not a regular variable"
* Easy to syntax highlight

Cons:

* No direct parser support for twigils
* Is somewhat controversial
* May contribute to "line-noise" complaints

## Overridding Fields

A method can override a parent method explicitly to avoid a warning:

```perl
method move($x,$y) :overrides {...}
```

Should methods generated via `field` attributes be allowed to override parents?
If so, how do we signal this?

## `can`, `does`, and `isa`

It has been suggested that we offer new versions of `can`, `does`, and `isa`.
They would not take arguments.

* `can`: returns all methods the current class can do (including inherited)
* `does`: returns all roles the current class does
* `isa`: returns the iteheritance list 

Because these methods currently do not take arguments, this might be extending
them instead of modifiying them. However, this would still be modifying
current behavior. Or we could put this in an `OBJECT`  base class for Corinna.
However, this would mean the external behaviors would be different for Corinna
and other objects.

I think this is probaby out of scope for Corinna.

## Inline POD?

Because we need a postfix block, many people will be disappointed that we
won't have inline POD quite as neat as what we had:

```perl
class Foo {

=head1 METHODS

=head2 C<bar>

This method does something

=cut

    method bar() { ... }
}
```
