local D = require("../src/shared/DuelRules")
assert(not D.canStart(1, true, true))
assert(not D.canStart(3, true, true))
assert(not D.canStart(2, false, true))
assert(D.canStart(2, true, true))
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
assert(D.advance(0,0,0/0,"A")==nil)
print("IRON YARD duel rules: first-to-five, draws, forfeit selection and participant isolation OK")
