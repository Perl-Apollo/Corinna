use Object::Pad;

role RFC::Role::File {
    method _slurp($file) {
        open my $fh, '<:encoding(UTF-8)', $file or die "Cannot open $file for reading: $!";
        return do { local $/; <$fh> };
    }

    method _splat( $file, $data ) {
        if ( ref $data ) {
            croak("Data for splat '$file' must not be a reference ($data)");
        }
        open my $fh, '>:encoding(UTF-8)', $file or die "Cannot open $file for writing: $!";
        print {$fh} $data;
    }
}
