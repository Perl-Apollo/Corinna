Due to the fast-moving nature of this project, we won't note every little
change to the RFC. You can always clone the repo and read the commits.
Instead, we'll cover major changes here.

# Change Log

# November 23, 2021

- Clarify that the `handles(*)` delegation will not auto-delegate to methods
  beginning with underscores to avoid those becoming part of the public
  interface. Of course, internally you can still call those methods directly
  on the slot variable calling the object.

# November 15, 2021

- After many suggestions from Paul Evans and later by Damian Conway, Corinna
  has been switched over to
  [KIM](https://ovid.github.io/articles/language-design-consistency.html)
  (Keyword, Identifier, Modifier) syntax. See also [Damian Conway's post on
  the
  topic](http://blogs.perl.org/users/damian_conway/2021/11/a-dream-resyntaxed.html).

# November 2, 2021

- Method modifiers RFC section added.
- Classes documentation now shows we use any legal version numbers, not just
  semver triples.

## September 22, 2021

- Abtract methods in classes and required methods in roles are no longer
  allowed to declare their argument lists. This gives us room to reconsider
  this behavior post-MVP.

## September 21, 2021

- `:name` attribute for slots removed from MVP. Might be returned later.
- Version numbers no longer limited to semver. All current Perl version
  formats intended to be supported.
- Classes which both inherit and consume roles must now declare the parent
  before the roles (previously, the order was not relevant).
- Method access levels such as `common`, `private`, and `overrides` are now
  attributes that come between the method name and the argument list:

```perl
method foo :overrides ($bar, $baz) { ... }
```

## August 26, 2021

- Class slots now declared with `my`. They do not take attributes.

## August 19, 2021

- Slot declaration keyword renamed from `has` to `slot`

## August 14, 2021

- First draft of RFC released as markdown in github repo so that pull requests
  can be received. Wiki is noted to primarily be of historical interest.
