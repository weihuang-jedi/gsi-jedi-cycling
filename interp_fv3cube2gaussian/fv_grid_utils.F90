module fv_grid_utils_module

  use tile_module

  implicit none

  private

  real, parameter::  big_number=1.d8
  real, parameter:: tiny_number=1.d-8
  real, parameter:: pi = 3.1415926536
  real, parameter:: deg2arc = pi/180.0

  public :: fv_grid_type
  public grid_utils_init, grid_utils_exit, cubed_to_latlon
 !public latlon2xyz, unit_vect_latlon, v_prod
 !public mid_pt_cart, vect_cross, &
 !       inner_prod, normalize_vect

  type fv_grid_type
     real, allocatable, dimension(:,:,:) :: grid, agrid

     real, allocatable, dimension(:,:) :: dx, dy

    !Cubed_2_latlon:
     real, allocatable :: a11(:,:)
     real, allocatable :: a12(:,:)
     real, allocatable :: a21(:,:)
     real, allocatable :: a22(:,:)

     real, allocatable :: ec1(:,:,:)
     real, allocatable :: ec2(:,:,:)

    !- 3D Super grid to contain all geometrical factors --
    ! the 3rd dimension is 9
     real, allocatable :: sin_sg(:,:)
     real, allocatable :: cos_sg(:,:)
    !--------------------------------------------------

    !Unit vectors for lat-lon grid
     real, allocatable :: vlon(:,:,:)
     real, allocatable :: vlat(:,:,:)

  end type fv_grid_type

contains

 subroutine grid_utils_init(gridspec, gridstruct, nx, ny)

   implicit none

!> Initialize 2D memory and geometrical factors
   type(tilespec_type), intent(in)    :: gridspec
   type(fv_grid_type),  intent(inout) :: gridstruct
   integer,             intent(in)    :: nx, ny
!
! Super (composite) grid:
 
!     9---4---8
!     |       |
!     1   5   3
!     |       |
!     6---2---7
 
   real grid3(3,nx+1,ny+1)
   real p1(3), p2(3), p3(3), p4(3), pp(3), ex(3), ey(3), e1(3), e2(3)
   real pp1(2), pp2(2), pp3(2)

   integer i, j, k, n, ip

  !----------------------------------------------------------------------------------
   allocate(gridstruct%grid(nx+1, ny+1, 2))
   allocate(gridstruct%agrid(nx, ny, 2))

   allocate(gridstruct%dx(nx, ny+1))
   allocate(gridstruct%dy(nx+1, ny))

   allocate(gridstruct%ec1(3, nx, ny))
   allocate(gridstruct%ec2(3, nx, ny))

   allocate(gridstruct%a11(nx, ny))
   allocate(gridstruct%a12(nx, ny))
   allocate(gridstruct%a21(nx, ny))
   allocate(gridstruct%a22(nx, ny))

   allocate(gridstruct%cos_sg(nx, ny))
   allocate(gridstruct%sin_sg(nx, ny))

   allocate(gridstruct%vlon(nx, ny, 3))
   allocate(gridstruct%vlat(nx, ny, 3))

   gridstruct%cos_sg(:,:) =  big_number
   gridstruct%sin_sg(:,:) = tiny_number

  !----------------------------------------------------------------------------------
   do j=1, ny+1
   do i=1, nx+1
      gridstruct%grid(i,j,1) = gridspec%x(2*i-1, 2*j-1)*deg2arc
      gridstruct%grid(i,j,2) = gridspec%y(2*i-1, 2*j-1)*deg2arc
      call latlon2xyz(gridstruct%grid(i,j,1:2), grid3(1:3,i,j))
   enddo
   enddo

   call get_center_vect( nx, ny, grid3, gridstruct%ec1, gridstruct%ec2 )

   do j=1, ny
   do i=1, nx
      gridstruct%agrid(i,j,1) = gridspec%x(2*i, 2*j)*deg2arc
      gridstruct%agrid(i,j,2) = gridspec%y(2*i, 2*j)*deg2arc
   enddo
   enddo

   do j=1, ny+1
   do i=1, nx
      gridstruct%dx(i,j) = gridspec%dx(2*i, 2*j-1)
   enddo
   enddo

   do j=1, ny
   do i=1, nx+1
      gridstruct%dy(i,j) = gridspec%dy(2*i-1, 2*j)
   enddo
   enddo

!--------------------------------------------------------------------------------------------------
!     9---4---8
!     |       |
!     1   5   3
!     |       |
!     6---2---7

   !--------------------------------------------------------------------------------------------------
    do j=1, ny
    do i=1, nx
       gridstruct%cos_sg(i,j) = inner_prod( gridstruct%ec1(1:3,i,j), gridstruct%ec2(1:3,i,j) )
       gridstruct%sin_sg(i,j) = min(1.0, sqrt(max(tiny_number, 1.0-gridstruct%cos_sg(i,j)**2)))
    enddo
    enddo

   !Initialize cubed_sphere to lat-lon transformation:
    call init_cubed_to_latlon( gridstruct, nx, ny )

  end subroutine grid_utils_init

  subroutine grid_utils_exit(gridstruct)

   implicit none

   type(fv_grid_type),  intent(inout) :: gridstruct

   deallocate(gridstruct%grid)
   deallocate(gridstruct%agrid)

   deallocate(gridstruct%dx)
   deallocate(gridstruct%dy)

   deallocate(gridstruct%ec1)
   deallocate(gridstruct%ec2)

   deallocate(gridstruct%a11)
   deallocate(gridstruct%a12)
   deallocate(gridstruct%a21)
   deallocate(gridstruct%a22)

   deallocate(gridstruct%cos_sg)
   deallocate(gridstruct%sin_sg)

   deallocate(gridstruct%vlon)
   deallocate(gridstruct%vlat)

  end subroutine grid_utils_exit

real function inner_prod(v1, v2)
   real,intent(in):: v1(3), v2(3)
   real :: vp1(3), vp2(3), prod16
   integer k
      
   do k=1,3
      vp1(k) = real(v1(k))
      vp2(k) = real(v2(k))
   enddo
   prod16 = vp1(1)*vp2(1) + vp1(2)*vp2(2) + vp1(3)*vp2(3)
   inner_prod = prod16

end function inner_prod


!>@brief The subroutine 'latlon2xyz' maps (lon, lat) to (x,y,z)
 subroutine latlon2xyz(p, e)

 real, intent(in) :: p(2)
 real, intent(out):: e(3)

    e(1) = cos(p(2)) * cos(p(1))
    e(2) = cos(p(2)) * sin(p(1))
    e(3) = sin(p(2))

 end subroutine latlon2xyz


!>@brief The subroutine 'vect_cross' performs cross products
!! of 3D vectors: e = P1 X P2
 subroutine vect_cross(e, p1, p2)
 real, intent(in) :: p1(3), p2(3)
 real, intent(out):: e(3)

      e(1) = p1(2)*p2(3) - p1(3)*p2(2)
      e(2) = p1(3)*p2(1) - p1(1)*p2(3)
      e(3) = p1(1)*p2(2) - p1(2)*p2(1)

 end subroutine vect_cross

 subroutine get_center_vect( nx, ny, pp, u1, u2 )
    integer, intent(in):: nx, ny
    real, dimension(3,nx+1,ny+1), intent(in)  :: pp
    real, dimension(3,nx,ny),     intent(out) :: u1, u2

! Local:
    integer i,j,k
    real p1(3), p2(3), pc(3), p3(3)

    do j=1,ny
       do i=1,nx
#ifdef OLD_VECT
          do k=1,3
             u1(k,i,j) = pp(k,i+1,j)+pp(k,i+1,j+1) - pp(k,i,j)-pp(k,i,j+1)
             u2(k,i,j) = pp(k,i,j+1)+pp(k,i+1,j+1) - pp(k,i,j)-pp(k,i+1,j)
          enddo
          call normalize_vect( u1(1,i,j) )
          call normalize_vect( u2(1,i,j) )
#else
          call cell_center3(pp(1,i,j), pp(1,i+1,j), pp(1,i,j+1), pp(1,i+1,j+1), pc)
! e1:
          call mid_pt3_cart(pp(1,i,j),   pp(1,i,j+1),   p1)
          call mid_pt3_cart(pp(1,i+1,j), pp(1,i+1,j+1), p2)
          call vect_cross(p3, p2, p1)
          call vect_cross(u1(1,i,j), pc, p3)
          call normalize_vect( u1(1,i,j) )
! e2:
          call mid_pt3_cart(pp(1,i,j),   pp(1,i+1,j),   p1)
          call mid_pt3_cart(pp(1,i,j+1), pp(1,i+1,j+1), p2)
          call vect_cross(p3, p2, p1)
          call vect_cross(u2(1,i,j), pc, p3)
          call normalize_vect( u2(1,i,j) )
#endif
       enddo
    enddo

 end subroutine get_center_vect


!>@brief The subroutine 'normalize_vect' makes 'e' a unit vector.
 subroutine normalize_vect(e)

 real, intent(inout):: e(3)
 real:: pdot
 integer k

    pdot = e(1)**2 + e(2)**2 + e(3)**2
    pdot = sqrt( pdot ) 

    do k=1,3
       e(k) = e(k) / pdot
    enddo

 end subroutine normalize_vect


 subroutine mid_pt3_cart(p1, p2, e)
       real, intent(IN)  :: p1(3), p2(3)
       real, intent(OUT) :: e(3)
!
       real:: q1(3), q2(3)
       real:: dd, e1, e2, e3
       integer k

       do k=1,3
          q1(k) = p1(k)
          q2(k) = p2(k)
       enddo

       e1 = q1(1) + q2(1)
       e2 = q1(2) + q2(2)
       e3 = q1(3) + q2(3)

       dd = sqrt( e1**2 + e2**2 + e3**2 )
       e1 = e1 / dd
       e2 = e2 / dd
       e3 = e3 / dd

       e(1) = e1
       e(2) = e2
       e(3) = e3

 end subroutine mid_pt3_cart



 subroutine mid_pt_cart(p1, p2, e3)
    real, intent(IN)  :: p1(2), p2(2)
    real, intent(OUT) :: e3(3)
!-------------------------------------
    real e1(3), e2(3)

    call latlon2xyz(p1, e1)
    call latlon2xyz(p2, e2)
    call mid_pt3_cart(e1, e2, e3)

 end subroutine mid_pt_cart



!------------------------------------------------------------------
subroutine unit_vect_latlon(pp, elon, elat)
  real, intent(IN)  :: pp(2)
  real, intent(OUT) :: elon(3), elat(3)

  real:: lon, lat
  real:: sin_lon, cos_lon, sin_lat, cos_lat

  lon = pp(1)
  lat = pp(2)

  sin_lon = sin(lon)
  cos_lon = cos(lon)
  sin_lat = sin(lat)
  cos_lat = cos(lat)

  elon(1) = -sin_lon
  elon(2) =  cos_lon
  elon(3) =  0.d0

  elat(1) = -sin_lat*cos_lon
  elat(2) = -sin_lat*sin_lon
  elat(3) =  cos_lat

end subroutine unit_vect_latlon

real function v_prod(v1, v2)
real v1(3), v2(3)

  v_prod = v1(1)*v2(1) + v1(2)*v2(2) + v1(3)*v2(3)

end function v_prod

subroutine init_cubed_to_latlon( gridstruct, nx, ny )
  
  implicit none

  type(fv_grid_type), intent(INOUT) :: gridstruct
  integer,            intent(in)    :: nx, ny

  integer i, j

 !Local pointers
  real :: z11, z12, z21, z22

  do j=1, ny
  do i=1, nx
     call unit_vect_latlon(gridstruct%agrid(i,j,1:2), gridstruct%vlon(i,j,1:3), gridstruct%vlat(i,j,1:3))
  enddo
  enddo

  do j=1, ny
  do i=1, nx
     z11 = v_prod(gridstruct%ec1(1:3,i,j), gridstruct%vlon(i,j,1:3))
     z12 = v_prod(gridstruct%ec1(1:3,i,j), gridstruct%vlat(i,j,1:3))
     z21 = v_prod(gridstruct%ec2(1:3,i,j), gridstruct%vlon(i,j,1:3))
     z22 = v_prod(gridstruct%ec2(1:3,i,j), gridstruct%vlat(i,j,1:3))

    !-------------------------------------------------------------------------
     gridstruct%a11(i,j) =  0.5d0*z22 / gridstruct%sin_sg(i,j)
     gridstruct%a12(i,j) = -0.5d0*z12 / gridstruct%sin_sg(i,j)
     gridstruct%a21(i,j) = -0.5d0*z21 / gridstruct%sin_sg(i,j)
     gridstruct%a22(i,j) =  0.5d0*z11 / gridstruct%sin_sg(i,j)
  enddo
  enddo

end subroutine init_cubed_to_latlon

!---------------------------------------------------------------
subroutine cubed_to_latlon(u, v, ua, va, gridstruct, nx, ny, nz)

  implicit none

  integer, intent(in) :: nx, ny, nz
  type(fv_grid_type), intent(IN) :: gridstruct
  real, dimension(nx, ny+1, nz), intent(inout) :: u
  real, dimension(nx+1, ny, nz), intent(inout) :: v
  real, dimension(nx, ny, nz),   intent(out)   :: ua, va

!--------------------------------------------------------------
! Local 
  real, dimension(nx, ny+1) :: wu
  real, dimension(nx+1, ny) :: wv
  real, dimension(nx)       :: u1, v1

  integer i, j, k

!$OMP parallel do default(none) &
!$OMP shared(nx,ny,nz,u,dx,v,dy,ua,va,a11,a12,a21,a22) &
!$OMP private(u1, v1, wu, wv)
  do k=1,nz
     do j=1, ny+1
     do i=1, nx
        wu(i,j) = u(i,j,k)*gridstruct%dx(i,j)
     enddo
     enddo

     do j=1, ny
     do i=1, nx+1
        wv(i,j) = v(i,j,k)*gridstruct%dy(i,j)
     enddo
     enddo

     do j=1, ny
     do i=1, nx
       !Co-variant to Co-variant "vorticity-conserving" interpolation
        u1(i) = 2.*(wu(i,j) + wu(i,j+1)) / (gridstruct%dx(i,j)+gridstruct%dx(i,j+1))
        v1(i) = 2.*(wv(i,j) + wv(i+1,j)) / (gridstruct%dy(i,j)+gridstruct%dy(i+1,j))

       !Cubed (cell center co-variant winds) to lat-lon:
        ua(i,j,k) = gridstruct%a11(i,j)*u1(i) + gridstruct%a12(i,j)*v1(i)
        va(i,j,k) = gridstruct%a21(i,j)*u1(i) + gridstruct%a22(i,j)*v1(i)
     enddo
     enddo
  enddo

end subroutine cubed_to_latlon


!>@brief The subroutine 'cell_center3' gets the center position of a cell.
 subroutine cell_center3(p1, p2, p3, p4, ec)
         real , intent(IN)  :: p1(3), p2(3), p3(3), p4(3)
         real , intent(OUT) :: ec(3)
! Local
         real dd
         integer k

         do k=1,3
            ec(k) = p1(k) + p2(k) + p3(k) + p4(k)
         enddo
         dd = sqrt( ec(1)**2 + ec(2)**2 + ec(3)**2 )

         do k=1,3
            ec(k) = ec(k) / dd
         enddo

 end subroutine cell_center3


!-------------------------------------------------------------------
 real function cos_angle(p1, p2, p3)
! As spherical_angle, but returns the cos(angle)
!       p3
!       ^  
!       |  
!       | 
!       p1 ---> p2
!
 real, intent(in):: p1(3), p2(3), p3(3)

 real:: e1(3), e2(3), e3(3)
 real:: px, py, pz
 real:: qx, qy, qz
 real:: angle, ddd
 integer n

  do n=1,3
     e1(n) = p1(n)
     e2(n) = p2(n)
     e3(n) = p3(n)
  enddo

!-------------------------------------------------------------------
! Page 41, 'Silverman's book on Vector Algebra; spherical trigonmetry
!-------------------------------------------------------------------
! Vector P:= e1 X e2
   px = e1(2)*e2(3) - e1(3)*e2(2) 
   py = e1(3)*e2(1) - e1(1)*e2(3) 
   pz = e1(1)*e2(2) - e1(2)*e2(1) 

! Vector Q: e1 X e3
   qx = e1(2)*e3(3) - e1(3)*e3(2) 
   qy = e1(3)*e3(1) - e1(1)*e3(3) 
   qz = e1(1)*e3(2) - e1(2)*e3(1) 

! ddd = sqrt[ (P*P) (Q*Q) ]
   ddd = sqrt( (px**2+py**2+pz**2)*(qx**2+qy**2+qz**2) )
   if ( ddd > 0.d0 ) then
        angle = (px*qx+py*qy+pz*qz) / ddd 
   else
        angle = 1.d0
   endif
   cos_angle = angle

 end function cos_angle

end module fv_grid_utils_module
  
