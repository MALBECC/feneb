subroutine getmaxforce(nrestr,nrep,rep,fav,maxforce,ftol,relaxd,maxforceat,rmsfneb)
  implicit none
  double precision, dimension(3,nrestr,nrep), intent(in) :: fav
  integer, intent(in) :: nrep, rep, nrestr
  double precision, intent(in) :: ftol
  double precision, intent(inout) :: maxforce, rmsfneb
  logical, intent(out) :: relaxd
  double precision :: fmax2
  integer :: i,j,maxforceat

  relaxd=.FALSE.
  maxforce=0.d0
  maxforceat=1
  do i=1,nrestr
    fmax2=0.d0
    do j=1,3
      fmax2=fmax2+fav(j,i,rep)**2
    end do
    rmsfneb=rmsfneb+fmax2
    if (fmax2 .gt. maxforce) maxforce=fmax2
    if (fmax2 .gt. maxforce) maxforceat=i
  end do
  maxforce=dsqrt(maxforce)
  if(maxforce .le. ftol) relaxd=.TRUE.

end subroutine getmaxforce

subroutine steep(rav,fav,nrep,rep,steep_size,maxforce,nrestr,stepl,smartstep)
implicit none
double precision, dimension(3,nrestr,nrep), intent(inout) :: rav
double precision, dimension(3,nrestr,nrep) :: rnew
double precision, dimension(3,nrestr,nrep), intent(in) :: fav
double precision, intent(out) :: stepl
double precision :: steep_size, step, n1, n2, n3
integer, intent(in) :: nrep, rep, nrestr
double precision, intent(inout) :: maxforce
integer :: i,j,auxunit
logical :: moved, smartstep

if (smartstep) then
  if(maxforce .ge. 11.5d0) stepl=0.005d0
  if(maxforce .lt. 11.5d0) stepl=0.002d0
  if(maxforce .lt. 2.3d0) stepl=0.001d0
  if(maxforce .lt. 0.23d0) stepl=0.0001d0
else
  stepl=steep_size
end if

if (maxforce .lt. 1d-30) stepl=0.d0
step=stepl/maxforce

  do i=1,nrestr
    do j=1,3
      rav(j,i,rep)=rav(j,i,rep)+step*fav(j,i,rep)
    end do
  end do

  if (stepl .lt. 1d-10) then
    moved=.true.
    stepl=0.d0
    write(*,*) "Step set to 0"
  end if

end subroutine steep

subroutine getmaxdisplacement(nrestr,nrep,rav,rrefall,maxdisp)
implicit none
double precision, dimension(3,nrestr,nrep), intent(in) :: rav, rrefall
double precision, intent(out) :: maxdisp
double precision :: disp
integer, intent(in) ::  nrestr, nrep
integer :: i, j ,k

maxdisp=0.d0
if (nrep .eq. 1) then
  k=1
  do i=1,nrestr
    do j=1,3
      disp=abs(rav(j,i,k)-rrefall(j,i,k))
      if (disp.gt.maxdisp) maxdisp = disp
    end do
  end do
else
  do k=2,nrep-1
    do i=1,nrestr
      do j=1,3
        disp=abs(rav(j,i,k)-rrefall(j,i,k))
        if (disp.gt.maxdisp) maxdisp = disp
      end do
    end do
  end do
end if
end subroutine getmaxdisplacement
