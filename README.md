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
 - [ ] underscore support

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

## Performance

Comparisons against current std implemenation (ryu).

```
# precision = null (shortest)

$ zig build perf -Doptimize=ReleaseFast -- --seed=0
# mode=scientific precision=null seed=0x0 accumulator=0xf438ef51bb6f4f0c22346
  pf: format: 23.26ns, parse: 22.61ns
 std: format: 25.50ns, parse: 23.28ns

$ zig build perf -Doptimize=ReleaseSafe -- --seed=0
# mode=scientific precision=null seed=0x0 accumulator=0xf438ef51bb6f4f0c22346
  pf: format: 33.24ns, parse: 30.17ns
 std: format: 32.41ns, parse: 34.40ns

$ zig build perf -Doptimize=ReleaseSmall -- --seed=0
# mode=scientific precision=null seed=0x0 accumulator=0xf438ef51bb6f4f0c22346
  pf: format: 35.39ns, parse: 31.16ns
 std: format: 45.40ns, parse: 53.78ns

$ zig build perf -Doptimize=Debug -- --seed=0
# mode=scientific precision=null seed=0x0 accumulator=0xf438ef51bb6f4f0c22346
  pf: format: 274.40ns, parse: 242.40ns
 std: format: 309.52ns, parse: 509.21ns
```

```
# precision = 10 (fixed)

$ zig build perf -Doptimize=ReleaseFast -- --seed=0 --precision=10
# mode=scientific precision=10 seed=0x0 accumulator=0xf438ef51bb6f4fb662b52
  pf: format: 21.29ns, parse: 23.46ns
 std: format: 33.69ns, parse: 22.76ns

$ zig build perf -Doptimize=ReleaseSafe -- --seed=0 --precision=10
# mode=scientific precision=10 seed=0x0 accumulator=0xf438ef51bb6f4fb662b52
  pf: format: 25.60ns, parse: 23.41ns
 std: format: 43.31ns, parse: 30.88ns

$ zig build perf -Doptimize=ReleaseSmall -- --seed=0 --precision=10
# mode=scientific precision=10 seed=0x0 accumulator=0xf438ef51bb6f4fb662b52
  pf: format: 25.78ns, parse: 24.17ns
 std: format: 82.85ns, parse: 46.77ns

$ zig build perf -Doptimize=Debug -- --seed=0 --precision=10
# mode=scientific precision=10 seed=0x0 accumulator=0xf438ef51bb6f4fb662b52
  pf: format: 198.78ns, parse: 214.04ns
 std: format: 330.89ns, parse: 438.64ns
```

## Size

### ReleaseFast

```
$ zig build size-fp -Doptimize=ReleaseFast
    FILE SIZE        VM SIZE
 --------------  --------------
  29.3%  27.4Ki   0.0%       0    .rela.debug_info
  18.0%  16.8Ki   0.0%       0    .debug_loc
  12.5%  11.7Ki   0.0%       0    .debug_info
  11.9%  11.1Ki  65.5%  11.0Ki    .rodata
   7.6%  7.05Ki   0.0%       0    .debug_str
   5.7%  5.36Ki  31.4%  5.29Ki    .text
   4.3%  4.00Ki   0.0%       0    .debug_line
   2.8%  2.59Ki   0.0%       0    .debug_ranges
   1.5%  1.42Ki   0.0%       0    .debug_pubnames
   1.4%  1.27Ki   0.0%       0    .debug_pubtypes
   1.0%     941   0.0%       0    .debug_abbrev
   0.9%     832   0.0%       0    .symtab
   0.7%     712   0.0%       0    .rela.text
   0.6%     556   0.0%       0    .strtab
   0.4%     420   0.1%      16    [6 Others]
   0.3%     320   1.5%     256    .eh_frame
   0.3%     277   1.2%     213    .rodata.str1.1
   0.3%     258   0.0%       0    [AR Headers]
   0.2%     192   0.0%       0    [ELF Headers]
   0.2%     184   0.0%       0    .rela.eh_frame
   0.1%     112   0.3%      48    .rodata.cst16
 100.0%  93.3Ki 100.0%  16.8Ki    TOTAL
```

```
$ zig build size-fp -Doptimize=ReleaseFast -Duse-compact-tables=true
    FILE SIZE        VM SIZE
 --------------  --------------
  31.2%  29.4Ki   0.0%       0    .rela.debug_info
  23.3%  22.0Ki   0.0%       0    .debug_loc
  13.3%  12.5Ki   0.0%       0    .debug_info
   7.8%  7.30Ki   0.0%       0    .debug_str
   7.5%  7.04Ki  82.0%  6.98Ki    .text
   4.9%  4.57Ki   0.0%       0    .debug_line
   2.8%  2.59Ki   0.0%       0    .debug_ranges
   1.6%  1.48Ki   0.0%       0    .debug_pubnames
   1.5%  1.37Ki   0.0%       0    .debug_pubtypes
   1.1%  1.08Ki  11.9%  1.02Ki    .rodata
   1.0%     932   0.0%       0    .debug_abbrev
   0.9%     856   0.0%       0    .rela.text
   0.9%     856   0.0%       0    .symtab
   0.6%     568   0.0%       0    .strtab
   0.4%     414   0.2%      16    [6 Others]
   0.3%     320   2.9%     256    .eh_frame
   0.3%     277   2.4%     213    .rodata.str1.1
   0.3%     258   0.0%       0    [AR Headers]
   0.2%     192   0.0%       0    [ELF Headers]
   0.2%     184   0.0%       0    .rela.eh_frame
   0.1%     112   0.6%      48    .rodata.cst16
 100.0%  94.1Ki 100.0%  8.52Ki    TOTAL
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
$ zig build size-fp -Doptimize=ReleaseSmall
    FILE SIZE        VM SIZE
 --------------  --------------
  60.3%  11.1Ki  69.6%  11.0Ki    .rodata
  22.7%  4.18Ki  26.0%  4.12Ki    .text
   3.9%     736   0.0%       0    .rela.text
   3.1%     584   2.8%     456    .eh_frame
   2.0%     376   0.0%       0    .symtab
   1.7%     328   0.0%       0    .rela.eh_frame
   1.5%     286   1.4%     222    .rodata.str1.1
   1.4%     258   0.0%       0    [AR Headers]
   1.4%     257   0.0%       0    .strtab
   0.7%     128   0.0%       0    [ELF Headers]
   0.5%      96   0.2%      32    .rodata.cst16
   0.4%      80   0.1%      16    .rodata.cst8
   0.3%      54   0.0%       0    [AR Symbol Table]
   0.1%      14   0.0%       0    [Unmapped]
 100.0%  18.4Ki 100.0%  15.9Ki    TOTAL
```

```
$ zig build size-fp -Doptimize=ReleaseSmall -Duse-compact-tables=true
    FILE SIZE        VM SIZE
 --------------  --------------
  51.3%  4.75Ki  72.7%  4.69Ki    .text
  11.6%  1.08Ki  15.7%  1.02Ki    .rodata
   9.8%     928   0.0%       0    .rela.text
   6.6%     624   7.5%     496    .eh_frame
   4.5%     424   0.0%       0    .symtab
   3.7%     352   0.0%       0    .rela.eh_frame
   3.0%     286   3.4%     222    .rodata.str1.1
   2.9%     277   0.0%       0    .strtab
   2.7%     258   0.0%       0    [AR Headers]
   1.3%     128   0.0%       0    [ELF Headers]
   1.0%      96   0.5%      32    .rodata.cst16
   0.8%      80   0.2%      16    .rodata.cst8
   0.6%      54   0.0%       0    [AR Symbol Table]
   0.1%      12   0.0%       0    [Unmapped]
 100.0%  9.27Ki 100.0%  6.45Ki    TOTAL
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