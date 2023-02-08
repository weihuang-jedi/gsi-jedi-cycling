!-------------------------------------------------------------

MODULE namelist_module

  implicit none

  integer :: nml_unit
  integer, parameter :: max_types = 5

  CHARACTER(LEN=1024) :: program_name
  character(len=1024) :: indirname, outdirname
  character(len=1024) :: output_flnm, wgt_flnm, prefix
  character(len=1024) :: gaussian_grid_file
  character(len=1024) :: griddirname
  character(len=128)  :: grid_type
  character(len=128), dimension(max_types) :: data_types
  integer :: nlat, nlon, nlev, nilev, npnt, num_types
  integer :: debug_level
  integer :: total_members
  logical :: generate_weights, debug_on, has_prefix, use_uv_directly
  logical :: use_gaussian_grid

contains
  subroutine read_namelist(file_path)
    implicit none

    !! Reads Namelist from given file.
    character(len=*),  intent(in)  :: file_path
    integer :: rc
    character(len=1000) :: line

    ! Namelist definition.
    namelist /control_param/ indirname, outdirname, &
                             output_flnm, wgt_flnm, &
                             nlat, nlon, nlev, nilev, npnt, &
                             num_types, data_types, &
                             generate_weights, prefix, &
                             griddirname, grid_type, &
                             debug_on, debug_level, total_members, &
                             has_prefix, use_uv_directly, &
                             gaussian_grid_file, &
                             use_gaussian_grid

    program_name = 'Interpolate FV3 cube sphere to Gaussian Grid'

    griddirname = '/work/noaa/gsienkf/weihuang/UFS-RNR-tools/JEDI.FV3-increments/grid/C96/'
    grid_type = 'C96_grid.tile'

    indirname = '/work2/noaa/gsienkf/weihuang/production/run/sondes/run_80.40t1n_36p/analysis.2/increment'
    outdirname = '/work2/noaa/gsienkf/weihuang/production/run/sondes/run_80.40t1n_36p/analysis.2/increment'
    gaussian_grid_file = 'gaussian_grid.nc4'
    output_flnm = 'fv3_increments.nc'
    wgt_flnm = 'weights.nc'
    prefix = '20200101.120000.'

    has_prefix = .false.
    use_uv_directly = .true.

    nlon = 384
    nlat = 192
    nlev = 127
    nilev = 128
    npnt = 4
    num_types = 1

    data_types(1) = 'fv_core.res.tile'

    generate_weights = .false.
    debug_on = .false.
    debug_level = 0
    total_members = 80

    use_gaussian_grid = .true.

   !Check whether file exists.
   !inquire(file=file_path, iostat=rc)

   !if(rc /= 0) then
   !  write(unit=0, fmt='(3a)') 'Error: input file "', &
   !                         trim(file_path), '" does not exist.'
   !  return
   !end if

   !Open and read Namelist file.
   !open(action='read', file=file_path, iostat=rc, unit=nml_unit)
   !read(nml=control_param, iostat=rc, unit=nml_unit)

   !if(rc /= 0) then
   !  write(unit=0, fmt='(a)') 'Error: invalid Namelist format.'
   !end if

    open(newunit=nml_unit, file=trim(file_path), status='OLD')

    read(nml_unit, nml=control_param, iostat=rc)

    if(rc/=0) then
       backspace(nml_unit)
       read(nml_unit, fmt='(A)') line
       write(*, '(A)') &
           'Invalid line in namelist: '//trim(line)
    end if

   !print *, 'file_path: ', trim(file_path)
   !write(*, control_param)

    close(nml_unit)

   !print *, 'indirname: ', trim(indirname)
   !print *, 'outdirname: ', trim(outdirname)
   !print *, 'data_types(1): ', trim(data_types(1))
   !print *, 'nlon, nlat, nlev, npnt = ', nlon, nlat, nlev, npnt

  end subroutine read_namelist

END MODULE namelist_module

