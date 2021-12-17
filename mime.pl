#!/usr/bin/perl -n

use Encode qw(encode decode);

local $Encode::MIME::Header::STRICT_DECODE = 1;
my $mime_str = encode("MIME-Q", $_);
print($mime_str);
