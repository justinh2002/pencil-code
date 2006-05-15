! $Id: noselfgravity.f90,v 1.1 2006-05-15 21:30:50 ajohan Exp $

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Selfgravity

  use Cdata
  use Cparam
  use Messages

  implicit none

  include 'selfgravity.h'

  contains

!***********************************************************************
    subroutine register_selfgravity()
!
!  Register self gravity variables.
!
!  15-may-06/anders+jeff: dummy
!
      use Cdata
!
      lselfgravity=.false.
!
    endsubroutine register_selfgravity
!***********************************************************************
    subroutine initialize_selfgravity()
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  15-may-06/anders+jeff: dummy
!
    endsubroutine initialize_selfgravity
!***********************************************************************
    subroutine pencil_criteria_selfgravity()
! 
!  All pencils that the Selfgravity module depends on are specified here.
! 
!  15-may-06/anders+jeff: dummy
!
    endsubroutine pencil_criteria_selfgravity
!***********************************************************************
    subroutine pencil_interdep_selfgravity(lpencil_in)
!
!  Interdependency among pencils from the Selfgravity module is specified here.
!
!  15-may-06/anders+jeff: dummy
!
      logical, dimension(npencils) :: lpencil_in
!
      if (NO_WARN) print*, lpencil_in !(keep compiler quiet)
!
    endsubroutine pencil_interdep_selfgravity
!***********************************************************************
    subroutine calc_pencils_selfgravity(f,p)
!
!  Calculate Selfgravity pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  15-may-06/anders+jeff: dummy
!
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (pencil_case) :: p
!      
      if (NO_WARN) print*, f, p !(keep compiler quiet)
!
    endsubroutine calc_pencils_selfgravity
!***********************************************************************
    subroutine calc_selfpotential(f)
!
!  Calculate the potential of self gravity.
!
!  15-may-06/anders+jeff: dummy
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      if (NO_WARN) print*, f
!
    endsubroutine calc_selfpotential
!***********************************************************************
    subroutine duu_dt_selfgrav(f,df,p)
!
!  Add self gravity acceleration on gas.
!
!  15-may-06/anders+jeff: dummy
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      if (NO_WARN) print*, f, df, p !(keep compiler quiet)
!        
    endsubroutine duu_dt_selfgrav
!***********************************************************************
    subroutine read_selfgravity_init_pars(unit,iostat)
!
!  Read self gravity init parameters
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (NO_WARN) print*, unit, iostat
!
    endsubroutine read_selfgravity_init_pars
!***********************************************************************
    subroutine write_selfgravity_init_pars(unit)
!
!  Write self gravity init parameters
!
      integer, intent(in) :: unit
!
      if (NO_WARN) print*, unit
!
    endsubroutine write_selfgravity_init_pars
!***********************************************************************
    subroutine read_selfgravity_run_pars(unit,iostat)
!
!  Read self gravity run parameters
!    
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (NO_WARN) print*, unit, iostat
!
    endsubroutine read_selfgravity_run_pars
!***********************************************************************
    subroutine write_selfgravity_run_pars(unit)
!
!  Write self gravity run parameters
!
      integer, intent(in) :: unit
!
      if (NO_WARN) print*, unit
!
    endsubroutine write_selfgravity_run_pars
!***********************************************************************
    subroutine rprint_selfgravity(lreset,lwrite)
!
!  reads and registers print parameters relevant for gravity advance
!  dummy routine
!
!  12-jun-04/axel: adapted from grav_z
!
      logical :: lreset
      logical, optional :: lwrite
!
      if (NO_WARN) print*, lreset, lwrite !(to keep compiler quiet)
!        
    endsubroutine rprint_selfgravity
!***********************************************************************

endmodule Selfgravity
