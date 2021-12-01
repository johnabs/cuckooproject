using Distributions.jl, Chain, Random, Plots

normalize(x)=x/sum(x)
function replace_sols(sol)
    flight=Levy(0,0.02)
    dist=sample(5:length(sol),Weights(normalize(rand(flight,25))))
    ind=sample(1:length(sol),dist,replace=false)
    sol[ind]=1 .- sol[ind]
   return sol
end

function pareto_filter(x::AbstractArray)
	d,n=size(x)
	io=repeat([true],n)
	for i∈ 1:n-1, j∈ i:n
		if i!=j && (io[i] || io[j])
			xi=x[:,i]
			xj=x[:,j]
			if all(xi<= xj) && any(xi<xj)
				io[j]=false
			elseif all(xj<= xi) && any(xj<xi)
				io[i]=false
			end

		end
	end
	return(x[:,io])
end

# Working as expected
function measure(qv)
    return resize(map(x->rand()>abs2(qv[x][2]) ? 1 : 0, 1:length(qv)),:,size(qv)[2])
end

#Working, but unsure if output is valid.
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
qmat=ab(10,3)

using Random

qb = [0.91 0.78 0.22 0.4 0.48 0.85 0.46 0.81 0.3 0.26; 0 0.55 0.23 0.35 0.44 0.5 0.91 0.95 0.26 0.40; 0 0 0.92 0.11 0.20 0.43 0.71 0.83 0.27 0.65]
knapsacks1 = [1 0 0 1 0 1 0 1 0 0; 1 1 0 1 1 0 1 1 0 0; 1 0 0 1 0 0 0 1 0 0]

function quantum_unentanglement(knapsacks1, qb)
    prob_sum, prob_list, r = 0, [], 0
    for i = 1:size(knapsacks1,2)
        if sum([knapsacks2[j,i] for j = 1:size(knapsacks2,1)]) > 1
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
    return knapsacks1
end

println(knapsacks1)
println(quantum_unentanglement(knapsacks1, qb))

knapsacks = [1 0 0 1 0 1 0 0 0 0; 0 1 0 0 1 0 1 1 0 0; 0 0 1 0 0 0 0 0 1 1]
profits = [91 78 22 4 48 85 46 81 3 26; 0 55 23 35 44 5 91 95 26 40; 0 0 92 11 20 43 71 83 27 65; 0 0 0 7 57 33 38 57 63 82; 0 0 0 0 100 87 91 83 44 48; 0 0 0 0 0 69 57 79 89 21; 0 0 0 0 0 0 9 40 22 26; 0 0 0 0 0 0 0 50 6 7; 0 0 0 0 0 0 0 0 71 52; 0 0 0 0 0 0 0 0 0 17]
weights = [34 33 12 3 43 26 10 2 48 39]

function knapsack_capacity(knapsacks, weights)
    total_weight = sum(weights)
    no_of_knapsacks = size(knapsacks,1)
    return 0.8*total_weight/no_of_knapsacks
end

capacity = knapsack_capacity(knapsacks, weights)

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

println(multi_fitness_values(knapsacks, profits, weights, capacity))
