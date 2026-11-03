# A Parallel 3D BCH decoder implementation with Slice-Wise 2D BCH corrections

This project extends the pipelined **decoder** for two-dimensional
Bose–Chaudhuri–Hocquenghem (BCH) codes, built on the frequency-domain architecture of

> A. Mondal and S. S. Garani, "Efficient Hardware Architectures for 2-D BCH Codes in the Frequency Domain
> for Two-Dimensional Data Storage Applications," *IEEE Transactions on Magnetics*, vol. 57, no. 5, May 2021.
> [DOI: 10.1109/TMAG.2021.3060807](https://doi.org/10.1109/TMAG.2021.3060807)

into a decoder for **three-dimensional** data. A 15 × 15 × 15 binary cube is treated as a stack of
2D slices, and each slice is decoded with the 2D frequency-domain decoder. The cube is cut along
all three orientations (XY, XZ and YZ), so every bit is covered by one slice in each orientation
and errors that one orientation cannot correct can be resolved by another.

> A full implementation of the 2D BCH decoder that this project builds on can be found at
> [acac2495/2D-BCH-Codes](https://github.com/acac2495/2D-BCH-Codes).

## How it works

1. **Slice.** For the current orientation (`pass_idx` = XY, XZ or YZ), the cube is split into
   N = 15 slices of 15 × 15 bits.
2. **Decode in parallel.** N copies of the 2D decoder (`ccp_top`) run at the same time, one per
   slice. Each decoder computes the 2D syndromes in the frequency domain, finds the row and
   column error-locator polynomials with Berlekamp–Massey, recovers the remaining syndromes by
   recursive extension, and returns an error pattern through the inverse transform.
3. **Verify.** A slice correction is accepted only if the corrected slice has all-zero syndromes
   (`dffft_top` is reused as a syndrome checker). Otherwise the slice is left unchanged, so an
   undecodable slice cannot corrupt the cube.
4. **Write back.** The corrected slices are reassembled into the cube.
5. **Repeat.** The three orientations are applied in turn. A sweep that makes no correction means
   the cube is clean (`done_3d`); if the cube is still changing after `MAX_ITER` sweeps, the decoder
   stops with `fail_3d` set.

The design is parameterized by [`N = 15`, `M = 4` (GF(2⁴)), `T = 2`], and the control logic is a
small FSM around the slice mux, the 2D decoders, and the verification and write-back stages.