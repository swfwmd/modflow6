module GwfNpfModule
  use KindModule, only: DP, I4B
  use SimVariablesModule, only: errmsg
  use ConstantsModule, only: DZERO, DEM9, DEM8, DEM7, DEM6, DEM2, &
                             DHALF, DP9, DONE, DTWO, &
                             DLNLOW, DLNHIGH, &
                             DHNOFLO, DHDRY, DEM10, &
                             LENMEMPATH, LENVARNAME, LINELENGTH
  use SmoothingModule, only: sQuadraticSaturation, &
                             sQuadraticSaturationDerivative
  use NumericalPackageModule, only: NumericalPackageType
  use GwfNpfOptionsModule, only: GwfNpfOptionsType
  use BaseDisModule, only: DisBaseType
  use GwfIcModule, only: GwfIcType
  use GwfVscModule, only: GwfVscType
  use Xt3dModule, only: Xt3dType
  use InputOutputModule, only: GetUnit, openfile
  use TvkModule, only: TvkType, tvk_cr
  use MemoryManagerModule, only: mem_allocate, mem_reallocate, &
                                 mem_deallocate, mem_setptr, &
                                 mem_reassignptr
  use MatrixBaseModule

  implicit none

  private
  public :: GwfNpfType
  public :: npf_cr
  public :: hcond
  public :: vcond
  public :: condmean
  public :: thksatnm
  public :: hyeff_calc

  type, extends(NumericalPackageType) :: GwfNpfType

    type(GwfIcType), pointer :: ic => null() !< initial conditions object
    type(GwfVscType), pointer :: vsc => null() !< viscosity object
    type(Xt3dType), pointer :: xt3d => null() !< xt3d pointer
    integer(I4B), pointer :: iname => null() !< length of variable names
    character(len=24), dimension(:), pointer :: aname => null() !< variable names
    integer(I4B), dimension(:), pointer, contiguous :: ibound => null() !< pointer to model ibound
    real(DP), dimension(:), pointer, contiguous :: hnew => null() !< pointer to model xnew
    integer(I4B), pointer :: ixt3d => null() !< xt3d flag (0 is off, 1 is lhs, 2 is rhs)
    integer(I4B), pointer :: ixt3drhs => null() !< xt3d rhs flag, xt3d rhs is set active if 1
    integer(I4B), pointer :: iperched => null() !< vertical flow corrections if 1
    integer(I4B), pointer :: ivarcv => null() !< CV is function of water table
    integer(I4B), pointer :: idewatcv => null() !< CV may be a discontinuous function of water table
    integer(I4B), pointer :: ithickstrt => null() !< thickstrt option flag
    integer(I4B), pointer :: igwfnewtonur => null() !< newton head dampening using node bottom option flag
    integer(I4B), pointer :: iusgnrhc => null() !< MODFLOW-USG saturation calculation option flag
    integer(I4B), pointer :: inwtupw => null() !< MODFLOW-NWT upstream weighting option flag
    integer(I4B), pointer :: icalcspdis => null() !< Calculate specific discharge at cell centers
    integer(I4B), pointer :: isavspdis => null() !< Save specific discharge at cell centers
    integer(I4B), pointer :: isavsat => null() !< Save sat to budget file
    real(DP), pointer :: hnoflo => null() !< default is 1.e30
    real(DP), pointer :: satomega => null() !< newton-raphson saturation omega
    integer(I4B), pointer :: irewet => null() !< rewetting (0:off, 1:on)
    integer(I4B), pointer :: iwetit => null() !< wetting interval (default is 1)
    integer(I4B), pointer :: ihdwet => null() !< (0 or not 0)
    integer(I4B), pointer :: icellavg => null() !< harmonic(0), logarithmic(1), or arithmetic thick-log K (2)
    real(DP), pointer :: wetfct => null() !< wetting factor
    real(DP), pointer :: hdry => null() !< default is -1.d30
    integer(I4B), dimension(:), pointer, contiguous :: icelltype => null() !< confined (0) or convertible (1)
    integer(I4B), dimension(:), pointer, contiguous :: ithickstartflag => null() !< array of flags for handling the thickstrt option
    !
    ! K properties
    real(DP), dimension(:), pointer, contiguous :: k11 => null() !< hydraulic conductivity; if anisotropic, then this is Kx prior to rotation
    real(DP), dimension(:), pointer, contiguous :: k22 => null() !< hydraulic conductivity; if specified then this is Ky prior to rotation
    real(DP), dimension(:), pointer, contiguous :: k33 => null() !< hydraulic conductivity; if specified then this is Kz prior to rotation
    real(DP), dimension(:), pointer, contiguous :: k11input => null() !< hydraulic conductivity originally specified by user prior to TVK or VSC modification
    real(DP), dimension(:), pointer, contiguous :: k22input => null() !< hydraulic conductivity originally specified by user prior to TVK or VSC modification
    real(DP), dimension(:), pointer, contiguous :: k33input => null() !< hydraulic conductivity originally specified by user prior to TVK or VSC modification
    integer(I4B), pointer :: iavgkeff => null() !< effective conductivity averaging (0: harmonic, 1: arithmetic)
    integer(I4B), pointer :: ik22 => null() !< flag that k22 is specified
    integer(I4B), pointer :: ik33 => null() !< flag that k33 is specified
    integer(I4B), pointer :: ik22overk => null() !< flag that k22 is specified as anisotropy ratio
    integer(I4B), pointer :: ik33overk => null() !< flag that k33 is specified as anisotropy ratio
    integer(I4B), pointer :: iangle1 => null() !< flag to indicate angle1 was read
    integer(I4B), pointer :: iangle2 => null() !< flag to indicate angle2 was read
    integer(I4B), pointer :: iangle3 => null() !< flag to indicate angle3 was read
    real(DP), dimension(:), pointer, contiguous :: angle1 => null() !< k ellipse rotation in xy plane around z axis (yaw)
    real(DP), dimension(:), pointer, contiguous :: angle2 => null() !< k ellipse rotation up from xy plane around y axis (pitch)
    real(DP), dimension(:), pointer, contiguous :: angle3 => null() !< k tensor rotation around x axis (roll)
    !
    integer(I4B), pointer :: iwetdry => null() !< flag to indicate angle1 was read
    real(DP), dimension(:), pointer, contiguous :: wetdry => null() !< wetdry array
    real(DP), dimension(:), pointer, contiguous :: sat => null() !< saturation (0. to 1.) for each cell
    real(DP), dimension(:), pointer, contiguous :: condsat => null() !< saturated conductance (symmetric array)
    real(DP), pointer :: satmin => null() !< minimum saturated thickness
    integer(I4B), dimension(:), pointer, contiguous :: ibotnode => null() !< bottom node used if igwfnewtonur /= 0
    !
    real(DP), dimension(:, :), pointer, contiguous :: spdis => null() !< specific discharge : qx, qy, qz (nodes, 3)
    integer(I4B), pointer :: nedges => null() !< number of cell edges
    integer(I4B), pointer :: lastedge => null() !< last edge number
    integer(I4B), dimension(:), pointer, contiguous :: nodedge => null() !< array of node numbers that have edges
    integer(I4B), dimension(:), pointer, contiguous :: ihcedge => null() !< edge type (horizontal or vertical)
    real(DP), dimension(:, :), pointer, contiguous :: propsedge => null() !< edge properties (Q, area, nx, ny, distance)
    !
    integer(I4B), pointer :: intvk => null() ! TVK (time-varying K) unit number (0 if unused)
    integer(I4B), pointer :: invsc => null() ! VSC (viscosity) unit number (0 if unused); viscosity leads to time-varying K's
    type(TvkType), pointer :: tvk => null() ! TVK object
    integer(I4B), pointer :: kchangeper => null() ! last stress period in which any node K (or K22, or K33) values were changed (0 if unchanged from start of simulation)
    integer(I4B), pointer :: kchangestp => null() ! last time step in which any node K (or K22, or K33) values were changed (0 if unchanged from start of simulation)
    integer(I4B), dimension(:), pointer, contiguous :: nodekchange => null() ! grid array of flags indicating for each node whether its K (or K22, or K33) value changed (1) at (kchangeper, kchangestp) or not (0)

  contains

    procedure :: npf_df
    procedure :: npf_ac
    procedure :: npf_mc
    procedure :: npf_ar
    procedure :: npf_rp
    procedure :: npf_ad
    procedure :: npf_cf
    procedure :: npf_fc
    procedure :: npf_fn
    procedure :: npf_cq
    procedure :: npf_save_model_flows
    procedure :: npf_nur
    procedure :: npf_print_model_flows
    procedure :: npf_da
    procedure, private :: thksat => sgwf_npf_thksat
    procedure, private :: qcalc => sgwf_npf_qcalc
    procedure, private :: wd => sgwf_npf_wetdry
    procedure, private :: wdmsg => sgwf_npf_wdmsg
    procedure :: allocate_scalars
    procedure, private :: store_original_k_arrays
    procedure, private :: allocate_arrays
    procedure, private :: source_options
    procedure, private :: source_griddata
    procedure, private :: log_options
    procedure, private :: log_griddata
    procedure, private :: set_options
    procedure, private :: check_options
    procedure, private :: prepcheck
    procedure, private :: preprocess_input
    procedure, private :: calc_condsat
    procedure, private :: calc_initial_sat
    procedure, public :: rewet_check
    procedure, public :: hy_eff
    procedure, public :: calc_spdis
    procedure, public :: sav_spdis
    procedure, public :: sav_sat
    procedure, public :: increase_edge_count
    procedure, public :: set_edge_properties
    procedure, public :: calcSatThickness

  end type

contains

  !> @brief Create a new NPF object. Pass a inunit value of 0 if npf data will
  !! initialized from memory
  !<
  subroutine npf_cr(npfobj, name_model, input_mempath, inunit, iout)
    ! -- modules
    use KindModule, only: LGP
    use MemoryManagerExtModule, only: mem_set_value
    ! -- dummy
    type(GwfNpfType), pointer :: npfobj
    character(len=*), intent(in) :: name_model
    character(len=*), intent(in) :: input_mempath
    integer(I4B), intent(in) :: inunit
    integer(I4B), intent(in) :: iout
    ! -- formats
    character(len=*), parameter :: fmtheader = &
      "(1x, /1x, 'NPF -- NODE PROPERTY FLOW PACKAGE, VERSION 1, 3/30/2015', &
       &' INPUT READ FROM MEMPATH: ', A, /)"
    !
    ! -- Create the object
    allocate (npfobj)
    !
    ! -- create name and memory path
    call npfobj%set_names(1, name_model, 'NPF', 'NPF', input_mempath)
    !
    ! -- Allocate scalars
    call npfobj%allocate_scalars()
    !
    ! -- Set variables
    npfobj%inunit = inunit
    npfobj%iout = iout
    !
    ! -- check if npf is enabled
    if (inunit > 0) then
      !
      ! -- Print a message identifying the node property flow package.
      write (iout, fmtheader) input_mempath
    end if
    !
    ! -- Return
    return
  end subroutine npf_cr

  !> @brief Define the NPF package instance
  !!
  !! This is a hybrid routine: it either reads the options for this package
  !! from the input file, or the optional argument @param npf_options
  !! should be passed. A consistency check is performed, and finally
  !! xt3d_df is called, when enabled.
  !<
  subroutine npf_df(this, dis, xt3d, ingnc, invsc, npf_options)
    ! -- modules
    use SimModule, only: store_error
    use Xt3dModule, only: xt3d_cr
    ! -- dummy
    class(GwfNpftype) :: this !< instance of the NPF package
    class(DisBaseType), pointer, intent(inout) :: dis !< the pointer to the discretization
    type(Xt3dType), pointer :: xt3d !< the pointer to the XT3D 'package'
    integer(I4B), intent(in) :: ingnc !< ghostnodes enabled? (>0 means yes)
    integer(I4B), intent(in) :: invsc !< viscosity enabled? (>0 means yes)
    type(GwfNpfOptionsType), optional, intent(in) :: npf_options !< the optional options, for when not constructing from file
    !
    ! -- Set a pointer to dis
    this%dis => dis
    !
    ! -- Set flag signifying whether vsc is active
    if (invsc > 0) this%invsc = invsc
    !
    if (.not. present(npf_options)) then
      !
      ! -- source options
      call this%source_options()
      !
      ! -- allocate arrays
      call this%allocate_arrays(this%dis%nodes, this%dis%njas)
      !
      ! -- source griddata, set, and convert/check the input
      call this%source_griddata()
      call this%prepcheck()
    else
      call this%set_options(npf_options)
      !
      ! -- allocate arrays
      call this%allocate_arrays(this%dis%nodes, this%dis%njas)
    end if
    !
    call this%check_options()
    !
    ! -- Save pointer to xt3d object
    this%xt3d => xt3d
    if (this%ixt3d /= 0) xt3d%ixt3d = this%ixt3d
    call this%xt3d%xt3d_df(dis)
    !
    ! -- Ensure GNC and XT3D are not both on at the same time
    if (this%ixt3d /= 0 .and. ingnc > 0) then
      call store_error('Error in model '//trim(this%name_model)// &
                       '.  The XT3D option cannot be used with the GNC &
                       &Package.', terminate=.TRUE.)
    end if
    !
    ! -- Return
    return
  end subroutine npf_df

  !> @brief Add connections for extended neighbors to the sparse matrix
  !<
  subroutine npf_ac(this, moffset, sparse)
    ! -- modules
    use SparseModule, only: sparsematrix
    ! -- dummy
    class(GwfNpftype) :: this
    integer(I4B), intent(in) :: moffset
    type(sparsematrix), intent(inout) :: sparse
    !
    ! -- Add extended neighbors (neighbors of neighbors)
    if (this%ixt3d /= 0) call this%xt3d%xt3d_ac(moffset, sparse)
    !
    ! -- Return
    return
  end subroutine npf_ac

  !> @brief Map connections and construct iax, jax, and idxglox
  !<
  subroutine npf_mc(this, moffset, matrix_sln)
    ! -- dummy
    class(GwfNpftype) :: this
    integer(I4B), intent(in) :: moffset
    class(MatrixBaseType), pointer :: matrix_sln
    !
    if (this%ixt3d /= 0) call this%xt3d%xt3d_mc(moffset, matrix_sln)
    !
    ! -- Return
    return
  end subroutine npf_mc

  !> @brief Allocate and read this NPF instance
  !!
  !! Allocate remaining package arrays, preprocess the input data and
  !! call *_ar on xt3d, when active.
  !<
  subroutine npf_ar(this, ic, vsc, ibound, hnew)
    ! -- modules
    use MemoryManagerModule, only: mem_reallocate
    ! -- dummy
    class(GwfNpftype) :: this !< instance of the NPF package
    type(GwfIcType), pointer, intent(in) :: ic !< initial conditions
    type(GwfVscType), pointer, intent(in) :: vsc !< viscosity package
    integer(I4B), dimension(:), pointer, contiguous, intent(inout) :: ibound !< model ibound array
    real(DP), dimension(:), pointer, contiguous, intent(inout) :: hnew !< pointer to model head array
    ! -- local
    integer(I4B) :: n
    !
    ! -- Store pointers to arguments that were passed in
    this%ic => ic
    this%ibound => ibound
    this%hnew => hnew
    !
    if (this%icalcspdis == 1) then
      call mem_reallocate(this%spdis, 3, this%dis%nodes, 'SPDIS', this%memoryPath)
      call mem_reallocate(this%nodedge, this%nedges, 'NODEDGE', this%memoryPath)
      call mem_reallocate(this%ihcedge, this%nedges, 'IHCEDGE', this%memoryPath)
      call mem_reallocate(this%propsedge, 5, this%nedges, 'PROPSEDGE', &
                          this%memoryPath)
      do n = 1, this%dis%nodes
        this%spdis(:, n) = DZERO
      end do
    end if
    !
    ! -- Store pointer to VSC if active
    if (this%invsc /= 0) then
      this%vsc => vsc
    end if
    !
    ! -- allocate arrays to store original user input in case TVK/VSC modify them
    if (this%invsc > 0) then
      !
      ! -- Reallocate arrays that store user-input values.
      call mem_reallocate(this%k11input, this%dis%nodes, 'K11INPUT', &
                          this%memoryPath)
      call mem_reallocate(this%k22input, this%dis%nodes, 'K22INPUT', &
                          this%memoryPath)
      call mem_reallocate(this%k33input, this%dis%nodes, 'K33INPUT', &
                          this%memoryPath)
      ! Allocate arrays that will store the original K values.  When VSC active,
      ! the current Kxx arrays carry the viscosity-adjusted K values.
      ! This approach leverages existing functionality that makes use of K.
      call this%store_original_k_arrays(this%dis%nodes, this%dis%njas)
    end if
    !
    ! -- preprocess data
    call this%preprocess_input()
    !
    ! -- xt3d
    if (this%ixt3d /= 0) then
      call this%xt3d%xt3d_ar(ibound, this%k11, this%ik33, this%k33, &
                             this%sat, this%ik22, this%k22, &
                             this%iangle1, this%iangle2, this%iangle3, &
                             this%angle1, this%angle2, this%angle3, &
                             this%inewton, this%icelltype)
    end if
    !
    ! -- TVK
    if (this%intvk /= 0) then
      call this%tvk%ar(this%dis)
    end if
    !
    ! -- Return
    return
  end subroutine npf_ar

  !> @brief Read and prepare method for package
  !!
  !! Read and prepare NPF stress period data.
  !<
  subroutine npf_rp(this)
    implicit none
    ! -- dummy
    class(GwfNpfType) :: this
    !
    ! -- TVK
    if (this%intvk /= 0) then
      call this%tvk%rp()
    end if
    !
    ! -- Return
    return
  end subroutine npf_rp

  !> @brief Advance
  !!
  !! Sets hold (head old) to bot whenever a wettable cell is dry
  !<
  subroutine npf_ad(this, nodes, hold, hnew, irestore)
    ! -- modules
    use TdisModule, only: kper, kstp
    !
    implicit none
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: nodes
    real(DP), dimension(nodes), intent(inout) :: hold
    real(DP), dimension(nodes), intent(inout) :: hnew
    integer(I4B), intent(in) :: irestore
    ! -- local
    integer(I4B) :: n
    !
    ! -- loop through all cells and set hold=bot if wettable cell is dry
    if (this%irewet > 0) then
      do n = 1, this%dis%nodes
        if (this%wetdry(n) == DZERO) cycle
        if (this%ibound(n) /= 0) cycle
        hold(n) = this%dis%bot(n)
      end do
      !
      ! -- if restore state, then set hnew to DRY if it is a dry wettable cell
      do n = 1, this%dis%nodes
        if (this%wetdry(n) == DZERO) cycle
        if (this%ibound(n) /= 0) cycle
        hnew(n) = DHDRY
      end do
    end if
    !
    ! -- TVK
    if (this%intvk /= 0) then
      call this%tvk%ad()
    end if
    !
    ! -- VSC
    ! -- Hit the TVK-updated K's with VSC correction before calling/updating condsat
    if (this%invsc /= 0) then
      call this%vsc%update_k_with_vsc()
    end if
    !
    ! -- If any K values have changed, we need to update CONDSAT or XT3D arrays
    if (this%kchangeper == kper .and. this%kchangestp == kstp) then
      if (this%ixt3d == 0) then
        !
        ! -- Update the saturated conductance for all connections
        ! -- of the affected nodes
        do n = 1, this%dis%nodes
          if (this%nodekchange(n) == 1) then
            call this%calc_condsat(n, .false.)
          end if
        end do
      else
        !
        ! -- Recompute XT3D coefficients for permanently confined connections
        if (this%xt3d%lamatsaved .and. .not. this%xt3d%ldispersion) then
          call this%xt3d%xt3d_fcpc(this%dis%nodes, .true.)
        end if
      end if
    end if
    !
    ! -- Return
    return
  end subroutine npf_ad

  !> @brief Routines associated fill coefficients
  !<
  subroutine npf_cf(this, kiter, nodes, hnew)
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B) :: kiter
    integer(I4B), intent(in) :: nodes
    real(DP), intent(inout), dimension(nodes) :: hnew
    ! -- local
    integer(I4B) :: n
    real(DP) :: satn
    !
    ! -- Perform wetting and drying
    if (this%inewton /= 1) then
      call this%wd(kiter, hnew)
    end if
    !
    ! -- Calculate saturation for convertible cells
    do n = 1, this%dis%nodes
      if (this%icelltype(n) /= 0) then
        if (this%ibound(n) == 0) then
          satn = DZERO
        else
          call this%thksat(n, hnew(n), satn)
        end if
        this%sat(n) = satn
      end if
    end do
    !
    ! -- Return
    return
  end subroutine npf_cf

  !> @brief Formulate coefficients
  !<
  subroutine npf_fc(this, kiter, matrix_sln, idxglo, rhs, hnew)
    ! -- modules
    use ConstantsModule, only: DONE
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B) :: kiter
    class(MatrixBaseType), pointer :: matrix_sln
    integer(I4B), intent(in), dimension(:) :: idxglo
    real(DP), intent(inout), dimension(:) :: rhs
    real(DP), intent(inout), dimension(:) :: hnew
    ! -- local
    integer(I4B) :: n, m, ii, idiag, ihc
    integer(I4B) :: isymcon, idiagm
    real(DP) :: hyn, hym
    real(DP) :: cond
    !
    ! -- Calculate conductance and put into amat
    !
    if (this%ixt3d /= 0) then
      call this%xt3d%xt3d_fc(kiter, matrix_sln, idxglo, rhs, hnew)
    else
      !
      do n = 1, this%dis%nodes
        do ii = this%dis%con%ia(n) + 1, this%dis%con%ia(n + 1) - 1
          if (this%dis%con%mask(ii) == 0) cycle

          m = this%dis%con%ja(ii)
          !
          ! -- Calculate conductance only for upper triangle but insert into
          !    upper and lower parts of amat.
          if (m < n) cycle
          ihc = this%dis%con%ihc(this%dis%con%jas(ii))
          hyn = this%hy_eff(n, m, ihc, ipos=ii)
          hym = this%hy_eff(m, n, ihc, ipos=ii)
          !
          ! -- Vertical connection
          if (ihc == 0) then
            !
            ! -- Calculate vertical conductance
            cond = vcond(this%ibound(n), this%ibound(m), &
                         this%icelltype(n), this%icelltype(m), this%inewton, &
                         this%ivarcv, this%idewatcv, &
                         this%condsat(this%dis%con%jas(ii)), hnew(n), hnew(m), &
                         hyn, hym, &
                         this%sat(n), this%sat(m), &
                         this%dis%top(n), this%dis%top(m), &
                         this%dis%bot(n), this%dis%bot(m), &
                         this%dis%con%hwva(this%dis%con%jas(ii)))
            !
            ! -- Vertical flow for perched conditions
            if (this%iperched /= 0) then
              if (this%icelltype(m) /= 0) then
                if (hnew(m) < this%dis%top(m)) then
                  !
                  ! -- Fill row n
                  idiag = this%dis%con%ia(n)
                  rhs(n) = rhs(n) - cond * this%dis%bot(n)
                  call matrix_sln%add_value_pos(idxglo(idiag), -cond)
                  !
                  ! -- Fill row m
                  isymcon = this%dis%con%isym(ii)
                  call matrix_sln%add_value_pos(idxglo(isymcon), cond)
                  rhs(m) = rhs(m) + cond * this%dis%bot(n)
                  !
                  ! -- cycle the connection loop
                  cycle
                end if
              end if
            end if
            !
          else
            !
            ! -- Horizontal conductance
            cond = hcond(this%ibound(n), this%ibound(m), &
                         this%icelltype(n), this%icelltype(m), &
                         this%inewton, this%inewton, &
                         this%dis%con%ihc(this%dis%con%jas(ii)), &
                         this%icellavg, this%iusgnrhc, this%inwtupw, &
                         this%condsat(this%dis%con%jas(ii)), &
                         hnew(n), hnew(m), this%sat(n), this%sat(m), hyn, hym, &
                         this%dis%top(n), this%dis%top(m), &
                         this%dis%bot(n), this%dis%bot(m), &
                         this%dis%con%cl1(this%dis%con%jas(ii)), &
                         this%dis%con%cl2(this%dis%con%jas(ii)), &
                         this%dis%con%hwva(this%dis%con%jas(ii)), &
                         this%satomega, this%satmin)
          end if
          !
          ! -- Fill row n
          idiag = this%dis%con%ia(n)
          call matrix_sln%add_value_pos(idxglo(ii), cond)
          call matrix_sln%add_value_pos(idxglo(idiag), -cond)
          !
          ! -- Fill row m
          isymcon = this%dis%con%isym(ii)
          idiagm = this%dis%con%ia(m)
          call matrix_sln%add_value_pos(idxglo(isymcon), cond)
          call matrix_sln%add_value_pos(idxglo(idiagm), -cond)
        end do
      end do
      !
    end if
    !
    ! -- Return
    return
  end subroutine npf_fc

  !> @brief Fill newton terms
  !<
  subroutine npf_fn(this, kiter, matrix_sln, idxglo, rhs, hnew)
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B) :: kiter
    class(MatrixBaseType), pointer :: matrix_sln
    integer(I4B), intent(in), dimension(:) :: idxglo
    real(DP), intent(inout), dimension(:) :: rhs
    real(DP), intent(inout), dimension(:) :: hnew
    ! -- local
    integer(I4B) :: nodes, nja
    integer(I4B) :: n, m, ii, idiag
    integer(I4B) :: isymcon, idiagm
    integer(I4B) :: iups
    integer(I4B) :: idn
    real(DP) :: cond
    real(DP) :: consterm
    real(DP) :: filledterm
    real(DP) :: derv
    real(DP) :: hds
    real(DP) :: term
    real(DP) :: afac
    real(DP) :: topup
    real(DP) :: botup
    real(DP) :: topdn
    real(DP) :: botdn
    !
    ! -- add newton terms to solution matrix
    nodes = this%dis%nodes
    nja = this%dis%con%nja
    if (this%ixt3d /= 0) then
      call this%xt3d%xt3d_fn(kiter, nodes, nja, matrix_sln, idxglo, rhs, hnew)
    else
      !
      do n = 1, nodes
        idiag = this%dis%con%ia(n)
        do ii = this%dis%con%ia(n) + 1, this%dis%con%ia(n + 1) - 1
          if (this%dis%con%mask(ii) == 0) cycle

          m = this%dis%con%ja(ii)
          isymcon = this%dis%con%isym(ii)
          ! work on upper triangle
          if (m < n) cycle
          if (this%dis%con%ihc(this%dis%con%jas(ii)) == 0 .and. &
              this%ivarcv == 0) then
            !call this%vcond(n,m,hnew(n),hnew(m),ii,cond)
            ! do nothing
          else
            ! determine upstream node
            iups = m
            if (hnew(m) < hnew(n)) iups = n
            idn = n
            if (iups == n) idn = m
            !
            ! -- no newton terms if upstream cell is confined
            if (this%icelltype(iups) == 0) cycle
            !
            ! -- Set the upstream top and bot, and then recalculate for a
            !    vertically staggered horizontal connection
            topup = this%dis%top(iups)
            botup = this%dis%bot(iups)
            if (this%dis%con%ihc(this%dis%con%jas(ii)) == 2) then
              topup = min(this%dis%top(n), this%dis%top(m))
              botup = max(this%dis%bot(n), this%dis%bot(m))
            end if
            !
            ! get saturated conductivity for derivative
            cond = this%condsat(this%dis%con%jas(ii))
            !
            ! -- if using MODFLOW-NWT upstream weighting option apply
            !    factor to remove average thickness
            if (this%inwtupw /= 0) then
              topdn = this%dis%top(idn)
              botdn = this%dis%bot(idn)
              afac = DTWO / (DONE + (topdn - botdn) / (topup - botup))
              cond = cond * afac
            end if
            !
            ! compute additional term
            consterm = -cond * (hnew(iups) - hnew(idn)) !needs to use hwadi instead of hnew(idn)
            !filledterm = cond
            filledterm = matrix_sln%get_value_pos(idxglo(ii))
            derv = sQuadraticSaturationDerivative(topup, botup, hnew(iups), &
                                                  this%satomega, this%satmin)
            idiagm = this%dis%con%ia(m)
            ! fill jacobian for n being the upstream node
            if (iups == n) then
              hds = hnew(m)
              !isymcon =  this%dis%con%isym(ii)
              term = consterm * derv
              rhs(n) = rhs(n) + term * hnew(n) !+ amat(idxglo(isymcon)) * (dwadi * hds - hds) !need to add dwadi
              rhs(m) = rhs(m) - term * hnew(n) !- amat(idxglo(isymcon)) * (dwadi * hds - hds) !need to add dwadi
              ! fill in row of n
              call matrix_sln%add_value_pos(idxglo(idiag), term)
              ! fill newton term in off diagonal if active cell
              if (this%ibound(n) > 0) then
                filledterm = matrix_sln%get_value_pos(idxglo(ii))
                call matrix_sln%set_value_pos(idxglo(ii), filledterm) !* dwadi !need to add dwadi
              end if
              !fill row of m
              filledterm = matrix_sln%get_value_pos(idxglo(idiagm))
              call matrix_sln%set_value_pos(idxglo(idiagm), filledterm) !- filledterm * (dwadi - DONE) !need to add dwadi
              ! fill newton term in off diagonal if active cell
              if (this%ibound(m) > 0) then
                call matrix_sln%add_value_pos(idxglo(isymcon), -term)
              end if
              ! fill jacobian for m being the upstream node
            else
              hds = hnew(n)
              term = -consterm * derv
              rhs(n) = rhs(n) + term * hnew(m) !+ amat(idxglo(ii)) * (dwadi * hds - hds) !need to add dwadi
              rhs(m) = rhs(m) - term * hnew(m) !- amat(idxglo(ii)) * (dwadi * hds - hds) !need to add dwadi
              ! fill in row of n
              filledterm = matrix_sln%get_value_pos(idxglo(idiag))
              call matrix_sln%set_value_pos(idxglo(idiag), filledterm) !- filledterm * (dwadi - DONE) !need to add dwadi
              ! fill newton term in off diagonal if active cell
              if (this%ibound(n) > 0) then
                call matrix_sln%add_value_pos(idxglo(ii), term)
              end if
              !fill row of m
              call matrix_sln%add_value_pos(idxglo(idiagm), -term)
              ! fill newton term in off diagonal if active cell
              if (this%ibound(m) > 0) then
                filledterm = matrix_sln%get_value_pos(idxglo(isymcon))
                call matrix_sln%set_value_pos(idxglo(isymcon), filledterm) !* dwadi  !need to add dwadi
              end if
            end if
          end if

        end do
      end do
      !
    end if
    !
    ! -- Return
    return
  end subroutine npf_fn

  !> @brief Under-relaxation
  !!
  !! Under-relaxation of Groundwater Flow Model Heads for current outer
  !! iteration using the cell bottoms at the bottom of the model
  !<
  subroutine npf_nur(this, neqmod, x, xtemp, dx, inewtonur, dxmax, locmax)
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: neqmod
    real(DP), dimension(neqmod), intent(inout) :: x
    real(DP), dimension(neqmod), intent(in) :: xtemp
    real(DP), dimension(neqmod), intent(inout) :: dx
    integer(I4B), intent(inout) :: inewtonur
    real(DP), intent(inout) :: dxmax
    integer(I4B), intent(inout) :: locmax
    ! -- local
    integer(I4B) :: n
    real(DP) :: botm
    real(DP) :: xx
    real(DP) :: dxx
    !
    ! -- Newton-Raphson under-relaxation
    do n = 1, this%dis%nodes
      if (this%ibound(n) < 1) cycle
      if (this%icelltype(n) > 0) then
        botm = this%dis%bot(this%ibotnode(n))
        ! -- only apply Newton-Raphson under-relaxation if
        !    solution head is below the bottom of the model
        if (x(n) < botm) then
          inewtonur = 1
          xx = xtemp(n) * (DONE - DP9) + botm * DP9
          dxx = x(n) - xx
          if (abs(dxx) > abs(dxmax)) then
            locmax = n
            dxmax = dxx
          end if
          x(n) = xx
          dx(n) = DZERO
        end if
      end if
    end do
    !
    ! -- Return
    return
  end subroutine npf_nur

  !> @brief Calculate flowja
  !<
  subroutine npf_cq(this, hnew, flowja)
    ! -- dummy
    class(GwfNpfType) :: this
    real(DP), intent(inout), dimension(:) :: hnew
    real(DP), intent(inout), dimension(:) :: flowja
    ! -- local
    integer(I4B) :: n, ipos, m
    real(DP) :: qnm
    !
    ! -- Calculate the flow across each cell face and store in flowja
    !
    if (this%ixt3d /= 0) then
      call this%xt3d%xt3d_flowja(hnew, flowja)
    else
      !
      do n = 1, this%dis%nodes
        do ipos = this%dis%con%ia(n) + 1, this%dis%con%ia(n + 1) - 1
          m = this%dis%con%ja(ipos)
          if (m < n) cycle
          call this%qcalc(n, m, hnew(n), hnew(m), ipos, qnm)
          flowja(ipos) = qnm
          flowja(this%dis%con%isym(ipos)) = -qnm
        end do
      end do
      !
    end if
    !
    ! -- Return
    return
  end subroutine npf_cq

  !> @brief Fractional cell saturation
  !<
  subroutine sgwf_npf_thksat(this, n, hn, thksat)
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: n
    real(DP), intent(in) :: hn
    real(DP), intent(inout) :: thksat
    !
    ! -- Standard Formulation
    if (hn >= this%dis%top(n)) then
      thksat = DONE
    else
      thksat = (hn - this%dis%bot(n)) / (this%dis%top(n) - this%dis%bot(n))
    end if
    !
    ! -- Newton-Raphson Formulation
    if (this%inewton /= 0) then
      thksat = sQuadraticSaturation(this%dis%top(n), this%dis%bot(n), hn, &
                                    this%satomega, this%satmin)
      !if (thksat < this%satmin) thksat = this%satmin
    end if
    !
    ! -- Return
    return
  end subroutine sgwf_npf_thksat

  !> @brief Flow between two cells
  !<
  subroutine sgwf_npf_qcalc(this, n, m, hn, hm, icon, qnm)
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: n
    integer(I4B), intent(in) :: m
    real(DP), intent(in) :: hn
    real(DP), intent(in) :: hm
    integer(I4B), intent(in) :: icon
    real(DP), intent(inout) :: qnm
    ! -- local
    real(DP) :: hyn, hym
    real(DP) :: condnm
    real(DP) :: hntemp, hmtemp
    integer(I4B) :: ihc
    !
    ! -- Initialize
    ihc = this%dis%con%ihc(this%dis%con%jas(icon))
    hyn = this%hy_eff(n, m, ihc, ipos=icon)
    hym = this%hy_eff(m, n, ihc, ipos=icon)
    !
    ! -- Calculate conductance
    if (ihc == 0) then
      condnm = vcond(this%ibound(n), this%ibound(m), &
                     this%icelltype(n), this%icelltype(m), this%inewton, &
                     this%ivarcv, this%idewatcv, &
                     this%condsat(this%dis%con%jas(icon)), hn, hm, &
                     hyn, hym, &
                     this%sat(n), this%sat(m), &
                     this%dis%top(n), this%dis%top(m), &
                     this%dis%bot(n), this%dis%bot(m), &
                     this%dis%con%hwva(this%dis%con%jas(icon)))
    else
      condnm = hcond(this%ibound(n), this%ibound(m), &
                     this%icelltype(n), this%icelltype(m), &
                     this%inewton, this%inewton, &
                     this%dis%con%ihc(this%dis%con%jas(icon)), &
                     this%icellavg, this%iusgnrhc, this%inwtupw, &
                     this%condsat(this%dis%con%jas(icon)), &
                     hn, hm, this%sat(n), this%sat(m), hyn, hym, &
                     this%dis%top(n), this%dis%top(m), &
                     this%dis%bot(n), this%dis%bot(m), &
                     this%dis%con%cl1(this%dis%con%jas(icon)), &
                     this%dis%con%cl2(this%dis%con%jas(icon)), &
                     this%dis%con%hwva(this%dis%con%jas(icon)), &
                     this%satomega, this%satmin)
    end if
    !
    ! -- Initialize hntemp and hmtemp
    hntemp = hn
    hmtemp = hm
    !
    ! -- Check and adjust for dewatered conditions
    if (this%iperched /= 0) then
      if (this%dis%con%ihc(this%dis%con%jas(icon)) == 0) then
        if (n > m) then
          if (this%icelltype(n) /= 0) then
            if (hn < this%dis%top(n)) hntemp = this%dis%bot(m)
          end if
        else
          if (this%icelltype(m) /= 0) then
            if (hm < this%dis%top(m)) hmtemp = this%dis%bot(n)
          end if
        end if
      end if
    end if
    !
    ! -- Calculate flow positive into cell n
    qnm = condnm * (hmtemp - hntemp)
    !
    ! -- Return
    return
  end subroutine sgwf_npf_qcalc

  !> @brief Record flowja and calculate specific discharge if requested
  !<
  subroutine npf_save_model_flows(this, flowja, icbcfl, icbcun)
    ! -- dummy
    class(GwfNpfType) :: this
    real(DP), dimension(:), intent(in) :: flowja
    integer(I4B), intent(in) :: icbcfl
    integer(I4B), intent(in) :: icbcun
    ! -- local
    integer(I4B) :: ibinun
    !
    ! -- Set unit number for binary output
    if (this%ipakcb < 0) then
      ibinun = icbcun
    elseif (this%ipakcb == 0) then
      ibinun = 0
    else
      ibinun = this%ipakcb
    end if
    if (icbcfl == 0) ibinun = 0
    !
    ! -- Write the face flows if requested
    if (ibinun /= 0) then
      call this%dis%record_connection_array(flowja, ibinun, this%iout)
    end if
    !
    ! -- Calculate specific discharge at cell centers and write, if requested
    if (this%isavspdis /= 0) then
      if (ibinun /= 0) call this%sav_spdis(ibinun)
    end if
    !
    ! -- Save saturation, if requested
    if (this%isavsat /= 0) then
      if (ibinun /= 0) call this%sav_sat(ibinun)
    end if
    !
    ! -- Return
    return
  end subroutine npf_save_model_flows

  !> @brief Print budget
  !<
  subroutine npf_print_model_flows(this, ibudfl, flowja)
    ! -- modules
    use TdisModule, only: kper, kstp
    use ConstantsModule, only: LENBIGLINE
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: ibudfl
    real(DP), intent(inout), dimension(:) :: flowja
    ! -- local
    character(len=LENBIGLINE) :: line
    character(len=30) :: tempstr
    integer(I4B) :: n, ipos, m
    real(DP) :: qnm
    ! -- formats
    character(len=*), parameter :: fmtiprflow = &
      &"(/,4x,'CALCULATED INTERCELL FLOW FOR PERIOD ', i0, ' STEP ', i0)"
    !
    ! -- Write flowja to list file if requested
    if (ibudfl /= 0 .and. this%iprflow > 0) then
      write (this%iout, fmtiprflow) kper, kstp
      do n = 1, this%dis%nodes
        line = ''
        call this%dis%noder_to_string(n, tempstr)
        line = trim(tempstr)//':'
        do ipos = this%dis%con%ia(n) + 1, this%dis%con%ia(n + 1) - 1
          m = this%dis%con%ja(ipos)
          call this%dis%noder_to_string(m, tempstr)
          line = trim(line)//' '//trim(tempstr)
          qnm = flowja(ipos)
          write (tempstr, '(1pg15.6)') qnm
          line = trim(line)//' '//trim(adjustl(tempstr))
        end do
        write (this%iout, '(a)') trim(line)
      end do
    end if
    !
    ! -- Return
    return
  end subroutine npf_print_model_flows

  !> @brief Deallocate variables
  !<
  subroutine npf_da(this)
    ! -- modules
    use MemoryManagerExtModule, only: memorylist_remove
    use SimVariablesModule, only: idm_context
    ! -- dummy
    class(GwfNpftype) :: this
    !
    ! -- Deallocate input memory
    call memorylist_remove(this%name_model, 'NPF', idm_context)
    !
    ! -- TVK
    if (this%intvk /= 0) then
      call this%tvk%da()
      deallocate (this%tvk)
    end if
    !
    ! -- VSC
    if (this%invsc /= 0) then
      nullify (this%vsc)
    end if
    !
    ! -- Strings
    !
    ! -- Scalars
    call mem_deallocate(this%iname)
    call mem_deallocate(this%ixt3d)
    call mem_deallocate(this%ixt3drhs)
    call mem_deallocate(this%satomega)
    call mem_deallocate(this%hnoflo)
    call mem_deallocate(this%hdry)
    call mem_deallocate(this%icellavg)
    call mem_deallocate(this%iavgkeff)
    call mem_deallocate(this%ik22)
    call mem_deallocate(this%ik33)
    call mem_deallocate(this%iperched)
    call mem_deallocate(this%ivarcv)
    call mem_deallocate(this%idewatcv)
    call mem_deallocate(this%ithickstrt)
    call mem_deallocate(this%iusgnrhc)
    call mem_deallocate(this%inwtupw)
    call mem_deallocate(this%isavspdis)
    call mem_deallocate(this%isavsat)
    call mem_deallocate(this%icalcspdis)
    call mem_deallocate(this%irewet)
    call mem_deallocate(this%wetfct)
    call mem_deallocate(this%iwetit)
    call mem_deallocate(this%ihdwet)
    call mem_deallocate(this%satmin)
    call mem_deallocate(this%ibotnode)
    call mem_deallocate(this%iwetdry)
    call mem_deallocate(this%iangle1)
    call mem_deallocate(this%iangle2)
    call mem_deallocate(this%iangle3)
    call mem_deallocate(this%nedges)
    call mem_deallocate(this%lastedge)
    call mem_deallocate(this%ik22overk)
    call mem_deallocate(this%ik33overk)
    call mem_deallocate(this%intvk)
    call mem_deallocate(this%invsc)
    call mem_deallocate(this%kchangeper)
    call mem_deallocate(this%kchangestp)
    !
    ! -- Deallocate arrays
    deallocate (this%aname)
    call mem_deallocate(this%ithickstartflag)
    call mem_deallocate(this%icelltype)
    call mem_deallocate(this%k11)
    call mem_deallocate(this%k22)
    call mem_deallocate(this%k33)
    call mem_deallocate(this%k11input)
    call mem_deallocate(this%k22input)
    call mem_deallocate(this%k33input)
    call mem_deallocate(this%sat)
    call mem_deallocate(this%condsat)
    call mem_deallocate(this%wetdry)
    call mem_deallocate(this%angle1)
    call mem_deallocate(this%angle2)
    call mem_deallocate(this%angle3)
    call mem_deallocate(this%nodedge)
    call mem_deallocate(this%ihcedge)
    call mem_deallocate(this%propsedge)
    call mem_deallocate(this%spdis)
    call mem_deallocate(this%nodekchange)
    !
    ! -- deallocate parent
    call this%NumericalPackageType%da()
    !
    ! -- Return
    return
  end subroutine npf_da

  !> @ brief Allocate scalars
  !!
  !! Allocate and initialize scalars for the VSC package. The base model
  !! allocate scalars method is also called.
  !<
  subroutine allocate_scalars(this)
    ! -- modules
    use MemoryHelperModule, only: create_mem_path
    ! -- dummy
    class(GwfNpftype) :: this
    !
    ! -- allocate scalars in NumericalPackageType
    call this%NumericalPackageType%allocate_scalars()
    !
    ! -- Allocate scalars
    call mem_allocate(this%iname, 'INAME', this%memoryPath)
    call mem_allocate(this%ixt3d, 'IXT3D', this%memoryPath)
    call mem_allocate(this%ixt3drhs, 'IXT3DRHS', this%memoryPath)
    call mem_allocate(this%satomega, 'SATOMEGA', this%memoryPath)
    call mem_allocate(this%hnoflo, 'HNOFLO', this%memoryPath)
    call mem_allocate(this%hdry, 'HDRY', this%memoryPath)
    call mem_allocate(this%icellavg, 'ICELLAVG', this%memoryPath)
    call mem_allocate(this%iavgkeff, 'IAVGKEFF', this%memoryPath)
    call mem_allocate(this%ik22, 'IK22', this%memoryPath)
    call mem_allocate(this%ik33, 'IK33', this%memoryPath)
    call mem_allocate(this%ik22overk, 'IK22OVERK', this%memoryPath)
    call mem_allocate(this%ik33overk, 'IK33OVERK', this%memoryPath)
    call mem_allocate(this%iperched, 'IPERCHED', this%memoryPath)
    call mem_allocate(this%ivarcv, 'IVARCV', this%memoryPath)
    call mem_allocate(this%idewatcv, 'IDEWATCV', this%memoryPath)
    call mem_allocate(this%ithickstrt, 'ITHICKSTRT', this%memoryPath)
    call mem_allocate(this%iusgnrhc, 'IUSGNRHC', this%memoryPath)
    call mem_allocate(this%inwtupw, 'INWTUPW', this%memoryPath)
    call mem_allocate(this%icalcspdis, 'ICALCSPDIS', this%memoryPath)
    call mem_allocate(this%isavspdis, 'ISAVSPDIS', this%memoryPath)
    call mem_allocate(this%isavsat, 'ISAVSAT', this%memoryPath)
    call mem_allocate(this%irewet, 'IREWET', this%memoryPath)
    call mem_allocate(this%wetfct, 'WETFCT', this%memoryPath)
    call mem_allocate(this%iwetit, 'IWETIT', this%memoryPath)
    call mem_allocate(this%ihdwet, 'IHDWET', this%memoryPath)
    call mem_allocate(this%satmin, 'SATMIN', this%memoryPath)
    call mem_allocate(this%iangle1, 'IANGLE1', this%memoryPath)
    call mem_allocate(this%iangle2, 'IANGLE2', this%memoryPath)
    call mem_allocate(this%iangle3, 'IANGLE3', this%memoryPath)
    call mem_allocate(this%iwetdry, 'IWETDRY', this%memoryPath)
    call mem_allocate(this%nedges, 'NEDGES', this%memoryPath)
    call mem_allocate(this%lastedge, 'LASTEDGE', this%memoryPath)
    call mem_allocate(this%intvk, 'INTVK', this%memoryPath)
    call mem_allocate(this%invsc, 'INVSC', this%memoryPath)
    call mem_allocate(this%kchangeper, 'KCHANGEPER', this%memoryPath)
    call mem_allocate(this%kchangestp, 'KCHANGESTP', this%memoryPath)
    !
    ! -- set pointer to inewtonur
    call mem_setptr(this%igwfnewtonur, 'INEWTONUR', &
                    create_mem_path(this%name_model))
    !
    ! -- Initialize value
    this%iname = 8
    this%ixt3d = 0
    this%ixt3drhs = 0
    this%satomega = DZERO
    this%hnoflo = DHNOFLO !1.d30
    this%hdry = DHDRY !-1.d30
    this%icellavg = 0
    this%iavgkeff = 0
    this%ik22 = 0
    this%ik33 = 0
    this%ik22overk = 0
    this%ik33overk = 0
    this%iperched = 0
    this%ivarcv = 0
    this%idewatcv = 0
    this%ithickstrt = 0
    this%iusgnrhc = 0
    this%inwtupw = 0
    this%icalcspdis = 0
    this%isavspdis = 0
    this%isavsat = 0
    this%irewet = 0
    this%wetfct = DONE
    this%iwetit = 1
    this%ihdwet = 0
    this%satmin = DZERO ! DEM7
    this%iangle1 = 0
    this%iangle2 = 0
    this%iangle3 = 0
    this%iwetdry = 0
    this%nedges = 0
    this%lastedge = 0
    this%intvk = 0
    this%invsc = 0
    this%kchangeper = 0
    this%kchangestp = 0
    !
    ! -- If newton is on, then NPF creates asymmetric matrix
    this%iasym = this%inewton
    !
    ! -- Return
    return
  end subroutine allocate_scalars

  !> @ brief Store backup copy of hydraulic conductivity when the VSC
  !!         package is activate
  !!
  !! The K arrays (K11, etc.) get multiplied by the viscosity ratio so that
  !! subsequent uses of K already take into account the effect of viscosity.
  !! Thus the original user-specified K array values are lost unless they are
  !! backed up in k11input, for example.  In a new stress period/time step,
  !! the values in k11input are multiplied by the viscosity ratio, not k11
  !! since it contains viscosity-adjusted hydraulic conductivity values.
  !<
  subroutine store_original_k_arrays(this, ncells, njas)
    ! -- modules
    use MemoryManagerModule, only: mem_allocate
    ! -- dummy
    class(GwfNpftype) :: this
    integer(I4B), intent(in) :: ncells
    integer(I4B), intent(in) :: njas
    ! -- local
    integer(I4B) :: n
    !
    ! -- Retain copy of user-specified K arrays
    do n = 1, ncells
      this%k11input(n) = this%k11(n)
      this%k22input(n) = this%k22(n)
      this%k33input(n) = this%k33(n)
    end do
    !
    ! -- Return
    return
  end subroutine store_original_k_arrays

  !> @brief Allocate npf arrays
  !<
  subroutine allocate_arrays(this, ncells, njas)
    ! -- dummy
    class(GwfNpftype) :: this
    integer(I4B), intent(in) :: ncells
    integer(I4B), intent(in) :: njas
    ! -- local
    integer(I4B) :: n
    !
    call mem_allocate(this%ithickstartflag, ncells, 'ITHICKSTARTFLAG', &
                      this%memoryPath)
    call mem_allocate(this%icelltype, ncells, 'ICELLTYPE', this%memoryPath)
    call mem_allocate(this%k11, ncells, 'K11', this%memoryPath)
    call mem_allocate(this%sat, ncells, 'SAT', this%memoryPath)
    call mem_allocate(this%condsat, njas, 'CONDSAT', this%memoryPath)
    !
    ! -- Optional arrays dimensioned to full size initially
    call mem_allocate(this%k22, ncells, 'K22', this%memoryPath)
    call mem_allocate(this%k33, ncells, 'K33', this%memoryPath)
    call mem_allocate(this%wetdry, ncells, 'WETDRY', this%memoryPath)
    call mem_allocate(this%angle1, ncells, 'ANGLE1', this%memoryPath)
    call mem_allocate(this%angle2, ncells, 'ANGLE2', this%memoryPath)
    call mem_allocate(this%angle3, ncells, 'ANGLE3', this%memoryPath)
    !
    ! -- Optional arrays
    call mem_allocate(this%ibotnode, 0, 'IBOTNODE', this%memoryPath)
    call mem_allocate(this%nodedge, 0, 'NODEDGE', this%memoryPath)
    call mem_allocate(this%ihcedge, 0, 'IHCEDGE', this%memoryPath)
    call mem_allocate(this%propsedge, 0, 0, 'PROPSEDGE', this%memoryPath)
    !
    ! -- Optional arrays only needed when vsc package is active
    call mem_allocate(this%k11input, 0, 'K11INPUT', this%memoryPath)
    call mem_allocate(this%k22input, 0, 'K22INPUT', this%memoryPath)
    call mem_allocate(this%k33input, 0, 'K33INPUT', this%memoryPath)
    !
    ! -- Specific discharge is (re-)allocated when nedges is known
    call mem_allocate(this%spdis, 3, 0, 'SPDIS', this%memoryPath)
    !
    ! -- Time-varying property flag arrays
    call mem_allocate(this%nodekchange, ncells, 'NODEKCHANGE', this%memoryPath)
    !
    ! -- initialize iangle1, iangle2, iangle3, and wetdry
    do n = 1, ncells
      this%angle1(n) = DZERO
      this%angle2(n) = DZERO
      this%angle3(n) = DZERO
      this%wetdry(n) = DZERO
      this%nodekchange(n) = DZERO
    end do
    !
    ! -- allocate variable names
    allocate (this%aname(this%iname))
    this%aname = ['               ICELLTYPE', '                       K', &
                  '                     K33', '                     K22', &
                  '                  WETDRY', '                  ANGLE1', &
                  '                  ANGLE2', '                  ANGLE3']
    !
    ! -- Return
    return
  end subroutine allocate_arrays

  !> @brief Log npf options sourced from the input mempath
  !<
  subroutine log_options(this, found)
    ! -- modules
    use KindModule, only: LGP
    use GwfNpfInputModule, only: GwfNpfParamFoundType
    ! -- dummy
    class(GwfNpftype) :: this
    ! -- locals
    type(GwfNpfParamFoundType), intent(in) :: found
    !
    write (this%iout, '(1x,a)') 'Setting NPF Options'
    if (found%iprflow) &
      write (this%iout, '(4x,a)') 'Cell-by-cell flow information will be printed &
                                  &to listing file whenever ICBCFL is not zero.'
    if (found%ipakcb) &
      write (this%iout, '(4x,a)') 'Cell-by-cell flow information will be saved &
                                  &to binary file whenever ICBCFL is not zero.'
    if (found%cellavg) &
      write (this%iout, '(4x,a,i0)') 'Alternative cell averaging [1=logarithmic, &
                                     &2=AMT-LMK, 3=AMT-HMK] set to: ', &
                                     this%icellavg
    if (found%ithickstrt) &
      write (this%iout, '(4x,a)') 'THICKSTRT option has been activated.'
    if (found%iperched) &
      write (this%iout, '(4x,a)') 'Vertical flow will be adjusted for perched &
                                  &conditions.'
    if (found%ivarcv) &
      write (this%iout, '(4x,a)') 'Vertical conductance varies with water table.'
    if (found%idewatcv) &
      write (this%iout, '(4x,a)') 'Vertical conductance accounts for dewatered &
                                  &portion of an underlying cell.'
    if (found%ixt3d) write (this%iout, '(4x,a)') 'XT3D formulation is selected.'
    if (found%ixt3drhs) &
      write (this%iout, '(4x,a)') 'XT3D RHS formulation is selected.'
    if (found%isavspdis) &
      write (this%iout, '(4x,a)') 'Specific discharge will be calculated at cell &
                                  &centers and written to DATA-SPDIS in budget &
                                  &file when requested.'
    if (found%isavsat) &
      write (this%iout, '(4x,a)') 'Saturation will be written to DATA-SAT in &
                                  &budget file when requested.'
    if (found%ik22overk) &
      write (this%iout, '(4x,a)') 'Values specified for K22 are anisotropy &
                                  &ratios and will be multiplied by K before &
                                  &being used in calculations.'
    if (found%ik33overk) &
      write (this%iout, '(4x,a)') 'Values specified for K33 are anisotropy &
                                  &ratios and will be multiplied by K before &
                                  &being used in calculations.'
    if (found%inewton) &
      write (this%iout, '(4x,a)') 'NEWTON-RAPHSON method disabled for unconfined &
                                  &cells'
    if (found%iusgnrhc) &
      write (this%iout, '(4x,a)') 'MODFLOW-USG saturation calculation method &
                                  &will be used'
    if (found%inwtupw) &
      write (this%iout, '(4x,a)') 'MODFLOW-NWT upstream weighting method will be &
                                  &used'
    if (found%satmin) &
      write (this%iout, '(4x,a,1pg15.6)') 'Minimum saturated thickness has been &
                                          &set to: ', this%satmin
    if (found%satomega) &
      write (this%iout, '(4x,a,1pg15.6)') 'Saturation omega: ', this%satomega
    if (found%irewet) &
      write (this%iout, '(4x,a)') 'Rewetting is active.'
    if (found%wetfct) &
      write (this%iout, '(4x,a,1pg15.6)') &
      'Wetting factor (WETFCT) has been set to: ', this%wetfct
    if (found%iwetit) &
      write (this%iout, '(4x,a,i5)') &
      'Wetting iteration interval (IWETIT) has been set to: ', this%iwetit
    if (found%ihdwet) &
      write (this%iout, '(4x,a,i5)') &
      'Head rewet equation (IHDWET) has been set to: ', this%ihdwet
    write (this%iout, '(1x,a,/)') 'End Setting NPF Options'
    !
    ! -- Return
    return
  end subroutine log_options

  !> @brief Update simulation options from input mempath
  !<
  subroutine source_options(this)
    ! -- modules
    use SimModule, only: store_error, store_error_filename
    use MemoryManagerModule, only: mem_setptr, get_isize
    use MemoryManagerExtModule, only: mem_set_value
    use CharacterStringModule, only: CharacterStringType
    use GwfNpfInputModule, only: GwfNpfParamFoundType
    use SourceCommonModule, only: filein_fname
    ! -- dummy
    class(GwfNpftype) :: this
    ! -- locals
    character(len=LENVARNAME), dimension(3) :: cellavg_method = &
      &[character(len=LENVARNAME) :: 'LOGARITHMIC', 'AMT-LMK', 'AMT-HMK']
    type(GwfNpfParamFoundType) :: found
    character(len=LINELENGTH) :: tvk6_filename
    !
    ! -- update defaults with idm sourced values
    call mem_set_value(this%iprflow, 'IPRFLOW', this%input_mempath, found%iprflow)
    call mem_set_value(this%ipakcb, 'IPAKCB', this%input_mempath, found%ipakcb)
    call mem_set_value(this%icellavg, 'CELLAVG', this%input_mempath, &
                       cellavg_method, found%cellavg)
    call mem_set_value(this%ithickstrt, 'ITHICKSTRT', this%input_mempath, &
                       found%ithickstrt)
    call mem_set_value(this%iperched, 'IPERCHED', this%input_mempath, &
                       found%iperched)
    call mem_set_value(this%ivarcv, 'IVARCV', this%input_mempath, found%ivarcv)
    call mem_set_value(this%idewatcv, 'IDEWATCV', this%input_mempath, &
                       found%idewatcv)
    call mem_set_value(this%ixt3d, 'IXT3D', this%input_mempath, found%ixt3d)
    call mem_set_value(this%ixt3drhs, 'IXT3DRHS', this%input_mempath, &
                       found%ixt3drhs)
    call mem_set_value(this%isavspdis, 'ISAVSPDIS', this%input_mempath, &
                       found%isavspdis)
    call mem_set_value(this%isavsat, 'ISAVSAT', this%input_mempath, found%isavsat)
    call mem_set_value(this%ik22overk, 'IK22OVERK', this%input_mempath, &
                       found%ik22overk)
    call mem_set_value(this%ik33overk, 'IK33OVERK', this%input_mempath, &
                       found%ik33overk)
    call mem_set_value(this%inewton, 'INEWTON', this%input_mempath, found%inewton)
    call mem_set_value(this%iusgnrhc, 'IUSGNRHC', this%input_mempath, &
                       found%iusgnrhc)
    call mem_set_value(this%inwtupw, 'INWTUPW', this%input_mempath, found%inwtupw)
    call mem_set_value(this%satmin, 'SATMIN', this%input_mempath, found%satmin)
    call mem_set_value(this%satomega, 'SATOMEGA', this%input_mempath, &
                       found%satomega)
    call mem_set_value(this%irewet, 'IREWET', this%input_mempath, found%irewet)
    call mem_set_value(this%wetfct, 'WETFCT', this%input_mempath, found%wetfct)
    call mem_set_value(this%iwetit, 'IWETIT', this%input_mempath, found%iwetit)
    call mem_set_value(this%ihdwet, 'IHDWET', this%input_mempath, found%ihdwet)
    !
    ! -- save flows option active
    if (found%ipakcb) this%ipakcb = -1
    !
    ! -- xt3d active with rhs
    if (found%ixt3d .and. found%ixt3drhs) this%ixt3d = 2
    !
    ! -- save specific discharge active
    if (found%isavspdis) this%icalcspdis = this%isavspdis
    !
    ! -- no newton specified
    if (found%inewton) then
      this%inewton = 0
      this%iasym = 0
    end if
    !
    ! -- enforce 0 or 1 TVK6_FILENAME entries in option block
    if (filein_fname(tvk6_filename, 'TVK6_FILENAME', this%input_mempath, &
                     this%input_fname)) then
      call openfile(this%intvk, this%iout, tvk6_filename, 'TVK')
      call tvk_cr(this%tvk, this%name_model, this%intvk, this%iout)
    end if
    !
    ! -- log options
    if (this%iout > 0) then
      call this%log_options(found)
    end if
    !
    ! -- Return
    return
  end subroutine source_options

  !> @brief Set options in the NPF object
  !<
  subroutine set_options(this, options)
    ! -- dummy
    class(GwfNpftype) :: this
    type(GwfNpfOptionsType), intent(in) :: options
    !
    this%icellavg = options%icellavg
    this%ithickstrt = options%ithickstrt
    this%iperched = options%iperched
    this%ivarcv = options%ivarcv
    this%idewatcv = options%idewatcv
    this%irewet = options%irewet
    this%wetfct = options%wetfct
    this%iwetit = options%iwetit
    this%ihdwet = options%ihdwet
    !
    ! -- Return
    return
  end subroutine set_options

  !> @brief Check for conflicting NPF options
  !<
  subroutine check_options(this)
    ! -- modules
    use SimModule, only: store_error, count_errors, store_error_filename
    use ConstantsModule, only: LINELENGTH
    ! -- dummy
    class(GwfNpftype) :: this
    !
    ! -- check if this%iusgnrhc has been enabled for a model that is not using
    !    the Newton-Raphson formulation
    if (this%iusgnrhc > 0 .and. this%inewton == 0) then
      this%iusgnrhc = 0
      write (this%iout, '(4x,a,3(1x,a))') &
        '****WARNING. MODFLOW-USG saturation calculation not needed', &
        'for a model that is using the standard conductance formulation.', &
        'Resetting DEV_MODFLOWUSG_UPSTREAM_WEIGHTED_SATURATION OPTION from', &
        '1 to 0.'
    end if
    !
    ! -- check that the this%inwtupw option is not specified for non-newton
    !    models
    if (this%inwtupw /= 0 .and. this%inewton == 0) then
      this%inwtupw = 0
      write (this%iout, '(4x,a,3(1x,a))') &
        '****WARNING. The DEV_MODFLOWNWT_UPSTREAM_WEIGHTING option has', &
        'been specified for a model that is using the standard conductance', &
        'formulation. Resetting DEV_MODFLOWNWT_UPSTREAM_WEIGHTING OPTION from', &
        '1 to 0.'
    end if
    !
    ! -- check that the transmissivity weighting functions are not specified with
    !    with the this%inwtupw option
    if (this%inwtupw /= 0 .and. this%icellavg < 2) then
      write (errmsg, '(a,2(1x,a))') &
        'THE DEV_MODFLOWNWT_UPSTREAM_WEIGHTING OPTION CAN', &
        'ONLY BE SPECIFIED WITH THE AMT-LMK AND AMT-HMK', &
        'ALTERNATIVE_CELL_AVERAGING OPTIONS IN THE NPF PACKAGE.'
      call store_error(errmsg)
    end if
    !
    ! -- check that this%iusgnrhc and this%inwtupw have not both been enabled
    if (this%iusgnrhc /= 0 .and. this%inwtupw /= 0) then
      write (errmsg, '(a,2(1x,a))') &
        'THE DEV_MODFLOWUSG_UPSTREAM_WEIGHTED_SATURATION', &
        'AND DEV_MODFLOWNWT_UPSTREAM_WEIGHTING OPTIONS CANNOT BE', &
        'SPECIFIED IN THE SAME NPF PACKAGE.'
      call store_error(errmsg)
    end if
    !
    ! -- set omega value used for saturation calculations
    if (this%inewton > 0) then
      this%satomega = DEM6
    end if
    !
    if (this%inewton > 0) then
      if (this%iperched > 0) then
        write (errmsg, '(a)') 'ERROR IN NPF OPTIONS. NEWTON OPTION CANNOT '// &
          'BE USED WITH PERCHED OPTION.'
        call store_error(errmsg)
      end if
      if (this%ivarcv > 0) then
        write (errmsg, '(a)') 'ERROR IN NPF OPTIONS. NEWTON OPTION CANNOT '// &
          'BE USED WITH VARIABLECV OPTION.'
        call store_error(errmsg)
      end if
      if (this%irewet > 0) then
        write (errmsg, '(a)') 'ERROR IN NPF OPTIONS. NEWTON OPTION CANNOT '// &
          'BE USED WITH REWET OPTION.'
        call store_error(errmsg)
      end if
    end if
    !
    if (this%ixt3d /= 0) then
      if (this%icellavg > 0) then
        write (errmsg, '(a)') 'ERROR IN NPF OPTIONS. '// &
          'ALTERNATIVE_CELL_AVERAGING OPTION '// &
          'CANNOT BE USED WITH XT3D OPTION.'
        call store_error(errmsg)
      end if
      if (this%ithickstrt > 0) then
        write (errmsg, '(a)') 'ERROR IN NPF OPTIONS. THICKSTRT OPTION '// &
          'CANNOT BE USED WITH XT3D OPTION.'
        call store_error(errmsg)
      end if
      if (this%iperched > 0) then
        write (errmsg, '(a)') 'ERROR IN NPF OPTIONS. PERCHED OPTION '// &
          'CANNOT BE USED WITH XT3D OPTION.'
        call store_error(errmsg)
      end if
      if (this%ivarcv > 0) then
        write (errmsg, '(a)') 'ERROR IN NPF OPTIONS. VARIABLECV OPTION '// &
          'CANNOT BE USED WITH XT3D OPTION.'
        call store_error(errmsg)
      end if
    end if
    !
    ! -- Terminate if errors
    if (count_errors() > 0) then
      call store_error_filename(this%input_fname)
    end if
    !
    ! -- Return
    return
  end subroutine check_options

  !> @brief Write dimensions to list file
  !<
  subroutine log_griddata(this, found)
    ! -- modules
    use GwfNpfInputModule, only: GwfNpfParamFoundType
    ! -- dummy
    class(GwfNpfType) :: this
    type(GwfNpfParamFoundType), intent(in) :: found
    !
    write (this%iout, '(1x,a)') 'Setting NPF Griddata'
    !
    if (found%icelltype) then
      write (this%iout, '(4x,a)') 'ICELLTYPE set from input file'
    end if
    !
    if (found%k) then
      write (this%iout, '(4x,a)') 'K set from input file'
    end if
    !
    if (found%k33) then
      write (this%iout, '(4x,a)') 'K33 set from input file'
    else
      write (this%iout, '(4x,a)') 'K33 not provided.  Setting K33 = K.'
    end if
    !
    if (found%k22) then
      write (this%iout, '(4x,a)') 'K22 set from input file'
    else
      write (this%iout, '(4x,a)') 'K22 not provided.  Setting K22 = K.'
    end if
    !
    if (found%wetdry) then
      write (this%iout, '(4x,a)') 'WETDRY set from input file'
    end if
    !
    if (found%angle1) then
      write (this%iout, '(4x,a)') 'ANGLE1 set from input file'
    end if
    !
    if (found%angle2) then
      write (this%iout, '(4x,a)') 'ANGLE2 set from input file'
    end if
    !
    if (found%angle3) then
      write (this%iout, '(4x,a)') 'ANGLE3 set from input file'
    end if
    !
    write (this%iout, '(1x,a,/)') 'End Setting NPF Griddata'
    !
    ! -- Return
    return
  end subroutine log_griddata

  !> @brief Update simulation griddata from input mempath
  !<
  subroutine source_griddata(this)
    ! -- modules
    use SimModule, only: count_errors, store_error
    use MemoryManagerModule, only: mem_reallocate
    use MemoryManagerExtModule, only: mem_set_value
    use GwfNpfInputModule, only: GwfNpfParamFoundType
    ! -- dummy
    class(GwfNpftype) :: this
    ! -- locals
    character(len=LINELENGTH) :: errmsg
    type(GwfNpfParamFoundType) :: found
    logical, dimension(2) :: afound
    integer(I4B), dimension(:), pointer, contiguous :: map
    !
    ! -- set map to convert user input data into reduced data
    map => null()
    if (this%dis%nodes < this%dis%nodesuser) map => this%dis%nodeuser
    !
    ! -- update defaults with idm sourced values
    call mem_set_value(this%icelltype, 'ICELLTYPE', this%input_mempath, map, &
                       found%icelltype)
    call mem_set_value(this%k11, 'K', this%input_mempath, map, found%k)
    call mem_set_value(this%k33, 'K33', this%input_mempath, map, found%k33)
    call mem_set_value(this%k22, 'K22', this%input_mempath, map, found%k22)
    call mem_set_value(this%wetdry, 'WETDRY', this%input_mempath, map, &
                       found%wetdry)
    call mem_set_value(this%angle1, 'ANGLE1', this%input_mempath, map, &
                       found%angle1)
    call mem_set_value(this%angle2, 'ANGLE2', this%input_mempath, map, &
                       found%angle2)
    call mem_set_value(this%angle3, 'ANGLE3', this%input_mempath, map, &
                       found%angle3)
    !
    ! -- ensure ICELLTYPE was found
    if (.not. found%icelltype) then
      write (errmsg, '(a)') 'Error in GRIDDATA block: ICELLTYPE not found.'
      call store_error(errmsg)
    end if
    !
    ! -- ensure K was found
    if (.not. found%k) then
      write (errmsg, '(a)') 'Error in GRIDDATA block: K not found.'
      call store_error(errmsg)
    end if
    !
    ! -- set error if ik33overk set with no k33
    if (.not. found%k33 .and. this%ik33overk /= 0) then
      write (errmsg, '(a)') 'K33OVERK option specified but K33 not specified.'
      call store_error(errmsg)
    end if
    !
    ! -- set error if ik22overk set with no k22
    if (.not. found%k22 .and. this%ik22overk /= 0) then
      write (errmsg, '(a)') 'K22OVERK option specified but K22 not specified.'
      call store_error(errmsg)
    end if
    !
    ! -- handle found side effects
    if (found%k33) this%ik33 = 1
    if (found%k22) this%ik22 = 1
    if (found%wetdry) this%iwetdry = 1
    if (found%angle1) this%iangle1 = 1
    if (found%angle2) this%iangle2 = 1
    if (found%angle3) this%iangle3 = 1
    !
    ! -- handle not found side effects
    if (.not. found%k33) then
      call mem_set_value(this%k33, 'K', this%input_mempath, map, afound(1))
    end if
    if (.not. found%k22) then
      call mem_set_value(this%k22, 'K', this%input_mempath, map, afound(2))
    end if
    if (.not. found%wetdry) call mem_reallocate(this%wetdry, 1, 'WETDRY', &
                                                trim(this%memoryPath))
    if (.not. found%angle1 .and. this%ixt3d == 0) &
      call mem_reallocate(this%angle1, 0, 'ANGLE1', trim(this%memoryPath))
    if (.not. found%angle2 .and. this%ixt3d == 0) &
      call mem_reallocate(this%angle2, 0, 'ANGLE2', trim(this%memoryPath))
    if (.not. found%angle3 .and. this%ixt3d == 0) &
      call mem_reallocate(this%angle3, 0, 'ANGLE3', trim(this%memoryPath))
    !
    ! -- log griddata
    if (this%iout > 0) then
      call this%log_griddata(found)
    end if
    !
    ! -- Return
    return
  end subroutine source_griddata

  !> @brief Initialize and check NPF data
  !<
  subroutine prepcheck(this)
    ! -- modules
    use ConstantsModule, only: LINELENGTH, DPIO180
    use SimModule, only: store_error, count_errors, store_error_filename
    ! -- dummy
    class(GwfNpfType) :: this
    ! -- local
    character(len=24), dimension(:), pointer :: aname
    character(len=LINELENGTH) :: cellstr, errmsg
    integer(I4B) :: nerr, n
    ! -- format
    character(len=*), parameter :: fmtkerr = &
      &"(1x, 'Hydraulic property ',a,' is <= 0 for cell ',a, ' ', 1pg15.6)"
    character(len=*), parameter :: fmtkerr2 = &
      &"(1x, '... ', i0,' additional errors not shown for ',a)"
    !
    ! -- initialize
    aname => this%aname
    !
    ! -- check k11
    nerr = 0
    do n = 1, size(this%k11)
      if (this%k11(n) <= DZERO) then
        nerr = nerr + 1
        if (nerr <= 20) then
          call this%dis%noder_to_string(n, cellstr)
          write (errmsg, fmtkerr) trim(adjustl(aname(2))), trim(cellstr), &
            this%k11(n)
          call store_error(errmsg)
        end if
      end if
    end do
    if (nerr > 20) then
      write (errmsg, fmtkerr2) nerr, trim(adjustl(aname(2)))
      call store_error(errmsg)
    end if
    !
    ! -- check k33 because it was read
    if (this%ik33 /= 0) then
      !
      ! -- Check to make sure values are greater than or equal to zero
      nerr = 0
      do n = 1, size(this%k33)
        if (this%ik33overk /= 0) this%k33(n) = this%k33(n) * this%k11(n)
        if (this%k33(n) <= DZERO) then
          nerr = nerr + 1
          if (nerr <= 20) then
            call this%dis%noder_to_string(n, cellstr)
            write (errmsg, fmtkerr) trim(adjustl(aname(3))), trim(cellstr), &
              this%k33(n)
            call store_error(errmsg)
          end if
        end if
      end do
      if (nerr > 20) then
        write (errmsg, fmtkerr2) nerr, trim(adjustl(aname(3)))
        call store_error(errmsg)
      end if
    end if
    !
    ! -- check k22 because it was read
    if (this%ik22 /= 0) then
      !
      ! -- Check to make sure that angles are available
      if (this%dis%con%ianglex == 0) then
        write (errmsg, '(a)') 'Error.  ANGLDEGX not provided in '// &
          'discretization file, but K22 was specified. '
        call store_error(errmsg)
      end if
      !
      ! -- Check to make sure values are greater than or equal to zero
      nerr = 0
      do n = 1, size(this%k22)
        if (this%ik22overk /= 0) this%k22(n) = this%k22(n) * this%k11(n)
        if (this%k22(n) <= DZERO) then
          nerr = nerr + 1
          if (nerr <= 20) then
            call this%dis%noder_to_string(n, cellstr)
            write (errmsg, fmtkerr) trim(adjustl(aname(4))), trim(cellstr), &
              this%k22(n)
            call store_error(errmsg)
          end if
        end if
      end do
      if (nerr > 20) then
        write (errmsg, fmtkerr2) nerr, trim(adjustl(aname(4)))
        call store_error(errmsg)
      end if
    end if
    !
    ! -- check for wetdry conflicts
    if (this%irewet == 1) then
      if (this%iwetdry == 0) then
        write (errmsg, '(a, a, a)') 'Error in GRIDDATA block: ', &
          trim(adjustl(aname(5))), ' not found.'
        call store_error(errmsg)
      end if
    end if
    !
    ! -- Check for angle conflicts
    if (this%iangle1 /= 0) then
      do n = 1, size(this%angle1)
        this%angle1(n) = this%angle1(n) * DPIO180
      end do
    else
      if (this%ixt3d /= 0) then
        this%iangle1 = 1
        write (this%iout, '(a)') 'XT3D IN USE, BUT ANGLE1 NOT SPECIFIED. '// &
          'SETTING ANGLE1 TO ZERO.'
        do n = 1, size(this%angle1)
          this%angle1(n) = DZERO
        end do
      end if
    end if
    if (this%iangle2 /= 0) then
      if (this%iangle1 == 0) then
        write (errmsg, '(a)') 'ANGLE2 SPECIFIED BUT NOT ANGLE1. '// &
          'ANGLE2 REQUIRES ANGLE1. '
        call store_error(errmsg)
      end if
      if (this%iangle3 == 0) then
        write (errmsg, '(a)') 'ANGLE2 SPECIFIED BUT NOT ANGLE3. '// &
          'SPECIFY BOTH OR NEITHER ONE. '
        call store_error(errmsg)
      end if
      do n = 1, size(this%angle2)
        this%angle2(n) = this%angle2(n) * DPIO180
      end do
    end if
    if (this%iangle3 /= 0) then
      if (this%iangle1 == 0) then
        write (errmsg, '(a)') 'ANGLE3 SPECIFIED BUT NOT ANGLE1. '// &
          'ANGLE3 REQUIRES ANGLE1. '
        call store_error(errmsg)
      end if
      if (this%iangle2 == 0) then
        write (errmsg, '(a)') 'ANGLE3 SPECIFIED BUT NOT ANGLE2. '// &
          'SPECIFY BOTH OR NEITHER ONE. '
        call store_error(errmsg)
      end if
      do n = 1, size(this%angle3)
        this%angle3(n) = this%angle3(n) * DPIO180
      end do
    end if
    !
    ! -- terminate if data errors
    if (count_errors() > 0) then
      call store_error_filename(this%input_fname)
    end if
    !
    ! -- Return
    return
  end subroutine prepcheck

  !> @brief preprocess the NPF input data
  !!
  !! This routine consists of the following steps:
  !!
  !! 1. convert cells to noflow when all transmissive parameters equal zero
  !! 2. perform initial wetting and drying
  !! 3. initialize cell saturation
  !! 4. calculate saturated conductance (when not xt3d)
  !! 5. If NEWTON under-relaxation, determine lower most node
  !<
  subroutine preprocess_input(this)
    ! -- modules
    use ConstantsModule, only: LINELENGTH
    use SimModule, only: store_error, count_errors, store_error_filename
    ! -- dummy
    class(GwfNpfType) :: this !< the instance of the NPF package
    ! -- local
    integer(I4B) :: n, m, ii, nn
    real(DP) :: hyn, hym
    real(DP) :: satn, topn, botn
    integer(I4B) :: nextn
    real(DP) :: minbot, botm
    logical :: finished
    character(len=LINELENGTH) :: cellstr, errmsg
    ! -- format
    character(len=*), parameter :: fmtcnv = &
      "(1X,'CELL ', A, &
      &' ELIMINATED BECAUSE ALL HYDRAULIC CONDUCTIVITIES TO NODE ARE 0.')"
    character(len=*), parameter :: fmtnct = &
      &"(1X,'Negative cell thickness at cell ', A)"
    character(len=*), parameter :: fmtihbe = &
      &"(1X,'Initial head, bottom elevation:',1P,2G13.5)"
    character(len=*), parameter :: fmttebe = &
      &"(1X,'Top elevation, bottom elevation:',1P,2G13.5)"
    !
    do n = 1, this%dis%nodes
      this%ithickstartflag(n) = 0
    end do
    !
    ! -- Insure that each cell has at least one non-zero transmissive parameter
    !    Note that a cell can be deactivated even if it has a valid connection
    !    to another model.
    nodeloop: do n = 1, this%dis%nodes
      !
      ! -- Skip if already inactive
      if (this%ibound(n) == 0) then
        if (this%irewet /= 0) then
          if (this%wetdry(n) == DZERO) cycle nodeloop
        else
          cycle nodeloop
        end if
      end if
      !
      ! -- Cycle if k11 is not zero
      if (this%k11(n) /= DZERO) cycle nodeloop
      !
      ! -- Cycle if at least one vertical connection has non-zero k33
      !    for n and m
      do ii = this%dis%con%ia(n) + 1, this%dis%con%ia(n + 1) - 1
        m = this%dis%con%ja(ii)
        if (this%dis%con%ihc(this%dis%con%jas(ii)) == 0) then
          hyn = this%k11(n)
          if (this%ik33 /= 0) hyn = this%k33(n)
          if (hyn /= DZERO) then
            hym = this%k11(m)
            if (this%ik33 /= 0) hym = this%k33(m)
            if (hym /= DZERO) cycle
          end if
        end if
      end do
      !
      ! -- If this part of the loop is reached, then all connections have
      !    zero transmissivity, so convert to noflow.
      this%ibound(n) = 0
      this%hnew(n) = this%hnoflo
      if (this%irewet /= 0) this%wetdry(n) = DZERO
      call this%dis%noder_to_string(n, cellstr)
      write (this%iout, fmtcnv) trim(adjustl(cellstr))
      !
    end do nodeloop
    !
    ! -- Preprocess cell status and heads based on initial conditions
    if (this%inewton == 0) then
      !
      ! -- For standard formulation (non-Newton) call wetdry routine
      call this%wd(0, this%hnew)
    else
      !
      ! -- Newton formulation, so adjust heads to be above bottom
      !    (Not used in present formulation because variable cv
      !    cannot be used with Newton)
      if (this%ivarcv == 1) then
        do n = 1, this%dis%nodes
          if (this%hnew(n) < this%dis%bot(n)) then
            this%hnew(n) = this%dis%bot(n) + DEM6
          end if
        end do
      end if
    end if
    !
    ! -- If THCKSTRT is not active, then loop through icelltype and replace
    !    any negative values with 1.
    if (this%ithickstrt == 0) then
      do n = 1, this%dis%nodes
        if (this%icelltype(n) < 0) then
          this%icelltype(n) = 1
        end if
      end do
    end if
    !
    ! -- Initialize sat to zero for ibound=0 cells, unless the cell can
    !    rewet.  Initialize sat to the saturated fraction based on strt
    !    if icelltype is negative and the THCKSTRT option is in effect.
    !    Initialize sat to 1.0 for all other cells in order to calculate
    !    condsat in next section.
    do n = 1, this%dis%nodes
      if (this%ibound(n) == 0) then
        this%sat(n) = DONE
        if (this%icelltype(n) < 0 .and. this%ithickstrt /= 0) then
          this%ithickstartflag(n) = 1
          this%icelltype(n) = 0
        end if
      else
        topn = this%dis%top(n)
        botn = this%dis%bot(n)
        if (this%icelltype(n) < 0 .and. this%ithickstrt /= 0) then
          call this%thksat(n, this%ic%strt(n), satn)
          if (botn > this%ic%strt(n)) then
            call this%dis%noder_to_string(n, cellstr)
            write (errmsg, fmtnct) trim(adjustl(cellstr))
            call store_error(errmsg)
            write (errmsg, fmtihbe) this%ic%strt(n), botn
            call store_error(errmsg)
          end if
          this%ithickstartflag(n) = 1
          this%icelltype(n) = 0
        else
          satn = DONE
          if (botn > topn) then
            call this%dis%noder_to_string(n, cellstr)
            write (errmsg, fmtnct) trim(adjustl(cellstr))
            call store_error(errmsg)
            write (errmsg, fmttebe) topn, botn
            call store_error(errmsg)
          end if
        end if
        this%sat(n) = satn
      end if
    end do
    if (count_errors() > 0) then
      call store_error_filename(this%input_fname)
    end if
    !
    ! -- Calculate condsat, but only if xt3d is not active.  If xt3d is
    !    active, then condsat is allocated to size of zero.
    if (this%ixt3d == 0) then
      !
      ! -- Calculate the saturated conductance for all connections assuming
      !    that saturation is 1 (except for case where icelltype was entered
      !    as a negative value and THCKSTRT option in effect)
      do n = 1, this%dis%nodes
        call this%calc_condsat(n, .true.)
      end do
      !
    end if
    !
    ! -- Determine the lower most node
    if (this%igwfnewtonur /= 0) then
      call mem_reallocate(this%ibotnode, this%dis%nodes, 'IBOTNODE', &
                          trim(this%memoryPath))
      do n = 1, this%dis%nodes
        !
        minbot = this%dis%bot(n)
        nn = n
        finished = .false.
        do while (.not. finished)
          nextn = 0
          !
          ! -- Go through the connecting cells
          do ii = this%dis%con%ia(nn) + 1, this%dis%con%ia(nn + 1) - 1
            !
            ! -- Set the m cell number
            m = this%dis%con%ja(ii)
            botm = this%dis%bot(m)
            !
            ! -- select vertical connections: ihc == 0
            if (this%dis%con%ihc(this%dis%con%jas(ii)) == 0) then
              if (m > nn .and. botm < minbot) then
                nextn = m
                minbot = botm
              end if
            end if
          end do
          if (nextn > 0) then
            nn = nextn
          else
            finished = .true.
          end if
        end do
        this%ibotnode(n) = nn
      end do
    end if
    !
    ! -- nullify unneeded gwf pointers
    this%igwfnewtonur => null()
    !
    ! -- Return
    return
  end subroutine preprocess_input

  !> @brief Calculate CONDSAT array entries for the given node
  !!
  !! Calculate saturated conductances for all connections of the given node,
  !! or optionally for the upper portion of the matrix only.
  !<
  subroutine calc_condsat(this, node, upperOnly)
    ! -- dummy variables
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: node
    logical, intent(in) :: upperOnly
    ! -- local variables
    integer(I4B) :: ii, m, n, ihc, jj
    real(DP) :: topm, topn, topnode, botm, botn, botnode, satm, satn, satnode
    real(DP) :: hyn, hym, hn, hm, fawidth, csat
    !
    satnode = this%calc_initial_sat(node)
    !
    topnode = this%dis%top(node)
    botnode = this%dis%bot(node)
    !
    ! -- Go through the connecting cells
    do ii = this%dis%con%ia(node) + 1, this%dis%con%ia(node + 1) - 1
      !
      ! -- Set the m cell number and cycle if lower triangle connection and
      ! -- we're not updating both upper and lower matrix parts for this node
      m = this%dis%con%ja(ii)
      jj = this%dis%con%jas(ii)
      if (m < node) then
        if (upperOnly) cycle
        ! m => node, n => neighbour
        n = m
        m = node
        topm = topnode
        botm = botnode
        satm = satnode
        topn = this%dis%top(n)
        botn = this%dis%bot(n)
        satn = this%calc_initial_sat(n)
      else
        ! n => node, m => neighbour
        n = node
        topn = topnode
        botn = botnode
        satn = satnode
        topm = this%dis%top(m)
        botm = this%dis%bot(m)
        satm = this%calc_initial_sat(m)
      end if
      !
      ihc = this%dis%con%ihc(jj)
      hyn = this%hy_eff(n, m, ihc, ipos=ii)
      hym = this%hy_eff(m, n, ihc, ipos=ii)
      if (this%ithickstartflag(n) == 0) then
        hn = topn
      else
        hn = this%ic%strt(n)
      end if
      if (this%ithickstartflag(m) == 0) then
        hm = topm
      else
        hm = this%ic%strt(m)
      end if
      !
      ! -- Calculate conductance depending on whether connection is
      !    vertical (0), horizontal (1), or staggered horizontal (2)
      if (ihc == 0) then
        !
        ! -- Vertical conductance for fully saturated conditions
        csat = vcond(1, 1, 1, 1, 0, 1, 1, DONE, &
                     botn, botm, &
                     hyn, hym, &
                     satn, satm, &
                     topn, topm, &
                     botn, botm, &
                     this%dis%con%hwva(jj))
      else
        !
        ! -- Horizontal conductance for fully saturated conditions
        fawidth = this%dis%con%hwva(jj)
        csat = hcond(1, 1, 1, 1, this%inewton, 0, &
                     ihc, &
                     this%icellavg, this%iusgnrhc, this%inwtupw, &
                     DONE, &
                     hn, hm, satn, satm, hyn, hym, &
                     topn, topm, &
                     botn, botm, &
                     this%dis%con%cl1(jj), &
                     this%dis%con%cl2(jj), &
                     fawidth, this%satomega, this%satmin)
      end if
      this%condsat(jj) = csat
    end do
    !
    ! -- Return
    return
  end subroutine calc_condsat

  !> @brief Calculate initial saturation for the given node
  !!
  !! Calculate saturation as a fraction of thickness for the given node, used
  !! for saturated conductance calculations: full thickness by default (1.0) or
  !! saturation based on initial conditions if the THICKSTRT option is used.
  !!
  !<
  function calc_initial_sat(this, n) result(satn)
    ! -- dummy variables
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: n
    ! -- Return
    real(DP) :: satn
    !
    satn = DONE
    if (this%ibound(n) /= 0 .and. this%ithickstartflag(n) /= 0) then
      call this%thksat(n, this%ic%strt(n), satn)
    end if
    !
    return
  end function calc_initial_sat

  !> @brief Perform wetting and drying
  !<
  subroutine sgwf_npf_wetdry(this, kiter, hnew)
    ! -- modules
    use TdisModule, only: kstp, kper
    use SimModule, only: store_error, store_error_filename
    use ConstantsModule, only: LINELENGTH
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: kiter
    real(DP), intent(inout), dimension(:) :: hnew
    ! -- local
    integer(I4B) :: n, m, ii, ihc
    real(DP) :: ttop, bbot, thck
    integer(I4B) :: ncnvrt, ihdcnv
    character(len=30), dimension(5) :: nodcnvrt
    character(len=30) :: nodestr
    character(len=3), dimension(5) :: acnvrt
    character(len=LINELENGTH) :: errmsg
    integer(I4B) :: irewet
    ! -- formats
    character(len=*), parameter :: fmtnct = &
      "(1X,/1X,'Negative cell thickness at (layer,row,col)', &
      &I4,',',I5,',',I5)"
    character(len=*), parameter :: fmttopbot = &
      &"(1X,'Top elevation, bottom elevation:',1P,2G13.5)"
    character(len=*), parameter :: fmttopbotthk = &
      &"(1X,'Top elevation, bottom elevation, thickness:',1P,3G13.5)"
    character(len=*), parameter :: fmtdrychd = &
      &"(1X,/1X,'CONSTANT-HEAD CELL WENT DRY -- SIMULATION ABORTED')"
    character(len=*), parameter :: fmtni = &
      &"(1X,'CELLID=',a,' ITERATION=',I0,' TIME STEP=',I0,' STRESS PERIOD=',I0)"
    !
    ! -- Initialize
    ncnvrt = 0
    ihdcnv = 0
    !
    ! -- Convert dry cells to wet
    do n = 1, this%dis%nodes
      do ii = this%dis%con%ia(n) + 1, this%dis%con%ia(n + 1) - 1
        m = this%dis%con%ja(ii)
        ihc = this%dis%con%ihc(this%dis%con%jas(ii))
        call this%rewet_check(kiter, n, hnew(m), this%ibound(m), ihc, hnew, &
                              irewet)
        if (irewet == 1) then
          call this%wdmsg(2, ncnvrt, nodcnvrt, acnvrt, ihdcnv, kiter, n)
        end if
      end do
    end do
    !
    ! -- Perform drying
    do n = 1, this%dis%nodes
      !
      ! -- cycle if inactive or confined
      if (this%ibound(n) == 0) cycle
      if (this%icelltype(n) == 0) cycle
      !
      ! -- check for negative cell thickness
      bbot = this%dis%bot(n)
      ttop = this%dis%top(n)
      if (bbot > ttop) then
        write (errmsg, fmtnct) n
        call store_error(errmsg)
        write (errmsg, fmttopbot) ttop, bbot
        call store_error(errmsg)
        call store_error_filename(this%input_fname)
      end if
      !
      ! -- Calculate saturated thickness
      if (this%icelltype(n) /= 0) then
        if (hnew(n) < ttop) ttop = hnew(n)
      end if
      thck = ttop - bbot
      !
      ! -- If thck<0 print message, set hnew, and ibound
      if (thck <= DZERO) then
        call this%wdmsg(1, ncnvrt, nodcnvrt, acnvrt, ihdcnv, kiter, n)
        hnew(n) = this%hdry
        if (this%ibound(n) < 0) then
          errmsg = 'CONSTANT-HEAD CELL WENT DRY -- SIMULATION ABORTED'
          call store_error(errmsg)
          write (errmsg, fmttopbotthk) ttop, bbot, thck
          call store_error(errmsg)
          call this%dis%noder_to_string(n, nodestr)
          write (errmsg, fmtni) trim(adjustl(nodestr)), kiter, kstp, kper
          call store_error(errmsg)
          call store_error_filename(this%input_fname)
        end if
        this%ibound(n) = 0
      end if
    end do
    !
    ! -- Print remaining cell conversions
    call this%wdmsg(0, ncnvrt, nodcnvrt, acnvrt, ihdcnv, kiter, n)
    !
    ! -- Change ibound from 30000 to 1
    do n = 1, this%dis%nodes
      if (this%ibound(n) == 30000) this%ibound(n) = 1
    end do
    !
    ! -- Return
    return
  end subroutine sgwf_npf_wetdry

  !> @brief Determine if a cell should rewet
  !!
  !! This method can be called from any external object that has a head that
  !! can be used to rewet the GWF cell node.  The ihc value is used to
  !! determine if it is a vertical or horizontal connection, which can operate
  !! differently depending on user settings.
  !<
  subroutine rewet_check(this, kiter, node, hm, ibdm, ihc, hnew, irewet)
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: kiter
    integer(I4B), intent(in) :: node
    real(DP), intent(in) :: hm
    integer(I4B), intent(in) :: ibdm
    integer(I4B), intent(in) :: ihc
    real(DP), intent(inout), dimension(:) :: hnew
    integer(I4B), intent(out) :: irewet
    ! -- local
    integer(I4B) :: itflg
    real(DP) :: wd, awd, turnon, bbot
    !
    irewet = 0
    !
    ! -- Convert a dry cell to wet if it meets the criteria
    if (this%irewet > 0) then
      itflg = mod(kiter, this%iwetit)
      if (itflg == 0) then
        if (this%ibound(node) == 0 .and. this%wetdry(node) /= DZERO) then
          !
          ! -- Calculate wetting elevation
          bbot = this%dis%bot(node)
          wd = this%wetdry(node)
          awd = wd
          if (wd < 0) awd = -wd
          turnon = bbot + awd
          !
          ! -- Check head in adjacent cells to see if wetting elevation has
          !    been reached
          if (ihc == 0) then
            !
            ! -- check cell below
            if (ibdm > 0 .and. hm >= turnon) irewet = 1
          else
            if (wd > DZERO) then
              !
              ! -- check horizontally adjacent cells
              if (ibdm > 0 .and. hm >= turnon) irewet = 1
            end if
          end if
          !
          if (irewet == 1) then
            ! -- rewet cell; use equation 3a if ihdwet=0; use equation 3b if
            !    ihdwet is not 0.
            if (this%ihdwet == 0) then
              hnew(node) = bbot + this%wetfct * (hm - bbot)
            else
              hnew(node) = bbot + this%wetfct * awd !(hm - bbot)
            end if
            this%ibound(node) = 30000
          end if
        end if
      end if
    end if
    !
    ! -- Return
    return
  end subroutine rewet_check

  !> @brief Print wet/dry message
  !<
  subroutine sgwf_npf_wdmsg(this, icode, ncnvrt, nodcnvrt, acnvrt, ihdcnv, &
                            kiter, n)
    ! -- modules
    use TdisModule, only: kstp, kper
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: icode
    integer(I4B), intent(inout) :: ncnvrt
    character(len=30), dimension(5), intent(inout) :: nodcnvrt
    character(len=3), dimension(5), intent(inout) :: acnvrt
    integer(I4B), intent(inout) :: ihdcnv
    integer(I4B), intent(in) :: kiter
    integer(I4B), intent(in) :: n
    ! -- local
    integer(I4B) :: l
    ! -- formats
    character(len=*), parameter :: fmtcnvtn = &
      "(1X,/1X,'CELL CONVERSIONS FOR ITER.=',I0, &
       &'  STEP=',I0,'  PERIOD=',I0,'   (NODE or LRC)')"
    character(len=*), parameter :: fmtnode = "(1X,3X,5(A4, A20))"
    !
    ! -- Keep track of cell conversions
    if (icode > 0) then
      ncnvrt = ncnvrt + 1
      call this%dis%noder_to_string(n, nodcnvrt(ncnvrt))
      if (icode == 1) then
        acnvrt(ncnvrt) = 'DRY'
      else
        acnvrt(ncnvrt) = 'WET'
      end if
    end if
    !
    ! -- Print a line if 5 conversions have occurred or if icode indicates that a
    !    partial line should be printed
    if (ncnvrt == 5 .or. (icode == 0 .and. ncnvrt > 0)) then
      if (ihdcnv == 0) write (this%iout, fmtcnvtn) kiter, kstp, kper
      ihdcnv = 1
      write (this%iout, fmtnode) &
        (acnvrt(l), trim(adjustl(nodcnvrt(l))), l=1, ncnvrt)
      ncnvrt = 0
    end if
    !
    ! -- Return
    return
  end subroutine sgwf_npf_wdmsg

  !> @brief Calculate the effective hydraulic conductivity for the n-m connection
  !!
  !! n is primary node node number
  !! m is connected node (not used if vg is provided)
  !! ihc is horizontal indicator (0 vertical, 1 horizontal, 2 vertically
  !!   staggered)
  !! ipos_opt is position of connection in ja array
  !! vg is the global unit vector that expresses the direction from which to
  !!   calculate an effective hydraulic conductivity.
  !<
  function hy_eff(this, n, m, ihc, ipos, vg) result(hy)
    ! -- return
    real(DP) :: hy
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: n
    integer(I4B), intent(in) :: m
    integer(I4B), intent(in) :: ihc
    integer(I4B), intent(in), optional :: ipos
    real(DP), dimension(3), intent(in), optional :: vg
    ! -- local
    integer(I4B) :: iipos
    real(DP) :: hy11, hy22, hy33
    real(DP) :: ang1, ang2, ang3
    real(DP) :: vg1, vg2, vg3
    !
    ! -- Initialize
    iipos = 0
    if (present(ipos)) iipos = ipos
    hy11 = this%k11(n)
    hy22 = this%k11(n)
    hy33 = this%k11(n)
    hy22 = this%k22(n)
    hy33 = this%k33(n)
    !
    ! -- Calculate effective K based on whether connection is vertical
    !    or horizontal
    if (ihc == 0) then
      !
      ! -- Handle rotated anisotropy case that would affect the effective
      !    vertical hydraulic conductivity
      hy = hy33
      if (this%iangle2 > 0) then
        if (present(vg)) then
          vg1 = vg(1)
          vg2 = vg(2)
          vg3 = vg(3)
        else
          call this%dis%connection_normal(n, m, ihc, vg1, vg2, vg3, iipos)
        end if
        ang1 = this%angle1(n)
        ang2 = this%angle2(n)
        ang3 = DZERO
        if (this%iangle3 > 0) ang3 = this%angle3(n)
        hy = hyeff_calc(hy11, hy22, hy33, ang1, ang2, ang3, vg1, vg2, vg3, &
                        this%iavgkeff)
      end if
      !
    else
      !
      ! -- Handle horizontal case
      hy = hy11
      if (this%ik22 > 0) then
        if (present(vg)) then
          vg1 = vg(1)
          vg2 = vg(2)
          vg3 = vg(3)
        else
          call this%dis%connection_normal(n, m, ihc, vg1, vg2, vg3, iipos)
        end if
        ang1 = DZERO
        ang2 = DZERO
        ang3 = DZERO
        if (this%iangle1 > 0) then
          ang1 = this%angle1(n)
          if (this%iangle2 > 0) then
            ang2 = this%angle2(n)
            if (this%iangle3 > 0) ang3 = this%angle3(n)
          end if
        end if
        hy = hyeff_calc(hy11, hy22, hy33, ang1, ang2, ang3, vg1, vg2, vg3, &
                        this%iavgkeff)
      end if
      !
    end if
    !
    ! -- Return
    return
  end function hy_eff

  !> @brief Horizontal conductance between two cells
  !!
  !! inwtup: if 1, then upstream-weight condsat, otherwise recalculate
  !!
  !! This function uses a weighted transmissivity in the harmonic mean
  !! conductance calculations. This differs from the MODFLOW-NWT and
  !! MODFLOW-USG conductance calculations for the Newton-Raphson formulation
  !! which use a weighted hydraulic conductivity.
  !<
  function hcond(ibdn, ibdm, ictn, ictm, inewton, inwtup, ihc, icellavg, iusg, &
                 iupw, condsat, hn, hm, satn, satm, hkn, hkm, topn, topm, &
                 botn, botm, cln, clm, fawidth, satomega, satminopt) &
    result(condnm)
    ! -- return
    real(DP) :: condnm
    ! -- dummy
    integer(I4B), intent(in) :: ibdn
    integer(I4B), intent(in) :: ibdm
    integer(I4B), intent(in) :: ictn
    integer(I4B), intent(in) :: ictm
    integer(I4B), intent(in) :: inewton
    integer(I4B), intent(in) :: inwtup
    integer(I4B), intent(in) :: ihc
    integer(I4B), intent(in) :: icellavg
    integer(I4B), intent(in) :: iusg
    integer(I4B), intent(in) :: iupw
    real(DP), intent(in) :: condsat
    real(DP), intent(in) :: hn
    real(DP), intent(in) :: hm
    real(DP), intent(in) :: satn
    real(DP), intent(in) :: satm
    real(DP), intent(in) :: hkn
    real(DP), intent(in) :: hkm
    real(DP), intent(in) :: topn
    real(DP), intent(in) :: topm
    real(DP), intent(in) :: botn
    real(DP), intent(in) :: botm
    real(DP), intent(in) :: cln
    real(DP), intent(in) :: clm
    real(DP), intent(in) :: fawidth
    real(DP), intent(in) :: satomega
    real(DP), optional, intent(in) :: satminopt
    ! -- local
    integer(I4B) :: indk
    real(DP) :: satmin
    real(DP) :: sn
    real(DP) :: sm
    real(DP) :: thksatn
    real(DP) :: thksatm
    real(DP) :: sill_top, sill_bot
    real(DP) :: tpn, tpm
    real(DP) :: top, bot
    real(DP) :: athk
    real(DP) :: afac
    !
    if (present(satminopt)) then
      satmin = satminopt
    else
      satmin = DZERO
    end if
    !
    ! -- If either n or m is inactive then conductance is zero
    if (ibdn == 0 .or. ibdm == 0) then
      condnm = DZERO
      !
      ! -- if both cells are non-convertible then use condsat
    elseif (ictn == 0 .and. ictm == 0) then
      if (icellavg /= 4) then
        condnm = condsat
      else
        if (hn > hm) then
          condnm = satn * (topn - botn)
        else
          condnm = satm * (topm - botm)
        end if
        condnm = condnm * condsat
      end if
      !
      ! -- At least one of the cells is convertible, so calculate average saturated
      !    thickness and multiply with saturated conductance
    else
      if (inwtup == 1) then
        ! -- set flag use to determine if bottom of cells n and m are
        !    significantly different
        indk = 0
        if (abs(botm - botn) < DEM2) indk = 1
        ! -- recalculate saturation if using MODFLOW-USG saturation
        !    calculation approach
        if (iusg == 1 .and. indk == 0) then
          if (botm > botn) then
            top = topm
            bot = botm
          else
            top = topn
            bot = botn
          end if
          sn = sQuadraticSaturation(top, bot, hn, satomega, satmin)
          sm = sQuadraticSaturation(top, bot, hm, satomega, satmin)
        else
          sn = sQuadraticSaturation(topn, botn, hn, satomega, satmin)
          sm = sQuadraticSaturation(topm, botm, hm, satomega, satmin)
        end if
        !
        if (hn > hm) then
          condnm = sn
        else
          condnm = sm
        end if
        !
        ! -- if using MODFLOW-NWT upstream weighting option apply
        !    factor to remove average thickness
        if (iupw /= 0) then
          if (hn > hm) then
            afac = DTWO / (DONE + (topm - botm) / (topn - botn))
            condnm = condnm * afac
          else
            afac = DTWO / (DONE + (topn - botn) / (topm - botm))
            condnm = condnm * afac
          end if
        end if
        !
        ! -- multiply condsat by condnm factor
        condnm = condnm * condsat
      else
        thksatn = satn * (topn - botn)
        thksatm = satm * (topm - botm)
        !
        ! -- If staggered connection, subtract parts of cell that are above and
        !    below the sill top and bottom elevations
        if (ihc == 2) then
          !
          ! -- Calculate sill_top and sill_bot
          sill_top = min(topn, topm)
          sill_bot = max(botn, botm)
          !
          ! -- Calculate tpn and tpm
          tpn = botn + thksatn
          tpm = botm + thksatm
          !
          ! -- Calculate saturated thickness for cells n and m
          thksatn = max(min(tpn, sill_top) - sill_bot, DZERO)
          thksatm = max(min(tpm, sill_top) - sill_bot, DZERO)
        end if
        !
        athk = DONE
        if (iusg == 1) then
          if (ihc == 2) then
            athk = min(thksatn, thksatm)
          else
            athk = DHALF * (thksatn + thksatm)
          end if
          thksatn = DONE
          thksatm = DONE
        end if
        !
        condnm = condmean(hkn, hkm, thksatn, thksatm, cln, clm, &
                          fawidth, icellavg) * athk
      end if
    end if
    !
    ! -- Return
    return
  end function hcond

  !> @brief Vertical conductance between two cells
  !<
  function vcond(ibdn, ibdm, ictn, ictm, inewton, ivarcv, idewatcv, &
                 condsat, hn, hm, vkn, vkm, satn, satm, topn, topm, botn, &
                 botm, flowarea) result(condnm)
    ! -- return
    real(DP) :: condnm
    ! -- dummy
    integer(I4B), intent(in) :: ibdn
    integer(I4B), intent(in) :: ibdm
    integer(I4B), intent(in) :: ictn
    integer(I4B), intent(in) :: ictm
    integer(I4B), intent(in) :: inewton
    integer(I4B), intent(in) :: ivarcv
    integer(I4B), intent(in) :: idewatcv
    real(DP), intent(in) :: condsat
    real(DP), intent(in) :: hn
    real(DP), intent(in) :: hm
    real(DP), intent(in) :: vkn
    real(DP), intent(in) :: vkm
    real(DP), intent(in) :: satn
    real(DP), intent(in) :: satm
    real(DP), intent(in) :: topn
    real(DP), intent(in) :: topm
    real(DP), intent(in) :: botn
    real(DP), intent(in) :: botm
    real(DP), intent(in) :: flowarea
    ! -- local
    real(DP) :: satntmp, satmtmp
    real(DP) :: bovk1
    real(DP) :: bovk2
    real(DP) :: denom
    !
    ! -- If either n or m is inactive then conductance is zero
    if (ibdn == 0 .or. ibdm == 0) then
      condnm = DZERO
      !
      ! -- if constantcv then use condsat
    elseif (ivarcv == 0) then
      condnm = condsat
      !
      ! -- if both cells are non-convertible then use condsat
    elseif (ictn == 0 .and. ictm == 0) then
      condnm = condsat
      !
      ! -- if both cells are fully saturated then use condsat
    elseif (hn >= topn .and. hm >= topm) then
      condnm = condsat
      !
      ! -- At least one cell is partially saturated, so recalculate vertical
      ! -- conductance for this connection
      ! -- todo: upstream weighting?
    else
      !
      ! -- Default is for CV correction (dewatered option); use underlying
      !    saturation of 1.
      satntmp = satn
      satmtmp = satm
      if (idewatcv == 0) then
        if (botn > botm) then
          ! -- n is above m
          satmtmp = DONE
        else
          ! -- m is above n
          satntmp = DONE
        end if
      end if
      bovk1 = satntmp * (topn - botn) * DHALF / vkn
      bovk2 = satmtmp * (topm - botm) * DHALF / vkm
      denom = (bovk1 + bovk2)
      if (denom /= DZERO) then
        condnm = flowarea / denom
      else
        condnm = DZERO
      end if
    end if
    !
    ! -- Return
    return
  end function vcond

  !> @brief Calculate the conductance between two cells
  !!
  !! k1 is hydraulic conductivity for cell 1 (in the direction of cell2)
  !! k2 is hydraulic conductivity for cell 2 (in the direction of cell1)
  !! thick1 is the saturated thickness for cell 1
  !! thick2 is the saturated thickness for cell 2
  !! cl1 is the distance from the center of cell1 to the shared face with cell2
  !! cl2 is the distance from the center of cell2 to the shared face with cell1
  !! h1 is the head for cell1
  !! h2 is the head for cell2
  !! width is the width perpendicular to flow
  !! iavgmeth is the averaging method:
  !!   0 is harmonic averaging
  !!   1 is logarithmic averaging
  !!   2 is arithmetic averaging of sat thickness and logarithmic averaging of
  !!     hydraulic conductivity
  !!   3 is arithmetic averaging of sat thickness and harmonic averaging of
  !!     hydraulic conductivity
  !<
  function condmean(k1, k2, thick1, thick2, cl1, cl2, width, iavgmeth)
    ! -- return
    real(DP) :: condmean
    ! -- dummy
    real(DP), intent(in) :: k1
    real(DP), intent(in) :: k2
    real(DP), intent(in) :: thick1
    real(DP), intent(in) :: thick2
    real(DP), intent(in) :: cl1
    real(DP), intent(in) :: cl2
    real(DP), intent(in) :: width
    integer(I4B), intent(in) :: iavgmeth
    ! -- local
    real(DP) :: t1
    real(DP) :: t2
    real(DP) :: tmean, kmean, denom
    !
    ! -- Initialize
    t1 = k1 * thick1
    t2 = k2 * thick2
    !
    ! -- Averaging
    select case (iavgmeth)
      !
      ! -- Harmonic-mean method
    case (0)
      !
      if (t1 * t2 > DZERO) then
        condmean = width * t1 * t2 / (t1 * cl2 + t2 * cl1)
      else
        condmean = DZERO
      end if
      !
      ! -- Logarithmic-mean method
    case (1)
      if (t1 * t2 > DZERO) then
        tmean = logmean(t1, t2)
      else
        tmean = DZERO
      end if
      condmean = tmean * width / (cl1 + cl2)
      !
      ! -- Arithmetic-mean thickness and logarithmic-mean hydraulic conductivity
    case (2)
      if (k1 * k2 > DZERO) then
        kmean = logmean(k1, k2)
      else
        kmean = DZERO
      end if
      condmean = kmean * DHALF * (thick1 + thick2) * width / (cl1 + cl2)
      !
      ! -- Arithmetic-mean thickness and harmonic-mean hydraulic conductivity
    case (3)
      denom = (k1 * cl2 + k2 * cl1)
      if (denom > DZERO) then
        kmean = k1 * k2 / denom
      else
        kmean = DZERO
      end if
      condmean = kmean * DHALF * (thick1 + thick2) * width
    end select
    !
    ! -- Return
    return
  end function condmean

  !> @brief Calculate the the logarithmic mean of two double precision numbers
  !!
  !! Use an approximation if the ratio is near 1
  !<
  function logmean(d1, d2)
    ! -- return
    real(DP) :: logmean
    ! -- dummy
    real(DP), intent(in) :: d1
    real(DP), intent(in) :: d2
    ! -- local
    real(DP) :: drat
    !
    drat = d2 / d1
    if (drat <= DLNLOW .or. drat >= DLNHIGH) then
      logmean = (d2 - d1) / log(drat)
    else
      logmean = DHALF * (d1 + d2)
    end if
    !
    ! -- Return
    return
  end function logmean

  !> @brief Calculate the effective horizontal hydraulic conductivity from an
  !! ellipse using a specified direction (unit vector vg1, vg2, vg3)
  !!
  !! k11 is the hydraulic conductivity of the major ellipse axis
  !! k22 is the hydraulic conductivity of first minor axis
  !! k33 is the hydraulic conductivity of the second minor axis
  !! ang1 is the counter-clockwise rotation (radians) of the ellipse in
  !!   the (x, y) plane
  !! ang2 is the rotation of the conductivity ellipsoid upward or
  !!   downward from the (x, y) plane
  !! ang3 is the rotation of the conductivity ellipsoid about the major
  !!   axis
  !! vg1, vg2, and vg3 are the components of a unit vector in model coordinates
  !!   in the direction of the connection between cell n and m
  !!iavgmeth is the averaging method.  If zero, then use harmonic averaging.
  !!   if one, then use arithmetic averaging.
  !<
  function hyeff_calc(k11, k22, k33, ang1, ang2, ang3, vg1, vg2, vg3, &
                      iavgmeth) result(hyeff)
    ! -- modules
    use ConstantsModule, only: DONE
    ! -- return
    real(DP) :: hyeff
    ! -- dummy
    real(DP), intent(in) :: k11
    real(DP), intent(in) :: k22
    real(DP), intent(in) :: k33
    real(DP), intent(in) :: ang1
    real(DP), intent(in) :: ang2
    real(DP), intent(in) :: ang3
    real(DP), intent(in) :: vg1
    real(DP), intent(in) :: vg2
    real(DP), intent(in) :: vg3
    integer(I4B), intent(in) :: iavgmeth
    ! -- local
    real(DP) :: s1, s2, s3, c1, c2, c3
    real(DP), dimension(3, 3) :: r
    real(DP) :: ve1, ve2, ve3
    real(DP) :: denom, dnum, d1, d2, d3
    !
    ! -- Sin and cos of angles
    s1 = sin(ang1)
    c1 = cos(ang1)
    s2 = sin(ang2)
    c2 = cos(ang2)
    s3 = sin(ang3)
    c3 = cos(ang3)
    !
    ! -- Rotation matrix
    r(1, 1) = c1 * c2
    r(1, 2) = c1 * s2 * s3 - s1 * c3
    r(1, 3) = -c1 * s2 * c3 - s1 * s3
    r(2, 1) = s1 * c2
    r(2, 2) = s1 * s2 * s3 + c1 * c3
    r(2, 3) = -s1 * s2 * c3 + c1 * s3
    r(3, 1) = s2
    r(3, 2) = -c2 * s3
    r(3, 3) = c2 * c3
    !
    ! -- Unit vector in direction of n-m connection in a local coordinate
    !    system aligned with the ellipse axes
    ve1 = r(1, 1) * vg1 + r(2, 1) * vg2 + r(3, 1) * vg3
    ve2 = r(1, 2) * vg1 + r(2, 2) * vg2 + r(3, 2) * vg3
    ve3 = r(1, 3) * vg1 + r(2, 3) * vg2 + r(3, 3) * vg3
    !
    ! -- Effective hydraulic conductivity calculated using harmonic (1)
    !    or arithmetic (2) weighting
    hyeff = DZERO
    if (iavgmeth == 0) then
      !
      ! -- Arithmetic weighting.  If principal direction corresponds exactly with
      !    unit vector then set to principal direction.  Otherwise weight it.
      dnum = DONE
      d1 = ve1**2
      d2 = ve2**2
      d3 = ve3**2
      if (ve1 /= DZERO) then
        dnum = dnum * k11
        d2 = d2 * k11
        d3 = d3 * k11
      end if
      if (ve2 /= DZERO) then
        dnum = dnum * k22
        d1 = d1 * k22
        d3 = d3 * k22
      end if
      if (ve3 /= DZERO) then
        dnum = dnum * k33
        d1 = d1 * k33
        d2 = d2 * k33
      end if
      denom = d1 + d2 + d3
      if (denom > DZERO) hyeff = dnum / denom
    else if (iavgmeth == 1) then
      ! -- arithmetic
      hyeff = ve1**2 * k11 + ve2**2 * k22 + ve3**2 * k33
    end if
    !
    ! -- Return
    return
  end function hyeff_calc

  !> @brief Calculate the 3 conmponents of specific discharge at the cell center
  !<
  subroutine calc_spdis(this, flowja)
    ! -- modules
    use SimModule, only: store_error
    ! -- dummy
    class(GwfNpfType) :: this
    real(DP), intent(in), dimension(:) :: flowja
    ! -- local
    integer(I4B) :: n
    integer(I4B) :: m
    integer(I4B) :: ipos
    integer(I4B) :: isympos
    integer(I4B) :: ihc
    integer(I4B) :: ic
    integer(I4B) :: iz
    integer(I4B) :: nc
    integer(I4B) :: ncz
    real(DP) :: qz
    real(DP) :: vx
    real(DP) :: vy
    real(DP) :: vz
    real(DP) :: xn
    real(DP) :: yn
    real(DP) :: zn
    real(DP) :: xc
    real(DP) :: yc
    real(DP) :: zc
    real(DP) :: cl1
    real(DP) :: cl2
    real(DP) :: dltot
    real(DP) :: ooclsum
    real(DP) :: dsumx
    real(DP) :: dsumy
    real(DP) :: dsumz
    real(DP) :: denom
    real(DP) :: area
    real(DP) :: dz
    real(DP) :: axy
    real(DP) :: ayx
    real(DP), allocatable, dimension(:) :: vi
    real(DP), allocatable, dimension(:) :: di
    real(DP), allocatable, dimension(:) :: viz
    real(DP), allocatable, dimension(:) :: diz
    real(DP), allocatable, dimension(:) :: nix
    real(DP), allocatable, dimension(:) :: niy
    real(DP), allocatable, dimension(:) :: wix
    real(DP), allocatable, dimension(:) :: wiy
    real(DP), allocatable, dimension(:) :: wiz
    real(DP), allocatable, dimension(:) :: bix
    real(DP), allocatable, dimension(:) :: biy
    logical :: nozee = .true.
    !
    ! -- Ensure dis has necessary information
    if (this%icalcspdis /= 0 .and. this%dis%con%ianglex == 0) then
      call store_error('Error.  ANGLDEGX not provided in '// &
                       'discretization file.  ANGLDEGX required for '// &
                       'calculation of specific discharge.', terminate=.TRUE.)
    end if
    !
    ! -- Find max number of connections and allocate weight arrays
    nc = 0
    do n = 1, this%dis%nodes
      !
      ! -- Count internal model connections
      ic = this%dis%con%ia(n + 1) - this%dis%con%ia(n) - 1
      !
      ! -- Count edge connections
      do m = 1, this%nedges
        if (this%nodedge(m) == n) then
          ic = ic + 1
        end if
      end do
      !
      ! -- Set max number of connections for any cell
      if (ic > nc) nc = ic
    end do
    !
    ! -- Allocate storage arrays needed for cell-centered spdis calculation
    allocate (vi(nc))
    allocate (di(nc))
    allocate (viz(nc))
    allocate (diz(nc))
    allocate (nix(nc))
    allocate (niy(nc))
    allocate (wix(nc))
    allocate (wiy(nc))
    allocate (wiz(nc))
    allocate (bix(nc))
    allocate (biy(nc))
    !
    ! -- Go through each cell and calculate specific discharge
    do n = 1, this%dis%nodes
      !
      ! -- first calculate geometric properties for x and y directions and
      !    the specific discharge at a face (vi)
      ic = 0
      iz = 0
      vi(:) = DZERO
      di(:) = DZERO
      viz(:) = DZERO
      diz(:) = DZERO
      nix(:) = DZERO
      niy(:) = DZERO
      do ipos = this%dis%con%ia(n) + 1, this%dis%con%ia(n + 1) - 1
        m = this%dis%con%ja(ipos)
        isympos = this%dis%con%jas(ipos)
        ihc = this%dis%con%ihc(isympos)
        area = this%dis%con%hwva(isympos)
        if (ihc == 0) then
          !
          ! -- vertical connection
          iz = iz + 1
          !call this%dis%connection_normal(n, m, ihc, xn, yn, zn, ipos)
          call this%dis%connection_vector(n, m, nozee, this%sat(n), this%sat(m), &
                                          ihc, xc, yc, zc, dltot)
          cl1 = this%dis%con%cl1(isympos)
          cl2 = this%dis%con%cl2(isympos)
          if (m < n) then
            cl1 = this%dis%con%cl2(isympos)
            cl2 = this%dis%con%cl1(isympos)
          end if
          ooclsum = DONE / (cl1 + cl2)
          diz(iz) = dltot * cl1 * ooclsum
          qz = flowja(ipos)
          if (n > m) qz = -qz
          viz(iz) = qz / area
        else
          !
          ! -- horizontal connection
          ic = ic + 1
          dz = thksatnm(this%ibound(n), this%ibound(m), &
                        this%icelltype(n), this%icelltype(m), &
                        this%inewton, ihc, this%iusgnrhc, &
                        this%hnew(n), this%hnew(m), this%sat(n), this%sat(m), &
                        this%dis%top(n), this%dis%top(m), this%dis%bot(n), &
                        this%dis%bot(m), this%satomega, this%satmin)
          area = area * dz
          call this%dis%connection_normal(n, m, ihc, xn, yn, zn, ipos)
          call this%dis%connection_vector(n, m, nozee, this%sat(n), this%sat(m), &
                                          ihc, xc, yc, zc, dltot)
          cl1 = this%dis%con%cl1(isympos)
          cl2 = this%dis%con%cl2(isympos)
          if (m < n) then
            cl1 = this%dis%con%cl2(isympos)
            cl2 = this%dis%con%cl1(isympos)
          end if
          ooclsum = DONE / (cl1 + cl2)
          nix(ic) = -xn
          niy(ic) = -yn
          di(ic) = dltot * cl1 * ooclsum
          if (area > DZERO) then
            vi(ic) = flowja(ipos) / area
          else
            vi(ic) = DZERO
          end if
        end if
      end do
      !
      ! -- Look through edge flows that may have been provided by an exchange
      !    and incorporate them into the averaging arrays
      do m = 1, this%nedges
        if (this%nodedge(m) == n) then
          !
          ! -- propsedge: (Q, area, nx, ny, distance)
          ihc = this%ihcedge(m)
          area = this%propsedge(2, m)
          if (ihc == 0) then
            iz = iz + 1
            viz(iz) = this%propsedge(1, m) / area
            diz(iz) = this%propsedge(5, m)
          else
            ic = ic + 1
            nix(ic) = -this%propsedge(3, m)
            niy(ic) = -this%propsedge(4, m)
            di(ic) = this%propsedge(5, m)
            if (area > DZERO) then
              vi(ic) = this%propsedge(1, m) / area
            else
              vi(ic) = DZERO
            end if
          end if
        end if
      end do
      !
      ! -- Assign number of vertical and horizontal connections
      ncz = iz
      nc = ic
      !
      ! -- calculate z weight (wiz) and z velocity
      if (ncz == 1) then
        wiz(1) = DONE
      else
        dsumz = DZERO
        do iz = 1, ncz
          dsumz = dsumz + diz(iz)
        end do
        denom = (ncz - DONE)
        if (denom < DZERO) denom = DZERO
        dsumz = dsumz + DEM10 * dsumz
        do iz = 1, ncz
          if (dsumz > DZERO) wiz(iz) = DONE - diz(iz) / dsumz
          if (denom > 0) then
            wiz(iz) = wiz(iz) / denom
          else
            wiz(iz) = DZERO
          end if
        end do
      end if
      vz = DZERO
      do iz = 1, ncz
        vz = vz + wiz(iz) * viz(iz)
      end do
      !
      ! -- distance-based weighting
      nc = ic
      dsumx = DZERO
      dsumy = DZERO
      dsumz = DZERO
      do ic = 1, nc
        wix(ic) = di(ic) * abs(nix(ic))
        wiy(ic) = di(ic) * abs(niy(ic))
        dsumx = dsumx + wix(ic)
        dsumy = dsumy + wiy(ic)
      end do
      !
      ! -- Finish computing omega weights.  Add a tiny bit
      !    to dsum so that the normalized omega weight later
      !    evaluates to (essentially) 1 in the case of a single
      !    relevant connection, avoiding 0/0.
      dsumx = dsumx + DEM10 * dsumx
      dsumy = dsumy + DEM10 * dsumy
      do ic = 1, nc
        wix(ic) = (dsumx - wix(ic)) * abs(nix(ic))
        wiy(ic) = (dsumy - wiy(ic)) * abs(niy(ic))
      end do
      !
      ! -- compute B weights
      dsumx = DZERO
      dsumy = DZERO
      do ic = 1, nc
        bix(ic) = wix(ic) * sign(DONE, nix(ic))
        biy(ic) = wiy(ic) * sign(DONE, niy(ic))
        dsumx = dsumx + wix(ic) * abs(nix(ic))
        dsumy = dsumy + wiy(ic) * abs(niy(ic))
      end do
      if (dsumx > DZERO) dsumx = DONE / dsumx
      if (dsumy > DZERO) dsumy = DONE / dsumy
      axy = DZERO
      ayx = DZERO
      do ic = 1, nc
        bix(ic) = bix(ic) * dsumx
        biy(ic) = biy(ic) * dsumy
        axy = axy + bix(ic) * niy(ic)
        ayx = ayx + biy(ic) * nix(ic)
      end do
      !
      ! -- Calculate specific discharge.  The divide by zero checking below
      !    is problematic for cells with only one flow, such as can happen
      !    with triangular cells in corners.  In this case, the resulting
      !    cell velocity will be calculated as zero.  The method should be
      !    improved so that edge flows of zero are included in these
      !    calculations.  But this needs to be done with consideration for LGR
      !    cases in which flows are submitted from an exchange.
      vx = DZERO
      vy = DZERO
      do ic = 1, nc
        vx = vx + (bix(ic) - axy * biy(ic)) * vi(ic)
        vy = vy + (biy(ic) - ayx * bix(ic)) * vi(ic)
      end do
      denom = DONE - axy * ayx
      if (denom /= DZERO) then
        vx = vx / denom
        vy = vy / denom
      end if
      !
      this%spdis(1, n) = vx
      this%spdis(2, n) = vy
      this%spdis(3, n) = vz
      !
    end do
    !
    ! -- cleanup
    deallocate (vi)
    deallocate (di)
    deallocate (nix)
    deallocate (niy)
    deallocate (wix)
    deallocate (wiy)
    deallocate (wiz)
    deallocate (bix)
    deallocate (biy)
    !
    ! -- Return
    return
  end subroutine calc_spdis

  !> @brief Save specific discharge in binary format to ibinun
  !<
  subroutine sav_spdis(this, ibinun)
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: ibinun
    ! -- local
    character(len=16) :: text
    character(len=16), dimension(3) :: auxtxt
    integer(I4B) :: n
    integer(I4B) :: naux
    !
    ! -- Write the header
    text = '      DATA-SPDIS'
    naux = 3
    auxtxt(:) = ['              qx', '              qy', '              qz']
    call this%dis%record_srcdst_list_header(text, this%name_model, &
                                            this%packName, this%name_model, &
                                            this%packName, naux, auxtxt, ibinun, &
                                            this%dis%nodes, this%iout)
    !
    ! -- Write a zero for Q, and then write qx, qy, qz as aux variables
    do n = 1, this%dis%nodes
      call this%dis%record_mf6_list_entry(ibinun, n, n, DZERO, naux, &
                                          this%spdis(:, n))
    end do
    !
    ! -- Return
    return
  end subroutine sav_spdis

  !> @brief Save saturation in binary format to ibinun
  !<
  subroutine sav_sat(this, ibinun)
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: ibinun
    ! -- local
    character(len=16) :: text
    character(len=16), dimension(1) :: auxtxt
    real(DP), dimension(1) :: a
    integer(I4B) :: n
    integer(I4B) :: naux
    !
    ! -- Write the header
    text = '        DATA-SAT'
    naux = 1
    auxtxt(:) = ['             sat']
    call this%dis%record_srcdst_list_header(text, this%name_model, &
                                            this%packName, this%name_model, &
                                            this%packName, naux, auxtxt, ibinun, &
                                            this%dis%nodes, this%iout)
    !
    ! -- Write a zero for Q, and then write saturation as an aux variables
    do n = 1, this%dis%nodes
      a(1) = this%sat(n)
      call this%dis%record_mf6_list_entry(ibinun, n, n, DZERO, naux, a)
    end do
    !
    ! -- Return
    return
  end subroutine sav_sat

  !> @brief Reserve space for nedges cells that have an edge on them.
  !!
  !! This must be called before the npf%allocate_arrays routine, which is
  !! called from npf%ar.
  !<
  subroutine increase_edge_count(this, nedges)
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: nedges
    !
    this%nedges = this%nedges + nedges
    !
    ! -- Return
    return
  end subroutine increase_edge_count

  !> @brief Provide the npf package with edge properties
  !<
  subroutine set_edge_properties(this, nodedge, ihcedge, q, area, nx, ny, &
                                 distance)
    ! -- dummy
    class(GwfNpfType) :: this
    integer(I4B), intent(in) :: nodedge
    integer(I4B), intent(in) :: ihcedge
    real(DP), intent(in) :: q
    real(DP), intent(in) :: area
    real(DP), intent(in) :: nx
    real(DP), intent(in) :: ny
    real(DP), intent(in) :: distance
    ! -- local
    integer(I4B) :: lastedge
    !
    this%lastedge = this%lastedge + 1
    lastedge = this%lastedge
    this%nodedge(lastedge) = nodedge
    this%ihcedge(lastedge) = ihcedge
    this%propsedge(1, lastedge) = q
    this%propsedge(2, lastedge) = area
    this%propsedge(3, lastedge) = nx
    this%propsedge(4, lastedge) = ny
    this%propsedge(5, lastedge) = distance
    !
    ! -- If this is the last edge, then the next call must be starting a new
    !    edge properties assignment loop, so need to reset lastedge to 0
    if (this%lastedge == this%nedges) this%lastedge = 0
    !
    ! -- Return
    return
  end subroutine set_edge_properties

  !> Calculate saturated thickness between cell n and m
  !<
  function calcSatThickness(this, n, m, ihc) result(satThickness)
    ! -- dummy
    class(GwfNpfType) :: this !< this NPF instance
    integer(I4B) :: n !< node n
    integer(I4B) :: m !< node m
    integer(I4B) :: ihc !< 1 = horizonal connection, 0 for vertical
    ! -- return
    real(DP) :: satThickness !< saturated thickness
    !
    satThickness = thksatnm(this%ibound(n), &
                            this%ibound(m), &
                            this%icelltype(n), &
                            this%icelltype(m), &
                            this%inewton, &
                            ihc, &
                            this%iusgnrhc, &
                            this%hnew(n), &
                            this%hnew(m), &
                            this%sat(n), &
                            this%sat(m), &
                            this%dis%top(n), &
                            this%dis%top(m), &
                            this%dis%bot(n), &
                            this%dis%bot(m), &
                            this%satomega, &
                            this%satmin)
    !
    ! -- Return
    return
  end function calcSatThickness

  !> @brief Calculate saturated thickness at interface between two cells
  !<
  function thksatnm(ibdn, ibdm, ictn, ictm, inwtup, ihc, iusg, &
                    hn, hm, satn, satm, topn, topm, botn, botm, &
                    satomega, satminopt) result(res)
    ! -- return
    real(DP) :: res
    ! -- dummy
    integer(I4B), intent(in) :: ibdn
    integer(I4B), intent(in) :: ibdm
    integer(I4B), intent(in) :: ictn
    integer(I4B), intent(in) :: ictm
    integer(I4B), intent(in) :: inwtup
    integer(I4B), intent(in) :: ihc
    integer(I4B), intent(in) :: iusg
    real(DP), intent(in) :: hn
    real(DP), intent(in) :: hm
    real(DP), intent(in) :: satn
    real(DP), intent(in) :: satm
    real(DP), intent(in) :: topn
    real(DP), intent(in) :: topm
    real(DP), intent(in) :: botn
    real(DP), intent(in) :: botm
    real(DP), intent(in) :: satomega
    real(DP), optional, intent(in) :: satminopt
    ! -- local
    integer(I4B) :: indk
    real(DP) :: satmin
    real(DP) :: sn
    real(DP) :: sm
    real(DP) :: thksatn
    real(DP) :: thksatm
    real(DP) :: sill_top, sill_bot
    real(DP) :: tpn, tpm
    real(DP) :: top, bot
    !
    if (present(satminopt)) then
      satmin = satminopt
    else
      satmin = DZERO
    end if
    !
    ! -- If either n or m is inactive then saturated thickness is zero
    if (ibdn == 0 .or. ibdm == 0) then
      res = DZERO
      !
      ! -- if both cells are non-convertible then use average cell thickness
    elseif (ictn == 0 .and. ictm == 0) then
      thksatn = topn - botn
      thksatm = topm - botm
      !
      ! -- If staggered connection, subtract parts of cell that are above and
      !    below the sill top and bottom elevations
      if (ihc == 2) then
        !
        ! -- Calculate sill_top and sill_bot
        sill_top = min(topn, topm)
        sill_bot = max(botn, botm)
        !
        ! -- Saturated thickness is sill_top - sill_bot
        thksatn = max(sill_top - sill_bot, DZERO)
        thksatm = thksatn
      end if
      !
      res = DHALF * (thksatn + thksatm)
      !
      ! -- At least one of the cells is convertible, so calculate average saturated
      !    thickness
    else
      if (inwtup == 1) then
        ! -- set flag used to determine if bottom of cells n and m are
        !    significantly different
        indk = 0
        if (abs(botm - botn) < DEM2) indk = 1
        ! -- recalculate saturation if using MODFLOW-USG saturation
        !    calculation approach
        if (iusg == 1 .and. indk == 0) then
          if (botm > botn) then
            top = topm
            bot = botm
          else
            top = topn
            bot = botn
          end if
          sn = sQuadraticSaturation(top, bot, hn, satomega, satmin)
          sm = sQuadraticSaturation(top, bot, hm, satomega, satmin)
        else
          sn = sQuadraticSaturation(topn, botn, hn, satomega, satmin)
          sm = sQuadraticSaturation(topm, botm, hm, satomega, satmin)
        end if
        !
        ! -- upstream weight the thickness
        if (hn > hm) then
          res = sn * (topn - botn)
        else
          res = sm * (topm - botm)
        end if
        !
      else
        thksatn = satn * (topn - botn)
        thksatm = satm * (topm - botm)
        !
        ! -- If staggered connection, subtract parts of cell that are above and
        !    below the sill top and bottom elevations
        if (ihc == 2) then
          !
          ! -- Calculate sill_top and sill_bot
          sill_top = min(topn, topm)
          sill_bot = max(botn, botm)
          !
          ! -- Calculate tpn and tpm
          tpn = botn + thksatn
          tpm = botm + thksatm
          !
          ! -- Calculate saturated thickness for cells n and m
          thksatn = max(min(tpn, sill_top) - sill_bot, DZERO)
          thksatm = max(min(tpm, sill_top) - sill_bot, DZERO)
        end if
        !
        res = DHALF * (thksatn + thksatm)
      end if
    end if
    !
    ! -- Return
    return
  end function thksatnm

end module GwfNpfModule
