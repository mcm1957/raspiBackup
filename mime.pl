#!/usr/bin/perl -n

use Encode qw(encode decode);

while (<>) {
	my $inp=$_;
	chomp $inp;
	printf("-%s-\n",$inp);
	my $mime_str = encode("MIME-Header", $inp);
	print("%s - %s\n", $inp, $mime_str);
}
