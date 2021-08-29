package Corinna::RFC::Types {
    use strict;
    use warnings;
    use Type::Library -base;
    use Type::Utils -all;
    use Type::Tiny::Class;
    use Type::Params;                # for compile and compile_named
    use Types::Standard 'slurpy';    # force import of slurpy

    our @EXPORT_OK;

    BEGIN {
        extends qw(
          Types::Standard
          Types::Common::Numeric
          Types::Common::String
        );
        push @EXPORT_OK => (
            'compile',         # from Type::Params
            'compile_named',   # from Type::Params
            'slurpy',          # For some reason, this isn't exported by default
        );
    }
}

1;
