export Billiard, randominside
import Base:iterate
#######################################################################################
## Billiard Table
#######################################################################################
struct Billiard{T, D, O<:Tuple}
    obstacles::O
end

#pretty print:
function Base.show(io::IO, bd::Billiard{T,D,BT}) where {T, D, BT}
    s = "Billiard{$T} with $D obstacles:\n"
    for o in bd
        s*="  $(o.name)\n"
    end
    print(io, s)
end



"""
    Billiard(obstacles...)
Construct a `Billiard` from given `obstacles` (tuple, vector, varargs).

If you want to use the [`boundarymap`](@ref) function, then it is expected to
provide the obstacles of the billiard in sorted order, such that the boundary
coordinate (measured using [`arclength`](@ref))
around the billiard is increasing counter-clockwise.

The boundary coordinate is measured as:
* the distance from start point to end point in `Wall`s
* the arc length measured counterclockwise from the open face in `Semicircle`s
* the arc length measured counterclockwise from the rightmost point in `Circular`s
"""
function Billiard(bd::Union{AbstractVector, Tuple})

    T = eltype(bd[1])
    D = length(bd)
    # Assert that all elements of `bd` are of same type:
    for i in 2:D
        eltype(bd[i]) != T && throw(ArgumentError(
        "All obstacles of the billiard must have same type of
        numbers. Found $T and $(eltype(bd[i])) instead."
        ))
    end

    tup = (bd...,)
    return Billiard{T, D, typeof(tup)}(tup)
end

function Billiard(bd::Vararg{Obstacle})
    T = eltype(bd[1])
    tup = (bd...,)
    return Billiard(tup)
end


getindex(bd::Billiard, i) = bd.obstacles[i]
# Iteration:
iterate(bd::Billiard) = iterate(bd.obstacles)
iterate(bd::Billiard, state) = iterate(bd.obstacles, state)

eltype(bd::Billiard{T}) where {T} = T

isperiodic(bd) = any(x -> typeof(x) <: PeriodicWall, bd.obstacles)

# total arclength
@inline totallength(bd::Billiard) = sum(totallength(x) for x in bd.obstacles)

#######################################################################################
## Distances
#######################################################################################
for f in (:distance, :distance_init)
    @eval $(f)(p::AbstractParticle, bd::Billiard) = $(f)(p.pos, bd.obstacles)
    @eval $(f)(pos::SV{T}, bd::Billiard) where {T} = $(f)(pos, bd.obstacles)
end

for f in (:distance, :distance_init)
    @eval begin
        function ($f)(p::SV{T}, bd::Tuple)::T where {T}
            dmin::T = T(Inf)
            for obst in bd
                d::T = distance(p, obst)
                d < dmin && (dmin = d)
            end#obstacle loop
            return dmin
        end
    end
end

#######################################################################################
## randominside
#######################################################################################
function cellsize(
    bd::Union{Vector{<:Obstacle{T}}, Billiard{T}}) where {T<:AbstractFloat}

    xmin::T = ymin::T = T(Inf)
    xmax::T = ymax::T = T(-Inf)
    for obst ∈ bd
        xs::T, ys::T, xm::T, ym::T = cellsize(obst)
        xmin = xmin > xs ? xs : xmin
        ymin = ymin > ys ? ys : ymin
        xmax = xmax < xm ? xm : xmax
        ymax = ymax < ym ? ym : ymax
    end
    return xmin, ymin, xmax, ymax
end

"""
    randominside(bd::Billiard [, ω])
Return a particle with random allowed initial conditions inside the given
billiard. If supplied with a second argument the
type of the returned particle is `MagneticParticle`, with angular velocity `ω`.
"""
randominside(bd::Billiard) = Particle(_randominside(bd)...)
randominside(bd::Billiard{T}, ω) where {T} =
MagneticParticle(_randominside(bd)..., T(ω))



function _randominside(bd::Billiard{T}) where {T<:AbstractFloat}
    #1. position
    xmin::T, ymin::T, xmax::T, ymax::T = cellsize(bd)

    xp = T(rand())*(xmax-xmin) + xmin
    yp = T(rand())*(ymax-ymin) + ymin
    pos = SV{T}(xp, yp)

    dist = distance_init(pos, bd)
    while dist <= sqrt(eps(T))

        xp = T(rand())*(xmax-xmin) + xmin
        yp = T(rand())*(ymax-ymin) + ymin
        pos = SV{T}(xp, yp)
        dist = distance_init(pos, bd)
    end

    #2. velocity
    φ = T(2π*rand())
    vel = SV{T}(sin(φ), cos(φ)) #TODO:Change to sincos for julia 0.7

    #3. current_cell (does nothing)
    cc = zero(SV{T})

    return pos, vel, cc
end
