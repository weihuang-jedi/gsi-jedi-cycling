!----------------------------------------------------------------------------------------
subroutine generate_header4gaussian(k, tile, gaussian, gridtype, flnm, last)
  
   use netcdf
   use tile_module
   use gaussian_module

   implicit none

   integer,                      intent(in)    :: k
   type(tilegrid), dimension(6), intent(inout) :: tile
   type(gaussiangrid),           intent(inout) :: gaussian
   character(len=*),             intent(in)    :: gridtype, flnm
   logical,                      intent(in)    :: last

   integer :: rc

  !print *, 'Enter generate_header4gaussian'
  !print *, 'k = ', k
  !print *, 'gridtype = ', trim(gridtype)
  !print *, 'flnm = ', trim(flnm)
  
   if(k == 1) then
      call create_coord4gaussian(tile(1)%nt, tile(1)%time(1:tile(1)%nt), gaussian, flnm)
   end if
  
   if('fv_core.res.tile' == trim(gridtype)) then
      call create_fv_core_var_attr4gaussian(tile, gaussian)
   else if('fv_tracer.res.tile' == trim(gridtype)) then
      call create_fv_tracer_var_attr4gaussian(tile, gaussian)
   end if

  !print *, 'last = ', last

   if(last) then
     !End define mode.
      rc = nf90_enddef(gaussian%ncid)
      if(rc /= nf90_noerr) then
         write(unit=0, fmt='(a,i6,a)') "Problem to enddef ncid: <", gaussian%ncid, ">."
         write(unit=0, fmt='(2a)') "Error status: ", trim(nf90_strerror(rc))
         write(unit=0, fmt='(3a, i4)') &
              "Stop in file: <", __FILE__, ">, line: ", __LINE__
         stop
      end if
   end if

  !print *, 'Leave generate_header4gaussian'

end subroutine generate_header4gaussian

!----------------------------------------------------------------------------------------
subroutine interp2gaussiangrid(gridtype, spec, gridstruct, tile, gaussian)

   use netcdf
   use tile_module
   use fv_grid_utils_module
   use gaussian_module

   implicit none

   character(len=*),                  intent(in)    :: gridtype
   type(tilespec_type), dimension(6), intent(in)    :: spec
   type(fv_grid_type), dimension(6),  intent(in)    :: gridstruct
   type(tilegrid), dimension(6),      intent(inout) :: tile
   type(gaussiangrid),                intent(inout) :: gaussian

  !print *, 'Enter interp2gaussiangrid'
  !print *, 'gridtype = ', trim(gridtype)

   if('fv_core.res.tile' == trim(gridtype)) then
      call process_fv_core4gaussian(spec, tile, gridstruct, gaussian)
   else if('fv_tracer.res.tile' == trim(gridtype)) then
      call process_fv_tracer4gaussian(tile, gaussian)
   end if

end subroutine interp2gaussiangrid

!---------------------------------------------------------------------------
subroutine create_global_attr4gaussian(ncid, filename, title, type)

   implicit none

   integer, intent(in) :: ncid
   character(len = *), intent(in) :: filename, title, type

  !print *, 'Enter create_global_attr'

 ! ----put global attributes----
   call nc_putGlobalCharAttr(ncid, 'filename', trim(filename))
   call nc_putGlobalCharAttr(ncid, 'title', trim(title))
   call nc_putGlobalCharAttr(ncid, 'grid_type', trim(type))

end subroutine create_global_attr4gaussian

!----------------------------------------------------------------------------------------
subroutine create_coord4gaussian(nt, time, gaussian, flnm)

   use netcdf
   use gaussian_module
   use status_module

   implicit none

   integer,          intent(in)              :: nt
   real(kind=8), dimension(1:nt), intent(in) :: time
   type(gaussiangrid), intent(inout)         :: gaussian
   character(len=*), intent(in)              :: flnm

   integer :: i, nd, rc, ncid

   integer, dimension(2) :: dimids
   logical :: fileExists
   real    :: missing_real

   missing_real = -1.0e38

  !print *, 'Enter create_coord4gaussian'
  !print *, 'flnm = ', trim(flnm)
  !print *, 'nt = ', nt
  !print *, 'time(1:nt) = ', time(1:nt)

  !print *, 'gaussian%nlon = ',  gaussian%nlon
  !print *, 'gaussian%nlat = ',  gaussian%nlat
  !print *, 'gaussian%nlev = ',  gaussian%nlev

   gaussian%filename = trim(flnm)

  !print *, 'gaussian%lon = ',  gaussian%lon
  !print *, 'gaussian%lat = ',  gaussian%lat
  !print *, 'gaussian%lev = ',  gaussian%lev

   rc = nf90_noerr

  !gaussian%dimid_time = -1

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

   gaussian%ncid = ncid
  !print *, 'ncid = ', ncid

   rc = nf90_def_dim(ncid, 'lon', gaussian%nlon, gaussian%dimid_lon)
   call check_status(rc)
   rc = nf90_def_dim(ncid, 'lat', gaussian%nlat, gaussian%dimid_lat)
   call check_status(rc)
   rc = nf90_def_dim(ncid, 'lev', gaussian%nlev, gaussian%dimid_lev)
   call check_status(rc)
   rc = nf90_def_dim(ncid, 'ilev', gaussian%nilev, gaussian%dimid_ilev)
   call check_status(rc)
  !rc = nf90_def_dim(ncid, 'Time', NF90_UNLIMITED, gaussian%dimid_time)
  !call check_status(rc)

   call create_global_attr4gaussian(ncid, flnm, 'FV3 to Gaussian Grid', 'Gaussian Grid')

   dimids(1) = gaussian%dimid_lon
   nd = 1
!--Field lon
   call nc_putAxisAttr(ncid, nd, dimids, NF90_REAL, &
                      'lon', &
                      "Lontitude Coordinate", &
                      "degree_east", &
                      "Longitude" )

   dimids(1) = gaussian%dimid_lat
!--Field lat
   call nc_putAxisAttr(ncid, nd, dimids, NF90_REAL, &
                      'lat', &
                      "Latitude Coordinate", &
                      "degree_north", &
                      "Latitude" )

   dimids(1) = gaussian%dimid_lev
!--Field lev
   call nc_putAxisAttr(ncid, nd, dimids, NF90_REAL, &
                      'lev', &
                      "Level Coordinate", &
                      "top_down", &
                      "Half Level" )

   dimids(1) = gaussian%dimid_ilev
!--Field ilev
   call nc_putAxisAttr(ncid, nd, dimids, NF90_REAL, &
                      'ilev', &
                      "Full Level Coordinate", &
                      "top_down", &
                      "Full Level" )

   dimids(1) = gaussian%dimid_ilev
!--Field hyai
   call nc_putAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                   'hyai', 'Hydro A Index', 'Pa', &
                   "Full Level", missing_real)

   dimids(1) = gaussian%dimid_ilev
!--Field hybi
   call nc_putAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                   'hybi', 'Hydro B Index', 'unitless', &
                   "Full Level", missing_real)

!  dimids(1) = gaussian%dimid_time
!--Field time
  !call nc_putAxisAttr(ncid, nd, dimids, NF90_REAL8, &
  !                   "Time", &
  !                   "Time Coordinate", &
  !                   "time lev", &
  !                   "Time" )

  !write lon
   call nc_put1Dvar0(ncid, 'lon', gaussian%lon, 1, gaussian%nlon)

  !write lat
   call nc_put1Dvar0(ncid, 'lat', gaussian%lat, 1, gaussian%nlat)

  !write lev
   call nc_put1Dvar0(ncid, 'lev', gaussian%lev, 1, gaussian%nlev)

  !write ilev
   call nc_put1Dvar0(ncid, 'ilev', gaussian%ilev, 1, gaussian%nilev)

  !write hyai
   call nc_put1Dvar0(ncid, 'hyai', gaussian%hyai, 1, gaussian%nilev)

  !write hybi
   call nc_put1Dvar0(ncid, 'hybi', gaussian%hybi, 1, gaussian%nilev)

  !write time
  !call nc_put1Ddbl0(ncid, 'Time', time, 1, nt)

  !print *, 'Leave create_coord4gaussian'
end subroutine create_coord4gaussian

!-------------------------------------------------------------------------------------
subroutine create_fv_core_var_attr4gaussian(tile, gaussian)

   use netcdf
   use namelist_module
   use tile_module
   use gaussian_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(gaussiangrid), intent(inout)             :: gaussian

   integer, dimension(4) :: dimids
   integer :: rc, nd, i
   integer :: missing_int
   real    :: missing_real
   character(len=80) :: long_name, units, coordinates, outname

  !print *, 'Enter create_fv_core_var_attr4gaussian'
  !print *, 'File: ', __FILE__, ', line: ', __LINE__

   missing_real = -1.0e38
   missing_int = -999999

   do i = 1, tile(1)%nVars
      if(tile(1)%vars(i)%nDims < 2) cycle

      long_name = 'unknown'
      units = 'unknown'
     !coordinates = 'Time lev lat lon'
      coordinates = 'lev lat lon'
      dimids(1) = gaussian%dimid_lon
      dimids(2) = gaussian%dimid_lat
      dimids(3) = gaussian%dimid_lev
     !dimids(4) = gaussian%dimid_time
     !nd = 4
      nd = 3

      long_name = trim(tile(1)%vars(i)%varname)
      if(trim(tile(1)%vars(i)%varname) == 'T') then
         outname = 'T_inc'
         long_name = 'air_temperature'
         units = 'K'
      else if(trim(tile(1)%vars(i)%varname) == 'ua') then
         outname = 'u_inc'
         long_name = 'eastward_wind'
         units = 'm/s'
      else if(trim(tile(1)%vars(i)%varname) == 'va') then
         outname = 'v_inc'
         long_name = 'northward_wind'
         units = 'm/s'
      else if(trim(tile(1)%vars(i)%varname) == 'delp') then
         outname = 'delp_inc'
         long_name = 'air_pressure_thick'
         units = 'Pa'
      else if(trim(tile(1)%vars(i)%varname) == 'DZ') then
         outname = 'delz_inc'
         long_name = 'layer_thickness'
         units = 'm'
      else
         cycle
      end if

     !print *, 'File: ', __FILE__, ', line: ', __LINE__
     !print *, 'outname: ', trim(outname)
     !print *, 'long_name: ', trim(long_name)

      call nc_putAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                      trim(outname), &
                      trim(long_name), trim(units), &
                      trim(coordinates), missing_real)
   end do

  !print *, 'Leave create_fv_core_var_attr4gaussian'

end subroutine create_fv_core_var_attr4gaussian

!-------------------------------------------------------------------------------------
subroutine create_fv_tracer_var_attr4gaussian(tile, gaussian)

   use netcdf
   use tile_module
   use gaussian_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(gaussiangrid),           intent(inout) :: gaussian

   integer, dimension(4) :: dimids
   integer :: rc, nd, i, j
   integer :: missing_int
   real    :: missing_real
   character(len=80) :: long_name, units, coordinates, outname

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

      if(trim(tile(1)%vars(i)%varname) == 'sphum') then
         outname = 'sphum_inc'
         long_name = 'specific_humidity'
         units = 'kgkg-1'
      else if(trim(tile(1)%vars(i)%varname) == 'o3mr') then
         outname = 'o3mr_inc'
         long_name = 'ozone_mass_mixing_ratio'
         units = 'kgkg-1'
      else
         cycle
      end if

     !coordinates = 'Time lev lat lon'
      coordinates = 'lev lat lon'

      dimids(1) = gaussian%dimid_lon
      dimids(2) = gaussian%dimid_lat
      dimids(3) = gaussian%dimid_lev
     !dimids(4) = gaussian%dimid_time
     !nd = 4
      nd = 3

      if(4 /= tile(1)%vars(i)%ndims) then
        print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(1)), &
                 '>, ndims = ', tile(1)%vars(i)%ndims

        print *, 'Problem in File: ', __FILE__, ', at line: ', __LINE__
      end if

      call nc_putAttr(gaussian%ncid, nd, dimids, NF90_REAL, &
                      trim(outname), &
                      trim(long_name), trim(units), &
                      trim(coordinates), missing_real)
   end do

end subroutine create_fv_tracer_var_attr4gaussian

!----------------------------------------------------------------------------------------
subroutine process_fv_core4gaussian(spec, tile, gridstruct, gaussian)

   use netcdf
   use namelist_module
   use tile_module
   use fv_grid_utils_module
   use gaussian_module

   implicit none

   type(tilespec_type), dimension(6), intent(in)    :: spec
   type(tilegrid), dimension(6),      intent(inout) :: tile
   type(fv_grid_type), dimension(6),  intent(in)    :: gridstruct
   type(gaussiangrid),                intent(inout) :: gaussian

   integer :: i, n, rc

   real, dimension(:,:,:), allocatable :: var3d, u
   character(len=80) :: outname

  !print *, 'Enter process_fv_core4gaussian'
  !print *, 'File: ', __FILE__, ', line: ', __LINE__

   allocate(var3d(gaussian%nlon, gaussian%nlat, gaussian%nlev))
   allocate(u(gaussian%nlon, gaussian%nlat, gaussian%nlev))

   do i = 1, tile(1)%nVars
     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         ndims=tile(1)%vars(i)%nDims, natts=tile(1)%vars(i)%nAtts)
     !call check_status(rc)

     !rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
     !         dimids=tile(1)%vars(i)%dimids)
     !call check_status(rc)

      rc = nf90_inquire_variable(tile(1)%fileid, tile(1)%varids(i), &
               name=tile(1)%vars(i)%varname)
      call check_status(rc)

     !print *, 'File: ', __FILE__, ', line: ', __LINE__
     !print *, 'Var No. ', i, ': name: ', trim(tile(1)%vars(i)%varname)
     !print *, 'Var No. ', i, ': varid: ', tile(1)%varids(i)

      if(tile(1)%vars(i)%nDims < 2) cycle

     !print *, 'P 1, Var No. ', i, ': name: ', trim(tile(1)%vars(i)%varname)

      if((trim(tile(1)%vars(i)%varname) == 'delp') .or. &
         (trim(tile(1)%vars(i)%varname) == 'DZ') .or. &
         (trim(tile(1)%vars(i)%varname) == 'ua') .or. &
         (trim(tile(1)%vars(i)%varname) == 'va') .or. &
         (trim(tile(1)%vars(i)%varname) == 'T')) then
         do n = 1, 6
            rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                  name=tile(n)%vars(i)%varname)
            call check_status(rc)

            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%var3d)
            call check_status(rc)
         end do
      else
         cycle
      end if

     !print *, 'File: ', __FILE__, ', line: ', __LINE__

      if(trim(tile(1)%vars(i)%varname) == 'T') then
         outname = 'T_inc'
      else if(trim(tile(1)%vars(i)%varname) == 'delp') then
         outname = 'delp_inc'
      else if(trim(tile(1)%vars(i)%varname) == 'DZ') then
         outname = 'delz_inc'
      else if(trim(tile(1)%vars(i)%varname) == 'ua') then
         outname = 'u_inc'
      else if(trim(tile(1)%vars(i)%varname) == 'va') then
         outname = 'v_inc'
      end if

     !print *, 'File: ', __FILE__, ', line: ', __LINE__

      call interp3dvar4gaussian(tile, gaussian, var3d)
      call nc_put3Dvar0(gaussian%ncid, trim(outname), &
           var3d, 1, gaussian%nlon, 1, gaussian%nlat, 1, gaussian%nlev)
   end do

   deallocate(var3d)
   deallocate(u)

  !print *, 'Leave process_fv_core4gaussian'

end subroutine process_fv_core4gaussian

!----------------------------------------------------------------------------------------
subroutine process_fv_tracer4gaussian(tile, gaussian)

   use netcdf
   use tile_module
   use gaussian_module

   implicit none

   type(tilegrid), dimension(6), intent(inout) :: tile
   type(gaussiangrid), intent(inout)             :: gaussian

   integer :: i, j, n, rc

   real, dimension(:,:,:), allocatable :: var3d
   character(len=80) :: outname

  !print *, 'Enter process_fv_tracer'

   allocate(var3d(gaussian%nlon, gaussian%nlat, gaussian%nlev))

   do i = 1, tile(1)%nVars
      if(trim(tile(1)%vars(i)%varname) == 'sphum') then
         outname = 'sphum_inc'
      else if(trim(tile(1)%vars(i)%varname) == 'o3mr') then
         outname = 'o3mr_inc'
      else
         cycle
      end if

      j = tile(1)%vars(i)%ndims

     !print *, 'Var ', i, ' name: <', trim(tile(1)%vars(i)%dimnames(j)), &
     !         '>, ndims = ', tile(1)%vars(i)%ndims

      if(tile(1)%vars(i)%ndims < 3) then
         cycle
      end if

      if('Time' /= trim(tile(1)%vars(i)%dimnames(j))) then
         cycle
      end if

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

      call interp3dvar4gaussian(tile, gaussian, var3d)
      call nc_put3Dvar0(gaussian%ncid, trim(outname), &
           var3d, 1, gaussian%nlon, 1, gaussian%nlat, 1, gaussian%nlev)
   end do

   deallocate(var3d)

end subroutine process_fv_tracer4gaussian

!----------------------------------------------------------------------
subroutine interp3dvar4gaussian(tile, gaussian, var3d)

  use tile_module
  use gaussian_module

  implicit none

  type(tilegrid), dimension(6), intent(in) :: tile
  type(gaussiangrid), intent(in) :: gaussian
  real, dimension(gaussian%nlon, gaussian%nlat, gaussian%nlev), intent(out) :: var3d

  integer :: i, j, k, n, ik, jk, m
  real :: w

!$OMP parallel do default(none) &
!$OMP shared(gaussian%nlat, gaussian%nlon, gaussian%nlev, gaussian%npnt) &
!$OMP shared(gaussian%tile, gaussian%ilon, gaussian%jlat, gaussian%wgt, var3d) &
!$OMP private(ik, jk, i, j, k, m, n, w)
  do jk = 1, gaussian%nlat
  do ik = 1, gaussian%nlon
     do k = 1, gaussian%nlev
        var3d(ik, jk, k) = 0.0
     end do

     do m = 1, gaussian%npnt
        n = gaussian%tile(ik, jk, m)
        i = gaussian%ilon(ik, jk, m)
        j = gaussian%jlat(ik, jk, m)
        w = gaussian%wgt(ik, jk, m)

        do k = 1, gaussian%nlev
           var3d(ik, jk, k) = var3d(ik, jk, k) + w*tile(n)%var3d(i, j, k)
        end do
     end do
  end do
  end do

end subroutine interp3dvar4gaussian

!----------------------------------------------------------------------
subroutine interp3dvect4gaussian(tile, spec, gridstruct, gaussian, var3du, var3dv)

  use tile_module
  use fv_grid_utils_module
  use gaussian_module

  implicit none

  type(tilegrid), dimension(6), intent(inout) :: tile
  type(tilespec_type), dimension(6), intent(in)    :: spec
  type(fv_grid_type), dimension(6), intent(in)     :: gridstruct
  type(gaussiangrid), intent(in) :: gaussian
  real, dimension(gaussian%nlon, gaussian%nlat, gaussian%nlev), intent(out) :: var3du
  real, dimension(gaussian%nlon, gaussian%nlat, gaussian%nlev), intent(out) :: var3dv

  integer :: i, j, k, n, ik, jk, m
  real :: w
  real :: um
  real :: vm
  real :: cxy
  real :: sxy
  real,allocatable :: ue(:,:,:,:)
  real,allocatable :: ve(:,:,:,:)
  allocate(ue(6,tile(1)%nx,tile(1)%ny,gaussian%nlev))  ! earth realtive winds on the "A" grid
  allocate(ve(6,tile(1)%nx,tile(1)%ny,gaussian%nlev))
  ! convert u and v from the staggered D-grid to the A-grid points
  ! need to use code from cubed_to_gaussian
  do n = 1, 6
     call cubed_to_latlon(tile(n)%var3du, tile(n)%var3dv, ue(n,:,:,:), ve(n,:,:,:), &
                          gridstruct(n), tile(n)%nx, tile(n)%ny, tile(n)%nz)
  enddo
  ! now that winds are earth relative, vector interpolate to new grid
  do jk = 1, gaussian%nlat
  do ik = 1, gaussian%nlon
     do k = 1, gaussian%nlev
        var3du(ik, jk, k) = 0.0
        var3dv(ik, jk, k) = 0.0
     end do

     do m = 1, gaussian%npnt
        n = gaussian%tile(ik, jk, m)
        i = gaussian%ilon(ik, jk, m)
        j = gaussian%jlat(ik, jk, m)
        w = gaussian%wgt(ik, jk, m)
        ! get rotation angle %x and %y are that longitude and latitude of the
        ! super-grid, so points 2,4,6,.etc refer to the "A" points
        CALL MOVECT(spec(n)%y(2*i,2*j), spec(n)%x(2*i,2*j), &
                    gaussian%lat(jk), gaussian%lon(ik) , cxy, sxy)
        ! vector interpolate to lat-lon grid
        do k = 1, gaussian%nlev
           var3du(ik, jk, k) = var3du(ik, jk, k) + w*(cxy * ue(n,i,j,k) - sxy * ve(n,i,j,k))
           var3dv(ik, jk, k) = var3dv(ik, jk, k) + w*(sxy * ue(n,i,j,k) + cxy * ve(n,i,j,k))
        end do
     end do
  end do
  end do

  deallocate(ue)
  deallocate(ve)

end subroutine interp3dvect4gaussian

