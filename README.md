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