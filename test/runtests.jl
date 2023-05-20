using Test
using Distributed
using SharedArrays
using SharedMemoryLocks

@testset "SharedMemoryLocks.jl" begin
    @testset "Basic" begin
        l = SharedMemoryLocks.SharedMemoryLock()
        @test !islocked(l)
        lock(l)
        @test islocked(l)
        unlock(l)
        @test !islocked(l)
    end

    @testset "Multiprocess" begin
        pids = addprocs(2)
        @everywhere pids using SharedMemoryLocks

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
    end
end
