#!/usr/bin/env python3
"""Reflect a SPIR-V module's descriptor bindings, push constants and entry point.

Prints one line per item, read by tu_compile.c:
  entry <execution model> <name>
  bind <set> <binding> <VkDescriptorType> <count>     (count 0 = runtime array)
  push <bytes>                                         (present when a PushConstant variable exists)
  spec <count>                                         (number of SpecId decorations, informational)
"""
import struct
import sys

# VkDescriptorType
SAMPLER, CIS, SAMPLED_IMAGE, STORAGE_IMAGE, UTB, STB, UBO, SSBO = 0, 1, 2, 3, 4, 5, 6, 7
INPUT_ATTACHMENT, ACCEL = 10, 1000150000


def main(path):
    w = open(path, "rb").read()
    n = len(w) // 4
    words = struct.unpack("<%dI" % n, w[: n * 4])
    if words[0] != 0x07230203:
        sys.exit("not SPIR-V: " + path)
    i = 5
    deco = {}            # id -> {decoration: [operands]}
    types = {}           # id -> (opcode, operands)
    consts = {}
    variables = []       # (id, ptr type, storage class)
    entries = []
    spec = 0
    while i < n:
        op = words[i] & 0xFFFF
        cnt = words[i] >> 16
        ops = words[i + 1 : i + cnt]
        if cnt == 0:
            break
        if op == 15:  # OpEntryPoint
            model, fid = ops[0], ops[1]
            raw = struct.pack("<%dI" % (len(ops) - 2), *ops[2:])
            name = raw.split(b"\0", 1)[0].decode()
            entries.append((model, name))
        elif op == 71:  # OpDecorate
            deco.setdefault(ops[0], {})[ops[1]] = list(ops[2:])
            if ops[1] == 1:
                spec += 1
        elif op in (19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 5341):
            types[ops[0]] = (op, list(ops[1:]))
        elif op == 43:  # OpConstant
            consts[ops[1]] = ops[2]
        elif op == 59:  # OpVariable
            variables.append((ops[1], ops[0], ops[2]))
        i += cnt

    def desc_of(tid, storage):
        op, o = types[tid]
        count = 1
        if op == 28:  # array
            count = consts.get(o[1], 1)
            tid = o[0]
            op, o = types[tid]
        elif op == 29:  # runtime array
            count = 0
            tid = o[0]
            op, o = types[tid]
        if storage == 12:
            return SSBO, count
        if storage == 2:
            d = deco.get(tid, {})
            return (SSBO if 3 in d else UBO), count
        if op == 26:
            return SAMPLER, count
        if op == 27:
            return CIS, count
        if op == 5341:
            return ACCEL, count
        if op == 25:
            dim, sampled = o[1], o[5]
            if dim == 6:
                return INPUT_ATTACHMENT, count
            if dim == 5:
                return (UTB if sampled == 1 else STB), count
            return (SAMPLED_IMAGE if sampled == 1 else STORAGE_IMAGE), count
        raise SystemExit("unknown descriptor type op %d" % op)

    for model, name in entries:
        print("entry", model, name)
    push = False
    for vid, ptr, storage in variables:
        if storage == 9:
            push = True
            continue
        if storage not in (0, 2, 12):
            continue
        d = deco.get(vid, {})
        if 34 not in d or 33 not in d:
            continue
        pop, po = types[ptr]
        dt, count = desc_of(po[1], storage)
        print("bind", d[34][0], d[33][0], dt, count)
    if push:
        print("push 256")
    print("spec", spec)


if __name__ == "__main__":
    main(sys.argv[1])
