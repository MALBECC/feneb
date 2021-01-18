 program feneb
use netcdf
use readandget
implicit none
character(len=50) :: infile, reffile, outfile, chi, iname, rname, oname
integer :: nsteps, spatial, natoms, nrestr, nrep, nscycle,maxforceat
integer :: i, j, k
integer, allocatable, dimension (:) :: mask
real(4) :: coordinate
real(4), allocatable, dimension (:) :: coordx,coordy,coordz
integer, dimension (3) :: point
double precision :: kref, steep_size, ftol, maxforce, kspring, maxforceband, lastmforce
double precision :: stepl, deltaA, rms
double precision, dimension(6) :: boxinfo
double precision, allocatable, dimension(:,:) :: rref
double precision, allocatable, dimension(:,:,:) :: rav, fav, tang, ftang, ftrue, fperp, rrefall
double precision, allocatable, dimension(:,:,:) :: fspring, dontg
logical ::  per, velin, velout, relaxd, converged, wgrad

!------------ Read input
    call readinput(nrep,infile,reffile,outfile,mask,nrestr,lastmforce, &
                 rav,fav,ftrue,ftang,fperp,fspring,tang,kref,kspring,steep_size, &
                 ftol,per,velin,velout,wgrad,rrefall,nscycle,dontg)
!------------


 open(unit=9999, file="feneb.out") !Opten file for feneb output
!------------ Main loop
  if (nrep .eq. 1) then !FE opt only
    write(9999,*) "---------------------------------------------------"
    write(9999,*) "Performing FE full optmization for a single replica"
    write(9999,*) "---------------------------------------------------"



    call getfilenames(nrep,chi,infile,reffile,outfile,iname,rname,oname)
    call getdims(iname,nsteps,spatial,natoms)


    if (allocated(coordx)) deallocate(coordx)
    if (allocated(coordy)) deallocate(coordy)
    if (allocated(coordz)) deallocate(coordz)
    if (allocated(rref)) deallocate(rref)

    allocate(coordx(nsteps),coordy(nsteps),coordz(nsteps),rref(3,natoms))

    call getrefcoord(rname,nrestr,mask,natoms,rref,boxinfo,per,velin)

    call getavcoordanforces(iname,nsteps,natoms,spatial,coordx,coordy,coordz,&
                        nrestr,mask,kref,rav,fav,nrep,nrep,rref,wgrad,dontg)

    call writeposforces(rav,fav,nrestr,nrep,nrep)

    call getmaxforce(nrestr,nrep,nrep,fav,maxforce,ftol,relaxd,maxforceat,rms)


    write(9999,*) "Max force: ", maxforce

    if (.not. relaxd) then
       call steep(rav,fav,nrep,nrep,steep_size,maxforce,nrestr,lastmforce,stepl,deltaA,dontg)
       if (stepl .lt. 1d-10) then
         write(9999,*) "-----------------------------------------------------"
         write(9999,*) "Warning: max precision reached on atomic displacement"
         write(9999,*) "step length has been set to zero"
         write(9999,*) "-----------------------------------------------------"
       end if
       call writenewcoord(oname,rref,boxinfo,natoms,nrestr,mask,per,velout,rav,nrep,nrep)
       write(9999,*) "System converged: F"
    else
       write(9999,*) "System converged: T"
       write(9999,*) "Convergence criteria of ", ftol, " (kcal/mol A) achieved"
    endif

  elseif (nrep .gt. 1) then !NEB on FE surface

    write(9999,*) "---------------------------------------------------"
    write(9999,*) "       Performing NEB on the FE surface"
    write(9999,*) "---------------------------------------------------"
!------------ Get coordinates for previously optimized extrema
!------------ And set forces to zero
    !Reactants
    call getfilenames(1,chi,infile,reffile,outfile,iname,rname,oname)
    call getrefcoord(rname,nrestr,mask,natoms,rref,boxinfo,per,velin)
    call getcoordextrema(rref,natoms,rav,nrestr,nrep,1,mask)



    !Products
    call getfilenames(nrep,chi,infile,reffile,outfile,iname,rname,oname)
    call getrefcoord(rname,nrestr,mask,natoms,rref,boxinfo,per,velin)
    call getcoordextrema(rref,natoms,rav,nrestr,nrep,nrep,mask)

    !Forces set to zero
    fav=0.d0

!------------ Band loop
    do i=1,nrep

      call getfilenames(i,chi,infile,reffile,outfile,iname,rname,oname)
      call getdims(iname,nsteps,spatial,natoms)

      if (allocated(coordx)) deallocate(coordx)
      if (allocated(coordy)) deallocate(coordy)
      if (allocated(coordz)) deallocate(coordz)
      if (allocated(rref)) deallocate(rref)
      allocate(coordx(nsteps),coordy(nsteps),coordz(nsteps),rref(3,natoms))

      call getrefcoord(rname,nrestr,mask,natoms,rref,boxinfo,per,velin)

      call getavcoordanforces(iname,nsteps,natoms,spatial,coordx,coordy, coordz,&
                    nrestr,mask,kref,rav,fav,nrep,i,rref,wgrad,dontg)
    end do


!----------- Puts reference values in a single array (rrefall). Currently not used.
    ! do i=1,nrep
    !   call getfilenames(i,chi,infile,reffile,outfile,iname,rname,oname)
    !   call getrefcoord(rname,nrestr,mask,natoms,rref,boxinfo,per,velin)
    !   call getcoordextrema(rref,natoms,rrefall,nrestr,nrep,i,mask)
    ! end do


!----------- Write mean pos and forces
    do i=1,nrep
      call writeposforces(rav,fav,nrestr,i,nrep)
    end do

!----------- Computes tangent and nebforce
    call gettang(rav,tang,nrestr,nrep)

    call getnebforce(rav,fav,tang,nrestr,nrep,kspring,maxforceband,ftol,relaxd,&
                    ftrue,ftang,fperp,fspring,.true.,dontg)
! fav ---> fneb

!----------- moves the band
    if (.not. converged) then

       do i=2,nrep-1
          if (.not. relaxd) call steep(rav,fperp,nrep,i,steep_size,maxforceband,nrestr,lastmforce,stepl,deltaA,dontg)
        end do

        write(9999,'(1x,a,f8.6)') "Step length: ", stepl
        if (stepl .lt. 1d-5) then
          write(9999,*) "-----------------------------------------------------"
          write(9999,*) "Warning: max precision reached on atomic displacement"
          write(9999,*) "step length has been set to zero"
          write(9999,*) "-----------------------------------------------------"
        end if

        rms=0.d0
        do i=1,nrep
          call getmaxforce(nrestr,nrep,i,fav,maxforce,ftol,relaxd,maxforceat,rms)
        end do
        rms=dsqrt(rms/dble(nrep*nrestr))

        write(9999,'(1x,a,f8.6)') "RMS(FNEB): ", rms/nrep

        if (nscycle .eq. 1) write(9999,*) "WARNING: Using only fperp to move the band!"
        if (nscycle .gt. 1) then

          write(9999,*) "-----------------------------------------------------"
          write(9999,*) "Performing extra optimization steps using fspring    "
          write(9999,*) "to get a better distribution of replicas.            "
          write(9999,'(1x,a,I4)') "Extra optmization movements: ", nscycle
          write(9999,*) "-----------------------------------------------------"
        end if

        do k=1,nscycle
          !Computes spring force and others
          call getnebforce(rav,fav,tang,nrestr,nrep,kspring,maxforceband,ftol,converged,&
                          ftrue,ftang,fperp,fspring,.false.,dontg)
          !como wrmforce es false, acá usa fspring para determinar maxforceband
          !Moves band using spring force only
          dontg=0.d0
          do i=2,nrep-1
            call steep(rav,fspring,nrep,i,steep_size,maxforceband,nrestr,lastmforce,stepl,deltaA,dontg)
          end do
        end do


    !------------ Get coordinates for previously optimized extrema
        !Reactants
        call getfilenames(1,chi,infile,reffile,outfile,iname,rname,oname)
        call getrefcoord(rname,nrestr,mask,natoms,rref,boxinfo,per,velin)
        call getcoordextrema(rref,natoms,rav,nrestr,nrep,1,mask)

        !Products
        call getfilenames(nrep,chi,infile,reffile,outfile,iname,rname,oname)
        call getrefcoord(rname,nrestr,mask,natoms,rref,boxinfo,per,velin)
        call getcoordextrema(rref,natoms,rav,nrestr,nrep,nrep,mask)


        do i=1,nrep
          call getfilenames(i,chi,infile,reffile,outfile,iname,rname,oname)
          call getrefcoord(rname,nrestr,mask,natoms,rref,boxinfo,per,velin)
          call writenewcoord(oname,rref,boxinfo,natoms,nrestr,mask,per,velout,rav,nrep,i)
        end do
    end if !converged
  end if !nrep gt 1

  close(unit=9999)

end program feneb
