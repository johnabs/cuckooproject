using NSGAII
using CSV
using DataFrames

################################ Copied from project.jl##############################################
## Read Information

#Does what it says on the tin.

function nsga_input(f)
    # This needs extra flags so we can read the fixed width file and skip the values at the end of the file.
    df = CSV.read(f, DataFrame, header = 0, skipto=2, delim=" ", ignorerepeated=true, footerskip=4, silencewarnings=true)
    df = mapcols(col->replace(col, missing=>0), df)
    n = df[1, 1]
    b = Array(df[2, :])
    #println(b)
    Q = Array(df[3:(n+2), :])
    #Q = quadratic_formatting(Q)
    #Skip the last row which is parsed as all 0s.
    #Q = Q[1:n-1,:]
    #matrix with regular and quadratic coefficients
    #coeff = vcat(b', Q)
    #weights of the items
    w = Array(df[nrow(df), :])
    return n, b, Q, w
end

function quadratic_formatting(Q::AbstractMatrix)
    nrows,ncols = size(Q)
    for i in 1:nrows
        temp = Q[i, 1:(ncols-i)]
        Q[i, 1:i] = Q[i, (ncols - i + 1):ncols]
        Q[i, (i+1):ncols] = temp
    end
    return Q
end

function knapsack_capacity(knapsacks, weights)
    total_weight = sum(weights)
    no_of_knapsacks = knapsacks
    return 0.8*total_weight/no_of_knapsacks
end
#####################################################################################################

## NSGA Functions


function gen_individual(n, n_kp)
    return rand(0:n_kp,n)
end

function mutate(ind, n_kp)
    n = length(ind)
    i = rand(1:n)
    ind[i] = rand(0:n_kp)
end

function r2b_transformer(r_ind, n_kp)
    n = length(r_ind)
    b_ind = zeros(Int64, n_kp, n)
    for i in 1:n
        kp = r_ind[i]
        if kp != 0
            b_ind[kp, i] = 1
        end
    end 
    return b_ind
end

function b2r_transformer(b_ind)
    n = size(b_ind, 2)
    r_ind = zeros(Int64, n)
    for i in 1:n
        index = findfirst(x->x==1, b_ind[:,i])
        if !isnothing(index)
            r_ind[i] = Int(index)
        end
    end
    return r_ind
end


function nsga_fitness(individual,coeff, weights, capacity, n_kp)
    print(individual)
end


#Takes the quadratic coefficients and formats them
#to work with the multi_fitness_function written
#by another group member.


function main()
    mut_rate = 0.3
    cx_rate = 0.7
    n_kp = 3
    n, b, Q, weights = nsga_input("data/r_100_25_1.txt")
    individual = gen_individual(n, n_kp)
    b_ind = r2b_transformer(individual,n_kp)
    r_ind = b2r_transformer(b_ind)
    capacity = knapsack_capacity(n_kp, weights)
end

main()

