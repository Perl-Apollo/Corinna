# Overview 

For Corinna, declaring class and instance data is done with `field`.

```
field $x;
field $name;
```

This keyword does nothing but let the class access that instance data. It has
absolutely no other behavior. In Moo/se, the `field` function is named `has`
and provides *tons* of different behavior, some of which later turned out to
be a bad idea, such as `lazy_build`, which adds a several methods you may not
need and possibly didn't realize you were asking for.

In Corinna, additional behavior is defined via field _attributes_ and these
have been carefully designed to be as composable as possible. It's very
difficult to create any combination of "illegal" attributes.

The minimal MVP grammar for fields and attributes can be found
[here](grammar.md#field-grammar).

To visualize that, let's look at the fields and their attributes from the
`Cache::LRU` class described in our [overview](overview.md).

1. `field $num_caches :common                  { 0 };` 
2. `field $cache      :handles(exists, delete) { Hash::Ordered->new} ;`
3. `field $max_size   :param  :reader          { 20 };`
4. `field $created    :reader                  { time };`

The first field is class data. This is data shared by all instances of this
class (and by the class itself). Note that it's initialized with any default
value as soon as the class is compiled.

The second field holds an instance of `Hash::Ordered` and the
`handles(exists, delete)` says "delegate these methods to the object
contained in `$cache`".

The third field uses `:param` to say "you may pass this as a parameter to
the contructor", however, the `= 20` tells us that this will be the default if
not passed. If there is no default, `:param` means we must pass this value to
the contructor.

The fourth field should, at this point, be self-explanatory, but its value is
always initialized at instantiation time, ensuring that every instance has its
value of `$created` calculated separately.

# Field Creation

Field creation done by declaring `field`, field variable, and an optional
default value.

```perl
field $answer { 42 };                           # instance data, defaults to 42
field %results_for;                             # instance data, no default
field @colors :common { qw(red green blue) };   # class data, default to qw(red green blue)
```

For scalar fields declared with `field` (and only for scalar fields), you can add
attributes after the declaration and before the optional default, if any.

For class data, for the MVP, only the `:reader` parameter may be used with
`:common`. This is because all instances share this data and using `:param`
and `:writer` to mutate it causes global action-at-a-distance. If you want
that behavior, you must write methods to support it. We do this to ensure that
you think carefully about this decision.

Note that all fields are completely encapsulated, but if they're exposed to the
outside world via `:reader`, `:writer`, or some other parameter, their _name_
defaults to the variable name, minus the leading punctuation. This will become
more clear as you read about the individual attributes.

If field name generation would cause another method to be overwritten, this is
a compile-time error (unless we can later think of an easy syntax for
specifying an override).

## Field Initialization

Note that all fields are initialized from top to bottom. So you can do
this:

```perl
field $x :param { 42 };
field $answer   { $x };
```

`:common` fields with defaults will be initialized at compile time, while
all instance attributes will be initialized at object construction.

## Field Destruction

When an instance goes out of scope, instance fields will be destroyed in
reverse order of declaration. When a class goes out of scope (currently only
in global destruction), the same is true for class fields.

## Field Attributes

The attributes we support for the MVP are as follows. Only variables declared
with `field` may take attributes.

### `:param(optional_identifier)`

This value for this field _may_ be passed in the constructor. If there is no
default via `= ...` on the field definition, this value _must_ be passed to the
constructor. If you wish for it to be optional, but not have a default value,
use the `= undef` default.

If `optional_identifier` is present in parenthesis, this must be a legal Perl
identifier and will be used as the parameter name.

```perl
class Soldier {
    field $id            :param;               # required in constructor
    field $name          :param { undef };     # optional in constructor
    field $rank          :param { 'recruit' }; # optional in constructor, defaults to 'recruit'
    field $serial_number :param(sn);
}

# usage
my $thing = Soldier->new(
    id   => $required,
    name => $optional_name, # this k/v pair can be omitted entirely
    rank => $optional_rank,
    sn   => $some_value,
);
```

Note that in the above, passing `serial_number` to the constructor is an
error.

Because field names generate fatal errors if they would redefine another
method, parent and child classes must have distinct constructor arguments.

### `:reader(optional_identifier)`

By default, all fields are private to the class. You may optionally expose a
field for reading by providing a `:reader` attribute. You may specify an
optional name, if desired.

```perl
class SomeClass {
    field $id            :param :reader;
    field $name          :param { undef };
    field $serial_number :param(sn) :reader(serial);
}

my $thing = SomeClass->new(...)
say $thing->id;
say $thing->serial;
say $thing->name;   # no such method error
```

### `:writer(optional_identifier)`

By default, all fields are private to the class. You may optionally expose
a field for writing by providing a `:writer` attribute. You may specify an optional
name, if desired. Note that a `:writer` has `set_` prepended to the name. If you explicity
set the name of the writer to the name of the field, there will be a special
case to allow `->method` for reading and `->method($new_value)` for writing:

```perl
class SomeClass {
    field $id            :param :writer;
    field $name          :param { undef };
    field $serial_number :reader :writer(serial);
}

my $thing = SomeClass->new(...);
$thing->set_id($new_id);
$thing->serial($new_serial);
say $thing->serial_number;
$thing->id($new_id);                    # no such method error
```
### `:predicate(optional_identifier)`

Generates a `has_$name` predicate method to let you know if the field value has
been _defined_. Of course, you may change the name.

```perl
class SomeClass {
    field $id            :predicate(is_initialized) :param { undef };
    field $name          :predicate                 :param { undef };
    field $serial_number;
}

my $thing = SomeClass->new(...);

if ( $thing->is_initialized ) { ... }
if ( $thing->has_name )       { ... }
```

### `:name(optional_identifier)`

By default, the name of a field is the name of the variable minus the
punctuation. However, this name might be unsuitable for public exposure, or
may conflict with a parent class's methods. Use `name(optional_identifier)` to
set a new name for the field. Of course, you can always use
`optional_identifier` with the _other_ attributes to change their names
individually.

```perl
field $id :name(ident)                # name is now "ident"
          :reader                     # ->ident()
          :writer                     # ->set_ident($value)
          :predicate(is_registered);  # ->is_registered
```

### `:handles(%@*)`

This attribute is used to delegate methods to the object contained in this
field. You may pass it either a list of identifiers and identifier:identifier
mappings, or the special `*` token.

#### List of Identifiers and Identifier:Identifier Mappings

A list of identifiers says "these methods will be handled by this object".

```perl
use DateTime;
field $datetime :handles(now, today) { 'DateTime' };
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
field $cache :handles(
    has_key:exists, delete
) = Hash::Ordered->new;
```
