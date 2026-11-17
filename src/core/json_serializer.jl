# Deterministic Zero-Dependency JSON Serializer

function escape_json_string(s::AbstractString)
    io = IOBuffer()
    print(io, '"')
    for c in s
        if c == '"'
            print(io, "\\\"")
        elseif c == '\\'
            print(io, "\\\\")
        elseif c == '\n'
            print(io, "\\n")
        elseif c == '\r'
            print(io, "\\r")
        elseif c == '\t'
            print(io, "\\t")
        else
            print(io, c)
        end
    end
    print(io, '"')
    return String(take!(io))
end

function to_json(io::IO, val::Nothing, indent::Int=0)
    print(io, "null")
end

function to_json(io::IO, val::Bool, indent::Int=0)
    print(io, val ? "true" : "false")
end

function to_json(io::IO, val::Integer, indent::Int=0)
    print(io, val)
end

function to_json(io::IO, val::AbstractFloat, indent::Int=0)
    if isnan(val) || isinf(val)
        print(io, "null")
    else
        print(io, val)
    end
end

function to_json(io::IO, val::AbstractString, indent::Int=0)
    print(io, escape_json_string(val))
end

function to_json(io::IO, val::Symbol, indent::Int=0)
    to_json(io, String(val), indent)
end

function to_json(io::IO, val::AbstractVector, indent::Int=0)
    if isempty(val)
        print(io, "[]")
        return
    end
    if all(x -> isa(x, Real), val) && length(val) <= 45
        print(io, "[")
        for (i, x) in enumerate(val)
            i > 1 && print(io, ", ")
            to_json(io, x, 0)
        end
        print(io, "]")
        return
    end
    println(io, "[")
    next_indent = indent + 2
    pad = " "^next_indent
    for (i, x) in enumerate(val)
        print(io, pad)
        to_json(io, x, next_indent)
        if i < length(val)
            println(io, ",")
        else
            println(io)
        end
    end
    print(io, " "^indent, "]")
end

function to_json(io::IO, val::AbstractDict, indent::Int=0)
    if isempty(val)
        print(io, "{}")
        return
    end
    println(io, "{")
    next_indent = indent + 2
    pad = " "^next_indent
    keys_sorted = sort!(collect(keys(val)), by=string)
    for (i, k) in enumerate(keys_sorted)
        print(io, pad, escape_json_string(string(k)), ": ")
        to_json(io, val[k], next_indent)
        if i < length(keys_sorted)
            println(io, ",")
        else
            println(io)
        end
    end
    print(io, " "^indent, "}")
end

function write_json(path::AbstractString, data)
    mkpath(dirname(path))
    open(path, "w") do io
        to_json(io, data, 0)
        println(io)
    end
end

