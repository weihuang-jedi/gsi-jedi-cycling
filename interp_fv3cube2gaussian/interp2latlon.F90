!----------------------------------------------------------------------------------------
subroutine generate_header(k, tile, latlon, gridtype, flnm, last)
  
   use netcdf
   use tile_module
   use latlon_module

   implicit none

   integer, intent(in)                         :: k
   type(tilegrid), dimension(6), intent(inout) :: tile
   type(latlongrid), intent(inout)             :: latlon
   character(len=*), intent(in)                :: gridtype, flnm
   logical, intent(in)                         :: last

   integer :: rc

  !print *, 'Enter generate_header'
  !print *, 'k = ', k
  !print *, 'gridtype = ', trim(gridtype)
  !print *, 'flnm = ', trim(flnm)
  
   if(k == 1) then
      call create_coord(tile(1)%nt, tile(1)%time(1:tile(1)%nt), latlon, flnm)
   end if
  
   if('fv_core.res.tile' == trim(gridtype)) then
      call create_fv_core_var_attr(tile, latlon)
   else if('sfc_data.tile' == trim(gridtype)) then
      call create_sfc_data_var_attr(tile, latlon)
   else if('fv_tracer.res.tile' == trim(gridtype)) then
      call create_fv_tracer_var_attr(tile, latlon)
   else if('fv_srf_wnd.res.tile' == trim(gridtype)) then
      call create_fv_srf_wnd_var_attr(tile, latlon)
   else if('phy_data.tile' == trim(gridtype)) then
      call create_phy_data_var_attr(tile, latlon)
   end if

  !print *, 'last = ', last

   if(last) then
     !End define mode.
      rc = nf90_enddef(latlon%ncid)
      if(rc /= nf90_noerr) then
         write(unit=0, fmt='(a,i6,a)') "Problem to enddef ncid: <", latlon%ncid, ">."
         write(unit=0, fmt='(2a)') "Error status: ", trim(nf90_strerror(rc))
         write(unit=0, fmt='(3a, i4)') &
              "Stop in file: <", __FILE__, ">, line: ", __LINE__
         stop
      end if
   end if

  !print *, 'Leave generate_header'

end subroutine generate_header

!----------------------------------------------------------------------------------------
subroutine interp2latlongrid(gridtype, spec, gridstruct, tile, latlon)

   use netcdf
   use tile_module
   use fv_grid_utils_module
   use latlon_module

   implicit none

   character(len=*),                  intent(in)    :: gridtype
   type(tilespec_type), dimension(6), intent(in)    :: spec
   type(fv_grid_type), dimension(6), intent(in)     :: gridstruct
   type(tilegrid), dimension(6),      intent(inout) :: tile
   type(latlongrid),                  intent(inout) :: latlon

  !print *, 'Enter interp2latlongrid'
  !print *, 'gridtype = ', trim(gridtype)

   if('fv_core.res.tile' == trim(gridtype)) then
      call process_fv_core(spec, tile, gridstruct, latlon)
   else if('sfc_data.tile' == trim(gridtype)) then
      call process_sfc_data(tile, latlon)
   else if('fv_tracer.res.tile' == trim(gridtype)) then
      call process_fv_tracer(tile, latlon)
   else if('fv_srf_wnd.res.tile' == trim(gridtype)) then
      call process_fv_srf_wnd(tile, latlon)
   else if('phy_data.tile' == trim(gridtype)) then
      call process_phy_data(tile, latlon)
   end if

end subroutine interp2latlongrid

!---------------------------------------------------------------------------
subroutine create_global_attr(ncid, filename, title, type)

   implicit none

   integer, intent(in) :: ncid
   character(len = *), intent(in) :: filename, title, type

  !print *, 'Enter create_global_attr'

 ! ----put global attributes----
   call nc_putGlobalCharAttr(ncid, 'filename', trim(filename))
   call nc_putGlobalCharAttr(ncid, 'title', trim(title))
   call nc_putGlobalCharAttr(ncid, 'grid_type', trim(type))

  !call nc_putGlobalIntAttr(ncid, 'WRF_for_first_guess', iwrf)

  !call nc_putGlobalRealAttr(ncid, 'top_height',bdytop)

end subroutine create_global_attr

!----------------------------------------------------------------------------------------
subroutine create_coord(nt, time, latlon, flnm)

   use netcdf
   use latlon_module
   use tile_module, only : check_status

   implicit none

   integer,          intent(in)              :: nt
   real(kind=8), dimension(1:nt), intent(in) :: time
   type(latlongrid), intent(inout)           :: latlon
   character(len=*), intent(in)              :: flnm

   integer :: i, nd, rc, ncid

   integer, dimension(2) :: dimids

   real, dimension(1) :: hor
   real, dimension(latlon%nlev) :: lev
   real, dimension(latlon%nlay) :: lay

   logical :: fileExists

  !print *, 'Enter create_coord'
  !print *, 'flnm = ', trim(flnm)
  !print *, 'nt = ', nt
  !print *, 'time(1:nt) = ', time(1:nt)

  !print *, 'latlon%nlon = ',  latlon%nlon
  !print *, 'latlon%nlat = ',  latlon%nlat
  !print *, 'latlon%nlev = ',  latlon%nlev
  !print *, 'latlon%nlay = ',  latlon%nlay

   latlon%filename = trim(flnm)

   allocate(latlon%lev(latlon%nlev))

   do i = 1, latlon%nlev
      latlon%lev(i) = real(i-1)
      lev(i) = real(i-1)
   end do

   allocate(latlon%lay(latlon%nlay))

   do i = 1, latlon%nlay
      latlon%lay(i) = real(i-1)
      lay(i) = real(i-1)
   end do

   hor(1) = 0.0

  !print *, 'latlon%lon = ',  latlon%lon
  !print *, 'latlon%lat = ',  latlon%lat
  !print *, 'latlon%lev = ',  latlon%lev
  !print *, 'latlon%lay = ',  latlon%lay

   rc = nf90_noerr

   latlon%dimidt = -1

  !Create the file. 
   inquire(file=trim(flnm), exist=fileExists)
   if (fileExists) then
     !call nf90_open(filePath, NF90_WRITE, ncid)
      open(unit=1234, iostat=rc, file=trim(flnm), status='old')
      if(rc == 0) close(1234, status='delete')
   end if

  !rc = nf90_create(trim(flnm), NF90_CLOBBER, ncid)
   rc = nf90_create(trim(flnm), NF90_NETCDF4, ncid)
   call check_status(rc)

   latlon%ncid = ncid
  !print *, 'ncid = ', ncid

   rc = nf90_def_dim(ncid, 'lon', latlon%nlon, latlon%dimidx)
   call check_status(rc)
   rc = nf90_def_dim(ncid, 'lat', latlon%nlat, latlon%dimidy)
   call check_status(rc)
   rc = nf90_def_dim(ncid, 'lev', latlon%nlev, latlon%dimidz)
   call check_status(rc)
   rc = nf90_def_dim(ncid, 'layer', latlon%nlay, latlon%dimidl)
   call check_status(rc)
   rc = nf90_def_dim(ncid, 'hor', 1, latlon%dimidh)
   call check_status(rc)
  !rc = nf90_def_dim(ncid, 'Time', NF90_UNLIMITED, latlon%dimidt)
  !call check_status(rc)

   call create_global_attr(ncid, flnm, 'FV3 to Lat-Lon Grid', 'Lat-Lon Grid')

   dimids(1) = latlon%dimidx
   nd = 1
!--Field lon
   call nc_putAxisAttr(ncid, nd, dimids, NF90_REAL, &
                      'lon', &
                      "Lontitude Coordinate", &
                      "degree_east", &
                      "Longitude" )

   dimids(1) = latlon%dimidy
!--Field lat
   call nc_putAxisAttr(ncid, nd, dimids, NF90_REAL, &
                      'lat', &
                      "Latitude Coordinate", &
                      "degree_north", &
                      "Latitude" )

   dimids(1) = latlon%dimidz
!--Field lev
   call nc_putAxisAttr(ncid, nd, dimids, NF90_REAL, &
                      'lev', &
                      "Altitude Coordinate", &
                      "top_down", &
                      "Altitude" )

   dimids(1) = latlon%dimidl
!--Field lay
   call nc_putAxisAttr(ncid, nd, dimids, NF90_REAL, &
                      'layer', &
                      "Layer Coordinate", &
                      "top_down", &
                      "Altitude" )

   dimids(1) = latlon%dimidh
!--Field hor
   call nc_putAxisAttr(ncid, nd, dimids, NF90_REAL, &
                      "hor", &
                      "Horizontal Coordinate", &
                      "one_lev", &
                      "Horizontal" )

   dimids(1) = latlon%dimidt
!--Field time
  !call nc_putAxisAttr(ncid, nd, dimids, NF90_REAL8, &
  !                   "Time", &
  !                   "Time Coordinate", &
  !                   "time lev", &
  !                   "Time" )

  !write lon
   call nc_put1Dvar0(ncid, 'lon', latlon%lon, 1, latlon%nlon)

  !write lat
   call nc_put1Dvar0(ncid, 'lat', latlon%lat, 1, latlon%nlat)

  !write lev
  !call nc_put1Dvar0(ncid, 'lev', latlon%lev, 1, latlon%nlev)
   call nc_put1Dvar0(ncid, 'lev', lev, 1, latlon%nlev)

  !write lay
  !call nc_put1Dvar0(ncid, 'layer', latlon%lay, 1, latlon%nlay)
   call nc_put1Dvar0(ncid, 'layer', lay, 1, latlon%nlay)

  !write hor
   call nc_put1Dvar0(ncid, 'hor', hor, 1, 1)

  !write time
  !call nc_put1Ddbl0(ncid, 'Time', time, 1, nt)

  !print *, 'Leave create_coord'
end subroutine create_coord

!-------------------------------------------------------------------------------------
subroutine create_fv_core_var_attr(tile, latlon)

   use netcdf
   use namelist_module
   use tile_module
   use latlon_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(latlongrid), intent(inout)             :: latlon

   integer, dimension(4) :: dimids
   integer :: rc, nd, i
   integer :: missing_int
   real    :: missing_real
   character(len=80) :: long_name, units, coordinates, outname

  !print *, 'Enter create_fv_core_var_attr'
  !print *, 'File: ', __FILE__, ', line: ', __LINE__

   missing_real = -1.0e38
   missing_int = -999999

   do i = 1, tile(1)%nVars
     !if((trim(tile(1)%vars(i)%varname) == 'xaxis_1') .or. &
     !   (trim(tile(1)%vars(i)%varname) == 'xaxis_2') .or. &
     !   (trim(tile(1)%vars(i)%varname) == 'yaxis_1') .or. &
     !   (trim(tile(1)%vars(i)%varname) == 'yaxis_2') .or. &
     !   (trim(tile(1)%vars(i)%varname) == 'zaxis_1') .or. &
     !   (trim(tile(1)%vars(i)%varname) == 'Time')) then
     !   cycle
     !end if

      if(tile(1)%vars(i)%nDims < 2) cycle

      units = 'unknown'
     !coordinates = 'Time lev lat lon'
      coordinates = 'lev lat lon'
      dimids(1) = latlon%dimidx
      dimids(2) = latlon%dimidy
      dimids(3) = latlon%dimidz
     !dimids(4) = latlon%dimidt
     !nd = 4
      nd = 3

     !print *, 'File: ', __FILE__, ', line: ', __LINE__
     !print *, 'Var No ', i, ' name: ', trim(tile(1)%vars(i)%varname)

      outname = trim(tile(1)%vars(i)%varname)
      long_name = trim(tile(1)%vars(i)%varname)
      if((trim(tile(1)%vars(i)%varname) == 'ps') .or. &
         (trim(tile(1)%vars(i)%varname) == 'phis')) then
         dimids(3) = latlon%dimidh
         coordinates = 'hor lat lon'
         if(trim(tile(1)%vars(i)%varname) == 'ps') then
            long_name = 'surface_pressure'
            units = 'Pa'
         else if(trim(tile(1)%vars(i)%varname) == 'phis') then
            long_name = 'surface_geopotential_height'
            units = 'm'
         end if
      else if((trim(tile(1)%vars(i)%varname) == 'ua') .or. &
              (trim(tile(1)%vars(i)%varname) == 'va') .or. &
              (trim(tile(1)%vars(i)%varname) == 'W') .or. &
              (trim(tile(1)%vars(i)%varname) == 'delp') .or. &
              (trim(tile(1)%vars(i)%varname) == 'DZ') .or. &
              (trim(tile(1)%vars(i)%varname) == 'T')) then
         if(trim(tile(1)%vars(i)%varname) == 'T') then
            long_name = 'air_temperature'
            units = 'K'
         else if(trim(tile(1)%vars(i)%varname) == 'delp') then
            long_name = 'air_pressure_thick'
            units = 'Pa'
         else if(trim(tile(1)%vars(i)%varname) == 'DZ') then
            long_name = 'layer_thickness'
            units = 'm'
         else if(trim(tile(1)%vars(i)%varname) == 'ua') then
            outname = 'ua'
            long_name = 'eastward_wind'
            units = 'm/s'
         else if(trim(tile(1)%vars(i)%varname) == 'va') then
            outname = 'va'
            long_name = 'northward_wind'
            units = 'm/s'
         end if
      end if

     !print *, 'File: ', __FILE__, ', line: ', __LINE__
     !print *, 'outname: ', trim(outname)

      call nc_putAttr(latlon%ncid, nd, dimids, NF90_REAL, &
                      trim(outname), &
                      trim(long_name), trim(units), &
                      trim(coordinates), missing_real)
   end do

  !print *, 'Leave create_fv_core_var_attr'

end subroutine create_fv_core_var_attr

!-------------------------------------------------------------------------------------
subroutine create_sfc_data_var_attr(tile, latlon)

   use netcdf
   use tile_module
   use latlon_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(latlongrid), intent(inout)             :: latlon

   integer, dimension(4) :: dimids
   integer :: rc, nd, i, j
   integer :: missing_int
   real    :: missing_real
   character(len=80) :: long_name, units, coordinates

  !print *, 'Enter create_sfc_data_var_attr'

   missing_real = -1.0e38
   missing_int = -999999

   do i = 1, tile(1)%nVars
      j = tile(1)%vars(i)%ndims

     !print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), '>, ndims = ', &
     !         tile(1)%vars(i)%ndims

      if(tile(1)%vars(i)%ndims < 3) then
         cycle
      end if

      if('Time' /= trim(tile(1)%vars(i)%dimnames(j))) then
         cycle
      end if

      long_name = 'unknown'
      units = 'unknown'
      dimids(1) = latlon%dimidx
      dimids(2) = latlon%dimidy

      if(3 == tile(1)%vars(i)%ndims) then
       !coordinates = 'Time lat lon'
        coordinates = 'lat lon'
       !dimids(3) = latlon%dimidt
       !nd = 3
        nd = 2
      else if(4 == tile(1)%vars(i)%ndims) then
       !coordinates = 'Time layer lat lon'
        coordinates = 'layer lat lon'
        dimids(3) = latlon%dimidl
       !dimids(4) = latlon%dimidt
       !nd = 4
        nd = 3
      else
        print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                 '>, ndims = ', tile(1)%vars(i)%ndims

        print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
      end if

      long_name = trim(tile(1)%vars(i)%varname)

      call nc_putAttr(latlon%ncid, nd, dimids, NF90_REAL, &
                      trim(tile(1)%vars(i)%varname), &
                      trim(long_name), trim(units), &
                      trim(coordinates), missing_real)
   end do

end subroutine create_sfc_data_var_attr

!-------------------------------------------------------------------------------------
subroutine create_fv_tracer_var_attr(tile, latlon)

   use netcdf
   use tile_module
   use latlon_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(latlongrid), intent(inout)             :: latlon

   integer, dimension(4) :: dimids
   integer :: rc, nd, i, j
   integer :: missing_int
   real    :: missing_real
   character(len=80) :: long_name, units, coordinates

  !print *, 'Enter create_fv_tracer_var_attr'

   missing_real = -1.0e38
   missing_int = -999999

   do i = 1, tile(1)%nVars
      j = tile(1)%vars(i)%ndims

     !print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), '>, ndims = ', &
     !         tile(1)%vars(i)%ndims

      if(tile(1)%vars(i)%ndims < 3) then
         cycle
      end if

      if('Time' /= trim(tile(1)%vars(i)%dimnames(j))) then
         cycle
      end if

      long_name = trim(tile(1)%vars(i)%varname)
      units = 'none'
     !coordinates = 'Time lev lat lon'
      coordinates = 'lev lat lon'

      dimids(1) = latlon%dimidx
      dimids(2) = latlon%dimidy
      dimids(3) = latlon%dimidz
     !dimids(4) = latlon%dimidt
     !nd = 4
      nd = 3

      if(4 /= tile(1)%vars(i)%ndims) then
        print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                 '>, ndims = ', tile(1)%vars(i)%ndims

        print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
      end if

      call nc_putAttr(latlon%ncid, nd, dimids, NF90_REAL, &
                      trim(tile(1)%vars(i)%varname), &
                      trim(long_name), trim(units), &
                      trim(coordinates), missing_real)
   end do

end subroutine create_fv_tracer_var_attr

!-------------------------------------------------------------------------------------
subroutine create_fv_srf_wnd_var_attr(tile, latlon)

   use netcdf
   use tile_module
   use latlon_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(latlongrid), intent(inout)             :: latlon

   integer, dimension(4) :: dimids
   integer :: rc, nd, i, j
   integer :: missing_int
   real    :: missing_real
   character(len=80) :: long_name, units, coordinates

  !print *, 'Enter create_fv_srf_wnd_var_attr'

   missing_real = -1.0e38
   missing_int = -999999

   do i = 1, tile(1)%nVars
      j = tile(1)%vars(i)%ndims

     !print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), '>, ndims = ', &
     !         tile(1)%vars(i)%ndims

      if(tile(1)%vars(i)%ndims < 3) then
         cycle
      end if

      if('Time' /= trim(tile(1)%vars(i)%dimnames(j))) then
         cycle
      end if

      long_name = trim(tile(1)%vars(i)%varname)
      units = 'none'
     !coordinates = 'Time lat lon'
      coordinates = 'lat lon'

      dimids(1) = latlon%dimidx
      dimids(2) = latlon%dimidy
     !dimids(3) = latlon%dimidt
     !nd = 3
      nd = 2

      if(3 /= tile(1)%vars(i)%ndims) then
        print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                 '>, ndims = ', tile(1)%vars(i)%ndims

        print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
      end if

      call nc_putAttr(latlon%ncid, nd, dimids, NF90_REAL, &
                      trim(tile(1)%vars(i)%varname), &
                      trim(long_name), trim(units), &
                      trim(coordinates), missing_real)
   end do

end subroutine create_fv_srf_wnd_var_attr

!-------------------------------------------------------------------------------------
subroutine create_phy_data_var_attr(tile, latlon)

   use netcdf
   use tile_module
   use latlon_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(latlongrid), intent(inout)             :: latlon

   integer, dimension(4) :: dimids
   integer :: rc, nd, i, j
   integer :: missing_int
   real    :: missing_real
   character(len=80) :: long_name, units, coordinates

  !print *, 'Enter create_phy_data_var_attr'

   missing_real = -1.0e38
   missing_int = -999999

   do i = 1, tile(1)%nVars
      j = tile(1)%vars(i)%ndims

     !print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), '>, ndims = ', &
     !         tile(1)%vars(i)%ndims

      if(tile(1)%vars(i)%ndims < 3) then
         cycle
      end if

      if('Time' /= trim(tile(1)%vars(i)%dimnames(j))) then
         cycle
      end if

      long_name = 'unknown'
      units = 'unknown'
      dimids(1) = latlon%dimidx
      dimids(2) = latlon%dimidy

      if(3 == tile(1)%vars(i)%ndims) then
       !coordinates = 'Time lat lon'
        coordinates = 'lat lon'
       !dimids(3) = latlon%dimidt
       !nd = 3
        nd = 2
      else if(4 == tile(1)%vars(i)%ndims) then
       !coordinates = 'Time lev lat lon'
        coordinates = 'lev lat lon'
        dimids(3) = latlon%dimidz
       !dimids(4) = latlon%dimidt
       !nd = 4
        nd = 3
      else
        print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                 '>, ndims = ', tile(1)%vars(i)%ndims

        print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
      end if

      long_name = trim(tile(1)%vars(i)%varname)

      call nc_putAttr(latlon%ncid, nd, dimids, NF90_REAL, &
                      trim(tile(1)%vars(i)%varname), &
                      trim(long_name), trim(units), &
                      trim(coordinates), missing_real)
   end do

end subroutine create_phy_data_var_attr

!----------------------------------------------------------------------------------------
subroutine process_fv_core(spec, tile, gridstruct, latlon)

   use netcdf
   use namelist_module
   use tile_module
   use fv_grid_utils_module
   use latlon_module

   implicit none

   type(tilespec_type), dimension(6), intent(in)    :: spec
   type(tilegrid), dimension(6),      intent(inout) :: tile
   type(fv_grid_type), dimension(6),  intent(in)    :: gridstruct
   type(latlongrid),                  intent(inout) :: latlon

   integer :: i, n, rc, uv_count

   real, dimension(:,:,:), allocatable :: var2d
   real, dimension(:,:,:), allocatable :: var3d, u

  !print *, 'Enter process_fv_core'

   allocate(var2d(latlon%nlon, latlon%nlat, 1))
   allocate(var3d(latlon%nlon, latlon%nlat, latlon%nlev))
   allocate(u(latlon%nlon, latlon%nlat, latlon%nlev))

   uv_count = 0
   do i = 1, tile(1)%nVars
     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         ndims=tile(1)%vars(i)%nDims, natts=tile(1)%vars(i)%nAtts)
     !call check_status(rc)

     !print *, 'Var No. ', i, ': ndims = ', tile(1)%vars(i)%nDims

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         dimids=tile(1)%vars(i)%dimids)
     !call check_status(rc)

      rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
               name=tile(1)%vars(i)%varname)
      call check_status(rc)

     !print *, 'Var No. ', i, ': name: ', trim(tile(1)%vars(i)%varname)
     !print *, 'Var No. ', i, ': varid: ', tile(1)%varids(i)

      if(tile(1)%vars(i)%nDims < 2) cycle

     !print *, 'P 1, Var No. ', i, ': name: ', trim(tile(1)%vars(i)%varname)

      do n = 1, 6
         rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                  name=tile(n)%vars(i)%varname)
         call check_status(rc)

        !print *, 'Tile ', n, ', Var No. ', i, ': varid: ', tile(n)%varids(i)
        !print *, 'Tile ', n, ', Var ', i, ': ', trim(tile(n)%vars(i)%varname)

         if((trim(tile(n)%vars(i)%varname) == 'ps') .or. &
            (trim(tile(n)%vars(i)%varname) == 'phis')) then
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%var2d)
            call check_status(rc)
         else if((trim(tile(n)%vars(i)%varname) == 'ua') .or. &
                 (trim(tile(n)%vars(i)%varname) == 'va') .or. &
                 (trim(tile(n)%vars(i)%varname) == 'W') .or. &
                 (trim(tile(n)%vars(i)%varname) == 'delp') .or. &
                 (trim(tile(n)%vars(i)%varname) == 'DZ') .or. &
                 (trim(tile(n)%vars(i)%varname) == 'T')) then
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%var3d)
            call check_status(rc)
         end if
      end do

     !print *, 'P 2, Var No. ', i, ': name: ', trim(tile(1)%vars(i)%varname)
     !print *, 'File: ', __FILE__, ', at line: ', __LINE__

      if((trim(tile(1)%vars(i)%varname) == 'ps') .or. &
         (trim(tile(1)%vars(i)%varname) == 'phis')) then
         call interp2dvar(tile, latlon, var2d)
        !call nc_put3Dvar(latlon%ncid, trim(tile(1)%vars(i)%varname), &
        !     var2d, 1, 1, latlon%nlon, 1, latlon%nlat, 1, 1)
         call nc_put3Dvar0(latlon%ncid, trim(tile(1)%vars(i)%varname), &
              var2d, 1, latlon%nlon, 1, latlon%nlat, 1, 1)
      else if((trim(tile(1)%vars(i)%varname) == 'ua') .or. &
              (trim(tile(1)%vars(i)%varname) == 'va') .or. &
              (trim(tile(1)%vars(i)%varname) == 'W') .or. &
              (trim(tile(1)%vars(i)%varname) == 'delp') .or. &
              (trim(tile(1)%vars(i)%varname) == 'DZ') .or. &
              (trim(tile(1)%vars(i)%varname) == 'T')) then
         call interp3dvar(tile, latlon, var3d)
        !call nc_put3Dvar(latlon%ncid, trim(tile(1)%vars(i)%varname), &
        !     var3d, 1, 1, latlon%nlon, 1, latlon%nlat, 1, latlon%nlev)
         call nc_put3Dvar0(latlon%ncid, trim(tile(1)%vars(i)%varname), &
              var3d, 1, latlon%nlon, 1, latlon%nlat, 1, latlon%nlev)
      end if
   end do

   deallocate(var2d)
   deallocate(var3d)
   deallocate(u)

  !print *, 'Leave process_fv_core'

end subroutine process_fv_core

!----------------------------------------------------------------------
subroutine process_sfc_data(tile, latlon)

   use netcdf
   use tile_module
   use latlon_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(latlongrid), intent(inout)             :: latlon

   integer :: i, j, n, rc

   real, dimension(:,:), allocatable :: var2d
   real, dimension(:,:,:), allocatable :: var3d

  !print *, 'Enter process_sfc_data'

   allocate(var2d(latlon%nlon, latlon%nlat))
   allocate(var3d(latlon%nlon, latlon%nlat, latlon%nlay))

   do i = 1, tile(1)%nVars
      j = tile(1)%vars(i)%ndims

     !print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), &
     !         '>, ndims = ', tile(1)%vars(i)%ndims

      if(tile(1)%vars(i)%ndims < 3) then
         cycle
      end if

      if('Time' /= trim(tile(1)%vars(i)%dimnames(j))) then
         cycle
      end if

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         ndims=tile(1)%vars(i)%nDims, natts=tile(1)%vars(i)%nAtts)
     !call check_status(rc)

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         dimids=tile(1)%vars(i)%dimids)
     !call check_status(rc)

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         name=tile(1)%vars(i)%varname)
     !call check_status(rc)

     !print *, 'Var No. ', i, ' name: ', trim(tile(1)%vars(i)%varname)
     !print *, 'Var No. ', i, ': varid: ', tile(1)%varids(i)
     !print *, 'Var No. ', i, ', ndims = ', tile(1)%vars(i)%ndims

      do n = 1, 6
         rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                  name=tile(n)%vars(i)%varname)
         call check_status(rc)

        !print *, 'Tile ', n, ', Var No. ', i, ': varid: ', tile(n)%varids(i)
        !print *, 'Tile ', n, ', Var ', i, ': ', trim(tile(n)%vars(i)%varname)

         if(3 == tile(1)%vars(i)%ndims) then
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%var2d)
            call check_status(rc)
         else if(4 == tile(1)%vars(i)%ndims) then
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%var3d)
            call check_status(rc)
         else
           print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                    '>, ndims = ', tile(1)%vars(i)%ndims

           print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
         end if
      end do

     !print *, 'Var No. ', i, ' name: ', trim(tile(1)%vars(i)%varname)
     !print *, 'Var No. ', i, ': varid: ', tile(1)%varids(i)
     !print *, 'Var No. ', i, ', ndims = ', tile(1)%vars(i)%ndims

     !do j = 1, tile(1)%vars(i)%ndims
        !print *, 'Dim ', j, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), &
        !         '>, len = ', tile(1)%vars(i)%dimlen(j)
     !end do

      if(3 == tile(1)%vars(i)%ndims) then
         call interp2dvar4sfc(tile, latlon, var2d)
        !call nc_put3Dvar1(latlon%ncid, trim(tile(1)%vars(i)%varname), &
        !     var2d, 1, 1, latlon%nlon, 1, latlon%nlat)
         call nc_put2Dvar0(latlon%ncid, trim(tile(1)%vars(i)%varname), &
              var2d, 1, latlon%nlon, 1, latlon%nlat)
      else if(4 == tile(1)%vars(i)%ndims) then
         call interp3dvar4sfc(tile, latlon, var3d)
        !call nc_put3Dvar(latlon%ncid, trim(tile(1)%vars(i)%varname), &
        !     var3d, 1, 1, latlon%nlon, 1, latlon%nlat, 1, latlon%nlay)
         call nc_put3Dvar0(latlon%ncid, trim(tile(1)%vars(i)%varname), &
              var3d, 1, latlon%nlon, 1, latlon%nlat, 1, latlon%nlay)
      else
         print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                  '>, ndims = ', tile(1)%vars(i)%ndims

         print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
      end if
   end do

   deallocate(var2d)
   deallocate(var3d)

end subroutine process_sfc_data

!----------------------------------------------------------------------------------------
subroutine process_fv_tracer(tile, latlon)

   use netcdf
   use tile_module
   use latlon_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(latlongrid), intent(inout)             :: latlon

   integer :: i, j, n, rc

   real, dimension(:,:,:), allocatable :: var3d

  !print *, 'Enter process_fv_tracer'

   allocate(var3d(latlon%nlon, latlon%nlat, latlon%nlev))

   do i = 1, tile(1)%nVars
      j = tile(1)%vars(i)%ndims

     !print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), &
     !         '>, ndims = ', tile(1)%vars(i)%ndims

      if(tile(1)%vars(i)%ndims < 3) then
         cycle
      end if

      if('Time' /= trim(tile(1)%vars(i)%dimnames(j))) then
         cycle
      end if

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         ndims=tile(1)%vars(i)%nDims, natts=tile(1)%vars(i)%nAtts)
     !call check_status(rc)

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         dimids=tile(1)%vars(i)%dimids)
     !call check_status(rc)

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         name=tile(1)%vars(i)%varname)
     !call check_status(rc)

     !print *, 'Var No. ', i, ' name: ', trim(tile(1)%vars(i)%varname)
     !print *, 'Var No. ', i, ': varid: ', tile(1)%varids(i)
     !print *, 'Var No. ', i, ', ndims = ', tile(1)%vars(i)%ndims

      do n = 1, 6
         rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                  name=tile(n)%vars(i)%varname)
         call check_status(rc)

        !print *, 'Tile ', n, ', Var No. ', i, ': varid: ', tile(n)%varids(i)
        !print *, 'Tile ', n, ', Var ', i, ': ', trim(tile(n)%vars(i)%varname)

         if(4 == tile(1)%vars(i)%ndims) then
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%var3d)
            call check_status(rc)
         else
           print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                    '>, ndims = ', tile(1)%vars(i)%ndims

           print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
         end if
      end do

     !print *, 'Var No. ', i, ' name: ', trim(tile(1)%vars(i)%varname)
     !print *, 'Var No. ', i, ': varid: ', tile(1)%varids(i)
     !print *, 'Var No. ', i, ', ndims = ', tile(1)%vars(i)%ndims

     !do j = 1, tile(1)%vars(i)%ndims
        !print *, 'Dim ', j, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), &
        !         '>, len = ', tile(1)%vars(i)%dimlen(j)
     !end do

      if(4 == tile(1)%vars(i)%ndims) then
         call interp3dvar(tile, latlon, var3d)
        !call nc_put3Dvar(latlon%ncid, trim(tile(1)%vars(i)%varname), &
        !     var3d, 1, 1, latlon%nlon, 1, latlon%nlat, 1, latlon%nlev)
         call nc_put3Dvar0(latlon%ncid, trim(tile(1)%vars(i)%varname), &
              var3d, 1, latlon%nlon, 1, latlon%nlat, 1, latlon%nlev)
      else
         print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                  '>, ndims = ', tile(1)%vars(i)%ndims

         print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
      end if
   end do

   deallocate(var3d)

end subroutine process_fv_tracer

!----------------------------------------------------------------------------------------
subroutine process_fv_srf_wnd(tile, latlon)

   use netcdf
   use tile_module
   use latlon_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(latlongrid), intent(inout)             :: latlon

   integer :: i, j, n, rc

   real, dimension(:,:), allocatable :: var2d

  !print *, 'Enter process_fv_srf_wnd'

   allocate(var2d(latlon%nlon, latlon%nlat))

   do i = 1, tile(1)%nVars
      j = tile(1)%vars(i)%ndims

     !print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), &
     !         '>, ndims = ', tile(1)%vars(i)%ndims

      if(tile(1)%vars(i)%ndims < 3) then
         cycle
      end if

      if('Time' /= trim(tile(1)%vars(i)%dimnames(j))) then
         cycle
      end if

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         ndims=tile(1)%vars(i)%nDims, natts=tile(1)%vars(i)%nAtts)
     !call check_status(rc)

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         dimids=tile(1)%vars(i)%dimids)
     !call check_status(rc)

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         name=tile(1)%vars(i)%varname)
     !call check_status(rc)

     !print *, 'Var No. ', i, ' name: ', trim(tile(1)%vars(i)%varname)
     !print *, 'Var No. ', i, ': varid: ', tile(1)%varids(i)
     !print *, 'Var No. ', i, ', ndims = ', tile(1)%vars(i)%ndims

      do n = 1, 6
         rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                  name=tile(n)%vars(i)%varname)
         call check_status(rc)

        !print *, 'Tile ', n, ', Var No. ', i, ': varid: ', tile(n)%varids(i)
        !print *, 'Tile ', n, ', Var ', i, ': ', trim(tile(n)%vars(i)%varname)

         if(3 == tile(1)%vars(i)%ndims) then
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%var2d)
            call check_status(rc)
         else
           print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                    '>, ndims = ', tile(1)%vars(i)%ndims

           print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
         end if
      end do

     !print *, 'Var No. ', i, ' name: ', trim(tile(1)%vars(i)%varname)
     !print *, 'Var No. ', i, ': varid: ', tile(1)%varids(i)
     !print *, 'Var No. ', i, ', ndims = ', tile(1)%vars(i)%ndims

     !do j = 1, tile(1)%vars(i)%ndims
        !print *, 'Dim ', j, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), &
        !         '>, len = ', tile(1)%vars(i)%dimlen(j)
     !end do

      if(3 == tile(1)%vars(i)%ndims) then
         call interp2dvar4sfc(tile, latlon, var2d)
        !call nc_put3Dvar1(latlon%ncid, trim(tile(1)%vars(i)%varname), &
        !     var2d, 1, 1, latlon%nlon, 1, latlon%nlat)
         call nc_put2Dvar0(latlon%ncid, trim(tile(1)%vars(i)%varname), &
              var2d, 1, latlon%nlon, 1, latlon%nlat)
      else
         print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                  '>, ndims = ', tile(1)%vars(i)%ndims

         print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
      end if
   end do

   deallocate(var2d)

end subroutine process_fv_srf_wnd

!----------------------------------------------------------------------------------------
subroutine process_phy_data(tile, latlon)

   use netcdf
   use tile_module
   use latlon_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(latlongrid), intent(inout)             :: latlon

   integer :: i, j, n, rc

   real, dimension(:,:), allocatable :: var2d
   real, dimension(:,:,:), allocatable :: var3d

  !print *, 'Enter process_phy_data'

   allocate(var2d(latlon%nlon, latlon%nlat))
   allocate(var3d(latlon%nlon, latlon%nlat, latlon%nlev))

   do i = 1, tile(1)%nVars
      j = tile(1)%vars(i)%ndims

     !print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), &
     !         '>, ndims = ', tile(1)%vars(i)%ndims

      if(tile(1)%vars(i)%ndims < 3) then
         cycle
      end if

      if('Time' /= trim(tile(1)%vars(i)%dimnames(j))) then
         cycle
      end if

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         ndims=tile(1)%vars(i)%nDims, natts=tile(1)%vars(i)%nAtts)
     !call check_status(rc)

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         dimids=tile(1)%vars(i)%dimids)
     !call check_status(rc)

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         name=tile(1)%vars(i)%varname)
     !call check_status(rc)

     !print *, 'Var No. ', i, ' name: ', trim(tile(1)%vars(i)%varname)
     !print *, 'Var No. ', i, ': varid: ', tile(1)%varids(i)
     !print *, 'Var No. ', i, ', ndims = ', tile(1)%vars(i)%ndims

      do n = 1, 6
         rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                  name=tile(n)%vars(i)%varname)
         call check_status(rc)

        !print *, 'Tile ', n, ', Var No. ', i, ': varid: ', tile(n)%varids(i)
        !print *, 'Tile ', n, ', Var ', i, ': ', trim(tile(n)%vars(i)%varname)

         if(3 == tile(1)%vars(i)%ndims) then
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%var2d)
            call check_status(rc)
         else if(4 == tile(1)%vars(i)%ndims) then
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%var3d)
            call check_status(rc)
         else
           print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                    '>, ndims = ', tile(1)%vars(i)%ndims

           print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
         end if
      end do

     !print *, 'Var No. ', i, ' name: ', trim(tile(1)%vars(i)%varname)
     !print *, 'Var No. ', i, ': varid: ', tile(1)%varids(i)
     !print *, 'Var No. ', i, ', ndims = ', tile(1)%vars(i)%ndims

     !do j = 1, tile(1)%vars(i)%ndims
        !print *, 'Dim ', j, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), &
        !         '>, len = ', tile(1)%vars(i)%dimlen(j)
     !end do

      if(3 == tile(1)%vars(i)%ndims) then
         call interp2dvar4sfc(tile, latlon, var2d)
        !call nc_put3Dvar1(latlon%ncid, trim(tile(1)%vars(i)%varname), &
        !     var2d, 1, 1, latlon%nlon, 1, latlon%nlat)
         call nc_put2Dvar0(latlon%ncid, trim(tile(1)%vars(i)%varname), &
              var2d, 1, latlon%nlon, 1, latlon%nlat)
      else if(4 == tile(1)%vars(i)%ndims) then
         call interp3dvar(tile, latlon, var3d)
        !call nc_put3Dvar(latlon%ncid, trim(tile(1)%vars(i)%varname), &
        !     var3d, 1, 1, latlon%nlon, 1, latlon%nlat, 1, latlon%nlev)
         call nc_put3Dvar0(latlon%ncid, trim(tile(1)%vars(i)%varname), &
              var3d, 1, latlon%nlon, 1, latlon%nlat, 1, latlon%nlev)
      else
         print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                  '>, ndims = ', tile(1)%vars(i)%ndims

         print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
      end if
   end do

   deallocate(var2d)
   deallocate(var3d)

end subroutine process_phy_data

!----------------------------------------------------------------------
subroutine interp2dvar(tile, latlon, var2d)

  use tile_module
  use latlon_module

  implicit none

  type(tilegrid), dimension(6), intent(in) :: tile
  type(latlongrid), intent(in) :: latlon
  real, dimension(latlon%nlon, latlon%nlat, 1), intent(out) :: var2d

  integer :: i, j, n, ik, jk, m
  real :: w

  do jk = 1, latlon%nlat
  do ik = 1, latlon%nlon
     var2d(ik, jk, 1) = 0.0

     do m = 1, latlon%npnt
        n = latlon%tile(ik, jk, m)
        i = latlon%ilon(ik, jk, m)
        j = latlon%jlat(ik, jk, m)
        w = latlon%wgt(ik, jk, m)

        var2d(ik, jk, 1) = var2d(ik, jk, 1) + w*tile(n)%var2d(i, j)
     end do
  end do
  end do

end subroutine interp2dvar

!----------------------------------------------------------------------
subroutine interp3dvar(tile, latlon, var3d)

  use tile_module
  use latlon_module

  implicit none

  type(tilegrid), dimension(6), intent(in) :: tile
  type(latlongrid), intent(in) :: latlon
  real, dimension(latlon%nlon, latlon%nlat, latlon%nlev), intent(out) :: var3d

  integer :: i, j, k, n, ik, jk, m
  real :: w

  do jk = 1, latlon%nlat
  do ik = 1, latlon%nlon
     do k = 1, latlon%nlev
        var3d(ik, jk, k) = 0.0
     end do

     do m = 1, latlon%npnt
        n = latlon%tile(ik, jk, m)
        i = latlon%ilon(ik, jk, m)
        j = latlon%jlat(ik, jk, m)
        w = latlon%wgt(ik, jk, m)

        do k = 1, latlon%nlev
           var3d(ik, jk, k) = var3d(ik, jk, k) + w*tile(n)%var3d(i, j, k)
        end do
     end do
  end do
  end do

end subroutine interp3dvar

!----------------------------------------------------------------------
subroutine interp2dvar4sfc(tile, latlon, var2d)

  use tile_module
  use latlon_module

  implicit none

  type(tilegrid), dimension(6),              intent(in)  :: tile
  type(latlongrid),                          intent(in)  :: latlon
  real, dimension(latlon%nlon, latlon%nlat), intent(out) :: var2d

  integer :: i, j, n, ik, jk, m
  real :: w

  do jk = 1, latlon%nlat
  do ik = 1, latlon%nlon
     var2d(ik, jk) = 0.0

     do m = 1, latlon%npnt
        n = latlon%tile(ik, jk, m)
        i = latlon%ilon(ik, jk, m)
        j = latlon%jlat(ik, jk, m)
        w = latlon%wgt(ik, jk, m)

        var2d(ik, jk) = var2d(ik, jk) + w*tile(n)%var2d(i, j)
     end do
  end do
  end do

end subroutine interp2dvar4sfc

!----------------------------------------------------------------------
subroutine interp3dvar4sfc(tile, latlon, var3d)

  use tile_module
  use latlon_module

  implicit none

  type(tilegrid), dimension(6), intent(in) :: tile
  type(latlongrid), intent(in) :: latlon
  real, dimension(latlon%nlon, latlon%nlat, latlon%nlay), intent(out) :: var3d

  integer :: i, j, k, n, ik, jk, m
  real :: w

  do jk = 1, latlon%nlat
  do ik = 1, latlon%nlon
     do k = 1, latlon%nlay
        var3d(ik, jk, k) = 0.0
     end do

     do m = 1, latlon%npnt
        n = latlon%tile(ik, jk, m)
        i = latlon%ilon(ik, jk, m)
        j = latlon%jlat(ik, jk, m)
        w = latlon%wgt(ik, jk, m)

        do k = 1, latlon%nlay
           var3d(ik, jk, k) = var3d(ik, jk, k) + w*tile(n)%var3d(i, j, k)
        end do
     end do
  end do
  end do

end subroutine interp3dvar4sfc

!=====================================================================  
subroutine copy_u2var3d(tile)

  use tile_module

  implicit none

  type(tilegrid), dimension(6),      intent(inout) :: tile

  integer :: i, j, k, n

  do n = 1, 6
  do k = 1, tile(n)%nz
  do j = 1, tile(n)%ny
  do i = 1, tile(n)%nx
     tile(n)%var3d(i,j,k) = tile(n)%u(i,j,k)
  end do
  end do
  end do
  end do

end subroutine copy_u2var3d

!----------------------------------------------------------------------
subroutine interp3dvect(tile, spec, gridstruct, latlon, var3du, var3dv)

  use tile_module
  use fv_grid_utils_module
  use latlon_module

  implicit none

  type(tilegrid), dimension(6), intent(inout) :: tile
  type(tilespec_type), dimension(6), intent(in)    :: spec
  type(fv_grid_type), dimension(6), intent(in)     :: gridstruct
  type(latlongrid), intent(in) :: latlon
  real, dimension(latlon%nlon, latlon%nlat, latlon%nlev), intent(out) :: var3du
  real, dimension(latlon%nlon, latlon%nlat, latlon%nlev), intent(out) :: var3dv

  integer :: i, j, k, n, ik, jk, m
  real :: w
  real :: um
  real :: vm
  real :: cxy
  real :: sxy
  real,allocatable :: ue(:,:,:,:)
  real,allocatable :: ve(:,:,:,:)
  allocate(ue(6,tile(1)%nx,tile(1)%ny,latlon%nlev))  ! earth realtive winds on the "A" grid
  allocate(ve(6,tile(1)%nx,tile(1)%ny,latlon%nlev))
  ! convert u and v from the staggered D-grid to the A-grid points
  ! need to use code from cubed_to_latlon
  do n = 1, 6
     call cubed_to_latlon(tile(n)%var3du, tile(n)%var3dv, ue(n,:,:,:), ve(n,:,:,:), &
                          gridstruct(n), tile(n)%nx, tile(n)%ny, tile(n)%nz)
  enddo
  ! now that winds are earth relative, vector interpolate to new grid
  do jk = 1, latlon%nlat
  do ik = 1, latlon%nlon
     do k = 1, latlon%nlev
        var3du(ik, jk, k) = 0.0
        var3dv(ik, jk, k) = 0.0
     end do

     do m = 1, latlon%npnt
        n = latlon%tile(ik, jk, m)
        i = latlon%ilon(ik, jk, m)
        j = latlon%jlat(ik, jk, m)
        w = latlon%wgt(ik, jk, m)
        ! get rotation angle %x and %y are that longitude and latitude of the
        ! super-grid, so points 2,4,6,.etc refer to the "A" points
        CALL MOVECT(spec(n)%y(2*i,2*j), spec(n)%x(2*i,2*j), &
                    latlon%lat(jk), latlon%lon(ik) , cxy, sxy)
        ! vector interpolate to lat-lon grid
        do k = 1, latlon%nlev
           var3du(ik, jk, k) = var3du(ik, jk, k) + w*(cxy * ue(n,i,j,k) - sxy * ve(n,i,j,k))
           var3dv(ik, jk, k) = var3dv(ik, jk, k) + w*(sxy * ue(n,i,j,k) + cxy * ve(n,i,j,k))
        end do
     end do
  end do
  end do

  deallocate(ue)
  deallocate(ve)

end subroutine interp3dvect

!=====================================================================  
SUBROUTINE MOVECT(FLAT,FLON,TLAT,TLON,CROT,SROT)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  MOVECT     MOVE A VECTOR ALONG A GREAT CIRCLE
!   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
!
! ABSTRACT: THIS SUBPROGRAM PROVIDES THE ROTATION PARAMETERS
!           TO MOVE A VECTOR ALONG A GREAT CIRCLE FROM ONE
!           POSITION TO ANOTHER WHILE CONSERVING ITS ORIENTATION
!           WITH RESPECT TO THE GREAT CIRCLE.  THESE ROTATION
!           PARAMETERS ARE USEFUL FOR VECTOR INTERPOLATION.
!
! PROGRAM HISTORY LOG:
!   96-04-10  IREDELL
! 1999-04-08  IREDELL  GENERALIZE PRECISION
!
! USAGE:    CALL MOVECT(FLAT,FLON,TLAT,TLON,CROT,SROT)
!
!   INPUT ARGUMENT LIST:
!     FLAT     - REAL LATITUDE IN DEGREES FROM WHICH TO MOVE THE VECTOR
!     FLON     - REAL LONGITUDE IN DEGREES FROM WHICH TO MOVE THE VECTOR
!     TLAT     - REAL LATITUDE IN DEGREES TO WHICH TO MOVE THE VECTOR
!     TLON     - REAL LONGITUDE IN DEGREES TO WHICH TO MOVE THE VECTOR
!
!   OUTPUT ARGUMENT LIST:
!     CROT     - REAL CLOCKWISE VECTOR ROTATION COSINE
!     SROT     - REAL CLOCKWISE VECTOR ROTATION SINE
!                (UTO=CROT*UFROM-SROT*VFROM;
!                 VTO=SROT*UFROM+CROT*VFROM)
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 IMPLICIT NONE

 REAL,            INTENT(IN   ) :: FLAT, FLON
 REAL,            INTENT(IN   ) :: TLAT, TLON
 REAL,            INTENT(  OUT) :: CROT, SROT

 REAL,   PARAMETER     :: CRDLIM=0.9999999
 REAL,   PARAMETER     :: PI=3.14159265358979
 REAL,   PARAMETER     :: RPD=PI/180.0

 REAL                  :: CTLAT,STLAT,CFLAT,SFLAT
 REAL                  :: CDLON,SDLON,CRD
 REAL                  :: SRD2RN,STR,CTR,SFR,CFR

! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE COSINE OF THE RADIAL DISTANCE BETWEEN THE POINTS.
 CTLAT=COS(TLAT*RPD)
 STLAT=SIN(TLAT*RPD)
 CFLAT=COS(FLAT*RPD)
 SFLAT=SIN(FLAT*RPD)
 CDLON=COS((FLON-TLON)*RPD)
 SDLON=SIN((FLON-TLON)*RPD)
 CRD=STLAT*SFLAT+CTLAT*CFLAT*CDLON

! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE ROTATIONS AT BOTH POINTS WITH RESPECT TO THE GREAT CIRCLE
!  AND COMBINE THEM TO GIVE THE TOTAL VECTOR ROTATION PARAMETERS.
 IF(ABS(CRD).LE.CRDLIM) THEN
   SRD2RN=-1/(1-CRD**2)
   STR=CFLAT*SDLON
   CTR=CFLAT*STLAT*CDLON-SFLAT*CTLAT
   SFR=CTLAT*SDLON
   CFR=CTLAT*SFLAT*CDLON-STLAT*CFLAT
   CROT=SRD2RN*(CTR*CFR-STR*SFR)
   SROT=SRD2RN*(CTR*SFR+STR*CFR)
!  USE A DIFFERENT APPROXIMATION FOR NEARLY COINCIDENT POINTS.
!  MOVING VECTORS TO ANTIPODAL POINTS IS AMBIGUOUS ANYWAY.
 ELSE
   CROT=CDLON
   SROT=SDLON*STLAT
 ENDIF

END SUBROUTINE MOVECT

