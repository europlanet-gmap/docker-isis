ARG BASE_IMAGE="jupyter/minimal-notebook:latest"
FROM $BASE_IMAGE

# ARG JUPYTERHUB_VERSION="3.0.0"
# RUN python -m pip install --no-cache jupyterhub==$JUPYTERHUB_VERSION

# This lines above are necessary to guarantee a smooth coupling JupyterHub.
# -------------------------------------------------------------------------

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

USER root
RUN apt-get update -y                           && \
    apt-get install -y --no-install-recommends  \
        bzip2                                   \
        ca-certificates                         \
        curl                                    \
        git                                     \
        libgl1-mesa-glx                         \
        libjpeg9                                \
        libjpeg9-dev                            \
        rsync                                   \
        wget                                    \
        vim                                     && \
    rm -rf /var/lib/apt/lists/*                 && \
    apt-get autoremove
USER $NB_UID

COPY gispy.txt /tmp/gispy.txt 

RUN mambda install -y --file /tmp/gispy.txt

# RUN	conda install gdal -y -c conda-forge && \
#     conda clean -a

# RUN python -m pip install           \
#                 geoplot             \
#                 geoviews            \
#                 holoviews           \
#                 hvplot              \
#                 ipywidgets          \
#                 plotly              \
#                 tqdm                \
#                 # owslib              \
#                 # pygeos              \
#                 fiona               \	
#                 geopandas           \
#                 matplotlib          \
#                 numpy               \
#                 rasterio            \
#                 rioxarray           \
#                 scikit-image        \
#                 scipy               \
#                 shapely             \
#                 spectral
    # pip install -y asap_stereo					 	\
    #     kalasiris         \
    #     pds4-tools									\
    #     rio-cogeo									\
    #     https://github.com/chbrandt/gpt/archive/refs/tags/v0.3dev.zip  

ENV USE_PYGEOS=0

# COPY etc/jupyterlab/user_settings.json /opt/conda/share/jupyter/lab/settings/overrides.json
