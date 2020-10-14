#!/usr/bin/env bash

run_idx_low=$1
run_idx_high=$2
n_nodes=$3
results_root=$4

#echo "sourcing"
#source ./lsf_kae_paths.config
source ./example_paths.config
#echo "done"

# Convenience function for making the dependency lists for the kernel distance
# time series job
#function join_by { local IFS="$1"; shift; echo "$*"; }
function join_by { local d=$1; shift; local f=$1; shift; printf %s "$f" "${@/#/$d}"; }

#proc_placement=("pack" "spread")
#run_scales=(11 21 41 81)
#message_sizes=(1 512 1024 2048)

#proc_placement=("pack")
#run_scales=(11)
#message_sizes=(1)

#proc_placement=("pack" "spread")
#run_scales=(36)
#interleave_options=("non_interleaved" "interleaved")

#proc_placement=("pack", "spread")
proc_placement=("pack")
run_scales=(32)
#interleave_options=("non_interleaved")
interleave_options=("interleaved" "non_interleaved")


#echo "before the loops"
for proc_placement in ${proc_placement[@]};
do
    for n_procs in ${run_scales[@]};
    do
        for option in ${interleave_options[@]};
        do
            echo "Launching jobs for: proc. placement = ${proc_placement}, # procs. = ${n_procs}, interleaving?  ${option}"
            runs_root=${results_root}/n_procs_${n_procs}/proc_placement_${proc_placement}/interleave_option_${option}/

            # Launch intra-execution jobs
            kdts_job_deps=()
            for run_idx in `seq -f "%03g" ${run_idx_low} ${run_idx_high}`; 
            do

                # Set up results dir
                run_dir=${runs_root}/run_${run_idx}/
                mkdir -p ${run_dir}
                cd ${run_dir}
#		echo "Entering submission of generator"
 
		# Trace execution
                config=${anacin_x_root}/apps/comm_pattern_generator/config/mini_mcb_grid_example_${option}.json
                if [ ${proc_placement} == "pack" ]; then
                    #n_nodes_trace=$(echo "(${n_procs} + ${n_procs_per_node} - 1)/${n_procs_per_node}" | bc)
                    trace_stdout=$( bsub -R "span[ptile=16]" -o ${a_output} -e ${a_error} ${job_script_trace_pack_procs} ${n_procs} ${app} ${config} )
                elif [ ${proc_placement} == "spread" ]; then
                    n_nodes_trace=${n_procs}
                    trace_stdout=$( bsub -nnodes ${n_nodes_trace} ${job_script_trace_spread_procs} ${n_procs} ${app} ${config} )
                fi
                trace_job_id=$( echo ${trace_stdout} | sed 's/[^0-9]*//g' )
#		echo "$trace_job_id is the id for this run of the tracer."
                
		# Build event graph
                #n_nodes_build_graph=$(echo "(${n_procs} + ${n_procs_per_node} - 1)/${n_procs_per_node}" | bc)
		#ptile_arg=$(echo "${n_procs} / ${n_nodes}" | bc)
                build_graph_stdout=$( bsub -R  "span[ptile=16]" -w "done(${trace_job_id})" ${job_script_build_graph} ${n_procs} ${dumpi_to_graph_bin} ${dumpi_to_graph_config} ${run_dir} )
                build_graph_job_id=$( echo ${build_graph_stdout} | sed 's/[^0-9]*//g' )
                event_graph=${run_dir}/event_graph.graphml
#		echo "exiting graph build"
                
		# Extract slices
                extract_slices_stdout=$( bsub -R "span[ptile=16]" "done(${build_graph_job_id})" ${job_script_extract_slices} ${n_procs_extract_slices} ${extract_slices_script} ${event_graph} ${slicing_policy} )
                extract_slices_job_id=$( echo ${extract_slices_stdout} | sed 's/[^0-9]*//g' ) 
                kdts_job_deps+=("done(${extract_slices_job_id})")
#		echo "exiting slice extraction"

            done # runs
#	    echo "entering kdts"
            
	    # Compute kernel distances for each slice
            kdts_job_dep_str=$( join_by "&&" ${kdts_job_deps[@]} )
            cd ${runs_root}
            compute_kdts_stdout=$( bsub -R "span[ptile=16]" -w ${kdts_job_dep_str} ${job_script_compute_kdts} ${n_procs_compute_kdts} ${compute_kdts_script} ${runs_root} ${graph_kernel} )
#	    echo "exiting kdts"        
	    #compute_kdts_stdout=$( sbatch -N${n_nodes_compute_kdts} ${job_script_compute_kdts} ${n_procs_compute_kdts} ${compute_kdts_script} ${runs_root} ${graph_kernel} )
            compute_kdts_job_id=$( echo ${compute_kdts_stdout} | sed 's/[^0-9]*//g' )
#	    echo "job id calc"
 
            ## Generate plot
            #make_plot_stdout=$( sbatch -N1 --dependency=afterok:${compute_kdts_job_id} ${job_script_make_plot} ${make_plot_script_mini_mcb} "${runs_root}/kdts.pkl" )
            ##make_plot_stdout=$( sbatch -N1 ${job_script_make_plot} ${make_plot_script_mini_mcb} "${runs_root}/kdts.pkl" )

        done # msg sizes
    done # num procs
done # proc placement
