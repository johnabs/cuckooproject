using Distributions.jl, Chain,

flight=Levy()

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

function measure(qv)
    return map(x->rand()>abs2(qv[x][2]) ? 1 : 0, 1:size(qv)[1])
end

function interfere(qv,sol)
    pa=pi/20

    rot_mat=[cos(pa) -sin(pa); sin(pa) cos(pa)]


end

function iq_mutate(qv)
pos=rand(1:length(qv))
a=qv[pos][1]
b=qv[pos][2]
qv[pos][2]=a
qv[pos][1]=b
return qv
end

function eq_mutate(qv)
p1,p2=rand(1:length(qv),2)
t1=qv[p1]
t2=qv[p2]
qv[p1]=t2
qv[p2]=t1
return qv
end

n=50
# This creates normalized qbits who's complex probabilities sum to 1.
function ab(x)
           a=rand(x)+rand(x)*im
           b=rand(x)+rand(x)*im
           return map(y->[a[y]/sqrt(abs2(a[y])+abs2(b[y])),b[y]/sqrt(abs2(a[y])+abs2(b[y]))],1:x)
end
qvec=

a=collect(1:10)
for i in 1:10
    if i%2==0
        a[i]=a[i]^2
    end
end
a
