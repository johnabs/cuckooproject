knapsacks1 = [1 0 0 1 0 1 0 0 0 0; 0 1 0 0 1 0 1 1 0 0; 0 0 1 0 0 0 0 0 1 1]
knapsacks2 = [0 0 0 1 0 1 0 0 0 0; 0 1 0 0 1 0 1 1 0 0; 0 0 0 0 0 0 0 0 0 0]
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

map(x->multi_fitness_values(x,profits, weights, capacity), [knapsacks1, knapsacks2])
