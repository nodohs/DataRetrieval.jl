# Testing the NLDI functions

@testset "NLDI Testing" begin

    # basin query
    df, response = readNLDIbasin("WQP", "USGS-054279485")
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0
    @test occursin("Polygon", string(df.geometry_type[1]))

    # flowlines query using feature source origin
    df, response = readNLDIflowlines("UM",
                                     feature_source="WQP",
                                     feature_id="USGS-054279485")
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0
    @test occursin("LineString", string(df.geometry_type[1]))

    # flowlines query using comid origin
    df, response = readNLDIflowlines("UM", comid=13294314, distance=50)
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    # features query by feature source with navigation
    df, response = readNLDIfeatures(feature_source="WQP",
                                    feature_id="USGS-054279485",
                                    data_source="nwissite",
                                    navigation_mode="UM",
                                    distance=50)
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    # features query by feature source without navigation
    df, response = readNLDIfeatures(feature_source="WQP", feature_id="USGS-054279485")
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    # features query by comid
    df, response = readNLDIfeatures(comid=13294314,
                                    data_source="WQP",
                                    navigation_mode="UM",
                                    distance=5)
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    # features query by lat/long
    df, response = readNLDIfeatures(lat=43.087, long=-89.509)
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    # search basin
    result, response = searchNLDI(feature_source="WQP", feature_id="USGS-054279485", find="basin")
    @test isa(result, AbstractDict)
    @test response.status == 200
    @test haskey(result, "features")

    # search flowlines
    result, response = searchNLDI(feature_source="WQP",
                                  feature_id="USGS-054279485",
                                  navigation_mode="UM",
                                  find="flowlines")
    @test isa(result, AbstractDict)
    @test response.status == 200
    @test haskey(result, "features")

    # search features by lat/long
    result, response = searchNLDI(lat=43.087, long=-89.509, find="features")
    @test isa(result, AbstractDict)
    @test response.status == 200
    @test haskey(result, "features")

    # validation checks
    @test_throws ArgumentError readNLDIflowlines("BAD", comid=13294314)
    @test_throws ArgumentError readNLDIfeatures(lat=43.087)
    @test_throws ArgumentError readNLDIfeatures(feature_source="WQP")
    @test_throws ArgumentError searchNLDI(find="bad")

end
