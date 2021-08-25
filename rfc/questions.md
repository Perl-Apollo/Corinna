Prev: [Phasers](phasers.md)   
Next: [Quotes](quotes.md)

---

# Section 9: Questions

# 9.1 Open issues for the RFC
## 9.1.1 Corinna v Other objects
What would be the easiest way to distinguish between Corinna and other kinds
of objects? I think having a base class of `Object` solves this.

Thus, anyone could simply ask if `$thing isa Object` and find out of it's
Corinna or not. This would be very useful if they want to use the MOP and
discover it doesn't work on a regular blessed reference.

## 9.1.2 Multiple Variables Types In A Slot
Can slots have more than one kind of variable?

```perl
has ($x, @y);
```

If so, do we disallow attributes?

## 9.1.3 Twigils?
```perl
has $:x;

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

## 9.1.4 Overridding Attributes
A method can override a parent method explicitly to avoid a warning:

```perl
override method move($x,$y) {...}
```

Should methods generated via slot attributes be allowed to override parents?
If so, how do we signal this?

## 9.1.5 `can`, `does`, and `isa`
It has been suggested that we offer new versions of `can`, `does`, and `isa`.
They would not take arguments.

* `can`: returns all methods the current class can do (including inherited)
* `does`: returns all roles the current class does
* `isa`: returns the iteheritance list 

Because these methods currently do not take arguments, this might be extending
them instead of modifiying them. However, this would still be modifying
current behavior. Or we could put this in an `Object`  base class for Corinna.
However, this would mean the external behaviors would be different for Corinna
and other objects.

I think this is probaby out of scope for Corinna.

## 9.1.6 Inline POD?
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


---

Prev: [Phasers](phasers.md)   
Next: [Quotes](quotes.md)
