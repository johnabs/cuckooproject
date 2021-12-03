using Distributions, Chain, Random, Plots, StatsBase

# Working as expected
normalize(x)=x/sum(x)
function replace_sols(sol)
    flight=Levy(0,0.02)
    dist=sample(5:length(sol),Weights(normalize(rand(flight,25))))
    ind=sample(1:length(sol),dist,replace=false)
    sol[ind]=1 .- sol[ind]
   return sol
end

#Working as expected.
# Upgrading to work with new data struct.
# In progress, needs testing.
function pareto_filter(y::AbstractArray)
x=reduce(hcat,map(z->z[2],y))
d,n=size(x)
io=repeat([true],n)
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
    return(y[:,io])
end

# Working as expected
function measure(qv)
    return reshape(map(x->rand()>abs2(qv[x][2]) ? 1 : 0, 1:length(qv)),:,size(qv)[2])
end

#Working, but unsure if output is valid.
# Seems valid, needs test.
function interfere(qv,sol,pa=pi/20)
    for i in 1:length(qv)
        scale=i_lookup(real(qv[i][1]),real(qv[i][2]),sol[i])
        pa=scale*pa
        rot_mat=[cos(pa) -sin(pa); sin(pa) cos(pa)]
        qv[i]=rot_mat*qv[i]
    end
return(qv)
end

# Working as expected
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
function iq_mutate(qv)
pos=rand(1:length(qv))
a=qv[pos][1]
b=qv[pos][2]
qv[pos][2]=a
qv[pos][1]=b
return qv
end

# Working as expected
function eq_mutate(qv)
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
function quantum_unentanglement(knapsacks1, qb)
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

#knapsacks = [1 0 0 1 0 1 0 0 0 0; 0 1 0 0 1 0 1 1 0 0; 0 0 1 0 0 0 0 0 1 1]
#profits = [91 78 22 4 48 85 46 81 3 26; 0 55 23 35 44 5 91 95 26 40; 0 0 92 11 20 43 71 83 27 65; 0 0 0 7 57 33 38 57 63 82; 0 0 0 0 100 87 91 83 44 48; 0 0 0 0 0 69 57 79 89 21; 0 0 0 0 0 0 9 40 22 26; 0 0 0 0 0 0 0 50 6 7; 0 0 0 0 0 0 0 0 71 52; 0 0 0 0 0 0 0 0 0 17]
#weights = [34 33 12 3 43 26 10 2 48 39]

function knapsack_capacity(knapsacks, weights)
    total_weight = sum(weights)
    no_of_knapsacks = size(knapsacks,1)
    return 0.8*total_weight/no_of_knapsacks
end

#Computes values of objective functions
# Returns all negative values to make this
# a minimization problem across the board
# values will be corrected during analyses.
function multi_fitness_values(knapsacks, profits, weights, capacity)
    profits_fitness_list = []
    weights_list = []
    for i = 1:size(knapsacks,1)
        fitness = 0
        weight = 0
        for j = 1:size(knapsacks,2)
            fitness = fitness + knapsacks[i,j]*profits[1,j]
            weight = weight + knapsacks[i,j]*weights[1,j]
            if knapsacks[i,j] == 1 && j < size(knapsacks,2)
                for k = (j+1):size(knapsacks,2)
                    if knapsacks[i,k] == 1
                        fitness = fitness + profits[j+1, k]
                    end
                end
            end
        end
        if weight > capacity
            fitness = fitness - (weight - capacity)*(maximum(profits))
        end
        append!(profits_fitness_list, fitness)
        append!(weights_list, (-1)*weight)
    end
    return [sum(profits_fitness_list), sum(weights_list), minimum(profits_fitness_list)]
end

# Takes list of pareto front values
# and plots in 3D.
function plot_pareto_front(front::Vector{Vector{Int64}})
    scatter(front...)
end

# Takes measured solutions
# and evaluates them, and returns a new data structure.
function score_solutions(sols)
 vals=map(x->multi_fitness_values(x,profits,weights,capacity),sols)
 return(collect(zip(sols,vals)))
end

# Extracts score from solution
# data structure.
function get_vals(scored)
 return reduce(hcat, map(x->x[2],scored))
end

# Not sure what I need this for.
# Maybe just update pareto_filter function.
function filter_sols(scored)
    .
end

#data=read(file,params);
#n_knapsacks=
#n_items=
#
#cuckoo=ab(n_items,n_knapsacks)
#capacity = knapsack_capacity(knapsacks, weights)

function search(cuckoo, profits, weights, capacity,cycles, iter)
    qb = prob_one(cuckoo)
    sols=quantum_unentanglement.([measure(cuckoo) for _ in 1:cycles],qb)
    nondominated=pareto_filter(multi_fitness_values(sols,profits,weights,capacity))
    replaced=filter(x->x ! in nondominated, sols)
    nondominated=pareto_filter(vcat(nondominated,replaced))
    count=0
    while count<iter
        iq_mutate!(cuckoo)
        eq_mutate!(cuckoo)
        interfere!(cuckoo,sample(nondominated))
        sols=[measure(cuckoo) for _ in 1:cycles]
        nondominated=pareto_filter(vcat(nondominated,sols))
        count+=1
    end
    return [cuckoo, nondominated]
end
