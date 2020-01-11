# PMT
PMT - Parallel Multithreaded encoder/decoder
by 78372

Main Options:
PMT.exe e/d {Encoder} {Basic Options} Input Output
e/d represents encode/decode
input/output can be specified as "-" for stdin/stdout
{Encoder} must be present both for encoding and decoding

Basic Options:
-t#: Number of threads to use(Default: number of threads you have)
-t#p:  Percentage of threads to use
-b#: BlockSize(Encode only) (Default: 64m)

INI Options:
PMT.ini is required for encoder/decoder
The section name should be as the {Encoder}
The keys should be as below:
Encode = It should have the Encode Command Line
Decode = It should have the Decode Command Line
Infile = It should be the encode input file name for the {Encoder}. Default is p
mtinfile.tmp. It will be the output file for decoding
Outfile = It should be the encode output file name for the {Encoder}. Default is
 pmtoutfile.tmp. It will be the input file for decoding
You can not encode using PMT and decode directly using {Encoder} and vice versa
Write <stdin> or <stdout> in Encode or Decode to specify stdin/stdout
