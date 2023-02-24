!-----------------------------------------------------------------------
!  The tile module read both tile specification, and tiled data.
!-----------------------------------------------------------------------

module tile_module

  use namelist_module
  use status_module
  use netcdf

  implicit none

  !-----------------------------------------------------------------------
  ! Define interfaces and attributes for module routines

  private
  public :: vartype
  public :: tilegrid
  public :: tilespec_type
  public :: initialize_tilegrid
  public :: finalize_tilegrid
  public :: initialize_tilespec
  public :: finalize_tilespec
  public :: check_status

  !-----------------------------------------------------------------------

  ! Define tile structure.

  type vartype
     integer             :: varid
     character(len=1024) :: varname
     integer             :: xtype, ndims, nAtts, deflate_level, endianness
     logical             :: contiguous, shuffle, fletcher32
     integer, dimension(:), allocatable :: dimids
     integer, dimension(:), allocatable :: dimlen
     character(len=128), dimension(:), allocatable :: dimnames
    !integer, dimension(:), allocatable :: chunksizes
  end type vartype

  type tilegrid
     character(len=1024)                   :: filename
     integer                               :: fileid
     integer                               :: nDims, nVars, nGlobalAtts, unlimDimID
     integer                               :: nx, ny, nz, ns, nt
     integer, dimension(:),    allocatable :: varids
     integer, dimension(:),    allocatable :: dimids
     integer, dimension(:),    allocatable :: dimlen
     character(len=128), dimension(:),    allocatable :: dimnames
     real,    dimension(:, :), allocatable :: lon, lat
     integer, dimension(:),    allocatable :: xt, yt

     real(kind=8), dimension(:), allocatable :: time

     real, dimension(:),       allocatable :: var1d
     real, dimension(:, :),    allocatable :: var2d
     real, dimension(:, :, :), allocatable :: var3d, var3du, var3dv, u

     type(vartype), dimension(:), allocatable :: vars
     logical                                  :: initialized
  end type tilegrid

  type tilespec_type
     character(len=1024)                   :: filename
     integer                               :: fileid
     integer                               :: nDims, nVars, nGlobalAtts, unlimDimID
     integer, dimension(:),    allocatable :: varids
     integer, dimension(:),    allocatable :: dimids
     integer, dimension(:),    allocatable :: dimlen
     character(len=128), dimension(:), allocatable :: dimnames
     type(vartype), dimension(:), allocatable :: vars

     integer                            :: nxp, nyp
     integer                            :: nx, ny

     real, dimension(:, :), allocatable :: x, y, dx, dy
    !real, dimension(:, :), allocatable :: area, angle_dx, angle_dy
  end type tilespec_type

contains

 !-----------------------------------------------------------------------
  subroutine initialize_tilegrid(tile, dname, ftype)

    implicit none

    type(tilegrid), dimension(6), intent(inout) :: tile
    character(len=*),             intent(in)    :: dname, ftype

    integer :: i, k, n, rc
    integer :: ny2, ik
    integer :: include_parents, dimlen

    character(len=1024) :: dimname, varname

   !print *, 'Enter initialize_tilegrid'
   !print *, 'File: ', __FILE__, ', line: ', __LINE__
   !print *, 'dname: <', trim(dname), '>'
   !print *, 'ftype: <', trim(ftype), '>'

    include_parents = 0

    do n = 1, 6
      ny2 = 0
      if(has_prefix) then
         write(tile(n)%filename, fmt='(4a, i1, a)') &
               trim(dname), '/', trim(prefix), trim(ftype), n, '.nc'
      else
         write(tile(n)%filename, fmt='(3a, i1, a)') &
               trim(dname), '/', trim(ftype), n, '.nc'
      end if
     !print *, 'Tile ', n, ', open filename: ', trim(tile(n)%filename)
      rc = nf90_open(trim(tile(n)%filename), nf90_nowrite, tile(n)%fileid)
      call check_status(rc)
     !print *, 'Tile ', n, ', fileid: ', tile(n)%fileid

      rc = nf90_inquire(tile(n)%fileid, tile(n)%nDims, tile(n)%nVars, &
               tile(n)%nGlobalAtts, tile(n)%unlimdimid)
      call check_status(rc)
     !print *, 'Tile ', n, ', nVars: ', tile(n)%nVars
     !print *, 'Tile ', n, ', nDims: ', tile(n)%nDims

      if(.not. tile(n)%initialized) then
        !Allocate memory.
         allocate(tile(n)%dimids(tile(n)%nDims))
         allocate(tile(n)%dimlen(tile(n)%nDims))
         allocate(tile(n)%dimnames(tile(n)%nDims))
      end if

      rc = nf90_inq_dimids(tile(n)%fileid, tile(n)%nDims, tile(n)%dimids, include_parents)
      call check_status(rc)

     !print *, 'Tile ', n, ', dimids: ', tile(n)%dimids
      tile(n)%nz = 1
      tile(n)%ns = 1

      do i = 1, tile(n)%nDims
         rc = nf90_inquire_dimension(tile(n)%fileid, tile(n)%dimids(i), dimname, dimlen)
         call check_status(rc)
        !print *, 'Dim No. ', i, ': ', trim(dimname), ', dimlen=', dimlen

         if(trim(dimname) == 'grid_xt') then
            tile(n)%nx = dimlen
         else if(trim(dimname) == 'grid_yt') then
            tile(n)%ny = dimlen
         else if(trim(dimname) == 'xaxis_1') then
            tile(n)%nx = dimlen
         else if(trim(dimname) == 'yaxis_1') then
            tile(n)%ny = dimlen
         else if(trim(dimname) == 'yaxis_2') then
            ny2 = dimlen
         else if(trim(dimname) == 'zaxis_1') then
            tile(n)%nz = dimlen
         else if(trim(dimname) == 'zaxis_2') then
            tile(n)%ns = dimlen
         else if(trim(dimname) == 'Time') then
            tile(n)%nt = dimlen
         end if

         tile(n)%dimlen(i) = dimlen
         tile(n)%dimnames(i) = trim(dimname)
      end do

      if((ny2 > 0) .and. (tile(n)%ny > ny2)) tile(n)%ny = ny2

     !print *, 'tile(n)%nx = ', tile(n)%nx, ', tile(n)%ny = ', tile(n)%ny, &
     !       ', tile(n)%nz = ', tile(n)%nz, ', tile(n)%nt = ', tile(n)%nt

      if(.not. tile(n)%initialized) then
        !Allocate memory.
         allocate(tile(n)%varids(tile(n)%nVars))
         allocate(tile(n)%vars(tile(n)%nVars))

         allocate(tile(n)%time(tile(n)%nt))

         allocate(tile(n)%var1d(tile(n)%nx))
         allocate(tile(n)%var2d(tile(n)%nx, tile(n)%ny))
         allocate(tile(n)%var3d(tile(n)%nx, tile(n)%ny, tile(n)%nz))
         allocate(tile(n)%var3du(tile(n)%nx, tile(n)%ny, tile(n)%nz))
         allocate(tile(n)%var3dv(tile(n)%nx, tile(n)%ny, tile(n)%nz))
         allocate(tile(n)%u(tile(n)%nx, tile(n)%ny, tile(n)%nz))
      end if

      rc = nf90_inq_varids(tile(n)%fileid, tile(n)%nVars, tile(n)%varids)
      call check_status(rc)

     !print *, 'Tile ', n, ', nvars = ', tile(n)%nVars, ', varids: ', tile(n)%varids

      do i = 1, tile(n)%nVars
         rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                                    ndims=tile(n)%vars(i)%nDims, natts=tile(n)%vars(i)%nAtts)
         call check_status(rc)
        !print *, 'Var No. ', i, ': ndims = ', tile(n)%vars(i)%nDims

         if(.not. tile(n)%initialized) then
            allocate(tile(n)%vars(i)%dimids(tile(n)%vars(i)%nDims))
            allocate(tile(n)%vars(i)%dimlen(tile(n)%vars(i)%nDims))
            allocate(tile(n)%vars(i)%dimnames(tile(n)%vars(i)%nDims))
         end if

         rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                                    dimids=tile(n)%vars(i)%dimids)
         call check_status(rc)
        !print *, 'Var No. ', i, ': tile(n)%vars(i)%dimids = ', tile(n)%vars(i)%dimids

         rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                  name=tile(n)%vars(i)%varname)
         call check_status(rc)
        !print *, 'Var No. ', i, ': ', trim(tile(n)%vars(i)%varname)

        !rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
        !         tile(n)%vars(i)%varname, tile(n)%vars(i)%xtype, &
        !         tile(n)%vars(i)%ndims, tile(n)%vars(i)%dimids, &
        !         tile(n)%vars(i)%nAtts, tile(n)%vars(i)%contiguous, &
        !         tile(n)%vars(i)%chunksizes, tile(n)%vars(i)%deflate_level, &
        !         tile(n)%vars(i)%shuffle, tile(n)%vars(i)%fletcher32, &
        !         tile(n)%vars(i)%endianness)
        !call check_status(rc)

         if(trim(tile(n)%vars(i)%varname) == 'grid_lont') then
            if(.not. tile(n)%initialized) &
               allocate(tile(n)%lon(tile(n)%nx, tile(n)%ny))
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%lon)
            call check_status(rc)
         else if(trim(tile(n)%vars(i)%varname) == 'grid_latt') then
            if(.not. tile(n)%initialized) &
               allocate(tile(n)%lat(tile(n)%nx, tile(n)%ny))
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%lat)
            call check_status(rc)
         else if(trim(tile(n)%vars(i)%varname) == 'grid_xt') then
            if(.not. tile(n)%initialized) &
               allocate(tile(n)%xt(tile(n)%nx))
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%xt)
            call check_status(rc)
         else if(trim(tile(n)%vars(i)%varname) == 'grid_yt') then
            if(.not. tile(n)%initialized) &
               allocate(tile(n)%yt(tile(n)%ny))
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%yt)
            call check_status(rc)
         else if(trim(tile(n)%vars(i)%varname) == 'Time') then
            if(.not. allocated(tile(n)%time)) then
               if(.not. tile(n)%initialized) &
                  allocate(tile(n)%time(tile(n)%nt))
            end if
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%time)
           !print *, 'time(', n, ')%time = ', tile(n)%time(1:tile(n)%nt)
            call check_status(rc)
         end if

         do k = 1, tile(n)%vars(i)%ndims
           !rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
           !                           tile(n)%vars(i)%dimids(k), &
           !                           dimname, dimlen)
           !call check_status(rc)
           !print *, 'k = ', k, ', tile(n)%vars(i)%dimids(k) = ', tile(n)%vars(i)%dimids(k)
            ik = tile(n)%vars(i)%dimids(k)
            tile(n)%vars(i)%dimnames(k) = trim(tile(n)%dimnames(ik))
            tile(n)%vars(i)%dimlen(k) = tile(n)%dimlen(ik)
         end do
      end do

      tile(n)%initialized = .true.
    end do

   !print *, 'Leave initialize_tilegrid'

  end subroutine initialize_tilegrid

  !----------------------------------------------------------------------
  subroutine finalize_tilegrid(tile)

    implicit none

    type(tilegrid), dimension(6), intent(inout) :: tile

    integer :: i, n, rc

    do n = 1, 6
      if(allocated(tile(n)%varids)) deallocate(tile(n)%varids)
      if(allocated(tile(n)%dimids)) deallocate(tile(n)%dimids)
      if(allocated(tile(n)%dimlen)) deallocate(tile(n)%dimlen)
      if(allocated(tile(n)%dimnames)) deallocate(tile(n)%dimnames)
      if(allocated(tile(n)%time)) deallocate(tile(n)%time)
      if(allocated(tile(n)%lon)) deallocate(tile(n)%lon)
      if(allocated(tile(n)%lat)) deallocate(tile(n)%lat)
      if(allocated(tile(n)%xt)) deallocate(tile(n)%xt)
      if(allocated(tile(n)%yt)) deallocate(tile(n)%yt)

      do i = 1, tile(n)%nVars
         if(allocated(tile(n)%vars(i)%dimids)) &
            deallocate(tile(n)%vars(i)%dimids)
         if(allocated(tile(n)%vars(i)%dimlen)) &
            deallocate(tile(n)%vars(i)%dimlen)
         if(allocated(tile(n)%vars(i)%dimnames)) &
            deallocate(tile(n)%vars(i)%dimnames)
      end do

      if(allocated(tile(n)%vars)) deallocate(tile(n)%vars)
      if(allocated(tile(n)%var1d)) deallocate(tile(n)%var1d)
      if(allocated(tile(n)%var2d)) deallocate(tile(n)%var2d)
      if(allocated(tile(n)%var3d)) deallocate(tile(n)%var3d)
      if(allocated(tile(n)%var3du)) deallocate(tile(n)%var3du)
      if(allocated(tile(n)%var3dv)) deallocate(tile(n)%var3dv)
      if(allocated(tile(n)%u)) deallocate(tile(n)%u)

     !print *, 'Tile ', n, ', close filename: ', trim(tile(n)%filename)
      rc = nf90_close(tile(n)%fileid)
      call check_status(rc)
    end do

  end subroutine finalize_tilegrid

 !-----------------------------------------------------------------------
  subroutine initialize_tilespec(tile, dname, ftype)

    implicit none

    type(tilespec_type), dimension(6), intent(out) :: tile
    character(len=*),                  intent(in)  :: dname, ftype

    integer :: i, j, k, n, rc
    integer :: include_parents, dimlen

    character(len=1024) :: dimname, varname

   !print *, 'Enter initialize_tilespec'
   !print *, 'dname: <', trim(dname), '>'
   !print *, 'ftype: <', trim(ftype), '>'

    include_parents = 0

    do n = 1, 6
      write(tile(n)%filename, fmt='(2a, i1, a)') &
            trim(dname), trim(ftype), n, '.nc'
     !print *, 'Tile ', n, ', open filename: ', trim(tile(n)%filename)

      rc = nf90_open(trim(tile(n)%filename), nf90_nowrite, tile(n)%fileid)
      call check_status(rc)

     !print *, 'Tile ', n, ', fileid: ', tile(n)%fileid

      rc = nf90_inquire(tile(n)%fileid, tile(n)%nDims, tile(n)%nVars, &
               tile(n)%nGlobalAtts, tile(n)%unlimdimid)
      call check_status(rc)
     !print *, 'Tile ', n, ', nVars: ', tile(n)%nVars
     !print *, 'Tile ', n, ', nDims: ', tile(n)%nDims

     !Allocate memory.
      allocate(tile(n)%dimids(tile(n)%nDims))
      allocate(tile(n)%dimlen(tile(n)%nDims))
      allocate(tile(n)%dimnames(tile(n)%nDims))

      rc = nf90_inq_dimids(tile(n)%fileid, tile(n)%nDims, tile(n)%dimids, include_parents)
      call check_status(rc)

     !print *, 'Tile ', n, ', dimids: ', tile(n)%dimids

      do i = 1, tile(n)%nDims
         rc = nf90_inquire_dimension(tile(n)%fileid, tile(n)%dimids(i), dimname, dimlen)
         call check_status(rc)
        !print *, 'Dim No. ', i, ': ', trim(dimname), ', dimlen=', dimlen

         if(trim(dimname) == 'nx') then
            tile(n)%nx = dimlen
         else if(trim(dimname) == 'ny') then
            tile(n)%ny = dimlen
         else if(trim(dimname) == 'nxp') then
            tile(n)%nxp = dimlen
         else if(trim(dimname) == 'nyp') then
            tile(n)%nyp = dimlen
         end if

         tile(n)%dimlen(i) = dimlen
         tile(n)%dimnames(i) = trim(dimname)
      end do

     !print *, 'tile(n)%nx = ', tile(n)%nx, ', tile(n)%ny = ', tile(n)%ny

     !Allocate memory.
      allocate(tile(n)%varids(tile(n)%nVars))
      allocate(tile(n)%vars(tile(n)%nVars))

      rc = nf90_inq_varids(tile(n)%fileid, tile(n)%nVars, tile(n)%varids)
      call check_status(rc)

     !print *, 'Tile ', n, ', nvars = ', tile(n)%nVars, ', varids: ', tile(n)%varids

      do i = 1, tile(n)%nVars
         rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                                    ndims=tile(n)%vars(i)%nDims, natts=tile(n)%vars(i)%nAtts)
         call check_status(rc)
        !print *, 'Var No. ', i, ': ndims = ', tile(n)%vars(i)%nDims

         allocate(tile(n)%vars(i)%dimids(tile(n)%vars(i)%nDims))
         allocate(tile(n)%vars(i)%dimlen(tile(n)%vars(i)%nDims))
         allocate(tile(n)%vars(i)%dimnames(tile(n)%vars(i)%nDims))

         rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                                    dimids=tile(n)%vars(i)%dimids)
         call check_status(rc)
        !print *, 'Var No. ', i, ': tile(n)%vars(i)%dimids = ', tile(n)%vars(i)%dimids

         rc = nf90_inquire_variable(tile(n)%fileid, tile(n)%varids(i), &
                  name=tile(n)%vars(i)%varname)
         call check_status(rc)
        !print *, 'Var No. ', i, ': ', trim(tile(n)%vars(i)%varname)

         if(trim(tile(n)%vars(i)%varname) == 'x') then
            allocate(tile(n)%x(tile(n)%nxp, tile(n)%nyp))
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%x)
            call check_status(rc)
         else if(trim(tile(n)%vars(i)%varname) == 'y') then
            allocate(tile(n)%y(tile(n)%nxp, tile(n)%nyp))
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%y)
            call check_status(rc)
         else if(trim(tile(n)%vars(i)%varname) == 'dx') then
            allocate(tile(n)%dx(tile(n)%nx, tile(n)%nyp))
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%dx)
            call check_status(rc)
         else if(trim(tile(n)%vars(i)%varname) == 'dy') then
            allocate(tile(n)%dy(tile(n)%nxp, tile(n)%ny))
            rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%dy)
            call check_status(rc)
        !else if(trim(tile(n)%vars(i)%varname) == 'angle_dx') then
        !   allocate(tile(n)%angle_dx(tile(n)%nxp, tile(n)%nyp))
        !   rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%angle_dx)
        !   call check_status(rc)
        !else if(trim(tile(n)%vars(i)%varname) == 'angle_dy') then
        !   allocate(tile(n)%angle_dy(tile(n)%nxp, tile(n)%nyp))
        !   rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%angle_dy)
        !   call check_status(rc)
        !else if(trim(tile(n)%vars(i)%varname) == 'area') then
        !   allocate(tile(n)%area(tile(n)%nx, tile(n)%ny))
        !   rc = nf90_get_var(tile(n)%fileid, tile(n)%varids(i), tile(n)%area)
        !   call check_status(rc)
         end if

         do k = 1, tile(n)%vars(i)%ndims
            j = tile(n)%vars(i)%dimids(k)
            tile(n)%vars(i)%dimnames(k) = trim(tile(n)%dimnames(j))
            tile(n)%vars(i)%dimlen(k) = tile(n)%dimlen(j)
         end do
      end do
    end do

   !print *, 'Leave initialize_tilespec'

  end subroutine initialize_tilespec

  !----------------------------------------------------------------------
  subroutine finalize_tilespec(tile)

    implicit none

    type(tilespec_type), dimension(6), intent(inout) :: tile

    integer :: i, n, rc

    do n = 1, 6
      if(allocated(tile(n)%varids)) deallocate(tile(n)%varids)
      if(allocated(tile(n)%dimids)) deallocate(tile(n)%dimids)
      if(allocated(tile(n)%dimlen)) deallocate(tile(n)%dimlen)
      if(allocated(tile(n)%dimnames)) deallocate(tile(n)%dimnames)

      if(allocated(tile(n)%x)) deallocate(tile(n)%x)
      if(allocated(tile(n)%y)) deallocate(tile(n)%y)
      if(allocated(tile(n)%dx)) deallocate(tile(n)%dx)
      if(allocated(tile(n)%dy)) deallocate(tile(n)%dy)
     !if(allocated(tile(n)%angle_dx)) deallocate(tile(n)%angle_dx)
     !if(allocated(tile(n)%angle_dy)) deallocate(tile(n)%angle_dy)
     !if(allocated(tile(n)%area)) deallocate(tile(n)%area)

      do i = 1, tile(n)%nVars
         if(allocated(tile(n)%vars(i)%dimids)) &
            deallocate(tile(n)%vars(i)%dimids)
         if(allocated(tile(n)%vars(i)%dimlen)) &
            deallocate(tile(n)%vars(i)%dimlen)
         if(allocated(tile(n)%vars(i)%dimnames)) &
            deallocate(tile(n)%vars(i)%dimnames)
      end do

      if(allocated(tile(n)%vars)) deallocate(tile(n)%vars)

     !print *, 'Tile ', n, ', close filename: ', trim(tile(n)%filename)
      rc = nf90_close(tile(n)%fileid)
      call check_status(rc)
    end do

  end subroutine finalize_tilespec

end module tile_module

