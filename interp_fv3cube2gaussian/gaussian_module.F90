module gaussian_module

  use netcdf
  use status_module
  use tile_module

  implicit none

  !-----------------------------------------------------------------------
  ! Define interfaces and attributes for module routines

  private
  public :: gaussiangrid
  public :: initialize_gaussiangrid
  public :: finalize_gaussiangrid
  public :: generate_weight4gaussian

  !-----------------------------------------------------------------------

  type gaussiangrid
     character(len=1024)                   :: filename
     integer                               :: ncid
     integer                               :: dimid_lon, dimid_lat, dimid_lev, &
                                              dimid_ilev, dimid_pnt, dimid_hor, dimid_time
     integer                               :: nlon, nlat, nlev, nilev, npnt, nhor
     real,    dimension(:),    allocatable :: lon, lat, lev, ilev, pnt, hyai, hybi
     integer, dimension(:, :), allocatable :: counter
     integer, dimension(:, :, :), allocatable :: tile
     integer, dimension(:, :, :), allocatable :: ilon, jlat
     real,    dimension(:, :, :), allocatable :: dist, wgt
     real,    dimension(:, :), allocatable :: pos
  end type gaussiangrid

  !-----------------------------------------------------------------------

contains

 !-----------------------------------------------------------------------
  subroutine initialize_gaussiangrid(gaussian_grid_file, &
                                     nlon, nlat, nlev, nilev, npnt, gaussian)

    implicit none

    character(len=*),   intent(in)  :: gaussian_grid_file
    integer,            intent(in)  :: nlon, nlat, nlev, nilev, npnt
    type(gaussiangrid), intent(out) :: gaussian

    integer :: i, j, k

   !print *, 'enter initialize_gaussiangrid'

    gaussian%nlon = nlon
    gaussian%nlat = nlat
    gaussian%nlev = nlev
    gaussian%nilev = nilev
    gaussian%npnt = npnt

    allocate(gaussian%counter(nlon, nlat))
    allocate(gaussian%tile(nlon, nlat, npnt))
    allocate(gaussian%ilon(nlon, nlat, npnt))
    allocate(gaussian%jlat(nlon, nlat, npnt))
    allocate(gaussian%dist(nlon, nlat, npnt))
    allocate(gaussian%wgt(nlon, nlat, npnt))
    allocate(gaussian%pos(nlon, nlat))

    allocate(gaussian%lon(nlon))
    allocate(gaussian%lat(nlat))
    allocate(gaussian%lev(nlev))
    allocate(gaussian%ilev(nilev))
    allocate(gaussian%hyai(nilev))
    allocate(gaussian%hybi(nilev))
    allocate(gaussian%pnt(npnt))
    
    do j = 1, nlat
      do i = 1, nlon
        gaussian%pos(i, j) = -1.0
        gaussian%counter(i, j) = 0

        do k = 1, npnt
          gaussian%tile(i, j, k) = 0
          gaussian%ilon(i, j, k) = 0
          gaussian%jlat(i, j, k) = 0
          gaussian%dist(i, j, k) = 1.0e36
          gaussian%wgt(i, j, k) = 0.0
        end do
      end do
    end do
    
    do i = 1, npnt
      gaussian%pnt(i) = real(i)
    end do

    call read_gaussian_grid(gaussian_grid_file, gaussian)

   !print *, 'gaussian%lon = ', gaussian%lon
   !print *, 'gaussian%lat = ', gaussian%lat

   !print *, 'leave initialize_gaussiangrid'

  end subroutine initialize_gaussiangrid

!----------------------------------------------------------------------------------------
  subroutine read_gaussian_grid(gaussian_grid_file, gaussian)

    use netcdf

    implicit none

    character(len=*),   intent(in)    :: gaussian_grid_file
    type(gaussiangrid), intent(inout) :: gaussian

    integer                                       :: fileid
    integer                                       :: nDims, nVars, &
                                                     nGlobalAtts, unlimDimID
!   integer, dimension(:),    allocatable         :: varids
    integer, dimension(:),    allocatable         :: dimids

    character(len=128) :: dimname
    integer :: status, i, include_parents, dimsize

   !print *, 'File: ', __FILE__, ', line: ', __LINE__
   !print *, 'Start Read gaussian grid info from file: ', trim(gaussian_grid_file)

    include_parents = 0

    status = nf90_noerr

   !Open the file. 
    status = nf90_open(trim(gaussian_grid_file), nf90_nowrite, fileid)
    call check_status(status)
   !print *, 'File: ', __FILE__, ', line: ', __LINE__

    status = nf90_inquire(fileid, nDims, nVars, &
                          nGlobalAtts, unlimdimid)
    call check_status(status)
   !print *, 'File: ', __FILE__, ', line: ', __LINE__
   !print *, 'nVars: ', nVars
   !print *, 'nDims: ', nDims

   !Allocate memory.
    allocate(dimids(nDims))

    status = nf90_inq_dimids(fileid, nDims, dimids, include_parents)
    call check_status(status)

   !print *, 'File: ', __FILE__, ', line: ', __LINE__
   !print *, 'dimids: ', dimids

    do i = 1, nDims
       status = nf90_inquire_dimension(fileid, dimids(i), dimname, dimsize)
       call check_status(status)
      !print *, 'Dim No. ', i, ': ', trim(dimname), ', dimsize=', dimsize

       if(trim(dimname) == 'lon') then
          if(gaussian%nlon /= dimsize) then
             print *, 'Dim lon: ', dimsize, ' in file is different to what read in: ', &
                       gaussian%nlon
             stop 'Wrong nlon'
          end if
       else if(trim(dimname) == 'lat') then
          if(gaussian%nlat /= dimsize) then
             print *, 'Dim lat: ', dimsize, ' in file is different to what read in: ', &
                       gaussian%nlat
             stop 'Wrong nlat'
          end if
       else if(trim(dimname) == 'lev') then
          if(gaussian%nlev /= dimsize) then
             print *, 'Dim lev: ', dimsize, ' in file is different to what read in: ', &
                       gaussian%nlev
             stop 'Wrong nlev'
          end if
       else if(trim(dimname) == 'ilev') then
          if(gaussian%nilev /= dimsize) then
             print *, 'Dim ilev: ', dimsize, ' in file is different to what read in: ', &
                       gaussian%nilev
             stop 'Wrong nilev'
          end if
       end if
    end do

   !print *, 'File: ', __FILE__, ', line: ', __LINE__

   !read lon
    call nc_get1Dvar0(fileid, 'lon', gaussian%lon, 1, gaussian%nlon)

   !read lat
    call nc_get1Dvar0(fileid, 'lat', gaussian%lat, 1, gaussian%nlat)

   !read lev
    call nc_get1Dvar0(fileid, 'lev', gaussian%lev, 1, gaussian%nlev)

   !read ilev
    call nc_get1Dvar0(fileid, 'ilev', gaussian%ilev, 1, gaussian%nilev)

   !read hyai
    call nc_get1Dvar0(fileid, 'hyai', gaussian%hyai, 1, gaussian%nilev)

   !read hybi
    call nc_get1Dvar0(fileid, 'hybi', gaussian%hybi, 1, gaussian%nilev)

    status =  nf90_close(fileid)
    call check_status(status)

   !print *, 'File: ', __FILE__, ', line: ', __LINE__

   !print *, 'lon = ', gaussian%lon
   !print *, 'lat = ', gaussian%lat

   !Allocate memory.
    deallocate(dimids)

   !print *, 'Finished Read gaussian grid info from file: ', trim(gaussian_grid_file)
   !print *, 'File: ', __FILE__, ', line: ', __LINE__

  end subroutine read_gaussian_grid
 !----------------------------------------------------------------------
  subroutine finalize_gaussiangrid(gaussian)

    use netcdf

    implicit none

    type(gaussiangrid), intent(inout) :: gaussian
    integer :: rc

    deallocate(gaussian%lon)
    deallocate(gaussian%lat)
    deallocate(gaussian%pnt)
    if(allocated(gaussian%lev)) deallocate(gaussian%lev)
    if(allocated(gaussian%ilev)) deallocate(gaussian%ilev)
    if(allocated(gaussian%hyai)) deallocate(gaussian%hyai)
    if(allocated(gaussian%hybi)) deallocate(gaussian%hybi)

    deallocate(gaussian%counter)
    deallocate(gaussian%tile)
    deallocate(gaussian%ilon)
    deallocate(gaussian%jlat)
    deallocate(gaussian%dist)
    deallocate(gaussian%wgt)
    deallocate(gaussian%pos)

    rc =  nf90_close(gaussian%ncid)
    call check_status(rc)
   !print *, 'Finished Write to file: ', trim(gaussian%filename)

  end subroutine finalize_gaussiangrid

  !----------------------------------------------------------------------
  subroutine generate_weight4gaussian(tile, gaussian)

    implicit none

    type(tilegrid), dimension(6), intent(in) :: tile
    type(gaussiangrid), intent(inout) :: gaussian

    integer :: ik, jk

   !print *, 'File: ', __FILE__, ', line: ', __LINE__

    do jk = 1, gaussian%nlat
    do ik = 1, gaussian%nlon
       call process_point(ik, jk, tile, gaussian)

       gaussian%pos(ik, jk) = real(gaussian%tile(ik, jk, 1))
       if((mod(ik-1,10) == 0) .and. (mod(jk-1, 10) == 0)) then
          print *, 'ik,jk,gaussian%pos(ik, jk),gaussian%dist(ik, jk, :) = ', &
                    ik,jk,gaussian%pos(ik, jk),gaussian%dist(ik, jk, :)
       end if
    end do
    end do

    !Check pos info
    do jk = 1, gaussian%nlat
    do ik = 1, gaussian%nlon
       call weighting(gaussian%npnt, gaussian%npnt, &
                      gaussian%dist(ik, jk, :), gaussian%wgt(ik, jk, :))
    end do
    end do

  end subroutine generate_weight4gaussian

  !----------------------------------------------------------------------
  subroutine process_point(ik, jk, tile, gaussian)

    implicit none

    integer, intent(in) :: ik, jk
    type(tilegrid), dimension(6), intent(in) :: tile
    type(gaussiangrid), intent(inout) :: gaussian

    integer :: i, j, n
    real :: plat, plon

    plon = gaussian%lon(ik)
    plat = gaussian%lat(jk)
    
    do n = 1, 6
    do j = 1, tile(n)%ny
    do i = 1, tile(n)%nx
      call check_point(ik, jk, i, j, n, plat, plon, &
           tile(n)%lat(i,j), tile(n)%lon(i,j), gaussian)
    end do
    end do
    end do

  end subroutine process_point

  !----------------------------------------------------------------------
  subroutine check_point(ik, jk, i, j, n, xlat1, xlon1, xlat2, xlon2, gaussian)
    implicit none

    integer, intent(in) :: ik, jk, i, j, n
    real, intent(in)  :: xlat1, xlon1, xlat2, xlon2
    type(gaussiangrid), intent(inout) :: gaussian

    real :: dist
    integer :: k

    call distance(xlat1, xlon1, xlat2, xlon2, dist)

    k = gaussian%counter(ik, jk)
    if((k > gaussian%npnt) .and. (dist >= gaussian%dist(ik, jk, gaussian%npnt))) then
       gaussian%counter(ik, jk) = k + 1
       return
    end if

    call insert(ik, jk, i, j, n, dist, gaussian)

  end subroutine check_point

  !----------------------------------------------------------------------
  subroutine insert(ik, jk, i, j, n, dist, gaussian)
    implicit none

    integer, intent(in) :: ik, jk, i, j, n
    real, intent(in)  :: dist
    type(gaussiangrid), intent(inout) :: gaussian
    integer :: k, kk, m

    k = gaussian%counter(ik, jk)
    gaussian%counter(ik, jk) = k + 1
    if(k >= gaussian%npnt) then
       k = gaussian%npnt
    else
       k = k + 1
    end if

    do kk = 1, gaussian%npnt
       m = k - 1
       if(m < 1) then
          exit
       end if

       if(dist < gaussian%dist(ik, jk, m)) then
          gaussian%tile(ik, jk, k) = gaussian%tile(ik, jk, m)
          gaussian%ilon(ik, jk, k) = gaussian%ilon(ik, jk, m)
          gaussian%jlat(ik, jk, k) = gaussian%jlat(ik, jk, m)
          gaussian%dist(ik, jk, k) = gaussian%dist(ik, jk, m)
       else
          exit
       end if
       k = k - 1
    end do

    gaussian%tile(ik, jk, k) = n
    gaussian%ilon(ik, jk, k) = i
    gaussian%jlat(ik, jk, k) = j
    gaussian%dist(ik, jk, k) = dist

   !print *, 'ik,jk,gaussian%dist(ik, jk, :) = ', ik,jk,gaussian%dist(ik, jk, :)

  end subroutine insert

  !----------------------------------------------------------------------
  subroutine distance(xlat1, xlon1, xlat2, xlon2, dist)

    implicit none

    real, intent(in)  :: xlat1, xlon1, xlat2, xlon2
    real, intent(out) :: dist

    real :: lat1, lon1, lat2, lon2, dlon, dlat

    real :: deg2arc, ang, sindlat, sindlon
    deg2arc = 3.1415926536/180.0

    lat1 = xlat1 * deg2arc
    lat2 = xlat2 * deg2arc
    lon1 = xlon1 * deg2arc
    lon2 = xlon2 * deg2arc

    dlon = lon2 - lon1
    dlat = lat2 - lat1
    sindlat = sin(0.5*dlat)
    sindlon = sin(0.5*dlon)
    ang = sindlat * sindlat + cos(lat1) * cos(lat2) * sindlon * sindlon
   !dist = 2.0 * atan2(sqrt(ang), sqrt(1.0-ang))
    dist = 2.0 * asin(min(1.0,sqrt(ang)))

  end subroutine distance

  !----------------------------------------------------------------------
  subroutine weighting(n, m, dist, wgt)

    implicit none

    integer, intent(in)  :: n, m
    real, dimension(n), intent(in)  :: dist
    real, dimension(n), intent(out) :: wgt

    real :: total, factor
    integer :: k

    total = 0.0
    do k = 1, m
       total = total + dist(k)
    end do
    
    if(m > 1) then
      factor = float(m - 1) * total
    else
      factor = total
    end if

    do k = 1, m
       wgt(k) = (total - dist(k)) / factor
    end do

    do k = m+1, n
       wgt(k) = 0.0
    end do

  end subroutine weighting

end module gaussian_module

