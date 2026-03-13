# Various commands I used to test available cores.

set -uo pipefail

function refresh_dir {
    local dir="$1"

    if test -d "$dir"; then
        rm -r "$dir"
    fi

    mkdir -p "$dir"
}

function check_submission_variants {
    local command=$1

    local basic_dir="./basic"
    local sbatch_2_dir="./sbatch-2"
    local sbatch_1_dir="./sbatch-1"

    echo "Testing command \"$command\"..."

    echo "Basic test"

    refresh_dir "$basic_dir"
    (cd "$basic_dir"; bash -c "$command")

    echo "Test via sbatch with main Snakemake getting 2 cores"

    refresh_dir "$sbatch_2_dir"
    (
        cd "$sbatch_2_dir"; \
        srun -c 2 bash -c "$command"
    )

    echo "Test via sbatch with main Snakemake getting 1 core"

    refresh_dir "$sbatch_1_dir"
    (
        cd "$sbatch_1_dir"; \
        srun -c 1 bash -c "$command"
   )
}


max_threads=2

if test -n "$1"; then
    max_threads="$1"
fi

if test $max_threads -lt 2; then
    echo -n "When using less than 2 threads we can't test variations in "
    echo -n "the number of cores provided to Snakemake."
    echo

    exit 1
fi

if test -z "$(which sbatch)"; then
    echo "Couldn't find 'sbatch', are you sure this is a SLURM cluster?"
    exit 1
fi

# Bake the Snakefile path into the commands as they will be run in subdirs of
# the current workdir.
export slurm_cmd="snakemake \
 --snakefile $(realpath ./Snakefile) \
 --executor slurm \
 --jobs 1 \
 --max-threads $max_threads \
 --cores 1 \
 --local-cores $max_threads"

export cluster_generic_cmd="snakemake \
 --snakefile $(realpath ./Snakefile) \
 --executor cluster-generic \
 --cluster-generic-submit-cmd \"sbatch --cpus-per-task {threads}\" \
 --cluster-generic-cancel-cmd \"scancel\" \
 --jobs 1 \
 --max-threads $max_threads \
 --cores 1 \
 --local-cores $max_threads"

echo "Testing slurm plugin..."

slurm_plugin_dir="./slurm-plugin"
refresh_dir $slurm_plugin_dir
(cd $slurm_plugin_dir && check_submission_variants "$slurm_cmd")

echo "Done."

echo "Testing cluster-generic plugin..."

cluster_generic_plugin_dir="./cluster-generic-plugin"
refresh_dir $cluster_generic_plugin_dir
(
    cd $cluster_generic_plugin_dir && \
        check_submission_variants "$cluster_generic_cmd"
)

echo "All done!"
