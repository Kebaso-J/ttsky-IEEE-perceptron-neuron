"""Cocotb testbench for tt_um_IEEE_perceptron.

Run with: make (inside the test/ directory, using TinyTapeout's sim infrastructure)

Tests:
  1. Zero inputs  -> output always 0 regardless of weights
  2. AND gate     -> fires only when all inputs are 1 (high weights, high threshold)
  3. OR gate      -> fires only if any input is 1 (weight=1 each, threshold=1)
  4. Weighted sum -> verify arithmetic across several cases
  5. Threshold    -> sweep threshold and confirm boundary
"""

import cocotb
from cocotb.triggers import Timer


def pack_inputs(x, w0, w1, w2, w3, thresh):
    """Pack perceptron inputs into ui_in and uio_in."""
    ui = (x[0] & 1) | ((x[1] & 1) << 1) | ((x[2] & 1) << 2) | ((x[3] & 1) << 3)
    ui |= (w0 & 3) << 4
    ui |= (w1 & 3) << 6

    uio = (w2 & 3) | ((w3 & 3) << 2) | ((thresh & 3) << 4)
    return ui, uio


def get_outputs(dut):
    value = int(dut.uo_out.value)
    y = value & 1
    s = (value >> 1) & 0xF
    return y, s


async def apply(dut, x, w0, w1, w2, w3, thresh):
    ui, uio = pack_inputs(x, w0, w1, w2, w3, thresh)
    dut.ena.value = 1
    dut.rst_n.value = 1
    dut.ui_in.value = ui
    dut.uio_in.value = uio
    await Timer(1, units="ns")
    return get_outputs(dut)


@cocotb.test()
async def test_zero_inputs(dut):
    """All inputs 0 -> sum must be 0 -> neuron silent."""
    for thresh in range(4):
        y, s = await apply(dut, [0, 0, 0, 0], 3, 3, 3, 3, thresh)
        assert s == 0, f"Expected sum=0, got {s}"
        assert y == 0, f"Expected y=0 with zero inputs, got {y}"


@cocotb.test()
async def test_or_gate(dut):
    """Weights=1 each, threshold=1 -> fires if any input is 1."""
    for bits in range(16):
        x = [(bits >> i) & 1 for i in range(4)]
        y, s = await apply(dut, x, 1, 1, 1, 1, 0)
        expected_y = 1 if any(x) else 0
        expected_s = sum(x)
        assert s == expected_s, f"OR: bits={bits:04b} sum={s} expected={expected_s}"
        assert y == expected_y, f"OR: bits={bits:04b} y={y} expected={expected_y}"


@cocotb.test()
async def test_and_gate(dut):
    """Weights=1, threshold=4 -> fires only when all four inputs are 1."""
    for bits in range(16):
        x = [(bits >> i) & 1 for i in range(4)]
        y, s = await apply(dut, x, 1, 1, 1, 1, 3)
        expected_y = 1 if all(x) else 0
        assert s == sum(x), f"AND: bits={bits:04b} sum={s} expected={sum(x)}"
        assert y == expected_y, f"AND: bits={bits:04b} y={y} expected={expected_y}"


@cocotb.test()
async def test_weighted_sum(dut):
    """Verify weighted arithmetic for a handful of hand-calculated cases."""
    cases = [
        ([1, 0, 0, 0], 3, 2, 1, 0, 3),
        ([1, 1, 0, 0], 2, 2, 2, 2, 4),
        ([1, 1, 1, 1], 1, 2, 3, 3, 9),
        ([0, 1, 0, 1], 3, 3, 3, 3, 6),
        ([1, 0, 1, 0], 2, 0, 2, 0, 4),
    ]

    for x, w0, w1, w2, w3, exp_sum in cases:
        y, s = await apply(dut, x, w0, w1, w2, w3, 0)
        assert s == exp_sum, (
            f"Weighted sum: x={x} w=[{w0},{w1},{w2},{w3}] got {s} expected {exp_sum}"
        )
        assert y == 1, f"Weighted sum case should fire with threshold=1, got y={y}"


@cocotb.test()
async def test_threshold_sweep(dut):
    """Sweep threshold with fixed inputs; verify the firing boundary."""
    for tc in range(4):
        y, s = await apply(dut, [1, 1, 1, 1], 1, 1, 1, 1, tc)
        assert s == 4, f"Threshold sweep: expected sum=4 got {s}"
        assert y == 1, f"Threshold sweep: sum=4 should fire for thresh_cfg={tc}"

    expected = [1, 1, 0, 0]
    for tc in range(4):
        y, s = await apply(dut, [1, 0, 0, 0], 2, 2, 2, 2, tc)
        assert s == 2, f"Boundary: expected sum=2 got {s}"
        assert y == expected[tc], f"Boundary: thresh_cfg={tc} y={y} expected={expected[tc]}"
