module SharedMemoryLocks

using Distributed
using SharedArrays
struct SharedMemoryLock <: Base.AbstractLock
    owned::SharedArray{Int64,1}
    SharedMemoryLock(pids::Vector{Int64} = Int64[]) = new(SharedArray{Int64,1}(1, init = 0, pids = pids))
    SharedMemoryLock(owned::SharedArray{Int64,1}) = new(owned)
end
export SharedMemoryLock

using Core.Intrinsics: atomic_pointerreplace

function Base.lock(l::SharedMemoryLock)
    while true
        if @inline trylock(l)
            return
        end
        ccall(:jl_cpu_pause, Cvoid, ())
        # Temporary solution before we have gc transition support in codegen.
        ccall(:jl_gc_safepoint, Cvoid, ())
    end
end

function Base.trylock(l::SharedMemoryLock)
    GC.disable_finalizers()
    res = atomic_pointerreplace(pointer(l.owned, 1), 0, myid(), :sequentially_consistent, :sequentially_consistent)
    if !res.success
        GC.enable_finalizers()
        return false
    end
    return res.success
end

function Base.unlock(l::SharedMemoryLock)
    res = atomic_pointerreplace(pointer(l.owned, 1), myid(), 0, :sequentially_consistent, :sequentially_consistent)
    if !res.success
        error("can't unlock a lock that is not owned by the current process")
    end
    GC.enable_finalizers()
    ccall(:jl_cpu_wake, Cvoid, ())
    return
end

function Base.islocked(l::SharedMemoryLock)
    return l.owned[1] != 0
end

using Serialization
Serialization.serialize(s::AbstractSerializer, l::SharedMemoryLock) = Serialization.serialize_any(s, l)
Serialization.deserialize(s::AbstractSerializer, t::Type{SharedMemoryLock}) =
    @invoke Serialization.deserialize(s::AbstractSerializer, t::DataType)

end
