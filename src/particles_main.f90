! $Id: particles_main.f90,v 1.65 2008-03-19 00:29:04 wlyra Exp $
!
!  This module contains all the main structure needed for particles.
!
module Particles_main

  use Cdata
  use Messages
  use Particles
  use Particles_cdata
  use Particles_nbody
  use Particles_number
  use Particles_radius
  use Particles_selfgravity
  use Particles_stalker
  use Particles_sub

  implicit none

  include 'particles_main.h'

  real, dimension (mpar_loc,mpvar) :: fp, dfp
  integer, dimension (mpar_loc,3) :: ineargrid

  contains

!***********************************************************************
    subroutine particles_register_modules()
!
!  Register particle modules.
!
!  07-jan-05/anders: coded
!
      call register_particles         ()
      call register_particles_radius  ()
      call register_particles_number  ()
      call register_particles_selfgrav()
      call register_particles_nbody   ()
!
    endsubroutine particles_register_modules
!***********************************************************************
    subroutine particles_rprint_list(lreset)
!
!  Read names of diagnostic particle variables to print out during run.
!
!  07-jan-05/anders: coded
!
      logical :: lreset
!
      if (lroot) open(3, file=trim(datadir)//'/index.pro', &
          STATUS='old', POSITION='append')
      call rprint_particles         (lreset,LWRITE=lroot)
      call rprint_particles_radius  (lreset,LWRITE=lroot)
      call rprint_particles_number  (lreset,LWRITE=lroot)
      call rprint_particles_selfgrav(lreset,LWRITE=lroot)
      call rprint_particles_nbody   (lreset,LWRITE=lroot)
      if (lroot) close(3)
!
    endsubroutine particles_rprint_list
!***********************************************************************
    subroutine particles_initialize_modules(lstarting)
!
!  Initialize particle modules.
!
!  07-jan-05/anders: coded
!
      logical :: lstarting
!
!  Check if there is enough total space allocated for particles.
!
      if (ncpus*mpar_loc<npar) then
        if (lroot) then
          print*, 'particles_initialize_modules: '// &
          'total number of particle slots available at the processors '// &
          'is smaller than the number of particles!'
          print*, 'particles_initialize_modules: npar/ncpus=', npar/ncpus
          print*, 'particles_initialize_modules: mpar_loc-ncpus*npar_mig=', &
              mpar_loc-ncpus*npar_mig
        endif
        call fatal_error('particles_initialize_modules','')
      endif
!
      call initialize_particles         (lstarting)
      call initialize_particles_radius  (lstarting)
      call initialize_particles_number  (lstarting)
      call initialize_particles_selfgrav(lstarting)
      call initialize_particles_nbody   (lstarting)
      call initialize_particles_stalker (lstarting)
!
!  Set internal and external radii of particles
!  (moved here from start.f90)
!
      if (rp_int == -impossible .and. r_int > epsi) &
           rp_int = r_int
      if (rp_ext == -impossible) rp_ext = r_ext
!
    endsubroutine particles_initialize_modules
!***********************************************************************
    subroutine particles_init(f)
!
!  Set up initial condition for particle modules.
!
!  07-jan-05/anders: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      intent (out) :: f
!
      call init_particles(f,fp,ineargrid)
      if (lparticles_radius) call init_particles_radius(f,fp)
      if (lparticles_number) call init_particles_number(f,fp)
      if (lparticles_nbody)  call init_particles_nbody(f,fp)
!
    endsubroutine particles_init
!***********************************************************************
    subroutine particles_read_snapshot(filename)
!
!  Read particle snapshot from file.
!
!  07-jan-05/anders: coded
!
      character (len=*) :: filename
!
      call input_particles(filename,fp,npar_loc,ipar)
!
    endsubroutine particles_read_snapshot
!***********************************************************************
    subroutine particles_write_snapshot(chsnap,enum,flist)
!
!  Write particle snapshot to file.
!
!  07-jan-05/anders: coded
!
      logical :: enum
      character (len=*) :: chsnap,flist
      optional :: flist
!
      logical :: lsnap
!
      if (present(flist)) then
        call wsnap_particles(chsnap,fp,enum,lsnap,dsnap_par_minor, &
            npar_loc,ipar,flist)
      else
        call wsnap_particles(chsnap,fp,enum,lsnap,dsnap_par_minor, &
            npar_loc,ipar)
      endif
!
    endsubroutine particles_write_snapshot
!***********************************************************************
    subroutine particles_write_dsnapshot(chsnap,enum,flist)
!
!  Write particle derivative snapshot to file.
!
!  07-jan-05/anders: coded
!
      logical :: enum
      character (len=*) :: chsnap,flist
      optional :: flist
!
      logical :: lsnap
!
      if (present(flist)) then
        call wsnap_particles(chsnap,dfp,enum,lsnap,dsnap_par_minor, &
            npar_loc,ipar,flist)
      else
        call wsnap_particles(chsnap,dfp,enum,lsnap,dsnap_par_minor, &
            npar_loc,ipar)
      endif
!
    endsubroutine particles_write_dsnapshot
!***********************************************************************
    subroutine particles_write_pdim(filename)
!
!  Write npar and mpvar to file.
!
!  09-jan-05/anders: coded
!
      character (len=*) :: filename
!
      open(1,file=filename)
        write(1,'(3i9)') npar, mpvar, npar_stalk
      close(1)
!
    endsubroutine particles_write_pdim
!***********************************************************************
    subroutine particles_timestep_first()
!
!  Setup dfp in the beginning of each itsub.
!
!  07-jan-05/anders: coded
!
      if (itsub==1) then
        dfp(1:npar_loc,:)=0.
      else
        dfp(1:npar_loc,:)=alpha_ts(itsub)*dfp(1:npar_loc,:)
      endif
!
    endsubroutine particles_timestep_first
!***********************************************************************
    subroutine particles_timestep_second()
!
!  Time evolution of particle variables.
!
!  07-jan-05/anders: coded
!
      fp(1:npar_loc,:) = fp(1:npar_loc,:) + dt_beta_ts(itsub)*dfp(1:npar_loc,:)
!
    endsubroutine particles_timestep_second
!***********************************************************************
    subroutine particles_boundconds(f)
!
!  Particle boundary conditions and parallel communication.
!
!  16-feb-06/anders: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call boundconds_particles(fp,npar_loc,ipar,dfp=dfp)
!
!  Map the particle positions on the grid for later use.
!
      call map_nearest_grid(fp,ineargrid)
      call map_xxp_grid(f,fp,ineargrid)
!
!  Sort particles so that they can be accessed contiguously in the memory.
!
      call sort_particles_imn(fp,ineargrid,ipar,dfp=dfp)
!
      if (lparticles_nbody) call share_sinkparticles(fp)
!
    endsubroutine particles_boundconds
!***********************************************************************
    subroutine particles_calc_selfpotential(f,rhs_poisson,rhs_poisson_const,lcontinued)
!
!  Calculate the potential of the dust particles (wrapper).
!
!  13-jun-06/anders: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (nx,ny,nz) :: rhs_poisson
      real :: rhs_poisson_const
      logical :: lcontinued
!
      call calc_selfpotential_particles(f,rhs_poisson,rhs_poisson_const,lcontinued)
!
    endsubroutine particles_calc_selfpotential
!***********************************************************************
    subroutine particles_calc_nbodygravity(f)
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call calc_nbodygravity_particles(f)
!
    endsubroutine particles_calc_nbodygravity
!***********************************************************************
    subroutine particles_pencil_criteria()
!
!  Request pencils for particles.
!
!  20-apr-06/anders: coded
!
      call pencil_criteria_particles()
      if (lparticles_radius) call pencil_criteria_par_radius()
      if (lparticles_number) call pencil_criteria_par_number()
      if (lparticles_selfgravity) call pencil_criteria_par_selfgrav()
      if (lparticles_nbody) call pencil_criteria_par_nbody()
!
    endsubroutine particles_pencil_criteria
!***********************************************************************
    subroutine particles_pencil_interdep(lpencil_in)
!
!  Calculate particle pencils.
!
!  15-feb-06/anders: coded
!
      logical, dimension(npencils) :: lpencil_in
!
      call pencil_interdep_particles(lpencil_in)
      if (lparticles_selfgravity) call pencil_interdep_par_selfgrav(lpencil_in)
      if (lparticles_nbody) call pencil_interdep_par_nbody(lpencil_in)
!
    endsubroutine particles_pencil_interdep
!***********************************************************************
    subroutine particles_calc_pencils(f,p)
!
!  Calculate particle pencils.
!
!  14-feb-06/anders: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      call calc_pencils_particles(f,p)
      if (lparticles_selfgravity) call calc_pencils_par_selfgrav(f,p)
      if (lparticles_nbody) call calc_pencils_par_nbody(f,p)
!
    endsubroutine particles_calc_pencils
!***********************************************************************
    subroutine particles_pde_pencil(f,df,p)
!
!  Dynamical evolution of particle variables.
!
!  20-apr-06/anders: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      intent (in) :: p
      intent (inout) :: f, df
!
!  Create shepherd/neighbour list of required.
!
      if (allocated(kneighbour)) &
          call shepherd_neighbour(f,fp,ineargrid,kshepherd,kneighbour)
!
!  Dynamical equations.
!
      call dxxp_dt_pencil(f,df,fp,dfp,p,ineargrid)
      call dvvp_dt_pencil(f,df,fp,dfp,p,ineargrid)
      if (lparticles_radius) call dap_dt_pencil(f,df,fp,dfp,p,ineargrid)
      if (lparticles_number) call dnptilde_dt_pencil(f,df,fp,dfp,p,ineargrid)
      if (lparticles_selfgravity) &
          call dvvp_dt_selfgrav_pencil(f,df,fp,dfp,p,ineargrid)
      if (lparticles_nbody) &
          call dvvp_dt_nbody_pencil(f,df,fp,dfp,p,ineargrid)
!
    endsubroutine particles_pde_pencil
!***********************************************************************
    subroutine particles_pde(f,df)
!
!  Dynamical evolution of particle variables.
!
!  07-jan-05/anders: coded
!
      use Mpicomm
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
!
      intent (out) :: f, df
!
!  Write information about local environment to file.
!
      if (itsub==1) call particles_stalker_sub(f,fp,ineargrid)
!
!  Dynamical equations.
!
      call dxxp_dt(f,df,fp,dfp,ineargrid)
      call dvvp_dt(f,df,fp,dfp,ineargrid)
      if (lparticles_radius)      call dap_dt(f,df,fp,dfp,ineargrid)
      if (lparticles_number)      call dnptilde_dt(f,df,fp,dfp,ineargrid)
      if (lparticles_selfgravity) call dvvp_dt_selfgrav(f,df,fp,dfp,ineargrid)
      if (lparticles_nbody) then
         call dxxp_dt_nbody(dfp)
         call dvvp_dt_nbody(f,df,fp,dfp,ineargrid)
      endif
!
!  Correct for curvilinear geometry
!
      call correct_curvilinear
!
    endsubroutine particles_pde
!***********************************************************************    
    subroutine correct_curvilinear
!
!  Curvilinear corrections to acceleration only.
!  Corrections to velocity were already taken into account
!  in the dxx_dp of particles_dust.f90
!
!  15-sep-07/wlad: coded
!
      real :: rad,raddot,phidot,thtdot,sintht,costht
      integer :: k


      do k=1,npar_loc
!
! Correct acceleration
!
        if (lcylindrical_coords) then
          rad=fp(k,ixp);raddot=fp(k,ivpx);phidot=fp(k,ivpy)/rad
          dfp(k,ivpx) = dfp(k,ivpx) + rad*phidot**2
          dfp(k,ivpy) = dfp(k,ivpy) - 2*raddot*phidot
        elseif (lspherical_coords) then
          rad=fp(k,ixp)
          sintht=sin(fp(k,iyp));costht=cos(fp(k,iyp))
          raddot=fp(k,ivpx);thtdot=fp(k,ivpy)/rad
          phidot=fp(k,ivpz)/(rad*sintht)
!
          dfp(k,ivpx) = dfp(k,ivpx) &
               + rad*(thtdot**2 + (sintht*phidot)**2)
          dfp(k,ivpy) = dfp(k,ivpy) &
               - 2*raddot*thtdot + rad*sintht*costht*phidot**2
          dfp(k,ivpz) = dfp(k,ivpz) &
               - 2*phidot*(sintht*raddot + rad*costht*thtdot)
        endif
      enddo
!
    endsubroutine correct_curvilinear
!***********************************************************************
    subroutine particles_create_sinks(f)
!
! Fetch fp and ineargrid to create sinks
!
! 14-mar-08/wlad : coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!     
      if (lparticles_nbody) &
           call create_sink_particles(f,fp,ineargrid)
!
    endsubroutine particles_create_sinks
!***********************************************************************
    subroutine read_particles_init_pars_wrap(unit,iostat)
!
      integer, intent (in) :: unit
      integer, intent (inout), optional :: iostat
!
      call read_particles_init_pars(unit,iostat)
      if (lparticles_radius) call read_particles_rad_init_pars(unit,iostat)
      if (lparticles_number) call read_particles_num_init_pars(unit,iostat)
      if (lparticles_selfgravity) &
          call read_particles_selfg_init_pars(unit,iostat)
      if (lparticles_nbody) &
          call read_particles_nbody_init_pars(unit,iostat)
      if (lparticles_stalker) &
          call read_pstalker_init_pars(unit,iostat)
!
    endsubroutine read_particles_init_pars_wrap
!***********************************************************************
    subroutine write_particles_init_pars_wrap(unit)
!
      integer, intent (in) :: unit
!
      call write_particles_init_pars(unit)
      if (lparticles_radius) call write_particles_rad_init_pars(unit)
      if (lparticles_number) call write_particles_num_init_pars(unit)
      if (lparticles_selfgravity) &
          call write_particles_selfg_init_pars(unit)
      if (lparticles_nbody) &
          call write_particles_nbody_init_pars(unit)
      if (lparticles_stalker) &
          call write_pstalker_init_pars(unit)
!
    endsubroutine write_particles_init_pars_wrap
!***********************************************************************
    subroutine read_particles_run_pars_wrap(unit,iostat)
!
      integer, intent (in) :: unit
      integer, intent (inout), optional :: iostat
!
      call read_particles_run_pars(unit,iostat)
      if (lparticles_radius) call read_particles_rad_run_pars(unit,iostat)
      if (lparticles_number) call read_particles_num_run_pars(unit,iostat)
      if (lparticles_selfgravity) &
          call read_particles_selfg_run_pars(unit,iostat)
      if (lparticles_nbody) &
          call read_particles_nbody_run_pars(unit,iostat)
      if (lparticles_stalker) &
          call read_pstalker_run_pars(unit,iostat)
!
    endsubroutine read_particles_run_pars_wrap
!***********************************************************************
    subroutine write_particles_run_pars_wrap(unit)
!
      integer, intent (in) :: unit
!
      call write_particles_run_pars(unit)
      if (lparticles_radius) call write_particles_rad_run_pars(unit)
      if (lparticles_number) call write_particles_num_run_pars(unit)
      if (lparticles_selfgravity) &
          call write_particles_selfg_run_pars(unit)
      if (lparticles_nbody) &
           call write_particles_nbody_run_pars(unit)
      if (lparticles_stalker) &
           call write_pstalker_run_pars(unit)
!
    endsubroutine write_particles_run_pars_wrap
!***********************************************************************
    subroutine particles_powersnap(f)
!
!  Calculate power spectra of particle variables.
!
!  01-jan-06/anders: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      call powersnap_particles(f)
!
    endsubroutine particles_powersnap
!***********************************************************************
    subroutine get_slices_particles(f,slices)
!
!  Write slices for animation of particle variables.
!
!  26-jun-06/anders: split from wvid
!  26-jun-06/tony: Rewrote to give Slices module responsibility for
!                  how and when slices are written
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
!
!  Loop over slices
!
      select case (trim(slices%name))
!
!  Dust number density (auxiliary variable)
!
        case ('np')
          slices%yz= f(slices%ix,m1:m2    ,n1:n2     ,inp)
          slices%xz= f(l1:l2    ,slices%iy,n1:n2     ,inp)
          slices%xy= f(l1:l2    ,m1:m2    ,slices%iz ,inp)
          slices%xy2=f(l1:l2    ,m1:m2    ,slices%iz2,inp)
          slices%ready = .true.
!
!  Dust density (auxiliary variable)
!
        case ('rhop')
          if (irhop/=0) then
            slices%yz= f(slices%ix,m1:m2    ,n1:n2     ,irhop)
            slices%xz= f(l1:l2    ,slices%iy,n1:n2     ,irhop)
            slices%xy= f(l1:l2    ,m1:m2    ,slices%iz ,irhop)
            slices%xy2=f(l1:l2    ,m1:m2    ,slices%iz2,irhop)
            slices%ready = .true.
          else
            slices%yz= rhop_tilde * f(slices%ix,m1:m2    ,n1:n2     ,inp)
            slices%xz= rhop_tilde * f(l1:l2    ,slices%iy,n1:n2     ,inp)
            slices%xy= rhop_tilde * f(l1:l2    ,m1:m2    ,slices%iz ,inp)
            slices%xy2=rhop_tilde * f(l1:l2    ,m1:m2    ,slices%iz2,inp)
           slices%ready = .true.
          endif
!
      endselect
!
    endsubroutine get_slices_particles
!***********************************************************************
endmodule Particles_main
