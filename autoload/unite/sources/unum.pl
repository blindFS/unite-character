#! /usr/bin/perl -CA
#                ^^^   This allows Unicode command-line arguments to be
#                      accepted if the underlying system supports it.
#                      If it causes an error, your version of Perl does
#                      not support this feature.  You can remove the option
#                      and continue to use the program with all other forms
#                      of arguments.

=head1 NAME

unum - Interconvert numbers, Unicode, and HTML/XHTML characters

=head1 SYNOPSIS

B<unum> I<argument...>

=head1 DESCRIPTION

The B<unum> program is a command line utility which allows you to
convert decimal, octal, hexadecimal, and binary numbers; Unicode
character and block names; and HTML/XHTML character entity names and
numbers into one another.  It can be used as an on-line special
character reference for Web authors.

=head2 Arguments

The command line may contain any number of the following
forms of I<argument>.

=over 10

=item 123

Decimal number.

=item 0371

Octal number preceded by a zero.

=item 0x1D351

Hexadecimal number preceded by C<0x>.  Letters may be upper or
lower case, but the C<x> must be lower case.

=item 0b110101

Binary number.

=item b=I<block>

Unicode character blocks matching I<block> are listed.
The I<block> specification may be a regular expression.
For example, C<b=greek> lists all Greek character blocks
in Unicode.

=item c=I<char>...

The Unicode character codes for the characters I<char>... are printed.
If the first character is not a decimal digit and the second not an
equal sign, the C<c=> may be omitted.

=item h=I<entity>

List all HTML/XHTML character entities matching I<entity>, which may
be a regular expression.  Matching is case-insensitive, so
C<h=alpha> finds both C<&Alpha;> and C<&alpha;>.

=item '&#I<number>;&#xI<hexnum>;...'

List the characters corresponding to the specified HTML/XHTML
character entities, which may be given in either decimal or
hexadecimal.  Note that the "x" in XHTML entities must be lower case.
On most Unix-like operating systems, you'll need to quote the argument
so the ampersand, octothorpe, and semicolon aren't interpreted by the
shell.

=item l=I<block>

List all Unicode blocks matching I<block> and all characters
within each block; C<l=goth> lists the C<Gothic> block
and the 32 characters it contains.

=item n=I<name>

List all Unicode character whose names match I<name>, which may be
a regular expression.  For example, C<n=telephone> finds the five
Unicode characters for telephone symbols.

=back

=head2 Output

For number or character arguments, the value(s) are listed in
all of the input formats, save binary.

   Octal  Decimal      Hex        HTML    Character   Unicode
     046       38     0x26       &amp;    "&"         AMPERSAND

If the terminal font cannot display the character being listed,
the "Character" field will contain whatever default is shown in
such circumstances.  Control characters are shown as a Perl
hexadecimal escape.

Unicode blocks are listed as follows:

    Start        End  Unicode Block
   U+2460 -   U+24FF  Enclosed Alphanumerics
  U+1D400 -  U+1D7FF  Mathematical Alphanumeric Symbols


=head1 VERSION

This is B<unum> version 1.1, released on February 11th, 2006.
The current version of this program is always posted at
http://www.fourmilab.ch/webtools/unum/.

=head1 AUTHOR

John Walker

http://www.fourmilab.ch/

=head1 BUGS

Specification of Unicode characters on the command line requires
an operating system and shell which support that feature and a
version of Perl with the B<-CA> command line option
(v5.8.5 has it, but v5.8.0 does not; I don't know in which
intermediate release it was introduced).  If your version of
Perl does not implement this switch, you'll have to remove it
from the C<#!> statement at the top of the program, and Unicode
characters on the command line will not be interpreted correctly.

If you specify a regular expression, be sure to quote the argument
if it contains any characters the shell would otherwise interpret.

Please report any bugs to bugs@fourmilab.ch.

=head1 COPYRIGHT

This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

    use strict;
    use warnings;

    sub usage {
    print << "EOD";
usage: unum arg...
    Arguments:
    147               Decimal number
    0371              Octal number
    0xfa75            Hexadecimal number (letters may be A-F or a-f)
    0b11010011        Binary number
    '&#8747;&#x3c0;'  One or more XHTML numeric entities (hex or decimal)
    xyz               The characters xyz (non-digit)
    c=7Y              The characters 7Y (any Unicode characters)
    b=cherokee        List Unicode blocks containing "CHEROKEE"
    h=alpha           List XHTML entities containing "alpha"
    n=aggravation     Unicode characters with "AGGRAVATION" in the name
    n=^greek.*rho     Unicode characters beginning with "GREEK" and containing "RHO"
    l=gothic          List all characters in matching Unicode blocks

    All name queries are case-insensitive and accept regular
    expressions.  Be sure to quote regular expressions if they
    contain characters with meaning to the shell.

    Run perldoc on this program or visit:
        http://www.fourmilab.ch/webtools/unum/
    for additional information.
EOD
    }

    my (%XHTML_ENTITIES, %JAMO_SHORT_NAME, %UNICODE_NAMES, @UNICODE_BLOCKS);

    binmode(STDOUT, ":utf8");

    if ($#ARGV < 0) {
    usage();
    exit(0);
    }

    init_names();

    my ($chartitle, $blocktitle) = (0, 0);
    my $arg = 0;
    while ($#ARGV >= 0) {
    my $n = shift();

    $arg++;
    if ($n =~ m/^\d/) {

        #   Number                  List numeric and character representations

        #   Argument is a number: use oct() to convert to binary
        $n = oct($n) if ($n =~ m/^0/);

    } elsif ($n =~ m/^(b|l)=(.+)/) {

        #   b=<block name>          List Unicode blocks matching name

        my $bl = $1;
        my $cpat = qr/$2/i;
        my $listall = $bl =~ m/l/i;

        my $k;
        for $k (@UNICODE_BLOCKS) {
        if ($k->[2] =~ m/$cpat/) {
            if (!$blocktitle) {
            $chartitle = 0;
            $blocktitle = 1;
            print("   Start        End  Unicode Block\n");
            }
            printf("%8s - %8s  %s\n",
            sprintf("U+%04X", $k->[0]),
            sprintf("U+%04X", $k->[1]),
            $k->[2]);

            if ($listall) {
            for (my $i = $k->[0]; $i <= $k->[1]; $i++) {
                showchar($i);
            }
            }
        }
        }
        next;

    } elsif ($n =~ m/^h=(.+)/) {

        #   h=<character name>      List XHTML character entities matching name

        my $cpat = qr/$1/i;

        my $k;
        for $k (sort {$a <=> $b} keys(%XHTML_ENTITIES)) {
        if ($XHTML_ENTITIES{$k} =~ m/$cpat/) {
            showchar($k);
        }
        }
        next;

    } elsif ($n =~ m/^n=(.+)/) {

        #   n=<character name>      List Unicode characters matching name

        my $cpat = qr/$1/i;

        #   The following would be faster if we selected matching
        #   characters into an auxiliary array and then sorted
        #   the selected ones before printing.  In fact, the time it
        #   takes to sort the entire list is less than that consumed
        #   in init_names() loading it, so there's little point bothering
        #   with this refinement.
        my $k;
        for $k (sort {oct("0x$a") <=> oct("0x$b")} keys(%UNICODE_NAMES)) {
        if ($UNICODE_NAMES{$k} =~ m/$cpat/) {
            showchar(oct("0x$k"));
        }
        }
        next;

    } elsif ($n =~ m/^&#/) {

        #   '&#NNN;&#xNNNN;...'     One or more XHTML numeric entities

        my @htmlent;
        while ($n =~ s/&#(x?[0-9A-Fa-f]+);//) {
        my $hch = $1;
        $hch =~ s/^x/0x/;
        push(@htmlent, $hch);
        }
        unshift(@ARGV, @htmlent);
        next;

    } else {

        #   =<char>... or c=<char>...   List code for one or more characters

        #   If argument is an equal sign followed by a single
        #   character, take the second character as the argument.
        #   This allows treating digits as characters to be looked
        #   up.
        $n =~ s/^c?=(.+)$/$1/i;

        while ($n =~ s/^(.)//) {
        showchar(ord($1));
        }
        next;
    }

    showchar($n);
    }

    #   Show a numeric code in all its manifestations

    sub showchar {
    my ($n) = @_;


    my $ch = ((($n >= 32) && ($n < 128)) || ($n > 160)) ?
        chr($n) :
        sprintf("\\x{%X}", $n);

    #   Determine the Unicode character code as best we can

    my $u = uname($n);
    if (!defined($u)) {
        $u = ublock($n);
        if (defined($u)) {
        $u = sprintf("%s U+%05X", $u, $n);
        } else {
        $u = sprintf("Undefined U+%05X", $n);
        }
    }

    if (!$chartitle) {
        $blocktitle = 0;
        $chartitle = 1;
        print("   Octal  Decimal      Hex        HTML    Character   Unicode\n");
    }

    printf("%8s %8d %8s %11s    %-8s    %s\n",
        sprintf("0%lo", $n),
        $n,
        sprintf("0x%X", $n),
        defined($XHTML_ENTITIES{$n}) ? "&$XHTML_ENTITIES{$n};"
                    : sprintf("&#%d;", $n),
        sprintf("\"%s\"", $ch),
        $u);
    }

=pod

The Unicode character tables are derived from the Unicode::CharName
module:

=over 4

Copyright 1997,2005 Gisle Aas.

The Unicode::CharName library is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

Name table extracted from the Unicode 4.1 Character
Database. Copyright (c) 1991-2005 Unicode, Inc. All Rights reserved.

The original Unicode::CharName module may be found at:

    http://search.cpan.org/~gaas/Unicode-String-2.09/lib/Unicode/CharName.pm

The control characters in this B<unum> version have been annotated
with their Unicode abbreviations, names, and for U+0000 to U+001F,
the Ctrl-letter code which generates them.

=back

=cut

    sub uname {
    my $code = shift;
    if ($code >= 0x4E00) {
        if ($code <= 0x9FFF || ($code >= 0xF900 && $code <= 0xFAFF)) {
        # CJK Ideographs
        return sprintf "CJK UNIFIED IDEOGRAPH %04X", $code;
        } elsif ($code >= 0xD800 && $code <= 0xF8FF) {
        # Surrogate and private
        if ($code <= 0xDFFF) {
            return "<surrogate>";
        } else {
            return "<private>";
        }
        } elsif ($code >= 0xAC00 && $code <= 0xD7A3) {
        # Hangul Syllables
        my $sindex = $code - 0xAC00;
        my $l = 0x1100 + int($sindex / (21*28));
        my $v = 0x1161 + int(($sindex % (21*28)) / 28);
        my $t = 0x11A7 + $sindex % 28;
        my @s = ($l, $v, $t);
        pop(@s) if $t == 0x11A7;
        @s = map {
            $_ = sprintf("%04X", $_);
            $JAMO_SHORT_NAME{$_} || " U+$_ ";
        } @s;
        return join("", "HANGUL SYLLABLE ", @s)
        }
    }
    $UNICODE_NAMES{sprintf("%04X",$code)}
    }

    sub ublock {
    my $code = shift;
    # XXX: could use a binary search, but I am too lazy today...
    my $block;
    for $block (@UNICODE_BLOCKS) {
        return $block->[2] if $block->[0] <= $code && $block->[1] >= $code;
    }
    undef;
    }

    sub init_names {
    keys %UNICODE_NAMES = 16351;  # preextent
    keys %XHTML_ENTITIES = 253;

    while (<DATA>) {
        chop;
        my($code, $name) = split(' ', $_, 2);
        $UNICODE_NAMES{$code} = $name;
    }
    close(DATA);

    #   XHTML 1.0 Entity Definitions
    %XHTML_ENTITIES = (
        #   From http://www.w3.org/TR/xhtml1/DTD/xhtml-lat1.ent
        160 => 'nbsp',
        161 => 'iexcl',
        162 => 'cent',
        163 => 'pound',
        164 => 'curren',
        165 => 'yen',
        166 => 'brvbar',
        167 => 'sect',
        168 => 'uml',
        169 => 'copy',
        170 => 'ordf',
        171 => 'laquo',
        172 => 'not',
        173 => 'shy',
        174 => 'reg',
        175 => 'macr',
        176 => 'deg',
        177 => 'plusmn',
        178 => 'sup2',
        179 => 'sup3',
        180 => 'acute',
        181 => 'micro',
        182 => 'para',
        183 => 'middot',
        184 => 'cedil',
        185 => 'sup1',
        186 => 'ordm',
        187 => 'raquo',
        188 => 'frac14',
        189 => 'frac12',
        190 => 'frac34',
        191 => 'iquest',
        192 => 'Agrave',
        193 => 'Aacute',
        194 => 'Acirc',
        195 => 'Atilde',
        196 => 'Auml',
        197 => 'Aring',
        198 => 'AElig',
        199 => 'Ccedil',
        200 => 'Egrave',
        201 => 'Eacute',
        202 => 'Ecirc',
        203 => 'Euml',
        204 => 'Igrave',
        205 => 'Iacute',
        206 => 'Icirc',
        207 => 'Iuml',
        208 => 'ETH',
        209 => 'Ntilde',
        210 => 'Ograve',
        211 => 'Oacute',
        212 => 'Ocirc',
        213 => 'Otilde',
        214 => 'Ouml',
        215 => 'times',
        216 => 'Oslash',
        217 => 'Ugrave',
        218 => 'Uacute',
        219 => 'Ucirc',
        220 => 'Uuml',
        221 => 'Yacute',
        222 => 'THORN',
        223 => 'szlig',
        224 => 'agrave',
        225 => 'aacute',
        226 => 'acirc',
        227 => 'atilde',
        228 => 'auml',
        229 => 'aring',
        230 => 'aelig',
        231 => 'ccedil',
        232 => 'egrave',
        233 => 'eacute',
        234 => 'ecirc',
        235 => 'euml',
        236 => 'igrave',
        237 => 'iacute',
        238 => 'icirc',
        239 => 'iuml',
        240 => 'eth',
        241 => 'ntilde',
        242 => 'ograve',
        243 => 'oacute',
        244 => 'ocirc',
        245 => 'otilde',
        246 => 'ouml',
        247 => 'divide',
        248 => 'oslash',
        249 => 'ugrave',
        250 => 'uacute',
        251 => 'ucirc',
        252 => 'uuml',
        253 => 'yacute',
        254 => 'thorn',
        255 => 'yuml',
        #   From http://www.w3.org/TR/xhtml1/DTD/xhtml-special.ent
        34 => 'quot',
        38 => 'amp',
        60 => 'lt',
        62 => 'gt',
        39 => 'apos',
        338 => 'OElig',
        339 => 'oelig',
        352 => 'Scaron',
        353 => 'scaron',
        376 => 'Yuml',
        710 => 'circ',
        732 => 'tilde',
        8194 => 'ensp',
        8195 => 'emsp',
        8201 => 'thinsp',
        8204 => 'zwnj',
        8205 => 'zwj',
        8206 => 'lrm',
        8207 => 'rlm',
        8211 => 'ndash',
        8212 => 'mdash',
        8216 => 'lsquo',
        8217 => 'rsquo',
        8218 => 'sbquo',
        8220 => 'ldquo',
        8221 => 'rdquo',
        8222 => 'bdquo',
        8224 => 'dagger',
        8225 => 'Dagger',
        8240 => 'permil',
        8249 => 'lsaquo',
        8250 => 'rsaquo',
        8364 => 'euro',
        #   From http://www.w3.org/TR/xhtml1/DTD/xhtml-symbol.ent
        402 => 'fnof',
        913 => 'Alpha',
        914 => 'Beta',
        915 => 'Gamma',
        916 => 'Delta',
        917 => 'Epsilon',
        918 => 'Zeta',
        919 => 'Eta',
        920 => 'Theta',
        921 => 'Iota',
        922 => 'Kappa',
        923 => 'Lambda',
        924 => 'Mu',
        925 => 'Nu',
        926 => 'Xi',
        927 => 'Omicron',
        928 => 'Pi',
        929 => 'Rho',
        931 => 'Sigma',
        932 => 'Tau',
        933 => 'Upsilon',
        934 => 'Phi',
        935 => 'Chi',
        936 => 'Psi',
        937 => 'Omega',
        945 => 'alpha',
        946 => 'beta',
        947 => 'gamma',
        948 => 'delta',
        949 => 'epsilon',
        950 => 'zeta',
        951 => 'eta',
        952 => 'theta',
        953 => 'iota',
        954 => 'kappa',
        955 => 'lambda',
        956 => 'mu',
        957 => 'nu',
        958 => 'xi',
        959 => 'omicron',
        960 => 'pi',
        961 => 'rho',
        962 => 'sigmaf',
        963 => 'sigma',
        964 => 'tau',
        965 => 'upsilon',
        966 => 'phi',
        967 => 'chi',
        968 => 'psi',
        969 => 'omega',
        977 => 'thetasym',
        978 => 'upsih',
        982 => 'piv',
        8226 => 'bull',
        8230 => 'hellip',
        8242 => 'prime',
        8243 => 'Prime',
        8254 => 'oline',
        8260 => 'frasl',
        8472 => 'weierp',
        8465 => 'image',
        8476 => 'real',
        8482 => 'trade',
        8501 => 'alefsym',
        8592 => 'larr',
        8593 => 'uarr',
        8594 => 'rarr',
        8595 => 'darr',
        8596 => 'harr',
        8629 => 'crarr',
        8656 => 'lArr',
        8657 => 'uArr',
        8658 => 'rArr',
        8659 => 'dArr',
        8660 => 'hArr',
        8704 => 'forall',
        8706 => 'part',
        8707 => 'exist',
        8709 => 'empty',
        8711 => 'nabla',
        8712 => 'isin',
        8713 => 'notin',
        8715 => 'ni',
        8719 => 'prod',
        8721 => 'sum',
        8722 => 'minus',
        8727 => 'lowast',
        8730 => 'radic',
        8733 => 'prop',
        8734 => 'infin',
        8736 => 'ang',
        8743 => 'and',
        8744 => 'or',
        8745 => 'cap',
        8746 => 'cup',
        8747 => 'int',
        8756 => 'there4',
        8764 => 'sim',
        8773 => 'cong',
        8776 => 'asymp',
        8800 => 'ne',
        8801 => 'equiv',
        8804 => 'le',
        8805 => 'ge',
        8834 => 'sub',
        8835 => 'sup',
        8836 => 'nsub',
        8838 => 'sube',
        8839 => 'supe',
        8853 => 'oplus',
        8855 => 'otimes',
        8869 => 'perp',
        8901 => 'sdot',
        8968 => 'lceil',
        8969 => 'rceil',
        8970 => 'lfloor',
        8971 => 'rfloor',
        9001 => 'lang',
        9002 => 'rang',
        9674 => 'loz',
        9824 => 'spades',
        9827 => 'clubs',
        9829 => 'hearts',
        9830 => 'diams'
    );

    @UNICODE_BLOCKS = (
    #  start   end        block name
      [0x0000, 0x007F => 'Basic Latin'],
      [0x0080, 0x00FF => 'Latin-1 Supplement'],
      [0x0100, 0x017F => 'Latin Extended-A'],
      [0x0180, 0x024F => 'Latin Extended-B'],
      [0x0250, 0x02AF => 'IPA Extensions'],
      [0x02B0, 0x02FF => 'Spacing Modifier Letters'],
      [0x0300, 0x036F => 'Combining Diacritical Marks'],
      [0x0370, 0x03FF => 'Greek and Coptic'],
      [0x0400, 0x04FF => 'Cyrillic'],
      [0x0500, 0x052F => 'Cyrillic Supplement'],
      [0x0530, 0x058F => 'Armenian'],
      [0x0590, 0x05FF => 'Hebrew'],
      [0x0600, 0x06FF => 'Arabic'],
      [0x0700, 0x074F => 'Syriac'],
      [0x0750, 0x077F => 'Arabic Supplement'],
      [0x0780, 0x07BF => 'Thaana'],
      [0x0900, 0x097F => 'Devanagari'],
      [0x0980, 0x09FF => 'Bengali'],
      [0x0A00, 0x0A7F => 'Gurmukhi'],
      [0x0A80, 0x0AFF => 'Gujarati'],
      [0x0B00, 0x0B7F => 'Oriya'],
      [0x0B80, 0x0BFF => 'Tamil'],
      [0x0C00, 0x0C7F => 'Telugu'],
      [0x0C80, 0x0CFF => 'Kannada'],
      [0x0D00, 0x0D7F => 'Malayalam'],
      [0x0D80, 0x0DFF => 'Sinhala'],
      [0x0E00, 0x0E7F => 'Thai'],
      [0x0E80, 0x0EFF => 'Lao'],
      [0x0F00, 0x0FFF => 'Tibetan'],
      [0x1000, 0x109F => 'Myanmar'],
      [0x10A0, 0x10FF => 'Georgian'],
      [0x1100, 0x11FF => 'Hangul Jamo'],
      [0x1200, 0x137F => 'Ethiopic'],
      [0x1380, 0x139F => 'Ethiopic Supplement'],
      [0x13A0, 0x13FF => 'Cherokee'],
      [0x1400, 0x167F => 'Unified Canadian Aboriginal Syllabics'],
      [0x1680, 0x169F => 'Ogham'],
      [0x16A0, 0x16FF => 'Runic'],
      [0x1700, 0x171F => 'Tagalog'],
      [0x1720, 0x173F => 'Hanunoo'],
      [0x1740, 0x175F => 'Buhid'],
      [0x1760, 0x177F => 'Tagbanwa'],
      [0x1780, 0x17FF => 'Khmer'],
      [0x1800, 0x18AF => 'Mongolian'],
      [0x1900, 0x194F => 'Limbu'],
      [0x1950, 0x197F => 'Tai Le'],
      [0x1980, 0x19DF => 'New Tai Lue'],
      [0x19E0, 0x19FF => 'Khmer Symbols'],
      [0x1A00, 0x1A1F => 'Buginese'],
      [0x1D00, 0x1D7F => 'Phonetic Extensions'],
      [0x1D80, 0x1DBF => 'Phonetic Extensions Supplement'],
      [0x1DC0, 0x1DFF => 'Combining Diacritical Marks Supplement'],
      [0x1E00, 0x1EFF => 'Latin Extended Additional'],
      [0x1F00, 0x1FFF => 'Greek Extended'],
      [0x2000, 0x206F => 'General Punctuation'],
      [0x2070, 0x209F => 'Superscripts and Subscripts'],
      [0x20A0, 0x20CF => 'Currency Symbols'],
      [0x20D0, 0x20FF => 'Combining Diacritical Marks for Symbols'],
      [0x2100, 0x214F => 'Letterlike Symbols'],
      [0x2150, 0x218F => 'Number Forms'],
      [0x2190, 0x21FF => 'Arrows'],
      [0x2200, 0x22FF => 'Mathematical Operators'],
      [0x2300, 0x23FF => 'Miscellaneous Technical'],
      [0x2400, 0x243F => 'Control Pictures'],
      [0x2440, 0x245F => 'Optical Character Recognition'],
      [0x2460, 0x24FF => 'Enclosed Alphanumerics'],
      [0x2500, 0x257F => 'Box Drawing'],
      [0x2580, 0x259F => 'Block Elements'],
      [0x25A0, 0x25FF => 'Geometric Shapes'],
      [0x2600, 0x26FF => 'Miscellaneous Symbols'],
      [0x2700, 0x27BF => 'Dingbats'],
      [0x27C0, 0x27EF => 'Miscellaneous Mathematical Symbols-A'],
      [0x27F0, 0x27FF => 'Supplemental Arrows-A'],
      [0x2800, 0x28FF => 'Braille Patterns'],
      [0x2900, 0x297F => 'Supplemental Arrows-B'],
      [0x2980, 0x29FF => 'Miscellaneous Mathematical Symbols-B'],
      [0x2A00, 0x2AFF => 'Supplemental Mathematical Operators'],
      [0x2B00, 0x2BFF => 'Miscellaneous Symbols and Arrows'],
      [0x2C00, 0x2C5F => 'Glagolitic'],
      [0x2C80, 0x2CFF => 'Coptic'],
      [0x2D00, 0x2D2F => 'Georgian Supplement'],
      [0x2D30, 0x2D7F => 'Tifinagh'],
      [0x2D80, 0x2DDF => 'Ethiopic Extended'],
      [0x2E00, 0x2E7F => 'Supplemental Punctuation'],
      [0x2E80, 0x2EFF => 'CJK Radicals Supplement'],
      [0x2F00, 0x2FDF => 'Kangxi Radicals'],
      [0x2FF0, 0x2FFF => 'Ideographic Description Characters'],
      [0x3000, 0x303F => 'CJK Symbols and Punctuation'],
      [0x3040, 0x309F => 'Hiragana'],
      [0x30A0, 0x30FF => 'Katakana'],
      [0x3100, 0x312F => 'Bopomofo'],
      [0x3130, 0x318F => 'Hangul Compatibility Jamo'],
      [0x3190, 0x319F => 'Kanbun'],
      [0x31A0, 0x31BF => 'Bopomofo Extended'],
      [0x31C0, 0x31EF => 'CJK Strokes'],
      [0x31F0, 0x31FF => 'Katakana Phonetic Extensions'],
      [0x3200, 0x32FF => 'Enclosed CJK Letters and Months'],
      [0x3300, 0x33FF => 'CJK Compatibility'],
      [0x3400, 0x4DBF => 'CJK Unified Ideographs Extension A'],
      [0x4DC0, 0x4DFF => 'Yijing Hexagram Symbols'],
      [0x4E00, 0x9FFF => 'CJK Unified Ideographs'],
      [0xA000, 0xA48F => 'Yi Syllables'],
      [0xA490, 0xA4CF => 'Yi Radicals'],
      [0xA700, 0xA71F => 'Modifier Tone Letters'],
      [0xA800, 0xA82F => 'Syloti Nagri'],
      [0xAC00, 0xD7AF => 'Hangul Syllables'],
      [0xD800, 0xDB7F => 'High Surrogates'],
      [0xDB80, 0xDBFF => 'High Private Use Surrogates'],
      [0xDC00, 0xDFFF => 'Low Surrogates'],
      [0xE000, 0xF8FF => 'Private Use Area'],
      [0xF900, 0xFAFF => 'CJK Compatibility Ideographs'],
      [0xFB00, 0xFB4F => 'Alphabetic Presentation Forms'],
      [0xFB50, 0xFDFF => 'Arabic Presentation Forms-A'],
      [0xFE00, 0xFE0F => 'Variation Selectors'],
      [0xFE10, 0xFE1F => 'Vertical Forms'],
      [0xFE20, 0xFE2F => 'Combining Half Marks'],
      [0xFE30, 0xFE4F => 'CJK Compatibility Forms'],
      [0xFE50, 0xFE6F => 'Small Form Variants'],
      [0xFE70, 0xFEFF => 'Arabic Presentation Forms-B'],
      [0xFF00, 0xFFEF => 'Halfwidth and Fullwidth Forms'],
      [0xFFF0, 0xFFFF => 'Specials'],
      [0x10000, 0x1007F => 'Linear B Syllabary'],
      [0x10080, 0x100FF => 'Linear B Ideograms'],
      [0x10100, 0x1013F => 'Aegean Numbers'],
      [0x10140, 0x1018F => 'Ancient Greek Numbers'],
      [0x10300, 0x1032F => 'Old Italic'],
      [0x10330, 0x1034F => 'Gothic'],
      [0x10380, 0x1039F => 'Ugaritic'],
      [0x103A0, 0x103DF => 'Old Persian'],
      [0x10400, 0x1044F => 'Deseret'],
      [0x10450, 0x1047F => 'Shavian'],
      [0x10480, 0x104AF => 'Osmanya'],
      [0x10800, 0x1083F => 'Cypriot Syllabary'],
      [0x10A00, 0x10A5F => 'Kharoshthi'],
      [0x1D000, 0x1D0FF => 'Byzantine Musical Symbols'],
      [0x1D100, 0x1D1FF => 'Musical Symbols'],
      [0x1D200, 0x1D24F => 'Ancient Greek Musical Notation'],
      [0x1D300, 0x1D35F => 'Tai Xuan Jing Symbols'],
      [0x1D400, 0x1D7FF => 'Mathematical Alphanumeric Symbols'],
      [0x20000, 0x2A6DF => 'CJK Unified Ideographs Extension B'],
      [0x2F800, 0x2FA1F => 'CJK Compatibility Ideographs Supplement'],
      [0xE0000, 0xE007F => 'Tags'],
      [0xE0100, 0xE01EF => 'Variation Selectors Supplement'],
      [0xF0000, 0xFFFFF => 'Supplementary Private Use Area-A'],
      [0x100000, 0x10FFFF => 'Supplementary Private Use Area-B'],
    );

    %JAMO_SHORT_NAME = (
        '1100' => 'G',
        '1101' => 'GG',
        '1102' => 'N',
        '1103' => 'D',
        '1104' => 'DD',
        '1105' => 'L',
        '1106' => 'M',
        '1107' => 'B',
        '1108' => 'BB',
        '1109' => 'S',
        '110A' => 'SS',
        '110B' => '',
        '110C' => 'J',
        '110D' => 'JJ',
        '110E' => 'C',
        '110F' => 'K',
        '1110' => 'T',
        '1111' => 'P',
        '1112' => 'H',
        '1161' => 'A',
        '1162' => 'AE',
        '1163' => 'YA',
        '1164' => 'YAE',
        '1165' => 'EO',
        '1166' => 'E',
        '1167' => 'YEO',
        '1168' => 'YE',
        '1169' => 'O',
        '116A' => 'WA',
        '116B' => 'WAE',
        '116C' => 'OE',
        '116D' => 'YO',
        '116E' => 'U',
        '116F' => 'WEO',
        '1170' => 'WE',
        '1171' => 'WI',
        '1172' => 'YU',
        '1173' => 'EU',
        '1174' => 'YI',
        '1175' => 'I',
        '11A8' => 'G',
        '11A9' => 'GG',
        '11AA' => 'GS',
        '11AB' => 'N',
        '11AC' => 'NJ',
        '11AD' => 'NH',
        '11AE' => 'D',
        '11AF' => 'L',
        '11B0' => 'LG',
        '11B1' => 'LM',
        '11B2' => 'LB',
        '11B3' => 'LS',
        '11B4' => 'LT',
        '11B5' => 'LP',
        '11B6' => 'LH',
        '11B7' => 'M',
        '11B8' => 'B',
        '11B9' => 'BS',
        '11BA' => 'S',
        '11BB' => 'SS',
        '11BC' => 'NG',
        '11BD' => 'J',
        '11BE' => 'C',
        '11BF' => 'K',
        '11C0' => 'T',
        '11C1' => 'P',
        '11C2' => 'H',
    );
    }

__DATA__
0000 <control> NUL NULL Ctrl-@
0001 <control> SOH START OF HEADING Ctrl-A
0002 <control> STX START OF TEXT Ctrl-B
0003 <control> ETX END OF TEXT Ctrl-C
0004 <control> EOT END OF TRANSMISSION Ctrl-D
0005 <control> ENQ ENQUIRY Ctrl-E
0006 <control> ACK ACKNOWLEDGE Ctrl-F
0007 <control> BEL BELL Ctrl-G
0008 <control> BS BACKSPACE Ctrl-H
0009 <control> HT CHARACTER TABULATION Ctrl-I
000A <control> LF LINE FEED Ctrl-J
000B <control> VT LINE TABULATION Ctrl-K
000C <control> FF FORM FEED Ctrl-L
000D <control> CR CARRIAGE RETURN Ctrl-M
000E <control> SO SHIFT OUT Ctrl-N
000F <control> SI SHIFT IN Ctrl-O
0010 <control> DLE DATA LINK ESCAPE Ctrl-P
0011 <control> DC1 DEVICE CONTROL ONE Ctrl-Q
0012 <control> DC2 DEVICE CONTROL TWO Ctrl-R
0013 <control> DC3 DEVICE CONTROL THREE Ctrl-S
0014 <control> DC4 DEVICE CONTROL FOUR Ctrl-T
0015 <control> NAK NEGATIVE ACKNOWLEDGE Ctrl-U
0016 <control> SYN SYNCHRONOUS IDLE Ctrl-V
0017 <control> ETB END OF TRANSMISSION BLOCK Ctrl-W
0018 <control> CAN CANCEL Ctrl-X
0019 <control> EM END OF MEDIUM Ctrl-Y
001A <control> SUB SUBSTITUTE Ctrl-Z
001B <control> ESC ESCAPE Ctrl-[
001C <control> FS INFORMATION SEPARATOR FOUR Ctrl-\
001D <control> GS INFORMATION SEPARATOR THREE Ctrl-]
001E <control> RS INFORMATION SEPARATOR TWO Ctrl-^
001F <control> US INFORMATION SEPARATOR ONE Ctrl-_
0020 SPACE
0021 EXCLAMATION MARK
0022 QUOTATION MARK
0023 NUMBER SIGN
0024 DOLLAR SIGN
0025 PERCENT SIGN
0026 AMPERSAND
0027 APOSTROPHE
0028 LEFT PARENTHESIS
0029 RIGHT PARENTHESIS
002A ASTERISK
002B PLUS SIGN
002C COMMA
002D HYPHEN-MINUS
002E FULL STOP
002F SOLIDUS
0030 DIGIT ZERO
0031 DIGIT ONE
0032 DIGIT TWO
0033 DIGIT THREE
0034 DIGIT FOUR
0035 DIGIT FIVE
0036 DIGIT SIX
0037 DIGIT SEVEN
0038 DIGIT EIGHT
0039 DIGIT NINE
003A COLON
003B SEMICOLON
003C LESS-THAN SIGN
003D EQUALS SIGN
003E GREATER-THAN SIGN
003F QUESTION MARK
0040 COMMERCIAL AT
0041 LATIN CAPITAL LETTER A
0042 LATIN CAPITAL LETTER B
0043 LATIN CAPITAL LETTER C
0044 LATIN CAPITAL LETTER D
0045 LATIN CAPITAL LETTER E
0046 LATIN CAPITAL LETTER F
0047 LATIN CAPITAL LETTER G
0048 LATIN CAPITAL LETTER H
0049 LATIN CAPITAL LETTER I
004A LATIN CAPITAL LETTER J
004B LATIN CAPITAL LETTER K
004C LATIN CAPITAL LETTER L
004D LATIN CAPITAL LETTER M
004E LATIN CAPITAL LETTER N
004F LATIN CAPITAL LETTER O
0050 LATIN CAPITAL LETTER P
0051 LATIN CAPITAL LETTER Q
0052 LATIN CAPITAL LETTER R
0053 LATIN CAPITAL LETTER S
0054 LATIN CAPITAL LETTER T
0055 LATIN CAPITAL LETTER U
0056 LATIN CAPITAL LETTER V
0057 LATIN CAPITAL LETTER W
0058 LATIN CAPITAL LETTER X
0059 LATIN CAPITAL LETTER Y
005A LATIN CAPITAL LETTER Z
005B LEFT SQUARE BRACKET
005C REVERSE SOLIDUS
005D RIGHT SQUARE BRACKET
005E CIRCUMFLEX ACCENT
005F LOW LINE
0060 GRAVE ACCENT
0061 LATIN SMALL LETTER A
0062 LATIN SMALL LETTER B
0063 LATIN SMALL LETTER C
0064 LATIN SMALL LETTER D
0065 LATIN SMALL LETTER E
0066 LATIN SMALL LETTER F
0067 LATIN SMALL LETTER G
0068 LATIN SMALL LETTER H
0069 LATIN SMALL LETTER I
006A LATIN SMALL LETTER J
006B LATIN SMALL LETTER K
006C LATIN SMALL LETTER L
006D LATIN SMALL LETTER M
006E LATIN SMALL LETTER N
006F LATIN SMALL LETTER O
0070 LATIN SMALL LETTER P
0071 LATIN SMALL LETTER Q
0072 LATIN SMALL LETTER R
0073 LATIN SMALL LETTER S
0074 LATIN SMALL LETTER T
0075 LATIN SMALL LETTER U
0076 LATIN SMALL LETTER V
0077 LATIN SMALL LETTER W
0078 LATIN SMALL LETTER X
0079 LATIN SMALL LETTER Y
007A LATIN SMALL LETTER Z
007B LEFT CURLY BRACKET
007C VERTICAL LINE
007D RIGHT CURLY BRACKET
007E TILDE
007F <control> DEL DELETE
0080 <control> XXX
0081 <control> XXX
0082 <control> BPH BREAK PERMITTED HERE
0083 <control> NBH NO BREAK HERE
0084 <control> IND
0085 <control> NEL NEXT LINE
0086 <control> SSA START OF SELECTED AREA
0087 <control> ESA END OF SELECTED AREA
0088 <control> HTS CHARACTER TABULATION SET
0089 <control> HTJ CHARACTER TABULATION WITH JUSTIFICATION
008A <control> VTS LINE TABULATION SET
008B <control> PLD PARTIAL LINE FORWARD
008C <control> PLU PARTIAL LINE BACKWARD
008D <control> RI REVERSE LINE FEED
008E <control> SS2 SINGLE SHIFT TWO
008F <control> SS3 SINGLE SHIFT THREE
0090 <control> DCS DEVICE CONTROL STRING
0091 <control> PU1 PRIVATE USE ONE
0092 <control> PU2 PRIVATE USE TWO
0093 <control> STS SET TRANSMIT STATE
0094 <control> CCH CANCEL CHARACTER
0095 <control> MW MESSAGE WAITING
0096 <control> SPA START OF GUARDED AREA
0097 <control> EPA END OF GUARDED AREA
0098 <control> SOS START OF STRING
0099 <control> XXX
009A <control> SCI SINGLE CHARACTER INTRODUCER
009B <control> CSI CONTRIL SEQUENCE INTRODUCER
009C <control> ST STRING TERMINATOR
009D <control> OSC OPERATING SYSTEM COMMAND
009E <control> PM PRIVACY MESSAGE
009F <control> APC APPLICATION PROGRAM COMMAND
00A0 NO-BREAK SPACE
00A1 INVERTED EXCLAMATION MARK
00A2 CENT SIGN
00A3 POUND SIGN
00A4 CURRENCY SIGN
00A5 YEN SIGN
00A6 BROKEN BAR
00A7 SECTION SIGN
00A8 DIAERESIS
00A9 COPYRIGHT SIGN
00AA FEMININE ORDINAL INDICATOR
00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
00AC NOT SIGN
00AD SOFT HYPHEN
00AE REGISTERED SIGN
00AF MACRON
00B0 DEGREE SIGN
00B1 PLUS-MINUS SIGN
00B2 SUPERSCRIPT TWO
00B3 SUPERSCRIPT THREE
00B4 ACUTE ACCENT
00B5 MICRO SIGN
00B6 PILCROW SIGN
00B7 MIDDLE DOT
00B8 CEDILLA
00B9 SUPERSCRIPT ONE
00BA MASCULINE ORDINAL INDICATOR
00BB RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
00BC VULGAR FRACTION ONE QUARTER
00BD VULGAR FRACTION ONE HALF
00BE VULGAR FRACTION THREE QUARTERS
00BF INVERTED QUESTION MARK
00C0 LATIN CAPITAL LETTER A WITH GRAVE
00C1 LATIN CAPITAL LETTER A WITH ACUTE
00C2 LATIN CAPITAL LETTER A WITH CIRCUMFLEX
00C3 LATIN CAPITAL LETTER A WITH TILDE
00C4 LATIN CAPITAL LETTER A WITH DIAERESIS
00C5 LATIN CAPITAL LETTER A WITH RING ABOVE
00C6 LATIN CAPITAL LETTER AE
00C7 LATIN CAPITAL LETTER C WITH CEDILLA
00C8 LATIN CAPITAL LETTER E WITH GRAVE
00C9 LATIN CAPITAL LETTER E WITH ACUTE
00CA LATIN CAPITAL LETTER E WITH CIRCUMFLEX
00CB LATIN CAPITAL LETTER E WITH DIAERESIS
00CC LATIN CAPITAL LETTER I WITH GRAVE
00CD LATIN CAPITAL LETTER I WITH ACUTE
00CE LATIN CAPITAL LETTER I WITH CIRCUMFLEX
00CF LATIN CAPITAL LETTER I WITH DIAERESIS
00D0 LATIN CAPITAL LETTER ETH
00D1 LATIN CAPITAL LETTER N WITH TILDE
00D2 LATIN CAPITAL LETTER O WITH GRAVE
00D3 LATIN CAPITAL LETTER O WITH ACUTE
00D4 LATIN CAPITAL LETTER O WITH CIRCUMFLEX
00D5 LATIN CAPITAL LETTER O WITH TILDE
00D6 LATIN CAPITAL LETTER O WITH DIAERESIS
00D7 MULTIPLICATION SIGN
00D8 LATIN CAPITAL LETTER O WITH STROKE
00D9 LATIN CAPITAL LETTER U WITH GRAVE
00DA LATIN CAPITAL LETTER U WITH ACUTE
00DB LATIN CAPITAL LETTER U WITH CIRCUMFLEX
00DC LATIN CAPITAL LETTER U WITH DIAERESIS
00DD LATIN CAPITAL LETTER Y WITH ACUTE
00DE LATIN CAPITAL LETTER THORN
00DF LATIN SMALL LETTER SHARP S
00E0 LATIN SMALL LETTER A WITH GRAVE
00E1 LATIN SMALL LETTER A WITH ACUTE
00E2 LATIN SMALL LETTER A WITH CIRCUMFLEX
00E3 LATIN SMALL LETTER A WITH TILDE
00E4 LATIN SMALL LETTER A WITH DIAERESIS
00E5 LATIN SMALL LETTER A WITH RING ABOVE
00E6 LATIN SMALL LETTER AE
00E7 LATIN SMALL LETTER C WITH CEDILLA
00E8 LATIN SMALL LETTER E WITH GRAVE
00E9 LATIN SMALL LETTER E WITH ACUTE
00EA LATIN SMALL LETTER E WITH CIRCUMFLEX
00EB LATIN SMALL LETTER E WITH DIAERESIS
00EC LATIN SMALL LETTER I WITH GRAVE
00ED LATIN SMALL LETTER I WITH ACUTE
00EE LATIN SMALL LETTER I WITH CIRCUMFLEX
00EF LATIN SMALL LETTER I WITH DIAERESIS
00F0 LATIN SMALL LETTER ETH
00F1 LATIN SMALL LETTER N WITH TILDE
00F2 LATIN SMALL LETTER O WITH GRAVE
00F3 LATIN SMALL LETTER O WITH ACUTE
00F4 LATIN SMALL LETTER O WITH CIRCUMFLEX
00F5 LATIN SMALL LETTER O WITH TILDE
00F6 LATIN SMALL LETTER O WITH DIAERESIS
00F7 DIVISION SIGN
00F8 LATIN SMALL LETTER O WITH STROKE
00F9 LATIN SMALL LETTER U WITH GRAVE
00FA LATIN SMALL LETTER U WITH ACUTE
00FB LATIN SMALL LETTER U WITH CIRCUMFLEX
00FC LATIN SMALL LETTER U WITH DIAERESIS
00FD LATIN SMALL LETTER Y WITH ACUTE
00FE LATIN SMALL LETTER THORN
00FF LATIN SMALL LETTER Y WITH DIAERESIS
0100 LATIN CAPITAL LETTER A WITH MACRON
0101 LATIN SMALL LETTER A WITH MACRON
0102 LATIN CAPITAL LETTER A WITH BREVE
0103 LATIN SMALL LETTER A WITH BREVE
0104 LATIN CAPITAL LETTER A WITH OGONEK
0105 LATIN SMALL LETTER A WITH OGONEK
0106 LATIN CAPITAL LETTER C WITH ACUTE
0107 LATIN SMALL LETTER C WITH ACUTE
0108 LATIN CAPITAL LETTER C WITH CIRCUMFLEX
0109 LATIN SMALL LETTER C WITH CIRCUMFLEX
010A LATIN CAPITAL LETTER C WITH DOT ABOVE
010B LATIN SMALL LETTER C WITH DOT ABOVE
010C LATIN CAPITAL LETTER C WITH CARON
010D LATIN SMALL LETTER C WITH CARON
010E LATIN CAPITAL LETTER D WITH CARON
010F LATIN SMALL LETTER D WITH CARON
0110 LATIN CAPITAL LETTER D WITH STROKE
0111 LATIN SMALL LETTER D WITH STROKE
0112 LATIN CAPITAL LETTER E WITH MACRON
0113 LATIN SMALL LETTER E WITH MACRON
0114 LATIN CAPITAL LETTER E WITH BREVE
0115 LATIN SMALL LETTER E WITH BREVE
0116 LATIN CAPITAL LETTER E WITH DOT ABOVE
0117 LATIN SMALL LETTER E WITH DOT ABOVE
0118 LATIN CAPITAL LETTER E WITH OGONEK
0119 LATIN SMALL LETTER E WITH OGONEK
011A LATIN CAPITAL LETTER E WITH CARON
011B LATIN SMALL LETTER E WITH CARON
011C LATIN CAPITAL LETTER G WITH CIRCUMFLEX
011D LATIN SMALL LETTER G WITH CIRCUMFLEX
011E LATIN CAPITAL LETTER G WITH BREVE
011F LATIN SMALL LETTER G WITH BREVE
0120 LATIN CAPITAL LETTER G WITH DOT ABOVE
0121 LATIN SMALL LETTER G WITH DOT ABOVE
0122 LATIN CAPITAL LETTER G WITH CEDILLA
0123 LATIN SMALL LETTER G WITH CEDILLA
0124 LATIN CAPITAL LETTER H WITH CIRCUMFLEX
0125 LATIN SMALL LETTER H WITH CIRCUMFLEX
0126 LATIN CAPITAL LETTER H WITH STROKE
0127 LATIN SMALL LETTER H WITH STROKE
0128 LATIN CAPITAL LETTER I WITH TILDE
0129 LATIN SMALL LETTER I WITH TILDE
012A LATIN CAPITAL LETTER I WITH MACRON
012B LATIN SMALL LETTER I WITH MACRON
012C LATIN CAPITAL LETTER I WITH BREVE
012D LATIN SMALL LETTER I WITH BREVE
012E LATIN CAPITAL LETTER I WITH OGONEK
012F LATIN SMALL LETTER I WITH OGONEK
0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
0131 LATIN SMALL LETTER DOTLESS I
0132 LATIN CAPITAL LIGATURE IJ
0133 LATIN SMALL LIGATURE IJ
0134 LATIN CAPITAL LETTER J WITH CIRCUMFLEX
0135 LATIN SMALL LETTER J WITH CIRCUMFLEX
0136 LATIN CAPITAL LETTER K WITH CEDILLA
0137 LATIN SMALL LETTER K WITH CEDILLA
0138 LATIN SMALL LETTER KRA
0139 LATIN CAPITAL LETTER L WITH ACUTE
013A LATIN SMALL LETTER L WITH ACUTE
013B LATIN CAPITAL LETTER L WITH CEDILLA
013C LATIN SMALL LETTER L WITH CEDILLA
013D LATIN CAPITAL LETTER L WITH CARON
013E LATIN SMALL LETTER L WITH CARON
013F LATIN CAPITAL LETTER L WITH MIDDLE DOT
0140 LATIN SMALL LETTER L WITH MIDDLE DOT
0141 LATIN CAPITAL LETTER L WITH STROKE
0142 LATIN SMALL LETTER L WITH STROKE
0143 LATIN CAPITAL LETTER N WITH ACUTE
0144 LATIN SMALL LETTER N WITH ACUTE
0145 LATIN CAPITAL LETTER N WITH CEDILLA
0146 LATIN SMALL LETTER N WITH CEDILLA
0147 LATIN CAPITAL LETTER N WITH CARON
0148 LATIN SMALL LETTER N WITH CARON
0149 LATIN SMALL LETTER N PRECEDED BY APOSTROPHE
014A LATIN CAPITAL LETTER ENG
014B LATIN SMALL LETTER ENG
014C LATIN CAPITAL LETTER O WITH MACRON
014D LATIN SMALL LETTER O WITH MACRON
014E LATIN CAPITAL LETTER O WITH BREVE
014F LATIN SMALL LETTER O WITH BREVE
0150 LATIN CAPITAL LETTER O WITH DOUBLE ACUTE
0151 LATIN SMALL LETTER O WITH DOUBLE ACUTE
0152 LATIN CAPITAL LIGATURE OE
0153 LATIN SMALL LIGATURE OE
0154 LATIN CAPITAL LETTER R WITH ACUTE
0155 LATIN SMALL LETTER R WITH ACUTE
0156 LATIN CAPITAL LETTER R WITH CEDILLA
0157 LATIN SMALL LETTER R WITH CEDILLA
0158 LATIN CAPITAL LETTER R WITH CARON
0159 LATIN SMALL LETTER R WITH CARON
015A LATIN CAPITAL LETTER S WITH ACUTE
015B LATIN SMALL LETTER S WITH ACUTE
015C LATIN CAPITAL LETTER S WITH CIRCUMFLEX
015D LATIN SMALL LETTER S WITH CIRCUMFLEX
015E LATIN CAPITAL LETTER S WITH CEDILLA
015F LATIN SMALL LETTER S WITH CEDILLA
0160 LATIN CAPITAL LETTER S WITH CARON
0161 LATIN SMALL LETTER S WITH CARON
0162 LATIN CAPITAL LETTER T WITH CEDILLA
0163 LATIN SMALL LETTER T WITH CEDILLA
0164 LATIN CAPITAL LETTER T WITH CARON
0165 LATIN SMALL LETTER T WITH CARON
0166 LATIN CAPITAL LETTER T WITH STROKE
0167 LATIN SMALL LETTER T WITH STROKE
0168 LATIN CAPITAL LETTER U WITH TILDE
0169 LATIN SMALL LETTER U WITH TILDE
016A LATIN CAPITAL LETTER U WITH MACRON
016B LATIN SMALL LETTER U WITH MACRON
016C LATIN CAPITAL LETTER U WITH BREVE
016D LATIN SMALL LETTER U WITH BREVE
016E LATIN CAPITAL LETTER U WITH RING ABOVE
016F LATIN SMALL LETTER U WITH RING ABOVE
0170 LATIN CAPITAL LETTER U WITH DOUBLE ACUTE
0171 LATIN SMALL LETTER U WITH DOUBLE ACUTE
0172 LATIN CAPITAL LETTER U WITH OGONEK
0173 LATIN SMALL LETTER U WITH OGONEK
0174 LATIN CAPITAL LETTER W WITH CIRCUMFLEX
0175 LATIN SMALL LETTER W WITH CIRCUMFLEX
0176 LATIN CAPITAL LETTER Y WITH CIRCUMFLEX
0177 LATIN SMALL LETTER Y WITH CIRCUMFLEX
0178 LATIN CAPITAL LETTER Y WITH DIAERESIS
0179 LATIN CAPITAL LETTER Z WITH ACUTE
017A LATIN SMALL LETTER Z WITH ACUTE
017B LATIN CAPITAL LETTER Z WITH DOT ABOVE
017C LATIN SMALL LETTER Z WITH DOT ABOVE
017D LATIN CAPITAL LETTER Z WITH CARON
017E LATIN SMALL LETTER Z WITH CARON
017F LATIN SMALL LETTER LONG S
0180 LATIN SMALL LETTER B WITH STROKE
0181 LATIN CAPITAL LETTER B WITH HOOK
0182 LATIN CAPITAL LETTER B WITH TOPBAR
0183 LATIN SMALL LETTER B WITH TOPBAR
0184 LATIN CAPITAL LETTER TONE SIX
0185 LATIN SMALL LETTER TONE SIX
0186 LATIN CAPITAL LETTER OPEN O
0187 LATIN CAPITAL LETTER C WITH HOOK
0188 LATIN SMALL LETTER C WITH HOOK
0189 LATIN CAPITAL LETTER AFRICAN D
018A LATIN CAPITAL LETTER D WITH HOOK
018B LATIN CAPITAL LETTER D WITH TOPBAR
018C LATIN SMALL LETTER D WITH TOPBAR
018D LATIN SMALL LETTER TURNED DELTA
018E LATIN CAPITAL LETTER REVERSED E
018F LATIN CAPITAL LETTER SCHWA
0190 LATIN CAPITAL LETTER OPEN E
0191 LATIN CAPITAL LETTER F WITH HOOK
0192 LATIN SMALL LETTER F WITH HOOK
0193 LATIN CAPITAL LETTER G WITH HOOK
0194 LATIN CAPITAL LETTER GAMMA
0195 LATIN SMALL LETTER HV
0196 LATIN CAPITAL LETTER IOTA
0197 LATIN CAPITAL LETTER I WITH STROKE
0198 LATIN CAPITAL LETTER K WITH HOOK
0199 LATIN SMALL LETTER K WITH HOOK
019A LATIN SMALL LETTER L WITH BAR
019B LATIN SMALL LETTER LAMBDA WITH STROKE
019C LATIN CAPITAL LETTER TURNED M
019D LATIN CAPITAL LETTER N WITH LEFT HOOK
019E LATIN SMALL LETTER N WITH LONG RIGHT LEG
019F LATIN CAPITAL LETTER O WITH MIDDLE TILDE
01A0 LATIN CAPITAL LETTER O WITH HORN
01A1 LATIN SMALL LETTER O WITH HORN
01A2 LATIN CAPITAL LETTER OI
01A3 LATIN SMALL LETTER OI
01A4 LATIN CAPITAL LETTER P WITH HOOK
01A5 LATIN SMALL LETTER P WITH HOOK
01A6 LATIN LETTER YR
01A7 LATIN CAPITAL LETTER TONE TWO
01A8 LATIN SMALL LETTER TONE TWO
01A9 LATIN CAPITAL LETTER ESH
01AA LATIN LETTER REVERSED ESH LOOP
01AB LATIN SMALL LETTER T WITH PALATAL HOOK
01AC LATIN CAPITAL LETTER T WITH HOOK
01AD LATIN SMALL LETTER T WITH HOOK
01AE LATIN CAPITAL LETTER T WITH RETROFLEX HOOK
01AF LATIN CAPITAL LETTER U WITH HORN
01B0 LATIN SMALL LETTER U WITH HORN
01B1 LATIN CAPITAL LETTER UPSILON
01B2 LATIN CAPITAL LETTER V WITH HOOK
01B3 LATIN CAPITAL LETTER Y WITH HOOK
01B4 LATIN SMALL LETTER Y WITH HOOK
01B5 LATIN CAPITAL LETTER Z WITH STROKE
01B6 LATIN SMALL LETTER Z WITH STROKE
01B7 LATIN CAPITAL LETTER EZH
01B8 LATIN CAPITAL LETTER EZH REVERSED
01B9 LATIN SMALL LETTER EZH REVERSED
01BA LATIN SMALL LETTER EZH WITH TAIL
01BB LATIN LETTER TWO WITH STROKE
01BC LATIN CAPITAL LETTER TONE FIVE
01BD LATIN SMALL LETTER TONE FIVE
01BE LATIN LETTER INVERTED GLOTTAL STOP WITH STROKE
01BF LATIN LETTER WYNN
01C0 LATIN LETTER DENTAL CLICK
01C1 LATIN LETTER LATERAL CLICK
01C2 LATIN LETTER ALVEOLAR CLICK
01C3 LATIN LETTER RETROFLEX CLICK
01C4 LATIN CAPITAL LETTER DZ WITH CARON
01C5 LATIN CAPITAL LETTER D WITH SMALL LETTER Z WITH CARON
01C6 LATIN SMALL LETTER DZ WITH CARON
01C7 LATIN CAPITAL LETTER LJ
01C8 LATIN CAPITAL LETTER L WITH SMALL LETTER J
01C9 LATIN SMALL LETTER LJ
01CA LATIN CAPITAL LETTER NJ
01CB LATIN CAPITAL LETTER N WITH SMALL LETTER J
01CC LATIN SMALL LETTER NJ
01CD LATIN CAPITAL LETTER A WITH CARON
01CE LATIN SMALL LETTER A WITH CARON
01CF LATIN CAPITAL LETTER I WITH CARON
01D0 LATIN SMALL LETTER I WITH CARON
01D1 LATIN CAPITAL LETTER O WITH CARON
01D2 LATIN SMALL LETTER O WITH CARON
01D3 LATIN CAPITAL LETTER U WITH CARON
01D4 LATIN SMALL LETTER U WITH CARON
01D5 LATIN CAPITAL LETTER U WITH DIAERESIS AND MACRON
01D6 LATIN SMALL LETTER U WITH DIAERESIS AND MACRON
01D7 LATIN CAPITAL LETTER U WITH DIAERESIS AND ACUTE
01D8 LATIN SMALL LETTER U WITH DIAERESIS AND ACUTE
01D9 LATIN CAPITAL LETTER U WITH DIAERESIS AND CARON
01DA LATIN SMALL LETTER U WITH DIAERESIS AND CARON
01DB LATIN CAPITAL LETTER U WITH DIAERESIS AND GRAVE
01DC LATIN SMALL LETTER U WITH DIAERESIS AND GRAVE
01DD LATIN SMALL LETTER TURNED E
01DE LATIN CAPITAL LETTER A WITH DIAERESIS AND MACRON
01DF LATIN SMALL LETTER A WITH DIAERESIS AND MACRON
01E0 LATIN CAPITAL LETTER A WITH DOT ABOVE AND MACRON
01E1 LATIN SMALL LETTER A WITH DOT ABOVE AND MACRON
01E2 LATIN CAPITAL LETTER AE WITH MACRON
01E3 LATIN SMALL LETTER AE WITH MACRON
01E4 LATIN CAPITAL LETTER G WITH STROKE
01E5 LATIN SMALL LETTER G WITH STROKE
01E6 LATIN CAPITAL LETTER G WITH CARON
01E7 LATIN SMALL LETTER G WITH CARON
01E8 LATIN CAPITAL LETTER K WITH CARON
01E9 LATIN SMALL LETTER K WITH CARON
01EA LATIN CAPITAL LETTER O WITH OGONEK
01EB LATIN SMALL LETTER O WITH OGONEK
01EC LATIN CAPITAL LETTER O WITH OGONEK AND MACRON
01ED LATIN SMALL LETTER O WITH OGONEK AND MACRON
01EE LATIN CAPITAL LETTER EZH WITH CARON
01EF LATIN SMALL LETTER EZH WITH CARON
01F0 LATIN SMALL LETTER J WITH CARON
01F1 LATIN CAPITAL LETTER DZ
01F2 LATIN CAPITAL LETTER D WITH SMALL LETTER Z
01F3 LATIN SMALL LETTER DZ
01F4 LATIN CAPITAL LETTER G WITH ACUTE
01F5 LATIN SMALL LETTER G WITH ACUTE
01F6 LATIN CAPITAL LETTER HWAIR
01F7 LATIN CAPITAL LETTER WYNN
01F8 LATIN CAPITAL LETTER N WITH GRAVE
01F9 LATIN SMALL LETTER N WITH GRAVE
01FA LATIN CAPITAL LETTER A WITH RING ABOVE AND ACUTE
01FB LATIN SMALL LETTER A WITH RING ABOVE AND ACUTE
01FC LATIN CAPITAL LETTER AE WITH ACUTE
01FD LATIN SMALL LETTER AE WITH ACUTE
01FE LATIN CAPITAL LETTER O WITH STROKE AND ACUTE
01FF LATIN SMALL LETTER O WITH STROKE AND ACUTE
0200 LATIN CAPITAL LETTER A WITH DOUBLE GRAVE
0201 LATIN SMALL LETTER A WITH DOUBLE GRAVE
0202 LATIN CAPITAL LETTER A WITH INVERTED BREVE
0203 LATIN SMALL LETTER A WITH INVERTED BREVE
0204 LATIN CAPITAL LETTER E WITH DOUBLE GRAVE
0205 LATIN SMALL LETTER E WITH DOUBLE GRAVE
0206 LATIN CAPITAL LETTER E WITH INVERTED BREVE
0207 LATIN SMALL LETTER E WITH INVERTED BREVE
0208 LATIN CAPITAL LETTER I WITH DOUBLE GRAVE
0209 LATIN SMALL LETTER I WITH DOUBLE GRAVE
020A LATIN CAPITAL LETTER I WITH INVERTED BREVE
020B LATIN SMALL LETTER I WITH INVERTED BREVE
020C LATIN CAPITAL LETTER O WITH DOUBLE GRAVE
020D LATIN SMALL LETTER O WITH DOUBLE GRAVE
020E LATIN CAPITAL LETTER O WITH INVERTED BREVE
020F LATIN SMALL LETTER O WITH INVERTED BREVE
0210 LATIN CAPITAL LETTER R WITH DOUBLE GRAVE
0211 LATIN SMALL LETTER R WITH DOUBLE GRAVE
0212 LATIN CAPITAL LETTER R WITH INVERTED BREVE
0213 LATIN SMALL LETTER R WITH INVERTED BREVE
0214 LATIN CAPITAL LETTER U WITH DOUBLE GRAVE
0215 LATIN SMALL LETTER U WITH DOUBLE GRAVE
0216 LATIN CAPITAL LETTER U WITH INVERTED BREVE
0217 LATIN SMALL LETTER U WITH INVERTED BREVE
0218 LATIN CAPITAL LETTER S WITH COMMA BELOW
0219 LATIN SMALL LETTER S WITH COMMA BELOW
021A LATIN CAPITAL LETTER T WITH COMMA BELOW
021B LATIN SMALL LETTER T WITH COMMA BELOW
021C LATIN CAPITAL LETTER YOGH
021D LATIN SMALL LETTER YOGH
021E LATIN CAPITAL LETTER H WITH CARON
021F LATIN SMALL LETTER H WITH CARON
0220 LATIN CAPITAL LETTER N WITH LONG RIGHT LEG
0221 LATIN SMALL LETTER D WITH CURL
0222 LATIN CAPITAL LETTER OU
0223 LATIN SMALL LETTER OU
0224 LATIN CAPITAL LETTER Z WITH HOOK
0225 LATIN SMALL LETTER Z WITH HOOK
0226 LATIN CAPITAL LETTER A WITH DOT ABOVE
0227 LATIN SMALL LETTER A WITH DOT ABOVE
0228 LATIN CAPITAL LETTER E WITH CEDILLA
0229 LATIN SMALL LETTER E WITH CEDILLA
022A LATIN CAPITAL LETTER O WITH DIAERESIS AND MACRON
022B LATIN SMALL LETTER O WITH DIAERESIS AND MACRON
022C LATIN CAPITAL LETTER O WITH TILDE AND MACRON
022D LATIN SMALL LETTER O WITH TILDE AND MACRON
022E LATIN CAPITAL LETTER O WITH DOT ABOVE
022F LATIN SMALL LETTER O WITH DOT ABOVE
0230 LATIN CAPITAL LETTER O WITH DOT ABOVE AND MACRON
0231 LATIN SMALL LETTER O WITH DOT ABOVE AND MACRON
0232 LATIN CAPITAL LETTER Y WITH MACRON
0233 LATIN SMALL LETTER Y WITH MACRON
0234 LATIN SMALL LETTER L WITH CURL
0235 LATIN SMALL LETTER N WITH CURL
0236 LATIN SMALL LETTER T WITH CURL
0237 LATIN SMALL LETTER DOTLESS J
0238 LATIN SMALL LETTER DB DIGRAPH
0239 LATIN SMALL LETTER QP DIGRAPH
023A LATIN CAPITAL LETTER A WITH STROKE
023B LATIN CAPITAL LETTER C WITH STROKE
023C LATIN SMALL LETTER C WITH STROKE
023D LATIN CAPITAL LETTER L WITH BAR
023E LATIN CAPITAL LETTER T WITH DIAGONAL STROKE
023F LATIN SMALL LETTER S WITH SWASH TAIL
0240 LATIN SMALL LETTER Z WITH SWASH TAIL
0241 LATIN CAPITAL LETTER GLOTTAL STOP
0250 LATIN SMALL LETTER TURNED A
0251 LATIN SMALL LETTER ALPHA
0252 LATIN SMALL LETTER TURNED ALPHA
0253 LATIN SMALL LETTER B WITH HOOK
0254 LATIN SMALL LETTER OPEN O
0255 LATIN SMALL LETTER C WITH CURL
0256 LATIN SMALL LETTER D WITH TAIL
0257 LATIN SMALL LETTER D WITH HOOK
0258 LATIN SMALL LETTER REVERSED E
0259 LATIN SMALL LETTER SCHWA
025A LATIN SMALL LETTER SCHWA WITH HOOK
025B LATIN SMALL LETTER OPEN E
025C LATIN SMALL LETTER REVERSED OPEN E
025D LATIN SMALL LETTER REVERSED OPEN E WITH HOOK
025E LATIN SMALL LETTER CLOSED REVERSED OPEN E
025F LATIN SMALL LETTER DOTLESS J WITH STROKE
0260 LATIN SMALL LETTER G WITH HOOK
0261 LATIN SMALL LETTER SCRIPT G
0262 LATIN LETTER SMALL CAPITAL G
0263 LATIN SMALL LETTER GAMMA
0264 LATIN SMALL LETTER RAMS HORN
0265 LATIN SMALL LETTER TURNED H
0266 LATIN SMALL LETTER H WITH HOOK
0267 LATIN SMALL LETTER HENG WITH HOOK
0268 LATIN SMALL LETTER I WITH STROKE
0269 LATIN SMALL LETTER IOTA
026A LATIN LETTER SMALL CAPITAL I
026B LATIN SMALL LETTER L WITH MIDDLE TILDE
026C LATIN SMALL LETTER L WITH BELT
026D LATIN SMALL LETTER L WITH RETROFLEX HOOK
026E LATIN SMALL LETTER LEZH
026F LATIN SMALL LETTER TURNED M
0270 LATIN SMALL LETTER TURNED M WITH LONG LEG
0271 LATIN SMALL LETTER M WITH HOOK
0272 LATIN SMALL LETTER N WITH LEFT HOOK
0273 LATIN SMALL LETTER N WITH RETROFLEX HOOK
0274 LATIN LETTER SMALL CAPITAL N
0275 LATIN SMALL LETTER BARRED O
0276 LATIN LETTER SMALL CAPITAL OE
0277 LATIN SMALL LETTER CLOSED OMEGA
0278 LATIN SMALL LETTER PHI
0279 LATIN SMALL LETTER TURNED R
027A LATIN SMALL LETTER TURNED R WITH LONG LEG
027B LATIN SMALL LETTER TURNED R WITH HOOK
027C LATIN SMALL LETTER R WITH LONG LEG
027D LATIN SMALL LETTER R WITH TAIL
027E LATIN SMALL LETTER R WITH FISHHOOK
027F LATIN SMALL LETTER REVERSED R WITH FISHHOOK
0280 LATIN LETTER SMALL CAPITAL R
0281 LATIN LETTER SMALL CAPITAL INVERTED R
0282 LATIN SMALL LETTER S WITH HOOK
0283 LATIN SMALL LETTER ESH
0284 LATIN SMALL LETTER DOTLESS J WITH STROKE AND HOOK
0285 LATIN SMALL LETTER SQUAT REVERSED ESH
0286 LATIN SMALL LETTER ESH WITH CURL
0287 LATIN SMALL LETTER TURNED T
0288 LATIN SMALL LETTER T WITH RETROFLEX HOOK
0289 LATIN SMALL LETTER U BAR
028A LATIN SMALL LETTER UPSILON
028B LATIN SMALL LETTER V WITH HOOK
028C LATIN SMALL LETTER TURNED V
028D LATIN SMALL LETTER TURNED W
028E LATIN SMALL LETTER TURNED Y
028F LATIN LETTER SMALL CAPITAL Y
0290 LATIN SMALL LETTER Z WITH RETROFLEX HOOK
0291 LATIN SMALL LETTER Z WITH CURL
0292 LATIN SMALL LETTER EZH
0293 LATIN SMALL LETTER EZH WITH CURL
0294 LATIN LETTER GLOTTAL STOP
0295 LATIN LETTER PHARYNGEAL VOICED FRICATIVE
0296 LATIN LETTER INVERTED GLOTTAL STOP
0297 LATIN LETTER STRETCHED C
0298 LATIN LETTER BILABIAL CLICK
0299 LATIN LETTER SMALL CAPITAL B
029A LATIN SMALL LETTER CLOSED OPEN E
029B LATIN LETTER SMALL CAPITAL G WITH HOOK
029C LATIN LETTER SMALL CAPITAL H
029D LATIN SMALL LETTER J WITH CROSSED-TAIL
029E LATIN SMALL LETTER TURNED K
029F LATIN LETTER SMALL CAPITAL L
02A0 LATIN SMALL LETTER Q WITH HOOK
02A1 LATIN LETTER GLOTTAL STOP WITH STROKE
02A2 LATIN LETTER REVERSED GLOTTAL STOP WITH STROKE
02A3 LATIN SMALL LETTER DZ DIGRAPH
02A4 LATIN SMALL LETTER DEZH DIGRAPH
02A5 LATIN SMALL LETTER DZ DIGRAPH WITH CURL
02A6 LATIN SMALL LETTER TS DIGRAPH
02A7 LATIN SMALL LETTER TESH DIGRAPH
02A8 LATIN SMALL LETTER TC DIGRAPH WITH CURL
02A9 LATIN SMALL LETTER FENG DIGRAPH
02AA LATIN SMALL LETTER LS DIGRAPH
02AB LATIN SMALL LETTER LZ DIGRAPH
02AC LATIN LETTER BILABIAL PERCUSSIVE
02AD LATIN LETTER BIDENTAL PERCUSSIVE
02AE LATIN SMALL LETTER TURNED H WITH FISHHOOK
02AF LATIN SMALL LETTER TURNED H WITH FISHHOOK AND TAIL
02B0 MODIFIER LETTER SMALL H
02B1 MODIFIER LETTER SMALL H WITH HOOK
02B2 MODIFIER LETTER SMALL J
02B3 MODIFIER LETTER SMALL R
02B4 MODIFIER LETTER SMALL TURNED R
02B5 MODIFIER LETTER SMALL TURNED R WITH HOOK
02B6 MODIFIER LETTER SMALL CAPITAL INVERTED R
02B7 MODIFIER LETTER SMALL W
02B8 MODIFIER LETTER SMALL Y
02B9 MODIFIER LETTER PRIME
02BA MODIFIER LETTER DOUBLE PRIME
02BB MODIFIER LETTER TURNED COMMA
02BC MODIFIER LETTER APOSTROPHE
02BD MODIFIER LETTER REVERSED COMMA
02BE MODIFIER LETTER RIGHT HALF RING
02BF MODIFIER LETTER LEFT HALF RING
02C0 MODIFIER LETTER GLOTTAL STOP
02C1 MODIFIER LETTER REVERSED GLOTTAL STOP
02C2 MODIFIER LETTER LEFT ARROWHEAD
02C3 MODIFIER LETTER RIGHT ARROWHEAD
02C4 MODIFIER LETTER UP ARROWHEAD
02C5 MODIFIER LETTER DOWN ARROWHEAD
02C6 MODIFIER LETTER CIRCUMFLEX ACCENT
02C7 CARON
02C8 MODIFIER LETTER VERTICAL LINE
02C9 MODIFIER LETTER MACRON
02CA MODIFIER LETTER ACUTE ACCENT
02CB MODIFIER LETTER GRAVE ACCENT
02CC MODIFIER LETTER LOW VERTICAL LINE
02CD MODIFIER LETTER LOW MACRON
02CE MODIFIER LETTER LOW GRAVE ACCENT
02CF MODIFIER LETTER LOW ACUTE ACCENT
02D0 MODIFIER LETTER TRIANGULAR COLON
02D1 MODIFIER LETTER HALF TRIANGULAR COLON
02D2 MODIFIER LETTER CENTRED RIGHT HALF RING
02D3 MODIFIER LETTER CENTRED LEFT HALF RING
02D4 MODIFIER LETTER UP TACK
02D5 MODIFIER LETTER DOWN TACK
02D6 MODIFIER LETTER PLUS SIGN
02D7 MODIFIER LETTER MINUS SIGN
02D8 BREVE
02D9 DOT ABOVE
02DA RING ABOVE
02DB OGONEK
02DC SMALL TILDE
02DD DOUBLE ACUTE ACCENT
02DE MODIFIER LETTER RHOTIC HOOK
02DF MODIFIER LETTER CROSS ACCENT
02E0 MODIFIER LETTER SMALL GAMMA
02E1 MODIFIER LETTER SMALL L
02E2 MODIFIER LETTER SMALL S
02E3 MODIFIER LETTER SMALL X
02E4 MODIFIER LETTER SMALL REVERSED GLOTTAL STOP
02E5 MODIFIER LETTER EXTRA-HIGH TONE BAR
02E6 MODIFIER LETTER HIGH TONE BAR
02E7 MODIFIER LETTER MID TONE BAR
02E8 MODIFIER LETTER LOW TONE BAR
02E9 MODIFIER LETTER EXTRA-LOW TONE BAR
02EA MODIFIER LETTER YIN DEPARTING TONE MARK
02EB MODIFIER LETTER YANG DEPARTING TONE MARK
02EC MODIFIER LETTER VOICING
02ED MODIFIER LETTER UNASPIRATED
02EE MODIFIER LETTER DOUBLE APOSTROPHE
02EF MODIFIER LETTER LOW DOWN ARROWHEAD
02F0 MODIFIER LETTER LOW UP ARROWHEAD
02F1 MODIFIER LETTER LOW LEFT ARROWHEAD
02F2 MODIFIER LETTER LOW RIGHT ARROWHEAD
02F3 MODIFIER LETTER LOW RING
02F4 MODIFIER LETTER MIDDLE GRAVE ACCENT
02F5 MODIFIER LETTER MIDDLE DOUBLE GRAVE ACCENT
02F6 MODIFIER LETTER MIDDLE DOUBLE ACUTE ACCENT
02F7 MODIFIER LETTER LOW TILDE
02F8 MODIFIER LETTER RAISED COLON
02F9 MODIFIER LETTER BEGIN HIGH TONE
02FA MODIFIER LETTER END HIGH TONE
02FB MODIFIER LETTER BEGIN LOW TONE
02FC MODIFIER LETTER END LOW TONE
02FD MODIFIER LETTER SHELF
02FE MODIFIER LETTER OPEN SHELF
02FF MODIFIER LETTER LOW LEFT ARROW
0300 COMBINING GRAVE ACCENT
0301 COMBINING ACUTE ACCENT
0302 COMBINING CIRCUMFLEX ACCENT
0303 COMBINING TILDE
0304 COMBINING MACRON
0305 COMBINING OVERLINE
0306 COMBINING BREVE
0307 COMBINING DOT ABOVE
0308 COMBINING DIAERESIS
0309 COMBINING HOOK ABOVE
030A COMBINING RING ABOVE
030B COMBINING DOUBLE ACUTE ACCENT
030C COMBINING CARON
030D COMBINING VERTICAL LINE ABOVE
030E COMBINING DOUBLE VERTICAL LINE ABOVE
030F COMBINING DOUBLE GRAVE ACCENT
0310 COMBINING CANDRABINDU
0311 COMBINING INVERTED BREVE
0312 COMBINING TURNED COMMA ABOVE
0313 COMBINING COMMA ABOVE
0314 COMBINING REVERSED COMMA ABOVE
0315 COMBINING COMMA ABOVE RIGHT
0316 COMBINING GRAVE ACCENT BELOW
0317 COMBINING ACUTE ACCENT BELOW
0318 COMBINING LEFT TACK BELOW
0319 COMBINING RIGHT TACK BELOW
031A COMBINING LEFT ANGLE ABOVE
031B COMBINING HORN
031C COMBINING LEFT HALF RING BELOW
031D COMBINING UP TACK BELOW
031E COMBINING DOWN TACK BELOW
031F COMBINING PLUS SIGN BELOW
0320 COMBINING MINUS SIGN BELOW
0321 COMBINING PALATALIZED HOOK BELOW
0322 COMBINING RETROFLEX HOOK BELOW
0323 COMBINING DOT BELOW
0324 COMBINING DIAERESIS BELOW
0325 COMBINING RING BELOW
0326 COMBINING COMMA BELOW
0327 COMBINING CEDILLA
0328 COMBINING OGONEK
0329 COMBINING VERTICAL LINE BELOW
032A COMBINING BRIDGE BELOW
032B COMBINING INVERTED DOUBLE ARCH BELOW
032C COMBINING CARON BELOW
032D COMBINING CIRCUMFLEX ACCENT BELOW
032E COMBINING BREVE BELOW
032F COMBINING INVERTED BREVE BELOW
0330 COMBINING TILDE BELOW
0331 COMBINING MACRON BELOW
0332 COMBINING LOW LINE
0333 COMBINING DOUBLE LOW LINE
0334 COMBINING TILDE OVERLAY
0335 COMBINING SHORT STROKE OVERLAY
0336 COMBINING LONG STROKE OVERLAY
0337 COMBINING SHORT SOLIDUS OVERLAY
0338 COMBINING LONG SOLIDUS OVERLAY
0339 COMBINING RIGHT HALF RING BELOW
033A COMBINING INVERTED BRIDGE BELOW
033B COMBINING SQUARE BELOW
033C COMBINING SEAGULL BELOW
033D COMBINING X ABOVE
033E COMBINING VERTICAL TILDE
033F COMBINING DOUBLE OVERLINE
0340 COMBINING GRAVE TONE MARK
0341 COMBINING ACUTE TONE MARK
0342 COMBINING GREEK PERISPOMENI
0343 COMBINING GREEK KORONIS
0344 COMBINING GREEK DIALYTIKA TONOS
0345 COMBINING GREEK YPOGEGRAMMENI
0346 COMBINING BRIDGE ABOVE
0347 COMBINING EQUALS SIGN BELOW
0348 COMBINING DOUBLE VERTICAL LINE BELOW
0349 COMBINING LEFT ANGLE BELOW
034A COMBINING NOT TILDE ABOVE
034B COMBINING HOMOTHETIC ABOVE
034C COMBINING ALMOST EQUAL TO ABOVE
034D COMBINING LEFT RIGHT ARROW BELOW
034E COMBINING UPWARDS ARROW BELOW
034F COMBINING GRAPHEME JOINER
0350 COMBINING RIGHT ARROWHEAD ABOVE
0351 COMBINING LEFT HALF RING ABOVE
0352 COMBINING FERMATA
0353 COMBINING X BELOW
0354 COMBINING LEFT ARROWHEAD BELOW
0355 COMBINING RIGHT ARROWHEAD BELOW
0356 COMBINING RIGHT ARROWHEAD AND UP ARROWHEAD BELOW
0357 COMBINING RIGHT HALF RING ABOVE
0358 COMBINING DOT ABOVE RIGHT
0359 COMBINING ASTERISK BELOW
035A COMBINING DOUBLE RING BELOW
035B COMBINING ZIGZAG ABOVE
035C COMBINING DOUBLE BREVE BELOW
035D COMBINING DOUBLE BREVE
035E COMBINING DOUBLE MACRON
035F COMBINING DOUBLE MACRON BELOW
0360 COMBINING DOUBLE TILDE
0361 COMBINING DOUBLE INVERTED BREVE
0362 COMBINING DOUBLE RIGHTWARDS ARROW BELOW
0363 COMBINING LATIN SMALL LETTER A
0364 COMBINING LATIN SMALL LETTER E
0365 COMBINING LATIN SMALL LETTER I
0366 COMBINING LATIN SMALL LETTER O
0367 COMBINING LATIN SMALL LETTER U
0368 COMBINING LATIN SMALL LETTER C
0369 COMBINING LATIN SMALL LETTER D
036A COMBINING LATIN SMALL LETTER H
036B COMBINING LATIN SMALL LETTER M
036C COMBINING LATIN SMALL LETTER R
036D COMBINING LATIN SMALL LETTER T
036E COMBINING LATIN SMALL LETTER V
036F COMBINING LATIN SMALL LETTER X
0374 GREEK NUMERAL SIGN
0375 GREEK LOWER NUMERAL SIGN
037A GREEK YPOGEGRAMMENI
037E GREEK QUESTION MARK
0384 GREEK TONOS
0385 GREEK DIALYTIKA TONOS
0386 GREEK CAPITAL LETTER ALPHA WITH TONOS
0387 GREEK ANO TELEIA
0388 GREEK CAPITAL LETTER EPSILON WITH TONOS
0389 GREEK CAPITAL LETTER ETA WITH TONOS
038A GREEK CAPITAL LETTER IOTA WITH TONOS
038C GREEK CAPITAL LETTER OMICRON WITH TONOS
038E GREEK CAPITAL LETTER UPSILON WITH TONOS
038F GREEK CAPITAL LETTER OMEGA WITH TONOS
0390 GREEK SMALL LETTER IOTA WITH DIALYTIKA AND TONOS
0391 GREEK CAPITAL LETTER ALPHA
0392 GREEK CAPITAL LETTER BETA
0393 GREEK CAPITAL LETTER GAMMA
0394 GREEK CAPITAL LETTER DELTA
0395 GREEK CAPITAL LETTER EPSILON
0396 GREEK CAPITAL LETTER ZETA
0397 GREEK CAPITAL LETTER ETA
0398 GREEK CAPITAL LETTER THETA
0399 GREEK CAPITAL LETTER IOTA
039A GREEK CAPITAL LETTER KAPPA
039B GREEK CAPITAL LETTER LAMDA
039C GREEK CAPITAL LETTER MU
039D GREEK CAPITAL LETTER NU
039E GREEK CAPITAL LETTER XI
039F GREEK CAPITAL LETTER OMICRON
03A0 GREEK CAPITAL LETTER PI
03A1 GREEK CAPITAL LETTER RHO
03A3 GREEK CAPITAL LETTER SIGMA
03A4 GREEK CAPITAL LETTER TAU
03A5 GREEK CAPITAL LETTER UPSILON
03A6 GREEK CAPITAL LETTER PHI
03A7 GREEK CAPITAL LETTER CHI
03A8 GREEK CAPITAL LETTER PSI
03A9 GREEK CAPITAL LETTER OMEGA
03AA GREEK CAPITAL LETTER IOTA WITH DIALYTIKA
03AB GREEK CAPITAL LETTER UPSILON WITH DIALYTIKA
03AC GREEK SMALL LETTER ALPHA WITH TONOS
03AD GREEK SMALL LETTER EPSILON WITH TONOS
03AE GREEK SMALL LETTER ETA WITH TONOS
03AF GREEK SMALL LETTER IOTA WITH TONOS
03B0 GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND TONOS
03B1 GREEK SMALL LETTER ALPHA
03B2 GREEK SMALL LETTER BETA
03B3 GREEK SMALL LETTER GAMMA
03B4 GREEK SMALL LETTER DELTA
03B5 GREEK SMALL LETTER EPSILON
03B6 GREEK SMALL LETTER ZETA
03B7 GREEK SMALL LETTER ETA
03B8 GREEK SMALL LETTER THETA
03B9 GREEK SMALL LETTER IOTA
03BA GREEK SMALL LETTER KAPPA
03BB GREEK SMALL LETTER LAMDA
03BC GREEK SMALL LETTER MU
03BD GREEK SMALL LETTER NU
03BE GREEK SMALL LETTER XI
03BF GREEK SMALL LETTER OMICRON
03C0 GREEK SMALL LETTER PI
03C1 GREEK SMALL LETTER RHO
03C2 GREEK SMALL LETTER FINAL SIGMA
03C3 GREEK SMALL LETTER SIGMA
03C4 GREEK SMALL LETTER TAU
03C5 GREEK SMALL LETTER UPSILON
03C6 GREEK SMALL LETTER PHI
03C7 GREEK SMALL LETTER CHI
03C8 GREEK SMALL LETTER PSI
03C9 GREEK SMALL LETTER OMEGA
03CA GREEK SMALL LETTER IOTA WITH DIALYTIKA
03CB GREEK SMALL LETTER UPSILON WITH DIALYTIKA
03CC GREEK SMALL LETTER OMICRON WITH TONOS
03CD GREEK SMALL LETTER UPSILON WITH TONOS
03CE GREEK SMALL LETTER OMEGA WITH TONOS
03D0 GREEK BETA SYMBOL
03D1 GREEK THETA SYMBOL
03D2 GREEK UPSILON WITH HOOK SYMBOL
03D3 GREEK UPSILON WITH ACUTE AND HOOK SYMBOL
03D4 GREEK UPSILON WITH DIAERESIS AND HOOK SYMBOL
03D5 GREEK PHI SYMBOL
03D6 GREEK PI SYMBOL
03D7 GREEK KAI SYMBOL
03D8 GREEK LETTER ARCHAIC KOPPA
03D9 GREEK SMALL LETTER ARCHAIC KOPPA
03DA GREEK LETTER STIGMA
03DB GREEK SMALL LETTER STIGMA
03DC GREEK LETTER DIGAMMA
03DD GREEK SMALL LETTER DIGAMMA
03DE GREEK LETTER KOPPA
03DF GREEK SMALL LETTER KOPPA
03E0 GREEK LETTER SAMPI
03E1 GREEK SMALL LETTER SAMPI
03E2 COPTIC CAPITAL LETTER SHEI
03E3 COPTIC SMALL LETTER SHEI
03E4 COPTIC CAPITAL LETTER FEI
03E5 COPTIC SMALL LETTER FEI
03E6 COPTIC CAPITAL LETTER KHEI
03E7 COPTIC SMALL LETTER KHEI
03E8 COPTIC CAPITAL LETTER HORI
03E9 COPTIC SMALL LETTER HORI
03EA COPTIC CAPITAL LETTER GANGIA
03EB COPTIC SMALL LETTER GANGIA
03EC COPTIC CAPITAL LETTER SHIMA
03ED COPTIC SMALL LETTER SHIMA
03EE COPTIC CAPITAL LETTER DEI
03EF COPTIC SMALL LETTER DEI
03F0 GREEK KAPPA SYMBOL
03F1 GREEK RHO SYMBOL
03F2 GREEK LUNATE SIGMA SYMBOL
03F3 GREEK LETTER YOT
03F4 GREEK CAPITAL THETA SYMBOL
03F5 GREEK LUNATE EPSILON SYMBOL
03F6 GREEK REVERSED LUNATE EPSILON SYMBOL
03F7 GREEK CAPITAL LETTER SHO
03F8 GREEK SMALL LETTER SHO
03F9 GREEK CAPITAL LUNATE SIGMA SYMBOL
03FA GREEK CAPITAL LETTER SAN
03FB GREEK SMALL LETTER SAN
03FC GREEK RHO WITH STROKE SYMBOL
03FD GREEK CAPITAL REVERSED LUNATE SIGMA SYMBOL
03FE GREEK CAPITAL DOTTED LUNATE SIGMA SYMBOL
03FF GREEK CAPITAL REVERSED DOTTED LUNATE SIGMA SYMBOL
0400 CYRILLIC CAPITAL LETTER IE WITH GRAVE
0401 CYRILLIC CAPITAL LETTER IO
0402 CYRILLIC CAPITAL LETTER DJE
0403 CYRILLIC CAPITAL LETTER GJE
0404 CYRILLIC CAPITAL LETTER UKRAINIAN IE
0405 CYRILLIC CAPITAL LETTER DZE
0406 CYRILLIC CAPITAL LETTER BYELORUSSIAN-UKRAINIAN I
0407 CYRILLIC CAPITAL LETTER YI
0408 CYRILLIC CAPITAL LETTER JE
0409 CYRILLIC CAPITAL LETTER LJE
040A CYRILLIC CAPITAL LETTER NJE
040B CYRILLIC CAPITAL LETTER TSHE
040C CYRILLIC CAPITAL LETTER KJE
040D CYRILLIC CAPITAL LETTER I WITH GRAVE
040E CYRILLIC CAPITAL LETTER SHORT U
040F CYRILLIC CAPITAL LETTER DZHE
0410 CYRILLIC CAPITAL LETTER A
0411 CYRILLIC CAPITAL LETTER BE
0412 CYRILLIC CAPITAL LETTER VE
0413 CYRILLIC CAPITAL LETTER GHE
0414 CYRILLIC CAPITAL LETTER DE
0415 CYRILLIC CAPITAL LETTER IE
0416 CYRILLIC CAPITAL LETTER ZHE
0417 CYRILLIC CAPITAL LETTER ZE
0418 CYRILLIC CAPITAL LETTER I
0419 CYRILLIC CAPITAL LETTER SHORT I
041A CYRILLIC CAPITAL LETTER KA
041B CYRILLIC CAPITAL LETTER EL
041C CYRILLIC CAPITAL LETTER EM
041D CYRILLIC CAPITAL LETTER EN
041E CYRILLIC CAPITAL LETTER O
041F CYRILLIC CAPITAL LETTER PE
0420 CYRILLIC CAPITAL LETTER ER
0421 CYRILLIC CAPITAL LETTER ES
0422 CYRILLIC CAPITAL LETTER TE
0423 CYRILLIC CAPITAL LETTER U
0424 CYRILLIC CAPITAL LETTER EF
0425 CYRILLIC CAPITAL LETTER HA
0426 CYRILLIC CAPITAL LETTER TSE
0427 CYRILLIC CAPITAL LETTER CHE
0428 CYRILLIC CAPITAL LETTER SHA
0429 CYRILLIC CAPITAL LETTER SHCHA
042A CYRILLIC CAPITAL LETTER HARD SIGN
042B CYRILLIC CAPITAL LETTER YERU
042C CYRILLIC CAPITAL LETTER SOFT SIGN
042D CYRILLIC CAPITAL LETTER E
042E CYRILLIC CAPITAL LETTER YU
042F CYRILLIC CAPITAL LETTER YA
0430 CYRILLIC SMALL LETTER A
0431 CYRILLIC SMALL LETTER BE
0432 CYRILLIC SMALL LETTER VE
0433 CYRILLIC SMALL LETTER GHE
0434 CYRILLIC SMALL LETTER DE
0435 CYRILLIC SMALL LETTER IE
0436 CYRILLIC SMALL LETTER ZHE
0437 CYRILLIC SMALL LETTER ZE
0438 CYRILLIC SMALL LETTER I
0439 CYRILLIC SMALL LETTER SHORT I
043A CYRILLIC SMALL LETTER KA
043B CYRILLIC SMALL LETTER EL
043C CYRILLIC SMALL LETTER EM
043D CYRILLIC SMALL LETTER EN
043E CYRILLIC SMALL LETTER O
043F CYRILLIC SMALL LETTER PE
0440 CYRILLIC SMALL LETTER ER
0441 CYRILLIC SMALL LETTER ES
0442 CYRILLIC SMALL LETTER TE
0443 CYRILLIC SMALL LETTER U
0444 CYRILLIC SMALL LETTER EF
0445 CYRILLIC SMALL LETTER HA
0446 CYRILLIC SMALL LETTER TSE
0447 CYRILLIC SMALL LETTER CHE
0448 CYRILLIC SMALL LETTER SHA
0449 CYRILLIC SMALL LETTER SHCHA
044A CYRILLIC SMALL LETTER HARD SIGN
044B CYRILLIC SMALL LETTER YERU
044C CYRILLIC SMALL LETTER SOFT SIGN
044D CYRILLIC SMALL LETTER E
044E CYRILLIC SMALL LETTER YU
044F CYRILLIC SMALL LETTER YA
0450 CYRILLIC SMALL LETTER IE WITH GRAVE
0451 CYRILLIC SMALL LETTER IO
0452 CYRILLIC SMALL LETTER DJE
0453 CYRILLIC SMALL LETTER GJE
0454 CYRILLIC SMALL LETTER UKRAINIAN IE
0455 CYRILLIC SMALL LETTER DZE
0456 CYRILLIC SMALL LETTER BYELORUSSIAN-UKRAINIAN I
0457 CYRILLIC SMALL LETTER YI
0458 CYRILLIC SMALL LETTER JE
0459 CYRILLIC SMALL LETTER LJE
045A CYRILLIC SMALL LETTER NJE
045B CYRILLIC SMALL LETTER TSHE
045C CYRILLIC SMALL LETTER KJE
045D CYRILLIC SMALL LETTER I WITH GRAVE
045E CYRILLIC SMALL LETTER SHORT U
045F CYRILLIC SMALL LETTER DZHE
0460 CYRILLIC CAPITAL LETTER OMEGA
0461 CYRILLIC SMALL LETTER OMEGA
0462 CYRILLIC CAPITAL LETTER YAT
0463 CYRILLIC SMALL LETTER YAT
0464 CYRILLIC CAPITAL LETTER IOTIFIED E
0465 CYRILLIC SMALL LETTER IOTIFIED E
0466 CYRILLIC CAPITAL LETTER LITTLE YUS
0467 CYRILLIC SMALL LETTER LITTLE YUS
0468 CYRILLIC CAPITAL LETTER IOTIFIED LITTLE YUS
0469 CYRILLIC SMALL LETTER IOTIFIED LITTLE YUS
046A CYRILLIC CAPITAL LETTER BIG YUS
046B CYRILLIC SMALL LETTER BIG YUS
046C CYRILLIC CAPITAL LETTER IOTIFIED BIG YUS
046D CYRILLIC SMALL LETTER IOTIFIED BIG YUS
046E CYRILLIC CAPITAL LETTER KSI
046F CYRILLIC SMALL LETTER KSI
0470 CYRILLIC CAPITAL LETTER PSI
0471 CYRILLIC SMALL LETTER PSI
0472 CYRILLIC CAPITAL LETTER FITA
0473 CYRILLIC SMALL LETTER FITA
0474 CYRILLIC CAPITAL LETTER IZHITSA
0475 CYRILLIC SMALL LETTER IZHITSA
0476 CYRILLIC CAPITAL LETTER IZHITSA WITH DOUBLE GRAVE ACCENT
0477 CYRILLIC SMALL LETTER IZHITSA WITH DOUBLE GRAVE ACCENT
0478 CYRILLIC CAPITAL LETTER UK
0479 CYRILLIC SMALL LETTER UK
047A CYRILLIC CAPITAL LETTER ROUND OMEGA
047B CYRILLIC SMALL LETTER ROUND OMEGA
047C CYRILLIC CAPITAL LETTER OMEGA WITH TITLO
047D CYRILLIC SMALL LETTER OMEGA WITH TITLO
047E CYRILLIC CAPITAL LETTER OT
047F CYRILLIC SMALL LETTER OT
0480 CYRILLIC CAPITAL LETTER KOPPA
0481 CYRILLIC SMALL LETTER KOPPA
0482 CYRILLIC THOUSANDS SIGN
0483 COMBINING CYRILLIC TITLO
0484 COMBINING CYRILLIC PALATALIZATION
0485 COMBINING CYRILLIC DASIA PNEUMATA
0486 COMBINING CYRILLIC PSILI PNEUMATA
0488 COMBINING CYRILLIC HUNDRED THOUSANDS SIGN
0489 COMBINING CYRILLIC MILLIONS SIGN
048A CYRILLIC CAPITAL LETTER SHORT I WITH TAIL
048B CYRILLIC SMALL LETTER SHORT I WITH TAIL
048C CYRILLIC CAPITAL LETTER SEMISOFT SIGN
048D CYRILLIC SMALL LETTER SEMISOFT SIGN
048E CYRILLIC CAPITAL LETTER ER WITH TICK
048F CYRILLIC SMALL LETTER ER WITH TICK
0490 CYRILLIC CAPITAL LETTER GHE WITH UPTURN
0491 CYRILLIC SMALL LETTER GHE WITH UPTURN
0492 CYRILLIC CAPITAL LETTER GHE WITH STROKE
0493 CYRILLIC SMALL LETTER GHE WITH STROKE
0494 CYRILLIC CAPITAL LETTER GHE WITH MIDDLE HOOK
0495 CYRILLIC SMALL LETTER GHE WITH MIDDLE HOOK
0496 CYRILLIC CAPITAL LETTER ZHE WITH DESCENDER
0497 CYRILLIC SMALL LETTER ZHE WITH DESCENDER
0498 CYRILLIC CAPITAL LETTER ZE WITH DESCENDER
0499 CYRILLIC SMALL LETTER ZE WITH DESCENDER
049A CYRILLIC CAPITAL LETTER KA WITH DESCENDER
049B CYRILLIC SMALL LETTER KA WITH DESCENDER
049C CYRILLIC CAPITAL LETTER KA WITH VERTICAL STROKE
049D CYRILLIC SMALL LETTER KA WITH VERTICAL STROKE
049E CYRILLIC CAPITAL LETTER KA WITH STROKE
049F CYRILLIC SMALL LETTER KA WITH STROKE
04A0 CYRILLIC CAPITAL LETTER BASHKIR KA
04A1 CYRILLIC SMALL LETTER BASHKIR KA
04A2 CYRILLIC CAPITAL LETTER EN WITH DESCENDER
04A3 CYRILLIC SMALL LETTER EN WITH DESCENDER
04A4 CYRILLIC CAPITAL LIGATURE EN GHE
04A5 CYRILLIC SMALL LIGATURE EN GHE
04A6 CYRILLIC CAPITAL LETTER PE WITH MIDDLE HOOK
04A7 CYRILLIC SMALL LETTER PE WITH MIDDLE HOOK
04A8 CYRILLIC CAPITAL LETTER ABKHASIAN HA
04A9 CYRILLIC SMALL LETTER ABKHASIAN HA
04AA CYRILLIC CAPITAL LETTER ES WITH DESCENDER
04AB CYRILLIC SMALL LETTER ES WITH DESCENDER
04AC CYRILLIC CAPITAL LETTER TE WITH DESCENDER
04AD CYRILLIC SMALL LETTER TE WITH DESCENDER
04AE CYRILLIC CAPITAL LETTER STRAIGHT U
04AF CYRILLIC SMALL LETTER STRAIGHT U
04B0 CYRILLIC CAPITAL LETTER STRAIGHT U WITH STROKE
04B1 CYRILLIC SMALL LETTER STRAIGHT U WITH STROKE
04B2 CYRILLIC CAPITAL LETTER HA WITH DESCENDER
04B3 CYRILLIC SMALL LETTER HA WITH DESCENDER
04B4 CYRILLIC CAPITAL LIGATURE TE TSE
04B5 CYRILLIC SMALL LIGATURE TE TSE
04B6 CYRILLIC CAPITAL LETTER CHE WITH DESCENDER
04B7 CYRILLIC SMALL LETTER CHE WITH DESCENDER
04B8 CYRILLIC CAPITAL LETTER CHE WITH VERTICAL STROKE
04B9 CYRILLIC SMALL LETTER CHE WITH VERTICAL STROKE
04BA CYRILLIC CAPITAL LETTER SHHA
04BB CYRILLIC SMALL LETTER SHHA
04BC CYRILLIC CAPITAL LETTER ABKHASIAN CHE
04BD CYRILLIC SMALL LETTER ABKHASIAN CHE
04BE CYRILLIC CAPITAL LETTER ABKHASIAN CHE WITH DESCENDER
04BF CYRILLIC SMALL LETTER ABKHASIAN CHE WITH DESCENDER
04C0 CYRILLIC LETTER PALOCHKA
04C1 CYRILLIC CAPITAL LETTER ZHE WITH BREVE
04C2 CYRILLIC SMALL LETTER ZHE WITH BREVE
04C3 CYRILLIC CAPITAL LETTER KA WITH HOOK
04C4 CYRILLIC SMALL LETTER KA WITH HOOK
04C5 CYRILLIC CAPITAL LETTER EL WITH TAIL
04C6 CYRILLIC SMALL LETTER EL WITH TAIL
04C7 CYRILLIC CAPITAL LETTER EN WITH HOOK
04C8 CYRILLIC SMALL LETTER EN WITH HOOK
04C9 CYRILLIC CAPITAL LETTER EN WITH TAIL
04CA CYRILLIC SMALL LETTER EN WITH TAIL
04CB CYRILLIC CAPITAL LETTER KHAKASSIAN CHE
04CC CYRILLIC SMALL LETTER KHAKASSIAN CHE
04CD CYRILLIC CAPITAL LETTER EM WITH TAIL
04CE CYRILLIC SMALL LETTER EM WITH TAIL
04D0 CYRILLIC CAPITAL LETTER A WITH BREVE
04D1 CYRILLIC SMALL LETTER A WITH BREVE
04D2 CYRILLIC CAPITAL LETTER A WITH DIAERESIS
04D3 CYRILLIC SMALL LETTER A WITH DIAERESIS
04D4 CYRILLIC CAPITAL LIGATURE A IE
04D5 CYRILLIC SMALL LIGATURE A IE
04D6 CYRILLIC CAPITAL LETTER IE WITH BREVE
04D7 CYRILLIC SMALL LETTER IE WITH BREVE
04D8 CYRILLIC CAPITAL LETTER SCHWA
04D9 CYRILLIC SMALL LETTER SCHWA
04DA CYRILLIC CAPITAL LETTER SCHWA WITH DIAERESIS
04DB CYRILLIC SMALL LETTER SCHWA WITH DIAERESIS
04DC CYRILLIC CAPITAL LETTER ZHE WITH DIAERESIS
04DD CYRILLIC SMALL LETTER ZHE WITH DIAERESIS
04DE CYRILLIC CAPITAL LETTER ZE WITH DIAERESIS
04DF CYRILLIC SMALL LETTER ZE WITH DIAERESIS
04E0 CYRILLIC CAPITAL LETTER ABKHASIAN DZE
04E1 CYRILLIC SMALL LETTER ABKHASIAN DZE
04E2 CYRILLIC CAPITAL LETTER I WITH MACRON
04E3 CYRILLIC SMALL LETTER I WITH MACRON
04E4 CYRILLIC CAPITAL LETTER I WITH DIAERESIS
04E5 CYRILLIC SMALL LETTER I WITH DIAERESIS
04E6 CYRILLIC CAPITAL LETTER O WITH DIAERESIS
04E7 CYRILLIC SMALL LETTER O WITH DIAERESIS
04E8 CYRILLIC CAPITAL LETTER BARRED O
04E9 CYRILLIC SMALL LETTER BARRED O
04EA CYRILLIC CAPITAL LETTER BARRED O WITH DIAERESIS
04EB CYRILLIC SMALL LETTER BARRED O WITH DIAERESIS
04EC CYRILLIC CAPITAL LETTER E WITH DIAERESIS
04ED CYRILLIC SMALL LETTER E WITH DIAERESIS
04EE CYRILLIC CAPITAL LETTER U WITH MACRON
04EF CYRILLIC SMALL LETTER U WITH MACRON
04F0 CYRILLIC CAPITAL LETTER U WITH DIAERESIS
04F1 CYRILLIC SMALL LETTER U WITH DIAERESIS
04F2 CYRILLIC CAPITAL LETTER U WITH DOUBLE ACUTE
04F3 CYRILLIC SMALL LETTER U WITH DOUBLE ACUTE
04F4 CYRILLIC CAPITAL LETTER CHE WITH DIAERESIS
04F5 CYRILLIC SMALL LETTER CHE WITH DIAERESIS
04F6 CYRILLIC CAPITAL LETTER GHE WITH DESCENDER
04F7 CYRILLIC SMALL LETTER GHE WITH DESCENDER
04F8 CYRILLIC CAPITAL LETTER YERU WITH DIAERESIS
04F9 CYRILLIC SMALL LETTER YERU WITH DIAERESIS
0500 CYRILLIC CAPITAL LETTER KOMI DE
0501 CYRILLIC SMALL LETTER KOMI DE
0502 CYRILLIC CAPITAL LETTER KOMI DJE
0503 CYRILLIC SMALL LETTER KOMI DJE
0504 CYRILLIC CAPITAL LETTER KOMI ZJE
0505 CYRILLIC SMALL LETTER KOMI ZJE
0506 CYRILLIC CAPITAL LETTER KOMI DZJE
0507 CYRILLIC SMALL LETTER KOMI DZJE
0508 CYRILLIC CAPITAL LETTER KOMI LJE
0509 CYRILLIC SMALL LETTER KOMI LJE
050A CYRILLIC CAPITAL LETTER KOMI NJE
050B CYRILLIC SMALL LETTER KOMI NJE
050C CYRILLIC CAPITAL LETTER KOMI SJE
050D CYRILLIC SMALL LETTER KOMI SJE
050E CYRILLIC CAPITAL LETTER KOMI TJE
050F CYRILLIC SMALL LETTER KOMI TJE
0531 ARMENIAN CAPITAL LETTER AYB
0532 ARMENIAN CAPITAL LETTER BEN
0533 ARMENIAN CAPITAL LETTER GIM
0534 ARMENIAN CAPITAL LETTER DA
0535 ARMENIAN CAPITAL LETTER ECH
0536 ARMENIAN CAPITAL LETTER ZA
0537 ARMENIAN CAPITAL LETTER EH
0538 ARMENIAN CAPITAL LETTER ET
0539 ARMENIAN CAPITAL LETTER TO
053A ARMENIAN CAPITAL LETTER ZHE
053B ARMENIAN CAPITAL LETTER INI
053C ARMENIAN CAPITAL LETTER LIWN
053D ARMENIAN CAPITAL LETTER XEH
053E ARMENIAN CAPITAL LETTER CA
053F ARMENIAN CAPITAL LETTER KEN
0540 ARMENIAN CAPITAL LETTER HO
0541 ARMENIAN CAPITAL LETTER JA
0542 ARMENIAN CAPITAL LETTER GHAD
0543 ARMENIAN CAPITAL LETTER CHEH
0544 ARMENIAN CAPITAL LETTER MEN
0545 ARMENIAN CAPITAL LETTER YI
0546 ARMENIAN CAPITAL LETTER NOW
0547 ARMENIAN CAPITAL LETTER SHA
0548 ARMENIAN CAPITAL LETTER VO
0549 ARMENIAN CAPITAL LETTER CHA
054A ARMENIAN CAPITAL LETTER PEH
054B ARMENIAN CAPITAL LETTER JHEH
054C ARMENIAN CAPITAL LETTER RA
054D ARMENIAN CAPITAL LETTER SEH
054E ARMENIAN CAPITAL LETTER VEW
054F ARMENIAN CAPITAL LETTER TIWN
0550 ARMENIAN CAPITAL LETTER REH
0551 ARMENIAN CAPITAL LETTER CO
0552 ARMENIAN CAPITAL LETTER YIWN
0553 ARMENIAN CAPITAL LETTER PIWR
0554 ARMENIAN CAPITAL LETTER KEH
0555 ARMENIAN CAPITAL LETTER OH
0556 ARMENIAN CAPITAL LETTER FEH
0559 ARMENIAN MODIFIER LETTER LEFT HALF RING
055A ARMENIAN APOSTROPHE
055B ARMENIAN EMPHASIS MARK
055C ARMENIAN EXCLAMATION MARK
055D ARMENIAN COMMA
055E ARMENIAN QUESTION MARK
055F ARMENIAN ABBREVIATION MARK
0561 ARMENIAN SMALL LETTER AYB
0562 ARMENIAN SMALL LETTER BEN
0563 ARMENIAN SMALL LETTER GIM
0564 ARMENIAN SMALL LETTER DA
0565 ARMENIAN SMALL LETTER ECH
0566 ARMENIAN SMALL LETTER ZA
0567 ARMENIAN SMALL LETTER EH
0568 ARMENIAN SMALL LETTER ET
0569 ARMENIAN SMALL LETTER TO
056A ARMENIAN SMALL LETTER ZHE
056B ARMENIAN SMALL LETTER INI
056C ARMENIAN SMALL LETTER LIWN
056D ARMENIAN SMALL LETTER XEH
056E ARMENIAN SMALL LETTER CA
056F ARMENIAN SMALL LETTER KEN
0570 ARMENIAN SMALL LETTER HO
0571 ARMENIAN SMALL LETTER JA
0572 ARMENIAN SMALL LETTER GHAD
0573 ARMENIAN SMALL LETTER CHEH
0574 ARMENIAN SMALL LETTER MEN
0575 ARMENIAN SMALL LETTER YI
0576 ARMENIAN SMALL LETTER NOW
0577 ARMENIAN SMALL LETTER SHA
0578 ARMENIAN SMALL LETTER VO
0579 ARMENIAN SMALL LETTER CHA
057A ARMENIAN SMALL LETTER PEH
057B ARMENIAN SMALL LETTER JHEH
057C ARMENIAN SMALL LETTER RA
057D ARMENIAN SMALL LETTER SEH
057E ARMENIAN SMALL LETTER VEW
057F ARMENIAN SMALL LETTER TIWN
0580 ARMENIAN SMALL LETTER REH
0581 ARMENIAN SMALL LETTER CO
0582 ARMENIAN SMALL LETTER YIWN
0583 ARMENIAN SMALL LETTER PIWR
0584 ARMENIAN SMALL LETTER KEH
0585 ARMENIAN SMALL LETTER OH
0586 ARMENIAN SMALL LETTER FEH
0587 ARMENIAN SMALL LIGATURE ECH YIWN
0589 ARMENIAN FULL STOP
058A ARMENIAN HYPHEN
0591 HEBREW ACCENT ETNAHTA
0592 HEBREW ACCENT SEGOL
0593 HEBREW ACCENT SHALSHELET
0594 HEBREW ACCENT ZAQEF QATAN
0595 HEBREW ACCENT ZAQEF GADOL
0596 HEBREW ACCENT TIPEHA
0597 HEBREW ACCENT REVIA
0598 HEBREW ACCENT ZARQA
0599 HEBREW ACCENT PASHTA
059A HEBREW ACCENT YETIV
059B HEBREW ACCENT TEVIR
059C HEBREW ACCENT GERESH
059D HEBREW ACCENT GERESH MUQDAM
059E HEBREW ACCENT GERSHAYIM
059F HEBREW ACCENT QARNEY PARA
05A0 HEBREW ACCENT TELISHA GEDOLA
05A1 HEBREW ACCENT PAZER
05A2 HEBREW ACCENT ATNAH HAFUKH
05A3 HEBREW ACCENT MUNAH
05A4 HEBREW ACCENT MAHAPAKH
05A5 HEBREW ACCENT MERKHA
05A6 HEBREW ACCENT MERKHA KEFULA
05A7 HEBREW ACCENT DARGA
05A8 HEBREW ACCENT QADMA
05A9 HEBREW ACCENT TELISHA QETANA
05AA HEBREW ACCENT YERAH BEN YOMO
05AB HEBREW ACCENT OLE
05AC HEBREW ACCENT ILUY
05AD HEBREW ACCENT DEHI
05AE HEBREW ACCENT ZINOR
05AF HEBREW MARK MASORA CIRCLE
05B0 HEBREW POINT SHEVA
05B1 HEBREW POINT HATAF SEGOL
05B2 HEBREW POINT HATAF PATAH
05B3 HEBREW POINT HATAF QAMATS
05B4 HEBREW POINT HIRIQ
05B5 HEBREW POINT TSERE
05B6 HEBREW POINT SEGOL
05B7 HEBREW POINT PATAH
05B8 HEBREW POINT QAMATS
05B9 HEBREW POINT HOLAM
05BB HEBREW POINT QUBUTS
05BC HEBREW POINT DAGESH OR MAPIQ
05BD HEBREW POINT METEG
05BE HEBREW PUNCTUATION MAQAF
05BF HEBREW POINT RAFE
05C0 HEBREW PUNCTUATION PASEQ
05C1 HEBREW POINT SHIN DOT
05C2 HEBREW POINT SIN DOT
05C3 HEBREW PUNCTUATION SOF PASUQ
05C4 HEBREW MARK UPPER DOT
05C5 HEBREW MARK LOWER DOT
05C6 HEBREW PUNCTUATION NUN HAFUKHA
05C7 HEBREW POINT QAMATS QATAN
05D0 HEBREW LETTER ALEF
05D1 HEBREW LETTER BET
05D2 HEBREW LETTER GIMEL
05D3 HEBREW LETTER DALET
05D4 HEBREW LETTER HE
05D5 HEBREW LETTER VAV
05D6 HEBREW LETTER ZAYIN
05D7 HEBREW LETTER HET
05D8 HEBREW LETTER TET
05D9 HEBREW LETTER YOD
05DA HEBREW LETTER FINAL KAF
05DB HEBREW LETTER KAF
05DC HEBREW LETTER LAMED
05DD HEBREW LETTER FINAL MEM
05DE HEBREW LETTER MEM
05DF HEBREW LETTER FINAL NUN
05E0 HEBREW LETTER NUN
05E1 HEBREW LETTER SAMEKH
05E2 HEBREW LETTER AYIN
05E3 HEBREW LETTER FINAL PE
05E4 HEBREW LETTER PE
05E5 HEBREW LETTER FINAL TSADI
05E6 HEBREW LETTER TSADI
05E7 HEBREW LETTER QOF
05E8 HEBREW LETTER RESH
05E9 HEBREW LETTER SHIN
05EA HEBREW LETTER TAV
05F0 HEBREW LIGATURE YIDDISH DOUBLE VAV
05F1 HEBREW LIGATURE YIDDISH VAV YOD
05F2 HEBREW LIGATURE YIDDISH DOUBLE YOD
05F3 HEBREW PUNCTUATION GERESH
05F4 HEBREW PUNCTUATION GERSHAYIM
0600 ARABIC NUMBER SIGN
0601 ARABIC SIGN SANAH
0602 ARABIC FOOTNOTE MARKER
0603 ARABIC SIGN SAFHA
060B AFGHANI SIGN
060C ARABIC COMMA
060D ARABIC DATE SEPARATOR
060E ARABIC POETIC VERSE SIGN
060F ARABIC SIGN MISRA
0610 ARABIC SIGN SALLALLAHOU ALAYHE WASSALLAM
0611 ARABIC SIGN ALAYHE ASSALLAM
0612 ARABIC SIGN RAHMATULLAH ALAYHE
0613 ARABIC SIGN RADI ALLAHOU ANHU
0614 ARABIC SIGN TAKHALLUS
0615 ARABIC SMALL HIGH TAH
061B ARABIC SEMICOLON
061E ARABIC TRIPLE DOT PUNCTUATION MARK
061F ARABIC QUESTION MARK
0621 ARABIC LETTER HAMZA
0622 ARABIC LETTER ALEF WITH MADDA ABOVE
0623 ARABIC LETTER ALEF WITH HAMZA ABOVE
0624 ARABIC LETTER WAW WITH HAMZA ABOVE
0625 ARABIC LETTER ALEF WITH HAMZA BELOW
0626 ARABIC LETTER YEH WITH HAMZA ABOVE
0627 ARABIC LETTER ALEF
0628 ARABIC LETTER BEH
0629 ARABIC LETTER TEH MARBUTA
062A ARABIC LETTER TEH
062B ARABIC LETTER THEH
062C ARABIC LETTER JEEM
062D ARABIC LETTER HAH
062E ARABIC LETTER KHAH
062F ARABIC LETTER DAL
0630 ARABIC LETTER THAL
0631 ARABIC LETTER REH
0632 ARABIC LETTER ZAIN
0633 ARABIC LETTER SEEN
0634 ARABIC LETTER SHEEN
0635 ARABIC LETTER SAD
0636 ARABIC LETTER DAD
0637 ARABIC LETTER TAH
0638 ARABIC LETTER ZAH
0639 ARABIC LETTER AIN
063A ARABIC LETTER GHAIN
0640 ARABIC TATWEEL
0641 ARABIC LETTER FEH
0642 ARABIC LETTER QAF
0643 ARABIC LETTER KAF
0644 ARABIC LETTER LAM
0645 ARABIC LETTER MEEM
0646 ARABIC LETTER NOON
0647 ARABIC LETTER HEH
0648 ARABIC LETTER WAW
0649 ARABIC LETTER ALEF MAKSURA
064A ARABIC LETTER YEH
064B ARABIC FATHATAN
064C ARABIC DAMMATAN
064D ARABIC KASRATAN
064E ARABIC FATHA
064F ARABIC DAMMA
0650 ARABIC KASRA
0651 ARABIC SHADDA
0652 ARABIC SUKUN
0653 ARABIC MADDAH ABOVE
0654 ARABIC HAMZA ABOVE
0655 ARABIC HAMZA BELOW
0656 ARABIC SUBSCRIPT ALEF
0657 ARABIC INVERTED DAMMA
0658 ARABIC MARK NOON GHUNNA
0659 ARABIC ZWARAKAY
065A ARABIC VOWEL SIGN SMALL V ABOVE
065B ARABIC VOWEL SIGN INVERTED SMALL V ABOVE
065C ARABIC VOWEL SIGN DOT BELOW
065D ARABIC REVERSED DAMMA
065E ARABIC FATHA WITH TWO DOTS
0660 ARABIC-INDIC DIGIT ZERO
0661 ARABIC-INDIC DIGIT ONE
0662 ARABIC-INDIC DIGIT TWO
0663 ARABIC-INDIC DIGIT THREE
0664 ARABIC-INDIC DIGIT FOUR
0665 ARABIC-INDIC DIGIT FIVE
0666 ARABIC-INDIC DIGIT SIX
0667 ARABIC-INDIC DIGIT SEVEN
0668 ARABIC-INDIC DIGIT EIGHT
0669 ARABIC-INDIC DIGIT NINE
066A ARABIC PERCENT SIGN
066B ARABIC DECIMAL SEPARATOR
066C ARABIC THOUSANDS SEPARATOR
066D ARABIC FIVE POINTED STAR
066E ARABIC LETTER DOTLESS BEH
066F ARABIC LETTER DOTLESS QAF
0670 ARABIC LETTER SUPERSCRIPT ALEF
0671 ARABIC LETTER ALEF WASLA
0672 ARABIC LETTER ALEF WITH WAVY HAMZA ABOVE
0673 ARABIC LETTER ALEF WITH WAVY HAMZA BELOW
0674 ARABIC LETTER HIGH HAMZA
0675 ARABIC LETTER HIGH HAMZA ALEF
0676 ARABIC LETTER HIGH HAMZA WAW
0677 ARABIC LETTER U WITH HAMZA ABOVE
0678 ARABIC LETTER HIGH HAMZA YEH
0679 ARABIC LETTER TTEH
067A ARABIC LETTER TTEHEH
067B ARABIC LETTER BEEH
067C ARABIC LETTER TEH WITH RING
067D ARABIC LETTER TEH WITH THREE DOTS ABOVE DOWNWARDS
067E ARABIC LETTER PEH
067F ARABIC LETTER TEHEH
0680 ARABIC LETTER BEHEH
0681 ARABIC LETTER HAH WITH HAMZA ABOVE
0682 ARABIC LETTER HAH WITH TWO DOTS VERTICAL ABOVE
0683 ARABIC LETTER NYEH
0684 ARABIC LETTER DYEH
0685 ARABIC LETTER HAH WITH THREE DOTS ABOVE
0686 ARABIC LETTER TCHEH
0687 ARABIC LETTER TCHEHEH
0688 ARABIC LETTER DDAL
0689 ARABIC LETTER DAL WITH RING
068A ARABIC LETTER DAL WITH DOT BELOW
068B ARABIC LETTER DAL WITH DOT BELOW AND SMALL TAH
068C ARABIC LETTER DAHAL
068D ARABIC LETTER DDAHAL
068E ARABIC LETTER DUL
068F ARABIC LETTER DAL WITH THREE DOTS ABOVE DOWNWARDS
0690 ARABIC LETTER DAL WITH FOUR DOTS ABOVE
0691 ARABIC LETTER RREH
0692 ARABIC LETTER REH WITH SMALL V
0693 ARABIC LETTER REH WITH RING
0694 ARABIC LETTER REH WITH DOT BELOW
0695 ARABIC LETTER REH WITH SMALL V BELOW
0696 ARABIC LETTER REH WITH DOT BELOW AND DOT ABOVE
0697 ARABIC LETTER REH WITH TWO DOTS ABOVE
0698 ARABIC LETTER JEH
0699 ARABIC LETTER REH WITH FOUR DOTS ABOVE
069A ARABIC LETTER SEEN WITH DOT BELOW AND DOT ABOVE
069B ARABIC LETTER SEEN WITH THREE DOTS BELOW
069C ARABIC LETTER SEEN WITH THREE DOTS BELOW AND THREE DOTS ABOVE
069D ARABIC LETTER SAD WITH TWO DOTS BELOW
069E ARABIC LETTER SAD WITH THREE DOTS ABOVE
069F ARABIC LETTER TAH WITH THREE DOTS ABOVE
06A0 ARABIC LETTER AIN WITH THREE DOTS ABOVE
06A1 ARABIC LETTER DOTLESS FEH
06A2 ARABIC LETTER FEH WITH DOT MOVED BELOW
06A3 ARABIC LETTER FEH WITH DOT BELOW
06A4 ARABIC LETTER VEH
06A5 ARABIC LETTER FEH WITH THREE DOTS BELOW
06A6 ARABIC LETTER PEHEH
06A7 ARABIC LETTER QAF WITH DOT ABOVE
06A8 ARABIC LETTER QAF WITH THREE DOTS ABOVE
06A9 ARABIC LETTER KEHEH
06AA ARABIC LETTER SWASH KAF
06AB ARABIC LETTER KAF WITH RING
06AC ARABIC LETTER KAF WITH DOT ABOVE
06AD ARABIC LETTER NG
06AE ARABIC LETTER KAF WITH THREE DOTS BELOW
06AF ARABIC LETTER GAF
06B0 ARABIC LETTER GAF WITH RING
06B1 ARABIC LETTER NGOEH
06B2 ARABIC LETTER GAF WITH TWO DOTS BELOW
06B3 ARABIC LETTER GUEH
06B4 ARABIC LETTER GAF WITH THREE DOTS ABOVE
06B5 ARABIC LETTER LAM WITH SMALL V
06B6 ARABIC LETTER LAM WITH DOT ABOVE
06B7 ARABIC LETTER LAM WITH THREE DOTS ABOVE
06B8 ARABIC LETTER LAM WITH THREE DOTS BELOW
06B9 ARABIC LETTER NOON WITH DOT BELOW
06BA ARABIC LETTER NOON GHUNNA
06BB ARABIC LETTER RNOON
06BC ARABIC LETTER NOON WITH RING
06BD ARABIC LETTER NOON WITH THREE DOTS ABOVE
06BE ARABIC LETTER HEH DOACHASHMEE
06BF ARABIC LETTER TCHEH WITH DOT ABOVE
06C0 ARABIC LETTER HEH WITH YEH ABOVE
06C1 ARABIC LETTER HEH GOAL
06C2 ARABIC LETTER HEH GOAL WITH HAMZA ABOVE
06C3 ARABIC LETTER TEH MARBUTA GOAL
06C4 ARABIC LETTER WAW WITH RING
06C5 ARABIC LETTER KIRGHIZ OE
06C6 ARABIC LETTER OE
06C7 ARABIC LETTER U
06C8 ARABIC LETTER YU
06C9 ARABIC LETTER KIRGHIZ YU
06CA ARABIC LETTER WAW WITH TWO DOTS ABOVE
06CB ARABIC LETTER VE
06CC ARABIC LETTER FARSI YEH
06CD ARABIC LETTER YEH WITH TAIL
06CE ARABIC LETTER YEH WITH SMALL V
06CF ARABIC LETTER WAW WITH DOT ABOVE
06D0 ARABIC LETTER E
06D1 ARABIC LETTER YEH WITH THREE DOTS BELOW
06D2 ARABIC LETTER YEH BARREE
06D3 ARABIC LETTER YEH BARREE WITH HAMZA ABOVE
06D4 ARABIC FULL STOP
06D5 ARABIC LETTER AE
06D6 ARABIC SMALL HIGH LIGATURE SAD WITH LAM WITH ALEF MAKSURA
06D7 ARABIC SMALL HIGH LIGATURE QAF WITH LAM WITH ALEF MAKSURA
06D8 ARABIC SMALL HIGH MEEM INITIAL FORM
06D9 ARABIC SMALL HIGH LAM ALEF
06DA ARABIC SMALL HIGH JEEM
06DB ARABIC SMALL HIGH THREE DOTS
06DC ARABIC SMALL HIGH SEEN
06DD ARABIC END OF AYAH
06DE ARABIC START OF RUB EL HIZB
06DF ARABIC SMALL HIGH ROUNDED ZERO
06E0 ARABIC SMALL HIGH UPRIGHT RECTANGULAR ZERO
06E1 ARABIC SMALL HIGH DOTLESS HEAD OF KHAH
06E2 ARABIC SMALL HIGH MEEM ISOLATED FORM
06E3 ARABIC SMALL LOW SEEN
06E4 ARABIC SMALL HIGH MADDA
06E5 ARABIC SMALL WAW
06E6 ARABIC SMALL YEH
06E7 ARABIC SMALL HIGH YEH
06E8 ARABIC SMALL HIGH NOON
06E9 ARABIC PLACE OF SAJDAH
06EA ARABIC EMPTY CENTRE LOW STOP
06EB ARABIC EMPTY CENTRE HIGH STOP
06EC ARABIC ROUNDED HIGH STOP WITH FILLED CENTRE
06ED ARABIC SMALL LOW MEEM
06EE ARABIC LETTER DAL WITH INVERTED V
06EF ARABIC LETTER REH WITH INVERTED V
06F0 EXTENDED ARABIC-INDIC DIGIT ZERO
06F1 EXTENDED ARABIC-INDIC DIGIT ONE
06F2 EXTENDED ARABIC-INDIC DIGIT TWO
06F3 EXTENDED ARABIC-INDIC DIGIT THREE
06F4 EXTENDED ARABIC-INDIC DIGIT FOUR
06F5 EXTENDED ARABIC-INDIC DIGIT FIVE
06F6 EXTENDED ARABIC-INDIC DIGIT SIX
06F7 EXTENDED ARABIC-INDIC DIGIT SEVEN
06F8 EXTENDED ARABIC-INDIC DIGIT EIGHT
06F9 EXTENDED ARABIC-INDIC DIGIT NINE
06FA ARABIC LETTER SHEEN WITH DOT BELOW
06FB ARABIC LETTER DAD WITH DOT BELOW
06FC ARABIC LETTER GHAIN WITH DOT BELOW
06FD ARABIC SIGN SINDHI AMPERSAND
06FE ARABIC SIGN SINDHI POSTPOSITION MEN
06FF ARABIC LETTER HEH WITH INVERTED V
0700 SYRIAC END OF PARAGRAPH
0701 SYRIAC SUPRALINEAR FULL STOP
0702 SYRIAC SUBLINEAR FULL STOP
0703 SYRIAC SUPRALINEAR COLON
0704 SYRIAC SUBLINEAR COLON
0705 SYRIAC HORIZONTAL COLON
0706 SYRIAC COLON SKEWED LEFT
0707 SYRIAC COLON SKEWED RIGHT
0708 SYRIAC SUPRALINEAR COLON SKEWED LEFT
0709 SYRIAC SUBLINEAR COLON SKEWED RIGHT
070A SYRIAC CONTRACTION
070B SYRIAC HARKLEAN OBELUS
070C SYRIAC HARKLEAN METOBELUS
070D SYRIAC HARKLEAN ASTERISCUS
070F SYRIAC ABBREVIATION MARK
0710 SYRIAC LETTER ALAPH
0711 SYRIAC LETTER SUPERSCRIPT ALAPH
0712 SYRIAC LETTER BETH
0713 SYRIAC LETTER GAMAL
0714 SYRIAC LETTER GAMAL GARSHUNI
0715 SYRIAC LETTER DALATH
0716 SYRIAC LETTER DOTLESS DALATH RISH
0717 SYRIAC LETTER HE
0718 SYRIAC LETTER WAW
0719 SYRIAC LETTER ZAIN
071A SYRIAC LETTER HETH
071B SYRIAC LETTER TETH
071C SYRIAC LETTER TETH GARSHUNI
071D SYRIAC LETTER YUDH
071E SYRIAC LETTER YUDH HE
071F SYRIAC LETTER KAPH
0720 SYRIAC LETTER LAMADH
0721 SYRIAC LETTER MIM
0722 SYRIAC LETTER NUN
0723 SYRIAC LETTER SEMKATH
0724 SYRIAC LETTER FINAL SEMKATH
0725 SYRIAC LETTER E
0726 SYRIAC LETTER PE
0727 SYRIAC LETTER REVERSED PE
0728 SYRIAC LETTER SADHE
0729 SYRIAC LETTER QAPH
072A SYRIAC LETTER RISH
072B SYRIAC LETTER SHIN
072C SYRIAC LETTER TAW
072D SYRIAC LETTER PERSIAN BHETH
072E SYRIAC LETTER PERSIAN GHAMAL
072F SYRIAC LETTER PERSIAN DHALATH
0730 SYRIAC PTHAHA ABOVE
0731 SYRIAC PTHAHA BELOW
0732 SYRIAC PTHAHA DOTTED
0733 SYRIAC ZQAPHA ABOVE
0734 SYRIAC ZQAPHA BELOW
0735 SYRIAC ZQAPHA DOTTED
0736 SYRIAC RBASA ABOVE
0737 SYRIAC RBASA BELOW
0738 SYRIAC DOTTED ZLAMA HORIZONTAL
0739 SYRIAC DOTTED ZLAMA ANGULAR
073A SYRIAC HBASA ABOVE
073B SYRIAC HBASA BELOW
073C SYRIAC HBASA-ESASA DOTTED
073D SYRIAC ESASA ABOVE
073E SYRIAC ESASA BELOW
073F SYRIAC RWAHA
0740 SYRIAC FEMININE DOT
0741 SYRIAC QUSHSHAYA
0742 SYRIAC RUKKAKHA
0743 SYRIAC TWO VERTICAL DOTS ABOVE
0744 SYRIAC TWO VERTICAL DOTS BELOW
0745 SYRIAC THREE DOTS ABOVE
0746 SYRIAC THREE DOTS BELOW
0747 SYRIAC OBLIQUE LINE ABOVE
0748 SYRIAC OBLIQUE LINE BELOW
0749 SYRIAC MUSIC
074A SYRIAC BARREKH
074D SYRIAC LETTER SOGDIAN ZHAIN
074E SYRIAC LETTER SOGDIAN KHAPH
074F SYRIAC LETTER SOGDIAN FE
0750 ARABIC LETTER BEH WITH THREE DOTS HORIZONTALLY BELOW
0751 ARABIC LETTER BEH WITH DOT BELOW AND THREE DOTS ABOVE
0752 ARABIC LETTER BEH WITH THREE DOTS POINTING UPWARDS BELOW
0753 ARABIC LETTER BEH WITH THREE DOTS POINTING UPWARDS BELOW AND TWO DOTS ABOVE
0754 ARABIC LETTER BEH WITH TWO DOTS BELOW AND DOT ABOVE
0755 ARABIC LETTER BEH WITH INVERTED SMALL V BELOW
0756 ARABIC LETTER BEH WITH SMALL V
0757 ARABIC LETTER HAH WITH TWO DOTS ABOVE
0758 ARABIC LETTER HAH WITH THREE DOTS POINTING UPWARDS BELOW
0759 ARABIC LETTER DAL WITH TWO DOTS VERTICALLY BELOW AND SMALL TAH
075A ARABIC LETTER DAL WITH INVERTED SMALL V BELOW
075B ARABIC LETTER REH WITH STROKE
075C ARABIC LETTER SEEN WITH FOUR DOTS ABOVE
075D ARABIC LETTER AIN WITH TWO DOTS ABOVE
075E ARABIC LETTER AIN WITH THREE DOTS POINTING DOWNWARDS ABOVE
075F ARABIC LETTER AIN WITH TWO DOTS VERTICALLY ABOVE
0760 ARABIC LETTER FEH WITH TWO DOTS BELOW
0761 ARABIC LETTER FEH WITH THREE DOTS POINTING UPWARDS BELOW
0762 ARABIC LETTER KEHEH WITH DOT ABOVE
0763 ARABIC LETTER KEHEH WITH THREE DOTS ABOVE
0764 ARABIC LETTER KEHEH WITH THREE DOTS POINTING UPWARDS BELOW
0765 ARABIC LETTER MEEM WITH DOT ABOVE
0766 ARABIC LETTER MEEM WITH DOT BELOW
0767 ARABIC LETTER NOON WITH TWO DOTS BELOW
0768 ARABIC LETTER NOON WITH SMALL TAH
0769 ARABIC LETTER NOON WITH SMALL V
076A ARABIC LETTER LAM WITH BAR
076B ARABIC LETTER REH WITH TWO DOTS VERTICALLY ABOVE
076C ARABIC LETTER REH WITH HAMZA ABOVE
076D ARABIC LETTER SEEN WITH TWO DOTS VERTICALLY ABOVE
0780 THAANA LETTER HAA
0781 THAANA LETTER SHAVIYANI
0782 THAANA LETTER NOONU
0783 THAANA LETTER RAA
0784 THAANA LETTER BAA
0785 THAANA LETTER LHAVIYANI
0786 THAANA LETTER KAAFU
0787 THAANA LETTER ALIFU
0788 THAANA LETTER VAAVU
0789 THAANA LETTER MEEMU
078A THAANA LETTER FAAFU
078B THAANA LETTER DHAALU
078C THAANA LETTER THAA
078D THAANA LETTER LAAMU
078E THAANA LETTER GAAFU
078F THAANA LETTER GNAVIYANI
0790 THAANA LETTER SEENU
0791 THAANA LETTER DAVIYANI
0792 THAANA LETTER ZAVIYANI
0793 THAANA LETTER TAVIYANI
0794 THAANA LETTER YAA
0795 THAANA LETTER PAVIYANI
0796 THAANA LETTER JAVIYANI
0797 THAANA LETTER CHAVIYANI
0798 THAANA LETTER TTAA
0799 THAANA LETTER HHAA
079A THAANA LETTER KHAA
079B THAANA LETTER THAALU
079C THAANA LETTER ZAA
079D THAANA LETTER SHEENU
079E THAANA LETTER SAADHU
079F THAANA LETTER DAADHU
07A0 THAANA LETTER TO
07A1 THAANA LETTER ZO
07A2 THAANA LETTER AINU
07A3 THAANA LETTER GHAINU
07A4 THAANA LETTER QAAFU
07A5 THAANA LETTER WAAVU
07A6 THAANA ABAFILI
07A7 THAANA AABAAFILI
07A8 THAANA IBIFILI
07A9 THAANA EEBEEFILI
07AA THAANA UBUFILI
07AB THAANA OOBOOFILI
07AC THAANA EBEFILI
07AD THAANA EYBEYFILI
07AE THAANA OBOFILI
07AF THAANA OABOAFILI
07B0 THAANA SUKUN
07B1 THAANA LETTER NAA
0901 DEVANAGARI SIGN CANDRABINDU
0902 DEVANAGARI SIGN ANUSVARA
0903 DEVANAGARI SIGN VISARGA
0904 DEVANAGARI LETTER SHORT A
0905 DEVANAGARI LETTER A
0906 DEVANAGARI LETTER AA
0907 DEVANAGARI LETTER I
0908 DEVANAGARI LETTER II
0909 DEVANAGARI LETTER U
090A DEVANAGARI LETTER UU
090B DEVANAGARI LETTER VOCALIC R
090C DEVANAGARI LETTER VOCALIC L
090D DEVANAGARI LETTER CANDRA E
090E DEVANAGARI LETTER SHORT E
090F DEVANAGARI LETTER E
0910 DEVANAGARI LETTER AI
0911 DEVANAGARI LETTER CANDRA O
0912 DEVANAGARI LETTER SHORT O
0913 DEVANAGARI LETTER O
0914 DEVANAGARI LETTER AU
0915 DEVANAGARI LETTER KA
0916 DEVANAGARI LETTER KHA
0917 DEVANAGARI LETTER GA
0918 DEVANAGARI LETTER GHA
0919 DEVANAGARI LETTER NGA
091A DEVANAGARI LETTER CA
091B DEVANAGARI LETTER CHA
091C DEVANAGARI LETTER JA
091D DEVANAGARI LETTER JHA
091E DEVANAGARI LETTER NYA
091F DEVANAGARI LETTER TTA
0920 DEVANAGARI LETTER TTHA
0921 DEVANAGARI LETTER DDA
0922 DEVANAGARI LETTER DDHA
0923 DEVANAGARI LETTER NNA
0924 DEVANAGARI LETTER TA
0925 DEVANAGARI LETTER THA
0926 DEVANAGARI LETTER DA
0927 DEVANAGARI LETTER DHA
0928 DEVANAGARI LETTER NA
0929 DEVANAGARI LETTER NNNA
092A DEVANAGARI LETTER PA
092B DEVANAGARI LETTER PHA
092C DEVANAGARI LETTER BA
092D DEVANAGARI LETTER BHA
092E DEVANAGARI LETTER MA
092F DEVANAGARI LETTER YA
0930 DEVANAGARI LETTER RA
0931 DEVANAGARI LETTER RRA
0932 DEVANAGARI LETTER LA
0933 DEVANAGARI LETTER LLA
0934 DEVANAGARI LETTER LLLA
0935 DEVANAGARI LETTER VA
0936 DEVANAGARI LETTER SHA
0937 DEVANAGARI LETTER SSA
0938 DEVANAGARI LETTER SA
0939 DEVANAGARI LETTER HA
093C DEVANAGARI SIGN NUKTA
093D DEVANAGARI SIGN AVAGRAHA
093E DEVANAGARI VOWEL SIGN AA
093F DEVANAGARI VOWEL SIGN I
0940 DEVANAGARI VOWEL SIGN II
0941 DEVANAGARI VOWEL SIGN U
0942 DEVANAGARI VOWEL SIGN UU
0943 DEVANAGARI VOWEL SIGN VOCALIC R
0944 DEVANAGARI VOWEL SIGN VOCALIC RR
0945 DEVANAGARI VOWEL SIGN CANDRA E
0946 DEVANAGARI VOWEL SIGN SHORT E
0947 DEVANAGARI VOWEL SIGN E
0948 DEVANAGARI VOWEL SIGN AI
0949 DEVANAGARI VOWEL SIGN CANDRA O
094A DEVANAGARI VOWEL SIGN SHORT O
094B DEVANAGARI VOWEL SIGN O
094C DEVANAGARI VOWEL SIGN AU
094D DEVANAGARI SIGN VIRAMA
0950 DEVANAGARI OM
0951 DEVANAGARI STRESS SIGN UDATTA
0952 DEVANAGARI STRESS SIGN ANUDATTA
0953 DEVANAGARI GRAVE ACCENT
0954 DEVANAGARI ACUTE ACCENT
0958 DEVANAGARI LETTER QA
0959 DEVANAGARI LETTER KHHA
095A DEVANAGARI LETTER GHHA
095B DEVANAGARI LETTER ZA
095C DEVANAGARI LETTER DDDHA
095D DEVANAGARI LETTER RHA
095E DEVANAGARI LETTER FA
095F DEVANAGARI LETTER YYA
0960 DEVANAGARI LETTER VOCALIC RR
0961 DEVANAGARI LETTER VOCALIC LL
0962 DEVANAGARI VOWEL SIGN VOCALIC L
0963 DEVANAGARI VOWEL SIGN VOCALIC LL
0964 DEVANAGARI DANDA
0965 DEVANAGARI DOUBLE DANDA
0966 DEVANAGARI DIGIT ZERO
0967 DEVANAGARI DIGIT ONE
0968 DEVANAGARI DIGIT TWO
0969 DEVANAGARI DIGIT THREE
096A DEVANAGARI DIGIT FOUR
096B DEVANAGARI DIGIT FIVE
096C DEVANAGARI DIGIT SIX
096D DEVANAGARI DIGIT SEVEN
096E DEVANAGARI DIGIT EIGHT
096F DEVANAGARI DIGIT NINE
0970 DEVANAGARI ABBREVIATION SIGN
097D DEVANAGARI LETTER GLOTTAL STOP
0981 BENGALI SIGN CANDRABINDU
0982 BENGALI SIGN ANUSVARA
0983 BENGALI SIGN VISARGA
0985 BENGALI LETTER A
0986 BENGALI LETTER AA
0987 BENGALI LETTER I
0988 BENGALI LETTER II
0989 BENGALI LETTER U
098A BENGALI LETTER UU
098B BENGALI LETTER VOCALIC R
098C BENGALI LETTER VOCALIC L
098F BENGALI LETTER E
0990 BENGALI LETTER AI
0993 BENGALI LETTER O
0994 BENGALI LETTER AU
0995 BENGALI LETTER KA
0996 BENGALI LETTER KHA
0997 BENGALI LETTER GA
0998 BENGALI LETTER GHA
0999 BENGALI LETTER NGA
099A BENGALI LETTER CA
099B BENGALI LETTER CHA
099C BENGALI LETTER JA
099D BENGALI LETTER JHA
099E BENGALI LETTER NYA
099F BENGALI LETTER TTA
09A0 BENGALI LETTER TTHA
09A1 BENGALI LETTER DDA
09A2 BENGALI LETTER DDHA
09A3 BENGALI LETTER NNA
09A4 BENGALI LETTER TA
09A5 BENGALI LETTER THA
09A6 BENGALI LETTER DA
09A7 BENGALI LETTER DHA
09A8 BENGALI LETTER NA
09AA BENGALI LETTER PA
09AB BENGALI LETTER PHA
09AC BENGALI LETTER BA
09AD BENGALI LETTER BHA
09AE BENGALI LETTER MA
09AF BENGALI LETTER YA
09B0 BENGALI LETTER RA
09B2 BENGALI LETTER LA
09B6 BENGALI LETTER SHA
09B7 BENGALI LETTER SSA
09B8 BENGALI LETTER SA
09B9 BENGALI LETTER HA
09BC BENGALI SIGN NUKTA
09BD BENGALI SIGN AVAGRAHA
09BE BENGALI VOWEL SIGN AA
09BF BENGALI VOWEL SIGN I
09C0 BENGALI VOWEL SIGN II
09C1 BENGALI VOWEL SIGN U
09C2 BENGALI VOWEL SIGN UU
09C3 BENGALI VOWEL SIGN VOCALIC R
09C4 BENGALI VOWEL SIGN VOCALIC RR
09C7 BENGALI VOWEL SIGN E
09C8 BENGALI VOWEL SIGN AI
09CB BENGALI VOWEL SIGN O
09CC BENGALI VOWEL SIGN AU
09CD BENGALI SIGN VIRAMA
09CE BENGALI LETTER KHANDA TA
09D7 BENGALI AU LENGTH MARK
09DC BENGALI LETTER RRA
09DD BENGALI LETTER RHA
09DF BENGALI LETTER YYA
09E0 BENGALI LETTER VOCALIC RR
09E1 BENGALI LETTER VOCALIC LL
09E2 BENGALI VOWEL SIGN VOCALIC L
09E3 BENGALI VOWEL SIGN VOCALIC LL
09E6 BENGALI DIGIT ZERO
09E7 BENGALI DIGIT ONE
09E8 BENGALI DIGIT TWO
09E9 BENGALI DIGIT THREE
09EA BENGALI DIGIT FOUR
09EB BENGALI DIGIT FIVE
09EC BENGALI DIGIT SIX
09ED BENGALI DIGIT SEVEN
09EE BENGALI DIGIT EIGHT
09EF BENGALI DIGIT NINE
09F0 BENGALI LETTER RA WITH MIDDLE DIAGONAL
09F1 BENGALI LETTER RA WITH LOWER DIAGONAL
09F2 BENGALI RUPEE MARK
09F3 BENGALI RUPEE SIGN
09F4 BENGALI CURRENCY NUMERATOR ONE
09F5 BENGALI CURRENCY NUMERATOR TWO
09F6 BENGALI CURRENCY NUMERATOR THREE
09F7 BENGALI CURRENCY NUMERATOR FOUR
09F8 BENGALI CURRENCY NUMERATOR ONE LESS THAN THE DENOMINATOR
09F9 BENGALI CURRENCY DENOMINATOR SIXTEEN
09FA BENGALI ISSHAR
0A01 GURMUKHI SIGN ADAK BINDI
0A02 GURMUKHI SIGN BINDI
0A03 GURMUKHI SIGN VISARGA
0A05 GURMUKHI LETTER A
0A06 GURMUKHI LETTER AA
0A07 GURMUKHI LETTER I
0A08 GURMUKHI LETTER II
0A09 GURMUKHI LETTER U
0A0A GURMUKHI LETTER UU
0A0F GURMUKHI LETTER EE
0A10 GURMUKHI LETTER AI
0A13 GURMUKHI LETTER OO
0A14 GURMUKHI LETTER AU
0A15 GURMUKHI LETTER KA
0A16 GURMUKHI LETTER KHA
0A17 GURMUKHI LETTER GA
0A18 GURMUKHI LETTER GHA
0A19 GURMUKHI LETTER NGA
0A1A GURMUKHI LETTER CA
0A1B GURMUKHI LETTER CHA
0A1C GURMUKHI LETTER JA
0A1D GURMUKHI LETTER JHA
0A1E GURMUKHI LETTER NYA
0A1F GURMUKHI LETTER TTA
0A20 GURMUKHI LETTER TTHA
0A21 GURMUKHI LETTER DDA
0A22 GURMUKHI LETTER DDHA
0A23 GURMUKHI LETTER NNA
0A24 GURMUKHI LETTER TA
0A25 GURMUKHI LETTER THA
0A26 GURMUKHI LETTER DA
0A27 GURMUKHI LETTER DHA
0A28 GURMUKHI LETTER NA
0A2A GURMUKHI LETTER PA
0A2B GURMUKHI LETTER PHA
0A2C GURMUKHI LETTER BA
0A2D GURMUKHI LETTER BHA
0A2E GURMUKHI LETTER MA
0A2F GURMUKHI LETTER YA
0A30 GURMUKHI LETTER RA
0A32 GURMUKHI LETTER LA
0A33 GURMUKHI LETTER LLA
0A35 GURMUKHI LETTER VA
0A36 GURMUKHI LETTER SHA
0A38 GURMUKHI LETTER SA
0A39 GURMUKHI LETTER HA
0A3C GURMUKHI SIGN NUKTA
0A3E GURMUKHI VOWEL SIGN AA
0A3F GURMUKHI VOWEL SIGN I
0A40 GURMUKHI VOWEL SIGN II
0A41 GURMUKHI VOWEL SIGN U
0A42 GURMUKHI VOWEL SIGN UU
0A47 GURMUKHI VOWEL SIGN EE
0A48 GURMUKHI VOWEL SIGN AI
0A4B GURMUKHI VOWEL SIGN OO
0A4C GURMUKHI VOWEL SIGN AU
0A4D GURMUKHI SIGN VIRAMA
0A59 GURMUKHI LETTER KHHA
0A5A GURMUKHI LETTER GHHA
0A5B GURMUKHI LETTER ZA
0A5C GURMUKHI LETTER RRA
0A5E GURMUKHI LETTER FA
0A66 GURMUKHI DIGIT ZERO
0A67 GURMUKHI DIGIT ONE
0A68 GURMUKHI DIGIT TWO
0A69 GURMUKHI DIGIT THREE
0A6A GURMUKHI DIGIT FOUR
0A6B GURMUKHI DIGIT FIVE
0A6C GURMUKHI DIGIT SIX
0A6D GURMUKHI DIGIT SEVEN
0A6E GURMUKHI DIGIT EIGHT
0A6F GURMUKHI DIGIT NINE
0A70 GURMUKHI TIPPI
0A71 GURMUKHI ADDAK
0A72 GURMUKHI IRI
0A73 GURMUKHI URA
0A74 GURMUKHI EK ONKAR
0A81 GUJARATI SIGN CANDRABINDU
0A82 GUJARATI SIGN ANUSVARA
0A83 GUJARATI SIGN VISARGA
0A85 GUJARATI LETTER A
0A86 GUJARATI LETTER AA
0A87 GUJARATI LETTER I
0A88 GUJARATI LETTER II
0A89 GUJARATI LETTER U
0A8A GUJARATI LETTER UU
0A8B GUJARATI LETTER VOCALIC R
0A8C GUJARATI LETTER VOCALIC L
0A8D GUJARATI VOWEL CANDRA E
0A8F GUJARATI LETTER E
0A90 GUJARATI LETTER AI
0A91 GUJARATI VOWEL CANDRA O
0A93 GUJARATI LETTER O
0A94 GUJARATI LETTER AU
0A95 GUJARATI LETTER KA
0A96 GUJARATI LETTER KHA
0A97 GUJARATI LETTER GA
0A98 GUJARATI LETTER GHA
0A99 GUJARATI LETTER NGA
0A9A GUJARATI LETTER CA
0A9B GUJARATI LETTER CHA
0A9C GUJARATI LETTER JA
0A9D GUJARATI LETTER JHA
0A9E GUJARATI LETTER NYA
0A9F GUJARATI LETTER TTA
0AA0 GUJARATI LETTER TTHA
0AA1 GUJARATI LETTER DDA
0AA2 GUJARATI LETTER DDHA
0AA3 GUJARATI LETTER NNA
0AA4 GUJARATI LETTER TA
0AA5 GUJARATI LETTER THA
0AA6 GUJARATI LETTER DA
0AA7 GUJARATI LETTER DHA
0AA8 GUJARATI LETTER NA
0AAA GUJARATI LETTER PA
0AAB GUJARATI LETTER PHA
0AAC GUJARATI LETTER BA
0AAD GUJARATI LETTER BHA
0AAE GUJARATI LETTER MA
0AAF GUJARATI LETTER YA
0AB0 GUJARATI LETTER RA
0AB2 GUJARATI LETTER LA
0AB3 GUJARATI LETTER LLA
0AB5 GUJARATI LETTER VA
0AB6 GUJARATI LETTER SHA
0AB7 GUJARATI LETTER SSA
0AB8 GUJARATI LETTER SA
0AB9 GUJARATI LETTER HA
0ABC GUJARATI SIGN NUKTA
0ABD GUJARATI SIGN AVAGRAHA
0ABE GUJARATI VOWEL SIGN AA
0ABF GUJARATI VOWEL SIGN I
0AC0 GUJARATI VOWEL SIGN II
0AC1 GUJARATI VOWEL SIGN U
0AC2 GUJARATI VOWEL SIGN UU
0AC3 GUJARATI VOWEL SIGN VOCALIC R
0AC4 GUJARATI VOWEL SIGN VOCALIC RR
0AC5 GUJARATI VOWEL SIGN CANDRA E
0AC7 GUJARATI VOWEL SIGN E
0AC8 GUJARATI VOWEL SIGN AI
0AC9 GUJARATI VOWEL SIGN CANDRA O
0ACB GUJARATI VOWEL SIGN O
0ACC GUJARATI VOWEL SIGN AU
0ACD GUJARATI SIGN VIRAMA
0AD0 GUJARATI OM
0AE0 GUJARATI LETTER VOCALIC RR
0AE1 GUJARATI LETTER VOCALIC LL
0AE2 GUJARATI VOWEL SIGN VOCALIC L
0AE3 GUJARATI VOWEL SIGN VOCALIC LL
0AE6 GUJARATI DIGIT ZERO
0AE7 GUJARATI DIGIT ONE
0AE8 GUJARATI DIGIT TWO
0AE9 GUJARATI DIGIT THREE
0AEA GUJARATI DIGIT FOUR
0AEB GUJARATI DIGIT FIVE
0AEC GUJARATI DIGIT SIX
0AED GUJARATI DIGIT SEVEN
0AEE GUJARATI DIGIT EIGHT
0AEF GUJARATI DIGIT NINE
0AF1 GUJARATI RUPEE SIGN
0B01 ORIYA SIGN CANDRABINDU
0B02 ORIYA SIGN ANUSVARA
0B03 ORIYA SIGN VISARGA
0B05 ORIYA LETTER A
0B06 ORIYA LETTER AA
0B07 ORIYA LETTER I
0B08 ORIYA LETTER II
0B09 ORIYA LETTER U
0B0A ORIYA LETTER UU
0B0B ORIYA LETTER VOCALIC R
0B0C ORIYA LETTER VOCALIC L
0B0F ORIYA LETTER E
0B10 ORIYA LETTER AI
0B13 ORIYA LETTER O
0B14 ORIYA LETTER AU
0B15 ORIYA LETTER KA
0B16 ORIYA LETTER KHA
0B17 ORIYA LETTER GA
0B18 ORIYA LETTER GHA
0B19 ORIYA LETTER NGA
0B1A ORIYA LETTER CA
0B1B ORIYA LETTER CHA
0B1C ORIYA LETTER JA
0B1D ORIYA LETTER JHA
0B1E ORIYA LETTER NYA
0B1F ORIYA LETTER TTA
0B20 ORIYA LETTER TTHA
0B21 ORIYA LETTER DDA
0B22 ORIYA LETTER DDHA
0B23 ORIYA LETTER NNA
0B24 ORIYA LETTER TA
0B25 ORIYA LETTER THA
0B26 ORIYA LETTER DA
0B27 ORIYA LETTER DHA
0B28 ORIYA LETTER NA
0B2A ORIYA LETTER PA
0B2B ORIYA LETTER PHA
0B2C ORIYA LETTER BA
0B2D ORIYA LETTER BHA
0B2E ORIYA LETTER MA
0B2F ORIYA LETTER YA
0B30 ORIYA LETTER RA
0B32 ORIYA LETTER LA
0B33 ORIYA LETTER LLA
0B35 ORIYA LETTER VA
0B36 ORIYA LETTER SHA
0B37 ORIYA LETTER SSA
0B38 ORIYA LETTER SA
0B39 ORIYA LETTER HA
0B3C ORIYA SIGN NUKTA
0B3D ORIYA SIGN AVAGRAHA
0B3E ORIYA VOWEL SIGN AA
0B3F ORIYA VOWEL SIGN I
0B40 ORIYA VOWEL SIGN II
0B41 ORIYA VOWEL SIGN U
0B42 ORIYA VOWEL SIGN UU
0B43 ORIYA VOWEL SIGN VOCALIC R
0B47 ORIYA VOWEL SIGN E
0B48 ORIYA VOWEL SIGN AI
0B4B ORIYA VOWEL SIGN O
0B4C ORIYA VOWEL SIGN AU
0B4D ORIYA SIGN VIRAMA
0B56 ORIYA AI LENGTH MARK
0B57 ORIYA AU LENGTH MARK
0B5C ORIYA LETTER RRA
0B5D ORIYA LETTER RHA
0B5F ORIYA LETTER YYA
0B60 ORIYA LETTER VOCALIC RR
0B61 ORIYA LETTER VOCALIC LL
0B66 ORIYA DIGIT ZERO
0B67 ORIYA DIGIT ONE
0B68 ORIYA DIGIT TWO
0B69 ORIYA DIGIT THREE
0B6A ORIYA DIGIT FOUR
0B6B ORIYA DIGIT FIVE
0B6C ORIYA DIGIT SIX
0B6D ORIYA DIGIT SEVEN
0B6E ORIYA DIGIT EIGHT
0B6F ORIYA DIGIT NINE
0B70 ORIYA ISSHAR
0B71 ORIYA LETTER WA
0B82 TAMIL SIGN ANUSVARA
0B83 TAMIL SIGN VISARGA
0B85 TAMIL LETTER A
0B86 TAMIL LETTER AA
0B87 TAMIL LETTER I
0B88 TAMIL LETTER II
0B89 TAMIL LETTER U
0B8A TAMIL LETTER UU
0B8E TAMIL LETTER E
0B8F TAMIL LETTER EE
0B90 TAMIL LETTER AI
0B92 TAMIL LETTER O
0B93 TAMIL LETTER OO
0B94 TAMIL LETTER AU
0B95 TAMIL LETTER KA
0B99 TAMIL LETTER NGA
0B9A TAMIL LETTER CA
0B9C TAMIL LETTER JA
0B9E TAMIL LETTER NYA
0B9F TAMIL LETTER TTA
0BA3 TAMIL LETTER NNA
0BA4 TAMIL LETTER TA
0BA8 TAMIL LETTER NA
0BA9 TAMIL LETTER NNNA
0BAA TAMIL LETTER PA
0BAE TAMIL LETTER MA
0BAF TAMIL LETTER YA
0BB0 TAMIL LETTER RA
0BB1 TAMIL LETTER RRA
0BB2 TAMIL LETTER LA
0BB3 TAMIL LETTER LLA
0BB4 TAMIL LETTER LLLA
0BB5 TAMIL LETTER VA
0BB6 TAMIL LETTER SHA
0BB7 TAMIL LETTER SSA
0BB8 TAMIL LETTER SA
0BB9 TAMIL LETTER HA
0BBE TAMIL VOWEL SIGN AA
0BBF TAMIL VOWEL SIGN I
0BC0 TAMIL VOWEL SIGN II
0BC1 TAMIL VOWEL SIGN U
0BC2 TAMIL VOWEL SIGN UU
0BC6 TAMIL VOWEL SIGN E
0BC7 TAMIL VOWEL SIGN EE
0BC8 TAMIL VOWEL SIGN AI
0BCA TAMIL VOWEL SIGN O
0BCB TAMIL VOWEL SIGN OO
0BCC TAMIL VOWEL SIGN AU
0BCD TAMIL SIGN VIRAMA
0BD7 TAMIL AU LENGTH MARK
0BE6 TAMIL DIGIT ZERO
0BE7 TAMIL DIGIT ONE
0BE8 TAMIL DIGIT TWO
0BE9 TAMIL DIGIT THREE
0BEA TAMIL DIGIT FOUR
0BEB TAMIL DIGIT FIVE
0BEC TAMIL DIGIT SIX
0BED TAMIL DIGIT SEVEN
0BEE TAMIL DIGIT EIGHT
0BEF TAMIL DIGIT NINE
0BF0 TAMIL NUMBER TEN
0BF1 TAMIL NUMBER ONE HUNDRED
0BF2 TAMIL NUMBER ONE THOUSAND
0BF3 TAMIL DAY SIGN
0BF4 TAMIL MONTH SIGN
0BF5 TAMIL YEAR SIGN
0BF6 TAMIL DEBIT SIGN
0BF7 TAMIL CREDIT SIGN
0BF8 TAMIL AS ABOVE SIGN
0BF9 TAMIL RUPEE SIGN
0BFA TAMIL NUMBER SIGN
0C01 TELUGU SIGN CANDRABINDU
0C02 TELUGU SIGN ANUSVARA
0C03 TELUGU SIGN VISARGA
0C05 TELUGU LETTER A
0C06 TELUGU LETTER AA
0C07 TELUGU LETTER I
0C08 TELUGU LETTER II
0C09 TELUGU LETTER U
0C0A TELUGU LETTER UU
0C0B TELUGU LETTER VOCALIC R
0C0C TELUGU LETTER VOCALIC L
0C0E TELUGU LETTER E
0C0F TELUGU LETTER EE
0C10 TELUGU LETTER AI
0C12 TELUGU LETTER O
0C13 TELUGU LETTER OO
0C14 TELUGU LETTER AU
0C15 TELUGU LETTER KA
0C16 TELUGU LETTER KHA
0C17 TELUGU LETTER GA
0C18 TELUGU LETTER GHA
0C19 TELUGU LETTER NGA
0C1A TELUGU LETTER CA
0C1B TELUGU LETTER CHA
0C1C TELUGU LETTER JA
0C1D TELUGU LETTER JHA
0C1E TELUGU LETTER NYA
0C1F TELUGU LETTER TTA
0C20 TELUGU LETTER TTHA
0C21 TELUGU LETTER DDA
0C22 TELUGU LETTER DDHA
0C23 TELUGU LETTER NNA
0C24 TELUGU LETTER TA
0C25 TELUGU LETTER THA
0C26 TELUGU LETTER DA
0C27 TELUGU LETTER DHA
0C28 TELUGU LETTER NA
0C2A TELUGU LETTER PA
0C2B TELUGU LETTER PHA
0C2C TELUGU LETTER BA
0C2D TELUGU LETTER BHA
0C2E TELUGU LETTER MA
0C2F TELUGU LETTER YA
0C30 TELUGU LETTER RA
0C31 TELUGU LETTER RRA
0C32 TELUGU LETTER LA
0C33 TELUGU LETTER LLA
0C35 TELUGU LETTER VA
0C36 TELUGU LETTER SHA
0C37 TELUGU LETTER SSA
0C38 TELUGU LETTER SA
0C39 TELUGU LETTER HA
0C3E TELUGU VOWEL SIGN AA
0C3F TELUGU VOWEL SIGN I
0C40 TELUGU VOWEL SIGN II
0C41 TELUGU VOWEL SIGN U
0C42 TELUGU VOWEL SIGN UU
0C43 TELUGU VOWEL SIGN VOCALIC R
0C44 TELUGU VOWEL SIGN VOCALIC RR
0C46 TELUGU VOWEL SIGN E
0C47 TELUGU VOWEL SIGN EE
0C48 TELUGU VOWEL SIGN AI
0C4A TELUGU VOWEL SIGN O
0C4B TELUGU VOWEL SIGN OO
0C4C TELUGU VOWEL SIGN AU
0C4D TELUGU SIGN VIRAMA
0C55 TELUGU LENGTH MARK
0C56 TELUGU AI LENGTH MARK
0C60 TELUGU LETTER VOCALIC RR
0C61 TELUGU LETTER VOCALIC LL
0C66 TELUGU DIGIT ZERO
0C67 TELUGU DIGIT ONE
0C68 TELUGU DIGIT TWO
0C69 TELUGU DIGIT THREE
0C6A TELUGU DIGIT FOUR
0C6B TELUGU DIGIT FIVE
0C6C TELUGU DIGIT SIX
0C6D TELUGU DIGIT SEVEN
0C6E TELUGU DIGIT EIGHT
0C6F TELUGU DIGIT NINE
0C82 KANNADA SIGN ANUSVARA
0C83 KANNADA SIGN VISARGA
0C85 KANNADA LETTER A
0C86 KANNADA LETTER AA
0C87 KANNADA LETTER I
0C88 KANNADA LETTER II
0C89 KANNADA LETTER U
0C8A KANNADA LETTER UU
0C8B KANNADA LETTER VOCALIC R
0C8C KANNADA LETTER VOCALIC L
0C8E KANNADA LETTER E
0C8F KANNADA LETTER EE
0C90 KANNADA LETTER AI
0C92 KANNADA LETTER O
0C93 KANNADA LETTER OO
0C94 KANNADA LETTER AU
0C95 KANNADA LETTER KA
0C96 KANNADA LETTER KHA
0C97 KANNADA LETTER GA
0C98 KANNADA LETTER GHA
0C99 KANNADA LETTER NGA
0C9A KANNADA LETTER CA
0C9B KANNADA LETTER CHA
0C9C KANNADA LETTER JA
0C9D KANNADA LETTER JHA
0C9E KANNADA LETTER NYA
0C9F KANNADA LETTER TTA
0CA0 KANNADA LETTER TTHA
0CA1 KANNADA LETTER DDA
0CA2 KANNADA LETTER DDHA
0CA3 KANNADA LETTER NNA
0CA4 KANNADA LETTER TA
0CA5 KANNADA LETTER THA
0CA6 KANNADA LETTER DA
0CA7 KANNADA LETTER DHA
0CA8 KANNADA LETTER NA
0CAA KANNADA LETTER PA
0CAB KANNADA LETTER PHA
0CAC KANNADA LETTER BA
0CAD KANNADA LETTER BHA
0CAE KANNADA LETTER MA
0CAF KANNADA LETTER YA
0CB0 KANNADA LETTER RA
0CB1 KANNADA LETTER RRA
0CB2 KANNADA LETTER LA
0CB3 KANNADA LETTER LLA
0CB5 KANNADA LETTER VA
0CB6 KANNADA LETTER SHA
0CB7 KANNADA LETTER SSA
0CB8 KANNADA LETTER SA
0CB9 KANNADA LETTER HA
0CBC KANNADA SIGN NUKTA
0CBD KANNADA SIGN AVAGRAHA
0CBE KANNADA VOWEL SIGN AA
0CBF KANNADA VOWEL SIGN I
0CC0 KANNADA VOWEL SIGN II
0CC1 KANNADA VOWEL SIGN U
0CC2 KANNADA VOWEL SIGN UU
0CC3 KANNADA VOWEL SIGN VOCALIC R
0CC4 KANNADA VOWEL SIGN VOCALIC RR
0CC6 KANNADA VOWEL SIGN E
0CC7 KANNADA VOWEL SIGN EE
0CC8 KANNADA VOWEL SIGN AI
0CCA KANNADA VOWEL SIGN O
0CCB KANNADA VOWEL SIGN OO
0CCC KANNADA VOWEL SIGN AU
0CCD KANNADA SIGN VIRAMA
0CD5 KANNADA LENGTH MARK
0CD6 KANNADA AI LENGTH MARK
0CDE KANNADA LETTER FA
0CE0 KANNADA LETTER VOCALIC RR
0CE1 KANNADA LETTER VOCALIC LL
0CE6 KANNADA DIGIT ZERO
0CE7 KANNADA DIGIT ONE
0CE8 KANNADA DIGIT TWO
0CE9 KANNADA DIGIT THREE
0CEA KANNADA DIGIT FOUR
0CEB KANNADA DIGIT FIVE
0CEC KANNADA DIGIT SIX
0CED KANNADA DIGIT SEVEN
0CEE KANNADA DIGIT EIGHT
0CEF KANNADA DIGIT NINE
0D02 MALAYALAM SIGN ANUSVARA
0D03 MALAYALAM SIGN VISARGA
0D05 MALAYALAM LETTER A
0D06 MALAYALAM LETTER AA
0D07 MALAYALAM LETTER I
0D08 MALAYALAM LETTER II
0D09 MALAYALAM LETTER U
0D0A MALAYALAM LETTER UU
0D0B MALAYALAM LETTER VOCALIC R
0D0C MALAYALAM LETTER VOCALIC L
0D0E MALAYALAM LETTER E
0D0F MALAYALAM LETTER EE
0D10 MALAYALAM LETTER AI
0D12 MALAYALAM LETTER O
0D13 MALAYALAM LETTER OO
0D14 MALAYALAM LETTER AU
0D15 MALAYALAM LETTER KA
0D16 MALAYALAM LETTER KHA
0D17 MALAYALAM LETTER GA
0D18 MALAYALAM LETTER GHA
0D19 MALAYALAM LETTER NGA
0D1A MALAYALAM LETTER CA
0D1B MALAYALAM LETTER CHA
0D1C MALAYALAM LETTER JA
0D1D MALAYALAM LETTER JHA
0D1E MALAYALAM LETTER NYA
0D1F MALAYALAM LETTER TTA
0D20 MALAYALAM LETTER TTHA
0D21 MALAYALAM LETTER DDA
0D22 MALAYALAM LETTER DDHA
0D23 MALAYALAM LETTER NNA
0D24 MALAYALAM LETTER TA
0D25 MALAYALAM LETTER THA
0D26 MALAYALAM LETTER DA
0D27 MALAYALAM LETTER DHA
0D28 MALAYALAM LETTER NA
0D2A MALAYALAM LETTER PA
0D2B MALAYALAM LETTER PHA
0D2C MALAYALAM LETTER BA
0D2D MALAYALAM LETTER BHA
0D2E MALAYALAM LETTER MA
0D2F MALAYALAM LETTER YA
0D30 MALAYALAM LETTER RA
0D31 MALAYALAM LETTER RRA
0D32 MALAYALAM LETTER LA
0D33 MALAYALAM LETTER LLA
0D34 MALAYALAM LETTER LLLA
0D35 MALAYALAM LETTER VA
0D36 MALAYALAM LETTER SHA
0D37 MALAYALAM LETTER SSA
0D38 MALAYALAM LETTER SA
0D39 MALAYALAM LETTER HA
0D3E MALAYALAM VOWEL SIGN AA
0D3F MALAYALAM VOWEL SIGN I
0D40 MALAYALAM VOWEL SIGN II
0D41 MALAYALAM VOWEL SIGN U
0D42 MALAYALAM VOWEL SIGN UU
0D43 MALAYALAM VOWEL SIGN VOCALIC R
0D46 MALAYALAM VOWEL SIGN E
0D47 MALAYALAM VOWEL SIGN EE
0D48 MALAYALAM VOWEL SIGN AI
0D4A MALAYALAM VOWEL SIGN O
0D4B MALAYALAM VOWEL SIGN OO
0D4C MALAYALAM VOWEL SIGN AU
0D4D MALAYALAM SIGN VIRAMA
0D57 MALAYALAM AU LENGTH MARK
0D60 MALAYALAM LETTER VOCALIC RR
0D61 MALAYALAM LETTER VOCALIC LL
0D66 MALAYALAM DIGIT ZERO
0D67 MALAYALAM DIGIT ONE
0D68 MALAYALAM DIGIT TWO
0D69 MALAYALAM DIGIT THREE
0D6A MALAYALAM DIGIT FOUR
0D6B MALAYALAM DIGIT FIVE
0D6C MALAYALAM DIGIT SIX
0D6D MALAYALAM DIGIT SEVEN
0D6E MALAYALAM DIGIT EIGHT
0D6F MALAYALAM DIGIT NINE
0D82 SINHALA SIGN ANUSVARAYA
0D83 SINHALA SIGN VISARGAYA
0D85 SINHALA LETTER AYANNA
0D86 SINHALA LETTER AAYANNA
0D87 SINHALA LETTER AEYANNA
0D88 SINHALA LETTER AEEYANNA
0D89 SINHALA LETTER IYANNA
0D8A SINHALA LETTER IIYANNA
0D8B SINHALA LETTER UYANNA
0D8C SINHALA LETTER UUYANNA
0D8D SINHALA LETTER IRUYANNA
0D8E SINHALA LETTER IRUUYANNA
0D8F SINHALA LETTER ILUYANNA
0D90 SINHALA LETTER ILUUYANNA
0D91 SINHALA LETTER EYANNA
0D92 SINHALA LETTER EEYANNA
0D93 SINHALA LETTER AIYANNA
0D94 SINHALA LETTER OYANNA
0D95 SINHALA LETTER OOYANNA
0D96 SINHALA LETTER AUYANNA
0D9A SINHALA LETTER ALPAPRAANA KAYANNA
0D9B SINHALA LETTER MAHAAPRAANA KAYANNA
0D9C SINHALA LETTER ALPAPRAANA GAYANNA
0D9D SINHALA LETTER MAHAAPRAANA GAYANNA
0D9E SINHALA LETTER KANTAJA NAASIKYAYA
0D9F SINHALA LETTER SANYAKA GAYANNA
0DA0 SINHALA LETTER ALPAPRAANA CAYANNA
0DA1 SINHALA LETTER MAHAAPRAANA CAYANNA
0DA2 SINHALA LETTER ALPAPRAANA JAYANNA
0DA3 SINHALA LETTER MAHAAPRAANA JAYANNA
0DA4 SINHALA LETTER TAALUJA NAASIKYAYA
0DA5 SINHALA LETTER TAALUJA SANYOOGA NAAKSIKYAYA
0DA6 SINHALA LETTER SANYAKA JAYANNA
0DA7 SINHALA LETTER ALPAPRAANA TTAYANNA
0DA8 SINHALA LETTER MAHAAPRAANA TTAYANNA
0DA9 SINHALA LETTER ALPAPRAANA DDAYANNA
0DAA SINHALA LETTER MAHAAPRAANA DDAYANNA
0DAB SINHALA LETTER MUURDHAJA NAYANNA
0DAC SINHALA LETTER SANYAKA DDAYANNA
0DAD SINHALA LETTER ALPAPRAANA TAYANNA
0DAE SINHALA LETTER MAHAAPRAANA TAYANNA
0DAF SINHALA LETTER ALPAPRAANA DAYANNA
0DB0 SINHALA LETTER MAHAAPRAANA DAYANNA
0DB1 SINHALA LETTER DANTAJA NAYANNA
0DB3 SINHALA LETTER SANYAKA DAYANNA
0DB4 SINHALA LETTER ALPAPRAANA PAYANNA
0DB5 SINHALA LETTER MAHAAPRAANA PAYANNA
0DB6 SINHALA LETTER ALPAPRAANA BAYANNA
0DB7 SINHALA LETTER MAHAAPRAANA BAYANNA
0DB8 SINHALA LETTER MAYANNA
0DB9 SINHALA LETTER AMBA BAYANNA
0DBA SINHALA LETTER YAYANNA
0DBB SINHALA LETTER RAYANNA
0DBD SINHALA LETTER DANTAJA LAYANNA
0DC0 SINHALA LETTER VAYANNA
0DC1 SINHALA LETTER TAALUJA SAYANNA
0DC2 SINHALA LETTER MUURDHAJA SAYANNA
0DC3 SINHALA LETTER DANTAJA SAYANNA
0DC4 SINHALA LETTER HAYANNA
0DC5 SINHALA LETTER MUURDHAJA LAYANNA
0DC6 SINHALA LETTER FAYANNA
0DCA SINHALA SIGN AL-LAKUNA
0DCF SINHALA VOWEL SIGN AELA-PILLA
0DD0 SINHALA VOWEL SIGN KETTI AEDA-PILLA
0DD1 SINHALA VOWEL SIGN DIGA AEDA-PILLA
0DD2 SINHALA VOWEL SIGN KETTI IS-PILLA
0DD3 SINHALA VOWEL SIGN DIGA IS-PILLA
0DD4 SINHALA VOWEL SIGN KETTI PAA-PILLA
0DD6 SINHALA VOWEL SIGN DIGA PAA-PILLA
0DD8 SINHALA VOWEL SIGN GAETTA-PILLA
0DD9 SINHALA VOWEL SIGN KOMBUVA
0DDA SINHALA VOWEL SIGN DIGA KOMBUVA
0DDB SINHALA VOWEL SIGN KOMBU DEKA
0DDC SINHALA VOWEL SIGN KOMBUVA HAA AELA-PILLA
0DDD SINHALA VOWEL SIGN KOMBUVA HAA DIGA AELA-PILLA
0DDE SINHALA VOWEL SIGN KOMBUVA HAA GAYANUKITTA
0DDF SINHALA VOWEL SIGN GAYANUKITTA
0DF2 SINHALA VOWEL SIGN DIGA GAETTA-PILLA
0DF3 SINHALA VOWEL SIGN DIGA GAYANUKITTA
0DF4 SINHALA PUNCTUATION KUNDDALIYA
0E01 THAI CHARACTER KO KAI
0E02 THAI CHARACTER KHO KHAI
0E03 THAI CHARACTER KHO KHUAT
0E04 THAI CHARACTER KHO KHWAI
0E05 THAI CHARACTER KHO KHON
0E06 THAI CHARACTER KHO RAKHANG
0E07 THAI CHARACTER NGO NGU
0E08 THAI CHARACTER CHO CHAN
0E09 THAI CHARACTER CHO CHING
0E0A THAI CHARACTER CHO CHANG
0E0B THAI CHARACTER SO SO
0E0C THAI CHARACTER CHO CHOE
0E0D THAI CHARACTER YO YING
0E0E THAI CHARACTER DO CHADA
0E0F THAI CHARACTER TO PATAK
0E10 THAI CHARACTER THO THAN
0E11 THAI CHARACTER THO NANGMONTHO
0E12 THAI CHARACTER THO PHUTHAO
0E13 THAI CHARACTER NO NEN
0E14 THAI CHARACTER DO DEK
0E15 THAI CHARACTER TO TAO
0E16 THAI CHARACTER THO THUNG
0E17 THAI CHARACTER THO THAHAN
0E18 THAI CHARACTER THO THONG
0E19 THAI CHARACTER NO NU
0E1A THAI CHARACTER BO BAIMAI
0E1B THAI CHARACTER PO PLA
0E1C THAI CHARACTER PHO PHUNG
0E1D THAI CHARACTER FO FA
0E1E THAI CHARACTER PHO PHAN
0E1F THAI CHARACTER FO FAN
0E20 THAI CHARACTER PHO SAMPHAO
0E21 THAI CHARACTER MO MA
0E22 THAI CHARACTER YO YAK
0E23 THAI CHARACTER RO RUA
0E24 THAI CHARACTER RU
0E25 THAI CHARACTER LO LING
0E26 THAI CHARACTER LU
0E27 THAI CHARACTER WO WAEN
0E28 THAI CHARACTER SO SALA
0E29 THAI CHARACTER SO RUSI
0E2A THAI CHARACTER SO SUA
0E2B THAI CHARACTER HO HIP
0E2C THAI CHARACTER LO CHULA
0E2D THAI CHARACTER O ANG
0E2E THAI CHARACTER HO NOKHUK
0E2F THAI CHARACTER PAIYANNOI
0E30 THAI CHARACTER SARA A
0E31 THAI CHARACTER MAI HAN-AKAT
0E32 THAI CHARACTER SARA AA
0E33 THAI CHARACTER SARA AM
0E34 THAI CHARACTER SARA I
0E35 THAI CHARACTER SARA II
0E36 THAI CHARACTER SARA UE
0E37 THAI CHARACTER SARA UEE
0E38 THAI CHARACTER SARA U
0E39 THAI CHARACTER SARA UU
0E3A THAI CHARACTER PHINTHU
0E3F THAI CURRENCY SYMBOL BAHT
0E40 THAI CHARACTER SARA E
0E41 THAI CHARACTER SARA AE
0E42 THAI CHARACTER SARA O
0E43 THAI CHARACTER SARA AI MAIMUAN
0E44 THAI CHARACTER SARA AI MAIMALAI
0E45 THAI CHARACTER LAKKHANGYAO
0E46 THAI CHARACTER MAIYAMOK
0E47 THAI CHARACTER MAITAIKHU
0E48 THAI CHARACTER MAI EK
0E49 THAI CHARACTER MAI THO
0E4A THAI CHARACTER MAI TRI
0E4B THAI CHARACTER MAI CHATTAWA
0E4C THAI CHARACTER THANTHAKHAT
0E4D THAI CHARACTER NIKHAHIT
0E4E THAI CHARACTER YAMAKKAN
0E4F THAI CHARACTER FONGMAN
0E50 THAI DIGIT ZERO
0E51 THAI DIGIT ONE
0E52 THAI DIGIT TWO
0E53 THAI DIGIT THREE
0E54 THAI DIGIT FOUR
0E55 THAI DIGIT FIVE
0E56 THAI DIGIT SIX
0E57 THAI DIGIT SEVEN
0E58 THAI DIGIT EIGHT
0E59 THAI DIGIT NINE
0E5A THAI CHARACTER ANGKHANKHU
0E5B THAI CHARACTER KHOMUT
0E81 LAO LETTER KO
0E82 LAO LETTER KHO SUNG
0E84 LAO LETTER KHO TAM
0E87 LAO LETTER NGO
0E88 LAO LETTER CO
0E8A LAO LETTER SO TAM
0E8D LAO LETTER NYO
0E94 LAO LETTER DO
0E95 LAO LETTER TO
0E96 LAO LETTER THO SUNG
0E97 LAO LETTER THO TAM
0E99 LAO LETTER NO
0E9A LAO LETTER BO
0E9B LAO LETTER PO
0E9C LAO LETTER PHO SUNG
0E9D LAO LETTER FO TAM
0E9E LAO LETTER PHO TAM
0E9F LAO LETTER FO SUNG
0EA1 LAO LETTER MO
0EA2 LAO LETTER YO
0EA3 LAO LETTER LO LING
0EA5 LAO LETTER LO LOOT
0EA7 LAO LETTER WO
0EAA LAO LETTER SO SUNG
0EAB LAO LETTER HO SUNG
0EAD LAO LETTER O
0EAE LAO LETTER HO TAM
0EAF LAO ELLIPSIS
0EB0 LAO VOWEL SIGN A
0EB1 LAO VOWEL SIGN MAI KAN
0EB2 LAO VOWEL SIGN AA
0EB3 LAO VOWEL SIGN AM
0EB4 LAO VOWEL SIGN I
0EB5 LAO VOWEL SIGN II
0EB6 LAO VOWEL SIGN Y
0EB7 LAO VOWEL SIGN YY
0EB8 LAO VOWEL SIGN U
0EB9 LAO VOWEL SIGN UU
0EBB LAO VOWEL SIGN MAI KON
0EBC LAO SEMIVOWEL SIGN LO
0EBD LAO SEMIVOWEL SIGN NYO
0EC0 LAO VOWEL SIGN E
0EC1 LAO VOWEL SIGN EI
0EC2 LAO VOWEL SIGN O
0EC3 LAO VOWEL SIGN AY
0EC4 LAO VOWEL SIGN AI
0EC6 LAO KO LA
0EC8 LAO TONE MAI EK
0EC9 LAO TONE MAI THO
0ECA LAO TONE MAI TI
0ECB LAO TONE MAI CATAWA
0ECC LAO CANCELLATION MARK
0ECD LAO NIGGAHITA
0ED0 LAO DIGIT ZERO
0ED1 LAO DIGIT ONE
0ED2 LAO DIGIT TWO
0ED3 LAO DIGIT THREE
0ED4 LAO DIGIT FOUR
0ED5 LAO DIGIT FIVE
0ED6 LAO DIGIT SIX
0ED7 LAO DIGIT SEVEN
0ED8 LAO DIGIT EIGHT
0ED9 LAO DIGIT NINE
0EDC LAO HO NO
0EDD LAO HO MO
0F00 TIBETAN SYLLABLE OM
0F01 TIBETAN MARK GTER YIG MGO TRUNCATED A
0F02 TIBETAN MARK GTER YIG MGO -UM RNAM BCAD MA
0F03 TIBETAN MARK GTER YIG MGO -UM GTER TSHEG MA
0F04 TIBETAN MARK INITIAL YIG MGO MDUN MA
0F05 TIBETAN MARK CLOSING YIG MGO SGAB MA
0F06 TIBETAN MARK CARET YIG MGO PHUR SHAD MA
0F07 TIBETAN MARK YIG MGO TSHEG SHAD MA
0F08 TIBETAN MARK SBRUL SHAD
0F09 TIBETAN MARK BSKUR YIG MGO
0F0A TIBETAN MARK BKA- SHOG YIG MGO
0F0B TIBETAN MARK INTERSYLLABIC TSHEG
0F0C TIBETAN MARK DELIMITER TSHEG BSTAR
0F0D TIBETAN MARK SHAD
0F0E TIBETAN MARK NYIS SHAD
0F0F TIBETAN MARK TSHEG SHAD
0F10 TIBETAN MARK NYIS TSHEG SHAD
0F11 TIBETAN MARK RIN CHEN SPUNGS SHAD
0F12 TIBETAN MARK RGYA GRAM SHAD
0F13 TIBETAN MARK CARET -DZUD RTAGS ME LONG CAN
0F14 TIBETAN MARK GTER TSHEG
0F15 TIBETAN LOGOTYPE SIGN CHAD RTAGS
0F16 TIBETAN LOGOTYPE SIGN LHAG RTAGS
0F17 TIBETAN ASTROLOGICAL SIGN SGRA GCAN -CHAR RTAGS
0F18 TIBETAN ASTROLOGICAL SIGN -KHYUD PA
0F19 TIBETAN ASTROLOGICAL SIGN SDONG TSHUGS
0F1A TIBETAN SIGN RDEL DKAR GCIG
0F1B TIBETAN SIGN RDEL DKAR GNYIS
0F1C TIBETAN SIGN RDEL DKAR GSUM
0F1D TIBETAN SIGN RDEL NAG GCIG
0F1E TIBETAN SIGN RDEL NAG GNYIS
0F1F TIBETAN SIGN RDEL DKAR RDEL NAG
0F20 TIBETAN DIGIT ZERO
0F21 TIBETAN DIGIT ONE
0F22 TIBETAN DIGIT TWO
0F23 TIBETAN DIGIT THREE
0F24 TIBETAN DIGIT FOUR
0F25 TIBETAN DIGIT FIVE
0F26 TIBETAN DIGIT SIX
0F27 TIBETAN DIGIT SEVEN
0F28 TIBETAN DIGIT EIGHT
0F29 TIBETAN DIGIT NINE
0F2A TIBETAN DIGIT HALF ONE
0F2B TIBETAN DIGIT HALF TWO
0F2C TIBETAN DIGIT HALF THREE
0F2D TIBETAN DIGIT HALF FOUR
0F2E TIBETAN DIGIT HALF FIVE
0F2F TIBETAN DIGIT HALF SIX
0F30 TIBETAN DIGIT HALF SEVEN
0F31 TIBETAN DIGIT HALF EIGHT
0F32 TIBETAN DIGIT HALF NINE
0F33 TIBETAN DIGIT HALF ZERO
0F34 TIBETAN MARK BSDUS RTAGS
0F35 TIBETAN MARK NGAS BZUNG NYI ZLA
0F36 TIBETAN MARK CARET -DZUD RTAGS BZHI MIG CAN
0F37 TIBETAN MARK NGAS BZUNG SGOR RTAGS
0F38 TIBETAN MARK CHE MGO
0F39 TIBETAN MARK TSA -PHRU
0F3A TIBETAN MARK GUG RTAGS GYON
0F3B TIBETAN MARK GUG RTAGS GYAS
0F3C TIBETAN MARK ANG KHANG GYON
0F3D TIBETAN MARK ANG KHANG GYAS
0F3E TIBETAN SIGN YAR TSHES
0F3F TIBETAN SIGN MAR TSHES
0F40 TIBETAN LETTER KA
0F41 TIBETAN LETTER KHA
0F42 TIBETAN LETTER GA
0F43 TIBETAN LETTER GHA
0F44 TIBETAN LETTER NGA
0F45 TIBETAN LETTER CA
0F46 TIBETAN LETTER CHA
0F47 TIBETAN LETTER JA
0F49 TIBETAN LETTER NYA
0F4A TIBETAN LETTER TTA
0F4B TIBETAN LETTER TTHA
0F4C TIBETAN LETTER DDA
0F4D TIBETAN LETTER DDHA
0F4E TIBETAN LETTER NNA
0F4F TIBETAN LETTER TA
0F50 TIBETAN LETTER THA
0F51 TIBETAN LETTER DA
0F52 TIBETAN LETTER DHA
0F53 TIBETAN LETTER NA
0F54 TIBETAN LETTER PA
0F55 TIBETAN LETTER PHA
0F56 TIBETAN LETTER BA
0F57 TIBETAN LETTER BHA
0F58 TIBETAN LETTER MA
0F59 TIBETAN LETTER TSA
0F5A TIBETAN LETTER TSHA
0F5B TIBETAN LETTER DZA
0F5C TIBETAN LETTER DZHA
0F5D TIBETAN LETTER WA
0F5E TIBETAN LETTER ZHA
0F5F TIBETAN LETTER ZA
0F60 TIBETAN LETTER -A
0F61 TIBETAN LETTER YA
0F62 TIBETAN LETTER RA
0F63 TIBETAN LETTER LA
0F64 TIBETAN LETTER SHA
0F65 TIBETAN LETTER SSA
0F66 TIBETAN LETTER SA
0F67 TIBETAN LETTER HA
0F68 TIBETAN LETTER A
0F69 TIBETAN LETTER KSSA
0F6A TIBETAN LETTER FIXED-FORM RA
0F71 TIBETAN VOWEL SIGN AA
0F72 TIBETAN VOWEL SIGN I
0F73 TIBETAN VOWEL SIGN II
0F74 TIBETAN VOWEL SIGN U
0F75 TIBETAN VOWEL SIGN UU
0F76 TIBETAN VOWEL SIGN VOCALIC R
0F77 TIBETAN VOWEL SIGN VOCALIC RR
0F78 TIBETAN VOWEL SIGN VOCALIC L
0F79 TIBETAN VOWEL SIGN VOCALIC LL
0F7A TIBETAN VOWEL SIGN E
0F7B TIBETAN VOWEL SIGN EE
0F7C TIBETAN VOWEL SIGN O
0F7D TIBETAN VOWEL SIGN OO
0F7E TIBETAN SIGN RJES SU NGA RO
0F7F TIBETAN SIGN RNAM BCAD
0F80 TIBETAN VOWEL SIGN REVERSED I
0F81 TIBETAN VOWEL SIGN REVERSED II
0F82 TIBETAN SIGN NYI ZLA NAA DA
0F83 TIBETAN SIGN SNA LDAN
0F84 TIBETAN MARK HALANTA
0F85 TIBETAN MARK PALUTA
0F86 TIBETAN SIGN LCI RTAGS
0F87 TIBETAN SIGN YANG RTAGS
0F88 TIBETAN SIGN LCE TSA CAN
0F89 TIBETAN SIGN MCHU CAN
0F8A TIBETAN SIGN GRU CAN RGYINGS
0F8B TIBETAN SIGN GRU MED RGYINGS
0F90 TIBETAN SUBJOINED LETTER KA
0F91 TIBETAN SUBJOINED LETTER KHA
0F92 TIBETAN SUBJOINED LETTER GA
0F93 TIBETAN SUBJOINED LETTER GHA
0F94 TIBETAN SUBJOINED LETTER NGA
0F95 TIBETAN SUBJOINED LETTER CA
0F96 TIBETAN SUBJOINED LETTER CHA
0F97 TIBETAN SUBJOINED LETTER JA
0F99 TIBETAN SUBJOINED LETTER NYA
0F9A TIBETAN SUBJOINED LETTER TTA
0F9B TIBETAN SUBJOINED LETTER TTHA
0F9C TIBETAN SUBJOINED LETTER DDA
0F9D TIBETAN SUBJOINED LETTER DDHA
0F9E TIBETAN SUBJOINED LETTER NNA
0F9F TIBETAN SUBJOINED LETTER TA
0FA0 TIBETAN SUBJOINED LETTER THA
0FA1 TIBETAN SUBJOINED LETTER DA
0FA2 TIBETAN SUBJOINED LETTER DHA
0FA3 TIBETAN SUBJOINED LETTER NA
0FA4 TIBETAN SUBJOINED LETTER PA
0FA5 TIBETAN SUBJOINED LETTER PHA
0FA6 TIBETAN SUBJOINED LETTER BA
0FA7 TIBETAN SUBJOINED LETTER BHA
0FA8 TIBETAN SUBJOINED LETTER MA
0FA9 TIBETAN SUBJOINED LETTER TSA
0FAA TIBETAN SUBJOINED LETTER TSHA
0FAB TIBETAN SUBJOINED LETTER DZA
0FAC TIBETAN SUBJOINED LETTER DZHA
0FAD TIBETAN SUBJOINED LETTER WA
0FAE TIBETAN SUBJOINED LETTER ZHA
0FAF TIBETAN SUBJOINED LETTER ZA
0FB0 TIBETAN SUBJOINED LETTER -A
0FB1 TIBETAN SUBJOINED LETTER YA
0FB2 TIBETAN SUBJOINED LETTER RA
0FB3 TIBETAN SUBJOINED LETTER LA
0FB4 TIBETAN SUBJOINED LETTER SHA
0FB5 TIBETAN SUBJOINED LETTER SSA
0FB6 TIBETAN SUBJOINED LETTER SA
0FB7 TIBETAN SUBJOINED LETTER HA
0FB8 TIBETAN SUBJOINED LETTER A
0FB9 TIBETAN SUBJOINED LETTER KSSA
0FBA TIBETAN SUBJOINED LETTER FIXED-FORM WA
0FBB TIBETAN SUBJOINED LETTER FIXED-FORM YA
0FBC TIBETAN SUBJOINED LETTER FIXED-FORM RA
0FBE TIBETAN KU RU KHA
0FBF TIBETAN KU RU KHA BZHI MIG CAN
0FC0 TIBETAN CANTILLATION SIGN HEAVY BEAT
0FC1 TIBETAN CANTILLATION SIGN LIGHT BEAT
0FC2 TIBETAN CANTILLATION SIGN CANG TE-U
0FC3 TIBETAN CANTILLATION SIGN SBUB -CHAL
0FC4 TIBETAN SYMBOL DRIL BU
0FC5 TIBETAN SYMBOL RDO RJE
0FC6 TIBETAN SYMBOL PADMA GDAN
0FC7 TIBETAN SYMBOL RDO RJE RGYA GRAM
0FC8 TIBETAN SYMBOL PHUR PA
0FC9 TIBETAN SYMBOL NOR BU
0FCA TIBETAN SYMBOL NOR BU NYIS -KHYIL
0FCB TIBETAN SYMBOL NOR BU GSUM -KHYIL
0FCC TIBETAN SYMBOL NOR BU BZHI -KHYIL
0FCF TIBETAN SIGN RDEL NAG GSUM
0FD0 TIBETAN MARK BSKA- SHOG GI MGO RGYAN
0FD1 TIBETAN MARK MNYAM YIG GI MGO RGYAN
1000 MYANMAR LETTER KA
1001 MYANMAR LETTER KHA
1002 MYANMAR LETTER GA
1003 MYANMAR LETTER GHA
1004 MYANMAR LETTER NGA
1005 MYANMAR LETTER CA
1006 MYANMAR LETTER CHA
1007 MYANMAR LETTER JA
1008 MYANMAR LETTER JHA
1009 MYANMAR LETTER NYA
100A MYANMAR LETTER NNYA
100B MYANMAR LETTER TTA
100C MYANMAR LETTER TTHA
100D MYANMAR LETTER DDA
100E MYANMAR LETTER DDHA
100F MYANMAR LETTER NNA
1010 MYANMAR LETTER TA
1011 MYANMAR LETTER THA
1012 MYANMAR LETTER DA
1013 MYANMAR LETTER DHA
1014 MYANMAR LETTER NA
1015 MYANMAR LETTER PA
1016 MYANMAR LETTER PHA
1017 MYANMAR LETTER BA
1018 MYANMAR LETTER BHA
1019 MYANMAR LETTER MA
101A MYANMAR LETTER YA
101B MYANMAR LETTER RA
101C MYANMAR LETTER LA
101D MYANMAR LETTER WA
101E MYANMAR LETTER SA
101F MYANMAR LETTER HA
1020 MYANMAR LETTER LLA
1021 MYANMAR LETTER A
1023 MYANMAR LETTER I
1024 MYANMAR LETTER II
1025 MYANMAR LETTER U
1026 MYANMAR LETTER UU
1027 MYANMAR LETTER E
1029 MYANMAR LETTER O
102A MYANMAR LETTER AU
102C MYANMAR VOWEL SIGN AA
102D MYANMAR VOWEL SIGN I
102E MYANMAR VOWEL SIGN II
102F MYANMAR VOWEL SIGN U
1030 MYANMAR VOWEL SIGN UU
1031 MYANMAR VOWEL SIGN E
1032 MYANMAR VOWEL SIGN AI
1036 MYANMAR SIGN ANUSVARA
1037 MYANMAR SIGN DOT BELOW
1038 MYANMAR SIGN VISARGA
1039 MYANMAR SIGN VIRAMA
1040 MYANMAR DIGIT ZERO
1041 MYANMAR DIGIT ONE
1042 MYANMAR DIGIT TWO
1043 MYANMAR DIGIT THREE
1044 MYANMAR DIGIT FOUR
1045 MYANMAR DIGIT FIVE
1046 MYANMAR DIGIT SIX
1047 MYANMAR DIGIT SEVEN
1048 MYANMAR DIGIT EIGHT
1049 MYANMAR DIGIT NINE
104A MYANMAR SIGN LITTLE SECTION
104B MYANMAR SIGN SECTION
104C MYANMAR SYMBOL LOCATIVE
104D MYANMAR SYMBOL COMPLETED
104E MYANMAR SYMBOL AFOREMENTIONED
104F MYANMAR SYMBOL GENITIVE
1050 MYANMAR LETTER SHA
1051 MYANMAR LETTER SSA
1052 MYANMAR LETTER VOCALIC R
1053 MYANMAR LETTER VOCALIC RR
1054 MYANMAR LETTER VOCALIC L
1055 MYANMAR LETTER VOCALIC LL
1056 MYANMAR VOWEL SIGN VOCALIC R
1057 MYANMAR VOWEL SIGN VOCALIC RR
1058 MYANMAR VOWEL SIGN VOCALIC L
1059 MYANMAR VOWEL SIGN VOCALIC LL
10A0 GEORGIAN CAPITAL LETTER AN
10A1 GEORGIAN CAPITAL LETTER BAN
10A2 GEORGIAN CAPITAL LETTER GAN
10A3 GEORGIAN CAPITAL LETTER DON
10A4 GEORGIAN CAPITAL LETTER EN
10A5 GEORGIAN CAPITAL LETTER VIN
10A6 GEORGIAN CAPITAL LETTER ZEN
10A7 GEORGIAN CAPITAL LETTER TAN
10A8 GEORGIAN CAPITAL LETTER IN
10A9 GEORGIAN CAPITAL LETTER KAN
10AA GEORGIAN CAPITAL LETTER LAS
10AB GEORGIAN CAPITAL LETTER MAN
10AC GEORGIAN CAPITAL LETTER NAR
10AD GEORGIAN CAPITAL LETTER ON
10AE GEORGIAN CAPITAL LETTER PAR
10AF GEORGIAN CAPITAL LETTER ZHAR
10B0 GEORGIAN CAPITAL LETTER RAE
10B1 GEORGIAN CAPITAL LETTER SAN
10B2 GEORGIAN CAPITAL LETTER TAR
10B3 GEORGIAN CAPITAL LETTER UN
10B4 GEORGIAN CAPITAL LETTER PHAR
10B5 GEORGIAN CAPITAL LETTER KHAR
10B6 GEORGIAN CAPITAL LETTER GHAN
10B7 GEORGIAN CAPITAL LETTER QAR
10B8 GEORGIAN CAPITAL LETTER SHIN
10B9 GEORGIAN CAPITAL LETTER CHIN
10BA GEORGIAN CAPITAL LETTER CAN
10BB GEORGIAN CAPITAL LETTER JIL
10BC GEORGIAN CAPITAL LETTER CIL
10BD GEORGIAN CAPITAL LETTER CHAR
10BE GEORGIAN CAPITAL LETTER XAN
10BF GEORGIAN CAPITAL LETTER JHAN
10C0 GEORGIAN CAPITAL LETTER HAE
10C1 GEORGIAN CAPITAL LETTER HE
10C2 GEORGIAN CAPITAL LETTER HIE
10C3 GEORGIAN CAPITAL LETTER WE
10C4 GEORGIAN CAPITAL LETTER HAR
10C5 GEORGIAN CAPITAL LETTER HOE
10D0 GEORGIAN LETTER AN
10D1 GEORGIAN LETTER BAN
10D2 GEORGIAN LETTER GAN
10D3 GEORGIAN LETTER DON
10D4 GEORGIAN LETTER EN
10D5 GEORGIAN LETTER VIN
10D6 GEORGIAN LETTER ZEN
10D7 GEORGIAN LETTER TAN
10D8 GEORGIAN LETTER IN
10D9 GEORGIAN LETTER KAN
10DA GEORGIAN LETTER LAS
10DB GEORGIAN LETTER MAN
10DC GEORGIAN LETTER NAR
10DD GEORGIAN LETTER ON
10DE GEORGIAN LETTER PAR
10DF GEORGIAN LETTER ZHAR
10E0 GEORGIAN LETTER RAE
10E1 GEORGIAN LETTER SAN
10E2 GEORGIAN LETTER TAR
10E3 GEORGIAN LETTER UN
10E4 GEORGIAN LETTER PHAR
10E5 GEORGIAN LETTER KHAR
10E6 GEORGIAN LETTER GHAN
10E7 GEORGIAN LETTER QAR
10E8 GEORGIAN LETTER SHIN
10E9 GEORGIAN LETTER CHIN
10EA GEORGIAN LETTER CAN
10EB GEORGIAN LETTER JIL
10EC GEORGIAN LETTER CIL
10ED GEORGIAN LETTER CHAR
10EE GEORGIAN LETTER XAN
10EF GEORGIAN LETTER JHAN
10F0 GEORGIAN LETTER HAE
10F1 GEORGIAN LETTER HE
10F2 GEORGIAN LETTER HIE
10F3 GEORGIAN LETTER WE
10F4 GEORGIAN LETTER HAR
10F5 GEORGIAN LETTER HOE
10F6 GEORGIAN LETTER FI
10F7 GEORGIAN LETTER YN
10F8 GEORGIAN LETTER ELIFI
10F9 GEORGIAN LETTER TURNED GAN
10FA GEORGIAN LETTER AIN
10FB GEORGIAN PARAGRAPH SEPARATOR
10FC MODIFIER LETTER GEORGIAN NAR
1100 HANGUL CHOSEONG KIYEOK
1101 HANGUL CHOSEONG SSANGKIYEOK
1102 HANGUL CHOSEONG NIEUN
1103 HANGUL CHOSEONG TIKEUT
1104 HANGUL CHOSEONG SSANGTIKEUT
1105 HANGUL CHOSEONG RIEUL
1106 HANGUL CHOSEONG MIEUM
1107 HANGUL CHOSEONG PIEUP
1108 HANGUL CHOSEONG SSANGPIEUP
1109 HANGUL CHOSEONG SIOS
110A HANGUL CHOSEONG SSANGSIOS
110B HANGUL CHOSEONG IEUNG
110C HANGUL CHOSEONG CIEUC
110D HANGUL CHOSEONG SSANGCIEUC
110E HANGUL CHOSEONG CHIEUCH
110F HANGUL CHOSEONG KHIEUKH
1110 HANGUL CHOSEONG THIEUTH
1111 HANGUL CHOSEONG PHIEUPH
1112 HANGUL CHOSEONG HIEUH
1113 HANGUL CHOSEONG NIEUN-KIYEOK
1114 HANGUL CHOSEONG SSANGNIEUN
1115 HANGUL CHOSEONG NIEUN-TIKEUT
1116 HANGUL CHOSEONG NIEUN-PIEUP
1117 HANGUL CHOSEONG TIKEUT-KIYEOK
1118 HANGUL CHOSEONG RIEUL-NIEUN
1119 HANGUL CHOSEONG SSANGRIEUL
111A HANGUL CHOSEONG RIEUL-HIEUH
111B HANGUL CHOSEONG KAPYEOUNRIEUL
111C HANGUL CHOSEONG MIEUM-PIEUP
111D HANGUL CHOSEONG KAPYEOUNMIEUM
111E HANGUL CHOSEONG PIEUP-KIYEOK
111F HANGUL CHOSEONG PIEUP-NIEUN
1120 HANGUL CHOSEONG PIEUP-TIKEUT
1121 HANGUL CHOSEONG PIEUP-SIOS
1122 HANGUL CHOSEONG PIEUP-SIOS-KIYEOK
1123 HANGUL CHOSEONG PIEUP-SIOS-TIKEUT
1124 HANGUL CHOSEONG PIEUP-SIOS-PIEUP
1125 HANGUL CHOSEONG PIEUP-SSANGSIOS
1126 HANGUL CHOSEONG PIEUP-SIOS-CIEUC
1127 HANGUL CHOSEONG PIEUP-CIEUC
1128 HANGUL CHOSEONG PIEUP-CHIEUCH
1129 HANGUL CHOSEONG PIEUP-THIEUTH
112A HANGUL CHOSEONG PIEUP-PHIEUPH
112B HANGUL CHOSEONG KAPYEOUNPIEUP
112C HANGUL CHOSEONG KAPYEOUNSSANGPIEUP
112D HANGUL CHOSEONG SIOS-KIYEOK
112E HANGUL CHOSEONG SIOS-NIEUN
112F HANGUL CHOSEONG SIOS-TIKEUT
1130 HANGUL CHOSEONG SIOS-RIEUL
1131 HANGUL CHOSEONG SIOS-MIEUM
1132 HANGUL CHOSEONG SIOS-PIEUP
1133 HANGUL CHOSEONG SIOS-PIEUP-KIYEOK
1134 HANGUL CHOSEONG SIOS-SSANGSIOS
1135 HANGUL CHOSEONG SIOS-IEUNG
1136 HANGUL CHOSEONG SIOS-CIEUC
1137 HANGUL CHOSEONG SIOS-CHIEUCH
1138 HANGUL CHOSEONG SIOS-KHIEUKH
1139 HANGUL CHOSEONG SIOS-THIEUTH
113A HANGUL CHOSEONG SIOS-PHIEUPH
113B HANGUL CHOSEONG SIOS-HIEUH
113C HANGUL CHOSEONG CHITUEUMSIOS
113D HANGUL CHOSEONG CHITUEUMSSANGSIOS
113E HANGUL CHOSEONG CEONGCHIEUMSIOS
113F HANGUL CHOSEONG CEONGCHIEUMSSANGSIOS
1140 HANGUL CHOSEONG PANSIOS
1141 HANGUL CHOSEONG IEUNG-KIYEOK
1142 HANGUL CHOSEONG IEUNG-TIKEUT
1143 HANGUL CHOSEONG IEUNG-MIEUM
1144 HANGUL CHOSEONG IEUNG-PIEUP
1145 HANGUL CHOSEONG IEUNG-SIOS
1146 HANGUL CHOSEONG IEUNG-PANSIOS
1147 HANGUL CHOSEONG SSANGIEUNG
1148 HANGUL CHOSEONG IEUNG-CIEUC
1149 HANGUL CHOSEONG IEUNG-CHIEUCH
114A HANGUL CHOSEONG IEUNG-THIEUTH
114B HANGUL CHOSEONG IEUNG-PHIEUPH
114C HANGUL CHOSEONG YESIEUNG
114D HANGUL CHOSEONG CIEUC-IEUNG
114E HANGUL CHOSEONG CHITUEUMCIEUC
114F HANGUL CHOSEONG CHITUEUMSSANGCIEUC
1150 HANGUL CHOSEONG CEONGCHIEUMCIEUC
1151 HANGUL CHOSEONG CEONGCHIEUMSSANGCIEUC
1152 HANGUL CHOSEONG CHIEUCH-KHIEUKH
1153 HANGUL CHOSEONG CHIEUCH-HIEUH
1154 HANGUL CHOSEONG CHITUEUMCHIEUCH
1155 HANGUL CHOSEONG CEONGCHIEUMCHIEUCH
1156 HANGUL CHOSEONG PHIEUPH-PIEUP
1157 HANGUL CHOSEONG KAPYEOUNPHIEUPH
1158 HANGUL CHOSEONG SSANGHIEUH
1159 HANGUL CHOSEONG YEORINHIEUH
115F HANGUL CHOSEONG FILLER
1160 HANGUL JUNGSEONG FILLER
1161 HANGUL JUNGSEONG A
1162 HANGUL JUNGSEONG AE
1163 HANGUL JUNGSEONG YA
1164 HANGUL JUNGSEONG YAE
1165 HANGUL JUNGSEONG EO
1166 HANGUL JUNGSEONG E
1167 HANGUL JUNGSEONG YEO
1168 HANGUL JUNGSEONG YE
1169 HANGUL JUNGSEONG O
116A HANGUL JUNGSEONG WA
116B HANGUL JUNGSEONG WAE
116C HANGUL JUNGSEONG OE
116D HANGUL JUNGSEONG YO
116E HANGUL JUNGSEONG U
116F HANGUL JUNGSEONG WEO
1170 HANGUL JUNGSEONG WE
1171 HANGUL JUNGSEONG WI
1172 HANGUL JUNGSEONG YU
1173 HANGUL JUNGSEONG EU
1174 HANGUL JUNGSEONG YI
1175 HANGUL JUNGSEONG I
1176 HANGUL JUNGSEONG A-O
1177 HANGUL JUNGSEONG A-U
1178 HANGUL JUNGSEONG YA-O
1179 HANGUL JUNGSEONG YA-YO
117A HANGUL JUNGSEONG EO-O
117B HANGUL JUNGSEONG EO-U
117C HANGUL JUNGSEONG EO-EU
117D HANGUL JUNGSEONG YEO-O
117E HANGUL JUNGSEONG YEO-U
117F HANGUL JUNGSEONG O-EO
1180 HANGUL JUNGSEONG O-E
1181 HANGUL JUNGSEONG O-YE
1182 HANGUL JUNGSEONG O-O
1183 HANGUL JUNGSEONG O-U
1184 HANGUL JUNGSEONG YO-YA
1185 HANGUL JUNGSEONG YO-YAE
1186 HANGUL JUNGSEONG YO-YEO
1187 HANGUL JUNGSEONG YO-O
1188 HANGUL JUNGSEONG YO-I
1189 HANGUL JUNGSEONG U-A
118A HANGUL JUNGSEONG U-AE
118B HANGUL JUNGSEONG U-EO-EU
118C HANGUL JUNGSEONG U-YE
118D HANGUL JUNGSEONG U-U
118E HANGUL JUNGSEONG YU-A
118F HANGUL JUNGSEONG YU-EO
1190 HANGUL JUNGSEONG YU-E
1191 HANGUL JUNGSEONG YU-YEO
1192 HANGUL JUNGSEONG YU-YE
1193 HANGUL JUNGSEONG YU-U
1194 HANGUL JUNGSEONG YU-I
1195 HANGUL JUNGSEONG EU-U
1196 HANGUL JUNGSEONG EU-EU
1197 HANGUL JUNGSEONG YI-U
1198 HANGUL JUNGSEONG I-A
1199 HANGUL JUNGSEONG I-YA
119A HANGUL JUNGSEONG I-O
119B HANGUL JUNGSEONG I-U
119C HANGUL JUNGSEONG I-EU
119D HANGUL JUNGSEONG I-ARAEA
119E HANGUL JUNGSEONG ARAEA
119F HANGUL JUNGSEONG ARAEA-EO
11A0 HANGUL JUNGSEONG ARAEA-U
11A1 HANGUL JUNGSEONG ARAEA-I
11A2 HANGUL JUNGSEONG SSANGARAEA
11A8 HANGUL JONGSEONG KIYEOK
11A9 HANGUL JONGSEONG SSANGKIYEOK
11AA HANGUL JONGSEONG KIYEOK-SIOS
11AB HANGUL JONGSEONG NIEUN
11AC HANGUL JONGSEONG NIEUN-CIEUC
11AD HANGUL JONGSEONG NIEUN-HIEUH
11AE HANGUL JONGSEONG TIKEUT
11AF HANGUL JONGSEONG RIEUL
11B0 HANGUL JONGSEONG RIEUL-KIYEOK
11B1 HANGUL JONGSEONG RIEUL-MIEUM
11B2 HANGUL JONGSEONG RIEUL-PIEUP
11B3 HANGUL JONGSEONG RIEUL-SIOS
11B4 HANGUL JONGSEONG RIEUL-THIEUTH
11B5 HANGUL JONGSEONG RIEUL-PHIEUPH
11B6 HANGUL JONGSEONG RIEUL-HIEUH
11B7 HANGUL JONGSEONG MIEUM
11B8 HANGUL JONGSEONG PIEUP
11B9 HANGUL JONGSEONG PIEUP-SIOS
11BA HANGUL JONGSEONG SIOS
11BB HANGUL JONGSEONG SSANGSIOS
11BC HANGUL JONGSEONG IEUNG
11BD HANGUL JONGSEONG CIEUC
11BE HANGUL JONGSEONG CHIEUCH
11BF HANGUL JONGSEONG KHIEUKH
11C0 HANGUL JONGSEONG THIEUTH
11C1 HANGUL JONGSEONG PHIEUPH
11C2 HANGUL JONGSEONG HIEUH
11C3 HANGUL JONGSEONG KIYEOK-RIEUL
11C4 HANGUL JONGSEONG KIYEOK-SIOS-KIYEOK
11C5 HANGUL JONGSEONG NIEUN-KIYEOK
11C6 HANGUL JONGSEONG NIEUN-TIKEUT
11C7 HANGUL JONGSEONG NIEUN-SIOS
11C8 HANGUL JONGSEONG NIEUN-PANSIOS
11C9 HANGUL JONGSEONG NIEUN-THIEUTH
11CA HANGUL JONGSEONG TIKEUT-KIYEOK
11CB HANGUL JONGSEONG TIKEUT-RIEUL
11CC HANGUL JONGSEONG RIEUL-KIYEOK-SIOS
11CD HANGUL JONGSEONG RIEUL-NIEUN
11CE HANGUL JONGSEONG RIEUL-TIKEUT
11CF HANGUL JONGSEONG RIEUL-TIKEUT-HIEUH
11D0 HANGUL JONGSEONG SSANGRIEUL
11D1 HANGUL JONGSEONG RIEUL-MIEUM-KIYEOK
11D2 HANGUL JONGSEONG RIEUL-MIEUM-SIOS
11D3 HANGUL JONGSEONG RIEUL-PIEUP-SIOS
11D4 HANGUL JONGSEONG RIEUL-PIEUP-HIEUH
11D5 HANGUL JONGSEONG RIEUL-KAPYEOUNPIEUP
11D6 HANGUL JONGSEONG RIEUL-SSANGSIOS
11D7 HANGUL JONGSEONG RIEUL-PANSIOS
11D8 HANGUL JONGSEONG RIEUL-KHIEUKH
11D9 HANGUL JONGSEONG RIEUL-YEORINHIEUH
11DA HANGUL JONGSEONG MIEUM-KIYEOK
11DB HANGUL JONGSEONG MIEUM-RIEUL
11DC HANGUL JONGSEONG MIEUM-PIEUP
11DD HANGUL JONGSEONG MIEUM-SIOS
11DE HANGUL JONGSEONG MIEUM-SSANGSIOS
11DF HANGUL JONGSEONG MIEUM-PANSIOS
11E0 HANGUL JONGSEONG MIEUM-CHIEUCH
11E1 HANGUL JONGSEONG MIEUM-HIEUH
11E2 HANGUL JONGSEONG KAPYEOUNMIEUM
11E3 HANGUL JONGSEONG PIEUP-RIEUL
11E4 HANGUL JONGSEONG PIEUP-PHIEUPH
11E5 HANGUL JONGSEONG PIEUP-HIEUH
11E6 HANGUL JONGSEONG KAPYEOUNPIEUP
11E7 HANGUL JONGSEONG SIOS-KIYEOK
11E8 HANGUL JONGSEONG SIOS-TIKEUT
11E9 HANGUL JONGSEONG SIOS-RIEUL
11EA HANGUL JONGSEONG SIOS-PIEUP
11EB HANGUL JONGSEONG PANSIOS
11EC HANGUL JONGSEONG IEUNG-KIYEOK
11ED HANGUL JONGSEONG IEUNG-SSANGKIYEOK
11EE HANGUL JONGSEONG SSANGIEUNG
11EF HANGUL JONGSEONG IEUNG-KHIEUKH
11F0 HANGUL JONGSEONG YESIEUNG
11F1 HANGUL JONGSEONG YESIEUNG-SIOS
11F2 HANGUL JONGSEONG YESIEUNG-PANSIOS
11F3 HANGUL JONGSEONG PHIEUPH-PIEUP
11F4 HANGUL JONGSEONG KAPYEOUNPHIEUPH
11F5 HANGUL JONGSEONG HIEUH-NIEUN
11F6 HANGUL JONGSEONG HIEUH-RIEUL
11F7 HANGUL JONGSEONG HIEUH-MIEUM
11F8 HANGUL JONGSEONG HIEUH-PIEUP
11F9 HANGUL JONGSEONG YEORINHIEUH
1200 ETHIOPIC SYLLABLE HA
1201 ETHIOPIC SYLLABLE HU
1202 ETHIOPIC SYLLABLE HI
1203 ETHIOPIC SYLLABLE HAA
1204 ETHIOPIC SYLLABLE HEE
1205 ETHIOPIC SYLLABLE HE
1206 ETHIOPIC SYLLABLE HO
1207 ETHIOPIC SYLLABLE HOA
1208 ETHIOPIC SYLLABLE LA
1209 ETHIOPIC SYLLABLE LU
120A ETHIOPIC SYLLABLE LI
120B ETHIOPIC SYLLABLE LAA
120C ETHIOPIC SYLLABLE LEE
120D ETHIOPIC SYLLABLE LE
120E ETHIOPIC SYLLABLE LO
120F ETHIOPIC SYLLABLE LWA
1210 ETHIOPIC SYLLABLE HHA
1211 ETHIOPIC SYLLABLE HHU
1212 ETHIOPIC SYLLABLE HHI
1213 ETHIOPIC SYLLABLE HHAA
1214 ETHIOPIC SYLLABLE HHEE
1215 ETHIOPIC SYLLABLE HHE
1216 ETHIOPIC SYLLABLE HHO
1217 ETHIOPIC SYLLABLE HHWA
1218 ETHIOPIC SYLLABLE MA
1219 ETHIOPIC SYLLABLE MU
121A ETHIOPIC SYLLABLE MI
121B ETHIOPIC SYLLABLE MAA
121C ETHIOPIC SYLLABLE MEE
121D ETHIOPIC SYLLABLE ME
121E ETHIOPIC SYLLABLE MO
121F ETHIOPIC SYLLABLE MWA
1220 ETHIOPIC SYLLABLE SZA
1221 ETHIOPIC SYLLABLE SZU
1222 ETHIOPIC SYLLABLE SZI
1223 ETHIOPIC SYLLABLE SZAA
1224 ETHIOPIC SYLLABLE SZEE
1225 ETHIOPIC SYLLABLE SZE
1226 ETHIOPIC SYLLABLE SZO
1227 ETHIOPIC SYLLABLE SZWA
1228 ETHIOPIC SYLLABLE RA
1229 ETHIOPIC SYLLABLE RU
122A ETHIOPIC SYLLABLE RI
122B ETHIOPIC SYLLABLE RAA
122C ETHIOPIC SYLLABLE REE
122D ETHIOPIC SYLLABLE RE
122E ETHIOPIC SYLLABLE RO
122F ETHIOPIC SYLLABLE RWA
1230 ETHIOPIC SYLLABLE SA
1231 ETHIOPIC SYLLABLE SU
1232 ETHIOPIC SYLLABLE SI
1233 ETHIOPIC SYLLABLE SAA
1234 ETHIOPIC SYLLABLE SEE
1235 ETHIOPIC SYLLABLE SE
1236 ETHIOPIC SYLLABLE SO
1237 ETHIOPIC SYLLABLE SWA
1238 ETHIOPIC SYLLABLE SHA
1239 ETHIOPIC SYLLABLE SHU
123A ETHIOPIC SYLLABLE SHI
123B ETHIOPIC SYLLABLE SHAA
123C ETHIOPIC SYLLABLE SHEE
123D ETHIOPIC SYLLABLE SHE
123E ETHIOPIC SYLLABLE SHO
123F ETHIOPIC SYLLABLE SHWA
1240 ETHIOPIC SYLLABLE QA
1241 ETHIOPIC SYLLABLE QU
1242 ETHIOPIC SYLLABLE QI
1243 ETHIOPIC SYLLABLE QAA
1244 ETHIOPIC SYLLABLE QEE
1245 ETHIOPIC SYLLABLE QE
1246 ETHIOPIC SYLLABLE QO
1247 ETHIOPIC SYLLABLE QOA
1248 ETHIOPIC SYLLABLE QWA
124A ETHIOPIC SYLLABLE QWI
124B ETHIOPIC SYLLABLE QWAA
124C ETHIOPIC SYLLABLE QWEE
124D ETHIOPIC SYLLABLE QWE
1250 ETHIOPIC SYLLABLE QHA
1251 ETHIOPIC SYLLABLE QHU
1252 ETHIOPIC SYLLABLE QHI
1253 ETHIOPIC SYLLABLE QHAA
1254 ETHIOPIC SYLLABLE QHEE
1255 ETHIOPIC SYLLABLE QHE
1256 ETHIOPIC SYLLABLE QHO
1258 ETHIOPIC SYLLABLE QHWA
125A ETHIOPIC SYLLABLE QHWI
125B ETHIOPIC SYLLABLE QHWAA
125C ETHIOPIC SYLLABLE QHWEE
125D ETHIOPIC SYLLABLE QHWE
1260 ETHIOPIC SYLLABLE BA
1261 ETHIOPIC SYLLABLE BU
1262 ETHIOPIC SYLLABLE BI
1263 ETHIOPIC SYLLABLE BAA
1264 ETHIOPIC SYLLABLE BEE
1265 ETHIOPIC SYLLABLE BE
1266 ETHIOPIC SYLLABLE BO
1267 ETHIOPIC SYLLABLE BWA
1268 ETHIOPIC SYLLABLE VA
1269 ETHIOPIC SYLLABLE VU
126A ETHIOPIC SYLLABLE VI
126B ETHIOPIC SYLLABLE VAA
126C ETHIOPIC SYLLABLE VEE
126D ETHIOPIC SYLLABLE VE
126E ETHIOPIC SYLLABLE VO
126F ETHIOPIC SYLLABLE VWA
1270 ETHIOPIC SYLLABLE TA
1271 ETHIOPIC SYLLABLE TU
1272 ETHIOPIC SYLLABLE TI
1273 ETHIOPIC SYLLABLE TAA
1274 ETHIOPIC SYLLABLE TEE
1275 ETHIOPIC SYLLABLE TE
1276 ETHIOPIC SYLLABLE TO
1277 ETHIOPIC SYLLABLE TWA
1278 ETHIOPIC SYLLABLE CA
1279 ETHIOPIC SYLLABLE CU
127A ETHIOPIC SYLLABLE CI
127B ETHIOPIC SYLLABLE CAA
127C ETHIOPIC SYLLABLE CEE
127D ETHIOPIC SYLLABLE CE
127E ETHIOPIC SYLLABLE CO
127F ETHIOPIC SYLLABLE CWA
1280 ETHIOPIC SYLLABLE XA
1281 ETHIOPIC SYLLABLE XU
1282 ETHIOPIC SYLLABLE XI
1283 ETHIOPIC SYLLABLE XAA
1284 ETHIOPIC SYLLABLE XEE
1285 ETHIOPIC SYLLABLE XE
1286 ETHIOPIC SYLLABLE XO
1287 ETHIOPIC SYLLABLE XOA
1288 ETHIOPIC SYLLABLE XWA
128A ETHIOPIC SYLLABLE XWI
128B ETHIOPIC SYLLABLE XWAA
128C ETHIOPIC SYLLABLE XWEE
128D ETHIOPIC SYLLABLE XWE
1290 ETHIOPIC SYLLABLE NA
1291 ETHIOPIC SYLLABLE NU
1292 ETHIOPIC SYLLABLE NI
1293 ETHIOPIC SYLLABLE NAA
1294 ETHIOPIC SYLLABLE NEE
1295 ETHIOPIC SYLLABLE NE
1296 ETHIOPIC SYLLABLE NO
1297 ETHIOPIC SYLLABLE NWA
1298 ETHIOPIC SYLLABLE NYA
1299 ETHIOPIC SYLLABLE NYU
129A ETHIOPIC SYLLABLE NYI
129B ETHIOPIC SYLLABLE NYAA
129C ETHIOPIC SYLLABLE NYEE
129D ETHIOPIC SYLLABLE NYE
129E ETHIOPIC SYLLABLE NYO
129F ETHIOPIC SYLLABLE NYWA
12A0 ETHIOPIC SYLLABLE GLOTTAL A
12A1 ETHIOPIC SYLLABLE GLOTTAL U
12A2 ETHIOPIC SYLLABLE GLOTTAL I
12A3 ETHIOPIC SYLLABLE GLOTTAL AA
12A4 ETHIOPIC SYLLABLE GLOTTAL EE
12A5 ETHIOPIC SYLLABLE GLOTTAL E
12A6 ETHIOPIC SYLLABLE GLOTTAL O
12A7 ETHIOPIC SYLLABLE GLOTTAL WA
12A8 ETHIOPIC SYLLABLE KA
12A9 ETHIOPIC SYLLABLE KU
12AA ETHIOPIC SYLLABLE KI
12AB ETHIOPIC SYLLABLE KAA
12AC ETHIOPIC SYLLABLE KEE
12AD ETHIOPIC SYLLABLE KE
12AE ETHIOPIC SYLLABLE KO
12AF ETHIOPIC SYLLABLE KOA
12B0 ETHIOPIC SYLLABLE KWA
12B2 ETHIOPIC SYLLABLE KWI
12B3 ETHIOPIC SYLLABLE KWAA
12B4 ETHIOPIC SYLLABLE KWEE
12B5 ETHIOPIC SYLLABLE KWE
12B8 ETHIOPIC SYLLABLE KXA
12B9 ETHIOPIC SYLLABLE KXU
12BA ETHIOPIC SYLLABLE KXI
12BB ETHIOPIC SYLLABLE KXAA
12BC ETHIOPIC SYLLABLE KXEE
12BD ETHIOPIC SYLLABLE KXE
12BE ETHIOPIC SYLLABLE KXO
12C0 ETHIOPIC SYLLABLE KXWA
12C2 ETHIOPIC SYLLABLE KXWI
12C3 ETHIOPIC SYLLABLE KXWAA
12C4 ETHIOPIC SYLLABLE KXWEE
12C5 ETHIOPIC SYLLABLE KXWE
12C8 ETHIOPIC SYLLABLE WA
12C9 ETHIOPIC SYLLABLE WU
12CA ETHIOPIC SYLLABLE WI
12CB ETHIOPIC SYLLABLE WAA
12CC ETHIOPIC SYLLABLE WEE
12CD ETHIOPIC SYLLABLE WE
12CE ETHIOPIC SYLLABLE WO
12CF ETHIOPIC SYLLABLE WOA
12D0 ETHIOPIC SYLLABLE PHARYNGEAL A
12D1 ETHIOPIC SYLLABLE PHARYNGEAL U
12D2 ETHIOPIC SYLLABLE PHARYNGEAL I
12D3 ETHIOPIC SYLLABLE PHARYNGEAL AA
12D4 ETHIOPIC SYLLABLE PHARYNGEAL EE
12D5 ETHIOPIC SYLLABLE PHARYNGEAL E
12D6 ETHIOPIC SYLLABLE PHARYNGEAL O
12D8 ETHIOPIC SYLLABLE ZA
12D9 ETHIOPIC SYLLABLE ZU
12DA ETHIOPIC SYLLABLE ZI
12DB ETHIOPIC SYLLABLE ZAA
12DC ETHIOPIC SYLLABLE ZEE
12DD ETHIOPIC SYLLABLE ZE
12DE ETHIOPIC SYLLABLE ZO
12DF ETHIOPIC SYLLABLE ZWA
12E0 ETHIOPIC SYLLABLE ZHA
12E1 ETHIOPIC SYLLABLE ZHU
12E2 ETHIOPIC SYLLABLE ZHI
12E3 ETHIOPIC SYLLABLE ZHAA
12E4 ETHIOPIC SYLLABLE ZHEE
12E5 ETHIOPIC SYLLABLE ZHE
12E6 ETHIOPIC SYLLABLE ZHO
12E7 ETHIOPIC SYLLABLE ZHWA
12E8 ETHIOPIC SYLLABLE YA
12E9 ETHIOPIC SYLLABLE YU
12EA ETHIOPIC SYLLABLE YI
12EB ETHIOPIC SYLLABLE YAA
12EC ETHIOPIC SYLLABLE YEE
12ED ETHIOPIC SYLLABLE YE
12EE ETHIOPIC SYLLABLE YO
12EF ETHIOPIC SYLLABLE YOA
12F0 ETHIOPIC SYLLABLE DA
12F1 ETHIOPIC SYLLABLE DU
12F2 ETHIOPIC SYLLABLE DI
12F3 ETHIOPIC SYLLABLE DAA
12F4 ETHIOPIC SYLLABLE DEE
12F5 ETHIOPIC SYLLABLE DE
12F6 ETHIOPIC SYLLABLE DO
12F7 ETHIOPIC SYLLABLE DWA
12F8 ETHIOPIC SYLLABLE DDA
12F9 ETHIOPIC SYLLABLE DDU
12FA ETHIOPIC SYLLABLE DDI
12FB ETHIOPIC SYLLABLE DDAA
12FC ETHIOPIC SYLLABLE DDEE
12FD ETHIOPIC SYLLABLE DDE
12FE ETHIOPIC SYLLABLE DDO
12FF ETHIOPIC SYLLABLE DDWA
1300 ETHIOPIC SYLLABLE JA
1301 ETHIOPIC SYLLABLE JU
1302 ETHIOPIC SYLLABLE JI
1303 ETHIOPIC SYLLABLE JAA
1304 ETHIOPIC SYLLABLE JEE
1305 ETHIOPIC SYLLABLE JE
1306 ETHIOPIC SYLLABLE JO
1307 ETHIOPIC SYLLABLE JWA
1308 ETHIOPIC SYLLABLE GA
1309 ETHIOPIC SYLLABLE GU
130A ETHIOPIC SYLLABLE GI
130B ETHIOPIC SYLLABLE GAA
130C ETHIOPIC SYLLABLE GEE
130D ETHIOPIC SYLLABLE GE
130E ETHIOPIC SYLLABLE GO
130F ETHIOPIC SYLLABLE GOA
1310 ETHIOPIC SYLLABLE GWA
1312 ETHIOPIC SYLLABLE GWI
1313 ETHIOPIC SYLLABLE GWAA
1314 ETHIOPIC SYLLABLE GWEE
1315 ETHIOPIC SYLLABLE GWE
1318 ETHIOPIC SYLLABLE GGA
1319 ETHIOPIC SYLLABLE GGU
131A ETHIOPIC SYLLABLE GGI
131B ETHIOPIC SYLLABLE GGAA
131C ETHIOPIC SYLLABLE GGEE
131D ETHIOPIC SYLLABLE GGE
131E ETHIOPIC SYLLABLE GGO
131F ETHIOPIC SYLLABLE GGWAA
1320 ETHIOPIC SYLLABLE THA
1321 ETHIOPIC SYLLABLE THU
1322 ETHIOPIC SYLLABLE THI
1323 ETHIOPIC SYLLABLE THAA
1324 ETHIOPIC SYLLABLE THEE
1325 ETHIOPIC SYLLABLE THE
1326 ETHIOPIC SYLLABLE THO
1327 ETHIOPIC SYLLABLE THWA
1328 ETHIOPIC SYLLABLE CHA
1329 ETHIOPIC SYLLABLE CHU
132A ETHIOPIC SYLLABLE CHI
132B ETHIOPIC SYLLABLE CHAA
132C ETHIOPIC SYLLABLE CHEE
132D ETHIOPIC SYLLABLE CHE
132E ETHIOPIC SYLLABLE CHO
132F ETHIOPIC SYLLABLE CHWA
1330 ETHIOPIC SYLLABLE PHA
1331 ETHIOPIC SYLLABLE PHU
1332 ETHIOPIC SYLLABLE PHI
1333 ETHIOPIC SYLLABLE PHAA
1334 ETHIOPIC SYLLABLE PHEE
1335 ETHIOPIC SYLLABLE PHE
1336 ETHIOPIC SYLLABLE PHO
1337 ETHIOPIC SYLLABLE PHWA
1338 ETHIOPIC SYLLABLE TSA
1339 ETHIOPIC SYLLABLE TSU
133A ETHIOPIC SYLLABLE TSI
133B ETHIOPIC SYLLABLE TSAA
133C ETHIOPIC SYLLABLE TSEE
133D ETHIOPIC SYLLABLE TSE
133E ETHIOPIC SYLLABLE TSO
133F ETHIOPIC SYLLABLE TSWA
1340 ETHIOPIC SYLLABLE TZA
1341 ETHIOPIC SYLLABLE TZU
1342 ETHIOPIC SYLLABLE TZI
1343 ETHIOPIC SYLLABLE TZAA
1344 ETHIOPIC SYLLABLE TZEE
1345 ETHIOPIC SYLLABLE TZE
1346 ETHIOPIC SYLLABLE TZO
1347 ETHIOPIC SYLLABLE TZOA
1348 ETHIOPIC SYLLABLE FA
1349 ETHIOPIC SYLLABLE FU
134A ETHIOPIC SYLLABLE FI
134B ETHIOPIC SYLLABLE FAA
134C ETHIOPIC SYLLABLE FEE
134D ETHIOPIC SYLLABLE FE
134E ETHIOPIC SYLLABLE FO
134F ETHIOPIC SYLLABLE FWA
1350 ETHIOPIC SYLLABLE PA
1351 ETHIOPIC SYLLABLE PU
1352 ETHIOPIC SYLLABLE PI
1353 ETHIOPIC SYLLABLE PAA
1354 ETHIOPIC SYLLABLE PEE
1355 ETHIOPIC SYLLABLE PE
1356 ETHIOPIC SYLLABLE PO
1357 ETHIOPIC SYLLABLE PWA
1358 ETHIOPIC SYLLABLE RYA
1359 ETHIOPIC SYLLABLE MYA
135A ETHIOPIC SYLLABLE FYA
135F ETHIOPIC COMBINING GEMINATION MARK
1360 ETHIOPIC SECTION MARK
1361 ETHIOPIC WORDSPACE
1362 ETHIOPIC FULL STOP
1363 ETHIOPIC COMMA
1364 ETHIOPIC SEMICOLON
1365 ETHIOPIC COLON
1366 ETHIOPIC PREFACE COLON
1367 ETHIOPIC QUESTION MARK
1368 ETHIOPIC PARAGRAPH SEPARATOR
1369 ETHIOPIC DIGIT ONE
136A ETHIOPIC DIGIT TWO
136B ETHIOPIC DIGIT THREE
136C ETHIOPIC DIGIT FOUR
136D ETHIOPIC DIGIT FIVE
136E ETHIOPIC DIGIT SIX
136F ETHIOPIC DIGIT SEVEN
1370 ETHIOPIC DIGIT EIGHT
1371 ETHIOPIC DIGIT NINE
1372 ETHIOPIC NUMBER TEN
1373 ETHIOPIC NUMBER TWENTY
1374 ETHIOPIC NUMBER THIRTY
1375 ETHIOPIC NUMBER FORTY
1376 ETHIOPIC NUMBER FIFTY
1377 ETHIOPIC NUMBER SIXTY
1378 ETHIOPIC NUMBER SEVENTY
1379 ETHIOPIC NUMBER EIGHTY
137A ETHIOPIC NUMBER NINETY
137B ETHIOPIC NUMBER HUNDRED
137C ETHIOPIC NUMBER TEN THOUSAND
1380 ETHIOPIC SYLLABLE SEBATBEIT MWA
1381 ETHIOPIC SYLLABLE MWI
1382 ETHIOPIC SYLLABLE MWEE
1383 ETHIOPIC SYLLABLE MWE
1384 ETHIOPIC SYLLABLE SEBATBEIT BWA
1385 ETHIOPIC SYLLABLE BWI
1386 ETHIOPIC SYLLABLE BWEE
1387 ETHIOPIC SYLLABLE BWE
1388 ETHIOPIC SYLLABLE SEBATBEIT FWA
1389 ETHIOPIC SYLLABLE FWI
138A ETHIOPIC SYLLABLE FWEE
138B ETHIOPIC SYLLABLE FWE
138C ETHIOPIC SYLLABLE SEBATBEIT PWA
138D ETHIOPIC SYLLABLE PWI
138E ETHIOPIC SYLLABLE PWEE
138F ETHIOPIC SYLLABLE PWE
1390 ETHIOPIC TONAL MARK YIZET
1391 ETHIOPIC TONAL MARK DERET
1392 ETHIOPIC TONAL MARK RIKRIK
1393 ETHIOPIC TONAL MARK SHORT RIKRIK
1394 ETHIOPIC TONAL MARK DIFAT
1395 ETHIOPIC TONAL MARK KENAT
1396 ETHIOPIC TONAL MARK CHIRET
1397 ETHIOPIC TONAL MARK HIDET
1398 ETHIOPIC TONAL MARK DERET-HIDET
1399 ETHIOPIC TONAL MARK KURT
13A0 CHEROKEE LETTER A
13A1 CHEROKEE LETTER E
13A2 CHEROKEE LETTER I
13A3 CHEROKEE LETTER O
13A4 CHEROKEE LETTER U
13A5 CHEROKEE LETTER V
13A6 CHEROKEE LETTER GA
13A7 CHEROKEE LETTER KA
13A8 CHEROKEE LETTER GE
13A9 CHEROKEE LETTER GI
13AA CHEROKEE LETTER GO
13AB CHEROKEE LETTER GU
13AC CHEROKEE LETTER GV
13AD CHEROKEE LETTER HA
13AE CHEROKEE LETTER HE
13AF CHEROKEE LETTER HI
13B0 CHEROKEE LETTER HO
13B1 CHEROKEE LETTER HU
13B2 CHEROKEE LETTER HV
13B3 CHEROKEE LETTER LA
13B4 CHEROKEE LETTER LE
13B5 CHEROKEE LETTER LI
13B6 CHEROKEE LETTER LO
13B7 CHEROKEE LETTER LU
13B8 CHEROKEE LETTER LV
13B9 CHEROKEE LETTER MA
13BA CHEROKEE LETTER ME
13BB CHEROKEE LETTER MI
13BC CHEROKEE LETTER MO
13BD CHEROKEE LETTER MU
13BE CHEROKEE LETTER NA
13BF CHEROKEE LETTER HNA
13C0 CHEROKEE LETTER NAH
13C1 CHEROKEE LETTER NE
13C2 CHEROKEE LETTER NI
13C3 CHEROKEE LETTER NO
13C4 CHEROKEE LETTER NU
13C5 CHEROKEE LETTER NV
13C6 CHEROKEE LETTER QUA
13C7 CHEROKEE LETTER QUE
13C8 CHEROKEE LETTER QUI
13C9 CHEROKEE LETTER QUO
13CA CHEROKEE LETTER QUU
13CB CHEROKEE LETTER QUV
13CC CHEROKEE LETTER SA
13CD CHEROKEE LETTER S
13CE CHEROKEE LETTER SE
13CF CHEROKEE LETTER SI
13D0 CHEROKEE LETTER SO
13D1 CHEROKEE LETTER SU
13D2 CHEROKEE LETTER SV
13D3 CHEROKEE LETTER DA
13D4 CHEROKEE LETTER TA
13D5 CHEROKEE LETTER DE
13D6 CHEROKEE LETTER TE
13D7 CHEROKEE LETTER DI
13D8 CHEROKEE LETTER TI
13D9 CHEROKEE LETTER DO
13DA CHEROKEE LETTER DU
13DB CHEROKEE LETTER DV
13DC CHEROKEE LETTER DLA
13DD CHEROKEE LETTER TLA
13DE CHEROKEE LETTER TLE
13DF CHEROKEE LETTER TLI
13E0 CHEROKEE LETTER TLO
13E1 CHEROKEE LETTER TLU
13E2 CHEROKEE LETTER TLV
13E3 CHEROKEE LETTER TSA
13E4 CHEROKEE LETTER TSE
13E5 CHEROKEE LETTER TSI
13E6 CHEROKEE LETTER TSO
13E7 CHEROKEE LETTER TSU
13E8 CHEROKEE LETTER TSV
13E9 CHEROKEE LETTER WA
13EA CHEROKEE LETTER WE
13EB CHEROKEE LETTER WI
13EC CHEROKEE LETTER WO
13ED CHEROKEE LETTER WU
13EE CHEROKEE LETTER WV
13EF CHEROKEE LETTER YA
13F0 CHEROKEE LETTER YE
13F1 CHEROKEE LETTER YI
13F2 CHEROKEE LETTER YO
13F3 CHEROKEE LETTER YU
13F4 CHEROKEE LETTER YV
1401 CANADIAN SYLLABICS E
1402 CANADIAN SYLLABICS AAI
1403 CANADIAN SYLLABICS I
1404 CANADIAN SYLLABICS II
1405 CANADIAN SYLLABICS O
1406 CANADIAN SYLLABICS OO
1407 CANADIAN SYLLABICS Y-CREE OO
1408 CANADIAN SYLLABICS CARRIER EE
1409 CANADIAN SYLLABICS CARRIER I
140A CANADIAN SYLLABICS A
140B CANADIAN SYLLABICS AA
140C CANADIAN SYLLABICS WE
140D CANADIAN SYLLABICS WEST-CREE WE
140E CANADIAN SYLLABICS WI
140F CANADIAN SYLLABICS WEST-CREE WI
1410 CANADIAN SYLLABICS WII
1411 CANADIAN SYLLABICS WEST-CREE WII
1412 CANADIAN SYLLABICS WO
1413 CANADIAN SYLLABICS WEST-CREE WO
1414 CANADIAN SYLLABICS WOO
1415 CANADIAN SYLLABICS WEST-CREE WOO
1416 CANADIAN SYLLABICS NASKAPI WOO
1417 CANADIAN SYLLABICS WA
1418 CANADIAN SYLLABICS WEST-CREE WA
1419 CANADIAN SYLLABICS WAA
141A CANADIAN SYLLABICS WEST-CREE WAA
141B CANADIAN SYLLABICS NASKAPI WAA
141C CANADIAN SYLLABICS AI
141D CANADIAN SYLLABICS Y-CREE W
141E CANADIAN SYLLABICS GLOTTAL STOP
141F CANADIAN SYLLABICS FINAL ACUTE
1420 CANADIAN SYLLABICS FINAL GRAVE
1421 CANADIAN SYLLABICS FINAL BOTTOM HALF RING
1422 CANADIAN SYLLABICS FINAL TOP HALF RING
1423 CANADIAN SYLLABICS FINAL RIGHT HALF RING
1424 CANADIAN SYLLABICS FINAL RING
1425 CANADIAN SYLLABICS FINAL DOUBLE ACUTE
1426 CANADIAN SYLLABICS FINAL DOUBLE SHORT VERTICAL STROKES
1427 CANADIAN SYLLABICS FINAL MIDDLE DOT
1428 CANADIAN SYLLABICS FINAL SHORT HORIZONTAL STROKE
1429 CANADIAN SYLLABICS FINAL PLUS
142A CANADIAN SYLLABICS FINAL DOWN TACK
142B CANADIAN SYLLABICS EN
142C CANADIAN SYLLABICS IN
142D CANADIAN SYLLABICS ON
142E CANADIAN SYLLABICS AN
142F CANADIAN SYLLABICS PE
1430 CANADIAN SYLLABICS PAAI
1431 CANADIAN SYLLABICS PI
1432 CANADIAN SYLLABICS PII
1433 CANADIAN SYLLABICS PO
1434 CANADIAN SYLLABICS POO
1435 CANADIAN SYLLABICS Y-CREE POO
1436 CANADIAN SYLLABICS CARRIER HEE
1437 CANADIAN SYLLABICS CARRIER HI
1438 CANADIAN SYLLABICS PA
1439 CANADIAN SYLLABICS PAA
143A CANADIAN SYLLABICS PWE
143B CANADIAN SYLLABICS WEST-CREE PWE
143C CANADIAN SYLLABICS PWI
143D CANADIAN SYLLABICS WEST-CREE PWI
143E CANADIAN SYLLABICS PWII
143F CANADIAN SYLLABICS WEST-CREE PWII
1440 CANADIAN SYLLABICS PWO
1441 CANADIAN SYLLABICS WEST-CREE PWO
1442 CANADIAN SYLLABICS PWOO
1443 CANADIAN SYLLABICS WEST-CREE PWOO
1444 CANADIAN SYLLABICS PWA
1445 CANADIAN SYLLABICS WEST-CREE PWA
1446 CANADIAN SYLLABICS PWAA
1447 CANADIAN SYLLABICS WEST-CREE PWAA
1448 CANADIAN SYLLABICS Y-CREE PWAA
1449 CANADIAN SYLLABICS P
144A CANADIAN SYLLABICS WEST-CREE P
144B CANADIAN SYLLABICS CARRIER H
144C CANADIAN SYLLABICS TE
144D CANADIAN SYLLABICS TAAI
144E CANADIAN SYLLABICS TI
144F CANADIAN SYLLABICS TII
1450 CANADIAN SYLLABICS TO
1451 CANADIAN SYLLABICS TOO
1452 CANADIAN SYLLABICS Y-CREE TOO
1453 CANADIAN SYLLABICS CARRIER DEE
1454 CANADIAN SYLLABICS CARRIER DI
1455 CANADIAN SYLLABICS TA
1456 CANADIAN SYLLABICS TAA
1457 CANADIAN SYLLABICS TWE
1458 CANADIAN SYLLABICS WEST-CREE TWE
1459 CANADIAN SYLLABICS TWI
145A CANADIAN SYLLABICS WEST-CREE TWI
145B CANADIAN SYLLABICS TWII
145C CANADIAN SYLLABICS WEST-CREE TWII
145D CANADIAN SYLLABICS TWO
145E CANADIAN SYLLABICS WEST-CREE TWO
145F CANADIAN SYLLABICS TWOO
1460 CANADIAN SYLLABICS WEST-CREE TWOO
1461 CANADIAN SYLLABICS TWA
1462 CANADIAN SYLLABICS WEST-CREE TWA
1463 CANADIAN SYLLABICS TWAA
1464 CANADIAN SYLLABICS WEST-CREE TWAA
1465 CANADIAN SYLLABICS NASKAPI TWAA
1466 CANADIAN SYLLABICS T
1467 CANADIAN SYLLABICS TTE
1468 CANADIAN SYLLABICS TTI
1469 CANADIAN SYLLABICS TTO
146A CANADIAN SYLLABICS TTA
146B CANADIAN SYLLABICS KE
146C CANADIAN SYLLABICS KAAI
146D CANADIAN SYLLABICS KI
146E CANADIAN SYLLABICS KII
146F CANADIAN SYLLABICS KO
1470 CANADIAN SYLLABICS KOO
1471 CANADIAN SYLLABICS Y-CREE KOO
1472 CANADIAN SYLLABICS KA
1473 CANADIAN SYLLABICS KAA
1474 CANADIAN SYLLABICS KWE
1475 CANADIAN SYLLABICS WEST-CREE KWE
1476 CANADIAN SYLLABICS KWI
1477 CANADIAN SYLLABICS WEST-CREE KWI
1478 CANADIAN SYLLABICS KWII
1479 CANADIAN SYLLABICS WEST-CREE KWII
147A CANADIAN SYLLABICS KWO
147B CANADIAN SYLLABICS WEST-CREE KWO
147C CANADIAN SYLLABICS KWOO
147D CANADIAN SYLLABICS WEST-CREE KWOO
147E CANADIAN SYLLABICS KWA
147F CANADIAN SYLLABICS WEST-CREE KWA
1480 CANADIAN SYLLABICS KWAA
1481 CANADIAN SYLLABICS WEST-CREE KWAA
1482 CANADIAN SYLLABICS NASKAPI KWAA
1483 CANADIAN SYLLABICS K
1484 CANADIAN SYLLABICS KW
1485 CANADIAN SYLLABICS SOUTH-SLAVEY KEH
1486 CANADIAN SYLLABICS SOUTH-SLAVEY KIH
1487 CANADIAN SYLLABICS SOUTH-SLAVEY KOH
1488 CANADIAN SYLLABICS SOUTH-SLAVEY KAH
1489 CANADIAN SYLLABICS CE
148A CANADIAN SYLLABICS CAAI
148B CANADIAN SYLLABICS CI
148C CANADIAN SYLLABICS CII
148D CANADIAN SYLLABICS CO
148E CANADIAN SYLLABICS COO
148F CANADIAN SYLLABICS Y-CREE COO
1490 CANADIAN SYLLABICS CA
1491 CANADIAN SYLLABICS CAA
1492 CANADIAN SYLLABICS CWE
1493 CANADIAN SYLLABICS WEST-CREE CWE
1494 CANADIAN SYLLABICS CWI
1495 CANADIAN SYLLABICS WEST-CREE CWI
1496 CANADIAN SYLLABICS CWII
1497 CANADIAN SYLLABICS WEST-CREE CWII
1498 CANADIAN SYLLABICS CWO
1499 CANADIAN SYLLABICS WEST-CREE CWO
149A CANADIAN SYLLABICS CWOO
149B CANADIAN SYLLABICS WEST-CREE CWOO
149C CANADIAN SYLLABICS CWA
149D CANADIAN SYLLABICS WEST-CREE CWA
149E CANADIAN SYLLABICS CWAA
149F CANADIAN SYLLABICS WEST-CREE CWAA
14A0 CANADIAN SYLLABICS NASKAPI CWAA
14A1 CANADIAN SYLLABICS C
14A2 CANADIAN SYLLABICS SAYISI TH
14A3 CANADIAN SYLLABICS ME
14A4 CANADIAN SYLLABICS MAAI
14A5 CANADIAN SYLLABICS MI
14A6 CANADIAN SYLLABICS MII
14A7 CANADIAN SYLLABICS MO
14A8 CANADIAN SYLLABICS MOO
14A9 CANADIAN SYLLABICS Y-CREE MOO
14AA CANADIAN SYLLABICS MA
14AB CANADIAN SYLLABICS MAA
14AC CANADIAN SYLLABICS MWE
14AD CANADIAN SYLLABICS WEST-CREE MWE
14AE CANADIAN SYLLABICS MWI
14AF CANADIAN SYLLABICS WEST-CREE MWI
14B0 CANADIAN SYLLABICS MWII
14B1 CANADIAN SYLLABICS WEST-CREE MWII
14B2 CANADIAN SYLLABICS MWO
14B3 CANADIAN SYLLABICS WEST-CREE MWO
14B4 CANADIAN SYLLABICS MWOO
14B5 CANADIAN SYLLABICS WEST-CREE MWOO
14B6 CANADIAN SYLLABICS MWA
14B7 CANADIAN SYLLABICS WEST-CREE MWA
14B8 CANADIAN SYLLABICS MWAA
14B9 CANADIAN SYLLABICS WEST-CREE MWAA
14BA CANADIAN SYLLABICS NASKAPI MWAA
14BB CANADIAN SYLLABICS M
14BC CANADIAN SYLLABICS WEST-CREE M
14BD CANADIAN SYLLABICS MH
14BE CANADIAN SYLLABICS ATHAPASCAN M
14BF CANADIAN SYLLABICS SAYISI M
14C0 CANADIAN SYLLABICS NE
14C1 CANADIAN SYLLABICS NAAI
14C2 CANADIAN SYLLABICS NI
14C3 CANADIAN SYLLABICS NII
14C4 CANADIAN SYLLABICS NO
14C5 CANADIAN SYLLABICS NOO
14C6 CANADIAN SYLLABICS Y-CREE NOO
14C7 CANADIAN SYLLABICS NA
14C8 CANADIAN SYLLABICS NAA
14C9 CANADIAN SYLLABICS NWE
14CA CANADIAN SYLLABICS WEST-CREE NWE
14CB CANADIAN SYLLABICS NWA
14CC CANADIAN SYLLABICS WEST-CREE NWA
14CD CANADIAN SYLLABICS NWAA
14CE CANADIAN SYLLABICS WEST-CREE NWAA
14CF CANADIAN SYLLABICS NASKAPI NWAA
14D0 CANADIAN SYLLABICS N
14D1 CANADIAN SYLLABICS CARRIER NG
14D2 CANADIAN SYLLABICS NH
14D3 CANADIAN SYLLABICS LE
14D4 CANADIAN SYLLABICS LAAI
14D5 CANADIAN SYLLABICS LI
14D6 CANADIAN SYLLABICS LII
14D7 CANADIAN SYLLABICS LO
14D8 CANADIAN SYLLABICS LOO
14D9 CANADIAN SYLLABICS Y-CREE LOO
14DA CANADIAN SYLLABICS LA
14DB CANADIAN SYLLABICS LAA
14DC CANADIAN SYLLABICS LWE
14DD CANADIAN SYLLABICS WEST-CREE LWE
14DE CANADIAN SYLLABICS LWI
14DF CANADIAN SYLLABICS WEST-CREE LWI
14E0 CANADIAN SYLLABICS LWII
14E1 CANADIAN SYLLABICS WEST-CREE LWII
14E2 CANADIAN SYLLABICS LWO
14E3 CANADIAN SYLLABICS WEST-CREE LWO
14E4 CANADIAN SYLLABICS LWOO
14E5 CANADIAN SYLLABICS WEST-CREE LWOO
14E6 CANADIAN SYLLABICS LWA
14E7 CANADIAN SYLLABICS WEST-CREE LWA
14E8 CANADIAN SYLLABICS LWAA
14E9 CANADIAN SYLLABICS WEST-CREE LWAA
14EA CANADIAN SYLLABICS L
14EB CANADIAN SYLLABICS WEST-CREE L
14EC CANADIAN SYLLABICS MEDIAL L
14ED CANADIAN SYLLABICS SE
14EE CANADIAN SYLLABICS SAAI
14EF CANADIAN SYLLABICS SI
14F0 CANADIAN SYLLABICS SII
14F1 CANADIAN SYLLABICS SO
14F2 CANADIAN SYLLABICS SOO
14F3 CANADIAN SYLLABICS Y-CREE SOO
14F4 CANADIAN SYLLABICS SA
14F5 CANADIAN SYLLABICS SAA
14F6 CANADIAN SYLLABICS SWE
14F7 CANADIAN SYLLABICS WEST-CREE SWE
14F8 CANADIAN SYLLABICS SWI
14F9 CANADIAN SYLLABICS WEST-CREE SWI
14FA CANADIAN SYLLABICS SWII
14FB CANADIAN SYLLABICS WEST-CREE SWII
14FC CANADIAN SYLLABICS SWO
14FD CANADIAN SYLLABICS WEST-CREE SWO
14FE CANADIAN SYLLABICS SWOO
14FF CANADIAN SYLLABICS WEST-CREE SWOO
1500 CANADIAN SYLLABICS SWA
1501 CANADIAN SYLLABICS WEST-CREE SWA
1502 CANADIAN SYLLABICS SWAA
1503 CANADIAN SYLLABICS WEST-CREE SWAA
1504 CANADIAN SYLLABICS NASKAPI SWAA
1505 CANADIAN SYLLABICS S
1506 CANADIAN SYLLABICS ATHAPASCAN S
1507 CANADIAN SYLLABICS SW
1508 CANADIAN SYLLABICS BLACKFOOT S
1509 CANADIAN SYLLABICS MOOSE-CREE SK
150A CANADIAN SYLLABICS NASKAPI SKW
150B CANADIAN SYLLABICS NASKAPI S-W
150C CANADIAN SYLLABICS NASKAPI SPWA
150D CANADIAN SYLLABICS NASKAPI STWA
150E CANADIAN SYLLABICS NASKAPI SKWA
150F CANADIAN SYLLABICS NASKAPI SCWA
1510 CANADIAN SYLLABICS SHE
1511 CANADIAN SYLLABICS SHI
1512 CANADIAN SYLLABICS SHII
1513 CANADIAN SYLLABICS SHO
1514 CANADIAN SYLLABICS SHOO
1515 CANADIAN SYLLABICS SHA
1516 CANADIAN SYLLABICS SHAA
1517 CANADIAN SYLLABICS SHWE
1518 CANADIAN SYLLABICS WEST-CREE SHWE
1519 CANADIAN SYLLABICS SHWI
151A CANADIAN SYLLABICS WEST-CREE SHWI
151B CANADIAN SYLLABICS SHWII
151C CANADIAN SYLLABICS WEST-CREE SHWII
151D CANADIAN SYLLABICS SHWO
151E CANADIAN SYLLABICS WEST-CREE SHWO
151F CANADIAN SYLLABICS SHWOO
1520 CANADIAN SYLLABICS WEST-CREE SHWOO
1521 CANADIAN SYLLABICS SHWA
1522 CANADIAN SYLLABICS WEST-CREE SHWA
1523 CANADIAN SYLLABICS SHWAA
1524 CANADIAN SYLLABICS WEST-CREE SHWAA
1525 CANADIAN SYLLABICS SH
1526 CANADIAN SYLLABICS YE
1527 CANADIAN SYLLABICS YAAI
1528 CANADIAN SYLLABICS YI
1529 CANADIAN SYLLABICS YII
152A CANADIAN SYLLABICS YO
152B CANADIAN SYLLABICS YOO
152C CANADIAN SYLLABICS Y-CREE YOO
152D CANADIAN SYLLABICS YA
152E CANADIAN SYLLABICS YAA
152F CANADIAN SYLLABICS YWE
1530 CANADIAN SYLLABICS WEST-CREE YWE
1531 CANADIAN SYLLABICS YWI
1532 CANADIAN SYLLABICS WEST-CREE YWI
1533 CANADIAN SYLLABICS YWII
1534 CANADIAN SYLLABICS WEST-CREE YWII
1535 CANADIAN SYLLABICS YWO
1536 CANADIAN SYLLABICS WEST-CREE YWO
1537 CANADIAN SYLLABICS YWOO
1538 CANADIAN SYLLABICS WEST-CREE YWOO
1539 CANADIAN SYLLABICS YWA
153A CANADIAN SYLLABICS WEST-CREE YWA
153B CANADIAN SYLLABICS YWAA
153C CANADIAN SYLLABICS WEST-CREE YWAA
153D CANADIAN SYLLABICS NASKAPI YWAA
153E CANADIAN SYLLABICS Y
153F CANADIAN SYLLABICS BIBLE-CREE Y
1540 CANADIAN SYLLABICS WEST-CREE Y
1541 CANADIAN SYLLABICS SAYISI YI
1542 CANADIAN SYLLABICS RE
1543 CANADIAN SYLLABICS R-CREE RE
1544 CANADIAN SYLLABICS WEST-CREE LE
1545 CANADIAN SYLLABICS RAAI
1546 CANADIAN SYLLABICS RI
1547 CANADIAN SYLLABICS RII
1548 CANADIAN SYLLABICS RO
1549 CANADIAN SYLLABICS ROO
154A CANADIAN SYLLABICS WEST-CREE LO
154B CANADIAN SYLLABICS RA
154C CANADIAN SYLLABICS RAA
154D CANADIAN SYLLABICS WEST-CREE LA
154E CANADIAN SYLLABICS RWAA
154F CANADIAN SYLLABICS WEST-CREE RWAA
1550 CANADIAN SYLLABICS R
1551 CANADIAN SYLLABICS WEST-CREE R
1552 CANADIAN SYLLABICS MEDIAL R
1553 CANADIAN SYLLABICS FE
1554 CANADIAN SYLLABICS FAAI
1555 CANADIAN SYLLABICS FI
1556 CANADIAN SYLLABICS FII
1557 CANADIAN SYLLABICS FO
1558 CANADIAN SYLLABICS FOO
1559 CANADIAN SYLLABICS FA
155A CANADIAN SYLLABICS FAA
155B CANADIAN SYLLABICS FWAA
155C CANADIAN SYLLABICS WEST-CREE FWAA
155D CANADIAN SYLLABICS F
155E CANADIAN SYLLABICS THE
155F CANADIAN SYLLABICS N-CREE THE
1560 CANADIAN SYLLABICS THI
1561 CANADIAN SYLLABICS N-CREE THI
1562 CANADIAN SYLLABICS THII
1563 CANADIAN SYLLABICS N-CREE THII
1564 CANADIAN SYLLABICS THO
1565 CANADIAN SYLLABICS THOO
1566 CANADIAN SYLLABICS THA
1567 CANADIAN SYLLABICS THAA
1568 CANADIAN SYLLABICS THWAA
1569 CANADIAN SYLLABICS WEST-CREE THWAA
156A CANADIAN SYLLABICS TH
156B CANADIAN SYLLABICS TTHE
156C CANADIAN SYLLABICS TTHI
156D CANADIAN SYLLABICS TTHO
156E CANADIAN SYLLABICS TTHA
156F CANADIAN SYLLABICS TTH
1570 CANADIAN SYLLABICS TYE
1571 CANADIAN SYLLABICS TYI
1572 CANADIAN SYLLABICS TYO
1573 CANADIAN SYLLABICS TYA
1574 CANADIAN SYLLABICS NUNAVIK HE
1575 CANADIAN SYLLABICS NUNAVIK HI
1576 CANADIAN SYLLABICS NUNAVIK HII
1577 CANADIAN SYLLABICS NUNAVIK HO
1578 CANADIAN SYLLABICS NUNAVIK HOO
1579 CANADIAN SYLLABICS NUNAVIK HA
157A CANADIAN SYLLABICS NUNAVIK HAA
157B CANADIAN SYLLABICS NUNAVIK H
157C CANADIAN SYLLABICS NUNAVUT H
157D CANADIAN SYLLABICS HK
157E CANADIAN SYLLABICS QAAI
157F CANADIAN SYLLABICS QI
1580 CANADIAN SYLLABICS QII
1581 CANADIAN SYLLABICS QO
1582 CANADIAN SYLLABICS QOO
1583 CANADIAN SYLLABICS QA
1584 CANADIAN SYLLABICS QAA
1585 CANADIAN SYLLABICS Q
1586 CANADIAN SYLLABICS TLHE
1587 CANADIAN SYLLABICS TLHI
1588 CANADIAN SYLLABICS TLHO
1589 CANADIAN SYLLABICS TLHA
158A CANADIAN SYLLABICS WEST-CREE RE
158B CANADIAN SYLLABICS WEST-CREE RI
158C CANADIAN SYLLABICS WEST-CREE RO
158D CANADIAN SYLLABICS WEST-CREE RA
158E CANADIAN SYLLABICS NGAAI
158F CANADIAN SYLLABICS NGI
1590 CANADIAN SYLLABICS NGII
1591 CANADIAN SYLLABICS NGO
1592 CANADIAN SYLLABICS NGOO
1593 CANADIAN SYLLABICS NGA
1594 CANADIAN SYLLABICS NGAA
1595 CANADIAN SYLLABICS NG
1596 CANADIAN SYLLABICS NNG
1597 CANADIAN SYLLABICS SAYISI SHE
1598 CANADIAN SYLLABICS SAYISI SHI
1599 CANADIAN SYLLABICS SAYISI SHO
159A CANADIAN SYLLABICS SAYISI SHA
159B CANADIAN SYLLABICS WOODS-CREE THE
159C CANADIAN SYLLABICS WOODS-CREE THI
159D CANADIAN SYLLABICS WOODS-CREE THO
159E CANADIAN SYLLABICS WOODS-CREE THA
159F CANADIAN SYLLABICS WOODS-CREE TH
15A0 CANADIAN SYLLABICS LHI
15A1 CANADIAN SYLLABICS LHII
15A2 CANADIAN SYLLABICS LHO
15A3 CANADIAN SYLLABICS LHOO
15A4 CANADIAN SYLLABICS LHA
15A5 CANADIAN SYLLABICS LHAA
15A6 CANADIAN SYLLABICS LH
15A7 CANADIAN SYLLABICS TH-CREE THE
15A8 CANADIAN SYLLABICS TH-CREE THI
15A9 CANADIAN SYLLABICS TH-CREE THII
15AA CANADIAN SYLLABICS TH-CREE THO
15AB CANADIAN SYLLABICS TH-CREE THOO
15AC CANADIAN SYLLABICS TH-CREE THA
15AD CANADIAN SYLLABICS TH-CREE THAA
15AE CANADIAN SYLLABICS TH-CREE TH
15AF CANADIAN SYLLABICS AIVILIK B
15B0 CANADIAN SYLLABICS BLACKFOOT E
15B1 CANADIAN SYLLABICS BLACKFOOT I
15B2 CANADIAN SYLLABICS BLACKFOOT O
15B3 CANADIAN SYLLABICS BLACKFOOT A
15B4 CANADIAN SYLLABICS BLACKFOOT WE
15B5 CANADIAN SYLLABICS BLACKFOOT WI
15B6 CANADIAN SYLLABICS BLACKFOOT WO
15B7 CANADIAN SYLLABICS BLACKFOOT WA
15B8 CANADIAN SYLLABICS BLACKFOOT NE
15B9 CANADIAN SYLLABICS BLACKFOOT NI
15BA CANADIAN SYLLABICS BLACKFOOT NO
15BB CANADIAN SYLLABICS BLACKFOOT NA
15BC CANADIAN SYLLABICS BLACKFOOT KE
15BD CANADIAN SYLLABICS BLACKFOOT KI
15BE CANADIAN SYLLABICS BLACKFOOT KO
15BF CANADIAN SYLLABICS BLACKFOOT KA
15C0 CANADIAN SYLLABICS SAYISI HE
15C1 CANADIAN SYLLABICS SAYISI HI
15C2 CANADIAN SYLLABICS SAYISI HO
15C3 CANADIAN SYLLABICS SAYISI HA
15C4 CANADIAN SYLLABICS CARRIER GHU
15C5 CANADIAN SYLLABICS CARRIER GHO
15C6 CANADIAN SYLLABICS CARRIER GHE
15C7 CANADIAN SYLLABICS CARRIER GHEE
15C8 CANADIAN SYLLABICS CARRIER GHI
15C9 CANADIAN SYLLABICS CARRIER GHA
15CA CANADIAN SYLLABICS CARRIER RU
15CB CANADIAN SYLLABICS CARRIER RO
15CC CANADIAN SYLLABICS CARRIER RE
15CD CANADIAN SYLLABICS CARRIER REE
15CE CANADIAN SYLLABICS CARRIER RI
15CF CANADIAN SYLLABICS CARRIER RA
15D0 CANADIAN SYLLABICS CARRIER WU
15D1 CANADIAN SYLLABICS CARRIER WO
15D2 CANADIAN SYLLABICS CARRIER WE
15D3 CANADIAN SYLLABICS CARRIER WEE
15D4 CANADIAN SYLLABICS CARRIER WI
15D5 CANADIAN SYLLABICS CARRIER WA
15D6 CANADIAN SYLLABICS CARRIER HWU
15D7 CANADIAN SYLLABICS CARRIER HWO
15D8 CANADIAN SYLLABICS CARRIER HWE
15D9 CANADIAN SYLLABICS CARRIER HWEE
15DA CANADIAN SYLLABICS CARRIER HWI
15DB CANADIAN SYLLABICS CARRIER HWA
15DC CANADIAN SYLLABICS CARRIER THU
15DD CANADIAN SYLLABICS CARRIER THO
15DE CANADIAN SYLLABICS CARRIER THE
15DF CANADIAN SYLLABICS CARRIER THEE
15E0 CANADIAN SYLLABICS CARRIER THI
15E1 CANADIAN SYLLABICS CARRIER THA
15E2 CANADIAN SYLLABICS CARRIER TTU
15E3 CANADIAN SYLLABICS CARRIER TTO
15E4 CANADIAN SYLLABICS CARRIER TTE
15E5 CANADIAN SYLLABICS CARRIER TTEE
15E6 CANADIAN SYLLABICS CARRIER TTI
15E7 CANADIAN SYLLABICS CARRIER TTA
15E8 CANADIAN SYLLABICS CARRIER PU
15E9 CANADIAN SYLLABICS CARRIER PO
15EA CANADIAN SYLLABICS CARRIER PE
15EB CANADIAN SYLLABICS CARRIER PEE
15EC CANADIAN SYLLABICS CARRIER PI
15ED CANADIAN SYLLABICS CARRIER PA
15EE CANADIAN SYLLABICS CARRIER P
15EF CANADIAN SYLLABICS CARRIER GU
15F0 CANADIAN SYLLABICS CARRIER GO
15F1 CANADIAN SYLLABICS CARRIER GE
15F2 CANADIAN SYLLABICS CARRIER GEE
15F3 CANADIAN SYLLABICS CARRIER GI
15F4 CANADIAN SYLLABICS CARRIER GA
15F5 CANADIAN SYLLABICS CARRIER KHU
15F6 CANADIAN SYLLABICS CARRIER KHO
15F7 CANADIAN SYLLABICS CARRIER KHE
15F8 CANADIAN SYLLABICS CARRIER KHEE
15F9 CANADIAN SYLLABICS CARRIER KHI
15FA CANADIAN SYLLABICS CARRIER KHA
15FB CANADIAN SYLLABICS CARRIER KKU
15FC CANADIAN SYLLABICS CARRIER KKO
15FD CANADIAN SYLLABICS CARRIER KKE
15FE CANADIAN SYLLABICS CARRIER KKEE
15FF CANADIAN SYLLABICS CARRIER KKI
1600 CANADIAN SYLLABICS CARRIER KKA
1601 CANADIAN SYLLABICS CARRIER KK
1602 CANADIAN SYLLABICS CARRIER NU
1603 CANADIAN SYLLABICS CARRIER NO
1604 CANADIAN SYLLABICS CARRIER NE
1605 CANADIAN SYLLABICS CARRIER NEE
1606 CANADIAN SYLLABICS CARRIER NI
1607 CANADIAN SYLLABICS CARRIER NA
1608 CANADIAN SYLLABICS CARRIER MU
1609 CANADIAN SYLLABICS CARRIER MO
160A CANADIAN SYLLABICS CARRIER ME
160B CANADIAN SYLLABICS CARRIER MEE
160C CANADIAN SYLLABICS CARRIER MI
160D CANADIAN SYLLABICS CARRIER MA
160E CANADIAN SYLLABICS CARRIER YU
160F CANADIAN SYLLABICS CARRIER YO
1610 CANADIAN SYLLABICS CARRIER YE
1611 CANADIAN SYLLABICS CARRIER YEE
1612 CANADIAN SYLLABICS CARRIER YI
1613 CANADIAN SYLLABICS CARRIER YA
1614 CANADIAN SYLLABICS CARRIER JU
1615 CANADIAN SYLLABICS SAYISI JU
1616 CANADIAN SYLLABICS CARRIER JO
1617 CANADIAN SYLLABICS CARRIER JE
1618 CANADIAN SYLLABICS CARRIER JEE
1619 CANADIAN SYLLABICS CARRIER JI
161A CANADIAN SYLLABICS SAYISI JI
161B CANADIAN SYLLABICS CARRIER JA
161C CANADIAN SYLLABICS CARRIER JJU
161D CANADIAN SYLLABICS CARRIER JJO
161E CANADIAN SYLLABICS CARRIER JJE
161F CANADIAN SYLLABICS CARRIER JJEE
1620 CANADIAN SYLLABICS CARRIER JJI
1621 CANADIAN SYLLABICS CARRIER JJA
1622 CANADIAN SYLLABICS CARRIER LU
1623 CANADIAN SYLLABICS CARRIER LO
1624 CANADIAN SYLLABICS CARRIER LE
1625 CANADIAN SYLLABICS CARRIER LEE
1626 CANADIAN SYLLABICS CARRIER LI
1627 CANADIAN SYLLABICS CARRIER LA
1628 CANADIAN SYLLABICS CARRIER DLU
1629 CANADIAN SYLLABICS CARRIER DLO
162A CANADIAN SYLLABICS CARRIER DLE
162B CANADIAN SYLLABICS CARRIER DLEE
162C CANADIAN SYLLABICS CARRIER DLI
162D CANADIAN SYLLABICS CARRIER DLA
162E CANADIAN SYLLABICS CARRIER LHU
162F CANADIAN SYLLABICS CARRIER LHO
1630 CANADIAN SYLLABICS CARRIER LHE
1631 CANADIAN SYLLABICS CARRIER LHEE
1632 CANADIAN SYLLABICS CARRIER LHI
1633 CANADIAN SYLLABICS CARRIER LHA
1634 CANADIAN SYLLABICS CARRIER TLHU
1635 CANADIAN SYLLABICS CARRIER TLHO
1636 CANADIAN SYLLABICS CARRIER TLHE
1637 CANADIAN SYLLABICS CARRIER TLHEE
1638 CANADIAN SYLLABICS CARRIER TLHI
1639 CANADIAN SYLLABICS CARRIER TLHA
163A CANADIAN SYLLABICS CARRIER TLU
163B CANADIAN SYLLABICS CARRIER TLO
163C CANADIAN SYLLABICS CARRIER TLE
163D CANADIAN SYLLABICS CARRIER TLEE
163E CANADIAN SYLLABICS CARRIER TLI
163F CANADIAN SYLLABICS CARRIER TLA
1640 CANADIAN SYLLABICS CARRIER ZU
1641 CANADIAN SYLLABICS CARRIER ZO
1642 CANADIAN SYLLABICS CARRIER ZE
1643 CANADIAN SYLLABICS CARRIER ZEE
1644 CANADIAN SYLLABICS CARRIER ZI
1645 CANADIAN SYLLABICS CARRIER ZA
1646 CANADIAN SYLLABICS CARRIER Z
1647 CANADIAN SYLLABICS CARRIER INITIAL Z
1648 CANADIAN SYLLABICS CARRIER DZU
1649 CANADIAN SYLLABICS CARRIER DZO
164A CANADIAN SYLLABICS CARRIER DZE
164B CANADIAN SYLLABICS CARRIER DZEE
164C CANADIAN SYLLABICS CARRIER DZI
164D CANADIAN SYLLABICS CARRIER DZA
164E CANADIAN SYLLABICS CARRIER SU
164F CANADIAN SYLLABICS CARRIER SO
1650 CANADIAN SYLLABICS CARRIER SE
1651 CANADIAN SYLLABICS CARRIER SEE
1652 CANADIAN SYLLABICS CARRIER SI
1653 CANADIAN SYLLABICS CARRIER SA
1654 CANADIAN SYLLABICS CARRIER SHU
1655 CANADIAN SYLLABICS CARRIER SHO
1656 CANADIAN SYLLABICS CARRIER SHE
1657 CANADIAN SYLLABICS CARRIER SHEE
1658 CANADIAN SYLLABICS CARRIER SHI
1659 CANADIAN SYLLABICS CARRIER SHA
165A CANADIAN SYLLABICS CARRIER SH
165B CANADIAN SYLLABICS CARRIER TSU
165C CANADIAN SYLLABICS CARRIER TSO
165D CANADIAN SYLLABICS CARRIER TSE
165E CANADIAN SYLLABICS CARRIER TSEE
165F CANADIAN SYLLABICS CARRIER TSI
1660 CANADIAN SYLLABICS CARRIER TSA
1661 CANADIAN SYLLABICS CARRIER CHU
1662 CANADIAN SYLLABICS CARRIER CHO
1663 CANADIAN SYLLABICS CARRIER CHE
1664 CANADIAN SYLLABICS CARRIER CHEE
1665 CANADIAN SYLLABICS CARRIER CHI
1666 CANADIAN SYLLABICS CARRIER CHA
1667 CANADIAN SYLLABICS CARRIER TTSU
1668 CANADIAN SYLLABICS CARRIER TTSO
1669 CANADIAN SYLLABICS CARRIER TTSE
166A CANADIAN SYLLABICS CARRIER TTSEE
166B CANADIAN SYLLABICS CARRIER TTSI
166C CANADIAN SYLLABICS CARRIER TTSA
166D CANADIAN SYLLABICS CHI SIGN
166E CANADIAN SYLLABICS FULL STOP
166F CANADIAN SYLLABICS QAI
1670 CANADIAN SYLLABICS NGAI
1671 CANADIAN SYLLABICS NNGI
1672 CANADIAN SYLLABICS NNGII
1673 CANADIAN SYLLABICS NNGO
1674 CANADIAN SYLLABICS NNGOO
1675 CANADIAN SYLLABICS NNGA
1676 CANADIAN SYLLABICS NNGAA
1680 OGHAM SPACE MARK
1681 OGHAM LETTER BEITH
1682 OGHAM LETTER LUIS
1683 OGHAM LETTER FEARN
1684 OGHAM LETTER SAIL
1685 OGHAM LETTER NION
1686 OGHAM LETTER UATH
1687 OGHAM LETTER DAIR
1688 OGHAM LETTER TINNE
1689 OGHAM LETTER COLL
168A OGHAM LETTER CEIRT
168B OGHAM LETTER MUIN
168C OGHAM LETTER GORT
168D OGHAM LETTER NGEADAL
168E OGHAM LETTER STRAIF
168F OGHAM LETTER RUIS
1690 OGHAM LETTER AILM
1691 OGHAM LETTER ONN
1692 OGHAM LETTER UR
1693 OGHAM LETTER EADHADH
1694 OGHAM LETTER IODHADH
1695 OGHAM LETTER EABHADH
1696 OGHAM LETTER OR
1697 OGHAM LETTER UILLEANN
1698 OGHAM LETTER IFIN
1699 OGHAM LETTER EAMHANCHOLL
169A OGHAM LETTER PEITH
169B OGHAM FEATHER MARK
169C OGHAM REVERSED FEATHER MARK
16A0 RUNIC LETTER FEHU FEOH FE F
16A1 RUNIC LETTER V
16A2 RUNIC LETTER URUZ UR U
16A3 RUNIC LETTER YR
16A4 RUNIC LETTER Y
16A5 RUNIC LETTER W
16A6 RUNIC LETTER THURISAZ THURS THORN
16A7 RUNIC LETTER ETH
16A8 RUNIC LETTER ANSUZ A
16A9 RUNIC LETTER OS O
16AA RUNIC LETTER AC A
16AB RUNIC LETTER AESC
16AC RUNIC LETTER LONG-BRANCH-OSS O
16AD RUNIC LETTER SHORT-TWIG-OSS O
16AE RUNIC LETTER O
16AF RUNIC LETTER OE
16B0 RUNIC LETTER ON
16B1 RUNIC LETTER RAIDO RAD REID R
16B2 RUNIC LETTER KAUNA
16B3 RUNIC LETTER CEN
16B4 RUNIC LETTER KAUN K
16B5 RUNIC LETTER G
16B6 RUNIC LETTER ENG
16B7 RUNIC LETTER GEBO GYFU G
16B8 RUNIC LETTER GAR
16B9 RUNIC LETTER WUNJO WYNN W
16BA RUNIC LETTER HAGLAZ H
16BB RUNIC LETTER HAEGL H
16BC RUNIC LETTER LONG-BRANCH-HAGALL H
16BD RUNIC LETTER SHORT-TWIG-HAGALL H
16BE RUNIC LETTER NAUDIZ NYD NAUD N
16BF RUNIC LETTER SHORT-TWIG-NAUD N
16C0 RUNIC LETTER DOTTED-N
16C1 RUNIC LETTER ISAZ IS ISS I
16C2 RUNIC LETTER E
16C3 RUNIC LETTER JERAN J
16C4 RUNIC LETTER GER
16C5 RUNIC LETTER LONG-BRANCH-AR AE
16C6 RUNIC LETTER SHORT-TWIG-AR A
16C7 RUNIC LETTER IWAZ EOH
16C8 RUNIC LETTER PERTHO PEORTH P
16C9 RUNIC LETTER ALGIZ EOLHX
16CA RUNIC LETTER SOWILO S
16CB RUNIC LETTER SIGEL LONG-BRANCH-SOL S
16CC RUNIC LETTER SHORT-TWIG-SOL S
16CD RUNIC LETTER C
16CE RUNIC LETTER Z
16CF RUNIC LETTER TIWAZ TIR TYR T
16D0 RUNIC LETTER SHORT-TWIG-TYR T
16D1 RUNIC LETTER D
16D2 RUNIC LETTER BERKANAN BEORC BJARKAN B
16D3 RUNIC LETTER SHORT-TWIG-BJARKAN B
16D4 RUNIC LETTER DOTTED-P
16D5 RUNIC LETTER OPEN-P
16D6 RUNIC LETTER EHWAZ EH E
16D7 RUNIC LETTER MANNAZ MAN M
16D8 RUNIC LETTER LONG-BRANCH-MADR M
16D9 RUNIC LETTER SHORT-TWIG-MADR M
16DA RUNIC LETTER LAUKAZ LAGU LOGR L
16DB RUNIC LETTER DOTTED-L
16DC RUNIC LETTER INGWAZ
16DD RUNIC LETTER ING
16DE RUNIC LETTER DAGAZ DAEG D
16DF RUNIC LETTER OTHALAN ETHEL O
16E0 RUNIC LETTER EAR
16E1 RUNIC LETTER IOR
16E2 RUNIC LETTER CWEORTH
16E3 RUNIC LETTER CALC
16E4 RUNIC LETTER CEALC
16E5 RUNIC LETTER STAN
16E6 RUNIC LETTER LONG-BRANCH-YR
16E7 RUNIC LETTER SHORT-TWIG-YR
16E8 RUNIC LETTER ICELANDIC-YR
16E9 RUNIC LETTER Q
16EA RUNIC LETTER X
16EB RUNIC SINGLE PUNCTUATION
16EC RUNIC MULTIPLE PUNCTUATION
16ED RUNIC CROSS PUNCTUATION
16EE RUNIC ARLAUG SYMBOL
16EF RUNIC TVIMADUR SYMBOL
16F0 RUNIC BELGTHOR SYMBOL
1700 TAGALOG LETTER A
1701 TAGALOG LETTER I
1702 TAGALOG LETTER U
1703 TAGALOG LETTER KA
1704 TAGALOG LETTER GA
1705 TAGALOG LETTER NGA
1706 TAGALOG LETTER TA
1707 TAGALOG LETTER DA
1708 TAGALOG LETTER NA
1709 TAGALOG LETTER PA
170A TAGALOG LETTER BA
170B TAGALOG LETTER MA
170C TAGALOG LETTER YA
170E TAGALOG LETTER LA
170F TAGALOG LETTER WA
1710 TAGALOG LETTER SA
1711 TAGALOG LETTER HA
1712 TAGALOG VOWEL SIGN I
1713 TAGALOG VOWEL SIGN U
1714 TAGALOG SIGN VIRAMA
1720 HANUNOO LETTER A
1721 HANUNOO LETTER I
1722 HANUNOO LETTER U
1723 HANUNOO LETTER KA
1724 HANUNOO LETTER GA
1725 HANUNOO LETTER NGA
1726 HANUNOO LETTER TA
1727 HANUNOO LETTER DA
1728 HANUNOO LETTER NA
1729 HANUNOO LETTER PA
172A HANUNOO LETTER BA
172B HANUNOO LETTER MA
172C HANUNOO LETTER YA
172D HANUNOO LETTER RA
172E HANUNOO LETTER LA
172F HANUNOO LETTER WA
1730 HANUNOO LETTER SA
1731 HANUNOO LETTER HA
1732 HANUNOO VOWEL SIGN I
1733 HANUNOO VOWEL SIGN U
1734 HANUNOO SIGN PAMUDPOD
1735 PHILIPPINE SINGLE PUNCTUATION
1736 PHILIPPINE DOUBLE PUNCTUATION
1740 BUHID LETTER A
1741 BUHID LETTER I
1742 BUHID LETTER U
1743 BUHID LETTER KA
1744 BUHID LETTER GA
1745 BUHID LETTER NGA
1746 BUHID LETTER TA
1747 BUHID LETTER DA
1748 BUHID LETTER NA
1749 BUHID LETTER PA
174A BUHID LETTER BA
174B BUHID LETTER MA
174C BUHID LETTER YA
174D BUHID LETTER RA
174E BUHID LETTER LA
174F BUHID LETTER WA
1750 BUHID LETTER SA
1751 BUHID LETTER HA
1752 BUHID VOWEL SIGN I
1753 BUHID VOWEL SIGN U
1760 TAGBANWA LETTER A
1761 TAGBANWA LETTER I
1762 TAGBANWA LETTER U
1763 TAGBANWA LETTER KA
1764 TAGBANWA LETTER GA
1765 TAGBANWA LETTER NGA
1766 TAGBANWA LETTER TA
1767 TAGBANWA LETTER DA
1768 TAGBANWA LETTER NA
1769 TAGBANWA LETTER PA
176A TAGBANWA LETTER BA
176B TAGBANWA LETTER MA
176C TAGBANWA LETTER YA
176E TAGBANWA LETTER LA
176F TAGBANWA LETTER WA
1770 TAGBANWA LETTER SA
1772 TAGBANWA VOWEL SIGN I
1773 TAGBANWA VOWEL SIGN U
1780 KHMER LETTER KA
1781 KHMER LETTER KHA
1782 KHMER LETTER KO
1783 KHMER LETTER KHO
1784 KHMER LETTER NGO
1785 KHMER LETTER CA
1786 KHMER LETTER CHA
1787 KHMER LETTER CO
1788 KHMER LETTER CHO
1789 KHMER LETTER NYO
178A KHMER LETTER DA
178B KHMER LETTER TTHA
178C KHMER LETTER DO
178D KHMER LETTER TTHO
178E KHMER LETTER NNO
178F KHMER LETTER TA
1790 KHMER LETTER THA
1791 KHMER LETTER TO
1792 KHMER LETTER THO
1793 KHMER LETTER NO
1794 KHMER LETTER BA
1795 KHMER LETTER PHA
1796 KHMER LETTER PO
1797 KHMER LETTER PHO
1798 KHMER LETTER MO
1799 KHMER LETTER YO
179A KHMER LETTER RO
179B KHMER LETTER LO
179C KHMER LETTER VO
179D KHMER LETTER SHA
179E KHMER LETTER SSO
179F KHMER LETTER SA
17A0 KHMER LETTER HA
17A1 KHMER LETTER LA
17A2 KHMER LETTER QA
17A3 KHMER INDEPENDENT VOWEL QAQ
17A4 KHMER INDEPENDENT VOWEL QAA
17A5 KHMER INDEPENDENT VOWEL QI
17A6 KHMER INDEPENDENT VOWEL QII
17A7 KHMER INDEPENDENT VOWEL QU
17A8 KHMER INDEPENDENT VOWEL QUK
17A9 KHMER INDEPENDENT VOWEL QUU
17AA KHMER INDEPENDENT VOWEL QUUV
17AB KHMER INDEPENDENT VOWEL RY
17AC KHMER INDEPENDENT VOWEL RYY
17AD KHMER INDEPENDENT VOWEL LY
17AE KHMER INDEPENDENT VOWEL LYY
17AF KHMER INDEPENDENT VOWEL QE
17B0 KHMER INDEPENDENT VOWEL QAI
17B1 KHMER INDEPENDENT VOWEL QOO TYPE ONE
17B2 KHMER INDEPENDENT VOWEL QOO TYPE TWO
17B3 KHMER INDEPENDENT VOWEL QAU
17B4 KHMER VOWEL INHERENT AQ
17B5 KHMER VOWEL INHERENT AA
17B6 KHMER VOWEL SIGN AA
17B7 KHMER VOWEL SIGN I
17B8 KHMER VOWEL SIGN II
17B9 KHMER VOWEL SIGN Y
17BA KHMER VOWEL SIGN YY
17BB KHMER VOWEL SIGN U
17BC KHMER VOWEL SIGN UU
17BD KHMER VOWEL SIGN UA
17BE KHMER VOWEL SIGN OE
17BF KHMER VOWEL SIGN YA
17C0 KHMER VOWEL SIGN IE
17C1 KHMER VOWEL SIGN E
17C2 KHMER VOWEL SIGN AE
17C3 KHMER VOWEL SIGN AI
17C4 KHMER VOWEL SIGN OO
17C5 KHMER VOWEL SIGN AU
17C6 KHMER SIGN NIKAHIT
17C7 KHMER SIGN REAHMUK
17C8 KHMER SIGN YUUKALEAPINTU
17C9 KHMER SIGN MUUSIKATOAN
17CA KHMER SIGN TRIISAP
17CB KHMER SIGN BANTOC
17CC KHMER SIGN ROBAT
17CD KHMER SIGN TOANDAKHIAT
17CE KHMER SIGN KAKABAT
17CF KHMER SIGN AHSDA
17D0 KHMER SIGN SAMYOK SANNYA
17D1 KHMER SIGN VIRIAM
17D2 KHMER SIGN COENG
17D3 KHMER SIGN BATHAMASAT
17D4 KHMER SIGN KHAN
17D5 KHMER SIGN BARIYOOSAN
17D6 KHMER SIGN CAMNUC PII KUUH
17D7 KHMER SIGN LEK TOO
17D8 KHMER SIGN BEYYAL
17D9 KHMER SIGN PHNAEK MUAN
17DA KHMER SIGN KOOMUUT
17DB KHMER CURRENCY SYMBOL RIEL
17DC KHMER SIGN AVAKRAHASANYA
17DD KHMER SIGN ATTHACAN
17E0 KHMER DIGIT ZERO
17E1 KHMER DIGIT ONE
17E2 KHMER DIGIT TWO
17E3 KHMER DIGIT THREE
17E4 KHMER DIGIT FOUR
17E5 KHMER DIGIT FIVE
17E6 KHMER DIGIT SIX
17E7 KHMER DIGIT SEVEN
17E8 KHMER DIGIT EIGHT
17E9 KHMER DIGIT NINE
17F0 KHMER SYMBOL LEK ATTAK SON
17F1 KHMER SYMBOL LEK ATTAK MUOY
17F2 KHMER SYMBOL LEK ATTAK PII
17F3 KHMER SYMBOL LEK ATTAK BEI
17F4 KHMER SYMBOL LEK ATTAK BUON
17F5 KHMER SYMBOL LEK ATTAK PRAM
17F6 KHMER SYMBOL LEK ATTAK PRAM-MUOY
17F7 KHMER SYMBOL LEK ATTAK PRAM-PII
17F8 KHMER SYMBOL LEK ATTAK PRAM-BEI
17F9 KHMER SYMBOL LEK ATTAK PRAM-BUON
1800 MONGOLIAN BIRGA
1801 MONGOLIAN ELLIPSIS
1802 MONGOLIAN COMMA
1803 MONGOLIAN FULL STOP
1804 MONGOLIAN COLON
1805 MONGOLIAN FOUR DOTS
1806 MONGOLIAN TODO SOFT HYPHEN
1807 MONGOLIAN SIBE SYLLABLE BOUNDARY MARKER
1808 MONGOLIAN MANCHU COMMA
1809 MONGOLIAN MANCHU FULL STOP
180A MONGOLIAN NIRUGU
180B MONGOLIAN FREE VARIATION SELECTOR ONE
180C MONGOLIAN FREE VARIATION SELECTOR TWO
180D MONGOLIAN FREE VARIATION SELECTOR THREE
180E MONGOLIAN VOWEL SEPARATOR
1810 MONGOLIAN DIGIT ZERO
1811 MONGOLIAN DIGIT ONE
1812 MONGOLIAN DIGIT TWO
1813 MONGOLIAN DIGIT THREE
1814 MONGOLIAN DIGIT FOUR
1815 MONGOLIAN DIGIT FIVE
1816 MONGOLIAN DIGIT SIX
1817 MONGOLIAN DIGIT SEVEN
1818 MONGOLIAN DIGIT EIGHT
1819 MONGOLIAN DIGIT NINE
1820 MONGOLIAN LETTER A
1821 MONGOLIAN LETTER E
1822 MONGOLIAN LETTER I
1823 MONGOLIAN LETTER O
1824 MONGOLIAN LETTER U
1825 MONGOLIAN LETTER OE
1826 MONGOLIAN LETTER UE
1827 MONGOLIAN LETTER EE
1828 MONGOLIAN LETTER NA
1829 MONGOLIAN LETTER ANG
182A MONGOLIAN LETTER BA
182B MONGOLIAN LETTER PA
182C MONGOLIAN LETTER QA
182D MONGOLIAN LETTER GA
182E MONGOLIAN LETTER MA
182F MONGOLIAN LETTER LA
1830 MONGOLIAN LETTER SA
1831 MONGOLIAN LETTER SHA
1832 MONGOLIAN LETTER TA
1833 MONGOLIAN LETTER DA
1834 MONGOLIAN LETTER CHA
1835 MONGOLIAN LETTER JA
1836 MONGOLIAN LETTER YA
1837 MONGOLIAN LETTER RA
1838 MONGOLIAN LETTER WA
1839 MONGOLIAN LETTER FA
183A MONGOLIAN LETTER KA
183B MONGOLIAN LETTER KHA
183C MONGOLIAN LETTER TSA
183D MONGOLIAN LETTER ZA
183E MONGOLIAN LETTER HAA
183F MONGOLIAN LETTER ZRA
1840 MONGOLIAN LETTER LHA
1841 MONGOLIAN LETTER ZHI
1842 MONGOLIAN LETTER CHI
1843 MONGOLIAN LETTER TODO LONG VOWEL SIGN
1844 MONGOLIAN LETTER TODO E
1845 MONGOLIAN LETTER TODO I
1846 MONGOLIAN LETTER TODO O
1847 MONGOLIAN LETTER TODO U
1848 MONGOLIAN LETTER TODO OE
1849 MONGOLIAN LETTER TODO UE
184A MONGOLIAN LETTER TODO ANG
184B MONGOLIAN LETTER TODO BA
184C MONGOLIAN LETTER TODO PA
184D MONGOLIAN LETTER TODO QA
184E MONGOLIAN LETTER TODO GA
184F MONGOLIAN LETTER TODO MA
1850 MONGOLIAN LETTER TODO TA
1851 MONGOLIAN LETTER TODO DA
1852 MONGOLIAN LETTER TODO CHA
1853 MONGOLIAN LETTER TODO JA
1854 MONGOLIAN LETTER TODO TSA
1855 MONGOLIAN LETTER TODO YA
1856 MONGOLIAN LETTER TODO WA
1857 MONGOLIAN LETTER TODO KA
1858 MONGOLIAN LETTER TODO GAA
1859 MONGOLIAN LETTER TODO HAA
185A MONGOLIAN LETTER TODO JIA
185B MONGOLIAN LETTER TODO NIA
185C MONGOLIAN LETTER TODO DZA
185D MONGOLIAN LETTER SIBE E
185E MONGOLIAN LETTER SIBE I
185F MONGOLIAN LETTER SIBE IY
1860 MONGOLIAN LETTER SIBE UE
1861 MONGOLIAN LETTER SIBE U
1862 MONGOLIAN LETTER SIBE ANG
1863 MONGOLIAN LETTER SIBE KA
1864 MONGOLIAN LETTER SIBE GA
1865 MONGOLIAN LETTER SIBE HA
1866 MONGOLIAN LETTER SIBE PA
1867 MONGOLIAN LETTER SIBE SHA
1868 MONGOLIAN LETTER SIBE TA
1869 MONGOLIAN LETTER SIBE DA
186A MONGOLIAN LETTER SIBE JA
186B MONGOLIAN LETTER SIBE FA
186C MONGOLIAN LETTER SIBE GAA
186D MONGOLIAN LETTER SIBE HAA
186E MONGOLIAN LETTER SIBE TSA
186F MONGOLIAN LETTER SIBE ZA
1870 MONGOLIAN LETTER SIBE RAA
1871 MONGOLIAN LETTER SIBE CHA
1872 MONGOLIAN LETTER SIBE ZHA
1873 MONGOLIAN LETTER MANCHU I
1874 MONGOLIAN LETTER MANCHU KA
1875 MONGOLIAN LETTER MANCHU RA
1876 MONGOLIAN LETTER MANCHU FA
1877 MONGOLIAN LETTER MANCHU ZHA
1880 MONGOLIAN LETTER ALI GALI ANUSVARA ONE
1881 MONGOLIAN LETTER ALI GALI VISARGA ONE
1882 MONGOLIAN LETTER ALI GALI DAMARU
1883 MONGOLIAN LETTER ALI GALI UBADAMA
1884 MONGOLIAN LETTER ALI GALI INVERTED UBADAMA
1885 MONGOLIAN LETTER ALI GALI BALUDA
1886 MONGOLIAN LETTER ALI GALI THREE BALUDA
1887 MONGOLIAN LETTER ALI GALI A
1888 MONGOLIAN LETTER ALI GALI I
1889 MONGOLIAN LETTER ALI GALI KA
188A MONGOLIAN LETTER ALI GALI NGA
188B MONGOLIAN LETTER ALI GALI CA
188C MONGOLIAN LETTER ALI GALI TTA
188D MONGOLIAN LETTER ALI GALI TTHA
188E MONGOLIAN LETTER ALI GALI DDA
188F MONGOLIAN LETTER ALI GALI NNA
1890 MONGOLIAN LETTER ALI GALI TA
1891 MONGOLIAN LETTER ALI GALI DA
1892 MONGOLIAN LETTER ALI GALI PA
1893 MONGOLIAN LETTER ALI GALI PHA
1894 MONGOLIAN LETTER ALI GALI SSA
1895 MONGOLIAN LETTER ALI GALI ZHA
1896 MONGOLIAN LETTER ALI GALI ZA
1897 MONGOLIAN LETTER ALI GALI AH
1898 MONGOLIAN LETTER TODO ALI GALI TA
1899 MONGOLIAN LETTER TODO ALI GALI ZHA
189A MONGOLIAN LETTER MANCHU ALI GALI GHA
189B MONGOLIAN LETTER MANCHU ALI GALI NGA
189C MONGOLIAN LETTER MANCHU ALI GALI CA
189D MONGOLIAN LETTER MANCHU ALI GALI JHA
189E MONGOLIAN LETTER MANCHU ALI GALI TTA
189F MONGOLIAN LETTER MANCHU ALI GALI DDHA
18A0 MONGOLIAN LETTER MANCHU ALI GALI TA
18A1 MONGOLIAN LETTER MANCHU ALI GALI DHA
18A2 MONGOLIAN LETTER MANCHU ALI GALI SSA
18A3 MONGOLIAN LETTER MANCHU ALI GALI CYA
18A4 MONGOLIAN LETTER MANCHU ALI GALI ZHA
18A5 MONGOLIAN LETTER MANCHU ALI GALI ZA
18A6 MONGOLIAN LETTER ALI GALI HALF U
18A7 MONGOLIAN LETTER ALI GALI HALF YA
18A8 MONGOLIAN LETTER MANCHU ALI GALI BHA
18A9 MONGOLIAN LETTER ALI GALI DAGALGA
1900 LIMBU VOWEL-CARRIER LETTER
1901 LIMBU LETTER KA
1902 LIMBU LETTER KHA
1903 LIMBU LETTER GA
1904 LIMBU LETTER GHA
1905 LIMBU LETTER NGA
1906 LIMBU LETTER CA
1907 LIMBU LETTER CHA
1908 LIMBU LETTER JA
1909 LIMBU LETTER JHA
190A LIMBU LETTER YAN
190B LIMBU LETTER TA
190C LIMBU LETTER THA
190D LIMBU LETTER DA
190E LIMBU LETTER DHA
190F LIMBU LETTER NA
1910 LIMBU LETTER PA
1911 LIMBU LETTER PHA
1912 LIMBU LETTER BA
1913 LIMBU LETTER BHA
1914 LIMBU LETTER MA
1915 LIMBU LETTER YA
1916 LIMBU LETTER RA
1917 LIMBU LETTER LA
1918 LIMBU LETTER WA
1919 LIMBU LETTER SHA
191A LIMBU LETTER SSA
191B LIMBU LETTER SA
191C LIMBU LETTER HA
1920 LIMBU VOWEL SIGN A
1921 LIMBU VOWEL SIGN I
1922 LIMBU VOWEL SIGN U
1923 LIMBU VOWEL SIGN EE
1924 LIMBU VOWEL SIGN AI
1925 LIMBU VOWEL SIGN OO
1926 LIMBU VOWEL SIGN AU
1927 LIMBU VOWEL SIGN E
1928 LIMBU VOWEL SIGN O
1929 LIMBU SUBJOINED LETTER YA
192A LIMBU SUBJOINED LETTER RA
192B LIMBU SUBJOINED LETTER WA
1930 LIMBU SMALL LETTER KA
1931 LIMBU SMALL LETTER NGA
1932 LIMBU SMALL LETTER ANUSVARA
1933 LIMBU SMALL LETTER TA
1934 LIMBU SMALL LETTER NA
1935 LIMBU SMALL LETTER PA
1936 LIMBU SMALL LETTER MA
1937 LIMBU SMALL LETTER RA
1938 LIMBU SMALL LETTER LA
1939 LIMBU SIGN MUKPHRENG
193A LIMBU SIGN KEMPHRENG
193B LIMBU SIGN SA-I
1940 LIMBU SIGN LOO
1944 LIMBU EXCLAMATION MARK
1945 LIMBU QUESTION MARK
1946 LIMBU DIGIT ZERO
1947 LIMBU DIGIT ONE
1948 LIMBU DIGIT TWO
1949 LIMBU DIGIT THREE
194A LIMBU DIGIT FOUR
194B LIMBU DIGIT FIVE
194C LIMBU DIGIT SIX
194D LIMBU DIGIT SEVEN
194E LIMBU DIGIT EIGHT
194F LIMBU DIGIT NINE
1950 TAI LE LETTER KA
1951 TAI LE LETTER XA
1952 TAI LE LETTER NGA
1953 TAI LE LETTER TSA
1954 TAI LE LETTER SA
1955 TAI LE LETTER YA
1956 TAI LE LETTER TA
1957 TAI LE LETTER THA
1958 TAI LE LETTER LA
1959 TAI LE LETTER PA
195A TAI LE LETTER PHA
195B TAI LE LETTER MA
195C TAI LE LETTER FA
195D TAI LE LETTER VA
195E TAI LE LETTER HA
195F TAI LE LETTER QA
1960 TAI LE LETTER KHA
1961 TAI LE LETTER TSHA
1962 TAI LE LETTER NA
1963 TAI LE LETTER A
1964 TAI LE LETTER I
1965 TAI LE LETTER EE
1966 TAI LE LETTER EH
1967 TAI LE LETTER U
1968 TAI LE LETTER OO
1969 TAI LE LETTER O
196A TAI LE LETTER UE
196B TAI LE LETTER E
196C TAI LE LETTER AUE
196D TAI LE LETTER AI
1970 TAI LE LETTER TONE-2
1971 TAI LE LETTER TONE-3
1972 TAI LE LETTER TONE-4
1973 TAI LE LETTER TONE-5
1974 TAI LE LETTER TONE-6
1980 NEW TAI LUE LETTER HIGH QA
1981 NEW TAI LUE LETTER LOW QA
1982 NEW TAI LUE LETTER HIGH KA
1983 NEW TAI LUE LETTER HIGH XA
1984 NEW TAI LUE LETTER HIGH NGA
1985 NEW TAI LUE LETTER LOW KA
1986 NEW TAI LUE LETTER LOW XA
1987 NEW TAI LUE LETTER LOW NGA
1988 NEW TAI LUE LETTER HIGH TSA
1989 NEW TAI LUE LETTER HIGH SA
198A NEW TAI LUE LETTER HIGH YA
198B NEW TAI LUE LETTER LOW TSA
198C NEW TAI LUE LETTER LOW SA
198D NEW TAI LUE LETTER LOW YA
198E NEW TAI LUE LETTER HIGH TA
198F NEW TAI LUE LETTER HIGH THA
1990 NEW TAI LUE LETTER HIGH NA
1991 NEW TAI LUE LETTER LOW TA
1992 NEW TAI LUE LETTER LOW THA
1993 NEW TAI LUE LETTER LOW NA
1994 NEW TAI LUE LETTER HIGH PA
1995 NEW TAI LUE LETTER HIGH PHA
1996 NEW TAI LUE LETTER HIGH MA
1997 NEW TAI LUE LETTER LOW PA
1998 NEW TAI LUE LETTER LOW PHA
1999 NEW TAI LUE LETTER LOW MA
199A NEW TAI LUE LETTER HIGH FA
199B NEW TAI LUE LETTER HIGH VA
199C NEW TAI LUE LETTER HIGH LA
199D NEW TAI LUE LETTER LOW FA
199E NEW TAI LUE LETTER LOW VA
199F NEW TAI LUE LETTER LOW LA
19A0 NEW TAI LUE LETTER HIGH HA
19A1 NEW TAI LUE LETTER HIGH DA
19A2 NEW TAI LUE LETTER HIGH BA
19A3 NEW TAI LUE LETTER LOW HA
19A4 NEW TAI LUE LETTER LOW DA
19A5 NEW TAI LUE LETTER LOW BA
19A6 NEW TAI LUE LETTER HIGH KVA
19A7 NEW TAI LUE LETTER HIGH XVA
19A8 NEW TAI LUE LETTER LOW KVA
19A9 NEW TAI LUE LETTER LOW XVA
19B0 NEW TAI LUE VOWEL SIGN VOWEL SHORTENER
19B1 NEW TAI LUE VOWEL SIGN AA
19B2 NEW TAI LUE VOWEL SIGN II
19B3 NEW TAI LUE VOWEL SIGN U
19B4 NEW TAI LUE VOWEL SIGN UU
19B5 NEW TAI LUE VOWEL SIGN E
19B6 NEW TAI LUE VOWEL SIGN AE
19B7 NEW TAI LUE VOWEL SIGN O
19B8 NEW TAI LUE VOWEL SIGN OA
19B9 NEW TAI LUE VOWEL SIGN UE
19BA NEW TAI LUE VOWEL SIGN AY
19BB NEW TAI LUE VOWEL SIGN AAY
19BC NEW TAI LUE VOWEL SIGN UY
19BD NEW TAI LUE VOWEL SIGN OY
19BE NEW TAI LUE VOWEL SIGN OAY
19BF NEW TAI LUE VOWEL SIGN UEY
19C0 NEW TAI LUE VOWEL SIGN IY
19C1 NEW TAI LUE LETTER FINAL V
19C2 NEW TAI LUE LETTER FINAL NG
19C3 NEW TAI LUE LETTER FINAL N
19C4 NEW TAI LUE LETTER FINAL M
19C5 NEW TAI LUE LETTER FINAL K
19C6 NEW TAI LUE LETTER FINAL D
19C7 NEW TAI LUE LETTER FINAL B
19C8 NEW TAI LUE TONE MARK-1
19C9 NEW TAI LUE TONE MARK-2
19D0 NEW TAI LUE DIGIT ZERO
19D1 NEW TAI LUE DIGIT ONE
19D2 NEW TAI LUE DIGIT TWO
19D3 NEW TAI LUE DIGIT THREE
19D4 NEW TAI LUE DIGIT FOUR
19D5 NEW TAI LUE DIGIT FIVE
19D6 NEW TAI LUE DIGIT SIX
19D7 NEW TAI LUE DIGIT SEVEN
19D8 NEW TAI LUE DIGIT EIGHT
19D9 NEW TAI LUE DIGIT NINE
19DE NEW TAI LUE SIGN LAE
19DF NEW TAI LUE SIGN LAEV
19E0 KHMER SYMBOL PATHAMASAT
19E1 KHMER SYMBOL MUOY KOET
19E2 KHMER SYMBOL PII KOET
19E3 KHMER SYMBOL BEI KOET
19E4 KHMER SYMBOL BUON KOET
19E5 KHMER SYMBOL PRAM KOET
19E6 KHMER SYMBOL PRAM-MUOY KOET
19E7 KHMER SYMBOL PRAM-PII KOET
19E8 KHMER SYMBOL PRAM-BEI KOET
19E9 KHMER SYMBOL PRAM-BUON KOET
19EA KHMER SYMBOL DAP KOET
19EB KHMER SYMBOL DAP-MUOY KOET
19EC KHMER SYMBOL DAP-PII KOET
19ED KHMER SYMBOL DAP-BEI KOET
19EE KHMER SYMBOL DAP-BUON KOET
19EF KHMER SYMBOL DAP-PRAM KOET
19F0 KHMER SYMBOL TUTEYASAT
19F1 KHMER SYMBOL MUOY ROC
19F2 KHMER SYMBOL PII ROC
19F3 KHMER SYMBOL BEI ROC
19F4 KHMER SYMBOL BUON ROC
19F5 KHMER SYMBOL PRAM ROC
19F6 KHMER SYMBOL PRAM-MUOY ROC
19F7 KHMER SYMBOL PRAM-PII ROC
19F8 KHMER SYMBOL PRAM-BEI ROC
19F9 KHMER SYMBOL PRAM-BUON ROC
19FA KHMER SYMBOL DAP ROC
19FB KHMER SYMBOL DAP-MUOY ROC
19FC KHMER SYMBOL DAP-PII ROC
19FD KHMER SYMBOL DAP-BEI ROC
19FE KHMER SYMBOL DAP-BUON ROC
19FF KHMER SYMBOL DAP-PRAM ROC
1A00 BUGINESE LETTER KA
1A01 BUGINESE LETTER GA
1A02 BUGINESE LETTER NGA
1A03 BUGINESE LETTER NGKA
1A04 BUGINESE LETTER PA
1A05 BUGINESE LETTER BA
1A06 BUGINESE LETTER MA
1A07 BUGINESE LETTER MPA
1A08 BUGINESE LETTER TA
1A09 BUGINESE LETTER DA
1A0A BUGINESE LETTER NA
1A0B BUGINESE LETTER NRA
1A0C BUGINESE LETTER CA
1A0D BUGINESE LETTER JA
1A0E BUGINESE LETTER NYA
1A0F BUGINESE LETTER NYCA
1A10 BUGINESE LETTER YA
1A11 BUGINESE LETTER RA
1A12 BUGINESE LETTER LA
1A13 BUGINESE LETTER VA
1A14 BUGINESE LETTER SA
1A15 BUGINESE LETTER A
1A16 BUGINESE LETTER HA
1A17 BUGINESE VOWEL SIGN I
1A18 BUGINESE VOWEL SIGN U
1A19 BUGINESE VOWEL SIGN E
1A1A BUGINESE VOWEL SIGN O
1A1B BUGINESE VOWEL SIGN AE
1A1E BUGINESE PALLAWA
1A1F BUGINESE END OF SECTION
1D00 LATIN LETTER SMALL CAPITAL A
1D01 LATIN LETTER SMALL CAPITAL AE
1D02 LATIN SMALL LETTER TURNED AE
1D03 LATIN LETTER SMALL CAPITAL BARRED B
1D04 LATIN LETTER SMALL CAPITAL C
1D05 LATIN LETTER SMALL CAPITAL D
1D06 LATIN LETTER SMALL CAPITAL ETH
1D07 LATIN LETTER SMALL CAPITAL E
1D08 LATIN SMALL LETTER TURNED OPEN E
1D09 LATIN SMALL LETTER TURNED I
1D0A LATIN LETTER SMALL CAPITAL J
1D0B LATIN LETTER SMALL CAPITAL K
1D0C LATIN LETTER SMALL CAPITAL L WITH STROKE
1D0D LATIN LETTER SMALL CAPITAL M
1D0E LATIN LETTER SMALL CAPITAL REVERSED N
1D0F LATIN LETTER SMALL CAPITAL O
1D10 LATIN LETTER SMALL CAPITAL OPEN O
1D11 LATIN SMALL LETTER SIDEWAYS O
1D12 LATIN SMALL LETTER SIDEWAYS OPEN O
1D13 LATIN SMALL LETTER SIDEWAYS O WITH STROKE
1D14 LATIN SMALL LETTER TURNED OE
1D15 LATIN LETTER SMALL CAPITAL OU
1D16 LATIN SMALL LETTER TOP HALF O
1D17 LATIN SMALL LETTER BOTTOM HALF O
1D18 LATIN LETTER SMALL CAPITAL P
1D19 LATIN LETTER SMALL CAPITAL REVERSED R
1D1A LATIN LETTER SMALL CAPITAL TURNED R
1D1B LATIN LETTER SMALL CAPITAL T
1D1C LATIN LETTER SMALL CAPITAL U
1D1D LATIN SMALL LETTER SIDEWAYS U
1D1E LATIN SMALL LETTER SIDEWAYS DIAERESIZED U
1D1F LATIN SMALL LETTER SIDEWAYS TURNED M
1D20 LATIN LETTER SMALL CAPITAL V
1D21 LATIN LETTER SMALL CAPITAL W
1D22 LATIN LETTER SMALL CAPITAL Z
1D23 LATIN LETTER SMALL CAPITAL EZH
1D24 LATIN LETTER VOICED LARYNGEAL SPIRANT
1D25 LATIN LETTER AIN
1D26 GREEK LETTER SMALL CAPITAL GAMMA
1D27 GREEK LETTER SMALL CAPITAL LAMDA
1D28 GREEK LETTER SMALL CAPITAL PI
1D29 GREEK LETTER SMALL CAPITAL RHO
1D2A GREEK LETTER SMALL CAPITAL PSI
1D2B CYRILLIC LETTER SMALL CAPITAL EL
1D2C MODIFIER LETTER CAPITAL A
1D2D MODIFIER LETTER CAPITAL AE
1D2E MODIFIER LETTER CAPITAL B
1D2F MODIFIER LETTER CAPITAL BARRED B
1D30 MODIFIER LETTER CAPITAL D
1D31 MODIFIER LETTER CAPITAL E
1D32 MODIFIER LETTER CAPITAL REVERSED E
1D33 MODIFIER LETTER CAPITAL G
1D34 MODIFIER LETTER CAPITAL H
1D35 MODIFIER LETTER CAPITAL I
1D36 MODIFIER LETTER CAPITAL J
1D37 MODIFIER LETTER CAPITAL K
1D38 MODIFIER LETTER CAPITAL L
1D39 MODIFIER LETTER CAPITAL M
1D3A MODIFIER LETTER CAPITAL N
1D3B MODIFIER LETTER CAPITAL REVERSED N
1D3C MODIFIER LETTER CAPITAL O
1D3D MODIFIER LETTER CAPITAL OU
1D3E MODIFIER LETTER CAPITAL P
1D3F MODIFIER LETTER CAPITAL R
1D40 MODIFIER LETTER CAPITAL T
1D41 MODIFIER LETTER CAPITAL U
1D42 MODIFIER LETTER CAPITAL W
1D43 MODIFIER LETTER SMALL A
1D44 MODIFIER LETTER SMALL TURNED A
1D45 MODIFIER LETTER SMALL ALPHA
1D46 MODIFIER LETTER SMALL TURNED AE
1D47 MODIFIER LETTER SMALL B
1D48 MODIFIER LETTER SMALL D
1D49 MODIFIER LETTER SMALL E
1D4A MODIFIER LETTER SMALL SCHWA
1D4B MODIFIER LETTER SMALL OPEN E
1D4C MODIFIER LETTER SMALL TURNED OPEN E
1D4D MODIFIER LETTER SMALL G
1D4E MODIFIER LETTER SMALL TURNED I
1D4F MODIFIER LETTER SMALL K
1D50 MODIFIER LETTER SMALL M
1D51 MODIFIER LETTER SMALL ENG
1D52 MODIFIER LETTER SMALL O
1D53 MODIFIER LETTER SMALL OPEN O
1D54 MODIFIER LETTER SMALL TOP HALF O
1D55 MODIFIER LETTER SMALL BOTTOM HALF O
1D56 MODIFIER LETTER SMALL P
1D57 MODIFIER LETTER SMALL T
1D58 MODIFIER LETTER SMALL U
1D59 MODIFIER LETTER SMALL SIDEWAYS U
1D5A MODIFIER LETTER SMALL TURNED M
1D5B MODIFIER LETTER SMALL V
1D5C MODIFIER LETTER SMALL AIN
1D5D MODIFIER LETTER SMALL BETA
1D5E MODIFIER LETTER SMALL GREEK GAMMA
1D5F MODIFIER LETTER SMALL DELTA
1D60 MODIFIER LETTER SMALL GREEK PHI
1D61 MODIFIER LETTER SMALL CHI
1D62 LATIN SUBSCRIPT SMALL LETTER I
1D63 LATIN SUBSCRIPT SMALL LETTER R
1D64 LATIN SUBSCRIPT SMALL LETTER U
1D65 LATIN SUBSCRIPT SMALL LETTER V
1D66 GREEK SUBSCRIPT SMALL LETTER BETA
1D67 GREEK SUBSCRIPT SMALL LETTER GAMMA
1D68 GREEK SUBSCRIPT SMALL LETTER RHO
1D69 GREEK SUBSCRIPT SMALL LETTER PHI
1D6A GREEK SUBSCRIPT SMALL LETTER CHI
1D6B LATIN SMALL LETTER UE
1D6C LATIN SMALL LETTER B WITH MIDDLE TILDE
1D6D LATIN SMALL LETTER D WITH MIDDLE TILDE
1D6E LATIN SMALL LETTER F WITH MIDDLE TILDE
1D6F LATIN SMALL LETTER M WITH MIDDLE TILDE
1D70 LATIN SMALL LETTER N WITH MIDDLE TILDE
1D71 LATIN SMALL LETTER P WITH MIDDLE TILDE
1D72 LATIN SMALL LETTER R WITH MIDDLE TILDE
1D73 LATIN SMALL LETTER R WITH FISHHOOK AND MIDDLE TILDE
1D74 LATIN SMALL LETTER S WITH MIDDLE TILDE
1D75 LATIN SMALL LETTER T WITH MIDDLE TILDE
1D76 LATIN SMALL LETTER Z WITH MIDDLE TILDE
1D77 LATIN SMALL LETTER TURNED G
1D78 MODIFIER LETTER CYRILLIC EN
1D79 LATIN SMALL LETTER INSULAR G
1D7A LATIN SMALL LETTER TH WITH STRIKETHROUGH
1D7B LATIN SMALL CAPITAL LETTER I WITH STROKE
1D7C LATIN SMALL LETTER IOTA WITH STROKE
1D7D LATIN SMALL LETTER P WITH STROKE
1D7E LATIN SMALL CAPITAL LETTER U WITH STROKE
1D7F LATIN SMALL LETTER UPSILON WITH STROKE
1D80 LATIN SMALL LETTER B WITH PALATAL HOOK
1D81 LATIN SMALL LETTER D WITH PALATAL HOOK
1D82 LATIN SMALL LETTER F WITH PALATAL HOOK
1D83 LATIN SMALL LETTER G WITH PALATAL HOOK
1D84 LATIN SMALL LETTER K WITH PALATAL HOOK
1D85 LATIN SMALL LETTER L WITH PALATAL HOOK
1D86 LATIN SMALL LETTER M WITH PALATAL HOOK
1D87 LATIN SMALL LETTER N WITH PALATAL HOOK
1D88 LATIN SMALL LETTER P WITH PALATAL HOOK
1D89 LATIN SMALL LETTER R WITH PALATAL HOOK
1D8A LATIN SMALL LETTER S WITH PALATAL HOOK
1D8B LATIN SMALL LETTER ESH WITH PALATAL HOOK
1D8C LATIN SMALL LETTER V WITH PALATAL HOOK
1D8D LATIN SMALL LETTER X WITH PALATAL HOOK
1D8E LATIN SMALL LETTER Z WITH PALATAL HOOK
1D8F LATIN SMALL LETTER A WITH RETROFLEX HOOK
1D90 LATIN SMALL LETTER ALPHA WITH RETROFLEX HOOK
1D91 LATIN SMALL LETTER D WITH HOOK AND TAIL
1D92 LATIN SMALL LETTER E WITH RETROFLEX HOOK
1D93 LATIN SMALL LETTER OPEN E WITH RETROFLEX HOOK
1D94 LATIN SMALL LETTER REVERSED OPEN E WITH RETROFLEX HOOK
1D95 LATIN SMALL LETTER SCHWA WITH RETROFLEX HOOK
1D96 LATIN SMALL LETTER I WITH RETROFLEX HOOK
1D97 LATIN SMALL LETTER OPEN O WITH RETROFLEX HOOK
1D98 LATIN SMALL LETTER ESH WITH RETROFLEX HOOK
1D99 LATIN SMALL LETTER U WITH RETROFLEX HOOK
1D9A LATIN SMALL LETTER EZH WITH RETROFLEX HOOK
1D9B MODIFIER LETTER SMALL TURNED ALPHA
1D9C MODIFIER LETTER SMALL C
1D9D MODIFIER LETTER SMALL C WITH CURL
1D9E MODIFIER LETTER SMALL ETH
1D9F MODIFIER LETTER SMALL REVERSED OPEN E
1DA0 MODIFIER LETTER SMALL F
1DA1 MODIFIER LETTER SMALL DOTLESS J WITH STROKE
1DA2 MODIFIER LETTER SMALL SCRIPT G
1DA3 MODIFIER LETTER SMALL TURNED H
1DA4 MODIFIER LETTER SMALL I WITH STROKE
1DA5 MODIFIER LETTER SMALL IOTA
1DA6 MODIFIER LETTER SMALL CAPITAL I
1DA7 MODIFIER LETTER SMALL CAPITAL I WITH STROKE
1DA8 MODIFIER LETTER SMALL J WITH CROSSED-TAIL
1DA9 MODIFIER LETTER SMALL L WITH RETROFLEX HOOK
1DAA MODIFIER LETTER SMALL L WITH PALATAL HOOK
1DAB MODIFIER LETTER SMALL CAPITAL L
1DAC MODIFIER LETTER SMALL M WITH HOOK
1DAD MODIFIER LETTER SMALL TURNED M WITH LONG LEG
1DAE MODIFIER LETTER SMALL N WITH LEFT HOOK
1DAF MODIFIER LETTER SMALL N WITH RETROFLEX HOOK
1DB0 MODIFIER LETTER SMALL CAPITAL N
1DB1 MODIFIER LETTER SMALL BARRED O
1DB2 MODIFIER LETTER SMALL PHI
1DB3 MODIFIER LETTER SMALL S WITH HOOK
1DB4 MODIFIER LETTER SMALL ESH
1DB5 MODIFIER LETTER SMALL T WITH PALATAL HOOK
1DB6 MODIFIER LETTER SMALL U BAR
1DB7 MODIFIER LETTER SMALL UPSILON
1DB8 MODIFIER LETTER SMALL CAPITAL U
1DB9 MODIFIER LETTER SMALL V WITH HOOK
1DBA MODIFIER LETTER SMALL TURNED V
1DBB MODIFIER LETTER SMALL Z
1DBC MODIFIER LETTER SMALL Z WITH RETROFLEX HOOK
1DBD MODIFIER LETTER SMALL Z WITH CURL
1DBE MODIFIER LETTER SMALL EZH
1DBF MODIFIER LETTER SMALL THETA
1DC0 COMBINING DOTTED GRAVE ACCENT
1DC1 COMBINING DOTTED ACUTE ACCENT
1DC2 COMBINING SNAKE BELOW
1DC3 COMBINING SUSPENSION MARK
1E00 LATIN CAPITAL LETTER A WITH RING BELOW
1E01 LATIN SMALL LETTER A WITH RING BELOW
1E02 LATIN CAPITAL LETTER B WITH DOT ABOVE
1E03 LATIN SMALL LETTER B WITH DOT ABOVE
1E04 LATIN CAPITAL LETTER B WITH DOT BELOW
1E05 LATIN SMALL LETTER B WITH DOT BELOW
1E06 LATIN CAPITAL LETTER B WITH LINE BELOW
1E07 LATIN SMALL LETTER B WITH LINE BELOW
1E08 LATIN CAPITAL LETTER C WITH CEDILLA AND ACUTE
1E09 LATIN SMALL LETTER C WITH CEDILLA AND ACUTE
1E0A LATIN CAPITAL LETTER D WITH DOT ABOVE
1E0B LATIN SMALL LETTER D WITH DOT ABOVE
1E0C LATIN CAPITAL LETTER D WITH DOT BELOW
1E0D LATIN SMALL LETTER D WITH DOT BELOW
1E0E LATIN CAPITAL LETTER D WITH LINE BELOW
1E0F LATIN SMALL LETTER D WITH LINE BELOW
1E10 LATIN CAPITAL LETTER D WITH CEDILLA
1E11 LATIN SMALL LETTER D WITH CEDILLA
1E12 LATIN CAPITAL LETTER D WITH CIRCUMFLEX BELOW
1E13 LATIN SMALL LETTER D WITH CIRCUMFLEX BELOW
1E14 LATIN CAPITAL LETTER E WITH MACRON AND GRAVE
1E15 LATIN SMALL LETTER E WITH MACRON AND GRAVE
1E16 LATIN CAPITAL LETTER E WITH MACRON AND ACUTE
1E17 LATIN SMALL LETTER E WITH MACRON AND ACUTE
1E18 LATIN CAPITAL LETTER E WITH CIRCUMFLEX BELOW
1E19 LATIN SMALL LETTER E WITH CIRCUMFLEX BELOW
1E1A LATIN CAPITAL LETTER E WITH TILDE BELOW
1E1B LATIN SMALL LETTER E WITH TILDE BELOW
1E1C LATIN CAPITAL LETTER E WITH CEDILLA AND BREVE
1E1D LATIN SMALL LETTER E WITH CEDILLA AND BREVE
1E1E LATIN CAPITAL LETTER F WITH DOT ABOVE
1E1F LATIN SMALL LETTER F WITH DOT ABOVE
1E20 LATIN CAPITAL LETTER G WITH MACRON
1E21 LATIN SMALL LETTER G WITH MACRON
1E22 LATIN CAPITAL LETTER H WITH DOT ABOVE
1E23 LATIN SMALL LETTER H WITH DOT ABOVE
1E24 LATIN CAPITAL LETTER H WITH DOT BELOW
1E25 LATIN SMALL LETTER H WITH DOT BELOW
1E26 LATIN CAPITAL LETTER H WITH DIAERESIS
1E27 LATIN SMALL LETTER H WITH DIAERESIS
1E28 LATIN CAPITAL LETTER H WITH CEDILLA
1E29 LATIN SMALL LETTER H WITH CEDILLA
1E2A LATIN CAPITAL LETTER H WITH BREVE BELOW
1E2B LATIN SMALL LETTER H WITH BREVE BELOW
1E2C LATIN CAPITAL LETTER I WITH TILDE BELOW
1E2D LATIN SMALL LETTER I WITH TILDE BELOW
1E2E LATIN CAPITAL LETTER I WITH DIAERESIS AND ACUTE
1E2F LATIN SMALL LETTER I WITH DIAERESIS AND ACUTE
1E30 LATIN CAPITAL LETTER K WITH ACUTE
1E31 LATIN SMALL LETTER K WITH ACUTE
1E32 LATIN CAPITAL LETTER K WITH DOT BELOW
1E33 LATIN SMALL LETTER K WITH DOT BELOW
1E34 LATIN CAPITAL LETTER K WITH LINE BELOW
1E35 LATIN SMALL LETTER K WITH LINE BELOW
1E36 LATIN CAPITAL LETTER L WITH DOT BELOW
1E37 LATIN SMALL LETTER L WITH DOT BELOW
1E38 LATIN CAPITAL LETTER L WITH DOT BELOW AND MACRON
1E39 LATIN SMALL LETTER L WITH DOT BELOW AND MACRON
1E3A LATIN CAPITAL LETTER L WITH LINE BELOW
1E3B LATIN SMALL LETTER L WITH LINE BELOW
1E3C LATIN CAPITAL LETTER L WITH CIRCUMFLEX BELOW
1E3D LATIN SMALL LETTER L WITH CIRCUMFLEX BELOW
1E3E LATIN CAPITAL LETTER M WITH ACUTE
1E3F LATIN SMALL LETTER M WITH ACUTE
1E40 LATIN CAPITAL LETTER M WITH DOT ABOVE
1E41 LATIN SMALL LETTER M WITH DOT ABOVE
1E42 LATIN CAPITAL LETTER M WITH DOT BELOW
1E43 LATIN SMALL LETTER M WITH DOT BELOW
1E44 LATIN CAPITAL LETTER N WITH DOT ABOVE
1E45 LATIN SMALL LETTER N WITH DOT ABOVE
1E46 LATIN CAPITAL LETTER N WITH DOT BELOW
1E47 LATIN SMALL LETTER N WITH DOT BELOW
1E48 LATIN CAPITAL LETTER N WITH LINE BELOW
1E49 LATIN SMALL LETTER N WITH LINE BELOW
1E4A LATIN CAPITAL LETTER N WITH CIRCUMFLEX BELOW
1E4B LATIN SMALL LETTER N WITH CIRCUMFLEX BELOW
1E4C LATIN CAPITAL LETTER O WITH TILDE AND ACUTE
1E4D LATIN SMALL LETTER O WITH TILDE AND ACUTE
1E4E LATIN CAPITAL LETTER O WITH TILDE AND DIAERESIS
1E4F LATIN SMALL LETTER O WITH TILDE AND DIAERESIS
1E50 LATIN CAPITAL LETTER O WITH MACRON AND GRAVE
1E51 LATIN SMALL LETTER O WITH MACRON AND GRAVE
1E52 LATIN CAPITAL LETTER O WITH MACRON AND ACUTE
1E53 LATIN SMALL LETTER O WITH MACRON AND ACUTE
1E54 LATIN CAPITAL LETTER P WITH ACUTE
1E55 LATIN SMALL LETTER P WITH ACUTE
1E56 LATIN CAPITAL LETTER P WITH DOT ABOVE
1E57 LATIN SMALL LETTER P WITH DOT ABOVE
1E58 LATIN CAPITAL LETTER R WITH DOT ABOVE
1E59 LATIN SMALL LETTER R WITH DOT ABOVE
1E5A LATIN CAPITAL LETTER R WITH DOT BELOW
1E5B LATIN SMALL LETTER R WITH DOT BELOW
1E5C LATIN CAPITAL LETTER R WITH DOT BELOW AND MACRON
1E5D LATIN SMALL LETTER R WITH DOT BELOW AND MACRON
1E5E LATIN CAPITAL LETTER R WITH LINE BELOW
1E5F LATIN SMALL LETTER R WITH LINE BELOW
1E60 LATIN CAPITAL LETTER S WITH DOT ABOVE
1E61 LATIN SMALL LETTER S WITH DOT ABOVE
1E62 LATIN CAPITAL LETTER S WITH DOT BELOW
1E63 LATIN SMALL LETTER S WITH DOT BELOW
1E64 LATIN CAPITAL LETTER S WITH ACUTE AND DOT ABOVE
1E65 LATIN SMALL LETTER S WITH ACUTE AND DOT ABOVE
1E66 LATIN CAPITAL LETTER S WITH CARON AND DOT ABOVE
1E67 LATIN SMALL LETTER S WITH CARON AND DOT ABOVE
1E68 LATIN CAPITAL LETTER S WITH DOT BELOW AND DOT ABOVE
1E69 LATIN SMALL LETTER S WITH DOT BELOW AND DOT ABOVE
1E6A LATIN CAPITAL LETTER T WITH DOT ABOVE
1E6B LATIN SMALL LETTER T WITH DOT ABOVE
1E6C LATIN CAPITAL LETTER T WITH DOT BELOW
1E6D LATIN SMALL LETTER T WITH DOT BELOW
1E6E LATIN CAPITAL LETTER T WITH LINE BELOW
1E6F LATIN SMALL LETTER T WITH LINE BELOW
1E70 LATIN CAPITAL LETTER T WITH CIRCUMFLEX BELOW
1E71 LATIN SMALL LETTER T WITH CIRCUMFLEX BELOW
1E72 LATIN CAPITAL LETTER U WITH DIAERESIS BELOW
1E73 LATIN SMALL LETTER U WITH DIAERESIS BELOW
1E74 LATIN CAPITAL LETTER U WITH TILDE BELOW
1E75 LATIN SMALL LETTER U WITH TILDE BELOW
1E76 LATIN CAPITAL LETTER U WITH CIRCUMFLEX BELOW
1E77 LATIN SMALL LETTER U WITH CIRCUMFLEX BELOW
1E78 LATIN CAPITAL LETTER U WITH TILDE AND ACUTE
1E79 LATIN SMALL LETTER U WITH TILDE AND ACUTE
1E7A LATIN CAPITAL LETTER U WITH MACRON AND DIAERESIS
1E7B LATIN SMALL LETTER U WITH MACRON AND DIAERESIS
1E7C LATIN CAPITAL LETTER V WITH TILDE
1E7D LATIN SMALL LETTER V WITH TILDE
1E7E LATIN CAPITAL LETTER V WITH DOT BELOW
1E7F LATIN SMALL LETTER V WITH DOT BELOW
1E80 LATIN CAPITAL LETTER W WITH GRAVE
1E81 LATIN SMALL LETTER W WITH GRAVE
1E82 LATIN CAPITAL LETTER W WITH ACUTE
1E83 LATIN SMALL LETTER W WITH ACUTE
1E84 LATIN CAPITAL LETTER W WITH DIAERESIS
1E85 LATIN SMALL LETTER W WITH DIAERESIS
1E86 LATIN CAPITAL LETTER W WITH DOT ABOVE
1E87 LATIN SMALL LETTER W WITH DOT ABOVE
1E88 LATIN CAPITAL LETTER W WITH DOT BELOW
1E89 LATIN SMALL LETTER W WITH DOT BELOW
1E8A LATIN CAPITAL LETTER X WITH DOT ABOVE
1E8B LATIN SMALL LETTER X WITH DOT ABOVE
1E8C LATIN CAPITAL LETTER X WITH DIAERESIS
1E8D LATIN SMALL LETTER X WITH DIAERESIS
1E8E LATIN CAPITAL LETTER Y WITH DOT ABOVE
1E8F LATIN SMALL LETTER Y WITH DOT ABOVE
1E90 LATIN CAPITAL LETTER Z WITH CIRCUMFLEX
1E91 LATIN SMALL LETTER Z WITH CIRCUMFLEX
1E92 LATIN CAPITAL LETTER Z WITH DOT BELOW
1E93 LATIN SMALL LETTER Z WITH DOT BELOW
1E94 LATIN CAPITAL LETTER Z WITH LINE BELOW
1E95 LATIN SMALL LETTER Z WITH LINE BELOW
1E96 LATIN SMALL LETTER H WITH LINE BELOW
1E97 LATIN SMALL LETTER T WITH DIAERESIS
1E98 LATIN SMALL LETTER W WITH RING ABOVE
1E99 LATIN SMALL LETTER Y WITH RING ABOVE
1E9A LATIN SMALL LETTER A WITH RIGHT HALF RING
1E9B LATIN SMALL LETTER LONG S WITH DOT ABOVE
1EA0 LATIN CAPITAL LETTER A WITH DOT BELOW
1EA1 LATIN SMALL LETTER A WITH DOT BELOW
1EA2 LATIN CAPITAL LETTER A WITH HOOK ABOVE
1EA3 LATIN SMALL LETTER A WITH HOOK ABOVE
1EA4 LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND ACUTE
1EA5 LATIN SMALL LETTER A WITH CIRCUMFLEX AND ACUTE
1EA6 LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND GRAVE
1EA7 LATIN SMALL LETTER A WITH CIRCUMFLEX AND GRAVE
1EA8 LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND HOOK ABOVE
1EA9 LATIN SMALL LETTER A WITH CIRCUMFLEX AND HOOK ABOVE
1EAA LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND TILDE
1EAB LATIN SMALL LETTER A WITH CIRCUMFLEX AND TILDE
1EAC LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND DOT BELOW
1EAD LATIN SMALL LETTER A WITH CIRCUMFLEX AND DOT BELOW
1EAE LATIN CAPITAL LETTER A WITH BREVE AND ACUTE
1EAF LATIN SMALL LETTER A WITH BREVE AND ACUTE
1EB0 LATIN CAPITAL LETTER A WITH BREVE AND GRAVE
1EB1 LATIN SMALL LETTER A WITH BREVE AND GRAVE
1EB2 LATIN CAPITAL LETTER A WITH BREVE AND HOOK ABOVE
1EB3 LATIN SMALL LETTER A WITH BREVE AND HOOK ABOVE
1EB4 LATIN CAPITAL LETTER A WITH BREVE AND TILDE
1EB5 LATIN SMALL LETTER A WITH BREVE AND TILDE
1EB6 LATIN CAPITAL LETTER A WITH BREVE AND DOT BELOW
1EB7 LATIN SMALL LETTER A WITH BREVE AND DOT BELOW
1EB8 LATIN CAPITAL LETTER E WITH DOT BELOW
1EB9 LATIN SMALL LETTER E WITH DOT BELOW
1EBA LATIN CAPITAL LETTER E WITH HOOK ABOVE
1EBB LATIN SMALL LETTER E WITH HOOK ABOVE
1EBC LATIN CAPITAL LETTER E WITH TILDE
1EBD LATIN SMALL LETTER E WITH TILDE
1EBE LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND ACUTE
1EBF LATIN SMALL LETTER E WITH CIRCUMFLEX AND ACUTE
1EC0 LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND GRAVE
1EC1 LATIN SMALL LETTER E WITH CIRCUMFLEX AND GRAVE
1EC2 LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND HOOK ABOVE
1EC3 LATIN SMALL LETTER E WITH CIRCUMFLEX AND HOOK ABOVE
1EC4 LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND TILDE
1EC5 LATIN SMALL LETTER E WITH CIRCUMFLEX AND TILDE
1EC6 LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND DOT BELOW
1EC7 LATIN SMALL LETTER E WITH CIRCUMFLEX AND DOT BELOW
1EC8 LATIN CAPITAL LETTER I WITH HOOK ABOVE
1EC9 LATIN SMALL LETTER I WITH HOOK ABOVE
1ECA LATIN CAPITAL LETTER I WITH DOT BELOW
1ECB LATIN SMALL LETTER I WITH DOT BELOW
1ECC LATIN CAPITAL LETTER O WITH DOT BELOW
1ECD LATIN SMALL LETTER O WITH DOT BELOW
1ECE LATIN CAPITAL LETTER O WITH HOOK ABOVE
1ECF LATIN SMALL LETTER O WITH HOOK ABOVE
1ED0 LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND ACUTE
1ED1 LATIN SMALL LETTER O WITH CIRCUMFLEX AND ACUTE
1ED2 LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND GRAVE
1ED3 LATIN SMALL LETTER O WITH CIRCUMFLEX AND GRAVE
1ED4 LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND HOOK ABOVE
1ED5 LATIN SMALL LETTER O WITH CIRCUMFLEX AND HOOK ABOVE
1ED6 LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND TILDE
1ED7 LATIN SMALL LETTER O WITH CIRCUMFLEX AND TILDE
1ED8 LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND DOT BELOW
1ED9 LATIN SMALL LETTER O WITH CIRCUMFLEX AND DOT BELOW
1EDA LATIN CAPITAL LETTER O WITH HORN AND ACUTE
1EDB LATIN SMALL LETTER O WITH HORN AND ACUTE
1EDC LATIN CAPITAL LETTER O WITH HORN AND GRAVE
1EDD LATIN SMALL LETTER O WITH HORN AND GRAVE
1EDE LATIN CAPITAL LETTER O WITH HORN AND HOOK ABOVE
1EDF LATIN SMALL LETTER O WITH HORN AND HOOK ABOVE
1EE0 LATIN CAPITAL LETTER O WITH HORN AND TILDE
1EE1 LATIN SMALL LETTER O WITH HORN AND TILDE
1EE2 LATIN CAPITAL LETTER O WITH HORN AND DOT BELOW
1EE3 LATIN SMALL LETTER O WITH HORN AND DOT BELOW
1EE4 LATIN CAPITAL LETTER U WITH DOT BELOW
1EE5 LATIN SMALL LETTER U WITH DOT BELOW
1EE6 LATIN CAPITAL LETTER U WITH HOOK ABOVE
1EE7 LATIN SMALL LETTER U WITH HOOK ABOVE
1EE8 LATIN CAPITAL LETTER U WITH HORN AND ACUTE
1EE9 LATIN SMALL LETTER U WITH HORN AND ACUTE
1EEA LATIN CAPITAL LETTER U WITH HORN AND GRAVE
1EEB LATIN SMALL LETTER U WITH HORN AND GRAVE
1EEC LATIN CAPITAL LETTER U WITH HORN AND HOOK ABOVE
1EED LATIN SMALL LETTER U WITH HORN AND HOOK ABOVE
1EEE LATIN CAPITAL LETTER U WITH HORN AND TILDE
1EEF LATIN SMALL LETTER U WITH HORN AND TILDE
1EF0 LATIN CAPITAL LETTER U WITH HORN AND DOT BELOW
1EF1 LATIN SMALL LETTER U WITH HORN AND DOT BELOW
1EF2 LATIN CAPITAL LETTER Y WITH GRAVE
1EF3 LATIN SMALL LETTER Y WITH GRAVE
1EF4 LATIN CAPITAL LETTER Y WITH DOT BELOW
1EF5 LATIN SMALL LETTER Y WITH DOT BELOW
1EF6 LATIN CAPITAL LETTER Y WITH HOOK ABOVE
1EF7 LATIN SMALL LETTER Y WITH HOOK ABOVE
1EF8 LATIN CAPITAL LETTER Y WITH TILDE
1EF9 LATIN SMALL LETTER Y WITH TILDE
1F00 GREEK SMALL LETTER ALPHA WITH PSILI
1F01 GREEK SMALL LETTER ALPHA WITH DASIA
1F02 GREEK SMALL LETTER ALPHA WITH PSILI AND VARIA
1F03 GREEK SMALL LETTER ALPHA WITH DASIA AND VARIA
1F04 GREEK SMALL LETTER ALPHA WITH PSILI AND OXIA
1F05 GREEK SMALL LETTER ALPHA WITH DASIA AND OXIA
1F06 GREEK SMALL LETTER ALPHA WITH PSILI AND PERISPOMENI
1F07 GREEK SMALL LETTER ALPHA WITH DASIA AND PERISPOMENI
1F08 GREEK CAPITAL LETTER ALPHA WITH PSILI
1F09 GREEK CAPITAL LETTER ALPHA WITH DASIA
1F0A GREEK CAPITAL LETTER ALPHA WITH PSILI AND VARIA
1F0B GREEK CAPITAL LETTER ALPHA WITH DASIA AND VARIA
1F0C GREEK CAPITAL LETTER ALPHA WITH PSILI AND OXIA
1F0D GREEK CAPITAL LETTER ALPHA WITH DASIA AND OXIA
1F0E GREEK CAPITAL LETTER ALPHA WITH PSILI AND PERISPOMENI
1F0F GREEK CAPITAL LETTER ALPHA WITH DASIA AND PERISPOMENI
1F10 GREEK SMALL LETTER EPSILON WITH PSILI
1F11 GREEK SMALL LETTER EPSILON WITH DASIA
1F12 GREEK SMALL LETTER EPSILON WITH PSILI AND VARIA
1F13 GREEK SMALL LETTER EPSILON WITH DASIA AND VARIA
1F14 GREEK SMALL LETTER EPSILON WITH PSILI AND OXIA
1F15 GREEK SMALL LETTER EPSILON WITH DASIA AND OXIA
1F18 GREEK CAPITAL LETTER EPSILON WITH PSILI
1F19 GREEK CAPITAL LETTER EPSILON WITH DASIA
1F1A GREEK CAPITAL LETTER EPSILON WITH PSILI AND VARIA
1F1B GREEK CAPITAL LETTER EPSILON WITH DASIA AND VARIA
1F1C GREEK CAPITAL LETTER EPSILON WITH PSILI AND OXIA
1F1D GREEK CAPITAL LETTER EPSILON WITH DASIA AND OXIA
1F20 GREEK SMALL LETTER ETA WITH PSILI
1F21 GREEK SMALL LETTER ETA WITH DASIA
1F22 GREEK SMALL LETTER ETA WITH PSILI AND VARIA
1F23 GREEK SMALL LETTER ETA WITH DASIA AND VARIA
1F24 GREEK SMALL LETTER ETA WITH PSILI AND OXIA
1F25 GREEK SMALL LETTER ETA WITH DASIA AND OXIA
1F26 GREEK SMALL LETTER ETA WITH PSILI AND PERISPOMENI
1F27 GREEK SMALL LETTER ETA WITH DASIA AND PERISPOMENI
1F28 GREEK CAPITAL LETTER ETA WITH PSILI
1F29 GREEK CAPITAL LETTER ETA WITH DASIA
1F2A GREEK CAPITAL LETTER ETA WITH PSILI AND VARIA
1F2B GREEK CAPITAL LETTER ETA WITH DASIA AND VARIA
1F2C GREEK CAPITAL LETTER ETA WITH PSILI AND OXIA
1F2D GREEK CAPITAL LETTER ETA WITH DASIA AND OXIA
1F2E GREEK CAPITAL LETTER ETA WITH PSILI AND PERISPOMENI
1F2F GREEK CAPITAL LETTER ETA WITH DASIA AND PERISPOMENI
1F30 GREEK SMALL LETTER IOTA WITH PSILI
1F31 GREEK SMALL LETTER IOTA WITH DASIA
1F32 GREEK SMALL LETTER IOTA WITH PSILI AND VARIA
1F33 GREEK SMALL LETTER IOTA WITH DASIA AND VARIA
1F34 GREEK SMALL LETTER IOTA WITH PSILI AND OXIA
1F35 GREEK SMALL LETTER IOTA WITH DASIA AND OXIA
1F36 GREEK SMALL LETTER IOTA WITH PSILI AND PERISPOMENI
1F37 GREEK SMALL LETTER IOTA WITH DASIA AND PERISPOMENI
1F38 GREEK CAPITAL LETTER IOTA WITH PSILI
1F39 GREEK CAPITAL LETTER IOTA WITH DASIA
1F3A GREEK CAPITAL LETTER IOTA WITH PSILI AND VARIA
1F3B GREEK CAPITAL LETTER IOTA WITH DASIA AND VARIA
1F3C GREEK CAPITAL LETTER IOTA WITH PSILI AND OXIA
1F3D GREEK CAPITAL LETTER IOTA WITH DASIA AND OXIA
1F3E GREEK CAPITAL LETTER IOTA WITH PSILI AND PERISPOMENI
1F3F GREEK CAPITAL LETTER IOTA WITH DASIA AND PERISPOMENI
1F40 GREEK SMALL LETTER OMICRON WITH PSILI
1F41 GREEK SMALL LETTER OMICRON WITH DASIA
1F42 GREEK SMALL LETTER OMICRON WITH PSILI AND VARIA
1F43 GREEK SMALL LETTER OMICRON WITH DASIA AND VARIA
1F44 GREEK SMALL LETTER OMICRON WITH PSILI AND OXIA
1F45 GREEK SMALL LETTER OMICRON WITH DASIA AND OXIA
1F48 GREEK CAPITAL LETTER OMICRON WITH PSILI
1F49 GREEK CAPITAL LETTER OMICRON WITH DASIA
1F4A GREEK CAPITAL LETTER OMICRON WITH PSILI AND VARIA
1F4B GREEK CAPITAL LETTER OMICRON WITH DASIA AND VARIA
1F4C GREEK CAPITAL LETTER OMICRON WITH PSILI AND OXIA
1F4D GREEK CAPITAL LETTER OMICRON WITH DASIA AND OXIA
1F50 GREEK SMALL LETTER UPSILON WITH PSILI
1F51 GREEK SMALL LETTER UPSILON WITH DASIA
1F52 GREEK SMALL LETTER UPSILON WITH PSILI AND VARIA
1F53 GREEK SMALL LETTER UPSILON WITH DASIA AND VARIA
1F54 GREEK SMALL LETTER UPSILON WITH PSILI AND OXIA
1F55 GREEK SMALL LETTER UPSILON WITH DASIA AND OXIA
1F56 GREEK SMALL LETTER UPSILON WITH PSILI AND PERISPOMENI
1F57 GREEK SMALL LETTER UPSILON WITH DASIA AND PERISPOMENI
1F59 GREEK CAPITAL LETTER UPSILON WITH DASIA
1F5B GREEK CAPITAL LETTER UPSILON WITH DASIA AND VARIA
1F5D GREEK CAPITAL LETTER UPSILON WITH DASIA AND OXIA
1F5F GREEK CAPITAL LETTER UPSILON WITH DASIA AND PERISPOMENI
1F60 GREEK SMALL LETTER OMEGA WITH PSILI
1F61 GREEK SMALL LETTER OMEGA WITH DASIA
1F62 GREEK SMALL LETTER OMEGA WITH PSILI AND VARIA
1F63 GREEK SMALL LETTER OMEGA WITH DASIA AND VARIA
1F64 GREEK SMALL LETTER OMEGA WITH PSILI AND OXIA
1F65 GREEK SMALL LETTER OMEGA WITH DASIA AND OXIA
1F66 GREEK SMALL LETTER OMEGA WITH PSILI AND PERISPOMENI
1F67 GREEK SMALL LETTER OMEGA WITH DASIA AND PERISPOMENI
1F68 GREEK CAPITAL LETTER OMEGA WITH PSILI
1F69 GREEK CAPITAL LETTER OMEGA WITH DASIA
1F6A GREEK CAPITAL LETTER OMEGA WITH PSILI AND VARIA
1F6B GREEK CAPITAL LETTER OMEGA WITH DASIA AND VARIA
1F6C GREEK CAPITAL LETTER OMEGA WITH PSILI AND OXIA
1F6D GREEK CAPITAL LETTER OMEGA WITH DASIA AND OXIA
1F6E GREEK CAPITAL LETTER OMEGA WITH PSILI AND PERISPOMENI
1F6F GREEK CAPITAL LETTER OMEGA WITH DASIA AND PERISPOMENI
1F70 GREEK SMALL LETTER ALPHA WITH VARIA
1F71 GREEK SMALL LETTER ALPHA WITH OXIA
1F72 GREEK SMALL LETTER EPSILON WITH VARIA
1F73 GREEK SMALL LETTER EPSILON WITH OXIA
1F74 GREEK SMALL LETTER ETA WITH VARIA
1F75 GREEK SMALL LETTER ETA WITH OXIA
1F76 GREEK SMALL LETTER IOTA WITH VARIA
1F77 GREEK SMALL LETTER IOTA WITH OXIA
1F78 GREEK SMALL LETTER OMICRON WITH VARIA
1F79 GREEK SMALL LETTER OMICRON WITH OXIA
1F7A GREEK SMALL LETTER UPSILON WITH VARIA
1F7B GREEK SMALL LETTER UPSILON WITH OXIA
1F7C GREEK SMALL LETTER OMEGA WITH VARIA
1F7D GREEK SMALL LETTER OMEGA WITH OXIA
1F80 GREEK SMALL LETTER ALPHA WITH PSILI AND YPOGEGRAMMENI
1F81 GREEK SMALL LETTER ALPHA WITH DASIA AND YPOGEGRAMMENI
1F82 GREEK SMALL LETTER ALPHA WITH PSILI AND VARIA AND YPOGEGRAMMENI
1F83 GREEK SMALL LETTER ALPHA WITH DASIA AND VARIA AND YPOGEGRAMMENI
1F84 GREEK SMALL LETTER ALPHA WITH PSILI AND OXIA AND YPOGEGRAMMENI
1F85 GREEK SMALL LETTER ALPHA WITH DASIA AND OXIA AND YPOGEGRAMMENI
1F86 GREEK SMALL LETTER ALPHA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI
1F87 GREEK SMALL LETTER ALPHA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI
1F88 GREEK CAPITAL LETTER ALPHA WITH PSILI AND PROSGEGRAMMENI
1F89 GREEK CAPITAL LETTER ALPHA WITH DASIA AND PROSGEGRAMMENI
1F8A GREEK CAPITAL LETTER ALPHA WITH PSILI AND VARIA AND PROSGEGRAMMENI
1F8B GREEK CAPITAL LETTER ALPHA WITH DASIA AND VARIA AND PROSGEGRAMMENI
1F8C GREEK CAPITAL LETTER ALPHA WITH PSILI AND OXIA AND PROSGEGRAMMENI
1F8D GREEK CAPITAL LETTER ALPHA WITH DASIA AND OXIA AND PROSGEGRAMMENI
1F8E GREEK CAPITAL LETTER ALPHA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI
1F8F GREEK CAPITAL LETTER ALPHA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI
1F90 GREEK SMALL LETTER ETA WITH PSILI AND YPOGEGRAMMENI
1F91 GREEK SMALL LETTER ETA WITH DASIA AND YPOGEGRAMMENI
1F92 GREEK SMALL LETTER ETA WITH PSILI AND VARIA AND YPOGEGRAMMENI
1F93 GREEK SMALL LETTER ETA WITH DASIA AND VARIA AND YPOGEGRAMMENI
1F94 GREEK SMALL LETTER ETA WITH PSILI AND OXIA AND YPOGEGRAMMENI
1F95 GREEK SMALL LETTER ETA WITH DASIA AND OXIA AND YPOGEGRAMMENI
1F96 GREEK SMALL LETTER ETA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI
1F97 GREEK SMALL LETTER ETA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI
1F98 GREEK CAPITAL LETTER ETA WITH PSILI AND PROSGEGRAMMENI
1F99 GREEK CAPITAL LETTER ETA WITH DASIA AND PROSGEGRAMMENI
1F9A GREEK CAPITAL LETTER ETA WITH PSILI AND VARIA AND PROSGEGRAMMENI
1F9B GREEK CAPITAL LETTER ETA WITH DASIA AND VARIA AND PROSGEGRAMMENI
1F9C GREEK CAPITAL LETTER ETA WITH PSILI AND OXIA AND PROSGEGRAMMENI
1F9D GREEK CAPITAL LETTER ETA WITH DASIA AND OXIA AND PROSGEGRAMMENI
1F9E GREEK CAPITAL LETTER ETA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI
1F9F GREEK CAPITAL LETTER ETA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI
1FA0 GREEK SMALL LETTER OMEGA WITH PSILI AND YPOGEGRAMMENI
1FA1 GREEK SMALL LETTER OMEGA WITH DASIA AND YPOGEGRAMMENI
1FA2 GREEK SMALL LETTER OMEGA WITH PSILI AND VARIA AND YPOGEGRAMMENI
1FA3 GREEK SMALL LETTER OMEGA WITH DASIA AND VARIA AND YPOGEGRAMMENI
1FA4 GREEK SMALL LETTER OMEGA WITH PSILI AND OXIA AND YPOGEGRAMMENI
1FA5 GREEK SMALL LETTER OMEGA WITH DASIA AND OXIA AND YPOGEGRAMMENI
1FA6 GREEK SMALL LETTER OMEGA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI
1FA7 GREEK SMALL LETTER OMEGA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI
1FA8 GREEK CAPITAL LETTER OMEGA WITH PSILI AND PROSGEGRAMMENI
1FA9 GREEK CAPITAL LETTER OMEGA WITH DASIA AND PROSGEGRAMMENI
1FAA GREEK CAPITAL LETTER OMEGA WITH PSILI AND VARIA AND PROSGEGRAMMENI
1FAB GREEK CAPITAL LETTER OMEGA WITH DASIA AND VARIA AND PROSGEGRAMMENI
1FAC GREEK CAPITAL LETTER OMEGA WITH PSILI AND OXIA AND PROSGEGRAMMENI
1FAD GREEK CAPITAL LETTER OMEGA WITH DASIA AND OXIA AND PROSGEGRAMMENI
1FAE GREEK CAPITAL LETTER OMEGA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI
1FAF GREEK CAPITAL LETTER OMEGA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI
1FB0 GREEK SMALL LETTER ALPHA WITH VRACHY
1FB1 GREEK SMALL LETTER ALPHA WITH MACRON
1FB2 GREEK SMALL LETTER ALPHA WITH VARIA AND YPOGEGRAMMENI
1FB3 GREEK SMALL LETTER ALPHA WITH YPOGEGRAMMENI
1FB4 GREEK SMALL LETTER ALPHA WITH OXIA AND YPOGEGRAMMENI
1FB6 GREEK SMALL LETTER ALPHA WITH PERISPOMENI
1FB7 GREEK SMALL LETTER ALPHA WITH PERISPOMENI AND YPOGEGRAMMENI
1FB8 GREEK CAPITAL LETTER ALPHA WITH VRACHY
1FB9 GREEK CAPITAL LETTER ALPHA WITH MACRON
1FBA GREEK CAPITAL LETTER ALPHA WITH VARIA
1FBB GREEK CAPITAL LETTER ALPHA WITH OXIA
1FBC GREEK CAPITAL LETTER ALPHA WITH PROSGEGRAMMENI
1FBD GREEK KORONIS
1FBE GREEK PROSGEGRAMMENI
1FBF GREEK PSILI
1FC0 GREEK PERISPOMENI
1FC1 GREEK DIALYTIKA AND PERISPOMENI
1FC2 GREEK SMALL LETTER ETA WITH VARIA AND YPOGEGRAMMENI
1FC3 GREEK SMALL LETTER ETA WITH YPOGEGRAMMENI
1FC4 GREEK SMALL LETTER ETA WITH OXIA AND YPOGEGRAMMENI
1FC6 GREEK SMALL LETTER ETA WITH PERISPOMENI
1FC7 GREEK SMALL LETTER ETA WITH PERISPOMENI AND YPOGEGRAMMENI
1FC8 GREEK CAPITAL LETTER EPSILON WITH VARIA
1FC9 GREEK CAPITAL LETTER EPSILON WITH OXIA
1FCA GREEK CAPITAL LETTER ETA WITH VARIA
1FCB GREEK CAPITAL LETTER ETA WITH OXIA
1FCC GREEK CAPITAL LETTER ETA WITH PROSGEGRAMMENI
1FCD GREEK PSILI AND VARIA
1FCE GREEK PSILI AND OXIA
1FCF GREEK PSILI AND PERISPOMENI
1FD0 GREEK SMALL LETTER IOTA WITH VRACHY
1FD1 GREEK SMALL LETTER IOTA WITH MACRON
1FD2 GREEK SMALL LETTER IOTA WITH DIALYTIKA AND VARIA
1FD3 GREEK SMALL LETTER IOTA WITH DIALYTIKA AND OXIA
1FD6 GREEK SMALL LETTER IOTA WITH PERISPOMENI
1FD7 GREEK SMALL LETTER IOTA WITH DIALYTIKA AND PERISPOMENI
1FD8 GREEK CAPITAL LETTER IOTA WITH VRACHY
1FD9 GREEK CAPITAL LETTER IOTA WITH MACRON
1FDA GREEK CAPITAL LETTER IOTA WITH VARIA
1FDB GREEK CAPITAL LETTER IOTA WITH OXIA
1FDD GREEK DASIA AND VARIA
1FDE GREEK DASIA AND OXIA
1FDF GREEK DASIA AND PERISPOMENI
1FE0 GREEK SMALL LETTER UPSILON WITH VRACHY
1FE1 GREEK SMALL LETTER UPSILON WITH MACRON
1FE2 GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND VARIA
1FE3 GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND OXIA
1FE4 GREEK SMALL LETTER RHO WITH PSILI
1FE5 GREEK SMALL LETTER RHO WITH DASIA
1FE6 GREEK SMALL LETTER UPSILON WITH PERISPOMENI
1FE7 GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND PERISPOMENI
1FE8 GREEK CAPITAL LETTER UPSILON WITH VRACHY
1FE9 GREEK CAPITAL LETTER UPSILON WITH MACRON
1FEA GREEK CAPITAL LETTER UPSILON WITH VARIA
1FEB GREEK CAPITAL LETTER UPSILON WITH OXIA
1FEC GREEK CAPITAL LETTER RHO WITH DASIA
1FED GREEK DIALYTIKA AND VARIA
1FEE GREEK DIALYTIKA AND OXIA
1FEF GREEK VARIA
1FF2 GREEK SMALL LETTER OMEGA WITH VARIA AND YPOGEGRAMMENI
1FF3 GREEK SMALL LETTER OMEGA WITH YPOGEGRAMMENI
1FF4 GREEK SMALL LETTER OMEGA WITH OXIA AND YPOGEGRAMMENI
1FF6 GREEK SMALL LETTER OMEGA WITH PERISPOMENI
1FF7 GREEK SMALL LETTER OMEGA WITH PERISPOMENI AND YPOGEGRAMMENI
1FF8 GREEK CAPITAL LETTER OMICRON WITH VARIA
1FF9 GREEK CAPITAL LETTER OMICRON WITH OXIA
1FFA GREEK CAPITAL LETTER OMEGA WITH VARIA
1FFB GREEK CAPITAL LETTER OMEGA WITH OXIA
1FFC GREEK CAPITAL LETTER OMEGA WITH PROSGEGRAMMENI
1FFD GREEK OXIA
1FFE GREEK DASIA
2000 EN QUAD
2001 EM QUAD
2002 EN SPACE
2003 EM SPACE
2004 THREE-PER-EM SPACE
2005 FOUR-PER-EM SPACE
2006 SIX-PER-EM SPACE
2007 FIGURE SPACE
2008 PUNCTUATION SPACE
2009 THIN SPACE
200A HAIR SPACE
200B ZERO WIDTH SPACE
200C ZERO WIDTH NON-JOINER
200D ZERO WIDTH JOINER
200E LEFT-TO-RIGHT MARK
200F RIGHT-TO-LEFT MARK
2010 HYPHEN
2011 NON-BREAKING HYPHEN
2012 FIGURE DASH
2013 EN DASH
2014 EM DASH
2015 HORIZONTAL BAR
2016 DOUBLE VERTICAL LINE
2017 DOUBLE LOW LINE
2018 LEFT SINGLE QUOTATION MARK
2019 RIGHT SINGLE QUOTATION MARK
201A SINGLE LOW-9 QUOTATION MARK
201B SINGLE HIGH-REVERSED-9 QUOTATION MARK
201C LEFT DOUBLE QUOTATION MARK
201D RIGHT DOUBLE QUOTATION MARK
201E DOUBLE LOW-9 QUOTATION MARK
201F DOUBLE HIGH-REVERSED-9 QUOTATION MARK
2020 DAGGER
2021 DOUBLE DAGGER
2022 BULLET
2023 TRIANGULAR BULLET
2024 ONE DOT LEADER
2025 TWO DOT LEADER
2026 HORIZONTAL ELLIPSIS
2027 HYPHENATION POINT
2028 LINE SEPARATOR
2029 PARAGRAPH SEPARATOR
202A LEFT-TO-RIGHT EMBEDDING
202B RIGHT-TO-LEFT EMBEDDING
202C POP DIRECTIONAL FORMATTING
202D LEFT-TO-RIGHT OVERRIDE
202E RIGHT-TO-LEFT OVERRIDE
202F NARROW NO-BREAK SPACE
2030 PER MILLE SIGN
2031 PER TEN THOUSAND SIGN
2032 PRIME
2033 DOUBLE PRIME
2034 TRIPLE PRIME
2035 REVERSED PRIME
2036 REVERSED DOUBLE PRIME
2037 REVERSED TRIPLE PRIME
2038 CARET
2039 SINGLE LEFT-POINTING ANGLE QUOTATION MARK
203A SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
203B REFERENCE MARK
203C DOUBLE EXCLAMATION MARK
203D INTERROBANG
203E OVERLINE
203F UNDERTIE
2040 CHARACTER TIE
2041 CARET INSERTION POINT
2042 ASTERISM
2043 HYPHEN BULLET
2044 FRACTION SLASH
2045 LEFT SQUARE BRACKET WITH QUILL
2046 RIGHT SQUARE BRACKET WITH QUILL
2047 DOUBLE QUESTION MARK
2048 QUESTION EXCLAMATION MARK
2049 EXCLAMATION QUESTION MARK
204A TIRONIAN SIGN ET
204B REVERSED PILCROW SIGN
204C BLACK LEFTWARDS BULLET
204D BLACK RIGHTWARDS BULLET
204E LOW ASTERISK
204F REVERSED SEMICOLON
2050 CLOSE UP
2051 TWO ASTERISKS ALIGNED VERTICALLY
2052 COMMERCIAL MINUS SIGN
2053 SWUNG DASH
2054 INVERTED UNDERTIE
2055 FLOWER PUNCTUATION MARK
2056 THREE DOT PUNCTUATION
2057 QUADRUPLE PRIME
2058 FOUR DOT PUNCTUATION
2059 FIVE DOT PUNCTUATION
205A TWO DOT PUNCTUATION
205B FOUR DOT MARK
205C DOTTED CROSS
205D TRICOLON
205E VERTICAL FOUR DOTS
205F MEDIUM MATHEMATICAL SPACE
2060 WORD JOINER
2061 FUNCTION APPLICATION
2062 INVISIBLE TIMES
2063 INVISIBLE SEPARATOR
206A INHIBIT SYMMETRIC SWAPPING
206B ACTIVATE SYMMETRIC SWAPPING
206C INHIBIT ARABIC FORM SHAPING
206D ACTIVATE ARABIC FORM SHAPING
206E NATIONAL DIGIT SHAPES
206F NOMINAL DIGIT SHAPES
2070 SUPERSCRIPT ZERO
2071 SUPERSCRIPT LATIN SMALL LETTER I
2074 SUPERSCRIPT FOUR
2075 SUPERSCRIPT FIVE
2076 SUPERSCRIPT SIX
2077 SUPERSCRIPT SEVEN
2078 SUPERSCRIPT EIGHT
2079 SUPERSCRIPT NINE
207A SUPERSCRIPT PLUS SIGN
207B SUPERSCRIPT MINUS
207C SUPERSCRIPT EQUALS SIGN
207D SUPERSCRIPT LEFT PARENTHESIS
207E SUPERSCRIPT RIGHT PARENTHESIS
207F SUPERSCRIPT LATIN SMALL LETTER N
2080 SUBSCRIPT ZERO
2081 SUBSCRIPT ONE
2082 SUBSCRIPT TWO
2083 SUBSCRIPT THREE
2084 SUBSCRIPT FOUR
2085 SUBSCRIPT FIVE
2086 SUBSCRIPT SIX
2087 SUBSCRIPT SEVEN
2088 SUBSCRIPT EIGHT
2089 SUBSCRIPT NINE
208A SUBSCRIPT PLUS SIGN
208B SUBSCRIPT MINUS
208C SUBSCRIPT EQUALS SIGN
208D SUBSCRIPT LEFT PARENTHESIS
208E SUBSCRIPT RIGHT PARENTHESIS
2090 LATIN SUBSCRIPT SMALL LETTER A
2091 LATIN SUBSCRIPT SMALL LETTER E
2092 LATIN SUBSCRIPT SMALL LETTER O
2093 LATIN SUBSCRIPT SMALL LETTER X
2094 LATIN SUBSCRIPT SMALL LETTER SCHWA
20A0 EURO-CURRENCY SIGN
20A1 COLON SIGN
20A2 CRUZEIRO SIGN
20A3 FRENCH FRANC SIGN
20A4 LIRA SIGN
20A5 MILL SIGN
20A6 NAIRA SIGN
20A7 PESETA SIGN
20A8 RUPEE SIGN
20A9 WON SIGN
20AA NEW SHEQEL SIGN
20AB DONG SIGN
20AC EURO SIGN
20AD KIP SIGN
20AE TUGRIK SIGN
20AF DRACHMA SIGN
20B0 GERMAN PENNY SIGN
20B1 PESO SIGN
20B2 GUARANI SIGN
20B3 AUSTRAL SIGN
20B4 HRYVNIA SIGN
20B5 CEDI SIGN
20D0 COMBINING LEFT HARPOON ABOVE
20D1 COMBINING RIGHT HARPOON ABOVE
20D2 COMBINING LONG VERTICAL LINE OVERLAY
20D3 COMBINING SHORT VERTICAL LINE OVERLAY
20D4 COMBINING ANTICLOCKWISE ARROW ABOVE
20D5 COMBINING CLOCKWISE ARROW ABOVE
20D6 COMBINING LEFT ARROW ABOVE
20D7 COMBINING RIGHT ARROW ABOVE
20D8 COMBINING RING OVERLAY
20D9 COMBINING CLOCKWISE RING OVERLAY
20DA COMBINING ANTICLOCKWISE RING OVERLAY
20DB COMBINING THREE DOTS ABOVE
20DC COMBINING FOUR DOTS ABOVE
20DD COMBINING ENCLOSING CIRCLE
20DE COMBINING ENCLOSING SQUARE
20DF COMBINING ENCLOSING DIAMOND
20E0 COMBINING ENCLOSING CIRCLE BACKSLASH
20E1 COMBINING LEFT RIGHT ARROW ABOVE
20E2 COMBINING ENCLOSING SCREEN
20E3 COMBINING ENCLOSING KEYCAP
20E4 COMBINING ENCLOSING UPWARD POINTING TRIANGLE
20E5 COMBINING REVERSE SOLIDUS OVERLAY
20E6 COMBINING DOUBLE VERTICAL STROKE OVERLAY
20E7 COMBINING ANNUITY SYMBOL
20E8 COMBINING TRIPLE UNDERDOT
20E9 COMBINING WIDE BRIDGE ABOVE
20EA COMBINING LEFTWARDS ARROW OVERLAY
20EB COMBINING LONG DOUBLE SOLIDUS OVERLAY
2100 ACCOUNT OF
2101 ADDRESSED TO THE SUBJECT
2102 DOUBLE-STRUCK CAPITAL C
2103 DEGREE CELSIUS
2104 CENTRE LINE SYMBOL
2105 CARE OF
2106 CADA UNA
2107 EULER CONSTANT
2108 SCRUPLE
2109 DEGREE FAHRENHEIT
210A SCRIPT SMALL G
210B SCRIPT CAPITAL H
210C BLACK-LETTER CAPITAL H
210D DOUBLE-STRUCK CAPITAL H
210E PLANCK CONSTANT
210F PLANCK CONSTANT OVER TWO PI
2110 SCRIPT CAPITAL I
2111 BLACK-LETTER CAPITAL I
2112 SCRIPT CAPITAL L
2113 SCRIPT SMALL L
2114 L B BAR SYMBOL
2115 DOUBLE-STRUCK CAPITAL N
2116 NUMERO SIGN
2117 SOUND RECORDING COPYRIGHT
2118 SCRIPT CAPITAL P
2119 DOUBLE-STRUCK CAPITAL P
211A DOUBLE-STRUCK CAPITAL Q
211B SCRIPT CAPITAL R
211C BLACK-LETTER CAPITAL R
211D DOUBLE-STRUCK CAPITAL R
211E PRESCRIPTION TAKE
211F RESPONSE
2120 SERVICE MARK
2121 TELEPHONE SIGN
2122 TRADE MARK SIGN
2123 VERSICLE
2124 DOUBLE-STRUCK CAPITAL Z
2125 OUNCE SIGN
2126 OHM SIGN
2127 INVERTED OHM SIGN
2128 BLACK-LETTER CAPITAL Z
2129 TURNED GREEK SMALL LETTER IOTA
212A KELVIN SIGN
212B ANGSTROM SIGN
212C SCRIPT CAPITAL B
212D BLACK-LETTER CAPITAL C
212E ESTIMATED SYMBOL
212F SCRIPT SMALL E
2130 SCRIPT CAPITAL E
2131 SCRIPT CAPITAL F
2132 TURNED CAPITAL F
2133 SCRIPT CAPITAL M
2134 SCRIPT SMALL O
2135 ALEF SYMBOL
2136 BET SYMBOL
2137 GIMEL SYMBOL
2138 DALET SYMBOL
2139 INFORMATION SOURCE
213A ROTATED CAPITAL Q
213B FACSIMILE SIGN
213C DOUBLE-STRUCK SMALL PI
213D DOUBLE-STRUCK SMALL GAMMA
213E DOUBLE-STRUCK CAPITAL GAMMA
213F DOUBLE-STRUCK CAPITAL PI
2140 DOUBLE-STRUCK N-ARY SUMMATION
2141 TURNED SANS-SERIF CAPITAL G
2142 TURNED SANS-SERIF CAPITAL L
2143 REVERSED SANS-SERIF CAPITAL L
2144 TURNED SANS-SERIF CAPITAL Y
2145 DOUBLE-STRUCK ITALIC CAPITAL D
2146 DOUBLE-STRUCK ITALIC SMALL D
2147 DOUBLE-STRUCK ITALIC SMALL E
2148 DOUBLE-STRUCK ITALIC SMALL I
2149 DOUBLE-STRUCK ITALIC SMALL J
214A PROPERTY LINE
214B TURNED AMPERSAND
214C PER SIGN
2153 VULGAR FRACTION ONE THIRD
2154 VULGAR FRACTION TWO THIRDS
2155 VULGAR FRACTION ONE FIFTH
2156 VULGAR FRACTION TWO FIFTHS
2157 VULGAR FRACTION THREE FIFTHS
2158 VULGAR FRACTION FOUR FIFTHS
2159 VULGAR FRACTION ONE SIXTH
215A VULGAR FRACTION FIVE SIXTHS
215B VULGAR FRACTION ONE EIGHTH
215C VULGAR FRACTION THREE EIGHTHS
215D VULGAR FRACTION FIVE EIGHTHS
215E VULGAR FRACTION SEVEN EIGHTHS
215F FRACTION NUMERATOR ONE
2160 ROMAN NUMERAL ONE
2161 ROMAN NUMERAL TWO
2162 ROMAN NUMERAL THREE
2163 ROMAN NUMERAL FOUR
2164 ROMAN NUMERAL FIVE
2165 ROMAN NUMERAL SIX
2166 ROMAN NUMERAL SEVEN
2167 ROMAN NUMERAL EIGHT
2168 ROMAN NUMERAL NINE
2169 ROMAN NUMERAL TEN
216A ROMAN NUMERAL ELEVEN
216B ROMAN NUMERAL TWELVE
216C ROMAN NUMERAL FIFTY
216D ROMAN NUMERAL ONE HUNDRED
216E ROMAN NUMERAL FIVE HUNDRED
216F ROMAN NUMERAL ONE THOUSAND
2170 SMALL ROMAN NUMERAL ONE
2171 SMALL ROMAN NUMERAL TWO
2172 SMALL ROMAN NUMERAL THREE
2173 SMALL ROMAN NUMERAL FOUR
2174 SMALL ROMAN NUMERAL FIVE
2175 SMALL ROMAN NUMERAL SIX
2176 SMALL ROMAN NUMERAL SEVEN
2177 SMALL ROMAN NUMERAL EIGHT
2178 SMALL ROMAN NUMERAL NINE
2179 SMALL ROMAN NUMERAL TEN
217A SMALL ROMAN NUMERAL ELEVEN
217B SMALL ROMAN NUMERAL TWELVE
217C SMALL ROMAN NUMERAL FIFTY
217D SMALL ROMAN NUMERAL ONE HUNDRED
217E SMALL ROMAN NUMERAL FIVE HUNDRED
217F SMALL ROMAN NUMERAL ONE THOUSAND
2180 ROMAN NUMERAL ONE THOUSAND C D
2181 ROMAN NUMERAL FIVE THOUSAND
2182 ROMAN NUMERAL TEN THOUSAND
2183 ROMAN NUMERAL REVERSED ONE HUNDRED
2190 LEFTWARDS ARROW
2191 UPWARDS ARROW
2192 RIGHTWARDS ARROW
2193 DOWNWARDS ARROW
2194 LEFT RIGHT ARROW
2195 UP DOWN ARROW
2196 NORTH WEST ARROW
2197 NORTH EAST ARROW
2198 SOUTH EAST ARROW
2199 SOUTH WEST ARROW
219A LEFTWARDS ARROW WITH STROKE
219B RIGHTWARDS ARROW WITH STROKE
219C LEFTWARDS WAVE ARROW
219D RIGHTWARDS WAVE ARROW
219E LEFTWARDS TWO HEADED ARROW
219F UPWARDS TWO HEADED ARROW
21A0 RIGHTWARDS TWO HEADED ARROW
21A1 DOWNWARDS TWO HEADED ARROW
21A2 LEFTWARDS ARROW WITH TAIL
21A3 RIGHTWARDS ARROW WITH TAIL
21A4 LEFTWARDS ARROW FROM BAR
21A5 UPWARDS ARROW FROM BAR
21A6 RIGHTWARDS ARROW FROM BAR
21A7 DOWNWARDS ARROW FROM BAR
21A8 UP DOWN ARROW WITH BASE
21A9 LEFTWARDS ARROW WITH HOOK
21AA RIGHTWARDS ARROW WITH HOOK
21AB LEFTWARDS ARROW WITH LOOP
21AC RIGHTWARDS ARROW WITH LOOP
21AD LEFT RIGHT WAVE ARROW
21AE LEFT RIGHT ARROW WITH STROKE
21AF DOWNWARDS ZIGZAG ARROW
21B0 UPWARDS ARROW WITH TIP LEFTWARDS
21B1 UPWARDS ARROW WITH TIP RIGHTWARDS
21B2 DOWNWARDS ARROW WITH TIP LEFTWARDS
21B3 DOWNWARDS ARROW WITH TIP RIGHTWARDS
21B4 RIGHTWARDS ARROW WITH CORNER DOWNWARDS
21B5 DOWNWARDS ARROW WITH CORNER LEFTWARDS
21B6 ANTICLOCKWISE TOP SEMICIRCLE ARROW
21B7 CLOCKWISE TOP SEMICIRCLE ARROW
21B8 NORTH WEST ARROW TO LONG BAR
21B9 LEFTWARDS ARROW TO BAR OVER RIGHTWARDS ARROW TO BAR
21BA ANTICLOCKWISE OPEN CIRCLE ARROW
21BB CLOCKWISE OPEN CIRCLE ARROW
21BC LEFTWARDS HARPOON WITH BARB UPWARDS
21BD LEFTWARDS HARPOON WITH BARB DOWNWARDS
21BE UPWARDS HARPOON WITH BARB RIGHTWARDS
21BF UPWARDS HARPOON WITH BARB LEFTWARDS
21C0 RIGHTWARDS HARPOON WITH BARB UPWARDS
21C1 RIGHTWARDS HARPOON WITH BARB DOWNWARDS
21C2 DOWNWARDS HARPOON WITH BARB RIGHTWARDS
21C3 DOWNWARDS HARPOON WITH BARB LEFTWARDS
21C4 RIGHTWARDS ARROW OVER LEFTWARDS ARROW
21C5 UPWARDS ARROW LEFTWARDS OF DOWNWARDS ARROW
21C6 LEFTWARDS ARROW OVER RIGHTWARDS ARROW
21C7 LEFTWARDS PAIRED ARROWS
21C8 UPWARDS PAIRED ARROWS
21C9 RIGHTWARDS PAIRED ARROWS
21CA DOWNWARDS PAIRED ARROWS
21CB LEFTWARDS HARPOON OVER RIGHTWARDS HARPOON
21CC RIGHTWARDS HARPOON OVER LEFTWARDS HARPOON
21CD LEFTWARDS DOUBLE ARROW WITH STROKE
21CE LEFT RIGHT DOUBLE ARROW WITH STROKE
21CF RIGHTWARDS DOUBLE ARROW WITH STROKE
21D0 LEFTWARDS DOUBLE ARROW
21D1 UPWARDS DOUBLE ARROW
21D2 RIGHTWARDS DOUBLE ARROW
21D3 DOWNWARDS DOUBLE ARROW
21D4 LEFT RIGHT DOUBLE ARROW
21D5 UP DOWN DOUBLE ARROW
21D6 NORTH WEST DOUBLE ARROW
21D7 NORTH EAST DOUBLE ARROW
21D8 SOUTH EAST DOUBLE ARROW
21D9 SOUTH WEST DOUBLE ARROW
21DA LEFTWARDS TRIPLE ARROW
21DB RIGHTWARDS TRIPLE ARROW
21DC LEFTWARDS SQUIGGLE ARROW
21DD RIGHTWARDS SQUIGGLE ARROW
21DE UPWARDS ARROW WITH DOUBLE STROKE
21DF DOWNWARDS ARROW WITH DOUBLE STROKE
21E0 LEFTWARDS DASHED ARROW
21E1 UPWARDS DASHED ARROW
21E2 RIGHTWARDS DASHED ARROW
21E3 DOWNWARDS DASHED ARROW
21E4 LEFTWARDS ARROW TO BAR
21E5 RIGHTWARDS ARROW TO BAR
21E6 LEFTWARDS WHITE ARROW
21E7 UPWARDS WHITE ARROW
21E8 RIGHTWARDS WHITE ARROW
21E9 DOWNWARDS WHITE ARROW
21EA UPWARDS WHITE ARROW FROM BAR
21EB UPWARDS WHITE ARROW ON PEDESTAL
21EC UPWARDS WHITE ARROW ON PEDESTAL WITH HORIZONTAL BAR
21ED UPWARDS WHITE ARROW ON PEDESTAL WITH VERTICAL BAR
21EE UPWARDS WHITE DOUBLE ARROW
21EF UPWARDS WHITE DOUBLE ARROW ON PEDESTAL
21F0 RIGHTWARDS WHITE ARROW FROM WALL
21F1 NORTH WEST ARROW TO CORNER
21F2 SOUTH EAST ARROW TO CORNER
21F3 UP DOWN WHITE ARROW
21F4 RIGHT ARROW WITH SMALL CIRCLE
21F5 DOWNWARDS ARROW LEFTWARDS OF UPWARDS ARROW
21F6 THREE RIGHTWARDS ARROWS
21F7 LEFTWARDS ARROW WITH VERTICAL STROKE
21F8 RIGHTWARDS ARROW WITH VERTICAL STROKE
21F9 LEFT RIGHT ARROW WITH VERTICAL STROKE
21FA LEFTWARDS ARROW WITH DOUBLE VERTICAL STROKE
21FB RIGHTWARDS ARROW WITH DOUBLE VERTICAL STROKE
21FC LEFT RIGHT ARROW WITH DOUBLE VERTICAL STROKE
21FD LEFTWARDS OPEN-HEADED ARROW
21FE RIGHTWARDS OPEN-HEADED ARROW
21FF LEFT RIGHT OPEN-HEADED ARROW
2200 FOR ALL
2201 COMPLEMENT
2202 PARTIAL DIFFERENTIAL
2203 THERE EXISTS
2204 THERE DOES NOT EXIST
2205 EMPTY SET
2206 INCREMENT
2207 NABLA
2208 ELEMENT OF
2209 NOT AN ELEMENT OF
220A SMALL ELEMENT OF
220B CONTAINS AS MEMBER
220C DOES NOT CONTAIN AS MEMBER
220D SMALL CONTAINS AS MEMBER
220E END OF PROOF
220F N-ARY PRODUCT
2210 N-ARY COPRODUCT
2211 N-ARY SUMMATION
2212 MINUS SIGN
2213 MINUS-OR-PLUS SIGN
2214 DOT PLUS
2215 DIVISION SLASH
2216 SET MINUS
2217 ASTERISK OPERATOR
2218 RING OPERATOR
2219 BULLET OPERATOR
221A SQUARE ROOT
221B CUBE ROOT
221C FOURTH ROOT
221D PROPORTIONAL TO
221E INFINITY
221F RIGHT ANGLE
2220 ANGLE
2221 MEASURED ANGLE
2222 SPHERICAL ANGLE
2223 DIVIDES
2224 DOES NOT DIVIDE
2225 PARALLEL TO
2226 NOT PARALLEL TO
2227 LOGICAL AND
2228 LOGICAL OR
2229 INTERSECTION
222A UNION
222B INTEGRAL
222C DOUBLE INTEGRAL
222D TRIPLE INTEGRAL
222E CONTOUR INTEGRAL
222F SURFACE INTEGRAL
2230 VOLUME INTEGRAL
2231 CLOCKWISE INTEGRAL
2232 CLOCKWISE CONTOUR INTEGRAL
2233 ANTICLOCKWISE CONTOUR INTEGRAL
2234 THEREFORE
2235 BECAUSE
2236 RATIO
2237 PROPORTION
2238 DOT MINUS
2239 EXCESS
223A GEOMETRIC PROPORTION
223B HOMOTHETIC
223C TILDE OPERATOR
223D REVERSED TILDE
223E INVERTED LAZY S
223F SINE WAVE
2240 WREATH PRODUCT
2241 NOT TILDE
2242 MINUS TILDE
2243 ASYMPTOTICALLY EQUAL TO
2244 NOT ASYMPTOTICALLY EQUAL TO
2245 APPROXIMATELY EQUAL TO
2246 APPROXIMATELY BUT NOT ACTUALLY EQUAL TO
2247 NEITHER APPROXIMATELY NOR ACTUALLY EQUAL TO
2248 ALMOST EQUAL TO
2249 NOT ALMOST EQUAL TO
224A ALMOST EQUAL OR EQUAL TO
224B TRIPLE TILDE
224C ALL EQUAL TO
224D EQUIVALENT TO
224E GEOMETRICALLY EQUIVALENT TO
224F DIFFERENCE BETWEEN
2250 APPROACHES THE LIMIT
2251 GEOMETRICALLY EQUAL TO
2252 APPROXIMATELY EQUAL TO OR THE IMAGE OF
2253 IMAGE OF OR APPROXIMATELY EQUAL TO
2254 COLON EQUALS
2255 EQUALS COLON
2256 RING IN EQUAL TO
2257 RING EQUAL TO
2258 CORRESPONDS TO
2259 ESTIMATES
225A EQUIANGULAR TO
225B STAR EQUALS
225C DELTA EQUAL TO
225D EQUAL TO BY DEFINITION
225E MEASURED BY
225F QUESTIONED EQUAL TO
2260 NOT EQUAL TO
2261 IDENTICAL TO
2262 NOT IDENTICAL TO
2263 STRICTLY EQUIVALENT TO
2264 LESS-THAN OR EQUAL TO
2265 GREATER-THAN OR EQUAL TO
2266 LESS-THAN OVER EQUAL TO
2267 GREATER-THAN OVER EQUAL TO
2268 LESS-THAN BUT NOT EQUAL TO
2269 GREATER-THAN BUT NOT EQUAL TO
226A MUCH LESS-THAN
226B MUCH GREATER-THAN
226C BETWEEN
226D NOT EQUIVALENT TO
226E NOT LESS-THAN
226F NOT GREATER-THAN
2270 NEITHER LESS-THAN NOR EQUAL TO
2271 NEITHER GREATER-THAN NOR EQUAL TO
2272 LESS-THAN OR EQUIVALENT TO
2273 GREATER-THAN OR EQUIVALENT TO
2274 NEITHER LESS-THAN NOR EQUIVALENT TO
2275 NEITHER GREATER-THAN NOR EQUIVALENT TO
2276 LESS-THAN OR GREATER-THAN
2277 GREATER-THAN OR LESS-THAN
2278 NEITHER LESS-THAN NOR GREATER-THAN
2279 NEITHER GREATER-THAN NOR LESS-THAN
227A PRECEDES
227B SUCCEEDS
227C PRECEDES OR EQUAL TO
227D SUCCEEDS OR EQUAL TO
227E PRECEDES OR EQUIVALENT TO
227F SUCCEEDS OR EQUIVALENT TO
2280 DOES NOT PRECEDE
2281 DOES NOT SUCCEED
2282 SUBSET OF
2283 SUPERSET OF
2284 NOT A SUBSET OF
2285 NOT A SUPERSET OF
2286 SUBSET OF OR EQUAL TO
2287 SUPERSET OF OR EQUAL TO
2288 NEITHER A SUBSET OF NOR EQUAL TO
2289 NEITHER A SUPERSET OF NOR EQUAL TO
228A SUBSET OF WITH NOT EQUAL TO
228B SUPERSET OF WITH NOT EQUAL TO
228C MULTISET
228D MULTISET MULTIPLICATION
228E MULTISET UNION
228F SQUARE IMAGE OF
2290 SQUARE ORIGINAL OF
2291 SQUARE IMAGE OF OR EQUAL TO
2292 SQUARE ORIGINAL OF OR EQUAL TO
2293 SQUARE CAP
2294 SQUARE CUP
2295 CIRCLED PLUS
2296 CIRCLED MINUS
2297 CIRCLED TIMES
2298 CIRCLED DIVISION SLASH
2299 CIRCLED DOT OPERATOR
229A CIRCLED RING OPERATOR
229B CIRCLED ASTERISK OPERATOR
229C CIRCLED EQUALS
229D CIRCLED DASH
229E SQUARED PLUS
229F SQUARED MINUS
22A0 SQUARED TIMES
22A1 SQUARED DOT OPERATOR
22A2 RIGHT TACK
22A3 LEFT TACK
22A4 DOWN TACK
22A5 UP TACK
22A6 ASSERTION
22A7 MODELS
22A8 TRUE
22A9 FORCES
22AA TRIPLE VERTICAL BAR RIGHT TURNSTILE
22AB DOUBLE VERTICAL BAR DOUBLE RIGHT TURNSTILE
22AC DOES NOT PROVE
22AD NOT TRUE
22AE DOES NOT FORCE
22AF NEGATED DOUBLE VERTICAL BAR DOUBLE RIGHT TURNSTILE
22B0 PRECEDES UNDER RELATION
22B1 SUCCEEDS UNDER RELATION
22B2 NORMAL SUBGROUP OF
22B3 CONTAINS AS NORMAL SUBGROUP
22B4 NORMAL SUBGROUP OF OR EQUAL TO
22B5 CONTAINS AS NORMAL SUBGROUP OR EQUAL TO
22B6 ORIGINAL OF
22B7 IMAGE OF
22B8 MULTIMAP
22B9 HERMITIAN CONJUGATE MATRIX
22BA INTERCALATE
22BB XOR
22BC NAND
22BD NOR
22BE RIGHT ANGLE WITH ARC
22BF RIGHT TRIANGLE
22C0 N-ARY LOGICAL AND
22C1 N-ARY LOGICAL OR
22C2 N-ARY INTERSECTION
22C3 N-ARY UNION
22C4 DIAMOND OPERATOR
22C5 DOT OPERATOR
22C6 STAR OPERATOR
22C7 DIVISION TIMES
22C8 BOWTIE
22C9 LEFT NORMAL FACTOR SEMIDIRECT PRODUCT
22CA RIGHT NORMAL FACTOR SEMIDIRECT PRODUCT
22CB LEFT SEMIDIRECT PRODUCT
22CC RIGHT SEMIDIRECT PRODUCT
22CD REVERSED TILDE EQUALS
22CE CURLY LOGICAL OR
22CF CURLY LOGICAL AND
22D0 DOUBLE SUBSET
22D1 DOUBLE SUPERSET
22D2 DOUBLE INTERSECTION
22D3 DOUBLE UNION
22D4 PITCHFORK
22D5 EQUAL AND PARALLEL TO
22D6 LESS-THAN WITH DOT
22D7 GREATER-THAN WITH DOT
22D8 VERY MUCH LESS-THAN
22D9 VERY MUCH GREATER-THAN
22DA LESS-THAN EQUAL TO OR GREATER-THAN
22DB GREATER-THAN EQUAL TO OR LESS-THAN
22DC EQUAL TO OR LESS-THAN
22DD EQUAL TO OR GREATER-THAN
22DE EQUAL TO OR PRECEDES
22DF EQUAL TO OR SUCCEEDS
22E0 DOES NOT PRECEDE OR EQUAL
22E1 DOES NOT SUCCEED OR EQUAL
22E2 NOT SQUARE IMAGE OF OR EQUAL TO
22E3 NOT SQUARE ORIGINAL OF OR EQUAL TO
22E4 SQUARE IMAGE OF OR NOT EQUAL TO
22E5 SQUARE ORIGINAL OF OR NOT EQUAL TO
22E6 LESS-THAN BUT NOT EQUIVALENT TO
22E7 GREATER-THAN BUT NOT EQUIVALENT TO
22E8 PRECEDES BUT NOT EQUIVALENT TO
22E9 SUCCEEDS BUT NOT EQUIVALENT TO
22EA NOT NORMAL SUBGROUP OF
22EB DOES NOT CONTAIN AS NORMAL SUBGROUP
22EC NOT NORMAL SUBGROUP OF OR EQUAL TO
22ED DOES NOT CONTAIN AS NORMAL SUBGROUP OR EQUAL
22EE VERTICAL ELLIPSIS
22EF MIDLINE HORIZONTAL ELLIPSIS
22F0 UP RIGHT DIAGONAL ELLIPSIS
22F1 DOWN RIGHT DIAGONAL ELLIPSIS
22F2 ELEMENT OF WITH LONG HORIZONTAL STROKE
22F3 ELEMENT OF WITH VERTICAL BAR AT END OF HORIZONTAL STROKE
22F4 SMALL ELEMENT OF WITH VERTICAL BAR AT END OF HORIZONTAL STROKE
22F5 ELEMENT OF WITH DOT ABOVE
22F6 ELEMENT OF WITH OVERBAR
22F7 SMALL ELEMENT OF WITH OVERBAR
22F8 ELEMENT OF WITH UNDERBAR
22F9 ELEMENT OF WITH TWO HORIZONTAL STROKES
22FA CONTAINS WITH LONG HORIZONTAL STROKE
22FB CONTAINS WITH VERTICAL BAR AT END OF HORIZONTAL STROKE
22FC SMALL CONTAINS WITH VERTICAL BAR AT END OF HORIZONTAL STROKE
22FD CONTAINS WITH OVERBAR
22FE SMALL CONTAINS WITH OVERBAR
22FF Z NOTATION BAG MEMBERSHIP
2300 DIAMETER SIGN
2301 ELECTRIC ARROW
2302 HOUSE
2303 UP ARROWHEAD
2304 DOWN ARROWHEAD
2305 PROJECTIVE
2306 PERSPECTIVE
2307 WAVY LINE
2308 LEFT CEILING
2309 RIGHT CEILING
230A LEFT FLOOR
230B RIGHT FLOOR
230C BOTTOM RIGHT CROP
230D BOTTOM LEFT CROP
230E TOP RIGHT CROP
230F TOP LEFT CROP
2310 REVERSED NOT SIGN
2311 SQUARE LOZENGE
2312 ARC
2313 SEGMENT
2314 SECTOR
2315 TELEPHONE RECORDER
2316 POSITION INDICATOR
2317 VIEWDATA SQUARE
2318 PLACE OF INTEREST SIGN
2319 TURNED NOT SIGN
231A WATCH
231B HOURGLASS
231C TOP LEFT CORNER
231D TOP RIGHT CORNER
231E BOTTOM LEFT CORNER
231F BOTTOM RIGHT CORNER
2320 TOP HALF INTEGRAL
2321 BOTTOM HALF INTEGRAL
2322 FROWN
2323 SMILE
2324 UP ARROWHEAD BETWEEN TWO HORIZONTAL BARS
2325 OPTION KEY
2326 ERASE TO THE RIGHT
2327 X IN A RECTANGLE BOX
2328 KEYBOARD
2329 LEFT-POINTING ANGLE BRACKET
232A RIGHT-POINTING ANGLE BRACKET
232B ERASE TO THE LEFT
232C BENZENE RING
232D CYLINDRICITY
232E ALL AROUND-PROFILE
232F SYMMETRY
2330 TOTAL RUNOUT
2331 DIMENSION ORIGIN
2332 CONICAL TAPER
2333 SLOPE
2334 COUNTERBORE
2335 COUNTERSINK
2336 APL FUNCTIONAL SYMBOL I-BEAM
2337 APL FUNCTIONAL SYMBOL SQUISH QUAD
2338 APL FUNCTIONAL SYMBOL QUAD EQUAL
2339 APL FUNCTIONAL SYMBOL QUAD DIVIDE
233A APL FUNCTIONAL SYMBOL QUAD DIAMOND
233B APL FUNCTIONAL SYMBOL QUAD JOT
233C APL FUNCTIONAL SYMBOL QUAD CIRCLE
233D APL FUNCTIONAL SYMBOL CIRCLE STILE
233E APL FUNCTIONAL SYMBOL CIRCLE JOT
233F APL FUNCTIONAL SYMBOL SLASH BAR
2340 APL FUNCTIONAL SYMBOL BACKSLASH BAR
2341 APL FUNCTIONAL SYMBOL QUAD SLASH
2342 APL FUNCTIONAL SYMBOL QUAD BACKSLASH
2343 APL FUNCTIONAL SYMBOL QUAD LESS-THAN
2344 APL FUNCTIONAL SYMBOL QUAD GREATER-THAN
2345 APL FUNCTIONAL SYMBOL LEFTWARDS VANE
2346 APL FUNCTIONAL SYMBOL RIGHTWARDS VANE
2347 APL FUNCTIONAL SYMBOL QUAD LEFTWARDS ARROW
2348 APL FUNCTIONAL SYMBOL QUAD RIGHTWARDS ARROW
2349 APL FUNCTIONAL SYMBOL CIRCLE BACKSLASH
234A APL FUNCTIONAL SYMBOL DOWN TACK UNDERBAR
234B APL FUNCTIONAL SYMBOL DELTA STILE
234C APL FUNCTIONAL SYMBOL QUAD DOWN CARET
234D APL FUNCTIONAL SYMBOL QUAD DELTA
234E APL FUNCTIONAL SYMBOL DOWN TACK JOT
234F APL FUNCTIONAL SYMBOL UPWARDS VANE
2350 APL FUNCTIONAL SYMBOL QUAD UPWARDS ARROW
2351 APL FUNCTIONAL SYMBOL UP TACK OVERBAR
2352 APL FUNCTIONAL SYMBOL DEL STILE
2353 APL FUNCTIONAL SYMBOL QUAD UP CARET
2354 APL FUNCTIONAL SYMBOL QUAD DEL
2355 APL FUNCTIONAL SYMBOL UP TACK JOT
2356 APL FUNCTIONAL SYMBOL DOWNWARDS VANE
2357 APL FUNCTIONAL SYMBOL QUAD DOWNWARDS ARROW
2358 APL FUNCTIONAL SYMBOL QUOTE UNDERBAR
2359 APL FUNCTIONAL SYMBOL DELTA UNDERBAR
235A APL FUNCTIONAL SYMBOL DIAMOND UNDERBAR
235B APL FUNCTIONAL SYMBOL JOT UNDERBAR
235C APL FUNCTIONAL SYMBOL CIRCLE UNDERBAR
235D APL FUNCTIONAL SYMBOL UP SHOE JOT
235E APL FUNCTIONAL SYMBOL QUOTE QUAD
235F APL FUNCTIONAL SYMBOL CIRCLE STAR
2360 APL FUNCTIONAL SYMBOL QUAD COLON
2361 APL FUNCTIONAL SYMBOL UP TACK DIAERESIS
2362 APL FUNCTIONAL SYMBOL DEL DIAERESIS
2363 APL FUNCTIONAL SYMBOL STAR DIAERESIS
2364 APL FUNCTIONAL SYMBOL JOT DIAERESIS
2365 APL FUNCTIONAL SYMBOL CIRCLE DIAERESIS
2366 APL FUNCTIONAL SYMBOL DOWN SHOE STILE
2367 APL FUNCTIONAL SYMBOL LEFT SHOE STILE
2368 APL FUNCTIONAL SYMBOL TILDE DIAERESIS
2369 APL FUNCTIONAL SYMBOL GREATER-THAN DIAERESIS
236A APL FUNCTIONAL SYMBOL COMMA BAR
236B APL FUNCTIONAL SYMBOL DEL TILDE
236C APL FUNCTIONAL SYMBOL ZILDE
236D APL FUNCTIONAL SYMBOL STILE TILDE
236E APL FUNCTIONAL SYMBOL SEMICOLON UNDERBAR
236F APL FUNCTIONAL SYMBOL QUAD NOT EQUAL
2370 APL FUNCTIONAL SYMBOL QUAD QUESTION
2371 APL FUNCTIONAL SYMBOL DOWN CARET TILDE
2372 APL FUNCTIONAL SYMBOL UP CARET TILDE
2373 APL FUNCTIONAL SYMBOL IOTA
2374 APL FUNCTIONAL SYMBOL RHO
2375 APL FUNCTIONAL SYMBOL OMEGA
2376 APL FUNCTIONAL SYMBOL ALPHA UNDERBAR
2377 APL FUNCTIONAL SYMBOL EPSILON UNDERBAR
2378 APL FUNCTIONAL SYMBOL IOTA UNDERBAR
2379 APL FUNCTIONAL SYMBOL OMEGA UNDERBAR
237A APL FUNCTIONAL SYMBOL ALPHA
237B NOT CHECK MARK
237C RIGHT ANGLE WITH DOWNWARDS ZIGZAG ARROW
237D SHOULDERED OPEN BOX
237E BELL SYMBOL
237F VERTICAL LINE WITH MIDDLE DOT
2380 INSERTION SYMBOL
2381 CONTINUOUS UNDERLINE SYMBOL
2382 DISCONTINUOUS UNDERLINE SYMBOL
2383 EMPHASIS SYMBOL
2384 COMPOSITION SYMBOL
2385 WHITE SQUARE WITH CENTRE VERTICAL LINE
2386 ENTER SYMBOL
2387 ALTERNATIVE KEY SYMBOL
2388 HELM SYMBOL
2389 CIRCLED HORIZONTAL BAR WITH NOTCH
238A CIRCLED TRIANGLE DOWN
238B BROKEN CIRCLE WITH NORTHWEST ARROW
238C UNDO SYMBOL
238D MONOSTABLE SYMBOL
238E HYSTERESIS SYMBOL
238F OPEN-CIRCUIT-OUTPUT H-TYPE SYMBOL
2390 OPEN-CIRCUIT-OUTPUT L-TYPE SYMBOL
2391 PASSIVE-PULL-DOWN-OUTPUT SYMBOL
2392 PASSIVE-PULL-UP-OUTPUT SYMBOL
2393 DIRECT CURRENT SYMBOL FORM TWO
2394 SOFTWARE-FUNCTION SYMBOL
2395 APL FUNCTIONAL SYMBOL QUAD
2396 DECIMAL SEPARATOR KEY SYMBOL
2397 PREVIOUS PAGE
2398 NEXT PAGE
2399 PRINT SCREEN SYMBOL
239A CLEAR SCREEN SYMBOL
239B LEFT PARENTHESIS UPPER HOOK
239C LEFT PARENTHESIS EXTENSION
239D LEFT PARENTHESIS LOWER HOOK
239E RIGHT PARENTHESIS UPPER HOOK
239F RIGHT PARENTHESIS EXTENSION
23A0 RIGHT PARENTHESIS LOWER HOOK
23A1 LEFT SQUARE BRACKET UPPER CORNER
23A2 LEFT SQUARE BRACKET EXTENSION
23A3 LEFT SQUARE BRACKET LOWER CORNER
23A4 RIGHT SQUARE BRACKET UPPER CORNER
23A5 RIGHT SQUARE BRACKET EXTENSION
23A6 RIGHT SQUARE BRACKET LOWER CORNER
23A7 LEFT CURLY BRACKET UPPER HOOK
23A8 LEFT CURLY BRACKET MIDDLE PIECE
23A9 LEFT CURLY BRACKET LOWER HOOK
23AA CURLY BRACKET EXTENSION
23AB RIGHT CURLY BRACKET UPPER HOOK
23AC RIGHT CURLY BRACKET MIDDLE PIECE
23AD RIGHT CURLY BRACKET LOWER HOOK
23AE INTEGRAL EXTENSION
23AF HORIZONTAL LINE EXTENSION
23B0 UPPER LEFT OR LOWER RIGHT CURLY BRACKET SECTION
23B1 UPPER RIGHT OR LOWER LEFT CURLY BRACKET SECTION
23B2 SUMMATION TOP
23B3 SUMMATION BOTTOM
23B4 TOP SQUARE BRACKET
23B5 BOTTOM SQUARE BRACKET
23B6 BOTTOM SQUARE BRACKET OVER TOP SQUARE BRACKET
23B7 RADICAL SYMBOL BOTTOM
23B8 LEFT VERTICAL BOX LINE
23B9 RIGHT VERTICAL BOX LINE
23BA HORIZONTAL SCAN LINE-1
23BB HORIZONTAL SCAN LINE-3
23BC HORIZONTAL SCAN LINE-7
23BD HORIZONTAL SCAN LINE-9
23BE DENTISTRY SYMBOL LIGHT VERTICAL AND TOP RIGHT
23BF DENTISTRY SYMBOL LIGHT VERTICAL AND BOTTOM RIGHT
23C0 DENTISTRY SYMBOL LIGHT VERTICAL WITH CIRCLE
23C1 DENTISTRY SYMBOL LIGHT DOWN AND HORIZONTAL WITH CIRCLE
23C2 DENTISTRY SYMBOL LIGHT UP AND HORIZONTAL WITH CIRCLE
23C3 DENTISTRY SYMBOL LIGHT VERTICAL WITH TRIANGLE
23C4 DENTISTRY SYMBOL LIGHT DOWN AND HORIZONTAL WITH TRIANGLE
23C5 DENTISTRY SYMBOL LIGHT UP AND HORIZONTAL WITH TRIANGLE
23C6 DENTISTRY SYMBOL LIGHT VERTICAL AND WAVE
23C7 DENTISTRY SYMBOL LIGHT DOWN AND HORIZONTAL WITH WAVE
23C8 DENTISTRY SYMBOL LIGHT UP AND HORIZONTAL WITH WAVE
23C9 DENTISTRY SYMBOL LIGHT DOWN AND HORIZONTAL
23CA DENTISTRY SYMBOL LIGHT UP AND HORIZONTAL
23CB DENTISTRY SYMBOL LIGHT VERTICAL AND TOP LEFT
23CC DENTISTRY SYMBOL LIGHT VERTICAL AND BOTTOM LEFT
23CD SQUARE FOOT
23CE RETURN SYMBOL
23CF EJECT SYMBOL
23D0 VERTICAL LINE EXTENSION
23D1 METRICAL BREVE
23D2 METRICAL LONG OVER SHORT
23D3 METRICAL SHORT OVER LONG
23D4 METRICAL LONG OVER TWO SHORTS
23D5 METRICAL TWO SHORTS OVER LONG
23D6 METRICAL TWO SHORTS JOINED
23D7 METRICAL TRISEME
23D8 METRICAL TETRASEME
23D9 METRICAL PENTASEME
23DA EARTH GROUND
23DB FUSE
2400 SYMBOL FOR NULL
2401 SYMBOL FOR START OF HEADING
2402 SYMBOL FOR START OF TEXT
2403 SYMBOL FOR END OF TEXT
2404 SYMBOL FOR END OF TRANSMISSION
2405 SYMBOL FOR ENQUIRY
2406 SYMBOL FOR ACKNOWLEDGE
2407 SYMBOL FOR BELL
2408 SYMBOL FOR BACKSPACE
2409 SYMBOL FOR HORIZONTAL TABULATION
240A SYMBOL FOR LINE FEED
240B SYMBOL FOR VERTICAL TABULATION
240C SYMBOL FOR FORM FEED
240D SYMBOL FOR CARRIAGE RETURN
240E SYMBOL FOR SHIFT OUT
240F SYMBOL FOR SHIFT IN
2410 SYMBOL FOR DATA LINK ESCAPE
2411 SYMBOL FOR DEVICE CONTROL ONE
2412 SYMBOL FOR DEVICE CONTROL TWO
2413 SYMBOL FOR DEVICE CONTROL THREE
2414 SYMBOL FOR DEVICE CONTROL FOUR
2415 SYMBOL FOR NEGATIVE ACKNOWLEDGE
2416 SYMBOL FOR SYNCHRONOUS IDLE
2417 SYMBOL FOR END OF TRANSMISSION BLOCK
2418 SYMBOL FOR CANCEL
2419 SYMBOL FOR END OF MEDIUM
241A SYMBOL FOR SUBSTITUTE
241B SYMBOL FOR ESCAPE
241C SYMBOL FOR FILE SEPARATOR
241D SYMBOL FOR GROUP SEPARATOR
241E SYMBOL FOR RECORD SEPARATOR
241F SYMBOL FOR UNIT SEPARATOR
2420 SYMBOL FOR SPACE
2421 SYMBOL FOR DELETE
2422 BLANK SYMBOL
2423 OPEN BOX
2424 SYMBOL FOR NEWLINE
2425 SYMBOL FOR DELETE FORM TWO
2426 SYMBOL FOR SUBSTITUTE FORM TWO
2440 OCR HOOK
2441 OCR CHAIR
2442 OCR FORK
2443 OCR INVERTED FORK
2444 OCR BELT BUCKLE
2445 OCR BOW TIE
2446 OCR BRANCH BANK IDENTIFICATION
2447 OCR AMOUNT OF CHECK
2448 OCR DASH
2449 OCR CUSTOMER ACCOUNT NUMBER
244A OCR DOUBLE BACKSLASH
2460 CIRCLED DIGIT ONE
2461 CIRCLED DIGIT TWO
2462 CIRCLED DIGIT THREE
2463 CIRCLED DIGIT FOUR
2464 CIRCLED DIGIT FIVE
2465 CIRCLED DIGIT SIX
2466 CIRCLED DIGIT SEVEN
2467 CIRCLED DIGIT EIGHT
2468 CIRCLED DIGIT NINE
2469 CIRCLED NUMBER TEN
246A CIRCLED NUMBER ELEVEN
246B CIRCLED NUMBER TWELVE
246C CIRCLED NUMBER THIRTEEN
246D CIRCLED NUMBER FOURTEEN
246E CIRCLED NUMBER FIFTEEN
246F CIRCLED NUMBER SIXTEEN
2470 CIRCLED NUMBER SEVENTEEN
2471 CIRCLED NUMBER EIGHTEEN
2472 CIRCLED NUMBER NINETEEN
2473 CIRCLED NUMBER TWENTY
2474 PARENTHESIZED DIGIT ONE
2475 PARENTHESIZED DIGIT TWO
2476 PARENTHESIZED DIGIT THREE
2477 PARENTHESIZED DIGIT FOUR
2478 PARENTHESIZED DIGIT FIVE
2479 PARENTHESIZED DIGIT SIX
247A PARENTHESIZED DIGIT SEVEN
247B PARENTHESIZED DIGIT EIGHT
247C PARENTHESIZED DIGIT NINE
247D PARENTHESIZED NUMBER TEN
247E PARENTHESIZED NUMBER ELEVEN
247F PARENTHESIZED NUMBER TWELVE
2480 PARENTHESIZED NUMBER THIRTEEN
2481 PARENTHESIZED NUMBER FOURTEEN
2482 PARENTHESIZED NUMBER FIFTEEN
2483 PARENTHESIZED NUMBER SIXTEEN
2484 PARENTHESIZED NUMBER SEVENTEEN
2485 PARENTHESIZED NUMBER EIGHTEEN
2486 PARENTHESIZED NUMBER NINETEEN
2487 PARENTHESIZED NUMBER TWENTY
2488 DIGIT ONE FULL STOP
2489 DIGIT TWO FULL STOP
248A DIGIT THREE FULL STOP
248B DIGIT FOUR FULL STOP
248C DIGIT FIVE FULL STOP
248D DIGIT SIX FULL STOP
248E DIGIT SEVEN FULL STOP
248F DIGIT EIGHT FULL STOP
2490 DIGIT NINE FULL STOP
2491 NUMBER TEN FULL STOP
2492 NUMBER ELEVEN FULL STOP
2493 NUMBER TWELVE FULL STOP
2494 NUMBER THIRTEEN FULL STOP
2495 NUMBER FOURTEEN FULL STOP
2496 NUMBER FIFTEEN FULL STOP
2497 NUMBER SIXTEEN FULL STOP
2498 NUMBER SEVENTEEN FULL STOP
2499 NUMBER EIGHTEEN FULL STOP
249A NUMBER NINETEEN FULL STOP
249B NUMBER TWENTY FULL STOP
249C PARENTHESIZED LATIN SMALL LETTER A
249D PARENTHESIZED LATIN SMALL LETTER B
249E PARENTHESIZED LATIN SMALL LETTER C
249F PARENTHESIZED LATIN SMALL LETTER D
24A0 PARENTHESIZED LATIN SMALL LETTER E
24A1 PARENTHESIZED LATIN SMALL LETTER F
24A2 PARENTHESIZED LATIN SMALL LETTER G
24A3 PARENTHESIZED LATIN SMALL LETTER H
24A4 PARENTHESIZED LATIN SMALL LETTER I
24A5 PARENTHESIZED LATIN SMALL LETTER J
24A6 PARENTHESIZED LATIN SMALL LETTER K
24A7 PARENTHESIZED LATIN SMALL LETTER L
24A8 PARENTHESIZED LATIN SMALL LETTER M
24A9 PARENTHESIZED LATIN SMALL LETTER N
24AA PARENTHESIZED LATIN SMALL LETTER O
24AB PARENTHESIZED LATIN SMALL LETTER P
24AC PARENTHESIZED LATIN SMALL LETTER Q
24AD PARENTHESIZED LATIN SMALL LETTER R
24AE PARENTHESIZED LATIN SMALL LETTER S
24AF PARENTHESIZED LATIN SMALL LETTER T
24B0 PARENTHESIZED LATIN SMALL LETTER U
24B1 PARENTHESIZED LATIN SMALL LETTER V
24B2 PARENTHESIZED LATIN SMALL LETTER W
24B3 PARENTHESIZED LATIN SMALL LETTER X
24B4 PARENTHESIZED LATIN SMALL LETTER Y
24B5 PARENTHESIZED LATIN SMALL LETTER Z
24B6 CIRCLED LATIN CAPITAL LETTER A
24B7 CIRCLED LATIN CAPITAL LETTER B
24B8 CIRCLED LATIN CAPITAL LETTER C
24B9 CIRCLED LATIN CAPITAL LETTER D
24BA CIRCLED LATIN CAPITAL LETTER E
24BB CIRCLED LATIN CAPITAL LETTER F
24BC CIRCLED LATIN CAPITAL LETTER G
24BD CIRCLED LATIN CAPITAL LETTER H
24BE CIRCLED LATIN CAPITAL LETTER I
24BF CIRCLED LATIN CAPITAL LETTER J
24C0 CIRCLED LATIN CAPITAL LETTER K
24C1 CIRCLED LATIN CAPITAL LETTER L
24C2 CIRCLED LATIN CAPITAL LETTER M
24C3 CIRCLED LATIN CAPITAL LETTER N
24C4 CIRCLED LATIN CAPITAL LETTER O
24C5 CIRCLED LATIN CAPITAL LETTER P
24C6 CIRCLED LATIN CAPITAL LETTER Q
24C7 CIRCLED LATIN CAPITAL LETTER R
24C8 CIRCLED LATIN CAPITAL LETTER S
24C9 CIRCLED LATIN CAPITAL LETTER T
24CA CIRCLED LATIN CAPITAL LETTER U
24CB CIRCLED LATIN CAPITAL LETTER V
24CC CIRCLED LATIN CAPITAL LETTER W
24CD CIRCLED LATIN CAPITAL LETTER X
24CE CIRCLED LATIN CAPITAL LETTER Y
24CF CIRCLED LATIN CAPITAL LETTER Z
24D0 CIRCLED LATIN SMALL LETTER A
24D1 CIRCLED LATIN SMALL LETTER B
24D2 CIRCLED LATIN SMALL LETTER C
24D3 CIRCLED LATIN SMALL LETTER D
24D4 CIRCLED LATIN SMALL LETTER E
24D5 CIRCLED LATIN SMALL LETTER F
24D6 CIRCLED LATIN SMALL LETTER G
24D7 CIRCLED LATIN SMALL LETTER H
24D8 CIRCLED LATIN SMALL LETTER I
24D9 CIRCLED LATIN SMALL LETTER J
24DA CIRCLED LATIN SMALL LETTER K
24DB CIRCLED LATIN SMALL LETTER L
24DC CIRCLED LATIN SMALL LETTER M
24DD CIRCLED LATIN SMALL LETTER N
24DE CIRCLED LATIN SMALL LETTER O
24DF CIRCLED LATIN SMALL LETTER P
24E0 CIRCLED LATIN SMALL LETTER Q
24E1 CIRCLED LATIN SMALL LETTER R
24E2 CIRCLED LATIN SMALL LETTER S
24E3 CIRCLED LATIN SMALL LETTER T
24E4 CIRCLED LATIN SMALL LETTER U
24E5 CIRCLED LATIN SMALL LETTER V
24E6 CIRCLED LATIN SMALL LETTER W
24E7 CIRCLED LATIN SMALL LETTER X
24E8 CIRCLED LATIN SMALL LETTER Y
24E9 CIRCLED LATIN SMALL LETTER Z
24EA CIRCLED DIGIT ZERO
24EB NEGATIVE CIRCLED NUMBER ELEVEN
24EC NEGATIVE CIRCLED NUMBER TWELVE
24ED NEGATIVE CIRCLED NUMBER THIRTEEN
24EE NEGATIVE CIRCLED NUMBER FOURTEEN
24EF NEGATIVE CIRCLED NUMBER FIFTEEN
24F0 NEGATIVE CIRCLED NUMBER SIXTEEN
24F1 NEGATIVE CIRCLED NUMBER SEVENTEEN
24F2 NEGATIVE CIRCLED NUMBER EIGHTEEN
24F3 NEGATIVE CIRCLED NUMBER NINETEEN
24F4 NEGATIVE CIRCLED NUMBER TWENTY
24F5 DOUBLE CIRCLED DIGIT ONE
24F6 DOUBLE CIRCLED DIGIT TWO
24F7 DOUBLE CIRCLED DIGIT THREE
24F8 DOUBLE CIRCLED DIGIT FOUR
24F9 DOUBLE CIRCLED DIGIT FIVE
24FA DOUBLE CIRCLED DIGIT SIX
24FB DOUBLE CIRCLED DIGIT SEVEN
24FC DOUBLE CIRCLED DIGIT EIGHT
24FD DOUBLE CIRCLED DIGIT NINE
24FE DOUBLE CIRCLED NUMBER TEN
24FF NEGATIVE CIRCLED DIGIT ZERO
2500 BOX DRAWINGS LIGHT HORIZONTAL
2501 BOX DRAWINGS HEAVY HORIZONTAL
2502 BOX DRAWINGS LIGHT VERTICAL
2503 BOX DRAWINGS HEAVY VERTICAL
2504 BOX DRAWINGS LIGHT TRIPLE DASH HORIZONTAL
2505 BOX DRAWINGS HEAVY TRIPLE DASH HORIZONTAL
2506 BOX DRAWINGS LIGHT TRIPLE DASH VERTICAL
2507 BOX DRAWINGS HEAVY TRIPLE DASH VERTICAL
2508 BOX DRAWINGS LIGHT QUADRUPLE DASH HORIZONTAL
2509 BOX DRAWINGS HEAVY QUADRUPLE DASH HORIZONTAL
250A BOX DRAWINGS LIGHT QUADRUPLE DASH VERTICAL
250B BOX DRAWINGS HEAVY QUADRUPLE DASH VERTICAL
250C BOX DRAWINGS LIGHT DOWN AND RIGHT
250D BOX DRAWINGS DOWN LIGHT AND RIGHT HEAVY
250E BOX DRAWINGS DOWN HEAVY AND RIGHT LIGHT
250F BOX DRAWINGS HEAVY DOWN AND RIGHT
2510 BOX DRAWINGS LIGHT DOWN AND LEFT
2511 BOX DRAWINGS DOWN LIGHT AND LEFT HEAVY
2512 BOX DRAWINGS DOWN HEAVY AND LEFT LIGHT
2513 BOX DRAWINGS HEAVY DOWN AND LEFT
2514 BOX DRAWINGS LIGHT UP AND RIGHT
2515 BOX DRAWINGS UP LIGHT AND RIGHT HEAVY
2516 BOX DRAWINGS UP HEAVY AND RIGHT LIGHT
2517 BOX DRAWINGS HEAVY UP AND RIGHT
2518 BOX DRAWINGS LIGHT UP AND LEFT
2519 BOX DRAWINGS UP LIGHT AND LEFT HEAVY
251A BOX DRAWINGS UP HEAVY AND LEFT LIGHT
251B BOX DRAWINGS HEAVY UP AND LEFT
251C BOX DRAWINGS LIGHT VERTICAL AND RIGHT
251D BOX DRAWINGS VERTICAL LIGHT AND RIGHT HEAVY
251E BOX DRAWINGS UP HEAVY AND RIGHT DOWN LIGHT
251F BOX DRAWINGS DOWN HEAVY AND RIGHT UP LIGHT
2520 BOX DRAWINGS VERTICAL HEAVY AND RIGHT LIGHT
2521 BOX DRAWINGS DOWN LIGHT AND RIGHT UP HEAVY
2522 BOX DRAWINGS UP LIGHT AND RIGHT DOWN HEAVY
2523 BOX DRAWINGS HEAVY VERTICAL AND RIGHT
2524 BOX DRAWINGS LIGHT VERTICAL AND LEFT
2525 BOX DRAWINGS VERTICAL LIGHT AND LEFT HEAVY
2526 BOX DRAWINGS UP HEAVY AND LEFT DOWN LIGHT
2527 BOX DRAWINGS DOWN HEAVY AND LEFT UP LIGHT
2528 BOX DRAWINGS VERTICAL HEAVY AND LEFT LIGHT
2529 BOX DRAWINGS DOWN LIGHT AND LEFT UP HEAVY
252A BOX DRAWINGS UP LIGHT AND LEFT DOWN HEAVY
252B BOX DRAWINGS HEAVY VERTICAL AND LEFT
252C BOX DRAWINGS LIGHT DOWN AND HORIZONTAL
252D BOX DRAWINGS LEFT HEAVY AND RIGHT DOWN LIGHT
252E BOX DRAWINGS RIGHT HEAVY AND LEFT DOWN LIGHT
252F BOX DRAWINGS DOWN LIGHT AND HORIZONTAL HEAVY
2530 BOX DRAWINGS DOWN HEAVY AND HORIZONTAL LIGHT
2531 BOX DRAWINGS RIGHT LIGHT AND LEFT DOWN HEAVY
2532 BOX DRAWINGS LEFT LIGHT AND RIGHT DOWN HEAVY
2533 BOX DRAWINGS HEAVY DOWN AND HORIZONTAL
2534 BOX DRAWINGS LIGHT UP AND HORIZONTAL
2535 BOX DRAWINGS LEFT HEAVY AND RIGHT UP LIGHT
2536 BOX DRAWINGS RIGHT HEAVY AND LEFT UP LIGHT
2537 BOX DRAWINGS UP LIGHT AND HORIZONTAL HEAVY
2538 BOX DRAWINGS UP HEAVY AND HORIZONTAL LIGHT
2539 BOX DRAWINGS RIGHT LIGHT AND LEFT UP HEAVY
253A BOX DRAWINGS LEFT LIGHT AND RIGHT UP HEAVY
253B BOX DRAWINGS HEAVY UP AND HORIZONTAL
253C BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL
253D BOX DRAWINGS LEFT HEAVY AND RIGHT VERTICAL LIGHT
253E BOX DRAWINGS RIGHT HEAVY AND LEFT VERTICAL LIGHT
253F BOX DRAWINGS VERTICAL LIGHT AND HORIZONTAL HEAVY
2540 BOX DRAWINGS UP HEAVY AND DOWN HORIZONTAL LIGHT
2541 BOX DRAWINGS DOWN HEAVY AND UP HORIZONTAL LIGHT
2542 BOX DRAWINGS VERTICAL HEAVY AND HORIZONTAL LIGHT
2543 BOX DRAWINGS LEFT UP HEAVY AND RIGHT DOWN LIGHT
2544 BOX DRAWINGS RIGHT UP HEAVY AND LEFT DOWN LIGHT
2545 BOX DRAWINGS LEFT DOWN HEAVY AND RIGHT UP LIGHT
2546 BOX DRAWINGS RIGHT DOWN HEAVY AND LEFT UP LIGHT
2547 BOX DRAWINGS DOWN LIGHT AND UP HORIZONTAL HEAVY
2548 BOX DRAWINGS UP LIGHT AND DOWN HORIZONTAL HEAVY
2549 BOX DRAWINGS RIGHT LIGHT AND LEFT VERTICAL HEAVY
254A BOX DRAWINGS LEFT LIGHT AND RIGHT VERTICAL HEAVY
254B BOX DRAWINGS HEAVY VERTICAL AND HORIZONTAL
254C BOX DRAWINGS LIGHT DOUBLE DASH HORIZONTAL
254D BOX DRAWINGS HEAVY DOUBLE DASH HORIZONTAL
254E BOX DRAWINGS LIGHT DOUBLE DASH VERTICAL
254F BOX DRAWINGS HEAVY DOUBLE DASH VERTICAL
2550 BOX DRAWINGS DOUBLE HORIZONTAL
2551 BOX DRAWINGS DOUBLE VERTICAL
2552 BOX DRAWINGS DOWN SINGLE AND RIGHT DOUBLE
2553 BOX DRAWINGS DOWN DOUBLE AND RIGHT SINGLE
2554 BOX DRAWINGS DOUBLE DOWN AND RIGHT
2555 BOX DRAWINGS DOWN SINGLE AND LEFT DOUBLE
2556 BOX DRAWINGS DOWN DOUBLE AND LEFT SINGLE
2557 BOX DRAWINGS DOUBLE DOWN AND LEFT
2558 BOX DRAWINGS UP SINGLE AND RIGHT DOUBLE
2559 BOX DRAWINGS UP DOUBLE AND RIGHT SINGLE
255A BOX DRAWINGS DOUBLE UP AND RIGHT
255B BOX DRAWINGS UP SINGLE AND LEFT DOUBLE
255C BOX DRAWINGS UP DOUBLE AND LEFT SINGLE
255D BOX DRAWINGS DOUBLE UP AND LEFT
255E BOX DRAWINGS VERTICAL SINGLE AND RIGHT DOUBLE
255F BOX DRAWINGS VERTICAL DOUBLE AND RIGHT SINGLE
2560 BOX DRAWINGS DOUBLE VERTICAL AND RIGHT
2561 BOX DRAWINGS VERTICAL SINGLE AND LEFT DOUBLE
2562 BOX DRAWINGS VERTICAL DOUBLE AND LEFT SINGLE
2563 BOX DRAWINGS DOUBLE VERTICAL AND LEFT
2564 BOX DRAWINGS DOWN SINGLE AND HORIZONTAL DOUBLE
2565 BOX DRAWINGS DOWN DOUBLE AND HORIZONTAL SINGLE
2566 BOX DRAWINGS DOUBLE DOWN AND HORIZONTAL
2567 BOX DRAWINGS UP SINGLE AND HORIZONTAL DOUBLE
2568 BOX DRAWINGS UP DOUBLE AND HORIZONTAL SINGLE
2569 BOX DRAWINGS DOUBLE UP AND HORIZONTAL
256A BOX DRAWINGS VERTICAL SINGLE AND HORIZONTAL DOUBLE
256B BOX DRAWINGS VERTICAL DOUBLE AND HORIZONTAL SINGLE
256C BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL
256D BOX DRAWINGS LIGHT ARC DOWN AND RIGHT
256E BOX DRAWINGS LIGHT ARC DOWN AND LEFT
256F BOX DRAWINGS LIGHT ARC UP AND LEFT
2570 BOX DRAWINGS LIGHT ARC UP AND RIGHT
2571 BOX DRAWINGS LIGHT DIAGONAL UPPER RIGHT TO LOWER LEFT
2572 BOX DRAWINGS LIGHT DIAGONAL UPPER LEFT TO LOWER RIGHT
2573 BOX DRAWINGS LIGHT DIAGONAL CROSS
2574 BOX DRAWINGS LIGHT LEFT
2575 BOX DRAWINGS LIGHT UP
2576 BOX DRAWINGS LIGHT RIGHT
2577 BOX DRAWINGS LIGHT DOWN
2578 BOX DRAWINGS HEAVY LEFT
2579 BOX DRAWINGS HEAVY UP
257A BOX DRAWINGS HEAVY RIGHT
257B BOX DRAWINGS HEAVY DOWN
257C BOX DRAWINGS LIGHT LEFT AND HEAVY RIGHT
257D BOX DRAWINGS LIGHT UP AND HEAVY DOWN
257E BOX DRAWINGS HEAVY LEFT AND LIGHT RIGHT
257F BOX DRAWINGS HEAVY UP AND LIGHT DOWN
2580 UPPER HALF BLOCK
2581 LOWER ONE EIGHTH BLOCK
2582 LOWER ONE QUARTER BLOCK
2583 LOWER THREE EIGHTHS BLOCK
2584 LOWER HALF BLOCK
2585 LOWER FIVE EIGHTHS BLOCK
2586 LOWER THREE QUARTERS BLOCK
2587 LOWER SEVEN EIGHTHS BLOCK
2588 FULL BLOCK
2589 LEFT SEVEN EIGHTHS BLOCK
258A LEFT THREE QUARTERS BLOCK
258B LEFT FIVE EIGHTHS BLOCK
258C LEFT HALF BLOCK
258D LEFT THREE EIGHTHS BLOCK
258E LEFT ONE QUARTER BLOCK
258F LEFT ONE EIGHTH BLOCK
2590 RIGHT HALF BLOCK
2591 LIGHT SHADE
2592 MEDIUM SHADE
2593 DARK SHADE
2594 UPPER ONE EIGHTH BLOCK
2595 RIGHT ONE EIGHTH BLOCK
2596 QUADRANT LOWER LEFT
2597 QUADRANT LOWER RIGHT
2598 QUADRANT UPPER LEFT
2599 QUADRANT UPPER LEFT AND LOWER LEFT AND LOWER RIGHT
259A QUADRANT UPPER LEFT AND LOWER RIGHT
259B QUADRANT UPPER LEFT AND UPPER RIGHT AND LOWER LEFT
259C QUADRANT UPPER LEFT AND UPPER RIGHT AND LOWER RIGHT
259D QUADRANT UPPER RIGHT
259E QUADRANT UPPER RIGHT AND LOWER LEFT
259F QUADRANT UPPER RIGHT AND LOWER LEFT AND LOWER RIGHT
25A0 BLACK SQUARE
25A1 WHITE SQUARE
25A2 WHITE SQUARE WITH ROUNDED CORNERS
25A3 WHITE SQUARE CONTAINING BLACK SMALL SQUARE
25A4 SQUARE WITH HORIZONTAL FILL
25A5 SQUARE WITH VERTICAL FILL
25A6 SQUARE WITH ORTHOGONAL CROSSHATCH FILL
25A7 SQUARE WITH UPPER LEFT TO LOWER RIGHT FILL
25A8 SQUARE WITH UPPER RIGHT TO LOWER LEFT FILL
25A9 SQUARE WITH DIAGONAL CROSSHATCH FILL
25AA BLACK SMALL SQUARE
25AB WHITE SMALL SQUARE
25AC BLACK RECTANGLE
25AD WHITE RECTANGLE
25AE BLACK VERTICAL RECTANGLE
25AF WHITE VERTICAL RECTANGLE
25B0 BLACK PARALLELOGRAM
25B1 WHITE PARALLELOGRAM
25B2 BLACK UP-POINTING TRIANGLE
25B3 WHITE UP-POINTING TRIANGLE
25B4 BLACK UP-POINTING SMALL TRIANGLE
25B5 WHITE UP-POINTING SMALL TRIANGLE
25B6 BLACK RIGHT-POINTING TRIANGLE
25B7 WHITE RIGHT-POINTING TRIANGLE
25B8 BLACK RIGHT-POINTING SMALL TRIANGLE
25B9 WHITE RIGHT-POINTING SMALL TRIANGLE
25BA BLACK RIGHT-POINTING POINTER
25BB WHITE RIGHT-POINTING POINTER
25BC BLACK DOWN-POINTING TRIANGLE
25BD WHITE DOWN-POINTING TRIANGLE
25BE BLACK DOWN-POINTING SMALL TRIANGLE
25BF WHITE DOWN-POINTING SMALL TRIANGLE
25C0 BLACK LEFT-POINTING TRIANGLE
25C1 WHITE LEFT-POINTING TRIANGLE
25C2 BLACK LEFT-POINTING SMALL TRIANGLE
25C3 WHITE LEFT-POINTING SMALL TRIANGLE
25C4 BLACK LEFT-POINTING POINTER
25C5 WHITE LEFT-POINTING POINTER
25C6 BLACK DIAMOND
25C7 WHITE DIAMOND
25C8 WHITE DIAMOND CONTAINING BLACK SMALL DIAMOND
25C9 FISHEYE
25CA LOZENGE
25CB WHITE CIRCLE
25CC DOTTED CIRCLE
25CD CIRCLE WITH VERTICAL FILL
25CE BULLSEYE
25CF BLACK CIRCLE
25D0 CIRCLE WITH LEFT HALF BLACK
25D1 CIRCLE WITH RIGHT HALF BLACK
25D2 CIRCLE WITH LOWER HALF BLACK
25D3 CIRCLE WITH UPPER HALF BLACK
25D4 CIRCLE WITH UPPER RIGHT QUADRANT BLACK
25D5 CIRCLE WITH ALL BUT UPPER LEFT QUADRANT BLACK
25D6 LEFT HALF BLACK CIRCLE
25D7 RIGHT HALF BLACK CIRCLE
25D8 INVERSE BULLET
25D9 INVERSE WHITE CIRCLE
25DA UPPER HALF INVERSE WHITE CIRCLE
25DB LOWER HALF INVERSE WHITE CIRCLE
25DC UPPER LEFT QUADRANT CIRCULAR ARC
25DD UPPER RIGHT QUADRANT CIRCULAR ARC
25DE LOWER RIGHT QUADRANT CIRCULAR ARC
25DF LOWER LEFT QUADRANT CIRCULAR ARC
25E0 UPPER HALF CIRCLE
25E1 LOWER HALF CIRCLE
25E2 BLACK LOWER RIGHT TRIANGLE
25E3 BLACK LOWER LEFT TRIANGLE
25E4 BLACK UPPER LEFT TRIANGLE
25E5 BLACK UPPER RIGHT TRIANGLE
25E6 WHITE BULLET
25E7 SQUARE WITH LEFT HALF BLACK
25E8 SQUARE WITH RIGHT HALF BLACK
25E9 SQUARE WITH UPPER LEFT DIAGONAL HALF BLACK
25EA SQUARE WITH LOWER RIGHT DIAGONAL HALF BLACK
25EB WHITE SQUARE WITH VERTICAL BISECTING LINE
25EC WHITE UP-POINTING TRIANGLE WITH DOT
25ED UP-POINTING TRIANGLE WITH LEFT HALF BLACK
25EE UP-POINTING TRIANGLE WITH RIGHT HALF BLACK
25EF LARGE CIRCLE
25F0 WHITE SQUARE WITH UPPER LEFT QUADRANT
25F1 WHITE SQUARE WITH LOWER LEFT QUADRANT
25F2 WHITE SQUARE WITH LOWER RIGHT QUADRANT
25F3 WHITE SQUARE WITH UPPER RIGHT QUADRANT
25F4 WHITE CIRCLE WITH UPPER LEFT QUADRANT
25F5 WHITE CIRCLE WITH LOWER LEFT QUADRANT
25F6 WHITE CIRCLE WITH LOWER RIGHT QUADRANT
25F7 WHITE CIRCLE WITH UPPER RIGHT QUADRANT
25F8 UPPER LEFT TRIANGLE
25F9 UPPER RIGHT TRIANGLE
25FA LOWER LEFT TRIANGLE
25FB WHITE MEDIUM SQUARE
25FC BLACK MEDIUM SQUARE
25FD WHITE MEDIUM SMALL SQUARE
25FE BLACK MEDIUM SMALL SQUARE
25FF LOWER RIGHT TRIANGLE
2600 BLACK SUN WITH RAYS
2601 CLOUD
2602 UMBRELLA
2603 SNOWMAN
2604 COMET
2605 BLACK STAR
2606 WHITE STAR
2607 LIGHTNING
2608 THUNDERSTORM
2609 SUN
260A ASCENDING NODE
260B DESCENDING NODE
260C CONJUNCTION
260D OPPOSITION
260E BLACK TELEPHONE
260F WHITE TELEPHONE
2610 BALLOT BOX
2611 BALLOT BOX WITH CHECK
2612 BALLOT BOX WITH X
2613 SALTIRE
2614 UMBRELLA WITH RAIN DROPS
2615 HOT BEVERAGE
2616 WHITE SHOGI PIECE
2617 BLACK SHOGI PIECE
2618 SHAMROCK
2619 REVERSED ROTATED FLORAL HEART BULLET
261A BLACK LEFT POINTING INDEX
261B BLACK RIGHT POINTING INDEX
261C WHITE LEFT POINTING INDEX
261D WHITE UP POINTING INDEX
261E WHITE RIGHT POINTING INDEX
261F WHITE DOWN POINTING INDEX
2620 SKULL AND CROSSBONES
2621 CAUTION SIGN
2622 RADIOACTIVE SIGN
2623 BIOHAZARD SIGN
2624 CADUCEUS
2625 ANKH
2626 ORTHODOX CROSS
2627 CHI RHO
2628 CROSS OF LORRAINE
2629 CROSS OF JERUSALEM
262A STAR AND CRESCENT
262B FARSI SYMBOL
262C ADI SHAKTI
262D HAMMER AND SICKLE
262E PEACE SYMBOL
262F YIN YANG
2630 TRIGRAM FOR HEAVEN
2631 TRIGRAM FOR LAKE
2632 TRIGRAM FOR FIRE
2633 TRIGRAM FOR THUNDER
2634 TRIGRAM FOR WIND
2635 TRIGRAM FOR WATER
2636 TRIGRAM FOR MOUNTAIN
2637 TRIGRAM FOR EARTH
2638 WHEEL OF DHARMA
2639 WHITE FROWNING FACE
263A WHITE SMILING FACE
263B BLACK SMILING FACE
263C WHITE SUN WITH RAYS
263D FIRST QUARTER MOON
263E LAST QUARTER MOON
263F MERCURY
2640 FEMALE SIGN
2641 EARTH
2642 MALE SIGN
2643 JUPITER
2644 SATURN
2645 URANUS
2646 NEPTUNE
2647 PLUTO
2648 ARIES
2649 TAURUS
264A GEMINI
264B CANCER
264C LEO
264D VIRGO
264E LIBRA
264F SCORPIUS
2650 SAGITTARIUS
2651 CAPRICORN
2652 AQUARIUS
2653 PISCES
2654 WHITE CHESS KING
2655 WHITE CHESS QUEEN
2656 WHITE CHESS ROOK
2657 WHITE CHESS BISHOP
2658 WHITE CHESS KNIGHT
2659 WHITE CHESS PAWN
265A BLACK CHESS KING
265B BLACK CHESS QUEEN
265C BLACK CHESS ROOK
265D BLACK CHESS BISHOP
265E BLACK CHESS KNIGHT
265F BLACK CHESS PAWN
2660 BLACK SPADE SUIT
2661 WHITE HEART SUIT
2662 WHITE DIAMOND SUIT
2663 BLACK CLUB SUIT
2664 WHITE SPADE SUIT
2665 BLACK HEART SUIT
2666 BLACK DIAMOND SUIT
2667 WHITE CLUB SUIT
2668 HOT SPRINGS
2669 QUARTER NOTE
266A EIGHTH NOTE
266B BEAMED EIGHTH NOTES
266C BEAMED SIXTEENTH NOTES
266D MUSIC FLAT SIGN
266E MUSIC NATURAL SIGN
266F MUSIC SHARP SIGN
2670 WEST SYRIAC CROSS
2671 EAST SYRIAC CROSS
2672 UNIVERSAL RECYCLING SYMBOL
2673 RECYCLING SYMBOL FOR TYPE-1 PLASTICS
2674 RECYCLING SYMBOL FOR TYPE-2 PLASTICS
2675 RECYCLING SYMBOL FOR TYPE-3 PLASTICS
2676 RECYCLING SYMBOL FOR TYPE-4 PLASTICS
2677 RECYCLING SYMBOL FOR TYPE-5 PLASTICS
2678 RECYCLING SYMBOL FOR TYPE-6 PLASTICS
2679 RECYCLING SYMBOL FOR TYPE-7 PLASTICS
267A RECYCLING SYMBOL FOR GENERIC MATERIALS
267B BLACK UNIVERSAL RECYCLING SYMBOL
267C RECYCLED PAPER SYMBOL
267D PARTIALLY-RECYCLED PAPER SYMBOL
267E PERMANENT PAPER SIGN
267F WHEELCHAIR SYMBOL
2680 DIE FACE-1
2681 DIE FACE-2
2682 DIE FACE-3
2683 DIE FACE-4
2684 DIE FACE-5
2685 DIE FACE-6
2686 WHITE CIRCLE WITH DOT RIGHT
2687 WHITE CIRCLE WITH TWO DOTS
2688 BLACK CIRCLE WITH WHITE DOT RIGHT
2689 BLACK CIRCLE WITH TWO WHITE DOTS
268A MONOGRAM FOR YANG
268B MONOGRAM FOR YIN
268C DIGRAM FOR GREATER YANG
268D DIGRAM FOR LESSER YIN
268E DIGRAM FOR LESSER YANG
268F DIGRAM FOR GREATER YIN
2690 WHITE FLAG
2691 BLACK FLAG
2692 HAMMER AND PICK
2693 ANCHOR
2694 CROSSED SWORDS
2695 STAFF OF AESCULAPIUS
2696 SCALES
2697 ALEMBIC
2698 FLOWER
2699 GEAR
269A STAFF OF HERMES
269B ATOM SYMBOL
269C FLEUR-DE-LIS
26A0 WARNING SIGN
26A1 HIGH VOLTAGE SIGN
26A2 DOUBLED FEMALE SIGN
26A3 DOUBLED MALE SIGN
26A4 INTERLOCKED FEMALE AND MALE SIGN
26A5 MALE AND FEMALE SIGN
26A6 MALE WITH STROKE SIGN
26A7 MALE WITH STROKE AND MALE AND FEMALE SIGN
26A8 VERTICAL MALE WITH STROKE SIGN
26A9 HORIZONTAL MALE WITH STROKE SIGN
26AA MEDIUM WHITE CIRCLE
26AB MEDIUM BLACK CIRCLE
26AC MEDIUM SMALL WHITE CIRCLE
26AD MARRIAGE SYMBOL
26AE DIVORCE SYMBOL
26AF UNMARRIED PARTNERSHIP SYMBOL
26B0 COFFIN
26B1 FUNERAL URN
2701 UPPER BLADE SCISSORS
2702 BLACK SCISSORS
2703 LOWER BLADE SCISSORS
2704 WHITE SCISSORS
2706 TELEPHONE LOCATION SIGN
2707 TAPE DRIVE
2708 AIRPLANE
2709 ENVELOPE
270C VICTORY HAND
270D WRITING HAND
270E LOWER RIGHT PENCIL
270F PENCIL
2710 UPPER RIGHT PENCIL
2711 WHITE NIB
2712 BLACK NIB
2713 CHECK MARK
2714 HEAVY CHECK MARK
2715 MULTIPLICATION X
2716 HEAVY MULTIPLICATION X
2717 BALLOT X
2718 HEAVY BALLOT X
2719 OUTLINED GREEK CROSS
271A HEAVY GREEK CROSS
271B OPEN CENTRE CROSS
271C HEAVY OPEN CENTRE CROSS
271D LATIN CROSS
271E SHADOWED WHITE LATIN CROSS
271F OUTLINED LATIN CROSS
2720 MALTESE CROSS
2721 STAR OF DAVID
2722 FOUR TEARDROP-SPOKED ASTERISK
2723 FOUR BALLOON-SPOKED ASTERISK
2724 HEAVY FOUR BALLOON-SPOKED ASTERISK
2725 FOUR CLUB-SPOKED ASTERISK
2726 BLACK FOUR POINTED STAR
2727 WHITE FOUR POINTED STAR
2729 STRESS OUTLINED WHITE STAR
272A CIRCLED WHITE STAR
272B OPEN CENTRE BLACK STAR
272C BLACK CENTRE WHITE STAR
272D OUTLINED BLACK STAR
272E HEAVY OUTLINED BLACK STAR
272F PINWHEEL STAR
2730 SHADOWED WHITE STAR
2731 HEAVY ASTERISK
2732 OPEN CENTRE ASTERISK
2733 EIGHT SPOKED ASTERISK
2734 EIGHT POINTED BLACK STAR
2735 EIGHT POINTED PINWHEEL STAR
2736 SIX POINTED BLACK STAR
2737 EIGHT POINTED RECTILINEAR BLACK STAR
2738 HEAVY EIGHT POINTED RECTILINEAR BLACK STAR
2739 TWELVE POINTED BLACK STAR
273A SIXTEEN POINTED ASTERISK
273B TEARDROP-SPOKED ASTERISK
273C OPEN CENTRE TEARDROP-SPOKED ASTERISK
273D HEAVY TEARDROP-SPOKED ASTERISK
273E SIX PETALLED BLACK AND WHITE FLORETTE
273F BLACK FLORETTE
2740 WHITE FLORETTE
2741 EIGHT PETALLED OUTLINED BLACK FLORETTE
2742 CIRCLED OPEN CENTRE EIGHT POINTED STAR
2743 HEAVY TEARDROP-SPOKED PINWHEEL ASTERISK
2744 SNOWFLAKE
2745 TIGHT TRIFOLIATE SNOWFLAKE
2746 HEAVY CHEVRON SNOWFLAKE
2747 SPARKLE
2748 HEAVY SPARKLE
2749 BALLOON-SPOKED ASTERISK
274A EIGHT TEARDROP-SPOKED PROPELLER ASTERISK
274B HEAVY EIGHT TEARDROP-SPOKED PROPELLER ASTERISK
274D SHADOWED WHITE CIRCLE
274F LOWER RIGHT DROP-SHADOWED WHITE SQUARE
2750 UPPER RIGHT DROP-SHADOWED WHITE SQUARE
2751 LOWER RIGHT SHADOWED WHITE SQUARE
2752 UPPER RIGHT SHADOWED WHITE SQUARE
2756 BLACK DIAMOND MINUS WHITE X
2758 LIGHT VERTICAL BAR
2759 MEDIUM VERTICAL BAR
275A HEAVY VERTICAL BAR
275B HEAVY SINGLE TURNED COMMA QUOTATION MARK ORNAMENT
275C HEAVY SINGLE COMMA QUOTATION MARK ORNAMENT
275D HEAVY DOUBLE TURNED COMMA QUOTATION MARK ORNAMENT
275E HEAVY DOUBLE COMMA QUOTATION MARK ORNAMENT
2761 CURVED STEM PARAGRAPH SIGN ORNAMENT
2762 HEAVY EXCLAMATION MARK ORNAMENT
2763 HEAVY HEART EXCLAMATION MARK ORNAMENT
2764 HEAVY BLACK HEART
2765 ROTATED HEAVY BLACK HEART BULLET
2766 FLORAL HEART
2767 ROTATED FLORAL HEART BULLET
2768 MEDIUM LEFT PARENTHESIS ORNAMENT
2769 MEDIUM RIGHT PARENTHESIS ORNAMENT
276A MEDIUM FLATTENED LEFT PARENTHESIS ORNAMENT
276B MEDIUM FLATTENED RIGHT PARENTHESIS ORNAMENT
276C MEDIUM LEFT-POINTING ANGLE BRACKET ORNAMENT
276D MEDIUM RIGHT-POINTING ANGLE BRACKET ORNAMENT
276E HEAVY LEFT-POINTING ANGLE QUOTATION MARK ORNAMENT
276F HEAVY RIGHT-POINTING ANGLE QUOTATION MARK ORNAMENT
2770 HEAVY LEFT-POINTING ANGLE BRACKET ORNAMENT
2771 HEAVY RIGHT-POINTING ANGLE BRACKET ORNAMENT
2772 LIGHT LEFT TORTOISE SHELL BRACKET ORNAMENT
2773 LIGHT RIGHT TORTOISE SHELL BRACKET ORNAMENT
2774 MEDIUM LEFT CURLY BRACKET ORNAMENT
2775 MEDIUM RIGHT CURLY BRACKET ORNAMENT
2776 DINGBAT NEGATIVE CIRCLED DIGIT ONE
2777 DINGBAT NEGATIVE CIRCLED DIGIT TWO
2778 DINGBAT NEGATIVE CIRCLED DIGIT THREE
2779 DINGBAT NEGATIVE CIRCLED DIGIT FOUR
277A DINGBAT NEGATIVE CIRCLED DIGIT FIVE
277B DINGBAT NEGATIVE CIRCLED DIGIT SIX
277C DINGBAT NEGATIVE CIRCLED DIGIT SEVEN
277D DINGBAT NEGATIVE CIRCLED DIGIT EIGHT
277E DINGBAT NEGATIVE CIRCLED DIGIT NINE
277F DINGBAT NEGATIVE CIRCLED NUMBER TEN
2780 DINGBAT CIRCLED SANS-SERIF DIGIT ONE
2781 DINGBAT CIRCLED SANS-SERIF DIGIT TWO
2782 DINGBAT CIRCLED SANS-SERIF DIGIT THREE
2783 DINGBAT CIRCLED SANS-SERIF DIGIT FOUR
2784 DINGBAT CIRCLED SANS-SERIF DIGIT FIVE
2785 DINGBAT CIRCLED SANS-SERIF DIGIT SIX
2786 DINGBAT CIRCLED SANS-SERIF DIGIT SEVEN
2787 DINGBAT CIRCLED SANS-SERIF DIGIT EIGHT
2788 DINGBAT CIRCLED SANS-SERIF DIGIT NINE
2789 DINGBAT CIRCLED SANS-SERIF NUMBER TEN
278A DINGBAT NEGATIVE CIRCLED SANS-SERIF DIGIT ONE
278B DINGBAT NEGATIVE CIRCLED SANS-SERIF DIGIT TWO
278C DINGBAT NEGATIVE CIRCLED SANS-SERIF DIGIT THREE
278D DINGBAT NEGATIVE CIRCLED SANS-SERIF DIGIT FOUR
278E DINGBAT NEGATIVE CIRCLED SANS-SERIF DIGIT FIVE
278F DINGBAT NEGATIVE CIRCLED SANS-SERIF DIGIT SIX
2790 DINGBAT NEGATIVE CIRCLED SANS-SERIF DIGIT SEVEN
2791 DINGBAT NEGATIVE CIRCLED SANS-SERIF DIGIT EIGHT
2792 DINGBAT NEGATIVE CIRCLED SANS-SERIF DIGIT NINE
2793 DINGBAT NEGATIVE CIRCLED SANS-SERIF NUMBER TEN
2794 HEAVY WIDE-HEADED RIGHTWARDS ARROW
2798 HEAVY SOUTH EAST ARROW
2799 HEAVY RIGHTWARDS ARROW
279A HEAVY NORTH EAST ARROW
279B DRAFTING POINT RIGHTWARDS ARROW
279C HEAVY ROUND-TIPPED RIGHTWARDS ARROW
279D TRIANGLE-HEADED RIGHTWARDS ARROW
279E HEAVY TRIANGLE-HEADED RIGHTWARDS ARROW
279F DASHED TRIANGLE-HEADED RIGHTWARDS ARROW
27A0 HEAVY DASHED TRIANGLE-HEADED RIGHTWARDS ARROW
27A1 BLACK RIGHTWARDS ARROW
27A2 THREE-D TOP-LIGHTED RIGHTWARDS ARROWHEAD
27A3 THREE-D BOTTOM-LIGHTED RIGHTWARDS ARROWHEAD
27A4 BLACK RIGHTWARDS ARROWHEAD
27A5 HEAVY BLACK CURVED DOWNWARDS AND RIGHTWARDS ARROW
27A6 HEAVY BLACK CURVED UPWARDS AND RIGHTWARDS ARROW
27A7 SQUAT BLACK RIGHTWARDS ARROW
27A8 HEAVY CONCAVE-POINTED BLACK RIGHTWARDS ARROW
27A9 RIGHT-SHADED WHITE RIGHTWARDS ARROW
27AA LEFT-SHADED WHITE RIGHTWARDS ARROW
27AB BACK-TILTED SHADOWED WHITE RIGHTWARDS ARROW
27AC FRONT-TILTED SHADOWED WHITE RIGHTWARDS ARROW
27AD HEAVY LOWER RIGHT-SHADOWED WHITE RIGHTWARDS ARROW
27AE HEAVY UPPER RIGHT-SHADOWED WHITE RIGHTWARDS ARROW
27AF NOTCHED LOWER RIGHT-SHADOWED WHITE RIGHTWARDS ARROW
27B1 NOTCHED UPPER RIGHT-SHADOWED WHITE RIGHTWARDS ARROW
27B2 CIRCLED HEAVY WHITE RIGHTWARDS ARROW
27B3 WHITE-FEATHERED RIGHTWARDS ARROW
27B4 BLACK-FEATHERED SOUTH EAST ARROW
27B5 BLACK-FEATHERED RIGHTWARDS ARROW
27B6 BLACK-FEATHERED NORTH EAST ARROW
27B7 HEAVY BLACK-FEATHERED SOUTH EAST ARROW
27B8 HEAVY BLACK-FEATHERED RIGHTWARDS ARROW
27B9 HEAVY BLACK-FEATHERED NORTH EAST ARROW
27BA TEARDROP-BARBED RIGHTWARDS ARROW
27BB HEAVY TEARDROP-SHANKED RIGHTWARDS ARROW
27BC WEDGE-TAILED RIGHTWARDS ARROW
27BD HEAVY WEDGE-TAILED RIGHTWARDS ARROW
27BE OPEN-OUTLINED RIGHTWARDS ARROW
27C0 THREE DIMENSIONAL ANGLE
27C1 WHITE TRIANGLE CONTAINING SMALL WHITE TRIANGLE
27C2 PERPENDICULAR
27C3 OPEN SUBSET
27C4 OPEN SUPERSET
27C5 LEFT S-SHAPED BAG DELIMITER
27C6 RIGHT S-SHAPED BAG DELIMITER
27D0 WHITE DIAMOND WITH CENTRED DOT
27D1 AND WITH DOT
27D2 ELEMENT OF OPENING UPWARDS
27D3 LOWER RIGHT CORNER WITH DOT
27D4 UPPER LEFT CORNER WITH DOT
27D5 LEFT OUTER JOIN
27D6 RIGHT OUTER JOIN
27D7 FULL OUTER JOIN
27D8 LARGE UP TACK
27D9 LARGE DOWN TACK
27DA LEFT AND RIGHT DOUBLE TURNSTILE
27DB LEFT AND RIGHT TACK
27DC LEFT MULTIMAP
27DD LONG RIGHT TACK
27DE LONG LEFT TACK
27DF UP TACK WITH CIRCLE ABOVE
27E0 LOZENGE DIVIDED BY HORIZONTAL RULE
27E1 WHITE CONCAVE-SIDED DIAMOND
27E2 WHITE CONCAVE-SIDED DIAMOND WITH LEFTWARDS TICK
27E3 WHITE CONCAVE-SIDED DIAMOND WITH RIGHTWARDS TICK
27E4 WHITE SQUARE WITH LEFTWARDS TICK
27E5 WHITE SQUARE WITH RIGHTWARDS TICK
27E6 MATHEMATICAL LEFT WHITE SQUARE BRACKET
27E7 MATHEMATICAL RIGHT WHITE SQUARE BRACKET
27E8 MATHEMATICAL LEFT ANGLE BRACKET
27E9 MATHEMATICAL RIGHT ANGLE BRACKET
27EA MATHEMATICAL LEFT DOUBLE ANGLE BRACKET
27EB MATHEMATICAL RIGHT DOUBLE ANGLE BRACKET
27F0 UPWARDS QUADRUPLE ARROW
27F1 DOWNWARDS QUADRUPLE ARROW
27F2 ANTICLOCKWISE GAPPED CIRCLE ARROW
27F3 CLOCKWISE GAPPED CIRCLE ARROW
27F4 RIGHT ARROW WITH CIRCLED PLUS
27F5 LONG LEFTWARDS ARROW
27F6 LONG RIGHTWARDS ARROW
27F7 LONG LEFT RIGHT ARROW
27F8 LONG LEFTWARDS DOUBLE ARROW
27F9 LONG RIGHTWARDS DOUBLE ARROW
27FA LONG LEFT RIGHT DOUBLE ARROW
27FB LONG LEFTWARDS ARROW FROM BAR
27FC LONG RIGHTWARDS ARROW FROM BAR
27FD LONG LEFTWARDS DOUBLE ARROW FROM BAR
27FE LONG RIGHTWARDS DOUBLE ARROW FROM BAR
27FF LONG RIGHTWARDS SQUIGGLE ARROW
2800 BRAILLE PATTERN BLANK
2801 BRAILLE PATTERN DOTS-1
2802 BRAILLE PATTERN DOTS-2
2803 BRAILLE PATTERN DOTS-12
2804 BRAILLE PATTERN DOTS-3
2805 BRAILLE PATTERN DOTS-13
2806 BRAILLE PATTERN DOTS-23
2807 BRAILLE PATTERN DOTS-123
2808 BRAILLE PATTERN DOTS-4
2809 BRAILLE PATTERN DOTS-14
280A BRAILLE PATTERN DOTS-24
280B BRAILLE PATTERN DOTS-124
280C BRAILLE PATTERN DOTS-34
280D BRAILLE PATTERN DOTS-134
280E BRAILLE PATTERN DOTS-234
280F BRAILLE PATTERN DOTS-1234
2810 BRAILLE PATTERN DOTS-5
2811 BRAILLE PATTERN DOTS-15
2812 BRAILLE PATTERN DOTS-25
2813 BRAILLE PATTERN DOTS-125
2814 BRAILLE PATTERN DOTS-35
2815 BRAILLE PATTERN DOTS-135
2816 BRAILLE PATTERN DOTS-235
2817 BRAILLE PATTERN DOTS-1235
2818 BRAILLE PATTERN DOTS-45
2819 BRAILLE PATTERN DOTS-145
281A BRAILLE PATTERN DOTS-245
281B BRAILLE PATTERN DOTS-1245
281C BRAILLE PATTERN DOTS-345
281D BRAILLE PATTERN DOTS-1345
281E BRAILLE PATTERN DOTS-2345
281F BRAILLE PATTERN DOTS-12345
2820 BRAILLE PATTERN DOTS-6
2821 BRAILLE PATTERN DOTS-16
2822 BRAILLE PATTERN DOTS-26
2823 BRAILLE PATTERN DOTS-126
2824 BRAILLE PATTERN DOTS-36
2825 BRAILLE PATTERN DOTS-136
2826 BRAILLE PATTERN DOTS-236
2827 BRAILLE PATTERN DOTS-1236
2828 BRAILLE PATTERN DOTS-46
2829 BRAILLE PATTERN DOTS-146
282A BRAILLE PATTERN DOTS-246
282B BRAILLE PATTERN DOTS-1246
282C BRAILLE PATTERN DOTS-346
282D BRAILLE PATTERN DOTS-1346
282E BRAILLE PATTERN DOTS-2346
282F BRAILLE PATTERN DOTS-12346
2830 BRAILLE PATTERN DOTS-56
2831 BRAILLE PATTERN DOTS-156
2832 BRAILLE PATTERN DOTS-256
2833 BRAILLE PATTERN DOTS-1256
2834 BRAILLE PATTERN DOTS-356
2835 BRAILLE PATTERN DOTS-1356
2836 BRAILLE PATTERN DOTS-2356
2837 BRAILLE PATTERN DOTS-12356
2838 BRAILLE PATTERN DOTS-456
2839 BRAILLE PATTERN DOTS-1456
283A BRAILLE PATTERN DOTS-2456
283B BRAILLE PATTERN DOTS-12456
283C BRAILLE PATTERN DOTS-3456
283D BRAILLE PATTERN DOTS-13456
283E BRAILLE PATTERN DOTS-23456
283F BRAILLE PATTERN DOTS-123456
2840 BRAILLE PATTERN DOTS-7
2841 BRAILLE PATTERN DOTS-17
2842 BRAILLE PATTERN DOTS-27
2843 BRAILLE PATTERN DOTS-127
2844 BRAILLE PATTERN DOTS-37
2845 BRAILLE PATTERN DOTS-137
2846 BRAILLE PATTERN DOTS-237
2847 BRAILLE PATTERN DOTS-1237
2848 BRAILLE PATTERN DOTS-47
2849 BRAILLE PATTERN DOTS-147
284A BRAILLE PATTERN DOTS-247
284B BRAILLE PATTERN DOTS-1247
284C BRAILLE PATTERN DOTS-347
284D BRAILLE PATTERN DOTS-1347
284E BRAILLE PATTERN DOTS-2347
284F BRAILLE PATTERN DOTS-12347
2850 BRAILLE PATTERN DOTS-57
2851 BRAILLE PATTERN DOTS-157
2852 BRAILLE PATTERN DOTS-257
2853 BRAILLE PATTERN DOTS-1257
2854 BRAILLE PATTERN DOTS-357
2855 BRAILLE PATTERN DOTS-1357
2856 BRAILLE PATTERN DOTS-2357
2857 BRAILLE PATTERN DOTS-12357
2858 BRAILLE PATTERN DOTS-457
2859 BRAILLE PATTERN DOTS-1457
285A BRAILLE PATTERN DOTS-2457
285B BRAILLE PATTERN DOTS-12457
285C BRAILLE PATTERN DOTS-3457
285D BRAILLE PATTERN DOTS-13457
285E BRAILLE PATTERN DOTS-23457
285F BRAILLE PATTERN DOTS-123457
2860 BRAILLE PATTERN DOTS-67
2861 BRAILLE PATTERN DOTS-167
2862 BRAILLE PATTERN DOTS-267
2863 BRAILLE PATTERN DOTS-1267
2864 BRAILLE PATTERN DOTS-367
2865 BRAILLE PATTERN DOTS-1367
2866 BRAILLE PATTERN DOTS-2367
2867 BRAILLE PATTERN DOTS-12367
2868 BRAILLE PATTERN DOTS-467
2869 BRAILLE PATTERN DOTS-1467
286A BRAILLE PATTERN DOTS-2467
286B BRAILLE PATTERN DOTS-12467
286C BRAILLE PATTERN DOTS-3467
286D BRAILLE PATTERN DOTS-13467
286E BRAILLE PATTERN DOTS-23467
286F BRAILLE PATTERN DOTS-123467
2870 BRAILLE PATTERN DOTS-567
2871 BRAILLE PATTERN DOTS-1567
2872 BRAILLE PATTERN DOTS-2567
2873 BRAILLE PATTERN DOTS-12567
2874 BRAILLE PATTERN DOTS-3567
2875 BRAILLE PATTERN DOTS-13567
2876 BRAILLE PATTERN DOTS-23567
2877 BRAILLE PATTERN DOTS-123567
2878 BRAILLE PATTERN DOTS-4567
2879 BRAILLE PATTERN DOTS-14567
287A BRAILLE PATTERN DOTS-24567
287B BRAILLE PATTERN DOTS-124567
287C BRAILLE PATTERN DOTS-34567
287D BRAILLE PATTERN DOTS-134567
287E BRAILLE PATTERN DOTS-234567
287F BRAILLE PATTERN DOTS-1234567
2880 BRAILLE PATTERN DOTS-8
2881 BRAILLE PATTERN DOTS-18
2882 BRAILLE PATTERN DOTS-28
2883 BRAILLE PATTERN DOTS-128
2884 BRAILLE PATTERN DOTS-38
2885 BRAILLE PATTERN DOTS-138
2886 BRAILLE PATTERN DOTS-238
2887 BRAILLE PATTERN DOTS-1238
2888 BRAILLE PATTERN DOTS-48
2889 BRAILLE PATTERN DOTS-148
288A BRAILLE PATTERN DOTS-248
288B BRAILLE PATTERN DOTS-1248
288C BRAILLE PATTERN DOTS-348
288D BRAILLE PATTERN DOTS-1348
288E BRAILLE PATTERN DOTS-2348
288F BRAILLE PATTERN DOTS-12348
2890 BRAILLE PATTERN DOTS-58
2891 BRAILLE PATTERN DOTS-158
2892 BRAILLE PATTERN DOTS-258
2893 BRAILLE PATTERN DOTS-1258
2894 BRAILLE PATTERN DOTS-358
2895 BRAILLE PATTERN DOTS-1358
2896 BRAILLE PATTERN DOTS-2358
2897 BRAILLE PATTERN DOTS-12358
2898 BRAILLE PATTERN DOTS-458
2899 BRAILLE PATTERN DOTS-1458
289A BRAILLE PATTERN DOTS-2458
289B BRAILLE PATTERN DOTS-12458
289C BRAILLE PATTERN DOTS-3458
289D BRAILLE PATTERN DOTS-13458
289E BRAILLE PATTERN DOTS-23458
289F BRAILLE PATTERN DOTS-123458
28A0 BRAILLE PATTERN DOTS-68
28A1 BRAILLE PATTERN DOTS-168
28A2 BRAILLE PATTERN DOTS-268
28A3 BRAILLE PATTERN DOTS-1268
28A4 BRAILLE PATTERN DOTS-368
28A5 BRAILLE PATTERN DOTS-1368
28A6 BRAILLE PATTERN DOTS-2368
28A7 BRAILLE PATTERN DOTS-12368
28A8 BRAILLE PATTERN DOTS-468
28A9 BRAILLE PATTERN DOTS-1468
28AA BRAILLE PATTERN DOTS-2468
28AB BRAILLE PATTERN DOTS-12468
28AC BRAILLE PATTERN DOTS-3468
28AD BRAILLE PATTERN DOTS-13468
28AE BRAILLE PATTERN DOTS-23468
28AF BRAILLE PATTERN DOTS-123468
28B0 BRAILLE PATTERN DOTS-568
28B1 BRAILLE PATTERN DOTS-1568
28B2 BRAILLE PATTERN DOTS-2568
28B3 BRAILLE PATTERN DOTS-12568
28B4 BRAILLE PATTERN DOTS-3568
28B5 BRAILLE PATTERN DOTS-13568
28B6 BRAILLE PATTERN DOTS-23568
28B7 BRAILLE PATTERN DOTS-123568
28B8 BRAILLE PATTERN DOTS-4568
28B9 BRAILLE PATTERN DOTS-14568
28BA BRAILLE PATTERN DOTS-24568
28BB BRAILLE PATTERN DOTS-124568
28BC BRAILLE PATTERN DOTS-34568
28BD BRAILLE PATTERN DOTS-134568
28BE BRAILLE PATTERN DOTS-234568
28BF BRAILLE PATTERN DOTS-1234568
28C0 BRAILLE PATTERN DOTS-78
28C1 BRAILLE PATTERN DOTS-178
28C2 BRAILLE PATTERN DOTS-278
28C3 BRAILLE PATTERN DOTS-1278
28C4 BRAILLE PATTERN DOTS-378
28C5 BRAILLE PATTERN DOTS-1378
28C6 BRAILLE PATTERN DOTS-2378
28C7 BRAILLE PATTERN DOTS-12378
28C8 BRAILLE PATTERN DOTS-478
28C9 BRAILLE PATTERN DOTS-1478
28CA BRAILLE PATTERN DOTS-2478
28CB BRAILLE PATTERN DOTS-12478
28CC BRAILLE PATTERN DOTS-3478
28CD BRAILLE PATTERN DOTS-13478
28CE BRAILLE PATTERN DOTS-23478
28CF BRAILLE PATTERN DOTS-123478
28D0 BRAILLE PATTERN DOTS-578
28D1 BRAILLE PATTERN DOTS-1578
28D2 BRAILLE PATTERN DOTS-2578
28D3 BRAILLE PATTERN DOTS-12578
28D4 BRAILLE PATTERN DOTS-3578
28D5 BRAILLE PATTERN DOTS-13578
28D6 BRAILLE PATTERN DOTS-23578
28D7 BRAILLE PATTERN DOTS-123578
28D8 BRAILLE PATTERN DOTS-4578
28D9 BRAILLE PATTERN DOTS-14578
28DA BRAILLE PATTERN DOTS-24578
28DB BRAILLE PATTERN DOTS-124578
28DC BRAILLE PATTERN DOTS-34578
28DD BRAILLE PATTERN DOTS-134578
28DE BRAILLE PATTERN DOTS-234578
28DF BRAILLE PATTERN DOTS-1234578
28E0 BRAILLE PATTERN DOTS-678
28E1 BRAILLE PATTERN DOTS-1678
28E2 BRAILLE PATTERN DOTS-2678
28E3 BRAILLE PATTERN DOTS-12678
28E4 BRAILLE PATTERN DOTS-3678
28E5 BRAILLE PATTERN DOTS-13678
28E6 BRAILLE PATTERN DOTS-23678
28E7 BRAILLE PATTERN DOTS-123678
28E8 BRAILLE PATTERN DOTS-4678
28E9 BRAILLE PATTERN DOTS-14678
28EA BRAILLE PATTERN DOTS-24678
28EB BRAILLE PATTERN DOTS-124678
28EC BRAILLE PATTERN DOTS-34678
28ED BRAILLE PATTERN DOTS-134678
28EE BRAILLE PATTERN DOTS-234678
28EF BRAILLE PATTERN DOTS-1234678
28F0 BRAILLE PATTERN DOTS-5678
28F1 BRAILLE PATTERN DOTS-15678
28F2 BRAILLE PATTERN DOTS-25678
28F3 BRAILLE PATTERN DOTS-125678
28F4 BRAILLE PATTERN DOTS-35678
28F5 BRAILLE PATTERN DOTS-135678
28F6 BRAILLE PATTERN DOTS-235678
28F7 BRAILLE PATTERN DOTS-1235678
28F8 BRAILLE PATTERN DOTS-45678
28F9 BRAILLE PATTERN DOTS-145678
28FA BRAILLE PATTERN DOTS-245678
28FB BRAILLE PATTERN DOTS-1245678
28FC BRAILLE PATTERN DOTS-345678
28FD BRAILLE PATTERN DOTS-1345678
28FE BRAILLE PATTERN DOTS-2345678
28FF BRAILLE PATTERN DOTS-12345678
2900 RIGHTWARDS TWO-HEADED ARROW WITH VERTICAL STROKE
2901 RIGHTWARDS TWO-HEADED ARROW WITH DOUBLE VERTICAL STROKE
2902 LEFTWARDS DOUBLE ARROW WITH VERTICAL STROKE
2903 RIGHTWARDS DOUBLE ARROW WITH VERTICAL STROKE
2904 LEFT RIGHT DOUBLE ARROW WITH VERTICAL STROKE
2905 RIGHTWARDS TWO-HEADED ARROW FROM BAR
2906 LEFTWARDS DOUBLE ARROW FROM BAR
2907 RIGHTWARDS DOUBLE ARROW FROM BAR
2908 DOWNWARDS ARROW WITH HORIZONTAL STROKE
2909 UPWARDS ARROW WITH HORIZONTAL STROKE
290A UPWARDS TRIPLE ARROW
290B DOWNWARDS TRIPLE ARROW
290C LEFTWARDS DOUBLE DASH ARROW
290D RIGHTWARDS DOUBLE DASH ARROW
290E LEFTWARDS TRIPLE DASH ARROW
290F RIGHTWARDS TRIPLE DASH ARROW
2910 RIGHTWARDS TWO-HEADED TRIPLE DASH ARROW
2911 RIGHTWARDS ARROW WITH DOTTED STEM
2912 UPWARDS ARROW TO BAR
2913 DOWNWARDS ARROW TO BAR
2914 RIGHTWARDS ARROW WITH TAIL WITH VERTICAL STROKE
2915 RIGHTWARDS ARROW WITH TAIL WITH DOUBLE VERTICAL STROKE
2916 RIGHTWARDS TWO-HEADED ARROW WITH TAIL
2917 RIGHTWARDS TWO-HEADED ARROW WITH TAIL WITH VERTICAL STROKE
2918 RIGHTWARDS TWO-HEADED ARROW WITH TAIL WITH DOUBLE VERTICAL STROKE
2919 LEFTWARDS ARROW-TAIL
291A RIGHTWARDS ARROW-TAIL
291B LEFTWARDS DOUBLE ARROW-TAIL
291C RIGHTWARDS DOUBLE ARROW-TAIL
291D LEFTWARDS ARROW TO BLACK DIAMOND
291E RIGHTWARDS ARROW TO BLACK DIAMOND
291F LEFTWARDS ARROW FROM BAR TO BLACK DIAMOND
2920 RIGHTWARDS ARROW FROM BAR TO BLACK DIAMOND
2921 NORTH WEST AND SOUTH EAST ARROW
2922 NORTH EAST AND SOUTH WEST ARROW
2923 NORTH WEST ARROW WITH HOOK
2924 NORTH EAST ARROW WITH HOOK
2925 SOUTH EAST ARROW WITH HOOK
2926 SOUTH WEST ARROW WITH HOOK
2927 NORTH WEST ARROW AND NORTH EAST ARROW
2928 NORTH EAST ARROW AND SOUTH EAST ARROW
2929 SOUTH EAST ARROW AND SOUTH WEST ARROW
292A SOUTH WEST ARROW AND NORTH WEST ARROW
292B RISING DIAGONAL CROSSING FALLING DIAGONAL
292C FALLING DIAGONAL CROSSING RISING DIAGONAL
292D SOUTH EAST ARROW CROSSING NORTH EAST ARROW
292E NORTH EAST ARROW CROSSING SOUTH EAST ARROW
292F FALLING DIAGONAL CROSSING NORTH EAST ARROW
2930 RISING DIAGONAL CROSSING SOUTH EAST ARROW
2931 NORTH EAST ARROW CROSSING NORTH WEST ARROW
2932 NORTH WEST ARROW CROSSING NORTH EAST ARROW
2933 WAVE ARROW POINTING DIRECTLY RIGHT
2934 ARROW POINTING RIGHTWARDS THEN CURVING UPWARDS
2935 ARROW POINTING RIGHTWARDS THEN CURVING DOWNWARDS
2936 ARROW POINTING DOWNWARDS THEN CURVING LEFTWARDS
2937 ARROW POINTING DOWNWARDS THEN CURVING RIGHTWARDS
2938 RIGHT-SIDE ARC CLOCKWISE ARROW
2939 LEFT-SIDE ARC ANTICLOCKWISE ARROW
293A TOP ARC ANTICLOCKWISE ARROW
293B BOTTOM ARC ANTICLOCKWISE ARROW
293C TOP ARC CLOCKWISE ARROW WITH MINUS
293D TOP ARC ANTICLOCKWISE ARROW WITH PLUS
293E LOWER RIGHT SEMICIRCULAR CLOCKWISE ARROW
293F LOWER LEFT SEMICIRCULAR ANTICLOCKWISE ARROW
2940 ANTICLOCKWISE CLOSED CIRCLE ARROW
2941 CLOCKWISE CLOSED CIRCLE ARROW
2942 RIGHTWARDS ARROW ABOVE SHORT LEFTWARDS ARROW
2943 LEFTWARDS ARROW ABOVE SHORT RIGHTWARDS ARROW
2944 SHORT RIGHTWARDS ARROW ABOVE LEFTWARDS ARROW
2945 RIGHTWARDS ARROW WITH PLUS BELOW
2946 LEFTWARDS ARROW WITH PLUS BELOW
2947 RIGHTWARDS ARROW THROUGH X
2948 LEFT RIGHT ARROW THROUGH SMALL CIRCLE
2949 UPWARDS TWO-HEADED ARROW FROM SMALL CIRCLE
294A LEFT BARB UP RIGHT BARB DOWN HARPOON
294B LEFT BARB DOWN RIGHT BARB UP HARPOON
294C UP BARB RIGHT DOWN BARB LEFT HARPOON
294D UP BARB LEFT DOWN BARB RIGHT HARPOON
294E LEFT BARB UP RIGHT BARB UP HARPOON
294F UP BARB RIGHT DOWN BARB RIGHT HARPOON
2950 LEFT BARB DOWN RIGHT BARB DOWN HARPOON
2951 UP BARB LEFT DOWN BARB LEFT HARPOON
2952 LEFTWARDS HARPOON WITH BARB UP TO BAR
2953 RIGHTWARDS HARPOON WITH BARB UP TO BAR
2954 UPWARDS HARPOON WITH BARB RIGHT TO BAR
2955 DOWNWARDS HARPOON WITH BARB RIGHT TO BAR
2956 LEFTWARDS HARPOON WITH BARB DOWN TO BAR
2957 RIGHTWARDS HARPOON WITH BARB DOWN TO BAR
2958 UPWARDS HARPOON WITH BARB LEFT TO BAR
2959 DOWNWARDS HARPOON WITH BARB LEFT TO BAR
295A LEFTWARDS HARPOON WITH BARB UP FROM BAR
295B RIGHTWARDS HARPOON WITH BARB UP FROM BAR
295C UPWARDS HARPOON WITH BARB RIGHT FROM BAR
295D DOWNWARDS HARPOON WITH BARB RIGHT FROM BAR
295E LEFTWARDS HARPOON WITH BARB DOWN FROM BAR
295F RIGHTWARDS HARPOON WITH BARB DOWN FROM BAR
2960 UPWARDS HARPOON WITH BARB LEFT FROM BAR
2961 DOWNWARDS HARPOON WITH BARB LEFT FROM BAR
2962 LEFTWARDS HARPOON WITH BARB UP ABOVE LEFTWARDS HARPOON WITH BARB DOWN
2963 UPWARDS HARPOON WITH BARB LEFT BESIDE UPWARDS HARPOON WITH BARB RIGHT
2964 RIGHTWARDS HARPOON WITH BARB UP ABOVE RIGHTWARDS HARPOON WITH BARB DOWN
2965 DOWNWARDS HARPOON WITH BARB LEFT BESIDE DOWNWARDS HARPOON WITH BARB RIGHT
2966 LEFTWARDS HARPOON WITH BARB UP ABOVE RIGHTWARDS HARPOON WITH BARB UP
2967 LEFTWARDS HARPOON WITH BARB DOWN ABOVE RIGHTWARDS HARPOON WITH BARB DOWN
2968 RIGHTWARDS HARPOON WITH BARB UP ABOVE LEFTWARDS HARPOON WITH BARB UP
2969 RIGHTWARDS HARPOON WITH BARB DOWN ABOVE LEFTWARDS HARPOON WITH BARB DOWN
296A LEFTWARDS HARPOON WITH BARB UP ABOVE LONG DASH
296B LEFTWARDS HARPOON WITH BARB DOWN BELOW LONG DASH
296C RIGHTWARDS HARPOON WITH BARB UP ABOVE LONG DASH
296D RIGHTWARDS HARPOON WITH BARB DOWN BELOW LONG DASH
296E UPWARDS HARPOON WITH BARB LEFT BESIDE DOWNWARDS HARPOON WITH BARB RIGHT
296F DOWNWARDS HARPOON WITH BARB LEFT BESIDE UPWARDS HARPOON WITH BARB RIGHT
2970 RIGHT DOUBLE ARROW WITH ROUNDED HEAD
2971 EQUALS SIGN ABOVE RIGHTWARDS ARROW
2972 TILDE OPERATOR ABOVE RIGHTWARDS ARROW
2973 LEFTWARDS ARROW ABOVE TILDE OPERATOR
2974 RIGHTWARDS ARROW ABOVE TILDE OPERATOR
2975 RIGHTWARDS ARROW ABOVE ALMOST EQUAL TO
2976 LESS-THAN ABOVE LEFTWARDS ARROW
2977 LEFTWARDS ARROW THROUGH LESS-THAN
2978 GREATER-THAN ABOVE RIGHTWARDS ARROW
2979 SUBSET ABOVE RIGHTWARDS ARROW
297A LEFTWARDS ARROW THROUGH SUBSET
297B SUPERSET ABOVE LEFTWARDS ARROW
297C LEFT FISH TAIL
297D RIGHT FISH TAIL
297E UP FISH TAIL
297F DOWN FISH TAIL
2980 TRIPLE VERTICAL BAR DELIMITER
2981 Z NOTATION SPOT
2982 Z NOTATION TYPE COLON
2983 LEFT WHITE CURLY BRACKET
2984 RIGHT WHITE CURLY BRACKET
2985 LEFT WHITE PARENTHESIS
2986 RIGHT WHITE PARENTHESIS
2987 Z NOTATION LEFT IMAGE BRACKET
2988 Z NOTATION RIGHT IMAGE BRACKET
2989 Z NOTATION LEFT BINDING BRACKET
298A Z NOTATION RIGHT BINDING BRACKET
298B LEFT SQUARE BRACKET WITH UNDERBAR
298C RIGHT SQUARE BRACKET WITH UNDERBAR
298D LEFT SQUARE BRACKET WITH TICK IN TOP CORNER
298E RIGHT SQUARE BRACKET WITH TICK IN BOTTOM CORNER
298F LEFT SQUARE BRACKET WITH TICK IN BOTTOM CORNER
2990 RIGHT SQUARE BRACKET WITH TICK IN TOP CORNER
2991 LEFT ANGLE BRACKET WITH DOT
2992 RIGHT ANGLE BRACKET WITH DOT
2993 LEFT ARC LESS-THAN BRACKET
2994 RIGHT ARC GREATER-THAN BRACKET
2995 DOUBLE LEFT ARC GREATER-THAN BRACKET
2996 DOUBLE RIGHT ARC LESS-THAN BRACKET
2997 LEFT BLACK TORTOISE SHELL BRACKET
2998 RIGHT BLACK TORTOISE SHELL BRACKET
2999 DOTTED FENCE
299A VERTICAL ZIGZAG LINE
299B MEASURED ANGLE OPENING LEFT
299C RIGHT ANGLE VARIANT WITH SQUARE
299D MEASURED RIGHT ANGLE WITH DOT
299E ANGLE WITH S INSIDE
299F ACUTE ANGLE
29A0 SPHERICAL ANGLE OPENING LEFT
29A1 SPHERICAL ANGLE OPENING UP
29A2 TURNED ANGLE
29A3 REVERSED ANGLE
29A4 ANGLE WITH UNDERBAR
29A5 REVERSED ANGLE WITH UNDERBAR
29A6 OBLIQUE ANGLE OPENING UP
29A7 OBLIQUE ANGLE OPENING DOWN
29A8 MEASURED ANGLE WITH OPEN ARM ENDING IN ARROW POINTING UP AND RIGHT
29A9 MEASURED ANGLE WITH OPEN ARM ENDING IN ARROW POINTING UP AND LEFT
29AA MEASURED ANGLE WITH OPEN ARM ENDING IN ARROW POINTING DOWN AND RIGHT
29AB MEASURED ANGLE WITH OPEN ARM ENDING IN ARROW POINTING DOWN AND LEFT
29AC MEASURED ANGLE WITH OPEN ARM ENDING IN ARROW POINTING RIGHT AND UP
29AD MEASURED ANGLE WITH OPEN ARM ENDING IN ARROW POINTING LEFT AND UP
29AE MEASURED ANGLE WITH OPEN ARM ENDING IN ARROW POINTING RIGHT AND DOWN
29AF MEASURED ANGLE WITH OPEN ARM ENDING IN ARROW POINTING LEFT AND DOWN
29B0 REVERSED EMPTY SET
29B1 EMPTY SET WITH OVERBAR
29B2 EMPTY SET WITH SMALL CIRCLE ABOVE
29B3 EMPTY SET WITH RIGHT ARROW ABOVE
29B4 EMPTY SET WITH LEFT ARROW ABOVE
29B5 CIRCLE WITH HORIZONTAL BAR
29B6 CIRCLED VERTICAL BAR
29B7 CIRCLED PARALLEL
29B8 CIRCLED REVERSE SOLIDUS
29B9 CIRCLED PERPENDICULAR
29BA CIRCLE DIVIDED BY HORIZONTAL BAR AND TOP HALF DIVIDED BY VERTICAL BAR
29BB CIRCLE WITH SUPERIMPOSED X
29BC CIRCLED ANTICLOCKWISE-ROTATED DIVISION SIGN
29BD UP ARROW THROUGH CIRCLE
29BE CIRCLED WHITE BULLET
29BF CIRCLED BULLET
29C0 CIRCLED LESS-THAN
29C1 CIRCLED GREATER-THAN
29C2 CIRCLE WITH SMALL CIRCLE TO THE RIGHT
29C3 CIRCLE WITH TWO HORIZONTAL STROKES TO THE RIGHT
29C4 SQUARED RISING DIAGONAL SLASH
29C5 SQUARED FALLING DIAGONAL SLASH
29C6 SQUARED ASTERISK
29C7 SQUARED SMALL CIRCLE
29C8 SQUARED SQUARE
29C9 TWO JOINED SQUARES
29CA TRIANGLE WITH DOT ABOVE
29CB TRIANGLE WITH UNDERBAR
29CC S IN TRIANGLE
29CD TRIANGLE WITH SERIFS AT BOTTOM
29CE RIGHT TRIANGLE ABOVE LEFT TRIANGLE
29CF LEFT TRIANGLE BESIDE VERTICAL BAR
29D0 VERTICAL BAR BESIDE RIGHT TRIANGLE
29D1 BOWTIE WITH LEFT HALF BLACK
29D2 BOWTIE WITH RIGHT HALF BLACK
29D3 BLACK BOWTIE
29D4 TIMES WITH LEFT HALF BLACK
29D5 TIMES WITH RIGHT HALF BLACK
29D6 WHITE HOURGLASS
29D7 BLACK HOURGLASS
29D8 LEFT WIGGLY FENCE
29D9 RIGHT WIGGLY FENCE
29DA LEFT DOUBLE WIGGLY FENCE
29DB RIGHT DOUBLE WIGGLY FENCE
29DC INCOMPLETE INFINITY
29DD TIE OVER INFINITY
29DE INFINITY NEGATED WITH VERTICAL BAR
29DF DOUBLE-ENDED MULTIMAP
29E0 SQUARE WITH CONTOURED OUTLINE
29E1 INCREASES AS
29E2 SHUFFLE PRODUCT
29E3 EQUALS SIGN AND SLANTED PARALLEL
29E4 EQUALS SIGN AND SLANTED PARALLEL WITH TILDE ABOVE
29E5 IDENTICAL TO AND SLANTED PARALLEL
29E6 GLEICH STARK
29E7 THERMODYNAMIC
29E8 DOWN-POINTING TRIANGLE WITH LEFT HALF BLACK
29E9 DOWN-POINTING TRIANGLE WITH RIGHT HALF BLACK
29EA BLACK DIAMOND WITH DOWN ARROW
29EB BLACK LOZENGE
29EC WHITE CIRCLE WITH DOWN ARROW
29ED BLACK CIRCLE WITH DOWN ARROW
29EE ERROR-BARRED WHITE SQUARE
29EF ERROR-BARRED BLACK SQUARE
29F0 ERROR-BARRED WHITE DIAMOND
29F1 ERROR-BARRED BLACK DIAMOND
29F2 ERROR-BARRED WHITE CIRCLE
29F3 ERROR-BARRED BLACK CIRCLE
29F4 RULE-DELAYED
29F5 REVERSE SOLIDUS OPERATOR
29F6 SOLIDUS WITH OVERBAR
29F7 REVERSE SOLIDUS WITH HORIZONTAL STROKE
29F8 BIG SOLIDUS
29F9 BIG REVERSE SOLIDUS
29FA DOUBLE PLUS
29FB TRIPLE PLUS
29FC LEFT-POINTING CURVED ANGLE BRACKET
29FD RIGHT-POINTING CURVED ANGLE BRACKET
29FE TINY
29FF MINY
2A00 N-ARY CIRCLED DOT OPERATOR
2A01 N-ARY CIRCLED PLUS OPERATOR
2A02 N-ARY CIRCLED TIMES OPERATOR
2A03 N-ARY UNION OPERATOR WITH DOT
2A04 N-ARY UNION OPERATOR WITH PLUS
2A05 N-ARY SQUARE INTERSECTION OPERATOR
2A06 N-ARY SQUARE UNION OPERATOR
2A07 TWO LOGICAL AND OPERATOR
2A08 TWO LOGICAL OR OPERATOR
2A09 N-ARY TIMES OPERATOR
2A0A MODULO TWO SUM
2A0B SUMMATION WITH INTEGRAL
2A0C QUADRUPLE INTEGRAL OPERATOR
2A0D FINITE PART INTEGRAL
2A0E INTEGRAL WITH DOUBLE STROKE
2A0F INTEGRAL AVERAGE WITH SLASH
2A10 CIRCULATION FUNCTION
2A11 ANTICLOCKWISE INTEGRATION
2A12 LINE INTEGRATION WITH RECTANGULAR PATH AROUND POLE
2A13 LINE INTEGRATION WITH SEMICIRCULAR PATH AROUND POLE
2A14 LINE INTEGRATION NOT INCLUDING THE POLE
2A15 INTEGRAL AROUND A POINT OPERATOR
2A16 QUATERNION INTEGRAL OPERATOR
2A17 INTEGRAL WITH LEFTWARDS ARROW WITH HOOK
2A18 INTEGRAL WITH TIMES SIGN
2A19 INTEGRAL WITH INTERSECTION
2A1A INTEGRAL WITH UNION
2A1B INTEGRAL WITH OVERBAR
2A1C INTEGRAL WITH UNDERBAR
2A1D JOIN
2A1E LARGE LEFT TRIANGLE OPERATOR
2A1F Z NOTATION SCHEMA COMPOSITION
2A20 Z NOTATION SCHEMA PIPING
2A21 Z NOTATION SCHEMA PROJECTION
2A22 PLUS SIGN WITH SMALL CIRCLE ABOVE
2A23 PLUS SIGN WITH CIRCUMFLEX ACCENT ABOVE
2A24 PLUS SIGN WITH TILDE ABOVE
2A25 PLUS SIGN WITH DOT BELOW
2A26 PLUS SIGN WITH TILDE BELOW
2A27 PLUS SIGN WITH SUBSCRIPT TWO
2A28 PLUS SIGN WITH BLACK TRIANGLE
2A29 MINUS SIGN WITH COMMA ABOVE
2A2A MINUS SIGN WITH DOT BELOW
2A2B MINUS SIGN WITH FALLING DOTS
2A2C MINUS SIGN WITH RISING DOTS
2A2D PLUS SIGN IN LEFT HALF CIRCLE
2A2E PLUS SIGN IN RIGHT HALF CIRCLE
2A2F VECTOR OR CROSS PRODUCT
2A30 MULTIPLICATION SIGN WITH DOT ABOVE
2A31 MULTIPLICATION SIGN WITH UNDERBAR
2A32 SEMIDIRECT PRODUCT WITH BOTTOM CLOSED
2A33 SMASH PRODUCT
2A34 MULTIPLICATION SIGN IN LEFT HALF CIRCLE
2A35 MULTIPLICATION SIGN IN RIGHT HALF CIRCLE
2A36 CIRCLED MULTIPLICATION SIGN WITH CIRCUMFLEX ACCENT
2A37 MULTIPLICATION SIGN IN DOUBLE CIRCLE
2A38 CIRCLED DIVISION SIGN
2A39 PLUS SIGN IN TRIANGLE
2A3A MINUS SIGN IN TRIANGLE
2A3B MULTIPLICATION SIGN IN TRIANGLE
2A3C INTERIOR PRODUCT
2A3D RIGHTHAND INTERIOR PRODUCT
2A3E Z NOTATION RELATIONAL COMPOSITION
2A3F AMALGAMATION OR COPRODUCT
2A40 INTERSECTION WITH DOT
2A41 UNION WITH MINUS SIGN
2A42 UNION WITH OVERBAR
2A43 INTERSECTION WITH OVERBAR
2A44 INTERSECTION WITH LOGICAL AND
2A45 UNION WITH LOGICAL OR
2A46 UNION ABOVE INTERSECTION
2A47 INTERSECTION ABOVE UNION
2A48 UNION ABOVE BAR ABOVE INTERSECTION
2A49 INTERSECTION ABOVE BAR ABOVE UNION
2A4A UNION BESIDE AND JOINED WITH UNION
2A4B INTERSECTION BESIDE AND JOINED WITH INTERSECTION
2A4C CLOSED UNION WITH SERIFS
2A4D CLOSED INTERSECTION WITH SERIFS
2A4E DOUBLE SQUARE INTERSECTION
2A4F DOUBLE SQUARE UNION
2A50 CLOSED UNION WITH SERIFS AND SMASH PRODUCT
2A51 LOGICAL AND WITH DOT ABOVE
2A52 LOGICAL OR WITH DOT ABOVE
2A53 DOUBLE LOGICAL AND
2A54 DOUBLE LOGICAL OR
2A55 TWO INTERSECTING LOGICAL AND
2A56 TWO INTERSECTING LOGICAL OR
2A57 SLOPING LARGE OR
2A58 SLOPING LARGE AND
2A59 LOGICAL OR OVERLAPPING LOGICAL AND
2A5A LOGICAL AND WITH MIDDLE STEM
2A5B LOGICAL OR WITH MIDDLE STEM
2A5C LOGICAL AND WITH HORIZONTAL DASH
2A5D LOGICAL OR WITH HORIZONTAL DASH
2A5E LOGICAL AND WITH DOUBLE OVERBAR
2A5F LOGICAL AND WITH UNDERBAR
2A60 LOGICAL AND WITH DOUBLE UNDERBAR
2A61 SMALL VEE WITH UNDERBAR
2A62 LOGICAL OR WITH DOUBLE OVERBAR
2A63 LOGICAL OR WITH DOUBLE UNDERBAR
2A64 Z NOTATION DOMAIN ANTIRESTRICTION
2A65 Z NOTATION RANGE ANTIRESTRICTION
2A66 EQUALS SIGN WITH DOT BELOW
2A67 IDENTICAL WITH DOT ABOVE
2A68 TRIPLE HORIZONTAL BAR WITH DOUBLE VERTICAL STROKE
2A69 TRIPLE HORIZONTAL BAR WITH TRIPLE VERTICAL STROKE
2A6A TILDE OPERATOR WITH DOT ABOVE
2A6B TILDE OPERATOR WITH RISING DOTS
2A6C SIMILAR MINUS SIMILAR
2A6D CONGRUENT WITH DOT ABOVE
2A6E EQUALS WITH ASTERISK
2A6F ALMOST EQUAL TO WITH CIRCUMFLEX ACCENT
2A70 APPROXIMATELY EQUAL OR EQUAL TO
2A71 EQUALS SIGN ABOVE PLUS SIGN
2A72 PLUS SIGN ABOVE EQUALS SIGN
2A73 EQUALS SIGN ABOVE TILDE OPERATOR
2A74 DOUBLE COLON EQUAL
2A75 TWO CONSECUTIVE EQUALS SIGNS
2A76 THREE CONSECUTIVE EQUALS SIGNS
2A77 EQUALS SIGN WITH TWO DOTS ABOVE AND TWO DOTS BELOW
2A78 EQUIVALENT WITH FOUR DOTS ABOVE
2A79 LESS-THAN WITH CIRCLE INSIDE
2A7A GREATER-THAN WITH CIRCLE INSIDE
2A7B LESS-THAN WITH QUESTION MARK ABOVE
2A7C GREATER-THAN WITH QUESTION MARK ABOVE
2A7D LESS-THAN OR SLANTED EQUAL TO
2A7E GREATER-THAN OR SLANTED EQUAL TO
2A7F LESS-THAN OR SLANTED EQUAL TO WITH DOT INSIDE
2A80 GREATER-THAN OR SLANTED EQUAL TO WITH DOT INSIDE
2A81 LESS-THAN OR SLANTED EQUAL TO WITH DOT ABOVE
2A82 GREATER-THAN OR SLANTED EQUAL TO WITH DOT ABOVE
2A83 LESS-THAN OR SLANTED EQUAL TO WITH DOT ABOVE RIGHT
2A84 GREATER-THAN OR SLANTED EQUAL TO WITH DOT ABOVE LEFT
2A85 LESS-THAN OR APPROXIMATE
2A86 GREATER-THAN OR APPROXIMATE
2A87 LESS-THAN AND SINGLE-LINE NOT EQUAL TO
2A88 GREATER-THAN AND SINGLE-LINE NOT EQUAL TO
2A89 LESS-THAN AND NOT APPROXIMATE
2A8A GREATER-THAN AND NOT APPROXIMATE
2A8B LESS-THAN ABOVE DOUBLE-LINE EQUAL ABOVE GREATER-THAN
2A8C GREATER-THAN ABOVE DOUBLE-LINE EQUAL ABOVE LESS-THAN
2A8D LESS-THAN ABOVE SIMILAR OR EQUAL
2A8E GREATER-THAN ABOVE SIMILAR OR EQUAL
2A8F LESS-THAN ABOVE SIMILAR ABOVE GREATER-THAN
2A90 GREATER-THAN ABOVE SIMILAR ABOVE LESS-THAN
2A91 LESS-THAN ABOVE GREATER-THAN ABOVE DOUBLE-LINE EQUAL
2A92 GREATER-THAN ABOVE LESS-THAN ABOVE DOUBLE-LINE EQUAL
2A93 LESS-THAN ABOVE SLANTED EQUAL ABOVE GREATER-THAN ABOVE SLANTED EQUAL
2A94 GREATER-THAN ABOVE SLANTED EQUAL ABOVE LESS-THAN ABOVE SLANTED EQUAL
2A95 SLANTED EQUAL TO OR LESS-THAN
2A96 SLANTED EQUAL TO OR GREATER-THAN
2A97 SLANTED EQUAL TO OR LESS-THAN WITH DOT INSIDE
2A98 SLANTED EQUAL TO OR GREATER-THAN WITH DOT INSIDE
2A99 DOUBLE-LINE EQUAL TO OR LESS-THAN
2A9A DOUBLE-LINE EQUAL TO OR GREATER-THAN
2A9B DOUBLE-LINE SLANTED EQUAL TO OR LESS-THAN
2A9C DOUBLE-LINE SLANTED EQUAL TO OR GREATER-THAN
2A9D SIMILAR OR LESS-THAN
2A9E SIMILAR OR GREATER-THAN
2A9F SIMILAR ABOVE LESS-THAN ABOVE EQUALS SIGN
2AA0 SIMILAR ABOVE GREATER-THAN ABOVE EQUALS SIGN
2AA1 DOUBLE NESTED LESS-THAN
2AA2 DOUBLE NESTED GREATER-THAN
2AA3 DOUBLE NESTED LESS-THAN WITH UNDERBAR
2AA4 GREATER-THAN OVERLAPPING LESS-THAN
2AA5 GREATER-THAN BESIDE LESS-THAN
2AA6 LESS-THAN CLOSED BY CURVE
2AA7 GREATER-THAN CLOSED BY CURVE
2AA8 LESS-THAN CLOSED BY CURVE ABOVE SLANTED EQUAL
2AA9 GREATER-THAN CLOSED BY CURVE ABOVE SLANTED EQUAL
2AAA SMALLER THAN
2AAB LARGER THAN
2AAC SMALLER THAN OR EQUAL TO
2AAD LARGER THAN OR EQUAL TO
2AAE EQUALS SIGN WITH BUMPY ABOVE
2AAF PRECEDES ABOVE SINGLE-LINE EQUALS SIGN
2AB0 SUCCEEDS ABOVE SINGLE-LINE EQUALS SIGN
2AB1 PRECEDES ABOVE SINGLE-LINE NOT EQUAL TO
2AB2 SUCCEEDS ABOVE SINGLE-LINE NOT EQUAL TO
2AB3 PRECEDES ABOVE EQUALS SIGN
2AB4 SUCCEEDS ABOVE EQUALS SIGN
2AB5 PRECEDES ABOVE NOT EQUAL TO
2AB6 SUCCEEDS ABOVE NOT EQUAL TO
2AB7 PRECEDES ABOVE ALMOST EQUAL TO
2AB8 SUCCEEDS ABOVE ALMOST EQUAL TO
2AB9 PRECEDES ABOVE NOT ALMOST EQUAL TO
2ABA SUCCEEDS ABOVE NOT ALMOST EQUAL TO
2ABB DOUBLE PRECEDES
2ABC DOUBLE SUCCEEDS
2ABD SUBSET WITH DOT
2ABE SUPERSET WITH DOT
2ABF SUBSET WITH PLUS SIGN BELOW
2AC0 SUPERSET WITH PLUS SIGN BELOW
2AC1 SUBSET WITH MULTIPLICATION SIGN BELOW
2AC2 SUPERSET WITH MULTIPLICATION SIGN BELOW
2AC3 SUBSET OF OR EQUAL TO WITH DOT ABOVE
2AC4 SUPERSET OF OR EQUAL TO WITH DOT ABOVE
2AC5 SUBSET OF ABOVE EQUALS SIGN
2AC6 SUPERSET OF ABOVE EQUALS SIGN
2AC7 SUBSET OF ABOVE TILDE OPERATOR
2AC8 SUPERSET OF ABOVE TILDE OPERATOR
2AC9 SUBSET OF ABOVE ALMOST EQUAL TO
2ACA SUPERSET OF ABOVE ALMOST EQUAL TO
2ACB SUBSET OF ABOVE NOT EQUAL TO
2ACC SUPERSET OF ABOVE NOT EQUAL TO
2ACD SQUARE LEFT OPEN BOX OPERATOR
2ACE SQUARE RIGHT OPEN BOX OPERATOR
2ACF CLOSED SUBSET
2AD0 CLOSED SUPERSET
2AD1 CLOSED SUBSET OR EQUAL TO
2AD2 CLOSED SUPERSET OR EQUAL TO
2AD3 SUBSET ABOVE SUPERSET
2AD4 SUPERSET ABOVE SUBSET
2AD5 SUBSET ABOVE SUBSET
2AD6 SUPERSET ABOVE SUPERSET
2AD7 SUPERSET BESIDE SUBSET
2AD8 SUPERSET BESIDE AND JOINED BY DASH WITH SUBSET
2AD9 ELEMENT OF OPENING DOWNWARDS
2ADA PITCHFORK WITH TEE TOP
2ADB TRANSVERSAL INTERSECTION
2ADC FORKING
2ADD NONFORKING
2ADE SHORT LEFT TACK
2ADF SHORT DOWN TACK
2AE0 SHORT UP TACK
2AE1 PERPENDICULAR WITH S
2AE2 VERTICAL BAR TRIPLE RIGHT TURNSTILE
2AE3 DOUBLE VERTICAL BAR LEFT TURNSTILE
2AE4 VERTICAL BAR DOUBLE LEFT TURNSTILE
2AE5 DOUBLE VERTICAL BAR DOUBLE LEFT TURNSTILE
2AE6 LONG DASH FROM LEFT MEMBER OF DOUBLE VERTICAL
2AE7 SHORT DOWN TACK WITH OVERBAR
2AE8 SHORT UP TACK WITH UNDERBAR
2AE9 SHORT UP TACK ABOVE SHORT DOWN TACK
2AEA DOUBLE DOWN TACK
2AEB DOUBLE UP TACK
2AEC DOUBLE STROKE NOT SIGN
2AED REVERSED DOUBLE STROKE NOT SIGN
2AEE DOES NOT DIVIDE WITH REVERSED NEGATION SLASH
2AEF VERTICAL LINE WITH CIRCLE ABOVE
2AF0 VERTICAL LINE WITH CIRCLE BELOW
2AF1 DOWN TACK WITH CIRCLE BELOW
2AF2 PARALLEL WITH HORIZONTAL STROKE
2AF3 PARALLEL WITH TILDE OPERATOR
2AF4 TRIPLE VERTICAL BAR BINARY RELATION
2AF5 TRIPLE VERTICAL BAR WITH HORIZONTAL STROKE
2AF6 TRIPLE COLON OPERATOR
2AF7 TRIPLE NESTED LESS-THAN
2AF8 TRIPLE NESTED GREATER-THAN
2AF9 DOUBLE-LINE SLANTED LESS-THAN OR EQUAL TO
2AFA DOUBLE-LINE SLANTED GREATER-THAN OR EQUAL TO
2AFB TRIPLE SOLIDUS BINARY RELATION
2AFC LARGE TRIPLE VERTICAL BAR OPERATOR
2AFD DOUBLE SOLIDUS OPERATOR
2AFE WHITE VERTICAL BAR
2AFF N-ARY WHITE VERTICAL BAR
2B00 NORTH EAST WHITE ARROW
2B01 NORTH WEST WHITE ARROW
2B02 SOUTH EAST WHITE ARROW
2B03 SOUTH WEST WHITE ARROW
2B04 LEFT RIGHT WHITE ARROW
2B05 LEFTWARDS BLACK ARROW
2B06 UPWARDS BLACK ARROW
2B07 DOWNWARDS BLACK ARROW
2B08 NORTH EAST BLACK ARROW
2B09 NORTH WEST BLACK ARROW
2B0A SOUTH EAST BLACK ARROW
2B0B SOUTH WEST BLACK ARROW
2B0C LEFT RIGHT BLACK ARROW
2B0D UP DOWN BLACK ARROW
2B0E RIGHTWARDS ARROW WITH TIP DOWNWARDS
2B0F RIGHTWARDS ARROW WITH TIP UPWARDS
2B10 LEFTWARDS ARROW WITH TIP DOWNWARDS
2B11 LEFTWARDS ARROW WITH TIP UPWARDS
2B12 SQUARE WITH TOP HALF BLACK
2B13 SQUARE WITH BOTTOM HALF BLACK
2C00 GLAGOLITIC CAPITAL LETTER AZU
2C01 GLAGOLITIC CAPITAL LETTER BUKY
2C02 GLAGOLITIC CAPITAL LETTER VEDE
2C03 GLAGOLITIC CAPITAL LETTER GLAGOLI
2C04 GLAGOLITIC CAPITAL LETTER DOBRO
2C05 GLAGOLITIC CAPITAL LETTER YESTU
2C06 GLAGOLITIC CAPITAL LETTER ZHIVETE
2C07 GLAGOLITIC CAPITAL LETTER DZELO
2C08 GLAGOLITIC CAPITAL LETTER ZEMLJA
2C09 GLAGOLITIC CAPITAL LETTER IZHE
2C0A GLAGOLITIC CAPITAL LETTER INITIAL IZHE
2C0B GLAGOLITIC CAPITAL LETTER I
2C0C GLAGOLITIC CAPITAL LETTER DJERVI
2C0D GLAGOLITIC CAPITAL LETTER KAKO
2C0E GLAGOLITIC CAPITAL LETTER LJUDIJE
2C0F GLAGOLITIC CAPITAL LETTER MYSLITE
2C10 GLAGOLITIC CAPITAL LETTER NASHI
2C11 GLAGOLITIC CAPITAL LETTER ONU
2C12 GLAGOLITIC CAPITAL LETTER POKOJI
2C13 GLAGOLITIC CAPITAL LETTER RITSI
2C14 GLAGOLITIC CAPITAL LETTER SLOVO
2C15 GLAGOLITIC CAPITAL LETTER TVRIDO
2C16 GLAGOLITIC CAPITAL LETTER UKU
2C17 GLAGOLITIC CAPITAL LETTER FRITU
2C18 GLAGOLITIC CAPITAL LETTER HERU
2C19 GLAGOLITIC CAPITAL LETTER OTU
2C1A GLAGOLITIC CAPITAL LETTER PE
2C1B GLAGOLITIC CAPITAL LETTER SHTA
2C1C GLAGOLITIC CAPITAL LETTER TSI
2C1D GLAGOLITIC CAPITAL LETTER CHRIVI
2C1E GLAGOLITIC CAPITAL LETTER SHA
2C1F GLAGOLITIC CAPITAL LETTER YERU
2C20 GLAGOLITIC CAPITAL LETTER YERI
2C21 GLAGOLITIC CAPITAL LETTER YATI
2C22 GLAGOLITIC CAPITAL LETTER SPIDERY HA
2C23 GLAGOLITIC CAPITAL LETTER YU
2C24 GLAGOLITIC CAPITAL LETTER SMALL YUS
2C25 GLAGOLITIC CAPITAL LETTER SMALL YUS WITH TAIL
2C26 GLAGOLITIC CAPITAL LETTER YO
2C27 GLAGOLITIC CAPITAL LETTER IOTATED SMALL YUS
2C28 GLAGOLITIC CAPITAL LETTER BIG YUS
2C29 GLAGOLITIC CAPITAL LETTER IOTATED BIG YUS
2C2A GLAGOLITIC CAPITAL LETTER FITA
2C2B GLAGOLITIC CAPITAL LETTER IZHITSA
2C2C GLAGOLITIC CAPITAL LETTER SHTAPIC
2C2D GLAGOLITIC CAPITAL LETTER TROKUTASTI A
2C2E GLAGOLITIC CAPITAL LETTER LATINATE MYSLITE
2C30 GLAGOLITIC SMALL LETTER AZU
2C31 GLAGOLITIC SMALL LETTER BUKY
2C32 GLAGOLITIC SMALL LETTER VEDE
2C33 GLAGOLITIC SMALL LETTER GLAGOLI
2C34 GLAGOLITIC SMALL LETTER DOBRO
2C35 GLAGOLITIC SMALL LETTER YESTU
2C36 GLAGOLITIC SMALL LETTER ZHIVETE
2C37 GLAGOLITIC SMALL LETTER DZELO
2C38 GLAGOLITIC SMALL LETTER ZEMLJA
2C39 GLAGOLITIC SMALL LETTER IZHE
2C3A GLAGOLITIC SMALL LETTER INITIAL IZHE
2C3B GLAGOLITIC SMALL LETTER I
2C3C GLAGOLITIC SMALL LETTER DJERVI
2C3D GLAGOLITIC SMALL LETTER KAKO
2C3E GLAGOLITIC SMALL LETTER LJUDIJE
2C3F GLAGOLITIC SMALL LETTER MYSLITE
2C40 GLAGOLITIC SMALL LETTER NASHI
2C41 GLAGOLITIC SMALL LETTER ONU
2C42 GLAGOLITIC SMALL LETTER POKOJI
2C43 GLAGOLITIC SMALL LETTER RITSI
2C44 GLAGOLITIC SMALL LETTER SLOVO
2C45 GLAGOLITIC SMALL LETTER TVRIDO
2C46 GLAGOLITIC SMALL LETTER UKU
2C47 GLAGOLITIC SMALL LETTER FRITU
2C48 GLAGOLITIC SMALL LETTER HERU
2C49 GLAGOLITIC SMALL LETTER OTU
2C4A GLAGOLITIC SMALL LETTER PE
2C4B GLAGOLITIC SMALL LETTER SHTA
2C4C GLAGOLITIC SMALL LETTER TSI
2C4D GLAGOLITIC SMALL LETTER CHRIVI
2C4E GLAGOLITIC SMALL LETTER SHA
2C4F GLAGOLITIC SMALL LETTER YERU
2C50 GLAGOLITIC SMALL LETTER YERI
2C51 GLAGOLITIC SMALL LETTER YATI
2C52 GLAGOLITIC SMALL LETTER SPIDERY HA
2C53 GLAGOLITIC SMALL LETTER YU
2C54 GLAGOLITIC SMALL LETTER SMALL YUS
2C55 GLAGOLITIC SMALL LETTER SMALL YUS WITH TAIL
2C56 GLAGOLITIC SMALL LETTER YO
2C57 GLAGOLITIC SMALL LETTER IOTATED SMALL YUS
2C58 GLAGOLITIC SMALL LETTER BIG YUS
2C59 GLAGOLITIC SMALL LETTER IOTATED BIG YUS
2C5A GLAGOLITIC SMALL LETTER FITA
2C5B GLAGOLITIC SMALL LETTER IZHITSA
2C5C GLAGOLITIC SMALL LETTER SHTAPIC
2C5D GLAGOLITIC SMALL LETTER TROKUTASTI A
2C5E GLAGOLITIC SMALL LETTER LATINATE MYSLITE
2C80 COPTIC CAPITAL LETTER ALFA
2C81 COPTIC SMALL LETTER ALFA
2C82 COPTIC CAPITAL LETTER VIDA
2C83 COPTIC SMALL LETTER VIDA
2C84 COPTIC CAPITAL LETTER GAMMA
2C85 COPTIC SMALL LETTER GAMMA
2C86 COPTIC CAPITAL LETTER DALDA
2C87 COPTIC SMALL LETTER DALDA
2C88 COPTIC CAPITAL LETTER EIE
2C89 COPTIC SMALL LETTER EIE
2C8A COPTIC CAPITAL LETTER SOU
2C8B COPTIC SMALL LETTER SOU
2C8C COPTIC CAPITAL LETTER ZATA
2C8D COPTIC SMALL LETTER ZATA
2C8E COPTIC CAPITAL LETTER HATE
2C8F COPTIC SMALL LETTER HATE
2C90 COPTIC CAPITAL LETTER THETHE
2C91 COPTIC SMALL LETTER THETHE
2C92 COPTIC CAPITAL LETTER IAUDA
2C93 COPTIC SMALL LETTER IAUDA
2C94 COPTIC CAPITAL LETTER KAPA
2C95 COPTIC SMALL LETTER KAPA
2C96 COPTIC CAPITAL LETTER LAULA
2C97 COPTIC SMALL LETTER LAULA
2C98 COPTIC CAPITAL LETTER MI
2C99 COPTIC SMALL LETTER MI
2C9A COPTIC CAPITAL LETTER NI
2C9B COPTIC SMALL LETTER NI
2C9C COPTIC CAPITAL LETTER KSI
2C9D COPTIC SMALL LETTER KSI
2C9E COPTIC CAPITAL LETTER O
2C9F COPTIC SMALL LETTER O
2CA0 COPTIC CAPITAL LETTER PI
2CA1 COPTIC SMALL LETTER PI
2CA2 COPTIC CAPITAL LETTER RO
2CA3 COPTIC SMALL LETTER RO
2CA4 COPTIC CAPITAL LETTER SIMA
2CA5 COPTIC SMALL LETTER SIMA
2CA6 COPTIC CAPITAL LETTER TAU
2CA7 COPTIC SMALL LETTER TAU
2CA8 COPTIC CAPITAL LETTER UA
2CA9 COPTIC SMALL LETTER UA
2CAA COPTIC CAPITAL LETTER FI
2CAB COPTIC SMALL LETTER FI
2CAC COPTIC CAPITAL LETTER KHI
2CAD COPTIC SMALL LETTER KHI
2CAE COPTIC CAPITAL LETTER PSI
2CAF COPTIC SMALL LETTER PSI
2CB0 COPTIC CAPITAL LETTER OOU
2CB1 COPTIC SMALL LETTER OOU
2CB2 COPTIC CAPITAL LETTER DIALECT-P ALEF
2CB3 COPTIC SMALL LETTER DIALECT-P ALEF
2CB4 COPTIC CAPITAL LETTER OLD COPTIC AIN
2CB5 COPTIC SMALL LETTER OLD COPTIC AIN
2CB6 COPTIC CAPITAL LETTER CRYPTOGRAMMIC EIE
2CB7 COPTIC SMALL LETTER CRYPTOGRAMMIC EIE
2CB8 COPTIC CAPITAL LETTER DIALECT-P KAPA
2CB9 COPTIC SMALL LETTER DIALECT-P KAPA
2CBA COPTIC CAPITAL LETTER DIALECT-P NI
2CBB COPTIC SMALL LETTER DIALECT-P NI
2CBC COPTIC CAPITAL LETTER CRYPTOGRAMMIC NI
2CBD COPTIC SMALL LETTER CRYPTOGRAMMIC NI
2CBE COPTIC CAPITAL LETTER OLD COPTIC OOU
2CBF COPTIC SMALL LETTER OLD COPTIC OOU
2CC0 COPTIC CAPITAL LETTER SAMPI
2CC1 COPTIC SMALL LETTER SAMPI
2CC2 COPTIC CAPITAL LETTER CROSSED SHEI
2CC3 COPTIC SMALL LETTER CROSSED SHEI
2CC4 COPTIC CAPITAL LETTER OLD COPTIC SHEI
2CC5 COPTIC SMALL LETTER OLD COPTIC SHEI
2CC6 COPTIC CAPITAL LETTER OLD COPTIC ESH
2CC7 COPTIC SMALL LETTER OLD COPTIC ESH
2CC8 COPTIC CAPITAL LETTER AKHMIMIC KHEI
2CC9 COPTIC SMALL LETTER AKHMIMIC KHEI
2CCA COPTIC CAPITAL LETTER DIALECT-P HORI
2CCB COPTIC SMALL LETTER DIALECT-P HORI
2CCC COPTIC CAPITAL LETTER OLD COPTIC HORI
2CCD COPTIC SMALL LETTER OLD COPTIC HORI
2CCE COPTIC CAPITAL LETTER OLD COPTIC HA
2CCF COPTIC SMALL LETTER OLD COPTIC HA
2CD0 COPTIC CAPITAL LETTER L-SHAPED HA
2CD1 COPTIC SMALL LETTER L-SHAPED HA
2CD2 COPTIC CAPITAL LETTER OLD COPTIC HEI
2CD3 COPTIC SMALL LETTER OLD COPTIC HEI
2CD4 COPTIC CAPITAL LETTER OLD COPTIC HAT
2CD5 COPTIC SMALL LETTER OLD COPTIC HAT
2CD6 COPTIC CAPITAL LETTER OLD COPTIC GANGIA
2CD7 COPTIC SMALL LETTER OLD COPTIC GANGIA
2CD8 COPTIC CAPITAL LETTER OLD COPTIC DJA
2CD9 COPTIC SMALL LETTER OLD COPTIC DJA
2CDA COPTIC CAPITAL LETTER OLD COPTIC SHIMA
2CDB COPTIC SMALL LETTER OLD COPTIC SHIMA
2CDC COPTIC CAPITAL LETTER OLD NUBIAN SHIMA
2CDD COPTIC SMALL LETTER OLD NUBIAN SHIMA
2CDE COPTIC CAPITAL LETTER OLD NUBIAN NGI
2CDF COPTIC SMALL LETTER OLD NUBIAN NGI
2CE0 COPTIC CAPITAL LETTER OLD NUBIAN NYI
2CE1 COPTIC SMALL LETTER OLD NUBIAN NYI
2CE2 COPTIC CAPITAL LETTER OLD NUBIAN WAU
2CE3 COPTIC SMALL LETTER OLD NUBIAN WAU
2CE4 COPTIC SYMBOL KAI
2CE5 COPTIC SYMBOL MI RO
2CE6 COPTIC SYMBOL PI RO
2CE7 COPTIC SYMBOL STAUROS
2CE8 COPTIC SYMBOL TAU RO
2CE9 COPTIC SYMBOL KHI RO
2CEA COPTIC SYMBOL SHIMA SIMA
2CF9 COPTIC OLD NUBIAN FULL STOP
2CFA COPTIC OLD NUBIAN DIRECT QUESTION MARK
2CFB COPTIC OLD NUBIAN INDIRECT QUESTION MARK
2CFC COPTIC OLD NUBIAN VERSE DIVIDER
2CFD COPTIC FRACTION ONE HALF
2CFE COPTIC FULL STOP
2CFF COPTIC MORPHOLOGICAL DIVIDER
2D00 GEORGIAN SMALL LETTER AN
2D01 GEORGIAN SMALL LETTER BAN
2D02 GEORGIAN SMALL LETTER GAN
2D03 GEORGIAN SMALL LETTER DON
2D04 GEORGIAN SMALL LETTER EN
2D05 GEORGIAN SMALL LETTER VIN
2D06 GEORGIAN SMALL LETTER ZEN
2D07 GEORGIAN SMALL LETTER TAN
2D08 GEORGIAN SMALL LETTER IN
2D09 GEORGIAN SMALL LETTER KAN
2D0A GEORGIAN SMALL LETTER LAS
2D0B GEORGIAN SMALL LETTER MAN
2D0C GEORGIAN SMALL LETTER NAR
2D0D GEORGIAN SMALL LETTER ON
2D0E GEORGIAN SMALL LETTER PAR
2D0F GEORGIAN SMALL LETTER ZHAR
2D10 GEORGIAN SMALL LETTER RAE
2D11 GEORGIAN SMALL LETTER SAN
2D12 GEORGIAN SMALL LETTER TAR
2D13 GEORGIAN SMALL LETTER UN
2D14 GEORGIAN SMALL LETTER PHAR
2D15 GEORGIAN SMALL LETTER KHAR
2D16 GEORGIAN SMALL LETTER GHAN
2D17 GEORGIAN SMALL LETTER QAR
2D18 GEORGIAN SMALL LETTER SHIN
2D19 GEORGIAN SMALL LETTER CHIN
2D1A GEORGIAN SMALL LETTER CAN
2D1B GEORGIAN SMALL LETTER JIL
2D1C GEORGIAN SMALL LETTER CIL
2D1D GEORGIAN SMALL LETTER CHAR
2D1E GEORGIAN SMALL LETTER XAN
2D1F GEORGIAN SMALL LETTER JHAN
2D20 GEORGIAN SMALL LETTER HAE
2D21 GEORGIAN SMALL LETTER HE
2D22 GEORGIAN SMALL LETTER HIE
2D23 GEORGIAN SMALL LETTER WE
2D24 GEORGIAN SMALL LETTER HAR
2D25 GEORGIAN SMALL LETTER HOE
2D30 TIFINAGH LETTER YA
2D31 TIFINAGH LETTER YAB
2D32 TIFINAGH LETTER YABH
2D33 TIFINAGH LETTER YAG
2D34 TIFINAGH LETTER YAGHH
2D35 TIFINAGH LETTER BERBER ACADEMY YAJ
2D36 TIFINAGH LETTER YAJ
2D37 TIFINAGH LETTER YAD
2D38 TIFINAGH LETTER YADH
2D39 TIFINAGH LETTER YADD
2D3A TIFINAGH LETTER YADDH
2D3B TIFINAGH LETTER YEY
2D3C TIFINAGH LETTER YAF
2D3D TIFINAGH LETTER YAK
2D3E TIFINAGH LETTER TUAREG YAK
2D3F TIFINAGH LETTER YAKHH
2D40 TIFINAGH LETTER YAH
2D41 TIFINAGH LETTER BERBER ACADEMY YAH
2D42 TIFINAGH LETTER TUAREG YAH
2D43 TIFINAGH LETTER YAHH
2D44 TIFINAGH LETTER YAA
2D45 TIFINAGH LETTER YAKH
2D46 TIFINAGH LETTER TUAREG YAKH
2D47 TIFINAGH LETTER YAQ
2D48 TIFINAGH LETTER TUAREG YAQ
2D49 TIFINAGH LETTER YI
2D4A TIFINAGH LETTER YAZH
2D4B TIFINAGH LETTER AHAGGAR YAZH
2D4C TIFINAGH LETTER TUAREG YAZH
2D4D TIFINAGH LETTER YAL
2D4E TIFINAGH LETTER YAM
2D4F TIFINAGH LETTER YAN
2D50 TIFINAGH LETTER TUAREG YAGN
2D51 TIFINAGH LETTER TUAREG YANG
2D52 TIFINAGH LETTER YAP
2D53 TIFINAGH LETTER YU
2D54 TIFINAGH LETTER YAR
2D55 TIFINAGH LETTER YARR
2D56 TIFINAGH LETTER YAGH
2D57 TIFINAGH LETTER TUAREG YAGH
2D58 TIFINAGH LETTER AYER YAGH
2D59 TIFINAGH LETTER YAS
2D5A TIFINAGH LETTER YASS
2D5B TIFINAGH LETTER YASH
2D5C TIFINAGH LETTER YAT
2D5D TIFINAGH LETTER YATH
2D5E TIFINAGH LETTER YACH
2D5F TIFINAGH LETTER YATT
2D60 TIFINAGH LETTER YAV
2D61 TIFINAGH LETTER YAW
2D62 TIFINAGH LETTER YAY
2D63 TIFINAGH LETTER YAZ
2D64 TIFINAGH LETTER TAWELLEMET YAZ
2D65 TIFINAGH LETTER YAZZ
2D6F TIFINAGH MODIFIER LETTER LABIALIZATION MARK
2D80 ETHIOPIC SYLLABLE LOA
2D81 ETHIOPIC SYLLABLE MOA
2D82 ETHIOPIC SYLLABLE ROA
2D83 ETHIOPIC SYLLABLE SOA
2D84 ETHIOPIC SYLLABLE SHOA
2D85 ETHIOPIC SYLLABLE BOA
2D86 ETHIOPIC SYLLABLE TOA
2D87 ETHIOPIC SYLLABLE COA
2D88 ETHIOPIC SYLLABLE NOA
2D89 ETHIOPIC SYLLABLE NYOA
2D8A ETHIOPIC SYLLABLE GLOTTAL OA
2D8B ETHIOPIC SYLLABLE ZOA
2D8C ETHIOPIC SYLLABLE DOA
2D8D ETHIOPIC SYLLABLE DDOA
2D8E ETHIOPIC SYLLABLE JOA
2D8F ETHIOPIC SYLLABLE THOA
2D90 ETHIOPIC SYLLABLE CHOA
2D91 ETHIOPIC SYLLABLE PHOA
2D92 ETHIOPIC SYLLABLE POA
2D93 ETHIOPIC SYLLABLE GGWA
2D94 ETHIOPIC SYLLABLE GGWI
2D95 ETHIOPIC SYLLABLE GGWEE
2D96 ETHIOPIC SYLLABLE GGWE
2DA0 ETHIOPIC SYLLABLE SSA
2DA1 ETHIOPIC SYLLABLE SSU
2DA2 ETHIOPIC SYLLABLE SSI
2DA3 ETHIOPIC SYLLABLE SSAA
2DA4 ETHIOPIC SYLLABLE SSEE
2DA5 ETHIOPIC SYLLABLE SSE
2DA6 ETHIOPIC SYLLABLE SSO
2DA8 ETHIOPIC SYLLABLE CCA
2DA9 ETHIOPIC SYLLABLE CCU
2DAA ETHIOPIC SYLLABLE CCI
2DAB ETHIOPIC SYLLABLE CCAA
2DAC ETHIOPIC SYLLABLE CCEE
2DAD ETHIOPIC SYLLABLE CCE
2DAE ETHIOPIC SYLLABLE CCO
2DB0 ETHIOPIC SYLLABLE ZZA
2DB1 ETHIOPIC SYLLABLE ZZU
2DB2 ETHIOPIC SYLLABLE ZZI
2DB3 ETHIOPIC SYLLABLE ZZAA
2DB4 ETHIOPIC SYLLABLE ZZEE
2DB5 ETHIOPIC SYLLABLE ZZE
2DB6 ETHIOPIC SYLLABLE ZZO
2DB8 ETHIOPIC SYLLABLE CCHA
2DB9 ETHIOPIC SYLLABLE CCHU
2DBA ETHIOPIC SYLLABLE CCHI
2DBB ETHIOPIC SYLLABLE CCHAA
2DBC ETHIOPIC SYLLABLE CCHEE
2DBD ETHIOPIC SYLLABLE CCHE
2DBE ETHIOPIC SYLLABLE CCHO
2DC0 ETHIOPIC SYLLABLE QYA
2DC1 ETHIOPIC SYLLABLE QYU
2DC2 ETHIOPIC SYLLABLE QYI
2DC3 ETHIOPIC SYLLABLE QYAA
2DC4 ETHIOPIC SYLLABLE QYEE
2DC5 ETHIOPIC SYLLABLE QYE
2DC6 ETHIOPIC SYLLABLE QYO
2DC8 ETHIOPIC SYLLABLE KYA
2DC9 ETHIOPIC SYLLABLE KYU
2DCA ETHIOPIC SYLLABLE KYI
2DCB ETHIOPIC SYLLABLE KYAA
2DCC ETHIOPIC SYLLABLE KYEE
2DCD ETHIOPIC SYLLABLE KYE
2DCE ETHIOPIC SYLLABLE KYO
2DD0 ETHIOPIC SYLLABLE XYA
2DD1 ETHIOPIC SYLLABLE XYU
2DD2 ETHIOPIC SYLLABLE XYI
2DD3 ETHIOPIC SYLLABLE XYAA
2DD4 ETHIOPIC SYLLABLE XYEE
2DD5 ETHIOPIC SYLLABLE XYE
2DD6 ETHIOPIC SYLLABLE XYO
2DD8 ETHIOPIC SYLLABLE GYA
2DD9 ETHIOPIC SYLLABLE GYU
2DDA ETHIOPIC SYLLABLE GYI
2DDB ETHIOPIC SYLLABLE GYAA
2DDC ETHIOPIC SYLLABLE GYEE
2DDD ETHIOPIC SYLLABLE GYE
2DDE ETHIOPIC SYLLABLE GYO
2E00 RIGHT ANGLE SUBSTITUTION MARKER
2E01 RIGHT ANGLE DOTTED SUBSTITUTION MARKER
2E02 LEFT SUBSTITUTION BRACKET
2E03 RIGHT SUBSTITUTION BRACKET
2E04 LEFT DOTTED SUBSTITUTION BRACKET
2E05 RIGHT DOTTED SUBSTITUTION BRACKET
2E06 RAISED INTERPOLATION MARKER
2E07 RAISED DOTTED INTERPOLATION MARKER
2E08 DOTTED TRANSPOSITION MARKER
2E09 LEFT TRANSPOSITION BRACKET
2E0A RIGHT TRANSPOSITION BRACKET
2E0B RAISED SQUARE
2E0C LEFT RAISED OMISSION BRACKET
2E0D RIGHT RAISED OMISSION BRACKET
2E0E EDITORIAL CORONIS
2E0F PARAGRAPHOS
2E10 FORKED PARAGRAPHOS
2E11 REVERSED FORKED PARAGRAPHOS
2E12 HYPODIASTOLE
2E13 DOTTED OBELOS
2E14 DOWNWARDS ANCORA
2E15 UPWARDS ANCORA
2E16 DOTTED RIGHT-POINTING ANGLE
2E17 DOUBLE OBLIQUE HYPHEN
2E1C LEFT LOW PARAPHRASE BRACKET
2E1D RIGHT LOW PARAPHRASE BRACKET
2E80 CJK RADICAL REPEAT
2E81 CJK RADICAL CLIFF
2E82 CJK RADICAL SECOND ONE
2E83 CJK RADICAL SECOND TWO
2E84 CJK RADICAL SECOND THREE
2E85 CJK RADICAL PERSON
2E86 CJK RADICAL BOX
2E87 CJK RADICAL TABLE
2E88 CJK RADICAL KNIFE ONE
2E89 CJK RADICAL KNIFE TWO
2E8A CJK RADICAL DIVINATION
2E8B CJK RADICAL SEAL
2E8C CJK RADICAL SMALL ONE
2E8D CJK RADICAL SMALL TWO
2E8E CJK RADICAL LAME ONE
2E8F CJK RADICAL LAME TWO
2E90 CJK RADICAL LAME THREE
2E91 CJK RADICAL LAME FOUR
2E92 CJK RADICAL SNAKE
2E93 CJK RADICAL THREAD
2E94 CJK RADICAL SNOUT ONE
2E95 CJK RADICAL SNOUT TWO
2E96 CJK RADICAL HEART ONE
2E97 CJK RADICAL HEART TWO
2E98 CJK RADICAL HAND
2E99 CJK RADICAL RAP
2E9B CJK RADICAL CHOKE
2E9C CJK RADICAL SUN
2E9D CJK RADICAL MOON
2E9E CJK RADICAL DEATH
2E9F CJK RADICAL MOTHER
2EA0 CJK RADICAL CIVILIAN
2EA1 CJK RADICAL WATER ONE
2EA2 CJK RADICAL WATER TWO
2EA3 CJK RADICAL FIRE
2EA4 CJK RADICAL PAW ONE
2EA5 CJK RADICAL PAW TWO
2EA6 CJK RADICAL SIMPLIFIED HALF TREE TRUNK
2EA7 CJK RADICAL COW
2EA8 CJK RADICAL DOG
2EA9 CJK RADICAL JADE
2EAA CJK RADICAL BOLT OF CLOTH
2EAB CJK RADICAL EYE
2EAC CJK RADICAL SPIRIT ONE
2EAD CJK RADICAL SPIRIT TWO
2EAE CJK RADICAL BAMBOO
2EAF CJK RADICAL SILK
2EB0 CJK RADICAL C-SIMPLIFIED SILK
2EB1 CJK RADICAL NET ONE
2EB2 CJK RADICAL NET TWO
2EB3 CJK RADICAL NET THREE
2EB4 CJK RADICAL NET FOUR
2EB5 CJK RADICAL MESH
2EB6 CJK RADICAL SHEEP
2EB7 CJK RADICAL RAM
2EB8 CJK RADICAL EWE
2EB9 CJK RADICAL OLD
2EBA CJK RADICAL BRUSH ONE
2EBB CJK RADICAL BRUSH TWO
2EBC CJK RADICAL MEAT
2EBD CJK RADICAL MORTAR
2EBE CJK RADICAL GRASS ONE
2EBF CJK RADICAL GRASS TWO
2EC0 CJK RADICAL GRASS THREE
2EC1 CJK RADICAL TIGER
2EC2 CJK RADICAL CLOTHES
2EC3 CJK RADICAL WEST ONE
2EC4 CJK RADICAL WEST TWO
2EC5 CJK RADICAL C-SIMPLIFIED SEE
2EC6 CJK RADICAL SIMPLIFIED HORN
2EC7 CJK RADICAL HORN
2EC8 CJK RADICAL C-SIMPLIFIED SPEECH
2EC9 CJK RADICAL C-SIMPLIFIED SHELL
2ECA CJK RADICAL FOOT
2ECB CJK RADICAL C-SIMPLIFIED CART
2ECC CJK RADICAL SIMPLIFIED WALK
2ECD CJK RADICAL WALK ONE
2ECE CJK RADICAL WALK TWO
2ECF CJK RADICAL CITY
2ED0 CJK RADICAL C-SIMPLIFIED GOLD
2ED1 CJK RADICAL LONG ONE
2ED2 CJK RADICAL LONG TWO
2ED3 CJK RADICAL C-SIMPLIFIED LONG
2ED4 CJK RADICAL C-SIMPLIFIED GATE
2ED5 CJK RADICAL MOUND ONE
2ED6 CJK RADICAL MOUND TWO
2ED7 CJK RADICAL RAIN
2ED8 CJK RADICAL BLUE
2ED9 CJK RADICAL C-SIMPLIFIED TANNED LEATHER
2EDA CJK RADICAL C-SIMPLIFIED LEAF
2EDB CJK RADICAL C-SIMPLIFIED WIND
2EDC CJK RADICAL C-SIMPLIFIED FLY
2EDD CJK RADICAL EAT ONE
2EDE CJK RADICAL EAT TWO
2EDF CJK RADICAL EAT THREE
2EE0 CJK RADICAL C-SIMPLIFIED EAT
2EE1 CJK RADICAL HEAD
2EE2 CJK RADICAL C-SIMPLIFIED HORSE
2EE3 CJK RADICAL BONE
2EE4 CJK RADICAL GHOST
2EE5 CJK RADICAL C-SIMPLIFIED FISH
2EE6 CJK RADICAL C-SIMPLIFIED BIRD
2EE7 CJK RADICAL C-SIMPLIFIED SALT
2EE8 CJK RADICAL SIMPLIFIED WHEAT
2EE9 CJK RADICAL SIMPLIFIED YELLOW
2EEA CJK RADICAL C-SIMPLIFIED FROG
2EEB CJK RADICAL J-SIMPLIFIED EVEN
2EEC CJK RADICAL C-SIMPLIFIED EVEN
2EED CJK RADICAL J-SIMPLIFIED TOOTH
2EEE CJK RADICAL C-SIMPLIFIED TOOTH
2EEF CJK RADICAL J-SIMPLIFIED DRAGON
2EF0 CJK RADICAL C-SIMPLIFIED DRAGON
2EF1 CJK RADICAL TURTLE
2EF2 CJK RADICAL J-SIMPLIFIED TURTLE
2EF3 CJK RADICAL C-SIMPLIFIED TURTLE
2F00 KANGXI RADICAL ONE
2F01 KANGXI RADICAL LINE
2F02 KANGXI RADICAL DOT
2F03 KANGXI RADICAL SLASH
2F04 KANGXI RADICAL SECOND
2F05 KANGXI RADICAL HOOK
2F06 KANGXI RADICAL TWO
2F07 KANGXI RADICAL LID
2F08 KANGXI RADICAL MAN
2F09 KANGXI RADICAL LEGS
2F0A KANGXI RADICAL ENTER
2F0B KANGXI RADICAL EIGHT
2F0C KANGXI RADICAL DOWN BOX
2F0D KANGXI RADICAL COVER
2F0E KANGXI RADICAL ICE
2F0F KANGXI RADICAL TABLE
2F10 KANGXI RADICAL OPEN BOX
2F11 KANGXI RADICAL KNIFE
2F12 KANGXI RADICAL POWER
2F13 KANGXI RADICAL WRAP
2F14 KANGXI RADICAL SPOON
2F15 KANGXI RADICAL RIGHT OPEN BOX
2F16 KANGXI RADICAL HIDING ENCLOSURE
2F17 KANGXI RADICAL TEN
2F18 KANGXI RADICAL DIVINATION
2F19 KANGXI RADICAL SEAL
2F1A KANGXI RADICAL CLIFF
2F1B KANGXI RADICAL PRIVATE
2F1C KANGXI RADICAL AGAIN
2F1D KANGXI RADICAL MOUTH
2F1E KANGXI RADICAL ENCLOSURE
2F1F KANGXI RADICAL EARTH
2F20 KANGXI RADICAL SCHOLAR
2F21 KANGXI RADICAL GO
2F22 KANGXI RADICAL GO SLOWLY
2F23 KANGXI RADICAL EVENING
2F24 KANGXI RADICAL BIG
2F25 KANGXI RADICAL WOMAN
2F26 KANGXI RADICAL CHILD
2F27 KANGXI RADICAL ROOF
2F28 KANGXI RADICAL INCH
2F29 KANGXI RADICAL SMALL
2F2A KANGXI RADICAL LAME
2F2B KANGXI RADICAL CORPSE
2F2C KANGXI RADICAL SPROUT
2F2D KANGXI RADICAL MOUNTAIN
2F2E KANGXI RADICAL RIVER
2F2F KANGXI RADICAL WORK
2F30 KANGXI RADICAL ONESELF
2F31 KANGXI RADICAL TURBAN
2F32 KANGXI RADICAL DRY
2F33 KANGXI RADICAL SHORT THREAD
2F34 KANGXI RADICAL DOTTED CLIFF
2F35 KANGXI RADICAL LONG STRIDE
2F36 KANGXI RADICAL TWO HANDS
2F37 KANGXI RADICAL SHOOT
2F38 KANGXI RADICAL BOW
2F39 KANGXI RADICAL SNOUT
2F3A KANGXI RADICAL BRISTLE
2F3B KANGXI RADICAL STEP
2F3C KANGXI RADICAL HEART
2F3D KANGXI RADICAL HALBERD
2F3E KANGXI RADICAL DOOR
2F3F KANGXI RADICAL HAND
2F40 KANGXI RADICAL BRANCH
2F41 KANGXI RADICAL RAP
2F42 KANGXI RADICAL SCRIPT
2F43 KANGXI RADICAL DIPPER
2F44 KANGXI RADICAL AXE
2F45 KANGXI RADICAL SQUARE
2F46 KANGXI RADICAL NOT
2F47 KANGXI RADICAL SUN
2F48 KANGXI RADICAL SAY
2F49 KANGXI RADICAL MOON
2F4A KANGXI RADICAL TREE
2F4B KANGXI RADICAL LACK
2F4C KANGXI RADICAL STOP
2F4D KANGXI RADICAL DEATH
2F4E KANGXI RADICAL WEAPON
2F4F KANGXI RADICAL DO NOT
2F50 KANGXI RADICAL COMPARE
2F51 KANGXI RADICAL FUR
2F52 KANGXI RADICAL CLAN
2F53 KANGXI RADICAL STEAM
2F54 KANGXI RADICAL WATER
2F55 KANGXI RADICAL FIRE
2F56 KANGXI RADICAL CLAW
2F57 KANGXI RADICAL FATHER
2F58 KANGXI RADICAL DOUBLE X
2F59 KANGXI RADICAL HALF TREE TRUNK
2F5A KANGXI RADICAL SLICE
2F5B KANGXI RADICAL FANG
2F5C KANGXI RADICAL COW
2F5D KANGXI RADICAL DOG
2F5E KANGXI RADICAL PROFOUND
2F5F KANGXI RADICAL JADE
2F60 KANGXI RADICAL MELON
2F61 KANGXI RADICAL TILE
2F62 KANGXI RADICAL SWEET
2F63 KANGXI RADICAL LIFE
2F64 KANGXI RADICAL USE
2F65 KANGXI RADICAL FIELD
2F66 KANGXI RADICAL BOLT OF CLOTH
2F67 KANGXI RADICAL SICKNESS
2F68 KANGXI RADICAL DOTTED TENT
2F69 KANGXI RADICAL WHITE
2F6A KANGXI RADICAL SKIN
2F6B KANGXI RADICAL DISH
2F6C KANGXI RADICAL EYE
2F6D KANGXI RADICAL SPEAR
2F6E KANGXI RADICAL ARROW
2F6F KANGXI RADICAL STONE
2F70 KANGXI RADICAL SPIRIT
2F71 KANGXI RADICAL TRACK
2F72 KANGXI RADICAL GRAIN
2F73 KANGXI RADICAL CAVE
2F74 KANGXI RADICAL STAND
2F75 KANGXI RADICAL BAMBOO
2F76 KANGXI RADICAL RICE
2F77 KANGXI RADICAL SILK
2F78 KANGXI RADICAL JAR
2F79 KANGXI RADICAL NET
2F7A KANGXI RADICAL SHEEP
2F7B KANGXI RADICAL FEATHER
2F7C KANGXI RADICAL OLD
2F7D KANGXI RADICAL AND
2F7E KANGXI RADICAL PLOW
2F7F KANGXI RADICAL EAR
2F80 KANGXI RADICAL BRUSH
2F81 KANGXI RADICAL MEAT
2F82 KANGXI RADICAL MINISTER
2F83 KANGXI RADICAL SELF
2F84 KANGXI RADICAL ARRIVE
2F85 KANGXI RADICAL MORTAR
2F86 KANGXI RADICAL TONGUE
2F87 KANGXI RADICAL OPPOSE
2F88 KANGXI RADICAL BOAT
2F89 KANGXI RADICAL STOPPING
2F8A KANGXI RADICAL COLOR
2F8B KANGXI RADICAL GRASS
2F8C KANGXI RADICAL TIGER
2F8D KANGXI RADICAL INSECT
2F8E KANGXI RADICAL BLOOD
2F8F KANGXI RADICAL WALK ENCLOSURE
2F90 KANGXI RADICAL CLOTHES
2F91 KANGXI RADICAL WEST
2F92 KANGXI RADICAL SEE
2F93 KANGXI RADICAL HORN
2F94 KANGXI RADICAL SPEECH
2F95 KANGXI RADICAL VALLEY
2F96 KANGXI RADICAL BEAN
2F97 KANGXI RADICAL PIG
2F98 KANGXI RADICAL BADGER
2F99 KANGXI RADICAL SHELL
2F9A KANGXI RADICAL RED
2F9B KANGXI RADICAL RUN
2F9C KANGXI RADICAL FOOT
2F9D KANGXI RADICAL BODY
2F9E KANGXI RADICAL CART
2F9F KANGXI RADICAL BITTER
2FA0 KANGXI RADICAL MORNING
2FA1 KANGXI RADICAL WALK
2FA2 KANGXI RADICAL CITY
2FA3 KANGXI RADICAL WINE
2FA4 KANGXI RADICAL DISTINGUISH
2FA5 KANGXI RADICAL VILLAGE
2FA6 KANGXI RADICAL GOLD
2FA7 KANGXI RADICAL LONG
2FA8 KANGXI RADICAL GATE
2FA9 KANGXI RADICAL MOUND
2FAA KANGXI RADICAL SLAVE
2FAB KANGXI RADICAL SHORT TAILED BIRD
2FAC KANGXI RADICAL RAIN
2FAD KANGXI RADICAL BLUE
2FAE KANGXI RADICAL WRONG
2FAF KANGXI RADICAL FACE
2FB0 KANGXI RADICAL LEATHER
2FB1 KANGXI RADICAL TANNED LEATHER
2FB2 KANGXI RADICAL LEEK
2FB3 KANGXI RADICAL SOUND
2FB4 KANGXI RADICAL LEAF
2FB5 KANGXI RADICAL WIND
2FB6 KANGXI RADICAL FLY
2FB7 KANGXI RADICAL EAT
2FB8 KANGXI RADICAL HEAD
2FB9 KANGXI RADICAL FRAGRANT
2FBA KANGXI RADICAL HORSE
2FBB KANGXI RADICAL BONE
2FBC KANGXI RADICAL TALL
2FBD KANGXI RADICAL HAIR
2FBE KANGXI RADICAL FIGHT
2FBF KANGXI RADICAL SACRIFICIAL WINE
2FC0 KANGXI RADICAL CAULDRON
2FC1 KANGXI RADICAL GHOST
2FC2 KANGXI RADICAL FISH
2FC3 KANGXI RADICAL BIRD
2FC4 KANGXI RADICAL SALT
2FC5 KANGXI RADICAL DEER
2FC6 KANGXI RADICAL WHEAT
2FC7 KANGXI RADICAL HEMP
2FC8 KANGXI RADICAL YELLOW
2FC9 KANGXI RADICAL MILLET
2FCA KANGXI RADICAL BLACK
2FCB KANGXI RADICAL EMBROIDERY
2FCC KANGXI RADICAL FROG
2FCD KANGXI RADICAL TRIPOD
2FCE KANGXI RADICAL DRUM
2FCF KANGXI RADICAL RAT
2FD0 KANGXI RADICAL NOSE
2FD1 KANGXI RADICAL EVEN
2FD2 KANGXI RADICAL TOOTH
2FD3 KANGXI RADICAL DRAGON
2FD4 KANGXI RADICAL TURTLE
2FD5 KANGXI RADICAL FLUTE
2FF0 IDEOGRAPHIC DESCRIPTION CHARACTER LEFT TO RIGHT
2FF1 IDEOGRAPHIC DESCRIPTION CHARACTER ABOVE TO BELOW
2FF2 IDEOGRAPHIC DESCRIPTION CHARACTER LEFT TO MIDDLE AND RIGHT
2FF3 IDEOGRAPHIC DESCRIPTION CHARACTER ABOVE TO MIDDLE AND BELOW
2FF4 IDEOGRAPHIC DESCRIPTION CHARACTER FULL SURROUND
2FF5 IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM ABOVE
2FF6 IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM BELOW
2FF7 IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM LEFT
2FF8 IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM UPPER LEFT
2FF9 IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM UPPER RIGHT
2FFA IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM LOWER LEFT
2FFB IDEOGRAPHIC DESCRIPTION CHARACTER OVERLAID
3000 IDEOGRAPHIC SPACE
3001 IDEOGRAPHIC COMMA
3002 IDEOGRAPHIC FULL STOP
3003 DITTO MARK
3004 JAPANESE INDUSTRIAL STANDARD SYMBOL
3005 IDEOGRAPHIC ITERATION MARK
3006 IDEOGRAPHIC CLOSING MARK
3007 IDEOGRAPHIC NUMBER ZERO
3008 LEFT ANGLE BRACKET
3009 RIGHT ANGLE BRACKET
300A LEFT DOUBLE ANGLE BRACKET
300B RIGHT DOUBLE ANGLE BRACKET
300C LEFT CORNER BRACKET
300D RIGHT CORNER BRACKET
300E LEFT WHITE CORNER BRACKET
300F RIGHT WHITE CORNER BRACKET
3010 LEFT BLACK LENTICULAR BRACKET
3011 RIGHT BLACK LENTICULAR BRACKET
3012 POSTAL MARK
3013 GETA MARK
3014 LEFT TORTOISE SHELL BRACKET
3015 RIGHT TORTOISE SHELL BRACKET
3016 LEFT WHITE LENTICULAR BRACKET
3017 RIGHT WHITE LENTICULAR BRACKET
3018 LEFT WHITE TORTOISE SHELL BRACKET
3019 RIGHT WHITE TORTOISE SHELL BRACKET
301A LEFT WHITE SQUARE BRACKET
301B RIGHT WHITE SQUARE BRACKET
301C WAVE DASH
301D REVERSED DOUBLE PRIME QUOTATION MARK
301E DOUBLE PRIME QUOTATION MARK
301F LOW DOUBLE PRIME QUOTATION MARK
3020 POSTAL MARK FACE
3021 HANGZHOU NUMERAL ONE
3022 HANGZHOU NUMERAL TWO
3023 HANGZHOU NUMERAL THREE
3024 HANGZHOU NUMERAL FOUR
3025 HANGZHOU NUMERAL FIVE
3026 HANGZHOU NUMERAL SIX
3027 HANGZHOU NUMERAL SEVEN
3028 HANGZHOU NUMERAL EIGHT
3029 HANGZHOU NUMERAL NINE
302A IDEOGRAPHIC LEVEL TONE MARK
302B IDEOGRAPHIC RISING TONE MARK
302C IDEOGRAPHIC DEPARTING TONE MARK
302D IDEOGRAPHIC ENTERING TONE MARK
302E HANGUL SINGLE DOT TONE MARK
302F HANGUL DOUBLE DOT TONE MARK
3030 WAVY DASH
3031 VERTICAL KANA REPEAT MARK
3032 VERTICAL KANA REPEAT WITH VOICED SOUND MARK
3033 VERTICAL KANA REPEAT MARK UPPER HALF
3034 VERTICAL KANA REPEAT WITH VOICED SOUND MARK UPPER HALF
3035 VERTICAL KANA REPEAT MARK LOWER HALF
3036 CIRCLED POSTAL MARK
3037 IDEOGRAPHIC TELEGRAPH LINE FEED SEPARATOR SYMBOL
3038 HANGZHOU NUMERAL TEN
3039 HANGZHOU NUMERAL TWENTY
303A HANGZHOU NUMERAL THIRTY
303B VERTICAL IDEOGRAPHIC ITERATION MARK
303C MASU MARK
303D PART ALTERNATION MARK
303E IDEOGRAPHIC VARIATION INDICATOR
303F IDEOGRAPHIC HALF FILL SPACE
3041 HIRAGANA LETTER SMALL A
3042 HIRAGANA LETTER A
3043 HIRAGANA LETTER SMALL I
3044 HIRAGANA LETTER I
3045 HIRAGANA LETTER SMALL U
3046 HIRAGANA LETTER U
3047 HIRAGANA LETTER SMALL E
3048 HIRAGANA LETTER E
3049 HIRAGANA LETTER SMALL O
304A HIRAGANA LETTER O
304B HIRAGANA LETTER KA
304C HIRAGANA LETTER GA
304D HIRAGANA LETTER KI
304E HIRAGANA LETTER GI
304F HIRAGANA LETTER KU
3050 HIRAGANA LETTER GU
3051 HIRAGANA LETTER KE
3052 HIRAGANA LETTER GE
3053 HIRAGANA LETTER KO
3054 HIRAGANA LETTER GO
3055 HIRAGANA LETTER SA
3056 HIRAGANA LETTER ZA
3057 HIRAGANA LETTER SI
3058 HIRAGANA LETTER ZI
3059 HIRAGANA LETTER SU
305A HIRAGANA LETTER ZU
305B HIRAGANA LETTER SE
305C HIRAGANA LETTER ZE
305D HIRAGANA LETTER SO
305E HIRAGANA LETTER ZO
305F HIRAGANA LETTER TA
3060 HIRAGANA LETTER DA
3061 HIRAGANA LETTER TI
3062 HIRAGANA LETTER DI
3063 HIRAGANA LETTER SMALL TU
3064 HIRAGANA LETTER TU
3065 HIRAGANA LETTER DU
3066 HIRAGANA LETTER TE
3067 HIRAGANA LETTER DE
3068 HIRAGANA LETTER TO
3069 HIRAGANA LETTER DO
306A HIRAGANA LETTER NA
306B HIRAGANA LETTER NI
306C HIRAGANA LETTER NU
306D HIRAGANA LETTER NE
306E HIRAGANA LETTER NO
306F HIRAGANA LETTER HA
3070 HIRAGANA LETTER BA
3071 HIRAGANA LETTER PA
3072 HIRAGANA LETTER HI
3073 HIRAGANA LETTER BI
3074 HIRAGANA LETTER PI
3075 HIRAGANA LETTER HU
3076 HIRAGANA LETTER BU
3077 HIRAGANA LETTER PU
3078 HIRAGANA LETTER HE
3079 HIRAGANA LETTER BE
307A HIRAGANA LETTER PE
307B HIRAGANA LETTER HO
307C HIRAGANA LETTER BO
307D HIRAGANA LETTER PO
307E HIRAGANA LETTER MA
307F HIRAGANA LETTER MI
3080 HIRAGANA LETTER MU
3081 HIRAGANA LETTER ME
3082 HIRAGANA LETTER MO
3083 HIRAGANA LETTER SMALL YA
3084 HIRAGANA LETTER YA
3085 HIRAGANA LETTER SMALL YU
3086 HIRAGANA LETTER YU
3087 HIRAGANA LETTER SMALL YO
3088 HIRAGANA LETTER YO
3089 HIRAGANA LETTER RA
308A HIRAGANA LETTER RI
308B HIRAGANA LETTER RU
308C HIRAGANA LETTER RE
308D HIRAGANA LETTER RO
308E HIRAGANA LETTER SMALL WA
308F HIRAGANA LETTER WA
3090 HIRAGANA LETTER WI
3091 HIRAGANA LETTER WE
3092 HIRAGANA LETTER WO
3093 HIRAGANA LETTER N
3094 HIRAGANA LETTER VU
3095 HIRAGANA LETTER SMALL KA
3096 HIRAGANA LETTER SMALL KE
3099 COMBINING KATAKANA-HIRAGANA VOICED SOUND MARK
309A COMBINING KATAKANA-HIRAGANA SEMI-VOICED SOUND MARK
309B KATAKANA-HIRAGANA VOICED SOUND MARK
309C KATAKANA-HIRAGANA SEMI-VOICED SOUND MARK
309D HIRAGANA ITERATION MARK
309E HIRAGANA VOICED ITERATION MARK
309F HIRAGANA DIGRAPH YORI
30A0 KATAKANA-HIRAGANA DOUBLE HYPHEN
30A1 KATAKANA LETTER SMALL A
30A2 KATAKANA LETTER A
30A3 KATAKANA LETTER SMALL I
30A4 KATAKANA LETTER I
30A5 KATAKANA LETTER SMALL U
30A6 KATAKANA LETTER U
30A7 KATAKANA LETTER SMALL E
30A8 KATAKANA LETTER E
30A9 KATAKANA LETTER SMALL O
30AA KATAKANA LETTER O
30AB KATAKANA LETTER KA
30AC KATAKANA LETTER GA
30AD KATAKANA LETTER KI
30AE KATAKANA LETTER GI
30AF KATAKANA LETTER KU
30B0 KATAKANA LETTER GU
30B1 KATAKANA LETTER KE
30B2 KATAKANA LETTER GE
30B3 KATAKANA LETTER KO
30B4 KATAKANA LETTER GO
30B5 KATAKANA LETTER SA
30B6 KATAKANA LETTER ZA
30B7 KATAKANA LETTER SI
30B8 KATAKANA LETTER ZI
30B9 KATAKANA LETTER SU
30BA KATAKANA LETTER ZU
30BB KATAKANA LETTER SE
30BC KATAKANA LETTER ZE
30BD KATAKANA LETTER SO
30BE KATAKANA LETTER ZO
30BF KATAKANA LETTER TA
30C0 KATAKANA LETTER DA
30C1 KATAKANA LETTER TI
30C2 KATAKANA LETTER DI
30C3 KATAKANA LETTER SMALL TU
30C4 KATAKANA LETTER TU
30C5 KATAKANA LETTER DU
30C6 KATAKANA LETTER TE
30C7 KATAKANA LETTER DE
30C8 KATAKANA LETTER TO
30C9 KATAKANA LETTER DO
30CA KATAKANA LETTER NA
30CB KATAKANA LETTER NI
30CC KATAKANA LETTER NU
30CD KATAKANA LETTER NE
30CE KATAKANA LETTER NO
30CF KATAKANA LETTER HA
30D0 KATAKANA LETTER BA
30D1 KATAKANA LETTER PA
30D2 KATAKANA LETTER HI
30D3 KATAKANA LETTER BI
30D4 KATAKANA LETTER PI
30D5 KATAKANA LETTER HU
30D6 KATAKANA LETTER BU
30D7 KATAKANA LETTER PU
30D8 KATAKANA LETTER HE
30D9 KATAKANA LETTER BE
30DA KATAKANA LETTER PE
30DB KATAKANA LETTER HO
30DC KATAKANA LETTER BO
30DD KATAKANA LETTER PO
30DE KATAKANA LETTER MA
30DF KATAKANA LETTER MI
30E0 KATAKANA LETTER MU
30E1 KATAKANA LETTER ME
30E2 KATAKANA LETTER MO
30E3 KATAKANA LETTER SMALL YA
30E4 KATAKANA LETTER YA
30E5 KATAKANA LETTER SMALL YU
30E6 KATAKANA LETTER YU
30E7 KATAKANA LETTER SMALL YO
30E8 KATAKANA LETTER YO
30E9 KATAKANA LETTER RA
30EA KATAKANA LETTER RI
30EB KATAKANA LETTER RU
30EC KATAKANA LETTER RE
30ED KATAKANA LETTER RO
30EE KATAKANA LETTER SMALL WA
30EF KATAKANA LETTER WA
30F0 KATAKANA LETTER WI
30F1 KATAKANA LETTER WE
30F2 KATAKANA LETTER WO
30F3 KATAKANA LETTER N
30F4 KATAKANA LETTER VU
30F5 KATAKANA LETTER SMALL KA
30F6 KATAKANA LETTER SMALL KE
30F7 KATAKANA LETTER VA
30F8 KATAKANA LETTER VI
30F9 KATAKANA LETTER VE
30FA KATAKANA LETTER VO
30FB KATAKANA MIDDLE DOT
30FC KATAKANA-HIRAGANA PROLONGED SOUND MARK
30FD KATAKANA ITERATION MARK
30FE KATAKANA VOICED ITERATION MARK
30FF KATAKANA DIGRAPH KOTO
3105 BOPOMOFO LETTER B
3106 BOPOMOFO LETTER P
3107 BOPOMOFO LETTER M
3108 BOPOMOFO LETTER F
3109 BOPOMOFO LETTER D
310A BOPOMOFO LETTER T
310B BOPOMOFO LETTER N
310C BOPOMOFO LETTER L
310D BOPOMOFO LETTER G
310E BOPOMOFO LETTER K
310F BOPOMOFO LETTER H
3110 BOPOMOFO LETTER J
3111 BOPOMOFO LETTER Q
3112 BOPOMOFO LETTER X
3113 BOPOMOFO LETTER ZH
3114 BOPOMOFO LETTER CH
3115 BOPOMOFO LETTER SH
3116 BOPOMOFO LETTER R
3117 BOPOMOFO LETTER Z
3118 BOPOMOFO LETTER C
3119 BOPOMOFO LETTER S
311A BOPOMOFO LETTER A
311B BOPOMOFO LETTER O
311C BOPOMOFO LETTER E
311D BOPOMOFO LETTER EH
311E BOPOMOFO LETTER AI
311F BOPOMOFO LETTER EI
3120 BOPOMOFO LETTER AU
3121 BOPOMOFO LETTER OU
3122 BOPOMOFO LETTER AN
3123 BOPOMOFO LETTER EN
3124 BOPOMOFO LETTER ANG
3125 BOPOMOFO LETTER ENG
3126 BOPOMOFO LETTER ER
3127 BOPOMOFO LETTER I
3128 BOPOMOFO LETTER U
3129 BOPOMOFO LETTER IU
312A BOPOMOFO LETTER V
312B BOPOMOFO LETTER NG
312C BOPOMOFO LETTER GN
3131 HANGUL LETTER KIYEOK
3132 HANGUL LETTER SSANGKIYEOK
3133 HANGUL LETTER KIYEOK-SIOS
3134 HANGUL LETTER NIEUN
3135 HANGUL LETTER NIEUN-CIEUC
3136 HANGUL LETTER NIEUN-HIEUH
3137 HANGUL LETTER TIKEUT
3138 HANGUL LETTER SSANGTIKEUT
3139 HANGUL LETTER RIEUL
313A HANGUL LETTER RIEUL-KIYEOK
313B HANGUL LETTER RIEUL-MIEUM
313C HANGUL LETTER RIEUL-PIEUP
313D HANGUL LETTER RIEUL-SIOS
313E HANGUL LETTER RIEUL-THIEUTH
313F HANGUL LETTER RIEUL-PHIEUPH
3140 HANGUL LETTER RIEUL-HIEUH
3141 HANGUL LETTER MIEUM
3142 HANGUL LETTER PIEUP
3143 HANGUL LETTER SSANGPIEUP
3144 HANGUL LETTER PIEUP-SIOS
3145 HANGUL LETTER SIOS
3146 HANGUL LETTER SSANGSIOS
3147 HANGUL LETTER IEUNG
3148 HANGUL LETTER CIEUC
3149 HANGUL LETTER SSANGCIEUC
314A HANGUL LETTER CHIEUCH
314B HANGUL LETTER KHIEUKH
314C HANGUL LETTER THIEUTH
314D HANGUL LETTER PHIEUPH
314E HANGUL LETTER HIEUH
314F HANGUL LETTER A
3150 HANGUL LETTER AE
3151 HANGUL LETTER YA
3152 HANGUL LETTER YAE
3153 HANGUL LETTER EO
3154 HANGUL LETTER E
3155 HANGUL LETTER YEO
3156 HANGUL LETTER YE
3157 HANGUL LETTER O
3158 HANGUL LETTER WA
3159 HANGUL LETTER WAE
315A HANGUL LETTER OE
315B HANGUL LETTER YO
315C HANGUL LETTER U
315D HANGUL LETTER WEO
315E HANGUL LETTER WE
315F HANGUL LETTER WI
3160 HANGUL LETTER YU
3161 HANGUL LETTER EU
3162 HANGUL LETTER YI
3163 HANGUL LETTER I
3164 HANGUL FILLER
3165 HANGUL LETTER SSANGNIEUN
3166 HANGUL LETTER NIEUN-TIKEUT
3167 HANGUL LETTER NIEUN-SIOS
3168 HANGUL LETTER NIEUN-PANSIOS
3169 HANGUL LETTER RIEUL-KIYEOK-SIOS
316A HANGUL LETTER RIEUL-TIKEUT
316B HANGUL LETTER RIEUL-PIEUP-SIOS
316C HANGUL LETTER RIEUL-PANSIOS
316D HANGUL LETTER RIEUL-YEORINHIEUH
316E HANGUL LETTER MIEUM-PIEUP
316F HANGUL LETTER MIEUM-SIOS
3170 HANGUL LETTER MIEUM-PANSIOS
3171 HANGUL LETTER KAPYEOUNMIEUM
3172 HANGUL LETTER PIEUP-KIYEOK
3173 HANGUL LETTER PIEUP-TIKEUT
3174 HANGUL LETTER PIEUP-SIOS-KIYEOK
3175 HANGUL LETTER PIEUP-SIOS-TIKEUT
3176 HANGUL LETTER PIEUP-CIEUC
3177 HANGUL LETTER PIEUP-THIEUTH
3178 HANGUL LETTER KAPYEOUNPIEUP
3179 HANGUL LETTER KAPYEOUNSSANGPIEUP
317A HANGUL LETTER SIOS-KIYEOK
317B HANGUL LETTER SIOS-NIEUN
317C HANGUL LETTER SIOS-TIKEUT
317D HANGUL LETTER SIOS-PIEUP
317E HANGUL LETTER SIOS-CIEUC
317F HANGUL LETTER PANSIOS
3180 HANGUL LETTER SSANGIEUNG
3181 HANGUL LETTER YESIEUNG
3182 HANGUL LETTER YESIEUNG-SIOS
3183 HANGUL LETTER YESIEUNG-PANSIOS
3184 HANGUL LETTER KAPYEOUNPHIEUPH
3185 HANGUL LETTER SSANGHIEUH
3186 HANGUL LETTER YEORINHIEUH
3187 HANGUL LETTER YO-YA
3188 HANGUL LETTER YO-YAE
3189 HANGUL LETTER YO-I
318A HANGUL LETTER YU-YEO
318B HANGUL LETTER YU-YE
318C HANGUL LETTER YU-I
318D HANGUL LETTER ARAEA
318E HANGUL LETTER ARAEAE
3190 IDEOGRAPHIC ANNOTATION LINKING MARK
3191 IDEOGRAPHIC ANNOTATION REVERSE MARK
3192 IDEOGRAPHIC ANNOTATION ONE MARK
3193 IDEOGRAPHIC ANNOTATION TWO MARK
3194 IDEOGRAPHIC ANNOTATION THREE MARK
3195 IDEOGRAPHIC ANNOTATION FOUR MARK
3196 IDEOGRAPHIC ANNOTATION TOP MARK
3197 IDEOGRAPHIC ANNOTATION MIDDLE MARK
3198 IDEOGRAPHIC ANNOTATION BOTTOM MARK
3199 IDEOGRAPHIC ANNOTATION FIRST MARK
319A IDEOGRAPHIC ANNOTATION SECOND MARK
319B IDEOGRAPHIC ANNOTATION THIRD MARK
319C IDEOGRAPHIC ANNOTATION FOURTH MARK
319D IDEOGRAPHIC ANNOTATION HEAVEN MARK
319E IDEOGRAPHIC ANNOTATION EARTH MARK
319F IDEOGRAPHIC ANNOTATION MAN MARK
31A0 BOPOMOFO LETTER BU
31A1 BOPOMOFO LETTER ZI
31A2 BOPOMOFO LETTER JI
31A3 BOPOMOFO LETTER GU
31A4 BOPOMOFO LETTER EE
31A5 BOPOMOFO LETTER ENN
31A6 BOPOMOFO LETTER OO
31A7 BOPOMOFO LETTER ONN
31A8 BOPOMOFO LETTER IR
31A9 BOPOMOFO LETTER ANN
31AA BOPOMOFO LETTER INN
31AB BOPOMOFO LETTER UNN
31AC BOPOMOFO LETTER IM
31AD BOPOMOFO LETTER NGG
31AE BOPOMOFO LETTER AINN
31AF BOPOMOFO LETTER AUNN
31B0 BOPOMOFO LETTER AM
31B1 BOPOMOFO LETTER OM
31B2 BOPOMOFO LETTER ONG
31B3 BOPOMOFO LETTER INNN
31B4 BOPOMOFO FINAL LETTER P
31B5 BOPOMOFO FINAL LETTER T
31B6 BOPOMOFO FINAL LETTER K
31B7 BOPOMOFO FINAL LETTER H
31C0 CJK STROKE T
31C1 CJK STROKE WG
31C2 CJK STROKE XG
31C3 CJK STROKE BXG
31C4 CJK STROKE SW
31C5 CJK STROKE HZZ
31C6 CJK STROKE HZG
31C7 CJK STROKE HP
31C8 CJK STROKE HZWG
31C9 CJK STROKE SZWG
31CA CJK STROKE HZT
31CB CJK STROKE HZZP
31CC CJK STROKE HPWG
31CD CJK STROKE HZW
31CE CJK STROKE HZZZ
31CF CJK STROKE N
31F0 KATAKANA LETTER SMALL KU
31F1 KATAKANA LETTER SMALL SI
31F2 KATAKANA LETTER SMALL SU
31F3 KATAKANA LETTER SMALL TO
31F4 KATAKANA LETTER SMALL NU
31F5 KATAKANA LETTER SMALL HA
31F6 KATAKANA LETTER SMALL HI
31F7 KATAKANA LETTER SMALL HU
31F8 KATAKANA LETTER SMALL HE
31F9 KATAKANA LETTER SMALL HO
31FA KATAKANA LETTER SMALL MU
31FB KATAKANA LETTER SMALL RA
31FC KATAKANA LETTER SMALL RI
31FD KATAKANA LETTER SMALL RU
31FE KATAKANA LETTER SMALL RE
31FF KATAKANA LETTER SMALL RO
3200 PARENTHESIZED HANGUL KIYEOK
3201 PARENTHESIZED HANGUL NIEUN
3202 PARENTHESIZED HANGUL TIKEUT
3203 PARENTHESIZED HANGUL RIEUL
3204 PARENTHESIZED HANGUL MIEUM
3205 PARENTHESIZED HANGUL PIEUP
3206 PARENTHESIZED HANGUL SIOS
3207 PARENTHESIZED HANGUL IEUNG
3208 PARENTHESIZED HANGUL CIEUC
3209 PARENTHESIZED HANGUL CHIEUCH
320A PARENTHESIZED HANGUL KHIEUKH
320B PARENTHESIZED HANGUL THIEUTH
320C PARENTHESIZED HANGUL PHIEUPH
320D PARENTHESIZED HANGUL HIEUH
320E PARENTHESIZED HANGUL KIYEOK A
320F PARENTHESIZED HANGUL NIEUN A
3210 PARENTHESIZED HANGUL TIKEUT A
3211 PARENTHESIZED HANGUL RIEUL A
3212 PARENTHESIZED HANGUL MIEUM A
3213 PARENTHESIZED HANGUL PIEUP A
3214 PARENTHESIZED HANGUL SIOS A
3215 PARENTHESIZED HANGUL IEUNG A
3216 PARENTHESIZED HANGUL CIEUC A
3217 PARENTHESIZED HANGUL CHIEUCH A
3218 PARENTHESIZED HANGUL KHIEUKH A
3219 PARENTHESIZED HANGUL THIEUTH A
321A PARENTHESIZED HANGUL PHIEUPH A
321B PARENTHESIZED HANGUL HIEUH A
321C PARENTHESIZED HANGUL CIEUC U
321D PARENTHESIZED KOREAN CHARACTER OJEON
321E PARENTHESIZED KOREAN CHARACTER O HU
3220 PARENTHESIZED IDEOGRAPH ONE
3221 PARENTHESIZED IDEOGRAPH TWO
3222 PARENTHESIZED IDEOGRAPH THREE
3223 PARENTHESIZED IDEOGRAPH FOUR
3224 PARENTHESIZED IDEOGRAPH FIVE
3225 PARENTHESIZED IDEOGRAPH SIX
3226 PARENTHESIZED IDEOGRAPH SEVEN
3227 PARENTHESIZED IDEOGRAPH EIGHT
3228 PARENTHESIZED IDEOGRAPH NINE
3229 PARENTHESIZED IDEOGRAPH TEN
322A PARENTHESIZED IDEOGRAPH MOON
322B PARENTHESIZED IDEOGRAPH FIRE
322C PARENTHESIZED IDEOGRAPH WATER
322D PARENTHESIZED IDEOGRAPH WOOD
322E PARENTHESIZED IDEOGRAPH METAL
322F PARENTHESIZED IDEOGRAPH EARTH
3230 PARENTHESIZED IDEOGRAPH SUN
3231 PARENTHESIZED IDEOGRAPH STOCK
3232 PARENTHESIZED IDEOGRAPH HAVE
3233 PARENTHESIZED IDEOGRAPH SOCIETY
3234 PARENTHESIZED IDEOGRAPH NAME
3235 PARENTHESIZED IDEOGRAPH SPECIAL
3236 PARENTHESIZED IDEOGRAPH FINANCIAL
3237 PARENTHESIZED IDEOGRAPH CONGRATULATION
3238 PARENTHESIZED IDEOGRAPH LABOR
3239 PARENTHESIZED IDEOGRAPH REPRESENT
323A PARENTHESIZED IDEOGRAPH CALL
323B PARENTHESIZED IDEOGRAPH STUDY
323C PARENTHESIZED IDEOGRAPH SUPERVISE
323D PARENTHESIZED IDEOGRAPH ENTERPRISE
323E PARENTHESIZED IDEOGRAPH RESOURCE
323F PARENTHESIZED IDEOGRAPH ALLIANCE
3240 PARENTHESIZED IDEOGRAPH FESTIVAL
3241 PARENTHESIZED IDEOGRAPH REST
3242 PARENTHESIZED IDEOGRAPH SELF
3243 PARENTHESIZED IDEOGRAPH REACH
3250 PARTNERSHIP SIGN
3251 CIRCLED NUMBER TWENTY ONE
3252 CIRCLED NUMBER TWENTY TWO
3253 CIRCLED NUMBER TWENTY THREE
3254 CIRCLED NUMBER TWENTY FOUR
3255 CIRCLED NUMBER TWENTY FIVE
3256 CIRCLED NUMBER TWENTY SIX
3257 CIRCLED NUMBER TWENTY SEVEN
3258 CIRCLED NUMBER TWENTY EIGHT
3259 CIRCLED NUMBER TWENTY NINE
325A CIRCLED NUMBER THIRTY
325B CIRCLED NUMBER THIRTY ONE
325C CIRCLED NUMBER THIRTY TWO
325D CIRCLED NUMBER THIRTY THREE
325E CIRCLED NUMBER THIRTY FOUR
325F CIRCLED NUMBER THIRTY FIVE
3260 CIRCLED HANGUL KIYEOK
3261 CIRCLED HANGUL NIEUN
3262 CIRCLED HANGUL TIKEUT
3263 CIRCLED HANGUL RIEUL
3264 CIRCLED HANGUL MIEUM
3265 CIRCLED HANGUL PIEUP
3266 CIRCLED HANGUL SIOS
3267 CIRCLED HANGUL IEUNG
3268 CIRCLED HANGUL CIEUC
3269 CIRCLED HANGUL CHIEUCH
326A CIRCLED HANGUL KHIEUKH
326B CIRCLED HANGUL THIEUTH
326C CIRCLED HANGUL PHIEUPH
326D CIRCLED HANGUL HIEUH
326E CIRCLED HANGUL KIYEOK A
326F CIRCLED HANGUL NIEUN A
3270 CIRCLED HANGUL TIKEUT A
3271 CIRCLED HANGUL RIEUL A
3272 CIRCLED HANGUL MIEUM A
3273 CIRCLED HANGUL PIEUP A
3274 CIRCLED HANGUL SIOS A
3275 CIRCLED HANGUL IEUNG A
3276 CIRCLED HANGUL CIEUC A
3277 CIRCLED HANGUL CHIEUCH A
3278 CIRCLED HANGUL KHIEUKH A
3279 CIRCLED HANGUL THIEUTH A
327A CIRCLED HANGUL PHIEUPH A
327B CIRCLED HANGUL HIEUH A
327C CIRCLED KOREAN CHARACTER CHAMKO
327D CIRCLED KOREAN CHARACTER JUEUI
327E CIRCLED HANGUL IEUNG U
327F KOREAN STANDARD SYMBOL
3280 CIRCLED IDEOGRAPH ONE
3281 CIRCLED IDEOGRAPH TWO
3282 CIRCLED IDEOGRAPH THREE
3283 CIRCLED IDEOGRAPH FOUR
3284 CIRCLED IDEOGRAPH FIVE
3285 CIRCLED IDEOGRAPH SIX
3286 CIRCLED IDEOGRAPH SEVEN
3287 CIRCLED IDEOGRAPH EIGHT
3288 CIRCLED IDEOGRAPH NINE
3289 CIRCLED IDEOGRAPH TEN
328A CIRCLED IDEOGRAPH MOON
328B CIRCLED IDEOGRAPH FIRE
328C CIRCLED IDEOGRAPH WATER
328D CIRCLED IDEOGRAPH WOOD
328E CIRCLED IDEOGRAPH METAL
328F CIRCLED IDEOGRAPH EARTH
3290 CIRCLED IDEOGRAPH SUN
3291 CIRCLED IDEOGRAPH STOCK
3292 CIRCLED IDEOGRAPH HAVE
3293 CIRCLED IDEOGRAPH SOCIETY
3294 CIRCLED IDEOGRAPH NAME
3295 CIRCLED IDEOGRAPH SPECIAL
3296 CIRCLED IDEOGRAPH FINANCIAL
3297 CIRCLED IDEOGRAPH CONGRATULATION
3298 CIRCLED IDEOGRAPH LABOR
3299 CIRCLED IDEOGRAPH SECRET
329A CIRCLED IDEOGRAPH MALE
329B CIRCLED IDEOGRAPH FEMALE
329C CIRCLED IDEOGRAPH SUITABLE
329D CIRCLED IDEOGRAPH EXCELLENT
329E CIRCLED IDEOGRAPH PRINT
329F CIRCLED IDEOGRAPH ATTENTION
32A0 CIRCLED IDEOGRAPH ITEM
32A1 CIRCLED IDEOGRAPH REST
32A2 CIRCLED IDEOGRAPH COPY
32A3 CIRCLED IDEOGRAPH CORRECT
32A4 CIRCLED IDEOGRAPH HIGH
32A5 CIRCLED IDEOGRAPH CENTRE
32A6 CIRCLED IDEOGRAPH LOW
32A7 CIRCLED IDEOGRAPH LEFT
32A8 CIRCLED IDEOGRAPH RIGHT
32A9 CIRCLED IDEOGRAPH MEDICINE
32AA CIRCLED IDEOGRAPH RELIGION
32AB CIRCLED IDEOGRAPH STUDY
32AC CIRCLED IDEOGRAPH SUPERVISE
32AD CIRCLED IDEOGRAPH ENTERPRISE
32AE CIRCLED IDEOGRAPH RESOURCE
32AF CIRCLED IDEOGRAPH ALLIANCE
32B0 CIRCLED IDEOGRAPH NIGHT
32B1 CIRCLED NUMBER THIRTY SIX
32B2 CIRCLED NUMBER THIRTY SEVEN
32B3 CIRCLED NUMBER THIRTY EIGHT
32B4 CIRCLED NUMBER THIRTY NINE
32B5 CIRCLED NUMBER FORTY
32B6 CIRCLED NUMBER FORTY ONE
32B7 CIRCLED NUMBER FORTY TWO
32B8 CIRCLED NUMBER FORTY THREE
32B9 CIRCLED NUMBER FORTY FOUR
32BA CIRCLED NUMBER FORTY FIVE
32BB CIRCLED NUMBER FORTY SIX
32BC CIRCLED NUMBER FORTY SEVEN
32BD CIRCLED NUMBER FORTY EIGHT
32BE CIRCLED NUMBER FORTY NINE
32BF CIRCLED NUMBER FIFTY
32C0 IDEOGRAPHIC TELEGRAPH SYMBOL FOR JANUARY
32C1 IDEOGRAPHIC TELEGRAPH SYMBOL FOR FEBRUARY
32C2 IDEOGRAPHIC TELEGRAPH SYMBOL FOR MARCH
32C3 IDEOGRAPHIC TELEGRAPH SYMBOL FOR APRIL
32C4 IDEOGRAPHIC TELEGRAPH SYMBOL FOR MAY
32C5 IDEOGRAPHIC TELEGRAPH SYMBOL FOR JUNE
32C6 IDEOGRAPHIC TELEGRAPH SYMBOL FOR JULY
32C7 IDEOGRAPHIC TELEGRAPH SYMBOL FOR AUGUST
32C8 IDEOGRAPHIC TELEGRAPH SYMBOL FOR SEPTEMBER
32C9 IDEOGRAPHIC TELEGRAPH SYMBOL FOR OCTOBER
32CA IDEOGRAPHIC TELEGRAPH SYMBOL FOR NOVEMBER
32CB IDEOGRAPHIC TELEGRAPH SYMBOL FOR DECEMBER
32CC SQUARE HG
32CD SQUARE ERG
32CE SQUARE EV
32CF LIMITED LIABILITY SIGN
32D0 CIRCLED KATAKANA A
32D1 CIRCLED KATAKANA I
32D2 CIRCLED KATAKANA U
32D3 CIRCLED KATAKANA E
32D4 CIRCLED KATAKANA O
32D5 CIRCLED KATAKANA KA
32D6 CIRCLED KATAKANA KI
32D7 CIRCLED KATAKANA KU
32D8 CIRCLED KATAKANA KE
32D9 CIRCLED KATAKANA KO
32DA CIRCLED KATAKANA SA
32DB CIRCLED KATAKANA SI
32DC CIRCLED KATAKANA SU
32DD CIRCLED KATAKANA SE
32DE CIRCLED KATAKANA SO
32DF CIRCLED KATAKANA TA
32E0 CIRCLED KATAKANA TI
32E1 CIRCLED KATAKANA TU
32E2 CIRCLED KATAKANA TE
32E3 CIRCLED KATAKANA TO
32E4 CIRCLED KATAKANA NA
32E5 CIRCLED KATAKANA NI
32E6 CIRCLED KATAKANA NU
32E7 CIRCLED KATAKANA NE
32E8 CIRCLED KATAKANA NO
32E9 CIRCLED KATAKANA HA
32EA CIRCLED KATAKANA HI
32EB CIRCLED KATAKANA HU
32EC CIRCLED KATAKANA HE
32ED CIRCLED KATAKANA HO
32EE CIRCLED KATAKANA MA
32EF CIRCLED KATAKANA MI
32F0 CIRCLED KATAKANA MU
32F1 CIRCLED KATAKANA ME
32F2 CIRCLED KATAKANA MO
32F3 CIRCLED KATAKANA YA
32F4 CIRCLED KATAKANA YU
32F5 CIRCLED KATAKANA YO
32F6 CIRCLED KATAKANA RA
32F7 CIRCLED KATAKANA RI
32F8 CIRCLED KATAKANA RU
32F9 CIRCLED KATAKANA RE
32FA CIRCLED KATAKANA RO
32FB CIRCLED KATAKANA WA
32FC CIRCLED KATAKANA WI
32FD CIRCLED KATAKANA WE
32FE CIRCLED KATAKANA WO
3300 SQUARE APAATO
3301 SQUARE ARUHUA
3302 SQUARE ANPEA
3303 SQUARE AARU
3304 SQUARE ININGU
3305 SQUARE INTI
3306 SQUARE UON
3307 SQUARE ESUKUUDO
3308 SQUARE EEKAA
3309 SQUARE ONSU
330A SQUARE OOMU
330B SQUARE KAIRI
330C SQUARE KARATTO
330D SQUARE KARORII
330E SQUARE GARON
330F SQUARE GANMA
3310 SQUARE GIGA
3311 SQUARE GINII
3312 SQUARE KYURII
3313 SQUARE GIRUDAA
3314 SQUARE KIRO
3315 SQUARE KIROGURAMU
3316 SQUARE KIROMEETORU
3317 SQUARE KIROWATTO
3318 SQUARE GURAMU
3319 SQUARE GURAMUTON
331A SQUARE KURUZEIRO
331B SQUARE KUROONE
331C SQUARE KEESU
331D SQUARE KORUNA
331E SQUARE KOOPO
331F SQUARE SAIKURU
3320 SQUARE SANTIIMU
3321 SQUARE SIRINGU
3322 SQUARE SENTI
3323 SQUARE SENTO
3324 SQUARE DAASU
3325 SQUARE DESI
3326 SQUARE DORU
3327 SQUARE TON
3328 SQUARE NANO
3329 SQUARE NOTTO
332A SQUARE HAITU
332B SQUARE PAASENTO
332C SQUARE PAATU
332D SQUARE BAARERU
332E SQUARE PIASUTORU
332F SQUARE PIKURU
3330 SQUARE PIKO
3331 SQUARE BIRU
3332 SQUARE HUARADDO
3333 SQUARE HUIITO
3334 SQUARE BUSSYERU
3335 SQUARE HURAN
3336 SQUARE HEKUTAARU
3337 SQUARE PESO
3338 SQUARE PENIHI
3339 SQUARE HERUTU
333A SQUARE PENSU
333B SQUARE PEEZI
333C SQUARE BEETA
333D SQUARE POINTO
333E SQUARE BORUTO
333F SQUARE HON
3340 SQUARE PONDO
3341 SQUARE HOORU
3342 SQUARE HOON
3343 SQUARE MAIKURO
3344 SQUARE MAIRU
3345 SQUARE MAHHA
3346 SQUARE MARUKU
3347 SQUARE MANSYON
3348 SQUARE MIKURON
3349 SQUARE MIRI
334A SQUARE MIRIBAARU
334B SQUARE MEGA
334C SQUARE MEGATON
334D SQUARE MEETORU
334E SQUARE YAADO
334F SQUARE YAARU
3350 SQUARE YUAN
3351 SQUARE RITTORU
3352 SQUARE RIRA
3353 SQUARE RUPII
3354 SQUARE RUUBURU
3355 SQUARE REMU
3356 SQUARE RENTOGEN
3357 SQUARE WATTO
3358 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR ZERO
3359 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR ONE
335A IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR TWO
335B IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR THREE
335C IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR FOUR
335D IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR FIVE
335E IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR SIX
335F IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR SEVEN
3360 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR EIGHT
3361 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR NINE
3362 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR TEN
3363 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR ELEVEN
3364 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR TWELVE
3365 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR THIRTEEN
3366 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR FOURTEEN
3367 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR FIFTEEN
3368 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR SIXTEEN
3369 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR SEVENTEEN
336A IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR EIGHTEEN
336B IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR NINETEEN
336C IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR TWENTY
336D IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR TWENTY-ONE
336E IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR TWENTY-TWO
336F IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR TWENTY-THREE
3370 IDEOGRAPHIC TELEGRAPH SYMBOL FOR HOUR TWENTY-FOUR
3371 SQUARE HPA
3372 SQUARE DA
3373 SQUARE AU
3374 SQUARE BAR
3375 SQUARE OV
3376 SQUARE PC
3377 SQUARE DM
3378 SQUARE DM SQUARED
3379 SQUARE DM CUBED
337A SQUARE IU
337B SQUARE ERA NAME HEISEI
337C SQUARE ERA NAME SYOUWA
337D SQUARE ERA NAME TAISYOU
337E SQUARE ERA NAME MEIZI
337F SQUARE CORPORATION
3380 SQUARE PA AMPS
3381 SQUARE NA
3382 SQUARE MU A
3383 SQUARE MA
3384 SQUARE KA
3385 SQUARE KB
3386 SQUARE MB
3387 SQUARE GB
3388 SQUARE CAL
3389 SQUARE KCAL
338A SQUARE PF
338B SQUARE NF
338C SQUARE MU F
338D SQUARE MU G
338E SQUARE MG
338F SQUARE KG
3390 SQUARE HZ
3391 SQUARE KHZ
3392 SQUARE MHZ
3393 SQUARE GHZ
3394 SQUARE THZ
3395 SQUARE MU L
3396 SQUARE ML
3397 SQUARE DL
3398 SQUARE KL
3399 SQUARE FM
339A SQUARE NM
339B SQUARE MU M
339C SQUARE MM
339D SQUARE CM
339E SQUARE KM
339F SQUARE MM SQUARED
33A0 SQUARE CM SQUARED
33A1 SQUARE M SQUARED
33A2 SQUARE KM SQUARED
33A3 SQUARE MM CUBED
33A4 SQUARE CM CUBED
33A5 SQUARE M CUBED
33A6 SQUARE KM CUBED
33A7 SQUARE M OVER S
33A8 SQUARE M OVER S SQUARED
33A9 SQUARE PA
33AA SQUARE KPA
33AB SQUARE MPA
33AC SQUARE GPA
33AD SQUARE RAD
33AE SQUARE RAD OVER S
33AF SQUARE RAD OVER S SQUARED
33B0 SQUARE PS
33B1 SQUARE NS
33B2 SQUARE MU S
33B3 SQUARE MS
33B4 SQUARE PV
33B5 SQUARE NV
33B6 SQUARE MU V
33B7 SQUARE MV
33B8 SQUARE KV
33B9 SQUARE MV MEGA
33BA SQUARE PW
33BB SQUARE NW
33BC SQUARE MU W
33BD SQUARE MW
33BE SQUARE KW
33BF SQUARE MW MEGA
33C0 SQUARE K OHM
33C1 SQUARE M OHM
33C2 SQUARE AM
33C3 SQUARE BQ
33C4 SQUARE CC
33C5 SQUARE CD
33C6 SQUARE C OVER KG
33C7 SQUARE CO
33C8 SQUARE DB
33C9 SQUARE GY
33CA SQUARE HA
33CB SQUARE HP
33CC SQUARE IN
33CD SQUARE KK
33CE SQUARE KM CAPITAL
33CF SQUARE KT
33D0 SQUARE LM
33D1 SQUARE LN
33D2 SQUARE LOG
33D3 SQUARE LX
33D4 SQUARE MB SMALL
33D5 SQUARE MIL
33D6 SQUARE MOL
33D7 SQUARE PH
33D8 SQUARE PM
33D9 SQUARE PPM
33DA SQUARE PR
33DB SQUARE SR
33DC SQUARE SV
33DD SQUARE WB
33DE SQUARE V OVER M
33DF SQUARE A OVER M
33E0 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY ONE
33E1 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWO
33E2 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY THREE
33E3 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY FOUR
33E4 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY FIVE
33E5 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY SIX
33E6 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY SEVEN
33E7 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY EIGHT
33E8 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY NINE
33E9 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TEN
33EA IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY ELEVEN
33EB IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWELVE
33EC IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY THIRTEEN
33ED IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY FOURTEEN
33EE IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY FIFTEEN
33EF IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY SIXTEEN
33F0 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY SEVENTEEN
33F1 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY EIGHTEEN
33F2 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY NINETEEN
33F3 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWENTY
33F4 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWENTY-ONE
33F5 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWENTY-TWO
33F6 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWENTY-THREE
33F7 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWENTY-FOUR
33F8 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWENTY-FIVE
33F9 IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWENTY-SIX
33FA IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWENTY-SEVEN
33FB IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWENTY-EIGHT
33FC IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY TWENTY-NINE
33FD IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY THIRTY
33FE IDEOGRAPHIC TELEGRAPH SYMBOL FOR DAY THIRTY-ONE
33FF SQUARE GAL
3400 <CJK Ideograph Extension A, First>
4DB5 <CJK Ideograph Extension A, Last>
4DC0 HEXAGRAM FOR THE CREATIVE HEAVEN
4DC1 HEXAGRAM FOR THE RECEPTIVE EARTH
4DC2 HEXAGRAM FOR DIFFICULTY AT THE BEGINNING
4DC3 HEXAGRAM FOR YOUTHFUL FOLLY
4DC4 HEXAGRAM FOR WAITING
4DC5 HEXAGRAM FOR CONFLICT
4DC6 HEXAGRAM FOR THE ARMY
4DC7 HEXAGRAM FOR HOLDING TOGETHER
4DC8 HEXAGRAM FOR SMALL TAMING
4DC9 HEXAGRAM FOR TREADING
4DCA HEXAGRAM FOR PEACE
4DCB HEXAGRAM FOR STANDSTILL
4DCC HEXAGRAM FOR FELLOWSHIP
4DCD HEXAGRAM FOR GREAT POSSESSION
4DCE HEXAGRAM FOR MODESTY
4DCF HEXAGRAM FOR ENTHUSIASM
4DD0 HEXAGRAM FOR FOLLOWING
4DD1 HEXAGRAM FOR WORK ON THE DECAYED
4DD2 HEXAGRAM FOR APPROACH
4DD3 HEXAGRAM FOR CONTEMPLATION
4DD4 HEXAGRAM FOR BITING THROUGH
4DD5 HEXAGRAM FOR GRACE
4DD6 HEXAGRAM FOR SPLITTING APART
4DD7 HEXAGRAM FOR RETURN
4DD8 HEXAGRAM FOR INNOCENCE
4DD9 HEXAGRAM FOR GREAT TAMING
4DDA HEXAGRAM FOR MOUTH CORNERS
4DDB HEXAGRAM FOR GREAT PREPONDERANCE
4DDC HEXAGRAM FOR THE ABYSMAL WATER
4DDD HEXAGRAM FOR THE CLINGING FIRE
4DDE HEXAGRAM FOR INFLUENCE
4DDF HEXAGRAM FOR DURATION
4DE0 HEXAGRAM FOR RETREAT
4DE1 HEXAGRAM FOR GREAT POWER
4DE2 HEXAGRAM FOR PROGRESS
4DE3 HEXAGRAM FOR DARKENING OF THE LIGHT
4DE4 HEXAGRAM FOR THE FAMILY
4DE5 HEXAGRAM FOR OPPOSITION
4DE6 HEXAGRAM FOR OBSTRUCTION
4DE7 HEXAGRAM FOR DELIVERANCE
4DE8 HEXAGRAM FOR DECREASE
4DE9 HEXAGRAM FOR INCREASE
4DEA HEXAGRAM FOR BREAKTHROUGH
4DEB HEXAGRAM FOR COMING TO MEET
4DEC HEXAGRAM FOR GATHERING TOGETHER
4DED HEXAGRAM FOR PUSHING UPWARD
4DEE HEXAGRAM FOR OPPRESSION
4DEF HEXAGRAM FOR THE WELL
4DF0 HEXAGRAM FOR REVOLUTION
4DF1 HEXAGRAM FOR THE CAULDRON
4DF2 HEXAGRAM FOR THE AROUSING THUNDER
4DF3 HEXAGRAM FOR THE KEEPING STILL MOUNTAIN
4DF4 HEXAGRAM FOR DEVELOPMENT
4DF5 HEXAGRAM FOR THE MARRYING MAIDEN
4DF6 HEXAGRAM FOR ABUNDANCE
4DF7 HEXAGRAM FOR THE WANDERER
4DF8 HEXAGRAM FOR THE GENTLE WIND
4DF9 HEXAGRAM FOR THE JOYOUS LAKE
4DFA HEXAGRAM FOR DISPERSION
4DFB HEXAGRAM FOR LIMITATION
4DFC HEXAGRAM FOR INNER TRUTH
4DFD HEXAGRAM FOR SMALL PREPONDERANCE
4DFE HEXAGRAM FOR AFTER COMPLETION
4DFF HEXAGRAM FOR BEFORE COMPLETION
4E00 <CJK Ideograph, First>
9FBB <CJK Ideograph, Last>
A000 YI SYLLABLE IT
A001 YI SYLLABLE IX
A002 YI SYLLABLE I
A003 YI SYLLABLE IP
A004 YI SYLLABLE IET
A005 YI SYLLABLE IEX
A006 YI SYLLABLE IE
A007 YI SYLLABLE IEP
A008 YI SYLLABLE AT
A009 YI SYLLABLE AX
A00A YI SYLLABLE A
A00B YI SYLLABLE AP
A00C YI SYLLABLE UOX
A00D YI SYLLABLE UO
A00E YI SYLLABLE UOP
A00F YI SYLLABLE OT
A010 YI SYLLABLE OX
A011 YI SYLLABLE O
A012 YI SYLLABLE OP
A013 YI SYLLABLE EX
A014 YI SYLLABLE E
A015 YI SYLLABLE WU
A016 YI SYLLABLE BIT
A017 YI SYLLABLE BIX
A018 YI SYLLABLE BI
A019 YI SYLLABLE BIP
A01A YI SYLLABLE BIET
A01B YI SYLLABLE BIEX
A01C YI SYLLABLE BIE
A01D YI SYLLABLE BIEP
A01E YI SYLLABLE BAT
A01F YI SYLLABLE BAX
A020 YI SYLLABLE BA
A021 YI SYLLABLE BAP
A022 YI SYLLABLE BUOX
A023 YI SYLLABLE BUO
A024 YI SYLLABLE BUOP
A025 YI SYLLABLE BOT
A026 YI SYLLABLE BOX
A027 YI SYLLABLE BO
A028 YI SYLLABLE BOP
A029 YI SYLLABLE BEX
A02A YI SYLLABLE BE
A02B YI SYLLABLE BEP
A02C YI SYLLABLE BUT
A02D YI SYLLABLE BUX
A02E YI SYLLABLE BU
A02F YI SYLLABLE BUP
A030 YI SYLLABLE BURX
A031 YI SYLLABLE BUR
A032 YI SYLLABLE BYT
A033 YI SYLLABLE BYX
A034 YI SYLLABLE BY
A035 YI SYLLABLE BYP
A036 YI SYLLABLE BYRX
A037 YI SYLLABLE BYR
A038 YI SYLLABLE PIT
A039 YI SYLLABLE PIX
A03A YI SYLLABLE PI
A03B YI SYLLABLE PIP
A03C YI SYLLABLE PIEX
A03D YI SYLLABLE PIE
A03E YI SYLLABLE PIEP
A03F YI SYLLABLE PAT
A040 YI SYLLABLE PAX
A041 YI SYLLABLE PA
A042 YI SYLLABLE PAP
A043 YI SYLLABLE PUOX
A044 YI SYLLABLE PUO
A045 YI SYLLABLE PUOP
A046 YI SYLLABLE POT
A047 YI SYLLABLE POX
A048 YI SYLLABLE PO
A049 YI SYLLABLE POP
A04A YI SYLLABLE PUT
A04B YI SYLLABLE PUX
A04C YI SYLLABLE PU
A04D YI SYLLABLE PUP
A04E YI SYLLABLE PURX
A04F YI SYLLABLE PUR
A050 YI SYLLABLE PYT
A051 YI SYLLABLE PYX
A052 YI SYLLABLE PY
A053 YI SYLLABLE PYP
A054 YI SYLLABLE PYRX
A055 YI SYLLABLE PYR
A056 YI SYLLABLE BBIT
A057 YI SYLLABLE BBIX
A058 YI SYLLABLE BBI
A059 YI SYLLABLE BBIP
A05A YI SYLLABLE BBIET
A05B YI SYLLABLE BBIEX
A05C YI SYLLABLE BBIE
A05D YI SYLLABLE BBIEP
A05E YI SYLLABLE BBAT
A05F YI SYLLABLE BBAX
A060 YI SYLLABLE BBA
A061 YI SYLLABLE BBAP
A062 YI SYLLABLE BBUOX
A063 YI SYLLABLE BBUO
A064 YI SYLLABLE BBUOP
A065 YI SYLLABLE BBOT
A066 YI SYLLABLE BBOX
A067 YI SYLLABLE BBO
A068 YI SYLLABLE BBOP
A069 YI SYLLABLE BBEX
A06A YI SYLLABLE BBE
A06B YI SYLLABLE BBEP
A06C YI SYLLABLE BBUT
A06D YI SYLLABLE BBUX
A06E YI SYLLABLE BBU
A06F YI SYLLABLE BBUP
A070 YI SYLLABLE BBURX
A071 YI SYLLABLE BBUR
A072 YI SYLLABLE BBYT
A073 YI SYLLABLE BBYX
A074 YI SYLLABLE BBY
A075 YI SYLLABLE BBYP
A076 YI SYLLABLE NBIT
A077 YI SYLLABLE NBIX
A078 YI SYLLABLE NBI
A079 YI SYLLABLE NBIP
A07A YI SYLLABLE NBIEX
A07B YI SYLLABLE NBIE
A07C YI SYLLABLE NBIEP
A07D YI SYLLABLE NBAT
A07E YI SYLLABLE NBAX
A07F YI SYLLABLE NBA
A080 YI SYLLABLE NBAP
A081 YI SYLLABLE NBOT
A082 YI SYLLABLE NBOX
A083 YI SYLLABLE NBO
A084 YI SYLLABLE NBOP
A085 YI SYLLABLE NBUT
A086 YI SYLLABLE NBUX
A087 YI SYLLABLE NBU
A088 YI SYLLABLE NBUP
A089 YI SYLLABLE NBURX
A08A YI SYLLABLE NBUR
A08B YI SYLLABLE NBYT
A08C YI SYLLABLE NBYX
A08D YI SYLLABLE NBY
A08E YI SYLLABLE NBYP
A08F YI SYLLABLE NBYRX
A090 YI SYLLABLE NBYR
A091 YI SYLLABLE HMIT
A092 YI SYLLABLE HMIX
A093 YI SYLLABLE HMI
A094 YI SYLLABLE HMIP
A095 YI SYLLABLE HMIEX
A096 YI SYLLABLE HMIE
A097 YI SYLLABLE HMIEP
A098 YI SYLLABLE HMAT
A099 YI SYLLABLE HMAX
A09A YI SYLLABLE HMA
A09B YI SYLLABLE HMAP
A09C YI SYLLABLE HMUOX
A09D YI SYLLABLE HMUO
A09E YI SYLLABLE HMUOP
A09F YI SYLLABLE HMOT
A0A0 YI SYLLABLE HMOX
A0A1 YI SYLLABLE HMO
A0A2 YI SYLLABLE HMOP
A0A3 YI SYLLABLE HMUT
A0A4 YI SYLLABLE HMUX
A0A5 YI SYLLABLE HMU
A0A6 YI SYLLABLE HMUP
A0A7 YI SYLLABLE HMURX
A0A8 YI SYLLABLE HMUR
A0A9 YI SYLLABLE HMYX
A0AA YI SYLLABLE HMY
A0AB YI SYLLABLE HMYP
A0AC YI SYLLABLE HMYRX
A0AD YI SYLLABLE HMYR
A0AE YI SYLLABLE MIT
A0AF YI SYLLABLE MIX
A0B0 YI SYLLABLE MI
A0B1 YI SYLLABLE MIP
A0B2 YI SYLLABLE MIEX
A0B3 YI SYLLABLE MIE
A0B4 YI SYLLABLE MIEP
A0B5 YI SYLLABLE MAT
A0B6 YI SYLLABLE MAX
A0B7 YI SYLLABLE MA
A0B8 YI SYLLABLE MAP
A0B9 YI SYLLABLE MUOT
A0BA YI SYLLABLE MUOX
A0BB YI SYLLABLE MUO
A0BC YI SYLLABLE MUOP
A0BD YI SYLLABLE MOT
A0BE YI SYLLABLE MOX
A0BF YI SYLLABLE MO
A0C0 YI SYLLABLE MOP
A0C1 YI SYLLABLE MEX
A0C2 YI SYLLABLE ME
A0C3 YI SYLLABLE MUT
A0C4 YI SYLLABLE MUX
A0C5 YI SYLLABLE MU
A0C6 YI SYLLABLE MUP
A0C7 YI SYLLABLE MURX
A0C8 YI SYLLABLE MUR
A0C9 YI SYLLABLE MYT
A0CA YI SYLLABLE MYX
A0CB YI SYLLABLE MY
A0CC YI SYLLABLE MYP
A0CD YI SYLLABLE FIT
A0CE YI SYLLABLE FIX
A0CF YI SYLLABLE FI
A0D0 YI SYLLABLE FIP
A0D1 YI SYLLABLE FAT
A0D2 YI SYLLABLE FAX
A0D3 YI SYLLABLE FA
A0D4 YI SYLLABLE FAP
A0D5 YI SYLLABLE FOX
A0D6 YI SYLLABLE FO
A0D7 YI SYLLABLE FOP
A0D8 YI SYLLABLE FUT
A0D9 YI SYLLABLE FUX
A0DA YI SYLLABLE FU
A0DB YI SYLLABLE FUP
A0DC YI SYLLABLE FURX
A0DD YI SYLLABLE FUR
A0DE YI SYLLABLE FYT
A0DF YI SYLLABLE FYX
A0E0 YI SYLLABLE FY
A0E1 YI SYLLABLE FYP
A0E2 YI SYLLABLE VIT
A0E3 YI SYLLABLE VIX
A0E4 YI SYLLABLE VI
A0E5 YI SYLLABLE VIP
A0E6 YI SYLLABLE VIET
A0E7 YI SYLLABLE VIEX
A0E8 YI SYLLABLE VIE
A0E9 YI SYLLABLE VIEP
A0EA YI SYLLABLE VAT
A0EB YI SYLLABLE VAX
A0EC YI SYLLABLE VA
A0ED YI SYLLABLE VAP
A0EE YI SYLLABLE VOT
A0EF YI SYLLABLE VOX
A0F0 YI SYLLABLE VO
A0F1 YI SYLLABLE VOP
A0F2 YI SYLLABLE VEX
A0F3 YI SYLLABLE VEP
A0F4 YI SYLLABLE VUT
A0F5 YI SYLLABLE VUX
A0F6 YI SYLLABLE VU
A0F7 YI SYLLABLE VUP
A0F8 YI SYLLABLE VURX
A0F9 YI SYLLABLE VUR
A0FA YI SYLLABLE VYT
A0FB YI SYLLABLE VYX
A0FC YI SYLLABLE VY
A0FD YI SYLLABLE VYP
A0FE YI SYLLABLE VYRX
A0FF YI SYLLABLE VYR
A100 YI SYLLABLE DIT
A101 YI SYLLABLE DIX
A102 YI SYLLABLE DI
A103 YI SYLLABLE DIP
A104 YI SYLLABLE DIEX
A105 YI SYLLABLE DIE
A106 YI SYLLABLE DIEP
A107 YI SYLLABLE DAT
A108 YI SYLLABLE DAX
A109 YI SYLLABLE DA
A10A YI SYLLABLE DAP
A10B YI SYLLABLE DUOX
A10C YI SYLLABLE DUO
A10D YI SYLLABLE DOT
A10E YI SYLLABLE DOX
A10F YI SYLLABLE DO
A110 YI SYLLABLE DOP
A111 YI SYLLABLE DEX
A112 YI SYLLABLE DE
A113 YI SYLLABLE DEP
A114 YI SYLLABLE DUT
A115 YI SYLLABLE DUX
A116 YI SYLLABLE DU
A117 YI SYLLABLE DUP
A118 YI SYLLABLE DURX
A119 YI SYLLABLE DUR
A11A YI SYLLABLE TIT
A11B YI SYLLABLE TIX
A11C YI SYLLABLE TI
A11D YI SYLLABLE TIP
A11E YI SYLLABLE TIEX
A11F YI SYLLABLE TIE
A120 YI SYLLABLE TIEP
A121 YI SYLLABLE TAT
A122 YI SYLLABLE TAX
A123 YI SYLLABLE TA
A124 YI SYLLABLE TAP
A125 YI SYLLABLE TUOT
A126 YI SYLLABLE TUOX
A127 YI SYLLABLE TUO
A128 YI SYLLABLE TUOP
A129 YI SYLLABLE TOT
A12A YI SYLLABLE TOX
A12B YI SYLLABLE TO
A12C YI SYLLABLE TOP
A12D YI SYLLABLE TEX
A12E YI SYLLABLE TE
A12F YI SYLLABLE TEP
A130 YI SYLLABLE TUT
A131 YI SYLLABLE TUX
A132 YI SYLLABLE TU
A133 YI SYLLABLE TUP
A134 YI SYLLABLE TURX
A135 YI SYLLABLE TUR
A136 YI SYLLABLE DDIT
A137 YI SYLLABLE DDIX
A138 YI SYLLABLE DDI
A139 YI SYLLABLE DDIP
A13A YI SYLLABLE DDIEX
A13B YI SYLLABLE DDIE
A13C YI SYLLABLE DDIEP
A13D YI SYLLABLE DDAT
A13E YI SYLLABLE DDAX
A13F YI SYLLABLE DDA
A140 YI SYLLABLE DDAP
A141 YI SYLLABLE DDUOX
A142 YI SYLLABLE DDUO
A143 YI SYLLABLE DDUOP
A144 YI SYLLABLE DDOT
A145 YI SYLLABLE DDOX
A146 YI SYLLABLE DDO
A147 YI SYLLABLE DDOP
A148 YI SYLLABLE DDEX
A149 YI SYLLABLE DDE
A14A YI SYLLABLE DDEP
A14B YI SYLLABLE DDUT
A14C YI SYLLABLE DDUX
A14D YI SYLLABLE DDU
A14E YI SYLLABLE DDUP
A14F YI SYLLABLE DDURX
A150 YI SYLLABLE DDUR
A151 YI SYLLABLE NDIT
A152 YI SYLLABLE NDIX
A153 YI SYLLABLE NDI
A154 YI SYLLABLE NDIP
A155 YI SYLLABLE NDIEX
A156 YI SYLLABLE NDIE
A157 YI SYLLABLE NDAT
A158 YI SYLLABLE NDAX
A159 YI SYLLABLE NDA
A15A YI SYLLABLE NDAP
A15B YI SYLLABLE NDOT
A15C YI SYLLABLE NDOX
A15D YI SYLLABLE NDO
A15E YI SYLLABLE NDOP
A15F YI SYLLABLE NDEX
A160 YI SYLLABLE NDE
A161 YI SYLLABLE NDEP
A162 YI SYLLABLE NDUT
A163 YI SYLLABLE NDUX
A164 YI SYLLABLE NDU
A165 YI SYLLABLE NDUP
A166 YI SYLLABLE NDURX
A167 YI SYLLABLE NDUR
A168 YI SYLLABLE HNIT
A169 YI SYLLABLE HNIX
A16A YI SYLLABLE HNI
A16B YI SYLLABLE HNIP
A16C YI SYLLABLE HNIET
A16D YI SYLLABLE HNIEX
A16E YI SYLLABLE HNIE
A16F YI SYLLABLE HNIEP
A170 YI SYLLABLE HNAT
A171 YI SYLLABLE HNAX
A172 YI SYLLABLE HNA
A173 YI SYLLABLE HNAP
A174 YI SYLLABLE HNUOX
A175 YI SYLLABLE HNUO
A176 YI SYLLABLE HNOT
A177 YI SYLLABLE HNOX
A178 YI SYLLABLE HNOP
A179 YI SYLLABLE HNEX
A17A YI SYLLABLE HNE
A17B YI SYLLABLE HNEP
A17C YI SYLLABLE HNUT
A17D YI SYLLABLE NIT
A17E YI SYLLABLE NIX
A17F YI SYLLABLE NI
A180 YI SYLLABLE NIP
A181 YI SYLLABLE NIEX
A182 YI SYLLABLE NIE
A183 YI SYLLABLE NIEP
A184 YI SYLLABLE NAX
A185 YI SYLLABLE NA
A186 YI SYLLABLE NAP
A187 YI SYLLABLE NUOX
A188 YI SYLLABLE NUO
A189 YI SYLLABLE NUOP
A18A YI SYLLABLE NOT
A18B YI SYLLABLE NOX
A18C YI SYLLABLE NO
A18D YI SYLLABLE NOP
A18E YI SYLLABLE NEX
A18F YI SYLLABLE NE
A190 YI SYLLABLE NEP
A191 YI SYLLABLE NUT
A192 YI SYLLABLE NUX
A193 YI SYLLABLE NU
A194 YI SYLLABLE NUP
A195 YI SYLLABLE NURX
A196 YI SYLLABLE NUR
A197 YI SYLLABLE HLIT
A198 YI SYLLABLE HLIX
A199 YI SYLLABLE HLI
A19A YI SYLLABLE HLIP
A19B YI SYLLABLE HLIEX
A19C YI SYLLABLE HLIE
A19D YI SYLLABLE HLIEP
A19E YI SYLLABLE HLAT
A19F YI SYLLABLE HLAX
A1A0 YI SYLLABLE HLA
A1A1 YI SYLLABLE HLAP
A1A2 YI SYLLABLE HLUOX
A1A3 YI SYLLABLE HLUO
A1A4 YI SYLLABLE HLUOP
A1A5 YI SYLLABLE HLOX
A1A6 YI SYLLABLE HLO
A1A7 YI SYLLABLE HLOP
A1A8 YI SYLLABLE HLEX
A1A9 YI SYLLABLE HLE
A1AA YI SYLLABLE HLEP
A1AB YI SYLLABLE HLUT
A1AC YI SYLLABLE HLUX
A1AD YI SYLLABLE HLU
A1AE YI SYLLABLE HLUP
A1AF YI SYLLABLE HLURX
A1B0 YI SYLLABLE HLUR
A1B1 YI SYLLABLE HLYT
A1B2 YI SYLLABLE HLYX
A1B3 YI SYLLABLE HLY
A1B4 YI SYLLABLE HLYP
A1B5 YI SYLLABLE HLYRX
A1B6 YI SYLLABLE HLYR
A1B7 YI SYLLABLE LIT
A1B8 YI SYLLABLE LIX
A1B9 YI SYLLABLE LI
A1BA YI SYLLABLE LIP
A1BB YI SYLLABLE LIET
A1BC YI SYLLABLE LIEX
A1BD YI SYLLABLE LIE
A1BE YI SYLLABLE LIEP
A1BF YI SYLLABLE LAT
A1C0 YI SYLLABLE LAX
A1C1 YI SYLLABLE LA
A1C2 YI SYLLABLE LAP
A1C3 YI SYLLABLE LUOT
A1C4 YI SYLLABLE LUOX
A1C5 YI SYLLABLE LUO
A1C6 YI SYLLABLE LUOP
A1C7 YI SYLLABLE LOT
A1C8 YI SYLLABLE LOX
A1C9 YI SYLLABLE LO
A1CA YI SYLLABLE LOP
A1CB YI SYLLABLE LEX
A1CC YI SYLLABLE LE
A1CD YI SYLLABLE LEP
A1CE YI SYLLABLE LUT
A1CF YI SYLLABLE LUX
A1D0 YI SYLLABLE LU
A1D1 YI SYLLABLE LUP
A1D2 YI SYLLABLE LURX
A1D3 YI SYLLABLE LUR
A1D4 YI SYLLABLE LYT
A1D5 YI SYLLABLE LYX
A1D6 YI SYLLABLE LY
A1D7 YI SYLLABLE LYP
A1D8 YI SYLLABLE LYRX
A1D9 YI SYLLABLE LYR
A1DA YI SYLLABLE GIT
A1DB YI SYLLABLE GIX
A1DC YI SYLLABLE GI
A1DD YI SYLLABLE GIP
A1DE YI SYLLABLE GIET
A1DF YI SYLLABLE GIEX
A1E0 YI SYLLABLE GIE
A1E1 YI SYLLABLE GIEP
A1E2 YI SYLLABLE GAT
A1E3 YI SYLLABLE GAX
A1E4 YI SYLLABLE GA
A1E5 YI SYLLABLE GAP
A1E6 YI SYLLABLE GUOT
A1E7 YI SYLLABLE GUOX
A1E8 YI SYLLABLE GUO
A1E9 YI SYLLABLE GUOP
A1EA YI SYLLABLE GOT
A1EB YI SYLLABLE GOX
A1EC YI SYLLABLE GO
A1ED YI SYLLABLE GOP
A1EE YI SYLLABLE GET
A1EF YI SYLLABLE GEX
A1F0 YI SYLLABLE GE
A1F1 YI SYLLABLE GEP
A1F2 YI SYLLABLE GUT
A1F3 YI SYLLABLE GUX
A1F4 YI SYLLABLE GU
A1F5 YI SYLLABLE GUP
A1F6 YI SYLLABLE GURX
A1F7 YI SYLLABLE GUR
A1F8 YI SYLLABLE KIT
A1F9 YI SYLLABLE KIX
A1FA YI SYLLABLE KI
A1FB YI SYLLABLE KIP
A1FC YI SYLLABLE KIEX
A1FD YI SYLLABLE KIE
A1FE YI SYLLABLE KIEP
A1FF YI SYLLABLE KAT
A200 YI SYLLABLE KAX
A201 YI SYLLABLE KA
A202 YI SYLLABLE KAP
A203 YI SYLLABLE KUOX
A204 YI SYLLABLE KUO
A205 YI SYLLABLE KUOP
A206 YI SYLLABLE KOT
A207 YI SYLLABLE KOX
A208 YI SYLLABLE KO
A209 YI SYLLABLE KOP
A20A YI SYLLABLE KET
A20B YI SYLLABLE KEX
A20C YI SYLLABLE KE
A20D YI SYLLABLE KEP
A20E YI SYLLABLE KUT
A20F YI SYLLABLE KUX
A210 YI SYLLABLE KU
A211 YI SYLLABLE KUP
A212 YI SYLLABLE KURX
A213 YI SYLLABLE KUR
A214 YI SYLLABLE GGIT
A215 YI SYLLABLE GGIX
A216 YI SYLLABLE GGI
A217 YI SYLLABLE GGIEX
A218 YI SYLLABLE GGIE
A219 YI SYLLABLE GGIEP
A21A YI SYLLABLE GGAT
A21B YI SYLLABLE GGAX
A21C YI SYLLABLE GGA
A21D YI SYLLABLE GGAP
A21E YI SYLLABLE GGUOT
A21F YI SYLLABLE GGUOX
A220 YI SYLLABLE GGUO
A221 YI SYLLABLE GGUOP
A222 YI SYLLABLE GGOT
A223 YI SYLLABLE GGOX
A224 YI SYLLABLE GGO
A225 YI SYLLABLE GGOP
A226 YI SYLLABLE GGET
A227 YI SYLLABLE GGEX
A228 YI SYLLABLE GGE
A229 YI SYLLABLE GGEP
A22A YI SYLLABLE GGUT
A22B YI SYLLABLE GGUX
A22C YI SYLLABLE GGU
A22D YI SYLLABLE GGUP
A22E YI SYLLABLE GGURX
A22F YI SYLLABLE GGUR
A230 YI SYLLABLE MGIEX
A231 YI SYLLABLE MGIE
A232 YI SYLLABLE MGAT
A233 YI SYLLABLE MGAX
A234 YI SYLLABLE MGA
A235 YI SYLLABLE MGAP
A236 YI SYLLABLE MGUOX
A237 YI SYLLABLE MGUO
A238 YI SYLLABLE MGUOP
A239 YI SYLLABLE MGOT
A23A YI SYLLABLE MGOX
A23B YI SYLLABLE MGO
A23C YI SYLLABLE MGOP
A23D YI SYLLABLE MGEX
A23E YI SYLLABLE MGE
A23F YI SYLLABLE MGEP
A240 YI SYLLABLE MGUT
A241 YI SYLLABLE MGUX
A242 YI SYLLABLE MGU
A243 YI SYLLABLE MGUP
A244 YI SYLLABLE MGURX
A245 YI SYLLABLE MGUR
A246 YI SYLLABLE HXIT
A247 YI SYLLABLE HXIX
A248 YI SYLLABLE HXI
A249 YI SYLLABLE HXIP
A24A YI SYLLABLE HXIET
A24B YI SYLLABLE HXIEX
A24C YI SYLLABLE HXIE
A24D YI SYLLABLE HXIEP
A24E YI SYLLABLE HXAT
A24F YI SYLLABLE HXAX
A250 YI SYLLABLE HXA
A251 YI SYLLABLE HXAP
A252 YI SYLLABLE HXUOT
A253 YI SYLLABLE HXUOX
A254 YI SYLLABLE HXUO
A255 YI SYLLABLE HXUOP
A256 YI SYLLABLE HXOT
A257 YI SYLLABLE HXOX
A258 YI SYLLABLE HXO
A259 YI SYLLABLE HXOP
A25A YI SYLLABLE HXEX
A25B YI SYLLABLE HXE
A25C YI SYLLABLE HXEP
A25D YI SYLLABLE NGIEX
A25E YI SYLLABLE NGIE
A25F YI SYLLABLE NGIEP
A260 YI SYLLABLE NGAT
A261 YI SYLLABLE NGAX
A262 YI SYLLABLE NGA
A263 YI SYLLABLE NGAP
A264 YI SYLLABLE NGUOT
A265 YI SYLLABLE NGUOX
A266 YI SYLLABLE NGUO
A267 YI SYLLABLE NGOT
A268 YI SYLLABLE NGOX
A269 YI SYLLABLE NGO
A26A YI SYLLABLE NGOP
A26B YI SYLLABLE NGEX
A26C YI SYLLABLE NGE
A26D YI SYLLABLE NGEP
A26E YI SYLLABLE HIT
A26F YI SYLLABLE HIEX
A270 YI SYLLABLE HIE
A271 YI SYLLABLE HAT
A272 YI SYLLABLE HAX
A273 YI SYLLABLE HA
A274 YI SYLLABLE HAP
A275 YI SYLLABLE HUOT
A276 YI SYLLABLE HUOX
A277 YI SYLLABLE HUO
A278 YI SYLLABLE HUOP
A279 YI SYLLABLE HOT
A27A YI SYLLABLE HOX
A27B YI SYLLABLE HO
A27C YI SYLLABLE HOP
A27D YI SYLLABLE HEX
A27E YI SYLLABLE HE
A27F YI SYLLABLE HEP
A280 YI SYLLABLE WAT
A281 YI SYLLABLE WAX
A282 YI SYLLABLE WA
A283 YI SYLLABLE WAP
A284 YI SYLLABLE WUOX
A285 YI SYLLABLE WUO
A286 YI SYLLABLE WUOP
A287 YI SYLLABLE WOX
A288 YI SYLLABLE WO
A289 YI SYLLABLE WOP
A28A YI SYLLABLE WEX
A28B YI SYLLABLE WE
A28C YI SYLLABLE WEP
A28D YI SYLLABLE ZIT
A28E YI SYLLABLE ZIX
A28F YI SYLLABLE ZI
A290 YI SYLLABLE ZIP
A291 YI SYLLABLE ZIEX
A292 YI SYLLABLE ZIE
A293 YI SYLLABLE ZIEP
A294 YI SYLLABLE ZAT
A295 YI SYLLABLE ZAX
A296 YI SYLLABLE ZA
A297 YI SYLLABLE ZAP
A298 YI SYLLABLE ZUOX
A299 YI SYLLABLE ZUO
A29A YI SYLLABLE ZUOP
A29B YI SYLLABLE ZOT
A29C YI SYLLABLE ZOX
A29D YI SYLLABLE ZO
A29E YI SYLLABLE ZOP
A29F YI SYLLABLE ZEX
A2A0 YI SYLLABLE ZE
A2A1 YI SYLLABLE ZEP
A2A2 YI SYLLABLE ZUT
A2A3 YI SYLLABLE ZUX
A2A4 YI SYLLABLE ZU
A2A5 YI SYLLABLE ZUP
A2A6 YI SYLLABLE ZURX
A2A7 YI SYLLABLE ZUR
A2A8 YI SYLLABLE ZYT
A2A9 YI SYLLABLE ZYX
A2AA YI SYLLABLE ZY
A2AB YI SYLLABLE ZYP
A2AC YI SYLLABLE ZYRX
A2AD YI SYLLABLE ZYR
A2AE YI SYLLABLE CIT
A2AF YI SYLLABLE CIX
A2B0 YI SYLLABLE CI
A2B1 YI SYLLABLE CIP
A2B2 YI SYLLABLE CIET
A2B3 YI SYLLABLE CIEX
A2B4 YI SYLLABLE CIE
A2B5 YI SYLLABLE CIEP
A2B6 YI SYLLABLE CAT
A2B7 YI SYLLABLE CAX
A2B8 YI SYLLABLE CA
A2B9 YI SYLLABLE CAP
A2BA YI SYLLABLE CUOX
A2BB YI SYLLABLE CUO
A2BC YI SYLLABLE CUOP
A2BD YI SYLLABLE COT
A2BE YI SYLLABLE COX
A2BF YI SYLLABLE CO
A2C0 YI SYLLABLE COP
A2C1 YI SYLLABLE CEX
A2C2 YI SYLLABLE CE
A2C3 YI SYLLABLE CEP
A2C4 YI SYLLABLE CUT
A2C5 YI SYLLABLE CUX
A2C6 YI SYLLABLE CU
A2C7 YI SYLLABLE CUP
A2C8 YI SYLLABLE CURX
A2C9 YI SYLLABLE CUR
A2CA YI SYLLABLE CYT
A2CB YI SYLLABLE CYX
A2CC YI SYLLABLE CY
A2CD YI SYLLABLE CYP
A2CE YI SYLLABLE CYRX
A2CF YI SYLLABLE CYR
A2D0 YI SYLLABLE ZZIT
A2D1 YI SYLLABLE ZZIX
A2D2 YI SYLLABLE ZZI
A2D3 YI SYLLABLE ZZIP
A2D4 YI SYLLABLE ZZIET
A2D5 YI SYLLABLE ZZIEX
A2D6 YI SYLLABLE ZZIE
A2D7 YI SYLLABLE ZZIEP
A2D8 YI SYLLABLE ZZAT
A2D9 YI SYLLABLE ZZAX
A2DA YI SYLLABLE ZZA
A2DB YI SYLLABLE ZZAP
A2DC YI SYLLABLE ZZOX
A2DD YI SYLLABLE ZZO
A2DE YI SYLLABLE ZZOP
A2DF YI SYLLABLE ZZEX
A2E0 YI SYLLABLE ZZE
A2E1 YI SYLLABLE ZZEP
A2E2 YI SYLLABLE ZZUX
A2E3 YI SYLLABLE ZZU
A2E4 YI SYLLABLE ZZUP
A2E5 YI SYLLABLE ZZURX
A2E6 YI SYLLABLE ZZUR
A2E7 YI SYLLABLE ZZYT
A2E8 YI SYLLABLE ZZYX
A2E9 YI SYLLABLE ZZY
A2EA YI SYLLABLE ZZYP
A2EB YI SYLLABLE ZZYRX
A2EC YI SYLLABLE ZZYR
A2ED YI SYLLABLE NZIT
A2EE YI SYLLABLE NZIX
A2EF YI SYLLABLE NZI
A2F0 YI SYLLABLE NZIP
A2F1 YI SYLLABLE NZIEX
A2F2 YI SYLLABLE NZIE
A2F3 YI SYLLABLE NZIEP
A2F4 YI SYLLABLE NZAT
A2F5 YI SYLLABLE NZAX
A2F6 YI SYLLABLE NZA
A2F7 YI SYLLABLE NZAP
A2F8 YI SYLLABLE NZUOX
A2F9 YI SYLLABLE NZUO
A2FA YI SYLLABLE NZOX
A2FB YI SYLLABLE NZOP
A2FC YI SYLLABLE NZEX
A2FD YI SYLLABLE NZE
A2FE YI SYLLABLE NZUX
A2FF YI SYLLABLE NZU
A300 YI SYLLABLE NZUP
A301 YI SYLLABLE NZURX
A302 YI SYLLABLE NZUR
A303 YI SYLLABLE NZYT
A304 YI SYLLABLE NZYX
A305 YI SYLLABLE NZY
A306 YI SYLLABLE NZYP
A307 YI SYLLABLE NZYRX
A308 YI SYLLABLE NZYR
A309 YI SYLLABLE SIT
A30A YI SYLLABLE SIX
A30B YI SYLLABLE SI
A30C YI SYLLABLE SIP
A30D YI SYLLABLE SIEX
A30E YI SYLLABLE SIE
A30F YI SYLLABLE SIEP
A310 YI SYLLABLE SAT
A311 YI SYLLABLE SAX
A312 YI SYLLABLE SA
A313 YI SYLLABLE SAP
A314 YI SYLLABLE SUOX
A315 YI SYLLABLE SUO
A316 YI SYLLABLE SUOP
A317 YI SYLLABLE SOT
A318 YI SYLLABLE SOX
A319 YI SYLLABLE SO
A31A YI SYLLABLE SOP
A31B YI SYLLABLE SEX
A31C YI SYLLABLE SE
A31D YI SYLLABLE SEP
A31E YI SYLLABLE SUT
A31F YI SYLLABLE SUX
A320 YI SYLLABLE SU
A321 YI SYLLABLE SUP
A322 YI SYLLABLE SURX
A323 YI SYLLABLE SUR
A324 YI SYLLABLE SYT
A325 YI SYLLABLE SYX
A326 YI SYLLABLE SY
A327 YI SYLLABLE SYP
A328 YI SYLLABLE SYRX
A329 YI SYLLABLE SYR
A32A YI SYLLABLE SSIT
A32B YI SYLLABLE SSIX
A32C YI SYLLABLE SSI
A32D YI SYLLABLE SSIP
A32E YI SYLLABLE SSIEX
A32F YI SYLLABLE SSIE
A330 YI SYLLABLE SSIEP
A331 YI SYLLABLE SSAT
A332 YI SYLLABLE SSAX
A333 YI SYLLABLE SSA
A334 YI SYLLABLE SSAP
A335 YI SYLLABLE SSOT
A336 YI SYLLABLE SSOX
A337 YI SYLLABLE SSO
A338 YI SYLLABLE SSOP
A339 YI SYLLABLE SSEX
A33A YI SYLLABLE SSE
A33B YI SYLLABLE SSEP
A33C YI SYLLABLE SSUT
A33D YI SYLLABLE SSUX
A33E YI SYLLABLE SSU
A33F YI SYLLABLE SSUP
A340 YI SYLLABLE SSYT
A341 YI SYLLABLE SSYX
A342 YI SYLLABLE SSY
A343 YI SYLLABLE SSYP
A344 YI SYLLABLE SSYRX
A345 YI SYLLABLE SSYR
A346 YI SYLLABLE ZHAT
A347 YI SYLLABLE ZHAX
A348 YI SYLLABLE ZHA
A349 YI SYLLABLE ZHAP
A34A YI SYLLABLE ZHUOX
A34B YI SYLLABLE ZHUO
A34C YI SYLLABLE ZHUOP
A34D YI SYLLABLE ZHOT
A34E YI SYLLABLE ZHOX
A34F YI SYLLABLE ZHO
A350 YI SYLLABLE ZHOP
A351 YI SYLLABLE ZHET
A352 YI SYLLABLE ZHEX
A353 YI SYLLABLE ZHE
A354 YI SYLLABLE ZHEP
A355 YI SYLLABLE ZHUT
A356 YI SYLLABLE ZHUX
A357 YI SYLLABLE ZHU
A358 YI SYLLABLE ZHUP
A359 YI SYLLABLE ZHURX
A35A YI SYLLABLE ZHUR
A35B YI SYLLABLE ZHYT
A35C YI SYLLABLE ZHYX
A35D YI SYLLABLE ZHY
A35E YI SYLLABLE ZHYP
A35F YI SYLLABLE ZHYRX
A360 YI SYLLABLE ZHYR
A361 YI SYLLABLE CHAT
A362 YI SYLLABLE CHAX
A363 YI SYLLABLE CHA
A364 YI SYLLABLE CHAP
A365 YI SYLLABLE CHUOT
A366 YI SYLLABLE CHUOX
A367 YI SYLLABLE CHUO
A368 YI SYLLABLE CHUOP
A369 YI SYLLABLE CHOT
A36A YI SYLLABLE CHOX
A36B YI SYLLABLE CHO
A36C YI SYLLABLE CHOP
A36D YI SYLLABLE CHET
A36E YI SYLLABLE CHEX
A36F YI SYLLABLE CHE
A370 YI SYLLABLE CHEP
A371 YI SYLLABLE CHUX
A372 YI SYLLABLE CHU
A373 YI SYLLABLE CHUP
A374 YI SYLLABLE CHURX
A375 YI SYLLABLE CHUR
A376 YI SYLLABLE CHYT
A377 YI SYLLABLE CHYX
A378 YI SYLLABLE CHY
A379 YI SYLLABLE CHYP
A37A YI SYLLABLE CHYRX
A37B YI SYLLABLE CHYR
A37C YI SYLLABLE RRAX
A37D YI SYLLABLE RRA
A37E YI SYLLABLE RRUOX
A37F YI SYLLABLE RRUO
A380 YI SYLLABLE RROT
A381 YI SYLLABLE RROX
A382 YI SYLLABLE RRO
A383 YI SYLLABLE RROP
A384 YI SYLLABLE RRET
A385 YI SYLLABLE RREX
A386 YI SYLLABLE RRE
A387 YI SYLLABLE RREP
A388 YI SYLLABLE RRUT
A389 YI SYLLABLE RRUX
A38A YI SYLLABLE RRU
A38B YI SYLLABLE RRUP
A38C YI SYLLABLE RRURX
A38D YI SYLLABLE RRUR
A38E YI SYLLABLE RRYT
A38F YI SYLLABLE RRYX
A390 YI SYLLABLE RRY
A391 YI SYLLABLE RRYP
A392 YI SYLLABLE RRYRX
A393 YI SYLLABLE RRYR
A394 YI SYLLABLE NRAT
A395 YI SYLLABLE NRAX
A396 YI SYLLABLE NRA
A397 YI SYLLABLE NRAP
A398 YI SYLLABLE NROX
A399 YI SYLLABLE NRO
A39A YI SYLLABLE NROP
A39B YI SYLLABLE NRET
A39C YI SYLLABLE NREX
A39D YI SYLLABLE NRE
A39E YI SYLLABLE NREP
A39F YI SYLLABLE NRUT
A3A0 YI SYLLABLE NRUX
A3A1 YI SYLLABLE NRU
A3A2 YI SYLLABLE NRUP
A3A3 YI SYLLABLE NRURX
A3A4 YI SYLLABLE NRUR
A3A5 YI SYLLABLE NRYT
A3A6 YI SYLLABLE NRYX
A3A7 YI SYLLABLE NRY
A3A8 YI SYLLABLE NRYP
A3A9 YI SYLLABLE NRYRX
A3AA YI SYLLABLE NRYR
A3AB YI SYLLABLE SHAT
A3AC YI SYLLABLE SHAX
A3AD YI SYLLABLE SHA
A3AE YI SYLLABLE SHAP
A3AF YI SYLLABLE SHUOX
A3B0 YI SYLLABLE SHUO
A3B1 YI SYLLABLE SHUOP
A3B2 YI SYLLABLE SHOT
A3B3 YI SYLLABLE SHOX
A3B4 YI SYLLABLE SHO
A3B5 YI SYLLABLE SHOP
A3B6 YI SYLLABLE SHET
A3B7 YI SYLLABLE SHEX
A3B8 YI SYLLABLE SHE
A3B9 YI SYLLABLE SHEP
A3BA YI SYLLABLE SHUT
A3BB YI SYLLABLE SHUX
A3BC YI SYLLABLE SHU
A3BD YI SYLLABLE SHUP
A3BE YI SYLLABLE SHURX
A3BF YI SYLLABLE SHUR
A3C0 YI SYLLABLE SHYT
A3C1 YI SYLLABLE SHYX
A3C2 YI SYLLABLE SHY
A3C3 YI SYLLABLE SHYP
A3C4 YI SYLLABLE SHYRX
A3C5 YI SYLLABLE SHYR
A3C6 YI SYLLABLE RAT
A3C7 YI SYLLABLE RAX
A3C8 YI SYLLABLE RA
A3C9 YI SYLLABLE RAP
A3CA YI SYLLABLE RUOX
A3CB YI SYLLABLE RUO
A3CC YI SYLLABLE RUOP
A3CD YI SYLLABLE ROT
A3CE YI SYLLABLE ROX
A3CF YI SYLLABLE RO
A3D0 YI SYLLABLE ROP
A3D1 YI SYLLABLE REX
A3D2 YI SYLLABLE RE
A3D3 YI SYLLABLE REP
A3D4 YI SYLLABLE RUT
A3D5 YI SYLLABLE RUX
A3D6 YI SYLLABLE RU
A3D7 YI SYLLABLE RUP
A3D8 YI SYLLABLE RURX
A3D9 YI SYLLABLE RUR
A3DA YI SYLLABLE RYT
A3DB YI SYLLABLE RYX
A3DC YI SYLLABLE RY
A3DD YI SYLLABLE RYP
A3DE YI SYLLABLE RYRX
A3DF YI SYLLABLE RYR
A3E0 YI SYLLABLE JIT
A3E1 YI SYLLABLE JIX
A3E2 YI SYLLABLE JI
A3E3 YI SYLLABLE JIP
A3E4 YI SYLLABLE JIET
A3E5 YI SYLLABLE JIEX
A3E6 YI SYLLABLE JIE
A3E7 YI SYLLABLE JIEP
A3E8 YI SYLLABLE JUOT
A3E9 YI SYLLABLE JUOX
A3EA YI SYLLABLE JUO
A3EB YI SYLLABLE JUOP
A3EC YI SYLLABLE JOT
A3ED YI SYLLABLE JOX
A3EE YI SYLLABLE JO
A3EF YI SYLLABLE JOP
A3F0 YI SYLLABLE JUT
A3F1 YI SYLLABLE JUX
A3F2 YI SYLLABLE JU
A3F3 YI SYLLABLE JUP
A3F4 YI SYLLABLE JURX
A3F5 YI SYLLABLE JUR
A3F6 YI SYLLABLE JYT
A3F7 YI SYLLABLE JYX
A3F8 YI SYLLABLE JY
A3F9 YI SYLLABLE JYP
A3FA YI SYLLABLE JYRX
A3FB YI SYLLABLE JYR
A3FC YI SYLLABLE QIT
A3FD YI SYLLABLE QIX
A3FE YI SYLLABLE QI
A3FF YI SYLLABLE QIP
A400 YI SYLLABLE QIET
A401 YI SYLLABLE QIEX
A402 YI SYLLABLE QIE
A403 YI SYLLABLE QIEP
A404 YI SYLLABLE QUOT
A405 YI SYLLABLE QUOX
A406 YI SYLLABLE QUO
A407 YI SYLLABLE QUOP
A408 YI SYLLABLE QOT
A409 YI SYLLABLE QOX
A40A YI SYLLABLE QO
A40B YI SYLLABLE QOP
A40C YI SYLLABLE QUT
A40D YI SYLLABLE QUX
A40E YI SYLLABLE QU
A40F YI SYLLABLE QUP
A410 YI SYLLABLE QURX
A411 YI SYLLABLE QUR
A412 YI SYLLABLE QYT
A413 YI SYLLABLE QYX
A414 YI SYLLABLE QY
A415 YI SYLLABLE QYP
A416 YI SYLLABLE QYRX
A417 YI SYLLABLE QYR
A418 YI SYLLABLE JJIT
A419 YI SYLLABLE JJIX
A41A YI SYLLABLE JJI
A41B YI SYLLABLE JJIP
A41C YI SYLLABLE JJIET
A41D YI SYLLABLE JJIEX
A41E YI SYLLABLE JJIE
A41F YI SYLLABLE JJIEP
A420 YI SYLLABLE JJUOX
A421 YI SYLLABLE JJUO
A422 YI SYLLABLE JJUOP
A423 YI SYLLABLE JJOT
A424 YI SYLLABLE JJOX
A425 YI SYLLABLE JJO
A426 YI SYLLABLE JJOP
A427 YI SYLLABLE JJUT
A428 YI SYLLABLE JJUX
A429 YI SYLLABLE JJU
A42A YI SYLLABLE JJUP
A42B YI SYLLABLE JJURX
A42C YI SYLLABLE JJUR
A42D YI SYLLABLE JJYT
A42E YI SYLLABLE JJYX
A42F YI SYLLABLE JJY
A430 YI SYLLABLE JJYP
A431 YI SYLLABLE NJIT
A432 YI SYLLABLE NJIX
A433 YI SYLLABLE NJI
A434 YI SYLLABLE NJIP
A435 YI SYLLABLE NJIET
A436 YI SYLLABLE NJIEX
A437 YI SYLLABLE NJIE
A438 YI SYLLABLE NJIEP
A439 YI SYLLABLE NJUOX
A43A YI SYLLABLE NJUO
A43B YI SYLLABLE NJOT
A43C YI SYLLABLE NJOX
A43D YI SYLLABLE NJO
A43E YI SYLLABLE NJOP
A43F YI SYLLABLE NJUX
A440 YI SYLLABLE NJU
A441 YI SYLLABLE NJUP
A442 YI SYLLABLE NJURX
A443 YI SYLLABLE NJUR
A444 YI SYLLABLE NJYT
A445 YI SYLLABLE NJYX
A446 YI SYLLABLE NJY
A447 YI SYLLABLE NJYP
A448 YI SYLLABLE NJYRX
A449 YI SYLLABLE NJYR
A44A YI SYLLABLE NYIT
A44B YI SYLLABLE NYIX
A44C YI SYLLABLE NYI
A44D YI SYLLABLE NYIP
A44E YI SYLLABLE NYIET
A44F YI SYLLABLE NYIEX
A450 YI SYLLABLE NYIE
A451 YI SYLLABLE NYIEP
A452 YI SYLLABLE NYUOX
A453 YI SYLLABLE NYUO
A454 YI SYLLABLE NYUOP
A455 YI SYLLABLE NYOT
A456 YI SYLLABLE NYOX
A457 YI SYLLABLE NYO
A458 YI SYLLABLE NYOP
A459 YI SYLLABLE NYUT
A45A YI SYLLABLE NYUX
A45B YI SYLLABLE NYU
A45C YI SYLLABLE NYUP
A45D YI SYLLABLE XIT
A45E YI SYLLABLE XIX
A45F YI SYLLABLE XI
A460 YI SYLLABLE XIP
A461 YI SYLLABLE XIET
A462 YI SYLLABLE XIEX
A463 YI SYLLABLE XIE
A464 YI SYLLABLE XIEP
A465 YI SYLLABLE XUOX
A466 YI SYLLABLE XUO
A467 YI SYLLABLE XOT
A468 YI SYLLABLE XOX
A469 YI SYLLABLE XO
A46A YI SYLLABLE XOP
A46B YI SYLLABLE XYT
A46C YI SYLLABLE XYX
A46D YI SYLLABLE XY
A46E YI SYLLABLE XYP
A46F YI SYLLABLE XYRX
A470 YI SYLLABLE XYR
A471 YI SYLLABLE YIT
A472 YI SYLLABLE YIX
A473 YI SYLLABLE YI
A474 YI SYLLABLE YIP
A475 YI SYLLABLE YIET
A476 YI SYLLABLE YIEX
A477 YI SYLLABLE YIE
A478 YI SYLLABLE YIEP
A479 YI SYLLABLE YUOT
A47A YI SYLLABLE YUOX
A47B YI SYLLABLE YUO
A47C YI SYLLABLE YUOP
A47D YI SYLLABLE YOT
A47E YI SYLLABLE YOX
A47F YI SYLLABLE YO
A480 YI SYLLABLE YOP
A481 YI SYLLABLE YUT
A482 YI SYLLABLE YUX
A483 YI SYLLABLE YU
A484 YI SYLLABLE YUP
A485 YI SYLLABLE YURX
A486 YI SYLLABLE YUR
A487 YI SYLLABLE YYT
A488 YI SYLLABLE YYX
A489 YI SYLLABLE YY
A48A YI SYLLABLE YYP
A48B YI SYLLABLE YYRX
A48C YI SYLLABLE YYR
A490 YI RADICAL QOT
A491 YI RADICAL LI
A492 YI RADICAL KIT
A493 YI RADICAL NYIP
A494 YI RADICAL CYP
A495 YI RADICAL SSI
A496 YI RADICAL GGOP
A497 YI RADICAL GEP
A498 YI RADICAL MI
A499 YI RADICAL HXIT
A49A YI RADICAL LYR
A49B YI RADICAL BBUT
A49C YI RADICAL MOP
A49D YI RADICAL YO
A49E YI RADICAL PUT
A49F YI RADICAL HXUO
A4A0 YI RADICAL TAT
A4A1 YI RADICAL GA
A4A2 YI RADICAL ZUP
A4A3 YI RADICAL CYT
A4A4 YI RADICAL DDUR
A4A5 YI RADICAL BUR
A4A6 YI RADICAL GGUO
A4A7 YI RADICAL NYOP
A4A8 YI RADICAL TU
A4A9 YI RADICAL OP
A4AA YI RADICAL JJUT
A4AB YI RADICAL ZOT
A4AC YI RADICAL PYT
A4AD YI RADICAL HMO
A4AE YI RADICAL YIT
A4AF YI RADICAL VUR
A4B0 YI RADICAL SHY
A4B1 YI RADICAL VEP
A4B2 YI RADICAL ZA
A4B3 YI RADICAL JO
A4B4 YI RADICAL NZUP
A4B5 YI RADICAL JJY
A4B6 YI RADICAL GOT
A4B7 YI RADICAL JJIE
A4B8 YI RADICAL WO
A4B9 YI RADICAL DU
A4BA YI RADICAL SHUR
A4BB YI RADICAL LIE
A4BC YI RADICAL CY
A4BD YI RADICAL CUOP
A4BE YI RADICAL CIP
A4BF YI RADICAL HXOP
A4C0 YI RADICAL SHAT
A4C1 YI RADICAL ZUR
A4C2 YI RADICAL SHOP
A4C3 YI RADICAL CHE
A4C4 YI RADICAL ZZIET
A4C5 YI RADICAL NBIE
A4C6 YI RADICAL KE
A700 MODIFIER LETTER CHINESE TONE YIN PING
A701 MODIFIER LETTER CHINESE TONE YANG PING
A702 MODIFIER LETTER CHINESE TONE YIN SHANG
A703 MODIFIER LETTER CHINESE TONE YANG SHANG
A704 MODIFIER LETTER CHINESE TONE YIN QU
A705 MODIFIER LETTER CHINESE TONE YANG QU
A706 MODIFIER LETTER CHINESE TONE YIN RU
A707 MODIFIER LETTER CHINESE TONE YANG RU
A708 MODIFIER LETTER EXTRA-HIGH DOTTED TONE BAR
A709 MODIFIER LETTER HIGH DOTTED TONE BAR
A70A MODIFIER LETTER MID DOTTED TONE BAR
A70B MODIFIER LETTER LOW DOTTED TONE BAR
A70C MODIFIER LETTER EXTRA-LOW DOTTED TONE BAR
A70D MODIFIER LETTER EXTRA-HIGH DOTTED LEFT-STEM TONE BAR
A70E MODIFIER LETTER HIGH DOTTED LEFT-STEM TONE BAR
A70F MODIFIER LETTER MID DOTTED LEFT-STEM TONE BAR
A710 MODIFIER LETTER LOW DOTTED LEFT-STEM TONE BAR
A711 MODIFIER LETTER EXTRA-LOW DOTTED LEFT-STEM TONE BAR
A712 MODIFIER LETTER EXTRA-HIGH LEFT-STEM TONE BAR
A713 MODIFIER LETTER HIGH LEFT-STEM TONE BAR
A714 MODIFIER LETTER MID LEFT-STEM TONE BAR
A715 MODIFIER LETTER LOW LEFT-STEM TONE BAR
A716 MODIFIER LETTER EXTRA-LOW LEFT-STEM TONE BAR
A800 SYLOTI NAGRI LETTER A
A801 SYLOTI NAGRI LETTER I
A802 SYLOTI NAGRI SIGN DVISVARA
A803 SYLOTI NAGRI LETTER U
A804 SYLOTI NAGRI LETTER E
A805 SYLOTI NAGRI LETTER O
A806 SYLOTI NAGRI SIGN HASANTA
A807 SYLOTI NAGRI LETTER KO
A808 SYLOTI NAGRI LETTER KHO
A809 SYLOTI NAGRI LETTER GO
A80A SYLOTI NAGRI LETTER GHO
A80B SYLOTI NAGRI SIGN ANUSVARA
A80C SYLOTI NAGRI LETTER CO
A80D SYLOTI NAGRI LETTER CHO
A80E SYLOTI NAGRI LETTER JO
A80F SYLOTI NAGRI LETTER JHO
A810 SYLOTI NAGRI LETTER TTO
A811 SYLOTI NAGRI LETTER TTHO
A812 SYLOTI NAGRI LETTER DDO
A813 SYLOTI NAGRI LETTER DDHO
A814 SYLOTI NAGRI LETTER TO
A815 SYLOTI NAGRI LETTER THO
A816 SYLOTI NAGRI LETTER DO
A817 SYLOTI NAGRI LETTER DHO
A818 SYLOTI NAGRI LETTER NO
A819 SYLOTI NAGRI LETTER PO
A81A SYLOTI NAGRI LETTER PHO
A81B SYLOTI NAGRI LETTER BO
A81C SYLOTI NAGRI LETTER BHO
A81D SYLOTI NAGRI LETTER MO
A81E SYLOTI NAGRI LETTER RO
A81F SYLOTI NAGRI LETTER LO
A820 SYLOTI NAGRI LETTER RRO
A821 SYLOTI NAGRI LETTER SO
A822 SYLOTI NAGRI LETTER HO
A823 SYLOTI NAGRI VOWEL SIGN A
A824 SYLOTI NAGRI VOWEL SIGN I
A825 SYLOTI NAGRI VOWEL SIGN U
A826 SYLOTI NAGRI VOWEL SIGN E
A827 SYLOTI NAGRI VOWEL SIGN OO
A828 SYLOTI NAGRI POETRY MARK-1
A829 SYLOTI NAGRI POETRY MARK-2
A82A SYLOTI NAGRI POETRY MARK-3
A82B SYLOTI NAGRI POETRY MARK-4
AC00 <Hangul Syllable, First>
D7A3 <Hangul Syllable, Last>
D800 <Non Private Use High Surrogate, First>
DB7F <Non Private Use High Surrogate, Last>
DB80 <Private Use High Surrogate, First>
DBFF <Private Use High Surrogate, Last>
DC00 <Low Surrogate, First>
DFFF <Low Surrogate, Last>
E000 <Private Use, First>
F8FF <Private Use, Last>
F900 CJK COMPATIBILITY IDEOGRAPH-F900
F901 CJK COMPATIBILITY IDEOGRAPH-F901
F902 CJK COMPATIBILITY IDEOGRAPH-F902
F903 CJK COMPATIBILITY IDEOGRAPH-F903
F904 CJK COMPATIBILITY IDEOGRAPH-F904
F905 CJK COMPATIBILITY IDEOGRAPH-F905
F906 CJK COMPATIBILITY IDEOGRAPH-F906
F907 CJK COMPATIBILITY IDEOGRAPH-F907
F908 CJK COMPATIBILITY IDEOGRAPH-F908
F909 CJK COMPATIBILITY IDEOGRAPH-F909
F90A CJK COMPATIBILITY IDEOGRAPH-F90A
F90B CJK COMPATIBILITY IDEOGRAPH-F90B
F90C CJK COMPATIBILITY IDEOGRAPH-F90C
F90D CJK COMPATIBILITY IDEOGRAPH-F90D
F90E CJK COMPATIBILITY IDEOGRAPH-F90E
F90F CJK COMPATIBILITY IDEOGRAPH-F90F
F910 CJK COMPATIBILITY IDEOGRAPH-F910
F911 CJK COMPATIBILITY IDEOGRAPH-F911
F912 CJK COMPATIBILITY IDEOGRAPH-F912
F913 CJK COMPATIBILITY IDEOGRAPH-F913
F914 CJK COMPATIBILITY IDEOGRAPH-F914
F915 CJK COMPATIBILITY IDEOGRAPH-F915
F916 CJK COMPATIBILITY IDEOGRAPH-F916
F917 CJK COMPATIBILITY IDEOGRAPH-F917
F918 CJK COMPATIBILITY IDEOGRAPH-F918
F919 CJK COMPATIBILITY IDEOGRAPH-F919
F91A CJK COMPATIBILITY IDEOGRAPH-F91A
F91B CJK COMPATIBILITY IDEOGRAPH-F91B
F91C CJK COMPATIBILITY IDEOGRAPH-F91C
F91D CJK COMPATIBILITY IDEOGRAPH-F91D
F91E CJK COMPATIBILITY IDEOGRAPH-F91E
F91F CJK COMPATIBILITY IDEOGRAPH-F91F
F920 CJK COMPATIBILITY IDEOGRAPH-F920
F921 CJK COMPATIBILITY IDEOGRAPH-F921
F922 CJK COMPATIBILITY IDEOGRAPH-F922
F923 CJK COMPATIBILITY IDEOGRAPH-F923
F924 CJK COMPATIBILITY IDEOGRAPH-F924
F925 CJK COMPATIBILITY IDEOGRAPH-F925
F926 CJK COMPATIBILITY IDEOGRAPH-F926
F927 CJK COMPATIBILITY IDEOGRAPH-F927
F928 CJK COMPATIBILITY IDEOGRAPH-F928
F929 CJK COMPATIBILITY IDEOGRAPH-F929
F92A CJK COMPATIBILITY IDEOGRAPH-F92A
F92B CJK COMPATIBILITY IDEOGRAPH-F92B
F92C CJK COMPATIBILITY IDEOGRAPH-F92C
F92D CJK COMPATIBILITY IDEOGRAPH-F92D
F92E CJK COMPATIBILITY IDEOGRAPH-F92E
F92F CJK COMPATIBILITY IDEOGRAPH-F92F
F930 CJK COMPATIBILITY IDEOGRAPH-F930
F931 CJK COMPATIBILITY IDEOGRAPH-F931
F932 CJK COMPATIBILITY IDEOGRAPH-F932
F933 CJK COMPATIBILITY IDEOGRAPH-F933
F934 CJK COMPATIBILITY IDEOGRAPH-F934
F935 CJK COMPATIBILITY IDEOGRAPH-F935
F936 CJK COMPATIBILITY IDEOGRAPH-F936
F937 CJK COMPATIBILITY IDEOGRAPH-F937
F938 CJK COMPATIBILITY IDEOGRAPH-F938
F939 CJK COMPATIBILITY IDEOGRAPH-F939
F93A CJK COMPATIBILITY IDEOGRAPH-F93A
F93B CJK COMPATIBILITY IDEOGRAPH-F93B
F93C CJK COMPATIBILITY IDEOGRAPH-F93C
F93D CJK COMPATIBILITY IDEOGRAPH-F93D
F93E CJK COMPATIBILITY IDEOGRAPH-F93E
F93F CJK COMPATIBILITY IDEOGRAPH-F93F
F940 CJK COMPATIBILITY IDEOGRAPH-F940
F941 CJK COMPATIBILITY IDEOGRAPH-F941
F942 CJK COMPATIBILITY IDEOGRAPH-F942
F943 CJK COMPATIBILITY IDEOGRAPH-F943
F944 CJK COMPATIBILITY IDEOGRAPH-F944
F945 CJK COMPATIBILITY IDEOGRAPH-F945
F946 CJK COMPATIBILITY IDEOGRAPH-F946
F947 CJK COMPATIBILITY IDEOGRAPH-F947
F948 CJK COMPATIBILITY IDEOGRAPH-F948
F949 CJK COMPATIBILITY IDEOGRAPH-F949
F94A CJK COMPATIBILITY IDEOGRAPH-F94A
F94B CJK COMPATIBILITY IDEOGRAPH-F94B
F94C CJK COMPATIBILITY IDEOGRAPH-F94C
F94D CJK COMPATIBILITY IDEOGRAPH-F94D
F94E CJK COMPATIBILITY IDEOGRAPH-F94E
F94F CJK COMPATIBILITY IDEOGRAPH-F94F
F950 CJK COMPATIBILITY IDEOGRAPH-F950
F951 CJK COMPATIBILITY IDEOGRAPH-F951
F952 CJK COMPATIBILITY IDEOGRAPH-F952
F953 CJK COMPATIBILITY IDEOGRAPH-F953
F954 CJK COMPATIBILITY IDEOGRAPH-F954
F955 CJK COMPATIBILITY IDEOGRAPH-F955
F956 CJK COMPATIBILITY IDEOGRAPH-F956
F957 CJK COMPATIBILITY IDEOGRAPH-F957
F958 CJK COMPATIBILITY IDEOGRAPH-F958
F959 CJK COMPATIBILITY IDEOGRAPH-F959
F95A CJK COMPATIBILITY IDEOGRAPH-F95A
F95B CJK COMPATIBILITY IDEOGRAPH-F95B
F95C CJK COMPATIBILITY IDEOGRAPH-F95C
F95D CJK COMPATIBILITY IDEOGRAPH-F95D
F95E CJK COMPATIBILITY IDEOGRAPH-F95E
F95F CJK COMPATIBILITY IDEOGRAPH-F95F
F960 CJK COMPATIBILITY IDEOGRAPH-F960
F961 CJK COMPATIBILITY IDEOGRAPH-F961
F962 CJK COMPATIBILITY IDEOGRAPH-F962
F963 CJK COMPATIBILITY IDEOGRAPH-F963
F964 CJK COMPATIBILITY IDEOGRAPH-F964
F965 CJK COMPATIBILITY IDEOGRAPH-F965
F966 CJK COMPATIBILITY IDEOGRAPH-F966
F967 CJK COMPATIBILITY IDEOGRAPH-F967
F968 CJK COMPATIBILITY IDEOGRAPH-F968
F969 CJK COMPATIBILITY IDEOGRAPH-F969
F96A CJK COMPATIBILITY IDEOGRAPH-F96A
F96B CJK COMPATIBILITY IDEOGRAPH-F96B
F96C CJK COMPATIBILITY IDEOGRAPH-F96C
F96D CJK COMPATIBILITY IDEOGRAPH-F96D
F96E CJK COMPATIBILITY IDEOGRAPH-F96E
F96F CJK COMPATIBILITY IDEOGRAPH-F96F
F970 CJK COMPATIBILITY IDEOGRAPH-F970
F971 CJK COMPATIBILITY IDEOGRAPH-F971
F972 CJK COMPATIBILITY IDEOGRAPH-F972
F973 CJK COMPATIBILITY IDEOGRAPH-F973
F974 CJK COMPATIBILITY IDEOGRAPH-F974
F975 CJK COMPATIBILITY IDEOGRAPH-F975
F976 CJK COMPATIBILITY IDEOGRAPH-F976
F977 CJK COMPATIBILITY IDEOGRAPH-F977
F978 CJK COMPATIBILITY IDEOGRAPH-F978
F979 CJK COMPATIBILITY IDEOGRAPH-F979
F97A CJK COMPATIBILITY IDEOGRAPH-F97A
F97B CJK COMPATIBILITY IDEOGRAPH-F97B
F97C CJK COMPATIBILITY IDEOGRAPH-F97C
F97D CJK COMPATIBILITY IDEOGRAPH-F97D
F97E CJK COMPATIBILITY IDEOGRAPH-F97E
F97F CJK COMPATIBILITY IDEOGRAPH-F97F
F980 CJK COMPATIBILITY IDEOGRAPH-F980
F981 CJK COMPATIBILITY IDEOGRAPH-F981
F982 CJK COMPATIBILITY IDEOGRAPH-F982
F983 CJK COMPATIBILITY IDEOGRAPH-F983
F984 CJK COMPATIBILITY IDEOGRAPH-F984
F985 CJK COMPATIBILITY IDEOGRAPH-F985
F986 CJK COMPATIBILITY IDEOGRAPH-F986
F987 CJK COMPATIBILITY IDEOGRAPH-F987
F988 CJK COMPATIBILITY IDEOGRAPH-F988
F989 CJK COMPATIBILITY IDEOGRAPH-F989
F98A CJK COMPATIBILITY IDEOGRAPH-F98A
F98B CJK COMPATIBILITY IDEOGRAPH-F98B
F98C CJK COMPATIBILITY IDEOGRAPH-F98C
F98D CJK COMPATIBILITY IDEOGRAPH-F98D
F98E CJK COMPATIBILITY IDEOGRAPH-F98E
F98F CJK COMPATIBILITY IDEOGRAPH-F98F
F990 CJK COMPATIBILITY IDEOGRAPH-F990
F991 CJK COMPATIBILITY IDEOGRAPH-F991
F992 CJK COMPATIBILITY IDEOGRAPH-F992
F993 CJK COMPATIBILITY IDEOGRAPH-F993
F994 CJK COMPATIBILITY IDEOGRAPH-F994
F995 CJK COMPATIBILITY IDEOGRAPH-F995
F996 CJK COMPATIBILITY IDEOGRAPH-F996
F997 CJK COMPATIBILITY IDEOGRAPH-F997
F998 CJK COMPATIBILITY IDEOGRAPH-F998
F999 CJK COMPATIBILITY IDEOGRAPH-F999
F99A CJK COMPATIBILITY IDEOGRAPH-F99A
F99B CJK COMPATIBILITY IDEOGRAPH-F99B
F99C CJK COMPATIBILITY IDEOGRAPH-F99C
F99D CJK COMPATIBILITY IDEOGRAPH-F99D
F99E CJK COMPATIBILITY IDEOGRAPH-F99E
F99F CJK COMPATIBILITY IDEOGRAPH-F99F
F9A0 CJK COMPATIBILITY IDEOGRAPH-F9A0
F9A1 CJK COMPATIBILITY IDEOGRAPH-F9A1
F9A2 CJK COMPATIBILITY IDEOGRAPH-F9A2
F9A3 CJK COMPATIBILITY IDEOGRAPH-F9A3
F9A4 CJK COMPATIBILITY IDEOGRAPH-F9A4
F9A5 CJK COMPATIBILITY IDEOGRAPH-F9A5
F9A6 CJK COMPATIBILITY IDEOGRAPH-F9A6
F9A7 CJK COMPATIBILITY IDEOGRAPH-F9A7
F9A8 CJK COMPATIBILITY IDEOGRAPH-F9A8
F9A9 CJK COMPATIBILITY IDEOGRAPH-F9A9
F9AA CJK COMPATIBILITY IDEOGRAPH-F9AA
F9AB CJK COMPATIBILITY IDEOGRAPH-F9AB
F9AC CJK COMPATIBILITY IDEOGRAPH-F9AC
F9AD CJK COMPATIBILITY IDEOGRAPH-F9AD
F9AE CJK COMPATIBILITY IDEOGRAPH-F9AE
F9AF CJK COMPATIBILITY IDEOGRAPH-F9AF
F9B0 CJK COMPATIBILITY IDEOGRAPH-F9B0
F9B1 CJK COMPATIBILITY IDEOGRAPH-F9B1
F9B2 CJK COMPATIBILITY IDEOGRAPH-F9B2
F9B3 CJK COMPATIBILITY IDEOGRAPH-F9B3
F9B4 CJK COMPATIBILITY IDEOGRAPH-F9B4
F9B5 CJK COMPATIBILITY IDEOGRAPH-F9B5
F9B6 CJK COMPATIBILITY IDEOGRAPH-F9B6
F9B7 CJK COMPATIBILITY IDEOGRAPH-F9B7
F9B8 CJK COMPATIBILITY IDEOGRAPH-F9B8
F9B9 CJK COMPATIBILITY IDEOGRAPH-F9B9
F9BA CJK COMPATIBILITY IDEOGRAPH-F9BA
F9BB CJK COMPATIBILITY IDEOGRAPH-F9BB
F9BC CJK COMPATIBILITY IDEOGRAPH-F9BC
F9BD CJK COMPATIBILITY IDEOGRAPH-F9BD
F9BE CJK COMPATIBILITY IDEOGRAPH-F9BE
F9BF CJK COMPATIBILITY IDEOGRAPH-F9BF
F9C0 CJK COMPATIBILITY IDEOGRAPH-F9C0
F9C1 CJK COMPATIBILITY IDEOGRAPH-F9C1
F9C2 CJK COMPATIBILITY IDEOGRAPH-F9C2
F9C3 CJK COMPATIBILITY IDEOGRAPH-F9C3
F9C4 CJK COMPATIBILITY IDEOGRAPH-F9C4
F9C5 CJK COMPATIBILITY IDEOGRAPH-F9C5
F9C6 CJK COMPATIBILITY IDEOGRAPH-F9C6
F9C7 CJK COMPATIBILITY IDEOGRAPH-F9C7
F9C8 CJK COMPATIBILITY IDEOGRAPH-F9C8
F9C9 CJK COMPATIBILITY IDEOGRAPH-F9C9
F9CA CJK COMPATIBILITY IDEOGRAPH-F9CA
F9CB CJK COMPATIBILITY IDEOGRAPH-F9CB
F9CC CJK COMPATIBILITY IDEOGRAPH-F9CC
F9CD CJK COMPATIBILITY IDEOGRAPH-F9CD
F9CE CJK COMPATIBILITY IDEOGRAPH-F9CE
F9CF CJK COMPATIBILITY IDEOGRAPH-F9CF
F9D0 CJK COMPATIBILITY IDEOGRAPH-F9D0
F9D1 CJK COMPATIBILITY IDEOGRAPH-F9D1
F9D2 CJK COMPATIBILITY IDEOGRAPH-F9D2
F9D3 CJK COMPATIBILITY IDEOGRAPH-F9D3
F9D4 CJK COMPATIBILITY IDEOGRAPH-F9D4
F9D5 CJK COMPATIBILITY IDEOGRAPH-F9D5
F9D6 CJK COMPATIBILITY IDEOGRAPH-F9D6
F9D7 CJK COMPATIBILITY IDEOGRAPH-F9D7
F9D8 CJK COMPATIBILITY IDEOGRAPH-F9D8
F9D9 CJK COMPATIBILITY IDEOGRAPH-F9D9
F9DA CJK COMPATIBILITY IDEOGRAPH-F9DA
F9DB CJK COMPATIBILITY IDEOGRAPH-F9DB
F9DC CJK COMPATIBILITY IDEOGRAPH-F9DC
F9DD CJK COMPATIBILITY IDEOGRAPH-F9DD
F9DE CJK COMPATIBILITY IDEOGRAPH-F9DE
F9DF CJK COMPATIBILITY IDEOGRAPH-F9DF
F9E0 CJK COMPATIBILITY IDEOGRAPH-F9E0
F9E1 CJK COMPATIBILITY IDEOGRAPH-F9E1
F9E2 CJK COMPATIBILITY IDEOGRAPH-F9E2
F9E3 CJK COMPATIBILITY IDEOGRAPH-F9E3
F9E4 CJK COMPATIBILITY IDEOGRAPH-F9E4
F9E5 CJK COMPATIBILITY IDEOGRAPH-F9E5
F9E6 CJK COMPATIBILITY IDEOGRAPH-F9E6
F9E7 CJK COMPATIBILITY IDEOGRAPH-F9E7
F9E8 CJK COMPATIBILITY IDEOGRAPH-F9E8
F9E9 CJK COMPATIBILITY IDEOGRAPH-F9E9
F9EA CJK COMPATIBILITY IDEOGRAPH-F9EA
F9EB CJK COMPATIBILITY IDEOGRAPH-F9EB
F9EC CJK COMPATIBILITY IDEOGRAPH-F9EC
F9ED CJK COMPATIBILITY IDEOGRAPH-F9ED
F9EE CJK COMPATIBILITY IDEOGRAPH-F9EE
F9EF CJK COMPATIBILITY IDEOGRAPH-F9EF
F9F0 CJK COMPATIBILITY IDEOGRAPH-F9F0
F9F1 CJK COMPATIBILITY IDEOGRAPH-F9F1
F9F2 CJK COMPATIBILITY IDEOGRAPH-F9F2
F9F3 CJK COMPATIBILITY IDEOGRAPH-F9F3
F9F4 CJK COMPATIBILITY IDEOGRAPH-F9F4
F9F5 CJK COMPATIBILITY IDEOGRAPH-F9F5
F9F6 CJK COMPATIBILITY IDEOGRAPH-F9F6
F9F7 CJK COMPATIBILITY IDEOGRAPH-F9F7
F9F8 CJK COMPATIBILITY IDEOGRAPH-F9F8
F9F9 CJK COMPATIBILITY IDEOGRAPH-F9F9
F9FA CJK COMPATIBILITY IDEOGRAPH-F9FA
F9FB CJK COMPATIBILITY IDEOGRAPH-F9FB
F9FC CJK COMPATIBILITY IDEOGRAPH-F9FC
F9FD CJK COMPATIBILITY IDEOGRAPH-F9FD
F9FE CJK COMPATIBILITY IDEOGRAPH-F9FE
F9FF CJK COMPATIBILITY IDEOGRAPH-F9FF
FA00 CJK COMPATIBILITY IDEOGRAPH-FA00
FA01 CJK COMPATIBILITY IDEOGRAPH-FA01
FA02 CJK COMPATIBILITY IDEOGRAPH-FA02
FA03 CJK COMPATIBILITY IDEOGRAPH-FA03
FA04 CJK COMPATIBILITY IDEOGRAPH-FA04
FA05 CJK COMPATIBILITY IDEOGRAPH-FA05
FA06 CJK COMPATIBILITY IDEOGRAPH-FA06
FA07 CJK COMPATIBILITY IDEOGRAPH-FA07
FA08 CJK COMPATIBILITY IDEOGRAPH-FA08
FA09 CJK COMPATIBILITY IDEOGRAPH-FA09
FA0A CJK COMPATIBILITY IDEOGRAPH-FA0A
FA0B CJK COMPATIBILITY IDEOGRAPH-FA0B
FA0C CJK COMPATIBILITY IDEOGRAPH-FA0C
FA0D CJK COMPATIBILITY IDEOGRAPH-FA0D
FA0E CJK COMPATIBILITY IDEOGRAPH-FA0E
FA0F CJK COMPATIBILITY IDEOGRAPH-FA0F
FA10 CJK COMPATIBILITY IDEOGRAPH-FA10
FA11 CJK COMPATIBILITY IDEOGRAPH-FA11
FA12 CJK COMPATIBILITY IDEOGRAPH-FA12
FA13 CJK COMPATIBILITY IDEOGRAPH-FA13
FA14 CJK COMPATIBILITY IDEOGRAPH-FA14
FA15 CJK COMPATIBILITY IDEOGRAPH-FA15
FA16 CJK COMPATIBILITY IDEOGRAPH-FA16
FA17 CJK COMPATIBILITY IDEOGRAPH-FA17
FA18 CJK COMPATIBILITY IDEOGRAPH-FA18
FA19 CJK COMPATIBILITY IDEOGRAPH-FA19
FA1A CJK COMPATIBILITY IDEOGRAPH-FA1A
FA1B CJK COMPATIBILITY IDEOGRAPH-FA1B
FA1C CJK COMPATIBILITY IDEOGRAPH-FA1C
FA1D CJK COMPATIBILITY IDEOGRAPH-FA1D
FA1E CJK COMPATIBILITY IDEOGRAPH-FA1E
FA1F CJK COMPATIBILITY IDEOGRAPH-FA1F
FA20 CJK COMPATIBILITY IDEOGRAPH-FA20
FA21 CJK COMPATIBILITY IDEOGRAPH-FA21
FA22 CJK COMPATIBILITY IDEOGRAPH-FA22
FA23 CJK COMPATIBILITY IDEOGRAPH-FA23
FA24 CJK COMPATIBILITY IDEOGRAPH-FA24
FA25 CJK COMPATIBILITY IDEOGRAPH-FA25
FA26 CJK COMPATIBILITY IDEOGRAPH-FA26
FA27 CJK COMPATIBILITY IDEOGRAPH-FA27
FA28 CJK COMPATIBILITY IDEOGRAPH-FA28
FA29 CJK COMPATIBILITY IDEOGRAPH-FA29
FA2A CJK COMPATIBILITY IDEOGRAPH-FA2A
FA2B CJK COMPATIBILITY IDEOGRAPH-FA2B
FA2C CJK COMPATIBILITY IDEOGRAPH-FA2C
FA2D CJK COMPATIBILITY IDEOGRAPH-FA2D
FA30 CJK COMPATIBILITY IDEOGRAPH-FA30
FA31 CJK COMPATIBILITY IDEOGRAPH-FA31
FA32 CJK COMPATIBILITY IDEOGRAPH-FA32
FA33 CJK COMPATIBILITY IDEOGRAPH-FA33
FA34 CJK COMPATIBILITY IDEOGRAPH-FA34
FA35 CJK COMPATIBILITY IDEOGRAPH-FA35
FA36 CJK COMPATIBILITY IDEOGRAPH-FA36
FA37 CJK COMPATIBILITY IDEOGRAPH-FA37
FA38 CJK COMPATIBILITY IDEOGRAPH-FA38
FA39 CJK COMPATIBILITY IDEOGRAPH-FA39
FA3A CJK COMPATIBILITY IDEOGRAPH-FA3A
FA3B CJK COMPATIBILITY IDEOGRAPH-FA3B
FA3C CJK COMPATIBILITY IDEOGRAPH-FA3C
FA3D CJK COMPATIBILITY IDEOGRAPH-FA3D
FA3E CJK COMPATIBILITY IDEOGRAPH-FA3E
FA3F CJK COMPATIBILITY IDEOGRAPH-FA3F
FA40 CJK COMPATIBILITY IDEOGRAPH-FA40
FA41 CJK COMPATIBILITY IDEOGRAPH-FA41
FA42 CJK COMPATIBILITY IDEOGRAPH-FA42
FA43 CJK COMPATIBILITY IDEOGRAPH-FA43
FA44 CJK COMPATIBILITY IDEOGRAPH-FA44
FA45 CJK COMPATIBILITY IDEOGRAPH-FA45
FA46 CJK COMPATIBILITY IDEOGRAPH-FA46
FA47 CJK COMPATIBILITY IDEOGRAPH-FA47
FA48 CJK COMPATIBILITY IDEOGRAPH-FA48
FA49 CJK COMPATIBILITY IDEOGRAPH-FA49
FA4A CJK COMPATIBILITY IDEOGRAPH-FA4A
FA4B CJK COMPATIBILITY IDEOGRAPH-FA4B
FA4C CJK COMPATIBILITY IDEOGRAPH-FA4C
FA4D CJK COMPATIBILITY IDEOGRAPH-FA4D
FA4E CJK COMPATIBILITY IDEOGRAPH-FA4E
FA4F CJK COMPATIBILITY IDEOGRAPH-FA4F
FA50 CJK COMPATIBILITY IDEOGRAPH-FA50
FA51 CJK COMPATIBILITY IDEOGRAPH-FA51
FA52 CJK COMPATIBILITY IDEOGRAPH-FA52
FA53 CJK COMPATIBILITY IDEOGRAPH-FA53
FA54 CJK COMPATIBILITY IDEOGRAPH-FA54
FA55 CJK COMPATIBILITY IDEOGRAPH-FA55
FA56 CJK COMPATIBILITY IDEOGRAPH-FA56
FA57 CJK COMPATIBILITY IDEOGRAPH-FA57
FA58 CJK COMPATIBILITY IDEOGRAPH-FA58
FA59 CJK COMPATIBILITY IDEOGRAPH-FA59
FA5A CJK COMPATIBILITY IDEOGRAPH-FA5A
FA5B CJK COMPATIBILITY IDEOGRAPH-FA5B
FA5C CJK COMPATIBILITY IDEOGRAPH-FA5C
FA5D CJK COMPATIBILITY IDEOGRAPH-FA5D
FA5E CJK COMPATIBILITY IDEOGRAPH-FA5E
FA5F CJK COMPATIBILITY IDEOGRAPH-FA5F
FA60 CJK COMPATIBILITY IDEOGRAPH-FA60
FA61 CJK COMPATIBILITY IDEOGRAPH-FA61
FA62 CJK COMPATIBILITY IDEOGRAPH-FA62
FA63 CJK COMPATIBILITY IDEOGRAPH-FA63
FA64 CJK COMPATIBILITY IDEOGRAPH-FA64
FA65 CJK COMPATIBILITY IDEOGRAPH-FA65
FA66 CJK COMPATIBILITY IDEOGRAPH-FA66
FA67 CJK COMPATIBILITY IDEOGRAPH-FA67
FA68 CJK COMPATIBILITY IDEOGRAPH-FA68
FA69 CJK COMPATIBILITY IDEOGRAPH-FA69
FA6A CJK COMPATIBILITY IDEOGRAPH-FA6A
FA70 CJK COMPATIBILITY IDEOGRAPH-FA70
FA71 CJK COMPATIBILITY IDEOGRAPH-FA71
FA72 CJK COMPATIBILITY IDEOGRAPH-FA72
FA73 CJK COMPATIBILITY IDEOGRAPH-FA73
FA74 CJK COMPATIBILITY IDEOGRAPH-FA74
FA75 CJK COMPATIBILITY IDEOGRAPH-FA75
FA76 CJK COMPATIBILITY IDEOGRAPH-FA76
FA77 CJK COMPATIBILITY IDEOGRAPH-FA77
FA78 CJK COMPATIBILITY IDEOGRAPH-FA78
FA79 CJK COMPATIBILITY IDEOGRAPH-FA79
FA7A CJK COMPATIBILITY IDEOGRAPH-FA7A
FA7B CJK COMPATIBILITY IDEOGRAPH-FA7B
FA7C CJK COMPATIBILITY IDEOGRAPH-FA7C
FA7D CJK COMPATIBILITY IDEOGRAPH-FA7D
FA7E CJK COMPATIBILITY IDEOGRAPH-FA7E
FA7F CJK COMPATIBILITY IDEOGRAPH-FA7F
FA80 CJK COMPATIBILITY IDEOGRAPH-FA80
FA81 CJK COMPATIBILITY IDEOGRAPH-FA81
FA82 CJK COMPATIBILITY IDEOGRAPH-FA82
FA83 CJK COMPATIBILITY IDEOGRAPH-FA83
FA84 CJK COMPATIBILITY IDEOGRAPH-FA84
FA85 CJK COMPATIBILITY IDEOGRAPH-FA85
FA86 CJK COMPATIBILITY IDEOGRAPH-FA86
FA87 CJK COMPATIBILITY IDEOGRAPH-FA87
FA88 CJK COMPATIBILITY IDEOGRAPH-FA88
FA89 CJK COMPATIBILITY IDEOGRAPH-FA89
FA8A CJK COMPATIBILITY IDEOGRAPH-FA8A
FA8B CJK COMPATIBILITY IDEOGRAPH-FA8B
FA8C CJK COMPATIBILITY IDEOGRAPH-FA8C
FA8D CJK COMPATIBILITY IDEOGRAPH-FA8D
FA8E CJK COMPATIBILITY IDEOGRAPH-FA8E
FA8F CJK COMPATIBILITY IDEOGRAPH-FA8F
FA90 CJK COMPATIBILITY IDEOGRAPH-FA90
FA91 CJK COMPATIBILITY IDEOGRAPH-FA91
FA92 CJK COMPATIBILITY IDEOGRAPH-FA92
FA93 CJK COMPATIBILITY IDEOGRAPH-FA93
FA94 CJK COMPATIBILITY IDEOGRAPH-FA94
FA95 CJK COMPATIBILITY IDEOGRAPH-FA95
FA96 CJK COMPATIBILITY IDEOGRAPH-FA96
FA97 CJK COMPATIBILITY IDEOGRAPH-FA97
FA98 CJK COMPATIBILITY IDEOGRAPH-FA98
FA99 CJK COMPATIBILITY IDEOGRAPH-FA99
FA9A CJK COMPATIBILITY IDEOGRAPH-FA9A
FA9B CJK COMPATIBILITY IDEOGRAPH-FA9B
FA9C CJK COMPATIBILITY IDEOGRAPH-FA9C
FA9D CJK COMPATIBILITY IDEOGRAPH-FA9D
FA9E CJK COMPATIBILITY IDEOGRAPH-FA9E
FA9F CJK COMPATIBILITY IDEOGRAPH-FA9F
FAA0 CJK COMPATIBILITY IDEOGRAPH-FAA0
FAA1 CJK COMPATIBILITY IDEOGRAPH-FAA1
FAA2 CJK COMPATIBILITY IDEOGRAPH-FAA2
FAA3 CJK COMPATIBILITY IDEOGRAPH-FAA3
FAA4 CJK COMPATIBILITY IDEOGRAPH-FAA4
FAA5 CJK COMPATIBILITY IDEOGRAPH-FAA5
FAA6 CJK COMPATIBILITY IDEOGRAPH-FAA6
FAA7 CJK COMPATIBILITY IDEOGRAPH-FAA7
FAA8 CJK COMPATIBILITY IDEOGRAPH-FAA8
FAA9 CJK COMPATIBILITY IDEOGRAPH-FAA9
FAAA CJK COMPATIBILITY IDEOGRAPH-FAAA
FAAB CJK COMPATIBILITY IDEOGRAPH-FAAB
FAAC CJK COMPATIBILITY IDEOGRAPH-FAAC
FAAD CJK COMPATIBILITY IDEOGRAPH-FAAD
FAAE CJK COMPATIBILITY IDEOGRAPH-FAAE
FAAF CJK COMPATIBILITY IDEOGRAPH-FAAF
FAB0 CJK COMPATIBILITY IDEOGRAPH-FAB0
FAB1 CJK COMPATIBILITY IDEOGRAPH-FAB1
FAB2 CJK COMPATIBILITY IDEOGRAPH-FAB2
FAB3 CJK COMPATIBILITY IDEOGRAPH-FAB3
FAB4 CJK COMPATIBILITY IDEOGRAPH-FAB4
FAB5 CJK COMPATIBILITY IDEOGRAPH-FAB5
FAB6 CJK COMPATIBILITY IDEOGRAPH-FAB6
FAB7 CJK COMPATIBILITY IDEOGRAPH-FAB7
FAB8 CJK COMPATIBILITY IDEOGRAPH-FAB8
FAB9 CJK COMPATIBILITY IDEOGRAPH-FAB9
FABA CJK COMPATIBILITY IDEOGRAPH-FABA
FABB CJK COMPATIBILITY IDEOGRAPH-FABB
FABC CJK COMPATIBILITY IDEOGRAPH-FABC
FABD CJK COMPATIBILITY IDEOGRAPH-FABD
FABE CJK COMPATIBILITY IDEOGRAPH-FABE
FABF CJK COMPATIBILITY IDEOGRAPH-FABF
FAC0 CJK COMPATIBILITY IDEOGRAPH-FAC0
FAC1 CJK COMPATIBILITY IDEOGRAPH-FAC1
FAC2 CJK COMPATIBILITY IDEOGRAPH-FAC2
FAC3 CJK COMPATIBILITY IDEOGRAPH-FAC3
FAC4 CJK COMPATIBILITY IDEOGRAPH-FAC4
FAC5 CJK COMPATIBILITY IDEOGRAPH-FAC5
FAC6 CJK COMPATIBILITY IDEOGRAPH-FAC6
FAC7 CJK COMPATIBILITY IDEOGRAPH-FAC7
FAC8 CJK COMPATIBILITY IDEOGRAPH-FAC8
FAC9 CJK COMPATIBILITY IDEOGRAPH-FAC9
FACA CJK COMPATIBILITY IDEOGRAPH-FACA
FACB CJK COMPATIBILITY IDEOGRAPH-FACB
FACC CJK COMPATIBILITY IDEOGRAPH-FACC
FACD CJK COMPATIBILITY IDEOGRAPH-FACD
FACE CJK COMPATIBILITY IDEOGRAPH-FACE
FACF CJK COMPATIBILITY IDEOGRAPH-FACF
FAD0 CJK COMPATIBILITY IDEOGRAPH-FAD0
FAD1 CJK COMPATIBILITY IDEOGRAPH-FAD1
FAD2 CJK COMPATIBILITY IDEOGRAPH-FAD2
FAD3 CJK COMPATIBILITY IDEOGRAPH-FAD3
FAD4 CJK COMPATIBILITY IDEOGRAPH-FAD4
FAD5 CJK COMPATIBILITY IDEOGRAPH-FAD5
FAD6 CJK COMPATIBILITY IDEOGRAPH-FAD6
FAD7 CJK COMPATIBILITY IDEOGRAPH-FAD7
FAD8 CJK COMPATIBILITY IDEOGRAPH-FAD8
FAD9 CJK COMPATIBILITY IDEOGRAPH-FAD9
FB00 LATIN SMALL LIGATURE FF
FB01 LATIN SMALL LIGATURE FI
FB02 LATIN SMALL LIGATURE FL
FB03 LATIN SMALL LIGATURE FFI
FB04 LATIN SMALL LIGATURE FFL
FB05 LATIN SMALL LIGATURE LONG S T
FB06 LATIN SMALL LIGATURE ST
FB13 ARMENIAN SMALL LIGATURE MEN NOW
FB14 ARMENIAN SMALL LIGATURE MEN ECH
FB15 ARMENIAN SMALL LIGATURE MEN INI
FB16 ARMENIAN SMALL LIGATURE VEW NOW
FB17 ARMENIAN SMALL LIGATURE MEN XEH
FB1D HEBREW LETTER YOD WITH HIRIQ
FB1E HEBREW POINT JUDEO-SPANISH VARIKA
FB1F HEBREW LIGATURE YIDDISH YOD YOD PATAH
FB20 HEBREW LETTER ALTERNATIVE AYIN
FB21 HEBREW LETTER WIDE ALEF
FB22 HEBREW LETTER WIDE DALET
FB23 HEBREW LETTER WIDE HE
FB24 HEBREW LETTER WIDE KAF
FB25 HEBREW LETTER WIDE LAMED
FB26 HEBREW LETTER WIDE FINAL MEM
FB27 HEBREW LETTER WIDE RESH
FB28 HEBREW LETTER WIDE TAV
FB29 HEBREW LETTER ALTERNATIVE PLUS SIGN
FB2A HEBREW LETTER SHIN WITH SHIN DOT
FB2B HEBREW LETTER SHIN WITH SIN DOT
FB2C HEBREW LETTER SHIN WITH DAGESH AND SHIN DOT
FB2D HEBREW LETTER SHIN WITH DAGESH AND SIN DOT
FB2E HEBREW LETTER ALEF WITH PATAH
FB2F HEBREW LETTER ALEF WITH QAMATS
FB30 HEBREW LETTER ALEF WITH MAPIQ
FB31 HEBREW LETTER BET WITH DAGESH
FB32 HEBREW LETTER GIMEL WITH DAGESH
FB33 HEBREW LETTER DALET WITH DAGESH
FB34 HEBREW LETTER HE WITH MAPIQ
FB35 HEBREW LETTER VAV WITH DAGESH
FB36 HEBREW LETTER ZAYIN WITH DAGESH
FB38 HEBREW LETTER TET WITH DAGESH
FB39 HEBREW LETTER YOD WITH DAGESH
FB3A HEBREW LETTER FINAL KAF WITH DAGESH
FB3B HEBREW LETTER KAF WITH DAGESH
FB3C HEBREW LETTER LAMED WITH DAGESH
FB3E HEBREW LETTER MEM WITH DAGESH
FB40 HEBREW LETTER NUN WITH DAGESH
FB41 HEBREW LETTER SAMEKH WITH DAGESH
FB43 HEBREW LETTER FINAL PE WITH DAGESH
FB44 HEBREW LETTER PE WITH DAGESH
FB46 HEBREW LETTER TSADI WITH DAGESH
FB47 HEBREW LETTER QOF WITH DAGESH
FB48 HEBREW LETTER RESH WITH DAGESH
FB49 HEBREW LETTER SHIN WITH DAGESH
FB4A HEBREW LETTER TAV WITH DAGESH
FB4B HEBREW LETTER VAV WITH HOLAM
FB4C HEBREW LETTER BET WITH RAFE
FB4D HEBREW LETTER KAF WITH RAFE
FB4E HEBREW LETTER PE WITH RAFE
FB4F HEBREW LIGATURE ALEF LAMED
FB50 ARABIC LETTER ALEF WASLA ISOLATED FORM
FB51 ARABIC LETTER ALEF WASLA FINAL FORM
FB52 ARABIC LETTER BEEH ISOLATED FORM
FB53 ARABIC LETTER BEEH FINAL FORM
FB54 ARABIC LETTER BEEH INITIAL FORM
FB55 ARABIC LETTER BEEH MEDIAL FORM
FB56 ARABIC LETTER PEH ISOLATED FORM
FB57 ARABIC LETTER PEH FINAL FORM
FB58 ARABIC LETTER PEH INITIAL FORM
FB59 ARABIC LETTER PEH MEDIAL FORM
FB5A ARABIC LETTER BEHEH ISOLATED FORM
FB5B ARABIC LETTER BEHEH FINAL FORM
FB5C ARABIC LETTER BEHEH INITIAL FORM
FB5D ARABIC LETTER BEHEH MEDIAL FORM
FB5E ARABIC LETTER TTEHEH ISOLATED FORM
FB5F ARABIC LETTER TTEHEH FINAL FORM
FB60 ARABIC LETTER TTEHEH INITIAL FORM
FB61 ARABIC LETTER TTEHEH MEDIAL FORM
FB62 ARABIC LETTER TEHEH ISOLATED FORM
FB63 ARABIC LETTER TEHEH FINAL FORM
FB64 ARABIC LETTER TEHEH INITIAL FORM
FB65 ARABIC LETTER TEHEH MEDIAL FORM
FB66 ARABIC LETTER TTEH ISOLATED FORM
FB67 ARABIC LETTER TTEH FINAL FORM
FB68 ARABIC LETTER TTEH INITIAL FORM
FB69 ARABIC LETTER TTEH MEDIAL FORM
FB6A ARABIC LETTER VEH ISOLATED FORM
FB6B ARABIC LETTER VEH FINAL FORM
FB6C ARABIC LETTER VEH INITIAL FORM
FB6D ARABIC LETTER VEH MEDIAL FORM
FB6E ARABIC LETTER PEHEH ISOLATED FORM
FB6F ARABIC LETTER PEHEH FINAL FORM
FB70 ARABIC LETTER PEHEH INITIAL FORM
FB71 ARABIC LETTER PEHEH MEDIAL FORM
FB72 ARABIC LETTER DYEH ISOLATED FORM
FB73 ARABIC LETTER DYEH FINAL FORM
FB74 ARABIC LETTER DYEH INITIAL FORM
FB75 ARABIC LETTER DYEH MEDIAL FORM
FB76 ARABIC LETTER NYEH ISOLATED FORM
FB77 ARABIC LETTER NYEH FINAL FORM
FB78 ARABIC LETTER NYEH INITIAL FORM
FB79 ARABIC LETTER NYEH MEDIAL FORM
FB7A ARABIC LETTER TCHEH ISOLATED FORM
FB7B ARABIC LETTER TCHEH FINAL FORM
FB7C ARABIC LETTER TCHEH INITIAL FORM
FB7D ARABIC LETTER TCHEH MEDIAL FORM
FB7E ARABIC LETTER TCHEHEH ISOLATED FORM
FB7F ARABIC LETTER TCHEHEH FINAL FORM
FB80 ARABIC LETTER TCHEHEH INITIAL FORM
FB81 ARABIC LETTER TCHEHEH MEDIAL FORM
FB82 ARABIC LETTER DDAHAL ISOLATED FORM
FB83 ARABIC LETTER DDAHAL FINAL FORM
FB84 ARABIC LETTER DAHAL ISOLATED FORM
FB85 ARABIC LETTER DAHAL FINAL FORM
FB86 ARABIC LETTER DUL ISOLATED FORM
FB87 ARABIC LETTER DUL FINAL FORM
FB88 ARABIC LETTER DDAL ISOLATED FORM
FB89 ARABIC LETTER DDAL FINAL FORM
FB8A ARABIC LETTER JEH ISOLATED FORM
FB8B ARABIC LETTER JEH FINAL FORM
FB8C ARABIC LETTER RREH ISOLATED FORM
FB8D ARABIC LETTER RREH FINAL FORM
FB8E ARABIC LETTER KEHEH ISOLATED FORM
FB8F ARABIC LETTER KEHEH FINAL FORM
FB90 ARABIC LETTER KEHEH INITIAL FORM
FB91 ARABIC LETTER KEHEH MEDIAL FORM
FB92 ARABIC LETTER GAF ISOLATED FORM
FB93 ARABIC LETTER GAF FINAL FORM
FB94 ARABIC LETTER GAF INITIAL FORM
FB95 ARABIC LETTER GAF MEDIAL FORM
FB96 ARABIC LETTER GUEH ISOLATED FORM
FB97 ARABIC LETTER GUEH FINAL FORM
FB98 ARABIC LETTER GUEH INITIAL FORM
FB99 ARABIC LETTER GUEH MEDIAL FORM
FB9A ARABIC LETTER NGOEH ISOLATED FORM
FB9B ARABIC LETTER NGOEH FINAL FORM
FB9C ARABIC LETTER NGOEH INITIAL FORM
FB9D ARABIC LETTER NGOEH MEDIAL FORM
FB9E ARABIC LETTER NOON GHUNNA ISOLATED FORM
FB9F ARABIC LETTER NOON GHUNNA FINAL FORM
FBA0 ARABIC LETTER RNOON ISOLATED FORM
FBA1 ARABIC LETTER RNOON FINAL FORM
FBA2 ARABIC LETTER RNOON INITIAL FORM
FBA3 ARABIC LETTER RNOON MEDIAL FORM
FBA4 ARABIC LETTER HEH WITH YEH ABOVE ISOLATED FORM
FBA5 ARABIC LETTER HEH WITH YEH ABOVE FINAL FORM
FBA6 ARABIC LETTER HEH GOAL ISOLATED FORM
FBA7 ARABIC LETTER HEH GOAL FINAL FORM
FBA8 ARABIC LETTER HEH GOAL INITIAL FORM
FBA9 ARABIC LETTER HEH GOAL MEDIAL FORM
FBAA ARABIC LETTER HEH DOACHASHMEE ISOLATED FORM
FBAB ARABIC LETTER HEH DOACHASHMEE FINAL FORM
FBAC ARABIC LETTER HEH DOACHASHMEE INITIAL FORM
FBAD ARABIC LETTER HEH DOACHASHMEE MEDIAL FORM
FBAE ARABIC LETTER YEH BARREE ISOLATED FORM
FBAF ARABIC LETTER YEH BARREE FINAL FORM
FBB0 ARABIC LETTER YEH BARREE WITH HAMZA ABOVE ISOLATED FORM
FBB1 ARABIC LETTER YEH BARREE WITH HAMZA ABOVE FINAL FORM
FBD3 ARABIC LETTER NG ISOLATED FORM
FBD4 ARABIC LETTER NG FINAL FORM
FBD5 ARABIC LETTER NG INITIAL FORM
FBD6 ARABIC LETTER NG MEDIAL FORM
FBD7 ARABIC LETTER U ISOLATED FORM
FBD8 ARABIC LETTER U FINAL FORM
FBD9 ARABIC LETTER OE ISOLATED FORM
FBDA ARABIC LETTER OE FINAL FORM
FBDB ARABIC LETTER YU ISOLATED FORM
FBDC ARABIC LETTER YU FINAL FORM
FBDD ARABIC LETTER U WITH HAMZA ABOVE ISOLATED FORM
FBDE ARABIC LETTER VE ISOLATED FORM
FBDF ARABIC LETTER VE FINAL FORM
FBE0 ARABIC LETTER KIRGHIZ OE ISOLATED FORM
FBE1 ARABIC LETTER KIRGHIZ OE FINAL FORM
FBE2 ARABIC LETTER KIRGHIZ YU ISOLATED FORM
FBE3 ARABIC LETTER KIRGHIZ YU FINAL FORM
FBE4 ARABIC LETTER E ISOLATED FORM
FBE5 ARABIC LETTER E FINAL FORM
FBE6 ARABIC LETTER E INITIAL FORM
FBE7 ARABIC LETTER E MEDIAL FORM
FBE8 ARABIC LETTER UIGHUR KAZAKH KIRGHIZ ALEF MAKSURA INITIAL FORM
FBE9 ARABIC LETTER UIGHUR KAZAKH KIRGHIZ ALEF MAKSURA MEDIAL FORM
FBEA ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH ALEF ISOLATED FORM
FBEB ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH ALEF FINAL FORM
FBEC ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH AE ISOLATED FORM
FBED ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH AE FINAL FORM
FBEE ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH WAW ISOLATED FORM
FBEF ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH WAW FINAL FORM
FBF0 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH U ISOLATED FORM
FBF1 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH U FINAL FORM
FBF2 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH OE ISOLATED FORM
FBF3 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH OE FINAL FORM
FBF4 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH YU ISOLATED FORM
FBF5 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH YU FINAL FORM
FBF6 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH E ISOLATED FORM
FBF7 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH E FINAL FORM
FBF8 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH E INITIAL FORM
FBF9 ARABIC LIGATURE UIGHUR KIRGHIZ YEH WITH HAMZA ABOVE WITH ALEF MAKSURA ISOLATED FORM
FBFA ARABIC LIGATURE UIGHUR KIRGHIZ YEH WITH HAMZA ABOVE WITH ALEF MAKSURA FINAL FORM
FBFB ARABIC LIGATURE UIGHUR KIRGHIZ YEH WITH HAMZA ABOVE WITH ALEF MAKSURA INITIAL FORM
FBFC ARABIC LETTER FARSI YEH ISOLATED FORM
FBFD ARABIC LETTER FARSI YEH FINAL FORM
FBFE ARABIC LETTER FARSI YEH INITIAL FORM
FBFF ARABIC LETTER FARSI YEH MEDIAL FORM
FC00 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH JEEM ISOLATED FORM
FC01 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH HAH ISOLATED FORM
FC02 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH MEEM ISOLATED FORM
FC03 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH ALEF MAKSURA ISOLATED FORM
FC04 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH YEH ISOLATED FORM
FC05 ARABIC LIGATURE BEH WITH JEEM ISOLATED FORM
FC06 ARABIC LIGATURE BEH WITH HAH ISOLATED FORM
FC07 ARABIC LIGATURE BEH WITH KHAH ISOLATED FORM
FC08 ARABIC LIGATURE BEH WITH MEEM ISOLATED FORM
FC09 ARABIC LIGATURE BEH WITH ALEF MAKSURA ISOLATED FORM
FC0A ARABIC LIGATURE BEH WITH YEH ISOLATED FORM
FC0B ARABIC LIGATURE TEH WITH JEEM ISOLATED FORM
FC0C ARABIC LIGATURE TEH WITH HAH ISOLATED FORM
FC0D ARABIC LIGATURE TEH WITH KHAH ISOLATED FORM
FC0E ARABIC LIGATURE TEH WITH MEEM ISOLATED FORM
FC0F ARABIC LIGATURE TEH WITH ALEF MAKSURA ISOLATED FORM
FC10 ARABIC LIGATURE TEH WITH YEH ISOLATED FORM
FC11 ARABIC LIGATURE THEH WITH JEEM ISOLATED FORM
FC12 ARABIC LIGATURE THEH WITH MEEM ISOLATED FORM
FC13 ARABIC LIGATURE THEH WITH ALEF MAKSURA ISOLATED FORM
FC14 ARABIC LIGATURE THEH WITH YEH ISOLATED FORM
FC15 ARABIC LIGATURE JEEM WITH HAH ISOLATED FORM
FC16 ARABIC LIGATURE JEEM WITH MEEM ISOLATED FORM
FC17 ARABIC LIGATURE HAH WITH JEEM ISOLATED FORM
FC18 ARABIC LIGATURE HAH WITH MEEM ISOLATED FORM
FC19 ARABIC LIGATURE KHAH WITH JEEM ISOLATED FORM
FC1A ARABIC LIGATURE KHAH WITH HAH ISOLATED FORM
FC1B ARABIC LIGATURE KHAH WITH MEEM ISOLATED FORM
FC1C ARABIC LIGATURE SEEN WITH JEEM ISOLATED FORM
FC1D ARABIC LIGATURE SEEN WITH HAH ISOLATED FORM
FC1E ARABIC LIGATURE SEEN WITH KHAH ISOLATED FORM
FC1F ARABIC LIGATURE SEEN WITH MEEM ISOLATED FORM
FC20 ARABIC LIGATURE SAD WITH HAH ISOLATED FORM
FC21 ARABIC LIGATURE SAD WITH MEEM ISOLATED FORM
FC22 ARABIC LIGATURE DAD WITH JEEM ISOLATED FORM
FC23 ARABIC LIGATURE DAD WITH HAH ISOLATED FORM
FC24 ARABIC LIGATURE DAD WITH KHAH ISOLATED FORM
FC25 ARABIC LIGATURE DAD WITH MEEM ISOLATED FORM
FC26 ARABIC LIGATURE TAH WITH HAH ISOLATED FORM
FC27 ARABIC LIGATURE TAH WITH MEEM ISOLATED FORM
FC28 ARABIC LIGATURE ZAH WITH MEEM ISOLATED FORM
FC29 ARABIC LIGATURE AIN WITH JEEM ISOLATED FORM
FC2A ARABIC LIGATURE AIN WITH MEEM ISOLATED FORM
FC2B ARABIC LIGATURE GHAIN WITH JEEM ISOLATED FORM
FC2C ARABIC LIGATURE GHAIN WITH MEEM ISOLATED FORM
FC2D ARABIC LIGATURE FEH WITH JEEM ISOLATED FORM
FC2E ARABIC LIGATURE FEH WITH HAH ISOLATED FORM
FC2F ARABIC LIGATURE FEH WITH KHAH ISOLATED FORM
FC30 ARABIC LIGATURE FEH WITH MEEM ISOLATED FORM
FC31 ARABIC LIGATURE FEH WITH ALEF MAKSURA ISOLATED FORM
FC32 ARABIC LIGATURE FEH WITH YEH ISOLATED FORM
FC33 ARABIC LIGATURE QAF WITH HAH ISOLATED FORM
FC34 ARABIC LIGATURE QAF WITH MEEM ISOLATED FORM
FC35 ARABIC LIGATURE QAF WITH ALEF MAKSURA ISOLATED FORM
FC36 ARABIC LIGATURE QAF WITH YEH ISOLATED FORM
FC37 ARABIC LIGATURE KAF WITH ALEF ISOLATED FORM
FC38 ARABIC LIGATURE KAF WITH JEEM ISOLATED FORM
FC39 ARABIC LIGATURE KAF WITH HAH ISOLATED FORM
FC3A ARABIC LIGATURE KAF WITH KHAH ISOLATED FORM
FC3B ARABIC LIGATURE KAF WITH LAM ISOLATED FORM
FC3C ARABIC LIGATURE KAF WITH MEEM ISOLATED FORM
FC3D ARABIC LIGATURE KAF WITH ALEF MAKSURA ISOLATED FORM
FC3E ARABIC LIGATURE KAF WITH YEH ISOLATED FORM
FC3F ARABIC LIGATURE LAM WITH JEEM ISOLATED FORM
FC40 ARABIC LIGATURE LAM WITH HAH ISOLATED FORM
FC41 ARABIC LIGATURE LAM WITH KHAH ISOLATED FORM
FC42 ARABIC LIGATURE LAM WITH MEEM ISOLATED FORM
FC43 ARABIC LIGATURE LAM WITH ALEF MAKSURA ISOLATED FORM
FC44 ARABIC LIGATURE LAM WITH YEH ISOLATED FORM
FC45 ARABIC LIGATURE MEEM WITH JEEM ISOLATED FORM
FC46 ARABIC LIGATURE MEEM WITH HAH ISOLATED FORM
FC47 ARABIC LIGATURE MEEM WITH KHAH ISOLATED FORM
FC48 ARABIC LIGATURE MEEM WITH MEEM ISOLATED FORM
FC49 ARABIC LIGATURE MEEM WITH ALEF MAKSURA ISOLATED FORM
FC4A ARABIC LIGATURE MEEM WITH YEH ISOLATED FORM
FC4B ARABIC LIGATURE NOON WITH JEEM ISOLATED FORM
FC4C ARABIC LIGATURE NOON WITH HAH ISOLATED FORM
FC4D ARABIC LIGATURE NOON WITH KHAH ISOLATED FORM
FC4E ARABIC LIGATURE NOON WITH MEEM ISOLATED FORM
FC4F ARABIC LIGATURE NOON WITH ALEF MAKSURA ISOLATED FORM
FC50 ARABIC LIGATURE NOON WITH YEH ISOLATED FORM
FC51 ARABIC LIGATURE HEH WITH JEEM ISOLATED FORM
FC52 ARABIC LIGATURE HEH WITH MEEM ISOLATED FORM
FC53 ARABIC LIGATURE HEH WITH ALEF MAKSURA ISOLATED FORM
FC54 ARABIC LIGATURE HEH WITH YEH ISOLATED FORM
FC55 ARABIC LIGATURE YEH WITH JEEM ISOLATED FORM
FC56 ARABIC LIGATURE YEH WITH HAH ISOLATED FORM
FC57 ARABIC LIGATURE YEH WITH KHAH ISOLATED FORM
FC58 ARABIC LIGATURE YEH WITH MEEM ISOLATED FORM
FC59 ARABIC LIGATURE YEH WITH ALEF MAKSURA ISOLATED FORM
FC5A ARABIC LIGATURE YEH WITH YEH ISOLATED FORM
FC5B ARABIC LIGATURE THAL WITH SUPERSCRIPT ALEF ISOLATED FORM
FC5C ARABIC LIGATURE REH WITH SUPERSCRIPT ALEF ISOLATED FORM
FC5D ARABIC LIGATURE ALEF MAKSURA WITH SUPERSCRIPT ALEF ISOLATED FORM
FC5E ARABIC LIGATURE SHADDA WITH DAMMATAN ISOLATED FORM
FC5F ARABIC LIGATURE SHADDA WITH KASRATAN ISOLATED FORM
FC60 ARABIC LIGATURE SHADDA WITH FATHA ISOLATED FORM
FC61 ARABIC LIGATURE SHADDA WITH DAMMA ISOLATED FORM
FC62 ARABIC LIGATURE SHADDA WITH KASRA ISOLATED FORM
FC63 ARABIC LIGATURE SHADDA WITH SUPERSCRIPT ALEF ISOLATED FORM
FC64 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH REH FINAL FORM
FC65 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH ZAIN FINAL FORM
FC66 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH MEEM FINAL FORM
FC67 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH NOON FINAL FORM
FC68 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH ALEF MAKSURA FINAL FORM
FC69 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH YEH FINAL FORM
FC6A ARABIC LIGATURE BEH WITH REH FINAL FORM
FC6B ARABIC LIGATURE BEH WITH ZAIN FINAL FORM
FC6C ARABIC LIGATURE BEH WITH MEEM FINAL FORM
FC6D ARABIC LIGATURE BEH WITH NOON FINAL FORM
FC6E ARABIC LIGATURE BEH WITH ALEF MAKSURA FINAL FORM
FC6F ARABIC LIGATURE BEH WITH YEH FINAL FORM
FC70 ARABIC LIGATURE TEH WITH REH FINAL FORM
FC71 ARABIC LIGATURE TEH WITH ZAIN FINAL FORM
FC72 ARABIC LIGATURE TEH WITH MEEM FINAL FORM
FC73 ARABIC LIGATURE TEH WITH NOON FINAL FORM
FC74 ARABIC LIGATURE TEH WITH ALEF MAKSURA FINAL FORM
FC75 ARABIC LIGATURE TEH WITH YEH FINAL FORM
FC76 ARABIC LIGATURE THEH WITH REH FINAL FORM
FC77 ARABIC LIGATURE THEH WITH ZAIN FINAL FORM
FC78 ARABIC LIGATURE THEH WITH MEEM FINAL FORM
FC79 ARABIC LIGATURE THEH WITH NOON FINAL FORM
FC7A ARABIC LIGATURE THEH WITH ALEF MAKSURA FINAL FORM
FC7B ARABIC LIGATURE THEH WITH YEH FINAL FORM
FC7C ARABIC LIGATURE FEH WITH ALEF MAKSURA FINAL FORM
FC7D ARABIC LIGATURE FEH WITH YEH FINAL FORM
FC7E ARABIC LIGATURE QAF WITH ALEF MAKSURA FINAL FORM
FC7F ARABIC LIGATURE QAF WITH YEH FINAL FORM
FC80 ARABIC LIGATURE KAF WITH ALEF FINAL FORM
FC81 ARABIC LIGATURE KAF WITH LAM FINAL FORM
FC82 ARABIC LIGATURE KAF WITH MEEM FINAL FORM
FC83 ARABIC LIGATURE KAF WITH ALEF MAKSURA FINAL FORM
FC84 ARABIC LIGATURE KAF WITH YEH FINAL FORM
FC85 ARABIC LIGATURE LAM WITH MEEM FINAL FORM
FC86 ARABIC LIGATURE LAM WITH ALEF MAKSURA FINAL FORM
FC87 ARABIC LIGATURE LAM WITH YEH FINAL FORM
FC88 ARABIC LIGATURE MEEM WITH ALEF FINAL FORM
FC89 ARABIC LIGATURE MEEM WITH MEEM FINAL FORM
FC8A ARABIC LIGATURE NOON WITH REH FINAL FORM
FC8B ARABIC LIGATURE NOON WITH ZAIN FINAL FORM
FC8C ARABIC LIGATURE NOON WITH MEEM FINAL FORM
FC8D ARABIC LIGATURE NOON WITH NOON FINAL FORM
FC8E ARABIC LIGATURE NOON WITH ALEF MAKSURA FINAL FORM
FC8F ARABIC LIGATURE NOON WITH YEH FINAL FORM
FC90 ARABIC LIGATURE ALEF MAKSURA WITH SUPERSCRIPT ALEF FINAL FORM
FC91 ARABIC LIGATURE YEH WITH REH FINAL FORM
FC92 ARABIC LIGATURE YEH WITH ZAIN FINAL FORM
FC93 ARABIC LIGATURE YEH WITH MEEM FINAL FORM
FC94 ARABIC LIGATURE YEH WITH NOON FINAL FORM
FC95 ARABIC LIGATURE YEH WITH ALEF MAKSURA FINAL FORM
FC96 ARABIC LIGATURE YEH WITH YEH FINAL FORM
FC97 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH JEEM INITIAL FORM
FC98 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH HAH INITIAL FORM
FC99 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH KHAH INITIAL FORM
FC9A ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH MEEM INITIAL FORM
FC9B ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH HEH INITIAL FORM
FC9C ARABIC LIGATURE BEH WITH JEEM INITIAL FORM
FC9D ARABIC LIGATURE BEH WITH HAH INITIAL FORM
FC9E ARABIC LIGATURE BEH WITH KHAH INITIAL FORM
FC9F ARABIC LIGATURE BEH WITH MEEM INITIAL FORM
FCA0 ARABIC LIGATURE BEH WITH HEH INITIAL FORM
FCA1 ARABIC LIGATURE TEH WITH JEEM INITIAL FORM
FCA2 ARABIC LIGATURE TEH WITH HAH INITIAL FORM
FCA3 ARABIC LIGATURE TEH WITH KHAH INITIAL FORM
FCA4 ARABIC LIGATURE TEH WITH MEEM INITIAL FORM
FCA5 ARABIC LIGATURE TEH WITH HEH INITIAL FORM
FCA6 ARABIC LIGATURE THEH WITH MEEM INITIAL FORM
FCA7 ARABIC LIGATURE JEEM WITH HAH INITIAL FORM
FCA8 ARABIC LIGATURE JEEM WITH MEEM INITIAL FORM
FCA9 ARABIC LIGATURE HAH WITH JEEM INITIAL FORM
FCAA ARABIC LIGATURE HAH WITH MEEM INITIAL FORM
FCAB ARABIC LIGATURE KHAH WITH JEEM INITIAL FORM
FCAC ARABIC LIGATURE KHAH WITH MEEM INITIAL FORM
FCAD ARABIC LIGATURE SEEN WITH JEEM INITIAL FORM
FCAE ARABIC LIGATURE SEEN WITH HAH INITIAL FORM
FCAF ARABIC LIGATURE SEEN WITH KHAH INITIAL FORM
FCB0 ARABIC LIGATURE SEEN WITH MEEM INITIAL FORM
FCB1 ARABIC LIGATURE SAD WITH HAH INITIAL FORM
FCB2 ARABIC LIGATURE SAD WITH KHAH INITIAL FORM
FCB3 ARABIC LIGATURE SAD WITH MEEM INITIAL FORM
FCB4 ARABIC LIGATURE DAD WITH JEEM INITIAL FORM
FCB5 ARABIC LIGATURE DAD WITH HAH INITIAL FORM
FCB6 ARABIC LIGATURE DAD WITH KHAH INITIAL FORM
FCB7 ARABIC LIGATURE DAD WITH MEEM INITIAL FORM
FCB8 ARABIC LIGATURE TAH WITH HAH INITIAL FORM
FCB9 ARABIC LIGATURE ZAH WITH MEEM INITIAL FORM
FCBA ARABIC LIGATURE AIN WITH JEEM INITIAL FORM
FCBB ARABIC LIGATURE AIN WITH MEEM INITIAL FORM
FCBC ARABIC LIGATURE GHAIN WITH JEEM INITIAL FORM
FCBD ARABIC LIGATURE GHAIN WITH MEEM INITIAL FORM
FCBE ARABIC LIGATURE FEH WITH JEEM INITIAL FORM
FCBF ARABIC LIGATURE FEH WITH HAH INITIAL FORM
FCC0 ARABIC LIGATURE FEH WITH KHAH INITIAL FORM
FCC1 ARABIC LIGATURE FEH WITH MEEM INITIAL FORM
FCC2 ARABIC LIGATURE QAF WITH HAH INITIAL FORM
FCC3 ARABIC LIGATURE QAF WITH MEEM INITIAL FORM
FCC4 ARABIC LIGATURE KAF WITH JEEM INITIAL FORM
FCC5 ARABIC LIGATURE KAF WITH HAH INITIAL FORM
FCC6 ARABIC LIGATURE KAF WITH KHAH INITIAL FORM
FCC7 ARABIC LIGATURE KAF WITH LAM INITIAL FORM
FCC8 ARABIC LIGATURE KAF WITH MEEM INITIAL FORM
FCC9 ARABIC LIGATURE LAM WITH JEEM INITIAL FORM
FCCA ARABIC LIGATURE LAM WITH HAH INITIAL FORM
FCCB ARABIC LIGATURE LAM WITH KHAH INITIAL FORM
FCCC ARABIC LIGATURE LAM WITH MEEM INITIAL FORM
FCCD ARABIC LIGATURE LAM WITH HEH INITIAL FORM
FCCE ARABIC LIGATURE MEEM WITH JEEM INITIAL FORM
FCCF ARABIC LIGATURE MEEM WITH HAH INITIAL FORM
FCD0 ARABIC LIGATURE MEEM WITH KHAH INITIAL FORM
FCD1 ARABIC LIGATURE MEEM WITH MEEM INITIAL FORM
FCD2 ARABIC LIGATURE NOON WITH JEEM INITIAL FORM
FCD3 ARABIC LIGATURE NOON WITH HAH INITIAL FORM
FCD4 ARABIC LIGATURE NOON WITH KHAH INITIAL FORM
FCD5 ARABIC LIGATURE NOON WITH MEEM INITIAL FORM
FCD6 ARABIC LIGATURE NOON WITH HEH INITIAL FORM
FCD7 ARABIC LIGATURE HEH WITH JEEM INITIAL FORM
FCD8 ARABIC LIGATURE HEH WITH MEEM INITIAL FORM
FCD9 ARABIC LIGATURE HEH WITH SUPERSCRIPT ALEF INITIAL FORM
FCDA ARABIC LIGATURE YEH WITH JEEM INITIAL FORM
FCDB ARABIC LIGATURE YEH WITH HAH INITIAL FORM
FCDC ARABIC LIGATURE YEH WITH KHAH INITIAL FORM
FCDD ARABIC LIGATURE YEH WITH MEEM INITIAL FORM
FCDE ARABIC LIGATURE YEH WITH HEH INITIAL FORM
FCDF ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH MEEM MEDIAL FORM
FCE0 ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH HEH MEDIAL FORM
FCE1 ARABIC LIGATURE BEH WITH MEEM MEDIAL FORM
FCE2 ARABIC LIGATURE BEH WITH HEH MEDIAL FORM
FCE3 ARABIC LIGATURE TEH WITH MEEM MEDIAL FORM
FCE4 ARABIC LIGATURE TEH WITH HEH MEDIAL FORM
FCE5 ARABIC LIGATURE THEH WITH MEEM MEDIAL FORM
FCE6 ARABIC LIGATURE THEH WITH HEH MEDIAL FORM
FCE7 ARABIC LIGATURE SEEN WITH MEEM MEDIAL FORM
FCE8 ARABIC LIGATURE SEEN WITH HEH MEDIAL FORM
FCE9 ARABIC LIGATURE SHEEN WITH MEEM MEDIAL FORM
FCEA ARABIC LIGATURE SHEEN WITH HEH MEDIAL FORM
FCEB ARABIC LIGATURE KAF WITH LAM MEDIAL FORM
FCEC ARABIC LIGATURE KAF WITH MEEM MEDIAL FORM
FCED ARABIC LIGATURE LAM WITH MEEM MEDIAL FORM
FCEE ARABIC LIGATURE NOON WITH MEEM MEDIAL FORM
FCEF ARABIC LIGATURE NOON WITH HEH MEDIAL FORM
FCF0 ARABIC LIGATURE YEH WITH MEEM MEDIAL FORM
FCF1 ARABIC LIGATURE YEH WITH HEH MEDIAL FORM
FCF2 ARABIC LIGATURE SHADDA WITH FATHA MEDIAL FORM
FCF3 ARABIC LIGATURE SHADDA WITH DAMMA MEDIAL FORM
FCF4 ARABIC LIGATURE SHADDA WITH KASRA MEDIAL FORM
FCF5 ARABIC LIGATURE TAH WITH ALEF MAKSURA ISOLATED FORM
FCF6 ARABIC LIGATURE TAH WITH YEH ISOLATED FORM
FCF7 ARABIC LIGATURE AIN WITH ALEF MAKSURA ISOLATED FORM
FCF8 ARABIC LIGATURE AIN WITH YEH ISOLATED FORM
FCF9 ARABIC LIGATURE GHAIN WITH ALEF MAKSURA ISOLATED FORM
FCFA ARABIC LIGATURE GHAIN WITH YEH ISOLATED FORM
FCFB ARABIC LIGATURE SEEN WITH ALEF MAKSURA ISOLATED FORM
FCFC ARABIC LIGATURE SEEN WITH YEH ISOLATED FORM
FCFD ARABIC LIGATURE SHEEN WITH ALEF MAKSURA ISOLATED FORM
FCFE ARABIC LIGATURE SHEEN WITH YEH ISOLATED FORM
FCFF ARABIC LIGATURE HAH WITH ALEF MAKSURA ISOLATED FORM
FD00 ARABIC LIGATURE HAH WITH YEH ISOLATED FORM
FD01 ARABIC LIGATURE JEEM WITH ALEF MAKSURA ISOLATED FORM
FD02 ARABIC LIGATURE JEEM WITH YEH ISOLATED FORM
FD03 ARABIC LIGATURE KHAH WITH ALEF MAKSURA ISOLATED FORM
FD04 ARABIC LIGATURE KHAH WITH YEH ISOLATED FORM
FD05 ARABIC LIGATURE SAD WITH ALEF MAKSURA ISOLATED FORM
FD06 ARABIC LIGATURE SAD WITH YEH ISOLATED FORM
FD07 ARABIC LIGATURE DAD WITH ALEF MAKSURA ISOLATED FORM
FD08 ARABIC LIGATURE DAD WITH YEH ISOLATED FORM
FD09 ARABIC LIGATURE SHEEN WITH JEEM ISOLATED FORM
FD0A ARABIC LIGATURE SHEEN WITH HAH ISOLATED FORM
FD0B ARABIC LIGATURE SHEEN WITH KHAH ISOLATED FORM
FD0C ARABIC LIGATURE SHEEN WITH MEEM ISOLATED FORM
FD0D ARABIC LIGATURE SHEEN WITH REH ISOLATED FORM
FD0E ARABIC LIGATURE SEEN WITH REH ISOLATED FORM
FD0F ARABIC LIGATURE SAD WITH REH ISOLATED FORM
FD10 ARABIC LIGATURE DAD WITH REH ISOLATED FORM
FD11 ARABIC LIGATURE TAH WITH ALEF MAKSURA FINAL FORM
FD12 ARABIC LIGATURE TAH WITH YEH FINAL FORM
FD13 ARABIC LIGATURE AIN WITH ALEF MAKSURA FINAL FORM
FD14 ARABIC LIGATURE AIN WITH YEH FINAL FORM
FD15 ARABIC LIGATURE GHAIN WITH ALEF MAKSURA FINAL FORM
FD16 ARABIC LIGATURE GHAIN WITH YEH FINAL FORM
FD17 ARABIC LIGATURE SEEN WITH ALEF MAKSURA FINAL FORM
FD18 ARABIC LIGATURE SEEN WITH YEH FINAL FORM
FD19 ARABIC LIGATURE SHEEN WITH ALEF MAKSURA FINAL FORM
FD1A ARABIC LIGATURE SHEEN WITH YEH FINAL FORM
FD1B ARABIC LIGATURE HAH WITH ALEF MAKSURA FINAL FORM
FD1C ARABIC LIGATURE HAH WITH YEH FINAL FORM
FD1D ARABIC LIGATURE JEEM WITH ALEF MAKSURA FINAL FORM
FD1E ARABIC LIGATURE JEEM WITH YEH FINAL FORM
FD1F ARABIC LIGATURE KHAH WITH ALEF MAKSURA FINAL FORM
FD20 ARABIC LIGATURE KHAH WITH YEH FINAL FORM
FD21 ARABIC LIGATURE SAD WITH ALEF MAKSURA FINAL FORM
FD22 ARABIC LIGATURE SAD WITH YEH FINAL FORM
FD23 ARABIC LIGATURE DAD WITH ALEF MAKSURA FINAL FORM
FD24 ARABIC LIGATURE DAD WITH YEH FINAL FORM
FD25 ARABIC LIGATURE SHEEN WITH JEEM FINAL FORM
FD26 ARABIC LIGATURE SHEEN WITH HAH FINAL FORM
FD27 ARABIC LIGATURE SHEEN WITH KHAH FINAL FORM
FD28 ARABIC LIGATURE SHEEN WITH MEEM FINAL FORM
FD29 ARABIC LIGATURE SHEEN WITH REH FINAL FORM
FD2A ARABIC LIGATURE SEEN WITH REH FINAL FORM
FD2B ARABIC LIGATURE SAD WITH REH FINAL FORM
FD2C ARABIC LIGATURE DAD WITH REH FINAL FORM
FD2D ARABIC LIGATURE SHEEN WITH JEEM INITIAL FORM
FD2E ARABIC LIGATURE SHEEN WITH HAH INITIAL FORM
FD2F ARABIC LIGATURE SHEEN WITH KHAH INITIAL FORM
FD30 ARABIC LIGATURE SHEEN WITH MEEM INITIAL FORM
FD31 ARABIC LIGATURE SEEN WITH HEH INITIAL FORM
FD32 ARABIC LIGATURE SHEEN WITH HEH INITIAL FORM
FD33 ARABIC LIGATURE TAH WITH MEEM INITIAL FORM
FD34 ARABIC LIGATURE SEEN WITH JEEM MEDIAL FORM
FD35 ARABIC LIGATURE SEEN WITH HAH MEDIAL FORM
FD36 ARABIC LIGATURE SEEN WITH KHAH MEDIAL FORM
FD37 ARABIC LIGATURE SHEEN WITH JEEM MEDIAL FORM
FD38 ARABIC LIGATURE SHEEN WITH HAH MEDIAL FORM
FD39 ARABIC LIGATURE SHEEN WITH KHAH MEDIAL FORM
FD3A ARABIC LIGATURE TAH WITH MEEM MEDIAL FORM
FD3B ARABIC LIGATURE ZAH WITH MEEM MEDIAL FORM
FD3C ARABIC LIGATURE ALEF WITH FATHATAN FINAL FORM
FD3D ARABIC LIGATURE ALEF WITH FATHATAN ISOLATED FORM
FD3E ORNATE LEFT PARENTHESIS
FD3F ORNATE RIGHT PARENTHESIS
FD50 ARABIC LIGATURE TEH WITH JEEM WITH MEEM INITIAL FORM
FD51 ARABIC LIGATURE TEH WITH HAH WITH JEEM FINAL FORM
FD52 ARABIC LIGATURE TEH WITH HAH WITH JEEM INITIAL FORM
FD53 ARABIC LIGATURE TEH WITH HAH WITH MEEM INITIAL FORM
FD54 ARABIC LIGATURE TEH WITH KHAH WITH MEEM INITIAL FORM
FD55 ARABIC LIGATURE TEH WITH MEEM WITH JEEM INITIAL FORM
FD56 ARABIC LIGATURE TEH WITH MEEM WITH HAH INITIAL FORM
FD57 ARABIC LIGATURE TEH WITH MEEM WITH KHAH INITIAL FORM
FD58 ARABIC LIGATURE JEEM WITH MEEM WITH HAH FINAL FORM
FD59 ARABIC LIGATURE JEEM WITH MEEM WITH HAH INITIAL FORM
FD5A ARABIC LIGATURE HAH WITH MEEM WITH YEH FINAL FORM
FD5B ARABIC LIGATURE HAH WITH MEEM WITH ALEF MAKSURA FINAL FORM
FD5C ARABIC LIGATURE SEEN WITH HAH WITH JEEM INITIAL FORM
FD5D ARABIC LIGATURE SEEN WITH JEEM WITH HAH INITIAL FORM
FD5E ARABIC LIGATURE SEEN WITH JEEM WITH ALEF MAKSURA FINAL FORM
FD5F ARABIC LIGATURE SEEN WITH MEEM WITH HAH FINAL FORM
FD60 ARABIC LIGATURE SEEN WITH MEEM WITH HAH INITIAL FORM
FD61 ARABIC LIGATURE SEEN WITH MEEM WITH JEEM INITIAL FORM
FD62 ARABIC LIGATURE SEEN WITH MEEM WITH MEEM FINAL FORM
FD63 ARABIC LIGATURE SEEN WITH MEEM WITH MEEM INITIAL FORM
FD64 ARABIC LIGATURE SAD WITH HAH WITH HAH FINAL FORM
FD65 ARABIC LIGATURE SAD WITH HAH WITH HAH INITIAL FORM
FD66 ARABIC LIGATURE SAD WITH MEEM WITH MEEM FINAL FORM
FD67 ARABIC LIGATURE SHEEN WITH HAH WITH MEEM FINAL FORM
FD68 ARABIC LIGATURE SHEEN WITH HAH WITH MEEM INITIAL FORM
FD69 ARABIC LIGATURE SHEEN WITH JEEM WITH YEH FINAL FORM
FD6A ARABIC LIGATURE SHEEN WITH MEEM WITH KHAH FINAL FORM
FD6B ARABIC LIGATURE SHEEN WITH MEEM WITH KHAH INITIAL FORM
FD6C ARABIC LIGATURE SHEEN WITH MEEM WITH MEEM FINAL FORM
FD6D ARABIC LIGATURE SHEEN WITH MEEM WITH MEEM INITIAL FORM
FD6E ARABIC LIGATURE DAD WITH HAH WITH ALEF MAKSURA FINAL FORM
FD6F ARABIC LIGATURE DAD WITH KHAH WITH MEEM FINAL FORM
FD70 ARABIC LIGATURE DAD WITH KHAH WITH MEEM INITIAL FORM
FD71 ARABIC LIGATURE TAH WITH MEEM WITH HAH FINAL FORM
FD72 ARABIC LIGATURE TAH WITH MEEM WITH HAH INITIAL FORM
FD73 ARABIC LIGATURE TAH WITH MEEM WITH MEEM INITIAL FORM
FD74 ARABIC LIGATURE TAH WITH MEEM WITH YEH FINAL FORM
FD75 ARABIC LIGATURE AIN WITH JEEM WITH MEEM FINAL FORM
FD76 ARABIC LIGATURE AIN WITH MEEM WITH MEEM FINAL FORM
FD77 ARABIC LIGATURE AIN WITH MEEM WITH MEEM INITIAL FORM
FD78 ARABIC LIGATURE AIN WITH MEEM WITH ALEF MAKSURA FINAL FORM
FD79 ARABIC LIGATURE GHAIN WITH MEEM WITH MEEM FINAL FORM
FD7A ARABIC LIGATURE GHAIN WITH MEEM WITH YEH FINAL FORM
FD7B ARABIC LIGATURE GHAIN WITH MEEM WITH ALEF MAKSURA FINAL FORM
FD7C ARABIC LIGATURE FEH WITH KHAH WITH MEEM FINAL FORM
FD7D ARABIC LIGATURE FEH WITH KHAH WITH MEEM INITIAL FORM
FD7E ARABIC LIGATURE QAF WITH MEEM WITH HAH FINAL FORM
FD7F ARABIC LIGATURE QAF WITH MEEM WITH MEEM FINAL FORM
FD80 ARABIC LIGATURE LAM WITH HAH WITH MEEM FINAL FORM
FD81 ARABIC LIGATURE LAM WITH HAH WITH YEH FINAL FORM
FD82 ARABIC LIGATURE LAM WITH HAH WITH ALEF MAKSURA FINAL FORM
FD83 ARABIC LIGATURE LAM WITH JEEM WITH JEEM INITIAL FORM
FD84 ARABIC LIGATURE LAM WITH JEEM WITH JEEM FINAL FORM
FD85 ARABIC LIGATURE LAM WITH KHAH WITH MEEM FINAL FORM
FD86 ARABIC LIGATURE LAM WITH KHAH WITH MEEM INITIAL FORM
FD87 ARABIC LIGATURE LAM WITH MEEM WITH HAH FINAL FORM
FD88 ARABIC LIGATURE LAM WITH MEEM WITH HAH INITIAL FORM
FD89 ARABIC LIGATURE MEEM WITH HAH WITH JEEM INITIAL FORM
FD8A ARABIC LIGATURE MEEM WITH HAH WITH MEEM INITIAL FORM
FD8B ARABIC LIGATURE MEEM WITH HAH WITH YEH FINAL FORM
FD8C ARABIC LIGATURE MEEM WITH JEEM WITH HAH INITIAL FORM
FD8D ARABIC LIGATURE MEEM WITH JEEM WITH MEEM INITIAL FORM
FD8E ARABIC LIGATURE MEEM WITH KHAH WITH JEEM INITIAL FORM
FD8F ARABIC LIGATURE MEEM WITH KHAH WITH MEEM INITIAL FORM
FD92 ARABIC LIGATURE MEEM WITH JEEM WITH KHAH INITIAL FORM
FD93 ARABIC LIGATURE HEH WITH MEEM WITH JEEM INITIAL FORM
FD94 ARABIC LIGATURE HEH WITH MEEM WITH MEEM INITIAL FORM
FD95 ARABIC LIGATURE NOON WITH HAH WITH MEEM INITIAL FORM
FD96 ARABIC LIGATURE NOON WITH HAH WITH ALEF MAKSURA FINAL FORM
FD97 ARABIC LIGATURE NOON WITH JEEM WITH MEEM FINAL FORM
FD98 ARABIC LIGATURE NOON WITH JEEM WITH MEEM INITIAL FORM
FD99 ARABIC LIGATURE NOON WITH JEEM WITH ALEF MAKSURA FINAL FORM
FD9A ARABIC LIGATURE NOON WITH MEEM WITH YEH FINAL FORM
FD9B ARABIC LIGATURE NOON WITH MEEM WITH ALEF MAKSURA FINAL FORM
FD9C ARABIC LIGATURE YEH WITH MEEM WITH MEEM FINAL FORM
FD9D ARABIC LIGATURE YEH WITH MEEM WITH MEEM INITIAL FORM
FD9E ARABIC LIGATURE BEH WITH KHAH WITH YEH FINAL FORM
FD9F ARABIC LIGATURE TEH WITH JEEM WITH YEH FINAL FORM
FDA0 ARABIC LIGATURE TEH WITH JEEM WITH ALEF MAKSURA FINAL FORM
FDA1 ARABIC LIGATURE TEH WITH KHAH WITH YEH FINAL FORM
FDA2 ARABIC LIGATURE TEH WITH KHAH WITH ALEF MAKSURA FINAL FORM
FDA3 ARABIC LIGATURE TEH WITH MEEM WITH YEH FINAL FORM
FDA4 ARABIC LIGATURE TEH WITH MEEM WITH ALEF MAKSURA FINAL FORM
FDA5 ARABIC LIGATURE JEEM WITH MEEM WITH YEH FINAL FORM
FDA6 ARABIC LIGATURE JEEM WITH HAH WITH ALEF MAKSURA FINAL FORM
FDA7 ARABIC LIGATURE JEEM WITH MEEM WITH ALEF MAKSURA FINAL FORM
FDA8 ARABIC LIGATURE SEEN WITH KHAH WITH ALEF MAKSURA FINAL FORM
FDA9 ARABIC LIGATURE SAD WITH HAH WITH YEH FINAL FORM
FDAA ARABIC LIGATURE SHEEN WITH HAH WITH YEH FINAL FORM
FDAB ARABIC LIGATURE DAD WITH HAH WITH YEH FINAL FORM
FDAC ARABIC LIGATURE LAM WITH JEEM WITH YEH FINAL FORM
FDAD ARABIC LIGATURE LAM WITH MEEM WITH YEH FINAL FORM
FDAE ARABIC LIGATURE YEH WITH HAH WITH YEH FINAL FORM
FDAF ARABIC LIGATURE YEH WITH JEEM WITH YEH FINAL FORM
FDB0 ARABIC LIGATURE YEH WITH MEEM WITH YEH FINAL FORM
FDB1 ARABIC LIGATURE MEEM WITH MEEM WITH YEH FINAL FORM
FDB2 ARABIC LIGATURE QAF WITH MEEM WITH YEH FINAL FORM
FDB3 ARABIC LIGATURE NOON WITH HAH WITH YEH FINAL FORM
FDB4 ARABIC LIGATURE QAF WITH MEEM WITH HAH INITIAL FORM
FDB5 ARABIC LIGATURE LAM WITH HAH WITH MEEM INITIAL FORM
FDB6 ARABIC LIGATURE AIN WITH MEEM WITH YEH FINAL FORM
FDB7 ARABIC LIGATURE KAF WITH MEEM WITH YEH FINAL FORM
FDB8 ARABIC LIGATURE NOON WITH JEEM WITH HAH INITIAL FORM
FDB9 ARABIC LIGATURE MEEM WITH KHAH WITH YEH FINAL FORM
FDBA ARABIC LIGATURE LAM WITH JEEM WITH MEEM INITIAL FORM
FDBB ARABIC LIGATURE KAF WITH MEEM WITH MEEM FINAL FORM
FDBC ARABIC LIGATURE LAM WITH JEEM WITH MEEM FINAL FORM
FDBD ARABIC LIGATURE NOON WITH JEEM WITH HAH FINAL FORM
FDBE ARABIC LIGATURE JEEM WITH HAH WITH YEH FINAL FORM
FDBF ARABIC LIGATURE HAH WITH JEEM WITH YEH FINAL FORM
FDC0 ARABIC LIGATURE MEEM WITH JEEM WITH YEH FINAL FORM
FDC1 ARABIC LIGATURE FEH WITH MEEM WITH YEH FINAL FORM
FDC2 ARABIC LIGATURE BEH WITH HAH WITH YEH FINAL FORM
FDC3 ARABIC LIGATURE KAF WITH MEEM WITH MEEM INITIAL FORM
FDC4 ARABIC LIGATURE AIN WITH JEEM WITH MEEM INITIAL FORM
FDC5 ARABIC LIGATURE SAD WITH MEEM WITH MEEM INITIAL FORM
FDC6 ARABIC LIGATURE SEEN WITH KHAH WITH YEH FINAL FORM
FDC7 ARABIC LIGATURE NOON WITH JEEM WITH YEH FINAL FORM
FDF0 ARABIC LIGATURE SALLA USED AS KORANIC STOP SIGN ISOLATED FORM
FDF1 ARABIC LIGATURE QALA USED AS KORANIC STOP SIGN ISOLATED FORM
FDF2 ARABIC LIGATURE ALLAH ISOLATED FORM
FDF3 ARABIC LIGATURE AKBAR ISOLATED FORM
FDF4 ARABIC LIGATURE MOHAMMAD ISOLATED FORM
FDF5 ARABIC LIGATURE SALAM ISOLATED FORM
FDF6 ARABIC LIGATURE RASOUL ISOLATED FORM
FDF7 ARABIC LIGATURE ALAYHE ISOLATED FORM
FDF8 ARABIC LIGATURE WASALLAM ISOLATED FORM
FDF9 ARABIC LIGATURE SALLA ISOLATED FORM
FDFA ARABIC LIGATURE SALLALLAHOU ALAYHE WASALLAM
FDFB ARABIC LIGATURE JALLAJALALOUHOU
FDFC RIAL SIGN
FDFD ARABIC LIGATURE BISMILLAH AR-RAHMAN AR-RAHEEM
FE00 VARIATION SELECTOR-1
FE01 VARIATION SELECTOR-2
FE02 VARIATION SELECTOR-3
FE03 VARIATION SELECTOR-4
FE04 VARIATION SELECTOR-5
FE05 VARIATION SELECTOR-6
FE06 VARIATION SELECTOR-7
FE07 VARIATION SELECTOR-8
FE08 VARIATION SELECTOR-9
FE09 VARIATION SELECTOR-10
FE0A VARIATION SELECTOR-11
FE0B VARIATION SELECTOR-12
FE0C VARIATION SELECTOR-13
FE0D VARIATION SELECTOR-14
FE0E VARIATION SELECTOR-15
FE0F VARIATION SELECTOR-16
FE10 PRESENTATION FORM FOR VERTICAL COMMA
FE11 PRESENTATION FORM FOR VERTICAL IDEOGRAPHIC COMMA
FE12 PRESENTATION FORM FOR VERTICAL IDEOGRAPHIC FULL STOP
FE13 PRESENTATION FORM FOR VERTICAL COLON
FE14 PRESENTATION FORM FOR VERTICAL SEMICOLON
FE15 PRESENTATION FORM FOR VERTICAL EXCLAMATION MARK
FE16 PRESENTATION FORM FOR VERTICAL QUESTION MARK
FE17 PRESENTATION FORM FOR VERTICAL LEFT WHITE LENTICULAR BRACKET
FE18 PRESENTATION FORM FOR VERTICAL RIGHT WHITE LENTICULAR BRAKCET
FE19 PRESENTATION FORM FOR VERTICAL HORIZONTAL ELLIPSIS
FE20 COMBINING LIGATURE LEFT HALF
FE21 COMBINING LIGATURE RIGHT HALF
FE22 COMBINING DOUBLE TILDE LEFT HALF
FE23 COMBINING DOUBLE TILDE RIGHT HALF
FE30 PRESENTATION FORM FOR VERTICAL TWO DOT LEADER
FE31 PRESENTATION FORM FOR VERTICAL EM DASH
FE32 PRESENTATION FORM FOR VERTICAL EN DASH
FE33 PRESENTATION FORM FOR VERTICAL LOW LINE
FE34 PRESENTATION FORM FOR VERTICAL WAVY LOW LINE
FE35 PRESENTATION FORM FOR VERTICAL LEFT PARENTHESIS
FE36 PRESENTATION FORM FOR VERTICAL RIGHT PARENTHESIS
FE37 PRESENTATION FORM FOR VERTICAL LEFT CURLY BRACKET
FE38 PRESENTATION FORM FOR VERTICAL RIGHT CURLY BRACKET
FE39 PRESENTATION FORM FOR VERTICAL LEFT TORTOISE SHELL BRACKET
FE3A PRESENTATION FORM FOR VERTICAL RIGHT TORTOISE SHELL BRACKET
FE3B PRESENTATION FORM FOR VERTICAL LEFT BLACK LENTICULAR BRACKET
FE3C PRESENTATION FORM FOR VERTICAL RIGHT BLACK LENTICULAR BRACKET
FE3D PRESENTATION FORM FOR VERTICAL LEFT DOUBLE ANGLE BRACKET
FE3E PRESENTATION FORM FOR VERTICAL RIGHT DOUBLE ANGLE BRACKET
FE3F PRESENTATION FORM FOR VERTICAL LEFT ANGLE BRACKET
FE40 PRESENTATION FORM FOR VERTICAL RIGHT ANGLE BRACKET
FE41 PRESENTATION FORM FOR VERTICAL LEFT CORNER BRACKET
FE42 PRESENTATION FORM FOR VERTICAL RIGHT CORNER BRACKET
FE43 PRESENTATION FORM FOR VERTICAL LEFT WHITE CORNER BRACKET
FE44 PRESENTATION FORM FOR VERTICAL RIGHT WHITE CORNER BRACKET
FE45 SESAME DOT
FE46 WHITE SESAME DOT
FE47 PRESENTATION FORM FOR VERTICAL LEFT SQUARE BRACKET
FE48 PRESENTATION FORM FOR VERTICAL RIGHT SQUARE BRACKET
FE49 DASHED OVERLINE
FE4A CENTRELINE OVERLINE
FE4B WAVY OVERLINE
FE4C DOUBLE WAVY OVERLINE
FE4D DASHED LOW LINE
FE4E CENTRELINE LOW LINE
FE4F WAVY LOW LINE
FE50 SMALL COMMA
FE51 SMALL IDEOGRAPHIC COMMA
FE52 SMALL FULL STOP
FE54 SMALL SEMICOLON
FE55 SMALL COLON
FE56 SMALL QUESTION MARK
FE57 SMALL EXCLAMATION MARK
FE58 SMALL EM DASH
FE59 SMALL LEFT PARENTHESIS
FE5A SMALL RIGHT PARENTHESIS
FE5B SMALL LEFT CURLY BRACKET
FE5C SMALL RIGHT CURLY BRACKET
FE5D SMALL LEFT TORTOISE SHELL BRACKET
FE5E SMALL RIGHT TORTOISE SHELL BRACKET
FE5F SMALL NUMBER SIGN
FE60 SMALL AMPERSAND
FE61 SMALL ASTERISK
FE62 SMALL PLUS SIGN
FE63 SMALL HYPHEN-MINUS
FE64 SMALL LESS-THAN SIGN
FE65 SMALL GREATER-THAN SIGN
FE66 SMALL EQUALS SIGN
FE68 SMALL REVERSE SOLIDUS
FE69 SMALL DOLLAR SIGN
FE6A SMALL PERCENT SIGN
FE6B SMALL COMMERCIAL AT
FE70 ARABIC FATHATAN ISOLATED FORM
FE71 ARABIC TATWEEL WITH FATHATAN ABOVE
FE72 ARABIC DAMMATAN ISOLATED FORM
FE73 ARABIC TAIL FRAGMENT
FE74 ARABIC KASRATAN ISOLATED FORM
FE76 ARABIC FATHA ISOLATED FORM
FE77 ARABIC FATHA MEDIAL FORM
FE78 ARABIC DAMMA ISOLATED FORM
FE79 ARABIC DAMMA MEDIAL FORM
FE7A ARABIC KASRA ISOLATED FORM
FE7B ARABIC KASRA MEDIAL FORM
FE7C ARABIC SHADDA ISOLATED FORM
FE7D ARABIC SHADDA MEDIAL FORM
FE7E ARABIC SUKUN ISOLATED FORM
FE7F ARABIC SUKUN MEDIAL FORM
FE80 ARABIC LETTER HAMZA ISOLATED FORM
FE81 ARABIC LETTER ALEF WITH MADDA ABOVE ISOLATED FORM
FE82 ARABIC LETTER ALEF WITH MADDA ABOVE FINAL FORM
FE83 ARABIC LETTER ALEF WITH HAMZA ABOVE ISOLATED FORM
FE84 ARABIC LETTER ALEF WITH HAMZA ABOVE FINAL FORM
FE85 ARABIC LETTER WAW WITH HAMZA ABOVE ISOLATED FORM
FE86 ARABIC LETTER WAW WITH HAMZA ABOVE FINAL FORM
FE87 ARABIC LETTER ALEF WITH HAMZA BELOW ISOLATED FORM
FE88 ARABIC LETTER ALEF WITH HAMZA BELOW FINAL FORM
FE89 ARABIC LETTER YEH WITH HAMZA ABOVE ISOLATED FORM
FE8A ARABIC LETTER YEH WITH HAMZA ABOVE FINAL FORM
FE8B ARABIC LETTER YEH WITH HAMZA ABOVE INITIAL FORM
FE8C ARABIC LETTER YEH WITH HAMZA ABOVE MEDIAL FORM
FE8D ARABIC LETTER ALEF ISOLATED FORM
FE8E ARABIC LETTER ALEF FINAL FORM
FE8F ARABIC LETTER BEH ISOLATED FORM
FE90 ARABIC LETTER BEH FINAL FORM
FE91 ARABIC LETTER BEH INITIAL FORM
FE92 ARABIC LETTER BEH MEDIAL FORM
FE93 ARABIC LETTER TEH MARBUTA ISOLATED FORM
FE94 ARABIC LETTER TEH MARBUTA FINAL FORM
FE95 ARABIC LETTER TEH ISOLATED FORM
FE96 ARABIC LETTER TEH FINAL FORM
FE97 ARABIC LETTER TEH INITIAL FORM
FE98 ARABIC LETTER TEH MEDIAL FORM
FE99 ARABIC LETTER THEH ISOLATED FORM
FE9A ARABIC LETTER THEH FINAL FORM
FE9B ARABIC LETTER THEH INITIAL FORM
FE9C ARABIC LETTER THEH MEDIAL FORM
FE9D ARABIC LETTER JEEM ISOLATED FORM
FE9E ARABIC LETTER JEEM FINAL FORM
FE9F ARABIC LETTER JEEM INITIAL FORM
FEA0 ARABIC LETTER JEEM MEDIAL FORM
FEA1 ARABIC LETTER HAH ISOLATED FORM
FEA2 ARABIC LETTER HAH FINAL FORM
FEA3 ARABIC LETTER HAH INITIAL FORM
FEA4 ARABIC LETTER HAH MEDIAL FORM
FEA5 ARABIC LETTER KHAH ISOLATED FORM
FEA6 ARABIC LETTER KHAH FINAL FORM
FEA7 ARABIC LETTER KHAH INITIAL FORM
FEA8 ARABIC LETTER KHAH MEDIAL FORM
FEA9 ARABIC LETTER DAL ISOLATED FORM
FEAA ARABIC LETTER DAL FINAL FORM
FEAB ARABIC LETTER THAL ISOLATED FORM
FEAC ARABIC LETTER THAL FINAL FORM
FEAD ARABIC LETTER REH ISOLATED FORM
FEAE ARABIC LETTER REH FINAL FORM
FEAF ARABIC LETTER ZAIN ISOLATED FORM
FEB0 ARABIC LETTER ZAIN FINAL FORM
FEB1 ARABIC LETTER SEEN ISOLATED FORM
FEB2 ARABIC LETTER SEEN FINAL FORM
FEB3 ARABIC LETTER SEEN INITIAL FORM
FEB4 ARABIC LETTER SEEN MEDIAL FORM
FEB5 ARABIC LETTER SHEEN ISOLATED FORM
FEB6 ARABIC LETTER SHEEN FINAL FORM
FEB7 ARABIC LETTER SHEEN INITIAL FORM
FEB8 ARABIC LETTER SHEEN MEDIAL FORM
FEB9 ARABIC LETTER SAD ISOLATED FORM
FEBA ARABIC LETTER SAD FINAL FORM
FEBB ARABIC LETTER SAD INITIAL FORM
FEBC ARABIC LETTER SAD MEDIAL FORM
FEBD ARABIC LETTER DAD ISOLATED FORM
FEBE ARABIC LETTER DAD FINAL FORM
FEBF ARABIC LETTER DAD INITIAL FORM
FEC0 ARABIC LETTER DAD MEDIAL FORM
FEC1 ARABIC LETTER TAH ISOLATED FORM
FEC2 ARABIC LETTER TAH FINAL FORM
FEC3 ARABIC LETTER TAH INITIAL FORM
FEC4 ARABIC LETTER TAH MEDIAL FORM
FEC5 ARABIC LETTER ZAH ISOLATED FORM
FEC6 ARABIC LETTER ZAH FINAL FORM
FEC7 ARABIC LETTER ZAH INITIAL FORM
FEC8 ARABIC LETTER ZAH MEDIAL FORM
FEC9 ARABIC LETTER AIN ISOLATED FORM
FECA ARABIC LETTER AIN FINAL FORM
FECB ARABIC LETTER AIN INITIAL FORM
FECC ARABIC LETTER AIN MEDIAL FORM
FECD ARABIC LETTER GHAIN ISOLATED FORM
FECE ARABIC LETTER GHAIN FINAL FORM
FECF ARABIC LETTER GHAIN INITIAL FORM
FED0 ARABIC LETTER GHAIN MEDIAL FORM
FED1 ARABIC LETTER FEH ISOLATED FORM
FED2 ARABIC LETTER FEH FINAL FORM
FED3 ARABIC LETTER FEH INITIAL FORM
FED4 ARABIC LETTER FEH MEDIAL FORM
FED5 ARABIC LETTER QAF ISOLATED FORM
FED6 ARABIC LETTER QAF FINAL FORM
FED7 ARABIC LETTER QAF INITIAL FORM
FED8 ARABIC LETTER QAF MEDIAL FORM
FED9 ARABIC LETTER KAF ISOLATED FORM
FEDA ARABIC LETTER KAF FINAL FORM
FEDB ARABIC LETTER KAF INITIAL FORM
FEDC ARABIC LETTER KAF MEDIAL FORM
FEDD ARABIC LETTER LAM ISOLATED FORM
FEDE ARABIC LETTER LAM FINAL FORM
FEDF ARABIC LETTER LAM INITIAL FORM
FEE0 ARABIC LETTER LAM MEDIAL FORM
FEE1 ARABIC LETTER MEEM ISOLATED FORM
FEE2 ARABIC LETTER MEEM FINAL FORM
FEE3 ARABIC LETTER MEEM INITIAL FORM
FEE4 ARABIC LETTER MEEM MEDIAL FORM
FEE5 ARABIC LETTER NOON ISOLATED FORM
FEE6 ARABIC LETTER NOON FINAL FORM
FEE7 ARABIC LETTER NOON INITIAL FORM
FEE8 ARABIC LETTER NOON MEDIAL FORM
FEE9 ARABIC LETTER HEH ISOLATED FORM
FEEA ARABIC LETTER HEH FINAL FORM
FEEB ARABIC LETTER HEH INITIAL FORM
FEEC ARABIC LETTER HEH MEDIAL FORM
FEED ARABIC LETTER WAW ISOLATED FORM
FEEE ARABIC LETTER WAW FINAL FORM
FEEF ARABIC LETTER ALEF MAKSURA ISOLATED FORM
FEF0 ARABIC LETTER ALEF MAKSURA FINAL FORM
FEF1 ARABIC LETTER YEH ISOLATED FORM
FEF2 ARABIC LETTER YEH FINAL FORM
FEF3 ARABIC LETTER YEH INITIAL FORM
FEF4 ARABIC LETTER YEH MEDIAL FORM
FEF5 ARABIC LIGATURE LAM WITH ALEF WITH MADDA ABOVE ISOLATED FORM
FEF6 ARABIC LIGATURE LAM WITH ALEF WITH MADDA ABOVE FINAL FORM
FEF7 ARABIC LIGATURE LAM WITH ALEF WITH HAMZA ABOVE ISOLATED FORM
FEF8 ARABIC LIGATURE LAM WITH ALEF WITH HAMZA ABOVE FINAL FORM
FEF9 ARABIC LIGATURE LAM WITH ALEF WITH HAMZA BELOW ISOLATED FORM
FEFA ARABIC LIGATURE LAM WITH ALEF WITH HAMZA BELOW FINAL FORM
FEFB ARABIC LIGATURE LAM WITH ALEF ISOLATED FORM
FEFC ARABIC LIGATURE LAM WITH ALEF FINAL FORM
FEFF ZERO WIDTH NO-BREAK SPACE
FF01 FULLWIDTH EXCLAMATION MARK
FF02 FULLWIDTH QUOTATION MARK
FF03 FULLWIDTH NUMBER SIGN
FF04 FULLWIDTH DOLLAR SIGN
FF05 FULLWIDTH PERCENT SIGN
FF06 FULLWIDTH AMPERSAND
FF07 FULLWIDTH APOSTROPHE
FF08 FULLWIDTH LEFT PARENTHESIS
FF09 FULLWIDTH RIGHT PARENTHESIS
FF0A FULLWIDTH ASTERISK
FF0B FULLWIDTH PLUS SIGN
FF0C FULLWIDTH COMMA
FF0D FULLWIDTH HYPHEN-MINUS
FF0E FULLWIDTH FULL STOP
FF0F FULLWIDTH SOLIDUS
FF10 FULLWIDTH DIGIT ZERO
FF11 FULLWIDTH DIGIT ONE
FF12 FULLWIDTH DIGIT TWO
FF13 FULLWIDTH DIGIT THREE
FF14 FULLWIDTH DIGIT FOUR
FF15 FULLWIDTH DIGIT FIVE
FF16 FULLWIDTH DIGIT SIX
FF17 FULLWIDTH DIGIT SEVEN
FF18 FULLWIDTH DIGIT EIGHT
FF19 FULLWIDTH DIGIT NINE
FF1A FULLWIDTH COLON
FF1B FULLWIDTH SEMICOLON
FF1C FULLWIDTH LESS-THAN SIGN
FF1D FULLWIDTH EQUALS SIGN
FF1E FULLWIDTH GREATER-THAN SIGN
FF1F FULLWIDTH QUESTION MARK
FF20 FULLWIDTH COMMERCIAL AT
FF21 FULLWIDTH LATIN CAPITAL LETTER A
FF22 FULLWIDTH LATIN CAPITAL LETTER B
FF23 FULLWIDTH LATIN CAPITAL LETTER C
FF24 FULLWIDTH LATIN CAPITAL LETTER D
FF25 FULLWIDTH LATIN CAPITAL LETTER E
FF26 FULLWIDTH LATIN CAPITAL LETTER F
FF27 FULLWIDTH LATIN CAPITAL LETTER G
FF28 FULLWIDTH LATIN CAPITAL LETTER H
FF29 FULLWIDTH LATIN CAPITAL LETTER I
FF2A FULLWIDTH LATIN CAPITAL LETTER J
FF2B FULLWIDTH LATIN CAPITAL LETTER K
FF2C FULLWIDTH LATIN CAPITAL LETTER L
FF2D FULLWIDTH LATIN CAPITAL LETTER M
FF2E FULLWIDTH LATIN CAPITAL LETTER N
FF2F FULLWIDTH LATIN CAPITAL LETTER O
FF30 FULLWIDTH LATIN CAPITAL LETTER P
FF31 FULLWIDTH LATIN CAPITAL LETTER Q
FF32 FULLWIDTH LATIN CAPITAL LETTER R
FF33 FULLWIDTH LATIN CAPITAL LETTER S
FF34 FULLWIDTH LATIN CAPITAL LETTER T
FF35 FULLWIDTH LATIN CAPITAL LETTER U
FF36 FULLWIDTH LATIN CAPITAL LETTER V
FF37 FULLWIDTH LATIN CAPITAL LETTER W
FF38 FULLWIDTH LATIN CAPITAL LETTER X
FF39 FULLWIDTH LATIN CAPITAL LETTER Y
FF3A FULLWIDTH LATIN CAPITAL LETTER Z
FF3B FULLWIDTH LEFT SQUARE BRACKET
FF3C FULLWIDTH REVERSE SOLIDUS
FF3D FULLWIDTH RIGHT SQUARE BRACKET
FF3E FULLWIDTH CIRCUMFLEX ACCENT
FF3F FULLWIDTH LOW LINE
FF40 FULLWIDTH GRAVE ACCENT
FF41 FULLWIDTH LATIN SMALL LETTER A
FF42 FULLWIDTH LATIN SMALL LETTER B
FF43 FULLWIDTH LATIN SMALL LETTER C
FF44 FULLWIDTH LATIN SMALL LETTER D
FF45 FULLWIDTH LATIN SMALL LETTER E
FF46 FULLWIDTH LATIN SMALL LETTER F
FF47 FULLWIDTH LATIN SMALL LETTER G
FF48 FULLWIDTH LATIN SMALL LETTER H
FF49 FULLWIDTH LATIN SMALL LETTER I
FF4A FULLWIDTH LATIN SMALL LETTER J
FF4B FULLWIDTH LATIN SMALL LETTER K
FF4C FULLWIDTH LATIN SMALL LETTER L
FF4D FULLWIDTH LATIN SMALL LETTER M
FF4E FULLWIDTH LATIN SMALL LETTER N
FF4F FULLWIDTH LATIN SMALL LETTER O
FF50 FULLWIDTH LATIN SMALL LETTER P
FF51 FULLWIDTH LATIN SMALL LETTER Q
FF52 FULLWIDTH LATIN SMALL LETTER R
FF53 FULLWIDTH LATIN SMALL LETTER S
FF54 FULLWIDTH LATIN SMALL LETTER T
FF55 FULLWIDTH LATIN SMALL LETTER U
FF56 FULLWIDTH LATIN SMALL LETTER V
FF57 FULLWIDTH LATIN SMALL LETTER W
FF58 FULLWIDTH LATIN SMALL LETTER X
FF59 FULLWIDTH LATIN SMALL LETTER Y
FF5A FULLWIDTH LATIN SMALL LETTER Z
FF5B FULLWIDTH LEFT CURLY BRACKET
FF5C FULLWIDTH VERTICAL LINE
FF5D FULLWIDTH RIGHT CURLY BRACKET
FF5E FULLWIDTH TILDE
FF5F FULLWIDTH LEFT WHITE PARENTHESIS
FF60 FULLWIDTH RIGHT WHITE PARENTHESIS
FF61 HALFWIDTH IDEOGRAPHIC FULL STOP
FF62 HALFWIDTH LEFT CORNER BRACKET
FF63 HALFWIDTH RIGHT CORNER BRACKET
FF64 HALFWIDTH IDEOGRAPHIC COMMA
FF65 HALFWIDTH KATAKANA MIDDLE DOT
FF66 HALFWIDTH KATAKANA LETTER WO
FF67 HALFWIDTH KATAKANA LETTER SMALL A
FF68 HALFWIDTH KATAKANA LETTER SMALL I
FF69 HALFWIDTH KATAKANA LETTER SMALL U
FF6A HALFWIDTH KATAKANA LETTER SMALL E
FF6B HALFWIDTH KATAKANA LETTER SMALL O
FF6C HALFWIDTH KATAKANA LETTER SMALL YA
FF6D HALFWIDTH KATAKANA LETTER SMALL YU
FF6E HALFWIDTH KATAKANA LETTER SMALL YO
FF6F HALFWIDTH KATAKANA LETTER SMALL TU
FF70 HALFWIDTH KATAKANA-HIRAGANA PROLONGED SOUND MARK
FF71 HALFWIDTH KATAKANA LETTER A
FF72 HALFWIDTH KATAKANA LETTER I
FF73 HALFWIDTH KATAKANA LETTER U
FF74 HALFWIDTH KATAKANA LETTER E
FF75 HALFWIDTH KATAKANA LETTER O
FF76 HALFWIDTH KATAKANA LETTER KA
FF77 HALFWIDTH KATAKANA LETTER KI
FF78 HALFWIDTH KATAKANA LETTER KU
FF79 HALFWIDTH KATAKANA LETTER KE
FF7A HALFWIDTH KATAKANA LETTER KO
FF7B HALFWIDTH KATAKANA LETTER SA
FF7C HALFWIDTH KATAKANA LETTER SI
FF7D HALFWIDTH KATAKANA LETTER SU
FF7E HALFWIDTH KATAKANA LETTER SE
FF7F HALFWIDTH KATAKANA LETTER SO
FF80 HALFWIDTH KATAKANA LETTER TA
FF81 HALFWIDTH KATAKANA LETTER TI
FF82 HALFWIDTH KATAKANA LETTER TU
FF83 HALFWIDTH KATAKANA LETTER TE
FF84 HALFWIDTH KATAKANA LETTER TO
FF85 HALFWIDTH KATAKANA LETTER NA
FF86 HALFWIDTH KATAKANA LETTER NI
FF87 HALFWIDTH KATAKANA LETTER NU
FF88 HALFWIDTH KATAKANA LETTER NE
FF89 HALFWIDTH KATAKANA LETTER NO
FF8A HALFWIDTH KATAKANA LETTER HA
FF8B HALFWIDTH KATAKANA LETTER HI
FF8C HALFWIDTH KATAKANA LETTER HU
FF8D HALFWIDTH KATAKANA LETTER HE
FF8E HALFWIDTH KATAKANA LETTER HO
FF8F HALFWIDTH KATAKANA LETTER MA
FF90 HALFWIDTH KATAKANA LETTER MI
FF91 HALFWIDTH KATAKANA LETTER MU
FF92 HALFWIDTH KATAKANA LETTER ME
FF93 HALFWIDTH KATAKANA LETTER MO
FF94 HALFWIDTH KATAKANA LETTER YA
FF95 HALFWIDTH KATAKANA LETTER YU
FF96 HALFWIDTH KATAKANA LETTER YO
FF97 HALFWIDTH KATAKANA LETTER RA
FF98 HALFWIDTH KATAKANA LETTER RI
FF99 HALFWIDTH KATAKANA LETTER RU
FF9A HALFWIDTH KATAKANA LETTER RE
FF9B HALFWIDTH KATAKANA LETTER RO
FF9C HALFWIDTH KATAKANA LETTER WA
FF9D HALFWIDTH KATAKANA LETTER N
FF9E HALFWIDTH KATAKANA VOICED SOUND MARK
FF9F HALFWIDTH KATAKANA SEMI-VOICED SOUND MARK
FFA0 HALFWIDTH HANGUL FILLER
FFA1 HALFWIDTH HANGUL LETTER KIYEOK
FFA2 HALFWIDTH HANGUL LETTER SSANGKIYEOK
FFA3 HALFWIDTH HANGUL LETTER KIYEOK-SIOS
FFA4 HALFWIDTH HANGUL LETTER NIEUN
FFA5 HALFWIDTH HANGUL LETTER NIEUN-CIEUC
FFA6 HALFWIDTH HANGUL LETTER NIEUN-HIEUH
FFA7 HALFWIDTH HANGUL LETTER TIKEUT
FFA8 HALFWIDTH HANGUL LETTER SSANGTIKEUT
FFA9 HALFWIDTH HANGUL LETTER RIEUL
FFAA HALFWIDTH HANGUL LETTER RIEUL-KIYEOK
FFAB HALFWIDTH HANGUL LETTER RIEUL-MIEUM
FFAC HALFWIDTH HANGUL LETTER RIEUL-PIEUP
FFAD HALFWIDTH HANGUL LETTER RIEUL-SIOS
FFAE HALFWIDTH HANGUL LETTER RIEUL-THIEUTH
FFAF HALFWIDTH HANGUL LETTER RIEUL-PHIEUPH
FFB0 HALFWIDTH HANGUL LETTER RIEUL-HIEUH
FFB1 HALFWIDTH HANGUL LETTER MIEUM
FFB2 HALFWIDTH HANGUL LETTER PIEUP
FFB3 HALFWIDTH HANGUL LETTER SSANGPIEUP
FFB4 HALFWIDTH HANGUL LETTER PIEUP-SIOS
FFB5 HALFWIDTH HANGUL LETTER SIOS
FFB6 HALFWIDTH HANGUL LETTER SSANGSIOS
FFB7 HALFWIDTH HANGUL LETTER IEUNG
FFB8 HALFWIDTH HANGUL LETTER CIEUC
FFB9 HALFWIDTH HANGUL LETTER SSANGCIEUC
FFBA HALFWIDTH HANGUL LETTER CHIEUCH
FFBB HALFWIDTH HANGUL LETTER KHIEUKH
FFBC HALFWIDTH HANGUL LETTER THIEUTH
FFBD HALFWIDTH HANGUL LETTER PHIEUPH
FFBE HALFWIDTH HANGUL LETTER HIEUH
FFC2 HALFWIDTH HANGUL LETTER A
FFC3 HALFWIDTH HANGUL LETTER AE
FFC4 HALFWIDTH HANGUL LETTER YA
FFC5 HALFWIDTH HANGUL LETTER YAE
FFC6 HALFWIDTH HANGUL LETTER EO
FFC7 HALFWIDTH HANGUL LETTER E
FFCA HALFWIDTH HANGUL LETTER YEO
FFCB HALFWIDTH HANGUL LETTER YE
FFCC HALFWIDTH HANGUL LETTER O
FFCD HALFWIDTH HANGUL LETTER WA
FFCE HALFWIDTH HANGUL LETTER WAE
FFCF HALFWIDTH HANGUL LETTER OE
FFD2 HALFWIDTH HANGUL LETTER YO
FFD3 HALFWIDTH HANGUL LETTER U
FFD4 HALFWIDTH HANGUL LETTER WEO
FFD5 HALFWIDTH HANGUL LETTER WE
FFD6 HALFWIDTH HANGUL LETTER WI
FFD7 HALFWIDTH HANGUL LETTER YU
FFDA HALFWIDTH HANGUL LETTER EU
FFDB HALFWIDTH HANGUL LETTER YI
FFDC HALFWIDTH HANGUL LETTER I
FFE0 FULLWIDTH CENT SIGN
FFE1 FULLWIDTH POUND SIGN
FFE2 FULLWIDTH NOT SIGN
FFE3 FULLWIDTH MACRON
FFE4 FULLWIDTH BROKEN BAR
FFE5 FULLWIDTH YEN SIGN
FFE6 FULLWIDTH WON SIGN
FFE8 HALFWIDTH FORMS LIGHT VERTICAL
FFE9 HALFWIDTH LEFTWARDS ARROW
FFEA HALFWIDTH UPWARDS ARROW
FFEB HALFWIDTH RIGHTWARDS ARROW
FFEC HALFWIDTH DOWNWARDS ARROW
FFED HALFWIDTH BLACK SQUARE
FFEE HALFWIDTH WHITE CIRCLE
FFF9 INTERLINEAR ANNOTATION ANCHOR
FFFA INTERLINEAR ANNOTATION SEPARATOR
FFFB INTERLINEAR ANNOTATION TERMINATOR
FFFC OBJECT REPLACEMENT CHARACTER
FFFD REPLACEMENT CHARACTER
10000 LINEAR B SYLLABLE B008 A
10001 LINEAR B SYLLABLE B038 E
10002 LINEAR B SYLLABLE B028 I
10003 LINEAR B SYLLABLE B061 O
10004 LINEAR B SYLLABLE B010 U
10005 LINEAR B SYLLABLE B001 DA
10006 LINEAR B SYLLABLE B045 DE
10007 LINEAR B SYLLABLE B007 DI
10008 LINEAR B SYLLABLE B014 DO
10009 LINEAR B SYLLABLE B051 DU
1000A LINEAR B SYLLABLE B057 JA
1000B LINEAR B SYLLABLE B046 JE
1000D LINEAR B SYLLABLE B036 JO
1000E LINEAR B SYLLABLE B065 JU
1000F LINEAR B SYLLABLE B077 KA
10010 LINEAR B SYLLABLE B044 KE
10011 LINEAR B SYLLABLE B067 KI
10012 LINEAR B SYLLABLE B070 KO
10013 LINEAR B SYLLABLE B081 KU
10014 LINEAR B SYLLABLE B080 MA
10015 LINEAR B SYLLABLE B013 ME
10016 LINEAR B SYLLABLE B073 MI
10017 LINEAR B SYLLABLE B015 MO
10018 LINEAR B SYLLABLE B023 MU
10019 LINEAR B SYLLABLE B006 NA
1001A LINEAR B SYLLABLE B024 NE
1001B LINEAR B SYLLABLE B030 NI
1001C LINEAR B SYLLABLE B052 NO
1001D LINEAR B SYLLABLE B055 NU
1001E LINEAR B SYLLABLE B003 PA
1001F LINEAR B SYLLABLE B072 PE
10020 LINEAR B SYLLABLE B039 PI
10021 LINEAR B SYLLABLE B011 PO
10022 LINEAR B SYLLABLE B050 PU
10023 LINEAR B SYLLABLE B016 QA
10024 LINEAR B SYLLABLE B078 QE
10025 LINEAR B SYLLABLE B021 QI
10026 LINEAR B SYLLABLE B032 QO
10028 LINEAR B SYLLABLE B060 RA
10029 LINEAR B SYLLABLE B027 RE
1002A LINEAR B SYLLABLE B053 RI
1002B LINEAR B SYLLABLE B002 RO
1002C LINEAR B SYLLABLE B026 RU
1002D LINEAR B SYLLABLE B031 SA
1002E LINEAR B SYLLABLE B009 SE
1002F LINEAR B SYLLABLE B041 SI
10030 LINEAR B SYLLABLE B012 SO
10031 LINEAR B SYLLABLE B058 SU
10032 LINEAR B SYLLABLE B059 TA
10033 LINEAR B SYLLABLE B004 TE
10034 LINEAR B SYLLABLE B037 TI
10035 LINEAR B SYLLABLE B005 TO
10036 LINEAR B SYLLABLE B069 TU
10037 LINEAR B SYLLABLE B054 WA
10038 LINEAR B SYLLABLE B075 WE
10039 LINEAR B SYLLABLE B040 WI
1003A LINEAR B SYLLABLE B042 WO
1003C LINEAR B SYLLABLE B017 ZA
1003D LINEAR B SYLLABLE B074 ZE
1003F LINEAR B SYLLABLE B020 ZO
10040 LINEAR B SYLLABLE B025 A2
10041 LINEAR B SYLLABLE B043 A3
10042 LINEAR B SYLLABLE B085 AU
10043 LINEAR B SYLLABLE B071 DWE
10044 LINEAR B SYLLABLE B090 DWO
10045 LINEAR B SYLLABLE B048 NWA
10046 LINEAR B SYLLABLE B029 PU2
10047 LINEAR B SYLLABLE B062 PTE
10048 LINEAR B SYLLABLE B076 RA2
10049 LINEAR B SYLLABLE B033 RA3
1004A LINEAR B SYLLABLE B068 RO2
1004B LINEAR B SYLLABLE B066 TA2
1004C LINEAR B SYLLABLE B087 TWE
1004D LINEAR B SYLLABLE B091 TWO
10050 LINEAR B SYMBOL B018
10051 LINEAR B SYMBOL B019
10052 LINEAR B SYMBOL B022
10053 LINEAR B SYMBOL B034
10054 LINEAR B SYMBOL B047
10055 LINEAR B SYMBOL B049
10056 LINEAR B SYMBOL B056
10057 LINEAR B SYMBOL B063
10058 LINEAR B SYMBOL B064
10059 LINEAR B SYMBOL B079
1005A LINEAR B SYMBOL B082
1005B LINEAR B SYMBOL B083
1005C LINEAR B SYMBOL B086
1005D LINEAR B SYMBOL B089
10080 LINEAR B IDEOGRAM B100 MAN
10081 LINEAR B IDEOGRAM B102 WOMAN
10082 LINEAR B IDEOGRAM B104 DEER
10083 LINEAR B IDEOGRAM B105 EQUID
10084 LINEAR B IDEOGRAM B105F MARE
10085 LINEAR B IDEOGRAM B105M STALLION
10086 LINEAR B IDEOGRAM B106F EWE
10087 LINEAR B IDEOGRAM B106M RAM
10088 LINEAR B IDEOGRAM B107F SHE-GOAT
10089 LINEAR B IDEOGRAM B107M HE-GOAT
1008A LINEAR B IDEOGRAM B108F SOW
1008B LINEAR B IDEOGRAM B108M BOAR
1008C LINEAR B IDEOGRAM B109F COW
1008D LINEAR B IDEOGRAM B109M BULL
1008E LINEAR B IDEOGRAM B120 WHEAT
1008F LINEAR B IDEOGRAM B121 BARLEY
10090 LINEAR B IDEOGRAM B122 OLIVE
10091 LINEAR B IDEOGRAM B123 SPICE
10092 LINEAR B IDEOGRAM B125 CYPERUS
10093 LINEAR B MONOGRAM B127 KAPO
10094 LINEAR B MONOGRAM B128 KANAKO
10095 LINEAR B IDEOGRAM B130 OIL
10096 LINEAR B IDEOGRAM B131 WINE
10097 LINEAR B IDEOGRAM B132
10098 LINEAR B MONOGRAM B133 AREPA
10099 LINEAR B MONOGRAM B135 MERI
1009A LINEAR B IDEOGRAM B140 BRONZE
1009B LINEAR B IDEOGRAM B141 GOLD
1009C LINEAR B IDEOGRAM B142
1009D LINEAR B IDEOGRAM B145 WOOL
1009E LINEAR B IDEOGRAM B146
1009F LINEAR B IDEOGRAM B150
100A0 LINEAR B IDEOGRAM B151 HORN
100A1 LINEAR B IDEOGRAM B152
100A2 LINEAR B IDEOGRAM B153
100A3 LINEAR B IDEOGRAM B154
100A4 LINEAR B MONOGRAM B156 TURO2
100A5 LINEAR B IDEOGRAM B157
100A6 LINEAR B IDEOGRAM B158
100A7 LINEAR B IDEOGRAM B159 CLOTH
100A8 LINEAR B IDEOGRAM B160
100A9 LINEAR B IDEOGRAM B161
100AA LINEAR B IDEOGRAM B162 GARMENT
100AB LINEAR B IDEOGRAM B163 ARMOUR
100AC LINEAR B IDEOGRAM B164
100AD LINEAR B IDEOGRAM B165
100AE LINEAR B IDEOGRAM B166
100AF LINEAR B IDEOGRAM B167
100B0 LINEAR B IDEOGRAM B168
100B1 LINEAR B IDEOGRAM B169
100B2 LINEAR B IDEOGRAM B170
100B3 LINEAR B IDEOGRAM B171
100B4 LINEAR B IDEOGRAM B172
100B5 LINEAR B IDEOGRAM B173 MONTH
100B6 LINEAR B IDEOGRAM B174
100B7 LINEAR B IDEOGRAM B176 TREE
100B8 LINEAR B IDEOGRAM B177
100B9 LINEAR B IDEOGRAM B178
100BA LINEAR B IDEOGRAM B179
100BB LINEAR B IDEOGRAM B180
100BC LINEAR B IDEOGRAM B181
100BD LINEAR B IDEOGRAM B182
100BE LINEAR B IDEOGRAM B183
100BF LINEAR B IDEOGRAM B184
100C0 LINEAR B IDEOGRAM B185
100C1 LINEAR B IDEOGRAM B189
100C2 LINEAR B IDEOGRAM B190
100C3 LINEAR B IDEOGRAM B191 HELMET
100C4 LINEAR B IDEOGRAM B220 FOOTSTOOL
100C5 LINEAR B IDEOGRAM B225 BATHTUB
100C6 LINEAR B IDEOGRAM B230 SPEAR
100C7 LINEAR B IDEOGRAM B231 ARROW
100C8 LINEAR B IDEOGRAM B232
100C9 LINEAR B IDEOGRAM B233 SWORD
100CA LINEAR B IDEOGRAM B234
100CB LINEAR B IDEOGRAM B236
100CC LINEAR B IDEOGRAM B240 WHEELED CHARIOT
100CD LINEAR B IDEOGRAM B241 CHARIOT
100CE LINEAR B IDEOGRAM B242 CHARIOT FRAME
100CF LINEAR B IDEOGRAM B243 WHEEL
100D0 LINEAR B IDEOGRAM B245
100D1 LINEAR B IDEOGRAM B246
100D2 LINEAR B MONOGRAM B247 DIPTE
100D3 LINEAR B IDEOGRAM B248
100D4 LINEAR B IDEOGRAM B249
100D5 LINEAR B IDEOGRAM B251
100D6 LINEAR B IDEOGRAM B252
100D7 LINEAR B IDEOGRAM B253
100D8 LINEAR B IDEOGRAM B254 DART
100D9 LINEAR B IDEOGRAM B255
100DA LINEAR B IDEOGRAM B256
100DB LINEAR B IDEOGRAM B257
100DC LINEAR B IDEOGRAM B258
100DD LINEAR B IDEOGRAM B259
100DE LINEAR B IDEOGRAM VESSEL B155
100DF LINEAR B IDEOGRAM VESSEL B200
100E0 LINEAR B IDEOGRAM VESSEL B201
100E1 LINEAR B IDEOGRAM VESSEL B202
100E2 LINEAR B IDEOGRAM VESSEL B203
100E3 LINEAR B IDEOGRAM VESSEL B204
100E4 LINEAR B IDEOGRAM VESSEL B205
100E5 LINEAR B IDEOGRAM VESSEL B206
100E6 LINEAR B IDEOGRAM VESSEL B207
100E7 LINEAR B IDEOGRAM VESSEL B208
100E8 LINEAR B IDEOGRAM VESSEL B209
100E9 LINEAR B IDEOGRAM VESSEL B210
100EA LINEAR B IDEOGRAM VESSEL B211
100EB LINEAR B IDEOGRAM VESSEL B212
100EC LINEAR B IDEOGRAM VESSEL B213
100ED LINEAR B IDEOGRAM VESSEL B214
100EE LINEAR B IDEOGRAM VESSEL B215
100EF LINEAR B IDEOGRAM VESSEL B216
100F0 LINEAR B IDEOGRAM VESSEL B217
100F1 LINEAR B IDEOGRAM VESSEL B218
100F2 LINEAR B IDEOGRAM VESSEL B219
100F3 LINEAR B IDEOGRAM VESSEL B221
100F4 LINEAR B IDEOGRAM VESSEL B222
100F5 LINEAR B IDEOGRAM VESSEL B226
100F6 LINEAR B IDEOGRAM VESSEL B227
100F7 LINEAR B IDEOGRAM VESSEL B228
100F8 LINEAR B IDEOGRAM VESSEL B229
100F9 LINEAR B IDEOGRAM VESSEL B250
100FA LINEAR B IDEOGRAM VESSEL B305
10100 AEGEAN WORD SEPARATOR LINE
10101 AEGEAN WORD SEPARATOR DOT
10102 AEGEAN CHECK MARK
10107 AEGEAN NUMBER ONE
10108 AEGEAN NUMBER TWO
10109 AEGEAN NUMBER THREE
1010A AEGEAN NUMBER FOUR
1010B AEGEAN NUMBER FIVE
1010C AEGEAN NUMBER SIX
1010D AEGEAN NUMBER SEVEN
1010E AEGEAN NUMBER EIGHT
1010F AEGEAN NUMBER NINE
10110 AEGEAN NUMBER TEN
10111 AEGEAN NUMBER TWENTY
10112 AEGEAN NUMBER THIRTY
10113 AEGEAN NUMBER FORTY
10114 AEGEAN NUMBER FIFTY
10115 AEGEAN NUMBER SIXTY
10116 AEGEAN NUMBER SEVENTY
10117 AEGEAN NUMBER EIGHTY
10118 AEGEAN NUMBER NINETY
10119 AEGEAN NUMBER ONE HUNDRED
1011A AEGEAN NUMBER TWO HUNDRED
1011B AEGEAN NUMBER THREE HUNDRED
1011C AEGEAN NUMBER FOUR HUNDRED
1011D AEGEAN NUMBER FIVE HUNDRED
1011E AEGEAN NUMBER SIX HUNDRED
1011F AEGEAN NUMBER SEVEN HUNDRED
10120 AEGEAN NUMBER EIGHT HUNDRED
10121 AEGEAN NUMBER NINE HUNDRED
10122 AEGEAN NUMBER ONE THOUSAND
10123 AEGEAN NUMBER TWO THOUSAND
10124 AEGEAN NUMBER THREE THOUSAND
10125 AEGEAN NUMBER FOUR THOUSAND
10126 AEGEAN NUMBER FIVE THOUSAND
10127 AEGEAN NUMBER SIX THOUSAND
10128 AEGEAN NUMBER SEVEN THOUSAND
10129 AEGEAN NUMBER EIGHT THOUSAND
1012A AEGEAN NUMBER NINE THOUSAND
1012B AEGEAN NUMBER TEN THOUSAND
1012C AEGEAN NUMBER TWENTY THOUSAND
1012D AEGEAN NUMBER THIRTY THOUSAND
1012E AEGEAN NUMBER FORTY THOUSAND
1012F AEGEAN NUMBER FIFTY THOUSAND
10130 AEGEAN NUMBER SIXTY THOUSAND
10131 AEGEAN NUMBER SEVENTY THOUSAND
10132 AEGEAN NUMBER EIGHTY THOUSAND
10133 AEGEAN NUMBER NINETY THOUSAND
10137 AEGEAN WEIGHT BASE UNIT
10138 AEGEAN WEIGHT FIRST SUBUNIT
10139 AEGEAN WEIGHT SECOND SUBUNIT
1013A AEGEAN WEIGHT THIRD SUBUNIT
1013B AEGEAN WEIGHT FOURTH SUBUNIT
1013C AEGEAN DRY MEASURE FIRST SUBUNIT
1013D AEGEAN LIQUID MEASURE FIRST SUBUNIT
1013E AEGEAN MEASURE SECOND SUBUNIT
1013F AEGEAN MEASURE THIRD SUBUNIT
10140 GREEK ACROPHONIC ATTIC ONE QUARTER
10141 GREEK ACROPHONIC ATTIC ONE HALF
10142 GREEK ACROPHONIC ATTIC ONE DRACHMA
10143 GREEK ACROPHONIC ATTIC FIVE
10144 GREEK ACROPHONIC ATTIC FIFTY
10145 GREEK ACROPHONIC ATTIC FIVE HUNDRED
10146 GREEK ACROPHONIC ATTIC FIVE THOUSAND
10147 GREEK ACROPHONIC ATTIC FIFTY THOUSAND
10148 GREEK ACROPHONIC ATTIC FIVE TALENTS
10149 GREEK ACROPHONIC ATTIC TEN TALENTS
1014A GREEK ACROPHONIC ATTIC FIFTY TALENTS
1014B GREEK ACROPHONIC ATTIC ONE HUNDRED TALENTS
1014C GREEK ACROPHONIC ATTIC FIVE HUNDRED TALENTS
1014D GREEK ACROPHONIC ATTIC ONE THOUSAND TALENTS
1014E GREEK ACROPHONIC ATTIC FIVE THOUSAND TALENTS
1014F GREEK ACROPHONIC ATTIC FIVE STATERS
10150 GREEK ACROPHONIC ATTIC TEN STATERS
10151 GREEK ACROPHONIC ATTIC FIFTY STATERS
10152 GREEK ACROPHONIC ATTIC ONE HUNDRED STATERS
10153 GREEK ACROPHONIC ATTIC FIVE HUNDRED STATERS
10154 GREEK ACROPHONIC ATTIC ONE THOUSAND STATERS
10155 GREEK ACROPHONIC ATTIC TEN THOUSAND STATERS
10156 GREEK ACROPHONIC ATTIC FIFTY THOUSAND STATERS
10157 GREEK ACROPHONIC ATTIC TEN MNAS
10158 GREEK ACROPHONIC HERAEUM ONE PLETHRON
10159 GREEK ACROPHONIC THESPIAN ONE
1015A GREEK ACROPHONIC HERMIONIAN ONE
1015B GREEK ACROPHONIC EPIDAUREAN TWO
1015C GREEK ACROPHONIC THESPIAN TWO
1015D GREEK ACROPHONIC CYRENAIC TWO DRACHMAS
1015E GREEK ACROPHONIC EPIDAUREAN TWO DRACHMAS
1015F GREEK ACROPHONIC TROEZENIAN FIVE
10160 GREEK ACROPHONIC TROEZENIAN TEN
10161 GREEK ACROPHONIC TROEZENIAN TEN ALTERNATE FORM
10162 GREEK ACROPHONIC HERMIONIAN TEN
10163 GREEK ACROPHONIC MESSENIAN TEN
10164 GREEK ACROPHONIC THESPIAN TEN
10165 GREEK ACROPHONIC THESPIAN THIRTY
10166 GREEK ACROPHONIC TROEZENIAN FIFTY
10167 GREEK ACROPHONIC TROEZENIAN FIFTY ALTERNATE FORM
10168 GREEK ACROPHONIC HERMIONIAN FIFTY
10169 GREEK ACROPHONIC THESPIAN FIFTY
1016A GREEK ACROPHONIC THESPIAN ONE HUNDRED
1016B GREEK ACROPHONIC THESPIAN THREE HUNDRED
1016C GREEK ACROPHONIC EPIDAUREAN FIVE HUNDRED
1016D GREEK ACROPHONIC TROEZENIAN FIVE HUNDRED
1016E GREEK ACROPHONIC THESPIAN FIVE HUNDRED
1016F GREEK ACROPHONIC CARYSTIAN FIVE HUNDRED
10170 GREEK ACROPHONIC NAXIAN FIVE HUNDRED
10171 GREEK ACROPHONIC THESPIAN ONE THOUSAND
10172 GREEK ACROPHONIC THESPIAN FIVE THOUSAND
10173 GREEK ACROPHONIC DELPHIC FIVE MNAS
10174 GREEK ACROPHONIC STRATIAN FIFTY MNAS
10175 GREEK ONE HALF SIGN
10176 GREEK ONE HALF SIGN ALTERNATE FORM
10177 GREEK TWO THIRDS SIGN
10178 GREEK THREE QUARTERS SIGN
10179 GREEK YEAR SIGN
1017A GREEK TALENT SIGN
1017B GREEK DRACHMA SIGN
1017C GREEK OBOL SIGN
1017D GREEK TWO OBOLS SIGN
1017E GREEK THREE OBOLS SIGN
1017F GREEK FOUR OBOLS SIGN
10180 GREEK FIVE OBOLS SIGN
10181 GREEK METRETES SIGN
10182 GREEK KYATHOS BASE SIGN
10183 GREEK LITRA SIGN
10184 GREEK OUNKIA SIGN
10185 GREEK XESTES SIGN
10186 GREEK ARTABE SIGN
10187 GREEK AROURA SIGN
10188 GREEK GRAMMA SIGN
10189 GREEK TRYBLION BASE SIGN
1018A GREEK ZERO SIGN
10300 OLD ITALIC LETTER A
10301 OLD ITALIC LETTER BE
10302 OLD ITALIC LETTER KE
10303 OLD ITALIC LETTER DE
10304 OLD ITALIC LETTER E
10305 OLD ITALIC LETTER VE
10306 OLD ITALIC LETTER ZE
10307 OLD ITALIC LETTER HE
10308 OLD ITALIC LETTER THE
10309 OLD ITALIC LETTER I
1030A OLD ITALIC LETTER KA
1030B OLD ITALIC LETTER EL
1030C OLD ITALIC LETTER EM
1030D OLD ITALIC LETTER EN
1030E OLD ITALIC LETTER ESH
1030F OLD ITALIC LETTER O
10310 OLD ITALIC LETTER PE
10311 OLD ITALIC LETTER SHE
10312 OLD ITALIC LETTER KU
10313 OLD ITALIC LETTER ER
10314 OLD ITALIC LETTER ES
10315 OLD ITALIC LETTER TE
10316 OLD ITALIC LETTER U
10317 OLD ITALIC LETTER EKS
10318 OLD ITALIC LETTER PHE
10319 OLD ITALIC LETTER KHE
1031A OLD ITALIC LETTER EF
1031B OLD ITALIC LETTER ERS
1031C OLD ITALIC LETTER CHE
1031D OLD ITALIC LETTER II
1031E OLD ITALIC LETTER UU
10320 OLD ITALIC NUMERAL ONE
10321 OLD ITALIC NUMERAL FIVE
10322 OLD ITALIC NUMERAL TEN
10323 OLD ITALIC NUMERAL FIFTY
10330 GOTHIC LETTER AHSA
10331 GOTHIC LETTER BAIRKAN
10332 GOTHIC LETTER GIBA
10333 GOTHIC LETTER DAGS
10334 GOTHIC LETTER AIHVUS
10335 GOTHIC LETTER QAIRTHRA
10336 GOTHIC LETTER IUJA
10337 GOTHIC LETTER HAGL
10338 GOTHIC LETTER THIUTH
10339 GOTHIC LETTER EIS
1033A GOTHIC LETTER KUSMA
1033B GOTHIC LETTER LAGUS
1033C GOTHIC LETTER MANNA
1033D GOTHIC LETTER NAUTHS
1033E GOTHIC LETTER JER
1033F GOTHIC LETTER URUS
10340 GOTHIC LETTER PAIRTHRA
10341 GOTHIC LETTER NINETY
10342 GOTHIC LETTER RAIDA
10343 GOTHIC LETTER SAUIL
10344 GOTHIC LETTER TEIWS
10345 GOTHIC LETTER WINJA
10346 GOTHIC LETTER FAIHU
10347 GOTHIC LETTER IGGWS
10348 GOTHIC LETTER HWAIR
10349 GOTHIC LETTER OTHAL
1034A GOTHIC LETTER NINE HUNDRED
10380 UGARITIC LETTER ALPA
10381 UGARITIC LETTER BETA
10382 UGARITIC LETTER GAMLA
10383 UGARITIC LETTER KHA
10384 UGARITIC LETTER DELTA
10385 UGARITIC LETTER HO
10386 UGARITIC LETTER WO
10387 UGARITIC LETTER ZETA
10388 UGARITIC LETTER HOTA
10389 UGARITIC LETTER TET
1038A UGARITIC LETTER YOD
1038B UGARITIC LETTER KAF
1038C UGARITIC LETTER SHIN
1038D UGARITIC LETTER LAMDA
1038E UGARITIC LETTER MEM
1038F UGARITIC LETTER DHAL
10390 UGARITIC LETTER NUN
10391 UGARITIC LETTER ZU
10392 UGARITIC LETTER SAMKA
10393 UGARITIC LETTER AIN
10394 UGARITIC LETTER PU
10395 UGARITIC LETTER SADE
10396 UGARITIC LETTER QOPA
10397 UGARITIC LETTER RASHA
10398 UGARITIC LETTER THANNA
10399 UGARITIC LETTER GHAIN
1039A UGARITIC LETTER TO
1039B UGARITIC LETTER I
1039C UGARITIC LETTER U
1039D UGARITIC LETTER SSU
1039F UGARITIC WORD DIVIDER
103A0 OLD PERSIAN SIGN A
103A1 OLD PERSIAN SIGN I
103A2 OLD PERSIAN SIGN U
103A3 OLD PERSIAN SIGN KA
103A4 OLD PERSIAN SIGN KU
103A5 OLD PERSIAN SIGN GA
103A6 OLD PERSIAN SIGN GU
103A7 OLD PERSIAN SIGN XA
103A8 OLD PERSIAN SIGN CA
103A9 OLD PERSIAN SIGN JA
103AA OLD PERSIAN SIGN JI
103AB OLD PERSIAN SIGN TA
103AC OLD PERSIAN SIGN TU
103AD OLD PERSIAN SIGN DA
103AE OLD PERSIAN SIGN DI
103AF OLD PERSIAN SIGN DU
103B0 OLD PERSIAN SIGN THA
103B1 OLD PERSIAN SIGN PA
103B2 OLD PERSIAN SIGN BA
103B3 OLD PERSIAN SIGN FA
103B4 OLD PERSIAN SIGN NA
103B5 OLD PERSIAN SIGN NU
103B6 OLD PERSIAN SIGN MA
103B7 OLD PERSIAN SIGN MI
103B8 OLD PERSIAN SIGN MU
103B9 OLD PERSIAN SIGN YA
103BA OLD PERSIAN SIGN VA
103BB OLD PERSIAN SIGN VI
103BC OLD PERSIAN SIGN RA
103BD OLD PERSIAN SIGN RU
103BE OLD PERSIAN SIGN LA
103BF OLD PERSIAN SIGN SA
103C0 OLD PERSIAN SIGN ZA
103C1 OLD PERSIAN SIGN SHA
103C2 OLD PERSIAN SIGN SSA
103C3 OLD PERSIAN SIGN HA
103C8 OLD PERSIAN SIGN AURAMAZDAA
103C9 OLD PERSIAN SIGN AURAMAZDAA-2
103CA OLD PERSIAN SIGN AURAMAZDAAHA
103CB OLD PERSIAN SIGN XSHAAYATHIYA
103CC OLD PERSIAN SIGN DAHYAAUSH
103CD OLD PERSIAN SIGN DAHYAAUSH-2
103CE OLD PERSIAN SIGN BAGA
103CF OLD PERSIAN SIGN BUUMISH
103D0 OLD PERSIAN WORD DIVIDER
103D1 OLD PERSIAN NUMBER ONE
103D2 OLD PERSIAN NUMBER TWO
103D3 OLD PERSIAN NUMBER TEN
103D4 OLD PERSIAN NUMBER TWENTY
103D5 OLD PERSIAN NUMBER HUNDRED
10400 DESERET CAPITAL LETTER LONG I
10401 DESERET CAPITAL LETTER LONG E
10402 DESERET CAPITAL LETTER LONG A
10403 DESERET CAPITAL LETTER LONG AH
10404 DESERET CAPITAL LETTER LONG O
10405 DESERET CAPITAL LETTER LONG OO
10406 DESERET CAPITAL LETTER SHORT I
10407 DESERET CAPITAL LETTER SHORT E
10408 DESERET CAPITAL LETTER SHORT A
10409 DESERET CAPITAL LETTER SHORT AH
1040A DESERET CAPITAL LETTER SHORT O
1040B DESERET CAPITAL LETTER SHORT OO
1040C DESERET CAPITAL LETTER AY
1040D DESERET CAPITAL LETTER OW
1040E DESERET CAPITAL LETTER WU
1040F DESERET CAPITAL LETTER YEE
10410 DESERET CAPITAL LETTER H
10411 DESERET CAPITAL LETTER PEE
10412 DESERET CAPITAL LETTER BEE
10413 DESERET CAPITAL LETTER TEE
10414 DESERET CAPITAL LETTER DEE
10415 DESERET CAPITAL LETTER CHEE
10416 DESERET CAPITAL LETTER JEE
10417 DESERET CAPITAL LETTER KAY
10418 DESERET CAPITAL LETTER GAY
10419 DESERET CAPITAL LETTER EF
1041A DESERET CAPITAL LETTER VEE
1041B DESERET CAPITAL LETTER ETH
1041C DESERET CAPITAL LETTER THEE
1041D DESERET CAPITAL LETTER ES
1041E DESERET CAPITAL LETTER ZEE
1041F DESERET CAPITAL LETTER ESH
10420 DESERET CAPITAL LETTER ZHEE
10421 DESERET CAPITAL LETTER ER
10422 DESERET CAPITAL LETTER EL
10423 DESERET CAPITAL LETTER EM
10424 DESERET CAPITAL LETTER EN
10425 DESERET CAPITAL LETTER ENG
10426 DESERET CAPITAL LETTER OI
10427 DESERET CAPITAL LETTER EW
10428 DESERET SMALL LETTER LONG I
10429 DESERET SMALL LETTER LONG E
1042A DESERET SMALL LETTER LONG A
1042B DESERET SMALL LETTER LONG AH
1042C DESERET SMALL LETTER LONG O
1042D DESERET SMALL LETTER LONG OO
1042E DESERET SMALL LETTER SHORT I
1042F DESERET SMALL LETTER SHORT E
10430 DESERET SMALL LETTER SHORT A
10431 DESERET SMALL LETTER SHORT AH
10432 DESERET SMALL LETTER SHORT O
10433 DESERET SMALL LETTER SHORT OO
10434 DESERET SMALL LETTER AY
10435 DESERET SMALL LETTER OW
10436 DESERET SMALL LETTER WU
10437 DESERET SMALL LETTER YEE
10438 DESERET SMALL LETTER H
10439 DESERET SMALL LETTER PEE
1043A DESERET SMALL LETTER BEE
1043B DESERET SMALL LETTER TEE
1043C DESERET SMALL LETTER DEE
1043D DESERET SMALL LETTER CHEE
1043E DESERET SMALL LETTER JEE
1043F DESERET SMALL LETTER KAY
10440 DESERET SMALL LETTER GAY
10441 DESERET SMALL LETTER EF
10442 DESERET SMALL LETTER VEE
10443 DESERET SMALL LETTER ETH
10444 DESERET SMALL LETTER THEE
10445 DESERET SMALL LETTER ES
10446 DESERET SMALL LETTER ZEE
10447 DESERET SMALL LETTER ESH
10448 DESERET SMALL LETTER ZHEE
10449 DESERET SMALL LETTER ER
1044A DESERET SMALL LETTER EL
1044B DESERET SMALL LETTER EM
1044C DESERET SMALL LETTER EN
1044D DESERET SMALL LETTER ENG
1044E DESERET SMALL LETTER OI
1044F DESERET SMALL LETTER EW
10450 SHAVIAN LETTER PEEP
10451 SHAVIAN LETTER TOT
10452 SHAVIAN LETTER KICK
10453 SHAVIAN LETTER FEE
10454 SHAVIAN LETTER THIGH
10455 SHAVIAN LETTER SO
10456 SHAVIAN LETTER SURE
10457 SHAVIAN LETTER CHURCH
10458 SHAVIAN LETTER YEA
10459 SHAVIAN LETTER HUNG
1045A SHAVIAN LETTER BIB
1045B SHAVIAN LETTER DEAD
1045C SHAVIAN LETTER GAG
1045D SHAVIAN LETTER VOW
1045E SHAVIAN LETTER THEY
1045F SHAVIAN LETTER ZOO
10460 SHAVIAN LETTER MEASURE
10461 SHAVIAN LETTER JUDGE
10462 SHAVIAN LETTER WOE
10463 SHAVIAN LETTER HA-HA
10464 SHAVIAN LETTER LOLL
10465 SHAVIAN LETTER MIME
10466 SHAVIAN LETTER IF
10467 SHAVIAN LETTER EGG
10468 SHAVIAN LETTER ASH
10469 SHAVIAN LETTER ADO
1046A SHAVIAN LETTER ON
1046B SHAVIAN LETTER WOOL
1046C SHAVIAN LETTER OUT
1046D SHAVIAN LETTER AH
1046E SHAVIAN LETTER ROAR
1046F SHAVIAN LETTER NUN
10470 SHAVIAN LETTER EAT
10471 SHAVIAN LETTER AGE
10472 SHAVIAN LETTER ICE
10473 SHAVIAN LETTER UP
10474 SHAVIAN LETTER OAK
10475 SHAVIAN LETTER OOZE
10476 SHAVIAN LETTER OIL
10477 SHAVIAN LETTER AWE
10478 SHAVIAN LETTER ARE
10479 SHAVIAN LETTER OR
1047A SHAVIAN LETTER AIR
1047B SHAVIAN LETTER ERR
1047C SHAVIAN LETTER ARRAY
1047D SHAVIAN LETTER EAR
1047E SHAVIAN LETTER IAN
1047F SHAVIAN LETTER YEW
10480 OSMANYA LETTER ALEF
10481 OSMANYA LETTER BA
10482 OSMANYA LETTER TA
10483 OSMANYA LETTER JA
10484 OSMANYA LETTER XA
10485 OSMANYA LETTER KHA
10486 OSMANYA LETTER DEEL
10487 OSMANYA LETTER RA
10488 OSMANYA LETTER SA
10489 OSMANYA LETTER SHIIN
1048A OSMANYA LETTER DHA
1048B OSMANYA LETTER CAYN
1048C OSMANYA LETTER GA
1048D OSMANYA LETTER FA
1048E OSMANYA LETTER QAAF
1048F OSMANYA LETTER KAAF
10490 OSMANYA LETTER LAAN
10491 OSMANYA LETTER MIIN
10492 OSMANYA LETTER NUUN
10493 OSMANYA LETTER WAW
10494 OSMANYA LETTER HA
10495 OSMANYA LETTER YA
10496 OSMANYA LETTER A
10497 OSMANYA LETTER E
10498 OSMANYA LETTER I
10499 OSMANYA LETTER O
1049A OSMANYA LETTER U
1049B OSMANYA LETTER AA
1049C OSMANYA LETTER EE
1049D OSMANYA LETTER OO
104A0 OSMANYA DIGIT ZERO
104A1 OSMANYA DIGIT ONE
104A2 OSMANYA DIGIT TWO
104A3 OSMANYA DIGIT THREE
104A4 OSMANYA DIGIT FOUR
104A5 OSMANYA DIGIT FIVE
104A6 OSMANYA DIGIT SIX
104A7 OSMANYA DIGIT SEVEN
104A8 OSMANYA DIGIT EIGHT
104A9 OSMANYA DIGIT NINE
10800 CYPRIOT SYLLABLE A
10801 CYPRIOT SYLLABLE E
10802 CYPRIOT SYLLABLE I
10803 CYPRIOT SYLLABLE O
10804 CYPRIOT SYLLABLE U
10805 CYPRIOT SYLLABLE JA
10808 CYPRIOT SYLLABLE JO
1080A CYPRIOT SYLLABLE KA
1080B CYPRIOT SYLLABLE KE
1080C CYPRIOT SYLLABLE KI
1080D CYPRIOT SYLLABLE KO
1080E CYPRIOT SYLLABLE KU
1080F CYPRIOT SYLLABLE LA
10810 CYPRIOT SYLLABLE LE
10811 CYPRIOT SYLLABLE LI
10812 CYPRIOT SYLLABLE LO
10813 CYPRIOT SYLLABLE LU
10814 CYPRIOT SYLLABLE MA
10815 CYPRIOT SYLLABLE ME
10816 CYPRIOT SYLLABLE MI
10817 CYPRIOT SYLLABLE MO
10818 CYPRIOT SYLLABLE MU
10819 CYPRIOT SYLLABLE NA
1081A CYPRIOT SYLLABLE NE
1081B CYPRIOT SYLLABLE NI
1081C CYPRIOT SYLLABLE NO
1081D CYPRIOT SYLLABLE NU
1081E CYPRIOT SYLLABLE PA
1081F CYPRIOT SYLLABLE PE
10820 CYPRIOT SYLLABLE PI
10821 CYPRIOT SYLLABLE PO
10822 CYPRIOT SYLLABLE PU
10823 CYPRIOT SYLLABLE RA
10824 CYPRIOT SYLLABLE RE
10825 CYPRIOT SYLLABLE RI
10826 CYPRIOT SYLLABLE RO
10827 CYPRIOT SYLLABLE RU
10828 CYPRIOT SYLLABLE SA
10829 CYPRIOT SYLLABLE SE
1082A CYPRIOT SYLLABLE SI
1082B CYPRIOT SYLLABLE SO
1082C CYPRIOT SYLLABLE SU
1082D CYPRIOT SYLLABLE TA
1082E CYPRIOT SYLLABLE TE
1082F CYPRIOT SYLLABLE TI
10830 CYPRIOT SYLLABLE TO
10831 CYPRIOT SYLLABLE TU
10832 CYPRIOT SYLLABLE WA
10833 CYPRIOT SYLLABLE WE
10834 CYPRIOT SYLLABLE WI
10835 CYPRIOT SYLLABLE WO
10837 CYPRIOT SYLLABLE XA
10838 CYPRIOT SYLLABLE XE
1083C CYPRIOT SYLLABLE ZA
1083F CYPRIOT SYLLABLE ZO
10A00 KHAROSHTHI LETTER A
10A01 KHAROSHTHI VOWEL SIGN I
10A02 KHAROSHTHI VOWEL SIGN U
10A03 KHAROSHTHI VOWEL SIGN VOCALIC R
10A05 KHAROSHTHI VOWEL SIGN E
10A06 KHAROSHTHI VOWEL SIGN O
10A0C KHAROSHTHI VOWEL LENGTH MARK
10A0D KHAROSHTHI SIGN DOUBLE RING BELOW
10A0E KHAROSHTHI SIGN ANUSVARA
10A0F KHAROSHTHI SIGN VISARGA
10A10 KHAROSHTHI LETTER KA
10A11 KHAROSHTHI LETTER KHA
10A12 KHAROSHTHI LETTER GA
10A13 KHAROSHTHI LETTER GHA
10A15 KHAROSHTHI LETTER CA
10A16 KHAROSHTHI LETTER CHA
10A17 KHAROSHTHI LETTER JA
10A19 KHAROSHTHI LETTER NYA
10A1A KHAROSHTHI LETTER TTA
10A1B KHAROSHTHI LETTER TTHA
10A1C KHAROSHTHI LETTER DDA
10A1D KHAROSHTHI LETTER DDHA
10A1E KHAROSHTHI LETTER NNA
10A1F KHAROSHTHI LETTER TA
10A20 KHAROSHTHI LETTER THA
10A21 KHAROSHTHI LETTER DA
10A22 KHAROSHTHI LETTER DHA
10A23 KHAROSHTHI LETTER NA
10A24 KHAROSHTHI LETTER PA
10A25 KHAROSHTHI LETTER PHA
10A26 KHAROSHTHI LETTER BA
10A27 KHAROSHTHI LETTER BHA
10A28 KHAROSHTHI LETTER MA
10A29 KHAROSHTHI LETTER YA
10A2A KHAROSHTHI LETTER RA
10A2B KHAROSHTHI LETTER LA
10A2C KHAROSHTHI LETTER VA
10A2D KHAROSHTHI LETTER SHA
10A2E KHAROSHTHI LETTER SSA
10A2F KHAROSHTHI LETTER SA
10A30 KHAROSHTHI LETTER ZA
10A31 KHAROSHTHI LETTER HA
10A32 KHAROSHTHI LETTER KKA
10A33 KHAROSHTHI LETTER TTTHA
10A38 KHAROSHTHI SIGN BAR ABOVE
10A39 KHAROSHTHI SIGN CAUDA
10A3A KHAROSHTHI SIGN DOT BELOW
10A3F KHAROSHTHI VIRAMA
10A40 KHAROSHTHI DIGIT ONE
10A41 KHAROSHTHI DIGIT TWO
10A42 KHAROSHTHI DIGIT THREE
10A43 KHAROSHTHI DIGIT FOUR
10A44 KHAROSHTHI NUMBER TEN
10A45 KHAROSHTHI NUMBER TWENTY
10A46 KHAROSHTHI NUMBER ONE HUNDRED
10A47 KHAROSHTHI NUMBER ONE THOUSAND
10A50 KHAROSHTHI PUNCTUATION DOT
10A51 KHAROSHTHI PUNCTUATION SMALL CIRCLE
10A52 KHAROSHTHI PUNCTUATION CIRCLE
10A53 KHAROSHTHI PUNCTUATION CRESCENT BAR
10A54 KHAROSHTHI PUNCTUATION MANGALAM
10A55 KHAROSHTHI PUNCTUATION LOTUS
10A56 KHAROSHTHI PUNCTUATION DANDA
10A57 KHAROSHTHI PUNCTUATION DOUBLE DANDA
10A58 KHAROSHTHI PUNCTUATION LINES
1D000 BYZANTINE MUSICAL SYMBOL PSILI
1D001 BYZANTINE MUSICAL SYMBOL DASEIA
1D002 BYZANTINE MUSICAL SYMBOL PERISPOMENI
1D003 BYZANTINE MUSICAL SYMBOL OXEIA EKFONITIKON
1D004 BYZANTINE MUSICAL SYMBOL OXEIA DIPLI
1D005 BYZANTINE MUSICAL SYMBOL VAREIA EKFONITIKON
1D006 BYZANTINE MUSICAL SYMBOL VAREIA DIPLI
1D007 BYZANTINE MUSICAL SYMBOL KATHISTI
1D008 BYZANTINE MUSICAL SYMBOL SYRMATIKI
1D009 BYZANTINE MUSICAL SYMBOL PARAKLITIKI
1D00A BYZANTINE MUSICAL SYMBOL YPOKRISIS
1D00B BYZANTINE MUSICAL SYMBOL YPOKRISIS DIPLI
1D00C BYZANTINE MUSICAL SYMBOL KREMASTI
1D00D BYZANTINE MUSICAL SYMBOL APESO EKFONITIKON
1D00E BYZANTINE MUSICAL SYMBOL EXO EKFONITIKON
1D00F BYZANTINE MUSICAL SYMBOL TELEIA
1D010 BYZANTINE MUSICAL SYMBOL KENTIMATA
1D011 BYZANTINE MUSICAL SYMBOL APOSTROFOS
1D012 BYZANTINE MUSICAL SYMBOL APOSTROFOS DIPLI
1D013 BYZANTINE MUSICAL SYMBOL SYNEVMA
1D014 BYZANTINE MUSICAL SYMBOL THITA
1D015 BYZANTINE MUSICAL SYMBOL OLIGON ARCHAION
1D016 BYZANTINE MUSICAL SYMBOL GORGON ARCHAION
1D017 BYZANTINE MUSICAL SYMBOL PSILON
1D018 BYZANTINE MUSICAL SYMBOL CHAMILON
1D019 BYZANTINE MUSICAL SYMBOL VATHY
1D01A BYZANTINE MUSICAL SYMBOL ISON ARCHAION
1D01B BYZANTINE MUSICAL SYMBOL KENTIMA ARCHAION
1D01C BYZANTINE MUSICAL SYMBOL KENTIMATA ARCHAION
1D01D BYZANTINE MUSICAL SYMBOL SAXIMATA
1D01E BYZANTINE MUSICAL SYMBOL PARICHON
1D01F BYZANTINE MUSICAL SYMBOL STAVROS APODEXIA
1D020 BYZANTINE MUSICAL SYMBOL OXEIAI ARCHAION
1D021 BYZANTINE MUSICAL SYMBOL VAREIAI ARCHAION
1D022 BYZANTINE MUSICAL SYMBOL APODERMA ARCHAION
1D023 BYZANTINE MUSICAL SYMBOL APOTHEMA
1D024 BYZANTINE MUSICAL SYMBOL KLASMA
1D025 BYZANTINE MUSICAL SYMBOL REVMA
1D026 BYZANTINE MUSICAL SYMBOL PIASMA ARCHAION
1D027 BYZANTINE MUSICAL SYMBOL TINAGMA
1D028 BYZANTINE MUSICAL SYMBOL ANATRICHISMA
1D029 BYZANTINE MUSICAL SYMBOL SEISMA
1D02A BYZANTINE MUSICAL SYMBOL SYNAGMA ARCHAION
1D02B BYZANTINE MUSICAL SYMBOL SYNAGMA META STAVROU
1D02C BYZANTINE MUSICAL SYMBOL OYRANISMA ARCHAION
1D02D BYZANTINE MUSICAL SYMBOL THEMA
1D02E BYZANTINE MUSICAL SYMBOL LEMOI
1D02F BYZANTINE MUSICAL SYMBOL DYO
1D030 BYZANTINE MUSICAL SYMBOL TRIA
1D031 BYZANTINE MUSICAL SYMBOL TESSERA
1D032 BYZANTINE MUSICAL SYMBOL KRATIMATA
1D033 BYZANTINE MUSICAL SYMBOL APESO EXO NEO
1D034 BYZANTINE MUSICAL SYMBOL FTHORA ARCHAION
1D035 BYZANTINE MUSICAL SYMBOL IMIFTHORA
1D036 BYZANTINE MUSICAL SYMBOL TROMIKON ARCHAION
1D037 BYZANTINE MUSICAL SYMBOL KATAVA TROMIKON
1D038 BYZANTINE MUSICAL SYMBOL PELASTON
1D039 BYZANTINE MUSICAL SYMBOL PSIFISTON
1D03A BYZANTINE MUSICAL SYMBOL KONTEVMA
1D03B BYZANTINE MUSICAL SYMBOL CHOREVMA ARCHAION
1D03C BYZANTINE MUSICAL SYMBOL RAPISMA
1D03D BYZANTINE MUSICAL SYMBOL PARAKALESMA ARCHAION
1D03E BYZANTINE MUSICAL SYMBOL PARAKLITIKI ARCHAION
1D03F BYZANTINE MUSICAL SYMBOL ICHADIN
1D040 BYZANTINE MUSICAL SYMBOL NANA
1D041 BYZANTINE MUSICAL SYMBOL PETASMA
1D042 BYZANTINE MUSICAL SYMBOL KONTEVMA ALLO
1D043 BYZANTINE MUSICAL SYMBOL TROMIKON ALLO
1D044 BYZANTINE MUSICAL SYMBOL STRAGGISMATA
1D045 BYZANTINE MUSICAL SYMBOL GRONTHISMATA
1D046 BYZANTINE MUSICAL SYMBOL ISON NEO
1D047 BYZANTINE MUSICAL SYMBOL OLIGON NEO
1D048 BYZANTINE MUSICAL SYMBOL OXEIA NEO
1D049 BYZANTINE MUSICAL SYMBOL PETASTI
1D04A BYZANTINE MUSICAL SYMBOL KOUFISMA
1D04B BYZANTINE MUSICAL SYMBOL PETASTOKOUFISMA
1D04C BYZANTINE MUSICAL SYMBOL KRATIMOKOUFISMA
1D04D BYZANTINE MUSICAL SYMBOL PELASTON NEO
1D04E BYZANTINE MUSICAL SYMBOL KENTIMATA NEO ANO
1D04F BYZANTINE MUSICAL SYMBOL KENTIMA NEO ANO
1D050 BYZANTINE MUSICAL SYMBOL YPSILI
1D051 BYZANTINE MUSICAL SYMBOL APOSTROFOS NEO
1D052 BYZANTINE MUSICAL SYMBOL APOSTROFOI SYNDESMOS NEO
1D053 BYZANTINE MUSICAL SYMBOL YPORROI
1D054 BYZANTINE MUSICAL SYMBOL KRATIMOYPORROON
1D055 BYZANTINE MUSICAL SYMBOL ELAFRON
1D056 BYZANTINE MUSICAL SYMBOL CHAMILI
1D057 BYZANTINE MUSICAL SYMBOL MIKRON ISON
1D058 BYZANTINE MUSICAL SYMBOL VAREIA NEO
1D059 BYZANTINE MUSICAL SYMBOL PIASMA NEO
1D05A BYZANTINE MUSICAL SYMBOL PSIFISTON NEO
1D05B BYZANTINE MUSICAL SYMBOL OMALON
1D05C BYZANTINE MUSICAL SYMBOL ANTIKENOMA
1D05D BYZANTINE MUSICAL SYMBOL LYGISMA
1D05E BYZANTINE MUSICAL SYMBOL PARAKLITIKI NEO
1D05F BYZANTINE MUSICAL SYMBOL PARAKALESMA NEO
1D060 BYZANTINE MUSICAL SYMBOL ETERON PARAKALESMA
1D061 BYZANTINE MUSICAL SYMBOL KYLISMA
1D062 BYZANTINE MUSICAL SYMBOL ANTIKENOKYLISMA
1D063 BYZANTINE MUSICAL SYMBOL TROMIKON NEO
1D064 BYZANTINE MUSICAL SYMBOL EKSTREPTON
1D065 BYZANTINE MUSICAL SYMBOL SYNAGMA NEO
1D066 BYZANTINE MUSICAL SYMBOL SYRMA
1D067 BYZANTINE MUSICAL SYMBOL CHOREVMA NEO
1D068 BYZANTINE MUSICAL SYMBOL EPEGERMA
1D069 BYZANTINE MUSICAL SYMBOL SEISMA NEO
1D06A BYZANTINE MUSICAL SYMBOL XIRON KLASMA
1D06B BYZANTINE MUSICAL SYMBOL TROMIKOPSIFISTON
1D06C BYZANTINE MUSICAL SYMBOL PSIFISTOLYGISMA
1D06D BYZANTINE MUSICAL SYMBOL TROMIKOLYGISMA
1D06E BYZANTINE MUSICAL SYMBOL TROMIKOPARAKALESMA
1D06F BYZANTINE MUSICAL SYMBOL PSIFISTOPARAKALESMA
1D070 BYZANTINE MUSICAL SYMBOL TROMIKOSYNAGMA
1D071 BYZANTINE MUSICAL SYMBOL PSIFISTOSYNAGMA
1D072 BYZANTINE MUSICAL SYMBOL GORGOSYNTHETON
1D073 BYZANTINE MUSICAL SYMBOL ARGOSYNTHETON
1D074 BYZANTINE MUSICAL SYMBOL ETERON ARGOSYNTHETON
1D075 BYZANTINE MUSICAL SYMBOL OYRANISMA NEO
1D076 BYZANTINE MUSICAL SYMBOL THEMATISMOS ESO
1D077 BYZANTINE MUSICAL SYMBOL THEMATISMOS EXO
1D078 BYZANTINE MUSICAL SYMBOL THEMA APLOUN
1D079 BYZANTINE MUSICAL SYMBOL THES KAI APOTHES
1D07A BYZANTINE MUSICAL SYMBOL KATAVASMA
1D07B BYZANTINE MUSICAL SYMBOL ENDOFONON
1D07C BYZANTINE MUSICAL SYMBOL YFEN KATO
1D07D BYZANTINE MUSICAL SYMBOL YFEN ANO
1D07E BYZANTINE MUSICAL SYMBOL STAVROS
1D07F BYZANTINE MUSICAL SYMBOL KLASMA ANO
1D080 BYZANTINE MUSICAL SYMBOL DIPLI ARCHAION
1D081 BYZANTINE MUSICAL SYMBOL KRATIMA ARCHAION
1D082 BYZANTINE MUSICAL SYMBOL KRATIMA ALLO
1D083 BYZANTINE MUSICAL SYMBOL KRATIMA NEO
1D084 BYZANTINE MUSICAL SYMBOL APODERMA NEO
1D085 BYZANTINE MUSICAL SYMBOL APLI
1D086 BYZANTINE MUSICAL SYMBOL DIPLI
1D087 BYZANTINE MUSICAL SYMBOL TRIPLI
1D088 BYZANTINE MUSICAL SYMBOL TETRAPLI
1D089 BYZANTINE MUSICAL SYMBOL KORONIS
1D08A BYZANTINE MUSICAL SYMBOL LEIMMA ENOS CHRONOU
1D08B BYZANTINE MUSICAL SYMBOL LEIMMA DYO CHRONON
1D08C BYZANTINE MUSICAL SYMBOL LEIMMA TRION CHRONON
1D08D BYZANTINE MUSICAL SYMBOL LEIMMA TESSARON CHRONON
1D08E BYZANTINE MUSICAL SYMBOL LEIMMA IMISEOS CHRONOU
1D08F BYZANTINE MUSICAL SYMBOL GORGON NEO ANO
1D090 BYZANTINE MUSICAL SYMBOL GORGON PARESTIGMENON ARISTERA
1D091 BYZANTINE MUSICAL SYMBOL GORGON PARESTIGMENON DEXIA
1D092 BYZANTINE MUSICAL SYMBOL DIGORGON
1D093 BYZANTINE MUSICAL SYMBOL DIGORGON PARESTIGMENON ARISTERA KATO
1D094 BYZANTINE MUSICAL SYMBOL DIGORGON PARESTIGMENON ARISTERA ANO
1D095 BYZANTINE MUSICAL SYMBOL DIGORGON PARESTIGMENON DEXIA
1D096 BYZANTINE MUSICAL SYMBOL TRIGORGON
1D097 BYZANTINE MUSICAL SYMBOL ARGON
1D098 BYZANTINE MUSICAL SYMBOL IMIDIARGON
1D099 BYZANTINE MUSICAL SYMBOL DIARGON
1D09A BYZANTINE MUSICAL SYMBOL AGOGI POLI ARGI
1D09B BYZANTINE MUSICAL SYMBOL AGOGI ARGOTERI
1D09C BYZANTINE MUSICAL SYMBOL AGOGI ARGI
1D09D BYZANTINE MUSICAL SYMBOL AGOGI METRIA
1D09E BYZANTINE MUSICAL SYMBOL AGOGI MESI
1D09F BYZANTINE MUSICAL SYMBOL AGOGI GORGI
1D0A0 BYZANTINE MUSICAL SYMBOL AGOGI GORGOTERI
1D0A1 BYZANTINE MUSICAL SYMBOL AGOGI POLI GORGI
1D0A2 BYZANTINE MUSICAL SYMBOL MARTYRIA PROTOS ICHOS
1D0A3 BYZANTINE MUSICAL SYMBOL MARTYRIA ALLI PROTOS ICHOS
1D0A4 BYZANTINE MUSICAL SYMBOL MARTYRIA DEYTEROS ICHOS
1D0A5 BYZANTINE MUSICAL SYMBOL MARTYRIA ALLI DEYTEROS ICHOS
1D0A6 BYZANTINE MUSICAL SYMBOL MARTYRIA TRITOS ICHOS
1D0A7 BYZANTINE MUSICAL SYMBOL MARTYRIA TRIFONIAS
1D0A8 BYZANTINE MUSICAL SYMBOL MARTYRIA TETARTOS ICHOS
1D0A9 BYZANTINE MUSICAL SYMBOL MARTYRIA TETARTOS LEGETOS ICHOS
1D0AA BYZANTINE MUSICAL SYMBOL MARTYRIA LEGETOS ICHOS
1D0AB BYZANTINE MUSICAL SYMBOL MARTYRIA PLAGIOS ICHOS
1D0AC BYZANTINE MUSICAL SYMBOL ISAKIA TELOUS ICHIMATOS
1D0AD BYZANTINE MUSICAL SYMBOL APOSTROFOI TELOUS ICHIMATOS
1D0AE BYZANTINE MUSICAL SYMBOL FANEROSIS TETRAFONIAS
1D0AF BYZANTINE MUSICAL SYMBOL FANEROSIS MONOFONIAS
1D0B0 BYZANTINE MUSICAL SYMBOL FANEROSIS DIFONIAS
1D0B1 BYZANTINE MUSICAL SYMBOL MARTYRIA VARYS ICHOS
1D0B2 BYZANTINE MUSICAL SYMBOL MARTYRIA PROTOVARYS ICHOS
1D0B3 BYZANTINE MUSICAL SYMBOL MARTYRIA PLAGIOS TETARTOS ICHOS
1D0B4 BYZANTINE MUSICAL SYMBOL GORTHMIKON N APLOUN
1D0B5 BYZANTINE MUSICAL SYMBOL GORTHMIKON N DIPLOUN
1D0B6 BYZANTINE MUSICAL SYMBOL ENARXIS KAI FTHORA VOU
1D0B7 BYZANTINE MUSICAL SYMBOL IMIFONON
1D0B8 BYZANTINE MUSICAL SYMBOL IMIFTHORON
1D0B9 BYZANTINE MUSICAL SYMBOL FTHORA ARCHAION DEYTEROU ICHOU
1D0BA BYZANTINE MUSICAL SYMBOL FTHORA DIATONIKI PA
1D0BB BYZANTINE MUSICAL SYMBOL FTHORA DIATONIKI NANA
1D0BC BYZANTINE MUSICAL SYMBOL FTHORA NAOS ICHOS
1D0BD BYZANTINE MUSICAL SYMBOL FTHORA DIATONIKI DI
1D0BE BYZANTINE MUSICAL SYMBOL FTHORA SKLIRON DIATONON DI
1D0BF BYZANTINE MUSICAL SYMBOL FTHORA DIATONIKI KE
1D0C0 BYZANTINE MUSICAL SYMBOL FTHORA DIATONIKI ZO
1D0C1 BYZANTINE MUSICAL SYMBOL FTHORA DIATONIKI NI KATO
1D0C2 BYZANTINE MUSICAL SYMBOL FTHORA DIATONIKI NI ANO
1D0C3 BYZANTINE MUSICAL SYMBOL FTHORA MALAKON CHROMA DIFONIAS
1D0C4 BYZANTINE MUSICAL SYMBOL FTHORA MALAKON CHROMA MONOFONIAS
1D0C5 BYZANTINE MUSICAL SYMBOL FHTORA SKLIRON CHROMA VASIS
1D0C6 BYZANTINE MUSICAL SYMBOL FTHORA SKLIRON CHROMA SYNAFI
1D0C7 BYZANTINE MUSICAL SYMBOL FTHORA NENANO
1D0C8 BYZANTINE MUSICAL SYMBOL CHROA ZYGOS
1D0C9 BYZANTINE MUSICAL SYMBOL CHROA KLITON
1D0CA BYZANTINE MUSICAL SYMBOL CHROA SPATHI
1D0CB BYZANTINE MUSICAL SYMBOL FTHORA I YFESIS TETARTIMORION
1D0CC BYZANTINE MUSICAL SYMBOL FTHORA ENARMONIOS ANTIFONIA
1D0CD BYZANTINE MUSICAL SYMBOL YFESIS TRITIMORION
1D0CE BYZANTINE MUSICAL SYMBOL DIESIS TRITIMORION
1D0CF BYZANTINE MUSICAL SYMBOL DIESIS TETARTIMORION
1D0D0 BYZANTINE MUSICAL SYMBOL DIESIS APLI DYO DODEKATA
1D0D1 BYZANTINE MUSICAL SYMBOL DIESIS MONOGRAMMOS TESSERA DODEKATA
1D0D2 BYZANTINE MUSICAL SYMBOL DIESIS DIGRAMMOS EX DODEKATA
1D0D3 BYZANTINE MUSICAL SYMBOL DIESIS TRIGRAMMOS OKTO DODEKATA
1D0D4 BYZANTINE MUSICAL SYMBOL YFESIS APLI DYO DODEKATA
1D0D5 BYZANTINE MUSICAL SYMBOL YFESIS MONOGRAMMOS TESSERA DODEKATA
1D0D6 BYZANTINE MUSICAL SYMBOL YFESIS DIGRAMMOS EX DODEKATA
1D0D7 BYZANTINE MUSICAL SYMBOL YFESIS TRIGRAMMOS OKTO DODEKATA
1D0D8 BYZANTINE MUSICAL SYMBOL GENIKI DIESIS
1D0D9 BYZANTINE MUSICAL SYMBOL GENIKI YFESIS
1D0DA BYZANTINE MUSICAL SYMBOL DIASTOLI APLI MIKRI
1D0DB BYZANTINE MUSICAL SYMBOL DIASTOLI APLI MEGALI
1D0DC BYZANTINE MUSICAL SYMBOL DIASTOLI DIPLI
1D0DD BYZANTINE MUSICAL SYMBOL DIASTOLI THESEOS
1D0DE BYZANTINE MUSICAL SYMBOL SIMANSIS THESEOS
1D0DF BYZANTINE MUSICAL SYMBOL SIMANSIS THESEOS DISIMOU
1D0E0 BYZANTINE MUSICAL SYMBOL SIMANSIS THESEOS TRISIMOU
1D0E1 BYZANTINE MUSICAL SYMBOL SIMANSIS THESEOS TETRASIMOU
1D0E2 BYZANTINE MUSICAL SYMBOL SIMANSIS ARSEOS
1D0E3 BYZANTINE MUSICAL SYMBOL SIMANSIS ARSEOS DISIMOU
1D0E4 BYZANTINE MUSICAL SYMBOL SIMANSIS ARSEOS TRISIMOU
1D0E5 BYZANTINE MUSICAL SYMBOL SIMANSIS ARSEOS TETRASIMOU
1D0E6 BYZANTINE MUSICAL SYMBOL DIGRAMMA GG
1D0E7 BYZANTINE MUSICAL SYMBOL DIFTOGGOS OU
1D0E8 BYZANTINE MUSICAL SYMBOL STIGMA
1D0E9 BYZANTINE MUSICAL SYMBOL ARKTIKO PA
1D0EA BYZANTINE MUSICAL SYMBOL ARKTIKO VOU
1D0EB BYZANTINE MUSICAL SYMBOL ARKTIKO GA
1D0EC BYZANTINE MUSICAL SYMBOL ARKTIKO DI
1D0ED BYZANTINE MUSICAL SYMBOL ARKTIKO KE
1D0EE BYZANTINE MUSICAL SYMBOL ARKTIKO ZO
1D0EF BYZANTINE MUSICAL SYMBOL ARKTIKO NI
1D0F0 BYZANTINE MUSICAL SYMBOL KENTIMATA NEO MESO
1D0F1 BYZANTINE MUSICAL SYMBOL KENTIMA NEO MESO
1D0F2 BYZANTINE MUSICAL SYMBOL KENTIMATA NEO KATO
1D0F3 BYZANTINE MUSICAL SYMBOL KENTIMA NEO KATO
1D0F4 BYZANTINE MUSICAL SYMBOL KLASMA KATO
1D0F5 BYZANTINE MUSICAL SYMBOL GORGON NEO KATO
1D100 MUSICAL SYMBOL SINGLE BARLINE
1D101 MUSICAL SYMBOL DOUBLE BARLINE
1D102 MUSICAL SYMBOL FINAL BARLINE
1D103 MUSICAL SYMBOL REVERSE FINAL BARLINE
1D104 MUSICAL SYMBOL DASHED BARLINE
1D105 MUSICAL SYMBOL SHORT BARLINE
1D106 MUSICAL SYMBOL LEFT REPEAT SIGN
1D107 MUSICAL SYMBOL RIGHT REPEAT SIGN
1D108 MUSICAL SYMBOL REPEAT DOTS
1D109 MUSICAL SYMBOL DAL SEGNO
1D10A MUSICAL SYMBOL DA CAPO
1D10B MUSICAL SYMBOL SEGNO
1D10C MUSICAL SYMBOL CODA
1D10D MUSICAL SYMBOL REPEATED FIGURE-1
1D10E MUSICAL SYMBOL REPEATED FIGURE-2
1D10F MUSICAL SYMBOL REPEATED FIGURE-3
1D110 MUSICAL SYMBOL FERMATA
1D111 MUSICAL SYMBOL FERMATA BELOW
1D112 MUSICAL SYMBOL BREATH MARK
1D113 MUSICAL SYMBOL CAESURA
1D114 MUSICAL SYMBOL BRACE
1D115 MUSICAL SYMBOL BRACKET
1D116 MUSICAL SYMBOL ONE-LINE STAFF
1D117 MUSICAL SYMBOL TWO-LINE STAFF
1D118 MUSICAL SYMBOL THREE-LINE STAFF
1D119 MUSICAL SYMBOL FOUR-LINE STAFF
1D11A MUSICAL SYMBOL FIVE-LINE STAFF
1D11B MUSICAL SYMBOL SIX-LINE STAFF
1D11C MUSICAL SYMBOL SIX-STRING FRETBOARD
1D11D MUSICAL SYMBOL FOUR-STRING FRETBOARD
1D11E MUSICAL SYMBOL G CLEF
1D11F MUSICAL SYMBOL G CLEF OTTAVA ALTA
1D120 MUSICAL SYMBOL G CLEF OTTAVA BASSA
1D121 MUSICAL SYMBOL C CLEF
1D122 MUSICAL SYMBOL F CLEF
1D123 MUSICAL SYMBOL F CLEF OTTAVA ALTA
1D124 MUSICAL SYMBOL F CLEF OTTAVA BASSA
1D125 MUSICAL SYMBOL DRUM CLEF-1
1D126 MUSICAL SYMBOL DRUM CLEF-2
1D12A MUSICAL SYMBOL DOUBLE SHARP
1D12B MUSICAL SYMBOL DOUBLE FLAT
1D12C MUSICAL SYMBOL FLAT UP
1D12D MUSICAL SYMBOL FLAT DOWN
1D12E MUSICAL SYMBOL NATURAL UP
1D12F MUSICAL SYMBOL NATURAL DOWN
1D130 MUSICAL SYMBOL SHARP UP
1D131 MUSICAL SYMBOL SHARP DOWN
1D132 MUSICAL SYMBOL QUARTER TONE SHARP
1D133 MUSICAL SYMBOL QUARTER TONE FLAT
1D134 MUSICAL SYMBOL COMMON TIME
1D135 MUSICAL SYMBOL CUT TIME
1D136 MUSICAL SYMBOL OTTAVA ALTA
1D137 MUSICAL SYMBOL OTTAVA BASSA
1D138 MUSICAL SYMBOL QUINDICESIMA ALTA
1D139 MUSICAL SYMBOL QUINDICESIMA BASSA
1D13A MUSICAL SYMBOL MULTI REST
1D13B MUSICAL SYMBOL WHOLE REST
1D13C MUSICAL SYMBOL HALF REST
1D13D MUSICAL SYMBOL QUARTER REST
1D13E MUSICAL SYMBOL EIGHTH REST
1D13F MUSICAL SYMBOL SIXTEENTH REST
1D140 MUSICAL SYMBOL THIRTY-SECOND REST
1D141 MUSICAL SYMBOL SIXTY-FOURTH REST
1D142 MUSICAL SYMBOL ONE HUNDRED TWENTY-EIGHTH REST
1D143 MUSICAL SYMBOL X NOTEHEAD
1D144 MUSICAL SYMBOL PLUS NOTEHEAD
1D145 MUSICAL SYMBOL CIRCLE X NOTEHEAD
1D146 MUSICAL SYMBOL SQUARE NOTEHEAD WHITE
1D147 MUSICAL SYMBOL SQUARE NOTEHEAD BLACK
1D148 MUSICAL SYMBOL TRIANGLE NOTEHEAD UP WHITE
1D149 MUSICAL SYMBOL TRIANGLE NOTEHEAD UP BLACK
1D14A MUSICAL SYMBOL TRIANGLE NOTEHEAD LEFT WHITE
1D14B MUSICAL SYMBOL TRIANGLE NOTEHEAD LEFT BLACK
1D14C MUSICAL SYMBOL TRIANGLE NOTEHEAD RIGHT WHITE
1D14D MUSICAL SYMBOL TRIANGLE NOTEHEAD RIGHT BLACK
1D14E MUSICAL SYMBOL TRIANGLE NOTEHEAD DOWN WHITE
1D14F MUSICAL SYMBOL TRIANGLE NOTEHEAD DOWN BLACK
1D150 MUSICAL SYMBOL TRIANGLE NOTEHEAD UP RIGHT WHITE
1D151 MUSICAL SYMBOL TRIANGLE NOTEHEAD UP RIGHT BLACK
1D152 MUSICAL SYMBOL MOON NOTEHEAD WHITE
1D153 MUSICAL SYMBOL MOON NOTEHEAD BLACK
1D154 MUSICAL SYMBOL TRIANGLE-ROUND NOTEHEAD DOWN WHITE
1D155 MUSICAL SYMBOL TRIANGLE-ROUND NOTEHEAD DOWN BLACK
1D156 MUSICAL SYMBOL PARENTHESIS NOTEHEAD
1D157 MUSICAL SYMBOL VOID NOTEHEAD
1D158 MUSICAL SYMBOL NOTEHEAD BLACK
1D159 MUSICAL SYMBOL NULL NOTEHEAD
1D15A MUSICAL SYMBOL CLUSTER NOTEHEAD WHITE
1D15B MUSICAL SYMBOL CLUSTER NOTEHEAD BLACK
1D15C MUSICAL SYMBOL BREVE
1D15D MUSICAL SYMBOL WHOLE NOTE
1D15E MUSICAL SYMBOL HALF NOTE
1D15F MUSICAL SYMBOL QUARTER NOTE
1D160 MUSICAL SYMBOL EIGHTH NOTE
1D161 MUSICAL SYMBOL SIXTEENTH NOTE
1D162 MUSICAL SYMBOL THIRTY-SECOND NOTE
1D163 MUSICAL SYMBOL SIXTY-FOURTH NOTE
1D164 MUSICAL SYMBOL ONE HUNDRED TWENTY-EIGHTH NOTE
1D165 MUSICAL SYMBOL COMBINING STEM
1D166 MUSICAL SYMBOL COMBINING SPRECHGESANG STEM
1D167 MUSICAL SYMBOL COMBINING TREMOLO-1
1D168 MUSICAL SYMBOL COMBINING TREMOLO-2
1D169 MUSICAL SYMBOL COMBINING TREMOLO-3
1D16A MUSICAL SYMBOL FINGERED TREMOLO-1
1D16B MUSICAL SYMBOL FINGERED TREMOLO-2
1D16C MUSICAL SYMBOL FINGERED TREMOLO-3
1D16D MUSICAL SYMBOL COMBINING AUGMENTATION DOT
1D16E MUSICAL SYMBOL COMBINING FLAG-1
1D16F MUSICAL SYMBOL COMBINING FLAG-2
1D170 MUSICAL SYMBOL COMBINING FLAG-3
1D171 MUSICAL SYMBOL COMBINING FLAG-4
1D172 MUSICAL SYMBOL COMBINING FLAG-5
1D173 MUSICAL SYMBOL BEGIN BEAM
1D174 MUSICAL SYMBOL END BEAM
1D175 MUSICAL SYMBOL BEGIN TIE
1D176 MUSICAL SYMBOL END TIE
1D177 MUSICAL SYMBOL BEGIN SLUR
1D178 MUSICAL SYMBOL END SLUR
1D179 MUSICAL SYMBOL BEGIN PHRASE
1D17A MUSICAL SYMBOL END PHRASE
1D17B MUSICAL SYMBOL COMBINING ACCENT
1D17C MUSICAL SYMBOL COMBINING STACCATO
1D17D MUSICAL SYMBOL COMBINING TENUTO
1D17E MUSICAL SYMBOL COMBINING STACCATISSIMO
1D17F MUSICAL SYMBOL COMBINING MARCATO
1D180 MUSICAL SYMBOL COMBINING MARCATO-STACCATO
1D181 MUSICAL SYMBOL COMBINING ACCENT-STACCATO
1D182 MUSICAL SYMBOL COMBINING LOURE
1D183 MUSICAL SYMBOL ARPEGGIATO UP
1D184 MUSICAL SYMBOL ARPEGGIATO DOWN
1D185 MUSICAL SYMBOL COMBINING DOIT
1D186 MUSICAL SYMBOL COMBINING RIP
1D187 MUSICAL SYMBOL COMBINING FLIP
1D188 MUSICAL SYMBOL COMBINING SMEAR
1D189 MUSICAL SYMBOL COMBINING BEND
1D18A MUSICAL SYMBOL COMBINING DOUBLE TONGUE
1D18B MUSICAL SYMBOL COMBINING TRIPLE TONGUE
1D18C MUSICAL SYMBOL RINFORZANDO
1D18D MUSICAL SYMBOL SUBITO
1D18E MUSICAL SYMBOL Z
1D18F MUSICAL SYMBOL PIANO
1D190 MUSICAL SYMBOL MEZZO
1D191 MUSICAL SYMBOL FORTE
1D192 MUSICAL SYMBOL CRESCENDO
1D193 MUSICAL SYMBOL DECRESCENDO
1D194 MUSICAL SYMBOL GRACE NOTE SLASH
1D195 MUSICAL SYMBOL GRACE NOTE NO SLASH
1D196 MUSICAL SYMBOL TR
1D197 MUSICAL SYMBOL TURN
1D198 MUSICAL SYMBOL INVERTED TURN
1D199 MUSICAL SYMBOL TURN SLASH
1D19A MUSICAL SYMBOL TURN UP
1D19B MUSICAL SYMBOL ORNAMENT STROKE-1
1D19C MUSICAL SYMBOL ORNAMENT STROKE-2
1D19D MUSICAL SYMBOL ORNAMENT STROKE-3
1D19E MUSICAL SYMBOL ORNAMENT STROKE-4
1D19F MUSICAL SYMBOL ORNAMENT STROKE-5
1D1A0 MUSICAL SYMBOL ORNAMENT STROKE-6
1D1A1 MUSICAL SYMBOL ORNAMENT STROKE-7
1D1A2 MUSICAL SYMBOL ORNAMENT STROKE-8
1D1A3 MUSICAL SYMBOL ORNAMENT STROKE-9
1D1A4 MUSICAL SYMBOL ORNAMENT STROKE-10
1D1A5 MUSICAL SYMBOL ORNAMENT STROKE-11
1D1A6 MUSICAL SYMBOL HAUPTSTIMME
1D1A7 MUSICAL SYMBOL NEBENSTIMME
1D1A8 MUSICAL SYMBOL END OF STIMME
1D1A9 MUSICAL SYMBOL DEGREE SLASH
1D1AA MUSICAL SYMBOL COMBINING DOWN BOW
1D1AB MUSICAL SYMBOL COMBINING UP BOW
1D1AC MUSICAL SYMBOL COMBINING HARMONIC
1D1AD MUSICAL SYMBOL COMBINING SNAP PIZZICATO
1D1AE MUSICAL SYMBOL PEDAL MARK
1D1AF MUSICAL SYMBOL PEDAL UP MARK
1D1B0 MUSICAL SYMBOL HALF PEDAL MARK
1D1B1 MUSICAL SYMBOL GLISSANDO UP
1D1B2 MUSICAL SYMBOL GLISSANDO DOWN
1D1B3 MUSICAL SYMBOL WITH FINGERNAILS
1D1B4 MUSICAL SYMBOL DAMP
1D1B5 MUSICAL SYMBOL DAMP ALL
1D1B6 MUSICAL SYMBOL MAXIMA
1D1B7 MUSICAL SYMBOL LONGA
1D1B8 MUSICAL SYMBOL BREVIS
1D1B9 MUSICAL SYMBOL SEMIBREVIS WHITE
1D1BA MUSICAL SYMBOL SEMIBREVIS BLACK
1D1BB MUSICAL SYMBOL MINIMA
1D1BC MUSICAL SYMBOL MINIMA BLACK
1D1BD MUSICAL SYMBOL SEMIMINIMA WHITE
1D1BE MUSICAL SYMBOL SEMIMINIMA BLACK
1D1BF MUSICAL SYMBOL FUSA WHITE
1D1C0 MUSICAL SYMBOL FUSA BLACK
1D1C1 MUSICAL SYMBOL LONGA PERFECTA REST
1D1C2 MUSICAL SYMBOL LONGA IMPERFECTA REST
1D1C3 MUSICAL SYMBOL BREVIS REST
1D1C4 MUSICAL SYMBOL SEMIBREVIS REST
1D1C5 MUSICAL SYMBOL MINIMA REST
1D1C6 MUSICAL SYMBOL SEMIMINIMA REST
1D1C7 MUSICAL SYMBOL TEMPUS PERFECTUM CUM PROLATIONE PERFECTA
1D1C8 MUSICAL SYMBOL TEMPUS PERFECTUM CUM PROLATIONE IMPERFECTA
1D1C9 MUSICAL SYMBOL TEMPUS PERFECTUM CUM PROLATIONE PERFECTA DIMINUTION-1
1D1CA MUSICAL SYMBOL TEMPUS IMPERFECTUM CUM PROLATIONE PERFECTA
1D1CB MUSICAL SYMBOL TEMPUS IMPERFECTUM CUM PROLATIONE IMPERFECTA
1D1CC MUSICAL SYMBOL TEMPUS IMPERFECTUM CUM PROLATIONE IMPERFECTA DIMINUTION-1
1D1CD MUSICAL SYMBOL TEMPUS IMPERFECTUM CUM PROLATIONE IMPERFECTA DIMINUTION-2
1D1CE MUSICAL SYMBOL TEMPUS IMPERFECTUM CUM PROLATIONE IMPERFECTA DIMINUTION-3
1D1CF MUSICAL SYMBOL CROIX
1D1D0 MUSICAL SYMBOL GREGORIAN C CLEF
1D1D1 MUSICAL SYMBOL GREGORIAN F CLEF
1D1D2 MUSICAL SYMBOL SQUARE B
1D1D3 MUSICAL SYMBOL VIRGA
1D1D4 MUSICAL SYMBOL PODATUS
1D1D5 MUSICAL SYMBOL CLIVIS
1D1D6 MUSICAL SYMBOL SCANDICUS
1D1D7 MUSICAL SYMBOL CLIMACUS
1D1D8 MUSICAL SYMBOL TORCULUS
1D1D9 MUSICAL SYMBOL PORRECTUS
1D1DA MUSICAL SYMBOL PORRECTUS FLEXUS
1D1DB MUSICAL SYMBOL SCANDICUS FLEXUS
1D1DC MUSICAL SYMBOL TORCULUS RESUPINUS
1D1DD MUSICAL SYMBOL PES SUBPUNCTIS
1D200 GREEK VOCAL NOTATION SYMBOL-1
1D201 GREEK VOCAL NOTATION SYMBOL-2
1D202 GREEK VOCAL NOTATION SYMBOL-3
1D203 GREEK VOCAL NOTATION SYMBOL-4
1D204 GREEK VOCAL NOTATION SYMBOL-5
1D205 GREEK VOCAL NOTATION SYMBOL-6
1D206 GREEK VOCAL NOTATION SYMBOL-7
1D207 GREEK VOCAL NOTATION SYMBOL-8
1D208 GREEK VOCAL NOTATION SYMBOL-9
1D209 GREEK VOCAL NOTATION SYMBOL-10
1D20A GREEK VOCAL NOTATION SYMBOL-11
1D20B GREEK VOCAL NOTATION SYMBOL-12
1D20C GREEK VOCAL NOTATION SYMBOL-13
1D20D GREEK VOCAL NOTATION SYMBOL-14
1D20E GREEK VOCAL NOTATION SYMBOL-15
1D20F GREEK VOCAL NOTATION SYMBOL-16
1D210 GREEK VOCAL NOTATION SYMBOL-17
1D211 GREEK VOCAL NOTATION SYMBOL-18
1D212 GREEK VOCAL NOTATION SYMBOL-19
1D213 GREEK VOCAL NOTATION SYMBOL-20
1D214 GREEK VOCAL NOTATION SYMBOL-21
1D215 GREEK VOCAL NOTATION SYMBOL-22
1D216 GREEK VOCAL NOTATION SYMBOL-23
1D217 GREEK VOCAL NOTATION SYMBOL-24
1D218 GREEK VOCAL NOTATION SYMBOL-50
1D219 GREEK VOCAL NOTATION SYMBOL-51
1D21A GREEK VOCAL NOTATION SYMBOL-52
1D21B GREEK VOCAL NOTATION SYMBOL-53
1D21C GREEK VOCAL NOTATION SYMBOL-54
1D21D GREEK INSTRUMENTAL NOTATION SYMBOL-1
1D21E GREEK INSTRUMENTAL NOTATION SYMBOL-2
1D21F GREEK INSTRUMENTAL NOTATION SYMBOL-4
1D220 GREEK INSTRUMENTAL NOTATION SYMBOL-5
1D221 GREEK INSTRUMENTAL NOTATION SYMBOL-7
1D222 GREEK INSTRUMENTAL NOTATION SYMBOL-8
1D223 GREEK INSTRUMENTAL NOTATION SYMBOL-11
1D224 GREEK INSTRUMENTAL NOTATION SYMBOL-12
1D225 GREEK INSTRUMENTAL NOTATION SYMBOL-13
1D226 GREEK INSTRUMENTAL NOTATION SYMBOL-14
1D227 GREEK INSTRUMENTAL NOTATION SYMBOL-17
1D228 GREEK INSTRUMENTAL NOTATION SYMBOL-18
1D229 GREEK INSTRUMENTAL NOTATION SYMBOL-19
1D22A GREEK INSTRUMENTAL NOTATION SYMBOL-23
1D22B GREEK INSTRUMENTAL NOTATION SYMBOL-24
1D22C GREEK INSTRUMENTAL NOTATION SYMBOL-25
1D22D GREEK INSTRUMENTAL NOTATION SYMBOL-26
1D22E GREEK INSTRUMENTAL NOTATION SYMBOL-27
1D22F GREEK INSTRUMENTAL NOTATION SYMBOL-29
1D230 GREEK INSTRUMENTAL NOTATION SYMBOL-30
1D231 GREEK INSTRUMENTAL NOTATION SYMBOL-32
1D232 GREEK INSTRUMENTAL NOTATION SYMBOL-36
1D233 GREEK INSTRUMENTAL NOTATION SYMBOL-37
1D234 GREEK INSTRUMENTAL NOTATION SYMBOL-38
1D235 GREEK INSTRUMENTAL NOTATION SYMBOL-39
1D236 GREEK INSTRUMENTAL NOTATION SYMBOL-40
1D237 GREEK INSTRUMENTAL NOTATION SYMBOL-42
1D238 GREEK INSTRUMENTAL NOTATION SYMBOL-43
1D239 GREEK INSTRUMENTAL NOTATION SYMBOL-45
1D23A GREEK INSTRUMENTAL NOTATION SYMBOL-47
1D23B GREEK INSTRUMENTAL NOTATION SYMBOL-48
1D23C GREEK INSTRUMENTAL NOTATION SYMBOL-49
1D23D GREEK INSTRUMENTAL NOTATION SYMBOL-50
1D23E GREEK INSTRUMENTAL NOTATION SYMBOL-51
1D23F GREEK INSTRUMENTAL NOTATION SYMBOL-52
1D240 GREEK INSTRUMENTAL NOTATION SYMBOL-53
1D241 GREEK INSTRUMENTAL NOTATION SYMBOL-54
1D242 COMBINING GREEK MUSICAL TRISEME
1D243 COMBINING GREEK MUSICAL TETRASEME
1D244 COMBINING GREEK MUSICAL PENTASEME
1D245 GREEK MUSICAL LEIMMA
1D300 MONOGRAM FOR EARTH
1D301 DIGRAM FOR HEAVENLY EARTH
1D302 DIGRAM FOR HUMAN EARTH
1D303 DIGRAM FOR EARTHLY HEAVEN
1D304 DIGRAM FOR EARTHLY HUMAN
1D305 DIGRAM FOR EARTH
1D306 TETRAGRAM FOR CENTRE
1D307 TETRAGRAM FOR FULL CIRCLE
1D308 TETRAGRAM FOR MIRED
1D309 TETRAGRAM FOR BARRIER
1D30A TETRAGRAM FOR KEEPING SMALL
1D30B TETRAGRAM FOR CONTRARIETY
1D30C TETRAGRAM FOR ASCENT
1D30D TETRAGRAM FOR OPPOSITION
1D30E TETRAGRAM FOR BRANCHING OUT
1D30F TETRAGRAM FOR DEFECTIVENESS OR DISTORTION
1D310 TETRAGRAM FOR DIVERGENCE
1D311 TETRAGRAM FOR YOUTHFULNESS
1D312 TETRAGRAM FOR INCREASE
1D313 TETRAGRAM FOR PENETRATION
1D314 TETRAGRAM FOR REACH
1D315 TETRAGRAM FOR CONTACT
1D316 TETRAGRAM FOR HOLDING BACK
1D317 TETRAGRAM FOR WAITING
1D318 TETRAGRAM FOR FOLLOWING
1D319 TETRAGRAM FOR ADVANCE
1D31A TETRAGRAM FOR RELEASE
1D31B TETRAGRAM FOR RESISTANCE
1D31C TETRAGRAM FOR EASE
1D31D TETRAGRAM FOR JOY
1D31E TETRAGRAM FOR CONTENTION
1D31F TETRAGRAM FOR ENDEAVOUR
1D320 TETRAGRAM FOR DUTIES
1D321 TETRAGRAM FOR CHANGE
1D322 TETRAGRAM FOR DECISIVENESS
1D323 TETRAGRAM FOR BOLD RESOLUTION
1D324 TETRAGRAM FOR PACKING
1D325 TETRAGRAM FOR LEGION
1D326 TETRAGRAM FOR CLOSENESS
1D327 TETRAGRAM FOR KINSHIP
1D328 TETRAGRAM FOR GATHERING
1D329 TETRAGRAM FOR STRENGTH
1D32A TETRAGRAM FOR PURITY
1D32B TETRAGRAM FOR FULLNESS
1D32C TETRAGRAM FOR RESIDENCE
1D32D TETRAGRAM FOR LAW OR MODEL
1D32E TETRAGRAM FOR RESPONSE
1D32F TETRAGRAM FOR GOING TO MEET
1D330 TETRAGRAM FOR ENCOUNTERS
1D331 TETRAGRAM FOR STOVE
1D332 TETRAGRAM FOR GREATNESS
1D333 TETRAGRAM FOR ENLARGEMENT
1D334 TETRAGRAM FOR PATTERN
1D335 TETRAGRAM FOR RITUAL
1D336 TETRAGRAM FOR FLIGHT
1D337 TETRAGRAM FOR VASTNESS OR WASTING
1D338 TETRAGRAM FOR CONSTANCY
1D339 TETRAGRAM FOR MEASURE
1D33A TETRAGRAM FOR ETERNITY
1D33B TETRAGRAM FOR UNITY
1D33C TETRAGRAM FOR DIMINISHMENT
1D33D TETRAGRAM FOR CLOSED MOUTH
1D33E TETRAGRAM FOR GUARDEDNESS
1D33F TETRAGRAM FOR GATHERING IN
1D340 TETRAGRAM FOR MASSING
1D341 TETRAGRAM FOR ACCUMULATION
1D342 TETRAGRAM FOR EMBELLISHMENT
1D343 TETRAGRAM FOR DOUBT
1D344 TETRAGRAM FOR WATCH
1D345 TETRAGRAM FOR SINKING
1D346 TETRAGRAM FOR INNER
1D347 TETRAGRAM FOR DEPARTURE
1D348 TETRAGRAM FOR DARKENING
1D349 TETRAGRAM FOR DIMMING
1D34A TETRAGRAM FOR EXHAUSTION
1D34B TETRAGRAM FOR SEVERANCE
1D34C TETRAGRAM FOR STOPPAGE
1D34D TETRAGRAM FOR HARDNESS
1D34E TETRAGRAM FOR COMPLETION
1D34F TETRAGRAM FOR CLOSURE
1D350 TETRAGRAM FOR FAILURE
1D351 TETRAGRAM FOR AGGRAVATION
1D352 TETRAGRAM FOR COMPLIANCE
1D353 TETRAGRAM FOR ON THE VERGE
1D354 TETRAGRAM FOR DIFFICULTIES
1D355 TETRAGRAM FOR LABOURING
1D356 TETRAGRAM FOR FOSTERING
1D400 MATHEMATICAL BOLD CAPITAL A
1D401 MATHEMATICAL BOLD CAPITAL B
1D402 MATHEMATICAL BOLD CAPITAL C
1D403 MATHEMATICAL BOLD CAPITAL D
1D404 MATHEMATICAL BOLD CAPITAL E
1D405 MATHEMATICAL BOLD CAPITAL F
1D406 MATHEMATICAL BOLD CAPITAL G
1D407 MATHEMATICAL BOLD CAPITAL H
1D408 MATHEMATICAL BOLD CAPITAL I
1D409 MATHEMATICAL BOLD CAPITAL J
1D40A MATHEMATICAL BOLD CAPITAL K
1D40B MATHEMATICAL BOLD CAPITAL L
1D40C MATHEMATICAL BOLD CAPITAL M
1D40D MATHEMATICAL BOLD CAPITAL N
1D40E MATHEMATICAL BOLD CAPITAL O
1D40F MATHEMATICAL BOLD CAPITAL P
1D410 MATHEMATICAL BOLD CAPITAL Q
1D411 MATHEMATICAL BOLD CAPITAL R
1D412 MATHEMATICAL BOLD CAPITAL S
1D413 MATHEMATICAL BOLD CAPITAL T
1D414 MATHEMATICAL BOLD CAPITAL U
1D415 MATHEMATICAL BOLD CAPITAL V
1D416 MATHEMATICAL BOLD CAPITAL W
1D417 MATHEMATICAL BOLD CAPITAL X
1D418 MATHEMATICAL BOLD CAPITAL Y
1D419 MATHEMATICAL BOLD CAPITAL Z
1D41A MATHEMATICAL BOLD SMALL A
1D41B MATHEMATICAL BOLD SMALL B
1D41C MATHEMATICAL BOLD SMALL C
1D41D MATHEMATICAL BOLD SMALL D
1D41E MATHEMATICAL BOLD SMALL E
1D41F MATHEMATICAL BOLD SMALL F
1D420 MATHEMATICAL BOLD SMALL G
1D421 MATHEMATICAL BOLD SMALL H
1D422 MATHEMATICAL BOLD SMALL I
1D423 MATHEMATICAL BOLD SMALL J
1D424 MATHEMATICAL BOLD SMALL K
1D425 MATHEMATICAL BOLD SMALL L
1D426 MATHEMATICAL BOLD SMALL M
1D427 MATHEMATICAL BOLD SMALL N
1D428 MATHEMATICAL BOLD SMALL O
1D429 MATHEMATICAL BOLD SMALL P
1D42A MATHEMATICAL BOLD SMALL Q
1D42B MATHEMATICAL BOLD SMALL R
1D42C MATHEMATICAL BOLD SMALL S
1D42D MATHEMATICAL BOLD SMALL T
1D42E MATHEMATICAL BOLD SMALL U
1D42F MATHEMATICAL BOLD SMALL V
1D430 MATHEMATICAL BOLD SMALL W
1D431 MATHEMATICAL BOLD SMALL X
1D432 MATHEMATICAL BOLD SMALL Y
1D433 MATHEMATICAL BOLD SMALL Z
1D434 MATHEMATICAL ITALIC CAPITAL A
1D435 MATHEMATICAL ITALIC CAPITAL B
1D436 MATHEMATICAL ITALIC CAPITAL C
1D437 MATHEMATICAL ITALIC CAPITAL D
1D438 MATHEMATICAL ITALIC CAPITAL E
1D439 MATHEMATICAL ITALIC CAPITAL F
1D43A MATHEMATICAL ITALIC CAPITAL G
1D43B MATHEMATICAL ITALIC CAPITAL H
1D43C MATHEMATICAL ITALIC CAPITAL I
1D43D MATHEMATICAL ITALIC CAPITAL J
1D43E MATHEMATICAL ITALIC CAPITAL K
1D43F MATHEMATICAL ITALIC CAPITAL L
1D440 MATHEMATICAL ITALIC CAPITAL M
1D441 MATHEMATICAL ITALIC CAPITAL N
1D442 MATHEMATICAL ITALIC CAPITAL O
1D443 MATHEMATICAL ITALIC CAPITAL P
1D444 MATHEMATICAL ITALIC CAPITAL Q
1D445 MATHEMATICAL ITALIC CAPITAL R
1D446 MATHEMATICAL ITALIC CAPITAL S
1D447 MATHEMATICAL ITALIC CAPITAL T
1D448 MATHEMATICAL ITALIC CAPITAL U
1D449 MATHEMATICAL ITALIC CAPITAL V
1D44A MATHEMATICAL ITALIC CAPITAL W
1D44B MATHEMATICAL ITALIC CAPITAL X
1D44C MATHEMATICAL ITALIC CAPITAL Y
1D44D MATHEMATICAL ITALIC CAPITAL Z
1D44E MATHEMATICAL ITALIC SMALL A
1D44F MATHEMATICAL ITALIC SMALL B
1D450 MATHEMATICAL ITALIC SMALL C
1D451 MATHEMATICAL ITALIC SMALL D
1D452 MATHEMATICAL ITALIC SMALL E
1D453 MATHEMATICAL ITALIC SMALL F
1D454 MATHEMATICAL ITALIC SMALL G
1D456 MATHEMATICAL ITALIC SMALL I
1D457 MATHEMATICAL ITALIC SMALL J
1D458 MATHEMATICAL ITALIC SMALL K
1D459 MATHEMATICAL ITALIC SMALL L
1D45A MATHEMATICAL ITALIC SMALL M
1D45B MATHEMATICAL ITALIC SMALL N
1D45C MATHEMATICAL ITALIC SMALL O
1D45D MATHEMATICAL ITALIC SMALL P
1D45E MATHEMATICAL ITALIC SMALL Q
1D45F MATHEMATICAL ITALIC SMALL R
1D460 MATHEMATICAL ITALIC SMALL S
1D461 MATHEMATICAL ITALIC SMALL T
1D462 MATHEMATICAL ITALIC SMALL U
1D463 MATHEMATICAL ITALIC SMALL V
1D464 MATHEMATICAL ITALIC SMALL W
1D465 MATHEMATICAL ITALIC SMALL X
1D466 MATHEMATICAL ITALIC SMALL Y
1D467 MATHEMATICAL ITALIC SMALL Z
1D468 MATHEMATICAL BOLD ITALIC CAPITAL A
1D469 MATHEMATICAL BOLD ITALIC CAPITAL B
1D46A MATHEMATICAL BOLD ITALIC CAPITAL C
1D46B MATHEMATICAL BOLD ITALIC CAPITAL D
1D46C MATHEMATICAL BOLD ITALIC CAPITAL E
1D46D MATHEMATICAL BOLD ITALIC CAPITAL F
1D46E MATHEMATICAL BOLD ITALIC CAPITAL G
1D46F MATHEMATICAL BOLD ITALIC CAPITAL H
1D470 MATHEMATICAL BOLD ITALIC CAPITAL I
1D471 MATHEMATICAL BOLD ITALIC CAPITAL J
1D472 MATHEMATICAL BOLD ITALIC CAPITAL K
1D473 MATHEMATICAL BOLD ITALIC CAPITAL L
1D474 MATHEMATICAL BOLD ITALIC CAPITAL M
1D475 MATHEMATICAL BOLD ITALIC CAPITAL N
1D476 MATHEMATICAL BOLD ITALIC CAPITAL O
1D477 MATHEMATICAL BOLD ITALIC CAPITAL P
1D478 MATHEMATICAL BOLD ITALIC CAPITAL Q
1D479 MATHEMATICAL BOLD ITALIC CAPITAL R
1D47A MATHEMATICAL BOLD ITALIC CAPITAL S
1D47B MATHEMATICAL BOLD ITALIC CAPITAL T
1D47C MATHEMATICAL BOLD ITALIC CAPITAL U
1D47D MATHEMATICAL BOLD ITALIC CAPITAL V
1D47E MATHEMATICAL BOLD ITALIC CAPITAL W
1D47F MATHEMATICAL BOLD ITALIC CAPITAL X
1D480 MATHEMATICAL BOLD ITALIC CAPITAL Y
1D481 MATHEMATICAL BOLD ITALIC CAPITAL Z
1D482 MATHEMATICAL BOLD ITALIC SMALL A
1D483 MATHEMATICAL BOLD ITALIC SMALL B
1D484 MATHEMATICAL BOLD ITALIC SMALL C
1D485 MATHEMATICAL BOLD ITALIC SMALL D
1D486 MATHEMATICAL BOLD ITALIC SMALL E
1D487 MATHEMATICAL BOLD ITALIC SMALL F
1D488 MATHEMATICAL BOLD ITALIC SMALL G
1D489 MATHEMATICAL BOLD ITALIC SMALL H
1D48A MATHEMATICAL BOLD ITALIC SMALL I
1D48B MATHEMATICAL BOLD ITALIC SMALL J
1D48C MATHEMATICAL BOLD ITALIC SMALL K
1D48D MATHEMATICAL BOLD ITALIC SMALL L
1D48E MATHEMATICAL BOLD ITALIC SMALL M
1D48F MATHEMATICAL BOLD ITALIC SMALL N
1D490 MATHEMATICAL BOLD ITALIC SMALL O
1D491 MATHEMATICAL BOLD ITALIC SMALL P
1D492 MATHEMATICAL BOLD ITALIC SMALL Q
1D493 MATHEMATICAL BOLD ITALIC SMALL R
1D494 MATHEMATICAL BOLD ITALIC SMALL S
1D495 MATHEMATICAL BOLD ITALIC SMALL T
1D496 MATHEMATICAL BOLD ITALIC SMALL U
1D497 MATHEMATICAL BOLD ITALIC SMALL V
1D498 MATHEMATICAL BOLD ITALIC SMALL W
1D499 MATHEMATICAL BOLD ITALIC SMALL X
1D49A MATHEMATICAL BOLD ITALIC SMALL Y
1D49B MATHEMATICAL BOLD ITALIC SMALL Z
1D49C MATHEMATICAL SCRIPT CAPITAL A
1D49E MATHEMATICAL SCRIPT CAPITAL C
1D49F MATHEMATICAL SCRIPT CAPITAL D
1D4A2 MATHEMATICAL SCRIPT CAPITAL G
1D4A5 MATHEMATICAL SCRIPT CAPITAL J
1D4A6 MATHEMATICAL SCRIPT CAPITAL K
1D4A9 MATHEMATICAL SCRIPT CAPITAL N
1D4AA MATHEMATICAL SCRIPT CAPITAL O
1D4AB MATHEMATICAL SCRIPT CAPITAL P
1D4AC MATHEMATICAL SCRIPT CAPITAL Q
1D4AE MATHEMATICAL SCRIPT CAPITAL S
1D4AF MATHEMATICAL SCRIPT CAPITAL T
1D4B0 MATHEMATICAL SCRIPT CAPITAL U
1D4B1 MATHEMATICAL SCRIPT CAPITAL V
1D4B2 MATHEMATICAL SCRIPT CAPITAL W
1D4B3 MATHEMATICAL SCRIPT CAPITAL X
1D4B4 MATHEMATICAL SCRIPT CAPITAL Y
1D4B5 MATHEMATICAL SCRIPT CAPITAL Z
1D4B6 MATHEMATICAL SCRIPT SMALL A
1D4B7 MATHEMATICAL SCRIPT SMALL B
1D4B8 MATHEMATICAL SCRIPT SMALL C
1D4B9 MATHEMATICAL SCRIPT SMALL D
1D4BB MATHEMATICAL SCRIPT SMALL F
1D4BD MATHEMATICAL SCRIPT SMALL H
1D4BE MATHEMATICAL SCRIPT SMALL I
1D4BF MATHEMATICAL SCRIPT SMALL J
1D4C0 MATHEMATICAL SCRIPT SMALL K
1D4C1 MATHEMATICAL SCRIPT SMALL L
1D4C2 MATHEMATICAL SCRIPT SMALL M
1D4C3 MATHEMATICAL SCRIPT SMALL N
1D4C5 MATHEMATICAL SCRIPT SMALL P
1D4C6 MATHEMATICAL SCRIPT SMALL Q
1D4C7 MATHEMATICAL SCRIPT SMALL R
1D4C8 MATHEMATICAL SCRIPT SMALL S
1D4C9 MATHEMATICAL SCRIPT SMALL T
1D4CA MATHEMATICAL SCRIPT SMALL U
1D4CB MATHEMATICAL SCRIPT SMALL V
1D4CC MATHEMATICAL SCRIPT SMALL W
1D4CD MATHEMATICAL SCRIPT SMALL X
1D4CE MATHEMATICAL SCRIPT SMALL Y
1D4CF MATHEMATICAL SCRIPT SMALL Z
1D4D0 MATHEMATICAL BOLD SCRIPT CAPITAL A
1D4D1 MATHEMATICAL BOLD SCRIPT CAPITAL B
1D4D2 MATHEMATICAL BOLD SCRIPT CAPITAL C
1D4D3 MATHEMATICAL BOLD SCRIPT CAPITAL D
1D4D4 MATHEMATICAL BOLD SCRIPT CAPITAL E
1D4D5 MATHEMATICAL BOLD SCRIPT CAPITAL F
1D4D6 MATHEMATICAL BOLD SCRIPT CAPITAL G
1D4D7 MATHEMATICAL BOLD SCRIPT CAPITAL H
1D4D8 MATHEMATICAL BOLD SCRIPT CAPITAL I
1D4D9 MATHEMATICAL BOLD SCRIPT CAPITAL J
1D4DA MATHEMATICAL BOLD SCRIPT CAPITAL K
1D4DB MATHEMATICAL BOLD SCRIPT CAPITAL L
1D4DC MATHEMATICAL BOLD SCRIPT CAPITAL M
1D4DD MATHEMATICAL BOLD SCRIPT CAPITAL N
1D4DE MATHEMATICAL BOLD SCRIPT CAPITAL O
1D4DF MATHEMATICAL BOLD SCRIPT CAPITAL P
1D4E0 MATHEMATICAL BOLD SCRIPT CAPITAL Q
1D4E1 MATHEMATICAL BOLD SCRIPT CAPITAL R
1D4E2 MATHEMATICAL BOLD SCRIPT CAPITAL S
1D4E3 MATHEMATICAL BOLD SCRIPT CAPITAL T
1D4E4 MATHEMATICAL BOLD SCRIPT CAPITAL U
1D4E5 MATHEMATICAL BOLD SCRIPT CAPITAL V
1D4E6 MATHEMATICAL BOLD SCRIPT CAPITAL W
1D4E7 MATHEMATICAL BOLD SCRIPT CAPITAL X
1D4E8 MATHEMATICAL BOLD SCRIPT CAPITAL Y
1D4E9 MATHEMATICAL BOLD SCRIPT CAPITAL Z
1D4EA MATHEMATICAL BOLD SCRIPT SMALL A
1D4EB MATHEMATICAL BOLD SCRIPT SMALL B
1D4EC MATHEMATICAL BOLD SCRIPT SMALL C
1D4ED MATHEMATICAL BOLD SCRIPT SMALL D
1D4EE MATHEMATICAL BOLD SCRIPT SMALL E
1D4EF MATHEMATICAL BOLD SCRIPT SMALL F
1D4F0 MATHEMATICAL BOLD SCRIPT SMALL G
1D4F1 MATHEMATICAL BOLD SCRIPT SMALL H
1D4F2 MATHEMATICAL BOLD SCRIPT SMALL I
1D4F3 MATHEMATICAL BOLD SCRIPT SMALL J
1D4F4 MATHEMATICAL BOLD SCRIPT SMALL K
1D4F5 MATHEMATICAL BOLD SCRIPT SMALL L
1D4F6 MATHEMATICAL BOLD SCRIPT SMALL M
1D4F7 MATHEMATICAL BOLD SCRIPT SMALL N
1D4F8 MATHEMATICAL BOLD SCRIPT SMALL O
1D4F9 MATHEMATICAL BOLD SCRIPT SMALL P
1D4FA MATHEMATICAL BOLD SCRIPT SMALL Q
1D4FB MATHEMATICAL BOLD SCRIPT SMALL R
1D4FC MATHEMATICAL BOLD SCRIPT SMALL S
1D4FD MATHEMATICAL BOLD SCRIPT SMALL T
1D4FE MATHEMATICAL BOLD SCRIPT SMALL U
1D4FF MATHEMATICAL BOLD SCRIPT SMALL V
1D500 MATHEMATICAL BOLD SCRIPT SMALL W
1D501 MATHEMATICAL BOLD SCRIPT SMALL X
1D502 MATHEMATICAL BOLD SCRIPT SMALL Y
1D503 MATHEMATICAL BOLD SCRIPT SMALL Z
1D504 MATHEMATICAL FRAKTUR CAPITAL A
1D505 MATHEMATICAL FRAKTUR CAPITAL B
1D507 MATHEMATICAL FRAKTUR CAPITAL D
1D508 MATHEMATICAL FRAKTUR CAPITAL E
1D509 MATHEMATICAL FRAKTUR CAPITAL F
1D50A MATHEMATICAL FRAKTUR CAPITAL G
1D50D MATHEMATICAL FRAKTUR CAPITAL J
1D50E MATHEMATICAL FRAKTUR CAPITAL K
1D50F MATHEMATICAL FRAKTUR CAPITAL L
1D510 MATHEMATICAL FRAKTUR CAPITAL M
1D511 MATHEMATICAL FRAKTUR CAPITAL N
1D512 MATHEMATICAL FRAKTUR CAPITAL O
1D513 MATHEMATICAL FRAKTUR CAPITAL P
1D514 MATHEMATICAL FRAKTUR CAPITAL Q
1D516 MATHEMATICAL FRAKTUR CAPITAL S
1D517 MATHEMATICAL FRAKTUR CAPITAL T
1D518 MATHEMATICAL FRAKTUR CAPITAL U
1D519 MATHEMATICAL FRAKTUR CAPITAL V
1D51A MATHEMATICAL FRAKTUR CAPITAL W
1D51B MATHEMATICAL FRAKTUR CAPITAL X
1D51C MATHEMATICAL FRAKTUR CAPITAL Y
1D51E MATHEMATICAL FRAKTUR SMALL A
1D51F MATHEMATICAL FRAKTUR SMALL B
1D520 MATHEMATICAL FRAKTUR SMALL C
1D521 MATHEMATICAL FRAKTUR SMALL D
1D522 MATHEMATICAL FRAKTUR SMALL E
1D523 MATHEMATICAL FRAKTUR SMALL F
1D524 MATHEMATICAL FRAKTUR SMALL G
1D525 MATHEMATICAL FRAKTUR SMALL H
1D526 MATHEMATICAL FRAKTUR SMALL I
1D527 MATHEMATICAL FRAKTUR SMALL J
1D528 MATHEMATICAL FRAKTUR SMALL K
1D529 MATHEMATICAL FRAKTUR SMALL L
1D52A MATHEMATICAL FRAKTUR SMALL M
1D52B MATHEMATICAL FRAKTUR SMALL N
1D52C MATHEMATICAL FRAKTUR SMALL O
1D52D MATHEMATICAL FRAKTUR SMALL P
1D52E MATHEMATICAL FRAKTUR SMALL Q
1D52F MATHEMATICAL FRAKTUR SMALL R
1D530 MATHEMATICAL FRAKTUR SMALL S
1D531 MATHEMATICAL FRAKTUR SMALL T
1D532 MATHEMATICAL FRAKTUR SMALL U
1D533 MATHEMATICAL FRAKTUR SMALL V
1D534 MATHEMATICAL FRAKTUR SMALL W
1D535 MATHEMATICAL FRAKTUR SMALL X
1D536 MATHEMATICAL FRAKTUR SMALL Y
1D537 MATHEMATICAL FRAKTUR SMALL Z
1D538 MATHEMATICAL DOUBLE-STRUCK CAPITAL A
1D539 MATHEMATICAL DOUBLE-STRUCK CAPITAL B
1D53B MATHEMATICAL DOUBLE-STRUCK CAPITAL D
1D53C MATHEMATICAL DOUBLE-STRUCK CAPITAL E
1D53D MATHEMATICAL DOUBLE-STRUCK CAPITAL F
1D53E MATHEMATICAL DOUBLE-STRUCK CAPITAL G
1D540 MATHEMATICAL DOUBLE-STRUCK CAPITAL I
1D541 MATHEMATICAL DOUBLE-STRUCK CAPITAL J
1D542 MATHEMATICAL DOUBLE-STRUCK CAPITAL K
1D543 MATHEMATICAL DOUBLE-STRUCK CAPITAL L
1D544 MATHEMATICAL DOUBLE-STRUCK CAPITAL M
1D546 MATHEMATICAL DOUBLE-STRUCK CAPITAL O
1D54A MATHEMATICAL DOUBLE-STRUCK CAPITAL S
1D54B MATHEMATICAL DOUBLE-STRUCK CAPITAL T
1D54C MATHEMATICAL DOUBLE-STRUCK CAPITAL U
1D54D MATHEMATICAL DOUBLE-STRUCK CAPITAL V
1D54E MATHEMATICAL DOUBLE-STRUCK CAPITAL W
1D54F MATHEMATICAL DOUBLE-STRUCK CAPITAL X
1D550 MATHEMATICAL DOUBLE-STRUCK CAPITAL Y
1D552 MATHEMATICAL DOUBLE-STRUCK SMALL A
1D553 MATHEMATICAL DOUBLE-STRUCK SMALL B
1D554 MATHEMATICAL DOUBLE-STRUCK SMALL C
1D555 MATHEMATICAL DOUBLE-STRUCK SMALL D
1D556 MATHEMATICAL DOUBLE-STRUCK SMALL E
1D557 MATHEMATICAL DOUBLE-STRUCK SMALL F
1D558 MATHEMATICAL DOUBLE-STRUCK SMALL G
1D559 MATHEMATICAL DOUBLE-STRUCK SMALL H
1D55A MATHEMATICAL DOUBLE-STRUCK SMALL I
1D55B MATHEMATICAL DOUBLE-STRUCK SMALL J
1D55C MATHEMATICAL DOUBLE-STRUCK SMALL K
1D55D MATHEMATICAL DOUBLE-STRUCK SMALL L
1D55E MATHEMATICAL DOUBLE-STRUCK SMALL M
1D55F MATHEMATICAL DOUBLE-STRUCK SMALL N
1D560 MATHEMATICAL DOUBLE-STRUCK SMALL O
1D561 MATHEMATICAL DOUBLE-STRUCK SMALL P
1D562 MATHEMATICAL DOUBLE-STRUCK SMALL Q
1D563 MATHEMATICAL DOUBLE-STRUCK SMALL R
1D564 MATHEMATICAL DOUBLE-STRUCK SMALL S
1D565 MATHEMATICAL DOUBLE-STRUCK SMALL T
1D566 MATHEMATICAL DOUBLE-STRUCK SMALL U
1D567 MATHEMATICAL DOUBLE-STRUCK SMALL V
1D568 MATHEMATICAL DOUBLE-STRUCK SMALL W
1D569 MATHEMATICAL DOUBLE-STRUCK SMALL X
1D56A MATHEMATICAL DOUBLE-STRUCK SMALL Y
1D56B MATHEMATICAL DOUBLE-STRUCK SMALL Z
1D56C MATHEMATICAL BOLD FRAKTUR CAPITAL A
1D56D MATHEMATICAL BOLD FRAKTUR CAPITAL B
1D56E MATHEMATICAL BOLD FRAKTUR CAPITAL C
1D56F MATHEMATICAL BOLD FRAKTUR CAPITAL D
1D570 MATHEMATICAL BOLD FRAKTUR CAPITAL E
1D571 MATHEMATICAL BOLD FRAKTUR CAPITAL F
1D572 MATHEMATICAL BOLD FRAKTUR CAPITAL G
1D573 MATHEMATICAL BOLD FRAKTUR CAPITAL H
1D574 MATHEMATICAL BOLD FRAKTUR CAPITAL I
1D575 MATHEMATICAL BOLD FRAKTUR CAPITAL J
1D576 MATHEMATICAL BOLD FRAKTUR CAPITAL K
1D577 MATHEMATICAL BOLD FRAKTUR CAPITAL L
1D578 MATHEMATICAL BOLD FRAKTUR CAPITAL M
1D579 MATHEMATICAL BOLD FRAKTUR CAPITAL N
1D57A MATHEMATICAL BOLD FRAKTUR CAPITAL O
1D57B MATHEMATICAL BOLD FRAKTUR CAPITAL P
1D57C MATHEMATICAL BOLD FRAKTUR CAPITAL Q
1D57D MATHEMATICAL BOLD FRAKTUR CAPITAL R
1D57E MATHEMATICAL BOLD FRAKTUR CAPITAL S
1D57F MATHEMATICAL BOLD FRAKTUR CAPITAL T
1D580 MATHEMATICAL BOLD FRAKTUR CAPITAL U
1D581 MATHEMATICAL BOLD FRAKTUR CAPITAL V
1D582 MATHEMATICAL BOLD FRAKTUR CAPITAL W
1D583 MATHEMATICAL BOLD FRAKTUR CAPITAL X
1D584 MATHEMATICAL BOLD FRAKTUR CAPITAL Y
1D585 MATHEMATICAL BOLD FRAKTUR CAPITAL Z
1D586 MATHEMATICAL BOLD FRAKTUR SMALL A
1D587 MATHEMATICAL BOLD FRAKTUR SMALL B
1D588 MATHEMATICAL BOLD FRAKTUR SMALL C
1D589 MATHEMATICAL BOLD FRAKTUR SMALL D
1D58A MATHEMATICAL BOLD FRAKTUR SMALL E
1D58B MATHEMATICAL BOLD FRAKTUR SMALL F
1D58C MATHEMATICAL BOLD FRAKTUR SMALL G
1D58D MATHEMATICAL BOLD FRAKTUR SMALL H
1D58E MATHEMATICAL BOLD FRAKTUR SMALL I
1D58F MATHEMATICAL BOLD FRAKTUR SMALL J
1D590 MATHEMATICAL BOLD FRAKTUR SMALL K
1D591 MATHEMATICAL BOLD FRAKTUR SMALL L
1D592 MATHEMATICAL BOLD FRAKTUR SMALL M
1D593 MATHEMATICAL BOLD FRAKTUR SMALL N
1D594 MATHEMATICAL BOLD FRAKTUR SMALL O
1D595 MATHEMATICAL BOLD FRAKTUR SMALL P
1D596 MATHEMATICAL BOLD FRAKTUR SMALL Q
1D597 MATHEMATICAL BOLD FRAKTUR SMALL R
1D598 MATHEMATICAL BOLD FRAKTUR SMALL S
1D599 MATHEMATICAL BOLD FRAKTUR SMALL T
1D59A MATHEMATICAL BOLD FRAKTUR SMALL U
1D59B MATHEMATICAL BOLD FRAKTUR SMALL V
1D59C MATHEMATICAL BOLD FRAKTUR SMALL W
1D59D MATHEMATICAL BOLD FRAKTUR SMALL X
1D59E MATHEMATICAL BOLD FRAKTUR SMALL Y
1D59F MATHEMATICAL BOLD FRAKTUR SMALL Z
1D5A0 MATHEMATICAL SANS-SERIF CAPITAL A
1D5A1 MATHEMATICAL SANS-SERIF CAPITAL B
1D5A2 MATHEMATICAL SANS-SERIF CAPITAL C
1D5A3 MATHEMATICAL SANS-SERIF CAPITAL D
1D5A4 MATHEMATICAL SANS-SERIF CAPITAL E
1D5A5 MATHEMATICAL SANS-SERIF CAPITAL F
1D5A6 MATHEMATICAL SANS-SERIF CAPITAL G
1D5A7 MATHEMATICAL SANS-SERIF CAPITAL H
1D5A8 MATHEMATICAL SANS-SERIF CAPITAL I
1D5A9 MATHEMATICAL SANS-SERIF CAPITAL J
1D5AA MATHEMATICAL SANS-SERIF CAPITAL K
1D5AB MATHEMATICAL SANS-SERIF CAPITAL L
1D5AC MATHEMATICAL SANS-SERIF CAPITAL M
1D5AD MATHEMATICAL SANS-SERIF CAPITAL N
1D5AE MATHEMATICAL SANS-SERIF CAPITAL O
1D5AF MATHEMATICAL SANS-SERIF CAPITAL P
1D5B0 MATHEMATICAL SANS-SERIF CAPITAL Q
1D5B1 MATHEMATICAL SANS-SERIF CAPITAL R
1D5B2 MATHEMATICAL SANS-SERIF CAPITAL S
1D5B3 MATHEMATICAL SANS-SERIF CAPITAL T
1D5B4 MATHEMATICAL SANS-SERIF CAPITAL U
1D5B5 MATHEMATICAL SANS-SERIF CAPITAL V
1D5B6 MATHEMATICAL SANS-SERIF CAPITAL W
1D5B7 MATHEMATICAL SANS-SERIF CAPITAL X
1D5B8 MATHEMATICAL SANS-SERIF CAPITAL Y
1D5B9 MATHEMATICAL SANS-SERIF CAPITAL Z
1D5BA MATHEMATICAL SANS-SERIF SMALL A
1D5BB MATHEMATICAL SANS-SERIF SMALL B
1D5BC MATHEMATICAL SANS-SERIF SMALL C
1D5BD MATHEMATICAL SANS-SERIF SMALL D
1D5BE MATHEMATICAL SANS-SERIF SMALL E
1D5BF MATHEMATICAL SANS-SERIF SMALL F
1D5C0 MATHEMATICAL SANS-SERIF SMALL G
1D5C1 MATHEMATICAL SANS-SERIF SMALL H
1D5C2 MATHEMATICAL SANS-SERIF SMALL I
1D5C3 MATHEMATICAL SANS-SERIF SMALL J
1D5C4 MATHEMATICAL SANS-SERIF SMALL K
1D5C5 MATHEMATICAL SANS-SERIF SMALL L
1D5C6 MATHEMATICAL SANS-SERIF SMALL M
1D5C7 MATHEMATICAL SANS-SERIF SMALL N
1D5C8 MATHEMATICAL SANS-SERIF SMALL O
1D5C9 MATHEMATICAL SANS-SERIF SMALL P
1D5CA MATHEMATICAL SANS-SERIF SMALL Q
1D5CB MATHEMATICAL SANS-SERIF SMALL R
1D5CC MATHEMATICAL SANS-SERIF SMALL S
1D5CD MATHEMATICAL SANS-SERIF SMALL T
1D5CE MATHEMATICAL SANS-SERIF SMALL U
1D5CF MATHEMATICAL SANS-SERIF SMALL V
1D5D0 MATHEMATICAL SANS-SERIF SMALL W
1D5D1 MATHEMATICAL SANS-SERIF SMALL X
1D5D2 MATHEMATICAL SANS-SERIF SMALL Y
1D5D3 MATHEMATICAL SANS-SERIF SMALL Z
1D5D4 MATHEMATICAL SANS-SERIF BOLD CAPITAL A
1D5D5 MATHEMATICAL SANS-SERIF BOLD CAPITAL B
1D5D6 MATHEMATICAL SANS-SERIF BOLD CAPITAL C
1D5D7 MATHEMATICAL SANS-SERIF BOLD CAPITAL D
1D5D8 MATHEMATICAL SANS-SERIF BOLD CAPITAL E
1D5D9 MATHEMATICAL SANS-SERIF BOLD CAPITAL F
1D5DA MATHEMATICAL SANS-SERIF BOLD CAPITAL G
1D5DB MATHEMATICAL SANS-SERIF BOLD CAPITAL H
1D5DC MATHEMATICAL SANS-SERIF BOLD CAPITAL I
1D5DD MATHEMATICAL SANS-SERIF BOLD CAPITAL J
1D5DE MATHEMATICAL SANS-SERIF BOLD CAPITAL K
1D5DF MATHEMATICAL SANS-SERIF BOLD CAPITAL L
1D5E0 MATHEMATICAL SANS-SERIF BOLD CAPITAL M
1D5E1 MATHEMATICAL SANS-SERIF BOLD CAPITAL N
1D5E2 MATHEMATICAL SANS-SERIF BOLD CAPITAL O
1D5E3 MATHEMATICAL SANS-SERIF BOLD CAPITAL P
1D5E4 MATHEMATICAL SANS-SERIF BOLD CAPITAL Q
1D5E5 MATHEMATICAL SANS-SERIF BOLD CAPITAL R
1D5E6 MATHEMATICAL SANS-SERIF BOLD CAPITAL S
1D5E7 MATHEMATICAL SANS-SERIF BOLD CAPITAL T
1D5E8 MATHEMATICAL SANS-SERIF BOLD CAPITAL U
1D5E9 MATHEMATICAL SANS-SERIF BOLD CAPITAL V
1D5EA MATHEMATICAL SANS-SERIF BOLD CAPITAL W
1D5EB MATHEMATICAL SANS-SERIF BOLD CAPITAL X
1D5EC MATHEMATICAL SANS-SERIF BOLD CAPITAL Y
1D5ED MATHEMATICAL SANS-SERIF BOLD CAPITAL Z
1D5EE MATHEMATICAL SANS-SERIF BOLD SMALL A
1D5EF MATHEMATICAL SANS-SERIF BOLD SMALL B
1D5F0 MATHEMATICAL SANS-SERIF BOLD SMALL C
1D5F1 MATHEMATICAL SANS-SERIF BOLD SMALL D
1D5F2 MATHEMATICAL SANS-SERIF BOLD SMALL E
1D5F3 MATHEMATICAL SANS-SERIF BOLD SMALL F
1D5F4 MATHEMATICAL SANS-SERIF BOLD SMALL G
1D5F5 MATHEMATICAL SANS-SERIF BOLD SMALL H
1D5F6 MATHEMATICAL SANS-SERIF BOLD SMALL I
1D5F7 MATHEMATICAL SANS-SERIF BOLD SMALL J
1D5F8 MATHEMATICAL SANS-SERIF BOLD SMALL K
1D5F9 MATHEMATICAL SANS-SERIF BOLD SMALL L
1D5FA MATHEMATICAL SANS-SERIF BOLD SMALL M
1D5FB MATHEMATICAL SANS-SERIF BOLD SMALL N
1D5FC MATHEMATICAL SANS-SERIF BOLD SMALL O
1D5FD MATHEMATICAL SANS-SERIF BOLD SMALL P
1D5FE MATHEMATICAL SANS-SERIF BOLD SMALL Q
1D5FF MATHEMATICAL SANS-SERIF BOLD SMALL R
1D600 MATHEMATICAL SANS-SERIF BOLD SMALL S
1D601 MATHEMATICAL SANS-SERIF BOLD SMALL T
1D602 MATHEMATICAL SANS-SERIF BOLD SMALL U
1D603 MATHEMATICAL SANS-SERIF BOLD SMALL V
1D604 MATHEMATICAL SANS-SERIF BOLD SMALL W
1D605 MATHEMATICAL SANS-SERIF BOLD SMALL X
1D606 MATHEMATICAL SANS-SERIF BOLD SMALL Y
1D607 MATHEMATICAL SANS-SERIF BOLD SMALL Z
1D608 MATHEMATICAL SANS-SERIF ITALIC CAPITAL A
1D609 MATHEMATICAL SANS-SERIF ITALIC CAPITAL B
1D60A MATHEMATICAL SANS-SERIF ITALIC CAPITAL C
1D60B MATHEMATICAL SANS-SERIF ITALIC CAPITAL D
1D60C MATHEMATICAL SANS-SERIF ITALIC CAPITAL E
1D60D MATHEMATICAL SANS-SERIF ITALIC CAPITAL F
1D60E MATHEMATICAL SANS-SERIF ITALIC CAPITAL G
1D60F MATHEMATICAL SANS-SERIF ITALIC CAPITAL H
1D610 MATHEMATICAL SANS-SERIF ITALIC CAPITAL I
1D611 MATHEMATICAL SANS-SERIF ITALIC CAPITAL J
1D612 MATHEMATICAL SANS-SERIF ITALIC CAPITAL K
1D613 MATHEMATICAL SANS-SERIF ITALIC CAPITAL L
1D614 MATHEMATICAL SANS-SERIF ITALIC CAPITAL M
1D615 MATHEMATICAL SANS-SERIF ITALIC CAPITAL N
1D616 MATHEMATICAL SANS-SERIF ITALIC CAPITAL O
1D617 MATHEMATICAL SANS-SERIF ITALIC CAPITAL P
1D618 MATHEMATICAL SANS-SERIF ITALIC CAPITAL Q
1D619 MATHEMATICAL SANS-SERIF ITALIC CAPITAL R
1D61A MATHEMATICAL SANS-SERIF ITALIC CAPITAL S
1D61B MATHEMATICAL SANS-SERIF ITALIC CAPITAL T
1D61C MATHEMATICAL SANS-SERIF ITALIC CAPITAL U
1D61D MATHEMATICAL SANS-SERIF ITALIC CAPITAL V
1D61E MATHEMATICAL SANS-SERIF ITALIC CAPITAL W
1D61F MATHEMATICAL SANS-SERIF ITALIC CAPITAL X
1D620 MATHEMATICAL SANS-SERIF ITALIC CAPITAL Y
1D621 MATHEMATICAL SANS-SERIF ITALIC CAPITAL Z
1D622 MATHEMATICAL SANS-SERIF ITALIC SMALL A
1D623 MATHEMATICAL SANS-SERIF ITALIC SMALL B
1D624 MATHEMATICAL SANS-SERIF ITALIC SMALL C
1D625 MATHEMATICAL SANS-SERIF ITALIC SMALL D
1D626 MATHEMATICAL SANS-SERIF ITALIC SMALL E
1D627 MATHEMATICAL SANS-SERIF ITALIC SMALL F
1D628 MATHEMATICAL SANS-SERIF ITALIC SMALL G
1D629 MATHEMATICAL SANS-SERIF ITALIC SMALL H
1D62A MATHEMATICAL SANS-SERIF ITALIC SMALL I
1D62B MATHEMATICAL SANS-SERIF ITALIC SMALL J
1D62C MATHEMATICAL SANS-SERIF ITALIC SMALL K
1D62D MATHEMATICAL SANS-SERIF ITALIC SMALL L
1D62E MATHEMATICAL SANS-SERIF ITALIC SMALL M
1D62F MATHEMATICAL SANS-SERIF ITALIC SMALL N
1D630 MATHEMATICAL SANS-SERIF ITALIC SMALL O
1D631 MATHEMATICAL SANS-SERIF ITALIC SMALL P
1D632 MATHEMATICAL SANS-SERIF ITALIC SMALL Q
1D633 MATHEMATICAL SANS-SERIF ITALIC SMALL R
1D634 MATHEMATICAL SANS-SERIF ITALIC SMALL S
1D635 MATHEMATICAL SANS-SERIF ITALIC SMALL T
1D636 MATHEMATICAL SANS-SERIF ITALIC SMALL U
1D637 MATHEMATICAL SANS-SERIF ITALIC SMALL V
1D638 MATHEMATICAL SANS-SERIF ITALIC SMALL W
1D639 MATHEMATICAL SANS-SERIF ITALIC SMALL X
1D63A MATHEMATICAL SANS-SERIF ITALIC SMALL Y
1D63B MATHEMATICAL SANS-SERIF ITALIC SMALL Z
1D63C MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL A
1D63D MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL B
1D63E MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL C
1D63F MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL D
1D640 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL E
1D641 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL F
1D642 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL G
1D643 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL H
1D644 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL I
1D645 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL J
1D646 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL K
1D647 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL L
1D648 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL M
1D649 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL N
1D64A MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL O
1D64B MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL P
1D64C MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL Q
1D64D MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL R
1D64E MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL S
1D64F MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL T
1D650 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL U
1D651 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL V
1D652 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL W
1D653 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL X
1D654 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL Y
1D655 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL Z
1D656 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL A
1D657 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL B
1D658 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL C
1D659 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL D
1D65A MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL E
1D65B MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL F
1D65C MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL G
1D65D MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL H
1D65E MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL I
1D65F MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL J
1D660 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL K
1D661 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL L
1D662 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL M
1D663 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL N
1D664 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL O
1D665 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL P
1D666 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL Q
1D667 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL R
1D668 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL S
1D669 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL T
1D66A MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL U
1D66B MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL V
1D66C MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL W
1D66D MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL X
1D66E MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL Y
1D66F MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL Z
1D670 MATHEMATICAL MONOSPACE CAPITAL A
1D671 MATHEMATICAL MONOSPACE CAPITAL B
1D672 MATHEMATICAL MONOSPACE CAPITAL C
1D673 MATHEMATICAL MONOSPACE CAPITAL D
1D674 MATHEMATICAL MONOSPACE CAPITAL E
1D675 MATHEMATICAL MONOSPACE CAPITAL F
1D676 MATHEMATICAL MONOSPACE CAPITAL G
1D677 MATHEMATICAL MONOSPACE CAPITAL H
1D678 MATHEMATICAL MONOSPACE CAPITAL I
1D679 MATHEMATICAL MONOSPACE CAPITAL J
1D67A MATHEMATICAL MONOSPACE CAPITAL K
1D67B MATHEMATICAL MONOSPACE CAPITAL L
1D67C MATHEMATICAL MONOSPACE CAPITAL M
1D67D MATHEMATICAL MONOSPACE CAPITAL N
1D67E MATHEMATICAL MONOSPACE CAPITAL O
1D67F MATHEMATICAL MONOSPACE CAPITAL P
1D680 MATHEMATICAL MONOSPACE CAPITAL Q
1D681 MATHEMATICAL MONOSPACE CAPITAL R
1D682 MATHEMATICAL MONOSPACE CAPITAL S
1D683 MATHEMATICAL MONOSPACE CAPITAL T
1D684 MATHEMATICAL MONOSPACE CAPITAL U
1D685 MATHEMATICAL MONOSPACE CAPITAL V
1D686 MATHEMATICAL MONOSPACE CAPITAL W
1D687 MATHEMATICAL MONOSPACE CAPITAL X
1D688 MATHEMATICAL MONOSPACE CAPITAL Y
1D689 MATHEMATICAL MONOSPACE CAPITAL Z
1D68A MATHEMATICAL MONOSPACE SMALL A
1D68B MATHEMATICAL MONOSPACE SMALL B
1D68C MATHEMATICAL MONOSPACE SMALL C
1D68D MATHEMATICAL MONOSPACE SMALL D
1D68E MATHEMATICAL MONOSPACE SMALL E
1D68F MATHEMATICAL MONOSPACE SMALL F
1D690 MATHEMATICAL MONOSPACE SMALL G
1D691 MATHEMATICAL MONOSPACE SMALL H
1D692 MATHEMATICAL MONOSPACE SMALL I
1D693 MATHEMATICAL MONOSPACE SMALL J
1D694 MATHEMATICAL MONOSPACE SMALL K
1D695 MATHEMATICAL MONOSPACE SMALL L
1D696 MATHEMATICAL MONOSPACE SMALL M
1D697 MATHEMATICAL MONOSPACE SMALL N
1D698 MATHEMATICAL MONOSPACE SMALL O
1D699 MATHEMATICAL MONOSPACE SMALL P
1D69A MATHEMATICAL MONOSPACE SMALL Q
1D69B MATHEMATICAL MONOSPACE SMALL R
1D69C MATHEMATICAL MONOSPACE SMALL S
1D69D MATHEMATICAL MONOSPACE SMALL T
1D69E MATHEMATICAL MONOSPACE SMALL U
1D69F MATHEMATICAL MONOSPACE SMALL V
1D6A0 MATHEMATICAL MONOSPACE SMALL W
1D6A1 MATHEMATICAL MONOSPACE SMALL X
1D6A2 MATHEMATICAL MONOSPACE SMALL Y
1D6A3 MATHEMATICAL MONOSPACE SMALL Z
1D6A4 MATHEMATICAL ITALIC SMALL DOTLESS I
1D6A5 MATHEMATICAL ITALIC SMALL DOTLESS J
1D6A8 MATHEMATICAL BOLD CAPITAL ALPHA
1D6A9 MATHEMATICAL BOLD CAPITAL BETA
1D6AA MATHEMATICAL BOLD CAPITAL GAMMA
1D6AB MATHEMATICAL BOLD CAPITAL DELTA
1D6AC MATHEMATICAL BOLD CAPITAL EPSILON
1D6AD MATHEMATICAL BOLD CAPITAL ZETA
1D6AE MATHEMATICAL BOLD CAPITAL ETA
1D6AF MATHEMATICAL BOLD CAPITAL THETA
1D6B0 MATHEMATICAL BOLD CAPITAL IOTA
1D6B1 MATHEMATICAL BOLD CAPITAL KAPPA
1D6B2 MATHEMATICAL BOLD CAPITAL LAMDA
1D6B3 MATHEMATICAL BOLD CAPITAL MU
1D6B4 MATHEMATICAL BOLD CAPITAL NU
1D6B5 MATHEMATICAL BOLD CAPITAL XI
1D6B6 MATHEMATICAL BOLD CAPITAL OMICRON
1D6B7 MATHEMATICAL BOLD CAPITAL PI
1D6B8 MATHEMATICAL BOLD CAPITAL RHO
1D6B9 MATHEMATICAL BOLD CAPITAL THETA SYMBOL
1D6BA MATHEMATICAL BOLD CAPITAL SIGMA
1D6BB MATHEMATICAL BOLD CAPITAL TAU
1D6BC MATHEMATICAL BOLD CAPITAL UPSILON
1D6BD MATHEMATICAL BOLD CAPITAL PHI
1D6BE MATHEMATICAL BOLD CAPITAL CHI
1D6BF MATHEMATICAL BOLD CAPITAL PSI
1D6C0 MATHEMATICAL BOLD CAPITAL OMEGA
1D6C1 MATHEMATICAL BOLD NABLA
1D6C2 MATHEMATICAL BOLD SMALL ALPHA
1D6C3 MATHEMATICAL BOLD SMALL BETA
1D6C4 MATHEMATICAL BOLD SMALL GAMMA
1D6C5 MATHEMATICAL BOLD SMALL DELTA
1D6C6 MATHEMATICAL BOLD SMALL EPSILON
1D6C7 MATHEMATICAL BOLD SMALL ZETA
1D6C8 MATHEMATICAL BOLD SMALL ETA
1D6C9 MATHEMATICAL BOLD SMALL THETA
1D6CA MATHEMATICAL BOLD SMALL IOTA
1D6CB MATHEMATICAL BOLD SMALL KAPPA
1D6CC MATHEMATICAL BOLD SMALL LAMDA
1D6CD MATHEMATICAL BOLD SMALL MU
1D6CE MATHEMATICAL BOLD SMALL NU
1D6CF MATHEMATICAL BOLD SMALL XI
1D6D0 MATHEMATICAL BOLD SMALL OMICRON
1D6D1 MATHEMATICAL BOLD SMALL PI
1D6D2 MATHEMATICAL BOLD SMALL RHO
1D6D3 MATHEMATICAL BOLD SMALL FINAL SIGMA
1D6D4 MATHEMATICAL BOLD SMALL SIGMA
1D6D5 MATHEMATICAL BOLD SMALL TAU
1D6D6 MATHEMATICAL BOLD SMALL UPSILON
1D6D7 MATHEMATICAL BOLD SMALL PHI
1D6D8 MATHEMATICAL BOLD SMALL CHI
1D6D9 MATHEMATICAL BOLD SMALL PSI
1D6DA MATHEMATICAL BOLD SMALL OMEGA
1D6DB MATHEMATICAL BOLD PARTIAL DIFFERENTIAL
1D6DC MATHEMATICAL BOLD EPSILON SYMBOL
1D6DD MATHEMATICAL BOLD THETA SYMBOL
1D6DE MATHEMATICAL BOLD KAPPA SYMBOL
1D6DF MATHEMATICAL BOLD PHI SYMBOL
1D6E0 MATHEMATICAL BOLD RHO SYMBOL
1D6E1 MATHEMATICAL BOLD PI SYMBOL
1D6E2 MATHEMATICAL ITALIC CAPITAL ALPHA
1D6E3 MATHEMATICAL ITALIC CAPITAL BETA
1D6E4 MATHEMATICAL ITALIC CAPITAL GAMMA
1D6E5 MATHEMATICAL ITALIC CAPITAL DELTA
1D6E6 MATHEMATICAL ITALIC CAPITAL EPSILON
1D6E7 MATHEMATICAL ITALIC CAPITAL ZETA
1D6E8 MATHEMATICAL ITALIC CAPITAL ETA
1D6E9 MATHEMATICAL ITALIC CAPITAL THETA
1D6EA MATHEMATICAL ITALIC CAPITAL IOTA
1D6EB MATHEMATICAL ITALIC CAPITAL KAPPA
1D6EC MATHEMATICAL ITALIC CAPITAL LAMDA
1D6ED MATHEMATICAL ITALIC CAPITAL MU
1D6EE MATHEMATICAL ITALIC CAPITAL NU
1D6EF MATHEMATICAL ITALIC CAPITAL XI
1D6F0 MATHEMATICAL ITALIC CAPITAL OMICRON
1D6F1 MATHEMATICAL ITALIC CAPITAL PI
1D6F2 MATHEMATICAL ITALIC CAPITAL RHO
1D6F3 MATHEMATICAL ITALIC CAPITAL THETA SYMBOL
1D6F4 MATHEMATICAL ITALIC CAPITAL SIGMA
1D6F5 MATHEMATICAL ITALIC CAPITAL TAU
1D6F6 MATHEMATICAL ITALIC CAPITAL UPSILON
1D6F7 MATHEMATICAL ITALIC CAPITAL PHI
1D6F8 MATHEMATICAL ITALIC CAPITAL CHI
1D6F9 MATHEMATICAL ITALIC CAPITAL PSI
1D6FA MATHEMATICAL ITALIC CAPITAL OMEGA
1D6FB MATHEMATICAL ITALIC NABLA
1D6FC MATHEMATICAL ITALIC SMALL ALPHA
1D6FD MATHEMATICAL ITALIC SMALL BETA
1D6FE MATHEMATICAL ITALIC SMALL GAMMA
1D6FF MATHEMATICAL ITALIC SMALL DELTA
1D700 MATHEMATICAL ITALIC SMALL EPSILON
1D701 MATHEMATICAL ITALIC SMALL ZETA
1D702 MATHEMATICAL ITALIC SMALL ETA
1D703 MATHEMATICAL ITALIC SMALL THETA
1D704 MATHEMATICAL ITALIC SMALL IOTA
1D705 MATHEMATICAL ITALIC SMALL KAPPA
1D706 MATHEMATICAL ITALIC SMALL LAMDA
1D707 MATHEMATICAL ITALIC SMALL MU
1D708 MATHEMATICAL ITALIC SMALL NU
1D709 MATHEMATICAL ITALIC SMALL XI
1D70A MATHEMATICAL ITALIC SMALL OMICRON
1D70B MATHEMATICAL ITALIC SMALL PI
1D70C MATHEMATICAL ITALIC SMALL RHO
1D70D MATHEMATICAL ITALIC SMALL FINAL SIGMA
1D70E MATHEMATICAL ITALIC SMALL SIGMA
1D70F MATHEMATICAL ITALIC SMALL TAU
1D710 MATHEMATICAL ITALIC SMALL UPSILON
1D711 MATHEMATICAL ITALIC SMALL PHI
1D712 MATHEMATICAL ITALIC SMALL CHI
1D713 MATHEMATICAL ITALIC SMALL PSI
1D714 MATHEMATICAL ITALIC SMALL OMEGA
1D715 MATHEMATICAL ITALIC PARTIAL DIFFERENTIAL
1D716 MATHEMATICAL ITALIC EPSILON SYMBOL
1D717 MATHEMATICAL ITALIC THETA SYMBOL
1D718 MATHEMATICAL ITALIC KAPPA SYMBOL
1D719 MATHEMATICAL ITALIC PHI SYMBOL
1D71A MATHEMATICAL ITALIC RHO SYMBOL
1D71B MATHEMATICAL ITALIC PI SYMBOL
1D71C MATHEMATICAL BOLD ITALIC CAPITAL ALPHA
1D71D MATHEMATICAL BOLD ITALIC CAPITAL BETA
1D71E MATHEMATICAL BOLD ITALIC CAPITAL GAMMA
1D71F MATHEMATICAL BOLD ITALIC CAPITAL DELTA
1D720 MATHEMATICAL BOLD ITALIC CAPITAL EPSILON
1D721 MATHEMATICAL BOLD ITALIC CAPITAL ZETA
1D722 MATHEMATICAL BOLD ITALIC CAPITAL ETA
1D723 MATHEMATICAL BOLD ITALIC CAPITAL THETA
1D724 MATHEMATICAL BOLD ITALIC CAPITAL IOTA
1D725 MATHEMATICAL BOLD ITALIC CAPITAL KAPPA
1D726 MATHEMATICAL BOLD ITALIC CAPITAL LAMDA
1D727 MATHEMATICAL BOLD ITALIC CAPITAL MU
1D728 MATHEMATICAL BOLD ITALIC CAPITAL NU
1D729 MATHEMATICAL BOLD ITALIC CAPITAL XI
1D72A MATHEMATICAL BOLD ITALIC CAPITAL OMICRON
1D72B MATHEMATICAL BOLD ITALIC CAPITAL PI
1D72C MATHEMATICAL BOLD ITALIC CAPITAL RHO
1D72D MATHEMATICAL BOLD ITALIC CAPITAL THETA SYMBOL
1D72E MATHEMATICAL BOLD ITALIC CAPITAL SIGMA
1D72F MATHEMATICAL BOLD ITALIC CAPITAL TAU
1D730 MATHEMATICAL BOLD ITALIC CAPITAL UPSILON
1D731 MATHEMATICAL BOLD ITALIC CAPITAL PHI
1D732 MATHEMATICAL BOLD ITALIC CAPITAL CHI
1D733 MATHEMATICAL BOLD ITALIC CAPITAL PSI
1D734 MATHEMATICAL BOLD ITALIC CAPITAL OMEGA
1D735 MATHEMATICAL BOLD ITALIC NABLA
1D736 MATHEMATICAL BOLD ITALIC SMALL ALPHA
1D737 MATHEMATICAL BOLD ITALIC SMALL BETA
1D738 MATHEMATICAL BOLD ITALIC SMALL GAMMA
1D739 MATHEMATICAL BOLD ITALIC SMALL DELTA
1D73A MATHEMATICAL BOLD ITALIC SMALL EPSILON
1D73B MATHEMATICAL BOLD ITALIC SMALL ZETA
1D73C MATHEMATICAL BOLD ITALIC SMALL ETA
1D73D MATHEMATICAL BOLD ITALIC SMALL THETA
1D73E MATHEMATICAL BOLD ITALIC SMALL IOTA
1D73F MATHEMATICAL BOLD ITALIC SMALL KAPPA
1D740 MATHEMATICAL BOLD ITALIC SMALL LAMDA
1D741 MATHEMATICAL BOLD ITALIC SMALL MU
1D742 MATHEMATICAL BOLD ITALIC SMALL NU
1D743 MATHEMATICAL BOLD ITALIC SMALL XI
1D744 MATHEMATICAL BOLD ITALIC SMALL OMICRON
1D745 MATHEMATICAL BOLD ITALIC SMALL PI
1D746 MATHEMATICAL BOLD ITALIC SMALL RHO
1D747 MATHEMATICAL BOLD ITALIC SMALL FINAL SIGMA
1D748 MATHEMATICAL BOLD ITALIC SMALL SIGMA
1D749 MATHEMATICAL BOLD ITALIC SMALL TAU
1D74A MATHEMATICAL BOLD ITALIC SMALL UPSILON
1D74B MATHEMATICAL BOLD ITALIC SMALL PHI
1D74C MATHEMATICAL BOLD ITALIC SMALL CHI
1D74D MATHEMATICAL BOLD ITALIC SMALL PSI
1D74E MATHEMATICAL BOLD ITALIC SMALL OMEGA
1D74F MATHEMATICAL BOLD ITALIC PARTIAL DIFFERENTIAL
1D750 MATHEMATICAL BOLD ITALIC EPSILON SYMBOL
1D751 MATHEMATICAL BOLD ITALIC THETA SYMBOL
1D752 MATHEMATICAL BOLD ITALIC KAPPA SYMBOL
1D753 MATHEMATICAL BOLD ITALIC PHI SYMBOL
1D754 MATHEMATICAL BOLD ITALIC RHO SYMBOL
1D755 MATHEMATICAL BOLD ITALIC PI SYMBOL
1D756 MATHEMATICAL SANS-SERIF BOLD CAPITAL ALPHA
1D757 MATHEMATICAL SANS-SERIF BOLD CAPITAL BETA
1D758 MATHEMATICAL SANS-SERIF BOLD CAPITAL GAMMA
1D759 MATHEMATICAL SANS-SERIF BOLD CAPITAL DELTA
1D75A MATHEMATICAL SANS-SERIF BOLD CAPITAL EPSILON
1D75B MATHEMATICAL SANS-SERIF BOLD CAPITAL ZETA
1D75C MATHEMATICAL SANS-SERIF BOLD CAPITAL ETA
1D75D MATHEMATICAL SANS-SERIF BOLD CAPITAL THETA
1D75E MATHEMATICAL SANS-SERIF BOLD CAPITAL IOTA
1D75F MATHEMATICAL SANS-SERIF BOLD CAPITAL KAPPA
1D760 MATHEMATICAL SANS-SERIF BOLD CAPITAL LAMDA
1D761 MATHEMATICAL SANS-SERIF BOLD CAPITAL MU
1D762 MATHEMATICAL SANS-SERIF BOLD CAPITAL NU
1D763 MATHEMATICAL SANS-SERIF BOLD CAPITAL XI
1D764 MATHEMATICAL SANS-SERIF BOLD CAPITAL OMICRON
1D765 MATHEMATICAL SANS-SERIF BOLD CAPITAL PI
1D766 MATHEMATICAL SANS-SERIF BOLD CAPITAL RHO
1D767 MATHEMATICAL SANS-SERIF BOLD CAPITAL THETA SYMBOL
1D768 MATHEMATICAL SANS-SERIF BOLD CAPITAL SIGMA
1D769 MATHEMATICAL SANS-SERIF BOLD CAPITAL TAU
1D76A MATHEMATICAL SANS-SERIF BOLD CAPITAL UPSILON
1D76B MATHEMATICAL SANS-SERIF BOLD CAPITAL PHI
1D76C MATHEMATICAL SANS-SERIF BOLD CAPITAL CHI
1D76D MATHEMATICAL SANS-SERIF BOLD CAPITAL PSI
1D76E MATHEMATICAL SANS-SERIF BOLD CAPITAL OMEGA
1D76F MATHEMATICAL SANS-SERIF BOLD NABLA
1D770 MATHEMATICAL SANS-SERIF BOLD SMALL ALPHA
1D771 MATHEMATICAL SANS-SERIF BOLD SMALL BETA
1D772 MATHEMATICAL SANS-SERIF BOLD SMALL GAMMA
1D773 MATHEMATICAL SANS-SERIF BOLD SMALL DELTA
1D774 MATHEMATICAL SANS-SERIF BOLD SMALL EPSILON
1D775 MATHEMATICAL SANS-SERIF BOLD SMALL ZETA
1D776 MATHEMATICAL SANS-SERIF BOLD SMALL ETA
1D777 MATHEMATICAL SANS-SERIF BOLD SMALL THETA
1D778 MATHEMATICAL SANS-SERIF BOLD SMALL IOTA
1D779 MATHEMATICAL SANS-SERIF BOLD SMALL KAPPA
1D77A MATHEMATICAL SANS-SERIF BOLD SMALL LAMDA
1D77B MATHEMATICAL SANS-SERIF BOLD SMALL MU
1D77C MATHEMATICAL SANS-SERIF BOLD SMALL NU
1D77D MATHEMATICAL SANS-SERIF BOLD SMALL XI
1D77E MATHEMATICAL SANS-SERIF BOLD SMALL OMICRON
1D77F MATHEMATICAL SANS-SERIF BOLD SMALL PI
1D780 MATHEMATICAL SANS-SERIF BOLD SMALL RHO
1D781 MATHEMATICAL SANS-SERIF BOLD SMALL FINAL SIGMA
1D782 MATHEMATICAL SANS-SERIF BOLD SMALL SIGMA
1D783 MATHEMATICAL SANS-SERIF BOLD SMALL TAU
1D784 MATHEMATICAL SANS-SERIF BOLD SMALL UPSILON
1D785 MATHEMATICAL SANS-SERIF BOLD SMALL PHI
1D786 MATHEMATICAL SANS-SERIF BOLD SMALL CHI
1D787 MATHEMATICAL SANS-SERIF BOLD SMALL PSI
1D788 MATHEMATICAL SANS-SERIF BOLD SMALL OMEGA
1D789 MATHEMATICAL SANS-SERIF BOLD PARTIAL DIFFERENTIAL
1D78A MATHEMATICAL SANS-SERIF BOLD EPSILON SYMBOL
1D78B MATHEMATICAL SANS-SERIF BOLD THETA SYMBOL
1D78C MATHEMATICAL SANS-SERIF BOLD KAPPA SYMBOL
1D78D MATHEMATICAL SANS-SERIF BOLD PHI SYMBOL
1D78E MATHEMATICAL SANS-SERIF BOLD RHO SYMBOL
1D78F MATHEMATICAL SANS-SERIF BOLD PI SYMBOL
1D790 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL ALPHA
1D791 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL BETA
1D792 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL GAMMA
1D793 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL DELTA
1D794 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL EPSILON
1D795 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL ZETA
1D796 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL ETA
1D797 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL THETA
1D798 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL IOTA
1D799 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL KAPPA
1D79A MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL LAMDA
1D79B MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL MU
1D79C MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL NU
1D79D MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL XI
1D79E MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL OMICRON
1D79F MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL PI
1D7A0 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL RHO
1D7A1 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL THETA SYMBOL
1D7A2 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL SIGMA
1D7A3 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL TAU
1D7A4 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL UPSILON
1D7A5 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL PHI
1D7A6 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL CHI
1D7A7 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL PSI
1D7A8 MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL OMEGA
1D7A9 MATHEMATICAL SANS-SERIF BOLD ITALIC NABLA
1D7AA MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL ALPHA
1D7AB MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL BETA
1D7AC MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL GAMMA
1D7AD MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL DELTA
1D7AE MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL EPSILON
1D7AF MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL ZETA
1D7B0 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL ETA
1D7B1 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL THETA
1D7B2 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL IOTA
1D7B3 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL KAPPA
1D7B4 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL LAMDA
1D7B5 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL MU
1D7B6 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL NU
1D7B7 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL XI
1D7B8 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL OMICRON
1D7B9 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL PI
1D7BA MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL RHO
1D7BB MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL FINAL SIGMA
1D7BC MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL SIGMA
1D7BD MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL TAU
1D7BE MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL UPSILON
1D7BF MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL PHI
1D7C0 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL CHI
1D7C1 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL PSI
1D7C2 MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL OMEGA
1D7C3 MATHEMATICAL SANS-SERIF BOLD ITALIC PARTIAL DIFFERENTIAL
1D7C4 MATHEMATICAL SANS-SERIF BOLD ITALIC EPSILON SYMBOL
1D7C5 MATHEMATICAL SANS-SERIF BOLD ITALIC THETA SYMBOL
1D7C6 MATHEMATICAL SANS-SERIF BOLD ITALIC KAPPA SYMBOL
1D7C7 MATHEMATICAL SANS-SERIF BOLD ITALIC PHI SYMBOL
1D7C8 MATHEMATICAL SANS-SERIF BOLD ITALIC RHO SYMBOL
1D7C9 MATHEMATICAL SANS-SERIF BOLD ITALIC PI SYMBOL
1D7CE MATHEMATICAL BOLD DIGIT ZERO
1D7CF MATHEMATICAL BOLD DIGIT ONE
1D7D0 MATHEMATICAL BOLD DIGIT TWO
1D7D1 MATHEMATICAL BOLD DIGIT THREE
1D7D2 MATHEMATICAL BOLD DIGIT FOUR
1D7D3 MATHEMATICAL BOLD DIGIT FIVE
1D7D4 MATHEMATICAL BOLD DIGIT SIX
1D7D5 MATHEMATICAL BOLD DIGIT SEVEN
1D7D6 MATHEMATICAL BOLD DIGIT EIGHT
1D7D7 MATHEMATICAL BOLD DIGIT NINE
1D7D8 MATHEMATICAL DOUBLE-STRUCK DIGIT ZERO
1D7D9 MATHEMATICAL DOUBLE-STRUCK DIGIT ONE
1D7DA MATHEMATICAL DOUBLE-STRUCK DIGIT TWO
1D7DB MATHEMATICAL DOUBLE-STRUCK DIGIT THREE
1D7DC MATHEMATICAL DOUBLE-STRUCK DIGIT FOUR
1D7DD MATHEMATICAL DOUBLE-STRUCK DIGIT FIVE
1D7DE MATHEMATICAL DOUBLE-STRUCK DIGIT SIX
1D7DF MATHEMATICAL DOUBLE-STRUCK DIGIT SEVEN
1D7E0 MATHEMATICAL DOUBLE-STRUCK DIGIT EIGHT
1D7E1 MATHEMATICAL DOUBLE-STRUCK DIGIT NINE
1D7E2 MATHEMATICAL SANS-SERIF DIGIT ZERO
1D7E3 MATHEMATICAL SANS-SERIF DIGIT ONE
1D7E4 MATHEMATICAL SANS-SERIF DIGIT TWO
1D7E5 MATHEMATICAL SANS-SERIF DIGIT THREE
1D7E6 MATHEMATICAL SANS-SERIF DIGIT FOUR
1D7E7 MATHEMATICAL SANS-SERIF DIGIT FIVE
1D7E8 MATHEMATICAL SANS-SERIF DIGIT SIX
1D7E9 MATHEMATICAL SANS-SERIF DIGIT SEVEN
1D7EA MATHEMATICAL SANS-SERIF DIGIT EIGHT
1D7EB MATHEMATICAL SANS-SERIF DIGIT NINE
1D7EC MATHEMATICAL SANS-SERIF BOLD DIGIT ZERO
1D7ED MATHEMATICAL SANS-SERIF BOLD DIGIT ONE
1D7EE MATHEMATICAL SANS-SERIF BOLD DIGIT TWO
1D7EF MATHEMATICAL SANS-SERIF BOLD DIGIT THREE
1D7F0 MATHEMATICAL SANS-SERIF BOLD DIGIT FOUR
1D7F1 MATHEMATICAL SANS-SERIF BOLD DIGIT FIVE
1D7F2 MATHEMATICAL SANS-SERIF BOLD DIGIT SIX
1D7F3 MATHEMATICAL SANS-SERIF BOLD DIGIT SEVEN
1D7F4 MATHEMATICAL SANS-SERIF BOLD DIGIT EIGHT
1D7F5 MATHEMATICAL SANS-SERIF BOLD DIGIT NINE
1D7F6 MATHEMATICAL MONOSPACE DIGIT ZERO
1D7F7 MATHEMATICAL MONOSPACE DIGIT ONE
1D7F8 MATHEMATICAL MONOSPACE DIGIT TWO
1D7F9 MATHEMATICAL MONOSPACE DIGIT THREE
1D7FA MATHEMATICAL MONOSPACE DIGIT FOUR
1D7FB MATHEMATICAL MONOSPACE DIGIT FIVE
1D7FC MATHEMATICAL MONOSPACE DIGIT SIX
1D7FD MATHEMATICAL MONOSPACE DIGIT SEVEN
1D7FE MATHEMATICAL MONOSPACE DIGIT EIGHT
1D7FF MATHEMATICAL MONOSPACE DIGIT NINE
20000 <CJK Ideograph Extension B, First>
2A6D6 <CJK Ideograph Extension B, Last>
2F800 CJK COMPATIBILITY IDEOGRAPH-2F800
2F801 CJK COMPATIBILITY IDEOGRAPH-2F801
2F802 CJK COMPATIBILITY IDEOGRAPH-2F802
2F803 CJK COMPATIBILITY IDEOGRAPH-2F803
2F804 CJK COMPATIBILITY IDEOGRAPH-2F804
2F805 CJK COMPATIBILITY IDEOGRAPH-2F805
2F806 CJK COMPATIBILITY IDEOGRAPH-2F806
2F807 CJK COMPATIBILITY IDEOGRAPH-2F807
2F808 CJK COMPATIBILITY IDEOGRAPH-2F808
2F809 CJK COMPATIBILITY IDEOGRAPH-2F809
2F80A CJK COMPATIBILITY IDEOGRAPH-2F80A
2F80B CJK COMPATIBILITY IDEOGRAPH-2F80B
2F80C CJK COMPATIBILITY IDEOGRAPH-2F80C
2F80D CJK COMPATIBILITY IDEOGRAPH-2F80D
2F80E CJK COMPATIBILITY IDEOGRAPH-2F80E
2F80F CJK COMPATIBILITY IDEOGRAPH-2F80F
2F810 CJK COMPATIBILITY IDEOGRAPH-2F810
2F811 CJK COMPATIBILITY IDEOGRAPH-2F811
2F812 CJK COMPATIBILITY IDEOGRAPH-2F812
2F813 CJK COMPATIBILITY IDEOGRAPH-2F813
2F814 CJK COMPATIBILITY IDEOGRAPH-2F814
2F815 CJK COMPATIBILITY IDEOGRAPH-2F815
2F816 CJK COMPATIBILITY IDEOGRAPH-2F816
2F817 CJK COMPATIBILITY IDEOGRAPH-2F817
2F818 CJK COMPATIBILITY IDEOGRAPH-2F818
2F819 CJK COMPATIBILITY IDEOGRAPH-2F819
2F81A CJK COMPATIBILITY IDEOGRAPH-2F81A
2F81B CJK COMPATIBILITY IDEOGRAPH-2F81B
2F81C CJK COMPATIBILITY IDEOGRAPH-2F81C
2F81D CJK COMPATIBILITY IDEOGRAPH-2F81D
2F81E CJK COMPATIBILITY IDEOGRAPH-2F81E
2F81F CJK COMPATIBILITY IDEOGRAPH-2F81F
2F820 CJK COMPATIBILITY IDEOGRAPH-2F820
2F821 CJK COMPATIBILITY IDEOGRAPH-2F821
2F822 CJK COMPATIBILITY IDEOGRAPH-2F822
2F823 CJK COMPATIBILITY IDEOGRAPH-2F823
2F824 CJK COMPATIBILITY IDEOGRAPH-2F824
2F825 CJK COMPATIBILITY IDEOGRAPH-2F825
2F826 CJK COMPATIBILITY IDEOGRAPH-2F826
2F827 CJK COMPATIBILITY IDEOGRAPH-2F827
2F828 CJK COMPATIBILITY IDEOGRAPH-2F828
2F829 CJK COMPATIBILITY IDEOGRAPH-2F829
2F82A CJK COMPATIBILITY IDEOGRAPH-2F82A
2F82B CJK COMPATIBILITY IDEOGRAPH-2F82B
2F82C CJK COMPATIBILITY IDEOGRAPH-2F82C
2F82D CJK COMPATIBILITY IDEOGRAPH-2F82D
2F82E CJK COMPATIBILITY IDEOGRAPH-2F82E
2F82F CJK COMPATIBILITY IDEOGRAPH-2F82F
2F830 CJK COMPATIBILITY IDEOGRAPH-2F830
2F831 CJK COMPATIBILITY IDEOGRAPH-2F831
2F832 CJK COMPATIBILITY IDEOGRAPH-2F832
2F833 CJK COMPATIBILITY IDEOGRAPH-2F833
2F834 CJK COMPATIBILITY IDEOGRAPH-2F834
2F835 CJK COMPATIBILITY IDEOGRAPH-2F835
2F836 CJK COMPATIBILITY IDEOGRAPH-2F836
2F837 CJK COMPATIBILITY IDEOGRAPH-2F837
2F838 CJK COMPATIBILITY IDEOGRAPH-2F838
2F839 CJK COMPATIBILITY IDEOGRAPH-2F839
2F83A CJK COMPATIBILITY IDEOGRAPH-2F83A
2F83B CJK COMPATIBILITY IDEOGRAPH-2F83B
2F83C CJK COMPATIBILITY IDEOGRAPH-2F83C
2F83D CJK COMPATIBILITY IDEOGRAPH-2F83D
2F83E CJK COMPATIBILITY IDEOGRAPH-2F83E
2F83F CJK COMPATIBILITY IDEOGRAPH-2F83F
2F840 CJK COMPATIBILITY IDEOGRAPH-2F840
2F841 CJK COMPATIBILITY IDEOGRAPH-2F841
2F842 CJK COMPATIBILITY IDEOGRAPH-2F842
2F843 CJK COMPATIBILITY IDEOGRAPH-2F843
2F844 CJK COMPATIBILITY IDEOGRAPH-2F844
2F845 CJK COMPATIBILITY IDEOGRAPH-2F845
2F846 CJK COMPATIBILITY IDEOGRAPH-2F846
2F847 CJK COMPATIBILITY IDEOGRAPH-2F847
2F848 CJK COMPATIBILITY IDEOGRAPH-2F848
2F849 CJK COMPATIBILITY IDEOGRAPH-2F849
2F84A CJK COMPATIBILITY IDEOGRAPH-2F84A
2F84B CJK COMPATIBILITY IDEOGRAPH-2F84B
2F84C CJK COMPATIBILITY IDEOGRAPH-2F84C
2F84D CJK COMPATIBILITY IDEOGRAPH-2F84D
2F84E CJK COMPATIBILITY IDEOGRAPH-2F84E
2F84F CJK COMPATIBILITY IDEOGRAPH-2F84F
2F850 CJK COMPATIBILITY IDEOGRAPH-2F850
2F851 CJK COMPATIBILITY IDEOGRAPH-2F851
2F852 CJK COMPATIBILITY IDEOGRAPH-2F852
2F853 CJK COMPATIBILITY IDEOGRAPH-2F853
2F854 CJK COMPATIBILITY IDEOGRAPH-2F854
2F855 CJK COMPATIBILITY IDEOGRAPH-2F855
2F856 CJK COMPATIBILITY IDEOGRAPH-2F856
2F857 CJK COMPATIBILITY IDEOGRAPH-2F857
2F858 CJK COMPATIBILITY IDEOGRAPH-2F858
2F859 CJK COMPATIBILITY IDEOGRAPH-2F859
2F85A CJK COMPATIBILITY IDEOGRAPH-2F85A
2F85B CJK COMPATIBILITY IDEOGRAPH-2F85B
2F85C CJK COMPATIBILITY IDEOGRAPH-2F85C
2F85D CJK COMPATIBILITY IDEOGRAPH-2F85D
2F85E CJK COMPATIBILITY IDEOGRAPH-2F85E
2F85F CJK COMPATIBILITY IDEOGRAPH-2F85F
2F860 CJK COMPATIBILITY IDEOGRAPH-2F860
2F861 CJK COMPATIBILITY IDEOGRAPH-2F861
2F862 CJK COMPATIBILITY IDEOGRAPH-2F862
2F863 CJK COMPATIBILITY IDEOGRAPH-2F863
2F864 CJK COMPATIBILITY IDEOGRAPH-2F864
2F865 CJK COMPATIBILITY IDEOGRAPH-2F865
2F866 CJK COMPATIBILITY IDEOGRAPH-2F866
2F867 CJK COMPATIBILITY IDEOGRAPH-2F867
2F868 CJK COMPATIBILITY IDEOGRAPH-2F868
2F869 CJK COMPATIBILITY IDEOGRAPH-2F869
2F86A CJK COMPATIBILITY IDEOGRAPH-2F86A
2F86B CJK COMPATIBILITY IDEOGRAPH-2F86B
2F86C CJK COMPATIBILITY IDEOGRAPH-2F86C
2F86D CJK COMPATIBILITY IDEOGRAPH-2F86D
2F86E CJK COMPATIBILITY IDEOGRAPH-2F86E
2F86F CJK COMPATIBILITY IDEOGRAPH-2F86F
2F870 CJK COMPATIBILITY IDEOGRAPH-2F870
2F871 CJK COMPATIBILITY IDEOGRAPH-2F871
2F872 CJK COMPATIBILITY IDEOGRAPH-2F872
2F873 CJK COMPATIBILITY IDEOGRAPH-2F873
2F874 CJK COMPATIBILITY IDEOGRAPH-2F874
2F875 CJK COMPATIBILITY IDEOGRAPH-2F875
2F876 CJK COMPATIBILITY IDEOGRAPH-2F876
2F877 CJK COMPATIBILITY IDEOGRAPH-2F877
2F878 CJK COMPATIBILITY IDEOGRAPH-2F878
2F879 CJK COMPATIBILITY IDEOGRAPH-2F879
2F87A CJK COMPATIBILITY IDEOGRAPH-2F87A
2F87B CJK COMPATIBILITY IDEOGRAPH-2F87B
2F87C CJK COMPATIBILITY IDEOGRAPH-2F87C
2F87D CJK COMPATIBILITY IDEOGRAPH-2F87D
2F87E CJK COMPATIBILITY IDEOGRAPH-2F87E
2F87F CJK COMPATIBILITY IDEOGRAPH-2F87F
2F880 CJK COMPATIBILITY IDEOGRAPH-2F880
2F881 CJK COMPATIBILITY IDEOGRAPH-2F881
2F882 CJK COMPATIBILITY IDEOGRAPH-2F882
2F883 CJK COMPATIBILITY IDEOGRAPH-2F883
2F884 CJK COMPATIBILITY IDEOGRAPH-2F884
2F885 CJK COMPATIBILITY IDEOGRAPH-2F885
2F886 CJK COMPATIBILITY IDEOGRAPH-2F886
2F887 CJK COMPATIBILITY IDEOGRAPH-2F887
2F888 CJK COMPATIBILITY IDEOGRAPH-2F888
2F889 CJK COMPATIBILITY IDEOGRAPH-2F889
2F88A CJK COMPATIBILITY IDEOGRAPH-2F88A
2F88B CJK COMPATIBILITY IDEOGRAPH-2F88B
2F88C CJK COMPATIBILITY IDEOGRAPH-2F88C
2F88D CJK COMPATIBILITY IDEOGRAPH-2F88D
2F88E CJK COMPATIBILITY IDEOGRAPH-2F88E
2F88F CJK COMPATIBILITY IDEOGRAPH-2F88F
2F890 CJK COMPATIBILITY IDEOGRAPH-2F890
2F891 CJK COMPATIBILITY IDEOGRAPH-2F891
2F892 CJK COMPATIBILITY IDEOGRAPH-2F892
2F893 CJK COMPATIBILITY IDEOGRAPH-2F893
2F894 CJK COMPATIBILITY IDEOGRAPH-2F894
2F895 CJK COMPATIBILITY IDEOGRAPH-2F895
2F896 CJK COMPATIBILITY IDEOGRAPH-2F896
2F897 CJK COMPATIBILITY IDEOGRAPH-2F897
2F898 CJK COMPATIBILITY IDEOGRAPH-2F898
2F899 CJK COMPATIBILITY IDEOGRAPH-2F899
2F89A CJK COMPATIBILITY IDEOGRAPH-2F89A
2F89B CJK COMPATIBILITY IDEOGRAPH-2F89B
2F89C CJK COMPATIBILITY IDEOGRAPH-2F89C
2F89D CJK COMPATIBILITY IDEOGRAPH-2F89D
2F89E CJK COMPATIBILITY IDEOGRAPH-2F89E
2F89F CJK COMPATIBILITY IDEOGRAPH-2F89F
2F8A0 CJK COMPATIBILITY IDEOGRAPH-2F8A0
2F8A1 CJK COMPATIBILITY IDEOGRAPH-2F8A1
2F8A2 CJK COMPATIBILITY IDEOGRAPH-2F8A2
2F8A3 CJK COMPATIBILITY IDEOGRAPH-2F8A3
2F8A4 CJK COMPATIBILITY IDEOGRAPH-2F8A4
2F8A5 CJK COMPATIBILITY IDEOGRAPH-2F8A5
2F8A6 CJK COMPATIBILITY IDEOGRAPH-2F8A6
2F8A7 CJK COMPATIBILITY IDEOGRAPH-2F8A7
2F8A8 CJK COMPATIBILITY IDEOGRAPH-2F8A8
2F8A9 CJK COMPATIBILITY IDEOGRAPH-2F8A9
2F8AA CJK COMPATIBILITY IDEOGRAPH-2F8AA
2F8AB CJK COMPATIBILITY IDEOGRAPH-2F8AB
2F8AC CJK COMPATIBILITY IDEOGRAPH-2F8AC
2F8AD CJK COMPATIBILITY IDEOGRAPH-2F8AD
2F8AE CJK COMPATIBILITY IDEOGRAPH-2F8AE
2F8AF CJK COMPATIBILITY IDEOGRAPH-2F8AF
2F8B0 CJK COMPATIBILITY IDEOGRAPH-2F8B0
2F8B1 CJK COMPATIBILITY IDEOGRAPH-2F8B1
2F8B2 CJK COMPATIBILITY IDEOGRAPH-2F8B2
2F8B3 CJK COMPATIBILITY IDEOGRAPH-2F8B3
2F8B4 CJK COMPATIBILITY IDEOGRAPH-2F8B4
2F8B5 CJK COMPATIBILITY IDEOGRAPH-2F8B5
2F8B6 CJK COMPATIBILITY IDEOGRAPH-2F8B6
2F8B7 CJK COMPATIBILITY IDEOGRAPH-2F8B7
2F8B8 CJK COMPATIBILITY IDEOGRAPH-2F8B8
2F8B9 CJK COMPATIBILITY IDEOGRAPH-2F8B9
2F8BA CJK COMPATIBILITY IDEOGRAPH-2F8BA
2F8BB CJK COMPATIBILITY IDEOGRAPH-2F8BB
2F8BC CJK COMPATIBILITY IDEOGRAPH-2F8BC
2F8BD CJK COMPATIBILITY IDEOGRAPH-2F8BD
2F8BE CJK COMPATIBILITY IDEOGRAPH-2F8BE
2F8BF CJK COMPATIBILITY IDEOGRAPH-2F8BF
2F8C0 CJK COMPATIBILITY IDEOGRAPH-2F8C0
2F8C1 CJK COMPATIBILITY IDEOGRAPH-2F8C1
2F8C2 CJK COMPATIBILITY IDEOGRAPH-2F8C2
2F8C3 CJK COMPATIBILITY IDEOGRAPH-2F8C3
2F8C4 CJK COMPATIBILITY IDEOGRAPH-2F8C4
2F8C5 CJK COMPATIBILITY IDEOGRAPH-2F8C5
2F8C6 CJK COMPATIBILITY IDEOGRAPH-2F8C6
2F8C7 CJK COMPATIBILITY IDEOGRAPH-2F8C7
2F8C8 CJK COMPATIBILITY IDEOGRAPH-2F8C8
2F8C9 CJK COMPATIBILITY IDEOGRAPH-2F8C9
2F8CA CJK COMPATIBILITY IDEOGRAPH-2F8CA
2F8CB CJK COMPATIBILITY IDEOGRAPH-2F8CB
2F8CC CJK COMPATIBILITY IDEOGRAPH-2F8CC
2F8CD CJK COMPATIBILITY IDEOGRAPH-2F8CD
2F8CE CJK COMPATIBILITY IDEOGRAPH-2F8CE
2F8CF CJK COMPATIBILITY IDEOGRAPH-2F8CF
2F8D0 CJK COMPATIBILITY IDEOGRAPH-2F8D0
2F8D1 CJK COMPATIBILITY IDEOGRAPH-2F8D1
2F8D2 CJK COMPATIBILITY IDEOGRAPH-2F8D2
2F8D3 CJK COMPATIBILITY IDEOGRAPH-2F8D3
2F8D4 CJK COMPATIBILITY IDEOGRAPH-2F8D4
2F8D5 CJK COMPATIBILITY IDEOGRAPH-2F8D5
2F8D6 CJK COMPATIBILITY IDEOGRAPH-2F8D6
2F8D7 CJK COMPATIBILITY IDEOGRAPH-2F8D7
2F8D8 CJK COMPATIBILITY IDEOGRAPH-2F8D8
2F8D9 CJK COMPATIBILITY IDEOGRAPH-2F8D9
2F8DA CJK COMPATIBILITY IDEOGRAPH-2F8DA
2F8DB CJK COMPATIBILITY IDEOGRAPH-2F8DB
2F8DC CJK COMPATIBILITY IDEOGRAPH-2F8DC
2F8DD CJK COMPATIBILITY IDEOGRAPH-2F8DD
2F8DE CJK COMPATIBILITY IDEOGRAPH-2F8DE
2F8DF CJK COMPATIBILITY IDEOGRAPH-2F8DF
2F8E0 CJK COMPATIBILITY IDEOGRAPH-2F8E0
2F8E1 CJK COMPATIBILITY IDEOGRAPH-2F8E1
2F8E2 CJK COMPATIBILITY IDEOGRAPH-2F8E2
2F8E3 CJK COMPATIBILITY IDEOGRAPH-2F8E3
2F8E4 CJK COMPATIBILITY IDEOGRAPH-2F8E4
2F8E5 CJK COMPATIBILITY IDEOGRAPH-2F8E5
2F8E6 CJK COMPATIBILITY IDEOGRAPH-2F8E6
2F8E7 CJK COMPATIBILITY IDEOGRAPH-2F8E7
2F8E8 CJK COMPATIBILITY IDEOGRAPH-2F8E8
2F8E9 CJK COMPATIBILITY IDEOGRAPH-2F8E9
2F8EA CJK COMPATIBILITY IDEOGRAPH-2F8EA
2F8EB CJK COMPATIBILITY IDEOGRAPH-2F8EB
2F8EC CJK COMPATIBILITY IDEOGRAPH-2F8EC
2F8ED CJK COMPATIBILITY IDEOGRAPH-2F8ED
2F8EE CJK COMPATIBILITY IDEOGRAPH-2F8EE
2F8EF CJK COMPATIBILITY IDEOGRAPH-2F8EF
2F8F0 CJK COMPATIBILITY IDEOGRAPH-2F8F0
2F8F1 CJK COMPATIBILITY IDEOGRAPH-2F8F1
2F8F2 CJK COMPATIBILITY IDEOGRAPH-2F8F2
2F8F3 CJK COMPATIBILITY IDEOGRAPH-2F8F3
2F8F4 CJK COMPATIBILITY IDEOGRAPH-2F8F4
2F8F5 CJK COMPATIBILITY IDEOGRAPH-2F8F5
2F8F6 CJK COMPATIBILITY IDEOGRAPH-2F8F6
2F8F7 CJK COMPATIBILITY IDEOGRAPH-2F8F7
2F8F8 CJK COMPATIBILITY IDEOGRAPH-2F8F8
2F8F9 CJK COMPATIBILITY IDEOGRAPH-2F8F9
2F8FA CJK COMPATIBILITY IDEOGRAPH-2F8FA
2F8FB CJK COMPATIBILITY IDEOGRAPH-2F8FB
2F8FC CJK COMPATIBILITY IDEOGRAPH-2F8FC
2F8FD CJK COMPATIBILITY IDEOGRAPH-2F8FD
2F8FE CJK COMPATIBILITY IDEOGRAPH-2F8FE
2F8FF CJK COMPATIBILITY IDEOGRAPH-2F8FF
2F900 CJK COMPATIBILITY IDEOGRAPH-2F900
2F901 CJK COMPATIBILITY IDEOGRAPH-2F901
2F902 CJK COMPATIBILITY IDEOGRAPH-2F902
2F903 CJK COMPATIBILITY IDEOGRAPH-2F903
2F904 CJK COMPATIBILITY IDEOGRAPH-2F904
2F905 CJK COMPATIBILITY IDEOGRAPH-2F905
2F906 CJK COMPATIBILITY IDEOGRAPH-2F906
2F907 CJK COMPATIBILITY IDEOGRAPH-2F907
2F908 CJK COMPATIBILITY IDEOGRAPH-2F908
2F909 CJK COMPATIBILITY IDEOGRAPH-2F909
2F90A CJK COMPATIBILITY IDEOGRAPH-2F90A
2F90B CJK COMPATIBILITY IDEOGRAPH-2F90B
2F90C CJK COMPATIBILITY IDEOGRAPH-2F90C
2F90D CJK COMPATIBILITY IDEOGRAPH-2F90D
2F90E CJK COMPATIBILITY IDEOGRAPH-2F90E
2F90F CJK COMPATIBILITY IDEOGRAPH-2F90F
2F910 CJK COMPATIBILITY IDEOGRAPH-2F910
2F911 CJK COMPATIBILITY IDEOGRAPH-2F911
2F912 CJK COMPATIBILITY IDEOGRAPH-2F912
2F913 CJK COMPATIBILITY IDEOGRAPH-2F913
2F914 CJK COMPATIBILITY IDEOGRAPH-2F914
2F915 CJK COMPATIBILITY IDEOGRAPH-2F915
2F916 CJK COMPATIBILITY IDEOGRAPH-2F916
2F917 CJK COMPATIBILITY IDEOGRAPH-2F917
2F918 CJK COMPATIBILITY IDEOGRAPH-2F918
2F919 CJK COMPATIBILITY IDEOGRAPH-2F919
2F91A CJK COMPATIBILITY IDEOGRAPH-2F91A
2F91B CJK COMPATIBILITY IDEOGRAPH-2F91B
2F91C CJK COMPATIBILITY IDEOGRAPH-2F91C
2F91D CJK COMPATIBILITY IDEOGRAPH-2F91D
2F91E CJK COMPATIBILITY IDEOGRAPH-2F91E
2F91F CJK COMPATIBILITY IDEOGRAPH-2F91F
2F920 CJK COMPATIBILITY IDEOGRAPH-2F920
2F921 CJK COMPATIBILITY IDEOGRAPH-2F921
2F922 CJK COMPATIBILITY IDEOGRAPH-2F922
2F923 CJK COMPATIBILITY IDEOGRAPH-2F923
2F924 CJK COMPATIBILITY IDEOGRAPH-2F924
2F925 CJK COMPATIBILITY IDEOGRAPH-2F925
2F926 CJK COMPATIBILITY IDEOGRAPH-2F926
2F927 CJK COMPATIBILITY IDEOGRAPH-2F927
2F928 CJK COMPATIBILITY IDEOGRAPH-2F928
2F929 CJK COMPATIBILITY IDEOGRAPH-2F929
2F92A CJK COMPATIBILITY IDEOGRAPH-2F92A
2F92B CJK COMPATIBILITY IDEOGRAPH-2F92B
2F92C CJK COMPATIBILITY IDEOGRAPH-2F92C
2F92D CJK COMPATIBILITY IDEOGRAPH-2F92D
2F92E CJK COMPATIBILITY IDEOGRAPH-2F92E
2F92F CJK COMPATIBILITY IDEOGRAPH-2F92F
2F930 CJK COMPATIBILITY IDEOGRAPH-2F930
2F931 CJK COMPATIBILITY IDEOGRAPH-2F931
2F932 CJK COMPATIBILITY IDEOGRAPH-2F932
2F933 CJK COMPATIBILITY IDEOGRAPH-2F933
2F934 CJK COMPATIBILITY IDEOGRAPH-2F934
2F935 CJK COMPATIBILITY IDEOGRAPH-2F935
2F936 CJK COMPATIBILITY IDEOGRAPH-2F936
2F937 CJK COMPATIBILITY IDEOGRAPH-2F937
2F938 CJK COMPATIBILITY IDEOGRAPH-2F938
2F939 CJK COMPATIBILITY IDEOGRAPH-2F939
2F93A CJK COMPATIBILITY IDEOGRAPH-2F93A
2F93B CJK COMPATIBILITY IDEOGRAPH-2F93B
2F93C CJK COMPATIBILITY IDEOGRAPH-2F93C
2F93D CJK COMPATIBILITY IDEOGRAPH-2F93D
2F93E CJK COMPATIBILITY IDEOGRAPH-2F93E
2F93F CJK COMPATIBILITY IDEOGRAPH-2F93F
2F940 CJK COMPATIBILITY IDEOGRAPH-2F940
2F941 CJK COMPATIBILITY IDEOGRAPH-2F941
2F942 CJK COMPATIBILITY IDEOGRAPH-2F942
2F943 CJK COMPATIBILITY IDEOGRAPH-2F943
2F944 CJK COMPATIBILITY IDEOGRAPH-2F944
2F945 CJK COMPATIBILITY IDEOGRAPH-2F945
2F946 CJK COMPATIBILITY IDEOGRAPH-2F946
2F947 CJK COMPATIBILITY IDEOGRAPH-2F947
2F948 CJK COMPATIBILITY IDEOGRAPH-2F948
2F949 CJK COMPATIBILITY IDEOGRAPH-2F949
2F94A CJK COMPATIBILITY IDEOGRAPH-2F94A
2F94B CJK COMPATIBILITY IDEOGRAPH-2F94B
2F94C CJK COMPATIBILITY IDEOGRAPH-2F94C
2F94D CJK COMPATIBILITY IDEOGRAPH-2F94D
2F94E CJK COMPATIBILITY IDEOGRAPH-2F94E
2F94F CJK COMPATIBILITY IDEOGRAPH-2F94F
2F950 CJK COMPATIBILITY IDEOGRAPH-2F950
2F951 CJK COMPATIBILITY IDEOGRAPH-2F951
2F952 CJK COMPATIBILITY IDEOGRAPH-2F952
2F953 CJK COMPATIBILITY IDEOGRAPH-2F953
2F954 CJK COMPATIBILITY IDEOGRAPH-2F954
2F955 CJK COMPATIBILITY IDEOGRAPH-2F955
2F956 CJK COMPATIBILITY IDEOGRAPH-2F956
2F957 CJK COMPATIBILITY IDEOGRAPH-2F957
2F958 CJK COMPATIBILITY IDEOGRAPH-2F958
2F959 CJK COMPATIBILITY IDEOGRAPH-2F959
2F95A CJK COMPATIBILITY IDEOGRAPH-2F95A
2F95B CJK COMPATIBILITY IDEOGRAPH-2F95B
2F95C CJK COMPATIBILITY IDEOGRAPH-2F95C
2F95D CJK COMPATIBILITY IDEOGRAPH-2F95D
2F95E CJK COMPATIBILITY IDEOGRAPH-2F95E
2F95F CJK COMPATIBILITY IDEOGRAPH-2F95F
2F960 CJK COMPATIBILITY IDEOGRAPH-2F960
2F961 CJK COMPATIBILITY IDEOGRAPH-2F961
2F962 CJK COMPATIBILITY IDEOGRAPH-2F962
2F963 CJK COMPATIBILITY IDEOGRAPH-2F963
2F964 CJK COMPATIBILITY IDEOGRAPH-2F964
2F965 CJK COMPATIBILITY IDEOGRAPH-2F965
2F966 CJK COMPATIBILITY IDEOGRAPH-2F966
2F967 CJK COMPATIBILITY IDEOGRAPH-2F967
2F968 CJK COMPATIBILITY IDEOGRAPH-2F968
2F969 CJK COMPATIBILITY IDEOGRAPH-2F969
2F96A CJK COMPATIBILITY IDEOGRAPH-2F96A
2F96B CJK COMPATIBILITY IDEOGRAPH-2F96B
2F96C CJK COMPATIBILITY IDEOGRAPH-2F96C
2F96D CJK COMPATIBILITY IDEOGRAPH-2F96D
2F96E CJK COMPATIBILITY IDEOGRAPH-2F96E
2F96F CJK COMPATIBILITY IDEOGRAPH-2F96F
2F970 CJK COMPATIBILITY IDEOGRAPH-2F970
2F971 CJK COMPATIBILITY IDEOGRAPH-2F971
2F972 CJK COMPATIBILITY IDEOGRAPH-2F972
2F973 CJK COMPATIBILITY IDEOGRAPH-2F973
2F974 CJK COMPATIBILITY IDEOGRAPH-2F974
2F975 CJK COMPATIBILITY IDEOGRAPH-2F975
2F976 CJK COMPATIBILITY IDEOGRAPH-2F976
2F977 CJK COMPATIBILITY IDEOGRAPH-2F977
2F978 CJK COMPATIBILITY IDEOGRAPH-2F978
2F979 CJK COMPATIBILITY IDEOGRAPH-2F979
2F97A CJK COMPATIBILITY IDEOGRAPH-2F97A
2F97B CJK COMPATIBILITY IDEOGRAPH-2F97B
2F97C CJK COMPATIBILITY IDEOGRAPH-2F97C
2F97D CJK COMPATIBILITY IDEOGRAPH-2F97D
2F97E CJK COMPATIBILITY IDEOGRAPH-2F97E
2F97F CJK COMPATIBILITY IDEOGRAPH-2F97F
2F980 CJK COMPATIBILITY IDEOGRAPH-2F980
2F981 CJK COMPATIBILITY IDEOGRAPH-2F981
2F982 CJK COMPATIBILITY IDEOGRAPH-2F982
2F983 CJK COMPATIBILITY IDEOGRAPH-2F983
2F984 CJK COMPATIBILITY IDEOGRAPH-2F984
2F985 CJK COMPATIBILITY IDEOGRAPH-2F985
2F986 CJK COMPATIBILITY IDEOGRAPH-2F986
2F987 CJK COMPATIBILITY IDEOGRAPH-2F987
2F988 CJK COMPATIBILITY IDEOGRAPH-2F988
2F989 CJK COMPATIBILITY IDEOGRAPH-2F989
2F98A CJK COMPATIBILITY IDEOGRAPH-2F98A
2F98B CJK COMPATIBILITY IDEOGRAPH-2F98B
2F98C CJK COMPATIBILITY IDEOGRAPH-2F98C
2F98D CJK COMPATIBILITY IDEOGRAPH-2F98D
2F98E CJK COMPATIBILITY IDEOGRAPH-2F98E
2F98F CJK COMPATIBILITY IDEOGRAPH-2F98F
2F990 CJK COMPATIBILITY IDEOGRAPH-2F990
2F991 CJK COMPATIBILITY IDEOGRAPH-2F991
2F992 CJK COMPATIBILITY IDEOGRAPH-2F992
2F993 CJK COMPATIBILITY IDEOGRAPH-2F993
2F994 CJK COMPATIBILITY IDEOGRAPH-2F994
2F995 CJK COMPATIBILITY IDEOGRAPH-2F995
2F996 CJK COMPATIBILITY IDEOGRAPH-2F996
2F997 CJK COMPATIBILITY IDEOGRAPH-2F997
2F998 CJK COMPATIBILITY IDEOGRAPH-2F998
2F999 CJK COMPATIBILITY IDEOGRAPH-2F999
2F99A CJK COMPATIBILITY IDEOGRAPH-2F99A
2F99B CJK COMPATIBILITY IDEOGRAPH-2F99B
2F99C CJK COMPATIBILITY IDEOGRAPH-2F99C
2F99D CJK COMPATIBILITY IDEOGRAPH-2F99D
2F99E CJK COMPATIBILITY IDEOGRAPH-2F99E
2F99F CJK COMPATIBILITY IDEOGRAPH-2F99F
2F9A0 CJK COMPATIBILITY IDEOGRAPH-2F9A0
2F9A1 CJK COMPATIBILITY IDEOGRAPH-2F9A1
2F9A2 CJK COMPATIBILITY IDEOGRAPH-2F9A2
2F9A3 CJK COMPATIBILITY IDEOGRAPH-2F9A3
2F9A4 CJK COMPATIBILITY IDEOGRAPH-2F9A4
2F9A5 CJK COMPATIBILITY IDEOGRAPH-2F9A5
2F9A6 CJK COMPATIBILITY IDEOGRAPH-2F9A6
2F9A7 CJK COMPATIBILITY IDEOGRAPH-2F9A7
2F9A8 CJK COMPATIBILITY IDEOGRAPH-2F9A8
2F9A9 CJK COMPATIBILITY IDEOGRAPH-2F9A9
2F9AA CJK COMPATIBILITY IDEOGRAPH-2F9AA
2F9AB CJK COMPATIBILITY IDEOGRAPH-2F9AB
2F9AC CJK COMPATIBILITY IDEOGRAPH-2F9AC
2F9AD CJK COMPATIBILITY IDEOGRAPH-2F9AD
2F9AE CJK COMPATIBILITY IDEOGRAPH-2F9AE
2F9AF CJK COMPATIBILITY IDEOGRAPH-2F9AF
2F9B0 CJK COMPATIBILITY IDEOGRAPH-2F9B0
2F9B1 CJK COMPATIBILITY IDEOGRAPH-2F9B1
2F9B2 CJK COMPATIBILITY IDEOGRAPH-2F9B2
2F9B3 CJK COMPATIBILITY IDEOGRAPH-2F9B3
2F9B4 CJK COMPATIBILITY IDEOGRAPH-2F9B4
2F9B5 CJK COMPATIBILITY IDEOGRAPH-2F9B5
2F9B6 CJK COMPATIBILITY IDEOGRAPH-2F9B6
2F9B7 CJK COMPATIBILITY IDEOGRAPH-2F9B7
2F9B8 CJK COMPATIBILITY IDEOGRAPH-2F9B8
2F9B9 CJK COMPATIBILITY IDEOGRAPH-2F9B9
2F9BA CJK COMPATIBILITY IDEOGRAPH-2F9BA
2F9BB CJK COMPATIBILITY IDEOGRAPH-2F9BB
2F9BC CJK COMPATIBILITY IDEOGRAPH-2F9BC
2F9BD CJK COMPATIBILITY IDEOGRAPH-2F9BD
2F9BE CJK COMPATIBILITY IDEOGRAPH-2F9BE
2F9BF CJK COMPATIBILITY IDEOGRAPH-2F9BF
2F9C0 CJK COMPATIBILITY IDEOGRAPH-2F9C0
2F9C1 CJK COMPATIBILITY IDEOGRAPH-2F9C1
2F9C2 CJK COMPATIBILITY IDEOGRAPH-2F9C2
2F9C3 CJK COMPATIBILITY IDEOGRAPH-2F9C3
2F9C4 CJK COMPATIBILITY IDEOGRAPH-2F9C4
2F9C5 CJK COMPATIBILITY IDEOGRAPH-2F9C5
2F9C6 CJK COMPATIBILITY IDEOGRAPH-2F9C6
2F9C7 CJK COMPATIBILITY IDEOGRAPH-2F9C7
2F9C8 CJK COMPATIBILITY IDEOGRAPH-2F9C8
2F9C9 CJK COMPATIBILITY IDEOGRAPH-2F9C9
2F9CA CJK COMPATIBILITY IDEOGRAPH-2F9CA
2F9CB CJK COMPATIBILITY IDEOGRAPH-2F9CB
2F9CC CJK COMPATIBILITY IDEOGRAPH-2F9CC
2F9CD CJK COMPATIBILITY IDEOGRAPH-2F9CD
2F9CE CJK COMPATIBILITY IDEOGRAPH-2F9CE
2F9CF CJK COMPATIBILITY IDEOGRAPH-2F9CF
2F9D0 CJK COMPATIBILITY IDEOGRAPH-2F9D0
2F9D1 CJK COMPATIBILITY IDEOGRAPH-2F9D1
2F9D2 CJK COMPATIBILITY IDEOGRAPH-2F9D2
2F9D3 CJK COMPATIBILITY IDEOGRAPH-2F9D3
2F9D4 CJK COMPATIBILITY IDEOGRAPH-2F9D4
2F9D5 CJK COMPATIBILITY IDEOGRAPH-2F9D5
2F9D6 CJK COMPATIBILITY IDEOGRAPH-2F9D6
2F9D7 CJK COMPATIBILITY IDEOGRAPH-2F9D7
2F9D8 CJK COMPATIBILITY IDEOGRAPH-2F9D8
2F9D9 CJK COMPATIBILITY IDEOGRAPH-2F9D9
2F9DA CJK COMPATIBILITY IDEOGRAPH-2F9DA
2F9DB CJK COMPATIBILITY IDEOGRAPH-2F9DB
2F9DC CJK COMPATIBILITY IDEOGRAPH-2F9DC
2F9DD CJK COMPATIBILITY IDEOGRAPH-2F9DD
2F9DE CJK COMPATIBILITY IDEOGRAPH-2F9DE
2F9DF CJK COMPATIBILITY IDEOGRAPH-2F9DF
2F9E0 CJK COMPATIBILITY IDEOGRAPH-2F9E0
2F9E1 CJK COMPATIBILITY IDEOGRAPH-2F9E1
2F9E2 CJK COMPATIBILITY IDEOGRAPH-2F9E2
2F9E3 CJK COMPATIBILITY IDEOGRAPH-2F9E3
2F9E4 CJK COMPATIBILITY IDEOGRAPH-2F9E4
2F9E5 CJK COMPATIBILITY IDEOGRAPH-2F9E5
2F9E6 CJK COMPATIBILITY IDEOGRAPH-2F9E6
2F9E7 CJK COMPATIBILITY IDEOGRAPH-2F9E7
2F9E8 CJK COMPATIBILITY IDEOGRAPH-2F9E8
2F9E9 CJK COMPATIBILITY IDEOGRAPH-2F9E9
2F9EA CJK COMPATIBILITY IDEOGRAPH-2F9EA
2F9EB CJK COMPATIBILITY IDEOGRAPH-2F9EB
2F9EC CJK COMPATIBILITY IDEOGRAPH-2F9EC
2F9ED CJK COMPATIBILITY IDEOGRAPH-2F9ED
2F9EE CJK COMPATIBILITY IDEOGRAPH-2F9EE
2F9EF CJK COMPATIBILITY IDEOGRAPH-2F9EF
2F9F0 CJK COMPATIBILITY IDEOGRAPH-2F9F0
2F9F1 CJK COMPATIBILITY IDEOGRAPH-2F9F1
2F9F2 CJK COMPATIBILITY IDEOGRAPH-2F9F2
2F9F3 CJK COMPATIBILITY IDEOGRAPH-2F9F3
2F9F4 CJK COMPATIBILITY IDEOGRAPH-2F9F4
2F9F5 CJK COMPATIBILITY IDEOGRAPH-2F9F5
2F9F6 CJK COMPATIBILITY IDEOGRAPH-2F9F6
2F9F7 CJK COMPATIBILITY IDEOGRAPH-2F9F7
2F9F8 CJK COMPATIBILITY IDEOGRAPH-2F9F8
2F9F9 CJK COMPATIBILITY IDEOGRAPH-2F9F9
2F9FA CJK COMPATIBILITY IDEOGRAPH-2F9FA
2F9FB CJK COMPATIBILITY IDEOGRAPH-2F9FB
2F9FC CJK COMPATIBILITY IDEOGRAPH-2F9FC
2F9FD CJK COMPATIBILITY IDEOGRAPH-2F9FD
2F9FE CJK COMPATIBILITY IDEOGRAPH-2F9FE
2F9FF CJK COMPATIBILITY IDEOGRAPH-2F9FF
2FA00 CJK COMPATIBILITY IDEOGRAPH-2FA00
2FA01 CJK COMPATIBILITY IDEOGRAPH-2FA01
2FA02 CJK COMPATIBILITY IDEOGRAPH-2FA02
2FA03 CJK COMPATIBILITY IDEOGRAPH-2FA03
2FA04 CJK COMPATIBILITY IDEOGRAPH-2FA04
2FA05 CJK COMPATIBILITY IDEOGRAPH-2FA05
2FA06 CJK COMPATIBILITY IDEOGRAPH-2FA06
2FA07 CJK COMPATIBILITY IDEOGRAPH-2FA07
2FA08 CJK COMPATIBILITY IDEOGRAPH-2FA08
2FA09 CJK COMPATIBILITY IDEOGRAPH-2FA09
2FA0A CJK COMPATIBILITY IDEOGRAPH-2FA0A
2FA0B CJK COMPATIBILITY IDEOGRAPH-2FA0B
2FA0C CJK COMPATIBILITY IDEOGRAPH-2FA0C
2FA0D CJK COMPATIBILITY IDEOGRAPH-2FA0D
2FA0E CJK COMPATIBILITY IDEOGRAPH-2FA0E
2FA0F CJK COMPATIBILITY IDEOGRAPH-2FA0F
2FA10 CJK COMPATIBILITY IDEOGRAPH-2FA10
2FA11 CJK COMPATIBILITY IDEOGRAPH-2FA11
2FA12 CJK COMPATIBILITY IDEOGRAPH-2FA12
2FA13 CJK COMPATIBILITY IDEOGRAPH-2FA13
2FA14 CJK COMPATIBILITY IDEOGRAPH-2FA14
2FA15 CJK COMPATIBILITY IDEOGRAPH-2FA15
2FA16 CJK COMPATIBILITY IDEOGRAPH-2FA16
2FA17 CJK COMPATIBILITY IDEOGRAPH-2FA17
2FA18 CJK COMPATIBILITY IDEOGRAPH-2FA18
2FA19 CJK COMPATIBILITY IDEOGRAPH-2FA19
2FA1A CJK COMPATIBILITY IDEOGRAPH-2FA1A
2FA1B CJK COMPATIBILITY IDEOGRAPH-2FA1B
2FA1C CJK COMPATIBILITY IDEOGRAPH-2FA1C
2FA1D CJK COMPATIBILITY IDEOGRAPH-2FA1D
E0001 LANGUAGE TAG
E0020 TAG SPACE
E0021 TAG EXCLAMATION MARK
E0022 TAG QUOTATION MARK
E0023 TAG NUMBER SIGN
E0024 TAG DOLLAR SIGN
E0025 TAG PERCENT SIGN
E0026 TAG AMPERSAND
E0027 TAG APOSTROPHE
E0028 TAG LEFT PARENTHESIS
E0029 TAG RIGHT PARENTHESIS
E002A TAG ASTERISK
E002B TAG PLUS SIGN
E002C TAG COMMA
E002D TAG HYPHEN-MINUS
E002E TAG FULL STOP
E002F TAG SOLIDUS
E0030 TAG DIGIT ZERO
E0031 TAG DIGIT ONE
E0032 TAG DIGIT TWO
E0033 TAG DIGIT THREE
E0034 TAG DIGIT FOUR
E0035 TAG DIGIT FIVE
E0036 TAG DIGIT SIX
E0037 TAG DIGIT SEVEN
E0038 TAG DIGIT EIGHT
E0039 TAG DIGIT NINE
E003A TAG COLON
E003B TAG SEMICOLON
E003C TAG LESS-THAN SIGN
E003D TAG EQUALS SIGN
E003E TAG GREATER-THAN SIGN
E003F TAG QUESTION MARK
E0040 TAG COMMERCIAL AT
E0041 TAG LATIN CAPITAL LETTER A
E0042 TAG LATIN CAPITAL LETTER B
E0043 TAG LATIN CAPITAL LETTER C
E0044 TAG LATIN CAPITAL LETTER D
E0045 TAG LATIN CAPITAL LETTER E
E0046 TAG LATIN CAPITAL LETTER F
E0047 TAG LATIN CAPITAL LETTER G
E0048 TAG LATIN CAPITAL LETTER H
E0049 TAG LATIN CAPITAL LETTER I
E004A TAG LATIN CAPITAL LETTER J
E004B TAG LATIN CAPITAL LETTER K
E004C TAG LATIN CAPITAL LETTER L
E004D TAG LATIN CAPITAL LETTER M
E004E TAG LATIN CAPITAL LETTER N
E004F TAG LATIN CAPITAL LETTER O
E0050 TAG LATIN CAPITAL LETTER P
E0051 TAG LATIN CAPITAL LETTER Q
E0052 TAG LATIN CAPITAL LETTER R
E0053 TAG LATIN CAPITAL LETTER S
E0054 TAG LATIN CAPITAL LETTER T
E0055 TAG LATIN CAPITAL LETTER U
E0056 TAG LATIN CAPITAL LETTER V
E0057 TAG LATIN CAPITAL LETTER W
E0058 TAG LATIN CAPITAL LETTER X
E0059 TAG LATIN CAPITAL LETTER Y
E005A TAG LATIN CAPITAL LETTER Z
E005B TAG LEFT SQUARE BRACKET
E005C TAG REVERSE SOLIDUS
E005D TAG RIGHT SQUARE BRACKET
E005E TAG CIRCUMFLEX ACCENT
E005F TAG LOW LINE
E0060 TAG GRAVE ACCENT
E0061 TAG LATIN SMALL LETTER A
E0062 TAG LATIN SMALL LETTER B
E0063 TAG LATIN SMALL LETTER C
E0064 TAG LATIN SMALL LETTER D
E0065 TAG LATIN SMALL LETTER E
E0066 TAG LATIN SMALL LETTER F
E0067 TAG LATIN SMALL LETTER G
E0068 TAG LATIN SMALL LETTER H
E0069 TAG LATIN SMALL LETTER I
E006A TAG LATIN SMALL LETTER J
E006B TAG LATIN SMALL LETTER K
E006C TAG LATIN SMALL LETTER L
E006D TAG LATIN SMALL LETTER M
E006E TAG LATIN SMALL LETTER N
E006F TAG LATIN SMALL LETTER O
E0070 TAG LATIN SMALL LETTER P
E0071 TAG LATIN SMALL LETTER Q
E0072 TAG LATIN SMALL LETTER R
E0073 TAG LATIN SMALL LETTER S
E0074 TAG LATIN SMALL LETTER T
E0075 TAG LATIN SMALL LETTER U
E0076 TAG LATIN SMALL LETTER V
E0077 TAG LATIN SMALL LETTER W
E0078 TAG LATIN SMALL LETTER X
E0079 TAG LATIN SMALL LETTER Y
E007A TAG LATIN SMALL LETTER Z
E007B TAG LEFT CURLY BRACKET
E007C TAG VERTICAL LINE
E007D TAG RIGHT CURLY BRACKET
E007E TAG TILDE
E007F CANCEL TAG
E0100 VARIATION SELECTOR-17
E0101 VARIATION SELECTOR-18
E0102 VARIATION SELECTOR-19
E0103 VARIATION SELECTOR-20
E0104 VARIATION SELECTOR-21
E0105 VARIATION SELECTOR-22
E0106 VARIATION SELECTOR-23
E0107 VARIATION SELECTOR-24
E0108 VARIATION SELECTOR-25
E0109 VARIATION SELECTOR-26
E010A VARIATION SELECTOR-27
E010B VARIATION SELECTOR-28
E010C VARIATION SELECTOR-29
E010D VARIATION SELECTOR-30
E010E VARIATION SELECTOR-31
E010F VARIATION SELECTOR-32
E0110 VARIATION SELECTOR-33
E0111 VARIATION SELECTOR-34
E0112 VARIATION SELECTOR-35
E0113 VARIATION SELECTOR-36
E0114 VARIATION SELECTOR-37
E0115 VARIATION SELECTOR-38
E0116 VARIATION SELECTOR-39
E0117 VARIATION SELECTOR-40
E0118 VARIATION SELECTOR-41
E0119 VARIATION SELECTOR-42
E011A VARIATION SELECTOR-43
E011B VARIATION SELECTOR-44
E011C VARIATION SELECTOR-45
E011D VARIATION SELECTOR-46
E011E VARIATION SELECTOR-47
E011F VARIATION SELECTOR-48
E0120 VARIATION SELECTOR-49
E0121 VARIATION SELECTOR-50
E0122 VARIATION SELECTOR-51
E0123 VARIATION SELECTOR-52
E0124 VARIATION SELECTOR-53
E0125 VARIATION SELECTOR-54
E0126 VARIATION SELECTOR-55
E0127 VARIATION SELECTOR-56
E0128 VARIATION SELECTOR-57
E0129 VARIATION SELECTOR-58
E012A VARIATION SELECTOR-59
E012B VARIATION SELECTOR-60
E012C VARIATION SELECTOR-61
E012D VARIATION SELECTOR-62
E012E VARIATION SELECTOR-63
E012F VARIATION SELECTOR-64
E0130 VARIATION SELECTOR-65
E0131 VARIATION SELECTOR-66
E0132 VARIATION SELECTOR-67
E0133 VARIATION SELECTOR-68
E0134 VARIATION SELECTOR-69
E0135 VARIATION SELECTOR-70
E0136 VARIATION SELECTOR-71
E0137 VARIATION SELECTOR-72
E0138 VARIATION SELECTOR-73
E0139 VARIATION SELECTOR-74
E013A VARIATION SELECTOR-75
E013B VARIATION SELECTOR-76
E013C VARIATION SELECTOR-77
E013D VARIATION SELECTOR-78
E013E VARIATION SELECTOR-79
E013F VARIATION SELECTOR-80
E0140 VARIATION SELECTOR-81
E0141 VARIATION SELECTOR-82
E0142 VARIATION SELECTOR-83
E0143 VARIATION SELECTOR-84
E0144 VARIATION SELECTOR-85
E0145 VARIATION SELECTOR-86
E0146 VARIATION SELECTOR-87
E0147 VARIATION SELECTOR-88
E0148 VARIATION SELECTOR-89
E0149 VARIATION SELECTOR-90
E014A VARIATION SELECTOR-91
E014B VARIATION SELECTOR-92
E014C VARIATION SELECTOR-93
E014D VARIATION SELECTOR-94
E014E VARIATION SELECTOR-95
E014F VARIATION SELECTOR-96
E0150 VARIATION SELECTOR-97
E0151 VARIATION SELECTOR-98
E0152 VARIATION SELECTOR-99
E0153 VARIATION SELECTOR-100
E0154 VARIATION SELECTOR-101
E0155 VARIATION SELECTOR-102
E0156 VARIATION SELECTOR-103
E0157 VARIATION SELECTOR-104
E0158 VARIATION SELECTOR-105
E0159 VARIATION SELECTOR-106
E015A VARIATION SELECTOR-107
E015B VARIATION SELECTOR-108
E015C VARIATION SELECTOR-109
E015D VARIATION SELECTOR-110
E015E VARIATION SELECTOR-111
E015F VARIATION SELECTOR-112
E0160 VARIATION SELECTOR-113
E0161 VARIATION SELECTOR-114
E0162 VARIATION SELECTOR-115
E0163 VARIATION SELECTOR-116
E0164 VARIATION SELECTOR-117
E0165 VARIATION SELECTOR-118
E0166 VARIATION SELECTOR-119
E0167 VARIATION SELECTOR-120
E0168 VARIATION SELECTOR-121
E0169 VARIATION SELECTOR-122
E016A VARIATION SELECTOR-123
E016B VARIATION SELECTOR-124
E016C VARIATION SELECTOR-125
E016D VARIATION SELECTOR-126
E016E VARIATION SELECTOR-127
E016F VARIATION SELECTOR-128
E0170 VARIATION SELECTOR-129
E0171 VARIATION SELECTOR-130
E0172 VARIATION SELECTOR-131
E0173 VARIATION SELECTOR-132
E0174 VARIATION SELECTOR-133
E0175 VARIATION SELECTOR-134
E0176 VARIATION SELECTOR-135
E0177 VARIATION SELECTOR-136
E0178 VARIATION SELECTOR-137
E0179 VARIATION SELECTOR-138
E017A VARIATION SELECTOR-139
E017B VARIATION SELECTOR-140
E017C VARIATION SELECTOR-141
E017D VARIATION SELECTOR-142
E017E VARIATION SELECTOR-143
E017F VARIATION SELECTOR-144
E0180 VARIATION SELECTOR-145
E0181 VARIATION SELECTOR-146
E0182 VARIATION SELECTOR-147
E0183 VARIATION SELECTOR-148
E0184 VARIATION SELECTOR-149
E0185 VARIATION SELECTOR-150
E0186 VARIATION SELECTOR-151
E0187 VARIATION SELECTOR-152
E0188 VARIATION SELECTOR-153
E0189 VARIATION SELECTOR-154
E018A VARIATION SELECTOR-155
E018B VARIATION SELECTOR-156
E018C VARIATION SELECTOR-157
E018D VARIATION SELECTOR-158
E018E VARIATION SELECTOR-159
E018F VARIATION SELECTOR-160
E0190 VARIATION SELECTOR-161
E0191 VARIATION SELECTOR-162
E0192 VARIATION SELECTOR-163
E0193 VARIATION SELECTOR-164
E0194 VARIATION SELECTOR-165
E0195 VARIATION SELECTOR-166
E0196 VARIATION SELECTOR-167
E0197 VARIATION SELECTOR-168
E0198 VARIATION SELECTOR-169
E0199 VARIATION SELECTOR-170
E019A VARIATION SELECTOR-171
E019B VARIATION SELECTOR-172
E019C VARIATION SELECTOR-173
E019D VARIATION SELECTOR-174
E019E VARIATION SELECTOR-175
E019F VARIATION SELECTOR-176
E01A0 VARIATION SELECTOR-177
E01A1 VARIATION SELECTOR-178
E01A2 VARIATION SELECTOR-179
E01A3 VARIATION SELECTOR-180
E01A4 VARIATION SELECTOR-181
E01A5 VARIATION SELECTOR-182
E01A6 VARIATION SELECTOR-183
E01A7 VARIATION SELECTOR-184
E01A8 VARIATION SELECTOR-185
E01A9 VARIATION SELECTOR-186
E01AA VARIATION SELECTOR-187
E01AB VARIATION SELECTOR-188
E01AC VARIATION SELECTOR-189
E01AD VARIATION SELECTOR-190
E01AE VARIATION SELECTOR-191
E01AF VARIATION SELECTOR-192
E01B0 VARIATION SELECTOR-193
E01B1 VARIATION SELECTOR-194
E01B2 VARIATION SELECTOR-195
E01B3 VARIATION SELECTOR-196
E01B4 VARIATION SELECTOR-197
E01B5 VARIATION SELECTOR-198
E01B6 VARIATION SELECTOR-199
E01B7 VARIATION SELECTOR-200
E01B8 VARIATION SELECTOR-201
E01B9 VARIATION SELECTOR-202
E01BA VARIATION SELECTOR-203
E01BB VARIATION SELECTOR-204
E01BC VARIATION SELECTOR-205
E01BD VARIATION SELECTOR-206
E01BE VARIATION SELECTOR-207
E01BF VARIATION SELECTOR-208
E01C0 VARIATION SELECTOR-209
E01C1 VARIATION SELECTOR-210
E01C2 VARIATION SELECTOR-211
E01C3 VARIATION SELECTOR-212
E01C4 VARIATION SELECTOR-213
E01C5 VARIATION SELECTOR-214
E01C6 VARIATION SELECTOR-215
E01C7 VARIATION SELECTOR-216
E01C8 VARIATION SELECTOR-217
E01C9 VARIATION SELECTOR-218
E01CA VARIATION SELECTOR-219
E01CB VARIATION SELECTOR-220
E01CC VARIATION SELECTOR-221
E01CD VARIATION SELECTOR-222
E01CE VARIATION SELECTOR-223
E01CF VARIATION SELECTOR-224
E01D0 VARIATION SELECTOR-225
E01D1 VARIATION SELECTOR-226
E01D2 VARIATION SELECTOR-227
E01D3 VARIATION SELECTOR-228
E01D4 VARIATION SELECTOR-229
E01D5 VARIATION SELECTOR-230
E01D6 VARIATION SELECTOR-231
E01D7 VARIATION SELECTOR-232
E01D8 VARIATION SELECTOR-233
E01D9 VARIATION SELECTOR-234
E01DA VARIATION SELECTOR-235
E01DB VARIATION SELECTOR-236
E01DC VARIATION SELECTOR-237
E01DD VARIATION SELECTOR-238
E01DE VARIATION SELECTOR-239
E01DF VARIATION SELECTOR-240
E01E0 VARIATION SELECTOR-241
E01E1 VARIATION SELECTOR-242
E01E2 VARIATION SELECTOR-243
E01E3 VARIATION SELECTOR-244
E01E4 VARIATION SELECTOR-245
E01E5 VARIATION SELECTOR-246
E01E6 VARIATION SELECTOR-247
E01E7 VARIATION SELECTOR-248
E01E8 VARIATION SELECTOR-249
E01E9 VARIATION SELECTOR-250
E01EA VARIATION SELECTOR-251
E01EB VARIATION SELECTOR-252
E01EC VARIATION SELECTOR-253
E01ED VARIATION SELECTOR-254
E01EE VARIATION SELECTOR-255
E01EF VARIATION SELECTOR-256
F0000 <Plane 15 Private Use, First>
FFFFD <Plane 15 Private Use, Last>
100000 <Plane 16 Private Use, First>
10FFFD <Plane 16 Private Use, Last>
