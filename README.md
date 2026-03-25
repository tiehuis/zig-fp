zig implementation of the floating-point printing and parsing methods described
in https://research.swtch.com/fp.

## TODO

 - [ ] f128 backend support
 - [ ] performance improvements
 - [ ] genericize for different float types
 - [ ] underscore support
 - [ ] fix remaining edge cases for std compatibility

## Build

```
zig run perf.zig -O ReleaseFast
```

```
zig run fuzz.zig uscale.c -O ReleaseFast
```

## Performance

```
# precision = null (shortest)

$ zig run perf.zig -O ReleaseFast
acc: 0xf438ef51bb6f4f0c22346
  pf: format: 29.92ns, parse: 20.94ns
 std: format: 23.56ns, parse: 20.96ns

$ zig run perf.zig -O ReleaseSafe
acc: 0xf438ef51bb6f4f0c22346
  pf: format: 21.72ns, parse: 42.29ns
 std: format: 30.44ns, parse: 44.54ns

$ zig run perf.zig -O ReleaseSmall
acc: 0xf438ef51bb6f4f0c22346
  pf: format: 26.64ns, parse: 35.06ns
 std: format: 42.39ns, parse: 53.58ns

$ zig run perf.zig -O Debug
acc: 0xf438ef51bb6f4f0c22346
  pf: format: 256.36ns, parse: 242.68ns
 std: format: 300.32ns, parse: 505.41ns
```

```
# precision = 10 (fixed)

$ zig run perf.zig -O ReleaseFast
acc: 0xf438ef51bb6f4f63782f4
  pf: format: 19.06ns, parse: 19.37ns
 std: format: 32.60ns, parse: 20.43ns

$ zig run perf.zig -O ReleaseSafe
acc: 0xf438ef51bb6f4f63782f4
  pf: format: 20.07ns, parse: 36.54ns
 std: format: 35.35ns, parse: 41.87ns

$ zig run perf.zig -O ReleaseSmall
acc: 0xf438ef51bb6f4f63782f4
  pf: format: 23.42ns, parse: 27.83ns
 std: format: 66.17ns, parse: 45.32ns

$ zig run perf.zig -O Debug
acc: 0xf438ef51bb6f4f63782f4
  pf: format: 200.11ns, parse: 225.07ns
 std: format: 325.88ns, parse: 440.74ns
```

## Size

```
zig build-lib zig-fp-size.zig -target x86_64-linux -O ReleaseSmall
zig build-lib zig-std-size.zig -target x86_64-linux -O ReleaseSmall
```

```
$ bloaty zig-fp-size.a
    FILE SIZE        VM SIZE    
 --------------  -------------- 
  59.7%  11.1Ki  71.9%  11.0Ki    .rodata
  19.6%  3.64Ki  23.3%  3.58Ki    .text
   5.1%     976   0.0%       0    .rela.text
   3.6%     688   0.0%       0    .symtab
   3.1%     584   2.9%     456    .eh_frame
   2.3%     440   0.0%       0    .strtab
   1.7%     328   0.0%       0    .rela.eh_frame
   1.5%     286   1.4%     222    .rodata.str1.1
   1.3%     254   0.0%       0    [AR Headers]
   0.7%     128   0.4%      64    .rodata.cst16
   0.7%     128   0.0%       0    [ELF Headers]
   0.4%      80   0.1%      16    .rodata.cst8
   0.3%      54   0.0%       0    [AR Symbol Table]
   0.0%       8   0.0%       0    [Unmapped]
 100.0%  18.6Ki 100.0%  15.4Ki    TOTAL
```

```
$ bloaty zig-std-size.a
    FILE SIZE        VM SIZE    
 --------------  -------------- 
  33.2%  14.4Ki  46.7%  14.3Ki    .rodata
  22.1%  9.56Ki  31.0%  9.50Ki    .text
  13.4%  5.81Ki  18.7%  5.75Ki    .rodata.str1.1
   9.6%  4.16Ki   0.0%       0    .symtab
   7.1%  3.06Ki   0.0%       0    .rela.rodata
   6.5%  2.81Ki   0.0%       0    .strtab
   2.4%  1.02Ki   0.0%       0    .rela.text
   2.3%    1024   3.1%     960    .eh_frame
   1.5%     664   0.0%       0    .rela.eh_frame
   0.6%     256   0.0%       0    [AR Headers]
   0.4%     192   0.0%       0    [ELF Headers]
   0.3%     140   0.2%      76    .rodata.str4.4
   0.3%     112   0.2%      48    .rodata.cst16
   0.2%     104   0.1%      40    .rodata.cst8
   0.1%      54   0.0%       0    [AR Symbol Table]
   0.0%      20   0.0%       0    [Unmapped]
 100.0%  43.3Ki 100.0%  30.7Ki    TOTAL
```
