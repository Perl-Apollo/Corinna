Prev: [Class Construction](class-construction.md)  
Next: [Methods](methods.md)

---

# Corinna Attributes

For Corinna, declaring instance data is done with `has`.

```
has $x;
has $name;
```

This keyword does nothing but let the class access that instance data. It has
absolutely no other behavior. In Moo/se, the `has` function provides *tons* of
different behavior, some of which later turned out to be a bad idea, such as
`lazy_build`, which adds a several methods you may not need and possibly
didn't realize you were asking for.

In Corinna, additional behavior is defined via slot _attributes_ and these
have been carefully designed to be as composable as possible. It's very
difficult to create any combination of "illegal" attributes.

The minimal MVP grammar for slots and attributes looks like this.

```
SLOT            ::= INSTANCE | SHARED
SHARED          ::= 'common' 'has'? SLOT_DEFINITION
INSTANCE        ::= 'has'    SLOT_DEFINITION
SLOT_DEFINITION ::=   SCALAR           ATTRIBUTES? DEFAULT?
                    | { ARRAY | HASH }             DEFAULT?
DEFAULT         ::= PERL_EXPRESSION
ATTRIBUTE       ::= 'param' MODIFIER? | 'reader' MODIFIER? | 'writer' MODIFIER?
                 |  'predicate' MODIFIER?  | 'name' MODIFIER? | HANDLES
ATTRIBUTES      ::= { ATTRIBUTE }
HANDLES         ::= 'handles' '('
                                    DELEGATION { ',' DELEGATION }    # this slot handles methods by delegating to its value (an object)
                                 |  '*'                              # this slot handles all unknown methods, but inheritance takes precedence
                              ')'
DELEGATION      ::= IDENTIFIER | PAIR                                # A method or a map (to:from) this slot handles
PAIR            ::= IDENTIFIER ':' IDENTIFIER                           
MODIFIER        ::= '(' IDENTIFIER ')'
IDENTIFIER      ::= [:alpha:] {[:alnum:]}
```

To visualize that, let's look at the slots and their attributes from the
`Cache::LRU` class described in our [overview](overview.md).

1. `common $num_caches :reader                     = 0;`
2. `has    $cache      :handles(qw/exists delete/) = Hash::Ordered->new;`
3. `has    $max_size   :param  :reader             = 20;`
4. `has    $created    :reader                     = time;`

The first slot declares class data and will be used to track now many
caches exist at any time. The `:reader` says "create a read-only method named
`num_caches` to allow people outside the class to read this data.

The second slot holds an instance of `Hash::Ordered` and the
`handles(qw/exists delete/)` says "delegate these to methods to the object
contained in `$cache`".

The third slot uses `:param` to say "you may pass this as a parameter to
the contructor", however, the `= 20` tells us that this will be the default if
not passed. If there is no default, `:param` means we must pass this value to
the contructor.

The fourth slot should, at this point, be self-explanatory.

## Slot Creation

Slot creation done by declaring `has` or `common`, the slot variable, and an
optional default value.

```perl
has $answer = 42;                      # instance data, defaults to 42
has %results_for;                      # instance data, no default
common @colors = qw(red green blue);   # class data, default to qw(red green blue)
```

For scalar slots (and only for scalar slots), you can add attributes after the
declaration and before the optional default, if any.

We do not (yet) support attributes for array or hash slots because these
automatically flatten into lists and it's not clear what the semantics
of readers and writers would be, now how you would pass them in the
constructor.

Note that all slots are completely encapsulated, but if they're exposed to the
outside world via `:reader`, `:writer`, or some other parameter, their _name_
defaults to the variable name, minus the leading punctuation. This will become
more clear as you read about the individual attributes.

If slot name generation would cause another method to be overwritten, this is
a compile-time error (unless we can later think of an easy syntax for
specifying an override).

## Slot Initialization

Note that all slots are initialized from top to bottom. So you can do
this:

```perl
has $x :param = 42;
has $answer = $x;
```

`common` attributes with defaults will be initialized at compile time, while
all instance attributes will be initialized at object construction.

## Slot Destruction

When an instance goes out of scope, instance slots will be destroyed in
reverse order of declaration. When a class goes out of scope (currently only
in global destruction), the same is true for class slots.

## Slot Attributes

The attributes we support for the MVP are as follows.

### `:param(optional_identifier)`

This value for this slot _may_ be passed in the constructor. If there is no
default via `= ...` on the slot definition, this value _must_ be passed to the
constructor. If you wish for it to be optional, but not have a default value,
use the `= undef` default.

If `optional_identifier` is present in parenthesis, this must be a legal Perl
identifier and will be used at the parameter name.

Note that `:param` and `common` are mutually exclusive.  You cannot pass class
data in constructors. This is one of the few conflicts in object creation.

```perl
class Soldier {
    has $id            :param;             # required in constructor
    has $name          :param = undef;     # optional in constructor
    has $rank          :param = 'private'; # optional in constructor, defaults to 'private'
    has $serial_number :param('sn');
}

# usage
my $thing = Soldier->new(
    is   => $required,
    name => $optional_name, # this k/v pair can be omitted entirely
    rank => $optional_rank,
    sn   => $some_value,
);
```

Note that in the above, passing `serial_number` to the constructor is an
error.

Because slot names generate fatal errors if they would redefine another
method, parent and child classes must have distinct constructor arguments.

### `:reader(optional_identifier)`

By default, all slots are private to the class. You may optionally expose a
slot for reading by providing a `:reader` attribute. You may specify an
optional name, if desired.

```perl
class SomeClass {
    has $id            :param :reader;
    has $name          :param = undef;
    has $serial_number :param('sn') :reader('serial');
}

my $thing = SomeClass->new(...)
say $thing->id;
say $thing->serial;
say $thing->name;   # no such method error
```

### `:writer(optional_identifier)`

By default, all slots are private to the class. You may optionally expose
a slot for writing by providing a `:writer` attribute. You may specify an optional
name, if desired. Note that a `:writer` has `set_` prepended to the name. If you explicity
set the name of the writer to the name of the slot, there will be a special
case to allow `->method` for reading and `->method($new_value)` for writing:

```perl
class SomeClass {
    has $id            :param :writer;
    has $name          :param = undef;
    has $serial_number :reader :writer('serial');
}

my $thing = SomeClass->new(...);
$thing->set_id($new_id);
$thing->serial_number($new_serial);
say $thing->serial_number;
$thing->id($new_id);                    # no such method error
```
### `:predicate(optional_identifier)`

Generates a `has_$name` predicate method to let you know if the slot value has
been _defined_. Of course, you may change the name.

```perl
class SomeClass {
    has $id            :predicate(is_initialized) :param = undef;
    has $name          :predicate :param = undef;
    has $serial_number;
}

my $thing = SomeClass->new(...);

if ( $thing->is_initialized ) { ... }
if ( $thing->has_name )       { ... }
```

### `:name(optional_identifier)`

By default, the name of a slot is the name of the variable minus the
punctuation. However, this name might be unsuitable for public exposure, or
may conflict with a parent class's methods. Use `name(optional_identifier)` to
set a new name for the slot. Of course, you can always use
`optional_identifier` with the _other_ attributes to change their names
individually.

```perl
has $id :name('ident')              # name is now "ident"
        :reader                     # ->ident()
        :writer                     # ->set_ident($value)
        :predicate(is_registered);  # ->is_registered
```

### `:handles(%@*)`

This attribute is used to delegate methods to the object contained in this
slot. You may pass it either a list of identifiers and identifier:identifier
mappings, or the special `*` token.

#### List of Identifiers and Identifier:Identifier Mappings

A list of identifiers says "these methods will be handled by this object.

```perl
use DateTime;
common $datetime :handles(now, today) = 'DateTime';
```

Now, when you call `->now` or `->today` on the object, those will be
delegated to the `DateTime` class. Note that because class names are not
"first class" in Perl, we regrettably treat the classname as a string.

A more common case is to delegate to an instance.

```
use Hash::Ordered;
has $cache :handles(exists, delete) = Hash::Ordered->new;
```

The above will delegate `->exists($key)` and `->delete($key)` to the object
held by `$cache`.

You can rename delegated methods by providing identifiers for the 
method the attribute will handle and for the delegated object's original 
method name, separated by a colon.  In the following example, we are 
renaming `exists` to `has_key`, but retaining the other method name.

```
use Hash::Ordered;
has $cache :handles(
    has_key:exists, delete
) = Hash::Ordered->new;
```

#### Delegate All Unknown Methods

As a special workaround for not being able to inherit from non-Corinna
objects, we have a special `handles(*)` syntax. This means that unless
`$self->can($method)`, try to call method on the delegation target, regardless
of whether or not `$target->can($method)` (internally, the `$target` might use
`AUTOLOAD` to provide methods and not have overridden `can($method)` to report
correctly).

For example, here's how you would fake inheriting from `DateTime`.

```perl
class DateTime::Improved {
    use DateTime;
    has $args :params;
    has $datetime :handles(*);

    ADJUST {
        my @datetimes_args = ...;
        $datetime = DateTime->new(@datetimes_args);
    }

    # more code here
}
```

---

Prev: [Class Construction](class-construction.md)  
Next: [Methods](methods.md)
