#!/usr/bin/env bash

n_procs=$1
n_iters=$2
msg_size=$3
n_nodes=$4
run_idx_low=$5
run_idx_high=$6
results_root=$7
example_paths_dir=$8
x_procs=$9
y_procs=${10}
z_procs=${11}
nd_start=${12}
nd_iter=${13}
nd_end=${14}
nd_neighbor_fraction=${15}

#echo "Starting runs of Unstructured Mesh communication pattern."
source ${example_paths_dir}/example_paths_unscheduled.config
#example_paths_dir=$(pwd)

# Convenience function for making the dependency lists for the kernel distance
# time series job
#function join_by { local IFS="$1"; shift; echo "$*"; }
#function join_by { local d=$1; shift; local f=$1; shift; printf %s "$f" "${@/#/$d}"; }

#proc_placement=("pack" "spread")
proc_placement=("pack")
#run_scales=(64)
#message_sizes=(512)
#nd_neighbor_fractions=("0" "0.25" "0.5" "0.75" "1")
#nd_neighbor_fractions=("0")

for proc_placement in ${proc_placement[@]};
do
    #    for n_procs in ${run_scales[@]};
    #    do
#    for nd_neighbor_fraction in ${nd_neighbor_fractions[@]};
#    do
	#            for msg_size in ${message_sizes[@]};
	#            do
        #echo "Launching jobs for: proc. placement = ${proc_placement}, # procs. = ${n_procs}, neighbor non-determinism fraction = ${nd_neighbor_fraction}, msg. size = ${msg_size}"
        runs_root=${results_root}/msg_size_${msg_size}/n_procs_${n_procs}/n_iters_${n_iters}/ndp_${nd_start}_${nd_iter}_${nd_end}/proc_placement_${proc_placement}/neighbor_nd_fraction_${nd_neighbor_fraction}/

        # Launch intra-execution jobs
        kdts_job_deps=()
        for run_idx in `seq -f "%03g" ${run_idx_low} ${run_idx_high}`; 
        do

            echo "Starting run ${run_idx} of Unstructured Mesh communication pattern with nd neighbor fraction = ${nd_neighbor_fraction}."

	    # Set up results dir
            run_dir=${runs_root}/run_${run_idx}
            mkdir -p ${run_dir}
	    debugging_path=${run_dir}/debug
	    mkdir -p ${debugging_path}
            cd ${run_dir}
            
            # Determine proc grid
            #if [ ${n_procs} == 64 ]; then
            proc_grid="${x_procs}x${y_procs}x${z_procs}"
            #else
            #    echo "Invalid # procs: ${n_procs}"
            #    exit
            #fi

	    #echo "Starting Trace Execution"
            # Create config if doesn't exist
#            config=${anacin_x_root}/apps/comm_pattern_generator/config/unstructured_mesh_${proc_grid}_nd_neighbor_fraction_${nd_neighbor_fraction}_msg_size_${msg_size}.json
	    config=${anacin_x_root}/apps/comm_pattern_generator/config/unstructured_mesh_${proc_grid}_nd_neighbor_fraction_${nd_neighbor_fraction}_msg_size_${msg_size}_niters_${n_iters}_ndp_${nd_start}_${nd_iter}_${nd_end}.json
	    if [ ! -f "config" ]; then
		old_dir=$PWD
		cd ${anacin_x_root}/apps/comm_pattern_generator/config
                #echo "Creating config file for message size ${msg_size}"
		#echo "                         iteration count ${n_iters}"
		#echo "                         nd neighbor fraction ${nd_neighbor_fraction}"
		#echo "                         coordinates ${x_procs}x${y_procs}x${z_procs}"
		python3 > ${debugging_path}/create_json_output.txt 2> ${debugging_path}/create_json_error.txt ${anacin_x_root}/apps/comm_pattern_generator/config/json_gen.py "unstructured_mesh" ${nd_neighbor_fraction} ${x_procs} ${y_procs} ${z_procs} ${msg_size} ${n_iters} "${example_paths_dir}/../" ${nd_start} ${nd_iter} ${nd_end}
		cd ${old_dir}
	    fi
	    
	    # Trace execution
	    #n_procs_per_node=$((n_procs/n_nodes))
            #if [ ${proc_placement} == "pack" ]; then
                #n_nodes_trace=$(echo "(${n_procs} + ${n_procs_per_node} - 1)/${n_procs_per_node}" | bc)
            #    trace_stdout=$( bsub -n ${n_procs} -R "span[ptile=${n_procs_per_node}]" -o ${debugging_path}/trace_exec_output.txt -e ${debugging_path}/trace_exec_error.txt ${job_script_trace_pack_procs} ${n_procs} ${app} ${config} )
            #elif [ ${proc_placement} == "spread" ]; then
            #    n_nodes_trace=${n_procs}
            #    trace_stdout=$( bsub -nnodes ${n_nodes_trace} ${job_script_trace_spread_procs} ${n_procs} ${app} ${config} )
            #fi
            #trace_job_id=$( echo ${trace_stdout} | sed 's/[^0-9]*//g' )
	    #echo "Tracing communiction pattern on run ${run_idx} and nd neighbor fraction ${nd_neighbor_fraction}"
	    bash > ${debugging_path}/trace_exec_output.txt 2> ${debugging_path}/trace_exec_error.txt ${job_script_trace_pack_procs} ${n_procs} ${app} ${config} ${example_paths_dir}

	    #echo "Starting Build Event Graph"
            # Build event graph
            #n_nodes_build_graph=$(echo "(${n_procs} + ${n_procs_per_node} - 1)/${n_procs_per_node}" | bc)
            #build_graph_stdout=$( bsub -n ${n_procs} -R "span[ptile=${n_procs_per_node}]" -w "done(${trace_job_id})" -o ${debugging_path}/build_graph_output.txt -e ${debugging_path}/build_graph_error.txt ${job_script_build_graph} ${n_procs} ${dumpi_to_graph_bin} ${dumpi_to_graph_config} ${run_dir} )
            #echo "Build the event graph on run ${run_idx} and nd neighbor fraction ${nd_neighbor_fraction}"
	    bash > ${debugging_path}/build_graph_output.txt 2> ${debugging_path}/build_graph_error.txt ${job_script_build_graph} ${n_procs} ${dumpi_to_graph_bin} ${dumpi_to_graph_config} ${run_dir} 
	    #build_graph_job_id=$( echo ${build_graph_stdout} | sed 's/[^0-9]*//g' )
            event_graph=${run_dir}/event_graph.graphml

	    #echo "Starting Extract Slices"
            # Extract slices
            #extract_slices_stdout=$( bsub -n ${n_procs} -R "span[ptile=${n_procs_per_node}]" -w "done(${build_graph_job_id})" -o ${debugging_path}/extract_slices_output.txt -e ${debugging_path}/extract_slices_error.txt ${job_script_extract_slices} ${n_procs_extract_slices} ${extract_slices_script} ${event_graph} ${slicing_policy} )
	    #echo "preslice"
	    #echo "Extract event graph slices on run ${run_idx} and nd neighbor fraction ${nd_neighbor_fraction}" 
	    bash > ${debugging_path}/extract_slices_output.txt 2> ${debugging_path}/extract_slices_error.txt ${job_script_extract_slices} ${n_procs_extract_slices} ${extract_slices_script} ${event_graph} ${slicing_policy} 
	    #echo "postslice"
	    #extract_slices_job_id=$( echo ${extract_slices_stdout} | sed 's/[^0-9]*//g' ) 
            #kdts_job_deps+=("done(${extract_slices_job_id})")
        done # runs

	#echo "Start Computing Kernel Distances"
        # Compute kernel distances for each slice
        #kdts_job_dep_str=$( join_by "&&" ${kdts_job_deps[@]} )
	#echo ${kdts_job_dep_str}
	#echo "precd"
        cd ${runs_root}
	#echo "postcd"
        #compute_kdts_stdout=$( bsub -n ${n_procs} -R "span[ptile=${n_procs_per_node}]" -w ${kdts_job_dep_str} -o ${debugging_path}/compute_kdts_output.txt -e ${debugging_path}/compute_kdts_error.txt ${job_script_compute_kdts} ${n_procs_compute_kdts} ${compute_kdts_script} ${runs_root} ${graph_kernel} ${slicing_policy} )
        #compute_kdts_stdout=$( sbatch -N${n_nodes_compute_kdts} ${job_script_compute_kdts} ${n_procs_compute_kdts} ${compute_kdts_script} ${runs_root} ${graph_kernel} )
	#echo "prekdts"
	echo "Computing KDTS data for Unstrucutured Mesh communication pattern with $((run_idx_high+1)) runs and nd neighbor fraction = ${nd_neighbor_fraction}"
	bash > ${debugging_path}/../../compute_kdts_output.txt 2> ${debugging_path}/../../compute_kdts_error.txt ${job_script_compute_kdts} ${n_procs_compute_kdts} ${compute_kdts_script} ${runs_root} ${graph_kernel} ${slicing_policy}
	#echo "postkdts"
        #compute_kdts_job_id=$( echo ${compute_kdts_stdout} | sed 's/[^0-9]*//g' )

        # Generate plot
        #make_plot_stdout=$( sbatch -N1 --dependency=afterok:${compute_kdts_job_id} ${job_script_make_plot} ${make_plot_script_unstructured_mesh} "${runs_root}/kdts.pkl" ${nd_neighbor_fraction})
        #make_plot_stdout=$( sbatch -N1 ${job_script_make_plot} ${make_plot_script_unstructured_mesh} "${runs_root}/kdts.pkl" )

	#    done # msg sizes
#    done # nd neighbor fraction
    #done # num procs
done # proc placement
