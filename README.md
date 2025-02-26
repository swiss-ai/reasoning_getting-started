# Getting Started with SLURM and Clariden - [CSCS KB](https://confluence.cscs.ch/spaces/KB/pages/840663123/Getting+started+on+Clariden)

Instructions for using the Clariden cluster at CSCS, working with SLURM, and creating and running containers in this environment. Tutorials at [https://confluence.cscs.ch/spaces/KB/overview](https://confluence.cscs.ch/spaces/KB/overview) and Clariden [https://confluence.cscs.ch/spaces/KB/pages/750223402/Alps+Clariden+User+Guide](https://confluence.cscs.ch/spaces/KB/pages/750223402/Alps+Clariden+User+Guide)

_TODO: TOC, VS Code Integration, Building a Container ontop of group's, creating group container_
1. [Set Up Your Access to Clariden](#17-set-up-your-access-to-clariden---cscs-kb)
2. [Persistent Storage](#27-persistent-storage---cscs-kb)
3. [SLURM Basics](#37-slurm-basics---cscs-kb)
4. [Containers and Env Files](#47-containers-and-env-files---cscs-kb)
5. [Everyday SLURM](#57-everyday-slurm---cscs-kb)
6. [TODO: VS Code Integration](#67-todo-vs-code-integration)
7. [(Optional) Building a Container](#77-optional-building-a-container---cscs-kb)

**NOTE**: For support visit https://support.cscs.ch where you can find tutorials, join the CSCS Slack for questions, and submit tickets if things are not working

## [1/7] Set Up Your Access to Clariden - [CSCS KB](https://confluence.cscs.ch/spaces/KB/pages/847904884/Debug+in+your+containers+with+IDEs)

Clariden is the supercomputer from CSCS that we mainly use

1. Check your e-mail for an invite, _"Invitation to Join CSCS"_, and complete registration

2. Wait until your account is manually confirmed, you should receive a second e-mail to setup your password and OTP (One-Time Password using an Authenticator App). Confirm your account by logging into [https://portal.cscs.ch](https://portal.cscs.ch)

3. Run the script for SSH key setup and connection to Clariden

    1. Pull the setup and configuration script
        ```bash
        curl -sL https://raw.githubusercontent.com/swiss-ai/reasoning_getting-started/main/{cscs-cl_setup.sh,user.env} -OO && chmod +x cscs-cl_setup.sh && ./cscs-cl_setup.sh
        ```

    2. Add to `user.env` your `WANDB_API_KEY`, `HF_TOKEN`, and any other env variables<br>**NOTE**: If you want to move `user.env`, make sure to run `./cscs-cl_setup.sh` again in the new directory

    3. To connect to Clariden simply run
        ```bash
        cscs-cl
        ```
        **NOTE**: SSH keys are valid for 24h, after which running `cscs-cl` will automatically generate new keys

    2. If you were able to login but suddenly get `Too many authentication failures` when logging into Clariden, you might have some deprecated keys in your ssh-agent. Try removing all ssh-agent identities (keys) and try again
       ```bash
       ssh-add -D
       cscs-cl
       ```

8. The preinstalled packages, like python, can be outdated and limiting. It's a good idea to work with your own miniconda environment

    1. Install miniconda by running the following commands, Clariden nodes use the `aarch64` ARM64bit architecture, meaning we can't use `x86_64` as is likely what your personal machine is running (you can check on linux using `uname -m`)<br>**NOTE**: Answer _"no"_ when prompted _"Do you wish to update your shell profile to automatically initialize conda?"_
       ```bash
       cd && wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh
       bash ./Miniconda3-latest-Linux-aarch64.sh
       rm ./Miniconda3-latest-Linux-aarch64.sh
       ```
       To make conda available in your shell, run to add to your shell-rc, e.g. `$HOME/{.bashrc, .zshrc}`<br>If you picked a different path for conda than default `~/miniconda3`, change the path accordingly
       ```bash
       echo -e "\nsource ~/miniconda3/etc/profile.d/conda.sh" >> $HOME/.${SHELL##*/}rc
       source $HOME/.${SHELL##*/}rc
       ```
       You can manually enable and disable the conda env using `conda activate` and `conda deactivate`

       VS Code will usually handle auto-activation of conda envs, if you want a specific conda env automatically activated on CLI, run (replace `base` with `<env_name>` for another env)
       ```bash
       echo -e "\nconda activate base" >> $HOME/.${SHELL##*/}rc
       ```

    3. If your conda env (e.g. `base`) is activated you should see it in the context indicator of your terminal - `(base) [clariden][<user>@clariden-ln001 ~]$` You can now install any packages you need
       ```bash
       pip install --upgrade pip setuptools
       ...
       ```


## [2/7] Persistent Storage - [CSCS KB](https://confluence.cscs.ch/spaces/KB/pages/821297419/Storage+in+Clariden)

Just connecting to Clariden via `cscs-cl` will give you a login node on `/users/$USER` with only 50GB of storage and should only be used for configuration files. Any files created during execution on a compute node (discussed later) will be lost once the session ends. For persistent storage, the Clariden cluster has two mounted storage partitions:
- `/iopsstor` is smaller and intended for faster, short-term access (3PB shared across all users)<br>Your personal scratch partition is on `/iopsstor/scratch/cscs/$USER` for easy access you can add a symbolic link to your home directory
    ```bash
    ln -s /iopsstor/scratch/cscs/$USER/ $HOME/scratch
    ```
    **IMPORTANT: Files are cleaned after 30 days**, remove temporary files and transfer important data to capstor
- `/capstor` is slower but larger and intended for long-term storage (150TB and 1M inodes(files)/user)<br>Your personal storage partition is on `/capstor/scratch/cscs/$USER`<br>**DO NOT** write to capstor from compute nodes during a job, always write to iopsstor then transfer important data after
    ```bash
    ln -s /capstor/scratch/cscs/$USER/ $HOME/store
    ```

You can check your usage quota by logging into ela.cscs.ch (it currently doesn't work on Clariden)
```
ssh ela "quota"
```


## [3/7] SLURM Basics - [CSCS KB](https://confluence.cscs.ch/spaces/KB/pages/794296411/Running+jobs)

Clariden uses SLURM to allocate and schedule compute resources across the cluster for efficient and fair usage among users. Example SLURM commands:

1. `sinfo -a -l`<br>Check available partitions (queues for jobs to run) and their nodes. `-a` show all partitions, `-l` in long format

2. **NOTE**: Never run compute-intensive jobs on the login node!

    For quick jobs
    ```bash
    srun --account=a-a06 --time=01:00 -p debug --pty bash -c '<command>'
    ```
    `--account` is mandatory and can be checked in [CSCS Projects](https://portal.cscs.ch/projects) (a06 for LLMs) or `id -Gn`<br>`--time=01:00` specifies runtime (1 minute, shorter jobs get priority)<br>`-p` specifies the partition (`debug` is usually for quick tests, max. 30min; else `normal`, max. 24h)<br>`--pty` starts an interactive session<br>`bash -c '<command>'` will run the subsequent command with bash

    You can get an interactive compute node for 30min (such as to process data)

    ```bash
    srun --account=a-a06 -p debug --pty bash
    ```
    For experiments you should use `sbatch` (See [5/7])

3. To replace `srun --account=a-$(id -Gn) -p debug --pty` with a shorthand `sdebug` command run (``--container-writable`` allows you to write if in a container, discussed in [4/7])
    ```bash
    echo -e "\nalias sdebug='srun --account=a-\$(id -Gn) -p debug --pty --container-writable \"\$@\"'" >> $HOME/.${SHELL##*/}rc && source $HOME/.${SHELL##*/}rc
    ```
    Now you can simply run

    `sdebug bash` to get an interactive compute node<br>`sdebug <options>` to add options such as `-t <MM:SS>` time, `bash -c '<command>'` for commands

4. `squeue --me`<br>Show your own jobs, their `<JOBID>`, and `<NODELIST>`. You can prepend `watch -n <interval>` to refresh the command every `<interval>` seconds

5. `scancel <JOBID>`<br>Cancel an individual _\<JOBID\>_

    `scancel --me`<br>Cancel all jobs

6. `scontrol show job <JOBID>`<br>See more details about your job after completion

7. `scontrol show nodes <NODELIST>`<br>See specific details about a node, usually nid00NNNN


## [4/7] Containers and Env Files - [CSCS KB](https://confluence.cscs.ch/spaces/KB/pages/776306695/Container+Engine)

Clariden containers run with Enroot for consistent and reproducible environments, making it possible to run Docker images without requiring elevated privileges. They are defined by `.toml` files which specify the container image to use, along with filesystem paths to mount inside it

1. Create a simple `my_env.toml` file in `$HOME/.edf/` (this allows you to call the env file without the full path)
    ```bash
    mkdir -p $HOME/.edf
    cat > $HOME/.edf/my_env.toml << EOF
    image = "/capstor/store/cscs/swissai/a06/containers/nanotron_pretrain/latest/nanotron_pretrain.sqsh"
    mounts = ["/capstor", "/iopsstor", "/users"]
    workdir = "/workspace"

    [annotations]
    com.hooks.aws_ofi_nccl.enabled = "true"
    com.hooks.aws_ofi_nccl.variant = "cuda12"
    EOF
    ```
    The annotations are arguments to load the proper NCCL plugin that CSCS has prepared for us<br>**NOTE**: EDF files expect realpaths (fullpaths), so `$GLOBAL_VARS` are **NOT** allowed, e.g. '$HOME' or '~' are **NOT** allowed, use `/users/<USER>` instead, replacing `<USER>` with your actual username ('$USER' also **NOT** allowed), to figure out the realpath run `pwd` in any directory

2. Launch an interactive session using the env file
    ```bash
    sdebug --environment=my_env bash
    ```
    **NOTE**: Only files saved in mounted paths (`my_env` example `/capstor`, `/iopsstor`, and `/users`) are persistent, changes to other paths like `/workspace` will be lost once the container session ends

3. If you aren't already familiar, it is worthwhile to learn CLI text editors like [vim](https://youtu.be/uE4aljoMBeg)


## [5/7] Everyday SLURM - [CSCS KB](https://confluence.cscs.ch/spaces/KB/pages/794296411/Running+jobs)

1. `sdebug <options>` for quick jobs max. 30min (make sure to include a shell, e.g. `bash`)<br>`squeue --me` to see your jobs<br>`ctrl+d` to exit<br>`scancel <JOBID>` to cancel a _\<JOBID\>_ or `scancel --me` to cancel all your jobs

2. For most production workloads or long-running experiments you'll submit jobs _non-interactively_ with `sbatch`. This allows the scheduler to queue up your jobs, allocate resources when they become available, and run your commands without you needing to stay logged in. Run `sbatch --help` to see all options available

    **NOTE: 'normal' partition jobs are max. 24h, 'debug' max. 30min, make sure to checkpoint**

    1. Create a file named `my_first_sbatch.sh` with the following content (read every entry) (substitute _'a-a06'_ if your project is different)
    ```bash
    #!/bin/bash
    #SBATCH --job-name=my_first_sbatch   # A name for your job. Visible in squeue.
    #SBATCH --account=a-a06              # The account you are charged for the job
    #SBATCH --nodes=1                    # Number of compute nodes to request.
    #SBATCH --ntasks-per-node=1          # Tasks (processes) per node
    #SBATCH --time=00:10:00              # HH:MM:SS, set a time limit for this job (here 10min)
    #SBATCH --partition=debug            # Partition to use; "debug" is usually for quick tests
    #SBATCH --mem=460000                 # Memory needed (simply set the mem of a node)
    #SBATCH --cpus-per-task=288          # CPU cores per task (simply set the number of cpus a node has)
    #SBATCH --environment=my_env         # the environment to use (See [4/7])
    #SBATCH --output=/iopsstor/scratch/cscs/%u/my_first_sbatch.out  # log file for stdout, prints, et cetera
    #SBATCH --error=/iopsstor/scratch/cscs/%u/my_first_sbatch.out  # log file for stderr, errors

    # Exit immediately if a command exits with a non-zero status (good practice)
    set -eo pipefail

    # Print SLURM variables so you see how your resources are allocated
    echo "Job Name: $SLURM_JOB_NAME"
    echo "Job ID: $SLURM_JOB_ID"
    echo "Allocated Node(s): $SLURM_NODELIST"
    echo "Number of Tasks: $SLURM_NTASKS"
    echo "CPUs per Task: $SLURM_CPUS_PER_TASK"
    echo "Current path: $(pwd)"
    ```

    2. Run `sbatch my_first_sbatch.sh` then `watch -n 1 squeue --me` and check `ST` the [Status Code](https://slurm.schedmd.com/squeue.html#SECTION_JOB-STATE-CODES)<br>`PD` - Pending, `R` - Running, `CG` - Completing

    3. Once completed, check the output file
    ```bash
    cat ~/scratch/my_first_sbatch.out
    ```
    **Remember to remove temporary files and transfer important data to `~/store` once jobs are finished, else they will be cleaned after 30 days**


## [6/7] TODO: VS Code Integration

1. Install Remote Explorer

    1. File > Preferences > Extensions

    2. Select Remote Explorer by Microsoft and install it

2. Enable this setting to prevent disconnects (you need to connect to Clariden with VS Code at least once before this setting appears)

    1. File > Preferences > Settings

    2. Search for: `remote.SSH.serverListenOnSocket`

    3. Enable this setting by selecting the checkbox.

3. In VS Code, now click on Remote Explorer and select Clariden server (which it took from your ssh config). Once connected you should be able to navigate your home directory on the Clariden login node. If you keep having problems ensure your `ssh clariden` works as expected and manually delete `.vscode-server`on Clariden so VS Code reinstalls the VS Code server from scratch


## [7/7] (Optional) Building a Container - [CSCS KB](https://confluence.cscs.ch/spaces/KB/pages/868834153/Building+container+images+on+Alps)

1. Set up Nvidia GPU Cloud (NGC) access to use Nvidia Containers

    1. Navigate to https://ngc.nvidia.com/setup/api-key and create an account if you don't have one

    2. Click the green button on the top right named "Generate API Key" and copy it

    3. Login to Clariden `cscs-cl` and run the following commands to configure `enroot` with your `<API_KEY>`
        ```bash
        NGC_API_KEY="<API_KEY>"
        mkdir -p $HOME/.config/enroot
        cat > $HOME/.config/enroot/.credentials << EOF
        machine nvcr.io login \$oauthtoken password $NGC_API_KEY
        machine authn.nvidia.com login \$oauthtoken password $NGC_API_KEY
        EOF
        unset NGC_API_KEY
        ```

    4. Download and unzip ngc-cli for 'ARM64 Linux' from https://ngc.nvidia.com/setup/installers/cli and add it to your PATH
        ```bash
        cd && wget --content-disposition https://api.ngc.nvidia.com/v2/resources/nvidia/ngc-apps/ngc_cli/versions/3.60.2/files/ngccli_arm64.zip -O ngccli_arm64.zip && unzip ngccli_arm64.zip
        echo -e "\nexport PATH=\"\$PATH:$HOME/ngc-cli\"" >> $HOME/.${SHELL##*/}rc && source $HOME/.${SHELL##*/}rc
        rm ngc-cli.md5 ngccli_arm64.zip
        ```

    5. Configure NGC by running the following command, enter your `<API_KEY>` when prompted
        ```bash
        ngc config set
        ```

    6. Replace the image in your `~/.edf/my_env.toml` file with a 'LINUX / ARM64' image that contains everything to run pytorch on GPUs https://catalog.ngc.nvidia.com/orgs/nvidia/containers/pytorch/tags
        ```bash
        image = "nvcr.io#nvidia/pytorch:25.01-py3"
        ```

    7. Run `sdebug --environment=my_env bash` and wait a minute while the container is downloaded, then check if you can import torch (make sure you are not in a conda env)
        ```bash
        python -c "import torch; print(torch.cuda.get_device_name()); print(torch.cuda.device_count())"
        ```
        and check GPUs
        ```bash
        nvidia-smi
        ```

2. In the login node, setup your container config
    ```bash
    mkdir -p $HOME/.config/containers
    cat > $HOME/.config/containers/storage.conf << EOF
    [storage]
    driver = "overlay"
    runroot = "/dev/shm/\$USER/runroot"
    graphroot = "/dev/shm/\$USER/root"

    [storage.options.overlay]
    mount_program = "/usr/bin/fuse-overlayfs-1.13"
    EOF
    ```

3. In your home directory of the login node on Clariden, create a file `Dockerfile`
    ```Dockerfile
    FROM nvcr.io/nvidia/pytorch:25.01-py3

    # setup
    RUN apt-get update && apt-get install python3-pip python3-venv -y
    RUN pip install --upgrade pip setuptools==69.5.1

    # Install the rest of dependencies.
    RUN pip install \
        datasets \
        transformers \
        accelerate \
        wandb \
        dacite \
        pyyaml \
        numpy \
        packaging \
        safetensors \
        tqdm \
        sentencepiece \
        tensorboard \
        pandas \
        jupyter \
        deepspeed \
        seaborn

    # Create a work directory
    RUN mkdir -p /workspace
    ```
    The Dockerfile defines steps to build a container image. In this example, we build on top of NVIDIA's PyTorch container 'nvcr.io/nvidia/pytorch:25.01-py3' which comes pre-configured with GPU acceleration and optimized libraries for deep learning. The Dockerfile then installs system dependencies ('python3-pip', 'python3-venv') and a collection of Python libraries for machine learning, data processing, and visualization

    Beyond installing packages, a Dockerfile can also define environment variables, set up default commands, configure network settings, expose ports, and optimize the container size using multi-stage builds. [Docker's official documentation](https://docs.docker.com/reference/dockerfile)

3. We will now build the container. **DO NOT BUILD ON THE LOGIN NODE**. You may hit space or memory limits and it will make the login node less responsive for all other users. Initialize a container without an env `sdebug bash`

4. Once you are on the compute node, navigate to the folder with your Dockerfile and use `podman` to create an image named `my_pytorch:25.01-py3` (be patient)
    ```bash
    podman build -t my_pytorch:25.01-py3 .
    ```

5. After you created your image you can see it in your local container registry
    ```bash
    podman images
    ```

6. Use `enroot` to save the image into a `.sqsh` compressed SquashFS which you can share with others. `enroot import` will convert the container image, `-o` specifies the output<br>**NOTE**: Save to scratch as the file can be large (easily 20GB, your $HOME only has 50GB). If you are planning to share your image across team-members, contact your supervisor so we can put it on persistent storage
    ```bash
    cd $HOME/scratch
    enroot import -o my_pytorch.sqsh podman://my_pytorch:25.01-py3
    ```

7. Now you can replace the image in your `~/.edf/my_env.toml` file with the `.sqsh` real filepath
    ```bash
    image = "/iopsstor/scratch/cscs/<USER>/my_pytorch.sqsh"
    ```
    **NOTE**: EDF files expect realpaths (fullpaths), so `$GLOBAL_VARS` are **NOT** allowed, make sure to replace `<USER>` with your actual username or replace with `sed`
    ```bash
    sed -i.bak "s|^image = .*|image = \"/iopsstor/scratch/cscs/$USER/my_pytorch.sqsh\"|" $HOME/.edf/my_env.toml && rm $HOME/.edf/my_env.toml.bak
    ```

8. Try it out and check if your software packages are now available when you get a compute node
    ```bash
    sdebug --environment=my_env bash -c "pip list"
    ```

9. _TODO: Building a container ontop of group's_