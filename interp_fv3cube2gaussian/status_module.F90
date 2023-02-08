!-----------------------------------------------------------------------
!  The status module check the return code meaning
!-----------------------------------------------------------------------

module status_module

  use netcdf

  implicit none

  public :: check_status

contains

  !----------------------------------------------------------------------
  subroutine check_status(rc)

    implicit none

    integer, intent(in) :: rc
    
    if(rc /= nf90_noerr) then 
      print *, trim(nf90_strerror(rc))
      print *, 'rc = ', rc, ', nf90_noerr = ', nf90_noerr
      stop 'in check_status'
    end if

  end subroutine check_status  

end module status_module

