!..................................................................................................................................
! LICENSING                                                                                                                         
! Copyright (C) 2013  National Renewable Energy Laboratory
!
!    Glue is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as
!    published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
!
!    This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
!    of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License along with Module2.
!    If not, see <http://www.gnu.org/licenses/>.
!
!**********************************************************************************************************************************
!  
!    ADD DESCRIPTION
!	
!    References:
!
!
!**********************************************************************************************************************************
PROGRAM MAIN

   USE BeamDyn_SP
   USE BeamDyn_Types

   USE NWTC_Library

   IMPLICIT NONE

   ! global glue-code-specific variables

   INTEGER(IntKi)                     :: ErrStat          ! Error status of the operation
   CHARACTER(1024)                    :: ErrMsg           ! Error message if ErrStat /= ErrID_None

   REAL(DbKi)                         :: dt_global        ! fixed/constant global time step
   REAL(DbKi)                         :: t_initial        ! time at initialization
   REAL(DbKi)                         :: t_final          ! time at simulation end 
   REAL(DbKi)                         :: t_global         ! global-loop time marker

   INTEGER(IntKi)                     :: n_t_final        ! total number of time steps
   INTEGER(IntKi)                     :: n_t_global       ! global-loop time counter

   INTEGER(IntKi)                     :: pc_max           ! 1:explicit loose; 2:pc loose
   INTEGER(IntKi)                     :: pc               ! counter for pc iterations

   INTEGER(IntKi)                     :: BD_interp_order     ! order of interpolation/extrapolation

   ! Module1 Derived-types variables; see Registry_Module1.txt for details

   TYPE(BD_InitInputType)           :: BD_InitInput
   TYPE(BD_ParameterType)           :: BD_Parameter
   TYPE(BD_ContinuousStateType)     :: BD_ContinuousState
   TYPE(BD_ContinuousStateType)     :: BD_ContinuousStateDeriv
   TYPE(BD_InitOutputType)          :: BD_InitOutput
   TYPE(BD_DiscreteStateType)       :: BD_DiscreteState
   TYPE(BD_ConstraintStateType)     :: BD_ConstraintState
   TYPE(BD_OtherStateType)          :: BD_OtherState

   TYPE(BD_InputType),ALLOCATABLE  :: BD_Input(:)
   REAL(DbKi),        ALLOCATABLE  :: BD_InputTimes(:)

   TYPE(BD_OutputType),ALLOCATABLE  :: BD_Output(:)
   REAL(DbKi),ALLOCATABLE           :: BD_OutputTimes(:)

   TYPE(BD_InputType)   :: u1    ! local variable for extrapolated inputs
   TYPE(BD_OutputType)  :: y1    ! local variable for extrapolated outputs

   ! Module 1 deived data typed needed in pc-coupling; predicted states

   TYPE(BD_ContinuousStateType)     :: BD_ContinuousState_pred
   TYPE(BD_DiscreteStateType)       :: BD_DiscreteState_pred
   TYPE(BD_ConstraintStateType)     :: BD_ConstraintState_pred

   ! local variables
   Integer(IntKi)                     :: i               ! counter for various loops
   Integer(IntKi)                     :: j               ! counter for various loops

   INTEGER(IntKi),PARAMETER:: QiDisUnit = 20
   INTEGER(IntKi),PARAMETER:: QiRootUnit = 30

   REAL(ReKi):: temp_H(3,3)
   REAL(ReKi):: temp_cc(3)
   REAL(ReKi):: temp_R(3,3)
   REAL(ReKi):: temp_vec(3)
   REAL(ReKi):: temp1,temp2
   REAL(ReKi):: temp_a,temp_b,temp_force
   REAL(DbKi):: start, finish
   Integer(IntKi)                     :: temp_count
!   REAL(ReKi),PARAMETER    :: PI = 3.1415926D0

   ! -------------------------------------------------------------------------
   ! Initialization of glue-code time-step variables
   ! -------------------------------------------------------------------------

   t_initial = 0.0D+00
   t_final   = 1.0D+01

   pc_max = 1  ! Number of predictor-corrector iterations; 1 corresponds to an explicit calculation where UpdateStates 
               ! is called only once  per time step for each module; inputs and outputs are extrapolated in time and 
               ! are available to modules that have an implicit dependence on other-module data

   ! specify time increment; currently, all modules will be time integrated with this increment size
!   dt_global = 1.0D-03
   dt_global = 1.0D-03*5.0D0

   n_t_final = ((t_final - t_initial) / dt_global )

   t_global = t_initial

   ! define polynomial-order for ModName_Input_ExtrapInterp and ModName_Output_ExtrapInterp
   ! Must be 0, 1, or 2
   BD_interp_order = 2

   !Module1: allocate Input and Output arrays; used for interpolation and extrapolation
   ALLOCATE(BD_Input(BD_interp_order + 1)) 
   ALLOCATE(BD_InputTimes(BD_interp_order + 1)) 

   ALLOCATE(BD_Output(BD_interp_order + 1)) 
   ALLOCATE(BD_OutputTimes(BD_interp_order + 1)) 


   ! -------------------------------------------------------------------------
   ! Initialization of Modules
   !  note that in this example, we are assuming that dt_global is not changed 
   !  in the modules, i.e., that both modules are called at the same glue-code  
   !  defined coupling interval.
   ! -------------------------------------------------------------------------
    OPEN(unit = QiDisUnit, file = 'QiDisp_AM2.out', status = 'REPLACE',ACTION = 'WRITE')
    OPEN(unit = QiRootUnit,file = 'QiRoot_AM2.out', status = 'REPLACE',ACTION = 'WRITE')


!   BD_InitInput%InputFile = 'BeamDyn_Input_CX100.inp'
!   BD_InitInput%InputFile = 'BeamDyn_Input_5MW.inp'
   BD_InitInput%InputFile = 'BeamDyn_Input_5MW_New.inp'
!   BD_InitInput%InputFile = 'Siemens_53_Input.inp'
!   BD_InitInput%InputFile = 'GA2_Debug.inp'
!   BD_InitInput%InputFile = 'BeamDyn_Input_Sample.inp'
!   BD_InitInput%InputFile = 'BeamDyn_Input_Composite.inp'
!   BD_InitInput%InputFile = 'BeamDyn_Input_Damp.inp'
!   BD_InitInput%InputFile = 'BeamDyn_Curved.inp'
   BD_InitInput%RootName  = TRIM(BD_Initinput%InputFile)
   ALLOCATE(BD_InitInput%gravity(3)) 
   BD_InitInput%gravity(1) = 0.0D0 !-9.80665
   BD_InitInput%gravity(2) = 0.0D0 
   BD_InitInput%gravity(3) = 0.0D0 

   ALLOCATE(BD_InitInput%GlbPos(3)) 
   BD_InitInput%GlbPos(1) = 0.0D+00
   BD_InitInput%GlbPos(2) = 0.0D+01
   BD_InitInput%GlbPos(3) = 0.0D0

   ALLOCATE(BD_InitInput%GlbRot(3,3)) 
   BD_InitInput%GlbRot(:,:) = 0.0D0
   temp_vec(1) = 0.0
   temp_vec(2) = 0.0
   temp_vec(3) = 4.0D0*TAN((-3.1415926D0/2.0D0)/4.0D0)
   CALL CrvMatrixR(temp_vec,temp_R)
   BD_InitInput%GlbRot(1:3,1:3) = temp_R(1:3,1:3)

   CALL BeamDyn_Init(BD_InitInput        &
                   , BD_Input(1)         &
                   , BD_Parameter        &
                   , BD_ContinuousState  &
                   , BD_DiscreteState    &
                   , BD_ConstraintState  &
                   , BD_OtherState       &
                   , BD_Output(1)        &
                   , dt_global             &
                   , BD_InitOutput       &
                   , ErrStat               &
                   , ErrMsg )


   CALL BD_CopyInput(  BD_Input(1), u1, MESH_NEWCOPY, ErrStat, ErrMsg )
   CALL BD_CopyOutput( BD_Output(1), y1, MESH_NEWCOPY, ErrStat, ErrMsg )

   ! We fill Mod1_InputTimes with negative times, but the Mod1_Input values are identical for each of those times; this allows 
   ! us to use, e.g., quadratic interpolation that effectively acts as a zeroth-order extrapolation and first-order extrapolation 
   ! for the first and second time steps.  (The interpolation order in the ExtrapInput routines are determined as 
   ! order = SIZE(Mod1_Input)
   DO i = 1, BD_interp_order + 1  
      BD_InputTimes(i) = t_initial - (i - 1) * dt_global
      BD_OutputTimes(i) = t_initial - (i - 1) * dt_global
   ENDDO

   DO i = 1, BD_interp_order
      CALL BD_CopyInput (BD_Input(i),  BD_Input(i+1),  MESH_NEWCOPY, Errstat, ErrMsg)
      CALL BD_CopyOutput (BD_Output(i),  BD_Output(i+1),  MESH_NEWCOPY, Errstat, ErrMsg)
   ENDDO

   ! -------------------------------------------------------------------------
   ! Time-stepping loops
   ! -------------------------------------------------------------------------

   ! write headers for output columns:
       
   CALL WrScr1( '  Time (t)         Numerical q_1(t) Analytical q_1(t)' )
   CALL WrScr(  '  ---------------  ---------------- -----------------' ) ! write initial condition for q1 !CALL WrScr  ( '  '//Num2LStr(t_global)//'  '//Num2LStr( Mod1_ContinuousState%q)//'  '//Num2LStr(Mod1_ContinuousState%q))   

temp_count = 0   
CALL CPU_TIME(start)
   DO n_t_global = 0, n_t_final-1

WRITE(*,*) "Time Step: ", n_t_global
!IF(n_t_global == 1) STOP 
!  This way, when RK4 is called using ExtrapInterp, it will grab the EXACT answers that you defined at the time
!  step endpionts and midpoint.

      CALL BD_InputSolve( t_global,                   BD_Input(1), BD_InputTimes(1), BD_Parameter, ErrStat, ErrMsg)
      CALL BD_InputSolve( t_global + dt_global,       BD_Input(2), BD_InputTimes(2), BD_Parameter, ErrStat, ErrMsg)
      CALL BD_InputSolve( t_global + 2.0D0*dt_global, BD_Input(3), BD_InputTimes(3), BD_Parameter, ErrStat, ErrMsg)
!--------------------------------------------
! Compute initial condition given root motion
!--------------------------------------------
      IF(n_t_global .EQ. 0) THEN
          CALL BD_InitialCondition(BD_Input(1),BD_Parameter,BD_ContinuousState,ErrStat,ErrMsg)
      ENDIF
!------------------------------
! END Compute initial condition
!------------------------------
     CALL BeamDyn_CalcOutput( t_global, BD_Input(1), BD_Parameter, BD_ContinuousState, BD_DiscreteState, &
                             BD_ConstraintState, &
                             BD_OtherState,  BD_Output(1), ErrStat, ErrMsg)


      DO pc = 1, pc_max

         !----------------------------------------------------------------------------------------
         ! Mod1
         !----------------------------------------------------------------------------------------

         ! copy ContinuousState to ContinuousState_pred; don't modify ContinuousState until completion of PC iterations

         CALL BD_CopyContState   (BD_ContinuousState, BD_ContinuousState_pred, 0, Errstat, ErrMsg)

         CALL BD_CopyConstrState (BD_ConstraintState, BD_ConstraintState_pred, 0, Errstat, ErrMsg)

         CALL BD_CopyDiscState   (BD_DiscreteState,   BD_DiscreteState_pred,   0, Errstat, ErrMsg)
         CALL BeamDyn_UpdateStates( t_global, n_t_global, BD_Input, BD_InputTimes, BD_Parameter, &
                                   BD_ContinuousState_pred, &
                                   BD_DiscreteState_pred, BD_ConstraintState_pred, &
                                   BD_OtherState, ErrStat, ErrMsg )


      ENDDO

!     CALL BeamDyn_CalcOutput( t_global, BD_Input(1), BD_Parameter, BD_ContinuousState, BD_DiscreteState, &
!                             BD_ConstraintState, &
!                             BD_OtherState,  BD_Output(1), ErrStat, ErrMsg)
!   WRITE(QiHUnit,*) n_t_global+1,BD_OtherState%NR_counter
!   temp_count = temp_count + BD_OtherState%NR_counter

!IF(n_t_global .EQ. 301) STOP
!      IF(n_t_global .GE. 149) THEN
!      DO i=1,BD_Parameter%dof_total
!          WRITE(*,*) BD_ContinuousState%dqdt(i)  
!      ENDDO
!      ENDIF
      WRITE(QiDisUnit,6000) t_global,BD_ContinuousState%q(BD_Parameter%dof_total-5),BD_ContinuousState%q(BD_Parameter%dof_total-4),&
                           &BD_ContinuousState%q(BD_Parameter%dof_total-3),BD_ContinuousState%q(BD_Parameter%dof_total-2),&
                           &BD_ContinuousState%q(BD_Parameter%dof_total-1),BD_ContinuousState%q(BD_Parameter%dof_total)
!      WRITE(QiDisUnit,6000) t_global,BD_ContinuousState%dqdt(BD_Parameter%dof_total-5),BD_ContinuousState%dqdt(BD_Parameter%dof_total-4),&
!                           &BD_ContinuousState%dqdt(BD_Parameter%dof_total-3),BD_ContinuousState%dqdt(BD_Parameter%dof_total-2),&
!                           &BD_ContinuousState%dqdt(BD_Parameter%dof_total-1),BD_ContinuousState%dqdt(BD_Parameter%dof_total)
!      WRITE(QiRootUnit,6000) t_global,BD_ContinuousState%dqdt(1),BD_ContinuousState%dqdt(2),&
!                           &BD_ContinuousState%dqdt(3),BD_ContinuousState%dqdt(4),&
!                           &BD_ContinuousState%dqdt(5),BD_ContinuousState%dqdt(6)
!      WRITE(QiRootUnit,6000) t_global,BD_ContinuousState%q(1),BD_ContinuousState%q(2),&
!                           &BD_ContinuousState%q(3),BD_ContinuousState%q(4),&
!                           &BD_ContinuousState%q(5),BD_ContinuousState%q(6)
!      WRITE(QiRootUnit,6000) t_global,BD_Input(1)%RootMotion%TranslationAcc(1:3,1)
!CALL CrvMatrixB(BD_ContinuousState%q(4:6),BD_ContinuousState%q(4:6),temp_H)
!CALL CrvMatrixH(BD_ContinuousState%q(4:6),temp_H)
!WRITE(QiHUnit,7000) t_global,temp_H(1,1),temp_H(1,2),temp_H(1,3),temp_H(2,1),temp_H(2,2),temp_H(2,3),&
!                    temp_H(3,1),temp_H(3,2),temp_H(3,3)      
!CALL CrvExtractCrv(BD_OutPut(1)%BldMotion%Orientation(1:3,1:3,BD_Parameter%node_total),temp_cc)
!      WRITE(QiDisUnit,6000) t_global,&
!                           &BD_OutPut(1)%BldMotion%TranslationDisp(1:3,BD_Parameter%node_total),&
!                           &temp_cc(1:3)
!                           &BD_OutPut(1)%BldMotion%TranslationVel(1:3,BD_Parameter%node_total)
!                           &BD_OutPut(1)%BldMotion%RotationVel(1:3,BD_Parameter%node_total)
!                           &BD_OutPut(1)%BldMotion%TranslationAcc(1:3,BD_Parameter%node_total),&
!                           &BD_OutPut(1)%BldForce%Force(1:3,1),&
!                           &BD_OutPut(1)%BldForce%Moment(1:3,1)
!                           &BD_OutPut(1)%BldMotion%RotationAcc(1:3,BD_Parameter%node_total)
!      WRITE(QiDisUnit,6000) t_global,BD_ContinuousState%q(1),BD_ContinuousState%q(2),&
!                           &BD_ContinuousState%q(3),BD_ContinuousState%q(4),&
!                           &BD_ContinuousState%q(5),BD_ContinuousState%q(6)

      ! Save all final variables 

      CALL BD_CopyContState   (BD_ContinuousState_pred,  BD_ContinuousState, 0, Errstat, ErrMsg)
      CALL BD_CopyConstrState (BD_ConstraintState_pred,  BD_ConstraintState, 0, Errstat, ErrMsg)
      CALL BD_CopyDiscState   (BD_DiscreteState_pred,    BD_DiscreteState,   0, Errstat, ErrMsg)

      ! update the global time

      t_global = REAL(n_t_global+1,DbKi) * dt_global + t_initial

   ENDDO
CALL CPU_TIME(finish)
!print '("Time = ",f6.3," seconds.")',finish-start
WRITE(*,*) 'Start: ', start
WRITE(*,*) 'Finish: ', finish
WRITE(*,*) 'Time: ', finish-start

!   WRITE(QiHUnit,*) "TOTAL",temp_count

   ! calculate final time normalized rms error


!   CALL WrScr1 ( 'Module 1 Method =  '//TRIM(Num2LStr(Mod1_Parameter%method)))
   CALL WrScr  ( 'pc_max =  '//TRIM(Num2LStr(pc_max)))

   !ALL WrScr1 ( 'normalized rms error of q_1(t) = '//TRIM(Num2LStr( rms_error )) )
   CALL WrScr  ( 'time increment = '//TRIM(Num2LStr(dt_global)) )

!  CALL WrScr1 ( 'log10(dt_global), log10(rms_error): ' )
!  CALL WrScr  ( TRIM(Num2LStr( log10(dt_global) ))//' '//TRIM(Num2LStr( log10(rms_error) )) )


   ! -------------------------------------------------------------------------
   ! Ending of modules
   ! -------------------------------------------------------------------------
   

   CALL BeamDyn_End( BD_Input(1), BD_Parameter, BD_ContinuousState, BD_DiscreteState, &
                    BD_ConstraintState, BD_OtherState, BD_Output(1), ErrStat, ErrMsg )

   DO i = 2, BD_interp_order+1
      CALL BD_DestroyInput(BD_Input(i), ErrStat, ErrMsg )
      CALL BD_DestroyOutput(BD_Output(i), ErrStat, ErrMsg )
   ENDDO

   DEALLOCATE(BD_Input)
   DEALLOCATE(BD_InputTimes)
   DEALLOCATE(BD_Output)
   DEALLOCATE(BD_OutputTimes)
   DEALLOCATE(BD_InitInput%gravity)

   6000 FORMAT (ES12.5,6ES21.12)
   CLOSE (QiDisUnit)
   CLOSE (QiRootUnit)

7000 FORMAT (ES12.5,9ES21.12)
!CLOSE (QiHUnit)

END PROGRAM MAIN



   SUBROUTINE BD_InputSolve( t, u, ut, p, ErrStat, ErrMsg)
 
   USE BeamDyn_SP
   USE BeamDyn_Types

   REAL(DbKi),                     INTENT(IN   ):: t
   TYPE(BD_InputType),             INTENT(INOUT):: u
   REAL(DbKi),                     INTENT(INOUT):: ut
   TYPE(BD_ParameterType),         INTENT(IN   ):: p
   INTEGER(IntKi),                 INTENT(  OUT):: ErrStat     ! Error status of the operation
   CHARACTER(*),                   INTENT(  OUT):: ErrMsg      ! Error message if ErrStat /= ErrID_None
   ! local variables
   INTEGER(IntKi)          :: i                ! do-loop counter
   REAL(ReKi)              :: temp_vec(3)
   REAL(ReKi)              :: temp_vec2(3)
   REAL(ReKi)              :: temp_rr(3)
   REAL(ReKi)              :: temp_pp(3)
   REAL(ReKi)              :: temp_qq(3)
   REAL(ReKi)              :: temp_R(3,3)

   ErrStat = ErrID_None
   ErrMsg  = ''

   temp_rr(:)     = 0.0D0
   temp_pp(:)     = 0.0D0
   temp_qq(:)     = 0.0D0
   temp_R(:,:)    = 0.0D0
   ! gather point forces and line forces

!------------------
!  Rotating beam
!------------------
   ! Point mesh: RootMotion 
   ! Calculate root displacements and rotations
   u%RootMotion%TranslationDisp(:,:)  = 0.0D0
   u%RootMotion%Orientation(:,:,:) = 0.0D0
   temp_pp(3) = 4.0D0*TAN((3.1415926D0*t*1.0D0/3.0D0)/4.0D0)
   CALL CrvMatrixR(temp_pp,temp_R)
   u%RootMotion%Orientation(1:3,1:3,1) = temp_R(1:3,1:3)
   temp_vec(:) = MATMUL(temp_R,p%uuN0(1:3,1))
   u%RootMotion%TranslationDisp(1:3,1)  = temp_vec(1:3) - p%uuN0(1:3,1)
   ! END Calculate root displacements and rotations

   ! Calculate root translational and angular velocities
   u%RootMotion%TranslationVel(:,:) = 0.0D0
   u%RootMotion%RotationVel(:,:) = 0.0D0

   u%RootMotion%RotationVel(3,1) = 3.1415926D+00*1.0D0/3.0D0
   u%RootMotion%TranslationVel(1:3,1) = -1.0D0*MATMUL(Tilde(temp_vec),u%RootMotion%RotationVel(1:3,1))
!   u%RootMotion%RotationVel(2,1) = -3.1415926D+00*1.0D0/3.0D0
!   u%RootMotion%TranslationVel(1:3,1) = -1.0D0*MATMUL(Tilde(temp_vec),u%RootMotion%RotationVel(1:3,1))
   ! END Calculate root translational and angular velocities


   ! Calculate root translational and angular accelerations
   u%RootMotion%TranslationAcc(:,:) = 0.0D0
   u%RootMotion%RotationAcc(:,:) = 0.0D0
   temp_vec2(1:3) = MATMUL(Tilde(u%RootMotion%RotationVel(1:3,1)),temp_vec)
   u%RootMotion%TranslationAcc(1:3,1) = MATMUL(Tilde(u%RootMotion%RotationVel(1:3,1)),temp_vec2) + &
                                       &MATMUL(Tilde(u%RootMotion%RotationAcc(1:3,1)),temp_vec)
   ! END Calculate root translational and angular accelerations
!------------------
! End rotating beam
!------------------

   u%PointLoad%Force(:,:)  = 0.0D0
   u%PointLoad%Moment(:,:) = 0.0D0

   ! LINE2 mesh: DistrLoad
   u%DistrLoad%Force(:,:)  = 0.0D0
   u%DistrLoad%Moment(:,:) = 0.0D0

   ut = t


   END SUBROUTINE BD_InputSolve


   SUBROUTINE BD_InitialCondition(u,p,x,ErrStat,ErrMsg)

   USE BeamDyn_SP
   USE BeamDyn_Types

   ! Module1 Derived-types variables; see Registry_Module1.txt for details

   TYPE(BD_InputType),                     INTENT(IN   ):: u
   TYPE(BD_ParameterType),                 INTENT(IN   ):: p
   TYPE(BD_ContinuousStateType),           INTENT(INOUT):: x
   INTEGER(IntKi),                         INTENT(  OUT):: ErrStat     ! Error status of the operation
   CHARACTER(*),                           INTENT(  OUT):: ErrMsg      ! Error message if ErrStat /= ErrID_None

   INTEGER(IntKi)                                       :: i
   INTEGER(IntKi)                                       :: j
   INTEGER(IntKi)                                       :: temp_id
   INTEGER(IntKi)                                       :: temp_id2

   ErrStat = ErrID_None
   ErrMsg  = ''
   ! Initial displacements and rotations
   x%q(:) = 0.0D0
   ! Initial velocities and angular velocities
!DO i=1,p%node_total
!WRITE(*,*) 'Nodal Position:', i
!WRITE(*,*) p%uuN0((i-1)*6+1:(i-1)*6+3,1)
!WRITE(*,*) p%uuN0((i-1)*6+4:(i-1)*6+6,1)
!ENDDO
!STOP
   DO i=1,p%elem_total
       DO j=1,p%node_elem
           temp_id = (i-1)*p%dof_node*p%node_elem+(j-1)*p%dof_node
           temp_id2= (j-1)*p%dof_node
!           x%dqdt(temp_id+1:temp_id+3) = u%RootMotion%TranslationVel(1:3,1) + &
!                 &MATMUL(Tilde(u%RootMotion%RotationVel(1:3,1)),p%uuN0(temp_id2+1:temp_id2+3,i))
           x%dqdt(temp_id+1:temp_id+3) = MATMUL(Tilde(u%RootMotion%RotationVel(1:3,1)),p%uuN0(temp_id2+1:temp_id2+3,i))
           x%dqdt(temp_id+4:temp_id+6) = u%RootMotion%RotationVel(1:3,1)
       ENDDO
   ENDDO

   END SUBROUTINE BD_InitialCondition
!----------------------------------------------------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------------------------------------------------
