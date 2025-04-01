ARG BASE_IMAGE="quay.io/jupyter/minimal-notebook:latest"
FROM $BASE_IMAGE

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

USER root
RUN apt-get update -y                           && \
    apt-get install -y --no-install-recommends  \
        btop                                    \
        bzip2                                   \
        ca-certificates                         \
        curl                                    \
        gettext                                 \
        git                                     \        
        libgl1                                  \
        libjpeg-dev                             \
        rsync                                   \
        wget                                    \
        vim                                     && \
    rm -rf /var/lib/apt/lists/*                 && \
    apt-get autoremove

USER $NB_UID
SHELL ["/bin/bash", "-c"]
ARG ASP_VERSION=""
RUN conda config --set always_yes true            && \
    conda config --set use_only_tar_bz2 false      && \
    conda config --set notify_outdated_conda false && \
    # We add pip, ipykernel and sh as a default create package so we always have pip in new envs
    conda config --add create_default_packages ipykernel        && \
    conda config --add create_default_packages pip              && \
    conda config --add create_default_packages sh               && \
    # Add USGS channels
    conda config --env --append channels defaults               && \
    conda config --env --prepend channels usgs-astrogeology     && \
    conda config --env --prepend channels nasa-ames-stereo-pipeline && \
    # We disable the base conda env
    conda config --set auto_activate_base False && \
    conda clean -a

ARG ENV_NAME="isis-asp"
ARG BASE_ENV_NAME="isis" 


RUN source /opt/conda/etc/profile.d/conda.sh && \    
    mamba create -n $ENV_NAME  && \     
    conda activate $ENV_NAME && \  
    mamba install stereo-pipeline=${ASP_VERSION} && \        
    source activate --stack ${BASE_ENV_NAME} && \    
    pip install ipykernel && \
    python -m ipykernel install --user --name ${ENV_NAME} --display-name ${ENV_NAME} && \
    mamba clean -a

# Update the .bashrc so that any interactive shell activates the stacked environments:
RUN echo "source /opt/conda/etc/profile.d/conda.sh" >> /home/$NB_USER/.bashrc && \
    echo "conda activate ${ISIS_ENV_NAME} && conda activate --stack ${ENV_NAME}" >> /home/$NB_USER/.bashrc && \
    sed -i '/conda activate ${BASE_ENV_NAME}/d' /home/$NB_USER/.bashrc
    
# Update PATH so that commands (like python) default to your custom environment
ENV PATH /opt/conda/envs/$ENV_NAME/bin:$PATH

# Ensure the new kernel is available in Jupyter
RUN jupyter kernelspec list 
# && \
#jupyter kernelspec uninstall ${BASE_ENV_NAME} -f

# Set Environmental Variables for ISIS DATA
ARG ISISDATA="/isis/data"
ARG ISISTESTDATA="/isis/testdata"

ENV ISISDATA=${ISISDATA}
ENV ISISTESTDATA=${ISISTESTDATA}

ENV ISISROOT="/opt/conda/envs/isis"   

## Write a README file for user
#
ENV README=$HOME/README.md

COPY readmes/readme.isisasp.md /tmp/readme.isisasp.md

RUN echo ""                                         >> $README  && \
    cat /tmp/readme.isisasp.md | envsubst           >> $README  && \
    echo ""                                         >> $README