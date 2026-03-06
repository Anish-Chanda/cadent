# Activity Upload E2E Tests - POST /api/v1/activities/upload
#
# Test data:
#   tests/mcfarland_bike_ride.gpx        — Real Strava export (road bike); embedded <ele>, type=cycling
#                                          Strava reference values: 11.05 km, 35:12 elapsed, 97 m elevation gain
#   tests/campus_loop_220pts_var_time.gpx — Synthetic GPX (created with online tools); no elevation,
#                                           type=run, triggers Valhalla elevation enrichment
#   tests/Morning_Run.fit                - Real Strava export (run); embedded <ele>, type=run
#                                          Strava reference values: 7.08 km, 29:58 elapsed, 106 m elevation gain
#

POST http://localhost:8080/api/v1/activities/upload
[Multipart]
file: file,tests/mcfarland_bike_ride.gpx; application/octet-stream
HTTP 401

POST http://localhost:8080/api/signup
Content-Type: application/json
{
    "user": "upload_e2e_{{now}}@test.com",
    "passwd": "UploadTest123!",
    "name": "Upload E2E Tester"
}
HTTP 201

POST http://localhost:8080/api/auth/local/login
[Form]
user: upload_e2e_{{now}}@test.com
passwd: UploadTest123!
HTTP 200

# Test 1: GPX with embedded elevation, no enrichment
POST http://localhost:8080/api/v1/activities/upload
[Multipart]
file: file,tests/mcfarland_bike_ride.gpx; application/octet-stream
enrich: false
HTTP 201
[Captures]
mcfarland_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

GET http://localhost:8080/api/v1/activities
HTTP 200
[Asserts]
jsonpath "$.activities" count == 1
jsonpath "$.activities[0].id" == "{{mcfarland_id}}"
jsonpath "$.activities[0].type" == "road_bike"
jsonpath "$.activities[0].title" == "Bike ride to McFarland"
jsonpath "$.activities[0].description" == ""
# Strava reference: 97 m gain; our threshold-based calc is close but not identical
jsonpath "$.activities[0].stats.elevation_gain_m" > 90
jsonpath "$.activities[0].stats.elevation_gain_m" < 120
jsonpath "$.activities[0].stats.elevation_loss_m" > 70
jsonpath "$.activities[0].stats.elevation_loss_m" < 130
jsonpath "$.activities[0].stats.max_height_m" > 290
jsonpath "$.activities[0].stats.max_height_m" < 315
jsonpath "$.activities[0].stats.min_height_m" > 270
jsonpath "$.activities[0].stats.min_height_m" < 285
# Strava reference: 11.05 km; haversine may differ slightly
jsonpath "$.activities[0].stats.distance_m" > 10950
jsonpath "$.activities[0].stats.distance_m" < 11200
# Strava reference shows 35:12 **moving time**; we store total GPS elapsed (includes pauses) ~42:24
jsonpath "$.activities[0].stats.elapsed_seconds" > 2520
jsonpath "$.activities[0].stats.elapsed_seconds" < 2570
# avg speed based on total elapsed, not moving time: ~11050 m / 2544 s ≈ 4.3 m/s
jsonpath "$.activities[0].stats.avg_speed_ms" > 4.0
jsonpath "$.activities[0].stats.avg_speed_ms" < 5.5
jsonpath "$.activities[0].stats.derived.speed_kmh" > 14
jsonpath "$.activities[0].stats.derived.speed_kmh" < 20
jsonpath "$.activities[0].stats.derived.distance_km" > 10.8
jsonpath "$.activities[0].stats.derived.distance_km" < 11.4
jsonpath "$.activities[0].bbox.min_lat" exists
jsonpath "$.activities[0].bbox.max_lat" exists
jsonpath "$.activities[0].bbox.min_lon" exists
jsonpath "$.activities[0].bbox.max_lon" exists
jsonpath "$.activities[0].start.lat" exists
jsonpath "$.activities[0].start.lon" exists
jsonpath "$.activities[0].polyline" exists

GET http://localhost:8080/api/v1/activities/{{mcfarland_id}}/streams?lod=medium&type=time,distance,elevation,speed
HTTP 200
[Asserts]
jsonpath "$.activity_id" == "{{mcfarland_id}}"
jsonpath "$.lod" == "medium"
jsonpath "$.index_by" == "distance"
jsonpath "$.num_points" > 0
jsonpath "$.original_num_points" > 0
jsonpath "$.streams" count == 4

# Test 2: GPX without elevation, enrich=true triggers Valhalla, title override applied
POST http://localhost:8080/api/v1/activities/upload
[Multipart]
file: file,tests/campus_loop_220pts_var_time.gpx; application/octet-stream
enrich: true
title: My Campus Run
HTTP 201
[Captures]
campus_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

GET http://localhost:8080/api/v1/activities
HTTP 200
[Asserts]
jsonpath "$.activities" count == 2
jsonpath "$.activities[0].id" == "{{campus_id}}"
jsonpath "$.activities[0].type" == "run"
jsonpath "$.activities[0].title" == "My Campus Run"
jsonpath "$.activities[0].stats.elevation_gain_m" > 0
jsonpath "$.activities[0].stats.elevation_loss_m" > 0
jsonpath "$.activities[0].stats.max_height_m" > 0
jsonpath "$.activities[0].stats.distance_m" > 2200
jsonpath "$.activities[0].stats.distance_m" < 2400
jsonpath "$.activities[0].stats.elapsed_seconds" > 400
jsonpath "$.activities[0].stats.derived.pace_s_per_km" > 0
jsonpath "$.activities[0].stats.derived.distance_km" > 2

GET http://localhost:8080/api/v1/activities/{{campus_id}}/streams?lod=medium&type=time,distance,elevation,speed
HTTP 200
[Asserts]
jsonpath "$.activity_id" == "{{campus_id}}"
jsonpath "$.lod" == "medium"
jsonpath "$.index_by" == "distance"
jsonpath "$.num_points" > 0
jsonpath "$.original_num_points" > 0
jsonpath "$.streams" count == 4

# Test 3: Unsupported file extension rejected
POST http://localhost:8080/api/v1/activities/upload
[Multipart]
file: file,tests/campus_loop_220pts.json; application/octet-stream
HTTP 400

# Test 4: Missing file field rejected
POST http://localhost:8080/api/v1/activities/upload
[Multipart]
enrich: false
HTTP 400

# Test 5: FIT with embedded elevation, enrich=false
POST http://localhost:8080/api/v1/activities/upload
[Multipart]
file: file,tests/Morning_Run.fit; application/octet-stream
enrich: false
HTTP 201
[Captures]
run_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

GET http://localhost:8080/api/v1/activities
HTTP 200
[Asserts]
jsonpath "$.activities" count == 3
jsonpath "$.activities[0].id" == "{{run_id}}"
jsonpath "$.activities[0].type" == "run"
jsonpath "$.activities[0].description" == ""
# Strava reference: 106 m gain; our threshold-based calc is close but not identical
jsonpath "$.activities[0].stats.elevation_gain_m" > 90
jsonpath "$.activities[0].stats.elevation_gain_m" < 120
jsonpath "$.activities[0].stats.elevation_loss_m" > 70
jsonpath "$.activities[0].stats.elevation_loss_m" < 130
# Strava reference: 7.08 km; haversine may differ slightly
jsonpath "$.activities[0].stats.distance_m" > 6950
jsonpath "$.activities[0].stats.distance_m" < 7200
# Strava reference shows 29:58 **moving time**;
jsonpath "$.activities[0].stats.elapsed_seconds" > 2000
jsonpath "$.activities[0].stats.elapsed_seconds" < 2200
jsonpath "$.activities[0].bbox.min_lat" exists
jsonpath "$.activities[0].bbox.max_lat" exists
jsonpath "$.activities[0].bbox.min_lon" exists
jsonpath "$.activities[0].bbox.max_lon" exists
jsonpath "$.activities[0].start.lat" exists
jsonpath "$.activities[0].start.lon" exists
jsonpath "$.activities[0].polyline" exists

GET http://localhost:8080/api/v1/activities/{{run_id}}/streams?lod=medium&type=time,distance,elevation,speed
HTTP 200
[Asserts]
jsonpath "$.activity_id" == "{{run_id}}"
jsonpath "$.lod" == "medium"
jsonpath "$.index_by" == "distance"
jsonpath "$.num_points" > 0
jsonpath "$.original_num_points" > 0
jsonpath "$.streams" count == 4