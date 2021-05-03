#! /bin/bash
#source ~/privat/bin/setpaths
#set_up CTSM
# create case brazil
#$CTSM_ROOT/cime/scripts/create_newcase --case ./test_sunnivin_ozone_lombardozzi_brazil --res 1x1_brazil --compset 2000_DATM%GSWP3v1_CLM50%BGC_SICE_SOCN_SROF_SGLC_SWAV --machine saga --run-unsupported

usage() { echo "./set_up_singlepoint_case_2000.sh [--ozone | --ozone_luna] [--o3_conc=100] [--hydrstress=False] [--postad --restartfile | --production --restartfile] <case directory> "; exit 1; }

check_null()
{
    if [ $# -eq 0 ]; then
        echo "No arguments provided!"
        usage
        exit 1
    fi
}

options()
{
    CLM_CASE=${@: -1}
    while [ "${1}" != "" ]; do
        
        case $1 in
            --ozone )
                use_ozone=true
                echo "use_ozone: ${use_ozone}"
                echo "Set Case: $CLM_CASE"
                ;;
            --ozone_luna )
                use_ozone_luna=true
                echo "use_ozone_luna: ${use_ozone_luna}"
                echo "Set Case: $CLM_CASE"
                ;;
            --o3_conc )
                shift
                O3_CONC=${1}
                echo "Ozone concentration: ${O3_CONC}"
                ;;
            --hydrstress )
                use_hydrstress=false
                echo "use_hydrstress: ${use_hydrstress}"
                echo "Set Case: $CLM_CASE"
                ;;
            --postad )
                use_postad=true
                echo "use post AD mode: ${use_postad}"
                ;;
            --production )
                use_production=true
                echo "use production mode: ${use_production}"
                ;;
            --restartfile )
                shift
                restart_file=${1}
                echo "restart file: ${restart_file}"
                ;;
            -h | --help )
                usage
                exit
                ;;
            * )
                echo "Case directory: ${1}"
                CLM_CASE=${1}
                ;;
        esac
        shift
    done
}

set_namelist () {

    echo "Change to $CLM_CASE"
    cd $CLM_CASE

    echo "Customize namelists"
    ./xmlchange CLM_FORCE_COLDSTART="on"
    ./xmlchange CLM_NML_USE_CASE="2000_control"
    ./xmlchange DATM_CLMNCEP_YR_START="1991"
    ./xmlchange DATM_CLMNCEP_YR_END="2010"
    ./xmlchange DATM_PRESAERO="clim_2000"
    ./xmlchange CCSM_CO2_PPMV="369."
    ./xmlchange STOP_OPTION="nyears"
    ./xmlchange RUN_REFDATE="0001-01-01"
    ./xmlchange RUN_STARTDATE="0001-01-01"
    # Additional xml changes for AD mode
    ./xmlchange CLM_ACCELERATED_SPINUP="on"
    # Number of years for spin-up 
    # STOP_N=400 =>1 week CPU time
    # Test shows that for this set-up only STOP_N=100 is needed!
    #./xmlchange STOP_N=100
    ./xmlchange STOP_N=5
    # Frequency of restart files (1/4 of STOP_N)
    #./xmlchange REST_N=25
    ./xmlchange REST_N=1
    # Setting wall clock time
    ./xmlchange --subgroup case.st_archive JOB_WALLCLOCK_TIME=01:00:00


    ./case.setup
    ./preview_namelists

    # Settings for bgc mode. 
    # For more see $CTSM_ROOT/bld/namelist_files/namelist_defaults_clm4_5.xml
    # Frequency of history files (these are already standard)
    echo "hist_mfilt = 20" >> user_nl_clm
    echo "hist_nhtfrq = -8760" >> user_nl_clm
    # adding this to user_nl_clm for AD simulations to reduce variables written out to .h0. files.
    echo "hist_empty_htapes = .true." >> user_nl_clm
    # Special output 
    if [ $use_ozone_luna ]; then
        echo "hist_fincl1 = 'TOTECOSYSC', 'TOTECOSYSN', 'TOTSOMC', 'TOTSOMN', 'TOTVEGC', 'TOTVEGN', 'TLAI', 'GPP', 'CPOOL', 'NPP', 'TWS', 'O3UPTAKESUN', 'O3UPTAKESHA', 'O3COEFJMAXSUN', 'O3COEFJMAXSHA'" >> user_nl_clm
    else 
        echo "hist_fincl1 = 'TOTECOSYSC', 'TOTECOSYSN', 'TOTSOMC', 'TOTSOMN', 'TOTVEGC', 'TOTVEGN', 'TLAI', 'GPP', 'CPOOL', 'NPP', 'TWS'" >> user_nl_clm
    fi

    # And add this to user_nl_datm
    echo "mapalgo = 'nn','nn','nn','nn','nn'" >> user_nl_datm
}

set_namelist_postad () {

    echo "Change to $CLM_CASE"
    cd $CLM_CASE

    echo "Set namelists for post AD."
    # Switch off cold start
    ./xmlchange CLM_FORCE_COLDSTART="off"
    ./xmlchange CONTINUE_RUN="FALSE"
    # Re-use directory but re-define reference time
    ./xmlchange RUN_REFDATE="0401-01-01"
    ./xmlchange RUN_STARTDATE="0401-01-01"
    # Additional xml changes for AD mode
    ./xmlchange CLM_ACCELERATED_SPINUP="off"
    
    ./xmlchange STOP_N=100
    # Frequency of restart files (1/4 of STOP_N)
    ./xmlchange REST_N=25

    ./case.setup

    # Point to restart file (IMPORTANT: Do not forget the single-quotationmarks '<path to restart file>')
    echo "finidat = '${restart_file}'" >> user_nl_clm
    echo "Restart file: ${restart_file}"

}

set_namelist_production () {
    echo "Change to $CLM_CASE"
    cd $CLM_CASE

    echo "Set namelists for production."
    # Switch off cold start
    ./xmlchange CLM_FORCE_COLDSTART="off"
    ./xmlchange CONTINUE_RUN="FALSE"
    ./xmlchange CLM_ACCELERATED_SPINUP="off"

    ./xmlchange CLM_NML_USE_CASE="2000_control"
    ./xmlchange RUN_TYPE=startup
    ./xmlchange DATM_CLMNCEP_YR_ALIGN=2000
    ./xmlchange DATM_CLMNCEP_YR_START="2000"
    ./xmlchange DATM_CLMNCEP_YR_END="2010"
    ./xmlchange DATM_PRESAERO="clim_2000"
    ./xmlchange CCSM_CO2_PPMV="369."

    ./xmlchange STOP_OPTION="nyears"
    ./xmlchange RUN_REFDATE="2000-01-01"
    ./xmlchange RUN_STARTDATE="2000-01-01"

    ./xmlchange STOP_N=10
    # Frequency of restart files (1/4 of STOP_N)
    ./xmlchange REST_N=2

    ./case.setup
    ./preview_namelists

    # And add this to user_nl_datm
    echo "mapalgo = 'nn','nn','nn','nn','nn'" >> user_nl_datm

    # Frequency of history files hourly every day
    echo "hist_mfilt = 24" >> user_nl_clm
    echo "hist_nhtfrq = -24" >> user_nl_clm

    # adding this to user_nl_clm for AD simulations to reduce variables written out to .h0. files.
    echo "hist_empty_htapes = .true." >> user_nl_clm

    # Point to restart file (IMPORTANT: Do not forget the single-quotationmarks '<path to restart file>')
    echo "finidat = '${restart_file}'" >> user_nl_clm
    echo "Restart file: ${restart_file}"

   
    if [ $use_ozone ]; then
        echo "hist_fincl1 = 'TOTECOSYSC', 'TOTECOSYSN', 'TOTSOMC', 'TOTSOMN', 'TOTVEGC', 'TOTVEGN', 'TLAI', 'GPP', 'CPOOL', 'NPP', 'TWS', 'O3UPTAKESUN', 'O3UPTAKESHA', 'PSNSUN', 'PSNSHA', 'RSSUN', 'RSSHA', 'GSSUN', 'GSSHA', 'Vcmx25Z', 'Jmx25Z', 'VCMX25T', 'JMX25T'" >> user_nl_clm

    elif [ $use_ozone_luna ]; then
        echo "hist_fincl1 = 'TOTECOSYSC', 'TOTECOSYSN', 'TOTSOMC', 'TOTSOMN', 'TOTVEGC', 'TOTVEGN', 'TLAI', 'GPP', 'CPOOL', 'NPP', 'TWS', 'O3UPTAKESUN', 'O3UPTAKESHA', 'O3COEFJMAXSUN', 'O3COEFJMAXSHA', 'PSNSUN', 'PSNSHA', 'RSSUN', 'RSSHA', 'GSSUN', 'GSSHA', 'Vcmx25Z', 'Jmx25Z', 'VCMX25T', 'JMX25T'" >> user_nl_clm    
    else
        echo "hist_fincl1 = 'TOTECOSYSC', 'TOTECOSYSN', 'TOTSOMC', 'TOTSOMN', 'TOTVEGC', 'TOTVEGN', 'TLAI', 'GPP', 'CPOOL', 'NPP', 'TWS','PSNSUN', 'PSNSHA', 'RSSUN', 'RSSHA', 'GSSUN', 'GSSHA', 'Vcmx25Z', 'Jmx25Z', 'VCMX25T', 'JMX25T'" >> user_nl_clm
    fi
}

# For using ozone add
set_ozone() {
    
    if [ $use_ozone ]; then
        echo "Setting ozone... $use_ozone"
        echo "ozone_method = 'stress_lombardozzi2015'" >> user_nl_clm
        
    elif [ $use_ozone_luna ]; then
        echo "Setting ozone_luna... $use_ozone_luna"
        echo "ozone_method = 'stress_falk'" >> user_nl_clm
    fi
    # Set constant ozone forcing if defined else default value will be used
    if [ ${O3_CONC} ]; then
        # dosn't work ./xmlchange CCSM_O3_PPBV="${O3_CONC}"
        echo "o3_ppbv = ${O3_CONC}" >> user_nl_clm
    fi
}

unset_hydrstress() {
    if [ $use_hydrstress ]; then
        echo "Unsetting hydrstress... $use_hydrstress"
        echo "use_hydrstress = .false." >> user_nl_clm
    fi
}

# MAIN

check_null $@

options $@

# Test for given case directory
if [ -z "${CLM_CASE}" ]; then
    echo "Error: No case specified."
    exit
fi


echo "post_ad: $use_postad"
if [ $use_postad ]; then
    set_namelist_postad
elif [ $use_production ]; then
    set_namelist_production
else
    set_namelist
fi

set_ozone

unset_hydrstress

exit
