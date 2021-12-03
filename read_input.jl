using CSV
using DataFrames

function convert_or_parse(number::Any)
    if typeof(number) == String
        return parse(Float64, number)
    end
    return Float64(number)
end


function quadratic_formatting(Q::AbstractMatrix)
    nrows = size(Q, 1)
    ncols = size(Q, 2)
    for i in 1:nrows
        temp = Q[i, 1:(ncols-i)]
        Q[i, 1:i] = Q[i, (ncols - i + 1):ncols]
        Q[i, (i+1):ncols] = temp
    end
    return Q
end

function input(f = "data/Example.txt")
    df = CSV.read(f, DataFrame, header = 0, delim=" ", ignorerepeated=true, skipto=2, footerskip=4, silencewarnings=true)
    
    df = mapcols(col->replace(col, missing=>0), df)

    # for i in 1:ncol(df)
    #     df[!, i] = convert_or_parse.(df[!,i])
    # end

    # number of items
    n = df[1, 1]

    b = Array(df[2, :])

    Q = Array(df[3:(n+2), :])

    Q = quadratic_formatting(Q)

    Q = Q[1:n-1, :]

    #matrix with regular and quadratic coefficients
    coeff = vcat(b', Q)

    #weights of the items
    w = Array(df[nrow(df), :])

    return n, coeff, w
end


# n, c, w = input()

# println("n:", n, "\nc:",c,"\nw:", w)