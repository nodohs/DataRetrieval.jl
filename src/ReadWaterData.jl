# Functions for querying the USGS Samples (WaterData) API
# See https://api.waterdata.usgs.gov/ for API reference.

const _WATERDATA_BASE_URL = "https://api.waterdata.usgs.gov/samples-data"
const _WATERDATA_OGC_BASE_URL = "https://api.waterdata.usgs.gov/ogcapi/v0"
const _WATERDATA_STATS_BASE_URL = "https://api.waterdata.usgs.gov/statistics/v0"

const _WATERDATA_CODE_SERVICES = Set([
    "characteristicgroup",
    "characteristics",
    "counties",
    "countries",
    "observedproperty",
    "samplemedia",
    "sitetype",
    "states",
])

const _WATERDATA_SERVICES = Set([
    "activities",
    "locations",
    "organizations",
    "projects",
    "results",
])

const _WATERDATA_PROFILE_LOOKUP = Dict(
    "activities"    => Set(["sampact", "actmetric", "actgroup", "count"]),
    "locations"     => Set(["site", "count"]),
    "organizations" => Set(["organization", "count"]),
    "projects"      => Set(["project", "projectmonitoringlocationweight"]),
    "results"       => Set([
        "fullphyschem",
        "basicphyschem",
        "fullbio",
        "basicbio",
        "narrow",
        "resultdetectionquantitationlimit",
        "labsampleprep",
        "count",
    ]),
)

const _WATERDATA_METADATA_COLLECTIONS = Set([
  "agency-codes",
  "altitude-datums",
  "aquifer-codes",
  "aquifer-types",
  "coordinate-accuracy-codes",
  "coordinate-datum-codes",
  "coordinate-method-codes",
  "counties",
  "hydrologic-unit-codes",
  "medium-codes",
  "national-aquifer-codes",
  "parameter-codes",
  "reliability-codes",
  "site-types",
  "states",
  "statistic-codes",
  "topographic-codes",
  "time-zone-codes",
])

# ---------------------------------------------------------------------------
# Primary public API
# ---------------------------------------------------------------------------

"""
    readWaterDataCodes(code_service; ssl_check=true)

Return code values from a USGS Samples code-service endpoint. Useful for
discovering valid filter values (states, characteristic groups, site types,
etc.) before constructing a `readWaterDataSamples` call.

# Arguments
- `code_service::String`: The code service to query. One of:
  `"states"`, `"counties"`, `"countries"`, `"sitetype"`, `"samplemedia"`,
  `"characteristicgroup"`, `"characteristics"`, or `"observedproperty"`.

# Keyword Arguments
- `ssl_check::Bool=true`: Whether to verify SSL certificates on the request.

# Returns
- `df::DataFrame`: Table of code values and descriptions returned by the
  service.
- `response::HTTP.Messages.Response`: The raw HTTP response object.

# Examples
```jldoctest
julia> df, response = readWaterDataCodes("states");

julia> typeof(df)
DataFrame

julia> typeof(response)
HTTP.Messages.Response
```
"""
function readWaterDataCodes(code_service; ssl_check=true)
    svc = lowercase(String(code_service))
    if svc ∉ _WATERDATA_CODE_SERVICES
        throw(ArgumentError(
            "Invalid code service: '$svc'. " *
            "Valid options are: $(sort(collect(_WATERDATA_CODE_SERVICES)))"
        ))
    end

    url = string(_WATERDATA_BASE_URL, "/codeservice/", svc)
    response = _custom_get(url;
                           query_params=Dict("mimeType" => "application/json"),
                           ssl_check=ssl_check)

    parsed = JSON.parse(String(response.body))
    data = get(parsed, "data", Any[])
    return DataFrame(data), response
end

"""
    readWaterDataSamples(; ssl_check=true, service="results",
                          profile="fullphyschem", kwargs...)

Flexible query of the USGS Samples database. All query parameters are
passed as keyword arguments. Prefer the service-specific convenience
functions (`readWaterDataResults`, `whatWaterDataLocations`, etc.) for
common use cases.

The Samples web GUI is at https://waterdata.usgs.gov/download-samples/ and
the Swagger docs are at https://api.waterdata.usgs.gov/samples-data/docs.

# Keyword Arguments
- `ssl_check::Bool=true`: Whether to verify SSL certificates.
- `service::String="results"`: Samples service to query. One of
  `"results"`, `"locations"`, `"activities"`, `"projects"`, or
  `"organizations"`.
- `profile::String="fullphyschem"`: Data profile for the selected service.
  Valid profiles per service:
  - `"results"` — `"fullphyschem"` (default), `"basicphyschem"`,
    `"fullbio"`, `"basicbio"`, `"narrow"`,
    `"resultdetectionquantitationlimit"`, `"labsampleprep"`, `"count"`
  - `"locations"` — `"site"`, `"count"`
  - `"activities"` — `"sampact"`, `"actmetric"`, `"actgroup"`, `"count"`
  - `"projects"` — `"project"`, `"projectmonitoringlocationweight"`
  - `"organizations"` — `"organization"`, `"count"`
- `activityMediaName::Union{String,Vector{String}}`: Environmental medium
  (e.g. `"Water"`). See `readWaterDataCodes("samplemedia")` for valid
  values.
- `activityStartDateLower::String`: Inclusive lower bound of the activity
  start date, in `YYYY-MM-DD` format.
- `activityStartDateUpper::String`: Inclusive upper bound of the activity
  start date, in `YYYY-MM-DD` format.
- `activityTypeCode::Union{String,Vector{String}}`: Activity type code
  (e.g. `"Sample-Routine, regular"`).
- `characteristicGroup::Union{String,Vector{String}}`: Broad characteristic
  category (e.g. `"Organics, PFAS"`). See
  `readWaterDataCodes("characteristicgroup")`.
- `characteristic::Union{String,Vector{String}}`: Specific characteristic
  (e.g. `"Suspended Sediment Discharge"`). See
  `readWaterDataCodes("characteristics")`.
- `characteristicUserSupplied::Union{String,Vector{String}}`: User-supplied
  characteristic name.
- `boundingBox::Vector{<:Real}`: Geographic bounding box in decimal degrees
  (NAD83), as `[west, south, east, north]`.
  Example: `[-92.8, 44.2, -88.9, 46.0]`.
- `countryFips::Union{String,Vector{String}}`: Country FIPS code
  (e.g. `"US"`). See `readWaterDataCodes("countries")`.
- `stateFips::Union{String,Vector{String}}`: State FIPS code
  (e.g. `"US:15"` for Hawaii). See `readWaterDataCodes("states")`.
- `countyFips::Union{String,Vector{String}}`: County FIPS code
  (e.g. `"US:15:001"`). See `readWaterDataCodes("counties")`.
- `siteTypeCode::Union{String,Vector{String}}`: Site-type abbreviation
  (e.g. `"GW"` for groundwater). See `readWaterDataCodes("sitetype")`.
- `siteTypeName::Union{String,Vector{String}}`: Full site-type name
  (e.g. `"Well"`). See `readWaterDataCodes("sitetype")`.
- `usgsPCode::Union{String,Vector{String}}`: Five-digit USGS parameter code
  (e.g. `"00060"` for discharge).
- `hydrologicUnit::Union{String,Vector{String}}`: Up to 12-digit HUC code.
- `monitoringLocationIdentifier::Union{String,Vector{String}}`:
  Agency-code/location-number identifier (e.g. `"USGS-040851385"`).
- `organizationIdentifier::Union{String,Vector{String}}`: Organization
  identifier (e.g. `"USGS"`).
- `pointLocationLatitude::Real`: Latitude for a point/radius search
  (decimal degrees, WGS84). Requires `pointLocationLongitude` and
  `pointLocationWithinMiles`.
- `pointLocationLongitude::Real`: Longitude for a point/radius search.
- `pointLocationWithinMiles::Real`: Radius for a point/radius search.
- `projectIdentifier::Union{String,Vector{String}}`: Project identifier
  (e.g. `"ZH003QW03"`).
- `recordIdentifierUserSupplied::Union{String,Vector{String}}`: Internal AQS
  record identifier. Only valid for `service="results"`.

# Returns
- `df::DataFrame`: Records returned by the selected service and profile.
- `response::HTTP.Messages.Response`: The raw HTTP response object.

# Examples
```jldoctest
julia> df, response = readWaterDataSamples(
           service="results",
           profile="narrow",
           monitoringLocationIdentifier="USGS-05288705",
           activityStartDateLower="2024-10-01",
           activityStartDateUpper="2025-04-24");

julia> typeof(df)
DataFrame

julia> typeof(response)
HTTP.Messages.Response
```
"""
function readWaterDataSamples(;
        ssl_check=true,
        service="results",
        profile="fullphyschem",
        activityMediaName=nothing,
        activityStartDateLower=nothing,
        activityStartDateUpper=nothing,
        activityTypeCode=nothing,
        characteristicGroup=nothing,
        characteristic=nothing,
        characteristicUserSupplied=nothing,
        boundingBox=nothing,
        countryFips=nothing,
        stateFips=nothing,
        countyFips=nothing,
        siteTypeCode=nothing,
        siteTypeName=nothing,
        usgsPCode=nothing,
        hydrologicUnit=nothing,
        monitoringLocationIdentifier=nothing,
        organizationIdentifier=nothing,
        pointLocationLatitude=nothing,
        pointLocationLongitude=nothing,
        pointLocationWithinMiles=nothing,
        projectIdentifier=nothing,
        recordIdentifierUserSupplied=nothing)

    svc  = lowercase(String(service))
    prof = lowercase(String(profile))
    _check_profiles(svc, prof)

    query_params = Dict{String,String}("mimeType" => "text/csv")
    possible_params = Dict(
        "activityMediaName"            => activityMediaName,
        "activityStartDateLower"       => activityStartDateLower,
        "activityStartDateUpper"       => activityStartDateUpper,
        "activityTypeCode"             => activityTypeCode,
        "characteristicGroup"          => characteristicGroup,
        "characteristic"               => characteristic,
        "characteristicUserSupplied"   => characteristicUserSupplied,
        "boundingBox"                  => boundingBox,
        "countryFips"                  => countryFips,
        "stateFips"                    => stateFips,
        "countyFips"                   => countyFips,
        "siteTypeCode"                 => siteTypeCode,
        "siteTypeName"                 => siteTypeName,
        "usgsPCode"                    => usgsPCode,
        "hydrologicUnit"               => hydrologicUnit,
        "monitoringLocationIdentifier" => monitoringLocationIdentifier,
        "organizationIdentifier"       => organizationIdentifier,
        "pointLocationLatitude"        => pointLocationLatitude,
        "pointLocationLongitude"       => pointLocationLongitude,
        "pointLocationWithinMiles"     => pointLocationWithinMiles,
        "projectIdentifier"            => projectIdentifier,
        "recordIdentifierUserSupplied" => recordIdentifierUserSupplied,
    )

    for (k, v) in possible_params
        v === nothing && continue
        query_params[k] = _waterdata_query_value(v)
    end

    url      = string(_WATERDATA_BASE_URL, "/", svc, "/", prof)
    response = _custom_get(url; query_params=query_params, ssl_check=ssl_check)
    df       = DataFrame(CSV.File(IOBuffer(response.body)))
    return df, response
end

# ---------------------------------------------------------------------------
# Service-specific convenience wrappers (mirrors ReadWQP.jl pattern)
# ---------------------------------------------------------------------------

"""
    readWaterDataResults(; profile="fullphyschem", kwargs...)

Query the USGS Samples database for **measurement results**. This is a
convenience wrapper around `readWaterDataSamples` with
`service="results"` pre-set.

# Keyword Arguments
- `profile::String="fullphyschem"`: One of `"fullphyschem"`,
  `"basicphyschem"`, `"fullbio"`, `"basicbio"`, `"narrow"`,
  `"resultdetectionquantitationlimit"`, `"labsampleprep"`, or `"count"`.
- All filter keywords accepted by `readWaterDataSamples` are also accepted
  here (e.g. `monitoringLocationIdentifier`, `usgsPCode`, `stateFips`, …).

# Returns
- `df::DataFrame`: Result records.
- `response::HTTP.Messages.Response`: The raw HTTP response object.

# Examples
```jldoctest
julia> df, response = readWaterDataResults(
           profile="narrow",
           monitoringLocationIdentifier="USGS-05288705",
           activityStartDateLower="2024-10-01",
           activityStartDateUpper="2025-04-24");

julia> typeof(df)
DataFrame

julia> typeof(response)
HTTP.Messages.Response
```
"""
function readWaterDataResults(; profile="fullphyschem", kwargs...)
    return readWaterDataSamples(; service="results", profile=profile, kwargs...)
end

"""
    whatWaterDataLocations(; profile="site", kwargs...)

Query the USGS Samples database for **monitoring locations**. This is a
convenience wrapper around `readWaterDataSamples` with
`service="locations"` pre-set.

# Keyword Arguments
- `profile::String="site"`: One of `"site"` or `"count"`.
- All filter keywords accepted by `readWaterDataSamples` are also accepted
  here (e.g. `stateFips`, `usgsPCode`, `boundingBox`, …).

# Returns
- `df::DataFrame`: Location records.
- `response::HTTP.Messages.Response`: The raw HTTP response object.

# Examples
```jldoctest
julia> df, response = whatWaterDataLocations(
           stateFips="US:55",
           usgsPCode="00010",
           activityStartDateLower="2024-10-01",
           activityStartDateUpper="2025-04-24");

julia> typeof(df)
DataFrame

julia> typeof(response)
HTTP.Messages.Response
```
"""
function whatWaterDataLocations(; profile="site", kwargs...)
    return readWaterDataSamples(; service="locations", profile=profile, kwargs...)
end

"""
    whatWaterDataActivities(; profile="sampact", kwargs...)

Query the USGS Samples database for **field activities**. This is a
convenience wrapper around `readWaterDataSamples` with
`service="activities"` pre-set.

# Keyword Arguments
- `profile::String="sampact"`: One of `"sampact"`, `"actmetric"`,
  `"actgroup"`, or `"count"`.
- All filter keywords accepted by `readWaterDataSamples` are also accepted
  here (e.g. `monitoringLocationIdentifier`, `stateFips`, …).

# Returns
- `df::DataFrame`: Activity records.
- `response::HTTP.Messages.Response`: The raw HTTP response object.

# Examples
```jldoctest
julia> df, response = whatWaterDataActivities(
           monitoringLocationIdentifier="USGS-06719505");

julia> typeof(df)
DataFrame

julia> typeof(response)
HTTP.Messages.Response
```
"""
function whatWaterDataActivities(; profile="sampact", kwargs...)
    return readWaterDataSamples(; service="activities", profile=profile, kwargs...)
end

"""
    whatWaterDataProjects(; profile="project", kwargs...)

Query the USGS Samples database for **monitoring projects**. This is a
convenience wrapper around `readWaterDataSamples` with
`service="projects"` pre-set.

# Keyword Arguments
- `profile::String="project"`: One of `"project"` or
  `"projectmonitoringlocationweight"`.
- All filter keywords accepted by `readWaterDataSamples` are also accepted
  here (e.g. `stateFips`, `activityStartDateLower`, …).

# Returns
- `df::DataFrame`: Project records.
- `response::HTTP.Messages.Response`: The raw HTTP response object.

# Examples
```jldoctest
julia> df, response = whatWaterDataProjects(
           stateFips="US:15",
           activityStartDateLower="2024-10-01",
           activityStartDateUpper="2025-04-24");

julia> typeof(df)
DataFrame

julia> typeof(response)
HTTP.Messages.Response
```
"""
function whatWaterDataProjects(; profile="project", kwargs...)
    return readWaterDataSamples(; service="projects", profile=profile, kwargs...)
end

"""
    whatWaterDataOrganizations(; profile="organization", kwargs...)

Query the USGS Samples database for **organizations**. This is a
convenience wrapper around `readWaterDataSamples` with
`service="organizations"` pre-set.

# Keyword Arguments
- `profile::String="organization"`: One of `"organization"` or `"count"`.
- All filter keywords accepted by `readWaterDataSamples` are also accepted
  here (e.g. `stateFips`, `organizationIdentifier`, …).

# Returns
- `df::DataFrame`: Organization records.
- `response::HTTP.Messages.Response`: The raw HTTP response object.

# Examples
```jldoctest
julia> df, response = whatWaterDataOrganizations(stateFips="US:01");

julia> typeof(df)
DataFrame

julia> typeof(response)
HTTP.Messages.Response
```
"""
function whatWaterDataOrganizations(; profile="organization", kwargs...)
    return readWaterDataSamples(; service="organizations", profile=profile, kwargs...)
end

"""
    readWaterDataDaily(; ssl_check=true, kwargs...)

Get daily observations from the USGS WaterData OGC API (`daily` collection).

Daily values generally represent one summary value per day for each time
series (for example daily mean streamflow).

# Keyword Arguments
- `ssl_check::Bool=true`: Whether to verify SSL certificates.
- `monitoring_location_id::Union{String,Vector{String}}`: Monitoring
  location identifier(s), e.g. `"USGS-05427718"`.
- `parameter_code::Union{String,Vector{String}}`: USGS 5-digit parameter
  code(s), e.g. `"00060"`.
- `statistic_id::Union{String,Vector{String}}`: Statistic code(s), e.g.
  `"00003"` for daily mean.
- `time_series_id::Union{String,Vector{String}}`: Time-series identifier(s).
- `daily_id::Union{String,Vector{String}}`: Daily record identifier(s).
- `approval_status::Union{String,Vector{String}}`: Approval status filter,
  typically `"Approved"` or `"Provisional"`.
- `unit_of_measure::Union{String,Vector{String}}`: Units filter.
- `qualifier::Union{String,Vector{String}}`: Qualifier filter.
- `value::Union{String,Vector{String}}`: Value filter.
- `last_modified::String`: RFC3339 datetime or interval filter.
- `time::Union{String,Vector{String}}`: Time filter (datetime, interval, or
  duration string).
- `bbox::Vector{<:Real}`: Bounding box in `[xmin, ymin, xmax, ymax]`.
- `properties::Vector{String}`: Restrict returned properties to a subset.
- `skip_geometry::Bool`: If `true`, omit geometry in the response.
- `limit::Integer`: Maximum number of rows returned (default API max is used
  when omitted).

# Returns
- `df::DataFrame`: Daily observations.
- `response::HTTP.Messages.Response`: Raw HTTP response object.

# Examples
```jldoctest
julia> df, response = readWaterDataDaily(
           monitoring_location_id="USGS-05427718",
           parameter_code="00060",
           time="2025-01-01/..");

julia> typeof(df)
DataFrame

julia> typeof(response)
HTTP.Messages.Response
```
"""
function readWaterDataDaily(; ssl_check=true, kwargs...)
  return _waterdata_ogc_get("daily", "daily_id"; ssl_check=ssl_check, kwargs...)
end

"""
    readWaterDataContinuous(; ssl_check=true, kwargs...)

Get continuous observations from the USGS WaterData OGC API (`continuous`
collection).

Continuous values are high-frequency observations (often 15-minute interval
telemetry).

# Keyword Arguments
- Accepts the same filter-style keywords as `readWaterDataDaily`, including
  `monitoring_location_id`, `parameter_code`, `statistic_id`, `time`,
  `properties`, `limit`, and `ssl_check`.
- Unlike some other collections, geometry may be absent in API responses for
  continuous data.

# Returns
- `df::DataFrame`: Continuous observations.
- `response::HTTP.Messages.Response`: Raw HTTP response object.
"""
function readWaterDataContinuous(; ssl_check=true, kwargs...)
  return _waterdata_ogc_get("continuous", "continuous_id"; ssl_check=ssl_check, kwargs...)
end

"""
    whatWaterDataMonitoringLocations(; ssl_check=true, kwargs...)

Query monitoring-location metadata from the USGS WaterData OGC API
(`monitoring-locations` collection).

This endpoint returns site metadata such as agency, site type, state/county,
hydrologic unit, and geospatial attributes.

# Keyword Arguments
- `monitoring_location_id`, `agency_code`, `state_name`, `county_code`,
  `site_type_code`, `hydrologic_unit_code`, `bbox`, `properties`,
  `skip_geometry`, `limit`, and other API-supported keyword filters.
- `ssl_check::Bool=true`: Whether to verify SSL certificates.

# Returns
- `df::DataFrame`: Monitoring-location records.
- `response::HTTP.Messages.Response`: Raw HTTP response object.
"""
function whatWaterDataMonitoringLocations(; ssl_check=true, kwargs...)
  return _waterdata_ogc_get("monitoring-locations", "monitoring_location_id"; ssl_check=ssl_check, kwargs...)
end

"""
    readWaterDataTimeSeriesMetadata(; ssl_check=true, kwargs...)

Query time-series metadata from the USGS WaterData OGC API
(`time-series-metadata` collection).

Time-series metadata describe observation streams (begin/end dates, parameter,
statistic, units, and threshold metadata).

# Keyword Arguments
- Typical filters include `monitoring_location_id`, `parameter_code`,
  `time_series_id`, `begin`, `end`, `last_modified`, `bbox`, `properties`,
  `skip_geometry`, `limit`.
- `ssl_check::Bool=true`: Whether to verify SSL certificates.

# Returns
- `df::DataFrame`: Time-series metadata records.
- `response::HTTP.Messages.Response`: Raw HTTP response object.
"""
function readWaterDataTimeSeriesMetadata(; ssl_check=true, kwargs...)
  return _waterdata_ogc_get("time-series-metadata", "time_series_id"; ssl_check=ssl_check, kwargs...)
end

"""
    readWaterDataLatestContinuous(; ssl_check=true, kwargs...)

Query the most recent continuous observation for each matching time series
from the `latest-continuous` collection.

# Keyword Arguments
- Supports the same filtering style used in `readWaterDataContinuous`,
  especially `monitoring_location_id`, `parameter_code`, `time_series_id`,
  `approval_status`, `bbox`, `properties`, and `limit`.
- `ssl_check::Bool=true`: Whether to verify SSL certificates.

# Returns
- `df::DataFrame`: Latest continuous records.
- `response::HTTP.Messages.Response`: Raw HTTP response object.
"""
function readWaterDataLatestContinuous(; ssl_check=true, kwargs...)
  return _waterdata_ogc_get("latest-continuous", "latest_continuous_id"; ssl_check=ssl_check, kwargs...)
end

"""
    readWaterDataLatestDaily(; ssl_check=true, kwargs...)

Query the most recent daily observation for each matching time series from
the `latest-daily` collection.

# Keyword Arguments
- Supports the same filtering style used in `readWaterDataDaily`, especially
  `monitoring_location_id`, `parameter_code`, `time_series_id`,
  `approval_status`, `bbox`, `properties`, and `limit`.
- `ssl_check::Bool=true`: Whether to verify SSL certificates.

# Returns
- `df::DataFrame`: Latest daily records.
- `response::HTTP.Messages.Response`: Raw HTTP response object.
"""
function readWaterDataLatestDaily(; ssl_check=true, kwargs...)
  return _waterdata_ogc_get("latest-daily", "latest_daily_id"; ssl_check=ssl_check, kwargs...)
end

"""
    readWaterDataFieldMeasurements(; ssl_check=true, kwargs...)

Query field-measurement observations from the USGS WaterData OGC API
(`field-measurements` collection).

Field measurements are low-frequency site visits (for example discharge
measurements and groundwater-level checks), often used for calibration and
validation of continuous records.

# Keyword Arguments
- Typical filters include `monitoring_location_id`, `parameter_code`,
  `observing_procedure_code`, `field_visit_id`, `approval_status`, `time`,
  `bbox`, `properties`, `skip_geometry`, `limit`.
- `ssl_check::Bool=true`: Whether to verify SSL certificates.

# Returns
- `df::DataFrame`: Field-measurement records.
- `response::HTTP.Messages.Response`: Raw HTTP response object.
"""
function readWaterDataFieldMeasurements(; ssl_check=true, kwargs...)
  return _waterdata_ogc_get("field-measurements", "field_measurement_id"; ssl_check=ssl_check, kwargs...)
end

"""
    readWaterDataReferenceTable(collection; query=Dict(), ssl_check=true)

Fetch a WaterData metadata reference table from the OGC API.

Reference tables provide allowable values used across WaterData filters.

# Arguments
- `collection::String`: One supported collection name. Available values are:
  `"agency-codes"`, `"altitude-datums"`, `"aquifer-codes"`,
  `"aquifer-types"`, `"coordinate-accuracy-codes"`,
  `"coordinate-datum-codes"`, `"coordinate-method-codes"`, `"counties"`,
  `"hydrologic-unit-codes"`, `"medium-codes"`,
  `"national-aquifer-codes"`, `"parameter-codes"`,
  `"reliability-codes"`, `"site-types"`, `"states"`,
  `"statistic-codes"`, `"topographic-codes"`, `"time-zone-codes"`.

# Keyword Arguments
- `query::AbstractDict=Dict()`: Additional API query parameters
  (for example `Dict("id" => "AK001,AK008")`).
- `ssl_check::Bool=true`: Whether to verify SSL certificates.

# Returns
- `df::DataFrame`: Reference table rows.
- `response::HTTP.Messages.Response`: Raw HTTP response object.
"""
function readWaterDataReferenceTable(collection; query=Dict{String,Any}(), ssl_check=true)
  c = lowercase(String(collection))
  if c ∉ _WATERDATA_METADATA_COLLECTIONS
    throw(ArgumentError(
      "Invalid collection: '$c'. " *
      "Valid options are: $(sort(collect(_WATERDATA_METADATA_COLLECTIONS)))"
    ))
  end

  output_id = if endswith(c, "s") && c != "counties"
    replace(chop(c), "-" => "_")
  elseif c == "counties"
    "county"
  else
    replace(c, "-" => "_")
  end

  return _waterdata_ogc_get(c, output_id; ssl_check=ssl_check, _extra_query=query)
end

"""
    readWaterDataStatsPOR(; ssl_check=true, expandPercentiles=true, kwargs...)

Query period-of-record statistics from the WaterData statistics API
(`observationNormals`).

This endpoint provides historical summary statistics such as minimum,
maximum, median, arithmetic mean, and percentile values over period-of-record
groupings.

# Keyword Arguments
- `expandPercentiles::Bool=true`: When `true`, percentile list values are
  expanded into row-level values where possible and helper percentile values
  are assigned for `minimum`/`median`/`maximum` rows.
- Common filters include `monitoring_location_id`, `parameter_code`,
  `computation_type`, `start_date`, `end_date`, `state_code`, `county_code`,
  `site_type_code`, `site_type_name`, `page_size`.
- `ssl_check::Bool=true`: Whether to verify SSL certificates.

# Returns
- `df::DataFrame`: Statistics records.
- `response::HTTP.Messages.Response`: Raw HTTP response object.
"""
function readWaterDataStatsPOR(; ssl_check=true, expandPercentiles=true, kwargs...)
  return _waterdata_stats_get("observationNormals";
                ssl_check=ssl_check,
                expand_percentiles=expandPercentiles,
                kwargs...)
end

"""
    readWaterDataStatsDateRange(; ssl_check=true, expandPercentiles=true, kwargs...)

Query interval-based statistics from the WaterData statistics API
(`observationIntervals`).

This endpoint provides month/year and water-year style statistical summaries
for selected monitoring locations and parameter codes.

# Keyword Arguments
- `expandPercentiles::Bool=true`: Same percentile expansion behavior as
  `readWaterDataStatsPOR`.
- Common filters include `monitoring_location_id`, `parameter_code`,
  `computation_type`, `start_date`, `end_date`, `state_code`, `county_code`,
  `site_type_code`, `site_type_name`, `page_size`.
- `ssl_check::Bool=true`: Whether to verify SSL certificates.

# Returns
- `df::DataFrame`: Statistics records.
- `response::HTTP.Messages.Response`: Raw HTTP response object.
"""
function readWaterDataStatsDateRange(; ssl_check=true, expandPercentiles=true, kwargs...)
  return _waterdata_stats_get("observationIntervals";
                ssl_check=ssl_check,
                expand_percentiles=expandPercentiles,
                kwargs...)
end

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

function _waterdata_ogc_get(service::String, output_id::String; ssl_check=true, kwargs...)
  url = string(_WATERDATA_OGC_BASE_URL, "/collections/", service, "/items")
  query_params = Dict{String,String}()

  extra_query = nothing
  if haskey(kwargs, :_extra_query)
    extra_query = kwargs[:_extra_query]
  end

  for (k, v) in kwargs
    k == :_extra_query && continue
    v === nothing && continue
    key = String(k)
    if key == "bbox" && v isa AbstractVector
      query_params[key] = join(string.(v), ",")
    elseif key == "properties" && v isa AbstractVector
      query_params[key] = join(string.(v), ",")
    elseif key == "skip_geometry"
      query_params["skipGeometry"] = lowercase(string(v))
    else
      query_params[key] = _waterdata_query_value(v)
    end
  end

  if haskey(query_params, "limit") == false
    query_params["limit"] = "50000"
  end

  if extra_query isa AbstractDict
    for (k, v) in extra_query
      query_params[String(k)] = _waterdata_query_value(v)
    end
  end

  response = _custom_get(url; query_params=query_params, ssl_check=ssl_check)
  parsed = JSON.parse(String(response.body))
  df = _waterdata_flatten_ogc_features(parsed)
  _waterdata_rename_id!(df, output_id)
  _waterdata_cast_columns!(df)
  return df, response
end

function _waterdata_flatten_ogc_features(parsed)
  features = get(parsed, "features", Any[])
  rows = Vector{Dict{Symbol,Any}}()
  for feat in features
    row = Dict{Symbol,Any}()
    props = get(feat, "properties", Dict{String,Any}())
    for (k, v) in props
      row[Symbol(replace(String(k), "-" => "_"))] = v
    end
    if haskey(feat, "id")
      row[:id] = feat["id"]
    end
    if haskey(feat, "geometry") && feat["geometry"] !== nothing
      row[:geometry] = feat["geometry"]
    end
    push!(rows, row)
  end

  return isempty(rows) ? DataFrame() : DataFrame(rows)
end

function _waterdata_rename_id!(df::DataFrame, output_id::String)
  if :id in names(df)
    rename!(df, :id => Symbol(output_id))
  elseif "id" in names(df)
    rename!(df, "id" => output_id)
  end
  return df
end

function _waterdata_cast_columns!(df::DataFrame)
  isempty(df) && return df

  numeric_cols = Set([
    "altitude",
    "altitude_accuracy",
    "contributing_drainage_area",
    "drainage_area",
    "hole_constructed_depth",
    "value",
    "well_constructed_depth",
  ])
  date_cols = Set([
    "begin",
    "begin_utc",
    "construction_date",
    "end",
    "end_utc",
    "last_modified",
    "time",
  ])

  for c in names(df)
    col_name = lowercase(string(c))
    if col_name in numeric_cols
      df[!, c] = map(x -> tryparse(Float64, string(x)), df[!, c])
    elseif col_name in date_cols
      df[!, c] = map(x -> _waterdata_try_datetime(x), df[!, c])
    end
  end
  return df
end

function _waterdata_try_datetime(x)
  x === missing && return missing
  s = string(x)
  for fmt in (dateformat"yyyy-mm-ddTHH:MM:SSZ", dateformat"yyyy-mm-ddTHH:MM:SS", dateformat"yyyy-mm-dd")
    dt = tryparse(DateTime, s, fmt)
    dt === nothing || return dt
  end
  return missing
end

function _waterdata_stats_get(endpoint::String; ssl_check=true, expand_percentiles=true, kwargs...)
  url = string(_WATERDATA_STATS_BASE_URL, "/", endpoint)
  query_params = Dict{String,String}()
  for (k, v) in kwargs
    v === nothing && continue
    query_params[String(k)] = _waterdata_query_value(v)
  end

  response = _custom_get(url; query_params=query_params, ssl_check=ssl_check)
  parsed = JSON.parse(String(response.body))
  df = _waterdata_flatten_stats(parsed)

  if expand_percentiles
    computation_col = _waterdata_find_column(df, "computation")
    if computation_col !== nothing
      percentile_col = _waterdata_find_column(df, "percentile")
      if percentile_col === nothing
        df[!, "percentile"] = Vector{Union{Missing,Float64}}(missing, nrow(df))
        percentile_col = "percentile"
      end

      for i in 1:nrow(df)
        comp = lowercase(string(df[i, computation_col]))
        if comp == "minimum"
          df[i, percentile_col] = 0.0
        elseif comp == "median"
          df[i, percentile_col] = 50.0
        elseif comp == "maximum"
          df[i, percentile_col] = 100.0
        end
      end
    end
  end

  return df, response
end

function _waterdata_find_column(df::DataFrame, target::String)
  target_lower = lowercase(target)
  for c in names(df)
    if lowercase(string(c)) == target_lower
      return c
    end
  end
  return nothing
end

function _waterdata_flatten_stats(parsed)
  features = get(parsed, "features", Any[])
  rows = Vector{Dict{Symbol,Any}}()

  for feat in features
    props = get(feat, "properties", Dict{String,Any}())
    geom = get(feat, "geometry", nothing)
    data_entries = get(props, "data", Any[])

    if isempty(data_entries)
      row = Dict{Symbol,Any}()
      for (k, v) in props
        if k == "data"
          continue
        end
        row[Symbol(replace(String(k), "-" => "_"))] = v
      end
      if geom !== nothing
        row[:geometry] = geom
      end
      push!(rows, row)
      continue
    end

    for item in data_entries
      item_vals = get(item, "values", Any[])
      percentiles = get(item, "percentiles", Any[])

      if item_vals isa AbstractVector && !isempty(item_vals)
        for (j, val) in enumerate(item_vals)
          row = Dict{Symbol,Any}()
          for (k, v) in props
            if k == "data"
              continue
            end
            row[Symbol(replace(String(k), "-" => "_"))] = v
          end
          for (k, v) in item
            if k in ("values", "percentiles")
              continue
            end
            row[Symbol(replace(String(k), "-" => "_"))] = v
          end
          row[:value] = val
          if percentiles isa AbstractVector && j <= length(percentiles)
            row[:percentile] = percentiles[j]
          end
          if geom !== nothing
            row[:geometry] = geom
          end
          push!(rows, row)
        end
      else
        row = Dict{Symbol,Any}()
        for (k, v) in props
          if k == "data"
            continue
          end
          row[Symbol(replace(String(k), "-" => "_"))] = v
        end
        for (k, v) in item
          row[Symbol(replace(String(k), "-" => "_"))] = v
        end
        if geom !== nothing
          row[:geometry] = geom
        end
        push!(rows, row)
      end
    end
  end

  return isempty(rows) ? DataFrame() : DataFrame(rows)
end

function _check_profiles(service, profile)
    if service ∉ _WATERDATA_SERVICES
        throw(ArgumentError(
            "Invalid service: '$service'. " *
            "Valid options are: $(sort(collect(_WATERDATA_SERVICES)))"
        ))
    end
    valid_profiles = _WATERDATA_PROFILE_LOOKUP[service]
    if profile ∉ valid_profiles
        throw(ArgumentError(
            "Invalid profile: '$profile' for service '$service'. " *
            "Valid options are: $(sort(collect(valid_profiles)))"
        ))
    end
end

function _waterdata_query_value(v)
    v isa AbstractVector ? join(string.(v), ",") : string(v)
end
