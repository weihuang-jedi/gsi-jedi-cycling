!----------------------------------------------------------------------------------------

subroutine read_weights4gaussian(gaussian, wgt_flnm)

   use netcdf
   use gaussian_module
   use status_module

   implicit none

   type(gaussiangrid), intent(inout) :: gaussian
   character(len=*),   intent(in) :: wgt_flnm

   integer :: ncid, dimidx, dimidy, dimidp

   integer :: i, j, n, status

  !print *, 'Start Read weights from file: ', trim(wgt_flnm)

   status = nf90_noerr

   n = 0

   !Open the file. 
   status = nf90_open(trim(wgt_flnm), nf90_nowrite, ncid)
   call check_status(status)

   gaussian%ncid = ncid

   !read lon
   call nc_get1Dvar0(ncid, 'lon', gaussian%lon, 1, gaussian%nlon)

   !read lat
   call nc_get1Dvar0(ncid, 'lat', gaussian%lat, 1, gaussian%nlat)

   !read lev
   call nc_get1Dvar0(ncid, 'lev', gaussian%lev, 1, gaussian%nlev)

   !read hyai
   call nc_get1Dvar0(ncid, 'hyai', gaussian%hyai, 1, gaussian%nilev)

   !read hybi
   call nc_get1Dvar0(ncid, 'hybi', gaussian%hybi, 1, gaussian%nilev)

   !read pnt
   call nc_get1Dvar0(ncid, 'pnt', gaussian%pnt, 1, gaussian%npnt)

   !--read tile
   call nc_get3Dint0(ncid, 'tile', gaussian%tile, 1, gaussian%nlon, &
                     1, gaussian%nlat, 1, gaussian%npnt)

   !--read ilon
   call nc_get3Dint0(ncid, 'ilon', gaussian%ilon, 1, gaussian%nlon, &
                     1, gaussian%nlat, 1, gaussian%npnt)

   !--read jlat
   call nc_get3Dint0(ncid, 'jlat', gaussian%jlat, 1, gaussian%nlon, &
                     1, gaussian%nlat, 1, gaussian%npnt)

   !--read wgt
   call nc_get3Dvar0(ncid, 'wgt', gaussian%wgt, 1, gaussian%nlon, &
                     1, gaussian%nlat, 1, gaussian%npnt)

   status =  nf90_close(ncid)
   call check_status(status)

  !print *, 'Finished Read weights from file: ', trim(wgt_flnm)

end subroutine read_weights4gaussian

