using Test

include("read_input.jl")

@testset verbose = true "input tests" begin
    @testset "Example.txt" begin
        f = "./data/Example.txt"
        n, c, w = input(f)
        @test n == 10
        @test size(c) == (10, 10)
        @test size(w) == (10,)
    end

    @testset "file 100_25_1" begin
        f = "./data/r_100_25_1.txt"
        n, c, w = input(f)
        @test n == 100
        @test size(c) == (100, 100)
        @test size(w) == (100,)
    end

    @testset "file 100_25_2" begin
        f = "./data/r_100_25_4.txt"
        n, c, w = input(f)
        @test n == 100
        @test size(c) == (100, 100)
        @test size(w) == (100,)
    end

    @testset "file 100_25_3" begin
        f = "./data/r_100_25_7.txt"
        n, c, w = input(f)
        @test n == 100
        @test size(c) == (100, 100)
        @test size(w) == (100,)
    end

    @testset "file 200_25_1" begin
        f = "./data/r_200_25_1.txt"
        n, c, w = input(f)
        @test n == 200
        @test size(c) == (200, 200)
        @test size(w) == (200,)
    end

    @testset "file 300_25_1" begin
        f = "./data/r_300_25_1.txt"
        n, c, w = input(f)
        @test n == 300
        @test size(c) == (300, 300)
        @test size(w) == (300,)
    end
end
