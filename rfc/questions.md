# Open Questions

## Multiple Variables Types In A Slot

Can slots have more than one kind of variable?

```perl
has ($x, @y);
```

If so, do we disallow attributes?

## Twigils?

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

## Overridding Attributes

A method can override a parent method explicitly to avoid a warning:

```perl
override method move($x,$y) {...}
```

Should methods generated via slot attributes be allowed to override parents?
If so, how do we signal this?
