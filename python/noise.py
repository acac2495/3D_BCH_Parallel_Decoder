import numpy as np
from math import erfc, sqrt
from cubedef import cube_to_hex
from display import full_datapath_3d_viz

N = 15

def q_func(x):
    return 0.5 * erfc(x / sqrt(2))

def awgn_ber(ebn0_db, rate=1.0):
    """Raw (hard-decision) bit error probability for BPSK over AWGN."""
    ebn0 = 10 ** (ebn0_db / 10)
    return q_func(sqrt(2 * rate * ebn0))

def awgn_error_cube(ebn0_db, rate=1.0, rng=None, return_rx=False):
    """All-zero codeword -> BPSK (bit 0 -> +1, bit 1 -> -1) -> AWGN -> hard decision.
    The 1 bits of the result are the error cube. rate = k/n of the *3-D* code (1.0 means
    ebn0_db is really Es/N0)."""
    rng = np.random.default_rng() if rng is None else rng
    sigma = sqrt(1.0 / (2 * rate * 10 ** (ebn0_db / 10)))
    rx = 1.0 + sigma * rng.standard_normal((N, N, N))     # tx is all +1
    err = (rx < 0).astype(np.uint8)
    return (err, rx) if return_rx else err

def fixed_weight_cube(k, rng=None):
    """Exactly k errors at uniformly random positions."""
    rng = np.random.default_rng() if rng is None else rng
    cube = np.zeros(N**3, dtype=np.uint8)
    cube[rng.choice(N**3, size=k, replace=False)] = 1
    return cube.reshape(N, N, N)

def burst_error_cube(n_bursts, max_dim=(2, 4), fill=1.0, rng=None, base=None):
    """Random box-shaped bursts. Each box has side lengths drawn from 1..max_dim in a random
    axis order, so some bursts are fixable in one orientation and not in another.
    fill < 1 punches random holes in the boxes."""
    rng = np.random.default_rng() if rng is None else rng
    cube = np.zeros((N, N, N), dtype=np.uint8) if base is None else base.copy()
    for _ in range(n_bursts):
        dims = rng.integers(1, np.array(max_dim) + 1)
        dims = rng.permutation(np.array([dims[0], dims[1], rng.integers(1, max_dim[1] + 1)]))
        start = [rng.integers(0, N - d + 1) for d in dims]
        box = tuple(slice(s, s + d) for s, d in zip(start, dims))
        mask = rng.random(tuple(dims)) < fill
        cube[box] |= mask.astype(np.uint8)
    return cube

def awgn_plus_bursts(ebn0_db, n_bursts, rate=1.0, max_dim=(2, 4), rng=None):
    """Background AWGN noise with a few box bursts on top (OR-ed in)."""
    rng = np.random.default_rng() if rng is None else rng
    return burst_error_cube(n_bursts, max_dim, rng=rng, base=awgn_error_cube(ebn0_db, rate, rng))

import contextlib, io
rng = np.random.default_rng(2026)

vectors = [
    ("fixed k=1",          fixed_weight_cube(1,  rng)),
    ("fixed k=5",          fixed_weight_cube(5,  rng)),
    ("fixed k=20",         fixed_weight_cube(20, rng)),
    ("fixed k=40",         fixed_weight_cube(40, rng)),
    ("awgn 8 dB",          awgn_error_cube(8, rng=rng)),
    ("awgn 6 dB",          awgn_error_cube(6, rng=rng)),
    ("1 burst",            burst_error_cube(1, rng=rng)),
    ("3 bursts",           burst_error_cube(3, rng=rng)),
    ("3 bursts, fill 0.6", burst_error_cube(3, fill=0.6, rng=rng)),
    ("awgn 8 dB + 2 bursts", burst_error_cube(2, rng=rng, base=awgn_error_cube(8, rng=rng))),
]

vector = [
    ("fixed k=20",         fixed_weight_cube(20, rng)),
]

cube = fixed_weight_cube(20, rng)
full_datapath_3d_viz(cube, MAX=5, slices=True)

with open("cube_check.hex", "w") as f:
    f.write(cube_to_hex(cube) + "\n")