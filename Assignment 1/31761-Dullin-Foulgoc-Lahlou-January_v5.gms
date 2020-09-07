SETS

t        time /1*744/
i        zones /DK1,DK2/
j        supplier id /G1*G19/
conv(j)  conventional plant
ren(j)   renewable plant (wind)
s1(j)    producer is in zone 1
s2(j)    producer is in zone 2
op(j)    producer only operates between 5am and 10pm
;

conv(j)$(ord(j)<16)=yes;
ren(j)$(ord(j)>15)=yes;
op('G6')=yes;
op('G8')=yes
;

SCALAR
max_trans capacity of transimission line between the 2 zones /600/

PARAMETERS
t_day(t) time of day
z(j)     zone of producer j
d(i,t)   demand of zone i at time t
imp(i,t) importation of zone i at time t
exp(i,t) exportation of zone i at time t
l(j)     marginal cost of producer j
P(j,t)   maximum production of producer j at time t

cons     matrix of consumption
sup_conv matrix of suppliers (conventional)
sup_wind matrix of suppliers (wind)
wind     total production from wind

l_s1(t)  market price in market 1 at time t
l_s2(t)  market price in market 2 at time t
wind_cut(j,t)    energy curtailed by producer j at time t

*WARNING: Delete the "*" in the imports below to run the model the first time!"

*$call gdxxrw.exe consumption.xlsx output=consumption_jan.gdx squeeze=n par=cons rng=Janvier2020!C1:F745 cdim=1 rdim=1
$gdxin consumption_jan.gdx
$load cons
$gdxin

*$call gdxxrw.exe wind.xlsx output=wind.gdx squeeze=n par=wind rng=Janvier2020!C1:E745 cdim=1 rdim=1
$gdxin wind.gdx
$load wind
$gdxin

*$call gdxxrw.exe suppliers.xlsx output=sup_conv.gdx squeeze=n acronyms=1 par=sup_conv rng=Conventional!B1:F16 cdim=1 rdim=1
$gdxin sup_conv.gdx
$load sup_conv
$gdxin

*$call gdxxrw.exe suppliers.xlsx output=sup_wind.gdx squeeze=n acronyms=1 par=sup_wind rng=Wind!B1:G5 cdim=1 rdim=1
$gdxin sup_wind.gdx
$load sup_wind
$gdxin
;

*Loading the demand
d(i,t)=cons(t,i);
*Determining the time of the time for each time unit
t_day(t)=cons(t,"t_day");
*Setting the imports and exports
imp(i,t)=0;
exp(i,t)=0;
imp('DK1',t)=100;
loop(t$(t_day(t)>=8 and t_day(t)<=14),exp('DK1',t)=120);
loop(t$(t_day(t)>=11 and t_day(t)<=16),imp('DK2',t)=80);
*Loading the marginal costs of the producers
l(j)$conv(j)=sup_conv(j,'lambda');
l(j)$ren(j)=sup_wind(j,'lambda');
*Determining the zones of the suppliers
z(j)$conv(j)=sup_conv(j,'Area');
z(j)$ren(j)=sup_wind(j,'Area');
s1(j)$(z(j)=1)=yes;
s2(j)$(z(j)=2)=yes;
*Setting the maximal electricity productions
P(j,t)$conv(j)=sup_conv(j,'P');
P(j,t)$(ren(j)and s1(j)) = sup_wind(j,'Share')*wind(t,'DK1');
P(j,t)$(ren(j)and s2(j)) = sup_wind(j,'Share')*wind(t,'DK2');

POSITIVE VARIABLES
y(j,t)    production of supplier j at time t
shed1(t)  load shedding in zone 1
shed2(t)  load shedding in zone 2

FREE VARIABLES
C         cost of production (taking shedding into account)
delta(t)  exchange between the zones (counted positively from 1 to 2)

EQUATIONS
bal1      balancing of zone 1
bal2      balancing of zone 2
oper      producers operating between 5am and 10pm
max_prod  setting maximum levels of production
trans_min capacity of transmission line
trans_max capacity of transmission line
obj       objective function
;

bal1(t)..                sum(j$s1(j),y(j,t))+shed1(t) =e= delta(t)+d('DK1',t)-imp('DK1',t)+exp('DK1',t);
bal2(t)..                sum(j$s2(j),y(j,t))+shed2(t) =e= -delta(t)+d('DK2',t)-imp('DK2',t)+exp('DK2',t);
oper(j,t)$op(j)..        y(j,t)$(t_day(t)<5 or t_day(t)>21) =e= 0;
max_prod(j,t)..          y(j,t) =l= P(j,t);
trans_min(t)..           delta(t) =l= max_trans;
trans_max(t)..           delta(t) =g= -max_trans;
obj..                    C =e= sum(t, sum(j,l(j)*y(j,t))+88*(shed1(t)+shed2(t)));

*VALUE V GIVEN TO THE SHEDDING: NO SHED <=> V > 87 (MARGINAL COST OF G5)

MODEL mod /all/;
SOLVE mod using LP minimizing C;

l_s1(t) = bal1.m(t);
l_s2(t) = bal2.m(t);

wind_cut(j,t)$ren(j) = P(j,t)-y.l(j,t);

DISPLAY C.l,y.l,delta.l,shed1.l,shed2.l,l_s1,l_s2,wind_cut;

**EXPORTING RESULTS TO EXCEL

y.l(j,t)$(not y.l(j,t)) = eps;
wind_cut(j,t)$(not wind_cut(j,t)) = eps;

$onEcho > howToRead_market_clearing_jan.txt
var = C.l rng=Clearing_jan!A2
squeeze=n EpsOut=0 var = y.l rng=Clearing_jan!B5 rdim=2
squeeze=n EpsOut=0 par = l_s1 rng=Clearing_jan!F5 rdim=1
squeeze=n EpsOut=0 par = l_s2 rng=Clearing_jan!J5 rdim=1
squeeze=n EpsOut=0 var = shed1.l rng=Misc_jan!B5 rdim=1
squeeze=n EpsOut=0 var = shed2.l rng=Misc_jan!F5 rdim=1
squeeze=n EpsOut=0 var = delta.l rng=Misc_jan!J5 rdim=1
squeeze=n EpsOut=0 par = wind_cut rng=Misc_jan!N5 rdim=2
$offEcho

execute_unload "market_clearing_jan.gdx" C.l y.l l_s1 l_s2 shed1.l shed2.l delta.l wind_cut
execute 'gdxxrw.exe market_clearing_jan.gdx o=market_clearing_v5.xls @howToRead_market_clearing_jan.txt'

