# Overview

For object construction, we provide a list of needed steps and then show
pseudocode to make the construction process explicit.

**Note**: because Corinna is single inheritance, MRO order is simply child to
parent.

Anything which can be removed from this will make object construction
faster. Anything which can be pushed to compile-time will make object
construction faster.

This is almost certainly incorrect, but it's a start.

Also, roles get an ADJUST phaser now

1. Check that the even-sized list of args to new() are not duplicated
   (stops the new( this => 1, this => 2 ) error)
2. And that the keys are not references
3. Walk through classes in reverse MRO order. Croak() if any field
   name is reused
4. After previous step, if we have any extra keys passed to new() which cannot be
   allocated to a field, throw an exception
5. For the internal NEW phaser, assign all values to their correct fields in
   reverse mro order
6. Call all ADJUST phasers in reverse MRO order (no need to validate here because
   everything should be checked at this point)

# Steps

## Step 1 Verify even-sized list of args

Check that the even-sized list of args to `new()` are not duplicated (stops
the `new( this => 1, this => 2` ) error).

```perl
my @args = ...; # get list passed to new()
if ( @args % 2 ) {
    croak("even-sized list required");
}
```

## Step 2 Constructor keys may not be references

Keys are not references (duh).

```perl
my %arg_for;
while (@args) {
    my ( $key, $value ) = (shift @args, shift @args);
    ref $key and croak qq{'$key' must not be a ref};
    exists $arg_for{$key} and croak qq{duplicate key '$key' detected};
    $arg_for{$key} = $value;
}
```

## Step 3 Find constructor args

Walk through classes from parent to child. `croak()` if any
constructor argument is reused.  Different roles and classes can
consume the same role, their constructor arguments only count once.

```perl
my %orig_args = %arg_for;    # shallow copy
my %constructor_args;


my @duplicate_constructor_args;
my %seen_roles;
foreach my $class (@reverse_mro) {
    my @roles = grep { ! $seen_roles{$_} } roles_from_class($class);
    @seen_roles{ @roles } = (1) x @roles;
    foreach my $thing ( $class, @roles ) {
        foreach my $name ( get_fields_with_param_attributes($thing) ) {
            if ( my $other_class = $constructor_args{$name} ) {
                # XXX Warning! This may be a bad thing
                # If you don't happen to notice that some parent class has done
                # `field $cutoff :param { 42 };`
                # then you might accidentally write:
                # `field $cutoff :param { DateTime->now->add(days => 7) };`
                # instead, we probably need some way of signaling this to the
                # programmer. A compile-time error would be good.
                push @duplicate_constructor_args 
                  => "Arg '$name' in '$thing' already used in '$other_class'";
            }
            $constructor_args{$name} = $class;
        }
    }
}
if (my $error = join '  ' => @duplicate_constructor_args) {
    croak($error);
}
```

**Note**: "reused" constructor arguments refers to the public name for the
field. You can reuse `field $message;` in subclasses because it's not public.
However, you cannot reuse `field $message :param;` in a subclass because the
field name default to `message`.  Instead, you would need to rename it: `field
$message :param :name(client_message);`.

We have this restriction to enforce encapsulation of logic in a class. If the
parent class has `field $error :param;` and expects that to contain an error
_object_ and a child class has a `field $error :param;` and expects that to
contain an error _string_, you're in trouble. Until such time that we can
squeeze types into Corinna (and to Perl in general), this restriction makes
the code safer, albeit at the cost of some annoyance.

## Step 4 Err out on unknown keys


After the previous step, if we have any extra keys passed to `new()` which cannot
be allocated to a field, throw an exception. This works because by the time we
get to the final class, all keys should be accounted for. Stops the issue of
`Class->new(feild => 4)` when the field is `field $field :param { 3 };`

```perl
my @bad_keys;
foreach my $key ( keys %arg_for ) {
    exists $constructor_args{$key}
        or push @bad_keys, $key;
}
if (@bad_keys) {
    croak(...);
}
```

## Step 5 `new()`

For the internal NEW phaser, assign all values to their correct fields from
parent to child.

```perl
my @field_values;
foreach my $this_class (@reverse_mro) {
    my @roles = roles_from_class($class);
    foreach my $thing ( $class, @roles ) {
        foreach my $field_name ( get_fields_in_initialization_order($thing) ) {
            push @field_values => $arg_for{$field_name};
        }
    }
}

# PSEUDOCODE! In no way is this meant to suggest that this will be the
# underlying representation of Corinna objects.
my $self = bless \@field_values => $class;
```

## Step 6 `ADJUST`

Call all `ADJUST` phasers from parent to children (no need to validate here because
everything should be checked at this point).

```perl
foreach my $class (@reverse_mro) {
    my @roles = roles_from_class($class);
    foreach my $thing ( $class, @roles ) {

        # the prefix is just pseudo-code to show the idea
        $thing::ADJUST();    # phaser, not a method
    }
}
```

# MOP Pseudocode

MOP stuff

```perl
class MOP {
    method get_fields_with_param_attributes($class_or_role) {
        return
          grep { $self->has_attribute( ':param', $_ ) }
          get_all_fields($class_or_role);
    }

    method get_fields_in_initialization_order($class_or_role) {
        # get_all_fields($class_or_role) should return them in declaration order
        my @fields = get_all_fields($class_or_role);
        my @ordered;
        my $constructor_args_processed = 0;
        while (@fields) {
            my $field = shift @fields;
            if ( $self->has_attribute( ':param', $field ) ) {
                push @ordered => $fields;
                my @remaining;
                foreach my $field (@fields) {
                    if ( $self->has_attribute( ':param', $field ) ) {
                        push @ordered => $field;
                    }
                    else {
                        push @remaining => $field;
                    }
                }
                @fields = @remaining;
            }
            else {
                push @ordered => $field;
            }
        }
    }
}
```
