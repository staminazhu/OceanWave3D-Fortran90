!
! ****************************************************************
!
SUBROUTINE StoreKinematicData(Nx,Ny,Nz,io,it)
!
! ****************************************************************
!
!>
!! Write 3D kinematics data to an unformatted binary file
!!
!!
!! By Allan P. Engsig-Karup.
!<
USE GlobalVariables
USE hl_hdf5
IMPLICIT NONE
! Input parameters
INTEGER :: Nx, Ny, Nz, io, it
! Local variables
INTEGER ::  i, j, k, i0, i1, is, j0, j1, js
INTEGER :: FOUT
REAL(KIND=long), DIMENSION(:,:), POINTER :: x, y, h, hx, hy, eta, etax, etay
REAL(KIND=long), DIMENSION(:), POINTER   :: z, tmpxval
! Automatic work space
REAL(KIND=long) :: U(Nz,Nx,Ny), V(Nz,Nx,Ny), W(Nz,Nx,Ny), d(Nx,Ny)
REAL(KIND=long) :: tmpx(Nx), tmpy(Ny)
CHARACTER(len=30) :: form
REAL(KIND=long) :: hint, etaint, dint
REAL(KIND=long) :: Uint(Nz), Vint(Nz)
REAL(KIND=long) :: Wz(Nz,Nx,Ny)!
CHARACTER(LEN=20) :: h5file
INTEGER(HID_T) :: extended_dimension_id
INTEGER(HSIZE_T), ALLOCATABLE :: dims_ext(:)
INTEGER(HSIZE_T), SAVE :: maxdims1(1), maxdims2(3), maxdims3(4), &
                    chunkdims1(1), chunkdims2(3), chunkdims3(4), &
                    extdims1(1), extdims2(3), extdims3(4)
INTEGER(HSIZE_T), SAVE :: nx_save, ny_save, nz_save, onei = 1

! Assign the local pointers
!
x => FineGrid%x; y => FineGrid%y; z => FineGrid%z; h => FineGrid%h; hx => FineGrid%hx
hy => FineGrid%hy; eta => WaveField%E; etax => WaveField%Ex; etay => WaveField%Ey
!
! Shift the horizontal grid point position to account for the ghost points.  
!
IF(FORMATTYPE/=22)THEN
  i0=Output(io)%xbeg+GhostGridX; i1=Output(io)%xend+GhostGridX; is=Output(io)%xstride; 
  j0=Output(io)%ybeg+GhostGridY; j1=Output(io)%yend+GhostGridY; js=Output(io)%ystride; 
ELSE
  PRINT*,'Storing kinematics data...'
  ! determine indices for stencils
  tmpx = x(1:Nx,1)-Output(io)%x
  ! search
  DO i=1,Nx
    IF(tmpx(i)>0)THEN
       Output(io)%idx(1) = i-alpha
       Output(io)%idx(2) = i+alpha
       EXIT ! Out of DO loop
    END IF
  END DO
  IF(Ny>1)THEN
    tmpy = y(1,1:Ny)-Output(io)%y
    DO j=1,Ny
      IF(tmpy(j)>0)THEN
         Output(io)%idx(3) = j-beta
         Output(io)%idx(4) = j+beta
         EXIT ! Out of DO loop
      END IF
    END DO
  ELSE
    Output(io)%idx(3) = 1
    Output(io)%idx(4) = 1
  ENDIF
  ! determine stencil weights for the interpolation
  ALLOCATE( Output(io)%stencilx(2*alpha+1) )
  ALLOCATE( tmpxval(2*alpha+1) )
  tmpxval = x(Output(io)%idx(1) : Output(io)%idx(2),1)
  tmpxval(alpha+1) = Output(io)%x
  CALL TaylorFDStencils1DArbitrary(alpha,alpha,0,Output(io)%stencilx,tmpxval)
!  Output(io)%stencilx = zero
!  print*,'stencilx = ',Output(io)%stencilx
  IF(Ny>1)THEN
     ALLOCATE( Output(io)%stencily(2*beta+1) )
     ! weights in stream_func_wave_finite.f
     CALL TaylorFDStencils1DArbitrary(beta,beta,0,Output(io)%stencily,Output(io)%y)
  ENDIF
  ! formattype=22
  i0=Output(io)%idx(1) ! xmin
  i1=Output(io)%idx(2) ! xmax
  j0=Output(io)%idx(3) ! ymin
  j1=Output(io)%idx(4) ! ymax
!  print*,'i0=',i0
!  print*,'i1=',i1
!  print*,'j0=',j0
!  print*,'j1=',j1
END IF


! Determine fileoutput
IF(formattype==21)THEN
   WRITE(unit=filename, FMT="(A,I2.2,A,I5.5,A)") "Kinematics_",io,"_",it,".bin"
   form="unformatted" ! binary format chosen
   FOUT = 22 ! file handle
   OPEN (unit=FOUT, file=filename,form=form)
   WRITE(*,FMT='(A,A)') '  File output = ',filename
ELSE IF(formattype==22)THEN
   WRITE(unit=filename, FMT="(A,I2.2,A,I5.5,A)") "Kinematics_",io,"_",it,".bin"
   form="unformatted" ! binary format chosen
   FOUT = 22 ! file handle
   OPEN (unit=FOUT, file=filename,form=form)
   WRITE(*,FMT='(A,A)') '  File output = ',filename
ELSE IF(formattype==30)THEN   
   WRITE(*,FMT='(A,A)') '  File output of h5 file number = ','Kinematics'//fnt(i+1)//'.h5'
ELSE
   FOUT = FILEOP(io+1)
   WRITE(*,FMT='(A,I2)') '  File output unit number = ',FOUT
END IF

IF(it==0)THEN
   !
   ! Save the grid data on the first call
   !
   IF(formattype==22)THEN
!     WRITE (FOUT) Nx,Ny,Nz
     WRITE (FOUT) Output(io)%x, Output(io)%y, Output(io)%tbeg,Output(io)%tend, &
          Output(io)%tstride, dt, FineGrid%Nz+GhostGridZ
     IF(FineGrid%Nx>1 .AND. FineGrid%Ny>1) THEN
        PRINT*,'3D setup for formattype=22 in StoreKinematicData.f90 not setup yet.'
        STOP
!        hint   = DOT_PRODUCT( Output(io)%stencilx,h(i0:i1,j0:j1)   )
!        etaint = DOT_PRODUCT( Output(io)%stencilx,eta(i0:i1,j0:j1) )
!        dint   = hint + etaint
        WRITE (FOUT) hint, etaint, dint
     ELSE IF(FineGrid%Nx>1) THEN
        hint   = DOT_PRODUCT( Output(io)%stencilx,h(i0:i1,1)   )
        print*,'hint = ',hint
        etaint = DOT_PRODUCT( Output(io)%stencilx,eta(i0:i1,1) )
        print*,'eta = ',etaint
        dint   = hint + etaint
        print*,'dint = ',dint
        WRITE (FOUT) hint, etaint, dint
     ELSE IF(FineGrid%Ny>1) THEN
        PRINT*,'2D setup in y-direction for formattype=22 in StoreKinematicData.f90 not setup yet.'
        STOP
     END IF
!     WRITE (FOUT) ( Output(io)%x, Output(io%y, hint )
!     WRITE (FOUT) ( ( x(i,j), y(i,j), h(i,j), hx(i,j), hy(i,j), &
!          i=i0,i1,is ), j=j0,j1,js )
     ! are these z values the sigma values??
     WRITE (FOUT) (z(i),i=1,Nz)
     print*,'z=',z
     IF(curvilinearOnOff/=0)THEN
        Print *, 'StoreKinematicData:  Saving horizontal fluid velocities is not yet implemented for curvilinear grids.'
     END IF
   ELSEIF (formattype == 30) THEN !hdf5 file

         ! Some parameters that are necessary for h5 saving
         ny_save = size((/(i, i=j0,j1,js)/))
         nx_save = size((/(i, i=i0,i1,is)/))
         nz_save = Nz
         
         ! Max dimensions for h5 writing
         maxdims1 = (/H5S_UNLIMITED_F/)
         maxdims2 = (/H5S_UNLIMITED_F, H5S_UNLIMITED_F, H5S_UNLIMITED_F/)
         maxdims3 = (/H5S_UNLIMITED_F, H5S_UNLIMITED_F, H5S_UNLIMITED_F, H5S_UNLIMITED_F/)
         ! Chunk dims
         chunkdims1 = (/100*onei/)
         chunkdims2 = (/ny_save, nx_save, 100*onei/)
         chunkdims3 = (/nz_save, ny_save, nx_save, 100*onei/)
         ! ext dims
         extdims1 = (/onei/)
         extdims2 = (/ny_save, nx_save, onei/)
         extdims3 = (/nz_save, ny_save, nx_save, onei/)

         ! Initialize all datasets
         h5file = 'Kinematics'//fnt(io)//'.h5';
         ! Create
         call h5_dataset_create_chunked(h5file, 'time', INT(1, HID_T), &
                  & extdims1, maxdims1, chunkdims1) 
         call h5_dataset_create_chunked(h5file, 'surface_elevation', INT(3, HID_T), &
                  & extdims2, maxdims2, chunkdims2)

         ! Write
         call h5_write(h5file, 'time', (/it*dt/))
         call h5_write(h5file, 'surface_elevation', transpose(eta(i0:i1:is, j0:j1:js)))

      IF(curvilinearOnOff/=0)THEN
      Print *, 'StoreKinematicData:  Saving horizontal fluid velocities is not yet implemented for curvilinear grids.'
      END IF
   ELSE
     ! formattype /= 22
     write (FOUT) Output(io)%xbeg,Output(io)%xend,Output(io)%xstride, &
          Output(io)%ybeg, Output(io)%yend, Output(io)%ystride,               &
          Output(io)%tbeg,Output(io)%tend,Output(io)%tstride, dt, Nz
     !
     WRITE (FOUT) ( ( x(i,j), y(i,j), h(i,j), hx(i,j), hy(i,j), &
          i=i0,i1,is ), j=j0,j1,js ) 
     WRITE (FOUT) (z(i),i=1,Nz)
     IF(curvilinearOnOff/=0)THEN
        Print *, 'StoreKinematicData:  Saving horizontal fluid velocities is not yet implemented for curvilinear grids.'
     END IF
   END IF

ELSE !IF(it==0)THEN

   !
   IF(curvilinearOnOff == 0)THEN
      IF(formattype==22)THEN
         !
         ! Dump free surface elevation, still water depth and kinematics to the output file.
         ! Minimal no of variables and storage is output.
         !
         ! WRITE (FOUT) ( ( eta(i,j), i=i0,i1,is ), j=j0,j1,js)
         ! WRITE (FOUT) ( ( h(i,j), i=i0,i1,is ), j=j0,j1,js) 
         !                                                                  
         ! The fluid thickness d=h+eta
         !            
         DO j=1,Ny
            DO i=1,Nx
                d(i,j)=h(i,j)+eta(i,j);
            END DO
         END DO
         !  CALL DiffZArbitrary(phi,W,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
         !  FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,gamma)
         ! Compute dphi/dsigma
         !
         CALL DiffZArbitrary(phi,W,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
           FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,gamma)
         IF (FineGrid%Nx>1) THEN
         !
         ! Compute dphi/dx 
         !	
            CALL DiffXEven(phi,U,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
              FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,alpha)
            IF ( LinearOnOff /= 0) THEN
               !
               ! Add in the chain rule contribution to get the velocity
               !
               Do j=1,Ny
                  Do i=1,Nx
                     Do k=1,Nz
                        U(k,i,j) = U(k,i,j) + ((1-z(k))/d(i,j)*hx(i,j)-z(k)/d(i,j)*etax(i,j))*W(k,i,j)
                     END Do
                  END Do
               END Do
            END IF
         ELSE
            U=zero
         END IF
         ! Interpolate to point in question
         DO k = 1, FineGrid%Nz+GhostGridZ
            DO j=j0,j1
               Uint(k) = DOT_PRODUCT( Output(io)%stencilx,U(k,i0:i1,j) )
            END DO
         END DO
         WRITE (FOUT) Uint
         ! print*,'Uint:stencilx=',Output(io)%stencilx
         ! print*,'Uint = ',Uint
         ! WRITE (FOUT) ( ( ( U(k,i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js)
         ! 
         IF (FineGrid%Ny>1) THEN
            ! dphi/dy
            CALL DiffYEven(phi,V,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
               FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,beta)
            IF ( LinearOnOff /= 0) THEN
               Do j=1,Ny
                  Do i=1,Nx
                     Do k=1,Nz
                        V(k,i,j) = V(k,i,j)+((1-z(k))/d(i,j)*hy(i,j)-z(k)/d(i,j)*etay(i,j))*W(k,i,j)
                     END Do
                  END Do
               END Do
            END IF
            ! WRITE (FOUT) ( ( ( V(k,i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js)
            ! Interpolate to point in question
            DO k = 1, FineGrid%Nz+GhostGridZ
               DO j=j0,j1
                  Vint(k) = DOT_PRODUCT( Output(io)%stencilx,V(k,i0:i1,j) )
               END DO
            END DO
            WRITE (FOUT) Vint
         ELSE
            V=zero
         END IF
      !
      ! Write the vertical velocity
      !
      ! WRITE (FOUT) ( ( ( W(k,i,j)/d(i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js) 
      ELSE IF (formattype==30)THEN
         h5file = 'Kinematics'//fnt(io)//'.h5';
         extended_dimension_id = 1
         call h5_extend(h5file, 'time', extended_dimension_id, extdims1, (/it*dt/))
         extended_dimension_id = 3
         call h5_extend(h5file, 'surface_elevation', extended_dimension_id, extdims2, &
            & transpose(eta(i0:i1:is, j0:j1:js)))
      ELSE
         !
         ! Dump this solution slice to the output file
         !
         ! First the free surface elevation and gradient at all points in this slice
         ! 
         WRITE (FOUT) ( ( eta(i,j), i=i0,i1,is ), j=j0,j1,js) 
         IF(Nx > 1) THEN
            WRITE (FOUT) ( ( etax(i,j), i=i0,i1,is ), j=j0,j1,js) 
         ELSE
            WRITE (FOUT) ( ( zero, i=i0,i1,is ), j=j0,j1,js) 
         END IF

         IF(Ny > 1) THEN
            WRITE (FOUT) ( ( etay(i,j), i=i0,i1,is ), j=j0,j1,js) 
         ELSE
            WRITE (FOUT) ( ( zero, i=i0,i1,is ), j=j0,j1,js) 
         END IF
         !
         ! The fluid thickness d=h+eta
         !
         DO j=1,Ny
            DO i=1,Nx
               d(i,j)=h(i,j)+eta(i,j);
            END DO
         END DO
         !
         ! Then the velocity potential at all points in this horizontal slice and at all sigma 
         ! (vertical) locations.  
         !
         WRITE (FOUT) ( ( ( phi(k,i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js) 
         !
         ! Then the velocities at all points in this horizontal slice and at all sigma 
         ! (vertical) locations.  
         !
         !
         ! Compute dphi/dsigma
         !
         CALL DiffZArbitrary(phi,W,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
            FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,gamma)
         IF (FineGrid%Nx>1) THEN
            !
            ! Compute dphi/dx 
            !	
         CALL DiffXEven(phi,U,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
               FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,alpha)
         IF ( LinearOnOff /= 0) THEN
            !
            ! Add in the chain rule contribution to get the velocity
            !
            Do j=1,Ny
               Do i=1,Nx
                  Do k=1,Nz
                     U(k,i,j) = U(k,i,j) + ((1-z(k))/d(i,j)*hx(i,j)-z(k)/d(i,j)*etax(i,j))*W(k,i,j)
                  END Do
               END Do
            END Do
         END IF

         ELSE
            U=zero
         END IF
         !
         WRITE (FOUT) ( ( ( U(k,i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js)
         ! 
         IF (FineGrid%Ny>1) THEN
            ! dphi/dy
            CALL DiffYEven(phi,V,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
               FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,beta)
            IF ( LinearOnOff /= 0) THEN
               Do j=1,Ny
                  Do i=1,Nx
                     Do k=1,Nz
                        V(k,i,j) = V(k,i,j)+((1-z(k))/d(i,j)*hy(i,j)-z(k)/d(i,j)*etay(i,j))*W(k,i,j)
                     END Do
                  END Do
               END Do
            END IF
         ELSE
            V=zero
         END IF

         WRITE (FOUT) ( ( ( V(k,i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js)
         !
         ! Write the vertical velocity
         !
         WRITE (FOUT) ( ( ( W(k,i,j)/d(i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js) 
         !
         ! Compute du/dsigma and write du/dz to disc
         !
         CALL DiffZArbitrary(U,W,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
            FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,gamma)
         WRITE (FOUT) ( ( ( W(k,i,j)/d(i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js) 
         !
         ! Compute du/dsigma and write dv/dz to disc
         !
         CALL DiffZArbitrary(V,W,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
            FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,gamma)
         WRITE (FOUT) ( ( ( W(k,i,j)/d(i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js) 
         !
         ! Compute du/dsigma and write dw/dz to disc
         !
         CALL DiffZArbitrary(W,Wz,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
         FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,gamma)
         WRITE (FOUT) ( ( ( Wz(k,i,j)/d(i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js) 
         !--------------------------------------- du/dy
         IF (FineGrid%Ny>1) THEN
         CALL DiffYEven(U,Wz,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
               FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,beta)
            ! IF ( LinearOnOff /= 0) THEN
            ! Do j=1,Ny
               !   Do i=1,Nx
               !     Do k=1,Nz
               !       V(k,i,j) = V(k,i,j)+((1-z(k))/d(i,j)*hy(i,j)-z(k)/d(i,j)*etay(i,j))*W(k,i,j)
                  !  END Do
                  ! END Do
            ! END Do
         ! END IF
         ELSE
         Wz=zero
         END IF
      
         WRITE (FOUT) ( ( ( Wz(k,i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js)
         !--------------------------------------- dv/dy
         IF (FineGrid%Ny>1) THEN
         CALL DiffYEven(V,Wz,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
               FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,beta)
            ! IF ( LinearOnOff /= 0) THEN
            ! Do j=1,Ny
               !   Do i=1,Nx
               !     Do k=1,Nz
               !       V(k,i,j) = V(k,i,j)+((1-z(k))/d(i,j)*hy(i,j)-z(k)/d(i,j)*etay(i,j))*W(k,i,j)
                  !  END Do
                  ! END Do
            ! END Do
         ! END IF
         ELSE
         Wz=zero
         END IF
         
         WRITE (FOUT) ( ( ( Wz(k,i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js)
         !--------------------------------------- du/dx
         IF (FineGrid%Nx>1) THEN
         CALL DiffXEven(U,Wz,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
               FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,alpha)
         !IF ( LinearOnOff /= 0) THEN
         !
         ! Add in the chain rule contribution to get the velocity
         !
         !Do j=1,Ny
         !    Do i=1,Nx
         !          Do k=1,Nz
            !            U(k,i,j) = U(k,i,j) + ((1-z(k))/d(i,j)*hx(i,j)-z(k)/d(i,j)*etax(i,j))*W(k,i,j)
            !        END Do
            !    END Do
               !END Do
            !END IF
         ELSE
            Wz=zero
         END IF
         WRITE (FOUT) ( ( ( Wz(k,i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js)
         !--------------------------------------- dv/dx
         IF (FineGrid%Nx>1) THEN
         CALL DiffXEven(V,Wz,1,FineGrid%Nx+2*GhostGridX,FineGrid%Ny+2*GhostGridY,  &
               FineGrid%Nz+GhostGridZ,FineGrid%DiffStencils,alpha)
         !IF ( LinearOnOff /= 0) THEN
         !
         ! Add in the chain rule contribution to get the velocity
         !
         !Do j=1,Ny
         !    Do i=1,Nx
         !          Do k=1,Nz
            !            U(k,i,j) = U(k,i,j) + ((1-z(k))/d(i,j)*hx(i,j)-z(k)/d(i,j)*etax(i,j))*W(k,i,j)
            !        END Do
            !    END Do
               !END Do
            !END IF
         ELSE
            Wz=zero
         END IF
         WRITE (FOUT) ( ( ( Wz(k,i,j), k=1,FineGrid%Nz+GhostGridZ), i=i0,i1,is), j=j0,j1,js)
      ! sigs ends lines
      END IF

   END IF
END IF

if (formattype == 22 .or. formattype == 21) then 
   CLOSE(FOUT)
end if
END SUBROUTINE StoreKinematicData
