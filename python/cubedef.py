
#Libraries

import numpy as np
import argparse
import itertools
import random

#Basic building block functions

ALPHA_POWERS = [8, 4, 2, 1, 12, 6, 3, 13, 10, 5, 14, 7, 15, 11, 9]  # a^0..a^14, MSB-first

EXP_STR = {0: "0"}
for idx, val in enumerate(ALPHA_POWERS):
    EXP_STR[val] = f"a^{idx}"

def alpha_pow(exp, n=15):
    return ALPHA_POWERS[exp % n]

def to_hex(val):
    return format(val, 'X')

#XOR array
def xor_array(c1, c2):
    c = [[0] * len(c1) for _ in range(len(c1))]
    for i in range(0, len(c1)):
        for j in range(0, len(c1[0])):
            c[i][j] = c1[i][j] ^ c2[i][j]
    return c

#Used Constants

N = 15
t = 2
m = 4

#Galois field operations

def gf_mul(a, b):
    if(a == 0 or b == 0):
        return 0
    p1 = ALPHA_POWERS.index(a)
    p2 = ALPHA_POWERS.index(b)
    return ALPHA_POWERS[(p1 + p2) % N]

def gf_pow(a, pow):
    if(a == 0):
        return 8
    p1 = ALPHA_POWERS.index(a)
    return ALPHA_POWERS[(p1 * pow) % N]

def gf_inv(a):
    if(a == 0):
        return 0
    p1 = ALPHA_POWERS.index(a)
    return ALPHA_POWERS[(N - p1) % N]

def alpha_pow(exp):
    return ALPHA_POWERS[exp % N]

#Discrete Finite Field Fourier Transform

def dffft_pt(c, j, jp):
    acc = 0
    for i in range(N):
        for ip in range(N):
            if(c[i][ip]):
                acc ^= alpha_pow(i * j + ip * jp)
    return acc

def dffft_2t(c):
    C = [[0] * (2*t) for _ in range(2*t)]
    for j in range(1, 2*t + 1):
        for jp in range(1, 2*t + 1):
            C[j-1][jp-1] = dffft_pt(c, j, jp)
    return C

def dffft_full(c):
    C = [[0] * N for _ in range(N)]
    for j in range(1, N + 1):
        for jp in range(1, N + 1):
            C[j-1][jp-1] = dffft_pt(c, j, jp)
    return C

#Inverse Discrete Finite Field Fourier Transform

def idffft_pt(C, i, ip):
    acc = 0
    for j in range(N):
        for jp in range(N):
            p1 = gf_inv(alpha_pow(i * j + ip * jp))
            acc ^= gf_mul(p1, C[j][jp])
    if(acc != 0):
        return 1
    else:
        return 0

def idffft_full(C):
    c = [[0] * N for _ in range(N)]
    for i in range(N):
        for ip in range(N):
            c[i][ip] = idffft_pt(C, i, ip)
    return c

#Printing aids

def print_grid(C):
    for row in C:
        for elem in row:
            print(EXP_STR[elem], " | " , end=" ")
        print("")

def print_bin(err):
    for row in err:
        print(row)

#Fixed Berlekamp Massey Engine

def BM_fixed(synds):
    sigma   = [0] * (t + 1);  sigma[0] = 8
    sigma_p = [0] * (t + 1);  sigma_p[1] = 8
    d_p = 8
    L = 0
    temp_reg = [0] * (t + 1)
    for i in range(2 * t):
        temp_reg = [synds[i]] + temp_reg[0:t]
        d_mu = temp_reg[0]
        for j in range(1, t + 1):
            d_mu ^= gf_mul(temp_reg[j], sigma[j])

        dmu_dpinv = gf_mul(d_mu, gf_inv(d_p))
        corr = [gf_mul(sigma_p[j], dmu_dpinv) for j in range(t + 1)]
        sigma_next = [sigma[j] ^ corr[j] for j in range(t + 1)]

        load_sigma = 1 if (d_mu != 0 and 2 * L <= i) else 0
        sigma_store = sigma[:] if load_sigma else sigma_p[:]
        sigma_p = [0] + sigma_store[0:t]
        sigma = sigma_next
        if load_sigma:
            d_p = d_mu
            L = i + 1 - L
    return sigma, L

#Polynomial and Root functions

def print_poly(sigma):
    powers = []
    for coeff in sigma:
        powers.append(EXP_STR[coeff])
    print(powers)

def print_roots(sigma):
    for i in ALPHA_POWERS:
        res = 8
        for j in range(1, t+1):
            pow = gf_pow(i, j)
            res ^= gf_mul(pow, sigma[j])
        if(res == 0):
            print(EXP_STR[i], end=" ")

def display_roots(roots):
    for root in roots:
        print(EXP_STR[root], end=" ")
    print("")

def get_rpos(sigma):
    rpos = []
    for i in ALPHA_POWERS:
        res = 8
        for j in range(1, t+1):
            pow = gf_pow(i, j)
            res ^= gf_mul(pow, sigma[j])
        if(res == 0):
            rpos.append(1)
        else:
            rpos.append(0)
    return rpos

def root_lookup(rpos):
    count = 0
    roots = []
    for i in range(len(rpos)):
        if(rpos[i] == 1):
            roots.append(ALPHA_POWERS[i])
            count += 1
        if(count == t):
            break
    return roots

def root_to_coeff(roots):
    if len(roots) >= 2:
        a1, a2 = roots[0], roots[1]
        prod = gf_mul(a1, a2)
        return [8, gf_mul(a1 ^ a2, gf_inv(prod)), gf_inv(prod)]
    if len(roots) == 1:
        return [8, gf_inv(roots[0]), 0]
    return [8, 0, 0]

#Recursive Extension basic functions

def RE_base(c, window):
    res = 0
    for i in range(1, t + 1):
        res ^= gf_mul(c[i], window[-i])
    return res

def RE_chain(c, S_init):
    window = list(S_init)
    out = []
    for _ in range(N - 2 * t):
        new = RE_base(c, window)
        out.append(new)
        window = window[1:] + [new]
    return out

#Recursive extension row and column wise

def extend_columns(S_2t, col_ccp_poly):
    S_full = [[0] * (2 * t) for _ in range(N)]
    for k in range(2*t):
        seq = [S_2t[j][k] for j in range(2*t)]
        seq_full = seq + RE_chain(col_ccp_poly, seq[-t:])
        for j in range(N):
            S_full[j][k] = seq_full[j]
    return S_full

def extend_rows(col_full, row_ccp_poly):
    S_full = []
    for j in range(N):
        seq = list(col_full[j])
        S_full.append(seq + RE_chain(row_ccp_poly, seq[-t:]))
    return S_full

#Full datapath implementation

def ecc_2d_silent(r_in):
    S_2t = dffft_2t(r_in)
    S_2t_arrnp = np.array(S_2t)
    S_2t_colwise = np.transpose(S_2t_arrnp).tolist()

    col_poly = []
    row_poly = []
    col_deg = []
    row_deg = []

    for j in S_2t:
        sigma_j, deg_j = BM_fixed(j)
        row_poly.append(sigma_j)
        row_deg.append(deg_j)
    for j in S_2t_colwise:
        sigma_j, deg_j = BM_fixed(j)
        col_poly.append(sigma_j)
        col_deg.append(deg_j)

    col_rpos = []
    row_rpos = []

    for sigma in col_poly:
        col_rpos.append(get_rpos(sigma))
    for sigma in row_poly:
        row_rpos.append(get_rpos(sigma))

    col_rpos_lcm = 0
    row_rpos_lcm = 0

    col_rpos_lcm = [0] * N
    row_rpos_lcm = [0] * N

    for rpos in col_rpos:
        col_rpos_lcm = [a | b for a, b in zip(col_rpos_lcm, rpos)]
    for rpos in row_rpos:
        row_rpos_lcm = [a | b for a, b in zip(row_rpos_lcm, rpos)]

    roots_row = root_lookup(row_rpos_lcm)
    roots_col = root_lookup(col_rpos_lcm)

    col_ccp_poly = root_to_coeff(roots_col)
    row_ccp_poly = root_to_coeff(roots_row)

    col_full = extend_columns(S_2t, col_ccp_poly)
    row_full = extend_rows(col_full, row_ccp_poly)

    err_obtained = idffft_full(row_full)

    return err_obtained

#Used Constants

XY = 0
XZ = 1
YZ = 2
MAX = 5

import numpy as np

def cube_to_hex(cube):
    """Hex of the cube as a [N*N*N-1:0] value: bit (x*N+y)*N+z = cube[x,y,z], MSB first."""
    cube = np.asarray(cube).astype(np.uint8)
    nbits = cube.size
    bits = cube.reshape(-1)                         # C order: index = (x*N + y)*N + z
    value = int("".join(map(str, bits[::-1])), 2)   # bit 0 on the right
    return f"{value:0{(nbits + 3) // 4}x}"          # 3375 bits -> 844 digits, zero padded

def hex_to_cube(h, N=15):
    value = int(h.strip(), 16)
    bits = [(value >> k) & 1 for k in range(N**3)]
    return np.array(bits, dtype=np.uint8).reshape(N, N, N)

def print_cube_hex(cube, label="cube", width=64):
    h = cube_to_hex(cube)
    print(f"{label} [{np.asarray(cube).size-1}:0] = {len(h)*4}'h")
    for k in range(0, len(h), width):
        print("  " + h[k:k+width])

def write_cube_hex(cube, path):
    """One line, no prefix: readable by $readmemh into a [N*N*N-1:0] word."""
    with open(path, "w") as f:
        f.write(cube_to_hex(cube) + "\n")

#3d datapath implementation

def display_orientation(o):
    if(o == XY):
        return "XY"
    elif(o == XZ):
        return "XZ"
    elif(o == YZ):
        return "YZ"
    raise ValueError(f"bad orientation {o}")

def display_slice_err(slc, err, o):
    print(f"Orientation : {display_orientation(o)}")
    print(f"slice : ")
    print_bin(slc)
    print(f"error : ")
    print_bin(err)

def extract_slice(cube, o, i):
    if(o == XY):
        return cube[:, :, i]
    elif(o == XZ):
        return cube[:, i, :]
    elif(o == YZ):
        return cube[i, :, :]

def check_block(slc, err):
    if ((slc ^ err) == 0).all():
        return True
    else:
        return False

def check_block_syndrome(slc, err):
    synd = np.array(dffft_2t(slc ^ err))
    return not synd.any()

def single_pass(cube, o):
    dirty = False
    slices = []
    for i in range (N):
        slices.append(extract_slice(cube, o, i))
    errors = []
    for i in slices:
        errors.append(ecc_2d_silent(i))
    corrs = []
    for i in range(N):
        if(check_block_syndrome(slices[i], errors[i]) and slices[i].any()):
            #display_slice_err(slices[i], errors[i], o)
            corrs.append(slices[i] ^ errors[i])
            if(dirty == False):
                dirty = True
        else:
            corrs.append(slices[i])

    if o == XY:
        corrected_cube = np.stack(corrs, axis=2)
    elif o == XZ:
        corrected_cube = np.stack(corrs, axis=1)
    elif o == YZ:
        corrected_cube = np.stack(corrs, axis=0)

    return corrected_cube, dirty

def full_datapath_3d(cube):
    iters = 0
    while(iters < MAX):
        sweep_dirty = False
        for o in range(3):
            cube, dirty = single_pass(cube, o)
            print_cube_hex(cube, f"iter {iters} pass {display_orientation(o)}")
            #print(f"Done iter : {iters}, pass : {display_orientation(o)}, Dirty : {dirty}")
            if(dirty):
                if(sweep_dirty == False):
                    sweep_dirty = True
        #print(f"Done iter : {iters}, Dirty Sweep : {sweep_dirty}")
        if(sweep_dirty == False):
            break
        iters += 1
    return cube, iters

