zig implementation of the floating-point printing and parsing methods described
in https://research.swtch.com/fp.

A few additional things this adds beyond just a zig port:
 - compact table support
 - more robust parsing
 - decimal output support

## TODO

 - [ ] f128 backend support
 - [ ] performance improvements
 - [ ] genericize for different float types
 - [x] underscore support

## Build

```
zig build perf -Doptimize=ReleaseFast
```

```
zig build fuzz -Doptimize=ReleaseFast
```

```
# requires bloaty installed
zig build size-fp -Doptimize=ReleaseSmall
zig build size-std -Doptimize=ReleaseSmall
```

### Test Fixed Samples

```
$ zig build perf -Doptimize=ReleaseFast -- --seed=0 '--sample=3.141592652589793238462643383279502884197169399375105' --zmij=true
# mode=scientific precision=null seed=0x0 iters=10000 accumulator=0xfa23acbdc0a4186800 sample=3.141592652589793e0
  pf: format: 14.02ns, parse: 16.09ns
 std: format: 20.24ns, parse: 13.07ns
zmij: format: 14.03ns
```

## Performance

Comparisons against current std implemenation (ryu) and [zmij](https://github.com/de-sh/zmij).

| *zmij only supports f64 scientific output*

```
# precision = null (shortest)

$ zig build perf -Doptimize=ReleaseFast -- --seed=0 --zmij=true
# mode=scientific precision=null seed=0x0 iters=10000 accumulator=0x1f357339e4ee5c3073c sample=null
  pf: format: 14.54ns, parse: 15.51ns
 std: format: 21.42ns, parse: 15.77ns
zmij: format: 14.08ns

$ zig build perf -Doptimize=ReleaseSafe -- --seed=0 --zmij=true
# mode=scientific precision=null seed=0x0 iters=10000 accumulator=0x1f357339e4ee5c3073c sample=null
  pf: format: 15.68ns, parse: 17.65ns
 std: format: 30.48ns, parse: 24.03ns
zmij: format: 16.14ns

$ zig build perf -Doptimize=ReleaseSmall -- --seed=0 --zmij=true
# mode=scientific precision=null seed=0x0 iters=10000 accumulator=0x1f357339e4ee5c3073c sample=null
  pf: format: 16.80ns, parse: 18.69ns
 std: format: 35.96ns, parse: 45.45ns
zmij: format: 16.23ns

$ zig build perf -Doptimize=Debug -- --seed=0 --zmij=true
# mode=scientific precision=null seed=0x0 iters=10000 accumulator=0x1f357339e4ee5c3073c sample=null
  pf: format: 188.99ns, parse: 193.22ns
 std: format: 214.47ns, parse: 422.66ns
zmij: format: 133.63ns
```

```
# precision = 10 (fixed)

$ zig build perf -Doptimize=ReleaseFast -- --seed=0 --precision=10
# mode=scientific precision=10 seed=0x0 iters=10000 accumulator=0x1f357339e4ee6365fc6 sample=null
  pf: format: 7.63ns, parse: 13.37ns
 std: format: 26.02ns, parse: 14.15ns

$ zig build perf -Doptimize=ReleaseSafe -- --seed=0 --precision=10
# mode=scientific precision=10 seed=0x0 iters=10000 accumulator=0x1f357339e4ee6365fc6 sample=null
  pf: format: 8.99ns, parse: 15.42ns
 std: format: 34.04ns, parse: 21.16ns

$ zig build perf -Doptimize=ReleaseSmall -- --seed=0 --precision=10
# mode=scientific precision=10 seed=0x0 iters=10000 accumulator=0x1f357339e4ee6365fc6 sample=null
  pf: format: 11.35ns, parse: 16.68ns
 std: format: 46.22ns, parse: 40.14ns

$ zig build perf -Doptimize=Debug -- --seed=0 --precision=10
# mode=scientific precision=10 seed=0x0 iters=10000 accumulator=0x1f357339e4ee6365fc6 sample=null
  pf: format: 127.21ns, parse: 176.92ns
 std: format: 227.01ns, parse: 372.34ns
```

## Size

### ReleaseFast

| *std includes hex-float formatting in std.Io.Writer instead of std.fmt so we exclude for a more direct comparison.*

```
$ zig build size-fp -Doptimize=ReleaseFast -Ddisable-hex-formatting=true
    FILE SIZE        VM SIZE
 --------------  --------------
  30.0%  29.8Ki   0.0%       0    .rela.debug_info
  16.9%  16.8Ki   0.0%       0    .debug_loc
  12.8%  12.7Ki   0.0%       0    .debug_info
  11.2%  11.1Ki  61.8%  11.0Ki    .rodata
   7.5%  7.41Ki   0.0%       0    .debug_str
   6.3%  6.31Ki  35.0%  6.25Ki    .text
   4.5%  4.52Ki   0.0%       0    .debug_line
   2.8%  2.80Ki   0.0%       0    .debug_ranges
   1.6%  1.63Ki   0.0%       0    .debug_pubnames
   1.3%  1.28Ki   0.0%       0    .debug_pubtypes
   0.9%     962   0.0%       0    .debug_abbrev
   0.9%     928   0.0%       0    .symtab
   0.8%     784   0.0%       0    .rela.text
   0.6%     646   0.0%       0    .strtab
   0.4%     414   0.1%      16    [6 Others]
   0.4%     384   1.7%     320    .eh_frame
   0.3%     291   1.2%     227    .rodata.str1.1
   0.3%     258   0.0%       0    [AR Headers]
   0.2%     232   0.0%       0    .rela.eh_frame
   0.2%     192   0.0%       0    [ELF Headers]
   0.1%      96   0.2%      32    .rodata.cst16
 100.0%  99.4Ki 100.0%  17.9Ki    TOTAL
```

```
$ zig build size-fp -Doptimize=ReleaseFast -Ddisable-hex-formatting=true -Duse-compact-tables=true
    FILE SIZE        VM SIZE
 --------------  --------------
  31.8%  31.6Ki   0.0%       0    .rela.debug_info
  21.7%  21.5Ki   0.0%       0    .debug_loc
  13.6%  13.5Ki   0.0%       0    .debug_info
   8.0%  7.98Ki  83.2%  7.92Ki    .text
   7.6%  7.59Ki   0.0%       0    .debug_str
   5.1%  5.06Ki   0.0%       0    .debug_line
   2.8%  2.78Ki   0.0%       0    .debug_ranges
   1.7%  1.69Ki   0.0%       0    .debug_pubnames
   1.3%  1.30Ki   0.0%       0    .debug_pubtypes
   1.1%  1.08Ki  10.7%  1.02Ki    .rodata
   0.9%     953   0.0%       0    .debug_abbrev
   0.9%     952   0.0%       0    .symtab
   0.9%     928   0.0%       0    .rela.text
   0.6%     658   0.0%       0    .strtab
   0.4%     417   0.2%      16    [6 Others]
   0.4%     384   3.3%     320    .eh_frame
   0.3%     291   2.3%     227    .rodata.str1.1
   0.3%     258   0.0%       0    [AR Headers]
   0.2%     232   0.0%       0    .rela.eh_frame
   0.2%     192   0.0%       0    [ELF Headers]
   0.1%      96   0.3%      32    .rodata.cst16
 100.0%  99.4Ki 100.0%  9.51Ki    TOTAL
```

```
$ zig build size-std -Doptimize=ReleaseFast
    FILE SIZE        VM SIZE
 --------------  --------------
  18.4%  41.0Ki   0.0%       0    .rela.debug_info
  17.8%  39.7Ki   0.0%       0    .debug_loc
  10.8%  24.1Ki  52.9%  24.0Ki    .rodata
   9.0%  20.1Ki   0.0%       0    .rela.debug_ranges
   8.6%  19.1Ki   0.0%       0    .debug_info
   6.0%  13.3Ki  29.1%  13.2Ki    .text
   5.4%  12.0Ki   0.0%       0    .debug_str
   4.8%  10.6Ki   0.0%       0    .debug_line
   4.0%  8.92Ki   0.0%       0    .debug_ranges
   3.5%  7.84Ki   0.0%       0    .rela.debug_loc
   2.7%  6.00Ki  13.1%  5.94Ki    .rodata.str1.1
   1.9%  4.14Ki   0.0%       0    .symtab
   1.4%  3.06Ki   0.0%       0    .rela.rodata
   1.2%  2.74Ki   0.0%       0    .debug_pubnames
   1.1%  2.43Ki   0.0%       0    .strtab
   0.8%  1.73Ki   3.7%  1.67Ki    .text.unlikely.
   0.7%  1.65Ki   0.0%       0    .debug_pubtypes
   0.7%  1.65Ki   0.2%      88    [11 Others]
   0.6%  1.30Ki   0.0%       0    .rela.text
   0.4%     907   0.0%       0    .debug_abbrev
   0.2%     560   1.1%     496    .eh_frame
 100.0%   222Ki 100.0%  45.4Ki    TOTAL
```

### ReleaseSmall

```
$ zig build size-fp -Doptimize=ReleaseSmall -Ddisable-hex-formatting=true
    FILE SIZE        VM SIZE
 --------------  --------------
  57.4%  11.1Ki  66.2%  11.0Ki    .rodata
  25.6%  4.94Ki  29.3%  4.87Ki    .text
   4.2%     832   0.0%       0    .rela.text
   3.1%     616   2.9%     488    .eh_frame
   1.9%     376   0.0%       0    .symtab
   1.8%     352   0.0%       0    .rela.eh_frame
   1.5%     300   1.4%     236    .rodata.str1.1
   1.3%     258   0.0%       0    [AR Headers]
   1.3%     257   0.0%       0    .strtab
   0.6%     128   0.0%       0    [ELF Headers]
   0.5%      96   0.2%      32    .rodata.cst16
   0.4%      80   0.1%      16    .rodata.cst8
   0.3%      54   0.0%       0    [AR Symbol Table]
   0.1%      12   0.0%       0    [Unmapped]
 100.0%  19.3Ki 100.0%  16.7Ki    TOTAL
```

```
$ zig build size-fp -Doptimize=ReleaseSmall -Ddisable-hex-formatting=true -Duse-compact-tables=true
    FILE SIZE        VM SIZE
 --------------  --------------
  54.3%  5.56Ki  75.2%  5.50Ki    .text
  10.5%  1.08Ki  13.9%  1.02Ki    .rodata
   9.8%    1024   0.0%       0    .rela.text
   6.3%     664   7.2%     536    .eh_frame
   4.0%     424   0.0%       0    .symtab
   3.6%     376   0.0%       0    .rela.eh_frame
   2.9%     300   3.1%     236    .rodata.str1.1
   2.6%     277   0.0%       0    .strtab
   2.5%     258   0.0%       0    [AR Headers]
   1.2%     128   0.0%       0    [ELF Headers]
   0.9%      96   0.4%      32    .rodata.cst16
   0.8%      80   0.2%      16    .rodata.cst8
   0.5%      54   0.0%       0    [AR Symbol Table]
   0.1%      13   0.0%       0    [Unmapped]
 100.0%  10.2Ki 100.0%  7.32Ki    TOTAL
```

```
$ zig build size-std -Doptimize=ReleaseSmall
    FILE SIZE        VM SIZE
 --------------  --------------
  38.7%  14.4Ki  46.7%  14.3Ki    .rodata
  25.7%  9.56Ki  31.0%  9.50Ki    .text
  15.6%  5.81Ki  18.7%  5.75Ki    .rodata.str1.1
   8.2%  3.06Ki   0.0%       0    .rela.rodata
   2.8%  1.02Ki   0.0%       0    .rela.text
   2.7%    1024   3.1%     960    .eh_frame
   1.7%     664   0.0%       0    .rela.eh_frame
   1.4%     544   0.0%       0    .symtab
   0.9%     336   0.0%       0    .strtab
   0.7%     260   0.0%       0    [AR Headers]
   0.5%     192   0.0%       0    [ELF Headers]
   0.4%     140   0.2%      76    .rodata.str4.4
   0.3%     112   0.2%      48    .rodata.cst16
   0.3%     104   0.1%      40    .rodata.cst8
   0.1%      54   0.0%       0    [AR Symbol Table]
   0.0%      17   0.0%       0    [Unmapped]
 100.0%  37.2Ki 100.0%  30.7Ki    TOTAL
```