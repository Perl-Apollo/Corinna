To make this more manageable and not define a grammar for all of Perl, we will break the grammar out into separate components for simplicity.

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
IDENTIFIER     ::= [:alpha:] {[:alnum:]}
VERSION        ::= ':version(' VERSION_NUMBER ')
VERSION_NUMBER ::= # all allowed Perl version numbers
BLOCK          ::= # Perl +/- Extras
```

We recommend [semantic versioning](https://semver.org/), but in we allow all
existing Perl version formats to facilitate upgarding existing modules.

# Method Grammar

The method grammar (skipping some bits to avoid defining a grammar for Perl):

```
METHOD        ::= 'method' ACCESS_LEVELS SIGNATURE '{' (perl code) '}'
SIGNATURE     ::= IDENTIFIER '(' current sub argument structure + extra work from Dave Mitchell ')'
ACCESS_LEVELS ::= ACCESS_LEVEL { ACCESS_LEVEL }
ACCESS_LEVEL  ::= ':' { 'private' | 'overrides' | 'common' }
SIGNATURE     ::= # currently allowed Perl signatures
```

# Field Grammar

"Fields" in Corinna parlance are the variables where class and instance data are stored.

For simplicity: `SCALAR`, `ARRAY`, and `HASH` refer to their corresponding variable names. `PERL_EXPRESSION` means what it says. `IDENTIFIER` is a valid Perl identifier.

**Note** `SHARED` (class data) is still in flux.

```
FIELD            ::= INSTANCE | SHARED ';'
SHARED           ::= 'my' { SCALAR | ARRAY | HASH } DEFAULT?
INSTANCE         ::= 'field'    FIELD_DEFINITION
FIELD_DEFINITION ::= SCALAR ATTRIBUTES? DEFAULT?  | { ARRAY | HASH } DEFAULT? 
DEFAULT          ::= '=' PERL_EXPRESSION
ATTRIBUTE        ::= ':' ( 'param' MODIFIER? | 'reader' MODIFIER? | 'writer' MODIFIER? |  'predicate' MODIFIER?  | HANDLES )
ATTRIBUTES       ::= { ATTRIBUTE }
HANDLES          ::= 'handles' '(' 
                                    IDENTIFIER { ',' IDENTIFIER }    # list of methods this field handles
                                 |  PAIR { ',' PAIR }                # map of methods (to, from) this field handles
                                 | '*'                               # this field handles all unknown methods, but inheritance takes precedence
                              ')'
PAIR             ::= IDENTIFIER  ':' IDENTIFIER
MODIFIER         ::= '(' IDENTIFIER ')'
IDENTIFIER       ::= [:alpha:] {[:alnum:]}
```
