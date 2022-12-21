if defined mainWasStarted {

set terminal:width to 48.
set terminal:height to 14.

local plandDone to false.

local wantSpeed to 0.0.
local onceUnderTime to false.

local stopEnginesUnder to 0.7.
local avoidEnginesStopUnderTime to 15.

set burnHeight to 0.0.

if(ship:body:name = "Kerbin") {
}

clearScreen.
print "Powered landing v3.1.2".
print "Ready.".
wait 0.

set lt to 0.
set lt2 to 0.

WHEN not plandDone THEN {
    set lt to lt + 1.
    set lt2 to lt2 + 1.
    if (lt > 2) {
        set lt to 0.
    }
    if (lt2 > 10) {
        set lt2 to 0.
    }

    return true.
}

local currentDeltaV to SHIP:STAGEDELTAV(SHIP:STAGENUM):CURRENT.
local lastMass to ship:mass.
local startDeltaV to 0.
local startTank to 0.
when ((currentDeltaV > SHIP:STAGEDELTAV(SHIP:STAGENUM):CURRENT and round(SHIP:STAGEDELTAV(SHIP:STAGENUM):CURRENT,0) > 0) or round(currentDeltaV,0) = 0) and lt = 0 then {
    set currentDeltaV to SHIP:STAGEDELTAV(SHIP:STAGENUM):CURRENT.
    set startDeltaV to currentDeltaV.
    set startTank to stage:resourcesLex["LiquidFuel"]:amount.
    set lastMass to ship:mass.
    return true.
}

when lt = 0 then {
    print "S-Speed       : " + round(ship:velocity:surface:mag, 0) + "m/s     " at (2, 6).
    print "V-Speed       : " + round(ship:verticalspeed * -1.0, 0) + "m/s     " at (2, 7).
    print "Tank          : " + round(stage:resourcesLex["LiquidFuel"]:amount, 0) +" ("+ round(currentDeltaV, 0) + "m/s dV)     " at (2, 10).
    if(not plandDone) return true.
}


wait until ship:verticalspeed < startPowerlandWithVSpeed and ship:status = "SUB_ORBITAL".
local bottomAlt to ship:bounds:bottomaltradar.
set currentDeltaV to currentDeltaV / (1/lastMass * ship:mass).
set startDeltaV to currentDeltaV.
set startTank to stage:resourcesLex["LiquidFuel"]:amount.

when ship:deltaV:current > 0 and lt = 0 then {
    set currentDeltaV to ship:deltaV:current.
    set startDeltaV to currentDeltaV.
    set startTank to stage:resourcesLex["LiquidFuel"]:amount.
    if(not plandDone) return true.
} 

function timeToImpactCalc {
    return bottomAlt / ship:verticalspeed * -1.0.
}
local timeToImpact to timeToImpactCalc().

function isStartBurnCalc {
    declare local vs to ship:verticalspeed * -1.0.
    return bottomAlt < burnHeight + vs.
}
local isStartBurn to isStartBurnCalc().

when lt = 0 then {
    set currentDeltaV to startDeltaV * (1 / startTank * stage:resourcesLex["LiquidFuel"]:amount).
    set isStartBurn to isStartBurnCalc().
    set timeToImpact to timeToImpactCalc().
    
    print "Time to impact: " + round(timeToImpact, 0)            + "s     " at (2, 3).
    print "Alt           : " + round(bottomAlt, 0)                 + "m     " at (2, 5).

    if(ship:availablethrust <= 0 or ship:verticalspeed > 0) {
        set burnHeight to 0.
        if(not plandDone) return true.
    }
    
	declare local surSpeed to ship:velocity:surface:mag.
    declare local vs to ship:verticalspeed * -1.0.
    declare local a to accel() - g().
    declare local speed to sqrt(vs^2 + surSpeed^2) / 3 + (vs / 3) * 2.

    if (accel() / g() > 3.0) {
        set a to a * ((1.0 / (accel() / g())) * 3.0).
    }

    if(speed > currentDeltaV or a < 0.0) {
        if(ship:body:atm:exists) {
            print "(!) ATM break : ...let ATM do the job " at (2, 4).
            set burnHeight to 0.
        } else {
            declare dvh to currentDeltaV / (accel() - g()) * (speed * -1.0). 
            set burnHeight to dvh.
            print "(!) Burn Alt  : " + round(dvh, 0) + "m                    " at (2, 4).
        }

        if(not plandDone) return true.
    }

    declare local bh to ((speed^2) / (2*a)).

    print "Burn Alt      : " + round(bh, 0)              + "m                " at (2, 4).

    set burnHeight to bh.
    if(not plandDone) return true.
}

WHEN lt2 = 0 THEN {
    set bottomAlt to ship:bounds:bottomaltradar.

    if(not plandDone) return true.
}

when not plandDone and lt = 0 then {
    lock steering to ship:srfretrograde.
    set SAS to false.
    set brakes to ship:body:atm:exists.
}

when not plandDone and ship:body:atm:exists and ship:altitude < ship:body:atm:height then {
    set ag2 to false.
}

when not plandDone and bottomAlt < 10 then {
    lock steering to up.
}

when not plandDone and bottomAlt < (ship:verticalspeed * -1) * 7.0 and not gear then {
    toggle gear.
}

when lt = 0 and not onceUnderTime and isStartBurn then { // breaking
    set wantSpeed to 1.0.
    set onceUnderTime to true.

    print "Throttle ^    : " + round(wantSpeed * 100, 0) + "%     " at (2, 12).
    lock throttle to wantSpeed.

    if(not plandDone) return true.
}
when onceUnderTime and lt = 0  then { // landing
    if (ship:verticalspeed >= -0.1 or timeToImpact < 0.05) {
        set wantSpeed to 0.
        set plandDone to true.
    } else {
        if (burnHeight <= 0.0001) set wantSpeed to 0.
        else set wantSpeed to 1.0 / bottomAlt * burnHeight.
    }

    if (wantSpeed < stopEnginesUnder and avoidEnginesStopUnderTime < timeToImpact) {
        set wantSpeed to 0.
        set onceUnderTime to false.
    }

    print "Throttle v    : " + round(wantSpeed * 100, 0) + "%     " at (2, 12).
    lock throttle to wantSpeed.

    if(not plandDone) return true.
}

wait until plandDone or ship:availablethrust <= 0.0.
lock throttle to 0.
wait 0.1.
unlock steering.
unlock throttle.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
SAS on.

clearScreen.
wait 0.1.
if (ship:availablethrust <= 0.0) {
    print "Thrusters lost.".
} else {
    print "Landed.".
    set brakes to false.
}
wait 5.0.

} else {
    copyPath("0:/boot/main", "1:/boot/main").
    run "boot/main".
}
