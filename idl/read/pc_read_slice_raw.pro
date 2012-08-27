; +
; NAME:
;       PC_READ_SLICE_RAW
;
; PURPOSE:
;       Read slices from var.dat, or other VAR files in an efficient way!
;
;       Returns one array from a snapshot (var) file generated by a
;       Pencil Code run, and another array with the variable labels.
;       If you need to be efficient, please use 'pc_collect.x' to combine
;       distributed varfiles before reading them in IDL.
;
; CATEGORY:
;       Pencil Code, File I/O
;
; CALLING SEQUENCE:
;       pc_read_slice_raw, object=object, varfile=varfile, tags=tags,         $
;                    datadir=datadir, trimall=trimall, /quiet,                $
;                    swap_endian=swap_endian, time=time, grid=grid,           $
;                    cut_x=cut_x, cut_y=cut_y, cut_z=cut_z, var_list=var_list
; KEYWORD PARAMETERS:
;    datadir: Specifies the root data directory. Default: './data'.  [string]
;    varfile: Name of the collective snapshot. Default: 'var.dat'.   [string]
;   allprocs: Load distributed (0) or collective (1 or 2) varfiles.  [integer]
;        dim: Dimension structure of the global 3D-setup.            [struct]
;  slice_dim: Dimension structure of the loaded 2D-slice.            [struct]
;
;      cut_x: x-coordinate of the yz-plane cut.                      [integer]
;      cut_y: y-coordinate of the xz-plane cut.                      [integer]
;      cut_z: z-coordinate of the xy-plane cut.                      [integer]
;             Exactly one of them must be set in the interval (0,ngrid-1).
;
;     object: Optional structure in which to return the loaded data. [4D-array]
;       tags: Array of tag names inside the object array.            [string(*)]
;   var_list: Array of varcontent idlvars to read (default = all).   [string(*)]
;
;   /trimall: Remove ghost points from the returned data.
;     /quiet: Suppress any information messages and summary statistics.
;
; EXAMPLES:
;
; * Load a slice and display it in a GUI:
;       pc_read_slice_raw, obj=vars, tags=tags, var_list=["lnrho","uu"]
;       cslice, vars
;   or:
;       cmp_cslice, { uz:vars[*,*,*,tags.uz], lnrho:vars[*,*,*,tags.lnrho] }
;
; * Load a slice and compute some physical quantity:
;       pc_read_slice_raw, obj=vars, tags=tags, slice_dim=dim
;       HR_ohm = pc_get_quantity ('HR_ohm', vars, tags, dim=dim)
;       tvscl, HR_ohm
;
; MODIFICATION HISTORY:
;       $Id$
;       Adapted from: pc_read_var_raw.pro, 4th May 2012
;
;-
pro pc_read_slice_raw,                                                        $
    object=object, varfile=varfile, datadir=datadir, allprocs=allprocs,       $
    tags=tags, dim=dim, param=param, par2=par2, varcontent=varcontent,        $
    trimall=trimall, quiet=quiet, swap_endian=swap_endian, f77=f77,           $
    cut_x=cut_x, cut_y=cut_y, cut_z=cut_z, var_list=var_list, time=time,      $
    grid=grid, slice_dim=slice_dim

COMPILE_OPT IDL2,HIDDEN
;
; Use common block belonging to derivative routines etc. so we can
; set them up properly.
;
  common cdat,x,y,z,mx,my,mz,nw,ntmax,date0,time0
  common cdat_grid,dx_1,dy_1,dz_1,dx_tilde,dy_tilde,dz_tilde,lequidist,lperi,ldegenerated
  common pc_precision, zero, one
  common cdat_coords,coord_system
;
; Default settings.
;
  default, allprocs, 0
  default, swap_endian, 0
  default, cut_x, -1
  default, cut_y, -1
  default, cut_z, -1
  addname = ""
  if (keyword_set (allprocs) and not keyword_set (f77)) then f77 = 0
  default, f77, 1
;
  if (total([cut_x, cut_y, cut_z] < 0) ne -2) then $
      message, 'pc_read_slice_raw: Please set exactly one cut index.'
;
; Default data directory.
;
  if (not keyword_set(datadir)) then datadir=pc_get_datadir()
;
; Name and path of varfile to read.
;
  if (not keyword_set(varfile)) then varfile = 'var.dat'
;
; Get necessary dimensions quietly.
;
  if (n_elements(dim) eq 0) then $
      pc_read_dim, object=dim, datadir=datadir, /quiet
  if (n_elements(param) eq 0) then $
      pc_read_param, object=param, dim=dim, datadir=datadir, /quiet
  if (n_elements(par2) eq 0) then begin
    if (file_test(datadir+'/param2.nml')) then begin
      pc_read_param, object=par2, /param2, dim=dim, datadir=datadir, /quiet
    endif else begin
      print, 'Could not find '+datadir+'/param2.nml'
    endelse
  endif
  if (n_elements(grid) eq 0) then $
      pc_read_grid, object=grid, dim=dim, param=param, datadir=datadir, allprocs=allprocs, /quiet
;
; Set the coordinate system.
;  
  coord_system = param.coord_system
;
; Read local dimensions.
;
  ipx_start = 0
  ipy_start = 0
  ipz_start = 0
  if (allprocs eq 1) then begin
    procdim = dim
    ipx_end = 0
    ipy_end = 0
    ipz_end = 0
  end else begin
    pc_read_dim, object=procdim, proc=0, datadir=datadir, /quiet
    if (allprocs eq 2) then begin
      ipx_end = 0
      ipy_end = 0
      procdim.nx = procdim.nxgrid
      procdim.ny = procdim.nygrid
      procdim.mx = procdim.mxgrid
      procdim.my = procdim.mygrid
      procdim.mw = procdim.mx * procdim.my * procdim.mz
    end else begin
      ipx_end = dim.nprocx-1
      ipy_end = dim.nprocy-1
      if (cut_x ge 0) then begin
        ipx_start = cut_x / procdim.nx
        ipx_end = ipx_start
      end
      if (cut_y ge 0) then begin
        ipy_start = cut_y / procdim.ny
        ipy_end = ipy_start
      end
    end
    ipz_end = dim.nprocz-1
    if (cut_z ge 0) then begin
      ipz_start = cut_z / procdim.nz
      ipz_end = ipz_start
    end
  end
;
; ... and check pc_precision is set for all Pencil Code tools.
;
  pc_set_precision, dim=dim, quiet=quiet
;
; Local shorthand for some parameters.
;
  nx=dim.nx
  ny=dim.ny
  nz=dim.nz
  nw=dim.nx*dim.ny*dim.nz
  mx=dim.mx
  my=dim.my
  mz=dim.mz
  precision=dim.precision
;
; Set cut parameters.
;
  if (cut_x eq -1) then begin
    cut_nx = dim.mx
    px_start = 0
    px_delta = procdim.mx
  endif else begin
    if ((cut_x lt 0) or (cut_x ge dim.nx)) then $
        message, 'pc_read_slice_raw: cut_x is invalid, min/max: 0-'+strtrim(dim.nx-1, 2)
    cut_nx = 1 + 2*dim.nghostx
    px_start = cut_x mod procdim.nx
    px_delta = 1 + 2*dim.nghostx
  endelse
  px_end = px_start + px_delta - 1
;
  if (cut_y eq -1) then begin
    cut_ny = dim.my
    py_start = 0
    py_delta = procdim.my
  endif else begin
    if ((cut_y lt 0) or (cut_y ge dim.ny)) then $
        message, 'pc_read_slice_raw: cut_y is invalid, min/max: 0-'+strtrim(dim.ny-1, 2)
    cut_ny = 1 + 2*dim.nghosty
    py_start = cut_y mod procdim.ny
    py_delta = 1 + 2*dim.nghosty
  endelse
  py_end = py_start + py_delta - 1
;
  if (cut_z eq -1) then begin
    cut_nz = dim.mz
    pz_start = 0
    pz_delta = procdim.mz
  endif else begin
    if ((cut_z lt 0) or (cut_z ge dim.nz)) then $
        message, 'pc_read_slice_raw: cut_z is invalid, min/max: 0-'+strtrim(dim.nz-1, 2)
    cut_nz = 1 + 2*dim.nghostz
    pz_start = cut_z mod procdim.nz
    pz_delta = 1 + 2*dim.nghostz
  endelse
  pz_end = pz_start + pz_delta - 1
;
; Generate dim structure of the 2D-slice.
;
  slice_dim = dim
  slice_dim.mx = cut_nx
  slice_dim.my = cut_ny
  slice_dim.mz = cut_nz
  slice_dim.nx = cut_nx - 2*dim.nghostx
  slice_dim.ny = cut_ny - 2*dim.nghosty
  slice_dim.nz = cut_nz - 2*dim.nghostz
  slice_dim.mxgrid = slice_dim.mx
  slice_dim.mygrid = slice_dim.my
  slice_dim.mzgrid = slice_dim.mz
  slice_dim.nxgrid = slice_dim.nx
  slice_dim.nygrid = slice_dim.ny
  slice_dim.nzgrid = slice_dim.nz
  slice_dim.mw = slice_dim.mx * slice_dim.my * slice_dim.mz
  if (cut_x ne -1) then slice_dim.l2 = slice_dim.mx - dim.nghostx - 1
  if (cut_y ne -1) then slice_dim.m2 = slice_dim.my - dim.nghosty - 1
  if (cut_z ne -1) then slice_dim.n2 = slice_dim.mz - dim.nghostz - 1
;
;  Read meta data and set up variable/tag lists.
;
  if (n_elements (varcontent) eq 0) then $
      varcontent = pc_varcontent(datadir=datadir,dim=dim,param=param,quiet=quiet)
  totalvars = (size(varcontent))[1]
  if (n_elements (var_list) eq 0) then begin
    var_list = varcontent[*].idlvar
    var_list = var_list[where (var_list ne "dummy")]
  endif
;
; Display information about the files contents.
;
  content = ''
  for iv=0L, totalvars-1L do begin
    content += ', '+varcontent[iv].variable
    ; For vector quantities skip the required number of elements of the f array.
    iv += varcontent[iv].skip
  endfor
  content = strmid (content, 2)
;
  tags = { time:0.0d0 }
  read_content = ''
  indices = [ -1 ]
  num_read = 0
  num = n_elements (var_list)
  for ov=0L, num-1L do begin
    tag = var_list[ov]
    iv = where (varcontent[*].idlvar eq tag)
    if (iv ge 0) then begin
      if (tag eq "uu") then begin
        tags = create_struct (tags, "uu", [num_read, num_read+1, num_read+2])
        tags = create_struct (tags, "ux", num_read, "uy", num_read+1, "uz", num_read+2)
        indices = [ indices, iv, iv+1, iv+2 ]
        num_read += 3
      endif else if (tag eq "aa") then begin
        tags = create_struct (tags, "aa", [num_read, num_read+1, num_read+2])
        tags = create_struct (tags, "ax", num_read, "ay", num_read+1, "az", num_read+2)
        indices = [ indices, iv, iv+1, iv+2 ]
        num_read += 3
      endif else begin
        tags = create_struct (tags, tag, num_read)
        indices = [ indices, iv ]
        num_read++
      endelse
      read_content += ', '+varcontent[iv].variable
    endif
  endfor
  read_content = strmid (read_content, 2)
  if (not keyword_set(quiet)) then begin
    print, ''
    print, 'The file '+varfile+' contains: ', content
    if (strlen (read_content) lt strlen (content)) then print, 'Will read only: ', read_content
    print, ''
    print, 'The slice dimension is ', slice_dim.mx, slice_dim.my, slice_dim.mz
    print, ''
  endif
  if (num_read le 0) then begin
    if (not keyword_set(quiet)) then message, 'ERROR: nothing to read!'
    return
  end
  indices = indices[where (indices ge 0)]
;
; Initialise read buffers.
;
  if (precision eq 'D') then begin
    bytes = 8
    object = dblarr (cut_nx, cut_ny, cut_nz, num_read)
    buffer = dblarr (px_delta)
  endif else begin
    bytes = 4
    object = fltarr (cut_nx, cut_ny, cut_nz, num_read)
    buffer = fltarr (px_delta)
  endelse
  if (f77 eq 0) then markers = 0 else markers = 1
;
; Iterate over processors.
;
  for ipz = ipz_start, ipz_end do begin
    for ipy = ipy_start, ipy_end do begin
      for ipx = ipx_start, ipx_end do begin
        iproc = ipx + ipy*dim.nprocx + ipz*dim.nprocx*dim.nprocy
        x_off = ipx * procdim.nx
        y_off = ipy * procdim.ny
        if (allprocs eq 2) then z_off = 0 else z_off = ipz * procdim.nz
        if (allprocs eq 1) then begin
          procdir = 'allprocs'
        end else begin
          procdir = 'proc' + strtrim (iproc, 2)
        end
;
; Build the full path and filename.
;
        filename = datadir+'/'+procdir+'/'+varfile
;
; Check for existence and read the data.
;
        if (not file_test(filename)) then $
            message, 'ERROR: File not found "'+filename+'"'
;
; Open a varfile and read some data!
;
        openr, lun, filename, swap_endian=swap_endian, /get_lun
        mx = long64 (procdim.mx)
        mxy = mx * procdim.my
        mxyz = mxy * procdim.mz
        for pos = 0, num_read-1 do begin
          pa = indices[pos]
          for pz = pz_start, pz_end do begin
            for py = py_start, py_end do begin
              point_lun, lun, bytes * (px_start + py*mx + pz*mxy + pa*mxyz) + long64 (markers*4)
              readu, lun, buffer
              object[x_off:x_off+px_delta-1,y_off+py-py_start,z_off+pz-pz_start,pos] = buffer
            endfor
          endfor
        endfor
        close, lun
        free_lun, lun
      end
    end
  end
;
; Tidy memory a little.
;
  undefine, buffer
;
; Read timestamp.
;
  pc_read_var_time, time=t, varfile=varfile, datadir=datadir, allprocs=allprocs, procdim=procdim, param=param, /quiet
;
; Crop grid.
;
  x_off = ipx_start * procdim.nx + px_start
  y_off = ipy_start * procdim.ny + py_start
  z_off = ipz_start * procdim.nz + pz_start
  x = grid.x[x_off:x_off+cut_nx-1]
  y = grid.y[y_off:y_off+cut_ny-1]
  z = grid.z[z_off:z_off+cut_nz-1]
;
; Prepare for derivatives.
;
  dx = grid.dx
  dy = grid.dy
  dz = grid.dz
  dx_1 = grid.dx_1[x_off:x_off+cut_nx-1]
  dy_1 = grid.dy_1[y_off:y_off+cut_ny-1]
  dz_1 = grid.dz_1[z_off:z_off+cut_nz-1]
  dx_tilde = grid.dx_tilde[x_off:x_off+cut_nx-1]
  dy_tilde = grid.dy_tilde[y_off:y_off+cut_ny-1]
  dz_tilde = grid.dz_tilde[z_off:z_off+cut_nz-1]
  if (cut_x ne -1) then Lx = 1.0/dx_1[dim.nghostx] else Lx = grid.Lx
  if (cut_y ne -1) then Ly = 1.0/dy_1[dim.nghosty] else Ly = grid.Ly
  if (cut_z ne -1) then Lz = 1.0/dz_1[dim.nghostz] else Lz = grid.Lz
;
; Remove ghost zones if requested.
;
  if (keyword_set(trimall)) then begin
    l1 = slice_dim.l1
    l2 = slice_dim.l2
    m1 = slice_dim.m1
    m2 = slice_dim.m2
    n1 = slice_dim.n1
    n2 = slice_dim.n2
    object = reform (object[l1:l2,m1:m2,n1:n2,*])
    x = x[l1:l2]
    y = y[m1:m2]
    z = z[n1:n2]
    dx_1 = dx_1[l1:l2]
    dy_1 = dy_1[m1:m2]
    dz_1 = dz_1[n1:n2]
    dx_tilde = dx_tilde[l1:l2]
    dy_tilde = dy_tilde[m1:m2]
    dz_tilde = dz_tilde[n1:n2]
    addname += "trimmed_"
  endif
;
  if (not keyword_set(quiet)) then begin
    print, ' t = ', t
    print, ''
  endif
;
  time = t
  tags.time = t
  name = "pc_read_slice_raw_"+addname+strtrim (cut_nx, 2)+"_"+strtrim (cut_ny, 2)+"_"+strtrim (cut_nz, 2)
  grid = create_struct (name=name, $
      ['t', 'x', 'y', 'z', 'dx', 'dy', 'dz', 'Lx', 'Ly', 'Lz', 'dx_1', 'dy_1', 'dz_1', 'dx_tilde', 'dy_tilde', 'dz_tilde'], $
      t, x, y, z, dx, dy, dz, Lx, Ly, Lz, dx_1, dy_1, dz_1, dx_tilde, dy_tilde, dz_tilde)
;
end
