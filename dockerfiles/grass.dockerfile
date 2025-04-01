###############################################################################
# 1) Base Image
###############################################################################
ARG BASE_IMAGE=quay.io/jupyter/minimal-notebook:2025-03-24
#latest
FROM ${BASE_IMAGE}

USER root
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

###############################################################################
# 2) Define the Official GRASS Run Packages
###############################################################################
ARG GRASS_RUN_PACKAGES="\
  cmake \
  libboost-all-dev \
  flex \
  bison \
  debhelper-compat \
  dh-python \
  doxygen \
  fakeroot \
  autoconf2.13 \
  autotools-dev \
  g++ \
  gcc \
  gettext \
  graphviz \
  libcairo2-dev \
  libbz2-dev \
  libfftw3-dev \
  libfreetype6-dev \
  libgdal-dev \
  libgeos-dev \
  libgl1-mesa-dev \
  libglu1-mesa-dev \
  libjpeg-dev \
  liblapack-dev \
  libmotif-dev \
  default-libmysqlclient-dev \
  libncurses5-dev \
  libnetcdf-dev \
  libpng-dev \
  libpq-dev \
  libproj-dev \
  libreadline-dev \
  libsqlite3-dev \
  libtiff-dev \
  libxmu-dev \
  libzstd-dev \
  netcdf-bin \
  pkg-config \
  proj-bin \
  proj-data \
  python3 \
  python3-dev \
  python3-numpy \
  python3-pil \
  python3-ply \
  python3-six \
  python3-wxgtk4.0 \
  wget \
  unixodbc-dev \
  zlib1g-dev \
  python3-sphinx \
  postgresql \
  libgeotiff-dev \
  libblas-dev \
  libatlas-base-dev \
  opencl-headers \
  ocl-icd-libopencl1 \
  subversion \
  python3-gdal \
  libpdal-dev \
  pdal \
  build-essential \
  bzip2 \
  curl \
  gdal-bin \
  geos-bin \
  git \
  language-pack-en-base \
  libcurl4-gnutls-dev \
  libfftw3-bin \
  libgsl-dev \
  libgsl27 \
  libjsoncpp-dev \
  libmagic-mgc \
  libmagic1 \
  libomp-dev \
  libomp5 \
  libopenblas-dev \
  libopenjp2-7 \
  libpdal-plugin-hdf \
  libpdal-plugins \
  libpq5 \
  libpython3-all-dev \
  libreadline8 \
  libtiff-tools \
  locales \
  make \
  mesa-utils \
  moreutils \
  ncurses-bin \
  python-is-python3 \
  python3-venv \
  sqlite3 \
  unzip \
  vim \
  zip \
"



###############################################################################
# 3) Install Packages & Add Missing Dev Libraries for Readline
###############################################################################
#  - 'libreadline-dev' is required by --with-readline
#  - (Optional) if you keep --with-wxwidgets, you need 'libwxgtk3.0-gtk3-dev' or similar
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      software-properties-common \
      gnupg2 \
    && rm -rf /var/lib/apt/lists/*

# Add ubuntugis-unstable PPA, then update and install packages
RUN add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      $GRASS_RUN_PACKAGES \
      pkg-config \
      libreadline-dev \      
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# Set up locale
RUN echo LANG="it_IT.UTF-8" > /etc/default/locale && \
    echo it_IT.UTF-8 UTF-8 >> /etc/locale.gen && \
    locale-gen

###############################################################################
# 4) (Optional) Symlink /usr/lib64 for Debian/Ubuntu
###############################################################################
#  - Because your config uses '--with-libs=/usr/lib64', but on Ubuntu libraries
#    live in /usr/lib/x86_64-linux-gnu. This step creates a symlink if not present.
RUN if [ ! -d /usr/lib64 ]; then \
      ln -s /usr/lib/x86_64-linux-gnu /usr/lib64 || true; \
    fi

###############################################################################
# 5) Build & Install GRASS (headless, with OpenMP)
###############################################################################
RUN git clone --depth=1 https://github.com/OSGeo/grass.git /tmp/grass_build
WORKDIR /tmp/grass_build

ENV GRASS_CONFIG="\
  --with-cxx \
  --with-gdal=/usr/bin/gdal-config \
  --with-geos \
  --with-proj-share=/usr/share/proj \
  --with-fftw \
  --with-freetype=yes \
  --with-freetype-includes=/usr/include/freetype2/ \
  --with-readline \
  --with-openmp=yes \
  --without-opengl \
  --without-mysql \
  --without-sqlite \
  --enable-largefile \
  --with-pthread \
  --with-odbc \
  --with-fftw-includes=/usr/include/ \
  --with-fftw-libs=/usr/lib/ \
  --with-wxwidgets \
  --with-postgres-includes=/usr/include/postgresql \
  --with-pdal \
  --with-netcdf \
  --without-cairo \
  --without-wxwidgets \
  #--with-bzlib \
  --with-zstd \
  --enable-64bit \
  --with-libs=/usr/lib64 \
"

# Clean any old state, configure, compile, install
RUN make distclean || true \
 && CFLAGS="-O2 -std=gnu99" LDFLAGS="-s" ./configure $GRASS_CONFIG \
 && make -j"$(nproc)" \
 && make install && ldconfig

# Make a symlink for convenience
RUN ln -sf /usr/local/grass85 /usr/local/grass

###############################################################################
# 6) Switch to Notebook User
###############################################################################
USER $NB_UID
WORKDIR /home/$NB_USER

###############################################################################
# 7) Create a Conda Environment 'matisse'
###############################################################################

COPY grass.txt /tmp/grass.txt

ARG ENV_NAME="grass"
ARG BASE_ENV_NAME="grass"

# Use mamba to update the base environment with all packages in environment.yml
RUN mamba create -n $ENV_NAME && \    
    source activate $ENV_NAME && \
    mamba install -y --file /tmp/grass.txt      && \
    source activate  ${BASE_ENV_NAME} && \
    source activate --stack ${ENV_NAME} && \ 
    pip install ipykernel && \
    python -m ipykernel install --user --name $ENV_NAME --display-name $ENV_NAME && \
    mamba clean -a   
 

# Update the .bashrc so that any interactive shell activates the stacked environments:
    RUN echo "source /opt/conda/etc/profile.d/conda.sh" >> /home/$NB_USER/.bashrc && \
    echo "conda activate ${BASE_ENV_NAME} && conda activate --stack ${ENV_NAME}" >> /home/$NB_USER/.bashrc && \
    sed -i '/conda activate gispy/d' /home/$NB_USER/.bashrc

ENV PATH=/opt/conda/envs/${ENV_NAME}/bin:$PATH

###############################################################################
# 8) GRASS env variables (PYTHONPATH, etc.)
###############################################################################
ENV GRASS_SKIP_MAPSET_OWNER_CHECK=1 \
    PYTHONPATH="/usr/local/grass/etc/python/:${PYTHONPATH}" \
    LD_LIBRARY_PATH="/usr/local/grass/lib:$LD_LIBRARY_PATH"

###############################################################################
# 9) Confirm Kernel & README
###############################################################################
RUN jupyter kernelspec list

ENV README=$HOME/README.md
RUN echo "" > $README && \
    echo "# Matisse Environment with GRASS GIS" >> $README && \
    echo "This container includes a conda environment 'matisse' plus a GRASS build." >> $README && \
    echo "Select 'Python (matisse)' in Jupyter. Have fun!" >> $README && \
    echo "" >> $README

# Done!
