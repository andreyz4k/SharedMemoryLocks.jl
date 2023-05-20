# SharedMemoryLocks

[![Build Status](https://github.com/andreyz4k/SharedMemoryLocks.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/andreyz4k/SharedMemoryLocks.jl/actions/workflows/CI.yml?query=branch%3Amain)

This package provides a class for a lock that can be shared between different processes on a local machine. It is a SpinLock that uses a SharedArray that is memory-mapped between processes, preserving atomicity. This lock is non-reentrant, meaning that recursive use will result in a deadlock.

Usage:
```julia
pids = addprocs(2)
@everywhere using SharedMemoryLocks

push!(pids, myid())
l = SharedMemoryLock(pids)
arr = SharedArray{Int}(1, init = 0, pids = pids)

function calc(l, arr)
    for i in 1:100
        lock(l)
        v = arr[1]
        sleep(0.000000001)
        arr[1] = v + 1
        unlock(l)
    end
end

f1 = @spawnat pids[1] calc(l, arr)
f2 = @spawnat pids[2] calc(l, arr)
fetch(f1)
fetch(f2)
@test arr[1] == 200
```
