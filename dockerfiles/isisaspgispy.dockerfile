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

ARG ASP_VERSION=""
ARG ENV_NAME="isis"
ARG ASP_ENV_NAME="isis-asp"
ARG ISISASP_GISPY_ENV_NAME="isis-asp-gispy"

COPY isisasp.yml /tmp/asp.tmp

RUN [ -n "${ASP_VERSION}" ]                                             && \
    sed "s/\(.*- stereo-pipeline\).*/\1=$ASP_VERSION/" /tmp/asp.tmp     \
        > /tmp/asp.yml                                                  || \
    cp /tmp/asp.tmp /tmp/asp.yml
 
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

RUN mamba create -n ${ENV_NAME} -y && \
    source activate  ${ENV_NAME} && \
    mamba install -y stereo-pipeline=${ASP_VERSION} && \
    conda rename -n gispy  ${ISISASP_GISPY_ENV_NAME} && \
    source activate --stack ${ISISASP_GISPY_ENV_NAME} && \    
    pip install ipykernel && \
    python -m ipykernel install --user --name ${ISISASP_GISPY_ENV_NAME} --display-name ${ISISASP_GISPY_ENV_NAME} && \
    mamba clean -a

# Update the .bashrc so that any interactive shell activates the stacked environments:
RUN echo "source /opt/conda/etc/profile.d/conda.sh" >> /home/$NB_USER/.bashrc && \
    echo "conda activate ${ENV_NAME} && conda activate --stack ${ISISASP_GISPY_ENV_NAME}" >> /home/$NB_USER/.bashrc && \
    sed -i '/conda activate gispy/d' /home/$NB_USER/.bashrc

# Update PATH so that the new environment's executables are first in line
ENV PATH /opt/conda/envs/${ENV_NAME}/bin:$PATH

# Ensure the new kernel is available in Jupyter
RUN jupyter kernelspec list

# Set Environmental Variables for ISIS DATA
ARG ISISDATA="/isis/data"
ARG ISISTESTDATA="/isis/testdata"

ENV ISISDATA=${ISISDATA}
ENV ISISTESTDATA=${ISISTESTDATA}

ENV ISISROOT="/opt/conda/envs/isis"   

## Write a README file for user

ENV README=$HOME/README.md

COPY readmes/readme.isisaspgispy.md /tmp/readme.isisaspgispy.md

RUN echo ""                                         >> $README  && \
    cat /tmp/readme.isisaspgispy.md | envsubst           >> $README  && \
    echo ""                                         >> $README