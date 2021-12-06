using Distributed
@everywhere begin
using Distributions, Chain, Random, Plots, StatsBase, CSV, DataFrames, ArgParse, StatsPlots

# Working as expected
normalize(x)=x/sum(x)
function replace_sols(sol,qb)
    temp=sol[1]
    flight=Levy(0,0.02)
    dist=sample(5:length(temp),Weights(normalize(rand(flight,length(temp)-5))))
    ind=sample(1:length(temp),dist,replace=false)
    temp[ind]=1 .- temp[ind]
   return quantum_unentanglement(temp,qb)
end

#Working as expected.
# Upgrading to work with new data struct.
# In progress, needs testing.
function pareto_filter(y::AbstractArray,capacity)
q=map(z->z[2],y)
x=mapreduce(q->[q[1],q[2],sum(q[3:end])],hcat,q)
d,n=size(x)
io=map(w->all(w[3:end].<capacity),q)
    for i∈ 1:n-1, j∈ i:n
        if i!=j && (io[i] || io[j])
            xi=x[:,i]
            xj=x[:,j]
            if all(xi .<= xj) && any(xi .< xj)
                io[j]=false
            elseif all(xj .<= xi) && any(xj .< xi)
                io[i]=false
            end
        end
    end
    return io
end

# Working as expected
function measure(qv)
    return reshape(map(x->rand()>abs2(qv[x][2]) ? 1 : 0, 1:length(qv)),:,size(qv)[2])
end

#Working, but unsure if output is valid.
# Seems valid, needs test.
function interfere!(qv,sol,pa=pi/20)
    for i in 1:length(qv)
        scale=i_lookup(real(qv[i][1]),real(qv[i][2]),sol[i])
        pa=scale*pa
        rot_mat=[cos(pa) -sin(pa); sin(pa) cos(pa)]
        qv[i]=rot_mat*qv[i]
    end
    return qv
end

# Working as expected
# Tested already.
function i_lookup(a,b,c)
    if a>0 && b >0 && c==1
        return(1)
    elseif a>0 && b >0 && c==0
        return(-1)
    elseif a>0 && b <0 && c==1
        return(-1)
    elseif a>0 && b <0 && c==0
        return(1)
    elseif a<0 && b >0 && c==1
            return(-1)
    elseif a<0 && b >0 && c==0
        return(1)
    elseif a<0 && b <0 && c==1
        return(1)
    else
        return(-1)
    end
end

# Working as expected
function iq_mutate!(qv)
    pos=rand(1:length(qv))
    a=qv[pos][1]
    b=qv[pos][2]
    qv[pos][2]=a
    qv[pos][1]=b
    return qv
end

# Working as expected
function eq_mutate!(qv)
    p1,p2=rand(1:length(qv),2)
    t1=qv[p1]
    t2=qv[p2]
    qv[p1]=t2
    qv[p2]=t1
    return qv
end

# This creates normalized qbits who's complex probabilities sum to 1.
# Working as expected
function ab(x,n)
    a=rand(x*n)+rand(x*n)*im
    b=rand(x*n)+rand(x*n)*im
    return reshape(map(y->[a[y]/sqrt(abs2(a[y])+abs2(b[y])),b[y]/sqrt(abs2(a[y])+abs2(b[y]))],1:x*n),:,n)
end

# Working as expected
# Used to convert quantum matrix to probability matrix
# for disentanglement.
function prob_one(cuckoo)
    return abs2.(map(x->x[2],cuckoo))
end

#Working as expected
#Repairs invalid solutions
function quantum_unentanglement(knapsack, q)
    knapsacks1=knapsack'
    qb=q'
    prob_sum, prob_list, r = 0, [], 0
    for i = 1:size(knapsacks1,2)
        if sum([knapsacks1[j,i] for j = 1:size(knapsacks1,1)]) > 1
            cpd, index = 0, -1
            prob_sum = sum([qb[j,i] for j = 1:size(qb,1)])
            prob_list = [qb[j,i]/prob_sum for j = 1:size(qb,1)]
            r = rand()
            for k = 1:size(prob_list, 1)
                cpd = cpd + prob_list[k]
                if r < cpd && index == -1
                    index = k
                end
            end
            for k = 1:size(knapsacks1, 1)
                if k == index
                    knapsacks1[k,i] = 1
                else
                    knapsacks1[k,i] = 0
                end
            end
        end
    end
    return knapsacks1'
end

#Does what it says on the tin.
function knapsack_capacity(knapsacks, weights)
    total_weight = sum(weights)
    no_of_knapsacks = knapsacks
    return 0.8*total_weight/no_of_knapsacks
end

#Computes values of objective functions
# Returns all negative values to make this
# a minimization problem across the board
# values will be corrected during analyses.
function multi_fitness_values(knapsack, profit, weight, capacity)
    knapsacks=deepcopy(knapsack)'
    weights=deepcopy(weight)'
    profits_fitness_list = []
    weights_list = []
    penalty=maximum(profit[1,:] ./ weights')
    for i = 1:size(knapsacks,1)
        fitness = 0
        weight = 0
        for j = 1:size(knapsacks,2)
            fitness = fitness + knapsacks[i,j]*profit[1,j]
            weight = weight + knapsacks[i,j]*weights[1,j]
            if knapsacks[i,j] == 1 && j < size(knapsacks,2)
                for k = (j+1):size(knapsacks,2)
                    if knapsacks[i,k] == 1
                        fitness = fitness + profit[j+1, k]
                    end
                end
            end
        end
        if weight > capacity
            fitness = fitness - (weight - capacity)*penalty
        end
        append!(profits_fitness_list, fitness)
        append!(weights_list, weight)
    end
    return [-sum(profits_fitness_list), -minimum(profits_fitness_list), weights_list...]
end

# Takes list of pareto front values
# and plots in 3D.
function plot_pareto_front(front)
    a=mapreduce(x->front[x][2],hcat,1:length(front))
    a[1,:]=(-1).*a[1,:]
    a[3,:]=(-1).*a[3,:]
    boxplot(a')
end

# Takes measured solutions
# and evaluates them, and returns a new data structure.
function score_solutions(sols::Vector{Matrix{Int64}},profits,weights,capacity)::Vector{Vector{Array}}
    vals=map(x->multi_fitness_values(x,profits,weights,capacity),sols)
    temp=collect.(zip(sols,vals))
    return temp
end

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--mut_prob1", "-m"
            help = "mutation probability 1"
            arg_type = Float64
            default = 0.5
        "--mut_prob2", "-n"
            help = "mutation probability 1"
            arg_type = Float64
            default = 0.5
        "--knapsacks", "-k"
            help = "number of knapsacks"
            arg_type = Int
            default = 3
        "--phaseangle", "-p"
            help = "Phase angle"
            arg_type = Float64
            default = pi/20
        "--replicates", "-r"
            help = "Number of replicates"
            arg_type = Int64
            default = 1
        # "--flag1"
        #     help = "an option without argument, i.e. a flag"
        #     action = :store_true
        "file"
            help = "a positional argument"
            required = true
    end
    return parse_args(s)
end

function parse()
    parsed_args = parse_commandline()
    println("Parsed args:")
    for (arg,val) in parsed_args
        println("  $arg  =>  $val")
    end
    # code to assign the parsed args
    file =  parsed_args["file"]
    mut_prob1 = parsed_args["mut_prob1"]
    mut_prob2 = parsed_args["mut_prob2"]
    knapsacks = parsed_args["knapsacks"]
    phaseangle = parsed_args["phaseangle"]
    r = parsed_args["replicates"]
    return file, mut_prob1, mut_prob2, knapsacks, phaseangle, r
end


function quadratic_formatting(Q::AbstractMatrix)
    nrows,ncols = size(Q)
    #ncols = size(Q, 2)
    for i in 1:nrows
        temp = Q[i, 1:(ncols-i)]
        Q[i, 1:i] = Q[i, (ncols - i + 1):ncols]
        Q[i, (i+1):ncols] = temp
    end
    return Q
end

function input(f)
    df = CSV.read(f, DataFrame, header = 0, skipto=2, delim=" ", ignorerepeated=true, footerskip=4, silencewarnings=true)
    df = mapcols(col->replace(col, missing=>0), df)
    # for i in 1:ncol(df)
    #     df[!, i] = convert_or_parse.(df[!,i])
    # end
    # number of items
    n = df[1, 1]
    b = Array(df[2, :])
    Q = Array(df[3:(n+2), :])
    Q = quadratic_formatting(Q)
    Q = Q[1:n-1,:]
    #matrix with regular and quadratic coefficients
    coeff = vcat(b', Q)
    #weights of the items
    w = Array(df[nrow(df), :])
    return n, coeff, w
end

function search(c, profits, weights, mut_prob1, mut_prob2, pa, capacity,cycles, iter)
    cuckoo=deepcopy(c)
    qb = prob_one(cuckoo)
    sols=[measure(cuckoo) for _ in 1:cycles]
    sols=map(x->quantum_unentanglement(x,qb),sols)
    sols=score_solutions(sols,profits,weights,capacity)
    nondominated=sols[pareto_filter(sols,capacity)]
    replaced=map(y->replace_sols(y,qb),sols[map(x->!x,pareto_filter(sols,capacity))])
    replaced=score_solutions(replaced,profits,weights,capacity)
    nondominated=vcat(nondominated,replaced)[pareto_filter(vcat(nondominated,replaced),capacity)]
    count=0
    while count<iter
        if(rand()<mut_prob1)
            iq_mutate!(cuckoo)
        end
        if(rand()<mut_prob2)
            eq_mutate!(cuckoo)
        end
        interfere!(cuckoo,sample(nondominated)[1],pa)
        qb = prob_one(cuckoo)
        sols=[measure(cuckoo) for _ in 1:cycles]
        sols=score_solutions(map(x->quantum_unentanglement(x,qb),sols),profits,weights,capacity)
        nondominated=vcat(nondominated,sols)[pareto_filter(vcat(nondominated,sols),capacity)]
        replaced=score_solutions(map(y->replace_sols(y,qb),sols[map(x->!x,pareto_filter(sols,capacity))]),profits,weights,capacity)
        nondominated=vcat(nondominated,replaced)[pareto_filter(vcat(nondominated,replaced),capacity)]
        count+=1
    end
    return unique(nondominated)
end

end

function rep(value,replicates)
    return repeat([value],replicates)
end

function main()
    file, mut_prob1, mut_prob2, n_knapsacks, phaseangle, reps = parse()
    n_items,profits,weights=input(file);
    cuckoo=[ab(n_items,n_knapsacks) for _ in 1:reps]
    cap=knapsack_capacity(n_knapsacks, weights)
    cycles=500
    iter=200
    @time outs=pmap(search,
                    cuckoo,
                    rep(profits,reps),
                    rep(weights,reps),
                    rep(mut_prob1,reps),
                    rep(mut_prob2,reps),
                    rep(phaseangle,reps),
                    rep(cap,reps),
                    rep(cycles,reps),
                    rep(iter,reps)
                    )
    outs2=map(y->mapreduce(x->[-x[2][1] -x[2][2] sum(x[2][3:end])],vcat,outs[y]),1:length(outs))
    #outs3=map(y->map(x->x[1],outs[y]),1:length(outs))
    for i in 1:length(outs2)
        CSV.write(file*"_pfront_"*string(i)*".csv",Tables.table(outs2[i]))
    end
    #CSV.write(file*"solutions.csv",(data=outs3,))
    #savefig(plot_pareto_front(out),file*"plot.png")
end

main()
