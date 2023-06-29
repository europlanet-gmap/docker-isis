ARG BASE_IMAGE="gmap/jupyter-isis:latest"
FROM $BASE_IMAGE

ARG ASP_VERSION="3.2.0"

RUN source activate isis                                            && \
    ## Add USGS/AMES channels just for this (isis) environment
    conda config --env --prepend channels nasa-ames-stereo-pipeline && \
    mamba install stereo-pipeline=${ASP_VERSION}                    && \
    conda clean -a

RUN DOC="${HOME}/README.md"                                     && \
    echo '# AMES Stereo Pipeline'                       >> $DOC && \
    echo ''                                             >> $DOC && \
    echo 'The version installed:'                       >> $DOC && \
    echo ''                                             >> $DOC && \
    echo "- ASP version: ${ASP_VERSION}"                >> $DOC && \
    echo ''                                             >> $DOC && \
    echo '-----'                                        >> $DOC && \
    echo "> This container is based on '${BASE_IMAGE}'" >> $DOC

# RUN source activate gispy                     && \
# 	pip install -y                              \
#         asap_stereo                             \
#         pds4-tools                              \
#         rio-cogeo

# # If WORK_DIR is not defined (when notebook/user is started), use (~) Home.
# RUN echo 'conda config --add envs_dirs ${WORK_DIR:-~}/.conda/envs 2> /dev/null' \
#       >> $HOME/.bashrc

# RUN python3 -m pip install nbgitpuller
# RUN echo 'http://localhost:8888/hub/user-redirect/git-pull?repo=https%3A%2F%2Fgithub.com%2Feuroplanet-gmap%2FBasemappingUtils&urlpath=lab%2Ftree%2FBasemappingUtils%2FREADME.md&branch=master' > $HOME/README.md

# COPY etc/jupyterlab/user_settings.json /opt/conda/share/jupyter/lab/settings/overrides.json
