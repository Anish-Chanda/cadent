# Planned Activity Creation E2E Tests

POST http://localhost:8080/api/signup
Content-Type: application/json
[Options]
variable: plan_uuid={{newUuid}}
variable: plan_email=plantest-{{plan_uuid}}@test.com
{
    "user": "{{plan_email}}",
    "passwd": "CreateTest123!",
    "name": "Activity Creator"
}
HTTP 201

POST http://localhost:8080/api/auth/local/login
[Form]
user: {{plan_email}}
passwd: CreateTest123!
HTTP 200
[Asserts]
cookie "JWT" exists

POST http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "title": "Riverside Tempo Ride",
  "description": "Maintain steady power on the flat sections. Focus on aerobic capacity.",
  "activityType": "road_bike",
  "startTime": "2026-03-10T07:30:00Z",
  "plannedDistanceMeter": 25000,
  "plannedDurationSecond": 3600,
  "plannedElevationGainMeter": 120,
  "targetAverageSpeedMeterPerSecond": 6.94,
  "targetPowerWatt": 185
}
HTTP 201
[Asserts]
jsonpath "$.status" == "success"