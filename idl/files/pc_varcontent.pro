;  $Id: pc_varcontent.pro,v 1.55 2008-01-09 09:33:42 ajohan Exp $
;
; VARCONTENT STRUCTURE DESCRIPTION
;
; variable (string)
;   Human readable name for the variable
;
; idlvar (string)
;   Name of the variable (usually in the IDL global namespace)
;   in which the variables data will be stored
;
; idlinit (string)
;   IDL command to initialise the storage variable ready for
;   reading in from a file
;
; idlvarloc (string)
;   As idlvar but used when two grid sizes are used eg. global mesh
;   and processor mesh (local -> loc). And used in processes such
;   as in rall.pro.  Eg. uses mesh sizes of (mxloc,myloc,mzloc)
;
; idlinitloc (string)
;   Again as idlinit but used when two mesh sizes are required at once.
;   see idlvarloc
;
function pc_varcontent, datadir=datadir, dim=dim, param=param, $
    run2D=run2D, scalar=scalar, quiet=quiet
COMPILE_OPT IDL2,HIDDEN
;
;  Read grid dimensions, input parameters and location of datadir.
;
if (n_elements(dim) eq 0) then pc_read_dim,obj=dim,datadir=datadir,quiet=quiet
if (n_elements(param) eq 0) then pc_read_param,obj=param,datadir=datadir, $
    dim=dim,quiet=quiet
if (not keyword_set(datadir)) then datadir=pc_get_datadir()
; 
;  Read the positions of variables in f.
;
cmd = 'perl -000 -ne '+"'"+'s/[ \t]+/ /g; print join(" & ",split(/\n/,$_)),"\n"'+"' "+datadir+'/index.pro'
spawn, cmd, result
res = flatten_strings(result) 
index=strsplit(res,'&',/extract)
nindex=n_elements(index)
for i=0,nindex-1 do begin
  if (execute(index[i]) ne 1) then $
  message, 'pc_varcontent: there was a problem with index.pro', /info
endfor
;
;  The number of variables in the snapshot file depends on whether we
;  are writing auxiliary data or not.
;
if (param.lwrite_aux ne 0) then totalvars=dim.mvar+dim.maux else totalvars=dim.mvar
;
;  Make an array of structures in which to store their descriptions.
;  Index zero is kept as a dummy entry.
;
varcontent=replicate({varcontent_all, $
    variable:'UNKNOWN', $ 
    idlvar:'dummy', $
    idlinit:'fltarr(mx,my,mz)*one', $
    idlvarloc:'dummy_loc', $
    idlinitloc:'fltarr(mxloc,myloc,mzloc)*one', $
    skip:0}, totalvars+1)
;
;  Predefine some variable types used regularly
;
if (keyword_set(run2D)) then begin
;
;  For 2-D runs with lwrite_2d=T. Data has been written by the code without
;  ghost zones in the missing direction. We add ghost zones here anyway so
;  that the array can be treated exactly like 3-D data.
;  
  if (dim.nx eq 1) then begin
;  2-D run in (y,z) plane.
    INIT_3VECTOR     = 'fltarr(mx,my,mz,3)*one'
    INIT_3VECTOR_LOC = 'fltarr(myloc,mzloc,3)*one'
    INIT_SCALAR      = 'fltarr(mx,my,mz)*one'
    INIT_SCALAR_LOC  = 'fltarr(myloc,mzloc)*one'
  endif else if (dim.ny eq 1) then begin
;  2-D run in (x,z) plane.
    INIT_3VECTOR     = 'fltarr(mx,my,mz,3)*one'
    INIT_3VECTOR_LOC = 'fltarr(mxloc,mzloc,3)*one'
    INIT_SCALAR      = 'fltarr(mx,my,mz)*one'
    INIT_SCALAR_LOC  = 'fltarr(mxloc,mzloc)*one'
  endif else begin
;  2-D run in (x,y) plane.
    INIT_3VECTOR     = 'fltarr(mx,my,mz,3)*one'
    INIT_3VECTOR_LOC = 'fltarr(mxloc,myloc,3)*one'
    INIT_SCALAR      = 'fltarr(mx,my,mz)*one'
    INIT_SCALAR_LOC  = 'fltarr(mxloc,myloc)*one'
  endelse
endif else begin
;
;  Regular 3-D run.
;
  INIT_3VECTOR     = 'fltarr(mx,my,mz,3)*one'
  INIT_3VECTOR_LOC = 'fltarr(mxloc,myloc,mzloc,3)*one'
  INIT_SCALAR      = 'fltarr(mx,my,mz)*one'
  INIT_SCALAR_LOC  = 'fltarr(mxloc,myloc,mzloc)*one'
endelse
;
;  For EVERY POSSIBLE variable in a snapshot file, store a
;  description of the variable in an indexed array of structures
;  where the indexes line up with those in the saved f array.
;
;  Any variable not stored should have iXXXXXX set to zero
;  and will only update the dummy index zero entry.
;
default, iuu, 0
varcontent[iuu].variable   = 'Velocity (uu)'
varcontent[iuu].idlvar     = 'uu'
varcontent[iuu].idlinit    = INIT_3VECTOR
varcontent[iuu].idlvarloc  = 'uu_loc'
varcontent[iuu].idlinitloc = INIT_3VECTOR_LOC
varcontent[iuu].skip       = 2
;
default, ilnrho, 0
varcontent[ilnrho].variable   = 'Log density (lnrho)'
varcontent[ilnrho].idlvar     = 'lnrho'
varcontent[ilnrho].idlinit    = INIT_SCALAR
varcontent[ilnrho].idlvarloc  = 'lnrho_loc'
varcontent[ilnrho].idlinitloc = INIT_SCALAR_LOC
;
default, iss, 0
varcontent[iss].variable   = 'Entropy (ss)'
varcontent[iss].idlvar     = 'ss'
varcontent[iss].idlinit    = INIT_SCALAR
varcontent[iss].idlvarloc  = 'ss_loc'
varcontent[iss].idlinitloc = INIT_SCALAR_LOC
;
default, iaa, 0
varcontent[iaa].variable   = 'Magnetic vector potential (aa)'
varcontent[iaa].idlvar     = 'aa'
varcontent[iaa].idlinit    = INIT_3VECTOR
varcontent[iaa].idlvarloc  = 'aa_loc'
varcontent[iaa].idlinitloc = INIT_3VECTOR_LOC
varcontent[iaa].skip       = 2
;
default, ibb, 0
varcontent[ibb].variable   = 'Magnetic field (bb)'
varcontent[ibb].idlvar     = 'bb'
varcontent[ibb].idlinit    = INIT_3VECTOR
varcontent[ibb].idlvarloc  = 'bb_loc'
varcontent[ibb].idlinitloc = INIT_3VECTOR_LOC
varcontent[ibb].skip       = 2
;
default, ijj, 0
varcontent[ijj].variable   = 'Current density (jj)'
varcontent[ijj].idlvar     = 'jj'
varcontent[ijj].idlinit    = INIT_3VECTOR
varcontent[ijj].idlvarloc  = 'jj_loc'
varcontent[ijj].idlinitloc = INIT_3VECTOR_LOC
varcontent[ijj].skip       = 2
;
default, iuut, 0
varcontent[iuut].variable   = 'Integrated velocity (uut)'
varcontent[iuut].idlvar     = 'uut'
varcontent[iuut].idlinit    = INIT_3VECTOR
varcontent[iuut].idlvarloc  = 'uut_loc'
varcontent[iuut].idlinitloc = INIT_3VECTOR_LOC
varcontent[iuut].skip       = 2
;
default, iaatest, 0
default, ntestfield, 0
varcontent[iaatest].variable   = 'Testfield vector potential (aatest)'
varcontent[iaatest].idlvar     = 'aatest'
varcontent[iaatest].idlinit    = 'fltarr(mx,my,mz,ntestfield)*one'
varcontent[iaatest].idlvarloc  = 'aatest_loc'
varcontent[iaatest].idlinitloc = 'fltarr(mxloc,myloc,mzloc,ntestfield)*one'
varcontent[iaatest].skip       = ntestfield-1
;
default, iuxb, 0
varcontent[iuxb].variable   = 'Testfield vector potential (uxb)'
varcontent[iuxb].idlvar     = 'uxb'
varcontent[iuxb].idlinit    = 'fltarr(mx,my,mz,ntestfield)*one'
varcontent[iuxb].idlvarloc  = 'uxb_loc'
varcontent[iuxb].idlinitloc = 'fltarr(mxloc,myloc,mzloc,ntestfield)*one'
varcontent[iuxb].skip       = ntestfield-1
;
default, iuun, 0
varcontent[iuun].variable   = 'Velocity of neutrals (uun)'
varcontent[iuun].idlvar     = 'uun'
varcontent[iuun].idlinit    = INIT_3VECTOR
varcontent[iuun].idlvarloc  = 'uun_loc'
varcontent[iuun].idlinitloc = INIT_3VECTOR_LOC
varcontent[iuun].skip       = 2
;
default, ilnrhon, 0
varcontent[ilnrhon].variable   = 'Log density of neutrals (lnrhon)'
varcontent[ilnrhon].idlvar     = 'lnrhon'
varcontent[ilnrhon].idlinit    = INIT_SCALAR
varcontent[ilnrhon].idlvarloc  = 'lnrhon_loc'
varcontent[ilnrhon].idlinitloc = INIT_SCALAR_LOC
;
default, ifx, 0
varcontent[ifx].variable   = 'Radiation vector ?something? (ff)'
varcontent[ifx].idlvar     = 'ff'
varcontent[ifx].idlinit    = INIT_3VECTOR
varcontent[ifx].idlvarloc  = 'ff_loc'
varcontent[ifx].idlinitloc = INIT_3VECTOR_LOC
varcontent[ifx].skip       = 2
;
default, ie, 0
varcontent[ie].variable   = 'Radiation scalar ?something? (ee)'
varcontent[ie].idlvar     = 'ee'
varcontent[ie].idlinit    = INIT_SCALAR
varcontent[ie].idlvarloc  = 'ee_loc'
varcontent[ie].idlinitloc = INIT_SCALAR_LOC
;
default, icc, 0
varcontent[icc].variable   = 'Passive scalar (cc)'
varcontent[icc].idlvar     = 'cc'
varcontent[icc].idlinit    = INIT_SCALAR
varcontent[icc].idlvarloc  = 'cc_loc'
varcontent[icc].idlinitloc = INIT_SCALAR_LOC
;
default, ilncc, 0
varcontent[ilncc].variable   = 'Log passive scalar (lncc)'
varcontent[ilncc].idlvar     = 'lncc'
varcontent[ilncc].idlinit    = INIT_SCALAR
varcontent[ilncc].idlvarloc  = 'lncc_loc'
varcontent[ilncc].idlinitloc = INIT_SCALAR_LOC
;
default, iXX_chiral, 0
varcontent[iXX_chiral].variable   = 'XX_chiral'
varcontent[iXX_chiral].idlvar     = 'XX_chiral'
varcontent[iXX_chiral].idlinit    = INIT_SCALAR
varcontent[iXX_chiral].idlvarloc  = 'XX_chiral_loc'
varcontent[iXX_chiral].idlinitloc = INIT_SCALAR_LOC
;
default, iYY_chiral, 0
varcontent[iYY_chiral].variable   = 'YY_chiral'
varcontent[iYY_chiral].idlvar     = 'YY_chiral'
varcontent[iYY_chiral].idlinit    = INIT_SCALAR
varcontent[iYY_chiral].idlvarloc  = 'YY_chiral_loc'
varcontent[iYY_chiral].idlinitloc = INIT_SCALAR_LOC
;
default, ispecial, 0
varcontent[ispecial].variable   = 'special'
varcontent[ispecial].idlvar     = 'special'
varcontent[ispecial].idlinit    = INIT_SCALAR
varcontent[ispecial].idlvarloc  = 'special_loc'
varcontent[ispecial].idlinitloc = INIT_SCALAR_LOC
;
default, iphi, 0
varcontent[iphi].variable   = 'Electric potential (phi)'
varcontent[iphi].idlvar     = 'phi'
varcontent[iphi].idlinit    = INIT_SCALAR
varcontent[iphi].idlvarloc  = 'phi_loc'
varcontent[iphi].idlinitloc = INIT_SCALAR_LOC
;
default, iecr, 0
varcontent[iecr].variable   = 'Cosmic ray energy density (ecr)'
varcontent[iecr].idlvar     = 'ecr'
varcontent[iecr].idlinit    = INIT_SCALAR
varcontent[iecr].idlvarloc  = 'ecr_loc'
varcontent[iecr].idlinitloc = INIT_SCALAR_LOC
;
default, ifcr, 0
varcontent[ifcr].variable   = 'Cosmic ray energy flux (fcr)'
varcontent[ifcr].idlvar     = 'fcr'
varcontent[ifcr].idlinit    = INIT_3VECTOR
varcontent[ifcr].idlvarloc  = 'fcr_loc'
varcontent[ifcr].idlinitloc = INIT_3VECTOR_LOC
varcontent[ifcr].skip       = 2
;
default, ipsi_real, 0
varcontent[ipsi_real].variable   = 'Wave function (real part)'
varcontent[ipsi_real].idlvar     = 'psi_real'
varcontent[ipsi_real].idlinit    = INIT_SCALAR
varcontent[ipsi_real].idlvarloc  = 'psi_real_loc'
varcontent[ipsi_real].idlinitloc = INIT_SCALAR_LOC
;
default, ipsi_imag, 0
varcontent[ipsi_imag].variable   = 'Wave function (imaginary part)'
varcontent[ipsi_imag].idlvar     = 'psi_imag'
varcontent[ipsi_imag].idlinit    = INIT_SCALAR
varcontent[ipsi_imag].idlvarloc  = 'psi_imag_loc'
varcontent[ipsi_imag].idlinitloc = INIT_SCALAR_LOC
;
default, ichemspec, 0
chemcount=n_elements(ichemspec)
if (chemcount gt 0L) then begin
  for i=0,chemcount-1 do begin
    istr=strcompress(string(i),/remove_all)
    print,'DEBUG: istr=',istr
    varcontent[ichemspec[i]].variable   = 'Chemical species mass fraction (YY'+istr+')'
    varcontent[ichemspec[i]].idlvar     = 'YY'+istr
    varcontent[ichemspec[i]].idlinit    = 'fltarr(mx,my,mz)*one'
    varcontent[ichemspec[i]].idlvarloc  = 'YY'+istr+'_loc'
    varcontent[ichemspec[i]].idlinitloc = 'fltarr(mxloc,myloc,mzloc)*one'
  endfor
endif
;
default, iuud, 0
dustcount=n_elements(iuud) 
if (dustcount gt 0L) then begin
  if (keyword_set(scalar)) then begin
    for i=0,dustcount-1 do begin
     istr=strcompress(string(i),/remove_all)
     varcontent[iuud[i]].variable   = 'Dust velocity  (uud['+istr+'])'
     varcontent[iuud[i]].idlvar     = 'uud'+istr
     varcontent[iuud[i]].idlinit    = 'fltarr(mx,my,mz,3)*one' 
     varcontent[iuud[i]].idlvarloc  = 'uud'+istr+'_loc'
     varcontent[iuud[i]].idlinitloc = 'fltarr(mxloc,myloc,mzloc,3)*one'
    endfor
  endif else begin
    varcontent[iuud[0]].variable   = 'Dust velocity  (uud)'
    varcontent[iuud[0]].idlvar     = 'uud'
    varcontent[iuud[0]].idlinit    = 'fltarr(mx,my,mz,3,'+str(dustcount)+')*one' 
    varcontent[iuud[0]].idlvarloc  = 'uud_loc'
    varcontent[iuud[0]].idlinitloc = 'fltarr(mxloc,myloc,mzloc,3,'+str(dustcount)+')*one'
    varcontent[iuud[0]].skip       = (dustcount * 3) - 1
  endelse
endif
;
default, ind, 0
dustcount=n_elements(ind)
if (dustcount gt 0L) then begin
  if (keyword_set(scalar)) then begin
    for i=0,dustcount-1 do begin
      istr=strcompress(string(i),/remove_all)
      varcontent[ind[i]].variable   = 'Dust number density (nd'+istr+')'
      varcontent[ind[i]].idlvar     = 'nd'+istr
      varcontent[ind[i]].idlinit    = 'fltarr(mx,my,mz)*one' 
      varcontent[ind[i]].idlvarloc  = 'nd'+istr+'_loc'
      varcontent[ind[i]].idlinitloc = 'fltarr(mxloc,myloc,mzloc)*one'
    endfor
  endif else begin
    varcontent[ind[0]].variable   = 'Dust number density (nd)'
    varcontent[ind[0]].idlvar     = 'nd'
    varcontent[ind[0]].idlinit    = 'fltarr(mx,my,mz,'+str(dustcount)+')*one' 
    varcontent[ind[0]].idlvarloc  = 'nd_loc'
    varcontent[ind[0]].idlinitloc = 'fltarr(mxloc,myloc,mzloc,'+str(dustcount)+')*one'
    varcontent[ind[0]].skip       = dustcount - 1
  endelse
endif
;
default, imd, 0
dustcount=n_elements(imd)
if (dustcount gt 0L) then begin
  if (keyword_set(scalar)) then begin
    for i=0,dustcount-1 do begin
     istr=strcompress(string(i),/remove_all)
      varcontent[imd[i]].variable   = 'Dust density (md'+istr+')'
      varcontent[imd[i]].idlvar     = 'md'+istr
      varcontent[imd[i]].idlinit    = 'fltarr(mx,my,mz)*one' 
      varcontent[imd[i]].idlvarloc  = 'md'+istr+'_loc'
      varcontent[imd[i]].idlinitloc = 'fltarr(mxloc,myloc,mzloc)*one'
    endfor
  endif else begin
    varcontent[imd[0]].variable   = 'Dust density (md)'
    varcontent[imd[0]].idlvar     = 'md'
    varcontent[imd[0]].idlinit    = 'fltarr(mx,my,mz,'+str(dustcount)+')*one' 
    varcontent[imd[0]].idlvarloc  = 'md_loc'
    varcontent[imd[0]].idlinitloc = 'fltarr(mxloc,myloc,mzloc,'+str(dustcount)+')*one'
    varcontent[imd[0]].skip       = dustcount - 1
  endelse
endif
;
default, imi, 0
dustcount=n_elements(imi)
if (dustcount gt 0L) then begin
  if (keyword_set(scalar)) then begin
    for i=0,dustcount-1 do begin
      istr=strcompress(string(i),/remove_all)
      varcontent[imi[i]].variable   = 'Ice density (mi'+istr+')'
      varcontent[imi[i]].idlvar     = 'mi'+istr
      varcontent[imi[i]].idlinit    = 'fltarr(mx,my,mz)*one' 
      varcontent[imi[i]].idlvarloc  = 'mi'+istr+'_loc'
      varcontent[imi[i]].idlinitloc = 'fltarr(mxloc,myloc,mzloc)*one'
    endfor
  endif else begin
    varcontent[imi[0]].variable = 'Ice density (mi)'
    varcontent[imi[0]].idlvar   = 'mi'
    varcontent[imi[0]].idlinit  = 'fltarr(mx,my,mz,'+str(dustcount)+')*one' 
    varcontent[imi[0]].idlvarloc= 'mi_loc'
    varcontent[imi[0]].idlinitloc = 'fltarr(mxloc,myloc,mzloc,'+str(dustcount)+')*one'
    varcontent[imi[0]].skip     = dustcount - 1
  endelse
endif
;
default, igg, 0
varcontent[igg].variable   = 'Gravitational acceleration (gg)'
varcontent[igg].idlvar     = 'gg'
varcontent[igg].idlinit    = INIT_3VECTOR
varcontent[igg].idlvarloc  = 'gg_loc'
varcontent[igg].idlinitloc = INIT_3VECTOR_LOC
varcontent[igg].skip       = 2
;
; Special condition as can be maux or mvar variable
;
default, ilnTT, 0
if ((ilnTT le dim.mvar) or (param.lwrite_aux ne 0)) then begin
    varcontent[ilnTT].variable   = 'Log temperature (lnTT)'
    varcontent[ilnTT].idlvar     = 'lnTT'
    varcontent[ilnTT].idlinit    = INIT_SCALAR
    varcontent[ilnTT].idlvarloc  = 'lnTT_loc'
    varcontent[ilnTT].idlinitloc = INIT_SCALAR_LOC
end
;
;  Auxiliary variables (only if they have been saved).
;
if (param.lwrite_aux ne 0) then begin
;
  default, iQrad, 0
  varcontent[iQrad].variable   = 'Radiative heating rate (Qrad)'
  varcontent[iQrad].idlvar     = 'Qrad'
  varcontent[iQrad].idlinit    = INIT_SCALAR
  varcontent[iQrad].idlvarloc  = 'Qrad_loc'
  varcontent[iQrad].idlinitloc = INIT_SCALAR_LOC
;
  default, ikapparho, 0
  varcontent[ikapparho].variable   = 'Opacity (kapparho)'
  varcontent[ikapparho].idlvar     = 'kapparho'
  varcontent[ikapparho].idlinit    = INIT_SCALAR
  varcontent[ikapparho].idlvarloc  = 'kapparho_loc'
  varcontent[ikapparho].idlinitloc = INIT_SCALAR_LOC
;
  default, iFrad, 0
  varcontent[iFrad].variable   = 'Radiative flux (Frad)'
  varcontent[iFrad].idlvar     = 'Frad'
  varcontent[iFrad].idlinit    = INIT_3VECTOR
  varcontent[iFrad].idlvarloc  = 'Frad_loc'
  varcontent[iFrad].idlinitloc = INIT_3VECTOR_LOC
  varcontent[iFrad].skip       = 2
;
  default, iyH, 0
  varcontent[iyH].variable   = 'Hydrogen ionization fraction (yH)'
  varcontent[iyH].idlvar     = 'yH'
  varcontent[iyH].idlinit    = INIT_SCALAR
  varcontent[iyH].idlvarloc  = 'yH_loc'
  varcontent[iyH].idlinitloc = INIT_SCALAR_LOC
;
  default, ishock, 0
  varcontent[ishock].variable   = 'Shock Profile (shock)'
  varcontent[ishock].idlvar     = 'shock'
  varcontent[ishock].idlinit    = INIT_SCALAR
  varcontent[ishock].idlvarloc  = 'shock_loc'
  varcontent[ishock].idlinitloc = INIT_SCALAR_LOC
;
  default, ishock_perp, 0
  varcontent[ishock_perp].variable   = 'B-Perp Shock Profile (shock_perp)'
  varcontent[ishock_perp].idlvar     = 'shock_perp'
  varcontent[ishock_perp].idlinit    = INIT_SCALAR
  varcontent[ishock_perp].idlvarloc  = 'shock_perp_loc'
  varcontent[ishock_perp].idlinitloc = INIT_SCALAR_LOC
;
  default, icooling, 0
  varcontent[icooling].variable   = 'Cooling Term (cooling)'
  varcontent[icooling].idlvar     = 'cooling'
  varcontent[icooling].idlinit    = INIT_SCALAR
  varcontent[icooling].idlvarloc  = 'cooling_loc'
  varcontent[icooling].idlinitloc = INIT_SCALAR_LOC
;
  default, icooling2, 0
  varcontent[icooling2].variable   = 'Applied Cooling Term (cooling)'
  varcontent[icooling2].idlvar     = 'cooling2'
  varcontent[icooling2].idlinit    = INIT_SCALAR
  varcontent[icooling2].idlvarloc  = 'cooling2_loc'
  varcontent[icooling2].idlinitloc = INIT_SCALAR_LOC
;
  default, inp, 0
  varcontent[inp].variable   = 'Particle number (np)'
  varcontent[inp].idlvar     = 'np'
  varcontent[inp].idlinit    = INIT_SCALAR
  varcontent[inp].idlvarloc  = 'np_loc'
  varcontent[inp].idlinitloc = INIT_SCALAR_LOC
;
  default, irhop, 0
  varcontent[irhop].variable   = 'Particle mass density (rhop)'
  varcontent[irhop].idlvar     = 'rhop'
  varcontent[irhop].idlinit    = INIT_SCALAR
  varcontent[irhop].idlvarloc  = 'rhop_loc'
  varcontent[irhop].idlinitloc = INIT_SCALAR_LOC
;
  default, ipotself, 0
  varcontent[ipotself].variable   = 'Self gravity potential'
  varcontent[ipotself].idlvar     = 'potself'
  varcontent[ipotself].idlinit    = INIT_SCALAR
  varcontent[ipotself].idlvarloc  = 'potself_loc'
  varcontent[ipotself].idlinitloc = INIT_SCALAR_LOC
;
  default, igpotselfx, 0
  varcontent[igpotselfx].variable   = 'Gradient of self gravity potential'
  varcontent[igpotselfx].idlvar     = 'gpotself'
  varcontent[igpotselfx].idlinit    = INIT_3VECTOR
  varcontent[igpotselfx].idlvarloc  = 'gpotself_loc'
  varcontent[igpotselfx].idlinitloc = INIT_3VECTOR_LOC
  varcontent[igpotselfx].skip       = 2
;
  default, ivisc_heat, 0
  varcontent[ivisc_heat].variable  = 'viscous dissipation'
  varcontent[ivisc_heat].idlvar    = 'visc_heat'
  varcontent[ivisc_heat].idlinit   = INIT_SCALAR
  varcontent[ivisc_heat].idlvarloc = 'visc_heat_loc'
;
  default, ihypvis, 0
  varcontent[ihypvis].variable   = 'Hyperviscosity (hyv)'
  varcontent[ihypvis].idlvar     = 'hyv'
  varcontent[ihypvis].idlinit    = INIT_3VECTOR
  varcontent[ihypvis].idlvarloc  = 'hyv_loc'
  varcontent[ihypvis].idlinitloc = INIT_3VECTOR_LOC
  varcontent[ihypvis].skip       = 2
;
  default, ihypres, 0
  varcontent[ihypres].variable   = 'Hyperresistivity (hyr)'
  varcontent[ihypres].idlvar     = 'hyr'
  varcontent[ihypres].idlinit    = INIT_3VECTOR
  varcontent[ihypres].idlvarloc  = 'hyr_loc'
  varcontent[ihypres].idlinitloc = INIT_3VECTOR_LOC
  varcontent[ihypres].skip       = 2
endif
;
;  Turn vector quantities into scalars if requested.
;
if (keyword_set(scalar)) then begin
  for i=1,totalvars do begin
    if (varcontent[i].skip eq 2) then begin
      varcontent[i+2].variable  = varcontent[i].variable + ' 3rd component' 
      varcontent[i+1].variable  = varcontent[i].variable + ' 2nd component' 
      varcontent[i  ].variable  = varcontent[i].variable + ' 1st component' 
      varcontent[i+2].idlvar    = varcontent[i].idlvar + '3' 
      varcontent[i+1].idlvar    = varcontent[i].idlvar + '2' 
      varcontent[i  ].idlvar    = varcontent[i].idlvar + '1' 
      varcontent[i+2].idlvarloc = varcontent[i].idlvarloc + '3' 
      varcontent[i+1].idlvarloc = varcontent[i].idlvarloc + '2' 
      varcontent[i  ].idlvarloc = varcontent[i].idlvarloc + '1' 
      varcontent[i:i+2].idlinit    = INIT_SCALAR
      varcontent[i:i+2].idlinitloc = INIT_SCALAR_LOC
      varcontent[i:i+2].skip       = 0
      i=i+2
    endif   
  endfor
endif
;
;  Zero out default definition in case it has been set by mistake.
;
varcontent[0].variable = 'UNKNOWN'
varcontent[0].idlvar   = 'UNKNOWN'
varcontent[0].idlinit  = '0.'
varcontent[0].skip     = 0
;
return, varcontent
;
end
