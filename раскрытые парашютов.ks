if defined mainWasStarted {

set parachuteMaxHeight to 800.0.

SAS off.
lock steering to ship:srfretrograde.
set landDone to false.

clearScreen.
print "Landing v1.0.0".

when body:name = "Kerbin" and ag2 and ship:altitude < 65000 then {
    set ag2 to false.
    print "Retract antenna and solar (AG2) at " + round(alt:radar, 2).

    return true.
}
when body:name = "Kerbin" and not ag2 and ship:altitude > 70000 then {
    set ag2 to true.
    print "Expand antenna and solar (AG2) " + round(alt:radar, 2).

    return true.
}

when body:name = "Kerbin" and ship:altitude < 200 and not gear then {
    toggle gear.
}

WHEN body:name = "Kerbin" and alt:radar <= parachuteMaxHeight THEN {
    chutesSafe on.
    print "Arm parachutes at: " + round(alt:radar, 2).
    if(chutes) {
        unlock steering.
        set landDone to true.
        return false.
    }
    return true.
}

wait until landDone.
if (not gear) toggle gear.
print "landDone.".
core:part:getmodule("kOSProcessor"):doevent("Close Terminal").

} else {
    copyPath("0:/boot/main", "1:/boot/main").
    run "boot/main".
}
