if defined mainWasStarted {

set terminal:width to 48.
set terminal:height to 24.

global minThustPercent is 0.1.
global burnDone is true.
global oldDeltaV to 0.
global beginManouverAt to 60.
global inManouver to false.
local execDone to false.

clearScreen.
print "Node execution v1.0.1".
print "Ready.".

function isFuelEmpy {
    return stage:resourcesLex["LiquidFuel"]:amount <= 0.025 and stage:resourcesLex["SolidFuel"]:amount <= 0.025.
}

function getBurnDuration {
    local manouver to nextNode.
    return manouver:deltav:mag / (max(0.0001, ship:availablethrust) / ship:mass).
}

function printNode {
    local n is nextNode.
    local e is n:eta-getBurnDuration()/2.
    if(inManouver) set e to n:eta.
    print "Node: " + round(e)+"s  r:"+round(n:radialout,2)+ "   n:"+ round(n:normal,2) + "   p:"+round(n:prograde, 2) at (2, 11).
}

when not execDone and not hasNode then {
    print "No manouver planned.       " at (2, 10).
    wait 1.
    return true.
}

when hasNode and burnDone and not inManouver and (nextNode:eta > getBurnDuration() / 2.0 + beginManouverAt) then {
    print "Wait for next manouver.    " at (2, 10).
    printNode().
    wait 1.

    return true.
}

when hasNode and burnDone and not inManouver and (nextNode:eta <= getBurnDuration() / 2.0 + beginManouverAt) then {
    local manouver to nextNode.
    SAS off.
    lock steering to manouver.
    print "Wait for ignition.         " at (2, 10).
    printNode().

    return true.
}

when hasNode and burnDone and not inManouver and (nextNode:eta <= getBurnDuration() / 2.0) then {
    print "Main engine start.         " at (2, 10).
    printNode().

    lock steering to nextNode.
    set oldDeltaV to round(nextNode:deltav:mag + 1000000.0, 4).
    set burnDone to false.
    set inManouver to true.

    return true.
}

when not burnDone and inManouver then {
    if(not hasNode) {
        set burnDone to true.
        return true.
    }
    local manouver to nextNode.
    lock steering to manouver.
    set deltaV to round(manouver:deltav:mag, 4).
    print "Delta-V: " + round(deltaV, 2) + "m/s                 " at (2, 10).
    printNode().
    if(isFuelEmpy()) print "No fuel left!                    " at (2, 13).
    
    if (deltaV < 0.1 or oldDeltaV < deltaV or isFuelEmpy()) {
        set burnDone to true.
    } else if (deltaV < 2.0) {
        lock throttle to minThustPercent.
    } else if (deltaV < 7.0) {
        lock throttle to max(minThustPercent, 1.0 / 4.0 * (deltaV - 2.0)).
    } else lock throttle to 1.0.

    set oldDeltaV to deltaV.
    lock steering to manouver.
    wait 0.

    return true.
}

when burnDone and inManouver then {
    lock throttle to 0.
    print "Main engine cut off.               " at (2, 10).
    if(hasNode) remove nextNode.
    unlock steering.
    unlock throttle.
    SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
    SAS on.
    set inManouver to false.
    print "                                                              " at (2, 11).

    return true.
}

when not execDone and isFuelEmpy() then {
    stage.
    wait 1.0.
    set execDone to isFuelEmpy().
    return true.
}

when not execDone and ship:periapsis < 0 and ship:verticalspeed < 0 and not hasNode then {
    set execDone to true.
    return true.
}

wait until execDone.
clearScreen.
print "Node execution done.".
wait 1.0.
if (isFuelEmpy()) run land.
else run pland.

} else {
    copyPath("0:/boot/main", "1:/boot/main").
    run "boot/main".
}
