local D = require("../src/shared/DuelRules")
assert(not D.canStart(1, true, true))
assert(not D.canStart(3, true, true))
assert(not D.canStart(2, false, true))
assert(D.canStart(2, true, true))
local p1, p2, replacement = {}, {}, {}
assert(D.sameParticipants({p1,p2},p1,p2))
assert(D.sameParticipants({p2,p1},p1,p2))
assert(not D.sameParticipants({p1},p1,p2))
assert(not D.sameParticipants({p1,p2,replacement},p1,p2))
assert(not D.sameParticipants({p1,replacement},p1,p2))
assert(not D.sameParticipants({p1,p1},p1,p2))
assert(not D.sameParticipants({p1,p2},p1,p1))
assert(not D.sameParticipants({},p1,p2))
assert(not D.sameParticipants("invalid",p1,p2))
local lifeA, lifeB = {}, {}
local hp, maxHP = D.healthForBout(lifeA, lifeA, 65, 100)
assert(hp == 65 and maxHP == 100)
hp, maxHP = D.healthForBout(lifeA, lifeB, 100, 100)
assert(hp == 0 and maxHP == 100, "Respawn cannot replace a duel life")
assert(D.boutWinner(hp, maxHP, 50, 100, false) == "B")
hp, maxHP = D.healthForBout(lifeA, nil, 100, 100)
assert(hp == 0 and maxHP == 100)
hp, maxHP = D.healthForBout(nil, nil, 100, 100)
assert(hp == 0 and maxHP == 100)
hp, maxHP = D.healthForBout(lifeA, lifeA, 0/0, 100)
assert(hp == 0 and maxHP == 100)
hp, maxHP = D.healthForBout(lifeA, lifeA, 9999, 100)
assert(hp == 100 and maxHP == 100)
hp, maxHP = D.healthForBout(lifeA, lifeA, 100, 0)
assert(hp == 0 and maxHP == 100)
assert(D.boutWinner(100,100,100,100,false)==nil)
assert(D.boutWinner(0,100,100,100,false)=="B")
assert(D.boutWinner(100,100,0,100,false)=="A")
assert(D.boutWinner(0,100,0,100,false)=="DRAW")
assert(D.boutWinner(30,100,60,100,true)=="B")
assert(D.boutWinner(75,150,50,100,true)=="DRAW")
assert(D.boutWinner(30,100,60,100,false)==nil)
assert(D.boutWinner(0/0,100,40,100,true)==nil)
assert(D.boutWinner(12,0,40,100,true)==nil)
assert(D.canFight("FFA",0,1,2,3))
assert(D.canFight("DUEL",1,1,2,2))
assert(D.canFight("DUEL",2,1,2,2))
assert(not D.canFight("DUEL",3,1,2,3))
assert(not D.canFight("DUEL",1,1,2,3))
assert(not D.canFight("DUEL",1,1,1,2))
assert(D.canFight("DUEL",-1,-1,-2,2))
assert(D.canFight("DUEL",-2,-1,-2,2))
assert(not D.canFight("DUEL",0,-1,-2,2))
assert(not D.canFight("DUEL",-3,-1,-2,2))
assert(not D.canFight("DUEL",1,0,1,2))
assert(not D.canFight("DUEL",0/0,-1,-2,2))
assert(not D.canFight("DUEL",1.5,1.5,2,2))
local a,b,n=0,0,0
for i=1,9 do
  local nextA,nextB,nextN,done,win = D.advance(a,b,n,i%2==0 and "B" or "A")
  assert(nextA and nextB and nextN==i)
  if i<9 then assert(not done and win==nil)
  else assert(done and win=="A") end
  a,b,n=nextA,nextB,nextN
end
assert(a==5 and b==4)
assert(D.advance(a,b,n,"INVALID")==nil)
local sa,sb,bouts=0,0,0
for i=1,D.MAX_BOUTS do
  local na,nb,nc,complete,winner=D.advance(sa,sb,bouts,"DRAW")
  assert(na==0 and nb==0 and nc==i)
  if i<D.MAX_BOUTS then assert(not complete and winner==nil)
  else assert(complete and winner=="DRAW") end
  sa,sb,bouts=na,nb,nc
end
assert(not D.recoveryExpired(10,10))
assert(not D.recoveryExpired(10,29.999))
assert(D.recoveryExpired(10,30))
assert(D.recoveryExpired(10,35))
assert(not D.recoveryExpired(10,8))
assert(D.recoveryExpired(nil,50))
assert(D.recoveryExpired(10,0/0))
assert(D.recoveryExpired(-1,50))
assert(D.PREP_SECONDS >= 2 and D.PREP_SECONDS <= 5)
local playerLifeA, playerLifeB = {}, {}
assert(D.prepValid(playerLifeA, playerLifeA, true,
    playerLifeB, playerLifeB, true))
assert(not D.prepValid(playerLifeA, {}, true,
    playerLifeB, playerLifeB, true))
assert(not D.prepValid(playerLifeA, playerLifeA, false,
    playerLifeB, playerLifeB, true))
assert(not D.prepValid(playerLifeA, playerLifeA, true,
    playerLifeB, playerLifeB, false))
assert(not D.prepValid(playerLifeA, playerLifeA, true,
    playerLifeA, playerLifeA, true))
assert(not D.prepValid(nil, nil, true,
    playerLifeB, playerLifeB, true))
assert(D.advance(0,0,0/0,"A")==nil)
print("IRON YARD duel rules: first-to-five, draws, forfeit selection and participant isolation OK")
