
---
# Getting Started with SLURM and Clariden - [CSCS KB](https://docs.cscs.ch/clusters/clariden)
_TODO: VS Code Integration_

Instructions for using the Clariden cluster at CSCS, working with SLURM, and creating and running containers in this environment.

You should send your GitHub username to your supervisor so they can add you to the group repository

**IMPORTANT**: If you are having problems with the cluster, before messaging your supervisor, try debugging. Usually your supervisor has 10+ students and many responsibilities, only come to them when none of the following have worked:
- Check [#cscs-users](https://swissai-initiative.slack.com/archives/C063R5THH99) in the Swiss AI Initiative Slack if anyone else has had a similar issue - if not, consider posting there
- Check [#announcements-alps](https://swissai-initiative.slack.com/archives/C08HDKTFB08) in the Swiss AI Initiative Slack
- Check the status page and familiarize yourself with CSCS's maintenance schedule and announcements https://status.cscs.ch
- Check the documentation and tutorials at http://docs.cscs.ch and Clariden https://docs.cscs.ch/platforms/mlp
- For support visit https://support.cscs.ch where you can find tutorials, join the CSCS Slack for questions, and **SUBMIT TICKETS** if things are not working

Please do not come to your supervisor with questions about Slurm, SSH, et cetera unless you truly have tried finding information in the resources, online, and have submitted a ticket. From experience, >90% of issues from students are found in these resources or in search, and ~10% are cluster-related issues which your supervisor cannot fix. If it is project-related questions this is of course a different story


---
<details>
<summary>&nbsp;&nbsp;&nbsp;&nbsp;[1/7] Set Up Your Access to Clariden</summary>

[CSCS KB](https://confluence.cscs.ch/spaces/KB/pages/847904884/Debug+in+your+containers+with+IDEs)<br>Clariden is the supercomputer from CSCS that we mainly use

1. Check your e-mail for an invite, _"Invitation to Join CSCS"_, and complete registration

2. Wait until your account is manually confirmed, you should receive a second e-mail to setup your password and OTP (One-Time Password using an Authenticator App). Confirm your account by logging into [https://portal.cscs.ch](https://portal.cscs.ch)

3. Run the script for SSH key setup and connection to Clariden

    1. Pull the setup and configuration script
        ```bash
        curl -sL https://raw.githubusercontent.com/swiss-ai/reasoning_getting-started/main/{cscs-cl_setup.sh,user.env} -OO && chmod +x cscs-cl_setup.sh && ./cscs-cl_setup.sh
        ```

    2. Add to `user.env` your `WANDB_API_KEY`, `HF_TOKEN`, Git Credentials, and any other env variables
        - `LOCAL_GIT_SSH_KEYPATH` is the path to your local private Git SSH key, e.g. `$HOME/.ssh/GitKey` (**not** .pub), if you haven't done so, generate https://www.youtube.com/watch?v=DuMcXyQkj5g then add https://github.com/settings/ssh/new you can test it works with
            ```bash
            ssh -T git@github.com
            ```
            You may need to add the key to ssh config (replacing `<key_name>` (**not** .pub))
            ```bash
            echo -e "\nIdentityFile $HOME/.ssh/<key_name>" >> $HOME/.ssh/config
            ```
        - You can find your Git email at https://github.com/settings/emails if you want a private email select _'Keep my email addresses private'_ and use the email in the format `<ID>+<username>@users.noreply.github.com`

        **NOTE**: If you want to move `user.env`, make sure to run `./cscs-cl_setup.sh` again in the new directory

    3. To connect to Clariden simply run
        ```bash
        cscs-cl
        ```
        **NOTE**: Cluster SSH keys are valid for 24h, after which running `cscs-cl` will automatically generate new keys

    2. If you were able to login but suddenly get `Too many authentication failures` when logging into Clariden, you might have some deprecated keys in your ssh-agent. Try removing all ssh-agent identities (keys) and try again
       ```bash
       ssh-add -D
       cscs-cl
       ```

4. The preinstalled packages, like python, can be outdated and limiting. It's a good idea to work with your own miniconda environment

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
5. It is good to have a central directory for installed packages, we will use `$HOME/bin` and add it to PATH
```bash
mkdir -p $HOME/bin
echo -e "\nexport PATH=\"\$PATH:$HOME/bin\"" >> $HOME/.${SHELL##*/}rc && source $HOME/.${SHELL##*/}rc
```
</details>

<details>
<summary>&nbsp;&nbsp;&nbsp;&nbsp;[2/7] Persistent Storage</summary>

[CSCS KB](https://docs.cscs.ch/storage/filesystems)<br>Just connecting to Clariden via `cscs-cl` will give you a login node on `/users/$USER` with only 50GB of storage and should only be used for configuration files. Any files created during execution on a compute node (discussed later) will be lost once the session ends. For persistent storage, the Clariden cluster has two mounted storage partitions:
- `/iopsstor` is smaller and intended for faster, short-term access (3PB shared across all users)<br>Your personal scratch partition is on `/iopsstor/scratch/cscs/$USER` for easy access you can add a symbolic link to your home directory
    ```bash
    ln -s /iopsstor/scratch/cscs/$USER/ $HOME/scratch
    ```
- `/capstor` is slower but larger and intended for large files (150TB and 1M inodes(files)/user)<br>Your personal storage partition is on `/capstor/scratch/cscs/$USER`<br>**DO NOT** write to capstor from compute nodes during a job, always write to iopsstor. capstor is not meant for quick reading and writing of many files

**IMPORTANT: Files on `/iopsstor/scratch` and `/capstor/scratch` are cleaned after 30 days**, remove temporary files and transfer important data to group capstor (**NOT** personal capstor as discussed previously, will be discussed in 'Reasoning Projects Framework')

You can check your usage quota by logging into ela.cscs.ch (it currently doesn't work on Clariden)
```
ssh ela "quota"
```
</details>

<details>
<summary>&nbsp;&nbsp;&nbsp;&nbsp;[3/7] SLURM Basics</summary>

[CSCS KB](https://docs.cscs.ch/running/slurm)<br>Clariden uses SLURM to allocate and schedule compute resources across the cluster for efficient and fair usage among users. Example SLURM commands:

1. `sinfo -a -l`<br>Check available partitions (queues for jobs to run) and their nodes. `-a` show all partitions, `-l` in long format

2. **NOTE**: Never run compute-intensive jobs on the login node!

    For quick jobs
    ```bash
    srun --account=infra01 --time=01:00 -p debug --pty bash -c '<command>'
    ```
    `--account` is mandatory and can be checked in:
    - [CSCS Projects](https://portal.cscs.ch/projects) (infra01, infra01-0, infra01-1 for infra)
    - `id -Gn`
    - `sacctmgr show assoc user=$USER format=account`
    
    `--time=01:00` specifies runtime (1 minute, shorter jobs get priority)<br>`-p` specifies the partition (`debug` is usually for quick tests, max. 1h30min; else `normal`, max. 12h)<br>`--pty` starts an interactive session<br>`bash -c '<command>'` will run the subsequent command with bash

    You can get an interactive compute node for 1h30min (such as to process data)

    ```bash
    srun --account=infra01 -p debug --pty bash
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

    `scancel --me`<br>Cancel your jobs

6. `scontrol show job <JOBID>`<br>See more details about your job after completion

7. `scontrol show nodes <NODELIST>`<br>See specific details about a node, usually nid00NNNN
</details>

<details>
<summary>&nbsp;&nbsp;&nbsp;&nbsp;[4/7] Containers and Env Files</summary>

[CSCS KB](https://confluence.cscs.ch/spaces/KB/pages/894960480/Container+Engine)<br>Clariden containers run with Enroot for consistent and reproducible environments, making it possible to run Docker images without requiring elevated privileges. They are defined by `.toml` files which specify the container image to use, along with filesystem paths to mount inside it

1. Create a simple `my_env.toml` file in `$HOME/.edf/` (this allows you to call the env file without the full path)
    ```bash
    mkdir -p $HOME/.edf
    cat > $HOME/.edf/my_env.toml << EOF
    image = "nvcr.io#nvidia/pytorch:25.01-py3"
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

3. You can also change the working directory in your `~/.edf/my_env.toml` file to your `$HOME`, manually (replacing `<USERNAME>`):
    ```bash
    workdir = "/users/<USERNAME>"
    ```
    or, with `sed`:
    ```bash
    sed -i.bak "s|^workdir = .*|workdir = \"/users/$USER\"|" $HOME/.edf/my_env.toml && rm $HOME/.edf/my_env.toml.bak
    ```
    Now, when you run jobs, you will start in your `$HOME` directory and can write to `$HOME/scratch`

3. If you aren't already familiar, it is worthwhile to learn CLI text editors like [vim](https://youtu.be/uE4aljoMBeg)
</details>

<details>
<summary>&nbsp;&nbsp;&nbsp;&nbsp;[5/7] Everyday SLURM</summary>

[CSCS KB](https://confluence.cscs.ch/spaces/KB/pages/794296411/Running+jobs)<br>

1. `sdebug <options>` for quick jobs max. 1h30min (make sure to include a shell, e.g. `bash`)<br>`squeue --me` to see your jobs<br>`ctrl+d` to exit<br>`scancel <JOBID>` to cancel a _\<JOBID\>_ or `scancel --me` to cancel all your jobs

2. For most production workloads or long-running experiments you'll submit jobs _non-interactively_ with `sbatch`. This allows the scheduler to queue up your jobs, allocate resources when they become available, and run your commands without you needing to stay logged in. Run `sbatch --help` to see all options available

    **NOTE: 'normal' partition jobs are max. 12h, 'debug' max. 1h30min, make sure to checkpoint**

    1. Create a file named `my_first_sbatch.sh` with the following content (read every entry) (substitute _'infra01'_ if your project is different)
    ```bash
    #!/bin/bash
    #SBATCH --job-name=my_first_sbatch   # A name for your job. Visible in squeue.
    #SBATCH --account=infra01          # The account you are charged for the job
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
    **Remember to remove temporary files and transfer important data to `~/project` once jobs are finished (will be discussed in 'Reasoning Projects Framework'), else they will be cleaned after 30 days**
</details>

<details>
<summary>&nbsp;&nbsp;&nbsp;&nbsp;[6/7] TODO: VS Code Integration</summary>

[CSCS KB](https://docs.cscs.ch/access/vscode)

There are many methods to connecting Clariden to VS Code
1. SSH (untested)
    - Install `Remote Explorer` by Microsoft: `File > Preferences > Extensions`
    - Connect to Clariden with VS Code, reload window, and enable `remote.SSH.remoteServerListenOnSocket` in `File > Preferences > Settings`
    - In VS Code, click on `Remote Explorer` and select `Clariden`. Once connected, you should be able to navigate your home directory on the login node
2. Tunnels
    - Install VS Code's CLI `code` on Clariden. Afterwards, you can check the version and update with `code --version` and `code update`
    ```bash
    cd && wget https://jfrog.svc.cscs.ch/artifactory/uenv-sources/vscode/vscode_cli_alpine_arm64_cli.tar.gz && tar -xf vscode_cli_alpine_arm64_cli.tar.gz -C $HOME/bin
    rm vscode_cli_alpine_arm64_cli.tar.gz
    ```
    - You can create a tunnel on Clariden with `code tunnel --name=$CLUSTER_NAME` then login using GitHub
    - On VS Code, select `Remote Explorer`, `Connect to Tunnel`, and either login using GitHub or connect to `clariden`
    - To make your life easier, you can add the following to your `${SHELL}rc`
    ```bash
    cat >> "$HOME/.${SHELL##*/}rc" <<'EOF'
    scode(){ (IFS=$'\n'; set -- $(printf '%s\0' "$@"|sed -z -E 's/^-e$/--environment/; s/^-e=(.*)$/--environment=\1/'|tr '\0' '\n'); sbatch -A infra01 -p normal --container-writable --container-entrypoint-log "$@" --wrap='bash -c "unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; code tunnel --name=$CLUSTER_NAME"'); }
    EOF
    source $HOME/.${SHELL##*/}rc
    ```
    - Now you can simply run `scode` to connect to Clariden, `scode -e my_env` to start with an image

If you have any issues, ensure `ssh clariden` works from local and delete `$HOME/.vscode-server` on Clariden (this forces VS Code to reinstall the server on host when re-connecting), also read the _CSCS KB_ tutorial hyperlinked at the top of the section
</details>

<details>
<summary>&nbsp;&nbsp;&nbsp;&nbsp;[7/7] (Optional) Building a Container</summary>

[CSCS KB](https://docs.cscs.ch/build-install/containers)

1. Set up Nvidia GPU Cloud (NGC) access to use Nvidia Containers

    1. Navigate to https://ngc.nvidia.com/setup/api-key and create an account if you don't have one

    2. Click the green button on the top right named "Generate API Key" and copy it

    3. Login to Clariden `cscs-cl` and run the following commands to configure `enroot` with your `<API_KEY>` (you will need the key again for 'ngc config set' later)
        ```bash
        NGC_API_KEY="<API_KEY>"
        ```
        ```bash
        mkdir -p $HOME/.config/enroot
        cat > $HOME/.config/enroot/.credentials << EOF
        machine nvcr.io login \$oauthtoken password $NGC_API_KEY
        machine authn.nvidia.com login \$oauthtoken password $NGC_API_KEY
        EOF
        unset NGC_API_KEY
        ```

    4. Download and unzip ngc-cli for 'ARM64 Linux' from https://ngc.nvidia.com/setup/installers/cli to `$HOME/bin` (added to PATH in [1/7])
        ```bash
        cd && wget --content-disposition https://api.ngc.nvidia.com/v2/resources/nvidia/ngc-apps/ngc_cli/versions/3.60.2/files/ngccli_arm64.zip -O ngccli_arm64.zip && unzip ngccli_arm64.zip -d $HOME/bin
        rm ngccli_arm64.zip bin/ngc-cli.md5
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
    The Dockerfile defines steps to build a container image. In this example, we build on top of NVIDIA's PyTorch container `nvcr.io/nvidia/pytorch:25.01-py3` which comes pre-configured with GPU acceleration and optimized libraries for deep learning. The Dockerfile then installs system dependencies ('python3-pip', 'python3-venv') and a collection of Python libraries for machine learning, data processing, and visualization

    Beyond installing packages, a Dockerfile can also define environment variables, set up default commands, configure network settings, expose ports, and optimize the container size using multi-stage builds. [Docker's official documentation](https://docs.docker.com/reference/dockerfile)

4. We will now build the container. **DO NOT BUILD ON THE LOGIN NODE**. You may hit space or memory limits and it will make the login node less responsive for all other users

    Initialize a container without an env `sdebug bash`

    Once you are on the compute node, navigate to the folder with your Dockerfile and use `podman` to create an image named `my_pytorch:25.01-py3` (be patient)
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
</details>
<br>


---
# Reasoning Projects Framework - Prototype
_TODO: Building a Container ontop of group's, creating group container, r-gym, {OpenR1, TinyZero}, Reasoning Resources_

Now that you know the basics of Clariden, you can set up the cluster for Reasoning Projects


<details>
<summary>&nbsp;&nbsp;&nbsp;&nbsp;[1/n] Set Up Shared Storage</summary>

- `/users/$USER` - For personal configuration files, use your home directory (`$HOME`, `~`) (50GB)
- `/iopsstor/scratch/cscs/$USER` - For compute jobs, use your personal scratch (`$SCRATCH`) (30d cleanup)
- `/capstor/scratch/cscs/$USER` - For large files, transfer to your personal storage **after** compute finished (30d cleanup)

For persistent storage for the most important files and group data, use `/capstor/store/cscs/swissai/infra01/reasoning` (if you don't have access, message your supervisor your `$USER`)<br>**DO NOT write to this during compute**, it costs $$$

Currently, the structure is
```bash
/capstor/store/cscs/swissai/infra01/reasoning
├── data/       # shared project data
├── imgs/       # project containers
├── models/     # shared models
└── users/      # individual user folders
```
1. First, create a symbolic link to the project folder
    ```bash
    ln -s /capstor/store/cscs/swissai/infra01/reasoning $HOME/shared
    ```

2. Create your user folder
    ```bash
    mkdir -p /capstor/store/cscs/swissai/infra01/reasoning/users/$USER
    ```

3. Create a symbolic link to your user folder
    ```bash
    ln -s /capstor/store/cscs/swissai/infra01/reasoning/users/$USER $HOME/project
    ```

Now, when you have data you need persistent, you can use
- `~/project` - For personal persistent data (important source code, results, et cetera)
- `~/shared/*` - For shared persistent data (data, models, et cetera)

**DO NOT** write to these during compute (that is what `$SCRATCH` is for), only transfer data you need saved after or e.g. source-code that cannot fit in your 50GB `$HOME`
</details>

<details>
<summary>&nbsp;&nbsp;&nbsp;&nbsp;[2/n] TODO: Group Container</summary>
</details>

<details>
<summary>&nbsp;&nbsp;&nbsp;&nbsp;[3/n] TODO: Set Up Relevant Libraries {Reasoning-Gym, OpenR1, TinyZero}</summary>
</details>

<details>
<summary>&nbsp;&nbsp;&nbsp;&nbsp;[4/n] TODO: Additional Readings and Resources</summary>
</details>
