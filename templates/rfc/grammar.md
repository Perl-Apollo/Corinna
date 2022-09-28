To make this more manageable and not define a grammar for all of Perl, we will break the grammar out into separate components for simplicity.

Note that due to the adoption of the [KIM
syntax](https://ovid.github.io/articles/language-design-consistency.html)
(keyword, identifier, modifier), we only introduce four new keywords to the
Perl language:

* `class`
* `role`
* `field`
* `method`

# Class and Role Grammar

The primary grammar looks like:

```
Corinna        ::= CLASS | ROLE
CLASS          ::= 'class' NAMESPACE DECLARATION? BLOCK
ROLE           ::= 'role' NAMESPACE ROLES? BLOCK
NAMESPACE      ::= IDENTIFIER { '::' IDENTIFIER }
DECLARATION    ::= ':abstract'? PARENT? ROLES? VERSION?
PARENT         ::= ':isa(' NAMESPACE ')'
ROLES          ::= ':does(' NAMESPACE { ',' NAMESPACE } ','? ')'
IDENTIFIER     ::= [_:alpha:] {[_:alnum:]}
VERSION        ::= ':version(' VERSION_NUMBER ')
VERSION_NUMBER ::= # all allowed Perl version numbers
BLOCK          ::= # Perl +/- Extras
```

We recommend [semantic versioning](https://semver.org/), but we allow all
existing Perl version formats to facilitate upgrading existing modules.

# Method Grammar

The method grammar (skipping some bits to avoid defining a grammar for Perl):

```
METHOD        ::= 'method' ACCESS_LEVELS SIGNATURE '{' (perl code) '}'
SIGNATURE     ::= IDENTIFIER '(' current sub argument structure + extra work from Dave Mitchell ')'
ACCESS_LEVELS ::= ACCESS_LEVEL { ACCESS_LEVEL }
ACCESS_LEVEL  ::= ':' ( 'private' | 'overrides' | 'common' )
SIGNATURE     ::= # currently allowed Perl signatures
```

# Field Grammar

"Fields" in Corinna parlance are the variables where class and instance data are stored.

For simplicity: `SCALAR`, `ARRAY`, and `HASH` refer to their corresponding variable names. `PERL_EXPRESSION` means what it says. `IDENTIFIER` is a valid Perl identifier.

```
FIELD            ::= 'field' ( 
                              SCALAR ATTRIBUTES? DEFAULT?
                            | ( ARRAY | HASH ) ':common'? DEFAULT?  # only the :common attribute is
                                                                    # currently supported for array/hash fields
                     )
DEFAULT          ::= '{' PERL_EXPRESSION '}'
ATTRIBUTES       ::= { ATTRIBUTE }
ATTRIBUTE        ::= ':' (
                              'param'     NAME?   # allowed in constructor
                            | 'name'      NAME?   # alternate name (defaults to field name minus the sigil)
                            | 'reader'    NAME?   # $field method to read the field
                            | 'writer'    NAME?   # set_$field method to write the field
                            | 'predicate' NAME?   # is_$field method to test if field is defined
                            | 'common'            # identifies field as class method
                            | HANDLES
                     )
HANDLES          ::= 'handles' '('
                                    IDENTIFIER { ',' IDENTIFIER }    # list of methods this field handles
                                 |  PAIR       { ',' PAIR }          # map of methods (to, from) this field handles
                                 | '*'                               # this field handles all unknown methods, but inheritance takes precedence
                     ')'
PAIR             ::= IDENTIFIER  ':' IDENTIFIER
NAME             ::= '(' IDENTIFIER ')'
```
