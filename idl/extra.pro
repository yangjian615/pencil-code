;  $Id: extra.pro,v 1.24 2003-08-09 19:47:27 mee Exp $
;
;  This routine calculates a number of extra variables
;
gamma=5./3.
gamma1=gamma-1.
;
@pencilconstants.pro
;
;print,'calculate xx,yy,zz (comment out if there isnt enough memory!)'
xx = spread(x, [1,2], [my,mz])
yy = spread(y, [0,2], [mx,mz])
zz = spread(z, [0,1], [mx,my])
;
;  calculate extra stuff that may be of some convenience
;
if (iuu ne 0) then oo=curl(uu)
if (iaa ne 0) then bb=curl(aa)
if (iaa ne 0) then jj=curl2(aa)
xxx=x(l1:l2)
yyy=y(m1:m2)
zzz=z(n1:n2)
if (iuu ne 0) then uuu=uu(l1:l2,m1:m2,n1:n2,*)
if (iuu ne 0) then ooo=oo(l1:l2,m1:m2,n1:n2,*)
if (iaa ne 0) then aaa=aa(l1:l2,m1:m2,n1:n2,*)
if (iaa ne 0) then bbb=bb(l1:l2,m1:m2,n1:n2,*)
if (iaa ne 0) then jjj=jj(l1:l2,m1:m2,n1:n2,*)
;
if (ilnrho ne 0) then begin
  llnrho=lnrho(l1:l2,m1:m2,n1:n2)
  rho=exp(llnrho)
  if (iss eq 0) then begin
    cs2=cs20*exp(gamma1*llnrho) 
  end else begin
    sss=ss(l1:l2,m1:m2,n1:n2)
    ; the following gives cs2,cp1tilde,eee,ppp
    @thermodynamics.pro
  end
;ajwm NOT SO SURE THE ENTHALPY IS CORRECT EITHER
  hhh=cs2/gamma1  ;(enthalpy)
;
end
;
if (iqrad ne 0) then QQrad=Qrad(l1:l2,m1:m2,n1:n2)
if (iqrad ne 0) then SSrad=sigmaSB*TTT^4/!pi
if (iqrad ne 0) then kaprho=.25*exp(2*llnrho-lnrho_e_)*(TT_ion_/TTT)^1.5 $
                            *exp(TT_ion_/TTT)*yyH*(1.-yyH)*kappa0
;
if (iuu ne 0) then for j=0,2 do print,sqrt(mean(uu(*,*,*,j)^2))
if (iuu ne 0) then print
;
;  calculate magnetic energy of mean field in the 3 directions
;
if (iaa ne 0) then begin
  default,b_ext,[0.,0.,0.]
  for j=0,2 do bbb(*,*,*,j)=bbb(*,*,*,j)+b_ext(j)
  bmx=sqrt(mean(dot2_1d(means(means(bbb,3),2))))
  bmy=sqrt(mean(dot2_1d(means(means(bbb,3),1))))
  bmz=sqrt(mean(dot2_1d(means(means(bbb,2),1))))
  print,'bmx,bmy,bmz=',bmx,bmy,bmz
end
;
;  calculate vertical averages
;
if (iss ne 0) then begin
  if (nz gt 1) then begin
    cs2m=haver(cs2) & csm=sqrt(cs2m)
    rhom=haver(rho)
  end
end
;
;  passive scalar
;
if (ilncc ne 0) then begin
  llncc=lncc(l1:l2,m1:m2,n1:n2)
  ccc=exp(llncc)
end
;
END
