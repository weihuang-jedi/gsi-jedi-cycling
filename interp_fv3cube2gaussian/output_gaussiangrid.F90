!----------------------------------------------------------------------------------------

subroutine write_gaussiangrid(gaussian, flnm)

   use netcdf
   use gaussian_module
   use status_module

   implicit none

   type(gaussiangrid), intent(inout) :: gaussian
   character(len=*), intent(in) :: flnm

   integer :: i, j, n, rc

   gaussian%filename = flnm

   rc = nf90_noerr

   !Create the file. 
   rc = nf90_create(trim(flnm), NF90_CLOBBER, gaussian%ncid)
   call check_status(rc)

  !print *, 'gaussian%ncid = ', gaussian%ncid

   rc = nf90_def_dim(gaussian%ncid, 'lon', gaussian%nlon, gaussian%dimid_lon)
   call check_status(rc)
   rc = nf90_def_dim(gaussian%ncid, 'lat', gaussian%nlat, gaussian%dimid_lat)
   call check_status(rc)
   rc = nf90_def_dim(gaussian%ncid, 'lev', gaussian%nlev, gaussian%dimid_lev)
   call check_status(rc)
   rc = nf90_def_dim(gaussian%ncid, 'ilev', gaussian%nilev, gaussian%dimid_ilev)
   call check_status(rc)
   rc = nf90_def_dim(gaussian%ncid, 'pnt', gaussian%npnt, gaussian%dimid_pnt)
   call check_status(rc)

   call write_global_attr4gaussian(gaussian%ncid, flnm, 'Weight of Grid', 'Gaussian')

   call write_var_attr4gaussian(gaussian)

  !End define mode.
   rc = nf90_enddef(gaussian%ncid)
   if(rc /= nf90_noerr) then
      write(unit=0, fmt='(a,i6,a)') "Problem to enddef gaussian%ncid: <", gaussian%ncid, ">."
      write(unit=0, fmt='(2a)') "Error status: ", trim(nf90_strerror(rc))
      write(unit=0, fmt='(3a, i4)') &
           "Stop in file: <", __FILE__, ">, line: ", __LINE__
      stop
   end if

   !write lon
   call nc_put1Dvar0(gaussian%ncid, 'lon', gaussian%lon, 1, gaussian%nlon)

   !write lat
   call nc_put1Dvar0(gaussian%ncid, 'lat', gaussian%lat, 1, gaussian%nlat)

   !write lev
   call nc_put1Dvar0(gaussian%ncid, 'lev', gaussian%lev, 1, gaussian%nlev)

   !write ilev
   call nc_put1Dvar0(gaussian%ncid, 'ilev', gaussian%ilev, 1, gaussian%nilev)

   !write pnt
   call nc_put1Dvar0(gaussian%ncid, 'pnt', gaussian%pnt, 1, gaussian%npnt)

   !write hyai
   call nc_put1Dvar0(gaussian%ncid, 'hyai', gaussian%hyai, 1, gaussian%nilev)

   !write hybi
   call nc_put1Dvar0(gaussian%ncid, 'hybi', gaussian%hybi, 1, gaussian%nilev)

   !--write pos
   call nc_put2Dvar0(gaussian%ncid, 'pos', gaussian%pos, 1, gaussian%nlon, 1, gaussian%nlat)

   !--write tile
   call nc_put3Dint0(gaussian%ncid, 'tile', gaussian%tile, 1, gaussian%nlon, &
                     1, gaussian%nlat, 1, gaussian%npnt)

   !--write ilon
   call nc_put3Dint0(gaussian%ncid, 'ilon', gaussian%ilon, 1, gaussian%nlon, &
                     1, gaussian%nlat, 1, gaussian%npnt)

   !--write jlat
   call nc_put3Dint0(gaussian%ncid, 'jlat', gaussian%jlat, 1, gaussian%nlon, &
                     1, gaussian%nlat, 1, gaussian%npnt)

   !--write wgt
   call nc_put3Dvar0(gaussian%ncid, 'wgt', gaussian%wgt, 1, gaussian%nlon, &
                     1, gaussian%nlat, 1, gaussian%npnt)

   rc =  nf90_close(gaussian%ncid)

  !print *, 'nf90_close rc = ', rc
  !print *, 'nf90_noerr = ', nf90_noerr

   if(rc /= nf90_noerr) then
      write(unit=0, fmt='(a,i6,a)') "Problem to close gaussian%ncid: <", gaussian%ncid, ">."
      write(unit=0, fmt='(2a)') "Error status: ", trim(nf90_strerror(rc))
      write(unit=0, fmt='(3a, i4)') &
           "Stop in file: <", __FILE__, ">, line: ", __LINE__
      stop
   end if

  !print *, 'Finished Write to file: ', trim(flnm)

end subroutine write_gaussiangrid

!-------------------------------------------------------------------------------------
subroutine write_var_attr4gaussian(gaussian)

   use netcdf
   use gaussian_module

   implicit none

   type(gaussiangrid), intent(in) :: gaussian

   integer, dimension(6) :: dimids
   integer :: rc, nd
   integer :: missing_int
   real    :: missing_real

   missing_real = -1.0e38
   missing_int = -999999

   dimids(1) = gaussian%dimid_lon
   nd = 1
!--Field lon
   call nc_putAxisAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                      "lon", &
                      "Lontitude Coordinate", &
                      "degree_east", &
                      "Longitude" )

   dimids(1) = gaussian%dimid_lat
   nd = 1
!--Field lat
   call nc_putAxisAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                      "lat", &
                      "Latitude Coordinate", &
                      "degree_north", &
                      "Latitude" )

   dimids(1) = gaussian%dimid_lev
   nd = 1
!--Field lev
   call nc_putAxisAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                      "lev", &
                      "Level Coordinate", &
                      "top_down", &
                      "Half Level" )

   dimids(1) = gaussian%dimid_ilev
   nd = 1
!--Field ilev
   call nc_putAxisAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                      "ilev", &
                      "Level Coordinate", &
                      "top_down", &
                      "Full Level" )

   dimids(1) = gaussian%dimid_pnt
   nd = 1
!--Field pnt
   call nc_putAxisAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                      "pnt", &
                      "Points for Weighting", &
                      "unitless", &
                      "Point" )

   dimids(1) = gaussian%dimid_ilev
   nd = 1
!--Field hyai
   call nc_putAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                  "hyai", &
                  "Hydro A index", &
                  "hPa", &
                  "ilev", &
                  missing_real)

   dimids(1) = gaussian%dimid_ilev
   nd = 1
!--Field hybi
   call nc_putAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                  "hybi", &
                  "Hydro B index", &
                  "unitless", &
                  "ilev", &
                   missing_real)

   dimids(1) = gaussian%dimid_lon
   dimids(2) = gaussian%dimid_lat
   nd = 2

!--Field 1, pos
   call nc_putAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                   "pos", &
                   "Postion in Tile", &
                   "unitless", &
                   "lat lon", &
                   missing_real)

   dimids(1) = gaussian%dimid_lon
   dimids(2) = gaussian%dimid_lat
   dimids(3) = gaussian%dimid_pnt
   nd = 3
!--Field 2, tile
   call nc_putAttrInt(gaussian%ncid, nd, dimids, NF90_INT, &
                   "tile", &
                   "Tile Number of Grid", &
                   "unitless", &
                   "pnt lat lon", &
                   missing_int)

!--Field 3, ilon
   call nc_putAttrInt(gaussian%ncid, nd, dimids, NF90_INT, &
                   "ilon", &
                   "Index of Longitude", &
                   "unitless", &
                   "pnt lat lon", &
                   missing_int)

!--Field 4, jlat
   call nc_putAttrInt(gaussian%ncid, nd, dimids, NF90_INT, &
                   "jlat", &
                   "Index of Latitude", &
                   "unitless", &
                   "pnt lat lon", &
                   missing_int)

!--Field 5, wgt
   call nc_putAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                   "wgt", &
                   "Weight of Grids", &
                   "unitless", &
                   "pnt lat lon", &
                   missing_real)

end subroutine write_var_attr4gaussian

!---------------------------------------------------------------------------
subroutine write_global_attr4gaussian(ncid, filename, title, type)

   implicit none

   integer, intent(in) :: ncid
   character(len = *), intent(in) :: filename, title, type

  !output global attributes
   call nc_putGlobalCharAttr(ncid, 'filename', trim(filename))
   call nc_putGlobalCharAttr(ncid, 'title', trim(title))
   call nc_putGlobalCharAttr(ncid, 'grid_type', trim(type))

end subroutine write_global_attr4gaussian

