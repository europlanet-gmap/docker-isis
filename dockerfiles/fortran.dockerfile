ARG BASE_IMAGE="quay.io/jupyter/minimal-notebook:latest"
FROM $BASE_IMAGE
ENV BASE_IMAGE $BASE_IMAGE

# Switch to root user to install apt packages
USER root
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      btop \
      bzip2 \
      ca-certificates \
      curl \
      git \ 
      gfortran \
      gdb \
      make           \
      libjpeg-dev \
      rsync \
      wget \
      vim && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get autoremove -y

# Back to non-root user (from the Jupyter Docker Stack approach)
USER $NB_UID

# Set some global configs to Conda
RUN conda config --set always_yes true            && \
    conda config --set use_only_tar_bz2 false      && \
    conda config --set notify_outdated_conda false && \
    # We add pip, ipykernel and sh as a default create package so we always have pip in new envs
    conda config --add create_default_packages ipykernel        && \
    conda config --add create_default_packages pip              && \
    conda config --add create_default_packages sh               && \
    # We disable the base conda env
    conda config --set auto_activate_base False && \
    conda clean -a

# Turn off PyGEOS, prefer Shapely
ENV USE_PYGEOS=0

# Copy the environment.yml that has both conda and pip dependencies
COPY fortran.txt /tmp/fortran.txt

ARG ENV_NAME="fortran"

# Use mamba to update the base environment with all packages in environment.yml
RUN mamba create -n $ENV_NAME && \    
    source activate $ENV_NAME && \
    mamba install -y --file /tmp/fortran.txt      && \
    pip install ipykernel && \
    python -m ipykernel install --user --name $ENV_NAME --display-name $ENV_NAME && \
    mamba clean -a    

# Update .bashrc so that interactive shells auto-activate the custom environment
RUN echo "source /opt/conda/etc/profile.d/conda.sh" >> /home/$NB_USER/.bashrc && \
    echo "conda activate $ENV_NAME" >> /home/$NB_USER/.bashrc

# Update PATH so that commands (like python) default to your custom environment
ENV PATH /opt/conda/envs/$ENV_NAME/bin:$PATH

# Ensure the new kernel is available in Jupyter
RUN jupyter kernelspec list

# (Optional) If you need a readme:
ENV README=$HOME/README.md
COPY readmes/readme.base.md   /tmp/readme.base.md
COPY readmes/readme.gispy.md  /tmp/readme.gispy.md