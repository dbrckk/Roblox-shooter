local Gate = require("../src/server/DuelCombatState")
local a = {UserId = 17, Character = {}}
local b = {UserId = 24, Character = {}}
local other = {UserId = 99, Character = {}}
local firstA, firstB = a.Character, b.Character
assert(Gate.canFire(a,"LIVE","FFA",3))
assert(Gate.canDamage(a,nil,{},"LIVE","FFA",3))
assert(not Gate.canFire(a,"LIVE","DUEL",2))
assert(Gate.begin(a,b))
for i=1,1000 do
    assert(Gate.canFire(a,"LIVE","DUEL",2))
    assert(Gate.canFire(b,"LIVE","DUEL",2))
    assert(Gate.canDamage(a,b,firstB,"LIVE","DUEL",2))
    assert(Gate.canDamage(b,a,firstA,"LIVE","DUEL",2))
    assert(not Gate.canDamage(a,b,firstA,"LIVE","DUEL",2))
    assert(not Gate.canDamage(a,a,firstA,"LIVE","DUEL",2))
    assert(not Gate.canDamage(a,nil,firstB,"LIVE","DUEL",2))
    assert(not Gate.canFire(other,"LIVE","DUEL",2))
    assert(not Gate.canFire(a,"DUEL_PREP","DUEL",2))
    assert(not Gate.canFire(a,"DUEL_BREAK","DUEL",2))
    assert(not Gate.canFire(a,"RESULTS","DUEL",2))
    assert(not Gate.canFire(a,"LIVE","DUEL",3))
end
a.Character = {}
assert(not Gate.canFire(a,"LIVE","DUEL",2))
assert(not Gate.canDamage(a,b,firstB,"LIVE","DUEL",2))
assert(not Gate.canDamage(b,a,a.Character,"LIVE","DUEL",2))
a.Character = firstA
b.Character = {}
assert(not Gate.canFire(b,"LIVE","DUEL",2))
assert(not Gate.canDamage(a,b,firstB,"LIVE","DUEL",2))
assert(not Gate.canDamage(a,b,b.Character,"LIVE","DUEL",2))
b.Character = firstB
Gate.clear()
assert(not Gate.canFire(a,"LIVE","DUEL",2))
assert(Gate.begin(a,b))
assert(Gate.canFire(a,"LIVE","DUEL",2))
Gate.clear()
assert(not Gate.begin(a,a))
assert(not Gate.begin(a,{UserId=17,Character={}}))
assert(not Gate.begin(a,{UserId=25,Character=firstA}))
assert(not Gate.canFire(a,"LIVE","DUEL",2))
local studioA = {UserId=-1,Character={}}
local studioB = {UserId=-2,Character={}}
assert(Gate.begin(studioA,studioB))
assert(Gate.canFire(studioA,"LIVE","DUEL",2))
assert(Gate.canDamage(studioA,studioB,studioB.Character,"LIVE","DUEL",2))
studioA.Character = {}
assert(not Gate.canFire(studioA,"LIVE","DUEL",2))
Gate.clear()
assert(not Gate.begin({UserId=0,Character={}},studioB))
assert(not Gate.begin({UserId=0/0,Character={}},studioB))
assert(not Gate.begin({UserId=0.5,Character={}},studioB))
assert(not Gate.begin({UserId=math.huge,Character={}},studioB))
print("IRON YARD duel combat: 1000 checks, rig generations and all damage channels OK")
