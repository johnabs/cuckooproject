using ArgParse

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
            default = 0.2
        "--knapsacks", "-k"
            help = "number of knapsacks"
            arg_type = Int
            default = 0
        "--phaseangle", "-p"
            help = "Phase angle"
            arg_type = Float64
            default = 0.0
        # "--flag1"
        #     help = "an option without argument, i.e. a flag"
        #     action = :store_true
        "file"
            help = "a positional argument"
            required = true
    end

    return parse_args(s)
end

function main()
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

    return file, mut_prob1, mut_prob2, knapsacks, phaseangle
end

file, mut_prob1, mut_prob2, knapsacks, phaseangle = main()

