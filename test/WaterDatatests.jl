# Testing the WaterData (USGS Samples) API functions

@testset "WaterData API Testing" begin

    # ------------------------------------------------------------------
    # Validation: _check_profiles throws on bad inputs
    # ------------------------------------------------------------------
    @test_throws ArgumentError readWaterDataSamples(service="foo", profile="bar")
    @test_throws ArgumentError readWaterDataSamples(service="results", profile="foo")
    @test_throws ArgumentError readWaterDataCodes("invalid_service")

    params, response = getWaterDataOGCParams("daily")
    @test response.status == 200
    @test haskey(params, "monitoring_location_id")

    payload, response = checkWaterDataOGCRequests(endpoint="daily", request_type="queryables")
    @test response.status == 200
    @test isa(payload, AbstractDict)

    df, response = readWaterData(
        "daily",
        monitoring_location_id="USGS-05427718",
        parameter_code="00060",
        time="2025-01-01/2025-01-07",
        no_paging=true,
        limit=200
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    # ------------------------------------------------------------------
    # readWaterDataCodes — code-service lookup
    # ------------------------------------------------------------------
    df, response = readWaterDataCodes("states")
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    df, response = readWaterDataCodes("characteristicgroup")
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    # ------------------------------------------------------------------
    # readWaterDataResults — service="results" convenience wrapper
    # ------------------------------------------------------------------
    df, response = readWaterDataResults(
        profile="narrow",
        monitoringLocationIdentifier="USGS-05288705",
        activityStartDateLower="2024-10-01",
        activityStartDateUpper="2025-04-24"
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0
    @test "Location_Identifier" in names(df)
    @test "Activity_ActivityIdentifier" in names(df)

    # ------------------------------------------------------------------
    # whatWaterDataLocations — service="locations" convenience wrapper
    # ------------------------------------------------------------------
    df, response = whatWaterDataLocations(
        stateFips="US:55",
        usgsPCode="00010",
        activityStartDateLower="2024-10-01",
        activityStartDateUpper="2025-04-24"
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0
    @test "Location_Identifier" in names(df)
    @test "Location_Latitude" in names(df)

    # ------------------------------------------------------------------
    # whatWaterDataActivities — service="activities" convenience wrapper
    # ------------------------------------------------------------------
    df, response = whatWaterDataActivities(
        monitoringLocationIdentifier="USGS-06719505"
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0
    @test "Location_HUCTwelveDigitCode" in names(df)

    # ------------------------------------------------------------------
    # whatWaterDataProjects — service="projects" convenience wrapper
    # ------------------------------------------------------------------
    df, response = whatWaterDataProjects(
        stateFips="US:15",
        activityStartDateLower="2024-10-01",
        activityStartDateUpper="2025-04-24"
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0
    @test "Project_Identifier" in names(df)

    # ------------------------------------------------------------------
    # whatWaterDataOrganizations — service="organizations" convenience wrapper
    # ------------------------------------------------------------------
    df, response = whatWaterDataOrganizations(
        profile="count",
        stateFips="US:01"
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) >= 1

    # ------------------------------------------------------------------
    # readWaterDataSamples — flexible function (all services accessible)
    # ------------------------------------------------------------------
    df, response = readWaterDataSamples(
        service="results",
        profile="narrow",
        monitoringLocationIdentifier="USGS-05288705",
        activityStartDateLower="2024-10-01",
        activityStartDateUpper="2025-04-24"
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test "Location_Identifier" in names(df)

    # boundingBox vector conversion (use count profile to keep query small)
    df, response = readWaterDataSamples(
        service="locations",
        profile="count",
        boundingBox=[-89.65, 43.06, -89.33, 43.18],
        stateFips="US:55"
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) >= 1

    # ------------------------------------------------------------------
    # New WaterData OGC/statistics APIs (ported from Python waterdata package)
    # ------------------------------------------------------------------

    df, response = readWaterDataDaily(
        monitoring_location_id="USGS-05427718",
        parameter_code="00060",
        time="2025-01-01/2025-01-07",
        limit=200
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test "daily_id" ∉ string.(names(df))

    df, response = readWaterDataContinuous(
        monitoring_location_id="USGS-06904500",
        parameter_code="00065",
        time="2025-01-01/2025-01-03",
        limit=200
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test "continuous_id" in string.(names(df))

    df, response = whatWaterDataMonitoringLocations(
        state_name="Connecticut",
        site_type_code="GW",
        limit=500
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    df, response = readWaterDataLatestContinuous(
        monitoring_location_id=["USGS-05427718", "USGS-05427719"],
        parameter_code=["00060", "00065"],
        limit=200
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test "latest_continuous_id" in string.(names(df))

    df, response = readWaterDataLatestDaily(
        monitoring_location_id=["USGS-05427718", "USGS-05427719"],
        parameter_code=["00060", "00065"],
        limit=200
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test "latest_daily_id" in string.(names(df))

    df, response = readWaterDataFieldMeasurements(
        monitoring_location_id="USGS-05427718",
        unit_of_measure="ft^3/s",
        time="2025-01-01/2025-10-01",
        skip_geometry=true,
        limit=200
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test "field_measurement_id" in string.(names(df))

    df, response = readWaterDataChannelMeasurements(
        monitoring_location_id="USGS-02238500",
        limit=200,
        skip_geometry=true
    )
    @test typeof(df) == DataFrame
    @test response.status == 200

    df, response = readWaterDataFieldMetadata(
        monitoring_location_id="USGS-02238500",
        limit=200,
        skip_geometry=true
    )
    @test typeof(df) == DataFrame
    @test response.status == 200

    df, response = readWaterDataCombinedMetadata(
        monitoring_location_id="USGS-05407000",
        limit=200,
        skip_geometry=true
    )
    @test typeof(df) == DataFrame
    @test response.status == 200

    df, response = readWaterDataTimeSeriesMetadata(
        bbox=[-89.840355, 42.853411, -88.818626, 43.422598],
        parameter_code=["00060", "00065", "72019"],
        skip_geometry=true,
        limit=1000
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    df, response = readWaterDataReferenceTable("agency-codes")
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    df, response = readWaterDataReferenceTable("agency-codes";
                                               query=Dict("id" => "AK001,AK008", "limit" => "20"))
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) >= 1

    @test_throws ArgumentError readWaterDataReferenceTable("agency-cod")

    df, response = readWaterDataStatsPOR(
        monitoring_location_id="USGS-12451000",
        parameter_code="00060",
        start_date="01-01",
        end_date="01-01"
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

    df, response = readWaterDataStatsDateRange(
        monitoring_location_id="USGS-12451000",
        parameter_code="00060",
        start_date="2025-01-01",
        end_date="2025-01-01",
        computation_type="maximum"
    )
    @test typeof(df) == DataFrame
    @test response.status == 200
    @test nrow(df) > 0

end