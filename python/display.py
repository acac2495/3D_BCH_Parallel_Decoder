import numpy as np
import matplotlib.pyplot as plt

from cubedef import full_datapath_3d, single_pass, print_cube_hex

N = 15

def show_cube(cube, title="cube", prev=None, ax=None, show=True):
    """3D view of an NxNxN 0/1 cube, indexed cube[x, y, z].
    Without prev: every set bit is a red dot.
    With prev (the cube before this pass):
        red dot    = still set (error not yet fixed)
        green ring = bit cleared by this pass
        black X    = bit newly set by this pass (a miscorrection)
    """
    cube = np.asarray(cube).astype(bool)
    own = ax is None
    if own:
        fig = plt.figure(figsize=(6.5, 6))
        ax = fig.add_subplot(111, projection="3d")
    N = cube.shape[0]
    if prev is None:
        x, y, z = np.nonzero(cube)
        ax.scatter(x, y, z, c="crimson", s=28, depthshade=True, label=f"set bits ({len(x)})")
    else:
        prev = np.asarray(prev).astype(bool)
        keep, cleared, new = cube & prev, prev & ~cube, cube & ~prev
        for m, kw in ((keep,    dict(c="crimson", marker="o", s=28, label=f"still set ({keep.sum()})")),
                      (cleared, dict(facecolors="none", edgecolors="limegreen", marker="o", s=70, linewidths=1.8, label=f"cleared ({cleared.sum()})")),
                      (new,     dict(c="black", marker="x", s=45, label=f"newly set ({new.sum()})"))):
            x, y, z = np.nonzero(m)
            if len(x):
                ax.scatter(x, y, z, **kw)
    ax.set_xlim(-0.5, N - 0.5); ax.set_ylim(-0.5, N - 0.5); ax.set_zlim(-0.5, N - 0.5)
    ax.set_xlabel("x"); ax.set_ylabel("y"); ax.set_zlabel("z")
    ax.set_xticks(range(0, N, 2)); ax.set_yticks(range(0, N, 2)); ax.set_zticks(range(0, N, 2))
    ax.set_title(title)
    ax.legend(loc="upper left", fontsize=8)
    if own and show:
        plt.tight_layout(); plt.show()
    return ax

def show_slices(cube, o, title=None, only_nonzero=False, show=True):
    """Grid of the N slices for one orientation (0=XY, 1=XZ, 2=YZ).
    Same slicing as extract_slice(): XY=cube[:,:,i], XZ=cube[:,i,:], YZ=cube[i,:,:]."""
    cube = np.asarray(cube)
    N = cube.shape[0]
    name = ("XY", "XZ", "YZ")[o]
    idx = list(range(N))
    sl = lambda i: (cube[:, :, i], cube[:, i, :], cube[i, :, :])[o]
    if only_nonzero:
        idx = [i for i in idx if sl(i).any()] or [0]
    cols = min(5, len(idx)); rows = -(-len(idx) // cols)
    fig, axes = plt.subplots(rows, cols, figsize=(2.3 * cols, 2.5 * rows), squeeze=False)
    for a in axes.ravel():
        a.axis("off")
    for k, i in enumerate(idx):
        a = axes[k // cols][k % cols]; a.axis("on")
        s = sl(i)
        a.imshow(s, cmap="Reds", vmin=0, vmax=1, interpolation="nearest")
        a.set_title(f"{name}[{i}]  ({int(s.sum())})", fontsize=9)
        a.set_xticks([]); a.set_yticks([])
        for sp in a.spines.values():
            sp.set_edgecolor("crimson" if s.any() else "lightgray")
    fig.suptitle(title or f"{name} slices (row = first axis, col = second axis)", fontsize=11)
    plt.tight_layout()
    if show: plt.show()
    return fig

def show_pass(prev, cur, title, o=None, slices=True):
    """One call per pass: 3D diff view, plus the slices of that pass's orientation if wanted."""
    show_cube(cur, title, prev=prev)
    if slices and o is not None:
        show_slices(cur, o, title=f"{title} -- {('XY','XZ','YZ')[o]} slices after this pass", only_nonzero=True)


def full_datapath_3d_viz(cube, MAX=100, slices=True):
    """Same loop as full_datapath_3d, but shows the cube after every pass.
    Pass in your (fixed) single_pass function."""
    names = ("XY", "XZ", "YZ")
    show_cube(cube, "input cube")
    iters = 0
    while iters < MAX:
        sweep_dirty = False
        for o in range(3):
            prev = cube.copy()
            cube, dirty = single_pass(cube, o)
            sweep_dirty |= dirty
            print(f"iter {iters}, pass {names[o]}: dirty={dirty}, bits set {int(prev.sum())} -> {int(cube.sum())}")
            show_pass(prev, cube, f"iter {iters}, after {names[o]} pass", o=o, slices=slices)
        if not sweep_dirty:
            break
        iters += 1
    return cube, iters
