using Distributed
@everywhere begin
using Distributions, Chain, Random, Plots, StatsBase, CSV, DataFrames, ArgParse, StatsPlots

# Does what is says on the tin.
normalize(x)=x/sum(x)

# Computes a bit distance between 5 and the
# maximum number of bits and flips that many bits
# and returns the new Levy flight solution,
# also unentangles them before returning.
function replace_sols(sol,qb,profits,weights,capacity)
    temp=sol[1]
    flight=Levy(0,0.02)
    dist=sample(5:length(temp),Weights(normalize(rand(flight,length(temp)-5))))
    ind=sample(1:length(temp),dist,replace=false)
    temp[ind]=1 .- temp[ind]
   return quantum_unentanglement(temp,qb,profits,weights,capacity)
end

# Takes solutions with their scores, and evaluates
# their scores and rejects invalid scores too.
# Shouldn't need the later part, but it's an extra
# safety check.
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

# Samples from a quantum cuckoo to
# return a real-valued solution.
function measure(qv)
    return reshape(map(x->rand()>abs2(qv[x][2]) ? 1 : 0, 1:length(qv)),:,size(qv)[2])
end

# Interferes by rotating each qubit some small angle
# toward a given pareto efficient solution.
function interfere!(qv,sol,pa=pi/20)
    for i in 1:length(qv)
        scale=i_lookup(real(qv[i][1]),real(qv[i][2]),sol[i])
        pa=scale*pa
        rot_mat=[cos(pa) -sin(pa); sin(pa) cos(pa)]
        qv[i]=rot_mat*qv[i]
    end
    return qv
end

# Facilitates interference
# as described in Layeb's work.
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

# Mutates by flipping a single qubit's
# α and β parameters.
function iq_mutate!(qv)
    pos=rand(1:length(qv))
    a=qv[pos][1]
    b=qv[pos][2]
    qv[pos][2]=a
    qv[pos][1]=b
    return qv
end

# Mutates by swapping the position
# of two qubits.
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
# for disentanglement, basically just computes |b|^2.
function prob_one(cuckoo)
    return abs2.(map(x->x[2],cuckoo))
end

# Repairs invalid solutions by preventing
# two items from being in the same knapsack
# also prevents any knapsack from being over
# its weight capacity.
function quantum_unentanglement(knapsack, q, profits, weight, capacity)
    knapsacks1=knapsack'
    qb=q'
    weights = weight'
    prob_sum, prob_list, r, p_over_w = 0, [], 0, []
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

    for i in 1:size(knapsacks1,1)
        while sum(knapsacks1[i,:].*weights')>capacity
            p_over_w = replace(((profits[1,:].+1) ./weights'.*knapsacks1[i,:]),0=>Inf)
            knapsacks1[i,findmin(p_over_w)[2]] = 0
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
# Returns all weights for each knapsack rather than
# the sum to check for validity.
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
# Not currently used in the search.
# Planned to be used afterwards with the CSV files.
function plot_pareto_front(front)
    a=mapreduce(x->front[x][2],hcat,1:length(front))
    a[1,:]=(-1).*a[1,:]
    a[3,:]=(-1).*a[3,:]
    boxplot(a')
end

# Takes measured solutions
# and evaluates them, and returns a data structure we
# made for this project. Specifically a solution + score list.
function score_solutions(sols::Vector{Matrix{Int64}},profits,weights,capacity)::Vector{Vector{Array}}
    vals=map(x->multi_fitness_values(x,profits,weights,capacity),sols)
    temp=collect.(zip(sols,vals))
    return temp
end

# The actual search algorithm, written to be as pure as possible so it can be trivially parallelized.
# Takes number of items, number of knapsacks, etc. as input, returns the unique values discovered
# during its iterations, but unique based on both solution and values. If there are replicate values,
# there are multiple solutions producing them.
function search(n, k, profits, weights, mut_prob1, mut_prob2, pa, capacity,cycles, iter)
    nondominated=[]
    cuckoo=ab(n[1],k[1])
    #This is a safety step which is likely no longer necessary, but we kept just in case.
    #Originally before the repair algorithm was fixing invalid solutions, that pareto filter
    #was rejecting them, then the interference wouldn't work, and the solution sets would return empty.
    #At worst, this adds one extra conditional check per replicate (not iteration),
    #at best, it catches an error and allows the simulations to keep running.
    while length(nondominated)==0
        qb = prob_one(cuckoo)
        sols=[measure(cuckoo) for _ in 1:cycles]
        sols=map(x->quantum_unentanglement(x,qb,profits,weights,capacity),sols)
        sols=score_solutions(sols,profits,weights,capacity)
        nondominated=sols[pareto_filter(sols,capacity)]
        #This part is the levy flights, but only replaces the pareto inefficient solutions.
        #The overall vector grows anyway from the cuckoo.
        replaced=map(y->replace_sols(y,qb,profits,weights,capacity),sols[map(x->!x,pareto_filter(sols,capacity))])
        replaced=score_solutions(replaced,profits,weights,capacity)
        #We keep a rolling list of the nondominated solutions which just keep getting checked against
        #the newest solutions found either via Levy flights or cuckoo sampling.
        nondominated=vcat(nondominated,replaced)[pareto_filter(vcat(nondominated,replaced),capacity)]

        #Can't define within the loop due to scoping rules, have to do this instead.
        if length(nondominated)==0
            cuckoo=ab(n[1],k[1])
        end
    end
    #Repeats what's going on above some number of iterations to do the search.
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
        sols=score_solutions(map(x->quantum_unentanglement(x,qb,profits,weights,capacity),sols),profits,weights,capacity)
        nondominated=vcat(nondominated,sols)[pareto_filter(vcat(nondominated,sols),capacity)]
        replaced=score_solutions(map(y->replace_sols(y,qb,profits,weights,capacity),sols[map(x->!x,pareto_filter(sols,capacity))]),profits,weights,capacity)
        nondominated=vcat(nondominated,replaced)[pareto_filter(vcat(nondominated,replaced),capacity)]
        count+=1
    end
    return unique(nondominated)
end

#Used to generate the values needed
#by pmap, as it applys a function over
#a set of vectors, rather than repeating
#automatically n times.
function rep(value,replicates)
    return repeat([value],replicates)
end

end

#Takes the quadratic coefficients and formats them
#to work with the multi_fitness_function written
#by another group member.
function quadratic_formatting(Q::AbstractMatrix)
    nrows,ncols = size(Q)
    for i in 1:nrows
        temp = Q[i, 1:(ncols-i)]
        Q[i, 1:i] = Q[i, (ncols - i + 1):ncols]
        Q[i, (i+1):ncols] = temp
    end
    return Q
end

#Reads command line arguments, works great for bash scripting
#or in conjunction with the --all/-a flag to run over all the
#problem instances in the data subfolder where the project file
#is run from.
function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--mut_prob1", "-m"
            help = "mutation probability 1"
            arg_type = Float64
            default = 1.0
        "--mut_prob2", "-n"
            help = "mutation probability 1"
            arg_type = Float64
            default = 1.0
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
        "--cycles", "-c"
            help = "Number of solutions to sample per iteration"
            arg_type = Int64
            default = 500
        "--iterations", "-i"
            help = "Number of iterations"
            arg_type = Int64
            default = 200
         "--all", "-a"
             help = "run all text files in directory with this config"
             action => :store_true
        "file"
            help = "a positional argument"
            required = true
    end
    return parse_args(s)
end

#Extracts the arguments read from the command line and returns them as a tuple
#which is read into individual variables in the main() function.
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
    a = parsed_args["all"]
    c = parsed_args["cycles"]
    i = parsed_args["iterations"]
    return file, mut_prob1, mut_prob2, knapsacks, phaseangle, r, a, c, i
end

#Allows us to combine matrices of different dimensions into a single data frame for
#exporting to a CSV. This allows us to only compile 1 time per run while maintaining
#the cleanliness of the output folder.
function combine_df(x)
    series = [columns.(x)...]
    series=[(series...)...]
    rows = [[1:size(s)[1];] for s in series]
    df = flatten(DataFrame(g=map(x->"x"*string(x),1:length(series)), s=series, r=rows), [:s, :r])
    return unstack(df, :g, :s)
end

#Gets the columns of a dataframe/matrix.
columns(M) = [ M[:,i] for i in 1:size(M, 2) ]

#Reads the files for the problem instance parameters.
function input(f)
    # This needs extra flags so we can read the fixed width file and skip the values at the end of the file.
    df = CSV.read(f, DataFrame, header = 0, skipto=2, delim=" ", ignorerepeated=true, footerskip=4, silencewarnings=true)
    df = mapcols(col->replace(col, missing=>0), df)
    n = df[1, 1]
    b = Array(df[2, :])
    Q = Array(df[3:(n+2), :])
    Q = quadratic_formatting(Q)
    #Skip the last row which is parsed as all 0s.
    Q = Q[1:n-1,:]
    #matrix with regular and quadratic coefficients
    coeff = vcat(b', Q)
    #weights of the items
    w = Array(df[nrow(df), :])
    return n, coeff, w
end

function main()
    # read commandline arguments to variables.
    file, mut_prob1, mut_prob2, n_knapsacks, phaseangle, reps,a,cycles,iter = parse()
    #If the --all flag is set, we run over all the txt files in the data directory.
    if(a)
        # This filters any extra files out that don't end with .txt
        filelist=filter(x->occursin(r"^.*\.txt$",x),readdir("./data",join=true))
        for f in filelist
            println(f)
            n_items,profits,weights=input(f);
            cap=knapsack_capacity(n_knapsacks, weights)
            #pmap allows parallelization over available threads
            #if there's only 1 thread, it's smart and doesn't
            #try to spin up more or do goofy stuff.
            @time outs=pmap(search,
                            rep([n_items],reps),
                            rep([n_knapsacks],reps),
                            rep(profits,reps),
                            rep(weights,reps),
                            rep(mut_prob1,reps),
                            rep(mut_prob2,reps),
                            rep(phaseangle,reps),
                            rep(cap,reps),
                            rep(cycles,reps),
                            rep(iter,reps)
                            )
            #Filters out any empty solutions, shouldn't be necessary anymore, but kept just in case
            outs=filter(x->length(x)>0, outs)
            #Combines all the Pareto Fronts into a single CSV.
            outs2=combine_df(map(y->mapreduce(x->[-x[2][1] -x[2][2] sum(x[2][3:end])],vcat,outs[y]),1:length(outs)))
            # Generates a "heatmap" matrix of the average solution found for that replicate.
            outs3=DataFrame(mapreduce(y->mean(map(x->x[1],outs[y])),hcat,1:length(outs)),:auto)
            CSV.write(f*"_pfront_"*string(n_knapsacks)*".csv",outs2)
            CSV.write(f*"_heatmaps_"*string(n_knapsacks)*".csv",outs3)
        end
    else
        #Replicate of what happens above but relies on the file value which is passed
        #rather than iterating over all of them.
        n_items,profits,weights=input(file);
        cap=knapsack_capacity(n_knapsacks, weights)
        @time outs=pmap(search,
                        rep([n_items],reps),
                        rep([n_knapsacks],reps),
                        rep(profits,reps),
                        rep(weights,reps),
                        rep(mut_prob1,reps),
                        rep(mut_prob2,reps),
                        rep(phaseangle,reps),
                        rep(cap,reps),
                        rep(cycles,reps),
                        rep(iter,reps)
                        )
        outs=filter(x->length(x)>0, outs)
        outs2=combine_df(map(y->mapreduce(x->[-x[2][1] -x[2][2] sum(x[2][3:end])],vcat,outs[y]),1:length(outs)))
        outs3=DataFrame(mapreduce(y->mean(map(x->x[1],outs[y])),hcat,1:length(outs)),:auto)
        CSV.write(file*"_pfront_"*string(n_knapsacks)*".csv",outs2)
        CSV.write(file*"_heatmaps_"*string(n_knapsacks)*".csv",outs3)
    end
end

main()


