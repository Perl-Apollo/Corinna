To make this more manageable and not define a grammar for all of Perl, we will break the grammar out into separate components for simplicity.

# Class and Role Grammar

The primary grammar looks like:

```
Corinna     ::= CLASS | ROLE
CLASS       ::= DESCRIPTOR? 'class' NAMESPACE
                DECLARATION BLOCK
DESCRIPTOR  ::= 'abstract'
ROLE        ::= 'role' NAMESPACE
                DECLARATION BLOCK
NAMESPACE   ::= IDENTIFIER { '::' IDENTIFIER } VERSION? 
DECLARATION ::= { PARENT | ROLES } | { ROLES | PARENT }
PARENT      ::= 'isa' NAMESPACE
ROLES       ::= 'does' NAMESPACE { ',' NAMESPACE } ','?
IDENTIFIER  ::= [:alpha:] {[:alnum:]}
VERSION     ::= 'v' DIGIT {DIGIT} '.' DIGIT {DIGIT} '.' DIGIT {DIGIT}
DIGIT       ::= [0-9]
BLOCK       ::= # Perl +/- Extras
```

The version numbers use the major, minor, and patch numbers from [semantic versioning](https://semver.org/).

# Method Grammar

The method grammar (skipping some bits to avoid defining a grammar for Perl):

```
METHOD     ::= MODIFIERS 'method' SIGNATURE '{' (perl code) '}'
SIGNATURE  ::= METHODNAME '(' current sub argument structure + extra work from Dave Mitchell ')'
METHODNAME ::= [a-zA-Z_]\w*
MODIFIERS  ::= MODIFIER { MODIFIER }
MODIFIER   ::= 'private' | 'overrides' | 'common' 
```

# Slot Grammar

"Slots" in Corinna parlance are the variables where class and instance data are stored.

For simplicity: `SCALAR`, `ARRAY`, and `HASH` refer to their corresponding variable names. `PERL_EXPRESSION` means what it says. `IDENTIFIER` is a valid Perl identifier.

```
SLOT            ::= INSTANCE | SHARED
SHARED          ::= 'common' 'slot'? SLOT_DEFINITION
INSTANCE        ::= 'slot'    SLOT_DEFINITION
SLOT_DEFINITION ::=   SCALAR           ATTRIBUTES? DEFAULT?  
                    | { ARRAY | HASH }             DEFAULT? 
DEFAULT         ::= PERL_EXPRESSION
ATTRIBUTE       ::= 'param' MODIFIER? | 'reader' MODIFIER? | 'writer' MODIFIER? |  'predicate' MODIFIER?  | 'name' MODIFIER? | HANDLES
ATTRIBUTES      ::= { ATTRIBUTE }
HANDLES         ::= 'handles' '(' 
                                    IDENTIFIER { ',' IDENTIFIER }    # list of methods this slot handles
                                 |  PAIR { ',' PAIR }                # map of methods (to, from) this slot handles
                                 | '*'                               # this slot handles all unknown methods, but inheritance takes precedence
                              ')'
PAIR            ::= IDENTIFIER  ( ',' | '=>' ) IDENTIFIER
MODIFIER        ::= '(' IDENTIFIER ')'
IDENTIFIER      ::= [:alpha:] {[:alnum:]}
```
