
if defined mainWasStarted {
    
set terminal:width to 48.
set terminal:height to 24.

global targetOrbit to 80000.
global maxQ to 0.2.
global minTimeToApoapsis to 10.
global maxTimeToApoapsis to 60.
global ag2DeployAt to 74000.
global powerLandFuelPercentage to 0.1.
global ignoredSolidFuel to 100.
global waitTimeBetweenStages to 2.

if (ship:body:name = "Appolo-12") {
    set targetOrbit to 20000.
}
if (ship:body:name = "Appolo-12") {
    set targetOrbit to 10000.
    global maxTimeToApoapsis to 90.
}

global apoapsisReached to false.
function isApoapsisReached {
    set apoapsisReached to apoapsisReached or ship:apoapsis >= targetOrbit.
    return apoapsisReached.
}

clearscreen.
print "Start v1.2.2".
global targetAngle to 0.0.
global startInFlight to ship:velocity:surface:mag > 100.
global orbitDone to startInFlight and isApoapsisReached().

if (not startInFlight) {
    SAS on.
    if(ship:status = "PRELAUNCH") lock throttle to 1.0.
    print "Wait for flight start.".
}

wait until ship:verticalspeed > 5.

local powerLandFuel to round(stage:resourcesLex["LiquidFuel"]:capacity * powerLandFuelPercentage, 0).
local corePos to 5.
WHEN not orbitDone and not isApoapsisReached() and not startInFlight THEN {

    set powerLandFuel to round(stage:resourcesLex["LiquidFuel"]:capacity * powerLandFuelPercentage, 0).

    PRINT "TWR    : " + round(twr(), 2) + "    " at (0, corePos).
    PRINT "L-Fuel : " + round(stage:resourcesLex["LiquidFuel"]:amount - powerLandFuel, 0) + "    " at (0, corePos + 1).
    PRINT "S-Fuel : " + round(stage:resourcesLex["SolidFuel"]:amount, 0) + "    " at (0, corePos + 2).
    
    PRINT "Speed  : " + round(ship:velocity:orbit:mag, 1) + "m/s     " at (20, corePos).
    PRINT "V-Speed: " + round(ship:verticalspeed, 1) + "m/s     " at (20, corePos + 1).
    PRINT "H-Speed: " + round(ship:groundspeed, 1) + "m/s     " at (20, corePos + 2).

    local orbVel to sqrt(body:mu / (body:radius + targetOrbit)) - ship:velocity:orbit:mag.
    PRINT "Delta-V: " + round(orbVel, 1) + "m/s  " at (0, corePos + 3).
    PRINT "Rest   : " + round(ship:deltaV:current - orbVel, 1) + "m/s    " at (20, corePos + 3).

    return true.
}

if (not startInFlight) {
    wait until ship:verticalspeed > 2.
    print "Flight startet.".

    SAS off.
    wait 0.
}

when ship:body:atm:exists and ship:altitude > ag2DeployAt and not ag2 then {
    set ag2 to true.
    return true.
}
when ship:body:atm:exists and ship:altitude < ag2DeployAt and ag2 then {
    set ag2 to false.
    return true.
}
when alt:radar > 100 and gear then {
    set gear to false.
}

local burnPos to 15.
print "--== Burning ==--" at (0, burnPos).
print "Multipliers:" at (2, burnPos+3).
when not orbitDone and 
    not startInFlight and 
    stage:resourcesLex["LiquidFuel"]:amount <= (0.025+powerLandFuel) and 
    (stage:resourcesLex["SolidFuel"]:amount - ignoredSolidFuel) <= 0.025 and 
    ship:stagenum > 0
then {

    print "Stage " + ship:stagenum + " at " + round(alt:radar, 2) at (2, burnPos + 1).
    lock throttle to 0.
    set oldThrottle to 1.0.
    list engines in MyList.
    FOR e IN MyList {  set e:THRUSTLIMIT to 100. }
    wait 0.5.
    stage.
    wait waitTimeBetweenStages.
    
    return true.
}

local oldThrottle to 1.0.
local thrusterLimit to 100.0.
when not orbitDone and not startInFlight then {
    if(isApoapsisReached()) {
        print "Throttle: apoapsis reached         " at (2, burnPos + 2).
        
        lock throttle to 0.
        list engines in MyList.
        FOR e IN MyList {  set e:THRUSTLIMIT to 100. }

        wait 0.
        unlock throttle.
        SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
        return false.
    }

    local newThrottle to 0.0.

    if(not isApoapsisReached()) {
        set newThrottle to 1.0. 

        local hgtAddPercent to 0.0.
        if (eta:apoapsis < minTimeToApoapsis) {
            set hgtAddPercent to max(0.0, 1.0 - (1.0 / minTimeToApoapsis * eta:apoapsis)).
        }
        print "min-T to apoapsis  : " + round((1.0+hgtAddPercent) * 100.0, 0) + "% "  at (4, burnPos + 4).
        set maxApoPower to 1.0.
        if (eta:apoapsis > maxTimeToApoapsis) {
            set maxApoPower to 1.0 - (max(0.0, (1.0 / 10.0) / maxTimeToApoapsis * 10.0 * eta:apoapsis) - 1.0).
        }
        set newThrottle to newThrottle * maxApoPower.
        print "max-T to apoapsis  : " + round(maxApoPower * 100.0, 0) + "% "  at (4, burnPos + 5).
        set newThrottle to newThrottle + hgtAddPercent. 

        local pressPercent to min(1.0, max(0.0, 1.0 - ((1.0 / maxQ * ship:dynamicpressure) - 1.0))).
        print "pressure           : " + round(pressPercent * 100.0, 0) + "% " at (4, burnPos + 6).
        print "(" + round(ship:dynamicpressure, 4) + "atm)      " at (30, burnPos + 6). 
        set newThrottle to newThrottle * pressPercent.
    }

    set newThrottle to (oldThrottle * 3.0 + newThrottle) / 4.0.
    set oldThrottle to newThrottle.

    lock throttle to newThrottle.
    print "Throttle: " + round(newThrottle * 100.0, 0) + "%  " at (2, burnPos + 2).

    set thrusterLimit to max(0.5, (thrusterLimit * 15.0 + newThrottle * 100.0) / 16.0).
    list engines in MyList.
    FOR e IN MyList {  set e:THRUSTLIMIT to thrusterLimit. }
    print "Limit: " + round(thrusterLimit, 0) + "%  " at (20, burnPos + 2).

    wait 0.
    return true.
}

local mySteering to heading(startDirection, 90, -90).
if (not startInFlight) LOCK steering TO mySteering.
local steeringPos to 10.
print "--== STEERING ==--" at (0, steeringPos).
WHEN not orbitDone and not startInFlight THEN {
    local speed to SHIP:VELOCITY:SURFACE:MAG.
    local apoPercent to 1.0 / targetOrbit * ship:apoapsis.
    local angle to 90.0 - ((90.0 - targetAngle) * apoPercent).
    print "Speed: " + round(speed, 1) + "m/s" at (2, steeringPos + 1).

    if(isApoapsisReached()) {
        print "Steering: apoapsis reached          "  at (2, steeringPos + 2).
        lock steering to ship:prograde.
        return false.
    }
    
    set mySteering TO heading(startDirection, angle, -90).
    print "Steering:" + round(angle, 2) at (2, steeringPos + 2).
    
    wait 0.
    return true.
}

print "Ready.".
wait until apoapsisReached or startInFlight.
//core:part:getmodule("kOSProcessor"):doevent("Close Terminal").
wait 0.5.

if (not orbitDone) {
    clearScreen.
    print "Orbital mode.".
    print "Wait for manouver...".

    set needVelocity to sqrt(body:mu / (body:radius + targetOrbit)).
    LOCAL timeToApoapsis to time:seconds + eta:apoapsis.
    LOCAL velcityAtAposis to velocityAt(ship, timeToApoapsis):ORBIT:MAG.
    set restVelocity to needVelocity - velcityAtAposis.

    set orbitalNode to node(timeToApoapsis, 0, 0, restVelocity).
    add orbitalNode.
}

set orbitDone to true.
run exec.

} else {
    copyPath("0:/boot/main", "1:/boot/main").
    run "boot/main".
}
