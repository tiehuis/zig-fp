// Generate compact zig tables.
//
// - store exact anchor entries every block_size exponents
// - reconstruct offset r inside a block by:
//     prod  = anchor_mantissa * 10^r
//     shift = bitlen(prod) - 128
//     mant  = ceil(prod >> shift)
//     be   -= shift
//     mant += tiny correction
//
// block_size must be < 10^19 to avoid overflow.
//
//go:build ignore

package main

import (
	"bytes"
	"fmt"
	"log"
	"math/big"
	"os"
)

const (
	minExp = -348
	maxExp = 347
)

var blockSizes = []int{16}

// 2-bit correction alphabets to try.
// Stored value 0..3 maps through one of these tables.
var corrAlphabets = [][]int64{
	{-1, 0, 1, 2},
	{-2, -1, 0, 1},
	{0, 1, 2, 3},
	{-3, -2, -1, 0},
}

type pmHiLo struct {
	Hi uint64
	Lo uint64
}

type denseEntry struct {
	E  int
	M  pmHiLo
	Be int
}

type anchorEntry struct {
	E  int
	M  pmHiLo
	Be int
}

type scheme struct {
	BlockSize    int
	CorrAlphabet [4]int8
	Anchors      []anchorEntry
	Small10      []uint64
	Corr         []uint8 // one 2-bit code per table entry; anchors use 0
}

func main() {
	dense := generateDense()

	var best *scheme
	for _, bs := range blockSizes {
		for _, alpha := range corrAlphabets {
			s, ok := tryScheme(dense, bs, alpha)
			if ok {
				best = s
				log.Printf("found exact scheme: block=%d corr=%v anchors=%d", bs, alpha, len(s.Anchors))
				break
			}
		}
		if best != nil {
			break
		}
	}

	if best == nil {
		log.Fatal("no exact scheme found; try smaller block sizes or a wider correction alphabet")
	}

	if err := emitZig("pow10compact.zig", best); err != nil {
		log.Fatal(err)
	}
}

func generateDense() []denseEntry {
	var (
		one = big.NewInt(1)
		ten = big.NewInt(10)

		b1p64  = new(big.Int).Lsh(one, 64)
		b1p128 = new(big.Int).Lsh(one, 128)

		r2     = big.NewRat(2, 1)
		r1p128 = new(big.Rat).SetInt(b1p128)
	)

	var out []denseEntry
	for e := int64(minExp); e <= maxExp; e++ {
		var r *big.Rat
		if e >= 0 {
			r = new(big.Rat).SetInt(new(big.Int).Exp(ten, big.NewInt(e), nil))
		} else {
			r = new(big.Rat).SetFrac(one, new(big.Int).Exp(ten, big.NewInt(-e), nil))
		}

		be := 0
		for r.Cmp(r1p128) < 0 {
			r.Mul(r, r2)
			be++
		}
		for r.Cmp(r1p128) >= 0 {
			r.Quo(r, r2)
			be--
		}

		d := new(big.Int).Div(r.Num(), r.Denom())
		hi, lo := new(big.Int).DivMod(d, b1p64, new(big.Int))
		uhi := hi.Uint64()
		ulo := lo.Uint64()
		if !r.IsInt() {
			ulo++
			if ulo == 0 {
				uhi++
			}
		}
		if ulo != 0 {
			uhi++
			ulo = -ulo
		}

		out = append(out, denseEntry{
			E:  int(e),
			M:  pmHiLo{uhi, ulo},
			Be: be,
		})
	}
	return out
}

func tryScheme(dense []denseEntry, blockSize int, alpha []int64) (*scheme, bool) {
	var corrAlpha [4]int8
	for i := 0; i < 4; i++ {
		corrAlpha[i] = int8(alpha[i])
	}

	numBlocks := (len(dense) + blockSize - 1) / blockSize
	anchors := make([]anchorEntry, numBlocks)
	for b := 0; b < numBlocks; b++ {
		i := b * blockSize
		anchors[b] = anchorEntry{
			E:  dense[i].E,
			M:  dense[i].M,
			Be: dense[i].Be,
		}
	}

	small10 := make([]uint64, blockSize)
	small10[0] = 1
	for i := 1; i < blockSize; i++ {
		x := new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(i)), nil)
		if !x.IsUint64() {
			return nil, false
		}
		small10[i] = x.Uint64()
	}

	corr := make([]uint8, len(dense))

	for b := 0; b < numBlocks; b++ {
		base := b * blockSize
		if base >= len(dense) {
			break
		}

		anchorM := decodePM(anchors[b].M)
		anchorBe := anchors[b].Be
		corr[base] = 0

		for j := 1; j < blockSize; j++ {
			i := base + j
			if i >= len(dense) {
				break
			}

			nextM, nextBe := directStep(anchorM, anchorBe, small10[j])

			found := false
			for code := uint8(0); code < 4; code++ {
				candM := new(big.Int).Add(nextM, big.NewInt(int64(corrAlpha[code])))
				candBe := nextBe

				candM, candBe = renorm128(candM, candBe)

				if encodePM(candM) == dense[i].M && candBe == dense[i].Be {
					corr[i] = code
					found = true
					break
				}
			}
			if !found {
				return nil, false
			}
		}
	}

	return &scheme{
		BlockSize:    blockSize,
		CorrAlphabet: corrAlpha,
		Anchors:      anchors,
		Small10:      small10,
		Corr:         corr,
	}, true
}

func directStep(anchorM *big.Int, anchorBe int, mul10 uint64) (*big.Int, int) {
	prod := new(big.Int).Mul(anchorM, new(big.Int).SetUint64(mul10))
	shift := prod.BitLen() - 128
	if shift < 0 {
		panic("unexpected negative shift")
	}
	prod = ceilRsh(prod, uint(shift))
	be := anchorBe - shift
	return prod, be
}

func renorm128(m *big.Int, be int) (*big.Int, int) {
	for m.BitLen() < 128 {
		m.Lsh(m, 1)
		be++
	}
	for m.BitLen() > 128 {
		m = ceilRsh(m, 1)
		be--
	}
	return m, be
}

func decodePM(m pmHiLo) *big.Int {
	hi := new(big.Int).SetUint64(m.Hi)
	hi.Lsh(hi, 64)
	lo := new(big.Int).SetUint64(m.Lo)
	return hi.Sub(hi, lo)
}

func encodePM(m *big.Int) pmHiLo {
	var (
		one   = big.NewInt(1)
		mask  = new(big.Int).Sub(new(big.Int).Lsh(one, 64), one)
		hiBig = new(big.Int).Rsh(new(big.Int).Set(m), 64)
		loBig = new(big.Int).And(new(big.Int).Set(m), mask)
	)

	uhi := hiBig.Uint64()
	ulo := loBig.Uint64()

	if ulo != 0 {
		uhi++
		ulo = -ulo
	}
	return pmHiLo{uhi, ulo}
}

func ceilRsh(x *big.Int, n uint) *big.Int {
	if n == 0 {
		return new(big.Int).Set(x)
	}
	one := big.NewInt(1)
	add := new(big.Int).Lsh(one, n)
	add.Sub(add, one)
	y := new(big.Int).Add(x, add)
	return y.Rsh(y, n)
}

func emitZig(path string, s *scheme) error {
	var out bytes.Buffer

	packedPerWord := 16 // 16 x 2-bit entries per u32
	numCorrWords := (len(s.Corr) + packedPerWord - 1) / packedPerWord
	corrWords := make([]uint32, numCorrWords)
	for i, c := range s.Corr {
		word := i / packedPerWord
		shift := (i % packedPerWord) * 2
		corrWords[word] |= uint32(c) << shift
	}

	fmt.Fprintf(&out, "// Code generated by go run pow10gen_zig_compact.go.\n\n")
	fmt.Fprintf(&out, "const std = @import(\"std\");\n\n")

	fmt.Fprintf(&out, "pub const pow10_min: i32 = %d;\n", minExp)
	fmt.Fprintf(&out, "pub const pow10_max: i32 = %d;\n", maxExp)
	fmt.Fprintf(&out, "pub const pow10_block_size: usize = %d;\n\n", s.BlockSize)

	fmt.Fprintf(&out, "pub const pow10_small10 = [_]u64{\n")
	for i, v := range s.Small10 {
		fmt.Fprintf(&out, "    0x%016x, // 10^%d\n", v, i)
	}
	fmt.Fprintf(&out, "};\n\n")

	fmt.Fprintf(&out, "pub const pow10_corr_map = [4]i8{ %d, %d, %d, %d };\n\n",
		s.CorrAlphabet[0], s.CorrAlphabet[1], s.CorrAlphabet[2], s.CorrAlphabet[3])

	fmt.Fprintf(&out, "pub const pow10_anchor = [_]struct { hi: u64, lo: u64, be: i16 }{\n")
	for _, a := range s.Anchors {
		fmt.Fprintf(&out, "    .{ .hi = 0x%016x, .lo = 0x%016x, .be = %d }, // 1e%d\n", a.M.Hi, a.M.Lo, a.Be, a.E)
	}
	fmt.Fprintf(&out, "};\n\n")

	fmt.Fprintf(&out, "pub const pow10_corr = [_]u32{\n")
	for _, w := range corrWords {
		fmt.Fprintf(&out, "    0x%08x,\n", w)
	}
	fmt.Fprintf(&out, "};\n")

	fmt.Fprintf(&out, zigLoader)

	return os.WriteFile(path, out.Bytes(), 0o666)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

const zigLoader = `
pub fn pow10ScaledCompact(e: i32) [2]u64 {
    std.debug.assert(pow10_min <= e and e <= pow10_max);

    const i: usize = @intCast(e - pow10_min);
    const base = i / pow10_block_size;
    const off = i %% pow10_block_size;

    const a = pow10_anchor[base];
    if (off == 0) return .{ a.hi, a.lo };

    // compute value from base offset
    const anchor_m: u128 = (@as(u128, a.hi) << 64) - @as(u128, a.lo);
    const prod: u256 = @as(u256, anchor_m) * @as(u256, pow10_small10[off]);
    const shift: u8 = @intCast((256 - @clz(prod)) - 128);

    // scale 256-bit down to 128-bit, rounding up
    var m: u128 = if (shift == 0)
        @truncate(prod)
    else blk: {
        const add = (@as(u256, 1) << @intCast(shift)) - 1;
        break :blk @truncate((prod + add) >> @intCast(shift));
    };

    var be: i32 = a.be - @as(i32, @intCast(shift));

    // compute and apply correct offset if needed
    const corr_word = pow10_corr[i / 16];
    const corr_shift: u5 = @intCast((i %% 16) * 2);
    const code: i8 = @intCast((corr_word >> corr_shift) & 0x3);
    const adj = code - 2; // map [0..4) -> [-2..2)

    if (adj != 0) {
        if (adj > 0) {
            m +%%= @as(u128, @intCast(adj));
        } else {
            m -%%= @as(u128, @intCast(-adj));
        }

        // normalize so top-bit is always set
        std.debug.assert(m != 0);
        const lz: u7 = @intCast(@clz(m));
        m <<= lz;
        be += @as(i32, lz);
    }

    // encode in expected format
    var hi: u64 = @truncate(m >> 64);
    var lo: u64 = @truncate(m);
    if (lo != 0) {
        hi +%%= 1;
        lo = 0 -%% lo;
    }
    return .{ hi, lo };
}
`
