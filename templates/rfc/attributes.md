# Overview 

For Corinna, declaring class and instance data is done with `slot`.

```
slot $x;
slot $name;
```

This keyword does nothing but let the class access that instance data. It has
absolutely no other behavior. In Moo/se, the `slot` function is named `has`
and provides *tons* of different behavior, some of which later turned out to
be a bad idea, such as `lazy_build`, which adds a several methods you may not
need and possibly didn't realize you were asking for.

In Corinna, additional behavior is defined via slot _attributes_ and these
have been carefully designed to be as composable as possible. It's very
difficult to create any combination of "illegal" attributes.

The minimal MVP grammar for slots and attributes can be found
[here](grammar.md#slot-grammar).

To visualize that, let's look at the slots and their attributes from the
`Cache::LRU` class described in our [overview](overview.md).

1. `my $num_caches = 0;` 
2. `slot    $cache      :handles(qw/exists delete/) = Hash::Ordered->new;`
3. `slot    $max_size   :param  :reader             = 20;`
4. `slot    $created    :reader                     = time;`

The first slot is a standard `my` variable and is used for class data. Note
that no attributes are allowed and it's initialized with any default value as
soon as the class is compiled.

The second slot holds an instance of `Hash::Ordered` and the
`handles(qw/exists delete/)` says "delegate these methods to the object
contained in `$cache`".

The third slot uses `:param` to say "you may pass this as a parameter to
the contructor", however, the `= 20` tells us that this will be the default if
not passed. If there is no default, `:param` means we must pass this value to
the contructor.

The fourth slot should, at this point, be self-explanatory.

# Slot Creation

Slot creation done by declaring `slot` or `my`, the slot variable, and an
optional default value.

```perl
slot $answer = 42;                 # instance data, defaults to 42
slot %results_for;                 # instance data, no default
my @colors = qw(red green blue);   # class data, default to qw(red green blue)
```

For scalar slots declared with `slot` (and only for scalar slots), you can add
attributes after the declaration and before the optional default, if any.

We do not (yet) support attributes for class data. We also do not support
attributes for array or hash slots because these automatically flatten into
lists and it's not clear what the semantics of readers and writers would be,
nor how you would pass them in the constructor.

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
slot $x :param = 42;
slot $answer = $x;
```

`my` variables with defaults will be initialized at compile time, while
all instance attributes will be initialized at object construction.

## Slot Destruction

When an instance goes out of scope, instance slots will be destroyed in
reverse order of declaration. When a class goes out of scope (currently only
in global destruction), the same is true for class slots.

## Slot Attributes

The attributes we support for the MVP are as follows. Only variables declared
with `slot` may take attributes.

### `:param(optional_identifier)`

This value for this slot _may_ be passed in the constructor. If there is no
default via `= ...` on the slot definition, this value _must_ be passed to the
constructor. If you wish for it to be optional, but not have a default value,
use the `= undef` default.

If `optional_identifier` is present in parenthesis, this must be a legal Perl
identifier and will be used as the parameter name.

```perl
class Soldier {
    slot $id            :param;             # required in constructor
    slot $name          :param = undef;     # optional in constructor
    slot $rank          :param = 'recruit'; # optional in constructor, defaults to 'recruit'
    slot $serial_number :param('sn');
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
    slot $id            :param :reader;
    slot $name          :param = undef;
    slot $serial_number :param('sn') :reader('serial');
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
    slot $id            :param :writer;
    slot $name          :param = undef;
    slot $serial_number :reader :writer('serial');
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
    slot $id            :predicate(is_initialized) :param = undef;
    slot $name          :predicate :param = undef;
    slot $serial_number;
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
slot $id :name('ident')              # name is now "ident"
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
slot $datetime :handles(now, today) = 'DateTime';
```

Now, when you call `->now` or `->today` on the object, those will be
delegated to the `DateTime` class. Note that because class names are not
"first class" in Perl, we regrettably treat the classname as a string.

You can rename delegated methods by providing identifiers for the 
method the attribute will handle and for the delegated object's original 
method name, separated by a colon.  In the following example, we are 
renaming `exists` to `has_key`, but retaining the other method name.

```
use Hash::Ordered;
slot $cache :handles(
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
    slot $args :params;
    slot $datetime :handles(*);

    ADJUST {
        my @datetimes_args = ...;
        $datetime = DateTime->new(@datetimes_args);
    }

    # more code here
}
```

Note that `handles(*)` should not attempt to delegate any method that begins
with an underscore. Otherwise, that becomes part of the private interface.
Instead, you need to call those explicitly:

```perl
class DateTime::Improved {
    use DateTime;
    slot $args :params;
    slot $datetime :handles(*);

    ADJUST {
        my @datetimes_args = ...;
        $datetime = DateTime->new(@datetimes_args);
    }

    method do_something() {

        # we cannot delegate directly to private methods
        my $timezone = $datetime->_default_time_zone;
        ...
    }
}
```
