using Plots, CSV, DataFrames, Metaheuristics, StatsPlots, Statistics

function make_heatmap(hmap)
    heatmap(collect(1:100), collect(1:3), Matrix(hmap[:,1:3]))
    savefig(file*"_example_heatmap.png")
end

function hypervol(flist)
   return map(x->Metaheuristics.PerformanceIndicators.hypervolume(Matrix(flist[x])*[-1 0 0 ; 0 -1 0 ; 0 0 1], nadir(reduce(vcat,Matrix.(flist))*[-1 0 0 ; 0 -1 0 ; 0 0 1])),1:length(flist))
end

function hypervol2(flist,ref)
   return map(x->Metaheuristics.PerformanceIndicators.hypervolume(Matrix(flist[x])*[-1 0 0 ; 0 -1 0 ; 0 0 1], nadir(reduce(vcat,Matrix.(flist))*[-1 0 0 ; 0 -1 0 ; 0 0 1])),1:length(flist))
end

function hypervol_dist(nhvi)
    histogram(nhvi, title="Hypervolume Distribution of "*file*"\n mean="*string(round(mean(nhvi),digits=3))*", sd="*string(round(std(nhvi),digits=3)), legend=false)
    savefig(file*"_hypervolume_dist.png")
end

function make_pairplot(front)
    l=@layout([° _ _; ° ° _; ° ° °])
    plot(histogram(front[!,1], legend=false, title="Profit:"*string(round(mean(front[!,1]),digits=0))*"±"*string(round(std(front[!,1]),digits=0))),
         scatter(front[!,1],front[!,2],legend=false),
         histogram(front[!,2],legend=false, title="Min K Profit:"*string(round(mean(front[!,2]),digits=0))*"±"*string(round(std(front[!,2]),digits=0))),
         scatter(front[!,1],front[!,3],legend=false),
         scatter(front[!,2],front[!,3],legend=false),
         histogram(front[!,3],legend=false, title="Total Weight:"*string(round(mean(front[!,3]),digits=0))*"±"*string(round(std(front[!,3]),digits=0))), layout=l, titlefontsize=8, xformatter=:scientific, xrotation=20, margins=-2mm)
        savefig(file*"_pairplots.png")
end

function three_dim_pfront(front)
    scatter(map(x->front[!,x],1:3)...,legend=false, formatter=:scientific, xlab="Profits", ylab="Min Profit", zlab="Total Weight", yrotation=-10, margins=0mm, guidefontsize=:8)
        savefig(file*"_3D_pfront.png")
end

function individual_info(n)
    filelist=filter(x->occursin(r"^.*pfront.+.csv$",x),readdir("./data/"*string(n)*"_knapsack_results",join=true))
    list=[]
    for f in filelist
        file=match(r"^.*.txt",f).match
        fronts=CSV.read(file*"_pfront_"*string(n)*".csv",DataFrame)
        #hmap=CSV.read("./data/"*string(n)*"_knapsack_results/"*file*"_heatmaps_"*string(n)*".csv",DataFrame)
        #ref=[sum(profits),sum(profits)/n,0]
        flist=map(x->rename(dropmissing(fronts[!,[x,x+1,x+2]]),Symbol.(["Profits","Min Profit","Weight"])),2:3:89)
        hvi=hypervol(flist)
        nhvi=hvi#/maximum(hvi)
        if(length(list)==0)
            list=nhvi
        else
            list=hcat(list,nhvi)
        end
        #Uncomment these if you want to make plots of everything.
        #three_dim_pfront(flist[1])
        #make_pairplot(flist[1])
        #hypervol_dist(nhvi)
        #make_heatmap(hmap)
    end
    files=map(x->match(r"r_.*.txt",x).match,filelist);
    test=map(x->match(r"\d+_\d+",files[x]).match,1:10:91)
    df=DataFrame(list,Symbol.(files));
    #lol=map(x->df[!,x],1:size(df,2));
    #sds5=map(x->std(df[!,x]),1:size(df,2));
    #plot(scatter(map(x->maximum(df3[!,x]),1:99)), scatter(map(x->minimum(df3[!,x]),1:99)),legend=false, layout=2)
    boxplot(map(y->mapreduce(x->df[!,x],vcat,y:y+9),1:10:91),labels=reshape(test,:,10),legend=:topleft,title="Absolute Hypervolume Distributions \n per Problem Type for 10 Knapsacks")
end

function parameter_comparison()
    filelist=filter(x->occursin(r"^.*pfront.+.csv$",x),readdir("./data/comp_set",join=true))
    list=[]
    for f in filelist
        #file=match(r"^.*.txt",f).match
        fronts=CSV.read(f,DataFrame)
        #hmap=CSV.read("./data/"*string(n)*"_knapsack_results/"*file*"_heatmaps_"*string(n)*".csv",DataFrame)
        #ref=[sum(profits),sum(profits)/n,0]
        flist=map(x->rename(dropmissing(fronts[!,[x,x+1,x+2]]),Symbol.(["Profits","Min Profit","Weight"])),2:3:89)
        hvi=hypervol(flist)
        nhvi=hvi#/maximum(hvi)
        if(length(list)==0)
            list=flist
        else
            list=hcat(list,flist)
        end
        #Uncomment these if you want to make plots of everything.
        #three_dim_pfront(flist[1])
        #make_pairplot(flist[1])
        #hypervol_dist(nhvi)
        #make_heatmap(hmap)
    end
    ref=nadir(reduce(vcat,flist[1:9]))
    files=map(x->replace(x,r"^.*r_(.*)_1\.txt_pfront(.*)\.csv"=>s"\g<1>\g<2>"),filelist)
    test=files
    df=DataFrame(list,Symbol.(files));
    #lol=map(x->df[!,x],1:size(df,2));
    #sds5=map(x->std(df[!,x]),1:size(df,2));
    #plot(scatter(map(x->maximum(df3[!,x]),1:99)), scatter(map(x->minimum(df3[!,x]),1:99)),legend=false, layout=2)
   ranges=hcat(collect(1:270:length(list)),collect(1:9:90))
    for x in 1:size(ranges,1)
        subset=list[ranges[x,1]:(ranges[x,1]+269)]
        ref=nadir(Matrix(reduce(vcat,subset))*[-1 0 0 ; 0 -1 0 ; 0 0 1])
        p1=hypervol2(subset,ref)
        p1=DataFrame(reshape(p1,:,9),:auto)
        boxplot(map(y->p1[!,y],[3,1,2,6,4,5,9,7,8])
                ,labels=reshape(map(y->(test[ranges[x,2]:(ranges[x,2]+8)])[y],[3,1,2,6,4,5,9,7,8]),:,9)
                ,legend=:outertopright
                ,title="Absolute Hypervolume Distributions \n per Parameter Type for "*string(match(r"^\d+_\d+",test[ranges[x,2]]).match))
        savefig("temp"*string(x)*".png")
    end
end
